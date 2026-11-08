/**
 * Platform adapter that binds the gaze pipeline to a reading session.
 *
 * Mirrors the ReaderVolumeKeys pattern: the host route owns one controller
 * and re-evaluates it whenever visibility or preference signals change. The
 * page-turn action is injected by the host (shared reader: ReaderInputPort
 * move; legacy reader: its internal user page-turn). When active it requests
 * the camera permission, runs the camera service feeding the gaze engine, and
 * fires the injected move (plus a soft haptic tick) when the engine triggers.
 * UI state (phase, dwell progress, error) is exposed through one listener.
 */
import { abilityAccessCtrl, common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { vibrator } from '@kit.SensorServiceKit'
import { display } from '@kit.ArkUI'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { GazeEngineState, GazePageTurnEngine, GazePhase, GazeSample } from './GazePageTurnEngine'
import { GazeCameraService } from './GazeCameraService'
import { GazeArTracker } from './GazeArTracker'

export interface GazeTurnUiState {
  /** Whether camera tracking is currently running. */
  readonly tracking: boolean
  readonly phase: GazePhase
  /** 0..1 progress of the bottom dwell window. */
  readonly dwellProgress: number
  /** Machine-readable failure reason, e.g. camera_permission_denied. */
  readonly errorMessage: string | null
}

/** Host-injected page turn; returns whether the move was accepted. */
export type GazeTurnAction = () => boolean

export class GazePageTurnController {
  private fireMove: GazeTurnAction
  private engine: GazePageTurnEngine
  private cameraService: GazeCameraService
  private arTracker: GazeArTracker
  private stateListener: ((state: GazeTurnUiState) => void) | null = null
  private tracking: boolean = false
  private starting: boolean = false
  private engineState: GazeEngineState = { phase: GazePhase.CALIBRATING, dwellProgress: 0 }
  private errorMessage: string | null = null

  constructor(fireMove: GazeTurnAction) {
    this.fireMove = fireMove
    this.engine = new GazePageTurnEngine()
    this.cameraService = new GazeCameraService()
    this.arTracker = new GazeArTracker()
    this.engine.onFire((): void => {
      this.firePageTurn()
    })
    this.engine.onStateChange((state: GazeEngineState): void => {
      this.engineState = state
      this.emitState()
    })
    const onSample: (sample: GazeSample | null) => void = (sample: GazeSample | null): void => {
      if (sample === null) {
        this.engine.markLost(Date.now())
        return
      }
      this.engine.feed(sample)
    }
    this.cameraService.onFrame(onSample)
    this.arTracker.onFrame(onSample)
    this.cameraService.onError((message: string): void => {
      this.errorMessage = message
      if (this.tracking) {
        this.stopTracking()
      } else {
        this.emitState()
      }
    })
  }

  onStateChange(listener: (state: GazeTurnUiState) => void): void {
    this.stateListener = listener
    this.emitState()
  }

  isTracking(): boolean {
    return this.tracking
  }

  private emitState(): void {
    if (this.stateListener !== null) {
      this.stateListener({
        tracking: this.tracking,
        phase: this.engineState.phase,
        dwellProgress: this.engineState.dwellProgress,
        errorMessage: this.errorMessage
      })
    }
  }

  private firePageTurn(): void {
    const accepted: boolean = this.fireMove()
    if (!accepted) {
      return
    }
    try {
      if (vibrator.isHdHapticSupported()) {
        void vibrator.startVibration({ type: 'preset', effectId: vibrator.HapticFeedback.EFFECT_SOFT, count: 1 },
          { usage: 'physicalFeedback' }).catch((): void => {})
      } else {
        void vibrator.startVibration({ type: 'time', duration: 20 },
          { usage: 'physicalFeedback' }).catch((): void => {})
      }
    } catch (_error) {
    }
  }

  /** Applies the desired tracking state; safe to call repeatedly. */
  async setActive(target: boolean, context: common.UIAbilityContext): Promise<void> {
    if (target) {
      await this.startTracking(context)
    } else {
      this.stopTracking()
    }
  }

  private async ensureCameraPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.CAMERA'])
      const granted: boolean = result.authResults.length > 0 && result.authResults[0] === 0
      DiagnosticLogger.info('reader', 'gaze_permission_result',
        `granted=${granted} authResults=[${result.authResults.join(',')}]`)
      return granted
    } catch (error) {
      const err = error as BusinessError
      DiagnosticLogger.error('reader', 'gaze_permission_request_failed',
        `code=${err.code} message=${err.message}`)
      return false
    }
  }

  /** Feeds the physical screen shape into the engine so tall (letterboxed)
   * screens relax the glance-up fire threshold. */
  private applyScreenAspect(): void {
    try {
      const d: display.Display = display.getDefaultDisplaySync()
      const longSide: number = Math.max(d.width, d.height)
      const shortSide: number = Math.min(d.width, d.height)
      if (shortSide > 0) {
        const aspect: number = longSide / shortSide
        this.engine.setScreenAspect(aspect)
        DiagnosticLogger.info('reader', 'gaze_screen_aspect', `screen=${d.width}x${d.height} aspect=${aspect}`)
      }
    } catch (error) {
      const err = error as BusinessError
      DiagnosticLogger.warn('reader', 'gaze_screen_aspect_failed',
        `code=${err.code} message=${err.message}`)
    }
  }

  private async startTracking(context: common.UIAbilityContext): Promise<void> {
    if (this.tracking || this.starting) {
      return
    }
    this.starting = true
    try {
      const granted: boolean = await this.ensureCameraPermission(context)
      if (!granted) {
        this.errorMessage = 'camera_permission_denied'
        this.emitState()
        return
      }
      this.errorMessage = null
      this.applyScreenAspect()
      this.engine.reset()
      // Prefer the AR Engine tracker: eyeball blendshapes make pure-eye
      // glances detectable, which the faceDetector pipeline cannot see.
      // Devices without AREngine support fall back to the camera pipeline.
      if (GazeArTracker.isSupported() && this.arTracker.start()) {
        this.tracking = true
        this.emitState()
        return
      }
      DiagnosticLogger.warn('reader', 'gaze_ar_fallback', 'falling back to faceDetector pipeline')
      const started: boolean = await this.cameraService.start(context)
      if (!started) {
        // errorMessage was recorded through the camera error listener.
        this.emitState()
        return
      }
      this.tracking = true
      this.emitState()
    } finally {
      this.starting = false
    }
  }

  stopTracking(): void {
    this.tracking = false
    this.arTracker.stop()
    this.cameraService.stop().catch((): void => {})
    this.emitState()
  }

  /** Final teardown when the owning route goes away. */
  dispose(): void {
    this.stateListener = null
    this.stopTracking()
  }
}

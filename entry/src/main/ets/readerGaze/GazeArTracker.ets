/**
 * ArkTS wrapper for the native AR Engine face tracker (libkoma_gaze_ar.so).
 *
 * The native module owns a human-perception FACE session and pumps it on its
 * own thread; this wrapper polls the latest snapshot at ~30 Hz and maps it
 * onto the existing GazeSample pipeline: head pitch comes from the face
 * center pose quaternion, and eyeCenterY is synthesized from the eyeball
 * down/up blendshape coefficients (straight ≈ 0.5, down > 0.5, up < 0.5).
 * Frames without a tracked face deliver null so the engine marks tracking
 * lost. Raw coefficients are logged (throttled) for on-device threshold
 * tuning; the faceDetector camera pipeline remains the fallback when the
 * device does not support AREngine face tracking.
 */
import gazeArNative from 'libkoma_gaze_ar.so'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { GazeSample } from './GazePageTurnEngine'

interface NativeGazeAr {
  isSupported(): number
  start(): number
  readSample(): GazeArNativeSample
  stop(): void
}

/** Shape returned by the native readSample() call. */
interface GazeArNativeSample {
  hasFace: boolean
  headPitchDeg: number
  eyeUp: number
  eyeDown: number
  eyeLeft: number
  eyeRight: number
  qx: number
  qy: number
  qz: number
  qw: number
  status: number
}

export type GazeArFrameListener = (sample: GazeSample | null) => void

const native: NativeGazeAr = gazeArNative as NativeGazeAr

export class GazeArTracker {
  private static readonly POLL_INTERVAL_MS: number = 33
  private static readonly AR_SUCCESS: number = 0
  private frameListener: GazeArFrameListener | null = null
  private pollTimer: number = -1
  private running: boolean = false
  private lastDiagAt: number = 0

  onFrame(listener: GazeArFrameListener): void {
    this.frameListener = listener
  }

  /** Whether AREngine face tracking is usable on this device. */
  static isSupported(): boolean {
    const status: number = native.isSupported()
    DiagnosticLogger.info('reader', 'gaze_ar_supported', `status=${status}`)
    return status === GazeArTracker.AR_SUCCESS
  }

  isRunning(): boolean {
    return this.running
  }

  start(): boolean {
    if (this.running) {
      return true
    }
    const status: number = native.start()
    if (status !== GazeArTracker.AR_SUCCESS) {
      DiagnosticLogger.warn('reader', 'gaze_ar_start_failed', `status=${status}`)
      return false
    }
    this.running = true
    this.lastDiagAt = 0
    this.pollTimer = setInterval((): void => {
      this.pollOnce()
    }, GazeArTracker.POLL_INTERVAL_MS)
    DiagnosticLogger.info('reader', 'gaze_ar_started', `pollMs=${GazeArTracker.POLL_INTERVAL_MS}`)
    return true
  }

  stop(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer)
      this.pollTimer = -1
    }
    if (!this.running) {
      return
    }
    this.running = false
    native.stop()
    DiagnosticLogger.info('reader', 'gaze_ar_stopped', '')
  }

  private pollOnce(): void {
    const raw: GazeArNativeSample = native.readSample()
    this.emitDiag(raw)
    if (this.frameListener === null) {
      return
    }
    if (!raw.hasFace) {
      this.frameListener(null)
      return
    }
    this.frameListener({
      pitch: raw.headPitchDeg,
      eyeCenterY: 0.5 + 0.5 * (raw.eyeDown - raw.eyeUp),
      probability: 1,
      timestamp: Date.now()
    })
  }

  /** Throttled (500ms) dump of the raw AR signals for threshold tuning. */
  private emitDiag(raw: GazeArNativeSample): void {
    const now: number = Date.now()
    if (now - this.lastDiagAt < 500) {
      return
    }
    this.lastDiagAt = now
    DiagnosticLogger.info('reader', 'gaze_ar_diag',
      `hasFace=${raw.hasFace ? 1 : 0} pitch=${raw.headPitchDeg.toFixed(2)} ` +
      `eU=${raw.eyeUp.toFixed(3)} eD=${raw.eyeDown.toFixed(3)} ` +
      `eL=${raw.eyeLeft.toFixed(3)} eR=${raw.eyeRight.toFixed(3)} ` +
      `q=[${raw.qx.toFixed(3)},${raw.qy.toFixed(3)},${raw.qz.toFixed(3)},${raw.qw.toFixed(3)}] ` +
      `st=${raw.status}`)
  }
}

/**
 * ArkTS wrapper for the native AR Engine face tracker (libkoma_gaze_ar.so).
 *
 * The native module owns a human-perception FACE session and pumps it on its
 * own thread; this wrapper polls the latest snapshot at ~30 Hz and maps it
 * onto the existing GazeSample pipeline: head pitch comes from the face
 * center pose quaternion, and eyeCenterY is synthesized from the eyeball
 * down/up blendshape coefficients (straight ≈ 0.5, down > 0.5, up < 0.5).
 * Frames without a tracked face deliver null so the engine marks tracking
 * lost. The faceDetector camera pipeline remains the fallback when the
 * device does not support AREngine face tracking.
 */
import gazeArNative from 'libkoma_gaze_ar.so'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { GazeSample, GazeTuning } from './GazePageTurnEngine'

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
  frameSequence: number
  lossSequence: number
  status: number
}

export type GazeArFrameListener = (sample: GazeSample | null) => void

const native: NativeGazeAr = gazeArNative as NativeGazeAr

export class GazeArTracker {
  private static readonly POLL_INTERVAL_MS: number = 33
  private static readonly AR_SUCCESS: number = 0
  private static owner: GazeArTracker | null = null
  private frameListener: GazeArFrameListener | null = null
  private pollTimer: number = -1
  private running: boolean = false
  private lastFrameSequence: number = 0
  private lastLossSequence: number = 0
  private lastFrameAt: number = 0

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
    if (GazeArTracker.owner !== null) return false
    const status: number = native.start()
    if (status !== GazeArTracker.AR_SUCCESS) {
      DiagnosticLogger.warn('reader', 'gaze_ar_start_failed', `status=${status}`)
      return false
    }
    this.running = true
    GazeArTracker.owner = this
    this.lastFrameSequence = 0
    this.lastLossSequence = 0
    this.lastFrameAt = Date.now()
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
    if (GazeArTracker.owner === this) {
      GazeArTracker.owner = null
      native.stop()
    }
    DiagnosticLogger.info('reader', 'gaze_ar_stopped', '')
  }

  private pollOnce(): void {
    if (!this.running) return
    const raw: GazeArNativeSample = native.readSample()
    if (this.frameListener === null) {
      return
    }
    const now = Date.now()
    const interrupted = raw.lossSequence !== this.lastLossSequence
    this.lastLossSequence = raw.lossSequence
    if (raw.status !== GazeArTracker.AR_SUCCESS || !raw.hasFace || raw.frameSequence <= 0) {
      this.frameListener(null)
      return
    }
    if (raw.frameSequence === this.lastFrameSequence) {
      if (now - this.lastFrameAt >= GazeTuning.LOST_TOLERANCE_MS) this.frameListener(null)
      return
    }
    if (interrupted) this.frameListener(null)
    this.lastFrameSequence = raw.frameSequence
    this.lastFrameAt = now
    this.frameListener({
      pitch: raw.headPitchDeg,
      eyeCenterY: 0.5 + 0.5 * (raw.eyeDown - raw.eyeUp),
      probability: 1,
      timestamp: now
    })
  }

}

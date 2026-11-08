/**
 * Gaze page turn state machine.
 *
 * Implements the Huawei-Reading style gesture: after the reader's gaze has
 * stayed at the bottom of the page for a dwell window, glancing back up
 * (head pitch up / eyes up relative to the calibrated baseline) fires a
 * single "next page" command. All thresholds are relative to a short
 * calibration baseline captured when tracking starts, so device posture
 * and individual differences do not require absolute tuning.
 */
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

export enum GazePhase {
  CALIBRATING = 'calibrating',
  READING = 'reading',
  ARMED = 'armed',
  COOLDOWN = 'cooldown',
  LOST = 'lost'
}

export interface GazeSample {
  /** Head pitch angle in degrees from faceDetector.pose.pitch. */
  readonly pitch: number
  /** Eye centers' vertical position inside the face rect, normalized 0..1. */
  readonly eyeCenterY: number
  readonly probability: number
  /** Monotonic milliseconds timestamp (e.g. Date.now()). */
  readonly timestamp: number
}



export interface GazeEngineState {
  readonly phase: GazePhase
  /** 0..1 progress of the bottom dwell window while READING. */
  readonly dwellProgress: number
}

/** Tuning constants; signs may be flipped on-device if the detector reports reversed directions. */
export class GazeTuning {
  static readonly CALIBRATION_MS: number = 2000
  static readonly MAX_CALIBRATION_SAMPLES: number = 64
  static readonly MIN_FACE_PROBABILITY: number = 0.3
  /** Combined gaze signal offset from baseline that arms the hint (shows the
    * "glance up to turn" pill). Loosened on user request so the hint appears
    * once the gaze reaches roughly the lower third of the screen (~10 deg
    * below baseline) instead of the page bottom. The actual page turn still
    * requires the unchanged deep-down-then-up travel (TRIGGER_UP_DELTA /
    * TRIGGER_TOP_LEVEL); armedGaze tracks the real lowest point, so arming
    * early cannot make a fire easier. */
  static readonly LOOK_BOTTOM_OFFSET: number = 0.25
  /** Consecutive frames below the bottom threshold required to arm (jitter filter). */
  static readonly ARM_CONFIRM_FRAMES: number = 2
  /** After a fire/timeout, the gaze must stay below the arm level this many
   * frames before a new arm may begin. Fast eye glances otherwise re-arm on
   * the still-downward gaze during cooldown and the natural return fires an
   * unintended second page turn. */
  static readonly ARM_RELEASE_FRAMES: number = 2
  /** After arming, glancing up must happen within this window. */
  static readonly ARMED_TIMEOUT_MS: number = 5000
  /** Drop of the combined signal from the lowest gaze point required to fire;
   * on-device pitch noise is ~+/-5 deg (~0.13 signal), so this stays far above it. */
  static readonly TRIGGER_UP_DELTA: number = 0.45
  /** The combined signal must rise above the baseline (a real glance toward the
   * upper page area); merely returning to the reading posture (gaze ~0)
   * must NOT fire. Negative on purpose. */
  static readonly TRIGGER_TOP_LEVEL: number = -0.10
  /** Typical manga page aspect (height / width) used for the letterbox estimate. */
  static readonly PAGE_ASPECT: number = 1.4
  /** How much each unit of letterbox ratio relaxes the trigger top level.
   * Kept small so the fire level always stays clearly below the arm level. */
  static readonly TRIGGER_TOP_RELAX_SCALE: number = 0.15
  /** Consecutive frames meeting the trigger condition required to fire (jitter filter). */
  static readonly TRIGGER_CONFIRM_FRAMES: number = 3
  /** Anti-repeat pause after a fired turn. On-device data: the natural gaze
   * return after a fire re-arms within ~1-2s and the recovery bounce fires a
   * second unintended turn; 3s covers the whole bounce while staying under
   * the fastest deliberate turn cadence observed (~4s). */
  static readonly COOLDOWN_MS: number = 3000
  /** Losing the face for this long resets to calibration. */
  static readonly LOST_TOLERANCE_MS: number = 1800
  /** Calibration completes only when the pitch p10..p90 spread stays within
   * this range — calibration captured while the user is still moving produced
   * wildly wrong baselines. */
  static readonly CALIBRATION_STABLE_RANGE_DEG: number = 10
  /** Hard cap on calibration duration; gives up and uses the median anyway. */
  static readonly CALIBRATION_MAX_MS: number = 10000
  /** Per-frame servo rate pulling the baseline so the windowed-mean gaze
   * settles at zero; recovers from a calibration captured mid-settle without
   * a visible recalibration. */
  static readonly BASELINE_SERVO_RATE: number = 0.02
  /** Rolling gaze window (frames) feeding the baseline servo; ~2.5s at 27fps,
   * long enough that brief glances barely move the mean. */
  static readonly SERVO_WINDOW_FRAMES: number = 68
  /** pitch weight/sign of the combined signal; on-device data shows pitch drops
   * below the baseline while looking down (positive = looking down). */
  static readonly PITCH_SIGN: number = -1
  /** Full-scale head pitch range in degrees: measured glances span ~40 deg. */
  static readonly PITCH_SCALE_DEG: number = 40
  /** eyeCenterY weight/sign; the detector's eye points barely move (no pupil
   * tracking), so this only contributes a small correction. */
  static readonly EYE_SIGN: number = 1
  static readonly EYE_SCALE: number = 0.5
}

type GazeFireListener = () => void
type GazeStateListener = (state: GazeEngineState) => void

export class GazePageTurnEngine {
  private phase: GazePhase = GazePhase.CALIBRATING
  private fireListener: GazeFireListener | null = null
  private stateListener: GazeStateListener | null = null
  private calibrationPitch: number[] = []
  private calibrationEye: number[] = []
  private calibrationStartedAt: number = 0
  private baselinePitch: number = 0
  private baselineEye: number = 0
  private baselineReady: boolean = false
  private armedAt: number = 0
  private armedGaze: number = 0
  private cooldownUntil: number = 0
  private lastFaceAt: number = 0
  /** Consecutive frames with the gaze at the bottom, for arm jitter filtering. */
  private bottomStreak: number = 0
  /** Consecutive frames meeting the trigger condition, for fire jitter filtering. */
  private upStreak: number = 0
  /** Screen-adapted trigger top level; see GazeTuning.TRIGGER_TOP_RELAX_SCALE. */
  private triggerTopLevel: number = GazeTuning.TRIGGER_TOP_LEVEL
  /** Last emitted state, so steady frames do not spam the UI (each emission
   * rebuilds the indicator overlay and can interrupt in-progress gestures). */
  private lastEmittedPhase: GazePhase | null = null
  private lastEmittedProgress: number = -1
  /** Throttled diagnostic sampling of raw gaze signals for on-device tuning. */
  private lastDiagAt: number = 0
  /** Rolling windows of recent READING pitch / eye values driving the per-channel baseline servo. */
  private pitchHistory: number[] = []
  private eyeHistory: number[] = []
  /** Re-arm hysteresis: a new arm may only begin after the gaze has left the
   * bottom region for ARM_RELEASE_FRAMES consecutive frames. */
  private releasePrimed: boolean = false
  private releaseStreak: number = 0

  constructor() {
    this.calibrationStartedAt = Date.now()
  }

  /**
   * Adapts the fire threshold to the screen shape. Tall screens (aspect > page
   * aspect) show the width-fitted page with big letterbox bars, so the glance
   * up only needs to return into the content area, not toward the screen top.
   * aspect: physical screen height / width (long side / short side).
   */
  setScreenAspect(aspect: number): void {
    const safeAspect: number = aspect > 0 ? aspect : 1
    const contentRatio: number = Math.min(1, GazeTuning.PAGE_ASPECT / safeAspect)
    this.triggerTopLevel =
      GazeTuning.TRIGGER_TOP_LEVEL + (1 - contentRatio) * GazeTuning.TRIGGER_TOP_RELAX_SCALE
  }

  onFire(listener: GazeFireListener): void {
    this.fireListener = listener
  }

  onStateChange(listener: GazeStateListener): void {
    this.stateListener = listener
  }

  /** Restart from calibration, dropping any armed/cooldown state. */
  reset(): void {
    this.phase = GazePhase.CALIBRATING
    this.calibrationPitch = []
    this.calibrationEye = []
    this.calibrationStartedAt = Date.now()
    this.baselineReady = false
    this.armedAt = 0
    this.armedGaze = 0
    this.cooldownUntil = 0
    this.bottomStreak = 0
    this.upStreak = 0
    this.releasePrimed = false
    this.releaseStreak = 0
    this.pitchHistory = []
    this.eyeHistory = []
    this.emitState()
  }

  /** Combined "looking down" signal; larger = gaze further toward the page bottom. */
  private combinedGaze(pitch: number, eyeCenterY: number): number {
    const pitchPart: number = GazeTuning.PITCH_SIGN * (pitch - this.baselinePitch) / GazeTuning.PITCH_SCALE_DEG
    const eyePart: number = GazeTuning.EYE_SIGN * (eyeCenterY - this.baselineEye) / GazeTuning.EYE_SCALE
    return pitchPart + eyePart
  }

  private emitState(): void {
    const progress: number = this.phase === GazePhase.ARMED ? 1 : 0
    if (this.phase === this.lastEmittedPhase && progress === this.lastEmittedProgress) {
      return
    }
    this.lastEmittedPhase = this.phase
    this.lastEmittedProgress = progress
    if (this.stateListener !== null) {
      this.stateListener({
        phase: this.phase,
        dwellProgress: progress
      })
    }
  }

  private finishCalibration(): void {
    this.baselinePitch = median(this.calibrationPitch)
    this.baselineEye = median(this.calibrationEye)
    this.baselineReady = this.calibrationPitch.length > 0
    this.calibrationPitch = []
    this.calibrationEye = []
    this.phase = GazePhase.READING
    this.releasePrimed = false
    this.releaseStreak = 0
    this.pitchHistory = []
    this.eyeHistory = []
  }

  /** True when the recent calibration window is tight enough to trust as a
   * baseline; a calibration captured mid-motion produced unusable baselines. */
  private calibrationSettled(): boolean {
    const count: number = this.calibrationPitch.length
    if (count < 10) {
      return false
    }
    const sorted: number[] = this.calibrationPitch.slice().sort((a: number, b: number): number => a - b)
    const lo: number = sorted[Math.floor(count * 0.1)]
    const hi: number = sorted[Math.min(count - 1, Math.floor(count * 0.9))]
    return hi - lo <= GazeTuning.CALIBRATION_STABLE_RANGE_DEG
  }

  private fireEvent(): void {
    if (this.fireListener !== null) {
      this.fireListener()
    }
  }

  private enterCooldown(now: number): void {
    this.phase = GazePhase.COOLDOWN
    this.cooldownUntil = now + GazeTuning.COOLDOWN_MS
    this.armedAt = 0
    this.armedGaze = 0
    this.bottomStreak = 0
    this.upStreak = 0
    this.releasePrimed = false
    this.releaseStreak = 0
    this.pitchHistory = []
    this.eyeHistory = []
  }

  /** Feed one detector frame. Invalid or missing faces are expressed by calling onFaceLost. */
  feed(sample: GazeSample): void {
    const now = sample.timestamp
    this.lastFaceAt = now
    this.emitDiag(sample, now)
    if (sample.probability < GazeTuning.MIN_FACE_PROBABILITY) {
      this.markLost(now)
      return
    }
    if (this.phase === GazePhase.LOST) {
      this.reset()
      return
    }
    if (this.phase === GazePhase.CALIBRATING) {
      this.calibrationPitch.push(sample.pitch)
      this.calibrationEye.push(sample.eyeCenterY)
      // Rolling window of the most recent samples: the baseline must reflect
      // the settled posture, not the moment tracking started.
      if (this.calibrationPitch.length > GazeTuning.MAX_CALIBRATION_SAMPLES) {
        this.calibrationPitch.shift()
        this.calibrationEye.shift()
      }
      const elapsed: number = now - this.calibrationStartedAt
      const minElapsedOk: boolean = elapsed >= GazeTuning.CALIBRATION_MS
      const stable: boolean = this.calibrationSettled()
      const timedOut: boolean = elapsed >= GazeTuning.CALIBRATION_MAX_MS
      if ((minElapsedOk && stable) || timedOut) {
        this.finishCalibration()
      }
      this.emitState()
      return
    }
    if (!this.baselineReady) {
      this.reset()
      return
    }
    const gaze = this.combinedGaze(sample.pitch, sample.eyeCenterY)
    if (this.phase === GazePhase.COOLDOWN) {
      // Keep the re-arm hysteresis tracking the real gaze during cooldown.
      // After a fire the user starts reading from the page top; when the gaze
      // has already reached the bottom region by the time the cooldown ends,
      // the previous hard reset deadlocked the armed hint until the user
      // looked up and back down. Priming here cannot arm early (arm only
      // happens in READING after the cooldown); the still-downward timeout
      // path is unaffected (it never passes through COOLDOWN).
      if (gaze >= GazeTuning.LOOK_BOTTOM_OFFSET) {
        this.releaseStreak = 0
      } else {
        this.releaseStreak += 1
        if (this.releaseStreak >= GazeTuning.ARM_RELEASE_FRAMES) {
          this.releasePrimed = true
        }
      }
      if (now >= this.cooldownUntil) {
        this.phase = GazePhase.READING
        this.bottomStreak = 0
        this.upStreak = 0
        // releasePrimed/releaseStreak keep the values accumulated above.
        this.pitchHistory = []
        this.eyeHistory = []
      }
      this.emitState()
      return
    }
    if (this.phase === GazePhase.ARMED) {
      if (now - this.armedAt > GazeTuning.ARMED_TIMEOUT_MS) {
        this.phase = GazePhase.READING
        this.armedAt = 0
        this.armedGaze = 0
        this.bottomStreak = 0
        this.upStreak = 0
        this.releasePrimed = false
        this.releaseStreak = 0
        this.pitchHistory = []
        this.eyeHistory = []
        this.emitState()
        return
      }
      // Track the lowest gaze point seen while armed so the fire delta
      // measures the real upward movement, not the arm-instant value.
      if (gaze > this.armedGaze) {
        this.armedGaze = gaze
      }
      if (this.armedGaze - gaze >= GazeTuning.TRIGGER_UP_DELTA &&
        gaze <= this.triggerTopLevel) {
        this.upStreak += 1
        if (this.upStreak >= GazeTuning.TRIGGER_CONFIRM_FRAMES) {
          this.fireEvent()
          this.enterCooldown(now)
        }
      } else {
        this.upStreak = 0
      }
      this.emitState()
      return
    }
    // READING: servo each baseline toward its own channel's windowed mean so
    // both contributions settle at zero. Per-channel on purpose: with
    // eye-dominated signals a single-channel servo shoved the pitch baseline
    // around with eye movement it could never absorb. Brief glances barely
    // move the windowed mean, and the servo is frozen while ARMED/COOLDOWN so
    // it cannot eat real triggers.
    this.pitchHistory.push(sample.pitch)
    this.eyeHistory.push(sample.eyeCenterY)
    if (this.pitchHistory.length > GazeTuning.SERVO_WINDOW_FRAMES) {
      this.pitchHistory.shift()
      this.eyeHistory.shift()
    }
    if (this.pitchHistory.length >= Math.floor(GazeTuning.SERVO_WINDOW_FRAMES / 2)) {
      let pitchSum: number = 0
      let eyeSum: number = 0
      for (let i = 0; i < this.pitchHistory.length; i++) {
        pitchSum += this.pitchHistory[i]
        eyeSum += this.eyeHistory[i]
      }
      const meanPitch: number = pitchSum / this.pitchHistory.length
      const meanEye: number = eyeSum / this.pitchHistory.length
      const pitchPart: number =
        GazeTuning.PITCH_SIGN * (meanPitch - this.baselinePitch) / GazeTuning.PITCH_SCALE_DEG
      const eyePart: number =
        GazeTuning.EYE_SIGN * (meanEye - this.baselineEye) / GazeTuning.EYE_SCALE
      this.baselinePitch +=
        GazeTuning.BASELINE_SERVO_RATE * pitchPart * GazeTuning.PITCH_SCALE_DEG / GazeTuning.PITCH_SIGN
      this.baselineEye +=
        GazeTuning.BASELINE_SERVO_RATE * eyePart * GazeTuning.EYE_SCALE / GazeTuning.EYE_SIGN
    }
    // Entering the lower-third region immediately shows the armed hint, but a
    // new arm may only begin after the re-arm hysteresis released: the gaze
    // must have left the bottom region since the last arm/cooldown.
    if (gaze >= GazeTuning.LOOK_BOTTOM_OFFSET) {
      this.releaseStreak = 0
      if (this.releasePrimed) {
        this.bottomStreak += 1
        if (this.bottomStreak >= GazeTuning.ARM_CONFIRM_FRAMES) {
          this.phase = GazePhase.ARMED
          this.armedAt = now
          this.armedGaze = gaze
          this.upStreak = 0
          this.bottomStreak = 0
          this.releasePrimed = false
          this.pitchHistory = []
          this.eyeHistory = []
        }
      }
    } else {
      this.bottomStreak = 0
      this.releaseStreak += 1
      if (this.releaseStreak >= GazeTuning.ARM_RELEASE_FRAMES) {
        this.releasePrimed = true
      }
    }
    this.emitState()
  }

  /** Throttled (500ms) dump of the raw gaze signals to calibrate thresholds. */
  private emitDiag(sample: GazeSample, now: number): void {
    if (now - this.lastDiagAt < 500) {
      return
    }
    this.lastDiagAt = now
    const gaze: string = this.baselineReady
      ? this.combinedGaze(sample.pitch, sample.eyeCenterY).toFixed(3) : 'n/a'
    DiagnosticLogger.info('reader', 'gaze_diag',
      `phase=${this.phase} pitch=${sample.pitch.toFixed(2)} eye=${sample.eyeCenterY.toFixed(3)} ` +
      `baseP=${this.baselinePitch.toFixed(2)} baseE=${this.baselineEye.toFixed(3)} gaze=${gaze} ` +
      `lowest=${this.armedGaze.toFixed(3)} top=${this.triggerTopLevel.toFixed(3)} primed=${this.releasePrimed ? 1 : 0}`)
  }

  /** Called when no usable face is present in the latest frame. */
  markLost(now: number): void {
    if (this.phase === GazePhase.LOST) {
      return
    }
    if (now - this.lastFaceAt < GazeTuning.LOST_TOLERANCE_MS && this.phase !== GazePhase.CALIBRATING) {
      // Brief dropouts keep the current phase.
      return
    }
    this.phase = GazePhase.LOST
    this.armedAt = 0
    this.armedGaze = 0
    this.bottomStreak = 0
    this.upStreak = 0
    this.emitState()
  }
}

function median(values: number[]): number {
  if (values.length === 0) {
    return 0
  }
  const sorted: number[] = values.slice().sort((a: number, b: number): number => a - b)
  const mid: number = Math.floor(sorted.length / 2)
  return sorted.length % 2 === 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
}

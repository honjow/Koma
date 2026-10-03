import type { Want } from '@kit.AbilityKit'

const DEVICE_VERIFICATION_ISOLATION_PARAM: string = 'komaDeviceVerificationIsolation'

// This is deliberately process-local: a recovery run must not change user preferences.
let suppressBackgroundSideEffects: boolean = false

/**
 * Debug-only verification isolation. A leased-device Want can keep normal Reader
 * routing while preventing app-open backup and remote-progress work from touching
 * user or remote state. The value is reset on every incoming Want and never stored.
 */
export function captureKomaDeviceVerificationIsolation(want: Want, debugBuild: boolean): void {
  suppressBackgroundSideEffects = debugBuild &&
    want.parameters?.[DEVICE_VERIFICATION_ISOLATION_PARAM] === true
}

export function shouldSuppressKomaDeviceVerificationBackgroundSideEffects(): boolean {
  return suppressBackgroundSideEffects
}

import type { Want } from '@kit.AbilityKit'

const DEVICE_VERIFICATION_ISOLATION_PARAM: string = 'komaDeviceVerificationIsolation'

// This is deliberately process-local: a recovery run must not change user preferences.
let suppressBackgroundSideEffects: boolean = false
let cloudVerificationRun: string = ''
let cloudReadingVerificationWork: string = ''

/**
 * Debug-only verification isolation. A leased-device Want can keep normal Reader
 * routing while preventing app-open backup and remote-progress work from touching
 * user or remote state. The value is reset on every incoming Want and never stored.
 */
export function captureKomaDeviceVerificationIsolation(want: Want, debugBuild: boolean): void {
  suppressBackgroundSideEffects = debugBuild &&
    want.parameters?.[DEVICE_VERIFICATION_ISOLATION_PARAM] === true
  const cloudRun = want.parameters?.['komaCloudVerificationRun']
  cloudVerificationRun = suppressBackgroundSideEffects && typeof cloudRun === 'string' &&
    /^(send|receive|remove|absent):[a-z0-9-]{6,40}$/.test(cloudRun) ? cloudRun : ''
  const work = want.parameters?.['komaCloudReadingVerificationWork']
  cloudReadingVerificationWork = ''
  if (suppressBackgroundSideEffects && typeof work === 'string' && work.length <= 2048 && work !== '') {
    const separator = work.indexOf('/')
    // Keep a malformed explicit scope active so it fails closed at admission.
    cloudReadingVerificationWork = separator > 0 ?
      JSON.stringify([work.slice(0, separator), work.slice(separator + 1)]) : work
  }
}

export function shouldSuppressKomaDeviceVerificationBackgroundSideEffects(): boolean {
  return suppressBackgroundSideEffects
}

export function komaCloudVerificationRun(): string {
  return cloudVerificationRun
}

export function komaCloudReadingVerificationWork(): string {
  return cloudReadingVerificationWork
}

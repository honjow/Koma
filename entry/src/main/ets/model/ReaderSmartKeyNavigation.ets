import { deviceInfo } from '@kit.BasicServicesKit'
import { Action, inputConsumer, inputDevice, KeyCode, KeyEvent } from '@kit.InputKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

/** API 26 exposes the two slide codes; the side key's touch/hold is not exposed here. */
export async function supportsReaderSmartKeyNavigation(): Promise<boolean> {
  if (deviceInfo.sdkApiVersion < 26) return false
  try {
    for (const id of await inputDevice.getDeviceList()) {
      try {
        const keys = inputDevice.supportKeysSync(id,
          [KeyCode.KEYCODE_FINGERPRINT_SLIDE_UP, KeyCode.KEYCODE_FINGERPRINT_SLIDE_DOWN])
        if (keys[0] && keys[1]) return true
      } catch (_error) {
        // A device can disappear between listing and checking its keys.
      }
    }
  } catch (_error) {
    // If the hardware cannot be confirmed, leave the system behavior alone.
  }
  return false
}

/** Owned by the foreground reader. A late capability result cannot take over system keys after exit. */
export class ReaderSmartKeyNavigation {
  private requested: boolean = false
  private revision: number = 0
  private previous: ((event: KeyEvent) => void) | null = null
  private next: ((event: KeyEvent) => void) | null = null
  private readonly move: (next: boolean) => void

  constructor(move: (next: boolean) => void) { this.move = move }

  setActive(active: boolean): void {
    if (!active) {
      this.close()
    } else if (!this.requested) {
      this.requested = true
      void this.subscribe(++this.revision)
    }
  }

  private async subscribe(revision: number): Promise<void> {
    if (!await supportsReaderSmartKeyNavigation() || revision !== this.revision) return
    this.releaseCallbacks()
    if (this.previous !== null || this.next !== null) return
    const previous = (event: KeyEvent): void => { this.dispatch(event, revision, false) }
    const next = (event: KeyEvent): void => { this.dispatch(event, revision, true) }
    try {
      inputConsumer.on('keyPressed', { key: KeyCode.KEYCODE_FINGERPRINT_SLIDE_UP,
        action: Action.DOWN, isRepeat: false }, previous)
      this.previous = previous
      inputConsumer.on('keyPressed', { key: KeyCode.KEYCODE_FINGERPRINT_SLIDE_DOWN,
        action: Action.DOWN, isRepeat: false }, next)
      this.next = next
    } catch (_error) {
      this.close()
      DiagnosticLogger.warn('reader', 'smart_key_subscribe_failed', '智控键订阅失败，保留系统响应')
    }
  }

  private dispatch(event: KeyEvent, revision: number, next: boolean): void {
    if (this.requested && revision === this.revision && event.action === Action.DOWN) this.move(next)
  }

  close(): void {
    this.requested = false
    this.revision += 1
    this.releaseCallbacks()
  }

  private releaseCallbacks(): void {
    if (this.previous !== null) {
      try { inputConsumer.off('keyPressed', this.previous); this.previous = null }
      catch (_error) { DiagnosticLogger.warn('reader', 'smart_key_release_failed', 'up') }
    }
    if (this.next !== null) {
      try { inputConsumer.off('keyPressed', this.next); this.next = null }
      catch (_error) { DiagnosticLogger.warn('reader', 'smart_key_release_failed', 'down') }
    }
  }
}

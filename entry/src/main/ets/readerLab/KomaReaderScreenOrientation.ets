import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { ReaderScreenOrientation } from '../model/ReaderPreferencesStore'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

/** A reading route owns only its override. Restore the previous window policy on exit or cover. */
export class KomaReaderScreenOrientation {
  private static operations: Promise<void> = Promise.resolve()
  private mainWindow: window.Window | null = null
  private previous: window.Orientation | null = null
  private requested: ReaderScreenOrientation | null = 'system'
  private revision: number = 0
  private completion: Promise<void> = Promise.resolve()

  apply(context: common.UIAbilityContext, orientation: ReaderScreenOrientation): Promise<void> {
    if (this.requested === orientation) return this.completion
    this.requested = orientation
    const revision = ++this.revision
    this.completion = KomaReaderScreenOrientation.operations.then(async (): Promise<void> => {
      if (revision !== this.revision) return
      if (orientation === 'system') {
        if (this.mainWindow !== null && this.previous !== null) {
          await this.mainWindow.setPreferredOrientation(this.previous)
          this.mainWindow = null
          this.previous = null
        }
        return
      }
      const win = this.mainWindow ?? await window.getLastWindow(context)
      if (revision !== this.revision) return
      if (this.previous === null) {
        this.previous = win.getPreferredOrientation()
        this.mainWindow = win
      }
      await win.setPreferredOrientation(orientation === 'landscape' ?
        window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT)
    }).catch((): void => {
      DiagnosticLogger.warn('reader', 'screen_orientation_failed', 'Reader window orientation request failed')
      if (revision === this.revision) this.requested = null
    })
    KomaReaderScreenOrientation.operations = this.completion
    return this.completion
  }
}

import { common } from '@kit.AbilityKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { AppStrings } from '../i18n/AppStrings'
import { LibraryFilterStore } from '../model/LibraryFilterStore'
import { komaToastOptions } from '../theme/KomaPopupOptions'
import { libraryCoverGridColumnCount, libraryCoverGridMinimumWidth, libraryCoverGridPinchWidth } from '../utils/LibraryCoverLayout'

/** A local preview until the shared width is committed by LibraryFilterStore. */
@ObservedV2
export class LibraryCoverGridAdjustment {
  @Trace private draftWidth: number = 0
  private revision: number = 0
  private viewport: number = 0
  private gridSpacing: string = 'standard'
  private startWidth: number = 0
  private startColumns: number = 0
  private crossedColumn: boolean = false
  private pinching: boolean = false
  private changed: boolean = false

  width(committedWidth: number): number {
    return this.draftWidth || committedWidth
  }

  preview(width: number): void {
    this.revision++
    this.draftWidth = width
  }

  beginPinch(viewport: number, gridSpacing: string, committedWidth: number): void {
    this.viewport = viewport
    this.gridSpacing = gridSpacing
    this.startWidth = libraryCoverGridMinimumWidth(viewport, this.width(committedWidth))
    this.startColumns = libraryCoverGridColumnCount(viewport, gridSpacing, this.startWidth)
    this.crossedColumn = false
    this.changed = false
    this.pinching = viewport > 0
  }

  updatePinch(scale: number, ui: UIContext): void {
    if (!this.pinching || this.crossedColumn || !Number.isFinite(scale) || scale <= 0) return
    const width = libraryCoverGridPinchWidth(this.viewport, this.gridSpacing, this.startWidth, this.startColumns, scale)
    if (!this.changed && width === this.startWidth) return
    this.changed = true
    this.preview(width)
    const columns = libraryCoverGridColumnCount(this.viewport, this.gridSpacing, width)
    this.crossedColumn = columns !== this.startColumns
    if (this.crossedColumn) {
      try {
        ui.getPromptAction().showToast(komaToastOptions({
          message: AppStrings.get(columns > this.startColumns ? 'column_density_more' : 'column_density_fewer'),
          duration: 800,
        }))
      } catch (_error) {}
    }
  }

  endPinch(ui: UIContext): void {
    if (!this.pinching) return
    this.pinching = false
    if (this.changed) this.save(ui, this.draftWidth)
  }

  cancelPinch(): void {
    if (!this.pinching) return
    this.pinching = false
    if (this.changed) this.preview(0)
  }

  save(ui: UIContext, width: number): void {
    const context = ui.getHostContext() as common.UIAbilityContext | undefined
    if (context === undefined) {
      this.preview(0)
      return
    }
    this.preview(width)
    const revision = this.revision
    void new LibraryFilterStore(context).update({ gridColumnWidth: width }).catch((error: Error): void => {
      DiagnosticLogger.exception('library', 'grid_column_width_save_failed', error)
      if (this.revision === revision) {
        try {
          ui.getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('library_category_display_save_failed') }))
        } catch (_error) {}
      }
    }).finally((): void => {
      if (this.revision === revision) this.preview(0)
    })
  }
}

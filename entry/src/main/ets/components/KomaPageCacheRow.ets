import { AppStrings } from '../i18n/AppStrings'
import { komaDialogMaterial } from '../theme/KomaPopupOptions'
import { sourceMangaDetailSnapshotCache } from '../model/SourceMangaDetailSnapshotCache'
import { ConciseListRow } from './ui/ConciseListRow'

/** Detail and chapter rows cached for the current process. */
@ComponentV2
export struct KomaPageCacheRow {
  @Local private count: number = 0
  private active: boolean = false

  aboutToAppear(): void {
    this.active = true
    this.count = sourceMangaDetailSnapshotCache.size()
  }

  aboutToDisappear(): void { this.active = false }

  private detail(): string {
    return AppStrings.format('cache_content_count', this.count.toString())
  }

  private confirmClear(): void {
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: AppStrings.get('cache_content_title'),
      message: AppStrings.format('cache_clear_confirm', AppStrings.get('cache_content_title')),
      primaryButton: { value: AppStrings.get('common_cancel'), action: () => {} },
      secondaryButton: { value: AppStrings.get('common_clear'), action: (): void => {
        sourceMangaDetailSnapshotCache.clear()
        if (this.active) this.count = 0
      } },
    })
  }

  build() {
    ConciseListRow({ title: AppStrings.get('cache_content_title'), trailingText: this.detail(),
      showChevron: false, action: (): void => { this.confirmClear() } })
  }
}

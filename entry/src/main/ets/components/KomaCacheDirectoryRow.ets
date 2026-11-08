import { common } from '@kit.AbilityKit'
import { AppStrings } from '../i18n/AppStrings'
import { komaDialogMaterial, komaToastOptions } from '../theme/KomaPopupOptions'
import { clearCoverImageCache, getCoverImageCacheStats } from '../model/CoverImageCacheService'
import { clearSourceIndexIconCache, getSourceIndexIconCacheStats } from '../model/SourceIndexIconCache'
import { ConciseListRow } from './ui/ConciseListRow'

/** A separate, rebuildable disk cache with its own size and clear action. */
@ComponentV2
export struct KomaCacheDirectoryRow {
  @Param kind: string = 'cover'
  @Param titleKey: string = ''
  @Local private totalBytes: number = 0
  @Local private clearing: boolean = false
  private active: boolean = false

  aboutToAppear(): void {
    this.active = true
    void this.refresh()
  }

  aboutToDisappear(): void { this.active = false }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private async refresh(): Promise<void> {
    try {
      const bytes = this.kind === 'cover'
        ? (await getCoverImageCacheStats(this.context())).totalBytes
        : getSourceIndexIconCacheStats(this.context()).totalBytes
      if (this.active) this.totalBytes = bytes
    } catch (_error) {
      if (this.active) this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('cache_stat_failed') }))
    }
  }

  private detail(): string {
    if (this.totalBytes >= 1024 * 1024) return (this.totalBytes / (1024 * 1024)).toFixed(1) + ' MB'
    if (this.totalBytes >= 1024) return (this.totalBytes / 1024).toFixed(1) + ' KB'
    return this.totalBytes.toString() + ' B'
  }

  private confirmClear(): void {
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: AppStrings.get(this.titleKey),
      message: AppStrings.format('cache_clear_confirm', AppStrings.get(this.titleKey)),
      primaryButton: { value: AppStrings.get('common_cancel'), action: () => {} },
      secondaryButton: { value: AppStrings.get('common_clear'), action: (): void => { void this.clear() } },
    })
  }

  private async clear(): Promise<void> {
    this.clearing = true
    try {
      if (this.kind === 'cover') {
        await clearCoverImageCache(this.context())
      } else {
        clearSourceIndexIconCache(this.context())
      }
      await this.refresh()
    } catch (_error) {
      if (this.active) this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('cache_clear_failed') }))
    } finally {
      if (this.active) this.clearing = false
    }
  }

  build() {
    ConciseListRow({ title: AppStrings.get(this.titleKey), trailingText: this.detail(),
      showChevron: false, isEnabled: !this.clearing, action: (): void => { this.confirmClear() } })
  }
}

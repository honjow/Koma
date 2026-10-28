import { common } from '@kit.AbilityKit'
import { AppStrings } from '../i18n/AppStrings'
import { ComicTranslationRuntimeService } from '../readerTranslation/services/ComicTranslationRuntimeService'
import { CacheStat } from '../readerTranslation/services/CacheStat'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection } from './ui/GroupedListSection'

/** Generated translation files belong to Storage, separate from service credentials and model assets. */
@ComponentV2
export struct KomaTranslationCacheRow {
  @Local private stat: CacheStat = new CacheStat()
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
      const value = await ComicTranslationRuntimeService.statGeneratedCache(this.context())
      if (this.active) this.stat = value
    } catch (_error) {
      if (this.active) this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('cache_stat_failed') })
    }
  }

  private detail(): string {
    const size = this.stat.bytes >= 1024 * 1024 ? `${(this.stat.bytes / (1024 * 1024)).toFixed(1)} MB` :
      this.stat.bytes >= 1024 ? `${(this.stat.bytes / 1024).toFixed(1)} KB` : `${this.stat.bytes} B`
    return size
  }

  private confirmClear(): void {
    this.getUIContext().showAlertDialog({
      title: AppStrings.get('cache_comic_translation'), message: AppStrings.format('cache_clear_confirm', AppStrings.get('cache_comic_translation')),
      primaryButton: { value: AppStrings.get('common_cancel'), action: () => {} },
      secondaryButton: { value: AppStrings.get('common_clear'), action: () => { void this.clear() } },
    })
  }

  private async clear(): Promise<void> {
    this.clearing = true
    try {
      await ComicTranslationRuntimeService.clearGeneratedCache(this.context())
      await this.refresh()
    } catch (_error) {
      if (this.active) this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('cache_clear_failed') })
    } finally {
      if (this.active) this.clearing = false
    }
  }

  build() {
    GroupedListSection() {
      ConciseListRow({ title: AppStrings.get('cache_comic_translation'), trailingText: this.detail(),
        leadingIcon: $r('sys.symbol.text_bubble_left_2'), showChevron: false, isEnabled: !this.clearing,
        action: () => { this.confirmClear() } })
    }
  }
}

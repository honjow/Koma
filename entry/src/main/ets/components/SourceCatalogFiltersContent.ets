import { komaToastOptions } from '../theme/KomaPopupOptions'
import { AppStrings } from '../i18n/AppStrings'
import { sourceLanguageName } from '../sourceRuntime/SourceLanguagePresentation'
import { SourceCatalogRating } from '../model/SourceCatalogPresentation'
import { SourceCatalogFilterState, appSourceCatalogFilters } from '../state/SourceCatalogFilterState'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'

export function sourceCatalogRatingLabel(rating: SourceCatalogRating): string {
  if (rating === 'all') return AppStrings.get('common_all')
  if (rating === 'safe') return AppStrings.get('source_pkg_rating_all_ages')
  if (rating === 'suggestive') return AppStrings.get('source_pkg_rating_suggestive')
  if (rating === 'adult') return '18+'
  return AppStrings.get('source_pkg_rating_unknown')
}

@ComponentV2
export struct SourceCatalogFiltersContent {
  @Param filters: SourceCatalogFilterState = appSourceCatalogFilters
  @Param languages: string[] = []
  @Event onClose: () => void = () => {}

  private save(languages: string[] | undefined, rating: SourceCatalogRating): void {
    void this.filters.save({ languages, rating }).catch((): void => {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_catalog_filter_save_failed') }))
    })
  }

  private setLanguage(language: string, enabled: boolean): void {
    void this.filters.setLanguage(language, enabled, this.languages).catch((): void => {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_catalog_filter_save_failed') }))
    })
  }

  @Builder
  private RatingMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['all', 'safe', 'suggestive', 'adult', 'unknown'] as SourceCatalogRating[], (rating: SourceCatalogRating) => {
        MenuItem({ content: sourceCatalogRatingLabel(rating) })
          .selected(this.filters.rating === rating)
          .onClick(() => { select(() => { this.save(this.filters.languages, rating) }) })
      }, (rating: SourceCatalogRating) => rating)
    }
  }

  build() {
    KomaModalScaffold({ title: AppStrings.get('common_filter'), onClose: this.onClose,
      contentHorizontalPadding: ThemeConstants.SPACE_MD }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        GroupedListSection() {
          ConciseListRow({ title: AppStrings.get('source_pkg_content_rating'),
            trailingText: sourceCatalogRatingLabel(this.filters.rating), trailingDropdown: true, dropdownMenuEnabled: true,
            dropdownMenuBuilder: (select: (action: () => void) => void) => { this.RatingMenu(select) } })
        }
        GroupedListSection({ title: AppStrings.get('source_catalog_languages') }) {
          ForEach(this.languages, (language: string, index: number) => {
            if (index > 0) { ListDivider() }
            ConciseListRow({ title: sourceLanguageName(language) || AppStrings.get('source_catalog_language_unknown'),
              hasSwitch: true, checked: this.filters.languages === undefined || this.filters.languages.includes(language),
              switchAction: (enabled: boolean): void => { this.setLanguage(language, enabled) } })
          }, (language: string) => language)
        }
      }
      .width('100%')
    }
  }
}

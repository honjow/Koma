import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { RemoteServerStore, KavitaServerRecord } from '../model/RemoteServerStore'
import { KavitaLibraryDto } from '../remote/KavitaModels'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct KavitaBrowsePage {
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private libraries: KavitaLibraryDto[] = []
  @Local private loading: boolean = true
  @Local private errorKey: string = ''
  private record?: KavitaServerRecord

  private store(): RemoteServerStore {
    return new RemoteServerStore(getContext(this) as common.UIAbilityContext)
  }

  aboutToAppear(): void {
    this.loadLibraries()
  }

  private async loadLibraries(): Promise<void> {
    this.loading = true
    this.errorKey = ''
    try {
      const store = this.store()
      const saved = await store.loadKavita()
      if (saved === undefined) {
        this.errorKey = 'kavita_browse_not_configured'
        this.libraries = []
        return
      }
      this.record = saved
      console.info('[Kavita] step=load_libraries_start')
      this.libraries = await store.createKavitaClient(saved).listLibraries()
      console.info(`[Kavita] step=load_libraries_ok libraries=${this.libraries.length}`)
    } catch (error) {
      void error
      this.errorKey = 'kavita_browse_load_failed'
      this.libraries = []
      console.error('[Kavita] step=load_libraries_failed code=kavita_libraries_load_failed')
    } finally {
      this.loading = false
    }
  }

  private libraryTypeText(item: KavitaLibraryDto): string {
    if (item.type === undefined) {
      return s('kavita_library_type_unknown')
    }
    return s('kavita_library_type_value').replace('%s', `${item.type}`)
  }

  @Builder
  private LibraryRow(item: KavitaLibraryDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('K')
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
      }
      .width(ThemeConstants.SOURCE_ICON_SIZE)
      .height(ThemeConstants.SOURCE_ICON_SIZE)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(ThemeConstants.SOURCE_KOMGA_COLOR)

      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(item.name)
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.libraryTypeText(item))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_TERTIARY])
        .opacity(0.35)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private EmptyState() {
    KomaEmptyState({
      title: s(this.errorKey.length > 0 ? this.errorKey : 'kavita_browse_empty_title'),
      message: s(this.errorKey.length > 0 ? 'kavita_browse_error_message' : 'kavita_browse_empty_message'),
      actionLabel: s('common_retry'),
      showAction: this.errorKey.length > 0,
      action: () => {
        this.loadLibraries()
      },
    })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_LG,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        if (this.loading) {
          ListItem() {
            Row() {
              LoadingProgress()
                .width(ThemeConstants.LOADING_SIZE_LARGE)
                .height(ThemeConstants.LOADING_SIZE_LARGE)
                .color(ThemeConstants.BRAND_PRIMARY)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
        } else if (this.libraries.length === 0) {
          ListItem() {
            this.EmptyState()
          }
        } else {
          ForEach(this.libraries, (item: KavitaLibraryDto) => {
            ListItem() {
              this.LibraryRow(item)
            }
          }, (item: KavitaLibraryDto) => `${item.id}`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

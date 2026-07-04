import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaEmptyState } from '../components/ui/KomaEmptyState'
import { RemoteServerStore, KavitaServerRecord } from '../model/RemoteServerStore'
import { KavitaChapterDto, KavitaLibraryDto, KavitaSeriesDto, KavitaVolumeDto } from '../remote/KavitaModels'
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
  @Local private selectedLibrary: KavitaLibraryDto | undefined = undefined
  @Local private selectedSeries: KavitaSeriesDto | undefined = undefined
  @Local private series: KavitaSeriesDto[] = []
  @Local private volumes: KavitaVolumeDto[] = []
  @Local private loading: boolean = true
  @Local private seriesLoading: boolean = false
  @Local private volumesLoading: boolean = false
  @Local private errorKey: string = ''
  @Local private seriesErrorKey: string = ''
  @Local private volumesErrorKey: string = ''
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

  private async openLibrary(item: KavitaLibraryDto): Promise<void> {
    if (this.record === undefined || this.seriesLoading) {
      return
    }
    this.selectedLibrary = item
    this.series = []
    this.seriesErrorKey = ''
    this.seriesLoading = true
    try {
      console.info(`[Kavita] step=load_series_start library=${item.id}`)
      const record = this.record
      if (record === undefined) {
        return
      }
      this.series = await this.store().createKavitaClient(record).listSeries(item.id)
      console.info(`[Kavita] step=load_series_ok library=${item.id} series=${this.series.length}`)
    } catch (error) {
      void error
      this.seriesErrorKey = 'kavita_series_load_failed'
      this.series = []
      console.error('[Kavita] step=load_series_failed code=kavita_series_load_failed')
    } finally {
      this.seriesLoading = false
    }
  }

  private backToLibraries(): void {
    this.selectedLibrary = undefined
    this.selectedSeries = undefined
    this.series = []
    this.volumes = []
    this.seriesErrorKey = ''
    this.volumesErrorKey = ''
  }

  private backToSeries(): void {
    this.selectedSeries = undefined
    this.volumes = []
    this.volumesErrorKey = ''
  }

  private async openSeries(item: KavitaSeriesDto): Promise<void> {
    if (this.record === undefined || this.volumesLoading) {
      return
    }
    this.selectedSeries = item
    this.volumes = []
    this.volumesErrorKey = ''
    this.volumesLoading = true
    try {
      const record = this.record
      if (record === undefined) {
        return
      }
      console.info(`[Kavita] step=load_volumes_start series=${item.id}`)
      this.volumes = await this.store().createKavitaClient(record).listVolumes(item.id)
      console.info(`[Kavita] step=load_volumes_ok series=${item.id} volumes=${this.volumes.length}`)
    } catch (error) {
      void error
      this.volumesErrorKey = 'kavita_volumes_load_failed'
      this.volumes = []
      console.error('[Kavita] step=load_volumes_failed code=kavita_volumes_load_failed')
    } finally {
      this.volumesLoading = false
    }
  }

  private libraryTypeText(item: KavitaLibraryDto): string {
    if (item.type === undefined) {
      return s('kavita_library_type_unknown')
    }
    return s('kavita_library_type_value').replace('%s', `${item.type}`)
  }

  private seriesTitle(item: KavitaSeriesDto): string {
    if (item.localizedName !== undefined && item.localizedName.length > 0) {
      return item.localizedName
    }
    return item.name
  }

  private seriesDetail(item: KavitaSeriesDto): string {
    const pages = item.pages === undefined ? 0 : item.pages
    const read = item.pagesRead === undefined ? 0 : item.pagesRead
    return s('kavita_series_pages_progress').replace('%s', `${read}`).replace('%s', `${pages}`)
  }

  private volumeTitle(item: KavitaVolumeDto): string {
    if (item.name !== undefined && item.name.length > 0) {
      return item.name
    }
    if (item.number !== undefined) {
      return s('kavita_volume_number_title').replace('%s', `${item.number}`)
    }
    return s('kavita_volume_unknown_title')
  }

  private volumeDetail(item: KavitaVolumeDto): string {
    const chapters = item.chapters === undefined ? 0 : item.chapters.length
    const pages = item.pages === undefined ? 0 : item.pages
    return s('kavita_volume_detail').replace('%s', `${chapters}`).replace('%s', `${pages}`)
  }

  private chapterTitle(item: KavitaChapterDto): string {
    if (item.titleName !== undefined && item.titleName.length > 0) {
      return item.titleName
    }
    if (item.title !== undefined && item.title.length > 0) {
      return item.title
    }
    if (item.range !== undefined && item.range.length > 0) {
      return s('kavita_chapter_range_title').replace('%s', item.range)
    }
    return s('kavita_chapter_unknown_title')
  }

  private chapterDetail(item: KavitaChapterDto): string {
    const pages = item.pages === undefined ? 0 : item.pages
    const read = item.pagesRead === undefined ? 0 : item.pagesRead
    return s('kavita_series_pages_progress').replace('%s', `${read}`).replace('%s', `${pages}`)
  }

  @Builder
  private BackRow() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
      Text(s('kavita_action_back_libraries'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.backToLibraries()
    })
  }

  @Builder
  private BackToSeriesRow() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      SymbolGlyph($r('sys.symbol.chevron_left'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
      Text(s('kavita_action_back_series'))
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.backToSeries()
    })
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
    .onClick(() => {
      this.openLibrary(item)
    })
  }

  @Builder
  private SeriesRow(item: KavitaSeriesDto) {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(s('kavita_series_icon'))
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
      }
      .width(ThemeConstants.SOURCE_ICON_SIZE)
      .height(ThemeConstants.SOURCE_ICON_SIZE)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(ThemeConstants.SOURCE_KAVITA_COLOR)

      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(this.seriesTitle(item))
          .fontSize(ThemeConstants.FONT_SIZE_TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.seriesDetail(item))
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.openSeries(item)
    })
  }

  @Builder
  private VolumeRow(item: KavitaVolumeDto) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Stack({ alignContent: Alignment.Center }) {
          Text(s('kavita_volume_icon'))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
        }
        .width(ThemeConstants.SOURCE_ICON_SIZE)
        .height(ThemeConstants.SOURCE_ICON_SIZE)
        .borderRadius(ThemeConstants.RADIUS_ROUND)
        .backgroundColor(ThemeConstants.SOURCE_KAVITA_COLOR)

        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(this.volumeTitle(item))
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.volumeDetail(item))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (item.chapters !== undefined && item.chapters.length > 0) {
        ForEach(item.chapters, (chapter: KavitaChapterDto) => {
          Row({ space: ThemeConstants.SPACE_SM }) {
            Text(this.chapterTitle(chapter))
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.chapterDetail(chapter))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .width('100%')
          .padding({ left: ThemeConstants.SOURCE_ICON_SIZE + ThemeConstants.SPACE_MD, right: 0, top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
        }, (chapter: KavitaChapterDto) => `${chapter.id}`)
      }
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

  @Builder
  private SeriesEmptyState() {
    KomaEmptyState({
      title: s(this.seriesErrorKey.length > 0 ? this.seriesErrorKey : 'kavita_series_empty_title'),
      message: s(this.seriesErrorKey.length > 0 ? 'kavita_browse_error_message' : 'kavita_series_empty_message'),
      actionLabel: s('common_retry'),
      showAction: this.seriesErrorKey.length > 0 && this.selectedLibrary !== undefined,
      action: () => {
        const library = this.selectedLibrary
        if (library !== undefined) {
          this.openLibrary(library)
        }
      },
    })
  }

  @Builder
  private VolumesEmptyState() {
    KomaEmptyState({
      title: s(this.volumesErrorKey.length > 0 ? this.volumesErrorKey : 'kavita_volumes_empty_title'),
      message: s(this.volumesErrorKey.length > 0 ? 'kavita_browse_error_message' : 'kavita_volumes_empty_message'),
      actionLabel: s('common_retry'),
      showAction: this.volumesErrorKey.length > 0 && this.selectedSeries !== undefined,
      action: () => {
        const series = this.selectedSeries
        if (series !== undefined) {
          this.openSeries(series)
        }
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
        if (this.selectedSeries !== undefined) {
          ListItem() {
            this.BackToSeriesRow()
          }
          if (this.volumesLoading) {
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
          } else if (this.volumes.length === 0) {
            ListItem() {
              this.VolumesEmptyState()
            }
          } else {
            ForEach(this.volumes, (item: KavitaVolumeDto) => {
              ListItem() {
                this.VolumeRow(item)
              }
            }, (item: KavitaVolumeDto) => `${item.id}`)
          }
        } else if (this.selectedLibrary !== undefined) {
          ListItem() {
            this.BackRow()
          }
          if (this.seriesLoading) {
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
          } else if (this.series.length === 0) {
            ListItem() {
              this.SeriesEmptyState()
            }
          } else {
            ForEach(this.series, (item: KavitaSeriesDto) => {
              ListItem() {
                this.SeriesRow(item)
              }
            }, (item: KavitaSeriesDto) => `${item.id}`)
          }
        } else if (this.loading) {
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

import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaIconButton } from './ui/KomaIconButton'

@ComponentV2
export struct SourceListItem {
  @Param source: SourceRuntimeRegistryInstalledSourceSummary = {
    sourceId: '',
    displayName: '',
    version: '',
    wasmByteCount: 0,
    importStatus: 'staged',
    networkEnabled: false,
    httpEnabled: false,
    enabled: true,
    language: '',
    nsfw: false,
    status: 'staged',
    capabilities: [],
  }
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr = ''
  @Param badge: ResourceStr = ''
  @Param initial: string = ''
  @Param accentColor: ResourceColor = ThemeConstants.BRAND_PRIMARY
  @Param showSearchButton: boolean = true
  @Param languageBadge: string = 'SRC'
  @Event onActivate: () => void = () => {}
  @Event onSourceTap: (source: SourceRuntimeRegistryInstalledSourceSummary) => void =
    (_source: SourceRuntimeRegistryInstalledSourceSummary) => {}
  @Event onSourceSearch: (source: SourceRuntimeRegistryInstalledSourceSummary) => void =
    (_source: SourceRuntimeRegistryInstalledSourceSummary) => {}

  private sourceBacked(): boolean {
    return this.source.sourceId.trim().length > 0
  }

  private displayTitle(): ResourceStr {
    if (this.title !== '') {
      return this.title
    }
    return this.source.displayName
  }

  private displaySubtitle(): ResourceStr {
    if (this.subtitle !== '') {
      return this.subtitle
    }
    return `v${this.source.version} · ${this.source.importStatus}`
  }

  private displayBadge(): ResourceStr {
    if (this.badge !== '') {
      return this.badge
    }
    return this.languageBadge
  }

  private sourceInitial(): string {
    if (this.initial.length > 0) {
      return this.initial.substring(0, 1).toLocaleUpperCase()
    }
    if (this.source.displayName.length === 0) {
      return 'K'
    }
    return this.source.displayName.substring(0, 1).toLocaleUpperCase()
  }

  private activate(): void {
    if (this.sourceBacked()) {
      this.onSourceTap(this.source)
      return
    }
    this.onActivate()
  }

  build() {
    Row({ space: ThemeConstants.SPACE_MD }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.sourceInitial())
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontWeight(FontWeight.Bold)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
      }
      .width(ThemeConstants.SOURCE_ICON_SIZE)
      .height(ThemeConstants.SOURCE_ICON_SIZE)
      .borderRadius(ThemeConstants.RADIUS_ROUND)
      .backgroundColor(this.accentColor)

      Column({ space: ThemeConstants.SPACE_XS }) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(this.displayTitle())
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.displayBadge())
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .backgroundColor(ThemeConstants.SOFT_TINT)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.displaySubtitle())
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.showSearchButton && this.sourceBacked()) {
        KomaIconButton({
          icon: $r('sys.symbol.magnifyingglass'),
          kind: 'secondary',
          controlSize: ThemeConstants.TOUCH_TARGET_SM,
          iconSize: ThemeConstants.FONT_SIZE_HEADING,
          accentColor: ThemeConstants.BRAND_PRIMARY,
          action: () => {
            this.onSourceSearch(this.source)
          },
        })
      }

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .onClick(() => {
      this.activate()
    })
  }
}

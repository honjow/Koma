import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ConciseListRow } from './ui/ConciseListRow'
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

  private presentationIconUri(): string {
    const icon = this.source.icon?.trim() ?? ''
    // Source icons are optional, user-provided package metadata.  Only render
    // a URI that ArkUI can load directly; do not invent a per-source logo when
    // the package did not provide one.
    if (icon.startsWith('https://') || icon.startsWith('http://') || icon.startsWith('file://')) {
      return icon
    }
    return ''
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
    // Browse is an entry surface, not the package-manager diagnostics screen.
    // A source index description frequently contains implementation jargon
    // (for example “HTML scraping source”) and makes otherwise identical
    // source rows visually noisy. Callers pass the compact, user-actionable
    // version/language summary for installed runtime sources instead.
    if (this.sourceBacked()) {
      return ''
    }
    const description = this.source.description?.trim() ?? ''
    return description
  }

  private displayBadge(): ResourceStr {
    if (this.badge !== '') {
      return this.badge
    }
    return this.languageBadge
  }

  private activate(): void {
    if (this.sourceBacked()) {
      this.onSourceTap(this.source)
      return
    }
    this.onActivate()
  }

  @Builder
  private SourcePrefix() {
    if (this.presentationIconUri().length > 0) {
      Image(this.presentationIconUri())
        .width(40)
        .height(40)
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.Medium)
    }
  }

  @Builder
  private SourceSuffix() {
    Row({ space: ThemeConstants.SPACE_SM }) {
      if (!this.sourceBacked() && this.displayBadge() !== '') {
        Text(this.displayBadge())
          .fontSize(ThemeConstants.FONT_SIZE_TAG)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }

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
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private SourceRowWithIcon() {
    ConciseListRow({
      title: this.displayTitle(),
      subtitle: this.displaySubtitle(),
      subtitleMaxLines: 1,
      showChevron: false,
      action: () => {
        this.activate()
      },
      prefixBuilderParam: () => {
        this.SourcePrefix()
      },
      suffixBuilderParam: () => {
        this.SourceSuffix()
      },
    })
  }

  @Builder
  private SourceRowWithoutIcon() {
    ConciseListRow({
      title: this.displayTitle(),
      subtitle: this.displaySubtitle(),
      subtitleMaxLines: 1,
      showChevron: false,
      action: () => {
        this.activate()
      },
      suffixBuilderParam: () => {
        this.SourceSuffix()
      },
    })
  }

  build() {
    if (this.presentationIconUri().length > 0) {
      this.SourceRowWithIcon()
    } else {
      this.SourceRowWithoutIcon()
    }
  }
}

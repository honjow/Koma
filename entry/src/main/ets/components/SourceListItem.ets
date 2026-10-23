import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ConciseListRow } from './ui/ConciseListRow'

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
    // Installed-source icons are host-created URIs for validated package
    // assets. Do not turn index metadata into an arbitrary network request.
    if (icon.startsWith('file://')) {
      return icon
    }
    return ''
  }

  private displayTitle(): ResourceStr {
    if (this.title !== '') {
      return this.title
    }
    return sourceDisplayName(this.source.sourceId, this.source.displayName)
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
  private SourceRow() {
    ConciseListRow({
      title: this.displayTitle(),
      subtitle: this.displaySubtitle(),
      subtitleMaxLines: 1,
      subtitleContentRating: this.source.nsfw,
      hasSourceIdentityPrefix: true,
      sourceIdentityIconUri: this.presentationIconUri(),
      sourceIdentitySourceId: this.source.sourceId,
      sourceIdentityVersion: this.source.version,
      sourceIdentityFallbackColor: this.accentColor,
      prefixPaddingLeft: ThemeConstants.SPACE_MD,
      prefixPaddingRight: ThemeConstants.SPACE_SM,
      trailingText: this.sourceBacked() ? '' : this.displayBadge(),
      trailingTextFontSize: ThemeConstants.FONT_SIZE_TAG,
      trailingIcon: this.showSearchButton && this.sourceBacked() ? $r('sys.symbol.magnifyingglass') : undefined,
      trailingIconAction: () => { this.onSourceSearch(this.source) },
      showChevron: true,
      action: () => {
        this.activate()
      },
    })
  }

  build() {
    this.SourceRow()
  }
}

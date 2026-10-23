import { ConciseListRow } from './ui/ConciseListRow'
import { InstalledSourcePackage, sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'

// The row observes its own package inputs, rather than the manager's full array.
// Keep the existing HDS-backed row and prefix geometry unchanged.
@ComponentV2
export struct SourcePackageListItem {
  @Require @Param source: InstalledSourcePackage
  @Param subtitle: string = ''
  @Param updateAvailable: boolean = false
  @Param updateLabel: string = ''
  @Param updateEnabled: boolean = true
  @Param remoteNsfw: boolean = false
  @Event onOpen: (source: InstalledSourcePackage) => void = () => {}
  @Event onUpdate: (source: InstalledSourcePackage) => void = () => {}

  build() {
    ConciseListRow({
      title: sourceDisplayName(this.source.id, this.source.name),
      subtitle: this.subtitle,
      showChevron: !this.updateAvailable,
      trailingText: this.updateAvailable ? '' : AppStrings.get(this.source.enabled ? 'source_pkg_enabled' : 'source_pkg_disabled'),
      actionButtonText: this.updateAvailable ? this.updateLabel : '',
      actionButtonEnabled: this.updateEnabled,
      actionButtonAction: () => { this.onUpdate(this.source) },
      hasSourceIdentityPrefix: true,
      sourceIdentityIconUri: this.source.icon,
      sourceIdentitySourceId: this.source.id,
      sourceIdentityVersion: this.source.version,
      sourceIdentityFallbackColor: ThemeConstants.SOURCE_WASM_COLOR,
      prefixPaddingLeft: ThemeConstants.SPACE_MD,
      prefixPaddingRight: ThemeConstants.SPACE_SM,
      primaryColor: ThemeConstants.TEXT_PRIMARY,
      subtitleContentRating: this.source.nsfw || this.remoteNsfw,
      secondaryColor: this.source.enabled ? ThemeConstants.TEXT_SECONDARY : ThemeConstants.TEXT_TERTIARY,
      action: () => { this.onOpen(this.source) },
    })
  }
}

import { komaSheetOptions } from '../theme/KomaPopupOptions'
import { sourceLanguageName } from '../sourceRuntime/SourceLanguagePresentation'
import { SourceSettingsSheetContent as SourceSettingsForm, sourceSettingsDraft } from '../components/SourceSettingsSheetContent'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { compareSourceNames } from '../sourceRuntime/SourceListOrder'
import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { resolveSourceLocalizedName } from '../sourceRuntime/SourceLocalizedNames'
import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaModalScaffold } from '../components/KomaModalScaffold'
import { SourcePackageListItem } from '../components/SourcePackageListItem'
import { ConciseListRow, SourceIdentityIconState } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { RouterHelper } from '../common/RouterHelper'
import { openSourceWebSession } from '../sourceRuntime/SourceWebSessionNavigation'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'
import {
  InstalledSourcePackage,
  appSourceRuntimeRegistry,
  installFromArchive,
  listInstalled,
  getInstalledSourcePackage,
  pickSourcePackageArchive,
  remove,
  runSmokeAsync,
  setEnabled,
} from '../sourceRuntime/SourceRuntimeAppRegistry'
import { runRegisteredSourceRequestByIdAsync } from '../sourceRuntime/SourceRuntimeService'
import {
  SourceSettingDescriptor,
  SourceSettingsRecord,
  appSourceSettingsStore,
  configureSourceSettingsStore,
  fetchSourceSettingDescriptorsAsync,
  loadSourceSettingsDescriptorsAsync,
} from '../sourceRuntime/SourceSettingsStore'
import {
  SourceIndexEntry,
  SourceIndexFetchResult,
  SourceIndexInstallResult,
  SourceIndexRepository,
  SourceIndexService,
  SourcePackageInstallTasks,
  appSourcePackageInstallTasks,
} from '../sourceRuntime/SourceIndexService'
import {
  installedSourceTrustSummary,
  SourcePackageTrustSummary,
  sourceIndexCandidateTrustSummary,
  sourcePackageTrustBoundaryNotice,
} from '../sourceRuntime/SourcePackageTrustPolicy'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

function t(name: string): string {
  return AppStrings.get(name)
}

function tf(name: string, ...args: Array<string | number>): string {
  return AppStrings.format(name, ...args)
}

type SourcePackageUpdateState = 'unknown' | 'checking' | 'latest' | 'update' | 'missing' | 'failed' | 'incomplete'
type SourceSettingsValidationState = 'unknown' | 'running' | 'pass' | 'fail'
type SourceManagerPendingAction = 'none' | 'open_browse' | 'open_search' | 'open_web' | 'confirm_remove'

interface SourcePackageUpdateStatus {
  sourceId: string
  status: SourcePackageUpdateState
  remoteEntry?: SourceIndexEntry
  remoteIndexUrl?: string
  remoteVersion?: string
  localVersion?: string
  reasonCode?: string
}

interface SourcePackageUpdateCandidate {
  entry: SourceIndexEntry
  indexUrl: string
}

interface SourcePackageListGroups {
  updates: SourcePackageUpdateCandidate[]
  missing: SourceIndexEntry[]
  installed: InstalledSourcePackage[]
}

interface SourceSettingsValidationStatus {
  sourceId: string
  status: SourceSettingsValidationState
  savedCount: number
  reasonCode?: string
}

interface SourceSettingsValidationArgs {}

interface SourceSettingsValidationHostHints {
  network: boolean
}

interface SourceSettingsValidationRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceSettingsValidationArgs
  settings: SourceSettingsRecord
  hostHints: SourceSettingsValidationHostHints
}

interface SourceDetailsContentParams {
  source: InstalledSourcePackage
}

interface SourceDiagnosticsSettingCounts {
  total: number
  editable: number
  sensitive: number
  saved: number
}

@ComponentV2
export struct SourcePackageManagerPage {
  @Param initialSettingsSourceId: string = ''
  @Event onSettingsSaved: () => void = () => {}
  private settingsRouteActive: boolean = false
  @Local private packages: InstalledSourcePackage[] = []
  @Local private busy: boolean = false
  @Local private statusText: string = ''
  @Local private settingsSourceId: string = ''
  @Local private settingsSourceName: string = ''
  @Local private settingDescriptors: SourceSettingDescriptor[] = []
  @Local private settingDraft: SourceSettingsRecord = {}
  @Local private sourceIndexUrl: string = ''
  @Local private sourceIndexRepositories: SourceIndexRepository[] = []
  @Local private sourceIndexFailures: Record<string, string> = {}
  @Local private indexEntries: SourceIndexEntry[] = []
  @Local private indexIconStates: Record<string, SourceIdentityIconState> = {}
  @Local private indexFetchBusy: boolean = false
  @Local private indexInstallBusy: boolean = false
  @Local private packageInstallTasks: SourcePackageInstallTasks = appSourcePackageInstallTasks
  @Local private indexStatusText: string = ''
  @Local private packageUpdateStatuses: SourcePackageUpdateStatus[] = []
  @Local private updateCheckBusy: boolean = false
  @Local private updateInstallSourceId: string = ''
  @Local private settingsAvailability: Record<string, string> = {}
  @Local private settingsValidationStatuses: SourceSettingsValidationStatus[] = []
  @Local private settingsValidationSourceId: string = ''
  @Local private savedSettingCounts: Record<string, number> = {}
  @Local private savedSettingsReadFailed: boolean = false
  @Local private sourceSheetShown: boolean = false
  @Local private sourceSheetSourceId: string = ''
  @Local private sourceSheetRetainedSource: InstalledSourcePackage | undefined = undefined
  @Local private sourceSettingsSheetShown: boolean = false
  @Local private settingsDescriptorSnapshot: Record<string, SourceSettingDescriptor[]> = {}
  private settingsReloadRevision: number = 0
  private settingsSourceReloads: Record<string, number> = {}
  private savedIndexLoadRevision: number = 0
  private indexLoadRevision: number = 0
  private indexDisplayRevision: number = 0
  private displayedIndexUrl: string = ''
  @Local private sourceIndexSheetShown: boolean = false
  @Local private pendingSourceSheetAction: SourceManagerPendingAction = 'none'
  @Local private pendingSourceSheetSourceId: string = ''
  @Local private languageState: LanguageState = connectLanguageState()
  private sourceIndexService: SourceIndexService = new SourceIndexService(this.context())

  aboutToAppear(): void {
    configureSourceSettingsStore(this.context())
    this.reload()
    this.loadSavedIndexUrl()
    this.settingsRouteActive = true
    if (this.initialSettingsSourceId.length > 0) void this.openRequestedSourceSettings()
  }

  private async openRequestedSourceSettings(): Promise<void> {
    const source = this.installedPackage(this.initialSettingsSourceId)
    if (source === undefined) return
    try {
      const result = await loadSourceSettingsDescriptorsAsync(appSourceRuntimeRegistry, source.id)
      if (!this.settingsRouteActive) return
      if (!result.ready) throw new Error('source_settings_unavailable')
      if (result.descriptors.length === 0) return
      this.openSettings(source, result.descriptors)
      this.sourceSettingsSheetShown = true
    } catch (_error) {
      this.showToast(t('source_pkg_reason_settings_validation_failed'))
    }
  }

  aboutToDisappear(): void {
    this.settingsRouteActive = false
    this.indexLoadRevision += 1
    this.indexDisplayRevision += 1
    this.savedIndexLoadRevision += 1
    this.settingsReloadRevision += 1
  }

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private sortedIndexEntries(entries: SourceIndexEntry[]): SourceIndexEntry[] {
    return entries.slice().sort((left: SourceIndexEntry, right: SourceIndexEntry): number =>
      compareSourceNames(
        resolveSourceLocalizedName(left.name, left.localizedNames, this.languageState.effectiveLocale), left.id,
        resolveSourceLocalizedName(right.name, right.localizedNames, this.languageState.effectiveLocale), right.id))
  }

  private setSourceIndexUrl(value: string): void {
    if (value === this.sourceIndexUrl) return
    this.savedIndexLoadRevision += 1
    this.indexLoadRevision += 1
    this.indexDisplayRevision += 1
    this.sourceIndexUrl = value
    this.indexFetchBusy = false
    this.indexEntries = []
    this.indexIconStates = {}
    this.displayedIndexUrl = ''
    this.indexStatusText = ''
  }

  private showIndexEntries(indexUrl: string, entries: SourceIndexEntry[], revision: number): void {
    if (revision !== this.indexLoadRevision) return
    // Refresh the same repository without taking displayed artwork away.
    // A changed package still loads its versioned icon and replaces the old URI
    // only when that replacement is ready. Switching repositories clears it.
    const previous = this.indexIconStates ?? {}
    const sameRepository = this.displayedIndexUrl === indexUrl
    const icons: Record<string, SourceIdentityIconState> = {}
    entries.forEach((entry: SourceIndexEntry): void => {
      icons[entry.id] = (sameRepository ? previous[entry.id] : undefined) ?? new SourceIdentityIconState()
    })
    if (!sameRepository || Object.keys(previous).length !== entries.length ||
      entries.some((entry: SourceIndexEntry): boolean => previous[entry.id] !== icons[entry.id])) {
      this.indexIconStates = icons
    }
    this.displayedIndexUrl = indexUrl
    this.indexEntries = this.sortedIndexEntries(entries)
    this.indexStatusText = tf('source_pkg_index_loaded', entries.length)
    const iconRevision = ++this.indexDisplayRevision
    void this.sourceIndexService.loadIndexIcons(indexUrl, entries, (ready: SourceIndexEntry): void => {
      if (iconRevision !== this.indexDisplayRevision) return
      if (!this.indexEntries.some((entry: SourceIndexEntry): boolean =>
        entry.id === ready.id && entry.version === ready.version && entry.icon === ready.icon)) return
      // Keep media observation inside the prefix; do not update the HDS text row.
      const icon = this.indexIconStates[ready.id]
      if (icon !== undefined) icon.uri = ready.iconUri ?? ''
    }, (): boolean => iconRevision === this.indexDisplayRevision).catch((_error: Error): void => {
      DiagnosticLogger.warn('source_package_manager_page', 'icons_incomplete', 'Index entries remain available')
    })
  }

  private reload(): void {
    const locale = this.languageState.effectiveLocale
    this.packages = listInstalled().slice().sort((left: InstalledSourcePackage, right: InstalledSourcePackage): number =>
      compareSourceNames(resolveSourceLocalizedName(left.name, left.localizedNames, locale), left.id,
        resolveSourceLocalizedName(right.name, right.localizedNames, locale), right.id))
    this.refreshSavedSettingsCounts()
    const sheetSource = this.sourceSheetSource()
    if (sheetSource !== undefined) {
      this.sourceSheetRetainedSource = sheetSource
    }
    const revision = ++this.settingsReloadRevision
    const packages = this.packages.slice()
    const validationStatuses: SourceSettingsValidationStatus[] = []
    this.packages.forEach((source: InstalledSourcePackage) => {
      const existing = this.settingsValidationStatuses.find((status: SourceSettingsValidationStatus): boolean => status.sourceId === source.id)
      if (existing !== undefined) {
        validationStatuses.push(existing)
      } else {
        validationStatuses.push({
          sourceId: source.id,
          status: 'unknown',
          savedCount: this.savedSettingsCount(source.id),
        })
      }
    })
    this.settingsValidationStatuses = validationStatuses
    void this.reloadSettingsDescriptors(packages, revision)
  }

  private settingsAvailabilityText(descriptors: SourceSettingDescriptor[]): string {
    if (descriptors.length === 0) return t('source_pkg_settings_none')
    const editable = descriptors.filter((descriptor: SourceSettingDescriptor): boolean => descriptor.supported && !descriptor.sensitive).length
    return tf('source_pkg_settings_editable', editable, descriptors.length)
  }

  private async reloadSettingsDescriptors(packages: InstalledSourcePackage[], revision: number): Promise<void> {
    const sourceRevisions: Record<string, number> = {}
    packages.forEach((source: InstalledSourcePackage): void => {
      sourceRevisions[source.id] = this.settingsSourceReloads[source.id] ?? 0
    })
    const loaded: Record<string, SourceSettingDescriptor[]> = {}
    for (const source of packages) {
      const result = await loadSourceSettingsDescriptorsAsync(appSourceRuntimeRegistry, source.id)
      if (revision !== this.settingsReloadRevision) return
      if (result.ready) loaded[source.id] = result.descriptors
    }
    const snapshot: Record<string, SourceSettingDescriptor[]> = {}
    const availability: Record<string, string> = {}
    this.packages.forEach((source: InstalledSourcePackage): void => {
      // An install may complete while the initial page load is still in flight.
      // Never overwrite that source's newer schema with the old load's result.
      const unchanged = packages.includes(source) &&
        sourceRevisions[source.id] === (this.settingsSourceReloads[source.id] ?? 0)
      const descriptors = (unchanged ? loaded[source.id] : undefined) ?? this.settingsDescriptorSnapshot[source.id]
      if (descriptors !== undefined) {
        snapshot[source.id] = descriptors
        availability[source.id] = this.settingsAvailabilityText(descriptors)
      }
    })
    this.settingsDescriptorSnapshot = snapshot
    this.settingsAvailability = availability
  }

  private refreshInstalledPackage(sourceId: string): void {
    const projectionStartedAt = Date.now()
    const source = getInstalledSourcePackage(sourceId)
    if (source === undefined) return
    // Preserve every unaffected row's input identity; only this package changed.
    const packages = this.packages.filter((item: InstalledSourcePackage): boolean => item.id !== sourceId)
    packages.push(source)
    // These DTOs already carry the registry names. Read the page's locale once;
    // connecting global state again inside every comparison adds work per row.
    const locale = this.languageState.effectiveLocale
    // CPU224 also sampled localized-name validation inside sort comparisons.
    // Resolve once for this refresh only; keep the original comparator and DTO
    // identities. Do not retain this map across locale or package changes.
    const displayNames = new Map<string, string>()
    packages.forEach((item: InstalledSourcePackage): void => {
      displayNames.set(item.id, resolveSourceLocalizedName(item.name, item.localizedNames, locale))
    })
    this.packages = packages.sort((left: InstalledSourcePackage, right: InstalledSourcePackage): number =>
      compareSourceNames(displayNames.get(left.id) ?? left.name, left.id,
        displayNames.get(right.id) ?? right.name, right.id))
    if (this.sourceSheetSourceId === sourceId) this.sourceSheetRetainedSource = source
    try {
      const count = Object.keys(appSourceSettingsStore.loadForSource(sourceId)).length
      const counts: Record<string, number> = {}
      Object.keys(this.savedSettingCounts).forEach((id: string): void => { counts[id] = this.savedSettingCounts[id] })
      counts[sourceId] = count
      this.savedSettingCounts = counts
      if (!this.settingsValidationStatuses.some((item: SourceSettingsValidationStatus): boolean => item.sourceId === sourceId)) {
        const status: SourceSettingsValidationStatus = { sourceId, status: 'unknown', savedCount: count }
        this.settingsValidationStatuses = this.settingsValidationStatuses.concat(status)
      }
    } catch (_error) {
      this.savedSettingsReadFailed = true
    }
    const sourceRevision = (this.settingsSourceReloads[sourceId] ?? 0) + 1
    this.settingsSourceReloads[sourceId] = sourceRevision
    this.publishSourceSettings(sourceId)
    void this.reloadInstalledPackageSettings(source, this.settingsReloadRevision, sourceRevision)
    DiagnosticLogger.info('source_package', 'row_projection', 'durationMs=' +
      Math.max(0, Date.now() - projectionStartedAt) + ' packageCount=' + this.packages.length)
  }

  private async reloadInstalledPackageSettings(source: InstalledSourcePackage, revision: number, sourceRevision: number): Promise<void> {
    const result = await loadSourceSettingsDescriptorsAsync(appSourceRuntimeRegistry, source.id)
    if (revision !== this.settingsReloadRevision || sourceRevision !== this.settingsSourceReloads[source.id] ||
      this.installedPackage(source.id) !== source || !result.ready) return
    this.publishSourceSettings(source.id, result.descriptors)
  }

  private publishSourceSettings(sourceId: string, descriptors?: SourceSettingDescriptor[]): void {
    const snapshot: Record<string, SourceSettingDescriptor[]> = {}
    const availability: Record<string, string> = {}
    Object.keys(this.settingsDescriptorSnapshot).forEach((id: string): void => {
      if (id !== sourceId) snapshot[id] = this.settingsDescriptorSnapshot[id]
    })
    Object.keys(this.settingsAvailability).forEach((id: string): void => {
      if (id !== sourceId) availability[id] = this.settingsAvailability[id]
    })
    if (descriptors !== undefined) {
      snapshot[sourceId] = descriptors
      availability[sourceId] = this.settingsAvailabilityText(descriptors)
    }
    this.settingsDescriptorSnapshot = snapshot
    this.settingsAvailability = availability
  }

  private async loadSavedIndexUrl(): Promise<void> {
    const revision = ++this.savedIndexLoadRevision
    const previousUrl = this.sourceIndexUrl
    try {
      const saved = await this.sourceIndexService.loadSavedUrl()
      const repositories = await this.sourceIndexService.loadSavedRepositories()
      if (revision !== this.savedIndexLoadRevision) return
      if (saved.length > 0 && this.sourceIndexUrl === previousUrl) this.setSourceIndexUrl(saved)
      this.sourceIndexRepositories = repositories
      // A direct source-settings route is not an index-browsing request.
      if (this.initialSettingsSourceId.length > 0) return
      const url = this.sourceIndexUrl.trim()
      if (url.length === 0) return
      const savedRevision = this.savedIndexLoadRevision
      const indexRevision = ++this.indexLoadRevision
      const cached = await this.sourceIndexService.loadCachedIndex(url)
      if (savedRevision !== this.savedIndexLoadRevision || indexRevision !== this.indexLoadRevision ||
        url !== this.sourceIndexUrl.trim()) return
      if (cached !== undefined) this.showIndexEntries(url, cached, indexRevision)
      // Existing metadata/artwork remains usable while the network revalidates.
      void this.checkInstalledUpdates()
    } catch (_error) {
      if (revision !== this.savedIndexLoadRevision) return
      this.indexStatusText = tf('source_pkg_index_load_failed', this.sourceReasonText('unknown'))
    }
  }

  private indexDisplayName(entry: SourceIndexEntry): string {
    return resolveSourceLocalizedName(entry.name, entry.localizedNames, this.languageState.effectiveLocale)
  }

  private installedSourceIds(): string[] {
    return this.packages.map((pkg: InstalledSourcePackage): string => pkg.id)
  }

  @Computed
  private get installedPackagesById(): Map<string, InstalledSourcePackage> {
    const installed: Map<string, InstalledSourcePackage> = new Map()
    this.packages.forEach((source: InstalledSourcePackage): void => {
      if (!installed.has(source.id)) installed.set(source.id, source)
    })
    return installed
  }

  private installedPackage(entryId: string): InstalledSourcePackage | undefined {
    return this.installedPackagesById.get(entryId)
  }

  private sourceSummary(source: InstalledSourcePackage): SourceRuntimeRegistryInstalledSourceSummary {
    const current = appSourceRuntimeRegistry.listInstalledSourceSummaries()
      .find((item: SourceRuntimeRegistryInstalledSourceSummary): boolean => item.sourceId === source.id)
    if (current !== undefined) return current
    const importStatus = source.status === 'staged' ? 'staged' : 'imported'
    return {
      sourceId: source.id,
      displayName: source.name,
      localizedNames: source.localizedNames,
      version: source.version,
      wasmByteCount: 0,
      importStatus,
      networkEnabled: false,
      httpEnabled: false,
      enabled: source.enabled,
      language: source.lang,
      nsfw: source.nsfw,
      status: importStatus,
      capabilities: source.capabilities,
      icon: source.icon,
    }
  }

  private sourceSupportsSearch(source: InstalledSourcePackage): boolean {
    return source.capabilities.includes('search')
  }

  private openSourceBrowse(source: InstalledSourcePackage): void {
    if (!source.enabled) {
      return
    }
    RouterHelper.pushSourceBrowse({ source: this.sourceSummary(source) })
  }

  private openSourceSearch(source: InstalledSourcePackage): void {
    if (!source.enabled || !this.sourceSupportsSearch(source)) {
      return
    }
    RouterHelper.pushSourceSearch({ source: this.sourceSummary(source) })
  }

  private sourceSheetSource(): InstalledSourcePackage | undefined {
    return this.packages.find((source: InstalledSourcePackage): boolean => source.id === this.sourceSheetSourceId)
  }

  private openSourceSheet(source: InstalledSourcePackage): void {
    this.pendingSourceSheetAction = 'none'
    this.pendingSourceSheetSourceId = ''
    this.sourceSheetRetainedSource = source
    this.sourceSheetSourceId = source.id
    this.sourceSheetShown = true
  }

  private openIndexSheet(): void {
    this.sourceIndexSheetShown = true
  }

  private requestSourceSheetDismiss(action: SourceManagerPendingAction = 'none', source?: InstalledSourcePackage): void {
    this.pendingSourceSheetAction = action
    this.pendingSourceSheetSourceId = source?.id ?? ''
    this.sourceSheetShown = false
  }

  private finishSourceSheetDismissal(): void {
    const action = this.pendingSourceSheetAction
    const sourceId = this.pendingSourceSheetSourceId
    this.sourceSheetShown = false
    this.pendingSourceSheetAction = 'none'
    this.pendingSourceSheetSourceId = ''
    this.sourceSheetSourceId = ''
    const source = this.packages.find((item: InstalledSourcePackage): boolean => item.id === sourceId)
    if (action === 'open_browse' && source !== undefined) {
      this.openSourceBrowse(source)
    } else if (action === 'open_search' && source !== undefined) {
      this.openSourceSearch(source)
    } else if (action === 'open_web' && source !== undefined) {
      if (!openSourceWebSession(source.id, sourceDisplayName(source.id, source.name), () => { this.reload() })) {
        this.showToast(t('source_web_not_allowed'))
      }
    } else if (action === 'confirm_remove' && source !== undefined) {
      this.confirmRemovePackage(source)
    }
  }

  private openSourceBrowseFromSheet(source: InstalledSourcePackage): void {
    this.requestSourceSheetDismiss('open_browse', source)
  }

  private openSourceSearchFromSheet(source: InstalledSourcePackage): void {
    this.requestSourceSheetDismiss('open_search', source)
  }

  private async openSourceSettingsFromSheet(source: InstalledSourcePackage): Promise<void> {
    try {
      const result = await loadSourceSettingsDescriptorsAsync(appSourceRuntimeRegistry, source.id)
      if (!this.sourceSheetShown || this.sourceSheetSourceId !== source.id) return
      if (!result.ready) throw new Error('source_settings_unavailable')
      if (result.descriptors.length === 0) {
        const snapshot: Record<string, SourceSettingDescriptor[]> = {}
        Object.keys(this.settingsDescriptorSnapshot).forEach((id: string): void => {
          snapshot[id] = this.settingsDescriptorSnapshot[id]
        })
        snapshot[source.id] = []
        this.settingsDescriptorSnapshot = snapshot
        return
      }
      this.openSettings(source, result.descriptors)
      this.pendingSourceSheetAction = 'none'
      this.pendingSourceSheetSourceId = ''
      this.sourceSettingsSheetShown = true
    } catch (_error) {
      this.savedSettingsReadFailed = true
      this.statusText = t('source_pkg_reason_settings_validation_failed')
      this.showToast(this.statusText)
    }
  }

  private closeSourceSettingsSheet(): void {
    this.sourceSettingsSheetShown = false
  }

  private finishSourceSettingsSheetDismissal(): void {
    this.sourceSettingsSheetShown = false
    this.closeSettings()
    if (this.settingsRouteActive && this.initialSettingsSourceId.length > 0) RouterHelper.pop()
  }

  private finishSourceIndexSheetDismissal(): void {
    this.sourceIndexSheetShown = false
  }

  private sourceDetailsSheetOptions(): SheetOptions {
    return {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false,
      enableOutsideInteractive: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      enableFloatingDragBar: true,
      onDisappear: () => {
        this.finishSourceSheetDismissal()
      },
    }
  }

  private sourceSettingsSheetOptions(): SheetOptions {
    return {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false,
      enableOutsideInteractive: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      enableFloatingDragBar: true,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
      onDisappear: () => {
        this.finishSourceSettingsSheetDismissal()
      },
    }
  }

  private sourceIndexSheetOptions(): SheetOptions {
    return {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false,
      enableOutsideInteractive: false,
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      enableFloatingDragBar: true,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
      onDisappear: () => {
        this.finishSourceIndexSheetDismissal()
      },
    }
  }


  private isSourceInstalled(entryId: string): boolean {
    return this.installedSourceIds().indexOf(entryId) >= 0
  }

  private compareVersion(left: string, right: string): number {
    const leftParts = left.split('.')
    const rightParts = right.split('.')
    const count = Math.max(leftParts.length, rightParts.length)
    for (let index = 0; index < count; index += 1) {
      const leftValue = Number.parseInt(leftParts[index] ?? '0')
      const rightValue = Number.parseInt(rightParts[index] ?? '0')
      if (Number.isNaN(leftValue) || Number.isNaN(rightValue)) {
        return left === right ? 0 : left.localeCompare(right)
      }
      if (leftValue !== rightValue) {
        return leftValue > rightValue ? 1 : -1
      }
    }
    return 0
  }

  private entryDeclaresPackageIcon(entry: SourceIndexEntry): boolean {
    return entry.icon.trim().length > 0
  }

  private needsPackageIdentityIconRepair(source: InstalledSourcePackage, entry: SourceIndexEntry): boolean {
    return this.entryDeclaresPackageIcon(entry) && (source.icon?.trim().length ?? 0) === 0
  }

  private updateAvailableFor(source: InstalledSourcePackage, entry: SourceIndexEntry): boolean {
    return this.compareVersion(entry.version, source.version) > 0 || this.needsPackageIdentityIconRepair(source, entry)
  }

  private hasUpdate(entry: SourceIndexEntry): boolean {
    const installed = this.installedPackage(entry.id)
    if (installed === undefined || entry.version.length === 0 || installed.version.length === 0) {
      return false
    }
    return this.updateAvailableFor(installed, entry)
  }

  // Keep the shared filters outside each row's parameter evaluation. Otherwise
  // a count label subscribes to every nested package read in the cross-list scan.
  @Computed
  private get missingIndexPackages(): SourceIndexEntry[] {
    return this.indexEntries.filter((entry: SourceIndexEntry): boolean => this.installedPackage(entry.id) === undefined)
  }

  @Computed
  private get updatableIndexPackages(): SourceIndexEntry[] {
    return this.indexEntries.filter((entry: SourceIndexEntry): boolean => this.hasUpdate(entry))
  }

  private missingIndexEntries(): SourceIndexEntry[] {
    return this.missingIndexPackages
  }

  private updatableIndexEntries(): SourceIndexEntry[] {
    return this.updatableIndexPackages
  }

  private availablePackageUpdates(): SourcePackageUpdateCandidate[] {
    const candidates: SourcePackageUpdateCandidate[] = []
    this.updatableIndexEntries().forEach((entry: SourceIndexEntry): void => {
      candidates.push({ entry, indexUrl: this.sourceIndexUrl.trim() })
    })
    this.packageUpdateStatuses.forEach((status: SourcePackageUpdateStatus): void => {
      const entry = status.remoteEntry
      const installed = this.installedPackage(status.sourceId)
      if (status.status !== 'update' || entry === undefined || installed === undefined ||
        status.remoteIndexUrl === undefined || !this.updateAvailableFor(installed, entry)) return
      const index = candidates.findIndex((candidate: SourcePackageUpdateCandidate): boolean => candidate.entry.id === entry.id)
      const candidate: SourcePackageUpdateCandidate = { entry, indexUrl: status.remoteIndexUrl }
      if (index < 0) candidates.push(candidate)
      else if (this.compareVersion(entry.version, candidates[index].entry.version) > 0 ||
        (this.compareVersion(entry.version, candidates[index].entry.version) === 0 &&
          this.entryDeclaresPackageIcon(entry) && !this.entryDeclaresPackageIcon(candidates[index].entry))) {
        candidates[index] = candidate
      }
    })
    return candidates.sort((left: SourcePackageUpdateCandidate, right: SourcePackageUpdateCandidate): number =>
      compareSourceNames(this.indexDisplayName(left.entry), left.entry.id, this.indexDisplayName(right.entry), right.entry.id))
  }

  private packageListGroups(): SourcePackageListGroups {
    const updates = this.availablePackageUpdates()
    const updating = updates.map((candidate: SourcePackageUpdateCandidate): string => candidate.entry.id)
    return { updates, missing: this.missingIndexEntries(),
      installed: this.packages.filter((source: InstalledSourcePackage): boolean => !updating.includes(source.id)) }
  }

  @Computed
  private get listGroups(): SourcePackageListGroups {
    return this.packageListGroups()
  }

  // Position belongs to the live group projection, never to row identity.
  // These primitive computed values update the divider without remounting its row.
  @Computed
  private get lastUpdateSourceId(): string {
    const rows = this.listGroups.updates
    return rows.length > 0 ? rows[rows.length - 1].entry.id : ''
  }

  @Computed
  private get lastMissingSourceId(): string {
    const rows = this.listGroups.missing
    return rows.length > 0 ? rows[rows.length - 1].id : ''
  }

  @Computed
  private get lastInstalledSourceId(): string {
    const rows = this.listGroups.installed
    return rows.length > 0 ? rows[rows.length - 1].id : ''
  }

  private checkedUpdateStatuses(): SourcePackageUpdateStatus[] {
    return this.packageUpdateStatuses.filter((status: SourcePackageUpdateStatus): boolean => {
      return status.status === 'update' && status.remoteEntry !== undefined && status.remoteIndexUrl !== undefined &&
        this.installedPackage(status.sourceId) !== undefined
    })
  }

  private sourceIndexBatchBusy(): boolean {
    return this.indexInstallBusy || this.indexFetchBusy || this.busy || this.updateCheckBusy ||
      this.packageInstallTasks.pendingIds.length > 0 || this.updateInstallSourceId.length > 0
  }

  private packageActivityText(): string {
    const runningId = this.packageInstallTasks.runningId
    if (runningId.length > 0) {
      const installed = this.installedPackage(runningId)
      if (installed !== undefined) {
        return tf('source_pkg_update_running', sourceDisplayName(installed.id, installed.name))
      }
      const entry = this.indexEntries.find((item: SourceIndexEntry): boolean => item.id === runningId)
      if (entry !== undefined) return tf('source_pkg_install_running', this.indexDisplayName(entry))
    }
    return this.statusText.length > 0 ? this.statusText : t('source_pkg_manual_check_notice')
  }

  private sourceIndexSummaryText(): string {
    const url = this.sourceIndexUrl.trim()
    return url.length > 0 ? url : t('source_pkg_boundary_notice')
  }

  private updateStatus(sourceId: string): SourcePackageUpdateStatus {
    const status = this.packageUpdateStatuses.find((item: SourcePackageUpdateStatus): boolean => item.sourceId === sourceId)
    if (status !== undefined) {
      return status
    }
    return { sourceId, status: 'unknown' }
  }

  private refreshDiagnostics(source: InstalledSourcePackage): void {
    console.info('[SourceRuntimeDiagnostics] step=refresh id=' + source.id)
    this.reload()
  }

  private setUpdateStatus(nextStatus: SourcePackageUpdateStatus): void {
    const next: SourcePackageUpdateStatus[] = []
    let replaced = false
    this.packageUpdateStatuses.forEach((item: SourcePackageUpdateStatus) => {
      if (item.sourceId === nextStatus.sourceId) {
        next.push(nextStatus)
        replaced = true
      } else {
        next.push(item)
      }
    })
    if (!replaced) {
      next.push(nextStatus)
    }
    this.packageUpdateStatuses = next
  }

  private clearUpdateStatus(sourceId: string): void {
    this.packageUpdateStatuses = this.packageUpdateStatuses.filter((item: SourcePackageUpdateStatus): boolean => item.sourceId !== sourceId)
  }

  private refreshSavedSettingsCounts(): void {
    try {
      const saved = appSourceSettingsStore.exportAll()
      const counts: Record<string, number> = {}
      Object.keys(saved).forEach((sourceId: string) => {
        counts[sourceId] = Object.keys(saved[sourceId]).length
      })
      this.savedSettingCounts = counts
      this.savedSettingsReadFailed = false
    } catch (_error) {
      // Keep file IO out of Builders and never present a failed read as zero.
      this.savedSettingsReadFailed = true
    }
  }

  private savedSettingsCount(sourceId: string): number {
    return this.savedSettingCounts[sourceId] ?? 0
  }

  private diagnosticsSettingCounts(sourceId: string): SourceDiagnosticsSettingCounts {
    const descriptors = this.settingsDescriptorSnapshot[sourceId] ?? []
    const counts: SourceDiagnosticsSettingCounts = {
      total: descriptors.length,
      editable: descriptors.filter((descriptor: SourceSettingDescriptor): boolean => descriptor.supported && !descriptor.sensitive).length,
      sensitive: descriptors.filter((descriptor: SourceSettingDescriptor): boolean => descriptor.sensitive).length,
      saved: this.savedSettingsCount(sourceId),
    }
    return counts
  }

  private settingsValidationStatus(sourceId: string): SourceSettingsValidationStatus {
    const status = this.settingsValidationStatuses.find((item: SourceSettingsValidationStatus): boolean => item.sourceId === sourceId)
    if (status !== undefined) {
      return status
    }
    return {
      sourceId,
      status: 'unknown',
      savedCount: this.savedSettingsCount(sourceId),
    }
  }

  private setSettingsValidationStatus(nextStatus: SourceSettingsValidationStatus): void {
    const next: SourceSettingsValidationStatus[] = []
    let replaced = false
    this.settingsValidationStatuses.forEach((item: SourceSettingsValidationStatus) => {
      if (item.sourceId === nextStatus.sourceId) {
        next.push(nextStatus)
        replaced = true
      } else {
        next.push(item)
      }
    })
    if (!replaced) {
      next.push(nextStatus)
    }
    this.settingsValidationStatuses = next
  }

  private clearSettingsValidationStatus(sourceId: string): void {
    this.settingsValidationStatuses = this.settingsValidationStatuses.filter((item: SourceSettingsValidationStatus): boolean => item.sourceId !== sourceId)
  }

  private updateStatusText(source: InstalledSourcePackage): string {
    const status = this.updateStatus(source.id)
    switch (status.status) {
      case 'checking':
        return t('source_pkg_update_status_checking')
      case 'latest':
        return tf('source_pkg_update_status_latest', status.localVersion ?? source.version)
      case 'update':
        return tf('source_pkg_update_status_available', status.localVersion ?? source.version, status.remoteVersion ?? '')
      case 'missing':
        return t('source_pkg_update_status_missing')
      case 'incomplete':
        return t('source_pkg_update_status_incomplete')
      case 'failed':
        return tf('source_pkg_update_status_failed', this.sourceRedactedReasonText(status.reasonCode))
      case 'unknown':
      default:
        return t('source_pkg_update_status_unknown')
    }
  }

  private updateStatusColor(source: InstalledSourcePackage): ResourceColor {
    const status = this.updateStatus(source.id)
    switch (status.status) {
      case 'update':
        return $r('app.color.koma_accent')
      case 'failed':
        return $r('app.color.koma_danger')
      case 'checking':
      case 'latest':
      case 'missing':
      case 'unknown':
      default:
        return $r('app.color.koma_text_secondary')
    }
  }

  private packageInstallPending(sourceId: string): boolean {
    return this.packageInstallTasks.stateFor(sourceId).phase !== 'idle'
  }

  private packageActionLabel(sourceId: string, update: boolean): string {
    // Aggregate queue fields belong to the activity summary. A row observes
    // only its stable per-source projection, so another install cannot dirty it.
    const phase = this.packageInstallTasks.stateFor(sourceId).phase
    if (phase !== 'idle') {
      return phase === 'running'
        ? t(update ? 'source_pkg_action_updating' : 'source_pkg_installing') : t('source_pkg_action_queued')
    }
    return t(update ? 'source_pkg_action_update' : 'source_pkg_install')
  }

  // This is a trigger, not a second batch-state owner. Each source registers
  // its own pending/running state through the same single-package action.
  private updateAllAvailablePackages(): void {
    if (this.busy) return
    this.availablePackageUpdates().forEach((candidate: SourcePackageUpdateCandidate): void => {
      const source = this.installedPackage(candidate.entry.id)
      if (source !== undefined) void this.updateInstalledPackage(source, candidate)
    })
  }

  private updateActionLabel(sourceId: string): string {
    return this.packageActionLabel(sourceId, true)
  }

  private updateEntry(sourceId: string): SourceIndexEntry | undefined {
    const status = this.updateStatus(sourceId)
    return status.status === 'update' ? status.remoteEntry : undefined
  }

  private updateIndexUrl(sourceId: string): string {
    const status = this.updateStatus(sourceId)
    return status.status === 'update' && status.remoteIndexUrl !== undefined ? status.remoteIndexUrl : ''
  }

  private sourceIndexUrlsForUpdate(activeUrl: string): string[] {
    const urls: string[] = []
    const normalizedActiveUrl = activeUrl.trim()
    if (normalizedActiveUrl.length > 0) {
      urls.push(normalizedActiveUrl)
    }
    this.sourceIndexRepositories.forEach((repository: SourceIndexRepository) => {
      const repositoryUrl = repository.url.trim()
      if (repositoryUrl.length > 0 && urls.indexOf(repositoryUrl) < 0) {
        urls.push(repositoryUrl)
      }
    })
    return urls
  }

  private sourceIndexFailureReason(error: Object): string {
    return (error as Error)?.message?.startsWith('source_index_preferences_') ? 'unknown' : 'network_error'
  }

  private setSavedIndexFailure(indexUrl: string, reason?: string): void {
    if (this.sourceIndexFailures[indexUrl] === reason) return
    const next: Record<string, string> = {}
    Object.keys(this.sourceIndexFailures).forEach((key: string): void => {
      if (key !== indexUrl) next[key] = this.sourceIndexFailures[key]
    })
    if (reason !== undefined) next[indexUrl] = reason
    this.sourceIndexFailures = next
  }

  private savedIndexSubtitle(repository: SourceIndexRepository): string {
    const current = repository.url === this.sourceIndexUrl.trim() ? t('source_pkg_current_index') : ''
    const reason = this.sourceIndexFailures[repository.url]
    if (reason === undefined) return current
    const failure = tf('source_pkg_check_failed', this.sourceRedactedReasonText(reason))
    return current.length > 0 ? current + ' · ' + failure : failure
  }

  private async currentIndexUrlOrPrompt(): Promise<string> {
    let url = this.sourceIndexUrl.trim()
    if (url.length === 0) {
      try {
        const saved = await this.sourceIndexService.loadSavedUrl()
        if (saved.length > 0) {
          this.setSourceIndexUrl(saved)
          url = saved
        }
      } catch (_error) {
        this.indexStatusText = tf('source_pkg_index_load_failed', this.sourceReasonText('unknown'))
        this.statusText = this.indexStatusText
        this.showToast(this.indexStatusText)
        return ''
      }
    }
    if (url.length === 0) {
      this.statusText = t('source_pkg_prompt_index_url')
      this.indexStatusText = t('source_pkg_prompt_index_url')
      this.showToast(t('source_pkg_prompt_index_url'))
    }
    return url
  }

  private async checkInstalledUpdates(): Promise<void> {
    this.savedIndexLoadRevision += 1
    if (this.updateCheckBusy || this.indexFetchBusy) {
      return
    }
    const url = await this.currentIndexUrlOrPrompt()
    if (url.length === 0) {
      return
    }
    const revision = ++this.indexLoadRevision
    const count = this.packages.length
    console.info('[SourcePackageUpdate] step=check_start count=' + count)
    this.updateCheckBusy = true
    this.statusText = t('source_pkg_check_updates_running')
    // The summary owns the in-flight indicator. Keep the last known per-source
    // results (and their groups) until this check has a replacement result.
    try {
      await this.sourceIndexService.saveUrl(url)
      const repositories = await this.sourceIndexService.loadSavedRepositories()
      if (revision !== this.indexLoadRevision) return
      this.sourceIndexRepositories = repositories
      const updateIndexUrls = this.sourceIndexUrlsForUpdate(url)
      const candidates: Record<string, SourcePackageUpdateCandidate> = {}
      const indexFailures: Record<string, string> = {}
      let loadedIndexCount = 0
      let failedIndexCount = 0
      let firstFailureReason = 'network_error'
      for (let index = 0; index < updateIndexUrls.length; index += 1) {
        const indexUrl = updateIndexUrls[index]
        const result: SourceIndexFetchResult = await this.sourceIndexService.fetchIndex(indexUrl)
        if (revision !== this.indexLoadRevision) return
        if (!result.ok) {
          failedIndexCount += 1
          firstFailureReason = result.reasonCode ?? firstFailureReason
          indexFailures[indexUrl] = result.reasonCode ?? 'network_error'
          continue
        }
        loadedIndexCount += 1
        if (indexUrl === url || this.indexEntries.length === 0) {
          this.showIndexEntries(indexUrl, result.entries, revision)
        }
        result.entries.forEach((entry: SourceIndexEntry) => {
          const existing = candidates[entry.id]
        if (existing === undefined || this.compareVersion(entry.version, existing.entry.version) > 0 ||
          (this.compareVersion(entry.version, existing.entry.version) === 0 && this.entryDeclaresPackageIcon(entry) &&
            !this.entryDeclaresPackageIcon(existing.entry))) {
            candidates[entry.id] = {
              entry,
              indexUrl,
            }
          }
        })
      }
      if (loadedIndexCount === 0) {
        this.sourceIndexFailures = {}
        this.packageUpdateStatuses = this.packages.map((source: InstalledSourcePackage): SourcePackageUpdateStatus => {
          return {
            sourceId: source.id,
            status: 'failed',
            localVersion: source.version,
            reasonCode: firstFailureReason,
          }
        })
        this.statusText = tf('source_pkg_check_failed', this.sourceRedactedReasonText(firstFailureReason))
        console.info('[SourcePackageUpdate] step=check_done update=0 latest=0 missing=0 failed=' + count)
        return
      }

      let updateCount = 0
      let latestCount = 0
      let missingCount = 0
      const nextStatuses: SourcePackageUpdateStatus[] = []
      const retainedUpdates: Record<string, SourcePackageUpdateCandidate> = {}
      if (failedIndexCount > 0) {
        this.checkedUpdateStatuses().forEach((status: SourcePackageUpdateStatus): void => {
          retainedUpdates[status.sourceId] = {
            entry: status.remoteEntry as SourceIndexEntry,
            indexUrl: status.remoteIndexUrl as string,
          }
        })
      }
      this.packages.forEach((source: InstalledSourcePackage) => {
        let candidate = candidates[source.id]
        const retained = retainedUpdates[source.id]
        if (retained !== undefined && this.updateAvailableFor(source, retained.entry) &&
          (candidate === undefined || this.compareVersion(retained.entry.version, candidate.entry.version) > 0)) {
          candidate = retained
        }
        const entry = candidate?.entry
        if (entry !== undefined && entry.version.length > 0 && source.version.length > 0 &&
          this.updateAvailableFor(source, entry)) {
          updateCount += 1
          nextStatuses.push({
            sourceId: source.id,
            status: 'update',
            remoteEntry: entry,
            remoteIndexUrl: candidate?.indexUrl,
            remoteVersion: entry.version,
            localVersion: source.version,
          })
          return
        }
        // A failed repository may contain a newer version or the missing ID.
        // The adopted partial-check contract retains positive updates only;
        // it cannot establish either negative conclusion across all indexes.
        if (failedIndexCount > 0) {
          nextStatuses.push({ sourceId: source.id, status: 'incomplete', localVersion: source.version })
          return
        }
        if (entry === undefined) {
          missingCount += 1
          nextStatuses.push({ sourceId: source.id, status: 'missing', localVersion: source.version })
          return
        }
        latestCount += 1
        nextStatuses.push({
          sourceId: source.id,
          status: 'latest',
          remoteEntry: entry,
          remoteIndexUrl: candidate?.indexUrl,
          remoteVersion: entry.version,
          localVersion: source.version,
        })
      })
      this.packageUpdateStatuses = nextStatuses
      this.sourceIndexFailures = failedIndexCount > 0 ? indexFailures : {}
      this.statusText = failedIndexCount > 0
        ? tf('source_pkg_check_incomplete', updateCount)
        : tf('source_pkg_check_complete', updateCount, latestCount, missingCount)
      console.info('[SourcePackageUpdate] step=check_done update=' + updateCount + ' latest=' + latestCount + ' missing=' + missingCount +
        ' failed_indexes=' + failedIndexCount)
    } catch (_error) {
      if (revision !== this.indexLoadRevision) return
      this.sourceIndexFailures = {}
      this.packageUpdateStatuses = this.packages.map((source: InstalledSourcePackage): SourcePackageUpdateStatus => {
        return {
          sourceId: source.id,
          status: 'failed',
          localVersion: source.version,
          reasonCode: this.sourceIndexFailureReason(_error),
        }
      })
      this.statusText = tf('source_pkg_check_failed', this.sourceRedactedReasonText(this.sourceIndexFailureReason(_error)))
      console.info('[SourcePackageUpdate] step=check_done update=0 latest=0 missing=0 failed=' + count)
    } finally {
      this.updateCheckBusy = false
    }
  }

  private async updateInstalledPackage(source: InstalledSourcePackage, candidate?: SourcePackageUpdateCandidate): Promise<void> {
    if (this.packageInstallPending(source.id) || this.busy) {
      return
    }
    const entry = candidate?.entry ?? this.updateEntry(source.id)
    if (entry === undefined) {
      return
    }
    let url = candidate?.indexUrl ?? this.updateIndexUrl(source.id)
    if (url.length === 0) {
      url = await this.currentIndexUrlOrPrompt()
    }
    if (url.length === 0) {
      return
    }
    const wasEnabled = source.enabled
    console.info('[SourcePackageUpdate] step=install_requested id=' + source.id)
    try {
      const result: SourceIndexInstallResult = await this.sourceIndexService.installPackage(url, entry)
      if (result.ok) {
        if (!wasEnabled) {
          setEnabled(this.context(), source.id, false)
        }
        this.refreshInstalledPackage(source.id)
        const installed = this.installedPackage(source.id)
        this.setUpdateStatus({
          sourceId: source.id,
          status: 'latest',
          remoteEntry: entry,
          remoteIndexUrl: url,
          remoteVersion: entry.version,
          localVersion: installed?.version ?? entry.version,
        })
        this.statusText = tf('source_pkg_update_done', sourceDisplayName(source.id, source.name))
        this.showToast(t('source_pkg_toast_updated'))
        console.info('[SourcePackageUpdate] step=install_done id=' + source.id)
      } else {
        this.setUpdateStatus({
          sourceId: source.id,
          status: 'failed',
          remoteEntry: entry,
          remoteIndexUrl: url,
          remoteVersion: entry.version,
          localVersion: source.version,
          reasonCode: result.reasonCode,
        })
        this.statusText = tf('source_pkg_update_failed', this.sourceRedactedReasonText(result.reasonCode))
        this.showToast(t('source_pkg_toast_install_failed'))
        DiagnosticLogger.error('source_package_manager_page', 'install_failed', '[SourcePackageUpdate] step=install_failed id=' + source.id + ' reason=' + (result.reasonCode ?? 'unknown'))
      }
    } catch (_error) {
      this.setUpdateStatus({
        sourceId: source.id,
        status: 'failed',
        remoteEntry: entry,
        remoteIndexUrl: url,
        remoteVersion: entry.version,
        localVersion: source.version,
        reasonCode: 'network_error',
      })
      this.statusText = tf('source_pkg_update_failed', this.sourceRedactedReasonText('network_error'))
      this.showToast(t('source_pkg_toast_install_failed'))
      DiagnosticLogger.error('source_package_manager_page', 'install_failed', '[SourcePackageUpdate] step=install_failed id=' + source.id + ' reason=' + this.sourceIndexFailureReason(_error))
    }
  }

  private indexVersionText(entry: SourceIndexEntry): string {
    const installed = this.installedPackage(entry.id)
    if (installed === undefined || this.compareVersion(installed.version, entry.version) === 0) {
      return 'v' + entry.version
    }
    return tf('source_pkg_index_version_installed', installed.version, entry.version)
  }

  private sourceReasonText(reasonCode: string | undefined): string {
    const code = reasonCode ?? 'unknown'
    switch (code) {
      case 'invalid_url':
        return t('source_pkg_reason_invalid_url')
      case 'network_error':
        return t('source_pkg_reason_network_error')
      case 'http_error':
        return t('source_pkg_reason_http_error')
      case 'invalid_index_format':
        return t('source_pkg_reason_invalid_index_format')
      case 'invalid_json':
        return t('source_pkg_reason_invalid_json')
      case 'invalid_pkg_url':
        return t('source_pkg_reason_invalid_pkg_url')
      case 'app_version_unsupported':
        return t('source_pkg_reason_app_version_unsupported')
      case 'invalid_response':
        return t('source_pkg_reason_invalid_response')
      case 'empty_package':
        return t('source_pkg_reason_empty_package')
      case 'checksum_mismatch':
        return t('source_pkg_reason_checksum_mismatch')
      case 'network_not_allowed':
        return t('source_pkg_reason_network_not_allowed')
      case 'unsafe_archive_entry':
        return t('source_pkg_reason_unsafe_archive_entry')
      case 'missing_icon':
        return t('source_pkg_reason_missing_icon')
      case 'invalid_icon':
        return t('source_pkg_reason_invalid_icon')
      case 'missing_manifest':
        return t('source_pkg_reason_missing_manifest')
      case 'missing_wasm':
        return t('source_pkg_reason_missing_wasm')
      case 'manifest_invalid':
        return t('source_pkg_reason_manifest_invalid')
      case 'validation_failed':
        return t('source_pkg_reason_validation_failed')
      case 'register_failed':
        return t('source_pkg_reason_register_failed')
      case 'import_failed':
        return t('source_pkg_reason_import_failed')
      case 'duplicate_source_id':
        return t('source_pkg_reason_duplicate_source_id')
      case 'missing_source_id':
        return t('source_pkg_reason_missing_source_id')
      case 'source_id_not_registered':
        return t('source_pkg_reason_source_id_not_registered')
      case 'source_disabled':
        return t('source_pkg_reason_source_disabled')
      case 'source_id_mismatch':
        return t('source_pkg_reason_source_id_mismatch')
      case 'malformed_json':
        return t('source_pkg_reason_malformed_json')
      case 'missing_or_invalid_operation':
        return t('source_pkg_reason_missing_or_invalid_operation')
      case 'request_too_large':
        return t('source_pkg_reason_request_too_large')
      case 'result_too_large':
        return t('source_pkg_reason_result_too_large')
      case 'malformed_result':
        return t('source_pkg_reason_malformed_result')
      case 'cancelled':
        return t('source_pkg_reason_cancelled')
      case 'timeout':
        return t('source_pkg_reason_timeout')
      case 'smoke_failed':
        return t('source_pkg_reason_smoke_failed')
      case 'missing_response':
        return t('source_pkg_reason_missing_response')
      case 'runtime_response_not_ok':
        return t('source_pkg_reason_runtime_response_not_ok')
      case 'settings_validation_failed':
        return t('source_pkg_reason_settings_validation_failed')
      case 'ok':
        return t('source_pkg_reason_ok')
      case 'unknown':
        return t('source_pkg_reason_unknown')
      default:
        return tf('source_pkg_reason_code', code)
    }
  }

  private sourceRedactedReasonText(reasonCode: string | undefined): string {
    const code = reasonCode ?? 'unknown'
    switch (code) {
      case 'invalid_url':
      case 'network_error':
      case 'http_error':
      case 'invalid_index_format':
      case 'invalid_json':
      case 'invalid_pkg_url':
      case 'app_version_unsupported':
      case 'invalid_response':
      case 'empty_package':
      case 'checksum_mismatch':
      case 'network_not_allowed':
      case 'unsafe_archive_entry':
      case 'invalid_icon':
      case 'missing_manifest':
      case 'missing_wasm':
      case 'manifest_invalid':
      case 'validation_failed':
      case 'register_failed':
      case 'import_failed':
      case 'duplicate_source_id':
      case 'missing_source_id':
      case 'source_id_not_registered':
      case 'source_id_mismatch':
      case 'malformed_json':
      case 'missing_or_invalid_operation':
      case 'request_too_large':
      case 'result_too_large':
      case 'malformed_result':
      case 'cancelled':
      case 'timeout':
      case 'smoke_failed':
      case 'missing_response':
      case 'runtime_response_not_ok':
      case 'settings_validation_failed':
      case 'ok':
      case 'unknown':
        return this.sourceReasonText(code)
      default:
        return t('source_pkg_reason_redacted')
    }
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message })
    } catch (_err) {
    }
  }

  private async importPackage(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    this.statusText = t('source_pkg_import_running')
    try {
      const uri = await pickSourcePackageArchive(this.context())
      if (uri === undefined) {
        this.statusText = ''
        return
      }
      const result = await installFromArchive(this.context(), uri)
      if (result.ok) {
        this.statusText = t('source_pkg_import_done')
        this.showToast(t('source_pkg_toast_imported'))
        // A successful archive import changes one package, just like an index install.
        if (result.id !== undefined) this.refreshInstalledPackage(result.id)
        else this.reload()
      } else {
        this.statusText = tf('source_pkg_import_failed', this.sourceReasonText(result.reasonCode))
        this.showToast(t('source_pkg_toast_validation_failed'))
        this.reload()
      }
    } catch (_error) {
      this.statusText = tf('source_pkg_import_failed', this.sourceReasonText('import_failed'))
      this.showToast(t('source_pkg_toast_import_failed'))
      this.reload()
    } finally {
      this.busy = false
    }
  }

  private async fetchIndex(): Promise<void> {
    this.savedIndexLoadRevision += 1
    if (this.indexFetchBusy) {
      return
    }
    const url = this.sourceIndexUrl.trim()
    if (url.length === 0) {
      this.indexStatusText = t('source_pkg_prompt_index_url')
      return
    }
    const revision = ++this.indexLoadRevision
    this.indexFetchBusy = true
    this.indexStatusText = t('source_pkg_index_loading')
    try {
      await this.sourceIndexService.saveUrl(url)
      const repositories = await this.sourceIndexService.loadSavedRepositories()
      if (revision !== this.indexLoadRevision) return
      this.sourceIndexRepositories = repositories
      const result: SourceIndexFetchResult = await this.sourceIndexService.fetchIndex(url)
      if (revision !== this.indexLoadRevision) return
      if (result.ok) {
        this.setSavedIndexFailure(url)
        this.showIndexEntries(url, result.entries, revision)
      } else {
        if (this.sourceIndexFailures[url] !== undefined) {
          this.setSavedIndexFailure(url, result.reasonCode ?? 'network_error')
        }
        this.indexStatusText = tf('source_pkg_index_load_failed', this.sourceReasonText(result.reasonCode))
      }
    } catch (_error) {
      if (revision !== this.indexLoadRevision) return
      if (this.sourceIndexFailures[url] !== undefined) {
        this.setSavedIndexFailure(url, this.sourceIndexFailureReason(_error))
      }
      this.indexStatusText = tf('source_pkg_index_load_failed', this.sourceReasonText(this.sourceIndexFailureReason(_error)))
    } finally {
      if (revision === this.indexLoadRevision) this.indexFetchBusy = false
    }
  }

  private selectSavedIndex(repository: SourceIndexRepository): void {
    this.setSourceIndexUrl(repository.url)
    void this.fetchIndex()
  }

  private removeSavedIndex(repository: SourceIndexRepository): void {
    this.savedIndexLoadRevision += 1
    void this.sourceIndexService.removeSavedRepository(repository.url)
      .then((repositories: SourceIndexRepository[]) => {
        this.setSavedIndexFailure(repository.url)
        this.sourceIndexRepositories = repositories
        if (this.sourceIndexUrl.trim() === repository.url && repositories.length > 0) {
          this.setSourceIndexUrl(repositories[0].url)
        }
        if (repositories.length === 0 && this.sourceIndexUrl.trim() === repository.url) {
          this.setSourceIndexUrl('')
        }
      })
      .catch((_error: Error) => {
        this.showToast(t('source_pkg_saved_index_remove_failed'))
      })
  }

  private async installIndexEntry(entry: SourceIndexEntry, replaceExisting: boolean = false): Promise<void> {
    if (this.packageInstallPending(entry.id) || this.busy) {
      return
    }
    const existing = this.installedPackage(entry.id)
    if (existing !== undefined && !replaceExisting) {
      this.showToast(t('source_pkg_toast_already_installed'))
      return
    }
    this.indexStatusText = replaceExisting ? tf('source_pkg_update_running', this.indexDisplayName(entry)) : tf('source_pkg_install_running', this.indexDisplayName(entry))
    try {
      const result: SourceIndexInstallResult = await this.sourceIndexService.installPackage(
        this.sourceIndexUrl.trim(),
        entry,
      )
      if (result.ok) {
        if (existing !== undefined && !existing.enabled) {
          setEnabled(this.context(), existing.id, false)
        }
        this.indexStatusText = replaceExisting ? tf('source_pkg_update_done', this.indexDisplayName(entry)) : tf('source_pkg_install_done', this.indexDisplayName(entry))
        this.showToast(replaceExisting ? t('source_pkg_toast_updated') : t('source_pkg_toast_install_success'))
        this.refreshInstalledPackage(entry.id)
      } else {
        this.indexStatusText = replaceExisting
          ? tf('source_pkg_update_failed', this.sourceReasonText(result.reasonCode))
          : tf('source_pkg_install_failed', this.sourceReasonText(result.reasonCode))
        this.showToast(t('source_pkg_toast_install_failed'))
      }
    } catch (_error) {
      this.indexStatusText = replaceExisting
        ? tf('source_pkg_update_failed', this.sourceReasonText('network_error'))
        : tf('source_pkg_install_failed', this.sourceReasonText('network_error'))
      this.showToast(t('source_pkg_toast_install_failed'))
    }
  }

  private async installIndexEntryBatch(entries: SourceIndexEntry[], replaceExisting: boolean): Promise<void> {
    this.savedIndexLoadRevision += 1
    if (this.sourceIndexBatchBusy()) {
      return
    }
    const url = this.sourceIndexUrl.trim()
    if (url.length === 0) {
      this.indexStatusText = t('source_pkg_prompt_index_url')
      this.showToast(t('source_pkg_prompt_index_url'))
      return
    }
    if (entries.length === 0) {
      this.showToast(replaceExisting ? t('source_pkg_batch_no_updates') : t('source_pkg_batch_no_missing'))
      return
    }
    this.indexInstallBusy = true
    let successCount = 0
    let failedCount = 0
    let skippedCount = 0
    this.indexStatusText = replaceExisting
      ? tf('source_pkg_batch_update_running', entries.length)
      : tf('source_pkg_batch_install_running', entries.length)
    console.info('[SourcePackageBatch] step=start mode=' + (replaceExisting ? 'update' : 'install') + ' count=' + entries.length)
    try {
      await this.sourceIndexService.saveUrl(url)
      for (let index = 0; index < entries.length; index += 1) {
        const entry = entries[index]
        const existing = this.installedPackage(entry.id)
        if (existing !== undefined && !replaceExisting) {
          skippedCount += 1
          continue
        }
        if (replaceExisting && (existing === undefined || !this.updateAvailableFor(existing, entry))) {
          skippedCount += 1
          continue
        }
        this.indexStatusText = replaceExisting
          ? tf('source_pkg_batch_update_progress', index + 1, entries.length)
          : tf('source_pkg_batch_install_progress', index + 1, entries.length)
        const result: SourceIndexInstallResult = await this.sourceIndexService.installPackage(url, entry)
        if (result.ok) {
          successCount += 1
          if (existing !== undefined && !existing.enabled) {
            setEnabled(this.context(), existing.id, false)
          }
          if (replaceExisting) {
            this.setUpdateStatus({
              sourceId: entry.id,
              status: 'latest',
              remoteEntry: entry,
              remoteIndexUrl: url,
              remoteVersion: entry.version,
              localVersion: entry.version,
            })
          }
        } else {
          failedCount += 1
          if (replaceExisting) {
            this.setUpdateStatus({
              sourceId: entry.id,
              status: 'failed',
              remoteEntry: entry,
              remoteIndexUrl: url,
              remoteVersion: entry.version,
              localVersion: existing?.version ?? '',
              reasonCode: result.reasonCode,
            })
          }
        }
        this.reload()
      }
      this.indexStatusText = replaceExisting
        ? tf('source_pkg_batch_update_done', successCount, failedCount, skippedCount)
        : tf('source_pkg_batch_install_done', successCount, failedCount, skippedCount)
      this.showToast(replaceExisting ? t('source_pkg_batch_update_toast') : t('source_pkg_batch_install_toast'))
      console.info('[SourcePackageBatch] step=done mode=' + (replaceExisting ? 'update' : 'install') +
        ' success=' + successCount + ' failed=' + failedCount + ' skipped=' + skippedCount)
    } catch (_error) {
      this.indexStatusText = replaceExisting
        ? tf('source_pkg_batch_update_failed', this.sourceReasonText(this.sourceIndexFailureReason(_error)))
        : tf('source_pkg_batch_install_failed', this.sourceReasonText(this.sourceIndexFailureReason(_error)))
      this.showToast(t('source_pkg_toast_install_failed'))
      DiagnosticLogger.error('source_package_manager_page', 'failed', '[SourcePackageBatch] step=failed mode=' + (replaceExisting ? 'update' : 'install') + ' reason=network_error')
    } finally {
      this.reload()
      this.indexInstallBusy = false
    }
  }

  private installMissingIndexEntries(): void {
    void this.installIndexEntryBatch(this.missingIndexEntries(), false)
  }

  private updateUpdatableIndexEntries(): void {
    void this.installIndexEntryBatch(this.updatableIndexEntries(), true)
  }

  private async updateCheckedPackages(): Promise<void> {
    if (this.sourceIndexBatchBusy()) {
      return
    }
    const statuses = this.checkedUpdateStatuses()
    if (statuses.length === 0) {
      this.showToast(t('source_pkg_batch_no_updates'))
      return
    }
    this.indexInstallBusy = true
    this.updateInstallSourceId = '__batch__'
    let successCount = 0
    let failedCount = 0
    let skippedCount = 0
    this.statusText = tf('source_pkg_batch_update_running', statuses.length)
    console.info('[SourcePackageUpdateBatch] step=start count=' + statuses.length)
    try {
      for (let index = 0; index < statuses.length; index += 1) {
        const status = statuses[index]
        const entry = status.remoteEntry
        const url = status.remoteIndexUrl ?? ''
        const source = this.installedPackage(status.sourceId)
        if (entry === undefined || url.length === 0 || source === undefined || !this.updateAvailableFor(source, entry)) {
          skippedCount += 1
          continue
        }
        this.statusText = tf('source_pkg_batch_update_progress', index + 1, statuses.length)
        const wasEnabled = source.enabled
        const result: SourceIndexInstallResult = await this.sourceIndexService.installPackage(url, entry)
        if (result.ok) {
          successCount += 1
          if (!wasEnabled) {
            setEnabled(this.context(), source.id, false)
          }
          this.reload()
          const installed = this.installedPackage(status.sourceId)
          this.setUpdateStatus({
            sourceId: status.sourceId,
            status: 'latest',
            remoteEntry: entry,
            remoteIndexUrl: url,
            remoteVersion: entry.version,
            localVersion: installed?.version ?? entry.version,
          })
        } else {
          failedCount += 1
          this.setUpdateStatus({
            sourceId: status.sourceId,
            status: 'failed',
            remoteEntry: entry,
            remoteIndexUrl: url,
            remoteVersion: entry.version,
            localVersion: source.version,
            reasonCode: result.reasonCode,
          })
        }
      }
      this.statusText = tf('source_pkg_batch_update_done', successCount, failedCount, skippedCount)
      this.showToast(t('source_pkg_batch_update_toast'))
      console.info('[SourcePackageUpdateBatch] step=done success=' + successCount + ' failed=' + failedCount + ' skipped=' + skippedCount)
    } catch (_error) {
      this.statusText = tf('source_pkg_batch_update_failed', this.sourceReasonText('network_error'))
      this.showToast(t('source_pkg_toast_install_failed'))
      DiagnosticLogger.error('source_package_manager_page', 'failed', '[SourcePackageUpdateBatch] step=failed reason=network_error')
    } finally {
      this.reload()
      this.updateInstallSourceId = ''
      this.indexInstallBusy = false
    }
  }

  private togglePackage(id: string): void {
    const source = this.packages.find((item: InstalledSourcePackage): boolean => item.id === id)
    if (source === undefined) {
      this.statusText = t('source_pkg_unavailable')
      return
    }
    const enabled = !source.enabled
    if (setEnabled(this.context(), source.id, enabled)) {
      this.statusText = enabled ? t('source_pkg_enabled') : t('source_pkg_disabled')
      this.reload()
    } else {
      this.statusText = t('source_pkg_unavailable')
    }
  }

  private async removePackage(source: InstalledSourcePackage): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      const removed = await remove(this.context(), source.id)
      this.statusText = removed ? t('source_pkg_removed') : t('source_pkg_unavailable')
      if (removed) {
        this.clearUpdateStatus(source.id)
        this.clearSettingsValidationStatus(source.id)
      }
      this.reload()
    } catch (_error) {
      this.statusText = tf('source_pkg_remove_failed', this.sourceReasonText('unknown'))
    } finally {
      this.busy = false
    }
  }

  private confirmRemovePackage(source: InstalledSourcePackage): void {
    if (this.busy) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: t('source_pkg_remove_title'),
      message: tf('source_pkg_remove_message', sourceDisplayName(source.id, source.name)),
      autoCancel: true,
      primaryButton: {
        value: t('source_pkg_delete'),
        fontColor: ThemeConstants.DANGER,
        action: () => {
          void this.removePackage(source)
        },
      },
      secondaryButton: {
        value: t('common_cancel'),
        action: () => {},
      },
    })
  }

  private async smokePackage(source: InstalledSourcePackage): Promise<void> {
    const result = await runSmokeAsync(source.id)
    if (result.ok) {
      this.statusText = t('source_pkg_smoke_pass')
      this.showToast(t('source_pkg_smoke_pass'))
    } else {
      this.statusText = tf('source_pkg_smoke_fail', this.sourceReasonText(result.reasonCode))
      this.showToast(t('source_pkg_smoke_fail_toast'))
    }
    this.reload()
  }

  private validateSettingsActionLabel(sourceId: string): string {
    return this.settingsValidationSourceId === sourceId ? t('source_pkg_settings_validation_running') : t('source_pkg_settings_validation_action')
  }

  private settingsValidationText(source: InstalledSourcePackage): string {
    if (this.savedSettingsReadFailed) return t('source_pkg_reason_settings_validation_failed')
    const status = this.settingsValidationStatus(source.id)
    const savedText = tf('source_pkg_settings_saved_count', status.savedCount)
    switch (status.status) {
      case 'running':
        return t('source_pkg_settings_validation_status_running') + savedText
      case 'pass':
        return t('source_pkg_settings_validation_status_pass') + savedText
      case 'fail':
        return tf('source_pkg_settings_validation_status_fail', this.sourceReasonText(status.reasonCode)) + savedText
      case 'unknown':
      default:
        return t('source_pkg_settings_validation_status_unknown') + savedText
    }
  }

  private async validateSettings(source: InstalledSourcePackage): Promise<void> {
    if (this.settingsValidationSourceId.length > 0) {
      return
    }
    let savedCount = this.savedSettingsCount(source.id)
    let settingsLoaded = false
    try {
      const savedSettings = appSourceSettingsStore.loadForSource(source.id)
      savedCount = Object.keys(savedSettings).length
      settingsLoaded = true
      this.savedSettingsReadFailed = false
      console.info('[SourceSettingsValidation] step=start id=' + source.id + ' saved=' + savedCount)
      this.settingsValidationSourceId = source.id
      this.setSettingsValidationStatus({
        sourceId: source.id,
        status: 'running',
        savedCount,
      })
      const args: SourceSettingsValidationArgs = {}
      const hostHints: SourceSettingsValidationHostHints = { network: false }
      const request: SourceSettingsValidationRequest = {
        type: 'request',
        version: 1,
        requestId: 'settings-validation-' + source.id + '-' + Date.now().toString(),
        operation: 'get_settings',
        sourceId: source.id,
        args,
        settings: savedSettings,
        hostHints,
      }
      const result = await runRegisteredSourceRequestByIdAsync(appSourceRuntimeRegistry, source.id, JSON.stringify(request))
      if (result.response !== undefined && result.response.ok === true) {
        this.setSettingsValidationStatus({
          sourceId: source.id,
          status: 'pass',
          savedCount,
        })
        this.statusText = t('source_pkg_settings_validation_toast_pass')
        this.showToast(t('source_pkg_settings_validation_toast_pass'))
        console.info('[SourceSettingsValidation] step=done id=' + source.id + ' ok=true saved=' + savedCount)
        return
      }
      const reason = result.reasonCode ?? result.response?.reasonCode ?? (result.response === undefined ? 'missing_response' : 'runtime_response_not_ok')
      this.setSettingsValidationStatus({
        sourceId: source.id,
        status: 'fail',
        savedCount,
        reasonCode: reason,
      })
      this.statusText = tf('source_pkg_settings_validation_failed', this.sourceReasonText(reason))
      this.showToast(t('source_pkg_settings_validation_toast_fail'))
      DiagnosticLogger.error('source_package_manager_page', 'done', '[SourceSettingsValidation] step=done id=' + source.id + ' ok=false reason=' + reason + ' saved=' + savedCount)
    } catch (_error) {
      if (!settingsLoaded) this.savedSettingsReadFailed = true
      const reason = 'settings_validation_failed'
      this.setSettingsValidationStatus({
        sourceId: source.id,
        status: 'fail',
        savedCount,
        reasonCode: reason,
      })
      this.statusText = tf('source_pkg_settings_validation_failed', this.sourceReasonText(reason))
      this.showToast(t('source_pkg_settings_validation_toast_fail'))
      DiagnosticLogger.error('source_package_manager_page', 'done', '[SourceSettingsValidation] step=done id=' + source.id + ' ok=false reason=' + reason + ' saved=' + savedCount)
    } finally {
      this.settingsValidationSourceId = ''
    }
  }

  private openSettings(source: InstalledSourcePackage, descriptors: SourceSettingDescriptor[]): void {
    const saved = appSourceSettingsStore.loadForSource(source.id)
    this.savedSettingsReadFailed = false
    this.settingsSourceId = source.id
    this.settingsSourceName = source.name
    this.settingDescriptors = descriptors
    this.settingDraft = sourceSettingsDraft(descriptors, saved)
  }

  private closeSettings(): void {
    this.settingsSourceId = ''
    this.settingsSourceName = ''
    this.settingDescriptors = []
    this.settingDraft = {}
  }

  private sourceSettingsSaved(cleared: boolean): void {
    this.setSettingsValidationStatus({
      sourceId: this.settingsSourceId,
      status: 'unknown',
      savedCount: this.savedSettingsCount(this.settingsSourceId),
    })
    this.reload()
    this.statusText = t(cleared ? 'source_pkg_settings_cleared' : 'source_pkg_settings_saved')
    this.onSettingsSaved()
  }

  private capabilityLabel(capability: string): string {
    if (capability.startsWith('hostImports:')) {
      return tf('source_pkg_capability_host_imports', capability.replace('hostImports:', ''))
    }
    switch (capability) {
      case 'search':
        return t('source_pkg_capability_search')
      case 'detail':
        return t('source_pkg_capability_detail')
      case 'chapters':
        return t('source_pkg_capability_chapters')
      case 'pages':
        return t('source_pkg_capability_pages')
      case 'sourceInfo':
        return t('source_pkg_capability_source_info')
      case 'listings':
        return t('source_pkg_capability_listings')
      case 'mangaList':
        return t('source_pkg_capability_manga_list')
      case 'home':
        return t('source_pkg_capability_home')
      case 'filters':
        return t('source_pkg_capability_filters')
      case 'settings':
        return t('source_pkg_capability_settings')
      case 'imageRequest':
        return t('source_pkg_capability_image_request')
      case 'network':
        return t('source_pkg_capability_network')
      default:
        return capability
    }
  }

  private capsText(source: InstalledSourcePackage): string {
    return this.capabilitySummaryText(source.capabilities)
  }

  private capabilitySummaryText(capabilities: string[]): string {
    if (capabilities.length === 0) {
      return t('source_pkg_capability_none')
    }
    const labels: string[] = []
    capabilities.forEach((capability: string) => {
      labels.push(this.capabilityLabel(capability))
    })
    return t('source_pkg_capability_prefix') + labels.join(' / ')
  }

  private installedTrustSummary(source: InstalledSourcePackage): SourcePackageTrustSummary {
    return installedSourceTrustSummary(source, this.capabilitySummaryText(source.capabilities).replace(t('source_pkg_capability_prefix'), ''))
  }

  private sourceIndexTrustSummary(entry: SourceIndexEntry): SourcePackageTrustSummary {
    return sourceIndexCandidateTrustSummary(entry, this.hasUpdate(entry))
  }

  private trustMetaText(summary: SourcePackageTrustSummary): string {
    return summary.provenanceLabel + ' · ' + summary.verificationLabel + ' · ' + summary.identityLabel
  }

  private installedTrustMetaText(source: InstalledSourcePackage): string {
    return this.trustMetaText(this.installedTrustSummary(source))
  }

  private installedTrustCapabilityText(source: InstalledSourcePackage): string {
    return this.installedTrustSummary(source).capabilitySummaryLabel
  }

  private sourceIndexTrustMetaText(entry: SourceIndexEntry): string {
    return this.trustMetaText(this.sourceIndexTrustSummary(entry))
  }

  private sourceIndexTrustCapabilityText(entry: SourceIndexEntry): string {
    return this.sourceIndexTrustSummary(entry).capabilitySummaryLabel
  }

  private sourceContentRatingLabel(source: InstalledSourcePackage): string {
    if (source.nsfw) {
      return '18+'
    }
    const rating = source.contentRating.trim().toLowerCase()
    if (rating === 'safe') {
      return t('source_pkg_rating_all_ages')
    }
    if (rating === 'suggestive') {
      return t('source_pkg_rating_suggestive')
    }
    if (rating.length === 0 || rating === 'unknown') {
      return t('source_pkg_rating_unknown')
    }
    return source.contentRating
  }

  private sourceMetaText(source: InstalledSourcePackage): string {
    const parts: string[] = ['v' + source.version]
    if (source.lang.length > 0) {
      parts.push(sourceLanguageName(source.lang))
    }
    parts.push(this.sourceContentRatingLabel(source))
    parts.push(this.installedTrustSummary(source).provenanceLabel)
    return parts.join(' · ')
  }

  private packageListMetaText(source: InstalledSourcePackage | undefined): string {
    if (source === undefined) {
      return ''
    }
    const parts: string[] = ['v' + source.version]
    if (source.lang.length > 0) {
      parts.push(sourceLanguageName(source.lang))
    }
    // The adopted partial-check state belongs in this existing subtitle.
    // updateStatusText in the update action is absent for non-updatable rows.
    if (this.updateStatus(source.id).status === 'incomplete') {
      parts.push(this.updateStatusText(source))
    }
    return parts.join(' · ')
  }

  private hasSourcePackageMetadata(source: InstalledSourcePackage): boolean {
    return source.description.length > 0 || source.author.length > 0 ||
      source.contentRating.length > 0 || source.minAppVersion.length > 0
  }

  private sourceSettingsText(source: InstalledSourcePackage): string {
    return this.settingsAvailability[source.id] ?? t('source_pkg_settings_unchecked')
  }

  private diagnosticsSourceMetaText(source: InstalledSourcePackage): string {
    return 'id: ' + source.id + ' · name: ' + source.name + ' · enabled: ' + (source.enabled ? 'true' : 'false') + ' · imported: ' + (source.status === 'imported' ? 'true' : 'false')
  }

  private diagnosticsVersionText(source: InstalledSourcePackage): string {
    return tf(
      'source_pkg_diagnostics_version',
      source.version,
      source.lang.length > 0 ? sourceLanguageName(source.lang) : t('common_unavailable'),
      this.sourceContentRatingLabel(source),
    )
  }

  private diagnosticsSmokeText(source: InstalledSourcePackage): string {
    const reason = source.lastDiagnosticMessage.length > 0 ? this.sourceReasonText(source.lastDiagnosticMessage) : t('source_pkg_not_run')
    return tf('source_pkg_diagnostics_smoke', source.smokeStatus, reason)
  }

  private diagnosticsUpdateReasonText(status: SourcePackageUpdateStatus): string {
    switch (status.status) {
      case 'checking':
        return t('source_pkg_checking')
      case 'latest':
      case 'update':
        return this.sourceReasonText(status.reasonCode ?? 'ok')
      case 'missing':
        return t('source_pkg_update_status_missing_brief')
      case 'incomplete':
        return t('source_pkg_update_status_incomplete')
      case 'failed':
        return this.sourceRedactedReasonText(status.reasonCode)
      case 'unknown':
      default:
        return t('source_pkg_not_checked')
    }
  }

  private diagnosticsUpdateText(source: InstalledSourcePackage): string {
    const status = this.updateStatus(source.id)
    const localVersion = status.localVersion ?? source.version
    const remoteVersion = status.remoteVersion ?? t('common_unavailable')
    return tf('source_pkg_diagnostics_update', status.status, localVersion, remoteVersion, this.diagnosticsUpdateReasonText(status))
  }

  private diagnosticsSettingsText(source: InstalledSourcePackage): string {
    if (this.savedSettingsReadFailed) return t('source_pkg_reason_settings_validation_failed')
    const counts = this.diagnosticsSettingCounts(source.id)
    return tf('source_pkg_diagnostics_settings', counts.total, counts.editable, counts.sensitive, counts.saved)
  }

  private diagnosticsSettingsValidationText(source: InstalledSourcePackage): string {
    if (this.savedSettingsReadFailed) return t('source_pkg_reason_settings_validation_failed')
    const status = this.settingsValidationStatus(source.id)
    const reason = status.status === 'fail'
      ? this.sourceReasonText(status.reasonCode)
      : (status.status === 'running'
        ? t('source_pkg_settings_validation_running')
        : (status.status === 'pass' ? t('source_pkg_reason_ok') : t('source_pkg_not_run')))
    return tf('source_pkg_diagnostics_validation', status.status, status.savedCount, reason)
  }

  private diagnosticsTrustText(source: InstalledSourcePackage): string {
    const summary = this.installedTrustSummary(source)
    return tf('source_pkg_diagnostics_trust', summary.provenanceLabel + ' · ' + summary.verificationLabel + ' · ' + summary.identityLabel)
  }

  private packageSmokeText(source: InstalledSourcePackage): string {
    const reason = source.lastDiagnosticMessage.length > 0 ? this.sourceReasonText(source.lastDiagnosticMessage) : ''
    if (reason.length > 0) {
      return tf('source_pkg_diagnostics_smoke', source.smokeStatus, reason)
    }
    return t('source_pkg_smoke_label') + source.smokeStatus
  }

  @Builder
  private IndexUrlCard() {
    ConciseListRow({
      title: t('source_pkg_index_url_heading'),
      subtitle: this.sourceIndexSummaryText(),
      subtitleMaxLines: 1,
      leadingIcon: $r('sys.symbol.compass'),
      leadingIconBackgroundColor: ThemeConstants.SOURCE_WASM_COLOR,
      action: () => {
        this.openIndexSheet()
      },
    })
  }

  @Builder
  private RemoteIndexCard(entry: SourceIndexEntry) {
    ConciseListRow({
      title: this.indexDisplayName(entry),
      subtitle: this.indexVersionText(entry) + (sourceLanguageName(entry.lang).length > 0 ? ' · ' + sourceLanguageName(entry.lang) : ''),
      subtitleMaxLines: 1,
      subtitleContentRating: entry.nsfw,
      hasSourceIdentityPrefix: true,
      sourceIdentityIconState: this.indexIconStates[entry.id],
      sourceIdentitySourceId: entry.id,
      sourceIdentityVersion: entry.version,
      sourceIdentityFallbackColor: ThemeConstants.SOURCE_WASM_COLOR,
      prefixPaddingLeft: ThemeConstants.SPACE_MD,
      prefixPaddingRight: ThemeConstants.SPACE_SM,
      showChevron: false,
      actionButtonText: this.hasUpdate(entry) || !this.isSourceInstalled(entry.id)
        ? this.packageActionLabel(entry.id, this.hasUpdate(entry)) : '',
      actionButtonEnabled: !this.busy && !this.packageInstallPending(entry.id),
      actionButtonAction: () => { void this.installIndexEntry(entry, this.hasUpdate(entry)) },
      trailingText: this.isSourceInstalled(entry.id) && !this.hasUpdate(entry) ? t('source_pkg_installed') : '',
    })
  }

  @Builder
  private SavedIndexRemoveButton(repository: SourceIndexRepository) {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(18)
        .fontColor([ThemeConstants.TEXT_SECONDARY])
    }
    .width(44)
    .height(44)
    .backgroundColor(Color.Transparent)
    .enabled(!this.sourceIndexBatchBusy())
    .accessibilityText(t('source_pkg_saved_index_remove'))
    .onClick(() => {
      this.removeSavedIndex(repository)
    })
  }

  @Builder
  private SourceIndexSheetContent() {
    KomaModalScaffold({
      title: t('source_pkg_index_url_heading'),
      onClose: () => {
        this.sourceIndexSheetShown = false
      },
    }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
          KomaFormTextField({
            label: t('source_pkg_index_url_label'),
            placeholder: t('source_pkg_index_url_placeholder'),
            value: this.sourceIndexUrl,
            submit: () => {
              void this.fetchIndex()
            },
            change: (value: string) => {
              this.setSourceIndexUrl(value)
            },
          })

          GroupedListSection() {
            ConciseListRow({
              title: this.indexFetchBusy ? t('source_pkg_loading') : t('source_pkg_load_sources'),
              leadingIcon: $r('sys.symbol.arrow_down_to_line'),
              isEnabled: !this.indexFetchBusy,
              action: () => {
                void this.fetchIndex()
              },
            })
            ListDivider()
            ConciseListRow({
              title: this.busy ? t('source_pkg_importing') : t('source_pkg_local_import'),
              leadingIcon: $r('sys.symbol.folder'),
              isEnabled: !this.busy,
              action: () => {
                void this.importPackage()
              },
            })
          }

          if (this.indexStatusText.length > 0) {
            Text(this.indexStatusText)
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }

          if (this.sourceIndexRepositories.length > 0) {
            GroupedListSection({ title: t('source_pkg_saved_indexes_heading') }) {
              ForEach(this.sourceIndexRepositories, (repository: SourceIndexRepository, index: number) => {
                ConciseListRow({
                  title: repository.url,
                  wrapTitle: true,
                  subtitle: this.savedIndexSubtitle(repository),
                  subtitleMaxLines: 1,
                  suffixBuilderParam: () => {
                    this.SavedIndexRemoveButton(repository)
                  },
                  action: () => {
                    this.selectSavedIndex(repository)
                  },
                })
                if (index < this.sourceIndexRepositories.length - 1) {
                  ListDivider()
                }
              }, (repository: SourceIndexRepository) => repository.url)
            }
          }

          if (this.indexEntries.length > 0) {
            GroupedListSection({ title: t('source_pkg_batch_actions_heading') }) {
              ConciseListRow({
                title: tf('source_pkg_batch_install_missing', this.missingIndexEntries().length),
                leadingIcon: $r('sys.symbol.arrow_down_to_line'),
                isEnabled: !this.sourceIndexBatchBusy() && this.missingIndexEntries().length > 0,
                action: () => {
                  this.installMissingIndexEntries()
                },
              })
              ListDivider()
              ConciseListRow({
                title: tf('source_pkg_batch_update_available', this.updatableIndexEntries().length),
                leadingIcon: $r('sys.symbol.arrow_clockwise'),
                isEnabled: !this.sourceIndexBatchBusy() && this.updatableIndexEntries().length > 0,
                action: () => {
                  this.updateUpdatableIndexEntries()
                },
              })
            }
          }

          Text(sourcePackageTrustBoundaryNotice())
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .lineHeight(18)
            .fontColor(ThemeConstants.TEXT_SECONDARY)

          Text(t('source_pkg_manual_update_notice'))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .lineHeight(18)
            .fontColor(ThemeConstants.TEXT_SECONDARY)

        Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
    }
  }

  @Builder
  private InstalledHeaderCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(t('source_pkg_installed_heading'))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
          Text(tf('source_pkg_source_count', this.packages.length))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        KomaActionButton({
          label: this.updateCheckBusy ? t('source_pkg_checking') : t('source_pkg_check_updates'),
          kind: 'primary',
          compact: true,
          controlHeight: ThemeConstants.FILTER_CHIP_HEIGHT,
          isEnabled: !this.updateCheckBusy && !this.indexFetchBusy,
          action: () => {
            this.checkInstalledUpdates()
          },
        })

        if (this.checkedUpdateStatuses().length > 0) {
          KomaActionButton({
            label: tf('source_pkg_batch_update_available', this.checkedUpdateStatuses().length),
            kind: 'secondary',
            compact: true,
            controlHeight: ThemeConstants.FILTER_CHIP_HEIGHT,
            isEnabled: !this.sourceIndexBatchBusy(),
            action: () => {
              this.updateCheckedPackages()
            },
          })
        }
      }
      .width('100%')

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }

      Text(t('source_pkg_manual_check_notice'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .lineHeight(18)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private EmptyCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text(t('source_pkg_empty_title'))
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(t('source_pkg_empty_message'))
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_XL)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private PackageCard(source: InstalledSourcePackage, candidate?: SourcePackageUpdateCandidate) {
    SourcePackageListItem({
      source,
      subtitle: candidate === undefined ? this.packageListMetaText(source)
        : this.indexVersionText(candidate.entry) + (sourceLanguageName(candidate.entry.lang).length > 0 ? ' · ' + sourceLanguageName(candidate.entry.lang) : ''),
      updateAvailable: candidate !== undefined,
      updateLabel: candidate !== undefined ? this.updateActionLabel(source.id) : '',
      updateEnabled: candidate === undefined || (!this.busy && !this.packageInstallPending(source.id)),
      remoteNsfw: candidate?.entry.nsfw ?? false,
      onUpdate: (selected: InstalledSourcePackage): void => {
        if (candidate !== undefined) void this.updateInstalledPackage(selected, candidate)
      },
      onOpen: (selected: InstalledSourcePackage): void => { this.openSourceSheet(selected) },
    })
  }

  @Builder
  private SourceDetailsContent(params: SourceDetailsContentParams) {
    Column({ space: ThemeConstants.SPACE_LG }) {
      GroupedListSection() {
        ConciseListRow({
          title: t('tab_browse'),
          subtitle: params.source.enabled ? '' : t('source_pkg_disabled'),
          leadingIcon: $r('sys.symbol.compass'),
          isEnabled: params.source.enabled,
          action: () => {
            this.openSourceBrowseFromSheet(params.source)
          },
        })
        ListDivider()
        ConciseListRow({
          title: t('tab_search'),
          subtitle: this.sourceSupportsSearch(params.source) ? '' : t('source_pkg_unsupported'),
          leadingIcon: $r('sys.symbol.magnifyingglass'),
          isEnabled: params.source.enabled && this.sourceSupportsSearch(params.source),
          action: () => {
            this.openSourceSearchFromSheet(params.source)
          },
        })
        if (this.settingsDescriptorSnapshot[params.source.id] === undefined ||
          this.settingsDescriptorSnapshot[params.source.id].length > 0) {
          ListDivider()
          ConciseListRow({
            title: t('source_pkg_settings'),
            trailingText: this.sourceSettingsText(params.source),
            leadingIcon: $r('sys.symbol.gearshape'),
            action: () => {
              this.openSourceSettingsFromSheet(params.source)
            },
          })
        }
        if ((appSourceRuntimeRegistry.lookup(params.source.id).entry?.webSessionOrigins ?? []).length > 0) {
          ListDivider()
          ConciseListRow({
            title: t('source_web_open'),
            leadingIcon: $r('sys.symbol.website'),
            isEnabled: params.source.enabled,
            action: () => { this.requestSourceSheetDismiss('open_web', params.source) },
          })
          if (appSourceWebSessionStore.status(params.source.id).state === 'available') {
            ListDivider()
            ConciseListRow({
              title: t('source_web_disconnect'),
              leadingIcon: $r('sys.symbol.xmark'),
              action: () => {
                try {
                  appSourceWebSessionStore.revoke(params.source.id)
                  this.reload()
                  this.showToast(t('source_web_disconnected'))
                } catch (_error) {
                  this.showToast(t('source_web_disconnect_failed'))
                }
              },
            })
          }
        }
      }

      if (this.hasSourcePackageMetadata(params.source)) {
        GroupedListSection({ title: t('source_pkg_information_section') }) {
          if (params.source.description.length > 0) {
            ConciseListRow({
              title: t('common_description'),
              subtitle: params.source.description,
              subtitleMaxLines: 3,
              showChevron: false,
            })
            if (params.source.author.length > 0 || params.source.contentRating.length > 0 || params.source.minAppVersion.length > 0) {
              ListDivider()
            }
          }
          if (params.source.author.length > 0) {
            ConciseListRow({
              title: t('source_pkg_author'),
              subtitle: params.source.author,
              showChevron: false,
            })
            if (params.source.contentRating.length > 0 || params.source.minAppVersion.length > 0) {
              ListDivider()
            }
          }
          if (params.source.contentRating.length > 0) {
            ConciseListRow({
              title: t('source_pkg_content_rating'),
              subtitle: this.sourceContentRatingLabel(params.source),
              showChevron: false,
            })
            if (params.source.minAppVersion.length > 0) {
              ListDivider()
            }
          }
          if (params.source.minAppVersion.length > 0) {
            ConciseListRow({
              title: t('source_pkg_min_app_version'),
              subtitle: params.source.minAppVersion,
              showChevron: false,
            })
          }
        }
      }

      GroupedListSection({ title: t('source_pkg_management_section') }) {
        if (this.updateEntry(params.source.id) !== undefined) {
          ConciseListRow({
            title: this.updateActionLabel(params.source.id),
            subtitle: this.updateStatusText(params.source),
            leadingIcon: $r('sys.symbol.arrow_clockwise'),
            isEnabled: !this.busy && !this.packageInstallPending(params.source.id),
            action: () => {
              this.updateInstalledPackage(params.source)
            },
          })
          ListDivider()
        }
        ConciseListRow({
          title: params.source.enabled ? t('source_pkg_disable') : t('source_pkg_enable'),
          leadingIcon: params.source.enabled ? $r('sys.symbol.pause') : $r('sys.symbol.play'),
          action: () => {
            this.togglePackage(params.source.id)
          },
        })
        ListDivider()
        ConciseListRow({
          title: t('source_pkg_delete'),
          destructive: true,
          leadingIcon: $r('sys.symbol.trash'),
          action: () => {
            this.requestSourceSheetDismiss('confirm_remove', params.source)
          },
        })
      }
      Blank().height(ThemeConstants.SPACE_XL)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
  }

  @Builder
  private SourceDetailsSheetContent() {
    if (this.sourceSheetSource() === undefined) {
      Blank().width('100%').height('100%')
    } else {
      KomaModalScaffold({
        title: sourceDisplayName(this.sourceSheetSource()!.id, this.sourceSheetSource()!.name),
        subtitle: this.sourceMetaText(this.sourceSheetSource()!),
        onClose: () => {
          this.requestSourceSheetDismiss()
        },
      }) {
        // Child updates can outlive onDisappear clearing the selected ID.
        // Retain the last live render payload; actions still resolve the registry.
        this.SourceDetailsContent({ source: this.sourceSheetSource() ?? this.sourceSheetRetainedSource! })
      }
    }
  }

  @Builder
  private SourceSettingsSheetContent() {
    SourceSettingsForm({
      settingsSourceId: this.settingsSourceId,
      settingsSourceName: this.settingsSourceName,
      settingDescriptors: this.settingDescriptors,
      initialDraft: this.settingDraft,
      onSaved: (cleared: boolean) => { this.sourceSettingsSaved(cleared) },
      onClose: () => { this.closeSourceSettingsSheet() },
    })
  }

  @Builder
  private SourceDiagnosticsSheetContent(source: InstalledSourcePackage) {
    Scroll() {
      Column({ space: ThemeConstants.SPACE_MD }) {
      this.DiagnosticsPanel(source)

      Row({ space: ThemeConstants.SPACE_SM }) {
        KomaActionButton({
          label: t('source_pkg_refresh_diagnostics'),
          kind: 'secondary',
          compact: true,
          action: () => {
            this.refreshDiagnostics(source)
          },
        })
          .layoutWeight(1)
        KomaActionButton({
          label: this.validateSettingsActionLabel(source.id),
          kind: 'secondary',
          compact: true,
          isEnabled: this.settingsValidationSourceId.length === 0,
          action: () => {
            this.validateSettings(source)
          },
        })
          .layoutWeight(1)
        KomaActionButton({
          label: 'Smoke',
          kind: 'secondary',
          compact: true,
          action: () => {
            this.smokePackage(source)
          },
        })
          .layoutWeight(1)
      }
      .width('100%')
      Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  private DiagnosticsPanel(source: InstalledSourcePackage) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Text(t('source_pkg_diagnostics_title'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)

        KomaActionButton({
          label: t('source_pkg_refresh_diagnostics'),
          kind: 'secondary',
          compact: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.refreshDiagnostics(source)
          },
        })
      }
      .width('100%')

      Text(this.diagnosticsSourceMetaText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      Text(this.diagnosticsVersionText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      Text(this.diagnosticsTrustText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.capsText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.diagnosticsSmokeText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      Text(this.diagnosticsUpdateText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.diagnosticsSettingsText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
      Text(this.diagnosticsSettingsValidationText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_MD)
    .border({ width: 1, color: ThemeConstants.DIVIDER })
    .borderRadius(ThemeConstants.RADIUS_CHIP)
    .backgroundColor(ThemeConstants.SOFT_TINT)
  }

  @Builder
  private PackageListGroups(groups: SourcePackageListGroups) {
    if (groups.updates.length > 0) {
      ListItem() {
        GroupedListSection({
          title: t('source_pkg_update_available'),
          actionLabel: t('source_pkg_update_all'),
          action: () => { this.updateAllAvailablePackages() },
        }) {
          ForEach(groups.updates, (candidate: SourcePackageUpdateCandidate, index: number) => {
            this.PackageCard(this.installedPackage(candidate.entry.id)!, candidate)
            if (candidate.entry.id !== this.lastUpdateSourceId) { ListDivider() }
          }, (candidate: SourcePackageUpdateCandidate, _index: number) => JSON.stringify([candidate.entry.id, candidate.entry.version,
            this.installedPackage(candidate.entry.id)?.version, this.installedPackage(candidate.entry.id)?.enabled, candidate.entry.nsfw]))
        }
      }
    }
    if (groups.missing.length > 0) {
      ListItem() {
        GroupedListSection({ title: t('source_pkg_uninstalled_heading') }) {
          ForEach(groups.missing, (entry: SourceIndexEntry, index: number) => {
            this.RemoteIndexCard(entry)
            if (entry.id !== this.lastMissingSourceId) { ListDivider() }
          }, (entry: SourceIndexEntry, _index: number) => JSON.stringify([entry.id, entry.version, entry.icon, entry.nsfw]))
        }
      }
    }
    if (groups.installed.length > 0) {
      ListItem() {
        GroupedListSection({ title: t('source_pkg_installed_heading') }) {
          ForEach(groups.installed, (source: InstalledSourcePackage, index: number) => {
            this.PackageCard(source)
            if (source.id !== this.lastInstalledSourceId) { ListDivider() }
          }, (source: InstalledSourcePackage, _index: number) => JSON.stringify([source.id, source.version, source.enabled, source.nsfw, source.icon, source.name, source.lang]))
        }
      }
    }
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Stack() {
        Column() {
          SecondaryListScaffold({
            listSpace: ThemeConstants.SPACE_MD,
            bottomPadding: ThemeConstants.SPACE_XL,
          }) {
            ListItem() {
              GroupedListSection() {
                this.IndexUrlCard()
              }
            }
            ListItem() {
              GroupedListSection() {
                ConciseListRow({
                  title: t('source_pkg_check_updates'),
                  subtitle: this.packageActivityText(),
                  leadingIcon: $r('sys.symbol.arrow_clockwise'),
                  leadingIconBackgroundColor: ThemeConstants.BRAND_PRIMARY,
                  isEnabled: !this.updateCheckBusy && !this.indexFetchBusy,
                  action: () => { this.checkInstalledUpdates() },
                })
              }
            }
            this.PackageListGroups({
              updates: this.listGroups.updates,
              missing: this.listGroups.missing,
              installed: this.listGroups.installed,
            })
            if (this.packages.length === 0) {
              ListItem() {
                this.EmptyCard()
              }
            }
          }
        }
        Column() {
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .bindSheet($$this.sourceIndexSheetShown, this.SourceIndexSheetContent, komaSheetOptions(this.sourceIndexSheetOptions()))
        Column() {
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .bindSheet($$this.sourceSheetShown, this.SourceDetailsSheetContent, komaSheetOptions(this.sourceDetailsSheetOptions()))
        Column() {
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .bindSheet($$this.sourceSettingsSheetShown, this.SourceSettingsSheetContent, komaSheetOptions(this.sourceSettingsSheetOptions()))
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
    }
  }
}

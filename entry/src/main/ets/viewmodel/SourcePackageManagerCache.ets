import { common } from '@kit.AbilityKit'
import { InstalledSourcePackage, listInstalled } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { SourceIndexEntry, SourceIndexRepository, SourceIndexService, SourceIndexFetchResult } from '../sourceRuntime/SourceIndexService'
import { compareSourceNames } from '../sourceRuntime/SourceListOrder'
import { resolveSourceLocalizedName } from '../sourceRuntime/SourceLocalizedNames'
import { SourceIdentityIconState } from '../components/ui/ConciseListRow'
import { AppStrings } from '../i18n/AppStrings'

function t(name: string): string { return AppStrings.get(name) }
function tf(name: string, ...args: Array<string | number>): string { return AppStrings.format(name, ...args) }

export type SourcePackageUpdateState = 'unknown' | 'checking' | 'latest' | 'update' | 'missing' | 'failed' | 'incomplete'

export interface SourcePackageUpdateStatus {
  sourceId: string
  status: SourcePackageUpdateState
  remoteEntry?: SourceIndexEntry
  remoteIndexUrl?: string
  remoteVersion?: string
  localVersion?: string
  reasonCode?: string
}

export interface SourcePackageUpdateCandidate {
  entry: SourceIndexEntry
  indexUrl: string
}


// This process owner survives destination creation. Hydrate before pushing the
// route, keep last content while revalidating, and never turn a revisit into a
// new empty/loading list. It is a display cache, never registry authority.
@ObservedV2
export class SourcePackageManagerCache {
  @Trace revision: number = 0
  packages: InstalledSourcePackage[] = []
  sourceIndexUrl: string = ''
  sourceIndexRepositories: SourceIndexRepository[] = []
  indexEntries: SourceIndexEntry[] = []
  indexIconStates: Record<string, SourceIdentityIconState> = {}
  displayedIndexUrl: string = ''
  sourceIndexFailures: Record<string, string> = {}
  packageUpdateStatuses: SourcePackageUpdateStatus[] = []
  statusText: string = ''
  indexStatusText: string = ''
  updateCheckBusy: boolean = false
  private indexLoadRevision: number = 0
  private scope: string = ''
  private generation: number = 0
  private locale: string = ''
  private ready: Promise<void> | undefined = undefined
  private automaticStarted: boolean = false
  private checkTail: Promise<void> = Promise.resolve()
  private checkedSavedUrl: string | undefined = undefined

  // Explicit repository edits retire running and queued work, while retaining
  // the last committed display. A text-field draft is never persistence.
  retireCheck(): void {
    this.generation += 1
    this.indexLoadRevision += 1
  }

  rememberSavedIndex(url: string, repositories?: SourceIndexRepository[]): void {
    // A later repositories read must not restore an older active URL after a
    // newer save has completed. Only the save completion owns the active URL.
    if (repositories !== undefined) {
      if (url === this.sourceIndexUrl) this.sourceIndexRepositories = repositories
      return
    }
    if (url !== this.sourceIndexUrl) {
      this.sourceIndexUrl = url
      this.indexEntries = []
      this.indexIconStates = {}
      this.displayedIndexUrl = ''
      this.indexStatusText = ''
    }
  }

  invalidate(): void {
    this.retireCheck()
    this.ready = undefined
    this.automaticStarted = false
    this.scope = ''
  }

  async prepare(context: common.UIAbilityContext, locale: string): Promise<void> {
    if (this.scope !== context.filesDir) {
      this.invalidate()
      this.scope = context.filesDir
      this.packages = []
      this.indexEntries = []
      this.indexIconStates = {}
      this.sourceIndexFailures = {}
      this.packageUpdateStatuses = []
      this.statusText = ''
    }
    const current = listInstalled()
    const names = new Map<string, string>()
    current.forEach((source: InstalledSourcePackage): void => {
      names.set(source.id, resolveSourceLocalizedName(source.name, source.localizedNames, locale))
    })
    const previous = new Map<string, InstalledSourcePackage>()
    this.packages.forEach((source: InstalledSourcePackage): void => { previous.set(source.id, source) })
    const packages = current.map((source: InstalledSourcePackage): InstalledSourcePackage => {
      const old = previous.get(source.id)
      return old !== undefined && JSON.stringify(old) === JSON.stringify(source) ? old : source
    }).sort((left: InstalledSourcePackage, right: InstalledSourcePackage): number =>
      compareSourceNames(names.get(left.id) ?? left.name, left.id, names.get(right.id) ?? right.name, right.id))
    if (packages.length !== this.packages.length || packages.some((source: InstalledSourcePackage, index: number): boolean => source !== this.packages[index])) {
      this.packages = packages
    }
    const localeChanged = this.locale !== locale
    this.locale = locale
    if (localeChanged && this.indexEntries.length > 0) this.showIndexEntries(this.displayedIndexUrl, this.indexEntries, this.indexLoadRevision)
    if (this.ready === undefined) this.ready = this.hydrate(context)
    await this.ready
  }

  private async hydrate(context: common.UIAbilityContext): Promise<void> {
    const service = new SourceIndexService(context)
    const revision = this.indexLoadRevision
    const scope = this.scope
    try {
      const url = await service.loadSavedUrl()
      const repositories = await service.loadSavedRepositories()
      const cached = await service.loadCachedIndex(url)
      if (revision !== this.indexLoadRevision || scope !== this.scope) return
      this.sourceIndexUrl = url
      this.sourceIndexRepositories = repositories
      if (cached !== undefined) {
        this.showIndexEntries(this.sourceIndexUrl, cached, this.indexLoadRevision)
        // Only local files before first paint; an absent icon never makes a
        // navigation wait for the network. Online warming remains background.
        await service.loadIndexIcons(this.sourceIndexUrl,
          this.indexEntries.filter((entry: SourceIndexEntry): boolean => !this.packages.some((source: InstalledSourcePackage): boolean => source.id === entry.id)),
          (entry: SourceIndexEntry): void => { this.indexIconStates[entry.id].uri = entry.iconUri ?? '' },
          (): boolean => revision === this.indexLoadRevision && scope === this.scope, false)
      }
    } catch (_error) {
      this.indexStatusText = tf('source_pkg_index_load_failed', t('source_pkg_reason_unknown'))
    }
  }

  revalidateInBackground(context: common.UIAbilityContext): void {
    if (this.automaticStarted) return
    this.automaticStarted = true
    void this.check(context)
  }

  capture(expectedRevision: number, retireCheck: boolean, packages: InstalledSourcePackage[], url: string, repositories: SourceIndexRepository[], entries: SourceIndexEntry[],
    icons: Record<string, SourceIdentityIconState>, displayedUrl: string, failures: Record<string, string>,
    statuses: SourcePackageUpdateStatus[], status: string, indexStatus: string): void {
    // Retire an older background publication when this page has performed a
    // newer explicit action. Saving view state does not start another request.
    if (!retireCheck && expectedRevision !== this.revision) return
    if (retireCheck) this.retireCheck()
    this.packages = packages
    // Page disappearance may retain installed rows/status, but an unsubmitted
    // URL must not replace the saved repository or its usable index/icon cache.
    if (url === this.sourceIndexUrl) {
      this.sourceIndexRepositories = repositories
      this.indexEntries = entries
      this.indexIconStates = icons
      this.displayedIndexUrl = displayedUrl
      this.indexStatusText = indexStatus
    }
    this.sourceIndexFailures = failures
    this.packageUpdateStatuses = statuses
    this.statusText = status
  }

  private showIndexEntries(url: string, entries: SourceIndexEntry[], revision: number): void {
    if (revision !== this.indexLoadRevision) return
    const previous = new Map<string, SourceIndexEntry>()
    if (url === this.displayedIndexUrl) this.indexEntries.forEach((entry: SourceIndexEntry): void => { previous.set(entry.id, entry) })
    const names = new Map<string, string>()
    const next = entries.map((entry: SourceIndexEntry): SourceIndexEntry => {
      names.set(entry.id, resolveSourceLocalizedName(entry.name, entry.localizedNames, this.locale))
      const old = previous.get(entry.id)
      return old !== undefined && JSON.stringify(old) === JSON.stringify(entry) ? old : entry
    }).sort((left: SourceIndexEntry, right: SourceIndexEntry): number =>
      compareSourceNames(names.get(left.id) ?? left.name, left.id, names.get(right.id) ?? right.name, right.id))
    const icons: Record<string, SourceIdentityIconState> = {}
    next.forEach((entry: SourceIndexEntry): void => { icons[entry.id] = this.indexIconStates[entry.id] ?? new SourceIdentityIconState() })
    this.indexIconStates = icons
    if (next.length !== this.indexEntries.length || next.some((entry: SourceIndexEntry, index: number): boolean => entry !== this.indexEntries[index])) this.indexEntries = next
    this.displayedIndexUrl = url
    this.indexStatusText = tf('source_pkg_index_loaded', entries.length)
  }

  private installedPackage(sourceId: string): InstalledSourcePackage | undefined {
    return this.packages.find((source: InstalledSourcePackage): boolean => source.id === sourceId)
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

  private checkedUpdateStatuses(): SourcePackageUpdateStatus[] {
    return this.packageUpdateStatuses.filter((status: SourcePackageUpdateStatus): boolean => {
      return status.status === 'update' && status.remoteEntry !== undefined && status.remoteIndexUrl !== undefined &&
        this.installedPackage(status.sourceId) !== undefined
    })
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
      case 'settings_read_failed':
      case 'ok':
      case 'unknown':
        return this.sourceReasonText(code)
      default:
        return t('source_pkg_reason_redacted')
    }
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
      case 'settings_read_failed':
        return t('source_pkg_reason_settings_read_failed')
      case 'settings_validation_failed':
        return t('source_pkg_reason_runtime_response_not_ok')
      case 'ok':
        return t('source_pkg_reason_ok')
      case 'unknown':
        return t('source_pkg_reason_unknown')
      default:
        return tf('source_pkg_reason_code', code)
    }
  }

  check(context: common.UIAbilityContext, requestedUrl?: string): Promise<void> {
    const generation = this.generation
    const result = this.checkTail.then((): Promise<void> => generation === this.generation
      ? this.refresh(context, requestedUrl) : Promise.resolve())
    this.checkTail = result.catch((): void => {})
    return result
  }

  private async refresh(context: common.UIAbilityContext, requestedUrl?: string): Promise<void> {
    const revision = ++this.indexLoadRevision
    const packages = this.packages
    // Collect into a detached draft. No partially fetched repository or status
    // may escape into the first paint, or change a live list between responses.
    const draft = new SourcePackageManagerCache()
    draft.packages = packages
    draft.sourceIndexUrl = requestedUrl ?? this.sourceIndexUrl
    draft.sourceIndexRepositories = this.sourceIndexRepositories
    draft.indexEntries = this.indexEntries
    draft.indexIconStates = this.indexIconStates
    draft.displayedIndexUrl = this.displayedIndexUrl
    draft.packageUpdateStatuses = this.packageUpdateStatuses
    draft.locale = this.locale
    await draft.collectCheck(context, (): boolean => revision === this.indexLoadRevision && packages === this.packages)
    if (revision !== this.indexLoadRevision || packages !== this.packages) return
    let changed = false
    if (draft.checkedSavedUrl !== undefined && this.sourceIndexUrl !== draft.checkedSavedUrl) {
      this.sourceIndexUrl = draft.checkedSavedUrl
      changed = true
    }
    if (draft.indexEntries !== this.indexEntries) {
      this.indexEntries = draft.indexEntries
      this.indexIconStates = draft.indexIconStates
      this.displayedIndexUrl = draft.displayedIndexUrl
      changed = true
    }
    if (JSON.stringify(draft.packageUpdateStatuses) !== JSON.stringify(this.packageUpdateStatuses)) {
      this.packageUpdateStatuses = draft.packageUpdateStatuses
      changed = true
    }
    if (JSON.stringify(draft.sourceIndexFailures) !== JSON.stringify(this.sourceIndexFailures)) {
      this.sourceIndexFailures = draft.sourceIndexFailures
      changed = true
    }
    this.sourceIndexRepositories = draft.sourceIndexRepositories
    if (this.statusText !== draft.statusText || this.indexStatusText !== draft.indexStatusText) changed = true
    this.statusText = draft.statusText
    this.indexStatusText = draft.indexStatusText
    if (changed) this.revision += 1
    const entries = this.indexEntries
    const url = this.displayedIndexUrl
    void new SourceIndexService(context).loadIndexIcons(url,
      entries.filter((entry: SourceIndexEntry): boolean => !packages.some((source: InstalledSourcePackage): boolean => source.id === entry.id)),
      (entry: SourceIndexEntry): void => {
        if (revision !== this.indexLoadRevision || url !== this.displayedIndexUrl ||
          !this.indexEntries.some((current: SourceIndexEntry): boolean => current.id === entry.id && current.version === entry.version && current.icon === entry.icon)) return
        const icon = this.indexIconStates[entry.id]
        if (icon !== undefined) icon.uri = entry.iconUri ?? ''
      }, (): boolean => revision === this.indexLoadRevision && url === this.displayedIndexUrl).catch((): void => {})
  }

  private async collectCheck(context: common.UIAbilityContext, isCurrent: () => boolean): Promise<void> {
    if (this.updateCheckBusy) {
      return
    }
    const url = this.sourceIndexUrl.trim()
    if (url.length === 0) {
      return
    }
    const revision = ++this.indexLoadRevision
    const packages = this.packages
    const service = new SourceIndexService(context)
    const count = this.packages.length
    console.info('[SourcePackageUpdate] step=check_start count=' + count)
    this.updateCheckBusy = true
    // The summary owns the in-flight indicator. Keep the last known per-source
    // results (and their groups) until this check has a replacement result.
    try {
      await service.saveUrl(url)
      this.checkedSavedUrl = url
      const repositories = await service.loadSavedRepositories()
      if (revision !== this.indexLoadRevision || !isCurrent()) return
      this.sourceIndexRepositories = repositories
      const updateIndexUrls = this.sourceIndexUrlsForUpdate(url)
      const candidates: Record<string, SourcePackageUpdateCandidate> = {}
      const indexFailures: Record<string, string> = {}
      let loadedIndexCount = 0
      let failedIndexCount = 0
      let firstFailureReason = 'network_error'
      for (let index = 0; index < updateIndexUrls.length; index += 1) {
        const indexUrl = updateIndexUrls[index]
        const result: SourceIndexFetchResult = await service.fetchIndex(indexUrl)
        if (revision !== this.indexLoadRevision || packages !== this.packages || !isCurrent()) return
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
      if (revision !== this.indexLoadRevision || !isCurrent()) return
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
      if (revision === this.indexLoadRevision) this.revision += 1
    }
  }
}

export const appSourcePackageManagerCache: SourcePackageManagerCache = new SourcePackageManagerCache()

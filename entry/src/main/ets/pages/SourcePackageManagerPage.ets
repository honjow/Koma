import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier } from '@kit.ArkUI'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider } from '../components/ui/GroupedListSection'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  InstalledSourcePackage,
  appSourceRuntimeRegistry,
  installFromArchive,
  listInstalled,
  pickSourcePackageArchive,
  remove,
  runSmoke,
  setEnabled,
} from '../sourceRuntime/SourceRuntimeAppRegistry'
import { runRegisteredSourceRequestById } from '../sourceRuntime/SourceRuntimeService'
import {
  SourceSettingDescriptor,
  SourceSettingOption,
  SourceSettingValue,
  SourceSettingsRecord,
  appSourceSettingsStore,
  configureSourceSettingsStore,
  fetchSourceSettingDescriptors,
} from '../sourceRuntime/SourceSettingsStore'
import {
  SourceIndexEntry,
  SourceIndexFetchResult,
  SourceIndexInstallResult,
  SourceIndexService,
} from '../sourceRuntime/SourceIndexService'
import {
  installedSourceTrustSummary,
  SourcePackageTrustSummary,
  sourceIndexCandidateTrustSummary,
  sourcePackageTrustBoundaryNotice,
} from '../sourceRuntime/SourcePackageTrustPolicy'

function t(name: string): string {
  return AppStrings.get(name)
}

function tf(name: string, ...args: Array<string | number>): string {
  return AppStrings.format(name, ...args)
}

type SourcePackageUpdateState = 'unknown' | 'checking' | 'latest' | 'update' | 'missing' | 'failed'
type SourceSettingsValidationState = 'unknown' | 'running' | 'pass' | 'fail'

interface SourcePackageUpdateStatus {
  sourceId: string
  status: SourcePackageUpdateState
  remoteEntry?: SourceIndexEntry
  remoteVersion?: string
  localVersion?: string
  reasonCode?: string
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

interface SourceDiagnosticsSettingCounts {
  total: number
  editable: number
  sensitive: number
  saved: number
}

@ComponentV2
export struct SourcePackageManagerPage {
  @Local private packages: InstalledSourcePackage[] = []
  @Local private busy: boolean = false
  @Local private statusText: string = ''
  @Local private settingsSourceId: string = ''
  @Local private settingsSourceName: string = ''
  @Local private settingDescriptors: SourceSettingDescriptor[] = []
  @Local private settingDraft: SourceSettingsRecord = {}
  @Local private sourceIndexUrl: string = ''
  @Local private indexEntries: SourceIndexEntry[] = []
  @Local private indexFetchBusy: boolean = false
  @Local private indexInstallBusy: boolean = false
  @Local private indexStatusText: string = ''
  @Local private packageUpdateStatuses: SourcePackageUpdateStatus[] = []
  @Local private updateCheckBusy: boolean = false
  @Local private updateInstallSourceId: string = ''
  @Local private settingsAvailability: Record<string, string> = {}
  @Local private settingsValidationStatuses: SourceSettingsValidationStatus[] = []
  @Local private settingsValidationSourceId: string = ''
  @Local private diagnosticsSourceId: string = ''
  @Local private settingMenuKey: string = ''
  @Local private languageState: LanguageState = connectLanguageState()
  private sourceIndexService: SourceIndexService = new SourceIndexService(this.context())

  aboutToAppear(): void {
    configureSourceSettingsStore(this.context())
    this.reload()
    this.loadSavedIndexUrl()
  }

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private reload(): void {
    this.packages = listInstalled()
    const availability: Record<string, string> = {}
    const validationStatuses: SourceSettingsValidationStatus[] = []
    this.packages.forEach((source: InstalledSourcePackage) => {
      const descriptors = fetchSourceSettingDescriptors(appSourceRuntimeRegistry, source.id)
      if (descriptors.length === 0) {
        availability[source.id] = t('source_pkg_settings_none')
      } else {
        const editable = descriptors.filter((descriptor: SourceSettingDescriptor): boolean => descriptor.supported && !descriptor.sensitive).length
        availability[source.id] = tf('source_pkg_settings_editable', editable, descriptors.length)
      }
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
    this.settingsAvailability = availability
    this.settingsValidationStatuses = validationStatuses
  }

  private async loadSavedIndexUrl(): Promise<void> {
    const saved = await this.sourceIndexService.loadSavedUrl()
    if (saved.length > 0) {
      this.sourceIndexUrl = saved
    }
  }

  private installedSourceIds(): string[] {
    return this.packages.map((pkg: InstalledSourcePackage): string => pkg.id)
  }

  private installedPackage(entryId: string): InstalledSourcePackage | undefined {
    return this.packages.find((pkg: InstalledSourcePackage): boolean => pkg.id === entryId)
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

  private hasUpdate(entry: SourceIndexEntry): boolean {
    const installed = this.installedPackage(entry.id)
    if (installed === undefined || entry.version.length === 0 || installed.version.length === 0) {
      return false
    }
    return this.compareVersion(entry.version, installed.version) > 0
  }

  private updateStatus(sourceId: string): SourcePackageUpdateStatus {
    const status = this.packageUpdateStatuses.find((item: SourcePackageUpdateStatus): boolean => item.sourceId === sourceId)
    if (status !== undefined) {
      return status
    }
    return { sourceId, status: 'unknown' }
  }

  private isDiagnosticsOpen(sourceId: string): boolean {
    return this.diagnosticsSourceId === sourceId
  }

  private toggleDiagnostics(source: InstalledSourcePackage): void {
    if (this.isDiagnosticsOpen(source.id)) {
      this.diagnosticsSourceId = ''
      console.info('[SourceRuntimeDiagnostics] step=close id=' + source.id)
      return
    }
    this.diagnosticsSourceId = source.id
    console.info('[SourceRuntimeDiagnostics] step=open id=' + source.id)
  }

  private refreshDiagnostics(source: InstalledSourcePackage): void {
    console.info('[SourceRuntimeDiagnostics] step=refresh id=' + source.id)
    this.reload()
    const installed = this.installedPackage(source.id)
    this.diagnosticsSourceId = installed === undefined ? '' : source.id
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

  private savedSettingsCount(sourceId: string): number {
    const saved = appSourceSettingsStore.loadForSource(sourceId)
    return Object.keys(saved).length
  }

  private diagnosticsSettingCounts(sourceId: string): SourceDiagnosticsSettingCounts {
    const descriptors = fetchSourceSettingDescriptors(appSourceRuntimeRegistry, sourceId)
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

  private updateActionLabel(sourceId: string): string {
    return this.updateInstallSourceId === sourceId ? t('source_pkg_action_updating') : t('source_pkg_action_update')
  }

  private updateEntry(sourceId: string): SourceIndexEntry | undefined {
    const status = this.updateStatus(sourceId)
    return status.status === 'update' ? status.remoteEntry : undefined
  }

  private async currentIndexUrlOrPrompt(): Promise<string> {
    let url = this.sourceIndexUrl.trim()
    if (url.length === 0) {
      const saved = await this.sourceIndexService.loadSavedUrl()
      if (saved.length > 0) {
        this.sourceIndexUrl = saved
        url = saved
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
    if (this.updateCheckBusy || this.indexFetchBusy) {
      return
    }
    const url = await this.currentIndexUrlOrPrompt()
    if (url.length === 0) {
      return
    }
    const count = this.packages.length
    console.info('[SourcePackageUpdate] step=check_start count=' + count)
    this.updateCheckBusy = true
    this.statusText = t('source_pkg_check_updates_running')
    this.packageUpdateStatuses = this.packages.map((source: InstalledSourcePackage): SourcePackageUpdateStatus => {
      return {
        sourceId: source.id,
        status: 'checking',
        localVersion: source.version,
      }
    })
    try {
      await this.sourceIndexService.saveUrl(url)
      const result: SourceIndexFetchResult = await this.sourceIndexService.fetchIndex(url)
      if (!result.ok) {
        this.packageUpdateStatuses = this.packages.map((source: InstalledSourcePackage): SourcePackageUpdateStatus => {
          return {
            sourceId: source.id,
            status: 'failed',
            localVersion: source.version,
            reasonCode: result.reasonCode,
          }
        })
        this.statusText = tf('source_pkg_check_failed', this.sourceRedactedReasonText(result.reasonCode))
        console.info('[SourcePackageUpdate] step=check_done update=0 latest=0 missing=0 failed=' + count)
        return
      }

      this.indexEntries = result.entries
      this.indexStatusText = tf('source_pkg_index_loaded', result.entries.length)
      let updateCount = 0
      let latestCount = 0
      let missingCount = 0
      const nextStatuses: SourcePackageUpdateStatus[] = []
      this.packages.forEach((source: InstalledSourcePackage) => {
        const entry = result.entries.find((item: SourceIndexEntry): boolean => item.id === source.id)
        if (entry === undefined) {
          missingCount += 1
          nextStatuses.push({
            sourceId: source.id,
            status: 'missing',
            localVersion: source.version,
          })
          return
        }
        if (entry.version.length > 0 && source.version.length > 0 && this.compareVersion(entry.version, source.version) > 0) {
          updateCount += 1
          nextStatuses.push({
            sourceId: source.id,
            status: 'update',
            remoteEntry: entry,
            remoteVersion: entry.version,
            localVersion: source.version,
          })
          return
        }
        latestCount += 1
        nextStatuses.push({
          sourceId: source.id,
          status: 'latest',
          remoteEntry: entry,
          remoteVersion: entry.version,
          localVersion: source.version,
        })
      })
      this.packageUpdateStatuses = nextStatuses
      this.statusText = tf('source_pkg_check_complete', updateCount, latestCount, missingCount)
      console.info('[SourcePackageUpdate] step=check_done update=' + updateCount + ' latest=' + latestCount + ' missing=' + missingCount + ' failed=0')
    } catch (_error) {
      this.packageUpdateStatuses = this.packages.map((source: InstalledSourcePackage): SourcePackageUpdateStatus => {
        return {
          sourceId: source.id,
          status: 'failed',
          localVersion: source.version,
          reasonCode: 'network_error',
        }
      })
      this.statusText = tf('source_pkg_check_failed', this.sourceRedactedReasonText('network_error'))
      console.info('[SourcePackageUpdate] step=check_done update=0 latest=0 missing=0 failed=' + count)
    } finally {
      this.updateCheckBusy = false
    }
  }

  private async updateInstalledPackage(source: InstalledSourcePackage): Promise<void> {
    if (this.updateInstallSourceId.length > 0 || this.indexInstallBusy || this.busy) {
      return
    }
    const entry = this.updateEntry(source.id)
    if (entry === undefined) {
      return
    }
    const url = await this.currentIndexUrlOrPrompt()
    if (url.length === 0) {
      return
    }
    const wasEnabled = source.enabled
    this.updateInstallSourceId = source.id
    this.statusText = tf('source_pkg_update_running', source.name)
    console.info('[SourcePackageUpdate] step=install_start id=' + source.id)
    try {
      const result: SourceIndexInstallResult = await this.sourceIndexService.installPackage(url, entry)
      if (result.ok) {
        if (!wasEnabled) {
          setEnabled(this.context(), source.id, false)
        }
        this.reload()
        const installed = this.installedPackage(source.id)
        this.setUpdateStatus({
          sourceId: source.id,
          status: 'latest',
          remoteEntry: entry,
          remoteVersion: entry.version,
          localVersion: installed?.version ?? entry.version,
        })
        this.statusText = tf('source_pkg_update_done', source.name)
        this.showToast(t('source_pkg_toast_updated'))
        console.info('[SourcePackageUpdate] step=install_done id=' + source.id)
      } else {
        this.setUpdateStatus({
          sourceId: source.id,
          status: 'failed',
          remoteEntry: entry,
          remoteVersion: entry.version,
          localVersion: source.version,
          reasonCode: result.reasonCode,
        })
        this.statusText = tf('source_pkg_update_failed', this.sourceRedactedReasonText(result.reasonCode))
        this.showToast(t('source_pkg_toast_install_failed'))
        console.error('[SourcePackageUpdate] step=install_failed id=' + source.id + ' reason=' + (result.reasonCode ?? 'unknown'))
      }
    } catch (_error) {
      this.setUpdateStatus({
        sourceId: source.id,
        status: 'failed',
        remoteEntry: entry,
        remoteVersion: entry.version,
        localVersion: source.version,
        reasonCode: 'network_error',
      })
      this.statusText = tf('source_pkg_update_failed', this.sourceRedactedReasonText('network_error'))
      this.showToast(t('source_pkg_toast_install_failed'))
      console.error('[SourcePackageUpdate] step=install_failed id=' + source.id + ' reason=network_error')
    } finally {
      this.updateInstallSourceId = ''
    }
  }

  private indexVersionText(entry: SourceIndexEntry): string {
    const installed = this.installedPackage(entry.id)
    if (installed === undefined) {
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
      case 'invalid_response':
      case 'empty_package':
      case 'checksum_mismatch':
      case 'network_not_allowed':
      case 'unsafe_archive_entry':
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
      } else {
        this.statusText = tf('source_pkg_import_failed', this.sourceReasonText(result.reasonCode))
        this.showToast(t('source_pkg_toast_validation_failed'))
      }
      this.reload()
    } catch (_error) {
      this.statusText = tf('source_pkg_import_failed', this.sourceReasonText('import_failed'))
      this.showToast(t('source_pkg_toast_import_failed'))
      this.reload()
    } finally {
      this.busy = false
    }
  }

  private async fetchIndex(): Promise<void> {
    if (this.indexFetchBusy) {
      return
    }
    const url = this.sourceIndexUrl.trim()
    if (url.length === 0) {
      this.indexStatusText = t('source_pkg_prompt_index_url')
      return
    }
    this.indexFetchBusy = true
    this.indexStatusText = t('source_pkg_index_loading')
    this.indexEntries = []
    try {
      await this.sourceIndexService.saveUrl(url)
      const result: SourceIndexFetchResult = await this.sourceIndexService.fetchIndex(url)
      if (result.ok) {
        this.indexEntries = result.entries
        this.indexStatusText = tf('source_pkg_index_loaded', result.entries.length)
      } else {
        this.indexStatusText = tf('source_pkg_index_load_failed', this.sourceReasonText(result.reasonCode))
      }
    } catch (_error) {
      this.indexStatusText = tf('source_pkg_index_load_failed', this.sourceReasonText('network_error'))
    } finally {
      this.indexFetchBusy = false
    }
  }

  private async installIndexEntry(entry: SourceIndexEntry, replaceExisting: boolean = false): Promise<void> {
    if (this.indexInstallBusy || this.busy) {
      return
    }
    const existing = this.installedPackage(entry.id)
    if (existing !== undefined && !replaceExisting) {
      this.showToast(t('source_pkg_toast_already_installed'))
      return
    }
    this.indexInstallBusy = true
    this.indexStatusText = replaceExisting ? tf('source_pkg_update_running', entry.name) : tf('source_pkg_install_running', entry.name)
    try {
      const result: SourceIndexInstallResult = await this.sourceIndexService.installPackage(
        this.sourceIndexUrl.trim(),
        entry,
      )
      if (result.ok) {
        if (existing !== undefined && !existing.enabled) {
          setEnabled(this.context(), existing.id, false)
        }
        this.indexStatusText = replaceExisting ? tf('source_pkg_update_done', entry.name) : tf('source_pkg_install_done', entry.name)
        this.showToast(replaceExisting ? t('source_pkg_toast_updated') : t('source_pkg_toast_install_success'))
        this.reload()
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
    } finally {
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
        if (this.diagnosticsSourceId === source.id) {
          this.diagnosticsSourceId = ''
        }
      }
      this.reload()
    } catch (_error) {
      this.statusText = tf('source_pkg_remove_failed', this.sourceReasonText('unknown'))
    } finally {
      this.busy = false
    }
  }

  private smokePackage(source: InstalledSourcePackage): void {
    const result = runSmoke(source.id)
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

  private validateSettings(source: InstalledSourcePackage): void {
    if (this.settingsValidationSourceId.length > 0) {
      return
    }
    const savedSettings = appSourceSettingsStore.loadForSource(source.id)
    const savedCount = Object.keys(savedSettings).length
    console.info('[SourceSettingsValidation] step=start id=' + source.id + ' saved=' + savedCount)
    this.settingsValidationSourceId = source.id
    this.setSettingsValidationStatus({
      sourceId: source.id,
      status: 'running',
      savedCount,
    })
    const args: SourceSettingsValidationArgs = {}
    const hostHints: SourceSettingsValidationHostHints = { network: true }
    const request: SourceSettingsValidationRequest = {
      type: 'request',
      version: 1,
      requestId: 'settings-validation-' + source.id + '-' + Date.now().toString(),
      operation: 'get_home',
      sourceId: source.id,
      args,
      settings: savedSettings,
      hostHints,
    }
    try {
      const result = runRegisteredSourceRequestById(appSourceRuntimeRegistry, source.id, JSON.stringify(request))
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
      console.error('[SourceSettingsValidation] step=done id=' + source.id + ' ok=false reason=' + reason + ' saved=' + savedCount)
    } catch (_error) {
      const reason = 'settings_validation_failed'
      this.setSettingsValidationStatus({
        sourceId: source.id,
        status: 'fail',
        savedCount,
        reasonCode: reason,
      })
      this.statusText = tf('source_pkg_settings_validation_failed', this.sourceReasonText(reason))
      this.showToast(t('source_pkg_settings_validation_toast_fail'))
      console.error('[SourceSettingsValidation] step=done id=' + source.id + ' ok=false reason=' + reason + ' saved=' + savedCount)
    } finally {
      this.settingsValidationSourceId = ''
    }
  }

  private openSettings(source: InstalledSourcePackage): void {
    this.settingsSourceId = source.id
    this.settingsSourceName = source.name
    this.settingDescriptors = fetchSourceSettingDescriptors(appSourceRuntimeRegistry, source.id)
    const saved = appSourceSettingsStore.loadForSource(source.id)
    const nextDraft: SourceSettingsRecord = {}
    this.settingDescriptors.forEach((descriptor: SourceSettingDescriptor) => {
      if (!descriptor.supported || descriptor.sensitive) {
        return
      }
      const savedValue = saved[descriptor.id]
      if (savedValue !== undefined) {
        nextDraft[descriptor.id] = savedValue
      } else if (descriptor.defaultValue !== undefined) {
        nextDraft[descriptor.id] = descriptor.defaultValue
      }
    })
    this.settingDraft = nextDraft
    this.statusText = this.settingDescriptors.length === 0 ? t('source_pkg_settings_none_detected') : t('source_pkg_settings_editing')
  }

  private closeSettings(): void {
    this.settingsSourceId = ''
    this.settingsSourceName = ''
    this.settingDescriptors = []
    this.settingDraft = {}
  }

  private saveSettings(): void {
    if (this.settingsSourceId.length === 0) {
      return
    }
    appSourceSettingsStore.saveForSource(this.settingsSourceId, this.settingDraft, this.settingDescriptors)
    const savedCount = this.savedSettingsCount(this.settingsSourceId)
    this.setSettingsValidationStatus({
      sourceId: this.settingsSourceId,
      status: 'unknown',
      savedCount,
    })
    this.reload()
    this.statusText = t('source_pkg_settings_saved')
    this.showToast(t('source_pkg_settings_saved'))
    this.closeSettings()
  }

  private updateSettingValue(id: string, value: SourceSettingValue): void {
    const nextDraft: SourceSettingsRecord = {}
    Object.keys(this.settingDraft).forEach((key: string) => {
      nextDraft[key] = this.settingDraft[key]
    })
    nextDraft[id] = value
    this.settingDraft = nextDraft
  }

  private settingStringValue(descriptor: SourceSettingDescriptor): string {
    const value = this.settingDraft[descriptor.id]
    return typeof value === 'string' ? value : ''
  }

  private settingBooleanValue(descriptor: SourceSettingDescriptor): boolean {
    return this.settingDraft[descriptor.id] === true
  }

  private settingNumberValue(descriptor: SourceSettingDescriptor): number {
    const value = this.settingDraft[descriptor.id]
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value
    }
    if (typeof descriptor.defaultValue === 'number' && Number.isFinite(descriptor.defaultValue)) {
      return this.normalizeRangeSetting(descriptor, descriptor.defaultValue)
    }
    return this.normalizeRangeSetting(descriptor, descriptor.minValue ?? 0)
  }

  private settingSelectLabel(descriptor: SourceSettingDescriptor): string {
    const value = this.settingDraft[descriptor.id]
    const selected = typeof value === 'string' ? value : ''
    const option = descriptor.options?.find((item) => item.id === selected)
    return option?.label ?? (selected.length > 0 ? selected : t('source_pkg_not_selected'))
  }

  private settingMultiSelectValue(descriptor: SourceSettingDescriptor): string[] {
    const value = this.settingDraft[descriptor.id]
    return Array.isArray(value) ? value : []
  }

  private settingMultiSelectLabel(descriptor: SourceSettingDescriptor): string {
    const selected = this.settingMultiSelectValue(descriptor)
    if (selected.length === 0) {
      return t('source_pkg_not_selected')
    }
    const labels: string[] = []
    selected.forEach((id: string) => {
      const option = descriptor.options?.find((item: SourceSettingOption): boolean => item.id === id)
      labels.push(option?.label ?? id)
    })
    return labels.join(' / ')
  }

  private setSelectSetting(descriptor: SourceSettingDescriptor, optionId: string): void {
    this.updateSettingValue(descriptor.id, optionId)
    this.settingMenuKey = ''
  }

  private toggleMultiSelectSetting(descriptor: SourceSettingDescriptor, optionId: string): void {
    const selected = this.settingMultiSelectValue(descriptor)
    if (selected.includes(optionId)) {
      this.updateSettingValue(descriptor.id, selected.filter((id: string): boolean => id !== optionId))
      return
    }
    const next = selected.slice()
    next.push(optionId)
    this.updateSettingValue(descriptor.id, next)
  }

  private rangeStep(descriptor: SourceSettingDescriptor): number {
    return descriptor.step !== undefined && descriptor.step > 0 ? descriptor.step : 1
  }

  private rangeMin(descriptor: SourceSettingDescriptor): number {
    return descriptor.minValue ?? 0
  }

  private rangeMax(descriptor: SourceSettingDescriptor): number {
    const minValue = this.rangeMin(descriptor)
    const step = this.rangeStep(descriptor)
    const fallbackMax = Math.max(minValue + step, this.settingNumberValue(descriptor), minValue + step * 10)
    const maxValue = descriptor.maxValue ?? fallbackMax
    return maxValue > minValue ? maxValue : minValue + step
  }

  private normalizeRangeSetting(descriptor: SourceSettingDescriptor, value: number): number {
    let next = Number.isFinite(value) ? value : 0
    if (descriptor.minValue !== undefined && next < descriptor.minValue) {
      next = descriptor.minValue
    }
    if (descriptor.maxValue !== undefined && next > descriptor.maxValue) {
      next = descriptor.maxValue
    }
    return next
  }

  private setRangeSetting(descriptor: SourceSettingDescriptor, value: number): void {
    const next = this.normalizeRangeSetting(descriptor, value)
    this.updateSettingValue(descriptor.id, next)
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

  private sourceMetaText(source: InstalledSourcePackage): string {
    const parts: string[] = ['v' + source.version]
    if (source.lang.length > 0) {
      parts.push(source.lang)
    }
    parts.push(source.nsfw ? 'NSFW' : t('source_pkg_rating_all_ages'))
    parts.push(source.status)
    return parts.join(' · ')
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
      source.lang.length > 0 ? source.lang : t('common_unavailable'),
      source.nsfw ? 'NSFW' : t('source_pkg_rating_all_ages'),
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
    const counts = this.diagnosticsSettingCounts(source.id)
    return tf('source_pkg_diagnostics_settings', counts.total, counts.editable, counts.sensitive, counts.saved)
  }

  private diagnosticsSettingsValidationText(source: InstalledSourcePackage): string {
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
  private SettingSelectMenu(descriptor: SourceSettingDescriptor) {
    Menu() {
      ForEach(descriptor.options ?? [], (option: SourceSettingOption) => {
        MenuItem({
          content: option.label,
          symbolEndIcon: this.settingStringValue(descriptor) === option.id ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
        })
          .onClick(() => {
            this.setSelectSetting(descriptor, option.id)
          })
      }, (option: SourceSettingOption) => option.id)
    }
  }

  @Builder
  private SettingMultiSelectMenu(descriptor: SourceSettingDescriptor) {
    Menu() {
      ForEach(descriptor.options ?? [], (option: SourceSettingOption) => {
        MenuItem({
          content: option.label,
          symbolEndIcon: this.settingMultiSelectValue(descriptor).includes(option.id) ?
            new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined,
        })
          .onClick(() => {
            this.toggleMultiSelectSetting(descriptor, option.id)
          })
      }, (option: SourceSettingOption) => option.id)
    }
  }

  @Builder
  private SettingRangeRow(descriptor: SourceSettingDescriptor) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Column({ space: ThemeConstants.SPACE_XS }) {
        Text(descriptor.label)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${this.settingNumberValue(descriptor)}`)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Slider({
        value: this.settingNumberValue(descriptor),
        min: this.rangeMin(descriptor),
        max: this.rangeMax(descriptor),
        step: this.rangeStep(descriptor),
      })
        .width('100%')
        .selectedColor(ThemeConstants.BRAND_PRIMARY)
        .onChange((value: number) => {
          this.setRangeSetting(descriptor, value)
        })
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private IndexUrlCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(t('source_pkg_index_url_heading'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)

      KomaFormTextField({
        label: 'URL',
        placeholder: 'https://...',
        value: this.sourceIndexUrl,
        submit: () => {
          this.fetchIndex()
        },
        change: (value: string) => {
          this.sourceIndexUrl = value
        },
      })

      Row({ space: ThemeConstants.SPACE_MD }) {
        KomaActionButton({
          label: this.indexFetchBusy ? t('source_pkg_loading') : t('source_pkg_load_sources'),
          kind: 'primary',
          fill: true,
          isEnabled: !this.indexFetchBusy,
          action: () => {
            this.fetchIndex()
          },
        })

        KomaActionButton({
          label: this.busy ? t('source_pkg_importing') : t('source_pkg_local_import'),
          kind: 'secondary',
          fill: true,
          isEnabled: !this.busy,
          accentColor: ThemeConstants.TEXT_SECONDARY,
          strokeColor: ThemeConstants.DIVIDER,
          action: () => {
            this.importPackage()
          },
        })
      }
      .width('100%')

      if (this.indexStatusText.length > 0) {
        Text(this.indexStatusText)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
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
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private RemoteIndexCard(entry: SourceIndexEntry) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(entry.name)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(entry.id)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.hasUpdate(entry)) {
          KomaActionButton({
            label: this.indexInstallBusy ? t('source_pkg_action_updating') : t('source_pkg_action_update'),
            kind: 'primary',
            compact: true,
            controlHeight: ThemeConstants.FILTER_CHIP_HEIGHT,
            isEnabled: !this.indexInstallBusy,
            action: () => {
              this.installIndexEntry(entry, true)
            },
          })
        } else if (this.isSourceInstalled(entry.id)) {
          Text(t('source_pkg_installed'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .backgroundColor(ThemeConstants.SOFT_TINT)
        } else {
          KomaActionButton({
            label: this.indexInstallBusy ? t('source_pkg_installing') : t('source_pkg_install'),
            kind: 'primary',
            compact: true,
            controlHeight: ThemeConstants.FILTER_CHIP_HEIGHT,
            isEnabled: !this.indexInstallBusy,
            action: () => {
              this.installIndexEntry(entry)
            },
          })
        }
      }
      .width('100%')

      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(this.indexVersionText(entry))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
        if (entry.lang.length > 0) {
          Text(entry.lang)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        if (entry.nsfw) {
          Text('NSFW')
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(ThemeConstants.RADIUS_SM)
            .backgroundColor(ThemeConstants.DANGER)
        }
        if (this.hasUpdate(entry)) {
          Text(t('source_pkg_update_available'))
            .fontSize(ThemeConstants.FONT_SIZE_TAG)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(ThemeConstants.RADIUS_SM)
            .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        }
      }
      .width('100%')

      if (entry.description.length > 0) {
        Text(entry.description)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }

      Text(this.sourceIndexTrustMetaText(entry))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.sourceIndexTrustCapabilityText(entry))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
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
      }
      .width('100%')

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }

      Text(sourcePackageTrustBoundaryNotice())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .lineHeight(18)
        .fontColor(ThemeConstants.TEXT_SECONDARY)

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
  private PackageCard(source: InstalledSourcePackage) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Column({ space: ThemeConstants.SPACE_XS }) {
          Text(source.name)
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(source.id)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(source.enabled ? t('source_pkg_enabled') : t('source_pkg_disabled'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(source.enabled ? ThemeConstants.TEXT_ON_BRAND : ThemeConstants.TEXT_SECONDARY)
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .backgroundColor(source.enabled ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.SOFT_TINT)
      }
      .width('100%')

      Text(this.sourceMetaText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)

      Text(this.installedTrustMetaText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.updateStatusText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(this.updateStatusColor(source))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.packageSmokeText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.sourceSettingsText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)

      Text(this.settingsValidationText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.capsText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.installedTrustCapabilityText(source))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: ThemeConstants.SPACE_SM }) {
        if (this.updateEntry(source.id) !== undefined) {
          KomaActionButton({
            label: this.updateActionLabel(source.id),
            kind: 'primary',
            fill: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            isEnabled: this.updateInstallSourceId.length === 0 && !this.indexInstallBusy && !this.busy,
            action: () => {
              this.updateInstalledPackage(source)
            },
          })
        }

        KomaActionButton({
          label: source.enabled ? t('source_pkg_disable') : t('source_pkg_enable'),
          kind: source.enabled ? 'secondary' : 'primary',
          fill: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          accentColor: source.enabled ? ThemeConstants.TEXT_SECONDARY : undefined,
          strokeColor: source.enabled ? ThemeConstants.DIVIDER : undefined,
          action: () => {
            this.togglePackage(source.id)
          },
        })

        KomaActionButton({
          label: 'Smoke',
          kind: 'secondary',
          fill: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.smokePackage(source)
          },
        })
      }
      .width('100%')

      Row({ space: ThemeConstants.SPACE_SM }) {
        KomaActionButton({
          label: t('source_pkg_settings'),
          kind: 'secondary',
          fill: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.openSettings(source)
          },
        })

        KomaActionButton({
          label: this.validateSettingsActionLabel(source.id),
          kind: 'secondary',
          fill: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          isEnabled: this.settingsValidationSourceId.length === 0,
          action: () => {
            this.validateSettings(source)
          },
        })

        KomaActionButton({
          label: this.isDiagnosticsOpen(source.id) ? t('source_pkg_hide_diagnostics') : t('source_pkg_diagnostics'),
          kind: 'secondary',
          fill: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.toggleDiagnostics(source)
          },
        })

        KomaActionButton({
          label: t('source_pkg_delete'),
          kind: 'danger',
          fill: true,
          controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
          action: () => {
            this.removePackage(source)
          },
        })
      }
      .width('100%')

      if (this.isDiagnosticsOpen(source.id)) {
        this.DiagnosticsPanel(source)
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
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
  private SettingsPanel() {
    if (this.settingsSourceId.length > 0) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(this.settingsSourceName)
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(t('source_pkg_settings_title'))
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          KomaActionButton({
            label: t('source_pkg_close'),
            kind: 'ghost',
            compact: true,
            accentColor: ThemeConstants.TEXT_SECONDARY,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            action: () => {
              this.closeSettings()
            },
          })
        }
        .width('100%')

        if (this.settingDescriptors.length === 0) {
          Text(t('source_pkg_no_settings'))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        } else {
          GroupedListSection({ inset: ThemeConstants.SPACE_SM }) {
            ForEach(this.settingDescriptors, (descriptor: SourceSettingDescriptor, index: number) => {
              this.SettingRow(descriptor)
              if (index < this.settingDescriptors.length - 1) {
                ListDivider()
              }
            }, (descriptor: SourceSettingDescriptor) => descriptor.id)
          }
        }

        KomaActionButton({
          label: t('source_pkg_save_settings'),
          kind: 'primary',
          action: () => {
            this.saveSettings()
          },
        })
          .width('100%')
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(ThemeConstants.CARD)
    }
  }

  @Builder
  private SettingRow(descriptor: SourceSettingDescriptor) {
    Column() {
      if (descriptor.sensitive || !descriptor.supported) {
        ConciseListRow({
          title: descriptor.label,
          trailingText: descriptor.sensitive ? t('source_pkg_login_required') : t('source_pkg_unsupported'),
          showChevron: false,
        })
      } else if (descriptor.kind === 'boolean') {
        ConciseListRow({
          title: descriptor.label,
          showChevron: false,
          hasSwitch: true,
          checked: this.settingBooleanValue(descriptor),
          switchAction: (isOn: boolean) => {
            this.updateSettingValue(descriptor.id, isOn)
          },
        })
      } else if (descriptor.kind === 'select') {
        Column() {
          ConciseListRow({
            title: descriptor.label,
            trailingText: this.settingSelectLabel(descriptor),
            trailingDropdown: true,
            action: () => {
              this.settingMenuKey = descriptor.id
            },
          })
        }
          .bindMenu(this.settingMenuKey === descriptor.id, this.SettingSelectMenu(descriptor), {
            placement: Placement.BottomRight,
          })
      } else if (descriptor.kind === 'multiselect') {
        Column() {
          ConciseListRow({
            title: descriptor.label,
            trailingText: this.settingMultiSelectLabel(descriptor),
            trailingDropdown: true,
            action: () => {
              this.settingMenuKey = descriptor.id
            },
          })
        }
          .bindMenu(this.settingMenuKey === descriptor.id, this.SettingMultiSelectMenu(descriptor), {
            placement: Placement.BottomRight,
          })
      } else if (descriptor.kind === 'range') {
        this.SettingRangeRow(descriptor)
      } else if (descriptor.kind === 'group') {
        ConciseListRow({
          title: descriptor.label,
          subtitle: (descriptor.children ?? []).join(' / '),
          showChevron: false,
        })
      } else {
        KomaFormTextField({
          label: descriptor.label,
          value: this.settingStringValue(descriptor),
          change: (value: string) => {
            this.updateSettingValue(descriptor.id, value)
          },
        })
          .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
      }
    }
    .width('100%')
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Column() {
        SecondaryListScaffold({
          listSpace: ThemeConstants.SPACE_MD,
          horizontalPadding: ThemeConstants.SPACE_XL,
          bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
        }) {
          ListItem() {
            this.IndexUrlCard()
          }
          if (this.indexEntries.length > 0) {
            ForEach(this.indexEntries, (entry: SourceIndexEntry) => {
              ListItem() {
                this.RemoteIndexCard(entry)
              }
            }, (entry: SourceIndexEntry) => entry.id)
          }
          ListItem() {
            this.InstalledHeaderCard()
          }
          if (this.packages.length === 0) {
            ListItem() {
              this.EmptyCard()
            }
          }
          if (this.settingsSourceId.length > 0) {
            ListItem() {
              this.SettingsPanel()
            }
          }
          ForEach(this.packages, (source: InstalledSourcePackage) => {
            ListItem() {
              this.PackageCard(source)
            }
          }, (source: InstalledSourcePackage) => `${source.id}-${source.enabled}`)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
    }
  }
}

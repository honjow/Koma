import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
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
  SOURCE_PACKAGE_TRUST_BOUNDARY_NOTICE,
} from '../sourceRuntime/SourcePackageTrustPolicy'

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

@Component
export struct SourcePackageManagerPage {
  @State private packages: InstalledSourcePackage[] = []
  @State private busy: boolean = false
  @State private statusText: string = ''
  @State private settingsSourceId: string = ''
  @State private settingsSourceName: string = ''
  @State private settingDescriptors: SourceSettingDescriptor[] = []
  @State private settingDraft: SourceSettingsRecord = {}
  @State private sourceIndexUrl: string = ''
  @State private indexEntries: SourceIndexEntry[] = []
  @State private indexFetchBusy: boolean = false
  @State private indexInstallBusy: boolean = false
  @State private indexStatusText: string = ''
  @State private packageUpdateStatuses: SourcePackageUpdateStatus[] = []
  @State private updateCheckBusy: boolean = false
  @State private updateInstallSourceId: string = ''
  @State private settingsAvailability: Record<string, string> = {}
  @State private settingsValidationStatuses: SourceSettingsValidationStatus[] = []
  @State private settingsValidationSourceId: string = ''
  @State private diagnosticsSourceId: string = ''
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
        availability[source.id] = '设置项：无'
      } else {
        const editable = descriptors.filter((descriptor: SourceSettingDescriptor): boolean => descriptor.supported && !descriptor.sensitive).length
        availability[source.id] = '设置项：' + editable.toString() + '/' + descriptors.length.toString() + ' 可编辑'
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
        return '更新：检查中（手动）'
      case 'latest':
        return '更新：已是最新 v' + (status.localVersion ?? source.version)
      case 'update':
        return '更新：可更新 v' + (status.localVersion ?? source.version) + ' → v' + (status.remoteVersion ?? '')
      case 'missing':
        return '更新：索引中未找到（仅检查当前配置索引）'
      case 'failed':
        return '更新：检查失败：' + this.sourceRedactedReasonText(status.reasonCode)
      case 'unknown':
      default:
        return '更新：未检查'
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
    return this.updateInstallSourceId === sourceId ? '更新中' : '更新'
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
      this.statusText = '请输入源索引地址'
      this.indexStatusText = '请输入源索引地址'
      this.showToast('请输入源索引地址')
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
    this.statusText = '正在检查更新...'
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
        this.statusText = '检查失败：' + this.sourceRedactedReasonText(result.reasonCode)
        console.info('[SourcePackageUpdate] step=check_done update=0 latest=0 missing=0 failed=' + count)
        return
      }

      this.indexEntries = result.entries
      this.indexStatusText = '已加载 ' + result.entries.length + ' 个源'
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
      this.statusText = '检查完成：可更新 ' + updateCount.toString() + '，最新 ' + latestCount.toString() + '，未找到 ' + missingCount.toString()
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
      this.statusText = '检查失败：' + this.sourceRedactedReasonText('network_error')
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
    this.statusText = '正在更新 ' + source.name + '...'
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
        this.statusText = '已更新 ' + source.name
        this.showToast('源包已更新')
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
        this.statusText = '更新失败：' + this.sourceRedactedReasonText(result.reasonCode)
        this.showToast('源包安装失败')
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
      this.statusText = '更新失败：' + this.sourceRedactedReasonText('network_error')
      this.showToast('源包安装失败')
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
    return '已装 v' + installed.version + ' / 索引 v' + entry.version
  }

  private sourceReasonText(reasonCode: string | undefined): string {
    const code = reasonCode ?? 'unknown'
    switch (code) {
      case 'invalid_url':
        return '索引地址必须是 http 或 https'
      case 'network_error':
        return '网络请求失败'
      case 'http_error':
        return '服务器返回错误状态'
      case 'invalid_index_format':
        return '源索引格式不正确'
      case 'invalid_json':
        return '源索引 JSON 无法解析'
      case 'invalid_pkg_url':
        return '源包地址不正确'
      case 'invalid_response':
        return '源包下载响应无效'
      case 'empty_package':
        return '源包为空'
      case 'checksum_mismatch':
        return '源包校验和不匹配'
      case 'network_not_allowed':
        return '源包请求了当前不允许的网络/安装能力'
      case 'unsafe_archive_entry':
        return '源包包含不安全文件路径'
      case 'missing_manifest':
        return '源包缺少 manifest'
      case 'missing_wasm':
        return '源包缺少 WASM 文件'
      case 'manifest_invalid':
        return '源包 manifest 不符合要求'
      case 'validation_failed':
        return '源包校验失败'
      case 'register_failed':
        return '源包注册失败'
      case 'import_failed':
        return '源包导入失败'
      case 'duplicate_source_id':
        return '源 ID 已存在'
      case 'missing_source_id':
        return '源 ID 缺失'
      case 'source_id_not_registered':
        return '源包未注册'
      case 'source_id_mismatch':
        return '请求源 ID 与源包不一致'
      case 'malformed_json':
        return '运行请求格式错误'
      case 'missing_or_invalid_operation':
        return '运行请求缺少有效操作'
      case 'request_too_large':
        return '运行请求过大'
      case 'result_too_large':
        return '运行结果过大'
      case 'malformed_result':
        return '运行结果格式错误'
      case 'cancelled':
        return '运行已取消'
      case 'timeout':
        return '运行超时'
      case 'smoke_failed':
        return 'Smoke 检查失败'
      case 'missing_response':
        return '源运行未返回结果'
      case 'runtime_response_not_ok':
        return '源运行返回失败'
      case 'settings_validation_failed':
        return '设置验证失败'
      case 'ok':
        return '正常'
      case 'unknown':
        return '未知错误'
      default:
        return '错误代码：' + code
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
        return '原因已隐藏（详情已写入诊断日志）'
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
    this.statusText = '正在导入源包...'
    try {
      const uri = await pickSourcePackageArchive(this.context())
      if (uri === undefined) {
        this.statusText = ''
        return
      }
      const result = await installFromArchive(this.context(), uri)
      if (result.ok) {
        this.statusText = '导入成功'
        this.showToast('源包已导入')
      } else {
        this.statusText = '导入失败：' + this.sourceReasonText(result.reasonCode)
        this.showToast('源包校验失败')
      }
      this.reload()
    } catch (_error) {
      this.statusText = '导入失败：' + this.sourceReasonText('import_failed')
      this.showToast('源包导入失败')
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
      this.indexStatusText = '请输入源索引地址'
      return
    }
    this.indexFetchBusy = true
    this.indexStatusText = '正在加载源列表...'
    this.indexEntries = []
    try {
      await this.sourceIndexService.saveUrl(url)
      const result: SourceIndexFetchResult = await this.sourceIndexService.fetchIndex(url)
      if (result.ok) {
        this.indexEntries = result.entries
        this.indexStatusText = '已加载 ' + result.entries.length + ' 个源'
      } else {
        this.indexStatusText = '加载失败：' + this.sourceReasonText(result.reasonCode)
      }
    } catch (_error) {
      this.indexStatusText = '加载失败：' + this.sourceReasonText('network_error')
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
      this.showToast('此源已安装')
      return
    }
    this.indexInstallBusy = true
    this.indexStatusText = replaceExisting ? ('正在更新 ' + entry.name + '...') : ('正在安装 ' + entry.name + '...')
    try {
      const result: SourceIndexInstallResult = await this.sourceIndexService.installPackage(
        this.sourceIndexUrl.trim(),
        entry,
      )
      if (result.ok) {
        if (existing !== undefined && !existing.enabled) {
          setEnabled(this.context(), existing.id, false)
        }
        this.indexStatusText = replaceExisting ? ('已更新 ' + entry.name) : ('已安装 ' + entry.name)
        this.showToast(replaceExisting ? '源包已更新' : '源包安装成功')
        this.reload()
      } else {
        this.indexStatusText = (replaceExisting ? '更新失败：' : '安装失败：') + this.sourceReasonText(result.reasonCode)
        this.showToast('源包安装失败')
      }
    } catch (_error) {
      this.indexStatusText = (replaceExisting ? '更新失败：' : '安装失败：') + this.sourceReasonText('network_error')
      this.showToast('源包安装失败')
    } finally {
      this.indexInstallBusy = false
    }
  }

  private togglePackage(id: string): void {
    const source = this.packages.find((item: InstalledSourcePackage): boolean => item.id === id)
    if (source === undefined) {
      this.statusText = '源包不可用'
      return
    }
    const enabled = !source.enabled
    if (setEnabled(this.context(), source.id, enabled)) {
      this.statusText = enabled ? '已启用' : '已停用'
      this.reload()
    } else {
      this.statusText = '源包不可用'
    }
  }

  private async removePackage(source: InstalledSourcePackage): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    try {
      const removed = await remove(this.context(), source.id)
      this.statusText = removed ? '已删除源包' : '源包不可用'
      if (removed) {
        this.clearUpdateStatus(source.id)
        this.clearSettingsValidationStatus(source.id)
        if (this.diagnosticsSourceId === source.id) {
          this.diagnosticsSourceId = ''
        }
      }
      this.reload()
    } catch (_error) {
      this.statusText = '删除失败：' + this.sourceReasonText('unknown')
    } finally {
      this.busy = false
    }
  }

  private smokePackage(source: InstalledSourcePackage): void {
    const result = runSmoke(source.id)
    if (result.ok) {
      this.statusText = 'Smoke PASS'
      this.showToast('Smoke PASS')
    } else {
      this.statusText = 'Smoke FAIL：' + this.sourceReasonText(result.reasonCode)
      this.showToast('Smoke FAIL')
    }
    this.reload()
  }

  private validateSettingsActionLabel(sourceId: string): string {
    return this.settingsValidationSourceId === sourceId ? '验证中' : '验证设置'
  }

  private settingsValidationText(source: InstalledSourcePackage): string {
    const status = this.settingsValidationStatus(source.id)
    const savedText = ' · 已保存 ' + status.savedCount.toString() + ' 项'
    switch (status.status) {
      case 'running':
        return '设置验证：验证中' + savedText
      case 'pass':
        return '设置验证：PASS' + savedText
      case 'fail':
        return '设置验证：FAIL：' + this.sourceReasonText(status.reasonCode) + savedText
      case 'unknown':
      default:
        return '设置验证：未运行' + savedText
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
        this.statusText = '设置验证 PASS'
        this.showToast('设置验证 PASS')
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
      this.statusText = '设置验证失败：' + this.sourceReasonText(reason)
      this.showToast('设置验证 FAIL')
      console.error('[SourceSettingsValidation] step=done id=' + source.id + ' ok=false reason=' + reason + ' saved=' + savedCount)
    } catch (_error) {
      const reason = 'settings_validation_failed'
      this.setSettingsValidationStatus({
        sourceId: source.id,
        status: 'fail',
        savedCount,
        reasonCode: reason,
      })
      this.statusText = '设置验证失败：' + this.sourceReasonText(reason)
      this.showToast('设置验证 FAIL')
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
    this.statusText = this.settingDescriptors.length === 0 ? '未发现可配置项' : '正在编辑源设置'
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
    this.statusText = '源设置已保存'
    this.showToast('源设置已保存')
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

  private settingSelectLabel(descriptor: SourceSettingDescriptor): string {
    const value = this.settingDraft[descriptor.id]
    const selected = typeof value === 'string' ? value : ''
    const option = descriptor.options?.find((item) => item.id === selected)
    return option?.label ?? (selected.length > 0 ? selected : '未选择')
  }

  private cycleSelectSetting(descriptor: SourceSettingDescriptor): void {
    const options = descriptor.options ?? []
    if (options.length === 0) {
      return
    }
    const current = this.settingDraft[descriptor.id]
    const currentId = typeof current === 'string' ? current : ''
    const currentIndex = options.findIndex((item) => item.id === currentId)
    const nextIndex = currentIndex < 0 || currentIndex >= options.length - 1 ? 0 : currentIndex + 1
    this.updateSettingValue(descriptor.id, options[nextIndex].id)
  }

  private capabilityLabel(capability: string): string {
    if (capability.startsWith('hostImports:')) {
      return '受控宿主接口 ' + capability.replace('hostImports:', '') + ' 项'
    }
    switch (capability) {
      case 'search':
        return '搜索'
      case 'detail':
        return '详情'
      case 'chapters':
        return '章节'
      case 'pages':
        return '页面'
      case 'network':
        return '网络访问'
      default:
        return capability
    }
  }

  private capsText(source: InstalledSourcePackage): string {
    return this.capabilitySummaryText(source.capabilities)
  }

  private capabilitySummaryText(capabilities: string[]): string {
    if (capabilities.length === 0) {
      return '能力：未声明'
    }
    const labels: string[] = []
    capabilities.forEach((capability: string) => {
      labels.push(this.capabilityLabel(capability))
    })
    return '能力：' + labels.join(' / ')
  }

  private installedTrustSummary(source: InstalledSourcePackage): SourcePackageTrustSummary {
    return installedSourceTrustSummary(source, this.capabilitySummaryText(source.capabilities).replace('能力：', ''))
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
    parts.push(source.nsfw ? 'NSFW' : '全年龄')
    parts.push(source.status)
    return parts.join(' · ')
  }

  private sourceSettingsText(source: InstalledSourcePackage): string {
    return this.settingsAvailability[source.id] ?? '设置项：未检查'
  }

  private diagnosticsSourceMetaText(source: InstalledSourcePackage): string {
    return 'id: ' + source.id + ' · name: ' + source.name + ' · enabled: ' + (source.enabled ? 'true' : 'false') + ' · imported: ' + (source.status === 'imported' ? 'true' : 'false')
  }

  private diagnosticsVersionText(source: InstalledSourcePackage): string {
    return 'version: ' + source.version + ' · language: ' + (source.lang.length > 0 ? source.lang : 'unknown') + ' · rating: ' + (source.nsfw ? 'NSFW' : '全年龄')
  }

  private diagnosticsSmokeText(source: InstalledSourcePackage): string {
    const reason = source.lastDiagnosticMessage.length > 0 ? this.sourceReasonText(source.lastDiagnosticMessage) : '未运行'
    return 'Smoke：' + source.smokeStatus + ' · ' + reason
  }

  private diagnosticsUpdateReasonText(status: SourcePackageUpdateStatus): string {
    switch (status.status) {
      case 'checking':
        return '检查中'
      case 'latest':
      case 'update':
        return this.sourceReasonText(status.reasonCode ?? 'ok')
      case 'missing':
        return '索引中未找到'
      case 'failed':
        return this.sourceRedactedReasonText(status.reasonCode)
      case 'unknown':
      default:
        return '未检查'
    }
  }

  private diagnosticsUpdateText(source: InstalledSourcePackage): string {
    const status = this.updateStatus(source.id)
    const localVersion = status.localVersion ?? source.version
    const remoteVersion = status.remoteVersion ?? 'unknown'
    return 'Update：' + status.status + ' · localVersion=' + localVersion + ' · remoteVersion=' + remoteVersion + ' · ' + this.diagnosticsUpdateReasonText(status)
  }

  private diagnosticsSettingsText(source: InstalledSourcePackage): string {
    const counts = this.diagnosticsSettingCounts(source.id)
    return 'Settings descriptors：total=' + counts.total.toString() + ' · editable=' + counts.editable.toString() + ' · sensitive=' + counts.sensitive.toString() + ' · saved=' + counts.saved.toString()
  }

  private diagnosticsSettingsValidationText(source: InstalledSourcePackage): string {
    const status = this.settingsValidationStatus(source.id)
    const reason = status.status === 'fail' ? this.sourceReasonText(status.reasonCode) : (status.status === 'running' ? '验证中' : (status.status === 'pass' ? '正常' : '未运行'))
    return 'Settings validation：' + status.status + ' · saved=' + status.savedCount.toString() + ' · ' + reason
  }

  private diagnosticsTrustText(source: InstalledSourcePackage): string {
    const summary = this.installedTrustSummary(source)
    return 'Trust：' + summary.provenanceLabel + ' · ' + summary.verificationLabel + ' · ' + summary.identityLabel
  }

  @Builder
  private IndexUrlCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text('源索引地址')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)

      TextInput({ text: this.sourceIndexUrl, placeholder: 'https://…' })
        .height(ThemeConstants.BUTTON_HEIGHT)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .placeholderColor(ThemeConstants.TEXT_SECONDARY)
        .backgroundColor(ThemeConstants.CARD)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .onChange((value: string) => {
          this.sourceIndexUrl = value
        })
        .onSubmit(() => {
          this.fetchIndex()
        })

      Row({ space: ThemeConstants.SPACE_MD }) {
        Button(this.indexFetchBusy ? '加载中' : '加载源列表')
          .height(ThemeConstants.BUTTON_HEIGHT)
          .layoutWeight(1)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
          .enabled(!this.indexFetchBusy)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.fetchIndex()
          })

        Button(this.busy ? '导入中' : '本地导入')
          .height(ThemeConstants.BUTTON_HEIGHT)
          .layoutWeight(1)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .enabled(!this.busy)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ThemeConstants.DIVIDER })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.importPackage()
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

      Text(SOURCE_PACKAGE_TRUST_BOUNDARY_NOTICE)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .lineHeight(18)
        .fontColor(ThemeConstants.TEXT_SECONDARY)

      Text('源包更新只会在你点按检查更新时读取当前填写或已保存的源索引地址；不会后台定时检查，也不会发送更新提醒。')
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
          Button(this.indexInstallBusy ? '更新中' : '更新')
            .height(ThemeConstants.FILTER_CHIP_HEIGHT)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
            .enabled(!this.indexInstallBusy)
            .backgroundColor(ThemeConstants.BRAND_PRIMARY)
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .onClick(() => {
              this.installIndexEntry(entry, true)
            })
        } else if (this.isSourceInstalled(entry.id)) {
          Text('已安装')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .backgroundColor(ThemeConstants.SOFT_TINT)
        } else {
          Button(this.indexInstallBusy ? '安装中' : '安装')
            .height(ThemeConstants.FILTER_CHIP_HEIGHT)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
            .enabled(!this.indexInstallBusy)
            .backgroundColor(ThemeConstants.BRAND_PRIMARY)
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .onClick(() => {
              this.installIndexEntry(entry)
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
          Text('可更新')
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
          Text('已安装源包')
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
          Text(this.packages.length.toString() + ' 个源')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Button(this.updateCheckBusy ? '检查中' : '检查更新')
          .height(ThemeConstants.FILTER_CHIP_HEIGHT)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
          .enabled(!this.updateCheckBusy && !this.indexFetchBusy)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.checkInstalledUpdates()
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

      Text(SOURCE_PACKAGE_TRUST_BOUNDARY_NOTICE)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .lineHeight(18)
        .fontColor(ThemeConstants.TEXT_SECONDARY)

      Text('检查更新为手动操作，仅对用户导入或用户配置索引中的源包生效。')
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
      Text('暂无已安装源包')
        .fontSize(ThemeConstants.FONT_SIZE_TITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text('输入源索引地址加载源列表，或通过本地导入打开 .koma / .koma-source.zip / .zip 源包。')
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

        Text(source.enabled ? '启用' : '停用')
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

      Text('Smoke：' + source.smokeStatus + (source.lastDiagnosticMessage.length > 0 ? (' · ' + this.sourceReasonText(source.lastDiagnosticMessage)) : ''))
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
          Button(this.updateActionLabel(source.id))
            .height(ThemeConstants.ACTION_CHIP_HEIGHT)
            .layoutWeight(1)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
            .enabled(this.updateInstallSourceId.length === 0 && !this.indexInstallBusy && !this.busy)
            .backgroundColor(ThemeConstants.BRAND_PRIMARY)
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .onClick(() => {
              this.updateInstalledPackage(source)
            })
        }

        Button(source.enabled ? '停用' : '启用')
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .layoutWeight(1)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(source.enabled ? ThemeConstants.TEXT_SECONDARY : ThemeConstants.TEXT_ON_BRAND)
          .backgroundColor(source.enabled ? Color.Transparent : ThemeConstants.BRAND_PRIMARY)
          .border({ width: 1, color: source.enabled ? ThemeConstants.DIVIDER : ThemeConstants.BRAND_PRIMARY })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.togglePackage(source.id)
          })

        Button('Smoke')
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .layoutWeight(1)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ThemeConstants.BRAND_PRIMARY })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.smokePackage(source)
          })
      }
      .width('100%')

      Row({ space: ThemeConstants.SPACE_SM }) {
        Button('设置')
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .layoutWeight(1)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ThemeConstants.BRAND_PRIMARY })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.openSettings(source)
          })

        Button(this.validateSettingsActionLabel(source.id))
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .layoutWeight(1)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .enabled(this.settingsValidationSourceId.length === 0)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ThemeConstants.BRAND_PRIMARY })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.validateSettings(source)
          })

        Button(this.isDiagnosticsOpen(source.id) ? '收起诊断' : '诊断')
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .layoutWeight(1)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ThemeConstants.BRAND_PRIMARY })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.toggleDiagnostics(source)
          })

        Button('删除')
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .layoutWeight(1)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.DANGER)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ThemeConstants.DANGER })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.removePackage(source)
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
        Text('源运行诊断')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)

        Button('刷新诊断')
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: ThemeConstants.BRAND_PRIMARY })
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.refreshDiagnostics(source)
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
            Text('源设置')
              .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('关闭')
            .height(ThemeConstants.ACTION_CHIP_HEIGHT)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.closeSettings()
            })
        }
        .width('100%')

        if (this.settingDescriptors.length === 0) {
          Text('此源包未提供设置项')
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        } else {
          ForEach(this.settingDescriptors, (descriptor: SourceSettingDescriptor) => {
            this.SettingRow(descriptor)
          }, (descriptor: SourceSettingDescriptor) => descriptor.id)
        }

        Button('保存设置')
          .height(ThemeConstants.BUTTON_HEIGHT)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .onClick(() => {
            this.saveSettings()
          })
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(ThemeConstants.CARD)
    }
  }

  @Builder
  private SettingRow(descriptor: SourceSettingDescriptor) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      if (descriptor.sensitive || !descriptor.supported) {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(descriptor.label)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          Text(descriptor.sensitive ? '需要登录配置（暂未启用）' : '暂不支持')
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .width('100%')
      } else if (descriptor.kind === 'boolean') {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(descriptor.label)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.settingBooleanValue(descriptor) })
            .onChange((isOn: boolean) => {
              this.updateSettingValue(descriptor.id, isOn)
            })
        }
        .width('100%')
      } else if (descriptor.kind === 'select') {
        Row({ space: ThemeConstants.SPACE_SM }) {
          Text(descriptor.label)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          Button(this.settingSelectLabel(descriptor))
            .height(ThemeConstants.ACTION_CHIP_HEIGHT)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: ThemeConstants.DIVIDER })
            .borderRadius(ThemeConstants.RADIUS_CHIP)
            .onClick(() => {
              this.cycleSelectSetting(descriptor)
            })
        }
        .width('100%')
      } else if (descriptor.kind === 'group') {
        Text(descriptor.label)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
        Text((descriptor.children ?? []).join(' / '))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      } else {
        Text(descriptor.label)
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
        TextInput({ text: this.settingStringValue(descriptor) })
          .height(ThemeConstants.ACTION_CHIP_HEIGHT)
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .onChange((value: string) => {
            this.updateSettingValue(descriptor.id, value)
          })
      }
    }
    .width('100%')
    .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_SM })
    .border({ width: { bottom: 1 }, color: ThemeConstants.DIVIDER })
  }

  build() {
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

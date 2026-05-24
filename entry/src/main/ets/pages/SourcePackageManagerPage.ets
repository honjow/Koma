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

  private isSourceInstalled(entryId: string): boolean {
    return this.installedSourceIds().indexOf(entryId) >= 0
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
        this.statusText = '导入失败：' + (result.reasonCode ?? 'validation_failed')
        this.showToast('源包校验失败')
      }
      this.reload()
    } catch (error) {
      const e = error as Error
      this.statusText = '导入失败：' + e.message
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
        this.indexStatusText = '加载失败：' + (result.reasonCode ?? 'unknown')
      }
    } catch (error) {
      const e = error as Error
      this.indexStatusText = '加载失败：' + e.message
    } finally {
      this.indexFetchBusy = false
    }
  }

  private async installIndexEntry(entry: SourceIndexEntry): Promise<void> {
    if (this.indexInstallBusy || this.busy) {
      return
    }
    if (this.isSourceInstalled(entry.id)) {
      this.showToast('此源已安装')
      return
    }
    this.indexInstallBusy = true
    this.indexStatusText = '正在安装 ' + entry.name + '...'
    try {
      const result: SourceIndexInstallResult = await this.sourceIndexService.installPackage(
        this.sourceIndexUrl.trim(),
        entry,
      )
      if (result.ok) {
        this.indexStatusText = '已安装 ' + entry.name
        this.showToast('源包安装成功')
        this.reload()
      } else {
        this.indexStatusText = '安装失败：' + (result.reasonCode ?? 'unknown')
        this.showToast('源包安装失败')
      }
    } catch (error) {
      const e = error as Error
      this.indexStatusText = '安装失败：' + e.message
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
      this.reload()
    } catch (error) {
      const e = error as Error
      this.statusText = '删除失败：' + e.message
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
      this.statusText = 'Smoke FAIL：' + (result.reasonCode ?? 'smoke_failed')
      this.showToast('Smoke FAIL')
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

  private capsText(source: InstalledSourcePackage): string {
    if (source.capabilities.length === 0) {
      return 'capabilities: none'
    }
    return 'capabilities: ' + source.capabilities.join(', ')
  }

  @Builder
  private IndexUrlCard() {
    Column({ space: 12 }) {
      Text('源索引地址')
        .width('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))

      TextInput({ text: this.sourceIndexUrl, placeholder: 'https://…' })
        .height(40)
        .width('100%')
        .fontSize(14)
        .fontColor($r('app.color.koma_text_primary'))
        .placeholderColor($r('app.color.koma_text_secondary'))
        .backgroundColor($r('app.color.koma_card'))
        .borderRadius(8)
        .onChange((value: string) => {
          this.sourceIndexUrl = value
        })
        .onSubmit(() => {
          this.fetchIndex()
        })

      Row({ space: 10 }) {
        Button(this.indexFetchBusy ? '加载中' : '加载源列表')
          .height(38)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(Color.White)
          .enabled(!this.indexFetchBusy)
          .backgroundColor($r('app.color.koma_accent'))
          .borderRadius(8)
          .onClick(() => {
            this.fetchIndex()
          })

        Button(this.busy ? '导入中' : '本地导入')
          .height(38)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
          .enabled(!this.busy)
          .backgroundColor('#00000000')
          .border({ width: 1, color: '#338F837D' })
          .borderRadius(8)
          .onClick(() => {
            this.importPackage()
          })
      }
      .width('100%')

      if (this.indexStatusText.length > 0) {
        Text(this.indexStatusText)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor($r('app.color.koma_text_secondary'))
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private RemoteIndexCard(entry: SourceIndexEntry) {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(entry.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(entry.id)
            .fontSize(12)
            .fontColor($r('app.color.koma_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.isSourceInstalled(entry.id)) {
          Text('已安装')
            .fontSize(12)
            .fontColor($r('app.color.koma_accent'))
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(8)
            .backgroundColor('#148F837D')
        } else {
          Button(this.indexInstallBusy ? '安装中' : '安装')
            .height(34)
            .fontSize(13)
            .fontColor(Color.White)
            .enabled(!this.indexInstallBusy)
            .backgroundColor($r('app.color.koma_accent'))
            .borderRadius(8)
            .onClick(() => {
              this.installIndexEntry(entry)
            })
        }
      }
      .width('100%')

      Row({ space: 8 }) {
        Text('v' + entry.version)
          .fontSize(12)
          .fontColor($r('app.color.koma_text_secondary'))
        if (entry.lang.length > 0) {
          Text(entry.lang)
            .fontSize(12)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        if (entry.nsfw) {
          Text('NSFW')
            .fontSize(11)
            .fontColor(Color.White)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(4)
            .backgroundColor('#A13D32')
        }
      }
      .width('100%')

      if (entry.description.length > 0) {
        Text(entry.description)
          .width('100%')
          .fontSize(13)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontColor($r('app.color.koma_text_secondary'))
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private InstalledHeaderCard() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('已安装源包')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.koma_text_primary'))
          Text(this.packages.length.toString() + ' 个源')
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .width('100%')
          .fontSize(13)
          .lineHeight(20)
          .fontColor($r('app.color.koma_text_secondary'))
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private EmptyCard() {
    Column({ space: 8 }) {
      Text('暂无已安装源包')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('输入源索引地址加载源列表，或通过本地导入打开 .koma / .koma-source.zip / .zip 源包。')
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding(20)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private PackageCard(source: InstalledSourcePackage) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        Column({ space: 5 }) {
          Text(source.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(source.id)
            .fontSize(12)
            .fontColor($r('app.color.koma_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(source.enabled ? '启用' : '停用')
          .fontSize(12)
          .fontColor(source.enabled ? Color.White : $r('app.color.koma_text_secondary'))
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .borderRadius(8)
          .backgroundColor(source.enabled ? $r('app.color.koma_accent') : '#1F8F837D')
      }
      .width('100%')

      Text('v' + source.version + ' · ' + source.status)
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))

      Text(this.capsText(source))
        .width('100%')
        .fontSize(12)
        .fontColor($r('app.color.koma_text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Row({ space: 8 }) {
        Button(source.enabled ? '停用' : '启用')
          .height(36)
          .layoutWeight(1)
          .fontSize(13)
          .fontColor(source.enabled ? $r('app.color.koma_text_secondary') : Color.White)
          .backgroundColor(source.enabled ? '#00000000' : $r('app.color.koma_accent'))
          .border({ width: 1, color: source.enabled ? '#338F837D' : $r('app.color.koma_accent') })
          .borderRadius(8)
          .onClick(() => {
            this.togglePackage(source.id)
          })

        Button('Smoke')
          .height(36)
          .layoutWeight(1)
          .fontSize(13)
          .fontColor($r('app.color.koma_accent'))
          .backgroundColor('#00000000')
          .border({ width: 1, color: $r('app.color.koma_accent') })
          .borderRadius(8)
          .onClick(() => {
            this.smokePackage(source)
          })

        Button('设置')
          .height(36)
          .layoutWeight(1)
          .fontSize(13)
          .fontColor($r('app.color.koma_accent'))
          .backgroundColor('#00000000')
          .border({ width: 1, color: $r('app.color.koma_accent') })
          .borderRadius(8)
          .onClick(() => {
            this.openSettings(source)
          })

        Button('删除')
          .height(36)
          .layoutWeight(1)
          .fontSize(13)
          .fontColor('#A13D32')
          .backgroundColor('#00000000')
          .border({ width: 1, color: '#33A13D32' })
          .borderRadius(8)
          .onClick(() => {
            this.removePackage(source)
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private SettingsPanel() {
    if (this.settingsSourceId.length > 0) {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text(this.settingsSourceName)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.koma_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('源设置')
              .fontSize(12)
              .fontColor($r('app.color.koma_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('关闭')
            .height(32)
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
            .backgroundColor('#00000000')
            .onClick(() => {
              this.closeSettings()
            })
        }
        .width('100%')

        if (this.settingDescriptors.length === 0) {
          Text('此源包未提供设置项')
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
        } else {
          ForEach(this.settingDescriptors, (descriptor: SourceSettingDescriptor) => {
            this.SettingRow(descriptor)
          }, (descriptor: SourceSettingDescriptor) => descriptor.id)
        }

        Button('保存设置')
          .height(38)
          .width('100%')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.koma_accent'))
          .borderRadius(8)
          .onClick(() => {
            this.saveSettings()
          })
      }
      .width('100%')
      .padding(16)
      .borderRadius(8)
      .backgroundColor($r('app.color.koma_card'))
    }
  }

  @Builder
  private SettingRow(descriptor: SourceSettingDescriptor) {
    Column({ space: 6 }) {
      if (descriptor.sensitive || !descriptor.supported) {
        Row({ space: 8 }) {
          Text(descriptor.label)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_primary'))
            .layoutWeight(1)
          Text(descriptor.sensitive ? '需要登录配置（暂未启用）' : '暂不支持')
            .fontSize(12)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        .width('100%')
      } else if (descriptor.kind === 'boolean') {
        Row({ space: 8 }) {
          Text(descriptor.label)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_primary'))
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.settingBooleanValue(descriptor) })
            .onChange((isOn: boolean) => {
              this.updateSettingValue(descriptor.id, isOn)
            })
        }
        .width('100%')
      } else if (descriptor.kind === 'select') {
        Row({ space: 8 }) {
          Text(descriptor.label)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_primary'))
            .layoutWeight(1)
          Button(this.settingSelectLabel(descriptor))
            .height(32)
            .fontSize(13)
            .fontColor($r('app.color.koma_accent'))
            .backgroundColor('#00000000')
            .border({ width: 1, color: '#338F837D' })
            .borderRadius(8)
            .onClick(() => {
              this.cycleSelectSetting(descriptor)
            })
        }
        .width('100%')
      } else if (descriptor.kind === 'group') {
        Text(descriptor.label)
          .width('100%')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
        Text((descriptor.children ?? []).join(' / '))
          .width('100%')
          .fontSize(12)
          .fontColor($r('app.color.koma_text_secondary'))
      } else {
        Text(descriptor.label)
          .width('100%')
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
        TextInput({ text: this.settingStringValue(descriptor) })
          .height(36)
          .fontSize(13)
          .onChange((value: string) => {
            this.updateSettingValue(descriptor.id, value)
          })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 1 }, color: '#148F837D' })
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 14,
        horizontalPadding: 20,
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
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

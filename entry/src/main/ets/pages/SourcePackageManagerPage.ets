import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ThemeConstants } from '../theme/ThemeConstants'
import {
  InstalledSourcePackage,
  installFromArchive,
  listInstalled,
  pickSourcePackageArchive,
  remove,
  runSmoke,
  setEnabled,
} from '../sourceRuntime/SourceRuntimeAppRegistry'

@Component
export struct SourcePackageManagerPage {
  @State private packages: InstalledSourcePackage[] = []
  @State private busy: boolean = false
  @State private statusText: string = ''

  aboutToAppear(): void {
    this.reload()
  }

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private reload(): void {
    this.packages = listInstalled()
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

  private capsText(source: InstalledSourcePackage): string {
    if (source.capabilities.length === 0) {
      return 'capabilities: none'
    }
    return 'capabilities: ' + source.capabilities.join(', ')
  }

  @Builder
  private HeaderCard() {
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

        Button(this.busy ? '导入中' : '导入')
          .height(36)
          .fontSize(14)
          .fontColor(Color.White)
          .enabled(!this.busy)
          .backgroundColor($r('app.color.koma_accent'))
          .borderRadius(8)
          .onClick(() => {
            this.importPackage()
          })
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
      Text('从本地文件导入 .koma / .koma-source.zip / .zip 源包。')
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

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 14,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20,
      }) {
        ListItem() {
          this.HeaderCard()
        }
        if (this.packages.length === 0) {
          ListItem() {
            this.EmptyCard()
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

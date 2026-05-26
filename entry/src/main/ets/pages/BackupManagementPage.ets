import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  BACKUP_ACCEPTED_SCHEMA_VERSIONS,
  BACKUP_ENCRYPTION_PLAN_LABEL,
  BACKUP_ENCRYPTION_STATUS_LABEL,
  BACKUP_INCLUDED_DOMAIN_LABELS,
  BACKUP_IMPORT_CONFLICT_POLICY,
  BACKUP_IMPORT_PREVIEW_NOTE,
  BACKUP_MANAGEMENT_STORAGE_NOTE,
  BACKUP_SCHEMA_VERSION,
  BACKUP_UNENCRYPTED_EXPORT_WARNING,
  BackupImportPreview,
  BackupImportSelectionPreview,
  BackupService,
} from '../model/BackupService'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct BackupManagementPage {
  @State private busy: boolean = false
  @State private selectedBackupPayload: string = ''
  @State private selectedBackupPreview: BackupImportPreview | undefined = undefined

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private backupService(): BackupService {
    return new BackupService(this.context())
  }

  private acceptedSchemaText(): string {
    return BACKUP_ACCEPTED_SCHEMA_VERSIONS.map((version: number) => `v${version}`).join(' / ')
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {
    }
  }

  private showInfoDialog(title: string, message: string): void {
    void this.getUIContext().getPromptAction().showDialog({
      title,
      message,
      buttons: [
        { text: '确定', color: '#8D5A3B' },
      ],
    })
  }

  private exportBackup(): void {
    if (this.busy) {
      return
    }
    this.busy = true
    console.info('[BackupManagement] step=export_start')
    void this.backupService().exportToPicker()
      .then((uri: string | undefined) => {
        if (uri !== undefined) {
          this.showInfoDialog('备份已导出', `备份 JSON 已保存到所选位置。\n${BACKUP_UNENCRYPTED_EXPORT_WARNING}`)
        }
      })
      .catch((error: Error) => {
        console.error('[BackupManagement] step=export_failed message=' + error.message)
        this.showInfoDialog('导出失败', error.message)
      })
      .finally(() => {
        this.busy = false
      })
  }

  private importBackup(): void {
    if (this.busy) {
      return
    }
    this.busy = true
    this.selectedBackupPayload = ''
    this.selectedBackupPreview = undefined
    console.info('[BackupManagement] step=preview_start')
    void this.backupService().selectImportPreviewFromPicker()
      .then((selection: BackupImportSelectionPreview | undefined) => {
        if (selection !== undefined) {
          this.selectedBackupPayload = selection.payload
          this.selectedBackupPreview = selection.preview
          this.showToast('已读取备份预览，请确认后恢复')
        }
      })
      .catch((error: Error) => {
        console.error('[BackupManagement] step=preview_failed message=' + error.message)
        this.showInfoDialog('预览失败', error.message)
      })
      .finally(() => {
        this.busy = false
      })
  }

  private restoreSelectedBackup(): void {
    if (this.busy || this.selectedBackupPayload.length === 0) {
      return
    }
    this.busy = true
    console.info('[BackupManagement] step=import_start')
    void this.backupService().import(this.selectedBackupPayload)
      .then(() => {
        this.selectedBackupPayload = ''
        this.selectedBackupPreview = undefined
        this.showInfoDialog('备份已导入', '已按所选备份恢复书架、阅读进度、远程服务器配置、源包和偏好。')
      })
      .catch((error: Error) => {
        console.error('[BackupManagement] step=import_failed message=' + error.message)
        this.showInfoDialog('导入失败', error.message)
      })
      .finally(() => {
        this.busy = false
      })
  }

  @Builder
  private StatusCard() {
    Column({ space: 12 }) {
      Row() {
        Text('当前导出架构')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .layoutWeight(1)
        Text(`v${BACKUP_SCHEMA_VERSION}`)
          .fontSize(14)
          .fontColor($r('app.color.koma_accent'))
      }
      .width('100%')

      Row() {
        Text('可恢复版本')
          .fontSize(15)
          .fontColor($r('app.color.koma_text_primary'))
          .layoutWeight(1)
        Text(this.acceptedSchemaText())
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private EncryptionCard() {
    Column({ space: 12 }) {
      Row() {
        Text('备份加密')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .layoutWeight(1)
        Text(BACKUP_ENCRYPTION_STATUS_LABEL)
          .fontSize(14)
          .fontColor($r('app.color.koma_accent'))
      }
      .width('100%')

      Text(BACKUP_ENCRYPTION_PLAN_LABEL)
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
        .lineHeight(19)

      Button('加密备份（计划中）')
        .width('100%')
        .height(42)
        .borderRadius(8)
        .fontSize(15)
        .fontColor($r('app.color.koma_text_secondary'))
        .backgroundColor('#00000000')
        .enabled(false)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private DomainsCard() {
    Column({ space: 10 }) {
      Text('包含的数据')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))

      ForEach(BACKUP_INCLUDED_DOMAIN_LABELS, (domain: string) => {
        Row({ space: 10 }) {
          Text('-')
            .fontSize(15)
            .fontColor($r('app.color.koma_accent'))
          Text(domain)
            .fontSize(14)
            .fontColor($r('app.color.koma_text_secondary'))
            .layoutWeight(1)
        }
        .width('100%')
      }, (domain: string) => domain)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private ActionsCard() {
    Column({ space: 10 }) {
      Button(this.busy ? '处理中' : '导出备份')
        .width('100%')
        .height(42)
        .borderRadius(8)
        .fontSize(15)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.koma_accent'))
        .enabled(!this.busy)
        .onClick(() => {
          this.exportBackup()
        })

      Button(this.busy ? '处理中' : '选择备份并预览')
        .width('100%')
        .height(42)
        .borderRadius(8)
        .fontSize(15)
        .fontColor($r('app.color.koma_accent'))
        .backgroundColor('#00000000')
        .enabled(!this.busy)
        .onClick(() => {
          this.importBackup()
        })

      Button(this.busy ? '处理中' : '恢复所选备份')
        .width('100%')
        .height(42)
        .borderRadius(8)
        .fontSize(15)
        .fontColor(this.selectedBackupPayload.length > 0 ? Color.White : $r('app.color.koma_text_secondary'))
        .backgroundColor(this.selectedBackupPayload.length > 0 ? $r('app.color.koma_accent') : '#00000000')
        .enabled(!this.busy && this.selectedBackupPayload.length > 0)
        .onClick(() => {
          this.restoreSelectedBackup()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private ImportPreviewIntroCard() {
    Column({ space: 8 }) {
      Text('导入预览')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text(BACKUP_IMPORT_PREVIEW_NOTE)
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
        .lineHeight(19)
      Text(BACKUP_IMPORT_CONFLICT_POLICY)
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
        .lineHeight(19)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private PreviewRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.koma_text_secondary'))
        .layoutWeight(1)
      Text(value)
        .fontSize(14)
        .fontColor($r('app.color.koma_text_primary'))
    }
    .width('100%')
  }

  @Builder
  private SelectedPreviewCard(preview: BackupImportPreview) {
    Column({ space: 10 }) {
      Text('已选择的备份')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      this.PreviewRow('备份版本', `v${preview.schemaVersion}`)
      this.PreviewRow('导出时间', preview.exportedAtText)
      this.PreviewRow('加密状态', preview.encryptionText)
      this.PreviewRow('书架项目', `${preview.libraryItemCount}`)
      this.PreviewRow('阅读进度', `${preview.progressCount}`)
      this.PreviewRow('设置项', `${preview.settingsCount}`)
      this.PreviewRow('分类', `${preview.categoryCount}`)
      this.PreviewRow('下载队列', preview.hasDownloadQueueCount ? `${preview.downloadQueueCount}` : '备份中未提供')
      this.PreviewRow('追踪映射', preview.hasTrackerMappingCount ? `${preview.trackerMappingCount}` : '备份中未提供')
      this.PreviewRow('源包元数据', `${preview.sourcePackageCount}`)
      this.PreviewRow('源设置', `${preview.sourceSettingsCount}`)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private StorageNoteCard() {
    Column({ space: 8 }) {
      Text('备份文件管理')
        .width('100%')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text(BACKUP_MANAGEMENT_STORAGE_NOTE)
        .width('100%')
        .fontSize(13)
        .fontColor($r('app.color.koma_text_secondary'))
        .lineHeight(19)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 12,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20 + ThemeConstants.SPACE_XL,
      }) {
        ListItem() {
          this.StatusCard()
        }
        ListItem() {
          this.EncryptionCard()
        }
        ListItem() {
          this.DomainsCard()
        }
        ListItem() {
          this.ImportPreviewIntroCard()
        }
        if (this.selectedBackupPreview !== undefined) {
          ListItem() {
            this.SelectedPreviewCard(this.selectedBackupPreview)
          }
        }
        ListItem() {
          this.ActionsCard()
        }
        ListItem() {
          this.StorageNoteCard()
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

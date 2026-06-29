import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  BACKUP_ACCEPTED_SCHEMA_VERSIONS,
  BACKUP_ENCRYPTED_EXPORT_SUCCESS,
  BACKUP_ENCRYPTION_PLAN_LABEL,
  BACKUP_ENCRYPTION_STATUS_LABEL,
  BACKUP_INCLUDED_DOMAIN_LABELS,
  BACKUP_IMPORT_CONFLICT_POLICY,
  BACKUP_IMPORT_PREVIEW_NOTE,
  BACKUP_MANAGEMENT_STORAGE_NOTE,
  BACKUP_PASSPHRASE_HELP_TEXT,
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
  @State private selectedEncryptedBackupPayload: string = ''
  @State private selectedBackupPreview: BackupImportPreview | undefined = undefined
  @State private exportPassphrase: string = ''
  @State private exportPassphraseConfirm: string = ''
  @State private importPassphrase: string = ''

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
        { text: '确定', color: $r('app.color.koma_accent') },
      ],
    })
  }

  private backupFailureMessage(code: string): string {
    return `操作未完成，请稍后重试或重新选择备份文件。错误码：${code}`
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
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=export_failed code=backup_export_failed')
        this.showInfoDialog('导出失败', this.backupFailureMessage('backup_export_failed'))
      })
      .finally(() => {
        this.exportPassphrase = ''
        this.exportPassphraseConfirm = ''
        this.busy = false
      })
  }

  private exportEncryptedBackup(): void {
    if (this.busy) {
      return
    }
    if (this.exportPassphrase.length < 8) {
      this.showInfoDialog('无法导出', '加密备份口令至少 8 个字符。')
      return
    }
    if (this.exportPassphrase !== this.exportPassphraseConfirm) {
      this.showInfoDialog('无法导出', '两次输入的口令不一致。')
      return
    }
    const passphrase = this.exportPassphrase
    this.busy = true
    console.info('[BackupManagement] step=export_encrypted_start')
    void this.backupService().exportEncryptedToPicker(passphrase)
      .then((uri: string | undefined) => {
        this.exportPassphrase = ''
        this.exportPassphraseConfirm = ''
        if (uri !== undefined) {
          this.showInfoDialog('加密备份已导出', BACKUP_ENCRYPTED_EXPORT_SUCCESS)
        }
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=export_encrypted_failed code=backup_export_failed')
        this.showInfoDialog('导出失败', this.backupFailureMessage('backup_export_failed'))
      })
      .finally(() => {
        this.importPassphrase = ''
        this.busy = false
      })
  }

  private importBackup(): void {
    if (this.busy) {
      return
    }
    this.busy = true
    this.selectedBackupPayload = ''
    this.selectedEncryptedBackupPayload = ''
    this.selectedBackupPreview = undefined
    this.importPassphrase = ''
    console.info('[BackupManagement] step=preview_start')
    void this.backupService().selectImportPreviewFromPicker()
      .then((selection: BackupImportSelectionPreview | undefined) => {
        if (selection !== undefined) {
          if (selection.preview.encrypted && !selection.preview.decrypted) {
            this.selectedEncryptedBackupPayload = selection.payload
          } else {
            this.selectedBackupPayload = selection.payload
          }
          this.selectedBackupPreview = selection.preview
          this.showToast('已读取备份预览，请确认后恢复')
        }
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=preview_failed code=backup_preview_failed')
        this.showInfoDialog('预览失败', this.backupFailureMessage('backup_preview_failed'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  private decryptSelectedBackup(): void {
    if (this.busy || this.selectedEncryptedBackupPayload.length === 0) {
      return
    }
    if (this.importPassphrase.length < 8) {
      this.showInfoDialog('无法解密', '请输入备份口令。')
      return
    }
    const passphrase = this.importPassphrase
    this.busy = true
    console.info('[BackupManagement] step=decrypt_preview_start')
    void this.backupService().decryptPreview(this.selectedEncryptedBackupPayload, passphrase)
      .then((selection: BackupImportSelectionPreview) => {
        this.selectedBackupPayload = selection.payload
        this.selectedBackupPreview = selection.preview
        this.selectedEncryptedBackupPayload = ''
        this.importPassphrase = ''
        this.showToast('加密备份已解密，请确认后恢复')
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=decrypt_preview_failed code=backup_decrypt_failed')
        this.showInfoDialog('解密失败', '无法解密备份。请确认文件和口令后重试。')
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
    const importPromise = this.selectedBackupPreview?.encrypted === true && this.selectedBackupPreview?.decrypted === true ?
      this.backupService().importDecrypted(this.selectedBackupPayload) :
      this.backupService().import(this.selectedBackupPayload)
    void importPromise
      .then(() => {
        this.selectedBackupPayload = ''
        this.selectedEncryptedBackupPayload = ''
        this.selectedBackupPreview = undefined
        this.showInfoDialog('备份已导入', '已按所选备份恢复书架、阅读进度、远程服务器配置、源包和偏好。')
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=import_failed code=backup_import_failed')
        this.showInfoDialog('导入失败', this.backupFailureMessage('backup_import_failed'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  @Builder
  private StatusCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row() {
        Text('当前导出架构')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
        Text(`v${BACKUP_SCHEMA_VERSION}`)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }
      .width('100%')

      Row() {
        Text('可恢复版本')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
        Text(this.acceptedSchemaText())
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private EncryptionCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row() {
        Text('备份加密')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
        Text(BACKUP_ENCRYPTION_STATUS_LABEL)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }
      .width('100%')

      Text(BACKUP_ENCRYPTION_PLAN_LABEL)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)

      Text(BACKUP_PASSPHRASE_HELP_TEXT)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)

      TextInput({ text: this.exportPassphrase, placeholder: '加密口令' })
        .width('100%')
        .height(ThemeConstants.BUTTON_HEIGHT)
        .type(InputType.Password)
        .showPassword(false)
        .onChange((value: string) => {
          this.exportPassphrase = value
        })

      TextInput({ text: this.exportPassphraseConfirm, placeholder: '再次输入口令' })
        .width('100%')
        .height(ThemeConstants.BUTTON_HEIGHT)
        .type(InputType.Password)
        .showPassword(false)
        .onChange((value: string) => {
          this.exportPassphraseConfirm = value
        })

      Button(this.busy ? '处理中' : '导出加密备份')
        .width('100%')
        .height(ThemeConstants.BUTTON_HEIGHT)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .enabled(!this.busy)
        .onClick(() => {
          this.exportEncryptedBackup()
        })
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private DomainsCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text('包含的数据')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)

      ForEach(BACKUP_INCLUDED_DOMAIN_LABELS, (domain: string) => {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Text('-')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
          Text(domain)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .layoutWeight(1)
        }
        .width('100%')
      }, (domain: string) => domain)
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private ActionsCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Button(this.busy ? '处理中' : '导出备份')
        .width('100%')
        .height(ThemeConstants.BUTTON_HEIGHT)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_ON_BRAND)
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .enabled(!this.busy)
        .onClick(() => {
          this.exportBackup()
        })

      Button(this.busy ? '处理中' : '选择备份并预览')
        .width('100%')
        .height(ThemeConstants.BUTTON_HEIGHT)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.BRAND_PRIMARY)
        .backgroundColor(Color.Transparent)
        .enabled(!this.busy)
        .onClick(() => {
          this.importBackup()
        })

      Button(this.busy ? '处理中' : '恢复所选备份')
        .width('100%')
        .height(ThemeConstants.BUTTON_HEIGHT)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(this.selectedBackupPayload.length > 0 ? ThemeConstants.TEXT_ON_BRAND : ThemeConstants.TEXT_SECONDARY)
        .backgroundColor(this.selectedBackupPayload.length > 0 ? ThemeConstants.BRAND_PRIMARY : Color.Transparent)
        .enabled(!this.busy && this.selectedBackupPayload.length > 0)
        .onClick(() => {
          this.restoreSelectedBackup()
        })

      if (this.selectedEncryptedBackupPayload.length > 0) {
        TextInput({ text: this.importPassphrase, placeholder: '输入口令解密预览' })
          .width('100%')
          .height(ThemeConstants.BUTTON_HEIGHT)
          .type(InputType.Password)
          .showPassword(false)
          .onChange((value: string) => {
            this.importPassphrase = value
          })

        Button(this.busy ? '处理中' : '解密并预览')
          .width('100%')
          .height(ThemeConstants.BUTTON_HEIGHT)
          .borderRadius(ThemeConstants.RADIUS_CHIP)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_ON_BRAND)
          .backgroundColor(ThemeConstants.BRAND_PRIMARY)
          .enabled(!this.busy)
          .onClick(() => {
            this.decryptSelectedBackup()
          })
      }
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private ImportPreviewIntroCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('导入预览')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(BACKUP_IMPORT_PREVIEW_NOTE)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
      Text(BACKUP_IMPORT_CONFLICT_POLICY)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private PreviewRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .layoutWeight(1)
      Text(value)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
    }
    .width('100%')
  }

  @Builder
  private SelectedPreviewCard(preview: BackupImportPreview) {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text('已选择的备份')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      this.PreviewRow('备份版本', `v${preview.schemaVersion}`)
      this.PreviewRow('导出时间', preview.exportedAtText)
      this.PreviewRow('加密状态', preview.encryptionText)
      if (preview.encrypted) {
        this.PreviewRow('加密算法', preview.algorithm)
        this.PreviewRow('密钥派生', preview.kdfId)
      }
      if (!preview.encrypted || preview.decrypted) {
        this.PreviewRow('书架项目', `${preview.libraryItemCount}`)
        this.PreviewRow('阅读进度', `${preview.progressCount}`)
        this.PreviewRow('设置项', `${preview.settingsCount}`)
        this.PreviewRow('分类', `${preview.categoryCount}`)
        this.PreviewRow('下载队列', preview.hasDownloadQueueCount ? `${preview.downloadQueueCount}` : '备份中未提供')
        this.PreviewRow('追踪映射', preview.hasTrackerMappingCount ? `${preview.trackerMappingCount}` : '备份中未提供')
        this.PreviewRow('源包元数据', `${preview.sourcePackageCount}`)
        this.PreviewRow('源设置', `${preview.sourceSettingsCount}`)
      }
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private StorageNoteCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Text('备份文件管理')
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(BACKUP_MANAGEMENT_STORAGE_NOTE)
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
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
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

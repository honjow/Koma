import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { AppStrings } from '../i18n/AppStrings'
import {
  BACKUP_ACCEPTED_SCHEMA_VERSIONS,
  BACKUP_SCHEMA_VERSION,
  BackupImportPreview,
  BackupImportSelectionPreview,
  BackupService,
  backupEncryptedExportSuccess,
  backupEncryptionPlanLabel,
  backupEncryptionStatusLabel,
  backupImportConflictPolicy,
  backupImportPreviewNote,
  backupIncludedDomainLabels,
  backupManagementStorageNote,
  backupPassphraseHelpText,
  backupUnencryptedExportWarning,
} from '../model/BackupService'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'

function t(name: string): string {
  return AppStrings.get(name)
}

function tf(name: string, ...args: Array<string | number>): string {
  return AppStrings.format(name, ...args)
}

@ComponentV2
export struct BackupManagementPage {
  @Local private busy: boolean = false
  @Local private selectedBackupPayload: string = ''
  @Local private selectedEncryptedBackupPayload: string = ''
  @Local private selectedBackupPreview: BackupImportPreview | undefined = undefined
  @Local private exportPassphrase: string = ''
  @Local private exportPassphraseConfirm: string = ''
  @Local private importPassphrase: string = ''
  @Local private languageState: LanguageState = connectLanguageState()

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
        { text: t('common_confirm'), color: $r('app.color.koma_accent') },
      ],
    })
  }

  private backupFailureMessage(code: string): string {
    return tf('backup_failure_message', code)
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
          this.showInfoDialog(
            t('backup_dialog_exported_title'),
            `${t('backup_dialog_exported_message')}\n${backupUnencryptedExportWarning()}`,
          )
        }
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=export_failed code=backup_export_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_export_failed'))
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
      this.showInfoDialog(t('backup_dialog_export_blocked_title'), t('backup_passphrase_too_short'))
      return
    }
    if (this.exportPassphrase !== this.exportPassphraseConfirm) {
      this.showInfoDialog(t('backup_dialog_export_blocked_title'), t('backup_passphrase_mismatch'))
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
          this.showInfoDialog(t('backup_dialog_encrypted_exported_title'), backupEncryptedExportSuccess())
        }
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=export_encrypted_failed code=backup_export_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_export_failed'))
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
          this.showToast(t('backup_preview_loaded_toast'))
        }
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=preview_failed code=backup_preview_failed')
        this.showInfoDialog(t('backup_dialog_preview_failed_title'), this.backupFailureMessage('backup_preview_failed'))
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
      this.showInfoDialog(t('backup_dialog_decrypt_blocked_title'), t('backup_enter_passphrase'))
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
        this.showToast(t('backup_decrypted_toast'))
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=decrypt_preview_failed code=backup_decrypt_failed')
        this.showInfoDialog(t('backup_dialog_decrypt_failed_title'), t('backup_decrypt_failed_message'))
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
        this.showInfoDialog(t('backup_dialog_imported_title'), t('backup_imported_message'))
      })
      .catch((_error: Error) => {
        console.error('[BackupManagement] step=import_failed code=backup_import_failed')
        this.showInfoDialog(t('backup_dialog_import_failed_title'), this.backupFailureMessage('backup_import_failed'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  @Builder
  private StatusCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Row() {
        Text(t('backup_current_schema'))
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
        Text(t('backup_supported_versions'))
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
        Text(t('backup_encryption_heading'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
        Text(backupEncryptionStatusLabel())
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.BRAND_PRIMARY)
      }
      .width('100%')

      Text(backupEncryptionPlanLabel())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)

      Text(backupPassphraseHelpText())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)

      KomaFormTextField({
        label: t('backup_passphrase_label'),
        value: this.exportPassphrase,
        isPassword: true,
        change: (value: string) => {
          this.exportPassphrase = value
        },
      })

      KomaFormTextField({
        label: t('backup_passphrase_confirm_label'),
        value: this.exportPassphraseConfirm,
        isPassword: true,
        change: (value: string) => {
          this.exportPassphraseConfirm = value
        },
      })

      KomaActionButton({
        label: this.busy ? t('backup_processing') : t('backup_export_encrypted_action'),
        kind: 'primary',
        fullWidth: true,
        icon: $r('sys.symbol.doc_plaintext'),
        isEnabled: !this.busy,
        action: () => {
          this.exportEncryptedBackup()
        },
      })
        .width('100%')
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
  }

  @Builder
  private DomainsCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      Text(t('backup_included_data'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)

      ForEach(backupIncludedDomainLabels(), (domain: string) => {
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
      KomaActionButton({
        label: this.busy ? t('backup_processing') : t('backup_export_action'),
        kind: 'primary',
        fullWidth: true,
        icon: $r('sys.symbol.doc_plaintext'),
        isEnabled: !this.busy,
        action: () => {
          this.exportBackup()
        },
      })
        .width('100%')

      KomaActionButton({
        label: this.busy ? t('backup_processing') : t('backup_select_preview_action'),
        kind: 'secondary',
        fullWidth: true,
        icon: $r('sys.symbol.doc_plaintext'),
        isEnabled: !this.busy,
        action: () => {
          this.importBackup()
        },
      })
        .width('100%')

      KomaActionButton({
        label: this.busy ? t('backup_processing') : t('backup_restore_selected_action'),
        kind: this.selectedBackupPayload.length > 0 ? 'primary' : 'secondary',
        fullWidth: true,
        icon: $r('sys.symbol.arrow_clockwise'),
        isEnabled: !this.busy && this.selectedBackupPayload.length > 0,
        action: () => {
          this.restoreSelectedBackup()
        },
      })
        .width('100%')

      if (this.selectedEncryptedBackupPayload.length > 0) {
        KomaFormTextField({
          label: t('backup_decrypt_passphrase_label'),
          value: this.importPassphrase,
          isPassword: true,
          change: (value: string) => {
            this.importPassphrase = value
          },
        })

        KomaActionButton({
          label: this.busy ? t('backup_processing') : t('backup_decrypt_preview_action'),
          kind: 'primary',
          fullWidth: true,
          icon: $r('sys.symbol.doc_plaintext'),
          isEnabled: !this.busy,
          action: () => {
            this.decryptSelectedBackup()
          },
        })
          .width('100%')
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
      Text(t('backup_import_preview_heading'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(backupImportPreviewNote())
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
      Text(backupImportConflictPolicy())
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
      Text(t('backup_selected_heading'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      this.PreviewRow(t('backup_preview_version'), `v${preview.schemaVersion}`)
      this.PreviewRow(t('backup_preview_exported_at'), preview.exportedAtText)
      this.PreviewRow(t('backup_preview_encryption_status'), preview.encryptionText)
      if (preview.encrypted) {
        this.PreviewRow(t('backup_preview_algorithm'), preview.algorithm)
        this.PreviewRow(t('backup_preview_kdf'), preview.kdfId)
      }
      if (!preview.encrypted || preview.decrypted) {
        this.PreviewRow(t('backup_preview_library_items'), `${preview.libraryItemCount}`)
        this.PreviewRow(t('backup_preview_progress'), `${preview.progressCount}`)
        this.PreviewRow(t('backup_preview_settings'), `${preview.settingsCount}`)
        this.PreviewRow(t('backup_preview_categories'), `${preview.categoryCount}`)
        this.PreviewRow(
          t('backup_preview_download_queue'),
          preview.hasDownloadQueueCount ? `${preview.downloadQueueCount}` : t('backup_preview_not_provided'),
        )
        this.PreviewRow(
          t('backup_preview_tracker_mappings'),
          preview.hasTrackerMappingCount ? `${preview.trackerMappingCount}` : t('backup_preview_not_provided'),
        )
        this.PreviewRow(t('backup_preview_source_package_metadata'), `${preview.sourcePackageCount}`)
        this.PreviewRow(t('backup_preview_source_settings'), `${preview.sourceSettingsCount}`)
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
      Text(t('backup_file_management_heading'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(backupManagementStorageNote())
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
    if (this.languageState.effectiveLocale.length >= 0) {
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
}

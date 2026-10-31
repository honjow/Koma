import { synchronizeBackgroundMaintenance } from '../model/BackgroundMaintenance'
import { selectAutomaticBackupDirectory, AutomaticBackupDirectorySelection } from '../model/BackupAutomaticDirectory'
import { komaMenuOptions } from '../theme/KomaPopupOptions'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { Binding, UIUtils } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { AppStrings } from '../i18n/AppStrings'
import {
  BACKUP_ACCEPTED_SCHEMA_VERSIONS,
  BACKUP_AUTOMATIC_INTERVAL_HOUR_OPTIONS,
  BACKUP_AUTOMATIC_RETENTION_COUNT_OPTIONS,
  BACKUP_SCHEMA_VERSION,
  BackupAutomaticPreferences,
  BackupAutomaticRunResult,
  BackupContentPreferences,
  BackupImportPreview,
  BackupImportSelectionPreview,
  BackupLocalFileRecord,
  BackupService,
  BackupAutomaticPreferencesPatch,
  DEFAULT_BACKUP_AUTOMATIC_PREFERENCES,
  DEFAULT_BACKUP_CONTENT_PREFERENCES,
  backupAutomaticIntervalLabel,
  backupAutomaticLastFailureText,
  backupAutomaticLastRunText,
  backupAutomaticRetentionLabel,
  backupEncryptedExportSuccess,
  backupEncryptionPlanLabel,
  backupImportConflictPolicy,
  backupImportPreviewNote,
  backupIncludedDomainLabels,
  backupLocalFileDetailText,
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

interface BackupPreviewRowParams {
  label: string
  value: string
}

interface SelectedBackupPreviewParams {
  preview: BackupImportPreview
}

@ComponentV2
export struct BackupManagementPage {
  @Param pane: string = 'home'
  @Param localFileName: string = ''
  @Param refreshRevision: number = 0
  @Event onOpenTask: (pane: string, fileName: string) => void = (_pane: string, _fileName: string) => {}
  @Event onRestoreCompleted: () => void = () => {}
  @Local private createLocal: boolean = false
  @Local private createEncrypted: boolean = true
  @Local private showTechnicalDetails: boolean = false
  @Local private showPreviewDetails: boolean = false
  private localSelectionStarted: boolean = false
  @Local private busy: boolean = false
  @Local private selectedBackupPayload: string = ''
  @Local private selectedEncryptedBackupPayload: string = ''
  @Local private selectedBackupPreview: BackupImportPreview | undefined = undefined
  @Local private localBackups: BackupLocalFileRecord[] = []
  @Local private localBackupsLoading: boolean = true
  @Local private localBackupsFailed: boolean = false
  private localBackupsEpoch: number = 0
  @Local private localFileActionMenuKey: string = ''
  @Local private autoPreferences: BackupAutomaticPreferences = DEFAULT_BACKUP_AUTOMATIC_PREFERENCES
  private automaticPreferencesEpoch: number = 0
  @Local private contentPreferences: BackupContentPreferences = DEFAULT_BACKUP_CONTENT_PREFERENCES
  @Local private autoIntervalMenuOpen: boolean = false
  @Local private autoRetentionMenuOpen: boolean = false
  @Local private editingLocalBackupFileName: string = ''
  @Local private editingLocalBackupName: string = ''
  @Local private exportPassphrase: string = ''
  @Local private exportPassphraseConfirm: string = ''
  @Local private importPassphrase: string = ''
  @Local private languageState: LanguageState = connectLanguageState()

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  @Monitor('refreshRevision')
  private onRefreshRevision(): void {
    if (this.pane === 'home' || this.pane === 'files') {
      this.loadLocalBackups()
      this.loadAutomaticPreferences()
    } else if (this.pane === 'create') {
      this.loadContentPreferences()
    } else if (this.pane === 'settings') {
      this.loadAutomaticPreferences()
    }
  }

  private createBackup(): void {
    if (this.busy) {
      return
    }
    if (this.createLocal) {
      if (this.createEncrypted) {
        this.exportEncryptedLocalBackup()
      } else {
        this.confirmExportLocalBackup()
      }
    } else if (this.createEncrypted) {
      this.exportEncryptedBackup()
    } else {
      this.confirmExportBackup()
    }
  }

  private createActionLabel(): string {
    if (this.busy) {
      return t('backup_processing')
    }
    if (this.createLocal) {
      return t(this.createEncrypted ? 'backup_local_create_encrypted_action' : 'backup_local_create_action')
    }
    return t(this.createEncrypted ? 'backup_export_encrypted_action' : 'backup_export_action')
  }

  private backupService(): BackupService {
    return new BackupService(this.context())
  }

  private localBackupCountText(): string {
    if (this.localBackupsLoading) return t('common_loading')
    return this.localBackupsFailed ? t('backup_local_unavailable') : `${this.localBackups.length}`
  }

  private loadLocalBackups(): void {
    const epoch = ++this.localBackupsEpoch
    this.localBackupsLoading = true
    this.localBackupsFailed = false
    void this.backupService().listLocalBackups()
      .then((records: BackupLocalFileRecord[]) => {
        if (epoch !== this.localBackupsEpoch) return
        this.localBackups = records
      })
      .catch((_error: Error) => {
        if (epoch !== this.localBackupsEpoch) return
        DiagnosticLogger.error('backup_management_page', 'local_list_failed', '[BackupManagement] step=local_list_failed code=backup_local_list_failed')
        this.localBackupsFailed = true
      })
      .finally(() => {
        if (epoch === this.localBackupsEpoch) this.localBackupsLoading = false
      })
  }

  private loadAutomaticPreferences(): void {
    const epoch = this.automaticPreferencesEpoch
    void this.backupService().loadAutomaticPreferences()
      .then((preferencesValue: BackupAutomaticPreferences) => {
        if (epoch !== this.automaticPreferencesEpoch) return
        this.autoPreferences = preferencesValue
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'auto_preferences_load_failed', '[BackupManagement] step=auto_preferences_load_failed code=backup_auto_preferences_failed')
        if (epoch !== this.automaticPreferencesEpoch) return
        this.autoPreferences = DEFAULT_BACKUP_AUTOMATIC_PREFERENCES
      })
  }

  private loadContentPreferences(): void {
    void this.backupService().loadContentPreferences()
      .then((preferencesValue: BackupContentPreferences) => {
        this.contentPreferences = preferencesValue
      })
      .catch((_error: Error) => {
        DiagnosticLogger.warn('backup_management_page', 'content_preferences_load_failed', '[BackupManagement] step=content_preferences_load_failed code=backup_content_preferences_failed')
        this.contentPreferences = DEFAULT_BACKUP_CONTENT_PREFERENCES
      })
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

  private confirmExportBackup(): void {
    if (this.busy) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: t('backup_unencrypted_confirm_title'),
      message: `${t('backup_unencrypted_confirm_message')}\n\n${backupUnencryptedExportWarning()}`,
      autoCancel: true,
      primaryButton: {
        value: t('backup_unencrypted_confirm_action'),
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.exportBackup()
        },
      },
      secondaryButton: {
        value: t('common_cancel'),
        action: () => {},
      },
    })
  }

  private confirmExportLocalBackup(): void {
    if (this.busy) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: t('backup_unencrypted_confirm_title'),
      message: `${t('backup_unencrypted_local_confirm_message')}\n\n${backupUnencryptedExportWarning()}`,
      autoCancel: true,
      primaryButton: {
        value: t('backup_unencrypted_confirm_action'),
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.exportLocalBackup()
        },
      },
      secondaryButton: {
        value: t('common_cancel'),
        action: () => {},
      },
    })
  }

  private saveAutomaticPreferences(patch: BackupAutomaticPreferencesPatch): void {
    const epoch = ++this.automaticPreferencesEpoch
    void this.backupService().saveAutomaticPreferences(patch)
      .then((preferencesValue: BackupAutomaticPreferences) => {
        if (epoch !== this.automaticPreferencesEpoch) return
        this.autoPreferences = preferencesValue
        void synchronizeBackgroundMaintenance(this.context()).catch((error: Error): void => {
          DiagnosticLogger.exception('maintenance', 'backup_schedule_failed', error)
        })
        this.showToast(t('backup_auto_saved_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'auto_preferences_save_failed', '[BackupManagement] step=auto_preferences_save_failed code=backup_auto_preferences_failed')
        if (epoch === this.automaticPreferencesEpoch) {
          this.loadAutomaticPreferences()
        }
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_auto_preferences_failed'))
      })
  }

  private saveContentPreferences(preferencesValue: BackupContentPreferences): void {
    void this.backupService().saveContentPreferences(preferencesValue)
      .then(() => {
        this.contentPreferences = preferencesValue
        this.showToast(t('backup_auto_saved_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'content_preferences_save_failed', '[BackupManagement] step=content_preferences_save_failed code=backup_content_preferences_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_content_preferences_failed'))
      })
  }

  private setBackupIncludeSettings(includeSettings: boolean): void {
    this.saveContentPreferences({
      includeSettings,
      includeDownloadQueue: this.contentPreferences.includeDownloadQueue,
      includeTrackerMappings: this.contentPreferences.includeTrackerMappings,
    })
  }

  private setBackupIncludeDownloadQueue(includeDownloadQueue: boolean): void {
    this.saveContentPreferences({
      includeSettings: this.contentPreferences.includeSettings,
      includeDownloadQueue,
      includeTrackerMappings: this.contentPreferences.includeTrackerMappings,
    })
  }

  private setBackupIncludeTrackerMappings(includeTrackerMappings: boolean): void {
    this.saveContentPreferences({
      includeSettings: this.contentPreferences.includeSettings,
      includeDownloadQueue: this.contentPreferences.includeDownloadQueue,
      includeTrackerMappings,
    })
  }

  private selectAutomaticDirectory(): void {
    if (this.busy) return
    void selectAutomaticBackupDirectory(this.context())
      .then((selection: AutomaticBackupDirectorySelection | undefined): void => {
        if (selection !== undefined) this.saveAutomaticPreferences({ directoryUri: selection.uri, directoryOwnedModes: selection.ownedModes })
      }).catch((error: Error): void => {
        DiagnosticLogger.exception('backup', 'automatic_directory_failed', error)
        this.showToast(t('backup_auto_directory_select_failed'))
      })
  }

  private setAutomaticBackupEnabled(enabled: boolean): void {
    this.saveAutomaticPreferences({ enabled })
  }

  private setAutomaticBackupInterval(intervalHours: number): void {
    this.autoIntervalMenuOpen = false
    this.saveAutomaticPreferences({ intervalHours })
  }

  private setAutomaticBackupRetention(retentionCount: number): void {
    this.autoRetentionMenuOpen = false
    this.saveAutomaticPreferences({ retentionCount })
  }

  private runAutomaticBackupNow(): void {
    if (this.busy) {
      return
    }
    this.busy = true
    console.info('[BackupManagement] step=auto_run_now_start')
    void this.backupService().runAutomaticLocalBackupNow()
      .then((result: BackupAutomaticRunResult) => {
        this.loadAutomaticPreferences()
        this.loadLocalBackups()
        if (result.ran) {
          this.showToast(t('backup_local_saved_toast'))
        } else if (result.failureCode !== undefined) {
          this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage(result.failureCode))
        } else {
          this.showToast(t('backup_auto_skipped_toast'))
        }
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'auto_run_now_failed', '[BackupManagement] step=auto_run_now_failed code=backup_auto_export_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_auto_export_failed'))
      })
      .finally(() => {
        this.busy = false
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
          this.showInfoDialog(
            t('backup_dialog_exported_title'),
            `${t('backup_dialog_exported_message')}\n${backupUnencryptedExportWarning()}`,
          )
        }
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'export_failed', '[BackupManagement] step=export_failed code=backup_export_failed')
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
        if (uri !== undefined) {
          this.showInfoDialog(t('backup_dialog_encrypted_exported_title'), backupEncryptedExportSuccess())
        }
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'export_encrypted_failed', '[BackupManagement] step=export_encrypted_failed code=backup_export_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_export_failed'))
      })
      .finally(() => {
        this.exportPassphrase = ''
        this.exportPassphraseConfirm = ''
        this.busy = false
      })
  }

  private exportLocalBackup(): void {
    if (this.busy) {
      return
    }
    this.busy = true
    console.info('[BackupManagement] step=local_export_start')
    void this.backupService().exportLocal()
      .then((_record: BackupLocalFileRecord) => {
        this.loadLocalBackups()
        this.showToast(t('backup_local_saved_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'local_export_failed', '[BackupManagement] step=local_export_failed code=backup_local_export_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_local_export_failed'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  private exportEncryptedLocalBackup(): void {
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
    console.info('[BackupManagement] step=local_export_encrypted_start')
    void this.backupService().exportEncryptedLocal(passphrase)
      .then((_record: BackupLocalFileRecord) => {
        this.loadLocalBackups()
        this.showToast(t('backup_local_saved_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'local_export_encrypted_failed', '[BackupManagement] step=local_export_encrypted_failed code=backup_local_export_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_local_export_failed'))
      })
      .finally(() => {
        this.exportPassphrase = ''
        this.exportPassphraseConfirm = ''
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
        DiagnosticLogger.error('backup_management_page', 'preview_failed', '[BackupManagement] step=preview_failed code=backup_preview_failed')
        this.showInfoDialog(t('backup_dialog_preview_failed_title'), this.backupFailureMessage('backup_preview_failed'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  private selectLocalBackup(fileName: string): void {
    if (this.busy) {
      return
    }
    this.busy = true
    console.info('[BackupManagement] step=local_preview_start')
    void this.backupService().selectLocalBackup(fileName)
      .then((selection: BackupImportSelectionPreview) => {
        if (selection.preview.encrypted && !selection.preview.decrypted) {
          this.selectedEncryptedBackupPayload = selection.payload
          this.selectedBackupPayload = ''
        } else {
          this.selectedBackupPayload = selection.payload
          this.selectedEncryptedBackupPayload = ''
        }
        this.selectedBackupPreview = selection.preview
        this.importPassphrase = ''
        this.showToast(t('backup_preview_loaded_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'local_preview_failed', '[BackupManagement] step=local_preview_failed code=backup_preview_failed')
        this.showInfoDialog(t('backup_dialog_preview_failed_title'), this.backupFailureMessage('backup_preview_failed'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  private startRenameLocalBackup(record: BackupLocalFileRecord): void {
    this.editingLocalBackupFileName = record.fileName
    this.editingLocalBackupName = record.displayName
  }

  private cancelRenameLocalBackup(): void {
    this.editingLocalBackupFileName = ''
    this.editingLocalBackupName = ''
  }

  private persistRenameLocalBackup(): void {
    if (this.busy || this.editingLocalBackupFileName.length === 0) {
      return
    }
    this.busy = true
    const fileName = this.editingLocalBackupFileName
    const displayName = this.editingLocalBackupName
    console.info('[BackupManagement] step=local_rename_start')
    void this.backupService().renameLocalBackup(fileName, displayName)
      .then((_record: BackupLocalFileRecord) => {
        this.cancelRenameLocalBackup()
        this.loadLocalBackups()
        this.showToast(t('backup_local_renamed_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'local_rename_failed', '[BackupManagement] step=local_rename_failed code=backup_local_rename_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_local_rename_failed'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  private confirmDeleteLocalBackup(record: BackupLocalFileRecord): void {
    this.getUIContext().showAlertDialog({
      title: t('backup_local_delete_title'),
      message: t('backup_local_delete_message').replace('%s', record.displayName),
      autoCancel: true,
      primaryButton: {
        value: t('backup_local_delete_action'),
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.deleteLocalBackup(record.fileName)
        },
      },
      secondaryButton: {
        value: t('common_cancel'),
        action: () => {},
      },
    })
  }

  private deleteLocalBackup(fileName: string): void {
    if (this.busy) {
      return
    }
    this.busy = true
    console.info('[BackupManagement] step=local_delete_start')
    void this.backupService().deleteLocalBackup(fileName)
      .then(() => {
        this.loadLocalBackups()
        this.showToast(t('backup_local_deleted_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'local_delete_failed', '[BackupManagement] step=local_delete_failed code=backup_local_delete_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_local_delete_failed'))
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
        DiagnosticLogger.error('backup_management_page', 'decrypt_preview_failed', '[BackupManagement] step=decrypt_preview_failed code=backup_decrypt_failed')
        this.showInfoDialog(t('backup_dialog_decrypt_failed_title'), t('backup_decrypt_failed_message'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  private restoreSelectedBackup(): void {
    const preview = this.selectedBackupPreview
    if (this.busy || this.selectedBackupPayload.length === 0 || preview === undefined) {
      return
    }
    this.getUIContext().showAlertDialog({
      title: t('backup_restore_confirm_title'),
      message: this.restoreConfirmationMessage(preview),
      autoCancel: true,
      primaryButton: {
        value: t('backup_restore_confirm_action'),
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.runRestoreSelectedBackup()
        },
      },
      secondaryButton: {
        value: t('common_cancel'),
        action: () => {},
      },
    })
  }

  private restoreConfirmationMessage(preview: BackupImportPreview): string {
    return `${tf(
      'backup_restore_confirm_message',
      preview.libraryAddCount,
      preview.libraryConflictCount,
      preview.progressAddCount,
      preview.progressConflictCount,
    )}\n\n${backupImportConflictPolicy()}`
  }

  private runRestoreSelectedBackup(): void {
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
        this.onRestoreCompleted()
        this.selectedBackupPayload = ''
        this.selectedEncryptedBackupPayload = ''
        this.selectedBackupPreview = undefined
        this.showInfoDialog(t('backup_dialog_imported_title'), t('backup_imported_message'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'import_failed', '[BackupManagement] step=import_failed code=backup_import_failed')
        this.showInfoDialog(t('backup_dialog_import_failed_title'), this.backupFailureMessage('backup_import_failed'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  @Builder
  private TaskNavigationCard() {
    GroupedListSection() {
      ConciseListRow({ title: t('backup_task_create'), subtitle: t('backup_task_create_hint'),
        action: () => { this.onOpenTask('create', '') } })
      ListDivider()
      ConciseListRow({ title: t('backup_task_restore'), subtitle: t('backup_task_restore_hint'),
        action: () => { this.onOpenTask('restore', '') } })
      ListDivider()
      ConciseListRow({ title: t('backup_task_files'), trailingText: this.localBackupCountText(),
        action: () => { this.onOpenTask('files', '') } })
    }
  }

  @Builder
  private SettingsNavigationCard() {
    GroupedListSection() {
      ConciseListRow({ title: t('backup_task_settings'),
        subtitle: t(this.autoPreferences.enabled ? 'backup_auto_enabled_summary' : 'backup_auto_disabled_summary'),
        action: () => { this.onOpenTask('settings', '') } })
    }
  }

  @Builder
  private CreateActions() {
    Column() {
      KomaActionButton({ label: this.createActionLabel(), kind: 'primary', fullWidth: true,
        isEnabled: !this.busy, action: () => { this.createBackup() } })
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
  }

  @Builder
  private ContentSummaryCard() {
    GroupedListSection() {
      ConciseListRow({ title: t('backup_included_data'),
        subtitle: backupIncludedDomainLabels(this.contentPreferences).join('、'),
        subtitleMaxLines: 2147483647,
        action: () => { this.onOpenTask('settings', '') } })
    }
  }

  @Builder
  private TechnicalDetailsCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      ConciseListRow({ title: t('backup_technical_details'), showChevron: false,
        trailingText: t(this.showTechnicalDetails ? 'common_collapse' : 'common_expand'),
        action: () => { this.showTechnicalDetails = !this.showTechnicalDetails } })
      if (this.showTechnicalDetails) {
        this.StatusCard()
        this.StorageNoteCard()
      }
    }
    .width('100%')
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
      Text(backupEncryptionPlanLabel())
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
  private CreateFormCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      GroupedListSection() {
        ConciseListRow({
          title: t('backup_create_local_choice'),
          subtitle: t(this.createLocal ? 'backup_create_local_hint' : 'backup_create_file_hint'),
          hasSwitch: true, checked: this.createLocal, showChevron: false,
          switchAction: (value: boolean) => { this.createLocal = value },
        })
        ListDivider()
        ConciseListRow({
          title: t('backup_create_encrypted_choice'),
          hasSwitch: true, checked: this.createEncrypted, showChevron: false,
          switchAction: (value: boolean) => { this.createEncrypted = value },
        })
      }
      if (this.createEncrypted) {
        Column({ space: ThemeConstants.SPACE_SM }) {
          Text(t('backup_passphrase_recovery_warning'))
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          Text(backupPassphraseHelpText())
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        }
        .width('100%')
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
        GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
          Column({ space: ThemeConstants.SPACE_LG }) {
            KomaFormTextField({
              label: t('backup_passphrase_label'), value: this.exportPassphrase,
              isPassword: true, change: (value: string) => { this.exportPassphrase = value },
            })
            KomaFormTextField({
              label: t('backup_passphrase_confirm_label'), value: this.exportPassphraseConfirm,
              isPassword: true, change: (value: string) => { this.exportPassphraseConfirm = value },
            })
          }
          .width('100%')
        }
      } else {
        Text(backupUnencryptedExportWarning())
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
          .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      }
    }
    .width('100%')
  }

  @Builder
  private ContentPreferenceSwitchRow(label: string, checked: Binding<boolean>, onChange: (isOn: boolean) => void) {
    ConciseListRow({
      title: label, hasSwitch: true, checked: checked.value, showChevron: false,
      switchAction: (value: boolean) => { if (value !== checked.value) onChange(value) },
    })
  }

  @Builder
  private DomainsCard() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      GroupedListSection({ title: t('backup_included_data') }) {
        ForEach(backupIncludedDomainLabels({
          includeSettings: false, includeDownloadQueue: false, includeTrackerMappings: false,
        }), (domain: string) => {
          ConciseListRow({ title: domain, wrapTitle: true, showChevron: false })
          ListDivider()
        }, (domain: string) => domain)
        this.ContentPreferenceSwitchRow(t('backup_domain_reader_preferences'),
          UIUtils.makeBinding<boolean>(() => this.contentPreferences.includeSettings),
          (value: boolean) => { this.setBackupIncludeSettings(value) })
        ListDivider()
        this.ContentPreferenceSwitchRow(t('backup_domain_download_queue'),
          UIUtils.makeBinding<boolean>(() => this.contentPreferences.includeDownloadQueue),
          (value: boolean) => { this.setBackupIncludeDownloadQueue(value) })
        ListDivider()
        this.ContentPreferenceSwitchRow(t('backup_domain_tracker_mappings'),
          UIUtils.makeBinding<boolean>(() => this.contentPreferences.includeTrackerMappings),
          (value: boolean) => { this.setBackupIncludeTrackerMappings(value) })
      }
    }
    .width('100%')
  }

  @Builder
  private RestorePassphraseCard() {
    GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(backupPassphraseHelpText())
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        KomaFormTextField({
          label: t('backup_decrypt_passphrase_label'), value: this.importPassphrase,
          isPassword: true, change: (value: string) => { this.importPassphrase = value },
        })
      }
      .width('100%')
    }
  }

  @Builder
  private RestoreActions() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      if (this.selectedBackupPayload.length > 0) {
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
      }

      if (this.selectedEncryptedBackupPayload.length > 0) {
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
      KomaActionButton({
        label: this.busy ? t('backup_processing') : t('backup_select_preview_action'),
        kind: this.selectedBackupPreview === undefined ? 'primary' : 'secondary',
        fullWidth: true,
        icon: $r('sys.symbol.doc_plaintext'),
        isEnabled: !this.busy,
        action: () => { this.importBackup() },
      })
        .width('100%')
    }
    .width('100%')
    .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
  }

  @Builder
  private AutomaticIntervalMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(BACKUP_AUTOMATIC_INTERVAL_HOUR_OPTIONS, (intervalHours: number) => {
        MenuItem({ content: backupAutomaticIntervalLabel(intervalHours) })
          .onClick(() => {
            select(() => { this.setAutomaticBackupInterval(intervalHours) })
          })
      }, (intervalHours: number) => `${intervalHours}`)
    }
  }

  @Builder
  private AutomaticRetentionMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(BACKUP_AUTOMATIC_RETENTION_COUNT_OPTIONS, (retentionCount: number) => {
        MenuItem({ content: backupAutomaticRetentionLabel(retentionCount) })
          .onClick(() => {
            select(() => { this.setAutomaticBackupRetention(retentionCount) })
          })
      }, (retentionCount: number) => `${retentionCount}`)
    }
  }

  @Builder
  private AutomaticDirectoryMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: t('backup_auto_directory_local') })
        .onClick(() => { select(() => { this.saveAutomaticPreferences({ directoryUri: '' }) }) })
      MenuItem({ content: t('backup_auto_directory_choose') })
        .onClick(() => { select(() => { this.selectAutomaticDirectory() }) })
    }
  }

  @Builder
  private AutomaticBackupCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      SectionHeader({ title: t('backup_auto_heading') })
      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(t('backup_auto_description'))
          .width('100%').fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY).lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        Text(t('backup_auto_plaintext_note'))
          .width('100%').fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY).lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      GroupedListSection() {
        ConciseListRow({
          title: t('backup_auto_enabled_title'), subtitle: t('backup_auto_enabled_detail'),
          hasSwitch: true, checked: this.autoPreferences.enabled, showChevron: false,
          switchAction: (value: boolean) => { this.setAutomaticBackupEnabled(value) },
        })
        ListDivider()
        ConciseListRow({ title: t('backup_auto_directory'),
          trailingText: this.autoPreferences.directoryUri ? decodeURIComponent(this.autoPreferences.directoryUri.split('/').pop() ?? '') : t('backup_auto_directory_local'),
          isEnabled: !this.busy, trailingDropdown: true, dropdownMenuEnabled: true,
          dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutomaticDirectoryMenu(select) } })
        ListDivider()
        ConciseListRow({ title: t('backup_auto_background'), hasSwitch: true,
          checked: this.autoPreferences.backgroundEnabled === true, showChevron: false, isEnabled: !this.busy,
          switchAction: (enabled: boolean) => { this.saveAutomaticPreferences({ backgroundEnabled: enabled }) } })
        ListDivider()
        ConciseListRow({
          title: t('backup_auto_interval_label'),
          trailingText: backupAutomaticIntervalLabel(this.autoPreferences.intervalHours),
          trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.busy,
          dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutomaticIntervalMenu(select) },
        })
        ListDivider()
        ConciseListRow({
          title: t('backup_auto_retention_label'),
          trailingText: backupAutomaticRetentionLabel(this.autoPreferences.retentionCount),
          trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.busy,
          dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutomaticRetentionMenu(select) },
        })
        ListDivider()
        ConciseListRow({
          title: t('backup_auto_last_run_label'), trailingText: backupAutomaticLastRunText(this.autoPreferences),
          trailingMaxLines: 2, showChevron: false,
        })
        ListDivider()
        ConciseListRow({
          title: t('backup_auto_last_failure_label'), trailingText: backupAutomaticLastFailureText(this.autoPreferences),
          trailingMaxLines: 2, showChevron: false,
        })
      }
      KomaActionButton({
        label: this.busy ? t('backup_processing') : t('backup_auto_run_now_action'),
        kind: 'primary', fullWidth: true, isEnabled: !this.busy,
        action: () => { this.runAutomaticBackupNow() },
      })
        .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
    }
    .width('100%')
  }

  @Builder
  private LocalBackupActionMenu(record: BackupLocalFileRecord) {
    Menu() {
      MenuItem({ content: t('backup_local_rename_action') })
        .enabled(!this.busy)
        .onClick(() => {
          this.localFileActionMenuKey = ''
          this.startRenameLocalBackup(record)
        })
      MenuItem({ content: t('backup_local_delete_action') })
        .contentFontColor(ThemeConstants.DANGER)
        .enabled(!this.busy)
        .onClick(() => {
          this.localFileActionMenuKey = ''
          this.confirmDeleteLocalBackup(record)
        })
    }
  }

  @Builder
  private LocalBackupMoreButton(record: BackupLocalFileRecord) {
    KomaIconButton({
      icon: $r('sys.symbol.ellipsis_circle'), kind: 'ghost',
      controlSize: ThemeConstants.TOUCH_TARGET_SM,
      iconSize: ThemeConstants.FONT_SIZE_H3,
      accentColor: ThemeConstants.TEXT_SECONDARY,
      isEnabled: !this.busy,
      action: () => { this.localFileActionMenuKey = record.fileName },
    })
      .accessibilityText(t('common_more_actions'))
      .bindMenu(this.localFileActionMenuKey === record.fileName, this.LocalBackupActionMenu(record), komaMenuOptions({
        placement: Placement.BottomRight,
        onDisappear: () => {
          if (this.localFileActionMenuKey === record.fileName) this.localFileActionMenuKey = ''
        },
      }))
  }

  @Builder
  private LocalBackupRow(record: BackupLocalFileRecord) {
    if (this.editingLocalBackupFileName === record.fileName) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        KomaFormTextField({
          label: t('backup_local_rename_label'), value: this.editingLocalBackupName,
          change: (value: string) => { this.editingLocalBackupName = value },
        })
        Row({ space: ThemeConstants.SPACE_MD }) {
          KomaActionButton({ label: t('common_confirm'), kind: 'primary', fill: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT, isEnabled: !this.busy,
            action: () => { this.persistRenameLocalBackup() } })
          KomaActionButton({ label: t('common_cancel'), kind: 'secondary', fill: true,
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT, isEnabled: !this.busy,
            action: () => { this.cancelRenameLocalBackup() } })
        }
        .width('100%')
      }
      .width('100%').padding(ThemeConstants.SPACE_LG)
    } else {
      ConciseListRow({
        title: record.displayName, wrapTitle: true,
        subtitle: backupLocalFileDetailText(record) + '\n' + record.preview.encryptionText,
        subtitleMaxLines: 2147483647, showChevron: false, isEnabled: !this.busy,
        action: () => { this.onOpenTask('restore', record.fileName) },
        suffixBuilderParam: () => { this.LocalBackupMoreButton(record) },
      })
    }
  }

  @Builder
  private LocalBackupsCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      SectionHeader({ title: t('backup_local_heading') })
      Text(t('backup_local_description'))
        .width('100%').fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY).lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      GroupedListSection() {
        if (this.localBackupsLoading) {
          ConciseListRow({ title: t('common_loading'), showChevron: false })
        } else if (this.localBackupsFailed) {
          ConciseListRow({ title: t('backup_local_load_failed'),
            trailingText: t('common_retry'), showChevron: false,
            action: () => { this.loadLocalBackups() } })
        }
        if (this.localBackups.length === 0) {
          if (!this.localBackupsLoading && !this.localBackupsFailed) {
            ConciseListRow({ title: t('backup_local_empty'), showChevron: false })
          }
        } else {
          if (this.localBackupsLoading || this.localBackupsFailed) { ListDivider() }
          ForEach(this.localBackups, (record: BackupLocalFileRecord, index: number) => {
            this.LocalBackupRow(record)
            if (index < this.localBackups.length - 1) { ListDivider() }
          }, (record: BackupLocalFileRecord) => record.fileName)
        }
      }
    }
    .width('100%')
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
  }

  @Builder
  private PreviewRow(params: BackupPreviewRowParams) {
    Row() {
      Text(params.label)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .layoutWeight(1)
      Text(params.value)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
    }
    .width('100%')
  }

  @Builder
  private SelectedPreviewCard(params: SelectedBackupPreviewParams) {
    GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
      Text(t('backup_selected_heading'))
        .width('100%')
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      this.PreviewRow({ label: t('backup_preview_version'), value: `v${params.preview.schemaVersion}` })
      this.PreviewRow({ label: t('backup_preview_exported_at'), value: params.preview.exportedAtText })
      this.PreviewRow({ label: t('backup_preview_encryption_status'), value: params.preview.encryptionText })
      if (params.preview.encrypted && this.showPreviewDetails) {
        this.PreviewRow({ label: t('backup_preview_algorithm'), value: params.preview.algorithm })
        this.PreviewRow({ label: t('backup_preview_kdf'), value: params.preview.kdfId })
      }
      if (!params.preview.encrypted || params.preview.decrypted) {
        this.PreviewRow({ label: t('backup_preview_library_items'), value: `${params.preview.libraryItemCount}` })
        this.PreviewRow({ label: t('backup_preview_library_additions'), value: `${params.preview.libraryAddCount}` })
        this.PreviewRow({ label: t('backup_preview_library_conflicts'), value: `${params.preview.libraryConflictCount}` })
        this.PreviewRow({ label: t('backup_preview_progress'), value: `${params.preview.progressCount}` })
        this.PreviewRow({ label: t('backup_preview_progress_additions'), value: `${params.preview.progressAddCount}` })
        this.PreviewRow({ label: t('backup_preview_progress_conflicts'), value: `${params.preview.progressConflictCount}` })
        if (this.showPreviewDetails) {
          this.PreviewRow({ label: t('backup_preview_current_library_items'), value: `${params.preview.currentLibraryItemCount}` })
          this.PreviewRow({ label: t('backup_preview_current_progress'), value: `${params.preview.currentProgressCount}` })
          this.PreviewRow({ label: t('backup_preview_settings'), value: `${params.preview.settingsCount}` })
          this.PreviewRow({ label: t('backup_preview_categories'), value: `${params.preview.categoryCount}` })
          this.PreviewRow({
            label: t('backup_preview_download_queue'),
            value: params.preview.hasDownloadQueueCount ? `${params.preview.downloadQueueCount}` : t('backup_preview_not_provided'),
          })
          this.PreviewRow({
            label: t('backup_preview_tracker_mappings'),
            value: params.preview.hasTrackerMappingCount ? `${params.preview.trackerMappingCount}` : t('backup_preview_not_provided'),
          })
          this.PreviewRow({ label: t('backup_preview_source_package_metadata'), value: `${params.preview.sourcePackageCount}` })
          this.PreviewRow({ label: t('backup_preview_source_settings'), value: `${params.preview.sourceSettingsCount}` })
        }
      }
      ConciseListRow({ title: t('backup_preview_details'), showChevron: false,
        trailingText: t(this.showPreviewDetails ? 'common_collapse' : 'common_expand'),
        action: () => { this.showPreviewDetails = !this.showPreviewDetails } })
    }
      .width('100%')
    }
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
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
          if (this.pane === 'home') {
            ListItem() { this.TaskNavigationCard() }
            ListItem() { this.SettingsNavigationCard() }
          } else if (this.pane === 'create') {
            ListItem() { this.CreateFormCard() }
            ListItem() { this.CreateActions() }
            ListItem() { this.ContentSummaryCard() }
          } else if (this.pane === 'restore') {
            if (this.selectedBackupPreview !== undefined) {
              ListItem() { this.SelectedPreviewCard({ preview: this.selectedBackupPreview }) }
            }
            if (this.selectedEncryptedBackupPayload.length > 0) {
              ListItem() { this.RestorePassphraseCard() }
            }
            ListItem() { this.RestoreActions() }
            ListItem() { this.ImportPreviewIntroCard() }
          } else if (this.pane === 'files') {
            ListItem() { this.LocalBackupsCard() }
          } else if (this.pane === 'settings') {
            ListItem() { this.AutomaticBackupCard() }
            ListItem() { this.DomainsCard() }
            ListItem() {
              this.TechnicalDetailsCard()
            }
          }
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
    }
  }

  aboutToDisappear(): void {
    this.localBackupsEpoch += 1
  }

  aboutToAppear(): void {
    if (this.pane === 'home' || this.pane === 'files') {
      this.loadLocalBackups()
      this.loadAutomaticPreferences()
    } else if (this.pane === 'create') {
      this.loadContentPreferences()
    } else if (this.pane === 'settings') {
      this.loadAutomaticPreferences()
      this.loadContentPreferences()
    } else if (this.pane === 'restore' && this.localFileName.length > 0 && !this.localSelectionStarted) {
      this.localSelectionStarted = true
      this.selectLocalBackup(this.localFileName)
    }
  }
}

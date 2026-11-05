import { SymbolGlyphModifier } from '@kit.ArkUI'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { synchronizeBackgroundMaintenance } from '../model/BackgroundMaintenance'
import { selectAutomaticBackupDirectory, AutomaticBackupDirectorySelection } from '../model/BackupAutomaticDirectory'
import { komaMenuOptions, komaToastOptions, komaDialogMaterial } from '../theme/KomaPopupOptions'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { Binding, CustomContentDialogV2, LengthMetrics, UIUtils } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { KomaIconButton } from '../components/ui/KomaIconButton'
import { KomaFormTextField } from '../components/ui/KomaFormTextField'
import { KomaDialogActionRow } from '../components/ui/KomaTextInputDialog'
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
  BackupLocalFilePreview,
  BackupLocalFileRecord,
  BackupManagementState,
  BackupService,
  BackupAutomaticPreferencesPatch,
  DEFAULT_BACKUP_AUTOMATIC_PREFERENCES,
  DEFAULT_BACKUP_CONTENT_PREFERENCES,
  backupAutomaticIntervalLabel,
  backupAutomaticLastFailureText,
  backupAutomaticLastRunText,
  backupAutomaticRetentionLabel,
  backupEncryptionPlanLabel,
  backupImportConflictPolicy,
  backupLocalFileDetailText,
  backupManagementStorageNote,
  backupUnencryptedExportWarning,
} from '../model/BackupService'
import { BACKUP_PASSPHRASE_MIN_LENGTH } from '../model/BackupEncryptionService'
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

interface BackupSaveDraft {
  saveToFile: boolean
  encrypted: boolean
  passphrase: string
  confirmation: string
}

type BackupPreferenceLoadState = 'loading' | 'ready' | 'failed'
const BACKUP_DISCLOSURE_DURATION_MS: number = 200
const BACKUP_SECTIONS: string[] = ['backup-actions', 'device-sync', 'backup-files', 'backup-automatic', 'backup-content', 'backup-details']

@ComponentV2
export struct BackupManagementPage {
  @Param searchTarget: string = ''
  @Event onOpenDeviceSync: () => void = () => {}
  @Param backupScroller: Scroller = new Scroller()
  @Local private backupSafeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Param refreshRevision: number = 0
  @Event onRestoreCompleted: () => void = () => {}
  @Local private backupDialogShown: boolean = false
  private backupDialogId: number = -1
  private active: boolean = false
  private backupDialogRequest: number = 0
  private finishBackupDialogClose?: () => void = undefined
  @Local private backupDialog: 'save' | 'restore' = 'save'
  @Local private exportFileName: string = ''
  @Local private saveToFile: boolean = false
  @Local private encryptBackup: boolean = false
  @Local private passphraseError: string = ''
  @Local private selectedBackupName: string = ''
  @Local private showTechnicalDetails: boolean = false
  @Local private showAutomaticOptions: boolean = false
  @Local private showPreviewDetails: boolean = false
  @Local private busy: boolean = false
  @Local private selectedBackupPayload: string = ''
  @Local private selectedEncryptedBackupPayload: string = ''
  @Local private selectedBackupPreview: BackupImportPreview | undefined = undefined
  @Local private backupState: BackupManagementState = new BackupManagementState()
  @Local private localFileActionMenuKey: string = ''
  @Local private autoPreferences: BackupAutomaticPreferences = DEFAULT_BACKUP_AUTOMATIC_PREFERENCES
  @Local private automaticPreferencesState: BackupPreferenceLoadState = 'loading'
  private automaticPreferencesEpoch: number = 0
  @Local private automaticPreferencesSaving: boolean = false
  @Local private contentPreferences: BackupContentPreferences = DEFAULT_BACKUP_CONTENT_PREFERENCES
  @Local private contentPreferencesState: BackupPreferenceLoadState = 'loading'
  @Local private contentPreferencesSaving: boolean = false
  private contentPreferencesEpoch: number = 0
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
    this.loadLocalBackups()
    if (!this.automaticPreferencesSaving) this.loadAutomaticPreferences()
    this.loadContentPreferences()
  }

  private backupService(): BackupService {
    return new BackupService(this.context())
  }

  private loadLocalBackups(): void {
    void this.backupService().refreshLocalBackupList()
  }

  private lastLocalBackupFileName(): string | undefined {
    const records = this.backupState.records
    return records?.[records.length - 1]?.fileName
  }

  private loadAutomaticPreferences(): void {
    if (this.automaticPreferencesState === 'failed') this.automaticPreferencesState = 'loading'
    const epoch = ++this.automaticPreferencesEpoch
    void this.backupService().loadAutomaticPreferences()
      .then((preferencesValue: BackupAutomaticPreferences) => {
        if (epoch !== this.automaticPreferencesEpoch) return
        this.autoPreferences = preferencesValue
        this.automaticPreferencesState = 'ready'
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'auto_preferences_load_failed', '[BackupManagement] step=auto_preferences_load_failed code=backup_auto_preferences_failed')
        if (epoch !== this.automaticPreferencesEpoch) return
        this.automaticPreferencesState = 'failed'
      })
  }

  private loadContentPreferences(): void {
    if (this.contentPreferencesSaving) return
    if (this.contentPreferencesState === 'failed') this.contentPreferencesState = 'loading'
    const epoch = ++this.contentPreferencesEpoch
    void this.backupService().loadContentPreferences()
      .then((preferencesValue: BackupContentPreferences) => {
        if (epoch !== this.contentPreferencesEpoch) return
        this.contentPreferences = preferencesValue
        this.contentPreferencesState = 'ready'
      })
      .catch((_error: Error) => {
        DiagnosticLogger.warn('backup_management_page', 'content_preferences_load_failed', '[BackupManagement] step=content_preferences_load_failed code=backup_content_preferences_failed')
        if (epoch === this.contentPreferencesEpoch) this.contentPreferencesState = 'failed'
      })
  }

  private acceptedSchemaText(): string {
    return BACKUP_ACCEPTED_SCHEMA_VERSIONS.map((version: number) => `v${version}`).join(' / ')
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: message }))
    } catch (_error) {
    }
  }

  private showInfoDialog(title: string, message: string): void {
    void this.getUIContext().getPromptAction().showDialog({ systemMaterial: komaDialogMaterial(),
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

  private saveAutomaticPreferences(patch: BackupAutomaticPreferencesPatch): void {
    if (this.automaticPreferencesState !== 'ready' || this.automaticPreferencesSaving) return
    this.automaticPreferencesSaving = true
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
          this.automaticPreferencesState = 'loading'
          this.loadAutomaticPreferences()
        }
        this.showInfoDialog(t('backup_settings_save_failed'), t('backup_try_again'))
      })
      .finally(() => { this.automaticPreferencesSaving = false })
  }

  private saveContentPreferences(preferencesValue: BackupContentPreferences): void {
    if (this.contentPreferencesState !== 'ready' || this.contentPreferencesSaving) return
    this.contentPreferencesEpoch += 1
    this.contentPreferencesSaving = true
    void this.backupService().saveContentPreferences(preferencesValue)
      .then(() => {
        this.contentPreferences = preferencesValue
        this.showToast(t('backup_content_saved_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'content_preferences_save_failed', '[BackupManagement] step=content_preferences_save_failed code=backup_content_preferences_failed')
        this.contentPreferencesState = 'failed'
        this.showInfoDialog(t('backup_settings_save_failed'), t('backup_try_again'))
      })
      .finally(() => { this.contentPreferencesSaving = false })
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
    if (this.busy || this.automaticPreferencesSaving) return
    this.busy = true
    void selectAutomaticBackupDirectory(this.context())
      .then((selection: AutomaticBackupDirectorySelection | undefined): void => {
        if (selection !== undefined) this.saveAutomaticPreferences({ directoryUri: selection.uri, directoryOwnedModes: selection.ownedModes })
      }).catch((error: Error): void => {
        DiagnosticLogger.exception('backup', 'automatic_directory_failed', error)
        this.showToast(t('backup_auto_directory_select_failed'))
      })
      .finally(() => { this.busy = false })
  }

  private setAutomaticBackupEnabled(enabled: boolean): void {
    if (this.automaticPreferencesState !== 'ready' || enabled === this.autoPreferences.enabled) return
    this.saveAutomaticPreferences({ enabled })
  }

  private setAutomaticBackupInterval(intervalHours: number): void {
    if (intervalHours === this.autoPreferences.intervalHours) return
    this.saveAutomaticPreferences({ intervalHours })
  }

  private setAutomaticBackupRetention(retentionCount: number): void {
    if (retentionCount === this.autoPreferences.retentionCount) return
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

  private openSaveDialog(fileName: string = '', draft?: BackupSaveDraft): void {
    if (this.busy || this.backupDialogShown || (fileName.length === 0 && this.contentPreferencesSaving)) return
    this.clearSaveDialog()
    this.exportFileName = fileName
    if (draft !== undefined) {
      this.saveToFile = draft.saveToFile
      this.encryptBackup = draft.encrypted
      this.exportPassphrase = draft.passphrase
      this.exportPassphraseConfirm = draft.confirmation
    }
    this.openBackupDialog('save')
  }

  private openBackupDialog(kind: 'save' | 'restore'): void {
    const request = ++this.backupDialogRequest
    this.backupDialog = kind
    this.backupDialogShown = true
    const prompt = this.getUIContext().getPromptAction()
    void prompt.openCustomDialog({
      systemMaterial: komaDialogMaterial(),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      builder: () => { this.BackupDialogContent() },
      onWillDismiss: (action: DismissDialogAction): void => {
        if (!this.busy) action.dismiss()
      },
      onDidDisappear: (): void => {
        if (request === this.backupDialogRequest) this.resetBackupDialog()
      },
    }).then((id: number): void => {
      if (request === this.backupDialogRequest && this.backupDialogShown) {
        this.backupDialogId = id
        if (this.finishBackupDialogClose !== undefined) prompt.closeCustomDialog(id)
      } else {
        prompt.closeCustomDialog(id)
      }
    }).catch((): void => {
      if (request === this.backupDialogRequest) this.resetBackupDialog()
    })
  }

  private resetBackupDialog(): void {
    this.backupDialogId = -1
    this.backupDialogShown = false
    this.clearSaveDialog()
    this.clearRestorePreview()
    const finishClose = this.finishBackupDialogClose
    this.finishBackupDialogClose = undefined
    finishClose?.()
  }

  private closeBackupDialog(): Promise<void> {
    if (!this.backupDialogShown || this.finishBackupDialogClose !== undefined) return Promise.resolve()
    // Leave the mounted dialog's content intact until the native dismissal has completed.
    return new Promise<void>((resolve: () => void) => {
      this.finishBackupDialogClose = resolve
      if (this.backupDialogId >= 0) {
        this.getUIContext().getPromptAction().closeCustomDialog(this.backupDialogId)
      }
    })
  }

  private animateBackupDisclosure(update: () => void): void {
    const request = this.backupDialogRequest
    // Let the HDS row release its native click callback before relayout can replace it.
    setTimeout((): void => {
      if (request !== this.backupDialogRequest || !this.backupDialogShown ||
        this.finishBackupDialogClose !== undefined) return
      this.getUIContext().animateTo({ duration: BACKUP_DISCLOSURE_DURATION_MS, curve: Curve.FastOutSlowIn }, update)
    }, 0)
  }

  private clearSaveDialog(): void {
    this.exportPassphrase = ''
    this.exportPassphraseConfirm = ''
    this.passphraseError = ''
    this.exportFileName = ''
    this.encryptBackup = false
    this.saveToFile = false
  }

  private submitBackupSave(): void {
    if (this.busy || (this.exportFileName.length === 0 && this.contentPreferencesSaving)) return
    let passphrase: string | undefined = undefined
    if (this.encryptBackup) {
      if (this.exportPassphrase.length < BACKUP_PASSPHRASE_MIN_LENGTH) {
        this.passphraseError = t('backup_passphrase_too_short')
        return
      }
      if (this.exportPassphrase !== this.exportPassphraseConfirm) {
        this.passphraseError = t('backup_passphrase_mismatch')
        return
      }
      passphrase = this.exportPassphrase
    }
    const fileName = this.exportFileName
    if (this.saveToFile || fileName.length > 0) {
      this.exportBackupFile(fileName, passphrase)
    } else {
      this.createLocalBackup(passphrase)
    }
  }

  private exportBackupFile(fileName: string, passphrase?: string): void {
    if (this.busy) return
    const draft: BackupSaveDraft | undefined = this.backupDialogShown ? {
      saveToFile: this.saveToFile, encrypted: this.encryptBackup,
      passphrase: this.exportPassphrase, confirmation: this.exportPassphraseConfirm,
    } : undefined
    // The system picker owns its dialog. Reopen the same draft when the user cancels it.
    this.busy = true
    const dismissed = draft === undefined ? Promise.resolve() : this.closeBackupDialog()
    const service = this.backupService()
    // A named record exports its saved snapshot. Creating straight to a file does not write a local record.
    void dismissed.then((): Promise<string | undefined> => {
      if (fileName.length > 0) return service.exportLocalCopyToPicker(fileName, passphrase)
      return passphrase === undefined ? service.exportToPicker() : service.exportEncryptedToPicker(passphrase)
    })
      .then((uri: string | undefined) => {
        if (uri !== undefined) {
          this.showToast(t('backup_dialog_exported_title'))
        } else if (draft !== undefined && this.active) {
          this.busy = false
          this.openSaveDialog(fileName, draft)
        }
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'file_export_failed', '[BackupManagement] step=file_export_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_export_failed'))
      })
      .finally(() => { this.busy = false })
  }

  private createLocalBackup(passphrase?: string): void {
    if (this.busy || this.contentPreferencesSaving) return
    this.busy = true
    const service = this.backupService()
    // Both manual creation and the scheduler read the same saved content preferences.
    const operation = passphrase === undefined ? service.exportLocal() : service.exportEncryptedLocal(passphrase)
    void operation
      .then((_record: BackupLocalFileRecord) => {
        if (this.backupDialogShown) void this.closeBackupDialog()
        this.loadLocalBackups()
        this.showToast(t('backup_local_saved_toast'))
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'local_export_failed', '[BackupManagement] step=local_export_failed code=backup_local_export_failed')
        this.showInfoDialog(t('backup_dialog_export_failed_title'), this.backupFailureMessage('backup_local_export_failed'))
      })
      .finally(() => { this.busy = false })
  }

  private openRestorePreview(selection: BackupImportSelectionPreview, name: string): void {
    this.clearRestorePreview()
    if (selection.preview.encrypted && !selection.preview.decrypted) {
      this.selectedEncryptedBackupPayload = selection.payload
    } else {
      this.selectedBackupPayload = selection.payload
    }
    this.selectedBackupPreview = selection.preview
    this.selectedBackupName = name
    this.openBackupDialog('restore')
  }

  private clearRestorePreview(): void {
    this.selectedBackupPayload = ''
    this.selectedEncryptedBackupPayload = ''
    this.selectedBackupPreview = undefined
    this.selectedBackupName = ''
    this.showPreviewDetails = false
    this.importPassphrase = ''
  }

  private importBackup(): void {
    if (this.busy) return
    this.busy = true
    void this.backupService().selectImportPreviewFromPicker()
      .then((selection: BackupImportSelectionPreview | undefined) => {
        if (selection !== undefined) this.openRestorePreview(selection, '')
      })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'preview_failed', '[BackupManagement] step=preview_failed code=backup_preview_failed')
        this.showInfoDialog(t('backup_dialog_preview_failed_title'), this.backupFailureMessage('backup_preview_failed'))
      })
      .finally(() => { this.busy = false })
  }

  private isGeneratedBackupName(record: BackupLocalFileRecord): boolean {
    return record.preview.exportedAt > 0 && /^koma-backup-\d{13}(?:-\d+)?$/.test(record.displayName)
  }

  private backupDate(preview: BackupLocalFilePreview): string {
    if (preview.exportedAt <= 0) return preview.exportedAtText
    return new Intl.DateTimeFormat(this.languageState.effectiveLocale, {
      year: 'numeric', month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', second: '2-digit',
    }).format(new Date(preview.exportedAt))
  }

  private backupRecordTitle(record: BackupLocalFileRecord): string {
    return this.isGeneratedBackupName(record) ? this.backupDate(record.preview) : record.displayName
  }

  private selectLocalBackup(record: BackupLocalFileRecord): void {
    if (this.busy) return
    this.busy = true
    void this.backupService().selectLocalBackup(record.fileName)
      .then((selection: BackupImportSelectionPreview) => { this.openRestorePreview(selection, this.isGeneratedBackupName(record) ? '' : record.displayName) })
      .catch((_error: Error) => {
        DiagnosticLogger.error('backup_management_page', 'local_preview_failed', '[BackupManagement] step=local_preview_failed code=backup_preview_failed')
        this.showInfoDialog(t('backup_dialog_preview_failed_title'), this.backupFailureMessage('backup_preview_failed'))
      })
      .finally(() => { this.busy = false })
  }

  private startRenameLocalBackup(record: BackupLocalFileRecord): void {
    this.editingLocalBackupFileName = record.fileName
    this.editingLocalBackupName = this.isGeneratedBackupName(record) ? '' : record.displayName
  }

  private cancelRenameLocalBackup(): void {
    this.editingLocalBackupFileName = ''
    this.editingLocalBackupName = ''
  }

  private persistRenameLocalBackup(): void {
    if (this.busy || this.editingLocalBackupFileName.length === 0 || this.editingLocalBackupName.trim().length === 0) {
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
        this.showInfoDialog(t('backup_local_rename_failed_title'), t('backup_try_again'))
      })
      .finally(() => {
        this.busy = false
      })
  }

  private confirmDeleteLocalBackup(record: BackupLocalFileRecord): void {
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: t('backup_local_delete_title'),
      message: tf('backup_local_delete_message', this.backupRecordTitle(record)),
      autoCancel: true,
      primaryButton: {
        value: t('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: t('backup_local_delete_action'),
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.deleteLocalBackup(record.fileName)
        },
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
        this.showInfoDialog(t('backup_local_delete_failed_title'), t('backup_try_again'))
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
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(),
      title: t('backup_restore_confirm_title'),
      message: this.restoreConfirmationMessage(preview),
      autoCancel: true,
      primaryButton: {
        value: t('common_cancel'),
        action: () => {},
      },
      secondaryButton: {
        value: t('backup_restore_confirm_action'),
        fontColor: $r('app.color.koma_danger'),
        action: () => {
          this.runRestoreSelectedBackup()
        },
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
      .then(async (): Promise<void> => {
        this.onRefreshRevision()
        this.onRestoreCompleted()
        await this.closeBackupDialog()
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
  private BackupActions() {
    GroupedListSection() {
      ConciseListRow({ title: t('backup_task_create'), leadingIcon: $r('sys.symbol.plus'),
        isEnabled: !this.busy && !this.contentPreferencesSaving, action: () => { this.openSaveDialog() } })
      ListDivider()
      ConciseListRow({ title: t('backup_restore_from_file'), leadingIcon: $r('sys.symbol.doc_plaintext'),
        isEnabled: !this.busy, action: () => { this.importBackup() } })
    }
  }

  @Builder
  private BackupDialogContent() {
    if (this.backupDialog === 'restore') {
      this.RestorePreviewDialog()
    } else {
      this.BackupSaveDialog()
    }
  }

  @Builder
  private SaveDestinationMenu(select: (action: () => void) => void) {
    Menu() {
      MenuItem({ content: t('backup_destination_koma'),
        symbolEndIcon: !this.saveToFile ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { select(() => { this.saveToFile = false }) })
      MenuItem({ content: t('backup_destination_file'),
        symbolEndIcon: this.saveToFile ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined })
        .onClick(() => { select(() => { this.saveToFile = true }) })
    }
  }

  @Builder
  private BackupSaveOptions() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      if (!this.exportFileName) {
        ConciseListRow({ title: t('backup_create_destination'),
          trailingText: t(this.saveToFile ? 'backup_destination_file' : 'backup_destination_koma'),
          trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.busy,
          dropdownMenuBuilder: (select: (action: () => void) => void) => { this.SaveDestinationMenu(select) } })
      }
      ConciseListRow({ title: t('backup_create_encrypted_choice'), showChevron: false,
        hasSwitch: true, checked: this.encryptBackup, isEnabled: !this.busy,
        switchAction: (enabled: boolean) => {
          if (enabled === this.encryptBackup) return
          this.animateBackupDisclosure(() => {
            this.encryptBackup = enabled
            this.exportPassphrase = ''
            this.exportPassphraseConfirm = ''
            this.passphraseError = ''
          })
        } })
      if (this.encryptBackup) {
        Column({ space: ThemeConstants.SPACE_SM }) {
          KomaFormTextField({ label: t('backup_passphrase_label'), value: this.exportPassphrase, isPassword: true,
            isEnabled: !this.busy, change: (value: string) => { this.exportPassphrase = value; this.passphraseError = '' } })
          KomaFormTextField({ label: t('backup_passphrase_confirm_label'), value: this.exportPassphraseConfirm, isPassword: true,
            isEnabled: !this.busy, validationError: this.passphraseError || undefined,
            change: (value: string) => { this.exportPassphraseConfirm = value; this.passphraseError = '' } })
          Text(t('backup_passphrase_too_short') + '\n' + t('backup_passphrase_recovery_warning'))
            .width('100%').fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
        }.width('100%').transition(TransitionEffect.OPACITY)
      } else if (this.saveToFile || this.exportFileName.length > 0) {
        Text(backupUnencryptedExportWarning())
          .width('100%').fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
          .transition(TransitionEffect.OPACITY)
      }
    }.width('100%').clip(true)
  }

  @Builder
  private BackupSaveDialog() {
    CustomContentDialogV2({
      primaryTitle: t(this.exportFileName ? 'backup_export_copy' : 'backup_task_create'),
      contentBuilder: () => { this.BackupSaveDialogContent() },
    })
  }

  @Builder
  private BackupSaveDialogContent() {
    Column() {
      this.BackupSaveOptions()
      KomaDialogActionRow({
        busy: this.busy,
        confirmLabel: t(this.busy ? 'backup_processing' : this.saveToFile || this.exportFileName.length > 0 ?
          (this.encryptBackup ? 'backup_create_destination_file' : 'backup_unencrypted_confirm_action') : 'common_save'),
        cancel: () => { void this.closeBackupDialog() },
        confirm: () => { this.submitBackupSave() },
      })
    }.width('100%')
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

  private positionBackupSection(): void {
    // Search positions the same page without creating, importing or changing a preference.
    const index = BACKUP_SECTIONS.indexOf(this.searchTarget)
    if (index < 0) return
    const inset = this.backupSafeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT + ThemeConstants.SPACE_MD
    // The shared scaffold owns the first spacer item.
    this.backupScroller.scrollToIndex(index + 1, false, ScrollAlign.START, { extraOffset: LengthMetrics.vp(-inset) })
  }

  @Builder
  private ContentPreferenceSwitchRow(label: string, checked: Binding<boolean>, onChange: (isOn: boolean) => void) {
    ConciseListRow({
      title: label, hasSwitch: true, checked: checked.value, showChevron: false,
      isEnabled: !this.contentPreferencesSaving,
      switchAction: (value: boolean) => { if (value !== checked.value) onChange(value) },
    })
  }

  @Builder
  private DomainsCard() {
    Column({ space: ThemeConstants.SPACE_XS }) {
      GroupedListSection({ title: t('backup_content_heading') }) {
        if (this.contentPreferencesState === 'ready') {
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
        } else {
          this.PreferenceLoadRow(this.contentPreferencesState, () => { this.loadContentPreferences() })
        }
      }
      Text(t('backup_shared_content_description') + '\n' + t('backup_fixed_content_description'))
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
        .width('100%')
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
    }
    .width('100%')
  }

  @Builder
  private RestorePassphraseCard() {
    GroupedListSection({ inset: ThemeConstants.SPACE_LG }) {
      KomaFormTextField({
        label: t('backup_decrypt_passphrase_label'), value: this.importPassphrase,
        isPassword: true, isEnabled: !this.busy, change: (value: string) => { this.importPassphrase = value },
      })
    }
  }

  @Builder
  private RestorePreviewContent() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      if (this.selectedBackupPreview !== undefined) {
        this.SelectedPreviewCard({ preview: this.selectedBackupPreview })
      }
      if (this.selectedEncryptedBackupPayload.length > 0) {
        this.RestorePassphraseCard()
      }
    }.width('100%').clip(true)
  }

  @Builder
  private RestorePreviewDialog() {
    CustomContentDialogV2({
      primaryTitle: t('backup_restore_preview'),
      secondaryTitle: this.selectedBackupName,
      contentBuilder: () => { this.RestorePreviewDialogContent() },
    })
  }

  @Builder
  private RestorePreviewDialogContent() {
    Flex({ direction: FlexDirection.Column }) {
      Scroll() {
        this.RestorePreviewContent()
      }
      .width('100%')
      .height('auto')
      .flexShrink(1)
      .edgeEffect(EdgeEffect.None)
      KomaDialogActionRow({
        busy: this.busy,
        confirmEnabled: this.selectedBackupPayload.length > 0 || this.importPassphrase.length > 0,
        confirmLabel: t(this.busy ? 'backup_processing' : this.selectedEncryptedBackupPayload.length > 0 ?
          'backup_decrypt_preview_action' : 'backup_restore_selected_action'),
        cancel: () => { void this.closeBackupDialog() },
        confirm: () => {
          if (this.selectedEncryptedBackupPayload.length > 0) this.decryptSelectedBackup()
          else this.restoreSelectedBackup()
        },
      }).flexShrink(0)
    }.width('100%').height('auto')
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
  private PreferenceLoadRow(state: BackupPreferenceLoadState, retry: () => void) {
    if (state === 'failed') {
      ConciseListRow({ title: t('common_load_failed'), trailingText: t('common_retry'),
        showChevron: false, action: retry })
    } else {
      ConciseListRow({ title: t('common_loading'), showChevron: false })
    }
  }

  @Builder
  private AutomaticBackupControls() {
    GroupedListSection() {
      ConciseListRow({
        title: t('backup_auto_enabled_title'), subtitle: t('backup_auto_enabled_detail'),
        hasSwitch: true, checked: this.autoPreferences.enabled, showChevron: false,
        isEnabled: !this.busy && !this.automaticPreferencesSaving,
        switchAction: (value: boolean) => { this.setAutomaticBackupEnabled(value) },
      })
      if (!this.autoPreferences.enabled) {
        ListDivider()
        ConciseListRow({
          title: t('backup_auto_options'),
          trailingText: t(this.showAutomaticOptions ? 'common_collapse' : 'common_expand'),
          showChevron: false,
          action: () => { this.showAutomaticOptions = !this.showAutomaticOptions },
        })
      }
      if (this.showAutomaticOptions || this.autoPreferences.enabled) {
        ListDivider()
        ConciseListRow({ title: t('backup_auto_directory'),
          trailingText: this.autoPreferences.directoryUri ? decodeURIComponent(this.autoPreferences.directoryUri.split('/').pop() ?? '') : t('backup_auto_directory_local'),
          isEnabled: !this.busy && !this.automaticPreferencesSaving, trailingDropdown: true, dropdownMenuEnabled: true,
          dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutomaticDirectoryMenu(select) } })
        ListDivider()
        ConciseListRow({ title: t('backup_auto_background'), hasSwitch: true,
          checked: this.autoPreferences.backgroundEnabled === true, showChevron: false, isEnabled: !this.busy && !this.automaticPreferencesSaving,
          switchAction: (enabled: boolean) => {
            if (enabled !== (this.autoPreferences.backgroundEnabled === true)) {
              this.saveAutomaticPreferences({ backgroundEnabled: enabled })
            }
          } })
        ListDivider()
        ConciseListRow({
          title: t('backup_auto_interval_label'),
          trailingText: backupAutomaticIntervalLabel(this.autoPreferences.intervalHours),
          trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.busy && !this.automaticPreferencesSaving,
          dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutomaticIntervalMenu(select) },
        })
        ListDivider()
        ConciseListRow({
          title: t('backup_auto_retention_label'), subtitle: t('backup_auto_retention_detail'),
          trailingText: backupAutomaticRetentionLabel(this.autoPreferences.retentionCount),
          trailingDropdown: true, dropdownMenuEnabled: true, isEnabled: !this.busy && !this.automaticPreferencesSaving,
          dropdownMenuBuilder: (select: (action: () => void) => void) => { this.AutomaticRetentionMenu(select) },
        })
        ListDivider()
        ConciseListRow({
          title: t('backup_auto_last_run_label'), trailingText: backupAutomaticLastRunText(this.autoPreferences),
          trailingMaxLines: 2, showChevron: false,
        })
        if (this.autoPreferences.lastFailureCode.length > 0) {
          ListDivider()
          ConciseListRow({
            title: t('backup_auto_last_failure_label'), trailingText: backupAutomaticLastFailureText(this.autoPreferences),
            trailingMaxLines: 2, showChevron: false,
          })
        }
      }
      ListDivider()
      ConciseListRow({ title: t('backup_auto_run_now_action'), subtitle: t('backup_auto_run_now_detail'), showChevron: false,
        isEnabled: !this.busy && !this.automaticPreferencesSaving && !this.contentPreferencesSaving,
        action: () => { this.runAutomaticBackupNow() } })
    }
  }

  @Builder
  private AutomaticBackupCard() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      SectionHeader({ title: t('backup_auto_heading') })
      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(t('backup_auto_plaintext_note'))
          .width('100%').fontSize(ThemeConstants.FONT_SIZE_META)
          .fontColor(ThemeConstants.TEXT_SECONDARY).lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      // The native switch may report its mounted value through onChange.
      // Mount it with the saved value so neither a false frame nor a save can result from hydration.
      if (this.automaticPreferencesState === 'ready') {
        this.AutomaticBackupControls()
      } else {
        GroupedListSection() {
          this.PreferenceLoadRow(this.automaticPreferencesState, () => { this.loadAutomaticPreferences() })
        }
      }
    }
    .width('100%')
  }

  @Builder
  private LocalBackupActionMenu(record: BackupLocalFileRecord) {
    Menu() {
      MenuItem({ content: t('backup_export_copy') })
        .enabled(!this.busy)
        .onClick(() => {
          this.localFileActionMenuKey = ''
          if (record.preview.encrypted) this.exportBackupFile(record.fileName)
          else this.openSaveDialog(record.fileName)
        })
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
            controlHeight: ThemeConstants.ACTION_CHIP_HEIGHT,
            isEnabled: !this.busy && this.editingLocalBackupName.trim().length > 0,
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
        title: this.backupRecordTitle(record), wrapTitle: true,
        subtitle: backupLocalFileDetailText(record, this.isGeneratedBackupName(record) ? '' :
          this.backupDate(record.preview)) + ' · ' + t(record.preview.encrypted ? 'backup_record_encrypted' : 'backup_record_plain'),
        subtitleMaxLines: 2147483647, showChevron: false, isEnabled: !this.busy,
        action: () => { this.selectLocalBackup(record) },
        suffixBuilderParam: () => { this.LocalBackupMoreButton(record) },
      })
    }
  }

  @Builder
  private LocalBackupsCard() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      SectionHeader({ title: t('backup_local_heading') })
      Text(t('backup_local_records_note'))
        .width('100%').fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(ThemeConstants.TEXT_SECONDARY).lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
      GroupedListSection() {
        if (!this.backupState.records?.length) {
          if (this.backupState.failed) {
            this.LocalBackupsRetryRow()
          } else if (this.backupState.records === undefined) {
            ConciseListRow({ title: t('common_loading'), showChevron: false })
          } else {
            ConciseListRow({ title: t('backup_local_empty'), showChevron: false })
          }
        } else {
          ForEach(this.backupState.records ?? [], (record: BackupLocalFileRecord) => {
            this.LocalBackupRow(record)
            if (record.fileName !== this.lastLocalBackupFileName()) { ListDivider() }
          }, (record: BackupLocalFileRecord) =>
            JSON.stringify([record.fileName, record.sizeBytes, record.preview.exportedAt, record.preview.encrypted]))
        }
      }
      if (this.backupState.failed && (this.backupState.records?.length ?? 0) > 0) {
        this.LocalBackupsRetryRow()
      }
    }
    .width('100%')
  }

  @Builder
  private LocalBackupsRetryRow() {
    ConciseListRow({ title: t('backup_local_load_failed'), trailingText: t('common_retry'), showChevron: false,
      action: () => { this.loadLocalBackups() } })
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
    // The restore dialog supplies the surface for this summary.
    GroupedListSection({ inset: ThemeConstants.SPACE_LG, surfaceColor: Color.Transparent }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        this.PreviewRow({ label: t('backup_preview_exported_at'), value: this.backupDate(params.preview) })
        this.PreviewRow({ label: t('backup_preview_encryption_status'), value: params.preview.encryptionText })
        if (!params.preview.encrypted || params.preview.decrypted) {
          this.PreviewRow({ label: t('backup_preview_library_items'), value: `${params.preview.libraryItemCount}` })
          this.PreviewRow({ label: t('backup_preview_progress'), value: `${params.preview.progressCount}` })
          Text(backupImportConflictPolicy())
            .width('100%')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
        }
        ConciseListRow({ title: t('backup_preview_details'), showChevron: false,
          trailingText: t(this.showPreviewDetails ? 'common_collapse' : 'common_expand'),
          action: () => {
            this.animateBackupDisclosure(() => {
              this.showPreviewDetails = !this.showPreviewDetails
            })
          } })
        if (this.showPreviewDetails) {
          Column({ space: ThemeConstants.SPACE_MD }) {
            this.PreviewRow({ label: t('backup_preview_version'), value: `v${params.preview.schemaVersion}` })
            if (params.preview.encrypted) {
              this.PreviewRow({ label: t('backup_preview_algorithm'), value: params.preview.algorithm })
              this.PreviewRow({ label: t('backup_preview_kdf'), value: params.preview.kdfId })
            }
            if (!params.preview.encrypted || params.preview.decrypted) {
              this.PreviewRow({ label: t('backup_preview_progress_conflicts'), value: `${params.preview.progressConflictCount}` })
              this.PreviewRow({ label: t('backup_preview_progress_additions'), value: `${params.preview.progressAddCount}` })
              this.PreviewRow({ label: t('backup_preview_library_conflicts'), value: `${params.preview.libraryConflictCount}` })
              this.PreviewRow({ label: t('backup_preview_library_additions'), value: `${params.preview.libraryAddCount}` })
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
          }.width('100%').transition(TransitionEffect.OPACITY)
        }
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
          scroller: this.backupScroller,
          onListAttach: () => { this.positionBackupSection() },
          listSpace: ThemeConstants.SPACE_LG,
          bottomPadding: ThemeConstants.SPACE_XL,
        }) {
          ForEach(BACKUP_SECTIONS, (section: string) => {
            ListItem() {
              if (section === 'backup-actions') this.BackupActions()
              else if (section === 'device-sync') {
                GroupedListSection() {
                  ConciseListRow({ title: t('device_sync_title'), subtitle: t('device_sync_entry_detail'),
                    action: (): void => { this.onOpenDeviceSync() } })
                }
              } else if (section === 'backup-files') this.LocalBackupsCard()
              else if (section === 'backup-automatic') this.AutomaticBackupCard()
              else if (section === 'backup-content') this.DomainsCard()
              else this.TechnicalDetailsCard()
            }
          }, (section: string): string => section)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
    }
  }

  aboutToDisappear(): void {
    this.active = false
    if (this.backupDialogShown) void this.closeBackupDialog()
  }

  aboutToAppear(): void {
    this.active = true
    this.backupState = this.backupService().managementState()
    // Mount preference controls with the last saved/read values, never the defaults while a read is pending.
    if (this.backupState.automaticPreferences !== undefined) {
      this.autoPreferences = this.backupState.automaticPreferences
      this.automaticPreferencesState = 'ready'
    }
    if (this.backupState.contentPreferences !== undefined) {
      this.contentPreferences = this.backupState.contentPreferences
      this.contentPreferencesState = 'ready'
    }
    this.showAutomaticOptions = this.searchTarget === 'backup-automatic'
    this.onRefreshRevision()
  }
}

import { common } from '@kit.AbilityKit'
import { LocalImportCoordinator } from '../import/LocalImportCoordinator'
import {
  LocalArchiveImportDebugEvent,
} from '../import/LocalImportDebugModels'
import { AppStrings } from '../i18n/AppStrings'
import { Comic } from '../model/ComicModels'
import { LocalLibraryFolderScanResult } from '../model/LocalLibraryFolderContract'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'

type ImportEntryKind = 'archive' | 'images' | 'folder'

interface ImportEntryInfo {
  kind: ImportEntryKind
  titleKey: string
  actionKey: string
  icon: Resource
}

export interface LocalFolderImportPersistResult {
  importedCount: number
  checkedCount: number
  addedCount: number
  changedCount: number
  missingCount: number
  metadataChangedCount: number
  rejectedEntryCount: number
}

const ARCHIVE_ENTRY: ImportEntryInfo = {
  kind: 'archive',
  titleKey: 'import_archive_title',
  actionKey: 'import_archive_action',
  icon: $r('sys.symbol.doc_plaintext'),
}

const IMAGE_ENTRY: ImportEntryInfo = {
  kind: 'images',
  titleKey: 'import_image_title',
  actionKey: 'import_image_action',
  icon: $r('sys.symbol.picture'),
}

const FOLDER_ENTRY: ImportEntryInfo = {
  kind: 'folder',
  titleKey: 'import_folder_title',
  actionKey: 'import_folder_action',
  icon: $r('sys.symbol.folder'),
}

function t(name: string): string {
  return AppStrings.get(name)
}

function tf(name: string, ...args: Array<string | number>): string {
  return AppStrings.format(name, ...args)
}

function importDebugEventSummary(event: LocalArchiveImportDebugEvent): string {
  const errorState = event.error === undefined || event.error.length === 0 ? 'none' : 'redacted'
  return `uris=${event.uriCount ?? 0} pages=${event.pageCount ?? 0} error=${errorState}`
}

@ComponentV2
export struct ImportPage {
  @Local private feedbackText: string = ''
  @Local private importing: boolean = false
  @Local private activeImportKind: ImportEntryKind | '' = ''
  @Local private languageState: LanguageState = connectLanguageState()
  @Event onArchiveImportSucceeded: (comic: Comic) => void = (_comic: Comic) => {}
  @Event onLocalImageImportSucceeded: (comic: Comic) => void = (_comic: Comic) => {}
  @Event onLocalFolderImportSucceeded: (scanResult: LocalLibraryFolderScanResult, rootUri: string) => LocalFolderImportPersistResult =
    (_scanResult: LocalLibraryFolderScanResult, _rootUri: string) => ({
      importedCount: 0,
      checkedCount: 0,
      addedCount: 0,
      changedCount: 0,
      missingCount: 0,
      metadataChangedCount: 0,
      rejectedEntryCount: 0,
    })
  private readonly localImportCoordinator: LocalImportCoordinator = new LocalImportCoordinator()

  private logImportDebugEvent(event: LocalArchiveImportDebugEvent): void {
    console.info(`[Import] step=${event.step} ${importDebugEventSummary(event)}`)
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private isActiveImport(entry: ImportEntryInfo): boolean {
    return this.importing && this.activeImportKind === entry.kind
  }

  private openImportPicker(entry: ImportEntryInfo): void {
    if (entry.kind === 'images') {
      void this.selectImagesFromPicker()
      return
    }
    if (entry.kind === 'folder') {
      void this.selectFolderFromPicker()
      return
    }
    void this.selectArchiveFromPicker()
  }

  private async selectArchiveFromPicker(): Promise<void> {
    if (this.importing) {
      return
    }
    this.importing = true
    this.activeImportKind = 'archive'
    this.feedbackText = t('import_feedback_busy')
    console.info('[Import] step=archive_import_started')
    this.localImportCoordinator.setDebugSink((event: LocalArchiveImportDebugEvent) => {
      this.logImportDebugEvent(event)
    })
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const results = await this.localImportCoordinator.pickAndImportArchives(context, 1)
      let succeededCount = 0
      let failedCount = 0
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          succeededCount += 1
          return
        }
        failedCount += 1
      })
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          this.onArchiveImportSucceeded(result.extractionResult.importResult.comic)
        }
      })
      if (results.length === 0) {
        this.feedbackText = t('import_feedback_no_selection')
      } else if (failedCount === 0) {
        this.feedbackText = tf('import_feedback_success', succeededCount)
        this.showToast(this.feedbackText)
      } else if (succeededCount === 0) {
        this.feedbackText = tf('import_feedback_failed_files', failedCount)
      } else {
        this.feedbackText = tf('import_feedback_partial', succeededCount, failedCount)
        this.showToast(this.feedbackText)
      }
      console.info(`[Import] step=archive_import_finished succeeded=${succeededCount} failed=${failedCount}`)
    } catch (error) {
      console.error('[Import] step=archive_import_failed code=archive_import_failed')
      this.feedbackText = t('import_feedback_failed_file')
    } finally {
      this.localImportCoordinator.setDebugSink(undefined)
      this.importing = false
      this.activeImportKind = ''
    }
  }

  private async selectImagesFromPicker(): Promise<void> {
    if (this.importing) {
      return
    }
    this.importing = true
    this.activeImportKind = 'images'
    this.feedbackText = t('import_feedback_busy')
    console.info('[Import] step=image_import_started')
    this.localImportCoordinator.setDebugSink((event: LocalArchiveImportDebugEvent) => {
      this.logImportDebugEvent(event)
    })
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const results = await this.localImportCoordinator.pickAndImportImages(context)
      let succeededCount = 0
      let failedCount = 0
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          succeededCount += 1
          return
        }
        failedCount += 1
      })
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          this.onLocalImageImportSucceeded(result.importResult.comic)
        }
      })
      if (results.length === 0) {
        this.feedbackText = t('import_feedback_no_selection')
      } else if (failedCount === 0) {
        this.feedbackText = tf('import_feedback_success', succeededCount)
        this.showToast(this.feedbackText)
      } else if (succeededCount === 0) {
        this.feedbackText = t('import_feedback_failed_images')
      } else {
        this.feedbackText = tf('import_feedback_partial', succeededCount, failedCount)
        this.showToast(this.feedbackText)
      }
      console.info(`[Import] step=image_import_finished succeeded=${succeededCount} failed=${failedCount}`)
    } catch (error) {
      console.error('[Import] step=image_import_failed code=image_import_failed')
      this.feedbackText = t('import_feedback_failed_images')
    } finally {
      this.localImportCoordinator.setDebugSink(undefined)
      this.importing = false
      this.activeImportKind = ''
    }
  }

  private async selectFolderFromPicker(): Promise<void> {
    if (this.importing) {
      return
    }
    this.importing = true
    this.activeImportKind = 'folder'
    this.feedbackText = t('import_feedback_busy')
    console.info('[Import] step=folder_import_started')
    this.localImportCoordinator.setDebugSink((event: LocalArchiveImportDebugEvent) => {
      this.logImportDebugEvent(event)
    })
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const results = await this.localImportCoordinator.pickAndScanFolders(context, 1)
      let importedCount = 0
      let checkedCount = 0
      let addedCount = 0
      let changedCount = 0
      let missingCount = 0
      let metadataChangedCount = 0
      let rejectedEntryCount = 0
      let failedCount = 0
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          try {
            const persistResult = this.onLocalFolderImportSucceeded(result.scanResult, result.rootUri)
            importedCount += persistResult.importedCount
            checkedCount += persistResult.checkedCount
            addedCount += persistResult.addedCount
            changedCount += persistResult.changedCount
            missingCount += persistResult.missingCount
            metadataChangedCount += persistResult.metadataChangedCount
            rejectedEntryCount += persistResult.rejectedEntryCount
          } catch (error) {
            failedCount += 1
            console.error('[Import] step=folder_import_persist_failed code=library_persist_failed')
          }
          return
        }
        failedCount += 1
      })
      if (results.length === 0) {
        this.feedbackText = t('import_feedback_no_selection')
      } else if (importedCount > 0 && failedCount === 0 &&
        (addedCount > 0 || changedCount > 0 || metadataChangedCount > 0 || missingCount > 0 || rejectedEntryCount > 0)) {
        this.feedbackText = tf('import_feedback_folder_rescan_done', addedCount, changedCount, metadataChangedCount, missingCount, rejectedEntryCount)
        this.showToast(this.feedbackText)
      } else if (importedCount > 0 && failedCount === 0) {
        this.feedbackText = tf('import_feedback_success', importedCount)
        this.showToast(this.feedbackText)
      } else if (importedCount > 0) {
        this.feedbackText = tf('import_feedback_partial', importedCount, failedCount)
        this.showToast(this.feedbackText)
      } else if (failedCount > 0) {
        this.feedbackText = t('import_feedback_folder_unavailable')
      } else if (checkedCount > 0 && (missingCount > 0 || rejectedEntryCount > 0)) {
        this.feedbackText = tf('import_feedback_folder_rescan_missing', missingCount, rejectedEntryCount)
        this.showToast(this.feedbackText)
      } else if (checkedCount > 0) {
        this.feedbackText = t('import_feedback_folder_rescan_unchanged')
        this.showToast(this.feedbackText)
      } else {
        this.feedbackText = t('import_feedback_folder_empty')
      }
      console.info('[Import] step=folder_import_finished imported=' + importedCount +
        ' checked=' + checkedCount +
        ' added=' + addedCount +
        ' changed=' + changedCount +
        ' metadata_changed=' + metadataChangedCount +
        ' missing=' + missingCount +
        ' rejected=' + rejectedEntryCount +
        ' failed=' + failedCount)
    } catch (error) {
      console.error('[Import] step=folder_import_failed code=folder_import_failed')
      this.feedbackText = t('import_feedback_folder_unavailable')
    } finally {
      this.localImportCoordinator.setDebugSink(undefined)
      this.importing = false
      this.activeImportKind = ''
    }
  }

  @Builder
  private ImportEntryRow(entry: ImportEntryInfo) {
    if (this.isActiveImport(entry)) {
      ConciseListRow({
        title: t(entry.titleKey),
        subtitle: t('import_button_busy'),
        leadingIcon: entry.icon,
        leadingIconBackgroundColor: ThemeConstants.SOURCE_LOCAL_COLOR,
        showChevron: false,
      })
    } else {
      ConciseListRow({
        title: t(entry.titleKey),
        subtitle: t(entry.actionKey),
        leadingIcon: entry.icon,
        leadingIconBackgroundColor: ThemeConstants.SOURCE_LOCAL_COLOR,
        isEnabled: !this.importing,
        action: () => {
          this.openImportPicker(entry)
        },
      })
    }
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        ListItem() {
          SectionHeader({ title: t('import_heading_detail') })
        }
        ListItem() {
          GroupedListSection() {
            this.ImportEntryRow(ARCHIVE_ENTRY)
            ListDivider()
            this.ImportEntryRow(IMAGE_ENTRY)
            ListDivider()
            this.ImportEntryRow(FOLDER_ENTRY)
          }
        }
        if (!this.importing && this.feedbackText.length > 0) {
          ListItem() {
            Text(this.feedbackText)
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .lineHeight(ThemeConstants.LINE_HEIGHT_BODY)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .padding({ left: ThemeConstants.SPACE_SM, right: ThemeConstants.SPACE_SM })
          }
        }
      }
    }
  }
}

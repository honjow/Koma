import { common } from '@kit.AbilityKit'
import { LocalImportCoordinator } from '../import/LocalImportCoordinator'
import {
  LocalArchiveImportDebugEvent,
} from '../import/LocalImportDebugModels'
import { AppStrings } from '../i18n/AppStrings'
import { Comic } from '../model/ComicModels'
import { LocalLibraryFolderScanResult } from '../model/LocalLibraryFolderContract'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { ThemeConstants } from '../theme/ThemeConstants'

interface ImportEntryInfo {
  titleKey: string
  actionKey: string
  accentColor: string
}

export interface LocalFolderImportPersistResult {
  importedCount: number
  checkedCount: number
  missingCount: number
}

const ARCHIVE_ENTRY: ImportEntryInfo = {
  titleKey: 'import_archive_title',
  actionKey: 'import_archive_action',
  accentColor: ThemeConstants.SOURCE_LOCAL_COLOR,
}

const IMAGE_ENTRY: ImportEntryInfo = {
  titleKey: 'import_image_title',
  actionKey: 'import_image_action',
  accentColor: ThemeConstants.SOURCE_OPDS_COLOR,
}

const FOLDER_ENTRY: ImportEntryInfo = {
  titleKey: 'import_folder_title',
  actionKey: 'import_folder_action',
  accentColor: ThemeConstants.SOURCE_WEBDAV_COLOR,
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
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private languageState: LanguageState = connectLanguageState()
  @Event onArchiveImportSucceeded: (comic: Comic) => void = (_comic: Comic) => {}
  @Event onLocalImageImportSucceeded: (comic: Comic) => void = (_comic: Comic) => {}
  @Event onLocalFolderImportSucceeded: (scanResult: LocalLibraryFolderScanResult, rootUri: string) => LocalFolderImportPersistResult =
    (_scanResult: LocalLibraryFolderScanResult, _rootUri: string) => ({ importedCount: 0, checkedCount: 0, missingCount: 0 })
  private readonly localImportCoordinator: LocalImportCoordinator = new LocalImportCoordinator()

  private topContentInset(): number {
    return this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT
  }

  private bottomContentInset(): number {
    return this.safeArea.bottomAvoidHeight + ThemeConstants.FLOAT_BAR_HEIGHT + 20
  }

  private logImportDebugEvent(event: LocalArchiveImportDebugEvent): void {
    console.info(`[Import] step=${event.step} ${importDebugEventSummary(event)}`)
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private displayedFeedbackText(): string {
    return this.feedbackText.length > 0 ? this.feedbackText : t('import_feedback_idle')
  }

  private async selectArchiveFromPicker(): Promise<void> {
    if (this.importing) {
      return
    }
    this.importing = true
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
    }
  }

  private async selectImagesFromPicker(): Promise<void> {
    if (this.importing) {
      return
    }
    this.importing = true
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
    }
  }

  private async selectFolderFromPicker(): Promise<void> {
    if (this.importing) {
      return
    }
    this.importing = true
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
      let missingCount = 0
      let failedCount = 0
      results.forEach((result) => {
        if (result.status === 'succeeded') {
          try {
            const persistResult = this.onLocalFolderImportSucceeded(result.scanResult, result.rootUri)
            importedCount += persistResult.importedCount
            checkedCount += persistResult.checkedCount
            missingCount += persistResult.missingCount
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
      } else if (importedCount > 0 && failedCount === 0 && missingCount === 0) {
        this.feedbackText = tf('import_feedback_success', importedCount)
        this.showToast(this.feedbackText)
      } else if (importedCount > 0 && failedCount === 0) {
        this.feedbackText = tf('import_feedback_folder_rescan_done', importedCount, missingCount)
        this.showToast(this.feedbackText)
      } else if (importedCount > 0) {
        this.feedbackText = tf('import_feedback_partial', importedCount, failedCount)
        this.showToast(this.feedbackText)
      } else if (failedCount > 0) {
        this.feedbackText = t('import_feedback_folder_unavailable')
      } else if (checkedCount > 0 && missingCount > 0) {
        this.feedbackText = tf('import_feedback_folder_rescan_missing', missingCount)
        this.showToast(this.feedbackText)
      } else if (checkedCount > 0) {
        this.feedbackText = t('import_feedback_folder_rescan_unchanged')
        this.showToast(this.feedbackText)
      } else {
        this.feedbackText = t('import_feedback_folder_empty')
      }
      console.info(`[Import] step=folder_import_finished imported=${importedCount} checked=${checkedCount} missing=${missingCount} failed=${failedCount}`)
    } catch (error) {
      console.error('[Import] step=folder_import_failed code=folder_import_failed')
      this.feedbackText = t('import_feedback_folder_unavailable')
    } finally {
      this.localImportCoordinator.setDebugSink(undefined)
      this.importing = false
    }
  }

  @Builder
  private ImportEntryCard(entry: ImportEntryInfo) {
    Column({ space: ThemeConstants.SPACE_LG }) {
      Row({ space: ThemeConstants.SPACE_MD }) {
        Stack({ alignContent: Alignment.Center }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontColor([ThemeConstants.TEXT_ON_BRAND])
        }
        .width(ThemeConstants.SOURCE_ICON_SIZE)
        .height(ThemeConstants.SOURCE_ICON_SIZE)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .backgroundColor(entry.accentColor)

        Text(t(entry.titleKey))
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      }
      .width('100%')

      KomaActionButton({
        label: this.importing ? t('import_button_busy') : t(entry.actionKey),
        kind: 'primary',
        accentColor: entry.accentColor,
        icon: entry.titleKey === IMAGE_ENTRY.titleKey
          ? $r('sys.symbol.picture')
          : entry.titleKey === FOLDER_ENTRY.titleKey
            ? $r('sys.symbol.folder')
            : $r('sys.symbol.doc_plaintext'),
        isEnabled: !this.importing,
        controlHeight: 42,
        action: () => {
          if (entry.titleKey === IMAGE_ENTRY.titleKey) {
            this.selectImagesFromPicker()
          } else if (entry.titleKey === FOLDER_ENTRY.titleKey) {
            this.selectFolderFromPicker()
          } else {
            this.selectArchiveFromPicker()
          }
        },
      })
        .width('100%')
      if (this.importing) {
        LoadingProgress()
          .width(22)
          .height(22)
      }
    }
    .width('100%')
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(ThemeConstants.CARD)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    if (this.languageState.effectiveLocale.length >= 0) {
      Scroll() {
        Column({ space: 18 }) {
          Column({ space: 6 }) {
            Text(t('route_import_title'))
              .fontSize(ThemeConstants.SPACE_XXL)
              .fontWeight(FontWeight.Bold)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
            Text(t('import_heading_detail'))
              .fontSize(ThemeConstants.FONT_SIZE_TITLE)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: ThemeConstants.SPACE_MD }) {
            Text(t('import_status_heading'))
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontWeight(FontWeight.Medium)
              .fontColor(ThemeConstants.BRAND_PRIMARY)
            Text(this.displayedFeedbackText())
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
          }
          .width('100%')
          .padding(ThemeConstants.SPACE_LG)
          .borderRadius(ThemeConstants.RADIUS_CARD)
          .backgroundColor(ThemeConstants.CARD)
          .alignItems(HorizontalAlign.Start)

          this.ImportEntryCard(ARCHIVE_ENTRY)
          this.ImportEntryCard(IMAGE_ENTRY)
          this.ImportEntryCard(FOLDER_ENTRY)
        }
        .width('100%')
        .height('100%')
        .padding({ left: 20, right: 20, top: this.topContentInset(), bottom: this.bottomContentInset() })
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ThemeConstants.BG_SUB)
    }
  }
}

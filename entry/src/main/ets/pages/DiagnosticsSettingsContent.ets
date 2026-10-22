import { common } from '@kit.AbilityKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { pasteboard } from '@kit.BasicServicesKit'
import { systemShare } from '@kit.ShareKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { AppStrings } from '../i18n/AppStrings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { DiagnosticsFileExport } from '../diagnostics/DiagnosticsFileExport'
import { DiagnosticsLogFileInfo, DiagnosticsLogFileSink } from '../diagnostics/DiagnosticsLogFileSink'
import { DiagnosticsSettings } from '../diagnostics/DiagnosticsSettings'
import { connectDiagnostics, DiagnosticsState } from '../state/DiagnosticsState'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { GroupedListSection, ListDivider, SectionHeader } from '../components/ui/GroupedListSection'
import { ThemeConstants } from '../theme/ThemeConstants'

@ComponentV2
export struct DiagnosticsSettingsContent {
  @Local private diagnostics: DiagnosticsState = connectDiagnostics()
  @Local private files: DiagnosticsLogFileInfo[] = []
  @Local private count: number = 0
  @Local private busy: boolean = false
  private shareController?: systemShare.ShareController

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  aboutToAppear(): void {
    this.refresh()
  }

  private refresh(): void {
    this.count = DiagnosticLogger.count()
    this.files = DiagnosticsLogFileSink.listRetainedLogFiles()
  }

  private toast(key: string): void {
    this.getUIContext().getPromptAction().showToast({ message: AppStrings.get(key) })
  }

  private saveSettings(enabled: boolean, minLevel: string): void {
    const snapshot = DiagnosticsSettings.current()
    snapshot.enabled = enabled
    snapshot.minLevel = minLevel
    void DiagnosticsSettings.save(this.context(), snapshot).then(() => this.refresh()).catch(() => {
      this.toast('diagnostics_settings_failed')
    })
  }

  private share(fileName: string, uri: string, text: string): void {
    try {
      const record: systemShare.SharedRecord = {
        utd: utd.UniformDataType.FILE, title: fileName,
        description: AppStrings.get('diagnostics_title'), uri: uri,
      }
      this.shareController = new systemShare.ShareController(new systemShare.SharedData(record))
      void this.shareController.show(this.context(), {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DEFAULT,
      }).catch(() => this.copy(text))
    } catch (_error) {
      this.copy(text)
    }
  }

  private copy(text: string): void {
    try {
      pasteboard.getSystemPasteboard().setDataSync(pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text))
      this.toast('diagnostics_copied')
    } catch (_error) {
      this.toast('diagnostics_export_failed')
    }
  }

  private exportCurrent(): void {
    try {
      const file = DiagnosticsFileExport.create(this.context())
      this.share(file.fileName, file.uri, file.text)
      this.refresh()
    } catch (_error) {
      this.toast('diagnostics_export_failed')
    }
  }

  private async saveCurrent(): Promise<void> {
    if (this.busy) return
    this.busy = true
    let file: fileIo.File | undefined = undefined
    try {
      const exported = DiagnosticsFileExport.create(this.context())
      const options = new picker.DocumentSaveOptions()
      options.newFileNames = [exported.fileName]
      options.fileSuffixChoices = [AppStrings.get('diagnostics_file_choice')]
      const uris = await new picker.DocumentViewPicker(this.context()).save(options)
      if (uris.length === 0) return
      file = fileIo.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(file.fd, exported.text)
      DiagnosticLogger.info('diagnostics', 'file_saved', 'saved=true')
      this.toast('diagnostics_saved')
    } catch (_error) {
      DiagnosticLogger.warn('diagnostics', 'file_save_failed', 'saved=false')
      this.toast('diagnostics_export_failed')
    } finally {
      if (file !== undefined) {
        try { fileIo.closeSync(file) } catch (_error) {}
      }
      this.busy = false
      this.refresh()
    }
  }

  private fileTitle(file: DiagnosticsLogFileInfo): string {
    const date = new Date(file.createdAtMs)
    const time = date.getFullYear() + '-' + (date.getMonth() + 1).toString().padStart(2, '0') + '-' +
      date.getDate().toString().padStart(2, '0') + ' ' + date.getHours().toString().padStart(2, '0') + ':' +
      date.getMinutes().toString().padStart(2, '0') + ':' + date.getSeconds().toString().padStart(2, '0')
    return AppStrings.format(file.isCurrent ? 'diagnostics_current_file' : 'diagnostics_previous_file', time)
  }

  @Builder
  private LevelMenu(select: (action: () => void) => void) {
    Menu() {
      ForEach(['debug', 'info', 'warn', 'error'], (level: string) => {
        MenuItem({ content: level.toUpperCase() })
          .onClick(() => select(() => this.saveSettings(this.diagnostics.enabled, level)))
      }, (level: string) => level)
    }
  }

  build() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      GroupedListSection() {
        ConciseListRow({
          title: AppStrings.get('diagnostics_enabled'),
          subtitle: AppStrings.get('diagnostics_privacy'),
          hasSwitch: true, checked: this.diagnostics.enabled,
          switchAction: (value: boolean) => this.saveSettings(value, this.diagnostics.minLevel),
        })
        ListDivider()
        ConciseListRow({
          title: AppStrings.get('diagnostics_level'), trailingText: this.diagnostics.minLevel.toUpperCase(),
          trailingDropdown: true, dropdownMenuEnabled: true,
          dropdownMenuBuilder: (select: (action: () => void) => void) => { this.LevelMenu(select) },
        })
      }
      GroupedListSection() {
        ConciseListRow({
          title: AppStrings.format('diagnostics_count', this.count), showChevron: false,
          action: () => this.refresh(),
        })
        ListDivider()
        ConciseListRow({ title: AppStrings.get('diagnostics_export'), action: () => this.exportCurrent() })
        ListDivider()
        ConciseListRow({ title: AppStrings.get('diagnostics_save'), isEnabled: !this.busy,
          action: () => { void this.saveCurrent() } })
        ListDivider()
        ConciseListRow({ title: AppStrings.get('diagnostics_marker'), showChevron: false,
          action: () => {
            DiagnosticLogger.info('diagnostics', 'manual_marker', 'user_marked=true')
            this.refresh()
            this.toast('diagnostics_marker_written')
          } })
        ListDivider()
        ConciseListRow({ title: AppStrings.get('diagnostics_clear_memory'), showChevron: false,
          action: () => { DiagnosticsSettings.clearLogs(); this.refresh() } })
      }
      Column({ space: ThemeConstants.SPACE_XS }) {
        SectionHeader({ title: AppStrings.get('diagnostics_history') })
        GroupedListSection() {
          if (this.files.length === 0) {
            ConciseListRow({ title: AppStrings.get('diagnostics_empty'), showChevron: false })
          } else {
            ForEach(this.files, (file: DiagnosticsLogFileInfo, index: number) => {
              ConciseListRow({ title: this.fileTitle(file),
                subtitle: AppStrings.format('diagnostics_file_detail', Math.max(1, Math.round(file.sizeBytes / 1024))),
                action: () => this.share(file.fileName, file.uri, DiagnosticsLogFileSink.readLogFileText(file.fileName)),
              })
              if (index < this.files.length - 1) { ListDivider() }
            }, (file: DiagnosticsLogFileInfo) => file.fileName)
          }
        }
        Text(AppStrings.get('diagnostics_retention'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
    }
    .width('100%')
  }
}

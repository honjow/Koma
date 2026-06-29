import { common } from '@kit.AbilityKit'
import { LocalImportCoordinator } from '../import/LocalImportCoordinator'
import {
  LocalArchiveImportDebugEvent,
  formatLocalArchiveImportDebugEvent,
} from '../import/LocalImportDebugModels'
import { Comic } from '../model/ComicModels'
import { KomaActionButton } from '../components/ui/KomaActionButton'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'

interface ImportEntryInfo {
  title: string
  actionText: string
  accentColor: string
}

const ARCHIVE_ENTRY: ImportEntryInfo = {
  title: 'CBZ / ZIP',
  actionText: '选择文件',
  accentColor: ThemeConstants.SOURCE_LOCAL_COLOR,
}

const IMAGE_ENTRY: ImportEntryInfo = {
  title: '图片',
  actionText: '选择多张图片',
  accentColor: ThemeConstants.SOURCE_OPDS_COLOR,
}

@ComponentV2
export struct ImportPage {
  @Local private feedbackText: string = '选择本地漫画文件。'
  @Local private importing: boolean = false
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Event onArchiveImportSucceeded: (comic: Comic) => void = (_comic: Comic) => {}
  @Event onLocalImageImportSucceeded: (comic: Comic) => void = (_comic: Comic) => {}
  private readonly localImportCoordinator: LocalImportCoordinator = new LocalImportCoordinator()

  private topContentInset(): number {
    return this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT
  }

  private bottomContentInset(): number {
    return this.safeArea.bottomAvoidHeight + ThemeConstants.FLOAT_BAR_HEIGHT + 20
  }

  private logImportDebugEvent(event: LocalArchiveImportDebugEvent): void {
    const path = event.sourceUri ?? event.extractionDir ?? event.sandboxZipPath ?? event.cacheRootDir ?? ''
    console.info(`[Import] step=${event.step} path=${path} ${formatLocalArchiveImportDebugEvent(event)}`)
  }

  private showToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_err) {
    }
  }

  private async selectArchiveFromPicker(): Promise<void> {
    if (this.importing) {
      return
    }
    this.importing = true
    this.feedbackText = '正在导入...'
    console.info('[Import] step=archive_import_started path=')
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
        this.feedbackText = '未选择文件。'
      } else if (failedCount === 0) {
        this.feedbackText = `已导入 ${succeededCount} 本。`
        this.showToast(this.feedbackText)
      } else if (succeededCount === 0) {
        this.feedbackText = `无法导入文件。失败 ${failedCount} 个。`
      } else {
        this.feedbackText = `已导入 ${succeededCount} 本，失败 ${failedCount} 个。`
        this.showToast(this.feedbackText)
      }
      console.info(`[Import] step=archive_import_finished path= succeeded=${succeededCount} failed=${failedCount}`)
    } catch (error) {
      console.error('[Import] step=archive_import_failed path= error=' + `${error}`)
      this.feedbackText = '无法导入文件。'
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
    this.feedbackText = '正在导入...'
    console.info('[Import] step=image_import_started path=')
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
        this.feedbackText = '未选择文件。'
      } else if (failedCount === 0) {
        this.feedbackText = `已导入 ${succeededCount} 本。`
        this.showToast(this.feedbackText)
      } else if (succeededCount === 0) {
        this.feedbackText = `无法导入图片。`
      } else {
        this.feedbackText = `已导入 ${succeededCount} 本，失败 ${failedCount} 个。`
        this.showToast(this.feedbackText)
      }
      console.info(`[Import] step=image_import_finished path= succeeded=${succeededCount} failed=${failedCount}`)
    } catch (error) {
      console.error('[Import] step=image_import_failed path= error=' + `${error}`)
      this.feedbackText = '无法导入图片。'
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
          Text('+')
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_ON_BRAND)
        }
        .width(ThemeConstants.SOURCE_ICON_SIZE)
        .height(ThemeConstants.SOURCE_ICON_SIZE)
        .borderRadius(ThemeConstants.RADIUS_CHIP)
        .backgroundColor(entry.accentColor)

        Text(entry.title)
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      }
      .width('100%')

      KomaActionButton({
        label: this.importing ? '导入中...' : entry.actionText,
        kind: 'primary',
        accentColor: entry.accentColor,
        icon: entry.title === IMAGE_ENTRY.title ? $r('sys.symbol.picture') : $r('sys.symbol.doc_plaintext'),
        isEnabled: !this.importing,
        controlHeight: 42,
        action: () => {
          if (entry.title === IMAGE_ENTRY.title) {
            this.selectImagesFromPicker()
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
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text('导入')
            .fontSize(ThemeConstants.SPACE_XXL)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
          Text('添加到书架')
            .fontSize(ThemeConstants.FONT_SIZE_TITLE)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: ThemeConstants.SPACE_MD }) {
          Text('状态')
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.BRAND_PRIMARY)
          Text(this.feedbackText)
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

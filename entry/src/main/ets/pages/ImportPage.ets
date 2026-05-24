import { common } from '@kit.AbilityKit'
import { LocalImportCoordinator } from '../import/LocalImportCoordinator'
import {
  LocalArchiveImportDebugEvent,
  formatLocalArchiveImportDebugEvent,
} from '../import/LocalImportDebugModels'
import { Comic } from '../model/ComicModels'

interface ImportEntryInfo {
  title: string
  actionText: string
  accentColor: string
}

const ARCHIVE_ENTRY: ImportEntryInfo = {
  title: 'CBZ / ZIP',
  actionText: '选择文件',
  accentColor: '#256E5D',
}

const IMAGE_ENTRY: ImportEntryInfo = {
  title: '图片',
  actionText: '选择多张图片',
  accentColor: '#80612D',
}

@Component
export struct ImportPage {
  @State private feedbackText: string = '选择本地漫画文件。'
  @State private importing: boolean = false
  onArchiveImportSucceeded: (comic: Comic) => void = (_comic: Comic) => {}
  onLocalImageImportSucceeded: (comic: Comic) => void = (_comic: Comic) => {}
  private readonly localImportCoordinator: LocalImportCoordinator = new LocalImportCoordinator()

  private logImportDebugEvent(event: LocalArchiveImportDebugEvent): void {
    const path = event.sourceUri ?? event.extractionDir ?? event.sandboxZipPath ?? event.cacheRootDir ?? ''
    console.info(`[Import] step=${event.step} path=${path} ${formatLocalArchiveImportDebugEvent(event)}`)
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
      } else if (succeededCount === 0) {
        this.feedbackText = `无法导入文件。失败 ${failedCount} 个。`
      } else {
        this.feedbackText = `已导入 ${succeededCount} 本，失败 ${failedCount} 个。`
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
      } else if (succeededCount === 0) {
        this.feedbackText = `无法导入图片。`
      } else {
        this.feedbackText = `已导入 ${succeededCount} 本，失败 ${failedCount} 个。`
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
    Column({ space: 16 }) {
      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text('+')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)
        .borderRadius(8)
        .backgroundColor(entry.accentColor)

        Text(entry.title)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      }
      .width('100%')

      Button(this.importing ? '导入中...' : entry.actionText)
        .height(42)
        .width('100%')
        .borderRadius(8)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(entry.accentColor)
        .enabled(!this.importing)
        .onClick(() => {
          if (entry.title === IMAGE_ENTRY.title) {
            this.selectImagesFromPicker()
          } else {
            this.selectArchiveFromPicker()
          }
        })
      if (this.importing) {
        LoadingProgress()
          .width(22)
          .height(22)
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text('导入')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.koma_text_primary'))
          Text('添加到书架')
            .fontSize(15)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 10 }) {
          Text('状态')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_accent'))
          Text(this.feedbackText)
            .fontSize(14)
            .lineHeight(22)
            .fontColor($r('app.color.koma_text_primary'))
        }
        .width('100%')
        .padding(16)
        .borderRadius(8)
        .backgroundColor($r('app.color.koma_card'))
        .alignItems(HorizontalAlign.Start)

        this.ImportEntryCard(ARCHIVE_ENTRY)
        this.ImportEntryCard(IMAGE_ENTRY)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 20, right: 20, top: 24, bottom: 28 })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
  }
}

interface ImportEntryInfo {
  title: string
  description: string
  actionText: string
  badge: string
  badgeColor: string
  accentColor: string
  feedback: string
}

const ARCHIVE_ENTRY: ImportEntryInfo = {
  title: '导入 CBZ/ZIP',
  description: '选择一个或多个漫画压缩包。后续会复制到 Koma 沙盒，再进行索引和解压。',
  actionText: '选择压缩包',
  badge: '推荐',
  badgeColor: '#E66A3A',
  accentColor: '#16745F',
  feedback: '下一步会打开系统文件选择器，并仅筛选 .cbz / .zip 文件。'
}

const IMAGE_ENTRY: ImportEntryInfo = {
  title: '导入图片',
  description: '适合零散页面或单章图片。Koma 会按文件名和页码规则整理阅读顺序。',
  actionText: '选择图片',
  badge: '本地',
  badgeColor: '#344E7A',
  accentColor: '#344E7A',
  feedback: '下一步会打开系统图片选择器，可一次选择多张图片。'
}

const FOLDER_ENTRY: ImportEntryInfo = {
  title: '文件夹导入',
  description: '实验功能，依赖设备是否支持文件夹选择；若无法枚举目录，请改用 CBZ/ZIP 或多选图片。',
  actionText: '尝试选择文件夹',
  badge: '实验',
  badgeColor: '#8A6240',
  accentColor: '#8A6240',
  feedback: '文件夹选择受系统能力限制；失败时请把文件夹压缩为 ZIP/CBZ，或直接多选图片。'
}

const PRIVATE_LIBRARY_ENTRY: ImportEntryInfo = {
  title: '私有库接入',
  description: 'Komga、OPDS、WebDAV 会作为私有库入口加入，不提供公共源或源市场。',
  actionText: '稍后接入',
  badge: '规划中',
  badgeColor: '#51624D',
  accentColor: '#51624D',
  feedback: '私有库入口会在账号和同步边界稳定后接入；当前版本先完成本地导入。'
}

@Component
export struct ImportPage {
  @State private feedbackText: string = '选择一种本地导入方式，当前页面只展示入口和后续系统 picker 边界。'

  @Builder
  private ImportEntryCard(entry: ImportEntryInfo) {
    Column({ space: 14 }) {
      Row({ space: 10 }) {
        Stack({ alignContent: Alignment.Center }) {
          Text(entry.title.substring(0, 1))
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(48)
        .height(48)
        .borderRadius(16)
        .backgroundColor(entry.accentColor)

        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(entry.title)
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_primary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(entry.badge)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .borderRadius(10)
              .backgroundColor(entry.badgeColor)
          }
          .width('100%')

          Text(entry.description)
            .fontSize(14)
            .lineHeight(21)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Button(entry.actionText)
        .height(42)
        .width('100%')
        .borderRadius(21)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(entry.accentColor)
        .onClick(() => {
          this.feedbackText = entry.feedback
        })
    }
    .width('100%')
    .padding(16)
    .borderRadius(22)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Column({ space: 6 }) {
          Text('导入')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.koma_text_primary'))
          Text('从本地文件开始建立私有漫画书架')
            .fontSize(15)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        Column({ space: 10 }) {
          Text('当前选择')
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
        .borderRadius(22)
        .backgroundColor('#FFFFF8F4')
        .alignItems(HorizontalAlign.Start)

        this.ImportEntryCard(ARCHIVE_ENTRY)
        this.ImportEntryCard(IMAGE_ENTRY)
        this.ImportEntryCard(FOLDER_ENTRY)
        this.ImportEntryCard(PRIVATE_LIBRARY_ENTRY)
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 28 })
    }
    .width('100%')
    .height('100%')
  }
}

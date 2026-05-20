import { ComicCoverCard, ComicCoverInfo } from '../components/ComicCoverCard'

interface ContinueReadingInfo {
  title: string
  detail: string
  progress: number
  color: string
}

const MOCK_COMICS: ComicCoverInfo[] = [
  {
    id: 'local-01',
    title: '雨后街区',
    subtitle: '本地 ZIP - 12 章',
    progressText: '第 8 话',
    coverColor: '#16745F',
    accentColor: '#2FAE84'
  },
  {
    id: 'local-02',
    title: '北窗短篇集',
    subtitle: '图片文件夹 - 6 章',
    progressText: '未读',
    coverColor: '#344E7A',
    accentColor: '#6E92CE'
  },
  {
    id: 'local-03',
    title: '海边的慢速列车',
    subtitle: 'CBZ - 4 章',
    progressText: '42%',
    coverColor: '#8A6240',
    accentColor: '#D39A62'
  },
  {
    id: 'local-04',
    title: '午后三点的笔记',
    subtitle: '本地 ZIP - 18 章',
    progressText: '第 3 话',
    coverColor: '#7A405D',
    accentColor: '#C46B92'
  },
  {
    id: 'local-05',
    title: '旧书店巡礼',
    subtitle: '图片文件夹 - 9 章',
    progressText: '新加入',
    coverColor: '#51624D',
    accentColor: '#89A57D'
  },
  {
    id: 'local-06',
    title: '银河便签',
    subtitle: 'CBZ - 21 章',
    progressText: '第 15 话',
    coverColor: '#4C4A70',
    accentColor: '#928FD2'
  }
]

const CONTINUE_READING: ContinueReadingInfo = {
  title: '雨后街区',
  detail: '继续阅读 第 8 话 / 第 24 页',
  progress: 64,
  color: '#16745F'
}

@Component
export struct LibraryPage {
  private hasComics: boolean = true

  @Builder
  private ContinueReadingCard() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text('K')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(76)
      .height(102)
      .borderRadius(18)
      .backgroundColor(CONTINUE_READING.color)

      Column({ space: 8 }) {
        Text('继续阅读')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_accent'))
        Text(CONTINUE_READING.title)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.koma_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(CONTINUE_READING.detail)
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Progress({ value: CONTINUE_READING.progress, total: 100, type: ProgressType.Linear })
          .height(4)
          .color($r('app.color.koma_accent'))
          .backgroundColor('#1FE66A3A')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(16)
    .borderRadius(26)
    .backgroundColor($r('app.color.koma_card'))
  }

  @Builder
  private EmptyLibrary() {
    Column({ space: 14 }) {
      Text('Koma')
        .fontSize(34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))
      Text('还没有本地漫画')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text('导入 CBZ/ZIP 或图片文件夹后，会在这里显示封面、进度和最近阅读。')
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)
      Button('导入本地漫画')
        .height(46)
        .padding({ left: 24, right: 24 })
        .borderRadius(23)
        .fontSize(15)
        .backgroundColor($r('app.color.koma_accent'))
    }
    .width('100%')
    .padding(26)
    .borderRadius(28)
    .backgroundColor($r('app.color.koma_card'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private LibraryGrid() {
    Grid() {
      ForEach(MOCK_COMICS, (comic: ComicCoverInfo) => {
        GridItem() {
          ComicCoverCard({ comic: comic })
        }
      }, (comic: ComicCoverInfo) => comic.id)
    }
    .width('100%')
    .columnsTemplate('1fr 1fr 1fr')
    .columnsGap(14)
    .rowsGap(22)
    .layoutWeight(1)
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Column({ space: 6 }) {
          Text('书架')
            .fontSize(34)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.koma_text_primary'))
          Text('本地漫画和私有库内容会集中在这里')
            .fontSize(15)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.hasComics) {
          this.ContinueReadingCard()

          Row() {
            Text('最近加入')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.koma_text_primary'))
            Blank()
            Text(`${MOCK_COMICS.length} 本`)
              .fontSize(13)
              .fontColor($r('app.color.koma_text_secondary'))
          }
          .width('100%')

          this.LibraryGrid()
        } else {
          this.EmptyLibrary()
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 28 })
    }
    .width('100%')
    .height('100%')
  }
}

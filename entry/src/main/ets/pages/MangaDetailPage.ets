import { RouterHelper, MangaDetailRouteParam } from '../common/RouterHelper'

@Component
export struct MangaDetailPage {
  @Prop comicId: string = ''

  build() {
    Column({ space: 16 }) {
      Text('漫画详情')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.koma_text_primary'))

      Text(this.comicId.length === 0 ? '未指定漫画' : `comicId: ${this.comicId}`)
        .fontSize(14)
        .fontColor($r('app.color.koma_text_secondary'))

      Text('完整的详情页将由 F3 实现。')
        .fontSize(13)
        .lineHeight(20)
        .fontColor($r('app.color.koma_text_secondary'))
        .textAlign(TextAlign.Center)

      Button('返回')
        .height(40)
        .padding({ left: 22, right: 22 })
        .borderRadius(8)
        .fontSize(15)
        .backgroundColor($r('app.color.koma_accent'))
        .onClick(() => {
          RouterHelper.pop()
        })
    }
    .width('100%')
    .height('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('app.color.koma_background'))
  }
}

export function readMangaDetailRouteParam(rawParam: ESObject): MangaDetailRouteParam {
  const param = rawParam as MangaDetailRouteParam | undefined
  if (param === undefined || param.comicId === undefined) {
    return { comicId: '' }
  }
  return { comicId: param.comicId }
}

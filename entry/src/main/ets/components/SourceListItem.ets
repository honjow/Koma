import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

@Component
export struct SourceListItem {
  @Prop source: SourceRuntimeRegistryInstalledSourceSummary = {
    sourceId: '',
    displayName: '',
    version: '',
    wasmByteCount: 0,
    importStatus: 'staged',
    networkEnabled: false,
    httpEnabled: false,
    enabled: true,
    status: 'staged',
    capabilities: [],
  }
  @Prop languageBadge: string = 'SRC'
  onSourceTap: (source: SourceRuntimeRegistryInstalledSourceSummary) => void = (_source: SourceRuntimeRegistryInstalledSourceSummary) => {}

  private sourceInitial(): string {
    if (this.source.displayName.length === 0) {
      return 'K'
    }
    return this.source.displayName.substring(0, 1).toLocaleUpperCase()
  }

  build() {
    Row({ space: 14 }) {
      Stack({ alignContent: Alignment.Center }) {
        Text(this.sourceInitial())
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor($r('app.color.koma_accent'))

      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(this.source.displayName)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.languageBadge)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_accent'))
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(8)
            .backgroundColor('#1F256E5D')
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(`v${this.source.version} · ${this.source.importStatus}`)
          .fontSize(13)
          .fontColor($r('app.color.koma_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('>')
        .fontSize(18)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .width('100%')
    .padding(14)
    .borderRadius(8)
    .backgroundColor($r('app.color.koma_card'))
    .onClick(() => {
      this.onSourceTap(this.source)
    })
  }
}

import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  LibraryUpdateComicResult,
  LibraryUpdateResultStatus,
  LibraryUpdateSummary,
} from '../model/LibraryUpdateService'
import {
  LibraryUpdateResultStore,
  getLatestLibraryUpdateSummary,
  setLatestLibraryUpdateSummary,
} from '../model/LibraryUpdateResultStore'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct LibraryUpdateResultPage {
  @State private summary?: LibraryUpdateSummary = undefined

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private libraryUpdateResultStore(): LibraryUpdateResultStore {
    return new LibraryUpdateResultStore(this.context())
  }

  aboutToAppear(): void {
    const latest = getLatestLibraryUpdateSummary()
    this.summary = latest
    const total = latest === undefined ? 0 : latest.totalCount
    console.info('[LibraryUpdateResults] step=appear hasSummary=' + (latest !== undefined) + ' total=' + total)
    if (latest !== undefined) {
      return
    }
    void this.libraryUpdateResultStore().load()
      .then((summary: LibraryUpdateSummary | undefined) => {
        const current = getLatestLibraryUpdateSummary()
        let effectiveSummary = current
        if (summary !== undefined && (current === undefined || summary.checkedAt > current.checkedAt)) {
          setLatestLibraryUpdateSummary(summary)
          effectiveSummary = summary
        }
        this.summary = effectiveSummary
        const total = effectiveSummary === undefined ? 0 : effectiveSummary.totalCount
        console.info('[LibraryUpdateResults] step=load_persisted hasSummary=' + (effectiveSummary !== undefined) + ' total=' + total)
      })
      .catch((error: Error) => {
        console.warn('[LibraryUpdateResults] step=load_persisted_failed message=' + error.message)
      })
  }

  private formatTimestamp(value: number): string {
    const date = new Date(value)
    const year = `${date.getFullYear()}`
    const month = `${date.getMonth() + 1}`.padStart(2, '0')
    const day = `${date.getDate()}`.padStart(2, '0')
    const hour = `${date.getHours()}`.padStart(2, '0')
    const minute = `${date.getMinutes()}`.padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${minute}`
  }

  private statusLabel(status: LibraryUpdateResultStatus): string {
    if (status === 'updated') {
      return '更新'
    }
    if (status === 'unchanged') {
      return '未变化'
    }
    if (status === 'skipped') {
      return '跳过'
    }
    return '失败'
  }

  private statusColor(status: LibraryUpdateResultStatus): ResourceColor {
    if (status === 'updated') {
      return '#2F7D4F'
    }
    if (status === 'failed') {
      return '#B04444'
    }
    if (status === 'skipped') {
      return '#8D6A2E'
    }
    return $r('app.color.koma_text_secondary')
  }

  @Builder
  private EmptyState() {
    ListItem() {
      Column({ space: 8 }) {
        Text('尚无检查结果')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.koma_text_primary'))
        Text('请先在设置中运行检查书架更新')
          .fontSize(14)
          .fontColor($r('app.color.koma_text_secondary'))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 28 })
      .borderRadius(8)
      .backgroundColor($r('app.color.koma_card'))
    }
  }

  @Builder
  private SummaryMetric(label: string, value: number) {
    Column({ space: 4 }) {
      Text(`${value}`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.koma_text_primary'))
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.koma_text_secondary'))
    }
    .layoutWeight(1)
  }

  @Builder
  private SummaryCard(summary: LibraryUpdateSummary) {
    ListItem() {
      Column({ space: 16 }) {
        Row() {
          Text('最近检查')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.koma_text_primary'))
            .layoutWeight(1)
          Text(this.formatTimestamp(summary.checkedAt))
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
        }
        .width('100%')

        Row() {
          this.SummaryMetric('总计', summary.totalCount)
          this.SummaryMetric('更新', summary.updatedCount)
          this.SummaryMetric('未变化', summary.unchangedCount)
          this.SummaryMetric('跳过', summary.skippedCount)
          this.SummaryMetric('失败', summary.failedCount)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .borderRadius(8)
      .backgroundColor($r('app.color.koma_card'))
    }
  }

  @Builder
  private ResultRow(result: LibraryUpdateComicResult) {
    ListItem() {
      Column({ space: 8 }) {
        Row({ space: 12 }) {
          Text(result.comicId)
            .fontSize(15)
            .fontColor($r('app.color.koma_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.statusLabel(result.status))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor(result.status))
        }
        .width('100%')

        Row({ space: 12 }) {
          Text(`${result.previousChapterCount} -> ${result.newChapterCount}`)
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
          Text(result.message)
            .fontSize(13)
            .fontColor($r('app.color.koma_text_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .borderRadius(8)
      .backgroundColor($r('app.color.koma_card'))
    }
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: 12,
        horizontalPadding: 20,
        bottomPadding: ThemeConstants.FLOAT_BAR_HEIGHT + 20 + ThemeConstants.SPACE_XL,
      }) {
        if (this.summary === undefined) {
          this.EmptyState()
        } else {
          this.SummaryCard(this.summary as LibraryUpdateSummary)
          ForEach((this.summary as LibraryUpdateSummary).results, (result: LibraryUpdateComicResult) => {
            this.ResultRow(result)
          }, (result: LibraryUpdateComicResult) => result.comicId)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}

import { common } from '@kit.AbilityKit'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  LibraryUpdateComicResult,
  LibraryUpdateResultStatus,
  LibraryUpdateSummary,
  countLibraryUpdateNewChapters,
} from '../model/LibraryUpdateService'
import {
  LibraryUpdateJobSnapshot,
  LibraryUpdateResultStore,
  clearLatestLibraryUpdateSummary,
  getLatestLibraryUpdateJobSnapshot,
  getLatestLibraryUpdateSummary,
  setLatestLibraryUpdateJobSnapshot,
  setLatestLibraryUpdateSummary,
} from '../model/LibraryUpdateResultStore'
import { formatLibraryUpdateTimestamp } from '../model/LibraryUpdatePreferencesStore'
import { ThemeConstants } from '../theme/ThemeConstants'

@Component
export struct LibraryUpdateResultPage {
  @State private summary?: LibraryUpdateSummary = undefined
  @State private jobSnapshot?: LibraryUpdateJobSnapshot = undefined

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private libraryUpdateResultStore(): LibraryUpdateResultStore {
    return new LibraryUpdateResultStore(this.context())
  }

  aboutToAppear(): void {
    const latestJob = getLatestLibraryUpdateJobSnapshot()
    const latest = this.effectiveSummaryForJob(getLatestLibraryUpdateSummary(), latestJob)
    this.jobSnapshot = latestJob
    this.summary = latest
    const total = latest === undefined ? 0 : latest.totalCount
    const state = latestJob === undefined ? 'none' : latestJob.state
    console.info('[LibraryUpdateResults] step=appear hasSummary=' + (latest !== undefined) + ' total=' + total + ' state=' + state)
    void this.libraryUpdateResultStore().loadJobSnapshot()
      .then((snapshot: LibraryUpdateJobSnapshot | undefined) => {
        const currentJob = getLatestLibraryUpdateJobSnapshot()
        let effectiveJob = currentJob
        if (snapshot !== undefined && (currentJob === undefined || snapshot.updatedAt > currentJob.updatedAt)) {
          setLatestLibraryUpdateJobSnapshot(snapshot)
          effectiveJob = snapshot
        }
        this.jobSnapshot = effectiveJob
        if (this.isSummaryBlockedByJob(this.summary, effectiveJob)) {
          clearLatestLibraryUpdateSummary()
          this.summary = undefined
        }
        this.loadPersistedSummary(effectiveJob)
      })
      .catch((error: Error) => {
        console.warn('[LibraryUpdateResults] step=load_job_failed message=' + error.message)
        this.loadPersistedSummary(latestJob)
      })
  }

  private loadPersistedSummary(jobSnapshot: LibraryUpdateJobSnapshot | undefined): void {
    if (this.summary !== undefined && !this.isSummaryBlockedByJob(this.summary, jobSnapshot)) {
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
        this.summary = this.effectiveSummaryForJob(effectiveSummary, jobSnapshot)
        const total = effectiveSummary === undefined ? 0 : effectiveSummary.totalCount
        console.info('[LibraryUpdateResults] step=load_persisted hasSummary=' + (effectiveSummary !== undefined) + ' total=' + total)
      })
      .catch((error: Error) => {
        console.warn('[LibraryUpdateResults] step=load_persisted_failed message=' + error.message)
      })
  }

  private isFailureJobSnapshot(snapshot: LibraryUpdateJobSnapshot | undefined): boolean {
    return snapshot !== undefined && (snapshot.state === 'failed' || snapshot.state === 'backed-off')
  }

  private isSummaryBlockedByJob(
    summary: LibraryUpdateSummary | undefined,
    snapshot: LibraryUpdateJobSnapshot | undefined,
  ): boolean {
    if (!this.isFailureJobSnapshot(snapshot)) {
      return false
    }
    if (summary === undefined) {
      return true
    }
    return (snapshot as LibraryUpdateJobSnapshot).updatedAt >= summary.checkedAt
  }

  private effectiveSummaryForJob(
    summary: LibraryUpdateSummary | undefined,
    snapshot: LibraryUpdateJobSnapshot | undefined,
  ): LibraryUpdateSummary | undefined {
    return this.isSummaryBlockedByJob(summary, snapshot) ? undefined : summary
  }

  private formatTimestamp(value: number): string {
    return formatLibraryUpdateTimestamp(value)
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
      return ThemeConstants.STATUS_SUCCESS
    }
    if (status === 'failed') {
      return ThemeConstants.STATUS_DANGER
    }
    if (status === 'skipped') {
      return ThemeConstants.STATUS_WARNING
    }
    return ThemeConstants.TEXT_SECONDARY
  }

  @Builder
  private EmptyState() {
    ListItem() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Text(this.emptyStateTitle())
          .fontSize(ThemeConstants.FONT_SIZE_HEADING)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
        Text(this.emptyStateMessage())
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
      }
      .width('100%')
      .padding({
        left: ThemeConstants.SPACE_XL,
        right: ThemeConstants.SPACE_XL,
        top: ThemeConstants.SPACE_XXL,
        bottom: ThemeConstants.SPACE_XXL,
      })
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(ThemeConstants.CARD)
    }
  }

  private emptyStateTitle(): string {
    if (this.isFailureJobSnapshot(this.jobSnapshot)) {
      return (this.jobSnapshot as LibraryUpdateJobSnapshot).state === 'backed-off' ? '检查失败，已退避' : '检查失败'
    }
    return '尚无检查结果'
  }

  private emptyStateMessage(): string {
    if (this.isFailureJobSnapshot(this.jobSnapshot)) {
      const snapshot = this.jobSnapshot as LibraryUpdateJobSnapshot
      const code = snapshot.failureCode ?? 'unknown'
      if (snapshot.nextDueAt !== undefined && snapshot.nextDueAt > 0) {
        return `最近一次检查失败：${code}。下次前台检查 ${this.formatTimestamp(snapshot.nextDueAt)}`
      }
      return `最近一次检查失败：${code}`
    }
    return '请先在设置中运行检查书架更新'
  }

  @Builder
  private SummaryMetric(label: string, value: number) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(`${value}`)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .layoutWeight(1)
  }

  @Builder
  private SummaryCard(summary: LibraryUpdateSummary) {
    ListItem() {
      Column({ space: ThemeConstants.SPACE_LG }) {
        Row() {
          Text('最近检查')
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          Text(this.formatTimestamp(summary.checkedAt))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
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
        Row() {
          this.SummaryMetric('新章', countLibraryUpdateNewChapters(summary))
          Blank()
            .layoutWeight(4)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(ThemeConstants.CARD)
    }
  }

  @Builder
  private ResultRow(result: LibraryUpdateComicResult) {
    ListItem() {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Text(result.comicId)
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(this.statusLabel(result.status))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.statusColor(result.status))
        }
        .width('100%')

        Row({ space: ThemeConstants.SPACE_MD }) {
          Text(`${result.previousChapterCount} -> ${result.newChapterCount}`)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
          Text(result.message)
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .backgroundColor(ThemeConstants.CARD)
    }
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        horizontalPadding: ThemeConstants.SPACE_XL,
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
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

import { sourceDisplayName } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { common } from '@kit.AbilityKit'
import { RouterHelper } from '../common/RouterHelper'
import { SecondaryListScaffold } from '../components/SecondaryListScaffold'
import {
  LibraryUpdateComicResult,
  LibraryUpdateProviderSummary,
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
import { AppStrings } from '../i18n/AppStrings'
import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { connectLibraryUpdateState, LibraryUpdateState } from '../state/LibraryUpdateState'
import { LibraryStore } from '../model/LibraryStore'
import { SourceRuntimeRegistry, SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'
import { libraryUpdateComicTitle, libraryUpdateProviderTitle, LibraryUpdateSourceLabel } from '../model/LibraryUpdatePresentation'

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct LibraryUpdateResultPage {
  @Param libraryStore?: LibraryStore = undefined
  @Param sourceRegistry?: SourceRuntimeRegistry = undefined
  @Local private languageState: LanguageState = connectLanguageState()
  @Local private libraryUpdateState: LibraryUpdateState = connectLibraryUpdateState()
  @Local private summary?: LibraryUpdateSummary = undefined
  @Local private jobSnapshot?: LibraryUpdateJobSnapshot = undefined

  private context(): common.UIAbilityContext {
    return getContext(this) as common.UIAbilityContext
  }

  private libraryUpdateResultStore(): LibraryUpdateResultStore {
    return new LibraryUpdateResultStore(this.context())
  }

  aboutToAppear(): void {
    this.reloadResults()
  }

  @Monitor('libraryUpdateState.revision')
  private reloadResults(): void {
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
      .catch((_error: Error) => {
        console.warn('[LibraryUpdateResults] step=load_job_failed code=library_update_job_load_failed')
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
        this.summary = this.effectiveSummaryForJob(effectiveSummary, getLatestLibraryUpdateJobSnapshot() ?? jobSnapshot)
        const total = effectiveSummary === undefined ? 0 : effectiveSummary.totalCount
        console.info('[LibraryUpdateResults] step=load_persisted hasSummary=' + (effectiveSummary !== undefined) + ' total=' + total)
      })
      .catch((_error: Error) => {
        console.warn('[LibraryUpdateResults] step=load_persisted_failed code=library_update_result_load_failed')
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
    return (snapshot as LibraryUpdateJobSnapshot).updatedAt > summary.checkedAt
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
      return s('library_update_results_status_updated')
    }
    if (status === 'unchanged') {
      return s('library_update_results_status_unchanged')
    }
    if (status === 'skipped') {
      return s('library_update_results_status_skipped')
    }
    return s('library_update_results_status_failed')
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

  private providerTitle(summary: LibraryUpdateProviderSummary): string {
    const sources: LibraryUpdateSourceLabel[] = (this.sourceRegistry?.list() ?? [])
      .map((entry: SourceRuntimeRegistryEntry): LibraryUpdateSourceLabel => {
        return { id: entry.sourceId, name: sourceDisplayName(entry.sourceId, entry.manifestName) }
      })
    return libraryUpdateProviderTitle(summary, this.summary?.results ?? [], this.libraryStore?.listComics() ?? [], sources)
  }

  private providerCountsText(summary: LibraryUpdateProviderSummary): string {
    return AppStrings.format(
      'library_update_results_provider_counts',
      summary.totalCount,
      summary.updatedCount,
      summary.skippedCount,
      summary.failedCount,
      summary.newChapterCount,
    )
  }

  private providerFailureText(summary: LibraryUpdateProviderSummary): string {
    if (summary.failureCodes.length === 0) {
      return s('library_update_results_provider_no_failures')
    }
    return AppStrings.format('library_update_results_provider_failures', summary.failureCodes.join(','))
  }

  private openResultComic(result: LibraryUpdateComicResult): void {
    RouterHelper.pushMangaDetail({ mangaId: result.comicId })
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
      return (this.jobSnapshot as LibraryUpdateJobSnapshot).state === 'backed-off'
        ? s('library_update_results_empty_backed_off')
        : s('library_update_results_empty_failed')
    }
    return s('library_update_results_empty_none')
  }

  private emptyStateMessage(): string {
    if (this.isFailureJobSnapshot(this.jobSnapshot)) {
      const snapshot = this.jobSnapshot as LibraryUpdateJobSnapshot
      const code = snapshot.failureCode ?? 'unknown'
      if (snapshot.nextDueAt !== undefined && snapshot.nextDueAt > 0) {
        return s('library_update_results_failure_next_due')
          .replace('%s', code)
          .replace('%s', this.formatTimestamp(snapshot.nextDueAt))
      }
      return s('library_update_results_failure_last').replace('%s', code)
    }
    return s('library_update_results_run_first')
  }

  @Builder
  private SummaryMetric(label: string, metric: string) {
    Column({ space: ThemeConstants.SPACE_XS }) {
      Text(`${this.summaryMetricValue(metric)}`)
        .fontSize(ThemeConstants.FONT_SIZE_HEADING)
        .fontWeight(FontWeight.Medium)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
      Text(label)
        .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
        .fontColor(ThemeConstants.TEXT_SECONDARY)
    }
    .layoutWeight(1)
  }

  private summaryMetricValue(metric: string): number {
    const summary = this.summary
    if (summary === undefined) {
      return 0
    }
    switch (metric) {
      case 'total': return summary.totalCount
      case 'updated': return summary.updatedCount
      case 'unchanged': return summary.unchangedCount
      case 'skipped': return summary.skippedCount
      case 'failed': return summary.failedCount
      default: return countLibraryUpdateNewChapters(summary)
    }
  }

  @Builder
  private SummaryCard() {
    ListItem() {
      Column({ space: ThemeConstants.SPACE_LG }) {
        Row() {
          Text(s('library_update_results_recent_check'))
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          Text(this.summary === undefined ? '' : this.formatTimestamp(this.summary.checkedAt))
            .fontSize(ThemeConstants.FONT_SIZE_META)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
        .width('100%')

        Row() {
          this.SummaryMetric(s('library_update_results_metric_total'), 'total')
          this.SummaryMetric(s('library_update_results_metric_updated'), 'updated')
          this.SummaryMetric(s('library_update_results_metric_unchanged'), 'unchanged')
          this.SummaryMetric(s('library_update_results_metric_skipped'), 'skipped')
          this.SummaryMetric(s('library_update_results_metric_failed'), 'failed')
        }
        .width('100%')
        Row() {
          this.SummaryMetric(s('library_update_results_metric_new_chapters'), 'new-chapters')
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
  private ProviderSummaryCard() {
    ListItem() {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(s('library_update_results_provider_heading'))
          .width('100%')
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
        ForEach(this.summary?.providerSummaries ?? [], (provider: LibraryUpdateProviderSummary) => {
          Column({ space: ThemeConstants.SPACE_XS }) {
            Text(this.providerTitle(provider))
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_BODY)
              .fontColor(ThemeConstants.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.providerCountsText(provider))
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(ThemeConstants.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.providerFailureText(provider))
              .width('100%')
              .fontSize(ThemeConstants.FONT_SIZE_META)
              .fontColor(provider.failedCount > 0 ? ThemeConstants.STATUS_DANGER : ThemeConstants.TEXT_SECONDARY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
        }, (provider: LibraryUpdateProviderSummary) => `${this.summary?.checkedAt}:${provider.providerKind}:${provider.sourceKey}`)
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
          Text(libraryUpdateComicTitle(this.libraryStore?.getComic(result.comicId)))
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
      .onClick(() => {
        this.openResultComic(result)
      })
    }
  }

  build() {
    Column() {
      SecondaryListScaffold({
        listSpace: ThemeConstants.SPACE_MD,
        bottomPadding: ThemeConstants.SPACE_XL,
      }) {
        if (this.summary === undefined) {
          this.EmptyState()
        } else {
          this.SummaryCard()
          this.ProviderSummaryCard()
          ForEach(this.summary?.results ?? [], (result: LibraryUpdateComicResult) => {
            this.ResultRow(result)
          }, (result: LibraryUpdateComicResult) => `${this.summary?.checkedAt}:${result.comicId}`)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_SUB)
  }
}

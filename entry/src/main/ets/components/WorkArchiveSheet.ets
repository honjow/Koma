import { common } from '@kit.AbilityKit'
import { KomaModalScaffold } from './KomaModalScaffold'
import { KomaActionButton } from './ui/KomaActionButton'
import { Chapter, Comic } from '../model/ComicModels'
import { continuationChapterIds } from '../model/ReaderChapterSequence'
import { OfflineDownloadQueueEntry } from '../model/OfflineDownloadQueueStore'
import {
  ArchiveChapter, ChapterArchiveFile, CHAPTER_ARCHIVE_CANCELED, CHAPTER_ARCHIVE_INCOMPLETE, CHAPTER_ARCHIVE_SAVE_FAILED,
  discardPreparedArchive, prepareWorkArchive, saveChapterArchive,
} from '../model/ChapterArchiveExport'
import { ThemeConstants } from '../theme/ThemeConstants'
import { komaModalCardSurface } from '../theme/KomaPopupOptions'
import { AppStrings } from '../i18n/AppStrings'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'

interface WorkArchiveChapter extends ArchiveChapter {
  version: string
}

function s(name: string): string {
  return AppStrings.get(name)
}

@ComponentV2
export struct WorkArchiveSheet {
  @Param comicId: string = ''
  @Param comicTitle: string = ''
  @Param comic?: Comic = undefined
  @Param entries: OfflineDownloadQueueEntry[] = []
  @Event onClose: () => void = () => {}
  @Local private chapters: WorkArchiveChapter[] = []
  @Local private selected: Set<string> = new Set<string>()
  @Local private multipleVersions: boolean = false
  @Local private exporting: boolean = false
  @Local private progressText: string = ''
  @Local private errorText: string = ''
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()
  private canceled: boolean = false

  aboutToAppear(): void {
    const catalog = this.comic?.chapters ?? []
    const byId = new Map<string, Chapter>()
    catalog.forEach((chapter: Chapter): void => { byId.set(chapter.id, chapter) })
    const versions = new Map<string, WorkArchiveChapter[]>()
    for (const entry of this.entries) {
      const chapter = byId.get(entry.chapterId)
      const version = [chapter?.language ?? '', chapter?.scanlator ?? ''].filter((value: string): boolean =>
        value.length > 0).join(' · ')
      const item: WorkArchiveChapter = { id: entry.chapterId, title: entry.chapterTitle ?? chapter?.title ?? entry.chapterId, version }
      const group = versions.get(version)
      if (group === undefined) versions.set(version, [item])
      else group.push(item)
    }
    const ordered: WorkArchiveChapter[] = []
    this.multipleVersions = versions.size > 1
    versions.forEach((group: WorkArchiveChapter[]): void => {
      const sequence = continuationChapterIds(catalog, group[0].id) ?? []
      const rank = new Map<string, number>()
      sequence.forEach((id: string, index: number): void => { rank.set(id, index) })
      // Prefer a verified reading sequence. Legacy rows remain visible in a
      // deterministic preview and can be reordered before writing the CBZ.
      group.sort((left: WorkArchiveChapter, right: WorkArchiveChapter): number =>
        (rank.get(left.id) ?? Number.MAX_SAFE_INTEGER) - (rank.get(right.id) ?? Number.MAX_SAFE_INTEGER) ||
        (byId.get(left.id)?.index ?? Number.MAX_SAFE_INTEGER) - (byId.get(right.id)?.index ?? Number.MAX_SAFE_INTEGER) ||
        left.title.localeCompare(right.title) || left.id.localeCompare(right.id))
      ordered.push(...group)
    })
    this.chapters = ordered
    this.selected = new Set<string>(ordered.map((chapter: WorkArchiveChapter): string => chapter.id))
  }

  aboutToDisappear(): void {
    this.canceled = true
  }

  @Computed
  private get canReorder(): boolean {
    return this.chapters.length > 1 && !this.exporting
  }

  private toggle(id: string): void {
    if (this.exporting) return
    const keys = new Set<string>(this.selected)
    if (keys.has(id)) keys.delete(id)
    else keys.add(id)
    this.selected = keys
    this.errorText = ''
  }

  private toggleAll(): void {
    this.selected = new Set<string>(this.selected.size === this.chapters.length ? [] :
      this.chapters.map((chapter: WorkArchiveChapter): string => chapter.id))
    this.errorText = ''
  }

  private move(from: number, to: number): void {
    if (!this.canReorder || from === to ||
      from < 0 || to < 0 || from >= this.chapters.length || to >= this.chapters.length) return
    const rows = this.chapters.slice()
    const chapter = rows.splice(from, 1)[0]
    rows.splice(to, 0, chapter)
    this.chapters = rows
  }

  private async exportSelected(): Promise<void> {
    if (this.exporting || this.selected.size === 0) return
    const context = getContext(this) as common.UIAbilityContext
    const chapters = this.chapters.filter((chapter: WorkArchiveChapter): boolean => this.selected.has(chapter.id))
    this.exporting = true
    this.errorText = ''
    this.progressText = s('downloads_archive_progress').replace('%s', '0').replace('%s', String(chapters.length))
    let file: ChapterArchiveFile | undefined
    try {
      file = await prepareWorkArchive(context, this.comicId, this.comicTitle, chapters, {
        isCanceled: (): boolean => this.canceled,
        onChapterPrepared: (count: number): void => {
          this.progressText = count === chapters.length ? s('downloads_archive_packing') :
            s('downloads_archive_progress').replace('%s', String(count)).replace('%s', String(chapters.length))
        },
      })
      if (this.canceled) return
      this.progressText = s('downloads_archive_saving')
      if (await saveChapterArchive(context, file) && !this.canceled) this.onClose()
    } catch (error) {
      const message = (error as Error).message ?? ''
      if (!this.canceled && message !== CHAPTER_ARCHIVE_CANCELED) {
        this.errorText = message.startsWith(CHAPTER_ARCHIVE_INCOMPLETE) ?
          s('downloads_archive_missing_chapter').replace('%s', message.substring(CHAPTER_ARCHIVE_INCOMPLETE.length)) :
          s(message === CHAPTER_ARCHIVE_SAVE_FAILED ? CHAPTER_ARCHIVE_SAVE_FAILED : 'chapter_archive_failed')
      }
    } finally {
      if (file !== undefined) await discardPreparedArchive(file)
      this.exporting = false
    }
  }

  @Builder
  private ChapterRow(chapter: WorkArchiveChapter, index: number) {
    Column() {
      if (this.multipleVersions && (index === 0 || this.chapters[index - 1].version !== chapter.version)) {
        Text(chapter.version || s('downloads_archive_other_version'))
          .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
          .fontColor(ThemeConstants.TEXT_SECONDARY)
          .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XS })
          .width('100%')
      }
      Row({ space: ThemeConstants.SPACE_MD }) {
        SymbolGlyph(this.selected.has(chapter.id) ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.circle'))
          .fontSize(ThemeConstants.FONT_SIZE_H3)
          .fontColor([this.selected.has(chapter.id) ? ThemeConstants.BRAND_PRIMARY : ThemeConstants.TEXT_SECONDARY])
        Text(chapter.title)
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .layoutWeight(1)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.canReorder) {
          SymbolGlyph($r('sys.symbol.line_3_horizontal'))
            .fontSize(ThemeConstants.FONT_SIZE_H3)
            .fontColor([ThemeConstants.TEXT_SECONDARY])
        }
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_MD)
      .backgroundColor(komaModalCardSurface())
      .borderRadius(ThemeConstants.RADIUS_CARD)
      .accessibilityDescription(this.selected.has(chapter.id) ? s('library_category_selection_checked') : '')
      .onClick(() => { this.toggle(chapter.id) })
    }
    .width('100%')
  }

  build() {
    KomaModalScaffold({
      title: s('chapter_export_cbz'),
      subtitle: this.comicTitle,
      confirmLabel: s('downloads_archive_export'),
      confirmEnabled: this.selected.size > 0 && !this.exporting,
      contentOwnsScrolling: true,
      onConfirm: () => { void this.exportSelected() },
      onClose: () => { this.canceled = true; this.onClose() },
    }) {
      Column({ space: ThemeConstants.SPACE_SM }) {
        Row({ space: ThemeConstants.SPACE_MD }) {
          Text(s('downloads_selected_count').replace('%s', String(this.selected.size)))
            .fontSize(ThemeConstants.FONT_SIZE_BODY)
            .fontColor(ThemeConstants.TEXT_PRIMARY)
            .layoutWeight(1)
          if (!this.exporting) {
            KomaActionButton({ label: this.selected.size === this.chapters.length ?
              s('downloads_deselect_all') : s('library_action_select_all'), kind: 'ghost', compact: true,
              action: () => { this.toggleAll() } })
          }
        }
        .width('100%')
        if (this.canReorder) {
          Text(s('downloads_archive_drag_order'))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
            .width('100%')
        }
        if (this.exporting || this.errorText.length > 0) {
          Text(this.exporting ? this.progressText : this.errorText)
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(this.exporting ? ThemeConstants.TEXT_SECONDARY : ThemeConstants.DANGER)
            .width('100%')
        }
        List({ space: ThemeConstants.SPACE_XS }) {
          ForEach(this.chapters, (chapter: WorkArchiveChapter, index: number) => {
            ListItem() { this.ChapterRow(chapter, index) }
          }, (chapter: WorkArchiveChapter): string => chapter.id)
            .onMove(this.canReorder ?
              (from: number, to: number): void => { this.move(from, to) } : undefined)
        }
        .width('100%')
        .layoutWeight(1)
        // This list owns scrolling, so it reserves the same bottom inset as the shared sheet list.
        .contentEndOffset(this.layout.bottomAvoidHeight + ThemeConstants.SPACE_MD)
        .scrollBar(BarState.Off)
      }
      .width('100%').height('100%')
    }
  }
}

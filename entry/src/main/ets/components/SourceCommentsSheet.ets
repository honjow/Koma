import { connectLanguageState, LanguageState } from '../state/LanguageState'
import { AppStrings } from '../i18n/AppStrings'
import { SourceRuntimeError, sourceFailureText } from '../model/SourceRuntimeError'
import { SourceComment, SourceCommentsTarget } from '../sourceRuntime/SourceCommentsContract'
import { loadSourceComments } from '../sourceRuntime/SourceCommentsService'
import { SourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeRegistry'
import { komaModalCardSurface } from '../theme/KomaPopupOptions'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { KomaActionButton } from './ui/KomaActionButton'
import { KomaEmptyState } from './ui/KomaEmptyState'

function s(name: string): string { return AppStrings.get(name) }

// Append only the new rows. Keeping the list's mounted rows and its scroll
// anchor matters when paging from the last visible comment.
class CommentRows implements IDataSource {
  private rows: SourceComment[] = []
  private ids: Set<string> = new Set()
  private listeners: DataChangeListener[] = []

  totalCount(): number { return this.rows.length }
  getData(index: number): SourceComment { return this.rows[index] }
  lastId(): string | undefined { return this.rows[this.rows.length - 1]?.id }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) this.listeners.push(listener)
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    this.listeners = this.listeners.filter((current: DataChangeListener): boolean => current !== listener)
  }

  append(items: SourceComment[]): void {
    const index = this.rows.length
    for (const item of items) {
      if (this.ids.has(item.id)) continue
      this.ids.add(item.id)
      this.rows.push(item)
    }
    const count = this.rows.length - index
    if (count === 0) return
    const operation: DataOperation = { type: DataOperationType.ADD, index, count }
    this.listeners.forEach((listener: DataChangeListener): void => { listener.onDatasetChange([operation]) })
  }
}

@ComponentV2
export struct SourceCommentsSheet {
  @Param registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()
  @Param target: SourceCommentsTarget = { sourceId: '', mangaId: '', subtitle: '' }
  @Event onClose: () => void = () => {}
  @Event isVisible: () => boolean = () => true
  private rows: CommentRows = new CommentRows()
  @Local private commentCount: number = 0
  @Local private loading: boolean = true
  @Local private errorText: string = ''
  @Local private language: LanguageState = connectLanguageState()
  private nextCursor?: string
  private started: boolean = false
  private alive: boolean = false
  private loadedCursors: Set<string> = new Set()

  aboutToAppear(): void {
    this.alive = true
    void this.loadPage()
  }

  aboutToDisappear(): void {
    this.alive = false
  }

  private async loadPage(): Promise<void> {
    if (!this.alive || (this.started && (this.loading || (this.nextCursor === undefined && this.errorText.length === 0)))) return
    const cursor = this.nextCursor
    const target = this.target
    const current = (): boolean => this.alive && this.target === target && this.isVisible()
    this.started = true
    this.loading = true
    this.errorText = ''
    try {
      const page = await loadSourceComments(this.registry, target, cursor, current)
      if (!current()) return
      if (cursor !== undefined) this.loadedCursors.add(cursor)
      this.nextCursor = page.nextCursor !== undefined && !this.loadedCursors.has(page.nextCursor)
        ? page.nextCursor : undefined
      this.rows.append(page.items)
      this.commentCount = this.rows.totalCount()
    } catch (error) {
      if (!current()) return
      const fallback = s('source_comments_load_failed')
      this.errorText = error instanceof SourceRuntimeError ? sourceFailureText(error.diagnostic, fallback) : fallback
    } finally {
      if (current()) this.loading = false
    }
  }

  private displayDate(value: string): string {
    if (!value.includes('T')) return value
    const time = Date.parse(value)
    if (!Number.isFinite(time)) return value
    return new Intl.DateTimeFormat(this.language.effectiveLocale,
      { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(time))
  }

  @Builder
  private CommentCard(comment: SourceComment) {
    Column({ space: ThemeConstants.SPACE_SM }) {
      Row({ space: ThemeConstants.SPACE_SM }) {
        Text(comment.author || s('source_comments_unknown_author'))
          .fontSize(ThemeConstants.FONT_SIZE_BODY)
          .fontColor(ThemeConstants.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        if (comment.createdAt) {
          Text(this.displayDate(comment.createdAt))
            .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
            .fontColor(ThemeConstants.TEXT_SECONDARY)
        }
      }
      .width('100%')
      Text(comment.deleted === true ? s('source_comments_deleted') : comment.content)
        .fontSize(ThemeConstants.FONT_SIZE_BODY)
        .fontColor(ThemeConstants.TEXT_PRIMARY)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(ThemeConstants.SPACE_LG)
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor(komaModalCardSurface())
  }

  build() {
    KomaModalScaffold({
      title: s(this.target.chapterId === undefined ? 'source_comments_manga' : 'source_comments_chapter'),
      subtitle: this.target.subtitle,
      onClose: this.onClose,
    }) {
      LazyForEach(this.rows, (comment: SourceComment) => {
        ListItem() {
          this.CommentCard(comment)
        }
        .onVisibleAreaChange([0.01], (visible: boolean) => {
          if (visible && this.errorText.length === 0 && comment.id === this.rows.lastId() &&
            this.nextCursor !== undefined) void this.loadPage()
        })
      }, (comment: SourceComment): string => comment.id)
      if (this.loading) {
        ListItem() {
          Row() {
            LoadingProgress().width(24).height(24).color(ThemeConstants.BRAND_PRIMARY)
          }
          .width('100%')
          .height(ThemeConstants.TOUCH_TARGET_SM)
          .justifyContent(FlexAlign.Center)
          .accessibilityText(s('source_comments_loading'))
        }
      } else if (this.errorText.length > 0) {
        ListItem() {
          Column({ space: ThemeConstants.SPACE_SM }) {
            Text(this.errorText).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor(ThemeConstants.TEXT_SECONDARY)
            KomaActionButton({ label: s('common_retry'), kind: 'secondary', action: () => { void this.loadPage() } })
          }
          .width('100%')
          .padding(ThemeConstants.SPACE_LG)
        }
      } else if (this.commentCount === 0) {
        ListItem() {
          KomaEmptyState({ title: s('source_comments_empty') })
        }
      }
    }
  }
}

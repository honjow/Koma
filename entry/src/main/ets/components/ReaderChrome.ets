import { SymbolGlyphModifier } from '@kit.ArkUI'
import { ReaderMode, getReaderModeLabel } from '../model/ReaderSessionStore'
import { ReaderPreferences, DEFAULT_READER_PREFERENCES } from '../model/ReaderPreferencesStore'
import { ReadingDirection } from '../model/ComicModels'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { ReaderSettingsContent } from './ReaderSettingsContent'
import { ConciseListRow } from './ui/ConciseListRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'

function s(key: string): string {
  return AppStrings.get(key)
}

export interface ReaderChromePreferencesChange {
  preferences: ReaderPreferences
}

/**
 * Reader chrome owns only presentation and navigation controls. Page gestures
 * are intrinsic reader behavior: there are no switches for tap/swipe/zoom or
 * for the transient tap-zone preview.
 */
@ComponentV2
export struct ReaderChrome {
  @Param visible: boolean = false
  /** One physical bar per component, matching NextE's sibling bar layers. */
  @Param placement: 'top' | 'bottom' = 'top'
  @Param viewportHeight: number = 0
  @Param pageIndex: number = 0
  @Param pageTotal: number = 0
  @Param title: string = ''
  @Param chapterIndex: number = 0
  @Param chapterTotal: number = 0
  @Param chapterTitles: string[] = []
  @Param readerMode: ReaderMode = ReaderMode.SINGLE_PAGE
  @Param preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Param topInset: number = 0
  @Param bottomInset: number = 0
  @Param canGoPrevious: boolean = false
  @Param canGoNext: boolean = false
  @Param canGoPreviousChapter: boolean = false
  @Param canGoNextChapter: boolean = false
  @Param pageFailed: boolean = false
  @Param zoomScale: number = 1
  @Param autoPageActive: boolean = false
  @Param canTurnOnePageInDoublePage: boolean = false
  @Param thumbStripVisible: boolean = false
  @Param pageImageWidth: number = 0
  @Param pageImageHeight: number = 0
  @Param pageImageSourceLabel: string = ''
  @Event onVisibleChange: (visible: boolean) => void = (_visible: boolean) => {}
  @Event onPageChange: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onSeekPage: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onPreviousChapter: () => void = () => {}
  @Event onNextChapter: () => void = () => {}
  @Event onOpenChapter: (chapterIndex: number) => void = (_chapterIndex: number) => {}
  @Event onModeChange: (mode: ReaderMode) => void = (_mode: ReaderMode) => {}
  @Event onPreferencesChange: (change: ReaderChromePreferencesChange) => void = (_change: ReaderChromePreferencesChange) => {}
  @Event onCloseReader: () => void = () => {}
  @Event onOpenMangaDetail: () => void = () => {}
  @Event onResetZoom: () => void = () => {}
  @Event onReloadPage: () => void = () => {}
  @Event onToggleAutoPage: () => void = () => {}
  @Event onTurnOnePageInDoublePage: () => void = () => {}
  @Event onToggleThumbStrip: () => void = () => {}
  @Event onSaveImage: () => void = () => {}
  @Event onShareImage: () => void = () => {}
  @BuilderParam thumbnailStrip?: () => void

  @Local private settingsShown: boolean = false
  @Local private moreShown: boolean = false
  @Local private modeShown: boolean = false
  @Local private imageInfoShown: boolean = false
  @Local private chapterPickerShown: boolean = false
  @Local private chapterPickerTarget: number = -1
  private chapterPickerScroller: Scroller = new Scroller()

  @Builder
  private ChapterSelectedCheckmark() {
    SymbolGlyph($r('sys.symbol.checkmark'))
      .fontSize(ThemeConstants.FONT_SIZE_H3)
      .fontWeight(FontWeight.Medium)
      .fontColor([ThemeConstants.BRAND_PRIMARY])
  }

  @Monitor('chapterPickerShown')
  private onChapterPickerVisibilityChanged(): void {
    if (this.chapterPickerShown && this.chapterIndex >= 0) {
      setTimeout(() => {
        this.chapterPickerScroller.scrollToIndex(Math.max(0, this.chapterIndex), true, ScrollAlign.CENTER)
      }, 120)
    }
  }

  private pageText(): string {
    const total = Math.max(this.pageTotal, 0)
    return total <= 0 ? '0 / 0' : `${Math.min(Math.max(this.pageIndex + 1, 1), total)} / ${total}`
  }

  private barHeight(): number {
    return this.placement === 'top'
      ? this.topInset + 56
      : this.bottomInset + 104 + (this.thumbStripVisible ? 156 : 0)
  }

  private barOffsetY(): number {
    return this.placement === 'top' ? 0 : Math.max(this.viewportHeight - this.barHeight(), 0)
  }

  private chapterText(): string {
    return this.chapterTotal <= 0 ? '' : `${s('reader_control_chapter')} ${this.chapterIndex + 1} / ${this.chapterTotal}`
  }

  private chapterTitleText(): string {
    const rawTitle = this.chapterIndex >= 0 && this.chapterIndex < this.chapterTitles.length
      ? this.chapterTitles[this.chapterIndex]
      : ''
    const title = rawTitle.trim().replace(/\s+/g, ' ')
    return title.length > 0 ? title : this.chapterText()
  }

  private chapterPickerTitle(index: number): string {
    const title = index >= 0 && index < this.chapterTitles.length ? this.chapterTitles[index] : ''
    return title.length > 0 ? title : `${s('reader_control_chapter')} ${index + 1}`
  }

  private chapterPickerIndexes(): number[] {
    const count = Math.max(this.chapterTotal, this.chapterTitles.length)
    const indexes: number[] = []
    for (let index = 0; index < count; index += 1) {
      indexes.push(index)
    }
    return indexes
  }

  private selectChapterFromPicker(index: number): void {
    if (index < 0 || index >= this.chapterTotal) {
      return
    }
    this.chapterPickerTarget = index
    this.chapterPickerShown = false
  }

  private finishChapterPickerDismissal(): void {
    const target = this.chapterPickerTarget
    this.chapterPickerTarget = -1
    this.chapterPickerShown = false
    if (target >= 0 && target < this.chapterTotal) {
      this.onOpenChapter(target)
    }
  }

  private openImageInfo(): void {
    // The detail surface is hosted by the dedicated back-button anchor, not
    // the menu trigger.  It can therefore be opened in the same event without
    // competing with the Menu overlay for ownership.
    this.moreShown = false
    this.imageInfoShown = true
  }

  private imageDimensionsText(): string {
    if (this.pageImageWidth <= 0 || this.pageImageHeight <= 0) {
      return s('reader_image_info_unavailable')
    }
    return `${this.pageImageWidth} × ${this.pageImageHeight}`
  }

  private closeSettings(): void {
    this.settingsShown = false
  }

  @Builder
  private ReaderSettingsSheet() {
    ReaderSettingsContent({
      readerMode: this.readerMode,
      preferences: this.preferences,
      onPreferencesChange: (preferences: ReaderPreferences): void => {
        this.onPreferencesChange({ preferences: preferences })
      },
      onClose: (): void => { this.closeSettings() },
      onRevealTapZones: (): void => { this.onVisibleChange(false) },
    })
  }

  @Builder
  private ModeMenu() {
    Menu() {
      MenuItem({ content: getReaderModeLabel(ReaderMode.SINGLE_PAGE), symbolEndIcon: this.readerMode === ReaderMode.SINGLE_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.SINGLE_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.DUAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.DUAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.DUAL_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.VERTICAL_PAGE), symbolEndIcon: this.readerMode === ReaderMode.VERTICAL_PAGE ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.VERTICAL_PAGE); this.modeShown = false })
      MenuItem({ content: getReaderModeLabel(ReaderMode.CONTINUOUS_SCROLL), symbolEndIcon: this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? new SymbolGlyphModifier($r('sys.symbol.checkmark')) : undefined }).onClick(() => { this.onModeChange(ReaderMode.CONTINUOUS_SCROLL); this.modeShown = false })
    }
  }

  @Builder
  private MoreMenu() {
    Menu() {
      MenuItem({ content: s('reader_action_image_info') }).enabled(this.pageTotal > 0).onClick(() => { this.openImageInfo() })
      MenuItem({ content: s('reader_action_save_image') }).enabled(this.pageTotal > 0).onClick(() => { this.onSaveImage(); this.moreShown = false })
      MenuItem({ content: s('reader_action_share_image') }).enabled(this.pageTotal > 0).onClick(() => { this.onShareImage(); this.moreShown = false })
      MenuItem({ content: s('reader_action_reset_zoom') }).enabled(this.zoomScale > 1.01).onClick(() => { this.onResetZoom(); this.moreShown = false })
      MenuItem({ content: s('reader_action_previous_chapter') }).enabled(this.canGoPreviousChapter).onClick(() => { this.onPreviousChapter(); this.moreShown = false })
      MenuItem({ content: s('reader_action_next_chapter') }).enabled(this.canGoNextChapter).onClick(() => { this.onNextChapter(); this.moreShown = false })
      MenuItem({ content: s('reader_action_return_to_detail') }).onClick(() => { this.onOpenMangaDetail(); this.moreShown = false })
      MenuItem({ content: s('reader_page_load_failed') }).enabled(this.pageFailed).onClick(() => { this.onReloadPage(); this.moreShown = false })
    }
  }

  @Builder
  private ImageInfoSheet() {
    KomaModalScaffold({
      title: s('reader_image_info_title'),
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'),
      onClose: () => {
        this.imageInfoShown = false
      },
    }) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        GroupedListSection() {
          ConciseListRow({ title: s('reader_image_info_page'), trailingText: this.pageText(), showChevron: false })
          ListDivider()
          ConciseListRow({ title: s('reader_image_info_dimensions'), trailingText: this.imageDimensionsText(), showChevron: false })
          ListDivider()
          ConciseListRow({ title: s('reader_image_info_source'), trailingText: this.pageImageSourceLabel, showChevron: false })
        }
      }
      .width('100%').padding(ThemeConstants.SPACE_LG)
    }
  }

  @Builder
  private ChapterPickerSheet() {
    KomaModalScaffold({
      title: s('reader_control_chapter'),
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'),
      contentOwnsScrolling: true,
      onClose: () => {
        this.chapterPickerShown = false
      },
    }) {
      List({ scroller: this.chapterPickerScroller, space: ThemeConstants.SPACE_SM }) {
        ForEach(this.chapterPickerIndexes(), (index: number) => {
          ListItem() {
            ConciseListRow({
              title: this.chapterPickerTitle(index),
              primaryColor: index === this.chapterIndex ? ThemeConstants.BRAND_PRIMARY : undefined,
              showChevron: index !== this.chapterIndex,
              suffixBuilderParam: index === this.chapterIndex ? () => {
                this.ChapterSelectedCheckmark()
              } : undefined,
              action: () => {
                this.selectChapterFromPicker(index)
              },
            })
          }
          .padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
        }, (index: number) => `reader-chapter-picker-${index}`)
      }
      .width('100%')
      .height('100%')
      .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XL })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  private TopBar() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_left')).fontSize(22).fontColor([Color.White])
      }
      .width(44)
      .height(44)
      .backgroundColor(Color.Transparent)
      .onClick(() => { this.onCloseReader() })
      .bindSheet($$this.imageInfoShown, this.ImageInfoSheet, {
        detents: [SheetSize.MEDIUM],
        showClose: false,
        enableOutsideInteractive: false,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        enableFloatingDragBar: true,
        onDisappear: () => { this.imageInfoShown = false },
      })

      Column({ space: 2 }) {
        Text(this.title.length > 0 ? this.title : s('reader_title_default'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineBreakStrategy(LineBreakStrategy.BALANCED)
          .textAlign(TextAlign.Start)
          .width('100%')

        Row({ space: ThemeConstants.SPACE_XS }) {
          Text(this.pageText())
            .fontSize(11)
            .fontColor('#CCFFFFFF')
            .maxLines(1)
            .flexShrink(0)
          Text('·')
            .fontSize(11)
            .fontColor('#CCFFFFFF')
            .flexShrink(0)
          Text(this.chapterTitleText())
            .fontSize(11)
            .fontColor('#CCFFFFFF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Start)
            .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .padding({ left: ThemeConstants.SPACE_XS, right: ThemeConstants.SPACE_SM })
      .alignItems(HorizontalAlign.Start)

      Row({ space: ThemeConstants.SPACE_XS }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.gearshape')).fontSize(22).fontColor([Color.White])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .onClick(() => { this.settingsShown = true })
        .bindSheet($$this.settingsShown, this.ReaderSettingsSheet, {
          detents: [SheetSize.MEDIUM, SheetSize.LARGE],
          showClose: false,
          enableOutsideInteractive: false,
          scrollSizeMode: ScrollSizeMode.CONTINUOUS,
          enableFloatingDragBar: true,
          onDisappear: () => { this.closeSettings() },
        })

        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.dot_grid_2x2')).fontSize(22).fontColor([Color.White])
        }
        .width(44)
        .height(44)
        .backgroundColor(Color.Transparent)
        .accessibilityText(s('common_more_actions'))
        .onClick(() => { this.moreShown = true })
        .bindMenu(this.moreShown, this.MoreMenu, {
          placement: Placement.BottomRight,
          onDisappear: () => { this.moreShown = false },
        })
      }
    }
    .width('100%')
    .height(this.topInset + 56)
    .padding({
      top: this.topInset,
      left: ThemeConstants.SPACE_SM,
      right: ThemeConstants.SPACE_SM,
    })
    .backgroundColor('#CC000000')
    .hitTestBehavior(HitTestMode.Default)
  }

  @Builder
  private BottomBar() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.thumbnailStrip) {
          this.thumbnailStrip()
        }
      }
      .width('100%')
      .height(this.thumbStripVisible ? 156 : 0)
      .padding({ top: this.thumbStripVisible ? ThemeConstants.SPACE_SM : 0, bottom: this.thumbStripVisible ? ThemeConstants.SPACE_SM : 0 })
      .margin({ bottom: this.bottomInset + 104 })
      .backgroundColor('#CC000000')
      .clip(true)
      .hitTestBehavior(this.thumbStripVisible ? HitTestMode.Default : HitTestMode.None)

      Column({ space: ThemeConstants.SPACE_XS }) {
        Row({ space: 4 }) {
          Text(`${this.pageIndex + 1}`).fontSize(14).fontColor(Color.White).width(30).textAlign(TextAlign.Start)
          Slider({ value: this.pageIndex + 1, min: 1, max: Math.max(this.pageTotal, 1), step: 1, style: SliderStyle.InSet, reverse: this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT })
            .layoutWeight(1).trackColor('#33FFFFFF').selectedColor(ThemeConstants.BRAND_PRIMARY)
            .onChange((value: number, mode: SliderChangeMode) => {
              const target = Math.max(0, Math.min(Math.round(value) - 1, Math.max(this.pageTotal - 1, 0)))
              if (this.readerMode === ReaderMode.CONTINUOUS_SCROLL || mode === SliderChangeMode.End) this.onSeekPage(target)
              else this.onPageChange(target)
            })
          Text(`${Math.max(this.pageTotal, 0)}`).fontSize(14).fontColor(Color.White).width(30).textAlign(TextAlign.End)
        }.width('100%').height(32)
        Row() {
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.book')).fontSize(22).fontColor([this.readerMode === ReaderMode.DUAL_PAGE ? ThemeConstants.BRAND_PRIMARY : Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.pageTotal > 1).onClick(() => { this.onModeChange(this.readerMode === ReaderMode.DUAL_PAGE ? ReaderMode.SINGLE_PAGE : ReaderMode.DUAL_PAGE) })
          if (this.readerMode === ReaderMode.DUAL_PAGE) {
            Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.transfer')).fontSize(22).fontColor([this.canTurnOnePageInDoublePage ? Color.White : ThemeConstants.STATUS_MUTED]) }
              .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.canTurnOnePageInDoublePage).onClick(() => { this.onTurnOnePageInDoublePage() })
          }
          Blank().layoutWeight(1)
          Text(this.chapterText())
            .fontSize(13)
            .fontColor(Color.White)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              if (this.chapterTotal > 0) {
                this.chapterPickerShown = true
              }
            })
            .bindSheet($$this.chapterPickerShown, this.ChapterPickerSheet, {
              detents: [SheetSize.MEDIUM, SheetSize.LARGE],
              showClose: false,
              enableOutsideInteractive: false,
              scrollSizeMode: ScrollSizeMode.CONTINUOUS,
              enableFloatingDragBar: true,
              onDisappear: () => {
                this.finishChapterPickerDismissal()
              },
            })
          Blank().layoutWeight(1)
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.clock')).fontSize(22).fontColor([this.autoPageActive ? ThemeConstants.BRAND_PRIMARY : Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).enabled(this.readerMode !== ReaderMode.CONTINUOUS_SCROLL).onClick(() => { this.onToggleAutoPage() })
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph($r('sys.symbol.rectangle_grid_2x1')).fontSize(22).fontColor([this.thumbStripVisible ? ThemeConstants.BRAND_PRIMARY : Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => { this.onToggleThumbStrip() })
          Button({ type: ButtonType.Circle, stateEffect: true }) { SymbolGlyph(this.readerMode === ReaderMode.CONTINUOUS_SCROLL ? $r('sys.symbol.scroll_vertical') : $r('sys.symbol.arrow_right_and_square')).fontSize(22).fontColor([Color.White]) }
            .width(44).height(44).backgroundColor(Color.Transparent).onClick(() => { this.modeShown = true }).bindMenu(this.modeShown, this.ModeMenu, { placement: Placement.TopRight, onDisappear: () => { this.modeShown = false } })
        }.width('100%').height(52).padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG }).alignItems(VerticalAlign.Center)
      }
      .width('100%').height(this.bottomInset + 104).padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG, top: ThemeConstants.SPACE_SM, bottom: this.bottomInset + ThemeConstants.SPACE_SM }).backgroundColor('#CC000000')
    }
    .width('100%').height(this.bottomInset + 104 + (this.thumbStripVisible ? 156 : 0)).hitTestBehavior(HitTestMode.Default)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.visible && this.placement === 'top') {
        this.TopBar()
      }
      if (this.visible && this.placement === 'bottom') {
        this.BottomBar()
      }
    }
    .width('100%')
    .height(this.barHeight())
    .position({ x: 0, y: this.barOffsetY() })
    .hitTestBehavior(HitTestMode.Default)
  }
}

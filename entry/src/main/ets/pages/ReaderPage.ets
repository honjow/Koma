import { image } from '@kit.ImageKit'
import { common } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { KeyCode } from '@kit.InputKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { ReaderChrome, ReaderChromePreferencesChange } from '../components/ReaderChrome'
import {
  EMPTY_READER_SESSION_CONFIG,
  InMemoryReaderSessionStore,
  ReaderMode,
  ReaderSessionConfig,
  ReaderSessionStore,
  getReaderSessionPageHeight,
  getReaderSessionPageId,
  getReaderSessionPageWidth,
} from '../model/ReaderSessionStore'
import {
  DEFAULT_READER_PREFERENCES,
  ReaderBackgroundMode,
  ReaderImageFitMode,
  ReaderPageGapMode,
  ReaderPageMode,
  ReaderPreferences,
  ReaderPreferencesStore,
  ReaderWideImageMode,
} from '../model/ReaderPreferencesStore'
import {
  ReaderPageRenderKind,
  ReaderPageRenderSource,
  configureReaderOfflineDownloads,
  configureReaderRemoteImageCache,
  createReaderPageRenderSource,
  fetchAndCacheReaderRemoteSource,
} from '../model/ReaderPageSourceAdapter'
import { ReadingDirection } from '../model/ComicModels'
import { ReaderTapZoneRegion, readerTapZoneRegions, resolveReaderTapZoneAction } from '../model/ReaderTapZoneGeometry'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'

const READER_TAP_VERTICAL_TOLERANCE: number = 10
const READER_TAP_SUPPRESS_MS: number = 360
const READER_TAP_ZONE_SCROLL_RATIO: number = 0.75
const READER_DOUBLE_TAP_SCALE: number = 2
const READER_MAX_ZOOM_SCALE: number = 6
const READER_WIDE_RATIO: number = 1.2

const EMPTY_RENDER_SOURCE: ReaderPageRenderSource = {
  kind: ReaderPageRenderKind.URI_PLACEHOLDER,
  uri: '',
  imageUri: '',
}

function s(key: string): string {
  return AppStrings.get(key)
}

function isWidePage(width: number | undefined, height: number | undefined): boolean {
  return width !== undefined && height !== undefined && width > 0 && height > 0 && width / height >= READER_WIDE_RATIO
}

function readerBackground(mode: ReaderBackgroundMode): ResourceColor {
  if (mode === 'paper') {
    return ThemeConstants.READER_BG_PAPER
  }
  if (mode === 'light') {
    return ThemeConstants.READER_BG_LIGHT
  }
  return ThemeConstants.READER_BG_DARK
}

function readerForeground(mode: ReaderBackgroundMode): ResourceColor {
  return mode === 'light' ? ThemeConstants.READER_TEXT_ON_LIGHT : ThemeConstants.READER_TEXT_PRIMARY
}

function imageFit(mode: ReaderImageFitMode): ImageFit {
  if (mode === 'fit_width' || mode === 'fit_height') {
    return ImageFit.Contain
  }
  return ImageFit.Contain
}

interface ReaderDisplayEntry {
  pageIndex: number
  splitSide: 'none' | 'left' | 'right'
}

function pageGap(mode: ReaderPageGapMode): number {
  if (mode === 'compact') return 2
  if (mode === 'wide') return 18
  return 8
}

function modeFromPageMode(mode: ReaderPageMode): ReaderMode {
  if (mode === 'double_page') return ReaderMode.DUAL_PAGE
  if (mode === 'continuous_scroll') return ReaderMode.CONTINUOUS_SCROLL
  return ReaderMode.SINGLE_PAGE
}

@ComponentV2
struct ReaderImageSurface {
  @Param source: ReaderPageRenderSource = EMPTY_RENDER_SOURCE
  @Param pageIndex: number = 0
  @Param sourceWidth: number | undefined = undefined
  @Param sourceHeight: number | undefined = undefined
  @Param fit: ImageFit = ImageFit.Contain
  @Param splitSide: 'none' | 'left' | 'right' = 'none'
  @Param rotateClockwise: boolean = false
  @Param zoomEnabled: boolean = true
  @Param zoomScale: number = 1
  @Param panX: number = 0
  @Param panY: number = 0
  @Param active: boolean = true
  @Param retryToken: number = 0
  @Event onZoomChange: (zoomed: boolean) => void = (_zoomed: boolean) => {}
  @Event onTransformChange: (scale: number, panX: number, panY: number, zoomed: boolean) => void = (_scale: number, _panX: number, _panY: number, _zoomed: boolean) => {}
  @Event onImageInfo: (pageIndex: number, width: number, height: number) => void = (_pageIndex: number, _width: number, _height: number) => {}
  @Event onLoaded: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onFailed: (pageIndex: number) => void = (_pageIndex: number) => {}

  @Local private pixelMap: image.PixelMap | undefined = undefined
  @Local private loading: boolean = false
  @Local private failed: boolean = false
  @Local private sourceToken: string = ''
  private disposed: boolean = false
  private generation: number = 0
  private pinchStart: number = 1
  private pinchAnchorX: number = 0.5
  private pinchAnchorY: number = 0.5
  private panStartX: number = 0
  private panStartY: number = 0
  private viewportWidth: number = 0
  private viewportHeight: number = 0
  @Local private gestureScale: number = 1
  @Local private gesturePanX: number = 0
  @Local private gesturePanY: number = 0

  aboutToAppear(): void {
    this.disposed = false
    this.gestureScale = this.zoomScale
    this.gesturePanX = this.panX
    this.gesturePanY = this.panY
    void this.resolveSource()
  }

  aboutToDisappear(): void {
    this.disposed = true
    this.generation += 1
    void this.releasePixelMap()
  }

  @Monitor('source', 'splitSide', 'rotateClockwise', 'retryToken')
  onSourceChanged(): void {
    this.gestureScale = this.zoomScale
    this.gesturePanX = this.panX
    this.gesturePanY = this.panY
    void this.resolveSource()
  }

  @Monitor('zoomScale', 'panX', 'panY')
  onParentTransformChanged(): void {
    this.gestureScale = this.zoomScale
    this.gesturePanX = this.panX
    this.gesturePanY = this.panY
  }

  private sourceKey(): string {
    return `${this.source.kind}:${this.source.uri}:${this.source.imageUri}:${this.source.pageId ?? ''}:${this.splitSide}:${this.rotateClockwise}:${this.retryToken}`
  }

  private async releasePixelMap(): Promise<void> {
    const map = this.pixelMap
    this.pixelMap = undefined
    if (map !== undefined) {
      try {
        await map.release()
      } catch (_error) {
      }
    }
  }

  private async resolveSource(): Promise<void> {
    const key = this.sourceKey()
    if (key === this.sourceToken && (this.loading || this.pixelMap !== undefined)) {
      return
    }
    this.generation += 1
    const run = this.generation
    this.sourceToken = key
    this.loading = true
    this.failed = false
    await this.releasePixelMap()
    if (this.source.kind === ReaderPageRenderKind.URI_PLACEHOLDER || this.source.imageUri.length === 0) {
      this.loading = false
      this.failed = true
      this.onFailed(this.pageIndex)
      return
    }
    let imageSource: image.ImageSource | undefined = undefined
    try {
      const filePath = await fetchAndCacheReaderRemoteSource(this.source)
      if (this.disposed || run !== this.generation) return
      imageSource = image.createImageSource(filePath)
      const options = this.regionOptions()
      const map = options === undefined ? await imageSource.createPixelMap() : await imageSource.createPixelMap(options)
      if (this.disposed || run !== this.generation) {
        await map.release()
        return
      }
      this.publishImageInfo(map)
      this.pixelMap = map
      this.failed = false
      this.onLoaded(this.pageIndex)
    } catch (_error) {
      if (!this.disposed && run === this.generation) {
        this.failed = true
        this.onFailed(this.pageIndex)
      }
    } finally {
      if (imageSource !== undefined) {
        try { await imageSource.release() } catch (_error) {}
      }
      if (!this.disposed && run === this.generation) this.loading = false
    }
  }

  private regionOptions(): image.DecodingOptions | undefined {
    if (this.splitSide === 'none' || this.sourceWidth === undefined || this.sourceHeight === undefined || this.sourceWidth <= 1 || this.sourceHeight <= 0) {
      return undefined
    }
    const leftWidth = Math.floor(this.sourceWidth / 2)
    const regionWidth = this.splitSide === 'right' ? this.sourceWidth - leftWidth : leftWidth
    return { desiredRegion: { size: { width: regionWidth, height: this.sourceHeight }, x: this.splitSide === 'right' ? leftWidth : 0, y: 0 } }
  }

  private publishImageInfo(map: image.PixelMap): void {
    let width = this.sourceWidth ?? 0
    let height = this.sourceHeight ?? 0
    if (width <= 0 || height <= 0) {
      try {
        const info = map.getImageInfoSync()
        width = info.size.width
        height = info.size.height
      } catch (_error) {
      }
    }
    if (width > 0 && height > 0) this.onImageInfo(this.pageIndex, width, height)
  }

  private clampScale(value: number): number {
    if (!Number.isFinite(value)) return 1
    return Math.min(Math.max(value, 1), READER_MAX_ZOOM_SCALE)
  }

  private clampOffset(value: number, viewport: number, content: number, scale: number): number {
    const bound = Math.max(0, (content * scale - viewport) / 2)
    return Math.min(Math.max(value, -bound), bound)
  }

  private resetZoom(): void {
    this.gestureScale = 1
    this.gesturePanX = 0
    this.gesturePanY = 0
    this.onZoomChange(false)
    this.onTransformChange(1, 0, 0, false)
  }

  private handlePinchStart(event?: GestureEvent): void {
    this.pinchStart = this.gestureScale
    this.gesturePanX = this.panX
    this.gesturePanY = this.panY
    this.pinchAnchorX = event === undefined ? this.viewportWidth / 2 : event.pinchCenterX as number
    this.pinchAnchorY = event === undefined ? this.viewportHeight / 2 : event.pinchCenterY as number
  }

  private handlePinchUpdate(event?: GestureEvent): void {
    if (event === undefined || !this.zoomEnabled) return
    const next = this.clampScale(this.pinchStart * (event.scale as number))
    const nextPanX = this.clampOffset(this.gesturePanX, this.viewportWidth, this.viewportWidth, next)
    const nextPanY = this.clampOffset(this.gesturePanY, this.viewportHeight, this.viewportHeight, next)
    this.gestureScale = next
    this.gesturePanX = nextPanX
    this.gesturePanY = nextPanY
    if (this.active) {
      this.onZoomChange(next > 1.01)
      this.onTransformChange(next, nextPanX, nextPanY, next > 1.01)
    }
  }

  private handleDoubleTap(): void {
    if (!this.zoomEnabled) return
    if (this.gestureScale > 1.01) {
      this.resetZoom()
      return
    }
    this.gestureScale = READER_DOUBLE_TAP_SCALE
    this.gesturePanX = 0
    this.gesturePanY = 0
    if (this.active) {
      this.onZoomChange(true)
      this.onTransformChange(READER_DOUBLE_TAP_SCALE, 0, 0, true)
    }
  }

  @Builder
  private LoadingContent() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      LoadingProgress().width(28).height(28).color(Color.White)
      Text(this.failed ? s('reader_page_load_failed') : s('reader_decoding_image')).fontSize(13).fontColor(Color.White)
    }.justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).width('100%').height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width('100%').height('100%').objectFit(this.fit).interpolation(ImageInterpolation.Medium)
          .rotate({ angle: this.rotateClockwise ? 90 : 0 })
          .scale({ x: this.active ? this.gestureScale : 1, y: this.active ? this.gestureScale : 1 })
          .translate({ x: this.active ? this.gesturePanX : 0, y: this.active ? this.gesturePanY : 0 })
      } else {
        this.LoadingContent()
      }
    }
    .width('100%').height('100%').clip(true)
    .onAreaChange((_old: Area, next: Area) => {
      this.viewportWidth = next.width as number
      this.viewportHeight = next.height as number
    })
    .gesture(GestureGroup(
      GestureMode.Parallel,
      PinchGesture({ fingers: 2 })
        .onActionStart((event?: GestureEvent) => { this.handlePinchStart(event) })
        .onActionUpdate((event?: GestureEvent) => { this.handlePinchUpdate(event) })
        .onActionEnd(() => { if (this.zoomScale <= 1.01) this.resetZoom() })
        .onActionCancel(() => { if (this.zoomScale <= 1.01) this.resetZoom() }),
      TapGesture({ count: 2, distanceThreshold: 8 }).onAction(() => { this.handleDoubleTap() }),
      PanGesture({ fingers: 1, direction: PanDirection.All, distance: 12 })
        .onActionStart(() => { this.panStartX = this.gesturePanX; this.panStartY = this.gesturePanY })
        .onActionUpdate((event?: GestureEvent) => {
          if (event === undefined || this.gestureScale <= 1.01) return
          const nextX = this.clampOffset(this.panStartX + (event.offsetX as number), this.viewportWidth, this.viewportWidth, this.gestureScale)
          const nextY = this.clampOffset(this.panStartY + (event.offsetY as number), this.viewportHeight, this.viewportHeight, this.gestureScale)
          this.gesturePanX = nextX
          this.gesturePanY = nextY
          if (this.active) this.onTransformChange(this.gestureScale, nextX, nextY, this.gestureScale > 1.01)
        }),
    ))
  }
}

@ComponentV2
export struct ReaderPage {
  @Param readerOpen: boolean = false
  @Param pageIndex: number = 0
  @Param chromeVisible: boolean = false
  @Param webtoonMode: boolean = false
  @Param sessionStore: ReaderSessionStore = new InMemoryReaderSessionStore()
  @Param sessionConfig: ReaderSessionConfig = EMPTY_READER_SESSION_CONFIG
  @Event onPageIndexChange: (value: number) => void = (_value: number) => {}
  @Event onChromeVisibleChange: (value: boolean) => void = (_value: boolean) => {}
  @Event onWebtoonModeChange: (value: boolean) => void = (_value: boolean) => {}
  @Event onCloseReader: () => void = () => {}
  @Event onOpenMangaDetail: () => void = () => {}
  @Event onOpenChapter: (chapterId: string) => void = (_chapterId: string) => {}
  @Event $readerOpen: (value: boolean) => void = (_value: boolean) => {}
  @Event $pageIndex: (value: number) => void = (_value: number) => {}
  @Event $chromeVisible: (value: boolean) => void = (_value: boolean) => {}
  @Event $webtoonMode: (value: boolean) => void = (_value: boolean) => {}

  @Local private preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Local private preferenceRevision: number = 0
  @Local private viewportWidth: number = 0
  @Local private viewportHeight: number = 0
  @Local private zoomed: boolean = false
  @Local private zoomScale: number = 1
  @Local private panX: number = 0
  @Local private panY: number = 0
  @Local private loadedRevision: number = 0
  @Local private failedPages: number[] = []
  @Local private continuousOffset: number = 0
  @Local private settingsReady: boolean = false
  @Local private tapPreviewVisible: boolean = false
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()
  private preferencesStore?: ReaderPreferencesStore
  private filesDir: string = ''
  private sourceSignature: string = ''
  private tapStartX: number = 0
  private tapStartY: number = 0
  private tapTimerId: number = 0
  private tapCancelled: boolean = false
  private skipNextTapUp: boolean = false
  private suppressTapUntil: number = 0
  private swiperController: SwiperController = new SwiperController()
  private listScroller: Scroller = new Scroller()

  aboutToAppear(): void {
    this.loadPreferences()
    this.syncSession(true)
  }

  aboutToDisappear(): void {
    this.persistCurrentProgress()
    this.setReaderKeepScreenOn(false)
  }

  @Monitor('sessionConfig')
  onSessionChanged(): void {
    this.syncSession(true)
  }

  @Monitor('pageIndex')
  onParentPageChanged(): void {
    this.persistCurrentProgress()
  }

  private async loadPreferences(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      this.filesDir = context.filesDir ?? ''
      if (this.filesDir.length > 0) {
        configureReaderRemoteImageCache(`${this.filesDir}/reader-image-cache`)
        configureReaderOfflineDownloads(this.filesDir)
      }
      this.preferencesStore = new ReaderPreferencesStore(context)
      this.preferences = await this.preferencesStore.loadForComic(this.sessionConfig.comicId)
      this.settingsReady = true
      this.preferenceRevision += 1
      this.tapPreviewVisible = this.preferences.showTapZones
      this.setReaderKeepScreenOn(this.preferences.keepScreenAwake)
      this.emitWebtoonMode(this.preferences.pageMode === 'continuous_scroll' || this.preferences.readingDirection === ReadingDirection.WEBTOON)
    } catch (_error) {
      this.preferences = DEFAULT_READER_PREFERENCES
      this.settingsReady = true
      this.tapPreviewVisible = this.preferences.showTapZones
      this.setReaderKeepScreenOn(this.preferences.keepScreenAwake)
    }
  }

  private sessionSignature(): string {
    const config = this.sessionConfig
    return `${config.comicId}:${config.chapterId}:${config.totalPages}:${config.pageUris.length}:${config.pageUris[0] ?? ''}:${config.pageUris[config.pageUris.length - 1] ?? ''}`
  }

  private syncSession(resetPage: boolean): void {
    const signature = this.sessionSignature()
    if (signature === this.sourceSignature && !resetPage) return
    this.sourceSignature = signature
    this.loadedRevision += 1
    this.failedPages = []
    this.resetZoomState()
    if (resetPage && this.sessionConfig.totalPages > 0 && this.pageIndex >= this.sessionConfig.totalPages) {
      this.emitPageIndex(this.sessionConfig.totalPages - 1)
    }
  }

  private effectiveMode(): ReaderMode {
    if (this.webtoonMode || this.preferences.readingDirection === ReadingDirection.WEBTOON) {
      return ReaderMode.CONTINUOUS_SCROLL
    }
    return modeFromPageMode(this.preferences.pageMode)
  }

  private pageIndexes(): number[] {
    const out: number[] = []
    for (let index = 0; index < this.sessionConfig.totalPages; index += 1) out.push(index)
    return out
  }

  private spreadIndexes(): number[] {
    const out: number[] = []
    for (let index = 0; index < this.sessionConfig.totalPages; index += 2) out.push(index)
    return out
  }

  private spreadIndexForPage(pageIndex: number): number {
    const normalized = Math.max(0, Math.min(pageIndex, Math.max(this.sessionConfig.totalPages - 1, 0)))
    return Math.floor(normalized / 2)
  }

  private sourceFor(index: number, offlineOnly: boolean = false): ReaderPageRenderSource {
    return createReaderPageRenderSource(this.sessionConfig, index, { preferOffline: this.sessionConfig.comicId.length > 0, offlineOnly })
  }

  private pageWidth(index: number): number | undefined {
    return getReaderSessionPageWidth(this.sessionConfig, index)
  }

  private pageHeight(index: number): number | undefined {
    return getReaderSessionPageHeight(this.sessionConfig, index)
  }

  private splitEnabled(): boolean {
    return this.preferences.wideImageMode === 'split_wide_pages' && this.effectiveMode() !== ReaderMode.DUAL_PAGE
  }

  private shouldSplit(index: number): boolean {
    return this.splitEnabled() && isWidePage(this.pageWidth(index), this.pageHeight(index))
  }

  private displayEntries(index: number): ReaderDisplayEntry[] {
    if (!this.shouldSplit(index)) return [{ pageIndex: index, splitSide: 'none' }]
    const first: 'left' | 'right' = this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? 'right' : 'left'
    const second: 'left' | 'right' = first === 'left' ? 'right' : 'left'
    return [{ pageIndex: index, splitSide: first }, { pageIndex: index, splitSide: second }]
  }

  private canPrevious(): boolean { return this.pageIndex > 0 }
  private canNext(): boolean { return this.pageIndex + 1 < this.sessionConfig.totalPages }
  private chapterIndex(): number { return Math.max(0, this.sessionConfig.chapterIds.indexOf(this.sessionConfig.chapterId)) }

  private setPage(index: number, animated: boolean = true): void {
    const total = this.sessionConfig.totalPages
    if (total <= 0) return
    const target = Math.min(Math.max(index, 0), total - 1)
    if (target === this.pageIndex) return
    this.resetZoomState()
    if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL) {
      this.emitPageIndex(target)
      this.scrollContinuousTo(target, animated)
    } else if (this.effectiveMode() === ReaderMode.DUAL_PAGE) {
      this.emitPageIndex(target)
      this.swiperController.changeIndex(this.spreadIndexForPage(target), animated)
    } else {
      this.emitPageIndex(target)
      this.swiperController.changeIndex(target, animated)
    }
    this.persistProgress(target)
  }

  private nextPage(): void { this.setPage(this.pageIndex + 1) }
  private previousPage(): void { this.setPage(this.pageIndex - 1) }

  private scrollContinuousTo(index: number, animated: boolean): void {
    setTimeout(() => {
      const extent = Math.max(this.continuousItemExtent(), 1)
      this.listScroller.scrollTo({ xOffset: 0, yOffset: index * extent, animation: animated })
      this.listScroller.scrollToIndex(index, animated, ScrollAlign.START)
    }, 80)
  }

  private continuousItemExtent(): number {
    return Math.max(this.viewportHeight - this.layout.topAvoidHeight - this.layout.bottomAvoidHeight, 360)
  }

  private onModeChange(mode: ReaderMode): void {
    const next = this.copyPreferences()
    next.pageMode = mode === ReaderMode.DUAL_PAGE ? 'double_page' : (mode === ReaderMode.CONTINUOUS_SCROLL ? 'continuous_scroll' : 'single_page')
    this.preferences = next
    this.preferenceRevision += 1
    this.emitWebtoonMode(mode === ReaderMode.CONTINUOUS_SCROLL)
    this.persistPreferences(next)
    this.resetZoomState()
  }

  private resetZoomState(): void {
    this.zoomed = false
    this.zoomScale = 1
    this.panX = 0
    this.panY = 0
  }

  private copyPreferences(): ReaderPreferences {
    const p = this.preferences
    return {
      pageMode: p.pageMode,
      readingDirection: p.readingDirection,
      themeMode: p.themeMode,
      backgroundMode: p.backgroundMode,
      showProgressControls: p.showProgressControls,
      keepScreenAwake: p.keepScreenAwake,
      imageFitMode: p.imageFitMode,
      tapNavigationEnabled: p.tapNavigationEnabled,
      swipeNavigationEnabled: p.swipeNavigationEnabled,
      zoomGesturesEnabled: p.zoomGesturesEnabled,
      tapZonePreset: p.tapZonePreset,
      tapZoneInvert: p.tapZoneInvert,
      showTapZones: p.showTapZones,
      pageGapMode: p.pageGapMode,
      trimPageMarginsEnabled: p.trimPageMarginsEnabled,
      wideImageMode: p.wideImageMode,
      volumeKeyNavigationEnabled: p.volumeKeyNavigationEnabled,
      volumeKeyBehavior: p.volumeKeyBehavior,
    }
  }

  private onPreferencesChanged(change: ReaderChromePreferencesChange): void {
    this.preferences = change.preferences
    this.preferenceRevision += 1
    this.tapPreviewVisible = this.preferences.showTapZones
    this.setReaderKeepScreenOn(this.preferences.keepScreenAwake)
    this.emitWebtoonMode(this.preferences.pageMode === 'continuous_scroll' || this.preferences.readingDirection === ReadingDirection.WEBTOON)
    this.persistPreferences(this.preferences)
  }

  private persistPreferences(next: ReaderPreferences): void {
    if (this.preferencesStore !== undefined) {
      void this.preferencesStore.saveForComic(this.sessionConfig.comicId, next)
    }
  }

  private setReaderKeepScreenOn(enabled: boolean): void {
    try {
      const context = getContext(this) as common.UIAbilityContext
      window.getLastWindow(context).then((win: window.Window) => {
        win.setWindowKeepScreenOn(enabled).catch(() => {})
      }).catch(() => {})
    } catch (_error) {
    }
  }

  private persistProgress(index: number = this.pageIndex): void {
    if (this.sessionConfig.comicId.length === 0 || this.sessionConfig.chapterId.length === 0 || this.sessionConfig.totalPages <= 0) return
    const previous = this.sessionStore.getProgress(this.sessionConfig.comicId)
    const total = this.sessionConfig.totalPages
    this.sessionStore.saveProgress({
      comicId: this.sessionConfig.comicId,
      chapterId: this.sessionConfig.chapterId,
      pageId: getReaderSessionPageId(this.sessionConfig, index),
      pageIndex: Math.min(Math.max(index, 0), total - 1),
      totalPages: total,
      progressRatio: (Math.min(Math.max(index, 0), total - 1) + 1) / total,
      completed: index >= total - 1,
      updatedAt: previous?.updatedAt ?? Date.now(),
    })
  }

  private persistCurrentProgress(): void { this.persistProgress(this.pageIndex) }

  private onImageFailed(index: number): void {
    if (!this.failedPages.includes(index)) this.failedPages = this.failedPages.concat([index])
  }

  private onImageLoaded(index: number): void {
    if (this.failedPages.includes(index)) this.failedPages = this.failedPages.filter((item: number) => item !== index)
  }

  private zoomChanged(zoomed: boolean): void {
    this.zoomed = zoomed
    this.zoomScale = zoomed ? READER_DOUBLE_TAP_SCALE : 1
    if (!zoomed) {
      this.panX = 0
      this.panY = 0
    }
  }

  private transformChanged(scale: number, panX: number, panY: number, zoomed: boolean): void {
    this.zoomScale = Math.min(Math.max(scale, 1), READER_MAX_ZOOM_SCALE)
    this.panX = panX
    this.panY = panY
    this.zoomed = zoomed
  }

  private tapAction(x: number, y: number): void {
    if (Date.now() < this.suppressTapUntil) return
    if (this.tapPreviewVisible) {
      this.tapPreviewVisible = false
      return
    }
    const action = resolveReaderTapZoneAction(this.preferences.tapZonePreset, this.preferences.tapZoneInvert, x, y, this.viewportWidth, this.viewportHeight)
    if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL) {
      if (action === 'previous') this.setPage(this.pageIndex - 1, false)
      else if (action === 'next') this.setPage(this.pageIndex + 1, false)
      else this.toggleChrome()
      return
    }
    if (!this.preferences.tapNavigationEnabled || action === 'center') {
      this.toggleChrome()
    } else if (action === 'previous') {
      this.previousPage()
    } else {
      this.nextPage()
    }
  }

  private toggleChrome(): void {
    this.emitChromeVisible(!this.chromeVisible)
  }

  private emitPageIndex(value: number): void {
    this.onPageIndexChange(value)
    this.$pageIndex(value)
  }

  private emitChromeVisible(value: boolean): void {
    this.onChromeVisibleChange(value)
    this.$chromeVisible(value)
  }

  private emitWebtoonMode(value: boolean): void {
    this.onWebtoonModeChange(value)
    this.$webtoonMode(value)
  }

  private onOverlayTouch(event: TouchEvent): void {
    const touch = event.touches.length > 0 ? event.touches[0] : (event.changedTouches.length > 0 ? event.changedTouches[0] : undefined)
    if (touch === undefined) return
    if (event.touches.length > 1 || event.changedTouches.length > 1) {
      this.suppressTapUntil = Date.now() + READER_TAP_SUPPRESS_MS
      this.tapCancelled = true
      this.clearTapTimer()
      return
    }
    if (event.type === TouchType.Down) {
      if (this.tapTimerId > 0) {
        this.clearTapTimer()
        this.skipNextTapUp = true
      }
      this.tapStartX = touch.x
      this.tapStartY = touch.y
      this.tapCancelled = false
    } else if (event.type === TouchType.Move) {
      const dx = touch.x - this.tapStartX
      const dy = touch.y - this.tapStartY
      if (Math.sqrt(dx * dx + dy * dy) > READER_TAP_VERTICAL_TOLERANCE) {
        this.suppressTapUntil = Date.now() + READER_TAP_SUPPRESS_MS
        this.tapCancelled = true
        this.clearTapTimer()
      }
    } else if (event.type === TouchType.Up) {
      const dx = touch.x - this.tapStartX
      const dy = touch.y - this.tapStartY
      if (!this.tapCancelled && !this.skipNextTapUp && Math.sqrt(dx * dx + dy * dy) <= READER_TAP_VERTICAL_TOLERANCE) {
        const tapX: number = touch.windowX as number
        const tapY: number = touch.windowY as number
        this.clearTapTimer()
        this.tapTimerId = setTimeout(() => {
          this.tapTimerId = 0
          if (Date.now() >= this.suppressTapUntil) this.tapAction(tapX, tapY)
        }, 220)
      }
      this.skipNextTapUp = false
      this.tapCancelled = false
    } else if (event.type === TouchType.Cancel) {
      this.suppressTapUntil = Date.now() + READER_TAP_SUPPRESS_MS
      this.tapCancelled = true
      this.clearTapTimer()
    }
  }

  private clearTapTimer(): void {
    if (this.tapTimerId > 0) {
      clearTimeout(this.tapTimerId)
      this.tapTimerId = 0
    }
  }

  private handleKeyEvent(event: KeyEvent): boolean {
    if (!this.preferences.volumeKeyNavigationEnabled) return false
    if (event.keyCode === KeyCode.KEYCODE_VOLUME_UP) {
      this.preferences.volumeKeyBehavior === 'up_next_down_previous' ? this.nextPage() : this.previousPage()
      return true
    }
    if (event.keyCode === KeyCode.KEYCODE_VOLUME_DOWN) {
      this.preferences.volumeKeyBehavior === 'up_next_down_previous' ? this.previousPage() : this.nextPage()
      return true
    }
    return false
  }

  private retryCurrentPage(): void {
    this.failedPages = this.failedPages.filter((index: number) => index !== this.pageIndex)
    this.loadedRevision += 1
  }

  private previousChapter(): void {
    const index = this.chapterIndex()
    if (index > 0) this.onOpenChapter(this.sessionConfig.chapterIds[index - 1])
  }

  private nextChapter(): void {
    const index = this.chapterIndex()
    if (index >= 0 && index + 1 < this.sessionConfig.chapterIds.length) this.onOpenChapter(this.sessionConfig.chapterIds[index + 1])
  }

  private chapterTitles(): string[] {
    return this.sessionConfig.chapterTitles ?? []
  }

  @Builder
  private ReaderPageSlot(index: number, splitSide: 'none' | 'left' | 'right', compact: boolean = false) {
    Stack({ alignContent: Alignment.Center }) {
      ReaderImageSurface({
        source: this.sourceFor(index),
        pageIndex: index,
        sourceWidth: this.pageWidth(index),
        sourceHeight: this.pageHeight(index),
        fit: imageFit(this.preferences.imageFitMode),
        splitSide: splitSide,
        rotateClockwise: this.preferences.wideImageMode === 'rotate_wide_pages' && isWidePage(this.pageWidth(index), this.pageHeight(index)),
        zoomEnabled: this.preferences.zoomGesturesEnabled,
        zoomScale: this.zoomScale,
        panX: this.panX,
        panY: this.panY,
        active: index === this.pageIndex,
        retryToken: this.loadedRevision,
        onZoomChange: (zoomed: boolean) => { if (index === this.pageIndex) this.zoomChanged(zoomed) },
        onTransformChange: (scale: number, panX: number, panY: number, zoomed: boolean) => {
          if (index === this.pageIndex) this.transformChanged(scale, panX, panY, zoomed)
        },
        onImageInfo: (page: number, width: number, height: number) => {
          if (page === index) {
            void width
            void height
          }
        },
        onLoaded: (page: number) => { this.onImageLoaded(page) },
        onFailed: (page: number) => { this.onImageFailed(page) },
      })
      if (this.failedPages.includes(index)) {
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Text(s('common_retry')).fontSize(13).fontColor(ThemeConstants.TEXT_ON_BRAND)
        }
        .backgroundColor(ThemeConstants.BRAND_PRIMARY)
        .onClick(() => { this.failedPages = this.failedPages.filter((item: number) => item !== index); this.loadedRevision += 1 })
      }
      if (compact) {
        Blank().width(1).height(1)
      }
    }
    .width(compact ? '50%' : '100%').height('100%').backgroundColor(readerBackground(this.preferences.backgroundMode))
  }

  @Builder
  private SinglePageReader() {
    Swiper(this.swiperController) {
      ForEach(this.pageIndexes(), (index: number) => {
        Row({ space: pageGap(this.preferences.pageGapMode) }) {
          ForEach(this.displayEntries(index), (entry: ReaderDisplayEntry) => {
            this.ReaderPageSlot(entry.pageIndex, entry.splitSide)
          }, (entry: ReaderDisplayEntry) => `page-${entry.pageIndex}-${entry.splitSide}`)
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
      }, (index: number) => `reader-page-${index}`)
    }
    .index(this.pageIndex)
    .direction(this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? Direction.Rtl : Direction.Ltr)
    .vertical(false)
    .loop(false)
    .indicator(false)
    .disableSwipe(this.zoomed || !this.preferences.swipeNavigationEnabled)
    .width('100%').height('100%')
    .onChange((index: number) => {
      this.resetZoomState()
      this.emitPageIndex(index)
      this.persistProgress(index)
    })
  }

  @Builder
  private DoublePageReader() {
    Swiper(this.swiperController) {
      ForEach(this.spreadIndexes(), (start: number) => {
        Row({ space: pageGap(this.preferences.pageGapMode) }) {
          if (this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT) {
            this.ReaderPageSlot(Math.min(start + 1, this.sessionConfig.totalPages - 1), 'none', true)
            this.ReaderPageSlot(start, 'none', true)
          } else {
            this.ReaderPageSlot(start, 'none', true)
            if (start + 1 < this.sessionConfig.totalPages) this.ReaderPageSlot(start + 1, 'none', true)
          }
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }, (start: number) => `reader-spread-${start}`)
    }
    .index(this.spreadIndexForPage(this.pageIndex))
    .direction(this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? Direction.Rtl : Direction.Ltr)
    .vertical(false)
    .loop(false)
    .indicator(false)
    .disableSwipe(this.zoomed || !this.preferences.swipeNavigationEnabled)
    .width('100%').height('100%')
    .onChange((index: number) => {
      this.resetZoomState()
      const starts = this.spreadIndexes()
      const page = index >= 0 && index < starts.length ? starts[index] : 0
      this.emitPageIndex(page)
      this.persistProgress(page)
    })
  }

  @Builder
  private ContinuousReader() {
    List({ initialIndex: this.pageIndex, scroller: this.listScroller }) {
      ForEach(this.pageIndexes(), (index: number) => {
        ListItem() {
          Column() {
            this.ReaderPageSlot(index, 'none')
          }
          .width('100%')
          .height(Math.max(this.viewportHeight - this.layout.topAvoidHeight - this.layout.bottomAvoidHeight, 360))
          .padding({ top: pageGap(this.preferences.pageGapMode) / 2, bottom: pageGap(this.preferences.pageGapMode) / 2 })
        }
      }, (index: number) => `reader-vertical-page-${index}`)
    }
    .width('100%').height('100%').scrollBar(BarState.Off).cachedCount(2)
    .enableScrollInteraction(!this.zoomed)
    .onTouch((event: TouchEvent) => { this.onOverlayTouch(event) })
    .onScrollIndex((start: number) => {
      if (start >= 0 && start < this.sessionConfig.totalPages && start !== this.pageIndex) {
        this.emitPageIndex(start)
        this.persistProgress(start)
      }
    })
  }

  @Builder
  private TapZonePreview() {
    Stack() {
      ForEach(readerTapZoneRegions(this.preferences.tapZonePreset, this.preferences.tapZoneInvert), (region: ReaderTapZoneRegion) => {
        Text(region.action === 'previous' ? s('reader_tap_zone_action_previous') : (region.action === 'next' ? s('reader_tap_zone_action_next') : s('reader_tap_zone_center')))
          .fontSize(13).fontColor(Color.White).textAlign(TextAlign.Center)
          .position({ x: `${region.left * 100}%`, y: `${region.top * 100}%` })
          .width(`${(region.right - region.left) * 100}%`).height(`${(region.bottom - region.top) * 100}%`)
          .backgroundColor(region.action === 'center' ? '#33000000' : '#336E8F7D')
          .border({ width: 1, color: '#55FFFFFF' })
      }, (region: ReaderTapZoneRegion) => `tap-zone-${region.action}-${region.left}-${region.top}`)
    }
    .width('100%').height('100%').hitTestBehavior(HitTestMode.Block).onClick(() => { this.tapPreviewVisible = false })
  }

  @Builder
  private TapOverlay() {
    Blank()
      .width('100%').height('100%').hitTestBehavior(HitTestMode.Transparent)
      .onTouch((event: TouchEvent) => { this.onOverlayTouch(event) })
      .gesture(GestureGroup(
        GestureMode.Exclusive,
        TapGesture({ count: 2, distanceThreshold: 8 }).onAction((event?: GestureEvent) => {
          if (Date.now() < this.suppressTapUntil) return
          this.zoomChanged(!this.zoomed)
        }),
      ))
  }

  @Builder
  private PersistentPageNumber() {
    Text(`${this.pageIndex + 1} / ${Math.max(this.sessionConfig.totalPages, 0)}`)
      .fontSize(14).fontWeight(FontWeight.Medium).fontColor(readerForeground(this.preferences.backgroundMode))
      .width('100%').textAlign(TextAlign.Center).margin({ bottom: this.layout.bottomAvoidHeight + 8 }).hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private ReaderContent() {
    if (this.sessionConfig.totalPages <= 0) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(s('reader_empty_no_pages')).fontSize(16).fontColor(readerForeground(this.preferences.backgroundMode))
        Text(s('reader_source_page_unavailable')).fontSize(13).fontColor(ThemeConstants.READER_TEXT_SECONDARY).textAlign(TextAlign.Center)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(ThemeConstants.SPACE_XL)
    } else if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL) {
      this.ContinuousReader()
    } else if (this.effectiveMode() === ReaderMode.DUAL_PAGE) {
      this.DoublePageReader()
    } else {
      this.SinglePageReader()
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.readerOpen) {
        this.ReaderContent()
      } else {
        Blank().width('100%').height('100%')
      }
      if (this.readerOpen && this.sessionConfig.totalPages > 0 && !this.chromeVisible && this.preferences.showProgressControls) this.PersistentPageNumber()
      if (this.readerOpen && this.sessionConfig.totalPages > 0 && !this.chromeVisible && this.effectiveMode() !== ReaderMode.CONTINUOUS_SCROLL) this.TapOverlay()
      if (this.readerOpen && this.tapPreviewVisible) this.TapZonePreview()
      if (this.readerOpen && this.chromeVisible) {
        ReaderChrome({
          visible: true,
          pageIndex: this.pageIndex,
          pageTotal: this.sessionConfig.totalPages,
          title: this.sessionConfig.title ?? s('reader_title_default'),
          chapterIndex: this.chapterIndex(),
          chapterTotal: this.sessionConfig.chapterIds.length,
          chapterTitles: this.chapterTitles(),
          readerMode: this.effectiveMode(),
          preferences: this.preferences,
          topInset: this.layout.topAvoidHeight,
          bottomInset: this.layout.bottomAvoidHeight,
          canGoPrevious: this.canPrevious(),
          canGoNext: this.canNext(),
          canGoPreviousChapter: this.chapterIndex() > 0,
          canGoNextChapter: this.chapterIndex() + 1 < this.sessionConfig.chapterIds.length,
          pageFailed: this.failedPages.includes(this.pageIndex),
          zoomScale: this.zoomScale,
          onVisibleChange: (visible: boolean) => { this.emitChromeVisible(visible) },
          onPageChange: (index: number) => { this.emitPageIndex(index) },
          onSeekPage: (index: number) => { this.setPage(index, false) },
          onPreviousChapter: () => { this.previousChapter() },
          onNextChapter: () => { this.nextChapter() },
          onOpenChapter: (index: number) => {
            if (index >= 0 && index < this.sessionConfig.chapterIds.length) this.onOpenChapter(this.sessionConfig.chapterIds[index])
          },
          onModeChange: (mode: ReaderMode) => { this.onModeChange(mode) },
          onPreferencesChange: (change: ReaderChromePreferencesChange) => { this.onPreferencesChanged(change) },
          onCloseReader: () => { this.persistCurrentProgress(); this.onCloseReader() },
          onOpenMangaDetail: () => { this.onOpenMangaDetail() },
          onResetZoom: () => { this.resetZoomState() },
          onReloadPage: () => { this.retryCurrentPage() },
        })
      }
    }
    .width('100%').height('100%')
    .id('reader_key_surface')
    .backgroundColor(readerBackground(this.preferences.backgroundMode))
    .focusable(true).defaultFocus(true)
    .onAreaChange((_old: Area, next: Area) => { this.viewportWidth = next.width as number; this.viewportHeight = next.height as number })
    .gesture(TapGesture({ count: 2, distanceThreshold: 8 }).onAction(() => {
      if (this.readerOpen && this.sessionConfig.totalPages > 0) this.zoomChanged(!this.zoomed)
    }))
    .onKeyEvent((event: KeyEvent): boolean => this.handleKeyEvent(event))
  }
}

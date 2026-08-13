import { image } from '@kit.ImageKit'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { KeyCode } from '@kit.InputKit'
import inputConsumer from '@ohos.multimodalInput.inputConsumer'
import { Action, KeyEvent as InputConsumerKeyEvent } from '@ohos.multimodalInput.keyEvent'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
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
  readerPreferencesFromRuntimeState,
} from '../model/ReaderPreferencesStore'
import {
  ReaderPageRenderKind,
  ReaderPageRenderSource,
  configureReaderOfflineDownloads,
  configureReaderRemoteImageCache,
  createReaderPageRenderSource,
  createReaderPageRenderSources,
  fetchAndCacheReaderRemoteSource,
} from '../model/ReaderPageSourceAdapter'
import { ReadingDirection } from '../model/ComicModels'
import { ReaderTapZoneRegion, readerTapZoneRegions, resolveReaderTapZoneAction } from '../model/ReaderTapZoneGeometry'
import { ReaderPageIndexDataSource } from '../model/ReaderPageIndexDataSource'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectReaderModeState, ReaderModeState } from '../state/ReaderModeState'

const READER_TAP_VERTICAL_TOLERANCE: number = 10
const READER_TAP_ZONE_SCROLL_RATIO: number = 0.75
// Harmony's device doubleClick path delivers the second click around 350ms;
// a 240ms timer turns it into two single page actions.  Keep the single tap
// pending long enough for a normal double tap to be arbitrated as one gesture.
const READER_SINGLE_TAP_DELAY_MS: number = 400
const READER_DOUBLE_TAP_SCALE: number = 2
const READER_ZOOM_ANIM_DURATION: number = 180
const READER_MIN_DYNAMIC_MAX_SCALE: number = 4
const READER_MAX_DYNAMIC_MAX_SCALE: number = 12
const READER_MAX_EFFECTIVE_ZOOM_SCALE: number = 48
const READER_PINCH_ELASTIC_MIN_SCALE: number = 0.8
const READER_PINCH_UNDER_SCALE_RESISTANCE: number = 0.35
const READER_WIDE_RATIO: number = 1.2
const READER_THUMB_STRIP_HEIGHT: number = 140
const READER_THUMB_TILE_WIDTH: number = 86
const READER_THUMB_TILE_HEIGHT: number = 112
const READER_THUMB_DECODE_MAX_EDGE: number = 192

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
  if (mode === 'gray') {
    return ThemeConstants.READER_BACKGROUND_GRAY
  }
  if (mode === 'white') {
    return ThemeConstants.READER_BACKGROUND_WHITE
  }
  if (mode === 'auto') {
    return ThemeConstants.BG_PRIMARY
  }
  return ThemeConstants.READER_BACKGROUND_BLACK
}

function readerForeground(mode: ReaderBackgroundMode): ResourceColor {
  return mode === 'black' ? ThemeConstants.READER_FOREGROUND_LIGHT :
    (mode === 'auto' ? ThemeConstants.TEXT_PRIMARY : ThemeConstants.READER_FOREGROUND_DARK)
}

function imageFit(mode: ReaderImageFitMode): ImageFit {
  if (mode === 'fit_width' || mode === 'fit_height') {
    return ImageFit.Contain
  }
  return ImageFit.Contain
}

function imageInterpolation(quality: string): ImageInterpolation {
  if (quality === 'low') return ImageInterpolation.Low
  if (quality === 'high') return ImageInterpolation.High
  return ImageInterpolation.Medium
}

interface ReaderDisplayEntry {
  pageIndex: number
  splitSide: 'none' | 'left' | 'right'
}

// Keep the display source on ArkUI's native Image path.  ImageKit PixelMap is
// appropriate for editor-style processing and bounded thumbnails, but making a
// full PixelMap for every reader page keeps an uncompressed bitmap alive in
// ArkTS and starves the UI runtime on large downloaded pages.
interface ReaderImageLoadEvent {
  loadingStatus: number
  width?: number
  height?: number
}

function readerDisplayUri(path: string): string {
  if (path.startsWith('file://')) {
    return path
  }
  try {
    return fileUri.getUriFromPath(path)
  } catch (_error) {
    return path.startsWith('/') ? `file://${path}` : path
  }
}

function pageGap(mode: ReaderPageGapMode): number {
  if (mode === 'compact') return 2
  if (mode === 'wide') return 18
  return 8
}

function modeFromPageMode(mode: ReaderPageMode): ReaderMode {
  if (mode === 'double_page') return ReaderMode.DUAL_PAGE
  if (mode === 'vertical_page') return ReaderMode.VERTICAL_PAGE
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
  @Param fitMode: ReaderImageFitMode = 'contain'
  @Param scalingQuality: string = 'medium'
  @Param splitSide: 'none' | 'left' | 'right' = 'none'
  @Param rotateClockwise: boolean = false
  @Param zoomEnabled: boolean = true
  @Param active: boolean = true
  @Param allowDirectDoubleTap: boolean = true
  @Param routeTaps: boolean = false
  @Param tapOriginX: number = 0
  @Param tapOriginY: number = 0
  /** Paged-mode double tap command from ReaderTapOverlay. */
  @Param externalDoubleTapSequence: number = 0
  @Param externalDoubleTapTargetPage: number = -1
  @Param externalDoubleTapX: number = 0
  @Param externalDoubleTapY: number = 0
  /** Replayed continuous transform; survives ListItem virtualization. */
  @Param renderTransformTargetPage: number = -1
  @Param renderTransformScale: number = 1
  @Param renderTransformPanX: number = 0
  @Param renderTransformPanY: number = 0
  @Param retryToken: number = 0
  @Param zoomResetToken: number = 0
  @Event onZoomChange: (zoomed: boolean) => void = (_zoomed: boolean) => {}
  @Event onTransformChange: (scale: number, panX: number, panY: number, zoomed: boolean) => void = (_scale: number, _panX: number, _panY: number, _zoomed: boolean) => {}
  @Event onImageInfo: (pageIndex: number, width: number, height: number) => void = (_pageIndex: number, _width: number, _height: number) => {}
  @Event onLoaded: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onFailed: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onTap: (x: number, y: number) => void = (_x: number, _y: number) => {}
  @Event onTransformPreview: (pageIndex: number, scale: number, panX: number, panY: number) => void =
    (_pageIndex: number, _scale: number, _panX: number, _panY: number) => {}

  @Local private displayUri: string = ''
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
  /**
   * These are deliberately direct ArkUI bindings rather than computed
   * accessors over ReaderPage's replay state.  NextE animates an image's own
   * transform first; the parent only receives the settled value so a recycled
   * ListItem can restore it later.  Binding a getter to the parent value makes
   * that parent update win in the same frame and turns the transition into a
   * snap.
   */
  @Local private renderScale: number = 1
  @Local private renderPanX: number = 0
  @Local private renderPanY: number = 0
  @Local private intrinsicWidth: number = 0
  @Local private intrinsicHeight: number = 0
  @Local private zoomAnimating: boolean = false
  @Local private areaGlobalX: number = 0
  @Local private areaGlobalY: number = 0
  private tapStartX: number = 0
  private tapStartY: number = 0
  private tapCancelled: boolean = false
  private skipNextTapUp: boolean = false
  private singleTapTimerId: number = -1
  private isPinching: boolean = false
  // The image recognizer is the normal path.  Some ArkUI containers keep
  // forwarding multi-touch as raw touch events while retaining their own
  // gesture stream (notably List, and Swiper when the transparent tap layer
  // is present).  Keep one image-local raw fallback for every reader mode;
  // it becomes dormant as soon as ArkUI recognizes the native PinchGesture.
  private nativePinchActive: boolean = false
  private rawPinchActive: boolean = false
  private rawPinchStartDistance: number = 0
  private rawPanActive: boolean = false
  private ignorePanSequence: boolean = false
  private pinchAdjustedSinceDoubleTap: boolean = false
  private zoomAnimatingTimerId: number = -1
  private continuousTransformCommitTimerId: number = -1
  private intrinsicPixelWidth: number = 0
  private intrinsicPixelHeight: number = 0

  aboutToAppear(): void {
    this.disposed = false
    this.resetZoom(false)
    this.applyReplayedTransform()
    void this.resolveSource()
  }

  aboutToDisappear(): void {
    this.disposed = true
    this.generation += 1
    this.displayUri = ''
    this.clearSingleTap()
    this.clearZoomAnimation()
    this.clearContinuousTransformCommit()
  }

  @Monitor('source', 'splitSide', 'rotateClockwise', 'retryToken')
  onSourceChanged(): void {
    this.resetZoom(false)
    this.intrinsicPixelWidth = this.sourceRegionWidth(this.sourceWidth)
    this.intrinsicPixelHeight = this.sourceHeight ?? 0
    this.intrinsicWidth = this.toVp(this.intrinsicPixelWidth)
    this.intrinsicHeight = this.toVp(this.intrinsicPixelHeight)
    void this.resolveSource()
  }

  @Monitor('renderTransformTargetPage', 'renderTransformScale', 'renderTransformPanX', 'renderTransformPanY')
  onReplayedTransformChanged(): void {
    if (!this.routeTaps || this.zoomAnimating) {
      return
    }
    this.applyReplayedTransform()
  }

  private applyReplayedTransform(): void {
    if (!this.routeTaps) {
      return
    }
    if (this.renderTransformTargetPage === this.pageIndex) {
      this.gestureScale = this.renderTransformScale
      this.gesturePanX = this.renderTransformPanX
      this.gesturePanY = this.renderTransformPanY
      this.setRenderedTransform(this.gestureScale, this.gesturePanX, this.gesturePanY)
      return
    }
    this.gestureScale = 1
    this.gesturePanX = 0
    this.gesturePanY = 0
    this.setRenderedTransform(1, 0, 0)
  }

  @Monitor('zoomResetToken')
  onZoomResetRequested(): void {
    this.beginZoomAnimation()
    this.resetZoom(true)
  }

  @Monitor('externalDoubleTapSequence')
  onExternalDoubleTap(): void {
    if (this.routeTaps || this.allowDirectDoubleTap || this.externalDoubleTapSequence <= 0 ||
      this.externalDoubleTapTargetPage !== this.pageIndex || !this.active) {
      return
    }
    // Paged overlay coordinates are reader-local. Convert them into this
    // page surface before applying its local anchored zoom transition.
    const x = this.tapOriginX + this.externalDoubleTapX - this.areaGlobalX
    const y = this.tapOriginY + this.externalDoubleTapY - this.areaGlobalY
    this.handleDoubleTapAt(x, y)
  }

  @Monitor('active')
  onActiveChanged(): void {
    // Paged surfaces deliberately release their transform when the pager
    // moves away. A vertical List reuses rows while its visible bounds move;
    // treating that bookkeeping change as a zoom reset races the target row's
    // replay state and is not part of NextE's vertical image contract.
    if (!this.routeTaps && !this.active) {
      this.resetZoom(true)
    }
  }

  private sourceKey(): string {
    return `${this.source.kind}:${this.source.uri}:${this.source.imageUri}:${this.source.pageId ?? ''}:${this.splitSide}:${this.rotateClockwise}:${this.retryToken}`
  }

  private sourceRegionWidth(width: number | undefined): number {
    if (width === undefined || width <= 0 || this.splitSide === 'none') {
      return width ?? 0
    }
    const leftWidth = Math.floor(width / 2)
    return this.splitSide === 'right' ? width - leftWidth : leftWidth
  }

  private async resolveSource(): Promise<void> {
    const key = this.sourceKey()
    if (key === this.sourceToken && (this.loading || this.displayUri.length > 0)) {
      return
    }
    this.generation += 1
    const run = this.generation
    this.sourceToken = key
    this.loading = true
    this.failed = false
    this.displayUri = ''
    if (this.source.kind === ReaderPageRenderKind.URI_PLACEHOLDER || this.source.imageUri.length === 0) {
      this.loading = false
      this.failed = true
      this.onFailed(this.pageIndex)
      return
    }
    try {
      const filePath = await fetchAndCacheReaderRemoteSource(this.source)
      if (this.disposed || run !== this.generation) return
      this.displayUri = readerDisplayUri(filePath)
      console.info(`[ReaderImage] step=display_ready page=${this.pageIndex + 1}`)
    } catch (error) {
      if (!this.disposed && run === this.generation) {
        const message = error instanceof Error ? error.message : String(error)
        console.warn(`[ReaderImage] step=resolve_failed page=${this.pageIndex + 1} reason=${message}`)
        this.failed = true
        this.onFailed(this.pageIndex)
      }
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

  private publishImageInfo(widthValue?: number, heightValue?: number): void {
    let width = this.sourceRegionWidth(this.sourceWidth)
    let height = this.sourceHeight ?? 0
    if (width <= 0 && widthValue !== undefined) {
      width = widthValue
    }
    if (height <= 0 && heightValue !== undefined) {
      height = heightValue
    }
    if (width > 0 && height > 0) {
      this.intrinsicPixelWidth = width
      this.intrinsicPixelHeight = height
      this.intrinsicWidth = this.toVp(width)
      this.intrinsicHeight = this.toVp(height)
      this.onImageInfo(this.pageIndex, width, height)
    }
  }

  private toVp(pixels: number): number {
    if (pixels <= 0) {
      return 0
    }
    try {
      const value = this.getUIContext().px2vp(pixels)
      return value > 0 && Number.isFinite(value) ? value : pixels
    } catch (_error) {
      return pixels
    }
  }

  private toPx(value: number): number {
    if (value <= 0) {
      return 0
    }
    try {
      const pixels = this.getUIContext().vp2px(value)
      return pixels > 0 && Number.isFinite(pixels) ? pixels : value
    } catch (_error) {
      return value
    }
  }

  private sourceWidthValue(): number {
    return this.intrinsicWidth > 0 ? this.intrinsicWidth : this.toVp(this.sourceRegionWidth(this.sourceWidth))
  }

  private sourceHeightValue(): number {
    return this.intrinsicHeight > 0 ? this.intrinsicHeight : this.toVp(this.sourceHeight ?? 0)
  }

  private displaySourceWidth(): number {
    return this.rotateClockwise ? this.sourceHeightValue() : this.sourceWidthValue()
  }

  private displaySourceHeight(): number {
    return this.rotateClockwise ? this.sourceWidthValue() : this.sourceHeightValue()
  }

  private baseScale(): number {
    const width = this.displaySourceWidth()
    const height = this.displaySourceHeight()
    if (width <= 0 || height <= 0 || this.viewportWidth <= 0 || this.viewportHeight <= 0) {
      return 1
    }
    if (this.fitMode === 'fit_width') {
      return this.viewportWidth / width
    }
    if (this.fitMode === 'fit_height') {
      return this.viewportHeight / height
    }
    return Math.min(this.viewportWidth / width, this.viewportHeight / height)
  }

  private displayWidth(): number {
    const width = this.displaySourceWidth()
    return width > 0 ? width * this.baseScale() : this.viewportWidth
  }

  private displayHeight(): number {
    const height = this.displaySourceHeight()
    return height > 0 ? height * this.baseScale() : this.viewportHeight
  }

  private maxScale(): number {
    const displayW = this.toPx(this.displayWidth())
    const displayH = this.toPx(this.displayHeight())
    if (displayW <= 0 || displayH <= 0 || this.intrinsicPixelWidth <= 0 || this.intrinsicPixelHeight <= 0) {
      return READER_MIN_DYNAMIC_MAX_SCALE
    }
    const native = Math.min(this.intrinsicPixelWidth / displayW, this.intrinsicPixelHeight / displayH)
    const candidate = Number.isFinite(native) && native > 0 ? native * 2 : READER_MIN_DYNAMIC_MAX_SCALE
    return Math.max(READER_MIN_DYNAMIC_MAX_SCALE, Math.min(READER_MAX_DYNAMIC_MAX_SCALE, candidate))
  }

  private nativeScale(): number {
    const displayW = this.toPx(this.displayWidth())
    const displayH = this.toPx(this.displayHeight())
    if (displayW <= 0 || displayH <= 0 || this.intrinsicPixelWidth <= 0 || this.intrinsicPixelHeight <= 0) {
      return READER_DOUBLE_TAP_SCALE
    }
    const native = Math.min(this.intrinsicPixelWidth / displayW, this.intrinsicPixelHeight / displayH)
    return Number.isFinite(native) && native > 0 ? native : READER_DOUBLE_TAP_SCALE
  }

  private clampScale(value: number): number {
    if (!Number.isFinite(value)) return 1
    return Math.min(Math.max(value, 1), Math.min(this.maxScale(), READER_MAX_EFFECTIVE_ZOOM_SCALE))
  }

  private clampPinchScale(value: number): number {
    if (!Number.isFinite(value)) {
      return 1
    }
    if (value >= 1) {
      return this.clampScale(value)
    }
    const resisted = 1 - (1 - value) * READER_PINCH_UNDER_SCALE_RESISTANCE
    return Math.max(READER_PINCH_ELASTIC_MIN_SCALE, resisted)
  }

  /**
   * Match NextE's recognizer boundary: an unzoomed image must not win a
   * single-finger drag from its surrounding pager/List.  Once zoomed, a
   * one-pixel pan threshold gives the image its own canvas again.
   */
  private panDistance(): number {
    if (this.gestureScale > 1.01) {
      return 1
    }
    const longSide = Math.max(this.viewportWidth, this.viewportHeight)
    return longSide > 0 ? longSide * 2 : 10000
  }

  private doubleTapTarget(): number {
    const max = this.maxScale()
    if (this.pinchAdjustedSinceDoubleTap && this.gestureScale > 1.01) {
      return 1
    }
    const primary = this.clampScale(READER_DOUBLE_TAP_SCALE)
    const native = this.clampScale(this.nativeScale())
    if (this.gestureScale <= 1.01) {
      return primary
    }
    if (Math.abs(this.gestureScale - primary) <= 0.02 && native > 1.02) {
      return native
    }
    return 1
  }

  private clampOffset(value: number, viewport: number, content: number, scale: number): number {
    const bound = Math.max(0, (content * scale - viewport) / 2)
    return Math.min(Math.max(value, -bound), bound)
  }

  private clearZoomAnimation(): void {
    if (this.zoomAnimatingTimerId >= 0) {
      clearTimeout(this.zoomAnimatingTimerId)
      this.zoomAnimatingTimerId = -1
    }
  }

  private clearContinuousTransformCommit(): void {
    if (this.continuousTransformCommitTimerId >= 0) {
      clearTimeout(this.continuousTransformCommitTimerId)
      this.continuousTransformCommitTimerId = -1
    }
  }

  private commitContinuousTransformAfterAnimation(scale: number, panX: number, panY: number, zoomed: boolean): void {
    this.clearContinuousTransformCommit()
    this.continuousTransformCommitTimerId = setTimeout(() => {
      this.continuousTransformCommitTimerId = -1
      if (this.disposed) {
        return
      }
      this.onTransformPreview(this.pageIndex, scale, panX, panY)
      this.onTransformChange(scale, panX, panY, zoomed)
      this.onZoomChange(zoomed)
    }, READER_ZOOM_ANIM_DURATION + 24)
  }

  private beginZoomAnimation(): void {
    this.clearZoomAnimation()
    this.zoomAnimating = true
    this.zoomAnimatingTimerId = setTimeout(() => {
      this.zoomAnimating = false
      this.zoomAnimatingTimerId = -1
    }, READER_ZOOM_ANIM_DURATION + 24)
  }

  private setRenderedTransform(scale: number, panX: number, panY: number): void {
    this.renderScale = scale
    this.renderPanX = panX
    this.renderPanY = panY
  }

  private resetZoom(notify: boolean = true): void {
    this.gestureScale = 1
    this.gesturePanX = 0
    this.gesturePanY = 0
    this.setRenderedTransform(1, 0, 0)
    this.pinchAdjustedSinceDoubleTap = false
    if (notify) {
      this.onZoomChange(false)
      this.onTransformChange(1, 0, 0, false)
    }
  }

  private beginPinchAt(centerX: number, centerY: number): void {
    if (!this.zoomEnabled || (!this.active && !this.routeTaps)) {
      return
    }
    this.isPinching = true
    this.ignorePanSequence = true
    this.zoomAnimating = false
    this.pinchAdjustedSinceDoubleTap = true
    this.pinchStart = this.gestureScale
    this.pinchAnchorX = centerX
    this.pinchAnchorY = centerY
    const displayW = this.displayWidth() * this.gestureScale
    const displayH = this.displayHeight() * this.gestureScale
    this.pinchAnchorX = displayW > 0 ? (this.pinchAnchorX - (this.viewportWidth - displayW) / 2 - this.gesturePanX) / displayW : 0.5
    this.pinchAnchorY = displayH > 0 ? (this.pinchAnchorY - (this.viewportHeight - displayH) / 2 - this.gesturePanY) / displayH : 0.5
  }

  private updatePinchAt(centerX: number, centerY: number, scale: number): void {
    if (!this.zoomEnabled || (!this.active && !this.routeTaps) || !this.isPinching) {
      return
    }
    const next = this.clampPinchScale(this.pinchStart * scale)
    const nextDisplayW = this.displayWidth() * next
    const nextDisplayH = this.displayHeight() * next
    const nextPanX = this.clampOffset(
      centerX - (this.viewportWidth - nextDisplayW) / 2 - nextDisplayW * this.pinchAnchorX,
      this.viewportWidth,
      this.displayWidth(),
      next,
    )
    const nextPanY = this.clampOffset(
      centerY - (this.viewportHeight - nextDisplayH) / 2 - nextDisplayH * this.pinchAnchorY,
      this.viewportHeight,
      this.displayHeight(),
      next,
    )
    this.gestureScale = next
    this.gesturePanX = nextPanX
    this.gesturePanY = nextPanY
    this.setRenderedTransform(next, nextPanX, nextPanY)
  }

  private finishPinch(cancelled: boolean): void {
    this.isPinching = false
    this.ignorePanSequence = false
    if (this.gestureScale <= 1.01) {
      this.beginZoomAnimation()
      this.resetZoom()
      return
    }
    this.gestureScale = this.clampScale(this.gestureScale)
    this.gesturePanX = this.clampOffset(this.gesturePanX, this.viewportWidth, this.displayWidth(), this.gestureScale)
    this.gesturePanY = this.clampOffset(this.gesturePanY, this.viewportHeight, this.displayHeight(), this.gestureScale)
    this.setRenderedTransform(this.gestureScale, this.gesturePanX, this.gesturePanY)
    this.onZoomChange(true)
    if (!cancelled || this.gestureScale > 1.01) {
      this.onTransformChange(this.gestureScale, this.gesturePanX, this.gesturePanY, true)
    }
  }

  private handlePinchStart(event?: GestureEvent): void {
    if (event !== undefined) {
      this.nativePinchActive = true
      this.rawPinchActive = false
      this.beginPinchAt(event.pinchCenterX as number, event.pinchCenterY as number)
    }
  }

  private handlePinchUpdate(event?: GestureEvent): void {
    if (event !== undefined) {
      this.updatePinchAt(event.pinchCenterX as number, event.pinchCenterY as number, event.scale as number)
    }
  }

  private finishNativePinch(cancelled: boolean): void {
    this.nativePinchActive = false
    this.finishPinch(cancelled)
  }

  private touchDistance(first: TouchObject, second: TouchObject): number {
    const dx = (second.x as number) - (first.x as number)
    const dy = (second.y as number) - (first.y as number)
    return Math.sqrt(dx * dx + dy * dy)
  }

  private rawPinchCenterX(first: TouchObject, second: TouchObject): number {
    return ((first.x as number) + (second.x as number)) / 2
  }

  private rawPinchCenterY(first: TouchObject, second: TouchObject): number {
    return ((first.y as number) + (second.y as number)) / 2
  }

  /**
   * A native PinchGesture should normally win.  When a parent List or Swiper
   * retains the recognizer, the image still receives its raw two-touch stream.
   * Reconstruct that exact scale here.  This path never handles a one-finger
   * drag, so ordinary List scrolling and unzoomed Swiper turning remain native.
   */
  private handleRawPinch(event: TouchEvent): boolean {
    if (this.nativePinchActive) {
      return false
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      if (this.rawPinchActive) {
        this.rawPinchActive = false
        this.finishPinch(event.type === TouchType.Cancel)
        return true
      }
      return false
    }
    if (event.touches.length < 2) {
      return false
    }
    const first = event.touches[0]
    const second = event.touches[1]
    const distance = this.touchDistance(first, second)
    if (distance <= 0) {
      return true
    }
    const centerX = this.rawPinchCenterX(first, second)
    const centerY = this.rawPinchCenterY(first, second)
    if (!this.rawPinchActive) {
      this.rawPinchActive = true
      this.rawPinchStartDistance = distance
      this.beginPinchAt(centerX, centerY)
      return true
    }
    if (this.rawPinchStartDistance > 0) {
      this.updatePinchAt(centerX, centerY, distance / this.rawPinchStartDistance)
    }
    return true
  }

  /**
   * In continuous mode the native List owns unzoomed drags.  Once a page is
   * zoomed, the same raw stream becomes that page's canvas pan; keeping this
   * local avoids a List re-layout while the image is under the finger.
   */
  private updateContinuousRawPan(touch: TouchObject): boolean {
    if (!this.routeTaps || this.isPinching || this.gestureScale <= 1.01) {
      return false
    }
    const dx = (touch.x as number) - this.tapStartX
    const dy = (touch.y as number) - this.tapStartY
    if (!this.rawPanActive && Math.sqrt(dx * dx + dy * dy) <= READER_TAP_VERTICAL_TOLERANCE) {
      return false
    }
    this.rawPanActive = true
    this.tapCancelled = true
    this.clearSingleTap()
    this.gesturePanX = this.clampOffset(this.panStartX + dx, this.viewportWidth, this.displayWidth(), this.gestureScale)
    this.gesturePanY = this.clampOffset(this.panStartY + dy, this.viewportHeight, this.displayHeight(), this.gestureScale)
    this.setRenderedTransform(this.gestureScale, this.gesturePanX, this.gesturePanY)
    return true
  }

  private handleDoubleTapAt(tapX: number, tapY: number): void {
    if (!this.zoomEnabled || (!this.active && !this.routeTaps)) return
    // Continuous rendering is replayed from ReaderPage to survive ListItem
    // reuse. Restore that authoritative visual state before choosing the
    // next double-tap target, otherwise a recycled row mistakes 1.9x for 1x
    // and zooms again instead of resetting.
    if (this.routeTaps && this.renderTransformTargetPage === this.pageIndex) {
      this.gestureScale = this.renderTransformScale
      this.gesturePanX = this.renderTransformPanX
      this.gesturePanY = this.renderTransformPanY
      this.setRenderedTransform(this.gestureScale, this.gesturePanX, this.gesturePanY)
    }
    this.clearSingleTap()
    this.beginZoomAnimation()
    const target = this.doubleTapTarget()
    if (target <= 1.01) {
      if (this.routeTaps) {
        // The List remains locked by the old zoom gate until the image's own
        // 1x transition ends. Committing it sooner remounts this row and
        // cuts the reset animation short.
        this.gestureScale = 1
        this.gesturePanX = 0
        this.gesturePanY = 0
        this.setRenderedTransform(1, 0, 0)
        this.pinchAdjustedSinceDoubleTap = false
        this.commitContinuousTransformAfterAnimation(1, 0, 0, false)
        return
      }
      this.resetZoom()
      return
    }
    const displayW = this.displayWidth() * this.gestureScale
    const displayH = this.displayHeight() * this.gestureScale
    const anchorX = displayW > 0 ? (tapX - (this.viewportWidth - displayW) / 2 - this.gesturePanX) / displayW : 0.5
    const anchorY = displayH > 0 ? (tapY - (this.viewportHeight - displayH) / 2 - this.gesturePanY) / displayH : 0.5
    const nextDisplayW = this.displayWidth() * target
    const nextDisplayH = this.displayHeight() * target
    this.gestureScale = target
    this.gesturePanX = this.clampOffset(tapX - (this.viewportWidth - nextDisplayW) / 2 - nextDisplayW * anchorX,
      this.viewportWidth, this.displayWidth(), target)
    this.gesturePanY = this.clampOffset(tapY - (this.viewportHeight - nextDisplayH) / 2 - nextDisplayH * anchorY,
      this.viewportHeight, this.displayHeight(), target)
    this.setRenderedTransform(target, this.gesturePanX, this.gesturePanY)
    this.pinchAdjustedSinceDoubleTap = false
    if (this.routeTaps) {
      // The image owns the transition. Do not update List state in this
      // frame: that rebuilds virtual rows and replaces the local transform
      // with 1x before ArkUI can animate it. Persist and lock after it ends.
      this.commitContinuousTransformAfterAnimation(target, this.gesturePanX, this.gesturePanY, true)
      return
    }
    this.onZoomChange(true)
    this.onTransformChange(target, this.gesturePanX, this.gesturePanY, true)
  }

  private clearSingleTap(): void {
    if (this.singleTapTimerId >= 0) {
      clearTimeout(this.singleTapTimerId)
      this.singleTapTimerId = -1
    }
  }

  private onSurfaceTouch(event: TouchEvent): void {
    const touch = event.touches.length > 0 ? event.touches[0] : (event.changedTouches.length > 0 ? event.changedTouches[0] : undefined)
    if (touch === undefined) {
      return
    }
    const touchX = touch.x as number
    const touchY = touch.y as number
    if (this.handleRawPinch(event)) {
      if (this.routeTaps) {
        this.tapCancelled = true
        this.clearSingleTap()
      }
      return
    }
    if (!this.routeTaps) {
      return
    }
    if (event.touches.length > 1 || event.changedTouches.length > 1) {
      this.tapCancelled = true
      this.clearSingleTap()
      return
    }
    if (event.type === TouchType.Down) {
      if (this.singleTapTimerId >= 0) {
        this.clearSingleTap()
        this.skipNextTapUp = true
        this.tapCancelled = true
        // In a continuous List the image receives the raw touch stream even
        // when ArkUI's double-tap recognizer remains held by List.  This is
        // the same image-local command as the native recognizer, just driven
        // from the already-delayed first tap so there is exactly one zoom
        // owner and no single-tap/chrome flash between the two taps.
        this.handleDoubleTapAt(touchX, touchY)
        return
      }
      this.tapStartX = touchX
      this.tapStartY = touchY
      this.panStartX = this.gesturePanX
      this.panStartY = this.gesturePanY
      this.rawPanActive = false
      this.tapCancelled = false
    } else if (event.type === TouchType.Move) {
      if (this.updateContinuousRawPan(touch)) {
        return
      }
      const dx = touchX - this.tapStartX
      const dy = touchY - this.tapStartY
      if (Math.sqrt(dx * dx + dy * dy) > READER_TAP_VERTICAL_TOLERANCE) {
        this.tapCancelled = true
        this.clearSingleTap()
      }
    } else if (event.type === TouchType.Up) {
      if (this.rawPanActive) {
        this.rawPanActive = false
        this.tapCancelled = true
        this.onTransformChange(this.gestureScale, this.gesturePanX, this.gesturePanY, true)
        this.skipNextTapUp = false
        return
      }
      const dx = touchX - this.tapStartX
      const dy = touchY - this.tapStartY
      if (!this.tapCancelled && !this.skipNextTapUp &&
        Math.sqrt(dx * dx + dy * dy) <= READER_TAP_VERTICAL_TOLERANCE) {
        // Keep the vertical reader on the same coordinate contract as NextE:
        // touch routing crosses a virtualized ListItem boundary, so its local
        // x/y describe the recycled image surface, not the reader canvas.
        // `windowX/windowY` are stable at the reader route and already match
        // the dimensions passed to the tap-zone resolver.  Reconstructing
        // them from area positions was the reason a visual centre tap could
        // become a page-scroll action after a List re-layout.
        const x = touch.windowX
        const y = touch.windowY
        this.singleTapTimerId = setTimeout(() => {
          this.singleTapTimerId = -1
          this.onTap(x, y)
        }, READER_SINGLE_TAP_DELAY_MS)
      }
      this.skipNextTapUp = false
      this.tapCancelled = false
    } else if (event.type === TouchType.Cancel) {
      this.tapCancelled = true
      this.skipNextTapUp = false
      this.clearSingleTap()
    }
  }

  private surfacePinchGesture(): PinchGestureInterface {
    return PinchGesture({ fingers: 2 })
      .onActionStart((event?: GestureEvent) => { this.handlePinchStart(event) })
      .onActionUpdate((event?: GestureEvent) => { this.handlePinchUpdate(event) })
      .onActionEnd(() => { this.finishNativePinch(false) })
      .onActionCancel(() => { this.finishNativePinch(true) })
  }

  private surfaceDoubleTapGesture(): TapGestureInterface {
    return TapGesture({ count: 2, distanceThreshold: 8 }).onAction((event?: GestureEvent) => {
      if (!this.allowDirectDoubleTap) {
        return
      }
      const location = event?.tapLocation
      this.handleDoubleTapAt(location === undefined ? this.viewportWidth / 2 : location.x as number,
        location === undefined ? this.viewportHeight / 2 : location.y as number)
    })
  }

  private pagedPanGesture(): PanGestureInterface {
    return PanGesture({ fingers: 1, direction: PanDirection.All, distance: this.panDistance() })
      .onActionStart(() => {
        if (this.routeTaps) return
        if (!this.active || this.gestureScale <= 1.01) return
        this.tapCancelled = true
        this.clearSingleTap()
        this.panStartX = this.gesturePanX
        this.panStartY = this.gesturePanY
      })
      .onActionUpdate((event?: GestureEvent) => {
        if (this.routeTaps) return
        if (event === undefined || !this.active || this.ignorePanSequence || this.isPinching || this.gestureScale <= 1.01) return
        this.tapCancelled = true
        this.clearSingleTap()
        const nextX = this.clampOffset(this.panStartX + (event.offsetX as number), this.viewportWidth, this.displayWidth(), this.gestureScale)
        const nextY = this.clampOffset(this.panStartY + (event.offsetY as number), this.viewportHeight, this.displayHeight(), this.gestureScale)
        this.gesturePanX = nextX
        this.gesturePanY = nextY
        if (this.active) this.onTransformChange(this.gestureScale, nextX, nextY, this.gestureScale > 1.01)
      })
      .onActionEnd(() => { this.ignorePanSequence = false })
      .onActionCancel(() => { this.ignorePanSequence = false })
  }

  private surfaceGestures(): GestureGroupInterface {
    if (this.routeTaps) {
      // Continuous rows arbitrate single/double taps and zoomed pan from
      // their raw touch sequence so List cannot retain a competing recognizer.
      // Keep the native pinch recognizer as the preferred fast path; the raw
      // pinch fallback above covers runtimes where List holds that recognizer.
      return GestureGroup(GestureMode.Parallel, this.surfacePinchGesture())
    }
    return GestureGroup(GestureMode.Parallel, this.surfacePinchGesture(), this.surfaceDoubleTapGesture(), this.pagedPanGesture())
  }

  @Builder
  private LoadingContent() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      LoadingProgress().width(28).height(28).color(Color.White)
      Text(this.failed ? s('reader_page_load_failed') : s('reader_decoding_image')).fontSize(13).fontColor(Color.White)
    }.justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).width('100%').height('100%')
  }

  private onDisplayComplete(event?: ReaderImageLoadEvent): void {
    if (this.displayUri.length === 0 || this.failed) {
      return
    }
    this.publishImageInfo(event?.width, event?.height)
    this.loading = false
    this.failed = false
    console.info(`[ReaderImage] step=display_complete page=${this.pageIndex + 1}`)
    this.onLoaded(this.pageIndex)
  }

  private onDisplayError(): void {
    if (this.displayUri.length === 0) {
      return
    }
    this.loading = false
    this.failed = true
    this.displayUri = ''
    console.warn(`[ReaderImage] step=display_failed page=${this.pageIndex + 1}`)
    this.onFailed(this.pageIndex)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.displayUri.length > 0) {
        Image(this.displayUri)
          .width(this.displayWidth() > 0 ? this.displayWidth() : '100%')
          .height(this.displayHeight() > 0 ? this.displayHeight() : '100%')
          .objectFit(ImageFit.Contain)
          .interpolation(imageInterpolation(this.scalingQuality))
          .rotate({ angle: this.rotateClockwise ? 90 : 0 })
          .scale({ x: this.renderScale, y: this.renderScale })
          .translate({ x: this.renderPanX, y: this.renderPanY })
          .animation({ duration: this.zoomAnimating ? READER_ZOOM_ANIM_DURATION : 0, curve: Curve.FastOutSlowIn })
          .onComplete((event?: ReaderImageLoadEvent) => { this.onDisplayComplete(event) })
          .onError(() => { this.onDisplayError() })
      }
      if (this.displayUri.length === 0 || this.loading) {
        this.LoadingContent()
      }
    }
    .width('100%').height('100%').clip(true)
    .onAreaChange((_old: Area, next: Area) => {
      this.viewportWidth = next.width as number
      this.viewportHeight = next.height as number
      this.areaGlobalX = next.globalPosition.x as number
      this.areaGlobalY = next.globalPosition.y as number
    })
    // Match NextE's vertical image contract: native List owns every
    // unzoomed one-finger drag. Touch is used only to defer/cancel a single
    // tap, while the image contributes its independent double-tap, pinch and
    // zoomed-pan recognizers below. A single-tap recognizer here would join
    // the recognizer race and starve the List before it can start scrolling.
    .onTouch((event: TouchEvent) => { this.onSurfaceTouch(event) })
    .gesture(this.surfaceGestures())
  }
}

/**
 * The NextE thumbnail strip is driven by page metadata.  Koma does not have
 * a second thumbnail URL per page, so this tile deliberately goes through the
 * canonical ReaderPageSourceAdapter and decodes a bounded PixelMap from the
 * same cache used by the reader surface.  It never issues an unbounded
 * full-resolution render just to paint a thumbnail.
 */
@ComponentV2
struct ReaderThumbnailTile {
  @Param source: ReaderPageRenderSource = EMPTY_RENDER_SOURCE
  @Param pageIndex: number = 0
  @Param selected: boolean = false
  @Event onTap: (pageIndex: number) => void = (_pageIndex: number) => {}

  @Local private pixelMap: image.PixelMap | undefined = undefined
  @Local private loading: boolean = false
  @Local private failed: boolean = false
  private disposed: boolean = false
  private generation: number = 0

  aboutToAppear(): void {
    this.disposed = false
    void this.resolveThumbnail()
  }

  aboutToDisappear(): void {
    this.disposed = true
    this.generation += 1
    void this.releasePixelMap()
  }

  @Monitor('source')
  onSourceChanged(): void {
    void this.resolveThumbnail()
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

  private async resolveThumbnail(): Promise<void> {
    this.generation += 1
    const run = this.generation
    this.loading = true
    this.failed = false
    await this.releasePixelMap()
    if (this.source.kind === ReaderPageRenderKind.URI_PLACEHOLDER || this.source.imageUri.length === 0) {
      this.loading = false
      this.failed = true
      return
    }
    let imageSource: image.ImageSource | undefined = undefined
    try {
      const filePath = await fetchAndCacheReaderRemoteSource(this.source)
      if (this.disposed || run !== this.generation) {
        return
      }
      imageSource = image.createImageSource(filePath)
      const info = await imageSource.getImageInfo()
      if (this.disposed || run !== this.generation) {
        return
      }
      const sourceWidth = Math.max(1, info.size.width)
      const sourceHeight = Math.max(1, info.size.height)
      const scale = Math.min(1, READER_THUMB_DECODE_MAX_EDGE / Math.max(sourceWidth, sourceHeight))
      const map = await imageSource.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(sourceWidth * scale)),
          height: Math.max(1, Math.round(sourceHeight * scale)),
        },
      })
      if (this.disposed || run !== this.generation) {
        await map.release()
        return
      }
      this.pixelMap = map
      this.failed = false
    } catch (_error) {
      if (!this.disposed && run === this.generation) {
        this.failed = true
      }
    } finally {
      if (imageSource !== undefined) {
        try {
          await imageSource.release()
        } catch (_error) {
        }
      }
      if (!this.disposed && run === this.generation) {
        this.loading = false
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.pixelMap !== undefined) {
        Image(this.pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.Medium)
      } else if (this.loading) {
        LoadingProgress().width(20).height(20).color('#CCFFFFFF')
      } else if (this.failed) {
        SymbolGlyph($r('sys.symbol.exclamationmark_triangle'))
          .fontSize(18)
          .fontColor(['#CCFFFFFF'])
      }
      Text(`${this.pageIndex + 1}`)
        .fontSize(11)
        .fontColor(Color.White)
        .padding({ left: 5, right: 5, top: 2, bottom: 2 })
        .borderRadius(8)
        .backgroundColor('#AA000000')
        .position({ right: 4, bottom: 4 })
    }
    .width(READER_THUMB_TILE_WIDTH)
    .height(READER_THUMB_TILE_HEIGHT)
    .border({ width: this.selected ? 2 : 1, color: this.selected ? ThemeConstants.BRAND_PRIMARY : '#55FFFFFF' })
    .borderRadius(ThemeConstants.RADIUS_CARD)
    .backgroundColor('#33000000')
    .clip(true)
    .onClick(() => { this.onTap(this.pageIndex) })
  }
}

@ComponentV2
export struct ReaderPage {
  @Param readerOpen: boolean = false
  @Param routeVisible: boolean = false
  @Param sessionLoading: boolean = false
  @Param closeRequestId: number = 0
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
  @Event $routeVisible: (value: boolean) => void = (_value: boolean) => {}
  @Event $sessionLoading: (value: boolean) => void = (_value: boolean) => {}
  @Event $closeRequestId: (value: number) => void = (_value: number) => {}
  @Event $pageIndex: (value: number) => void = (_value: number) => {}
  @Event $chromeVisible: (value: boolean) => void = (_value: boolean) => {}
  @Event $webtoonMode: (value: boolean) => void = (_value: boolean) => {}

  @Local private preferences: ReaderPreferences = DEFAULT_READER_PREFERENCES
  @Local private preferenceRevision: number = 0
  /** The reader owns immediate chrome rendering; the route receives a sync event. */
  @Local private chromeShown: boolean = false
  @Local private viewportWidth: number = 0
  @Local private viewportHeight: number = 0
  @Local private zoomed: boolean = false
  @Local private zoomScale: number = 1
  @Local private panX: number = 0
  @Local private panY: number = 0
  @Local private zoomResetToken: number = 0
  @Local private loadedRevision: number = 0
  @Local private failedPages: number[] = []
  @Local private loadedPageIndexes: number[] = []
  @Local private continuousOffset: number = 0
  @Local private settingsReady: boolean = false
  @Local private tapPreviewVisible: boolean = false
  @Local private autoPageActive: boolean = false
  @Local private thumbnailStripVisible: boolean = false
  @Local private verticalVisibleStart: number = 0
  @Local private verticalVisibleEnd: number = 0
  @Local private verticalZoomedPage: number = -1
  @Local private measuredPageWidths: number[] = []
  @Local private measuredPageHeights: number[] = []
  @Local private measuredPageRevision: number = 0
  @Local private readerGlobalX: number = 0
  @Local private readerGlobalY: number = 0
  @Local private readerDoubleTapSequence: number = 0
  @Local private readerDoubleTapTargetPage: number = -1
  @Local private readerDoubleTapX: number = 0
  @Local private readerDoubleTapY: number = 0
  @Local private continuousRenderTargetPage: number = -1
  @Local private continuousRenderScale: number = 1
  @Local private continuousRenderPanX: number = 0
  @Local private continuousRenderPanY: number = 0
  /**
   * Immutable session snapshot.  It is deliberately separate from the
   * LazyForEach index sources: resolving an offline page source validates a
   * manifest and must never run on a tap, scroll or render callback.
   */
  @Local private readerPageSources: ReaderPageRenderSource[] = []
  private layout: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private readerModeState: ReaderModeState = connectReaderModeState()
  private preferencesStore?: ReaderPreferencesStore
  private filesDir: string = ''
  private sourceSignature: string = ''
  private swiperController: SwiperController = new SwiperController()
  private doublePageSwiperController: SwiperController = new SwiperController()
  private listScroller: Scroller = new Scroller()
  private thumbnailScroller: Scroller = new Scroller()
  /** Kept stable: LazyForEach, rather than the Reader build, owns long-page rows. */
  private pageIndexSource: ReaderPageIndexDataSource = new ReaderPageIndexDataSource()
  private spreadStartSource: ReaderPageIndexDataSource = new ReaderPageIndexDataSource()
  private pageIndexSourceKey: string = ''
  private spreadStartSourceKey: string = ''
  private statusBarHideTimerId: number = -1
  private statusBarEpoch: number = 0
  /**
   * Window system-bar APIs are asynchronous. Keep writes ordered so a hide
   * already handed to the platform cannot finish after a newer detail/chrome
   * restore and leave the final bar state stale.
   */
  private statusBarWriteTail: Promise<void> = Promise.resolve()
  private observedCloseRequestId: number = 0
  private volumeDownConsumer: ((event: InputConsumerKeyEvent) => void) | null = null
  private volumeUpConsumer: ((event: InputConsumerKeyEvent) => void) | null = null
  private closing: boolean = false
  private autoPageTimerId: number = -1
  private autoPageWaitingIndex: number = -1
  private continuousInitialTarget: number = -1
  private prefetchEpoch: number = 0
  private overlayTapStartX: number = 0
  private overlayTapStartY: number = 0
  private overlayTapSuppressedUntilMs: number = 0

  aboutToAppear(): void {
    this.closing = false
    this.chromeShown = this.chromeVisible
    this.loadPreferences()
    this.syncSession(true)
    this.registerVolumeKeyConsumerIfNeeded()
  }

  aboutToDisappear(): void {
    this.persistCurrentProgress()
    this.sessionStore.flush()
    this.setReaderKeepScreenOn(false)
    this.clearStatusBarHideTimer()
    this.unregisterVolumeKeyConsumer()
    this.stopAutoPage()
  }

  @Monitor('sessionConfig')
  onSessionChanged(): void {
    this.syncSession(true)
  }

  @Monitor('pageIndex')
  onParentPageChanged(): void {
    this.persistCurrentProgress()
  }

  @Monitor('readerOpen', 'chromeVisible')
  onReaderVisibilityChanged(): void {
    this.chromeShown = this.chromeVisible
    if (!this.readerOpen) {
      this.clearStatusBarHideTimer()
      return
    }
    if (this.routeVisible) {
      this.syncReaderStatusBarWithChrome()
    }
  }

  @Monitor('routeVisible')
  onReaderRouteVisibilityChanged(): void {
    if (!this.routeVisible) {
      this.clearStatusBarHideTimer()
      // A pushed Reader-owned detail route covers this page without closing
      // it. Restore the application bar before that route becomes visible;
      // a normal Reader close already does this before it pops.
      if (!this.closing) {
        void this.applyAppStatusBarVisible(this.appShellUsesDarkMode())
      }
      return
    }
    this.scheduleStatusBarVisibility()
  }

  @Monitor('closeRequestId')
  onReaderCloseRequested(): void {
    if (this.closeRequestId === this.observedCloseRequestId || this.closing) {
      return
    }
    this.observedCloseRequestId = this.closeRequestId
    this.closeReaderRoute()
  }

  @Monitor('readerModeState.revision')
  onReaderModeStateChanged(): void {
    if (!this.readerModeState.hydrated || !this.settingsReady) {
      return
    }
    // The spread-column pairing is session progress, never global runtime
    // state.  Keep it while applying a Settings-page change to this live
    // Reader.
    this.applyPreferences(readerPreferencesFromRuntimeState(this.preferences.columnMode), false)
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
      // Pairing parity belongs to the active comic/chapter progress.  The
      // legacy global preference remains only as a migration fallback in the
      // store; never carry another comic's parity into a new session.
      this.preferences.columnMode = this.sessionStore.restoreColumnMode(this.sessionConfig, 'odd_left')
      this.settingsReady = true
      this.rebuildReaderPageSources()
      this.preferenceRevision += 1
      this.tapPreviewVisible = false
      this.setReaderKeepScreenOn(this.preferences.keepScreenAwake)
      this.emitWebtoonMode(this.preferences.pageMode === 'continuous_scroll' || this.preferences.readingDirection === ReadingDirection.WEBTOON)
      this.registerVolumeKeyConsumerIfNeeded()
      if (this.routeVisible) {
        this.scheduleStatusBarVisibility()
      }
    } catch (_error) {
      this.preferences = DEFAULT_READER_PREFERENCES
      this.settingsReady = true
      this.rebuildReaderPageSources()
      this.tapPreviewVisible = false
      this.setReaderKeepScreenOn(this.preferences.keepScreenAwake)
      this.registerVolumeKeyConsumerIfNeeded()
      if (this.routeVisible) {
        this.scheduleStatusBarVisibility()
      }
    }
  }

  private readerStatusBarContentColor(chromeVisible: boolean): string {
    // The bars are rendered on a dark scrim, so their status-area content must
    // remain light even when the page itself uses the white/auto palette.
    return chromeVisible || this.readerBackgroundIsDarkForStatus() ? '#FFFFFFFF' : '#FF000000'
  }

  private readerBackgroundIsDarkForStatus(): boolean {
    return this.preferences.backgroundMode === 'black' ||
      (this.preferences.backgroundMode === 'auto' && this.preferences.themeMode === 'dark')
  }

  private enqueueStatusBarWrite(
    operation: (win: window.Window, epoch: number) => Promise<void>,
  ): Promise<void> {
    const epoch = ++this.statusBarEpoch
    const run = (): Promise<void> => {
      if (epoch !== this.statusBarEpoch) {
        return Promise.resolve()
      }
      try {
        const context = getContext(this) as common.UIAbilityContext
        return window.getLastWindow(context).then((win: window.Window): Promise<void> => {
          if (epoch !== this.statusBarEpoch) {
            return Promise.resolve()
          }
          return operation(win, epoch).catch(() => {})
        }).catch(() => {})
      } catch (_error) {
        return Promise.resolve()
      }
    }
    const queued = this.statusBarWriteTail.then(run, run)
    // A failed platform write must never poison a later route owner's write.
    this.statusBarWriteTail = queued.catch(() => {})
    return queued
  }

  private applyStatusBarVisible(visible: boolean, chromeVisible: boolean = this.chromeShown): Promise<void> {
    return this.enqueueStatusBarWrite((win: window.Window, epoch: number): Promise<void> => {
      if (visible) {
        return win.setWindowSystemBarProperties({
          statusBarContentColor: this.readerStatusBarContentColor(chromeVisible),
          isStatusBarLightIcon: chromeVisible || this.readerBackgroundIsDarkForStatus(),
        }).then((): Promise<void> => {
          if (epoch !== this.statusBarEpoch) {
            return Promise.resolve()
          }
          return win.setSpecificSystemBarEnabled('status', true, false)
        })
      }
      return win.setSpecificSystemBarEnabled('status', false, false)
    })
  }

  private setReaderStatusBarForChrome(chromeVisible: boolean): void {
    this.applyStatusBarVisible(!this.preferences.fullscreen || chromeVisible, chromeVisible)
  }

  private syncReaderStatusBarWithChrome(): void {
    this.setReaderStatusBarForChrome(this.chromeShown)
  }

  private applyAppStatusBarVisible(dark: boolean): Promise<void> {
    return this.enqueueStatusBarWrite((win: window.Window, epoch: number): Promise<void> => {
      return win.setWindowSystemBarProperties({
        statusBarColor: '#00FFFFFF',
        navigationBarColor: '#00FFFFFF',
        statusBarContentColor: dark ? '#FFFFFFFF' : '#FF000000',
        isStatusBarLightIcon: dark,
      }).then((): Promise<void> => {
        if (epoch !== this.statusBarEpoch) {
          return Promise.resolve()
        }
        return win.setSpecificSystemBarEnabled('status', true, false)
      })
    })
  }

  private appShellUsesDarkMode(): boolean {
    try {
      const context = getContext(this) as common.UIAbilityContext
      return context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK
    } catch (_error) {
      return false
    }
  }

  private clearStatusBarHideTimer(): void {
    if (this.statusBarHideTimerId >= 0) {
      clearTimeout(this.statusBarHideTimerId)
      this.statusBarHideTimerId = -1
    }
  }

  private scheduleStatusBarVisibility(): void {
    this.clearStatusBarHideTimer()
    if (!this.readerOpen || !this.routeVisible || !this.preferences.fullscreen || this.chromeShown) {
      this.setReaderStatusBarForChrome(this.chromeShown)
      return
    }
    const epoch = ++this.statusBarEpoch
    this.statusBarHideTimerId = setTimeout(() => {
      this.statusBarHideTimerId = -1
      if (epoch === this.statusBarEpoch && this.readerOpen && this.routeVisible && this.preferences.fullscreen && !this.chromeShown) {
        this.setReaderStatusBarForChrome(false)
      }
    }, 500)
  }

  private closeReaderRoute(): void {
    if (this.closing) {
      return
    }
    this.closing = true
    this.statusBarEpoch += 1
    this.clearStatusBarHideTimer()
    this.stopAutoPage()
    this.persistCurrentProgress()
    this.sessionStore.flush()
    this.applyAppStatusBarVisible(this.appShellUsesDarkMode()).then(() => {
      setTimeout(() => {
        this.onCloseReader()
      }, 20)
    })
  }

  @Builder
  private ReaderSessionLoading() {
    Column({ space: ThemeConstants.SPACE_MD }) {
      LoadingProgress()
        .width(ThemeConstants.LOADING_SIZE_LARGE)
        .height(ThemeConstants.LOADING_SIZE_LARGE)
        .color(ThemeConstants.BRAND_PRIMARY)
      Text(s('source_pkg_loading'))
        .fontSize(16)
        .fontColor(readerForeground(this.preferences.backgroundMode))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(ThemeConstants.SPACE_XL)
  }

  private clearAutoPageTimer(): void {
    if (this.autoPageTimerId >= 0) {
      clearTimeout(this.autoPageTimerId)
      this.autoPageTimerId = -1
    }
  }

  private scheduleAutoPage(): void {
    this.clearAutoPageTimer()
    if (!this.autoPageActive || !this.readerOpen || this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL) {
      return
    }
    this.autoPageTimerId = setTimeout(() => {
      this.autoPageTimerId = -1
      if (!this.autoPageActive || this.zoomed || !this.readerOpen) {
        this.scheduleAutoPage()
        return
      }
      if (!this.canNext()) {
        this.stopAutoPage()
        return
      }
      const target = this.nextAutoPageIndex()
      if (target < 0 || target >= this.sessionConfig.totalPages) {
        this.stopAutoPage()
        return
      }
      if (!this.isPageReadyForAutoPage(target)) {
        this.waitForAutoPage(target)
        return
      }
      this.setPage(target)
      this.scheduleAutoPage()
    }, Math.max(1, this.preferences.autoPageSeconds) * 1000)
  }

  private toggleAutoPage(): void {
    if (this.autoPageActive) {
      this.stopAutoPage()
      return
    }
    if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL) {
      return
    }
    this.autoPageActive = true
    this.scheduleAutoPage()
  }

  private stopAutoPage(): void {
    this.autoPageActive = false
    this.autoPageWaitingIndex = -1
    this.clearAutoPageTimer()
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
    this.loadedPageIndexes = []
    this.autoPageWaitingIndex = -1
    this.measuredPageWidths = []
    this.measuredPageHeights = []
    this.resetZoomState()
    this.rebuildReaderPageSources()
    this.refreshPageDataSources(true)
    if (resetPage && this.sessionConfig.totalPages > 0 && this.pageIndex >= this.sessionConfig.totalPages) {
      this.emitPageIndex(this.sessionConfig.totalPages - 1)
    }
  }

  private effectiveMode(): ReaderMode {
    // An explicit vertical-paged mode must win over the legacy WEBTOON
    // direction flag. Otherwise selecting vertical paging after continuous
    // mode leaves the old direction latched and still renders a List.
    if (this.preferences.pageMode === 'vertical_page') {
      return ReaderMode.VERTICAL_PAGE
    }
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

  private refreshPageDataSources(force: boolean = false): void {
    const pageKey = this.sessionSignature()
    if (force || pageKey !== this.pageIndexSourceKey) {
      this.pageIndexSourceKey = pageKey
      this.pageIndexSource.setIndexes(this.pageIndexes())
    }
    const spreadKey = `${pageKey}:${this.preferences.columnMode}`
    if (force || spreadKey !== this.spreadStartSourceKey) {
      this.spreadStartSourceKey = spreadKey
      this.spreadStartSource.setIndexes(this.spreadIndexes())
    }
  }

  private spreadIndexes(): number[] {
    const out: number[] = []
    const total = this.sessionConfig.totalPages
    if (this.preferences.columnMode === 'even_left') {
      if (total > 0) out.push(0)
      for (let index = 1; index < total; index += 2) out.push(index)
      return out
    }
    for (let index = 0; index < total; index += 2) out.push(index)
    return out
  }

  private spreadIndexForPage(pageIndex: number): number {
    const normalized = Math.max(0, Math.min(pageIndex, Math.max(this.sessionConfig.totalPages - 1, 0)))
    if (this.preferences.columnMode === 'even_left') {
      return normalized <= 0 ? 0 : Math.floor((normalized + 1) / 2)
    }
    return Math.floor(normalized / 2)
  }

  private spreadSecondIndex(start: number): number {
    if (this.preferences.columnMode === 'even_left' && start <= 0) {
      return -1
    }
    return start + 1
  }

  private hasSpreadSecond(start: number): boolean {
    const second = this.spreadSecondIndex(start)
    return second >= 0 && second < this.sessionConfig.totalPages
  }

  private rebuildReaderPageSources(): void {
    // `syncSession` runs before the asynchronous preference read completes.
    // Before the app files directory is known, use only canonical session
    // URIs; after it is known, replace the whole list with one validated
    // offline snapshot.  No later reader hot path reads the manifest.
    const preferOffline = this.filesDir.length > 0 && this.sessionConfig.comicId.trim().length > 0
    this.readerPageSources = createReaderPageRenderSources(this.sessionConfig, { preferOffline })
  }

  private sourceFor(index: number): ReaderPageRenderSource {
    if (index >= 0 && index < this.readerPageSources.length) {
      return this.readerPageSources[index]
    }
    // A session always builds the complete list.  This fallback only covers a
    // transient empty config during route teardown and intentionally bypasses
    // offline resolution so it cannot reintroduce synchronous manifest I/O.
    return createReaderPageRenderSource(this.sessionConfig, index, { preferOffline: false })
  }

  private pageImageSourceLabel(): string {
    return this.sourceFor(this.pageIndex).kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE
      ? s('reader_image_info_local')
      : s('reader_image_info_cached')
  }

  private pageImageTitle(): string {
    const base = (this.sessionConfig.title ?? s('reader_title_default')).trim()
    const normalized = base.replace(/[\\/:*?"<>|]/g, '_').replace(/\s+/g, ' ').trim()
    const safe = normalized.length > 0 ? normalized.substring(0, 80) : s('reader_title_default')
    return `${safe}-${this.pageIndex + 1}`
  }

  private imageExtension(path: string): string {
    const name = path.split('?')[0].split('#')[0].toLowerCase()
    const lastSlash = name.lastIndexOf('/')
    const dot = name.lastIndexOf('.')
    if (dot <= lastSlash || dot >= name.length - 1) {
      return 'jpg'
    }
    const extension = name.substring(dot + 1).replace(/[^a-z0-9]/g, '')
    if (extension === 'jpeg' || extension === 'jpg' || extension === 'png' || extension === 'webp' || extension === 'bmp' || extension === 'gif' || extension === 'heic') {
      return extension
    }
    return 'jpg'
  }

  private async pageImageFileForSystemAction(): Promise<string> {
    const source = this.sourceFor(this.pageIndex)
    if (source.kind === ReaderPageRenderKind.URI_PLACEHOLDER || source.imageUri.length === 0) {
      throw new Error('reader_page_source_unavailable')
    }
    const sourcePath = await fetchAndCacheReaderRemoteSource(source)
    const sandboxRoot = this.filesDir.trim().length > 0 ? `${this.filesDir}/` : ''
    if (sandboxRoot.length > 0 && sourcePath.startsWith(sandboxRoot)) {
      return sourcePath
    }
    if (sandboxRoot.length === 0) {
      throw new Error('reader_files_dir_unavailable')
    }
    const extension = this.imageExtension(source.imageUri.length > 0 ? source.imageUri : sourcePath)
    const exportDir = `${this.filesDir}/reader-exports`
    const exportPath = `${exportDir}/${this.pageImageTitle()}.${extension}`
    if (!fs.accessSync(exportDir)) {
      fs.mkdirSync(exportDir)
    }
    let sourceFile: fs.File | undefined = undefined
    let targetFile: fs.File | undefined = undefined
    try {
      sourceFile = await fs.open(sourcePath, fs.OpenMode.READ_ONLY)
      targetFile = await fs.open(exportPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      await fs.copyFile(sourceFile.fd, targetFile.fd, 0)
      return exportPath
    } finally {
      if (sourceFile !== undefined) {
        try { fs.closeSync(sourceFile) } catch (_error) {}
      }
      if (targetFile !== undefined) {
        try { fs.closeSync(targetFile) } catch (_error) {}
      }
    }
  }

  private showReaderToast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: message })
    } catch (_error) {
    }
  }

  private async saveCurrentPageImage(): Promise<void> {
    try {
      const sourcePath = await this.pageImageFileForSystemAction()
      const context = getContext(this) as common.UIAbilityContext
      const helper = photoAccessHelper.getPhotoAccessHelper(context)
      const targets = await helper.showAssetsCreationDialog(
        [fileUri.getUriFromPath(sourcePath)],
        [{
          title: this.pageImageTitle(),
          fileNameExtension: this.imageExtension(sourcePath),
          photoType: photoAccessHelper.PhotoType.IMAGE,
          subtype: photoAccessHelper.PhotoSubtype.DEFAULT,
        }],
      )
      if (targets.length === 0) {
        return
      }
      let sourceFile: fs.File | undefined = undefined
      let targetFile: fs.File | undefined = undefined
      try {
        sourceFile = await fs.open(sourcePath, fs.OpenMode.READ_ONLY)
        targetFile = await fs.open(targets[0], fs.OpenMode.WRITE_ONLY)
        await fs.copyFile(sourceFile.fd, targetFile.fd, 0)
      } finally {
        if (sourceFile !== undefined) {
          try { fs.closeSync(sourceFile) } catch (_error) {}
        }
        if (targetFile !== undefined) {
          try { fs.closeSync(targetFile) } catch (_error) {}
        }
      }
      this.showReaderToast(s('reader_image_saved'))
    } catch (_error) {
      this.showReaderToast(s('reader_image_save_failed'))
    }
  }

  private async shareCurrentPageImage(): Promise<void> {
    try {
      const sourcePath = await this.pageImageFileForSystemAction()
      const extension = this.imageExtension(sourcePath)
      const sharedData = new systemShare.SharedData({
        utd: utd.getUniformDataTypeByFilenameExtension(`.${extension}`, utd.UniformDataType.IMAGE),
        uri: fileUri.getUriFromPath(sourcePath),
        title: this.pageImageTitle(),
      })
      const controller = new systemShare.ShareController(sharedData)
      const context = getContext(this) as common.UIAbilityContext
      await controller.show(context, {
        previewMode: systemShare.SharePreviewMode.DETAIL,
        selectionMode: systemShare.SelectionMode.SINGLE,
      })
    } catch (_error) {
      this.showReaderToast(s('reader_image_share_failed'))
    }
  }

  private pageWidth(index: number): number | undefined {
    if (index >= 0 && index < this.measuredPageWidths.length && this.measuredPageWidths[index] > 0) {
      return this.measuredPageWidths[index]
    }
    return getReaderSessionPageWidth(this.sessionConfig, index)
  }

  private pageHeight(index: number): number | undefined {
    if (index >= 0 && index < this.measuredPageHeights.length && this.measuredPageHeights[index] > 0) {
      return this.measuredPageHeights[index]
    }
    return getReaderSessionPageHeight(this.sessionConfig, index)
  }

  private rememberImageInfo(index: number, width: number, height: number): void {
    if (index < 0 || width <= 0 || height <= 0) {
      return
    }
    if (this.pageWidth(index) === width && this.pageHeight(index) === height) {
      return
    }
    const widths = this.measuredPageWidths.slice()
    const heights = this.measuredPageHeights.slice()
    while (widths.length <= index) widths.push(0)
    while (heights.length <= index) heights.push(0)
    widths[index] = width
    heights[index] = height
    this.measuredPageWidths = widths
    this.measuredPageHeights = heights
    this.measuredPageRevision += 1
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

  private canTurnOnePageInDoublePage(): boolean {
    return this.effectiveMode() === ReaderMode.DUAL_PAGE &&
      this.pageIndex + 1 < this.sessionConfig.totalPages
  }

  private turnOnePageInDoublePage(): void {
    if (!this.canTurnOnePageInDoublePage()) {
      return
    }
    const target = this.pageIndex + 1
    const next = this.copyPreferences()
    // NextE alternates the first spread parity when stepping one page so the
    // newly exposed page becomes the leading page of the next spread.
    next.columnMode = target % 2 === 0 ? 'odd_left' : 'even_left'
    this.preferences = next
    this.preferenceRevision += 1
    this.refreshPageDataSources()
    this.persistPreferences(next)
    this.setPage(target)
  }

  private setPage(index: number, animated: boolean = this.preferences.pageTurnAnimation): void {
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
      this.doublePageSwiperController.changeIndex(this.spreadIndexForPage(target), animated)
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
      this.listScroller.scrollToIndex(index, animated, ScrollAlign.START)
    }, 80)
  }

  private continuousItemExtent(): number {
    return Math.max(this.viewportHeight - this.layout.topAvoidHeight - this.layout.bottomAvoidHeight, 360)
  }

  private continuousRowHeight(index: number): number {
    let width = this.pageWidth(index)
    let height = this.pageHeight(index)
    if (this.preferences.wideImageMode === 'rotate_wide_pages' && isWidePage(width, height)) {
      const originalWidth = width
      width = height
      height = originalWidth
    }
    if (width !== undefined && height !== undefined && width > 0 && height > 0 && this.viewportWidth > 0) {
      return Math.max(120, this.viewportWidth * height / width + pageGap(this.preferences.pageGapMode))
    }
    return this.continuousItemExtent()
  }

  private onModeChange(mode: ReaderMode): void {
    const next = this.copyPreferences()
    next.pageMode = mode === ReaderMode.DUAL_PAGE ? 'double_page' :
      (mode === ReaderMode.CONTINUOUS_SCROLL ? 'continuous_scroll' :
        (mode === ReaderMode.VERTICAL_PAGE ? 'vertical_page' : 'single_page'))
    if (mode === ReaderMode.CONTINUOUS_SCROLL) {
      next.readingDirection = ReadingDirection.WEBTOON
    } else if (next.readingDirection === ReadingDirection.WEBTOON) {
      next.readingDirection = ReadingDirection.LEFT_TO_RIGHT
    }
    this.preferences = next
    this.preferenceRevision += 1
    this.emitWebtoonMode(mode === ReaderMode.CONTINUOUS_SCROLL)
    this.persistPreferences(next)
    this.resetZoomState()
    if (mode === ReaderMode.CONTINUOUS_SCROLL) {
      this.continuousInitialTarget = this.pageIndex
      setTimeout(() => {
        if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL && this.continuousInitialTarget >= 0) {
          this.listScroller.scrollToIndex(this.continuousInitialTarget, false, ScrollAlign.START)
        }
      }, 80)
    } else {
      this.continuousInitialTarget = -1
    }
    if (this.routeVisible) {
      this.scheduleStatusBarVisibility()
    }
  }

  private resetZoomState(): void {
    this.zoomed = false
    this.zoomScale = 1
    this.panX = 0
    this.panY = 0
    this.verticalZoomedPage = -1
    this.continuousRenderTargetPage = -1
    this.continuousRenderScale = 1
    this.continuousRenderPanX = 0
    this.continuousRenderPanY = 0
    this.zoomResetToken += 1
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
      fullscreen: p.fullscreen,
      imageFitMode: p.imageFitMode,
      imageScalingQuality: p.imageScalingQuality,
      showPageNumber: p.showPageNumber,
      pageTurnAnimation: p.pageTurnAnimation,
      autoPageSeconds: p.autoPageSeconds,
      preloadPages: p.preloadPages,
      spreadLayoutMode: p.spreadLayoutMode,
      columnMode: p.columnMode,
      tapZonePreset: p.tapZonePreset,
      tapZoneInvert: p.tapZoneInvert,
      pageGapMode: p.pageGapMode,
      trimPageMarginsEnabled: p.trimPageMarginsEnabled,
      wideImageMode: p.wideImageMode,
      volumeKeyNavigationEnabled: p.volumeKeyNavigationEnabled,
      volumeKeyBehavior: p.volumeKeyBehavior,
    }
  }

  private onPreferencesChanged(change: ReaderChromePreferencesChange): void {
    this.applyPreferences(change.preferences, true)
  }

  private applyPreferences(next: ReaderPreferences, persist: boolean): void {
    const previousMode = this.effectiveMode()
    const previousTapZone = this.preferences.tapZonePreset
    const previousTapInvert = this.preferences.tapZoneInvert
    this.preferences = next
    this.preferenceRevision += 1
    this.refreshPageDataSources()
    // NextE's zone feedback is intentionally immediate and one-shot: the
    // user gets the exact geometry they just selected, then dismisses it with
    // one tap. It is not a persistent reader mode.
    // A store publish is echoed back through ReaderModeState so Settings and
    // an already-open Reader share one source of truth.  That echo must not
    // erase the one-shot preview that the initiating selection just opened.
    if (previousTapZone !== this.preferences.tapZonePreset ||
      previousTapInvert !== this.preferences.tapZoneInvert) {
      this.tapPreviewVisible = true
    }
    this.setReaderKeepScreenOn(this.preferences.keepScreenAwake)
    this.emitWebtoonMode(this.preferences.pageMode === 'continuous_scroll' || this.preferences.readingDirection === ReadingDirection.WEBTOON)
    if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL && previousMode !== ReaderMode.CONTINUOUS_SCROLL) {
      this.continuousInitialTarget = this.pageIndex
      setTimeout(() => {
        if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL && this.continuousInitialTarget >= 0) {
          this.listScroller.scrollToIndex(this.continuousInitialTarget, false, ScrollAlign.START)
        }
      }, 80)
    } else if (this.effectiveMode() !== ReaderMode.CONTINUOUS_SCROLL) {
      this.continuousInitialTarget = -1
    }
    this.registerVolumeKeyConsumerIfNeeded()
    if (!this.preferences.volumeKeyNavigationEnabled) {
      this.unregisterVolumeKeyConsumer()
    }
    if (this.routeVisible) {
      this.scheduleStatusBarVisibility()
    }
    if (persist) {
      this.persistPreferences(this.preferences)
      this.persistCurrentProgress()
    }
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
    const total = this.sessionConfig.totalPages
    this.sessionStore.saveProgress({
      comicId: this.sessionConfig.comicId,
      chapterId: this.sessionConfig.chapterId,
      pageId: getReaderSessionPageId(this.sessionConfig, index),
      pageIndex: Math.min(Math.max(index, 0), total - 1),
      totalPages: total,
      progressRatio: (Math.min(Math.max(index, 0), total - 1) + 1) / total,
      completed: index >= total - 1,
      updatedAt: Date.now(),
      columnMode: this.preferences.columnMode,
    })
    this.prefetchLookahead(index)
  }

  /**
   * Warm the same remote-image cache used by the visible surface.  NextE keeps
   * a bounded lookahead alive independently of pager construction; doing this
   * at the progress boundary also covers Swiper, double-page and continuous
   * List transitions without introducing a second data source.
   */
  private prefetchLookahead(startIndex: number): void {
    const count = Math.max(0, Math.min(5, Math.round(this.preferences.preloadPages)))
    if (count <= 0 || this.sessionConfig.totalPages <= 0) {
      return
    }
    // `sourceFor` prefers an offline page and synchronously resolves its
    // download manifest.  Calling it once per lookahead slot from a tap
    // handler turns a normal page turn into repeated filesystem traversal;
    // the device watchdog captured that exact stack as THREAD_BLOCK_6S.
    // A currently downloaded page has no network latency to hide, so it must
    // not enter remote warming at all.  For a remote current page, construct
    // lookahead sources with offline preference disabled: warming never needs
    // a download-manifest lookup and still skips genuinely local archives.
    if (this.sourceFor(startIndex).kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE) {
      return
    }
    const epoch = ++this.prefetchEpoch
    for (let offset = 1; offset <= count; offset += 1) {
      const index = startIndex + offset
      if (index >= this.sessionConfig.totalPages) {
        break
      }
      const source = createReaderPageRenderSource(this.sessionConfig, index, { preferOffline: false })
      if (source.kind !== ReaderPageRenderKind.REMOTE_URL_IMAGE) {
        continue
      }
      void fetchAndCacheReaderRemoteSource(source).catch(() => {
        // The visible page owns user-facing failure/retry.  Lookahead is
        // opportunistic and must never turn a successful page into an error.
        if (epoch !== this.prefetchEpoch) {
          return
        }
      })
    }
  }

  /**
   * A downloaded chapter is already locally available, so its next-page work
   * is rendering work rather than network warming.  On the target device a
   * double-page Swiper retaining two neighbouring spreads starts four full
   * local decodes while the first spread is still painting.  That starves the
   * UI thread long enough for the system freeze watchdog to terminate the
   * ability.  Keep the visible spread responsive; each adjacent page is
   * created only when the user actually turns to it. Remote chapters retain
   * the user-selected cache depth because that cache hides network latency.
   */
  private pagerCachedPageCount(): number {
    const activeSource = this.sourceFor(this.pageIndex)
    if (activeSource.kind === ReaderPageRenderKind.LOCAL_FILE_IMAGE) {
      return 0
    }
    return Math.max(0, Math.min(5, Math.round(this.preferences.preloadPages)))
  }

  private persistCurrentProgress(): void { this.persistProgress(this.pageIndex) }

  private onImageFailed(index: number): void {
    if (!this.failedPages.includes(index)) this.failedPages = this.failedPages.concat([index])
    if (this.autoPageWaitingIndex === index) {
      this.stopAutoPage()
    }
  }

  private onImageLoaded(index: number): void {
    if (this.failedPages.includes(index)) this.failedPages = this.failedPages.filter((item: number) => item !== index)
    if (!this.loadedPageIndexes.includes(index)) {
      this.loadedPageIndexes = this.loadedPageIndexes.concat([index])
    }
    this.maybeResumeAutoPage(index)
  }

  private isPageReadyForAutoPage(index: number): boolean {
    if (index < 0 || index >= this.sessionConfig.totalPages) {
      return false
    }
    if (this.loadedPageIndexes.includes(index)) {
      return true
    }
    // Mirrors NextE's preview-ready fallback: Koma already has canonical page
    // URIs at session creation, so a non-empty render source may advance even
    // when preload is explicitly configured to zero.
    return this.sourceFor(index).imageUri.length > 0 && !this.failedPages.includes(index)
  }

  private nextAutoPageIndex(): number {
    if (this.effectiveMode() !== ReaderMode.DUAL_PAGE) {
      return this.pageIndex + 1
    }
    const starts = this.spreadIndexes()
    const currentSpread = this.spreadIndexForPage(this.pageIndex)
    const nextSpread = currentSpread + 1
    return nextSpread >= 0 && nextSpread < starts.length ? starts[nextSpread] : -1
  }

  private waitForAutoPage(index: number): void {
    this.autoPageWaitingIndex = index
    this.clearAutoPageTimer()
    // The remote cache request is bounded by the Reader preference.  A loaded
    // surface will call maybeResumeAutoPage; a failed surface stops auto mode
    // rather than skipping unreadable content.
    this.prefetchLookahead(Math.max(-1, index - 1))
  }

  private maybeResumeAutoPage(index: number): void {
    if (!this.autoPageActive || this.autoPageTimerId >= 0 || this.autoPageWaitingIndex < 0) {
      return
    }
    if (index === this.autoPageWaitingIndex || this.isPageReadyForAutoPage(this.autoPageWaitingIndex)) {
      this.autoPageWaitingIndex = -1
      this.scheduleAutoPage()
    }
  }

  private toggleThumbnailStrip(): void {
    this.thumbnailStripVisible = !this.thumbnailStripVisible
    if (this.thumbnailStripVisible) {
      setTimeout(() => {
        this.scrollThumbnailStripTo(this.pageIndex, false)
      }, 0)
    }
  }

  private scrollThumbnailStripTo(index: number, animated: boolean): void {
    if (!this.thumbnailStripVisible || index < 0 || index >= this.sessionConfig.totalPages) {
      return
    }
    this.thumbnailScroller.scrollToIndex(index, animated, ScrollAlign.CENTER)
  }

  private zoomChanged(zoomed: boolean): void {
    this.zoomed = zoomed
    if (!zoomed) {
      this.zoomScale = 1
      this.panX = 0
      this.panY = 0
    }
  }

  private transformChanged(scale: number, panX: number, panY: number, zoomed: boolean): void {
    // This is telemetry for chrome actions only. Individual surfaces own the
    // actual transform, so a zoom can never leak to another page.
    this.zoomScale = Math.min(Math.max(scale, 1), READER_MAX_EFFECTIVE_ZOOM_SCALE)
    this.panX = panX
    this.panY = panY
    this.zoomed = zoomed
  }

  private tapAction(x: number, y: number): void {
    if (this.tapPreviewVisible) {
      this.tapPreviewVisible = false
      return
    }
    const action = resolveReaderTapZoneAction(this.preferences.tapZonePreset, this.preferences.tapZoneInvert, x, y, this.viewportWidth, this.viewportHeight)
    if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL) {
      if (action === 'previous' || action === 'left') {
        this.listScroller.scrollBy(0, -this.viewportHeight * READER_TAP_ZONE_SCROLL_RATIO)
      } else if (action === 'next' || action === 'right') {
        this.listScroller.scrollBy(0, this.viewportHeight * READER_TAP_ZONE_SCROLL_RATIO)
      } else {
        this.toggleChrome()
      }
      return
    }
    if (action === 'center' || action === 'menu') {
      this.toggleChrome()
    } else if (action === 'previous') {
      this.previousPage()
    } else if (action === 'next') {
      this.nextPage()
    } else if (action === 'left') {
      if (this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT) this.nextPage()
      else this.previousPage()
    } else {
      if (this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT) this.previousPage()
      else this.nextPage()
    }
  }

  private tapActionForSlot(x: number, y: number, _splitSide: 'none' | 'left' | 'right', _compact: boolean): void {
    this.tapAction(x, y)
  }

  private suppressOverlayTap(): void {
    this.overlayTapSuppressedUntilMs = Date.now() + READER_SINGLE_TAP_DELAY_MS
  }

  private consumeOverlayTapSuppression(): boolean {
    return Date.now() <= this.overlayTapSuppressedUntilMs
  }

  private overlayTouchPoint(event: TouchEvent): TouchObject | undefined {
    if (event.touches.length > 0) {
      return event.touches[0]
    }
    if (event.changedTouches.length > 0) {
      return event.changedTouches[0]
    }
    return undefined
  }

  private onPagedOverlayTouch(event: TouchEvent): void {
    const touch = this.overlayTouchPoint(event)
    if (touch === undefined) {
      return
    }
    if (event.touches.length > 1 || event.changedTouches.length > 1) {
      this.suppressOverlayTap()
      return
    }
    if (event.type === TouchType.Down) {
      this.overlayTapStartX = touch.x
      this.overlayTapStartY = touch.y
      return
    }
    if (event.type === TouchType.Move) {
      const dx = touch.x - this.overlayTapStartX
      const dy = touch.y - this.overlayTapStartY
      if (dx * dx + dy * dy > READER_TAP_VERTICAL_TOLERANCE * READER_TAP_VERTICAL_TOLERANCE) {
        this.suppressOverlayTap()
      }
      return
    }
    if (event.type === TouchType.Cancel) {
      this.suppressOverlayTap()
    }
  }

  private doubleTapTargetForPagedMode(x: number): number {
    if (this.effectiveMode() !== ReaderMode.DUAL_PAGE) {
      return this.pageIndex
    }
    const starts = this.spreadIndexes()
    const spread = this.spreadIndexForPage(this.pageIndex)
    const start = spread >= 0 && spread < starts.length ? starts[spread] : this.pageIndex
    const second = this.hasSpreadSecond(start) ? this.spreadSecondIndex(start) : -1
    if (second < 0) {
      return start
    }
    const leftPage = this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? second : start
    const rightPage = this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? start : second
    return x < this.viewportWidth / 2 ? leftPage : rightPage
  }

  private onPagedOverlayDoubleTap(x: number, y: number): void {
    if (this.consumeOverlayTapSuppression()) {
      return
    }
    this.readerDoubleTapX = x
    this.readerDoubleTapY = y
    this.readerDoubleTapTargetPage = this.doubleTapTargetForPagedMode(x)
    this.readerDoubleTapSequence += 1
  }

  @Builder
  private ReaderTapOverlay() {
    Blank()
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
      .onTouch((event: TouchEvent) => { this.onPagedOverlayTouch(event) })
      .gesture(
        GestureGroup(
          GestureMode.Exclusive,
          TapGesture({ count: 2, distanceThreshold: 8 }).onAction((event?: GestureEvent) => {
            const location = event?.tapLocation
            const x = location === undefined ? this.viewportWidth / 2 : location.x as number
            const y = location === undefined ? this.viewportHeight / 2 : location.y as number
            this.onPagedOverlayDoubleTap(x, y)
          }),
          TapGesture({ count: 1 }).onAction((event?: GestureEvent) => {
            if (this.consumeOverlayTapSuppression()) {
              return
            }
            const location = event?.tapLocation
            const x = location === undefined ? this.viewportWidth / 2 : location.x as number
            const y = location === undefined ? this.viewportHeight / 2 : location.y as number
            this.tapAction(x, y)
          }),
        ),
      )
  }

  private toggleChrome(): void {
    const nextVisible = !this.chromeShown
    this.chromeShown = nextVisible
    if (this.routeVisible) {
      this.setReaderStatusBarForChrome(nextVisible)
    }
    this.emitChromeVisible(nextVisible)
  }

  private emitPageIndex(value: number): void {
    this.onPageIndexChange(value)
    this.$pageIndex(value)
    this.scrollThumbnailStripTo(value, true)
  }

  private emitChromeVisible(value: boolean): void {
    this.onChromeVisibleChange(value)
    this.$chromeVisible(value)
  }

  private emitWebtoonMode(value: boolean): void {
    this.onWebtoonModeChange(value)
    this.$webtoonMode(value)
  }

  private handleKeyEvent(event: KeyEvent): boolean {
    if (!this.preferences.volumeKeyNavigationEnabled) {
      return false
    }
    if (event.keyCode !== KeyCode.KEYCODE_VOLUME_UP && event.keyCode !== KeyCode.KEYCODE_VOLUME_DOWN) {
      return false
    }
    if (event.type !== KeyType.Down) {
      return true
    }
    const volumeUp = event.keyCode === KeyCode.KEYCODE_VOLUME_UP
    const next = volumeUp
      ? this.preferences.volumeKeyBehavior === 'up_next_down_previous'
      : this.preferences.volumeKeyBehavior === 'up_previous_down_next'
    if (next) this.nextPage()
    else this.previousPage()
    return true
  }

  private registerVolumeKeyConsumerIfNeeded(): void {
    if (!this.readerOpen || !this.preferences.volumeKeyNavigationEnabled ||
      this.volumeDownConsumer !== null || this.volumeUpConsumer !== null) {
      return
    }
    const down = (event: InputConsumerKeyEvent): void => {
      if (event.action === Action.DOWN) {
        if (this.preferences.volumeKeyBehavior === 'up_previous_down_next') this.nextPage()
        else this.previousPage()
      }
    }
    const up = (event: InputConsumerKeyEvent): void => {
      if (event.action === Action.DOWN) {
        if (this.preferences.volumeKeyBehavior === 'up_next_down_previous') this.nextPage()
        else this.previousPage()
      }
    }
    this.volumeDownConsumer = down
    this.volumeUpConsumer = up
    try {
      inputConsumer.on('keyPressed', { key: KeyCode.KEYCODE_VOLUME_DOWN, action: Action.DOWN, isRepeat: false }, down)
      inputConsumer.on('keyPressed', { key: KeyCode.KEYCODE_VOLUME_UP, action: Action.DOWN, isRepeat: false }, up)
    } catch (_error) {
      this.unregisterVolumeKeyConsumer()
    }
  }

  private unregisterVolumeKeyConsumer(): void {
    try {
      if (this.volumeDownConsumer !== null) {
        inputConsumer.off('keyPressed', this.volumeDownConsumer)
      }
      if (this.volumeUpConsumer !== null) {
        inputConsumer.off('keyPressed', this.volumeUpConsumer)
      }
    } catch (_error) {
    }
    this.volumeDownConsumer = null
    this.volumeUpConsumer = null
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

  private tapZoneActionLabel(action: string): string {
    if (action === 'previous') return s('reader_tap_zone_action_previous')
    if (action === 'next') return s('reader_tap_zone_action_next')
    if (action === 'left') return s('reader_tap_zone_action_left')
    if (action === 'right') return s('reader_tap_zone_action_right')
    return s('reader_tap_zone_action_menu')
  }

  private tapZoneActionColor(action: string): string {
    if (action === 'previous') return '#884E78B8'
    if (action === 'next') return '#88588752'
    if (action === 'left') return '#88705A9F'
    if (action === 'right') return '#88876D45'
    return '#884A4A4A'
  }

  private pageIsZoomActive(index: number, continuous: boolean): boolean {
    if (continuous) {
      return this.verticalZoomedPage >= 0
        ? index === this.verticalZoomedPage
        : index >= this.verticalVisibleStart && index <= this.verticalVisibleEnd
    }
    if (this.effectiveMode() !== ReaderMode.DUAL_PAGE) {
      return index === this.pageIndex
    }
    const start = this.spreadIndexes()[this.spreadIndexForPage(this.pageIndex)]
    return index === start || index === this.spreadSecondIndex(start)
  }

  @Builder
  private ReaderPageSlot(index: number, splitSide: 'none' | 'left' | 'right', compact: boolean = false, continuous: boolean = false) {
    Stack({ alignContent: Alignment.Center }) {
      ReaderImageSurface({
        source: this.sourceFor(index),
        pageIndex: index,
        sourceWidth: this.pageWidth(index),
        sourceHeight: this.pageHeight(index),
        fit: imageFit(this.preferences.imageFitMode),
        // Paged readers must always show the complete page.  The natural-width
        // fit modes are only meaningful for the vertical reader, where the row
        // height is derived from the decoded aspect ratio.  Applying fit_width
        // to a paged surface makes a tall page extend beyond the viewport and
        // silently crops it before any zoom gesture is involved.
        fitMode: continuous ? this.preferences.imageFitMode : 'contain',
        scalingQuality: this.preferences.imageScalingQuality,
        splitSide: splitSide,
        rotateClockwise: this.preferences.wideImageMode === 'rotate_wide_pages' && isWidePage(this.pageWidth(index), this.pageHeight(index)),
        zoomEnabled: true,
        active: this.pageIsZoomActive(index, continuous),
        zoomResetToken: this.zoomResetToken,
        // The page surface owns its transform and animation. The reader only
        // receives a zoom gate so native List/Swiper movement is paused.
        // Keep single/double arbitration next to the image transform. In
        // ArkUI a transparent sibling tap layer stops receiving after a
        // zoomed PanGesture claims the stream; the image-local contract is
        // the same one NextE uses for its vertical reader and remains valid
        // for every pager surface.
        // Paged modes route taps through ReaderTapOverlay. The continuous
        // image row receives its own raw double-tap sequence because List
        // owns the recognizer stream on this runtime; it remains the sole
        // local zoom owner, exactly as NextE's vertical image does.
        allowDirectDoubleTap: continuous,
        routeTaps: continuous,
        tapOriginX: this.readerGlobalX,
        tapOriginY: this.readerGlobalY,
        externalDoubleTapSequence: this.readerDoubleTapSequence,
        externalDoubleTapTargetPage: this.readerDoubleTapTargetPage,
        externalDoubleTapX: this.readerDoubleTapX,
        externalDoubleTapY: this.readerDoubleTapY,
        renderTransformTargetPage: this.continuousRenderTargetPage,
        renderTransformScale: this.continuousRenderScale,
        renderTransformPanX: this.continuousRenderPanX,
        renderTransformPanY: this.continuousRenderPanY,
        retryToken: this.loadedRevision,
        onZoomChange: (zoomed: boolean) => {
          if (!continuous && this.pageIsZoomActive(index, false)) {
            this.zoomChanged(zoomed)
          } else if (continuous) {
            if (zoomed) {
              this.verticalZoomedPage = index
              this.zoomChanged(true)
            } else if (index === this.verticalZoomedPage || index === this.continuousRenderTargetPage) {
              this.verticalZoomedPage = -1
              this.continuousRenderTargetPage = -1
              this.continuousRenderScale = 1
              this.continuousRenderPanX = 0
              this.continuousRenderPanY = 0
              this.zoomChanged(false)
            }
          }
        },
        onTransformChange: (scale: number, panX: number, panY: number, zoomed: boolean) => {
          if (!continuous && this.pageIsZoomActive(index, false)) {
            this.transformChanged(scale, panX, panY, zoomed)
          } else if (continuous && zoomed && (index === this.verticalZoomedPage || this.verticalZoomedPage < 0)) {
            this.verticalZoomedPage = index
            this.continuousRenderTargetPage = index
            this.continuousRenderScale = scale
            this.continuousRenderPanX = panX
            this.continuousRenderPanY = panY
            this.transformChanged(scale, panX, panY, zoomed)
          }
        },
        onImageInfo: (page: number, width: number, height: number) => {
          if (page === index) {
            this.rememberImageInfo(page, width, height)
          }
        },
        onLoaded: (page: number) => { this.onImageLoaded(page) },
        onFailed: (page: number) => { this.onImageFailed(page) },
        onTap: (x: number, y: number) => { this.tapActionForSlot(x, y, splitSide, compact) },
        onTransformPreview: (page: number, scale: number, panX: number, panY: number) => {
          if (continuous) {
            this.continuousRenderTargetPage = page
            this.continuousRenderScale = scale
            this.continuousRenderPanX = panX
            this.continuousRenderPanY = panY
          }
        },
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
    .width(compact ? '50%' : '100%')
    .height(continuous ? this.continuousRowHeight(index) : '100%')
    .backgroundColor(readerBackground(this.preferences.backgroundMode))
  }

  @Builder
  private SinglePageReader() {
    Swiper(this.swiperController) {
      LazyForEach(this.pageIndexSource, (index: number) => {
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
    .vertical(this.effectiveMode() === ReaderMode.VERTICAL_PAGE)
    .loop(false)
    .cachedCount(this.pagerCachedPageCount())
    .indicator(false)
    .disableSwipe(this.zoomed)
    .width('100%').height('100%')
    .onChange((index: number) => {
      this.resetZoomState()
      this.emitPageIndex(index)
      this.persistProgress(index)
    })
  }

  @Builder
  private VerticalPageReader() {
    Swiper(this.swiperController) {
      LazyForEach(this.pageIndexSource, (index: number) => {
        Row({ space: pageGap(this.preferences.pageGapMode) }) {
          ForEach(this.displayEntries(index), (entry: ReaderDisplayEntry) => {
            this.ReaderPageSlot(entry.pageIndex, entry.splitSide)
          }, (entry: ReaderDisplayEntry) => `vertical-page-${entry.pageIndex}-${entry.splitSide}`)
        }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
      }, (index: number) => `reader-vertical-paged-${index}`)
    }
    .index(this.pageIndex)
    .direction(Direction.Ltr)
    .vertical(true)
    .loop(false)
    .cachedCount(this.pagerCachedPageCount())
    .indicator(false)
    .disableSwipe(this.zoomed)
    .width('100%').height('100%')
    .onChange((index: number) => {
      this.resetZoomState()
      this.emitPageIndex(Math.max(0, Math.min(index, Math.max(this.sessionConfig.totalPages - 1, 0))))
      this.persistProgress(index)
    })
  }

  @Builder
  private DoublePageReader() {
    Swiper(this.doublePageSwiperController) {
      LazyForEach(this.spreadStartSource, (start: number) => {
        Row({ space: this.preferences.spreadLayoutMode === 'split' ? pageGap(this.preferences.pageGapMode) : 0 }) {
          if (this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT) {
            // `splitSide` is an image-region decode instruction, not the
            // visual column of a spread. Passing left/right here cropped
            // every portrait page to half its source in double-page mode.
            // A regular spread must render each complete page; wide-page
            // splitting is a separate reader mode handled by displayEntries.
            if (this.hasSpreadSecond(start)) this.ReaderPageSlot(this.spreadSecondIndex(start), 'none', true)
            this.ReaderPageSlot(start, 'none', true)
          } else {
            this.ReaderPageSlot(start, 'none', true)
            if (this.hasSpreadSecond(start)) this.ReaderPageSlot(this.spreadSecondIndex(start), 'none', true)
          }
        }.width('100%').height('100%').justifyContent(FlexAlign.Center)
      }, (start: number) => `reader-spread-${start}`)
    }
    .index(this.spreadIndexForPage(this.pageIndex))
    .direction(this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? Direction.Rtl : Direction.Ltr)
    .vertical(false)
    .loop(false)
    .cachedCount(this.pagerCachedPageCount())
    .indicator(false)
    .disableSwipe(this.zoomed)
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
      LazyForEach(this.pageIndexSource, (index: number) => {
        ListItem() {
          this.ReaderPageSlot(index, 'none', false, true)
        }
        .width('100%')
        // List virtualizes from its ListItem geometry.  The vertical image's
        // decoded ratio therefore belongs on the item itself, not only on an
        // inner Stack; otherwise the List sees one viewport-sized row and has
        // no next natural-height segment to scroll into.
        .height(this.continuousRowHeight(index))
      }, (index: number) => `reader-vertical-page-${index}`)
    }
    .width('100%').height('100%').scrollBar(BarState.Off).cachedCount(this.pagerCachedPageCount())
    // Image dimensions are often absent from the source payload.  Keep the
    // List subscribed to the decoded-size revision so a row that initially
    // used the loading fallback is immediately remeasured after decode.
    .visibility(this.measuredPageRevision >= 0 ? Visibility.Visible : Visibility.None)
    .listDirection(Axis.Vertical)
    .enableScrollInteraction(!this.zoomed)
    .onScrollIndex((start: number, end: number) => {
      this.verticalVisibleStart = Math.max(0, start)
      this.verticalVisibleEnd = Math.max(this.verticalVisibleStart, end)
      if (this.continuousInitialTarget >= 0) {
        if (start !== this.continuousInitialTarget) {
          return
        }
        this.continuousInitialTarget = -1
      }
      if (start >= 0 && start < this.sessionConfig.totalPages && start !== this.pageIndex) {
        this.emitPageIndex(start)
        this.persistProgress(start)
      }
    })
  }

  @Builder
  private ReaderThumbnailStrip() {
    List({ initialIndex: this.pageIndex, scroller: this.thumbnailScroller, space: ThemeConstants.SPACE_SM }) {
      LazyForEach(this.pageIndexSource, (index: number) => {
        ListItem() {
          ReaderThumbnailTile({
            source: this.sourceFor(index),
            pageIndex: index,
            selected: index === this.pageIndex,
            onTap: (target: number) => {
              this.setPage(target, false)
              this.scrollThumbnailStripTo(target, true)
            },
          })
        }
        .margin({
          left: index === 0 ? ThemeConstants.SPACE_LG : 0,
          right: index === this.sessionConfig.totalPages - 1 ? ThemeConstants.SPACE_LG : 0,
        })
      }, (index: number) => `reader-thumb-${index}-${this.sourceFor(index).uri}`)
    }
    .listDirection(Axis.Horizontal)
    .direction(this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? Direction.Rtl : Direction.Ltr)
    .scrollBar(BarState.Off)
    .height(READER_THUMB_STRIP_HEIGHT)
    .width('100%')
  }

  @Builder
  private TapZonePreview() {
    Stack() {
      ForEach(readerTapZoneRegions(this.preferences.tapZonePreset, this.preferences.tapZoneInvert), (region: ReaderTapZoneRegion) => {
        Stack({ alignContent: Alignment.Center }) {
          Text(this.tapZoneActionLabel(region.action))
            .fontSize(13).fontWeight(FontWeight.Medium).fontColor(Color.White).textAlign(TextAlign.Center)
            .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD, top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
            .backgroundColor('#99000000').borderRadius(ThemeConstants.RADIUS_ROUND)
        }
          .position({ x: `${region.left * 100}%`, y: `${region.top * 100}%` })
          .width(`${(region.right - region.left) * 100}%`).height(`${(region.bottom - region.top) * 100}%`)
          .backgroundColor(this.tapZoneActionColor(region.action))
          .border({ width: 1, color: '#AAFFFFFF' })
      }, (region: ReaderTapZoneRegion) => `tap-zone-${region.action}-${region.left}-${region.top}-${region.right}-${region.bottom}`)
    }
    .width('100%').height('100%').hitTestBehavior(HitTestMode.Block).onClick(() => { this.tapPreviewVisible = false })
  }

  @Builder
  private PersistentPageNumber() {
    Text(`${this.pageIndex + 1} / ${Math.max(this.sessionConfig.totalPages, 0)}`)
      .fontSize(14).fontWeight(FontWeight.Medium).fontColor(readerForeground(this.preferences.backgroundMode))
      .width('100%').textAlign(TextAlign.Center).margin({ bottom: this.layout.bottomAvoidHeight + 8 }).hitTestBehavior(HitTestMode.None)
  }

  @Builder
  private ReaderContent() {
    if (this.sessionLoading) {
      this.ReaderSessionLoading()
    } else if (this.sessionConfig.totalPages <= 0) {
      Column({ space: ThemeConstants.SPACE_MD }) {
        Text(s('reader_empty_no_pages')).fontSize(16).fontColor(readerForeground(this.preferences.backgroundMode))
        Text(s('reader_source_page_unavailable')).fontSize(13).fontColor(ThemeConstants.READER_TEXT_SECONDARY).textAlign(TextAlign.Center)
      }.width('100%').height('100%').justifyContent(FlexAlign.Center).padding(ThemeConstants.SPACE_XL)
    } else if (this.effectiveMode() === ReaderMode.CONTINUOUS_SCROLL) {
      this.ContinuousReader()
    } else if (this.effectiveMode() === ReaderMode.DUAL_PAGE) {
      this.DoublePageReader()
    } else if (this.effectiveMode() === ReaderMode.VERTICAL_PAGE) {
      this.VerticalPageReader()
    } else {
      this.SinglePageReader()
    }
  }

  @Builder
  private ReaderChromeBar(placement: 'top' | 'bottom') {
    ReaderChrome({
      visible: true,
      placement: placement,
      viewportHeight: this.viewportHeight,
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
      autoPageActive: this.autoPageActive,
      canTurnOnePageInDoublePage: this.canTurnOnePageInDoublePage(),
      thumbStripVisible: this.thumbnailStripVisible,
      pageImageWidth: this.pageWidth(this.pageIndex) ?? 0,
      pageImageHeight: this.pageHeight(this.pageIndex) ?? 0,
      pageImageSourceLabel: this.pageImageSourceLabel(),
      thumbnailStrip: (): void => { this.ReaderThumbnailStrip() },
      onVisibleChange: (visible: boolean) => {
        this.chromeShown = visible
        if (this.routeVisible) {
          this.setReaderStatusBarForChrome(visible)
        }
        this.emitChromeVisible(visible)
      },
      onPageChange: (index: number) => { this.setPage(index, false) },
      onSeekPage: (index: number) => { this.setPage(index, false) },
      onPreviousChapter: () => { this.previousChapter() },
      onNextChapter: () => { this.nextChapter() },
      onOpenChapter: (index: number) => {
        if (index >= 0 && index < this.sessionConfig.chapterIds.length) this.onOpenChapter(this.sessionConfig.chapterIds[index])
      },
      onModeChange: (mode: ReaderMode) => { this.onModeChange(mode) },
      onPreferencesChange: (change: ReaderChromePreferencesChange) => { this.onPreferencesChanged(change) },
      onCloseReader: () => { this.closeReaderRoute() },
      onOpenMangaDetail: () => { this.onOpenMangaDetail() },
      onResetZoom: () => { this.resetZoomState() },
      onReloadPage: () => { this.retryCurrentPage() },
      onToggleAutoPage: () => { this.toggleAutoPage() },
      onTurnOnePageInDoublePage: () => { this.turnOnePageInDoublePage() },
      onToggleThumbStrip: () => { this.toggleThumbnailStrip() },
      onSaveImage: () => { void this.saveCurrentPageImage() },
      onShareImage: () => { void this.shareCurrentPageImage() },
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.readerOpen) {
        this.ReaderContent()
      } else {
        Blank().width('100%').height('100%')
      }
      if (this.readerOpen && this.sessionConfig.totalPages > 0 && this.effectiveMode() !== ReaderMode.CONTINUOUS_SCROLL) {
        this.ReaderTapOverlay()
      }
      if (this.readerOpen && this.sessionConfig.totalPages > 0 && !this.chromeShown && this.preferences.showPageNumber) this.PersistentPageNumber()
      if (this.readerOpen && this.tapPreviewVisible) this.TapZonePreview()
      if (this.readerOpen && this.chromeShown) {
        this.ReaderChromeBar('top')
        this.ReaderChromeBar('bottom')
      }
    }
    .width('100%').height('100%')
    .id('reader_key_surface')
    .backgroundColor(readerBackground(this.preferences.backgroundMode))
    .focusable(true).defaultFocus(true)
    .onAreaChange((_old: Area, next: Area) => {
      this.viewportWidth = next.width as number
      this.viewportHeight = next.height as number
      this.readerGlobalX = next.globalPosition.x as number
      this.readerGlobalY = next.globalPosition.y as number
    })
    .onKeyEvent((event: KeyEvent): boolean => this.handleKeyEvent(event))
  }
}

import { image } from '@kit.ImageKit'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { LengthMetrics, window } from '@kit.ArkUI'
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
import { CoverPixelMapLease, CoverPixelMapMemoryCache } from '../model/CoverPixelMapMemoryCache'
import { ReaderTapZoneRegion, readerTapZoneRegions, resolveReaderTapZoneAction } from '../model/ReaderTapZoneGeometry'
import { ReaderPageIndexDataSource } from '../model/ReaderPageIndexDataSource'
import {
  buildReaderDisplayPages,
  ReaderDisplayPage,
  ReaderDisplayPageDataSource,
  readerDisplayIndexForPage,
  ReaderSplitSide,
} from '../model/ReaderDisplayPageDataSource'
import { ThemeConstants } from '../theme/ThemeConstants'
import { AppStrings } from '../i18n/AppStrings'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { connectReaderModeState, ReaderModeState } from '../state/ReaderModeState'
import { AppForegroundState, connectAppForegroundState } from '../state/AppForegroundState'

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
const READER_THUMB_DISPLAY_HEIGHT: number = 118
const READER_THUMB_FALLBACK_ASPECT: number = 0.7
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
  @Param parentViewportWidth: number = 0
  @Param parentViewportHeight: number = 0
  @Param fit: ImageFit = ImageFit.Contain
  @Param fitMode: ReaderImageFitMode = 'contain'
  @Param scalingQuality: string = 'medium'
  @Param splitSide: 'none' | 'left' | 'right' = 'none'
  @Param rotateClockwise: boolean = false
  @Param zoomEnabled: boolean = true
  @Param gesturesEnabled: boolean = true
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
  @Param retryToken: number = 0
  @Param zoomResetToken: number = 0
  @Event onZoomChange: (zoomed: boolean) => void = (_zoomed: boolean) => {}
  @Event onImageInfo: (pageIndex: number, width: number, height: number) => void = (_pageIndex: number, _width: number, _height: number) => {}
  @Event onLoaded: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onFailed: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onTap: (x: number, y: number) => void = (_x: number, _y: number) => {}

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
  // One image-local transform is both the recognizer state and the rendered
  // state. ReaderPage owns only the surrounding pager/List zoom gate.
  @Local private zoomScale: number = 1
  @Local private offsetX: number = 0
  @Local private offsetY: number = 0
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
  private ignorePanSequence: boolean = false
  private pinchAdjustedSinceDoubleTap: boolean = false
  private zoomAnimatingTimerId: number = -1
  private intrinsicPixelWidth: number = 0
  private intrinsicPixelHeight: number = 0

  aboutToAppear(): void {
    this.disposed = false
    if (this.parentViewportWidth > 0 && this.parentViewportHeight > 0) {
      this.viewportWidth = this.parentViewportWidth
      this.viewportHeight = this.parentViewportHeight
    }
    this.resetZoom(false)
    void this.resolveSource()
  }

  @Monitor('parentViewportWidth', 'parentViewportHeight')
  private onParentViewportChange(): void {
    if (this.viewportWidth <= 0 && this.parentViewportWidth > 0) {
      this.viewportWidth = this.parentViewportWidth
    }
    if (this.viewportHeight <= 0 && this.parentViewportHeight > 0) {
      this.viewportHeight = this.parentViewportHeight
    }
  }

  aboutToDisappear(): void {
    this.disposed = true
    this.generation += 1
    this.displayUri = ''
    this.clearSingleTap()
    this.clearZoomAnimation()
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
    // local transform and is not part of NextE's vertical image contract.
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

  private publishImageInfo(widthValue?: number, heightValue?: number): void {
    let sourceWidth = this.sourceWidth ?? 0
    let sourceHeight = this.sourceHeight ?? 0
    if (sourceWidth <= 0 && widthValue !== undefined) {
      sourceWidth = widthValue
    }
    if (sourceHeight <= 0 && heightValue !== undefined) {
      sourceHeight = heightValue
    }
    if (sourceWidth > 0 && sourceHeight > 0) {
      const displayWidth = this.sourceRegionWidth(sourceWidth)
      this.intrinsicPixelWidth = displayWidth
      this.intrinsicPixelHeight = sourceHeight
      this.intrinsicWidth = this.toVp(displayWidth)
      this.intrinsicHeight = this.toVp(sourceHeight)
      // Display geometry may use one half, but the owning page model must
      // always retain the original decoded dimensions. Publishing a half
      // width here makes the page stop qualifying as wide on the next build.
      this.onImageInfo(this.pageIndex, sourceWidth, sourceHeight)
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
    if (this.viewportWidth <= 0) {
      return 0
    }
    const width = this.displaySourceWidth()
    return width > 0 ? width * this.baseScale() : this.viewportWidth
  }

  private displayHeight(): number {
    if (this.viewportHeight <= 0) {
      return 0
    }
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
    if (this.zoomScale > 1.01) {
      return 1
    }
    const longSide = Math.max(this.viewportWidth, this.viewportHeight)
    return longSide > 0 ? longSide * 2 : 10000
  }

  private doubleTapTarget(): number {
    const max = this.maxScale()
    if (this.pinchAdjustedSinceDoubleTap && this.zoomScale > 1.01) {
      return 1
    }
    const primary = this.clampScale(READER_DOUBLE_TAP_SCALE)
    const native = this.clampScale(this.nativeScale())
    if (this.zoomScale <= 1.01) {
      return primary
    }
    if (Math.abs(this.zoomScale - primary) <= 0.02 && native > 1.02) {
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

  private beginZoomAnimation(): void {
    this.clearZoomAnimation()
    this.zoomAnimating = true
    this.zoomAnimatingTimerId = setTimeout(() => {
      this.zoomAnimating = false
      this.zoomAnimatingTimerId = -1
    }, READER_ZOOM_ANIM_DURATION + 24)
  }

  private resetZoom(notify: boolean = true): void {
    this.zoomScale = 1
    this.offsetX = 0
    this.offsetY = 0
    this.pinchAdjustedSinceDoubleTap = false
    if (notify) {
      this.onZoomChange(false)
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
    this.pinchStart = this.zoomScale
    this.pinchAnchorX = centerX
    this.pinchAnchorY = centerY
    const displayW = this.displayWidth() * this.zoomScale
    const displayH = this.displayHeight() * this.zoomScale
    this.pinchAnchorX = displayW > 0 ? (this.pinchAnchorX - (this.viewportWidth - displayW) / 2 - this.offsetX) / displayW : 0.5
    this.pinchAnchorY = displayH > 0 ? (this.pinchAnchorY - (this.viewportHeight - displayH) / 2 - this.offsetY) / displayH : 0.5
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
    this.zoomScale = next
    this.offsetX = nextPanX
    this.offsetY = nextPanY
  }

  private finishPinch(): void {
    this.isPinching = false
    this.ignorePanSequence = false
    if (this.zoomScale <= 1.01) {
      this.beginZoomAnimation()
      this.resetZoom()
      return
    }
    this.zoomScale = this.clampScale(this.zoomScale)
    this.offsetX = this.clampOffset(this.offsetX, this.viewportWidth, this.displayWidth(), this.zoomScale)
    this.offsetY = this.clampOffset(this.offsetY, this.viewportHeight, this.displayHeight(), this.zoomScale)
    this.onZoomChange(true)
  }

  private handlePinchStart(event?: GestureEvent): void {
    if (event !== undefined) {
      this.beginPinchAt(event.pinchCenterX as number, event.pinchCenterY as number)
    }
  }

  private handlePinchUpdate(event?: GestureEvent): void {
    if (event !== undefined) {
      this.updatePinchAt(event.pinchCenterX as number, event.pinchCenterY as number, event.scale as number)
    }
  }

  private finishNativePinch(): void {
    this.finishPinch()
  }

  private handleDoubleTapAt(tapX: number, tapY: number): void {
    if (!this.zoomEnabled || (!this.active && !this.routeTaps)) return
    this.clearSingleTap()
    this.skipNextTapUp = false
    this.beginZoomAnimation()
    const target = this.doubleTapTarget()
    if (target <= 1.01) {
      this.resetZoom()
      return
    }
    const displayW = this.displayWidth() * this.zoomScale
    const displayH = this.displayHeight() * this.zoomScale
    const anchorX = displayW > 0 ? (tapX - (this.viewportWidth - displayW) / 2 - this.offsetX) / displayW : 0.5
    const anchorY = displayH > 0 ? (tapY - (this.viewportHeight - displayH) / 2 - this.offsetY) / displayH : 0.5
    const nextDisplayW = this.displayWidth() * target
    const nextDisplayH = this.displayHeight() * target
    this.zoomScale = target
    this.offsetX = this.clampOffset(tapX - (this.viewportWidth - nextDisplayW) / 2 - nextDisplayW * anchorX,
      this.viewportWidth, this.displayWidth(), target)
    this.offsetY = this.clampOffset(tapY - (this.viewportHeight - nextDisplayH) / 2 - nextDisplayH * anchorY,
      this.viewportHeight, this.displayHeight(), target)
    this.pinchAdjustedSinceDoubleTap = false
    this.onZoomChange(true)
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
      }
      this.tapStartX = touchX
      this.tapStartY = touchY
      this.tapCancelled = false
    } else if (event.type === TouchType.Move) {
      const dx = touchX - this.tapStartX
      const dy = touchY - this.tapStartY
      if (Math.sqrt(dx * dx + dy * dy) > READER_TAP_VERTICAL_TOLERANCE) {
        this.tapCancelled = true
        this.clearSingleTap()
      }
    } else if (event.type === TouchType.Up) {
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

  @Builder
  private ResolvedImage() {
    if (this.splitSide === 'none') {
      Image(this.displayUri)
        .width('100%')
        .height('100%')
        .objectFit(this.fit)
        .interpolation(imageInterpolation(this.scalingQuality))
        .rotate({ angle: this.rotateClockwise ? 90 : 0 })
        .scale({ x: this.zoomScale, y: this.zoomScale })
        .translate({ x: this.offsetX, y: this.offsetY })
        .animation({ duration: this.zoomAnimating ? READER_ZOOM_ANIM_DURATION : 0, curve: Curve.FastOutSlowIn })
        .onComplete((event?: ReaderImageLoadEvent) => { this.onDisplayComplete(event) })
        .onError(() => { this.onDisplayError() })
    } else {
      // Keep the native URI Image path instead of retaining a full-resolution
      // PixelMap for each half. The inner image is laid out at twice the
      // selected half's fitted width, shifted so the requested half is
      // centered, and clipped by a half-page viewport. Zoom/pan belongs to
      // that viewport, so each split display page has an independent canvas.
      Stack({ alignContent: Alignment.Center }) {
        Image(this.displayUri)
          .width(this.displayWidth() * 2)
          .height(this.displayHeight())
          .objectFit(ImageFit.Fill)
          .interpolation(imageInterpolation(this.scalingQuality))
          .translate({ x: this.splitSide === 'left' ? this.displayWidth() / 2 : -this.displayWidth() / 2 })
          .onComplete((event?: ReaderImageLoadEvent) => { this.onDisplayComplete(event) })
          .onError(() => { this.onDisplayError() })
      }
      .width(this.displayWidth())
      .height(this.displayHeight())
      .clip(true)
      .scale({ x: this.zoomScale, y: this.zoomScale })
      .translate({ x: this.offsetX, y: this.offsetY })
      .animation({ duration: this.zoomAnimating ? READER_ZOOM_ANIM_DURATION : 0, curve: Curve.FastOutSlowIn })
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.displayUri.length > 0) {
        this.ResolvedImage()
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
    .hitTestBehavior(this.gesturesEnabled ? HitTestMode.Default : HitTestMode.None)
    // Keep this declaration inline. `panDistance()` depends on local zoom
    // state; hiding the recognizer behind a factory freezes its construction
    // at the unzoomed threshold and makes post-zoom pan impossible.
    .gesture(
      GestureGroup(
        GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart((event?: GestureEvent) => { this.handlePinchStart(event) })
          .onActionUpdate((event?: GestureEvent) => { this.handlePinchUpdate(event) })
          .onActionEnd(() => { this.finishNativePinch() })
          .onActionCancel(() => { this.finishNativePinch() }),
        TapGesture({ count: 2, distanceThreshold: 8 }).onAction((event?: GestureEvent) => {
          if (!this.allowDirectDoubleTap) {
            return
          }
          const location = event?.tapLocation
          this.handleDoubleTapAt(location === undefined ? this.viewportWidth / 2 : location.x as number,
            location === undefined ? this.viewportHeight / 2 : location.y as number)
        }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: this.panDistance() })
          .onActionStart(() => {
            if (!this.active || this.zoomScale <= 1.01) return
            this.tapCancelled = true
            this.clearSingleTap()
            this.panStartX = this.offsetX
            this.panStartY = this.offsetY
          })
          .onActionUpdate((event?: GestureEvent) => {
            if (event === undefined || !this.active || this.ignorePanSequence || this.isPinching || this.zoomScale <= 1.01) return
            this.tapCancelled = true
            this.clearSingleTap()
            this.offsetX = this.clampOffset(this.panStartX + (event.offsetX as number), this.viewportWidth, this.displayWidth(), this.zoomScale)
            this.offsetY = this.clampOffset(this.panStartY + (event.offsetY as number), this.viewportHeight, this.displayHeight(), this.zoomScale)
          })
          .onActionEnd(() => {
            this.ignorePanSequence = false
          })
          .onActionCancel(() => {
            this.ignorePanSequence = false
          }),
      ),
    )
  }
}

/**
 * A double-page spread is one zoomable canvas. The two image layers only load
 * and paint their page; this component owns the sole transform and recognizer
 * state for the spread, matching NextE's ReaderSpreadSurface boundary.
 */
@ComponentV2
struct ReaderSpreadSurface {
  @Param firstSource: ReaderPageRenderSource = EMPTY_RENDER_SOURCE
  @Param secondSource: ReaderPageRenderSource = EMPTY_RENDER_SOURCE
  @Param firstIndex: number = 0
  @Param secondIndex: number = -1
  @Param firstWidth: number | undefined = undefined
  @Param firstHeight: number | undefined = undefined
  @Param secondWidth: number | undefined = undefined
  @Param secondHeight: number | undefined = undefined
  @Param firstRotateClockwise: boolean = false
  @Param secondRotateClockwise: boolean = false
  @Param hasSecond: boolean = false
  @Param rowReversed: boolean = false
  @Param joined: boolean = true
  @Param gap: number = 0
  @Param scalingQuality: string = 'medium'
  @Param parentViewportWidth: number = 0
  @Param parentViewportHeight: number = 0
  @Param active: boolean = true
  @Param doubleTapSequence: number = 0
  @Param doubleTapTargetPage: number = -1
  @Param doubleTapX: number = 0
  @Param doubleTapY: number = 0
  @Param retryToken: number = 0
  @Param zoomResetToken: number = 0
  @Event onZoomChange: (zoomed: boolean) => void = (_zoomed: boolean) => {}
  @Event onImageInfo: (pageIndex: number, width: number, height: number) => void =
    (_pageIndex: number, _width: number, _height: number) => {}
  @Event onLoaded: (pageIndex: number) => void = (_pageIndex: number) => {}
  @Event onFailed: (pageIndex: number) => void = (_pageIndex: number) => {}

  @Local private zoomScale: number = 1
  @Local private offsetX: number = 0
  @Local private offsetY: number = 0
  @Local private viewportWidth: number = 0
  @Local private viewportHeight: number = 0
  @Local private zoomAnimating: boolean = false
  private pinchStartScale: number = 1
  private pinchAnchorX: number = 0.5
  private pinchAnchorY: number = 0.5
  private panStartX: number = 0
  private panStartY: number = 0
  private isPinching: boolean = false
  private ignorePanSequence: boolean = false
  private pinchAdjustedSinceDoubleTap: boolean = false
  private zoomFocusPage: number = -1
  private lastZoomed: boolean = false
  private zoomAnimatingTimerId: number = -1

  aboutToAppear(): void {
    this.applyViewportFallback()
  }

  aboutToDisappear(): void {
    this.clearZoomAnimation()
  }

  @Monitor('parentViewportWidth', 'parentViewportHeight')
  private onParentViewportChanged(): void {
    this.applyViewportFallback()
  }

  @Monitor('active')
  private onActiveChanged(): void {
    if (!this.active) {
      this.resetZoom()
      this.notifyZoom()
    }
  }

  @Monitor('zoomResetToken')
  private onZoomResetRequested(): void {
    this.beginZoomAnimation()
    this.resetZoom()
    this.notifyZoom()
  }

  @Monitor('doubleTapSequence')
  private onDoubleTapCommand(): void {
    if (!this.active || this.doubleTapSequence <= 0 || !this.includesPage(this.doubleTapTargetPage)) {
      return
    }
    this.onDoubleTap(this.doubleTapX, this.doubleTapY)
  }

  private applyViewportFallback(): void {
    if (this.viewportWidth <= 0 && this.parentViewportWidth > 0) {
      this.viewportWidth = this.parentViewportWidth
    }
    if (this.viewportHeight <= 0 && this.parentViewportHeight > 0) {
      this.viewportHeight = this.parentViewportHeight
    }
  }

  private includesPage(page: number): boolean {
    return page === this.firstIndex || (this.hasSecond && page === this.secondIndex)
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

  private sourceWidthForPage(page: number): number {
    if (page === this.firstIndex) {
      const width = this.firstWidth ?? 0
      const height = this.firstHeight ?? 0
      return this.firstRotateClockwise ? this.toVp(height) : this.toVp(width)
    }
    const width = this.secondWidth ?? 0
    const height = this.secondHeight ?? 0
    return this.secondRotateClockwise ? this.toVp(height) : this.toVp(width)
  }

  private sourceHeightForPage(page: number): number {
    if (page === this.firstIndex) {
      const width = this.firstWidth ?? 0
      const height = this.firstHeight ?? 0
      return this.firstRotateClockwise ? this.toVp(width) : this.toVp(height)
    }
    const width = this.secondWidth ?? 0
    const height = this.secondHeight ?? 0
    return this.secondRotateClockwise ? this.toVp(width) : this.toVp(height)
  }

  private saneRatio(page: number): number {
    const width = this.sourceWidthForPage(page)
    const height = this.sourceHeightForPage(page)
    if (width > 0 && height > 0) {
      const ratio = width / height
      if (ratio > 0 && Number.isFinite(ratio)) {
        return ratio
      }
    }
    return 0.75
  }

  private usesJoinedLayout(): boolean {
    return this.joined && this.hasSecond
  }

  private paneWidth(): number {
    if (!this.hasSecond) {
      return this.viewportWidth
    }
    return Math.max(0, (this.viewportWidth - this.gap) / 2)
  }

  private joinedRatio(): number {
    return this.saneRatio(this.firstIndex) + this.saneRatio(this.secondIndex)
  }

  private joinedFrameHeight(): number {
    const ratio = this.joinedRatio()
    if (!this.usesJoinedLayout() || this.viewportWidth <= 0 || this.viewportHeight <= 0 || ratio <= 0) {
      return this.viewportHeight
    }
    return Math.min(this.viewportHeight, this.viewportWidth / ratio)
  }

  private joinedFrameWidth(): number {
    return this.usesJoinedLayout() ? this.joinedFrameHeight() * this.joinedRatio() : this.viewportWidth
  }

  private paneWidthForPage(page: number): number {
    return this.usesJoinedLayout() ? this.joinedFrameHeight() * this.saneRatio(page) : this.paneWidth()
  }

  private paneHeightForPage(_page: number): number {
    return this.usesJoinedLayout() ? this.joinedFrameHeight() : this.viewportHeight
  }

  private fitScale(viewportW: number, viewportH: number, page: number): number {
    const width = this.sourceWidthForPage(page)
    const height = this.sourceHeightForPage(page)
    if (viewportW <= 0 || viewportH <= 0 || width <= 0 || height <= 0) {
      return 1
    }
    return Math.min(viewportW / width, viewportH / height)
  }

  private displayWidthForPage(page: number): number {
    const width = this.sourceWidthForPage(page)
    return width > 0 ? width * this.fitScale(this.paneWidthForPage(page), this.paneHeightForPage(page), page) : this.paneWidthForPage(page)
  }

  private displayHeightForPage(page: number): number {
    const height = this.sourceHeightForPage(page)
    return height > 0 ? height * this.fitScale(this.paneWidthForPage(page), this.paneHeightForPage(page), page) : this.paneHeightForPage(page)
  }

  private displayWidth(): number {
    if (this.usesJoinedLayout()) {
      return this.joinedFrameWidth()
    }
    const first = this.displayWidthForPage(this.firstIndex)
    const second = this.hasSecond ? this.displayWidthForPage(this.secondIndex) : 0
    return Math.max(1, first + second + (this.hasSecond ? this.gap : 0))
  }

  private displayHeight(): number {
    if (this.usesJoinedLayout()) {
      return this.joinedFrameHeight()
    }
    const first = this.displayHeightForPage(this.firstIndex)
    const second = this.hasSecond ? this.displayHeightForPage(this.secondIndex) : 0
    return Math.max(1, Math.max(first, second))
  }

  private referenceDisplayWidthForPage(page: number): number {
    const width = this.sourceWidthForPage(page)
    return width > 0 ? width * this.fitScale(this.viewportWidth, this.viewportHeight, page) : this.viewportWidth
  }

  private referenceDisplayHeightForPage(page: number): number {
    const height = this.sourceHeightForPage(page)
    return height > 0 ? height * this.fitScale(this.viewportWidth, this.viewportHeight, page) : this.viewportHeight
  }

  private nativeScaleForPage(page: number): number {
    const width = this.sourceWidthForPage(page)
    const height = this.sourceHeightForPage(page)
    const displayW = this.referenceDisplayWidthForPage(page)
    const displayH = this.referenceDisplayHeightForPage(page)
    if (width <= 0 || height <= 0 || displayW <= 0 || displayH <= 0) {
      return READER_DOUBLE_TAP_SCALE
    }
    return Math.min(width / displayW, height / displayH)
  }

  private scaleForReference(target: number, page: number): number {
    const displayW = this.displayWidthForPage(page)
    const displayH = this.displayHeightForPage(page)
    const referenceW = this.referenceDisplayWidthForPage(page)
    const referenceH = this.referenceDisplayHeightForPage(page)
    if (displayW <= 0 || displayH <= 0 || referenceW <= 0 || referenceH <= 0) {
      return target
    }
    return Math.min(referenceW * target / displayW, referenceH * target / displayH)
  }

  private maxScaleForPage(page: number): number {
    const referenceMax = Math.max(READER_MIN_DYNAMIC_MAX_SCALE,
      Math.min(READER_MAX_DYNAMIC_MAX_SCALE, this.nativeScaleForPage(page) * 2))
    return Math.max(READER_MIN_DYNAMIC_MAX_SCALE,
      Math.min(READER_MAX_EFFECTIVE_ZOOM_SCALE, this.scaleForReference(referenceMax, page)))
  }

  private activeMaxScale(): number {
    const page = this.includesPage(this.zoomFocusPage) ? this.zoomFocusPage : this.firstIndex
    return this.maxScaleForPage(page)
  }

  private clampScale(value: number, max: number = this.activeMaxScale()): number {
    if (!Number.isFinite(value)) {
      return 1
    }
    return Math.min(Math.max(value, 1), max)
  }

  private clampPinchScale(value: number, max: number): number {
    if (!Number.isFinite(value)) {
      return 1
    }
    if (value >= 1) {
      return this.clampScale(value, max)
    }
    return Math.max(READER_PINCH_ELASTIC_MIN_SCALE, 1 - (1 - value) * READER_PINCH_UNDER_SCALE_RESISTANCE)
  }

  private clampOffset(value: number, viewport: number, display: number, scale: number): number {
    const bound = Math.max(0, (display * scale - viewport) / 2)
    return Math.min(Math.max(value, -bound), bound)
  }

  private clampOffsets(): void {
    this.zoomScale = this.clampScale(this.zoomScale)
    this.offsetX = this.clampOffset(this.offsetX, this.viewportWidth, this.displayWidth(), this.zoomScale)
    this.offsetY = this.clampOffset(this.offsetY, this.viewportHeight, this.displayHeight(), this.zoomScale)
  }

  private panDistance(): number {
    if (this.zoomScale > 1.01) {
      return 1
    }
    const longSide = Math.max(this.viewportWidth, this.viewportHeight)
    return longSide > 0 ? longSide * 2 : 10000
  }

  private pageForPoint(x: number): number {
    if (!this.hasSecond) {
      return this.firstIndex
    }
    let left = x < this.viewportWidth / 2
    if (this.usesJoinedLayout()) {
      const leftPage = this.rowReversed ? this.secondIndex : this.firstIndex
      const boundary = (this.viewportWidth - this.joinedFrameWidth()) / 2 + this.paneWidthForPage(leftPage)
      left = x < boundary
    }
    if (this.rowReversed) {
      return left ? this.secondIndex : this.firstIndex
    }
    return left ? this.firstIndex : this.secondIndex
  }

  private clearZoomAnimation(): void {
    if (this.zoomAnimatingTimerId >= 0) {
      clearTimeout(this.zoomAnimatingTimerId)
      this.zoomAnimatingTimerId = -1
    }
  }

  private beginZoomAnimation(): void {
    this.clearZoomAnimation()
    this.zoomAnimating = true
    this.zoomAnimatingTimerId = setTimeout(() => {
      this.zoomAnimating = false
      this.zoomAnimatingTimerId = -1
    }, READER_ZOOM_ANIM_DURATION + 24)
  }

  private resetZoom(): void {
    this.zoomScale = 1
    this.offsetX = 0
    this.offsetY = 0
    this.pinchAdjustedSinceDoubleTap = false
    this.zoomFocusPage = -1
  }

  private notifyZoom(): void {
    const zoomed = this.zoomScale > 1.01
    if (zoomed !== this.lastZoomed) {
      this.lastZoomed = zoomed
      this.onZoomChange(zoomed)
    }
  }

  private doubleTapTarget(page: number): number {
    if (this.pinchAdjustedSinceDoubleTap && this.zoomScale > 1.01) {
      return 1
    }
    const max = this.maxScaleForPage(page)
    const primary = this.clampScale(this.scaleForReference(READER_DOUBLE_TAP_SCALE, page), max)
    const native = this.clampScale(this.scaleForReference(this.nativeScaleForPage(page), page), max)
    if (this.zoomScale <= 1.01) {
      return primary
    }
    if (Math.abs(this.zoomScale - primary) <= 0.02 && native > 1.02) {
      return native
    }
    return 1
  }

  private onDoubleTap(x: number, y: number): void {
    this.beginZoomAnimation()
    const page = this.pageForPoint(x)
    this.zoomFocusPage = page
    const target = this.doubleTapTarget(page)
    this.pinchAdjustedSinceDoubleTap = false
    if (target <= 1.01) {
      this.resetZoom()
      this.notifyZoom()
      return
    }
    const anchorX = this.displayWidth() > 0
      ? (x - (this.viewportWidth - this.displayWidth() * this.zoomScale) / 2 - this.offsetX) /
        (this.displayWidth() * this.zoomScale)
      : 0.5
    const anchorY = this.displayHeight() > 0
      ? (y - (this.viewportHeight - this.displayHeight() * this.zoomScale) / 2 - this.offsetY) /
        (this.displayHeight() * this.zoomScale)
      : 0.5
    this.zoomScale = target
    this.offsetX = this.clampOffset(
      x - (this.viewportWidth - this.displayWidth() * target) / 2 - this.displayWidth() * target * anchorX,
      this.viewportWidth,
      this.displayWidth(),
      target,
    )
    this.offsetY = this.clampOffset(
      y - (this.viewportHeight - this.displayHeight() * target) / 2 - this.displayHeight() * target * anchorY,
      this.viewportHeight,
      this.displayHeight(),
      target,
    )
    this.notifyZoom()
  }

  @Builder
  private ImageLayer(source: ReaderPageRenderSource, index: number, width: number | undefined,
    height: number | undefined, rotateClockwise: boolean) {
    ReaderImageSurface({
      source: source,
      pageIndex: index,
      sourceWidth: width,
      sourceHeight: height,
      parentViewportWidth: this.paneWidthForPage(index),
      parentViewportHeight: this.paneHeightForPage(index),
      fit: ImageFit.Contain,
      fitMode: 'contain',
      scalingQuality: this.scalingQuality,
      rotateClockwise: rotateClockwise,
      zoomEnabled: false,
      gesturesEnabled: false,
      active: false,
      allowDirectDoubleTap: false,
      routeTaps: false,
      retryToken: this.retryToken,
      onImageInfo: (pageIndex: number, imageWidth: number, imageHeight: number) => {
        this.onImageInfo(pageIndex, imageWidth, imageHeight)
      },
      onLoaded: (pageIndex: number) => { this.onLoaded(pageIndex) },
      onFailed: (pageIndex: number) => { this.onFailed(pageIndex) },
    })
  }

  @Builder
  private WeightedImageLayer(source: ReaderPageRenderSource, index: number, width: number | undefined,
    height: number | undefined, rotateClockwise: boolean) {
    Column() {
      this.ImageLayer(source, index, width, height, rotateClockwise)
    }
    .layoutWeight(1)
    .height('100%')
  }

  @Builder
  private JoinedImageLayer(source: ReaderPageRenderSource, index: number, width: number | undefined,
    height: number | undefined, rotateClockwise: boolean) {
    Column() {
      this.ImageLayer(source, index, width, height, rotateClockwise)
    }
    .width(this.paneWidthForPage(index))
    .height(this.joinedFrameHeight())
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.usesJoinedLayout()) {
        Row() {
          if (this.rowReversed) {
            this.JoinedImageLayer(this.secondSource, this.secondIndex, this.secondWidth, this.secondHeight, this.secondRotateClockwise)
            this.JoinedImageLayer(this.firstSource, this.firstIndex, this.firstWidth, this.firstHeight, this.firstRotateClockwise)
          } else {
            this.JoinedImageLayer(this.firstSource, this.firstIndex, this.firstWidth, this.firstHeight, this.firstRotateClockwise)
            this.JoinedImageLayer(this.secondSource, this.secondIndex, this.secondWidth, this.secondHeight, this.secondRotateClockwise)
          }
        }
        .width(this.joinedFrameWidth())
        .height(this.joinedFrameHeight())
        .scale({ x: this.zoomScale, y: this.zoomScale })
        .translate({ x: this.offsetX, y: this.offsetY })
        .animation({ duration: this.zoomAnimating ? READER_ZOOM_ANIM_DURATION : 0, curve: Curve.FastOutSlowIn })
      } else {
        Row({ space: this.hasSecond ? this.gap : 0 }) {
          if (!this.hasSecond) {
            this.WeightedImageLayer(this.firstSource, this.firstIndex, this.firstWidth, this.firstHeight, this.firstRotateClockwise)
          } else if (this.rowReversed) {
            this.WeightedImageLayer(this.secondSource, this.secondIndex, this.secondWidth, this.secondHeight, this.secondRotateClockwise)
            this.WeightedImageLayer(this.firstSource, this.firstIndex, this.firstWidth, this.firstHeight, this.firstRotateClockwise)
          } else {
            this.WeightedImageLayer(this.firstSource, this.firstIndex, this.firstWidth, this.firstHeight, this.firstRotateClockwise)
            this.WeightedImageLayer(this.secondSource, this.secondIndex, this.secondWidth, this.secondHeight, this.secondRotateClockwise)
          }
        }
        .width('100%')
        .height('100%')
        .scale({ x: this.zoomScale, y: this.zoomScale })
        .translate({ x: this.offsetX, y: this.offsetY })
        .animation({ duration: this.zoomAnimating ? READER_ZOOM_ANIM_DURATION : 0, curve: Curve.FastOutSlowIn })
      }
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .onAreaChange((_old: Area, next: Area) => {
      this.viewportWidth = next.width as number
      this.viewportHeight = next.height as number
      this.clampOffsets()
    })
    // As with the single-page surface, keep zoom-dependent recognizer
    // options in the component declaration so ArkUI rebuilds the pan
    // threshold when the spread enters or leaves zoom.
    .gesture(
      GestureGroup(
        GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart((event?: GestureEvent) => {
            if (event === undefined || !this.active) {
              return
            }
            this.isPinching = true
            this.ignorePanSequence = true
            this.zoomAnimating = false
            this.zoomFocusPage = this.pageForPoint(event.pinchCenterX as number)
            this.pinchStartScale = this.zoomScale
            this.pinchAnchorX = this.displayWidth() > 0
              ? ((event.pinchCenterX as number) - (this.viewportWidth - this.displayWidth() * this.zoomScale) / 2 - this.offsetX) /
                (this.displayWidth() * this.zoomScale)
              : 0.5
            this.pinchAnchorY = this.displayHeight() > 0
              ? ((event.pinchCenterY as number) - (this.viewportHeight - this.displayHeight() * this.zoomScale) / 2 - this.offsetY) /
                (this.displayHeight() * this.zoomScale)
              : 0.5
          })
          .onActionUpdate((event?: GestureEvent) => {
            if (event === undefined || !this.active || !this.isPinching) {
              return
            }
            this.zoomFocusPage = this.pageForPoint(event.pinchCenterX as number)
            const next = this.clampPinchScale(this.pinchStartScale * (event.scale as number), this.maxScaleForPage(this.zoomFocusPage))
            this.pinchAdjustedSinceDoubleTap = true
            this.zoomScale = next
            this.offsetX = this.clampOffset(
              (event.pinchCenterX as number) - (this.viewportWidth - this.displayWidth() * next) / 2 -
                this.displayWidth() * next * this.pinchAnchorX,
              this.viewportWidth,
              this.displayWidth(),
              next,
            )
            this.offsetY = this.clampOffset(
              (event.pinchCenterY as number) - (this.viewportHeight - this.displayHeight() * next) / 2 -
                this.displayHeight() * next * this.pinchAnchorY,
              this.viewportHeight,
              this.displayHeight(),
              next,
            )
          })
          .onActionEnd(() => {
            this.isPinching = false
            this.ignorePanSequence = false
            if (this.zoomScale <= 1.01) {
              this.beginZoomAnimation()
              this.resetZoom()
            } else {
              this.clampOffsets()
            }
            this.notifyZoom()
          })
          .onActionCancel(() => {
            this.isPinching = false
            this.ignorePanSequence = false
            this.clampOffsets()
            this.notifyZoom()
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: this.panDistance() })
          .onActionStart(() => {
            this.ignorePanSequence = this.isPinching
            this.panStartX = this.offsetX
            this.panStartY = this.offsetY
          })
          .onActionUpdate((event?: GestureEvent) => {
            if (event === undefined || !this.active || this.ignorePanSequence || this.isPinching || this.zoomScale <= 1.01) {
              return
            }
            this.offsetX = this.clampOffset(this.panStartX + (event.offsetX as number), this.viewportWidth, this.displayWidth(), this.zoomScale)
            this.offsetY = this.clampOffset(this.panStartY + (event.offsetY as number), this.viewportHeight, this.displayHeight(), this.zoomScale)
          })
          .onActionEnd(() => {
            this.ignorePanSequence = false
          })
          .onActionCancel(() => { this.ignorePanSequence = false }),
      ),
    )
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
  @Param sourceWidth: number = 0
  @Param sourceHeight: number = 0
  @Param thumbnailCache: CoverPixelMapMemoryCache = new CoverPixelMapMemoryCache()
  @Event onTap: (pageIndex: number) => void = (_pageIndex: number) => {}

  @Local private pixelMap: image.PixelMap | undefined = undefined
  @Local private loading: boolean = false
  @Local private failed: boolean = false
  private pixelMapLease: CoverPixelMapLease | undefined = undefined
  private disposed: boolean = false
  private generation: number = 0

  aboutToAppear(): void {
    this.disposed = false
    void this.resolveThumbnail()
  }

  aboutToDisappear(): void {
    this.disposed = true
    this.generation += 1
    void this.releaseThumbnailLease()
  }

  @Monitor('source')
  onSourceChanged(): void {
    void this.resolveThumbnail()
  }

  private thumbnailWidth(): number {
    const aspect = this.sourceWidth > 0 && this.sourceHeight > 0
      ? this.sourceWidth / this.sourceHeight
      : READER_THUMB_FALLBACK_ASPECT
    return Math.max(1, Math.round(READER_THUMB_DISPLAY_HEIGHT * aspect))
  }

  private thumbnailCacheKey(): string {
    return `${this.source.kind}:${this.source.sourceRuntimeId ?? ''}:${this.source.pageId ?? ''}:${this.source.imageUri}::reader_thumbnail_v1::${READER_THUMB_DECODE_MAX_EDGE}`
  }

  private async releaseThumbnailLease(): Promise<void> {
    const lease = this.pixelMapLease
    this.pixelMapLease = undefined
    this.pixelMap = undefined
    if (lease !== undefined) {
      await this.thumbnailCache.release(lease)
    }
  }

  private async loadThumbnailPixelMap(): Promise<image.PixelMap> {
    let imageSource: image.ImageSource | undefined = undefined
    try {
      const filePath = await fetchAndCacheReaderRemoteSource(this.source)
      imageSource = image.createImageSource(filePath)
      const info = await imageSource.getImageInfo()
      const sourceWidth = Math.max(1, info.size.width)
      const sourceHeight = Math.max(1, info.size.height)
      const scale = Math.min(1, READER_THUMB_DECODE_MAX_EDGE / Math.max(sourceWidth, sourceHeight))
      return await imageSource.createPixelMap({
        desiredSize: {
          width: Math.max(1, Math.round(sourceWidth * scale)),
          height: Math.max(1, Math.round(sourceHeight * scale)),
        },
      })
    } finally {
      if (imageSource !== undefined) {
        try {
          await imageSource.release()
        } catch (_error) {
        }
      }
    }
  }

  private async resolveThumbnail(): Promise<void> {
    this.generation += 1
    const run = this.generation
    this.failed = false
    const staleLease = this.pixelMapLease
    this.pixelMapLease = undefined
    this.pixelMap = undefined
    if (staleLease !== undefined) {
      await this.thumbnailCache.release(staleLease)
    }
    if (this.source.kind === ReaderPageRenderKind.URI_PLACEHOLDER || this.source.imageUri.length === 0) {
      this.loading = false
      this.failed = true
      return
    }
    const key = this.thumbnailCacheKey()
    const cachedLease = this.thumbnailCache.acquire(key)
    if (cachedLease !== undefined) {
      if (this.disposed || run !== this.generation) {
        await this.thumbnailCache.release(cachedLease)
        return
      }
      this.pixelMapLease = cachedLease
      this.pixelMap = cachedLease.pixelMap
      this.loading = false
      return
    }
    this.loading = true
    try {
      const lease = await this.thumbnailCache.acquireOrLoad(key, () => this.loadThumbnailPixelMap())
      if (this.disposed || run !== this.generation) {
        await this.thumbnailCache.release(lease)
        return
      }
      this.pixelMapLease = lease
      this.pixelMap = lease.pixelMap
      this.failed = false
    } catch (_error) {
      if (!this.disposed && run === this.generation) {
        this.failed = true
      }
    } finally {
      if (!this.disposed && run === this.generation) {
        this.loading = false
      }
    }
  }

  build() {
    Column({ space: ThemeConstants.SPACE_XS }) {
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
      }
      .width(this.thumbnailWidth())
      .height(READER_THUMB_DISPLAY_HEIGHT)
      .border({
        width: this.selected ? 2 : 0,
        color: this.selected ? ThemeConstants.BRAND_PRIMARY : Color.Transparent,
      })
      .borderRadius(ThemeConstants.RADIUS_SM)
      .backgroundColor('#33000000')
      .clip(true)

      Text(`${this.pageIndex + 1}`)
        .fontSize(ThemeConstants.FONT_SIZE_META)
        .fontColor(this.selected ? ThemeConstants.BRAND_PRIMARY : Color.White)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .height(18)
        .width(this.thumbnailWidth())
        .textAlign(TextAlign.Center)
    }
    .width(this.thumbnailWidth())
    .height(READER_THUMB_STRIP_HEIGHT)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.onTap(this.pageIndex) })
  }
}

@ComponentV2
struct ReaderPageNumberOverlay {
  @Require @Param value: string
  @Require @Param bottomMargin: number
  private controller: TextController = new TextController()

  @Monitor('value')
  onValueChanged(): void {
    this.updateStyledText()
  }

  private styledText(): MutableStyledString {
    const styled: MutableStyledString = new MutableStyledString(this.value, [])
    styled.setStyle({
      start: 0,
      length: this.value.length,
      styledKey: StyledStringKey.FONT,
      styledValue: new TextStyle({
        fontColor: ThemeConstants.READER_PAGE_NUMBER_TEXT,
        fontSize: LengthMetrics.vp(ThemeConstants.FONT_SIZE_BODY),
        fontWeight: FontWeight.Medium,
        strokeWidth: LengthMetrics.vp(-ThemeConstants.READER_PAGE_NUMBER_STROKE_WIDTH),
        strokeColor: ThemeConstants.READER_PAGE_NUMBER_OUTLINE,
      }),
    })
    return styled
  }

  private updateStyledText(): void {
    this.controller.setStyledString(this.styledText())
  }

  build() {
    Text(undefined, { controller: this.controller })
      .width('100%')
      .textAlign(TextAlign.Center)
      .maxLines(1)
      .margin({ bottom: this.bottomMargin })
      .hitTestBehavior(HitTestMode.None)
      .onAppear(() => {
        this.updateStyledText()
      })
  }
}

@ComponentV2
export struct ReaderPage {
  @Local private appForegroundState: AppForegroundState = connectAppForegroundState()
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
  @Local private activeDisplayIndex: number = 0
  @Local private activeSplitSide: ReaderSplitSide = 'none'
  @Local private readerGlobalX: number = 0
  @Local private readerGlobalY: number = 0
  @Local private readerDoubleTapSequence: number = 0
  @Local private readerDoubleTapTargetPage: number = -1
  @Local private readerDoubleTapX: number = 0
  @Local private readerDoubleTapY: number = 0
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
  // The strip is transient, but its decoded previews belong to the active
  // reader session. Hiding the strip releases each tile's lease without
  // discarding the bounded cache, so reopening it is an immediate cache hit.
  private thumbnailPixelMapCache: CoverPixelMapMemoryCache = new CoverPixelMapMemoryCache()
  /** Kept stable: LazyForEach, rather than the Reader build, owns long-page rows. */
  private pageIndexSource: ReaderPageIndexDataSource = new ReaderPageIndexDataSource()
  private displayPageSource: ReaderDisplayPageDataSource = new ReaderDisplayPageDataSource()
  private displayPages: ReaderDisplayPage[] = []
  private spreadStartSource: ReaderPageIndexDataSource = new ReaderPageIndexDataSource()
  private pageIndexSourceKey: string = ''
  private displayPageSourceKey: string = ''
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
    void this.thumbnailPixelMapCache.clear()
  }

  @Monitor('sessionConfig')
  onSessionChanged(): void {
    this.syncSession(true)
  }

  @Monitor('pageIndex')
  onParentPageChanged(): void {
    if (this.usesDisplayPagePager()) {
      const current = this.currentDisplayPage()
      if (current === undefined || current.pageIndex !== this.pageIndex) {
        const displayIndex = readerDisplayIndexForPage(this.displayPages, this.pageIndex)
        if (displayIndex >= 0) {
          this.setActiveDisplayIndex(displayIndex)
          this.swiperController.changeIndex(displayIndex, false)
        }
      }
    }
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
    if (this.isLastReadingUnitVisibleAndLoaded(this.pageIndex)) this.persistCurrentProgress()
  }

  @Monitor('appForegroundState.active', 'sessionLoading')
  private onReaderForegroundChanged(): void {
    if (this.isLastReadingUnitVisibleAndLoaded(this.pageIndex)) this.persistCurrentProgress()
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
      this.refreshPageDataSources()
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
      this.refreshPageDataSources()
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
      this.nextPage()
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
    if (signature !== this.sourceSignature) {
      void this.thumbnailPixelMapCache.clear()
    }
    this.sourceSignature = signature
    this.loadedRevision += 1
    this.failedPages = []
    this.loadedPageIndexes = []
    this.autoPageWaitingIndex = -1
    this.measuredPageWidths = []
    this.measuredPageHeights = []
    this.activeDisplayIndex = 0
    this.activeSplitSide = 'none'
    this.displayPageSourceKey = ''
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

  private usesDisplayPagePager(): boolean {
    const mode = this.effectiveMode()
    return mode === ReaderMode.SINGLE_PAGE || mode === ReaderMode.VERTICAL_PAGE
  }

  private widePageIndexes(): number[] {
    const indexes: number[] = []
    for (let index = 0; index < this.sessionConfig.totalPages; index += 1) {
      if (isWidePage(this.pageWidth(index), this.pageHeight(index))) {
        indexes.push(index)
      }
    }
    return indexes
  }

  private refreshPageDataSources(force: boolean = false): void {
    const pageKey = this.sessionSignature()
    if (force || pageKey !== this.pageIndexSourceKey) {
      this.pageIndexSourceKey = pageKey
      this.pageIndexSource.setIndexes(this.pageIndexes())
    }
    const wideIndexes = this.widePageIndexes()
    const splitWidePages = this.preferences.wideImageMode === 'split_wide_pages' && this.usesDisplayPagePager()
    const displayKey = `${pageKey}:${this.effectiveMode()}:${this.preferences.wideImageMode}:${this.preferences.readingDirection}:${wideIndexes.join(',')}`
    if (force || displayKey !== this.displayPageSourceKey) {
      const total = this.sessionConfig.totalPages
      const sourcePage = total <= 0 ? 0 : Math.max(0, Math.min(this.pageIndex, total - 1))
      const preferredSide = this.activeSplitSide
      const pages = buildReaderDisplayPages(
        total,
        wideIndexes,
        splitWidePages,
        this.preferences.readingDirection,
      )
      this.displayPageSourceKey = displayKey
      this.displayPages = pages
      this.displayPageSource.setPages(pages)
      const displayIndex = readerDisplayIndexForPage(pages, sourcePage, preferredSide)
      this.activeDisplayIndex = Math.max(0, displayIndex)
      const activePage = this.currentDisplayPage()
      this.activeSplitSide = activePage?.splitSide ?? 'none'
      if (this.routeVisible && this.usesDisplayPagePager() && pages.length > 0) {
        const expectedKey = displayKey
        setTimeout(() => {
          if (this.displayPageSourceKey === expectedKey && this.usesDisplayPagePager()) {
            this.swiperController.changeIndex(this.activeDisplayIndex, false)
          }
        }, 0)
      }
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
    this.refreshPageDataSources()
  }

  private currentDisplayPage(): ReaderDisplayPage | undefined {
    if (this.activeDisplayIndex < 0 || this.activeDisplayIndex >= this.displayPages.length) {
      return undefined
    }
    return this.displayPages[this.activeDisplayIndex]
  }

  private setActiveDisplayIndex(index: number): ReaderDisplayPage | undefined {
    if (this.displayPages.length <= 0) {
      this.activeDisplayIndex = 0
      this.activeSplitSide = 'none'
      return undefined
    }
    const target = Math.max(0, Math.min(index, this.displayPages.length - 1))
    const page = this.displayPages[target]
    this.activeDisplayIndex = target
    this.activeSplitSide = page.splitSide
    return page
  }

  private setDisplayPage(index: number, animated: boolean = this.preferences.pageTurnAnimation): void {
    const previousDisplayIndex = this.activeDisplayIndex
    const page = this.setActiveDisplayIndex(index)
    if (page === undefined || (previousDisplayIndex === this.activeDisplayIndex && page.pageIndex === this.pageIndex)) {
      return
    }
    this.resetZoomState()
    if (page.pageIndex !== this.pageIndex) {
      this.emitPageIndex(page.pageIndex)
    }
    this.swiperController.changeIndex(this.activeDisplayIndex, animated)
    this.persistProgress(page.pageIndex)
  }

  private onDisplayPageChanged(index: number): void {
    this.resetZoomState()
    const page = this.setActiveDisplayIndex(index)
    if (page === undefined) {
      return
    }
    if (page.pageIndex !== this.pageIndex) {
      this.emitPageIndex(page.pageIndex)
    }
    this.persistProgress(page.pageIndex)
  }

  private canPrevious(): boolean {
    if (this.usesDisplayPagePager()) {
      return this.activeDisplayIndex > 0
    }
    if (this.effectiveMode() === ReaderMode.DUAL_PAGE) {
      return this.spreadIndexForPage(this.pageIndex) > 0
    }
    return this.pageIndex > 0
  }

  private canNext(): boolean {
    if (this.usesDisplayPagePager()) {
      return this.activeDisplayIndex + 1 < this.displayPages.length
    }
    if (this.effectiveMode() === ReaderMode.DUAL_PAGE) {
      return this.spreadIndexForPage(this.pageIndex) + 1 < this.spreadIndexes().length
    }
    return this.pageIndex + 1 < this.sessionConfig.totalPages
  }
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
    if (this.usesDisplayPagePager()) {
      const displayIndex = readerDisplayIndexForPage(this.displayPages, target)
      if (displayIndex >= 0) {
        this.setDisplayPage(displayIndex, animated)
      }
      return
    }
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

  private nextPage(): void {
    if (this.usesDisplayPagePager()) {
      this.setDisplayPage(this.activeDisplayIndex + 1)
      return
    }
    if (this.effectiveMode() === ReaderMode.DUAL_PAGE) {
      const starts = this.spreadIndexes()
      const nextSpread = this.spreadIndexForPage(this.pageIndex) + 1
      if (nextSpread >= 0 && nextSpread < starts.length) {
        this.setPage(starts[nextSpread])
      }
      return
    }
    this.setPage(this.pageIndex + 1)
  }

  private previousPage(): void {
    if (this.usesDisplayPagePager()) {
      this.setDisplayPage(this.activeDisplayIndex - 1)
      return
    }
    if (this.effectiveMode() === ReaderMode.DUAL_PAGE) {
      const starts = this.spreadIndexes()
      const previousSpread = this.spreadIndexForPage(this.pageIndex) - 1
      if (previousSpread >= 0 && previousSpread < starts.length) {
        this.setPage(starts[previousSpread])
      }
      return
    }
    this.setPage(this.pageIndex - 1)
  }

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
    this.refreshPageDataSources()
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
    this.verticalZoomedPage = -1
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

  private isLastReadingUnitVisibleAndLoaded(index: number): boolean {
    const last = this.sessionConfig.totalPages - 1
    if (!this.readerOpen || !this.routeVisible || !this.appForegroundState.active ||
      this.sessionLoading || this.closing || last < 0 ||
      !this.loadedPageIndexes.includes(last) || this.failedPages.includes(last)) return false
    if (this.usesDisplayPagePager()) {
      const current = this.currentDisplayPage()
      return current !== undefined && current.pageIndex === index && current.pageIndex === last &&
        this.activeDisplayIndex === this.displayPages.length - 1
    }
    if (this.effectiveMode() === ReaderMode.DUAL_PAGE) {
      const starts = this.spreadIndexes()
      const spread = this.spreadIndexForPage(index)
      const start = starts[spread]
      return start !== undefined && (start === last || this.spreadSecondIndex(start) === last)
    }
    return this.continuousInitialTarget < 0 && this.verticalVisibleStart >= 0 &&
      this.verticalVisibleStart <= last && this.verticalVisibleEnd >= last
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
      completed: this.isLastReadingUnitVisibleAndLoaded(index),
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
    if (this.isLastReadingUnitVisibleAndLoaded(this.pageIndex)) this.persistCurrentProgress()
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
    this.zoomScale = zoomed ? READER_DOUBLE_TAP_SCALE : 1
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

  private tapActionForSlot(x: number, y: number, _splitSide: ReaderSplitSide, _compact: boolean): void {
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
    if (this.routeVisible) {
      this.setReaderStatusBarForChrome(nextVisible)
    }
    this.getUIContext().animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => {
      this.chromeShown = nextVisible
    })
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
    const ids = this.continuationChapterIds()
    const index = ids.indexOf(this.sessionConfig.chapterId)
    if (index > 0) this.onOpenChapter(ids[index - 1])
  }

  private nextChapter(): void {
    const ids = this.continuationChapterIds()
    const index = ids.indexOf(this.sessionConfig.chapterId)
    if (index >= 0 && index + 1 < ids.length) this.onOpenChapter(ids[index + 1])
  }

  private continuationChapterIds(): string[] {
    return this.sessionConfig.continuationChapterIds ?? this.sessionConfig.chapterIds
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

  private pageIsZoomActive(index: number, continuous: boolean, splitSide: ReaderSplitSide = 'none'): boolean {
    if (continuous) {
      return this.verticalZoomedPage >= 0
        ? index === this.verticalZoomedPage
        : index >= this.verticalVisibleStart && index <= this.verticalVisibleEnd
    }
    if (this.effectiveMode() !== ReaderMode.DUAL_PAGE) {
      return index === this.pageIndex && (splitSide === 'none' || splitSide === this.activeSplitSide)
    }
    const start = this.spreadIndexes()[this.spreadIndexForPage(this.pageIndex)]
    return index === start || index === this.spreadSecondIndex(start)
  }

  @Builder
  private ReaderPageSlot(index: number, splitSide: ReaderSplitSide, compact: boolean = false, continuous: boolean = false) {
    Stack({ alignContent: Alignment.Center }) {
      ReaderImageSurface({
        source: this.sourceFor(index),
        pageIndex: index,
        parentViewportWidth: this.viewportWidth,
        parentViewportHeight: this.viewportHeight,
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
        active: this.pageIsZoomActive(index, continuous, splitSide),
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
        retryToken: this.loadedRevision,
        onZoomChange: (zoomed: boolean) => {
          if (!continuous && this.pageIsZoomActive(index, false, splitSide)) {
            this.zoomChanged(zoomed)
          } else if (continuous) {
            if (zoomed) {
              this.verticalZoomedPage = index
              this.zoomChanged(true)
            } else if (index === this.verticalZoomedPage) {
              this.verticalZoomedPage = -1
              this.zoomChanged(false)
            }
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
      LazyForEach(this.displayPageSource, (page: ReaderDisplayPage) => {
        this.ReaderPageSlot(page.pageIndex, page.splitSide)
      }, (page: ReaderDisplayPage) => `reader-page-${page.pageIndex}-${page.splitSide}`)
    }
    .index(this.activeDisplayIndex)
    .direction(this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? Direction.Rtl : Direction.Ltr)
    .vertical(this.effectiveMode() === ReaderMode.VERTICAL_PAGE)
    .loop(false)
    .cachedCount(this.pagerCachedPageCount())
    .indicator(false)
    .disableSwipe(this.zoomed)
    .width('100%').height('100%')
    .onChange((index: number) => {
      this.onDisplayPageChanged(index)
    })
  }

  @Builder
  private VerticalPageReader() {
    Swiper(this.swiperController) {
      LazyForEach(this.displayPageSource, (page: ReaderDisplayPage) => {
        this.ReaderPageSlot(page.pageIndex, page.splitSide)
      }, (page: ReaderDisplayPage) => `reader-vertical-paged-${page.pageIndex}-${page.splitSide}`)
    }
    .index(this.activeDisplayIndex)
    .direction(Direction.Ltr)
    .vertical(true)
    .loop(false)
    .cachedCount(this.pagerCachedPageCount())
    .indicator(false)
    .disableSwipe(this.zoomed)
    .width('100%').height('100%')
    .onChange((index: number) => {
      this.onDisplayPageChanged(index)
    })
  }

  @Builder
  private DoublePageReader() {
    Swiper(this.doublePageSwiperController) {
      LazyForEach(this.spreadStartSource, (start: number) => {
        ReaderSpreadSurface({
          firstSource: this.sourceFor(start),
          secondSource: this.hasSpreadSecond(start) ? this.sourceFor(this.spreadSecondIndex(start)) : EMPTY_RENDER_SOURCE,
          firstIndex: start,
          secondIndex: this.hasSpreadSecond(start) ? this.spreadSecondIndex(start) : -1,
          firstWidth: this.pageWidth(start),
          firstHeight: this.pageHeight(start),
          secondWidth: this.hasSpreadSecond(start) ? this.pageWidth(this.spreadSecondIndex(start)) : undefined,
          secondHeight: this.hasSpreadSecond(start) ? this.pageHeight(this.spreadSecondIndex(start)) : undefined,
          firstRotateClockwise: this.preferences.wideImageMode === 'rotate_wide_pages' &&
            isWidePage(this.pageWidth(start), this.pageHeight(start)),
          secondRotateClockwise: this.hasSpreadSecond(start) &&
            this.preferences.wideImageMode === 'rotate_wide_pages' &&
            isWidePage(this.pageWidth(this.spreadSecondIndex(start)), this.pageHeight(this.spreadSecondIndex(start))),
          hasSecond: this.hasSpreadSecond(start),
          rowReversed: this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT,
          joined: this.preferences.spreadLayoutMode !== 'split',
          gap: this.preferences.spreadLayoutMode === 'split' ? pageGap(this.preferences.pageGapMode) : 0,
          scalingQuality: this.preferences.imageScalingQuality,
          parentViewportWidth: this.viewportWidth,
          parentViewportHeight: this.viewportHeight,
          active: this.pageIsZoomActive(start, false),
          doubleTapSequence: this.readerDoubleTapSequence,
          doubleTapTargetPage: this.readerDoubleTapTargetPage,
          doubleTapX: this.readerDoubleTapX,
          doubleTapY: this.readerDoubleTapY,
          retryToken: this.loadedRevision,
          zoomResetToken: this.zoomResetToken,
          onZoomChange: (zoomed: boolean) => {
            if (this.pageIsZoomActive(start, false)) {
              this.zoomChanged(zoomed)
            }
          },
          onImageInfo: (page: number, width: number, height: number) => {
            this.rememberImageInfo(page, width, height)
          },
          onLoaded: (page: number) => { this.onImageLoaded(page) },
          onFailed: (page: number) => { this.onImageFailed(page) },
        })
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
      const endChanged = this.verticalVisibleEnd !== Math.max(start, end)
      this.verticalVisibleStart = Math.max(0, start)
      this.verticalVisibleEnd = Math.max(this.verticalVisibleStart, end)
      if (this.continuousInitialTarget >= 0) {
        const targetVisibleAtEnd = end === this.sessionConfig.totalPages - 1 &&
          start <= this.continuousInitialTarget && end >= this.continuousInitialTarget
        if (start !== this.continuousInitialTarget && !targetVisibleAtEnd) {
          return
        }
        this.continuousInitialTarget = -1
      }
      if (start >= 0 && start < this.sessionConfig.totalPages && (start !== this.pageIndex || endChanged)) {
        if (start !== this.pageIndex) this.emitPageIndex(start)
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
            sourceWidth: this.pageWidth(index) ?? 0,
            sourceHeight: this.pageHeight(index) ?? 0,
            thumbnailCache: this.thumbnailPixelMapCache,
            onTap: (target: number) => {
              this.setPage(target, false)
              this.scrollThumbnailStripTo(target, true)
            },
          })
        }
      }, (index: number) => `reader-thumb-${index}-${this.sourceFor(index).uri}`)
    }
    .listDirection(Axis.Horizontal)
    .direction(this.preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? Direction.Rtl : Direction.Ltr)
    .scrollBar(BarState.Off)
    .padding({ left: ThemeConstants.SPACE_MD, right: ThemeConstants.SPACE_MD })
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
    ReaderPageNumberOverlay({
      value: `${this.pageIndex + 1} / ${Math.max(this.sessionConfig.totalPages, 0)}`,
      bottomMargin: this.layout.bottomAvoidHeight + 8,
    })
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
      canGoPreviousChapter: this.continuationChapterIds().indexOf(this.sessionConfig.chapterId) > 0,
      canGoNextChapter: this.continuationChapterIds().indexOf(this.sessionConfig.chapterId) >= 0 &&
        this.continuationChapterIds().indexOf(this.sessionConfig.chapterId) + 1 < this.continuationChapterIds().length,
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

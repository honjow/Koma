import { RouteName } from '../common/Constants'
import { MangaDetailRouteParam, RouterHelper } from '../common/RouterHelper'
import { MangaDetailTransitionCoverSource, sameTransitionCover } from '../state/MangaDetailTransitionCoverSource'
import { image } from '@kit.ImageKit'
import { FrameCallback, UIUtils, curves, display, window } from '@kit.ArkUI'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import {
  connectMangaDetailTransition,
  MANGA_DETAIL_SOURCE_SURFACE_SCALE,
  MangaDetailReturnLayout,
  MangaDetailTransitionPhase,
} from '../state/MangaDetailTransitionState'
import {
  connectAppearanceState,
  MangaDetailTransitionMode,
} from '../state/AppearanceState'
import { ThemeConstants } from '../theme/ThemeConstants'

const MANGA_DETAIL_TRANSITION_DURATION_MS: number = 350
// CURRENT_STATUS #359: the user chose the system standard curve after rejecting
// a front-loaded custom ease-out. Both directions start and settle at rest;
// use this same native curve for geometry and spatial fade-time inversion.
const MANGA_DETAIL_OPEN_CURVE: curves.ICurve = curves.initCurve(Curve.FastOutSlowIn)
const MANGA_DETAIL_CLOSE_CURVE: curves.ICurve = MANGA_DETAIL_OPEN_CURVE
// Crossfade thresholds describe spatial window progress, not elapsed time. Curve changes therefore
// keep the card/detail handoff at the same visible window size.
const MANGA_DETAIL_OPEN_CARD_EXIT_START_PROGRESS: number = 0
const MANGA_DETAIL_OPEN_CARD_EXIT_END_PROGRESS: number = 0.55
const MANGA_DETAIL_CLOSE_CARD_ENTRY_START_PROGRESS: number = 0.55
const MANGA_DETAIL_CLOSE_CARD_ENTRY_END_PROGRESS: number = 0.9
// The captured source card hands off as one rounded surface. These are spatial progress thresholds:
// curve changes cannot move its fade to a different expanded-card size.
const MANGA_DETAIL_COVER_OPEN_CARD_EXIT_START_PROGRESS: number = 0.15
const MANGA_DETAIL_COVER_OPEN_CARD_EXIT_END_PROGRESS: number = 0.5
const MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_START_PROGRESS: number = 0.5
const MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_END_PROGRESS: number = 0.75
const MANGA_DETAIL_CURVE_INVERSE_ITERATIONS: number = 16

function mangaDetailTimeAtProgress(curve: curves.ICurve, targetProgress: number): number {
  const boundedTarget: number = Math.max(0, Math.min(1, targetProgress))
  let lower: number = 0
  let upper: number = 1
  for (let index: number = 0; index < MANGA_DETAIL_CURVE_INVERSE_ITERATIONS; index += 1) {
    const candidate: number = (lower + upper) / 2
    if (curve.interpolate(candidate) < boundedTarget) {
      lower = candidate
    } else {
      upper = candidate
    }
  }
  return (lower + upper) / 2
}
const MANGA_DETAIL_OPEN_CARD_EXIT_START_TIME: number = mangaDetailTimeAtProgress(
  MANGA_DETAIL_OPEN_CURVE,
  MANGA_DETAIL_OPEN_CARD_EXIT_START_PROGRESS,
)
const MANGA_DETAIL_OPEN_CARD_EXIT_END_TIME: number = mangaDetailTimeAtProgress(
  MANGA_DETAIL_OPEN_CURVE,
  MANGA_DETAIL_OPEN_CARD_EXIT_END_PROGRESS,
)
const MANGA_DETAIL_COVER_OPEN_CARD_EXIT_START_TIME: number = mangaDetailTimeAtProgress(
  MANGA_DETAIL_OPEN_CURVE,
  MANGA_DETAIL_COVER_OPEN_CARD_EXIT_START_PROGRESS,
)
const MANGA_DETAIL_COVER_OPEN_CARD_EXIT_END_TIME: number = mangaDetailTimeAtProgress(
  MANGA_DETAIL_OPEN_CURVE,
  MANGA_DETAIL_COVER_OPEN_CARD_EXIT_END_PROGRESS,
)
const MANGA_DETAIL_CLOSE_CARD_ENTRY_START_TIME: number = mangaDetailTimeAtProgress(
  MANGA_DETAIL_CLOSE_CURVE,
  MANGA_DETAIL_CLOSE_CARD_ENTRY_START_PROGRESS,
)
const MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_START_TIME: number = mangaDetailTimeAtProgress(
  MANGA_DETAIL_CLOSE_CURVE,
  MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_START_PROGRESS,
)
const MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_END_TIME: number = mangaDetailTimeAtProgress(
  MANGA_DETAIL_CLOSE_CURVE,
  MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_END_PROGRESS,
)
const MANGA_DETAIL_CLOSE_CARD_ENTRY_END_TIME: number = mangaDetailTimeAtProgress(
  MANGA_DETAIL_CLOSE_CURVE,
  MANGA_DETAIL_CLOSE_CARD_ENTRY_END_PROGRESS,
)

export const MANGA_DETAIL_ROOT_ID = 'koma-root-navigation'

interface MangaDetailSourceSurfaceStyle {
  radius: number
  background: ResourceColor
}

class MangaDetailCaptureFrameCallback extends FrameCallback {
  private action: () => void

  constructor(action: () => void) {
    super()
    this.action = action
  }

  onFrame(_frameTimeInNano: number): void {}

  onIdle(_timeLeftInNano: number): void {
    this.action()
  }
}

class MangaDetailSettleFrameCallback extends FrameCallback {
  private action: () => void
  constructor(action: () => void) { super(); this.action = action }
  onFrame(_frameTimeInNano: number): void { this.action() }
}

/**
 * Shared launcher for every gallery-card -> MangaDetail transition surface. Pages only provide
 * the real card node id and their existing navigation action; capture, eligibility and cleanup stay
 * identical across Home, Toplist, Favorites, Search and Viewed History.
 */
export class MangaDetailTransitionCoordinator {
  private static transitionSerial: number = 0
  private static routeSeed: number = 0
  private static scopeSeed: number = 0
  private static opening: boolean = false
  private static openingPreparation: number = 0
  private static popPreparationToken: number = 0

  private static screenCornerRadii(uiContext: UIContext): number | BorderRadiuses {
    try {
      const windowName = uiContext.getWindowName()
      if (windowName === undefined) return 0
      const properties = window.findWindow(windowName).getWindowProperties()
      const screen = properties.displayId === undefined ? display.getDefaultDisplaySync() :
        display.getDisplayByIdSync(properties.displayId)
      // Physical screen corners apply only when the window covers the display.
      if (properties.windowRect.width !== screen.width || properties.windowRect.height !== screen.height) return 0
      const corners = screen.getRoundedCorner()
      const radii: BorderRadiuses = { topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0 }
      for (const corner of corners) {
        const radius = uiContext.px2vp(corner.radius)
        switch (corner.type) {
          case display.CornerType.TOP_LEFT: radii.topLeft = radius; break
          case display.CornerType.TOP_RIGHT: radii.topRight = radius; break
          case display.CornerType.BOTTOM_LEFT: radii.bottomLeft = radius; break
          case display.CornerType.BOTTOM_RIGHT: radii.bottomRight = radius; break
        }
      }
      return radii
    } catch (_error) {
      // Some physical displays do not report their rounding.
      return 0
    }
  }

  static syncDetailCoverTarget(uiContext: UIContext): boolean {
    const transition = connectMangaDetailTransition()
    if (!transition.isCoverExpand() || transition.targetCoverComponentId.length === 0) {
      return false
    }
    try {
      const rootRect = uiContext.getComponentUtils().getRectangleById(MANGA_DETAIL_ROOT_ID)
      const coverRect = uiContext.getComponentUtils()
        .getRectangleById(transition.targetCoverComponentId)
      const rootWidth: number = uiContext.px2vp(rootRect.size.width)
      const rootHeight: number = uiContext.px2vp(rootRect.size.height)
      const width: number = uiContext.px2vp(coverRect.size.width)
      const height: number = uiContext.px2vp(coverRect.size.height)
      if (width <= 0 || height <= 0) {
        return transition.coverTargetReadyForRoot(rootWidth, rootHeight)
      }
      const x: number = uiContext.px2vp(coverRect.windowOffset.x - rootRect.windowOffset.x)
      const y: number = uiContext.px2vp(coverRect.windowOffset.y - rootRect.windowOffset.y)
      if (x + width <= 0 || y + height <= 0 || x >= rootWidth || y >= rootHeight) {
        transition.clearCoverTarget()
        return false
      }
      transition.setCoverTarget(
        x,
        y,
        width,
        height,
        ThemeConstants.RADIUS_THUMB,
        rootWidth,
        rootHeight,
      )
      return true
    } catch (_error) {
      return false
    }
  }

  static sourceGeometryNeedsRefresh(uiContext: UIContext): boolean {
    const transition = connectMangaDetailTransition()
    if (
      !transition.eligible ||
      transition.phase !== MangaDetailTransitionPhase.OPEN ||
      transition.sourceComponentId.length === 0
    ) {
      return false
    }
    try {
      const rootRect = uiContext.getComponentUtils().getRectangleById(MANGA_DETAIL_ROOT_ID)
      const rootWidth: number = uiContext.px2vp(rootRect.size.width)
      const rootHeight: number = uiContext.px2vp(rootRect.size.height)
      // Cover-expand already replaces the foreground image independently of
      // the card remainder. Do not recapture an unchanged layout just to swap
      // artwork: a covered Navigation surface can retain outgoing text layers.
      return (!transition.isCoverExpand() && transition.detailCoverSource !== undefined &&
        !sameTransitionCover(transition.coverSource, transition.detailCoverSource)) ||
        Math.abs(rootWidth - transition.rootWidth) > 0.5 ||
        Math.abs(rootHeight - transition.rootHeight) > 0.5
    } catch (_error) {
      return false
    }
  }

  static async prepareIndependentPopSurface(uiContext: UIContext, screenRadius: number | BorderRadiuses): Promise<boolean> {
    const transition = connectMangaDetailTransition()
    const token: number = transition.routeToken
    let snapshot: image.PixelMap | undefined = undefined
    try {
      const rootRect = uiContext.getComponentUtils().getRectangleById(MANGA_DETAIL_ROOT_ID)
      const rootWidth: number = uiContext.px2vp(rootRect.size.width)
      const rootHeight: number = uiContext.px2vp(rootRect.size.height)
      if (rootWidth <= 0 || rootHeight <= 0) {
        return false
      }
      snapshot = await uiContext.getComponentSnapshot()
        .get(MANGA_DETAIL_ROOT_ID, { waitUntilRenderFinished: true })
      if (!transition.owns(token) ||
        !transition.prepareIndependentPopSurface(snapshot, rootWidth, rootHeight, screenRadius)) {
        snapshot.release().catch((_error: Error) => {})
        return false
      }
      snapshot = undefined
      return true
    } catch (error) {
      if (snapshot !== undefined) {
        snapshot.release().catch((_releaseError: Error) => {})
      }
      DiagnosticLogger.info(
        'gallery-detail-transition',
        'detail_surface_snapshot_failed',
        `gid=${transition.galleryId} error=${error}`,
      )
      return false
    }
  }

  static refreshSourceGeometryForPop(
    uiContext: UIContext,
    onComplete: (success: boolean) => void,
  ): void {
    const transition = connectMangaDetailTransition()
    const token: number = transition.routeToken
    const componentId: string = transition.beginSourceRecapture()
    if (componentId.length === 0) {
      onComplete(false)
      return
    }

    let rootWidth: number = 0
    let rootHeight: number = 0
    let sourceX: number = 0
    let sourceY: number = 0
    let sourceWidth: number = 0
    let sourceHeight: number = 0
    let coverX: number = 0
    let coverY: number = 0
    let coverWidth: number = 0
    let coverHeight: number = 0
    let coverSnapshot: image.PixelMap | undefined = undefined
    let sourceSurfaceX: number = 0
    let sourceSurfaceY: number = 0
    let sourceSurfaceWidth: number = 0
    let sourceSurfaceHeight: number = 0
    let currentSourceSnapshot: image.PixelMap | undefined = undefined
    let cardSnapshot: image.PixelMap | undefined = undefined

    const current: () => boolean = (): boolean => transition.owns(token) &&
      transition.phase === MangaDetailTransitionPhase.OPEN
    const finishAfterHiddenFrame: (success: boolean) => void = (success: boolean): void => {
      uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback((): void => {
        onComplete(success && current())
      }))
    }
    const fail: (reason: string) => void = (reason: string): void => {
      if (coverSnapshot !== undefined) {
        coverSnapshot.release().catch((_releaseError: Error) => {})
        coverSnapshot = undefined
      }
      if (currentSourceSnapshot !== undefined) {
        currentSourceSnapshot.release().catch((_releaseError: Error) => {})
        currentSourceSnapshot = undefined
      }
      if (cardSnapshot !== undefined) {
        cardSnapshot.release().catch((_releaseError: Error) => {})
        cardSnapshot = undefined
      }
      if (current()) transition.cancelSourceRecapture(componentId)
      DiagnosticLogger.info(
        'gallery-detail-transition',
        'source_recapture_failed',
        `gid=${transition.galleryId} source=${componentId} reason=${reason}`,
      )
      finishAfterHiddenFrame(false)
    }
    const captureSourceSurface: () => Promise<void> = async (): Promise<void> => {
      if (!current()) return
      if (
        transition.independentPopSurfaceActive ||
        transition.sourceSurfaceComponentId.length === 0 ||
        currentSourceSnapshot !== undefined
      ) {
        return
      }
      try {
        const rootRect = uiContext.getComponentUtils().getRectangleById(MANGA_DETAIL_ROOT_ID)
        const sourceSurfaceRect = uiContext.getComponentUtils()
          .getRectangleById(transition.sourceSurfaceComponentId)
        sourceSurfaceWidth = uiContext.px2vp(sourceSurfaceRect.size.width)
        sourceSurfaceHeight = uiContext.px2vp(sourceSurfaceRect.size.height)
        sourceSurfaceX = uiContext.px2vp(
          sourceSurfaceRect.windowOffset.x - rootRect.windowOffset.x,
        )
        sourceSurfaceY = uiContext.px2vp(
          sourceSurfaceRect.windowOffset.y - rootRect.windowOffset.y,
        )
        if (sourceSurfaceWidth > 0 && sourceSurfaceHeight > 0) {
          currentSourceSnapshot = await uiContext.getComponentSnapshot()
            .get(transition.sourceSurfaceComponentId, { waitUntilRenderFinished: true })
          if (!current()) {
            currentSourceSnapshot.release().catch((_error: Error) => {})
            currentSourceSnapshot = undefined
          }
        }
      } catch (surfaceError) {
        DiagnosticLogger.info(
          'gallery-detail-transition',
          'source_surface_snapshot_failed',
          `gid=${transition.galleryId} source=${transition.sourceSurfaceComponentId} ` +
            `error=${surfaceError}`,
        )
      }
    }
    const completeAfterSourceHidden: () => Promise<void> = async (): Promise<void> => {
      try {
        await captureSourceSurface()
        if (!current()) { fail('route_cancelled'); return }
        if (
          cardSnapshot === undefined ||
          (!transition.independentPopSurfaceActive &&
            (currentSourceSnapshot === undefined ||
              sourceSurfaceWidth <= 0 ||
              sourceSurfaceHeight <= 0))
        ) {
          fail('missing_current_source_surface')
          return
        }
        const completed: boolean = transition.completeSourceRecapture(
          componentId,
          rootWidth,
          rootHeight,
          sourceX,
          sourceY,
          sourceWidth,
          sourceHeight,
          cardSnapshot,
          coverX,
          coverY,
          coverWidth,
          coverHeight,
          ThemeConstants.RADIUS_COVER,
          coverSnapshot,
          currentSourceSnapshot,
          sourceSurfaceX,
          sourceSurfaceY,
          sourceSurfaceWidth,
          sourceSurfaceHeight,
        )
        if (!completed) {
          cardSnapshot.release().catch((_releaseError: Error) => {})
          if (coverSnapshot !== undefined) {
            coverSnapshot.release().catch((_releaseError: Error) => {})
          }
          if (currentSourceSnapshot !== undefined) {
            currentSourceSnapshot.release().catch((_releaseError: Error) => {})
          }
          cardSnapshot = undefined
          coverSnapshot = undefined
          currentSourceSnapshot = undefined
          finishAfterHiddenFrame(false)
          return
        }
        cardSnapshot = undefined
        coverSnapshot = undefined
        currentSourceSnapshot = undefined
        DiagnosticLogger.info(
          'gallery-detail-transition',
          'source_recaptured',
          `gid=${transition.galleryId} source=${componentId} root=${rootWidth}x${rootHeight} ` +
            `card=${sourceX},${sourceY},${sourceWidth}x${sourceHeight}`,
        )
        finishAfterHiddenFrame(true)
      } catch (error) {
        fail(`${error}`)
      }
    }
    const captureCard: () => Promise<void> = async (): Promise<void> => {
      try {
        if (!current()) { fail('route_cancelled'); return }
        cardSnapshot = await uiContext.getComponentSnapshot()
          .get(componentId, { waitUntilRenderFinished: true })
        if (!current()) { fail('route_cancelled'); return }
        if (!transition.hideSourceForSurfaceCapture(componentId)) {
          fail('source_hide_before_surface_capture_failed')
          return
        }
        // The destination list is now active, but its virtualized item still needs rendered-frame
        // barriers after the source card becomes Hidden. Independent POP renders that live list
        // directly; only the legacy in-route path needs a captured source surface afterward.
        uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
          uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(
            completeAfterSourceHidden,
          ))
        }))
      } catch (error) {
        fail(`${error}`)
      }
    }

    // Rendering the retained source behind the still-opaque detail page gives ComponentUtils and
    // ComponentSnapshot the actual post-rotation card. No coordinate rotation or cached portrait
    // aspect is inferred here.
    uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
      try {
        if (!current()) { fail('route_cancelled'); return }
        const rootRect = uiContext.getComponentUtils().getRectangleById(MANGA_DETAIL_ROOT_ID)
        const sourceRect = uiContext.getComponentUtils().getRectangleById(componentId)
        rootWidth = uiContext.px2vp(rootRect.size.width)
        rootHeight = uiContext.px2vp(rootRect.size.height)
        sourceWidth = uiContext.px2vp(sourceRect.size.width)
        sourceHeight = uiContext.px2vp(sourceRect.size.height)
        sourceX = uiContext.px2vp(sourceRect.windowOffset.x - rootRect.windowOffset.x)
        sourceY = uiContext.px2vp(sourceRect.windowOffset.y - rootRect.windowOffset.y)
        if (rootWidth <= 0 || rootHeight <= 0 || sourceWidth <= 0 || sourceHeight <= 0 ||
          sourceX >= rootWidth || sourceY >= rootHeight || sourceX + sourceWidth <= 0 || sourceY + sourceHeight <= 0) {
          fail('invalid_current_geometry')
          return
        }

        if (transition.isCoverExpand()) {
          if (transition.sourceCoverComponentId.length === 0) {
            fail('missing_source_cover_id')
            return
          }
          const coverRect = uiContext.getComponentUtils()
            .getRectangleById(transition.sourceCoverComponentId)
          coverWidth = uiContext.px2vp(coverRect.size.width)
          coverHeight = uiContext.px2vp(coverRect.size.height)
          coverX = uiContext.px2vp(coverRect.windowOffset.x - rootRect.windowOffset.x)
          coverY = uiContext.px2vp(coverRect.windowOffset.y - rootRect.windowOffset.y)
          if (coverWidth <= 0 || coverHeight <= 0 || coverX >= rootWidth || coverY >= rootHeight ||
            coverX + coverWidth <= 0 || coverY + coverHeight <= 0) {
            fail('invalid_current_cover_geometry')
            return
          }
          coverSnapshot = await uiContext.getComponentSnapshot()
            .get(transition.sourceCoverComponentId, { waitUntilRenderFinished: true })
          if (!current()) { fail('route_cancelled'); return }
        }

        if (transition.isCoverExpand() && transition.preserveSourceCoverBackground) {
          uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
            uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
              if (!current()) { fail('route_cancelled'); return }
              transition.hideSourceCoverForRecapture()
              uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(captureCard))
            }))
          }))
          return
        }
        // A retained list item can expose cached image/tag render groups one frame before ordinary
        // Text and Symbol children. Capture both the card and its current list surface only after two
        // further rendered-frame boundaries; this is a paint barrier, not a millisecond delay.
        uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
          uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(captureCard))
        }))
      } catch (error) {
        fail(`${error}`)
      }
    }))
  }

  static finishPostPopHandoff(
    uiContext: UIContext,
    onComplete: () => void,
  ): boolean {
    const transition = connectMangaDetailTransition()
    const token: number = transition.routeToken
    let started: boolean = false
    UIUtils.applySync((): void => { started = transition.beginPostPopHandoff() })
    if (!started) {
      return false
    }
    uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
      if (!transition.owns(token) || !transition.postPopHandoffActive()) {
        return
      }
      uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
        if (transition.owns(token) && transition.postPopHandoffActive()) {
          onComplete()
        }
      }))
    }))
    return true
  }

  static finishNavigationBeforeIndependentPop(
    uiContext: UIContext,
    finishNavigation: () => void,
    onSourceReady: () => void,
  ): void {
    const transition = connectMangaDetailTransition()
    const token: number = transition.routeToken
    // First render the opaque detail snapshot above Navigation. Only then finish POP so the real source
    // route and its HDS chrome can become active underneath without exposing an intermediate frame.
    uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
      if (!transition.owns(token) || !transition.independentPopSurfaceVisible()) {
        return
      }
      finishNavigation()
      // HDS applies the destination route and its title/tab chrome on rendered-frame boundaries. Wait
      // for two such boundaries before shrinking the snapshot; no visual millisecond delay is inferred.
      uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
        uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
          if (transition.owns(token) && transition.independentPopSurfaceVisible()) {
            onSourceReady()
          }
        }))
      }))
    }))
  }

  static allocateScope(owner: string): string {
    MangaDetailTransitionCoordinator.scopeSeed += 1
    return `gallery-list-${owner}-${MangaDetailTransitionCoordinator.scopeSeed}`
  }

  static sourceId(scope: string, mode: string, galleryId: string): string {
    return `${scope}-${mode}-${galleryId}`
  }

  static sourceCoverId(scope: string, mode: string, galleryId: string): string {
    return `${MangaDetailTransitionCoordinator.sourceId(scope, mode, galleryId)}-cover`
  }

  static sourceSurfaceId(scope: string, mode: string): string {
    return `${scope}-${mode}-surface`
  }

  static async open(
    uiContext: UIContext,
    componentId: string,
    openDetail: () => void,
    sourceSurfaceComponentId: string = '',
    sourceCoverComponentId: string = '',
    coverSource: MangaDetailTransitionCoverSource | undefined = undefined,
    sourceIsCurrent: () => boolean = (): boolean => true,
    refreshSourceLayout?: () => MangaDetailReturnLayout,
    sourceSurfaceStyle?: MangaDetailSourceSurfaceStyle,
  ): Promise<void> {
    if (MangaDetailTransitionCoordinator.opening) return
    const transition = connectMangaDetailTransition()
    const mode = connectAppearanceState().detailTransitionMode
    if (mode === MangaDetailTransitionMode.SYSTEM || !transition.beginRouteContext()) { openDetail(); return }
    const preparation = transition.preparationToken
    const galleryId = `${++MangaDetailTransitionCoordinator.routeSeed}`
    const stack = RouterHelper.getAppPathStack()
    const depth = stack?.size() ?? 0
    const top: Object | undefined = depth > 0 ? stack?.getParamByIndex(depth - 1) as Object : undefined
    const names = stack?.getAllPathName().join('|') ?? ''
    const owned = (): boolean => transition.preparationToken === preparation
    const sourceGeometryValid = (): boolean => {
      try {
        const sourceRect = uiContext.getComponentUtils().getRectangleById(componentId)
        const rootRect = uiContext.getComponentUtils().getRectangleById(MANGA_DETAIL_ROOT_ID)
        return sourceRect.size.width > 0 && sourceRect.size.height > 0 &&
          sourceRect.windowOffset.x + sourceRect.size.width > rootRect.windowOffset.x &&
          sourceRect.windowOffset.y + sourceRect.size.height > rootRect.windowOffset.y &&
          sourceRect.windowOffset.x < rootRect.windowOffset.x + rootRect.size.width &&
          sourceRect.windowOffset.y < rootRect.windowOffset.y + rootRect.size.height
      } catch (_error) { return false }
    }
    const sourceContextCurrent = (): boolean => sourceIsCurrent() && sourceGeometryValid() &&
      RouterHelper.getAppPathStack() === stack && (stack?.size() ?? 0) === depth &&
      (stack?.getAllPathName().join('|') ?? '') === names &&
      (depth === 0 || stack?.getParamByIndex(depth - 1) === top)
    const current = (): boolean => owned() && sourceContextCurrent()
    const abort = (): void => {
      if (owned()) transition.finishRouteContext()
      if (MangaDetailTransitionCoordinator.openingPreparation === preparation) MangaDetailTransitionCoordinator.opening = false
    }
    const frame = (): Promise<void> => new Promise<void>((resolve): void => {
      uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(resolve))
    })
    let card: image.PixelMap | undefined = undefined
    let cover: image.PixelMap | undefined = undefined
    let source: image.PixelMap | undefined = undefined
    let dispatched: boolean = false
    MangaDetailTransitionCoordinator.opening = true
    MangaDetailTransitionCoordinator.openingPreparation = preparation
    const captureTimeout = setTimeout((): void => {
      // A slow snapshot must not consume the user's valid tap. Return the card first, then
      // use ordinary navigation only while the same source and stack still own that tap.
      const shouldNavigate: boolean = !dispatched && current()
      abort()
      if (shouldNavigate && sourceContextCurrent()) {
        dispatched = true
        openDetail()
      }
    }, 4500)
    try {
      const rect = uiContext.getComponentUtils().getRectangleById(componentId)
      const root = uiContext.getComponentUtils().getRectangleById(MANGA_DETAIL_ROOT_ID)
      const rw = uiContext.px2vp(root.size.width), rh = uiContext.px2vp(root.size.height)
      const w = uiContext.px2vp(rect.size.width), h = uiContext.px2vp(rect.size.height)
      const x = uiContext.px2vp(rect.windowOffset.x - root.windowOffset.x)
      const y = uiContext.px2vp(rect.windowOffset.y - root.windowOffset.y)
      if (rw <= 0 || rh <= 0 || w <= 0 || h <= 0) throw new Error('invalid_source_geometry')
      let cx = x, cy = y, cw = w, ch = h
      let selectedMode = mode
      let preserveBackground = false
      if (mode === MangaDetailTransitionMode.COVER_EXPAND && sourceCoverComponentId.length > 0) {
        try {
          const cr = uiContext.getComponentUtils().getRectangleById(sourceCoverComponentId)
          cx = uiContext.px2vp(cr.windowOffset.x - root.windowOffset.x)
          cy = uiContext.px2vp(cr.windowOffset.y - root.windowOffset.y)
          cw = uiContext.px2vp(cr.size.width); ch = uiContext.px2vp(cr.size.height)
          if (cw <= 0 || ch <= 0) throw new Error('cover_not_rendered')
          cover = await uiContext.getComponentSnapshot().get(sourceCoverComponentId, { waitUntilRenderFinished: true })
          if (!current()) { abort(); return }
          try {
            const bg = uiContext.getComponentUtils().getRectangleById(`${sourceCoverComponentId}-background`)
            preserveBackground = bg.size.width > 0 && bg.size.height > 0
          } catch (_error) { preserveBackground = false }
        } catch (error) {
          if (!current()) { abort(); return }
          selectedMode = MangaDetailTransitionMode.SEAMLESS
          DiagnosticLogger.info('detail-transition', 'cover_snapshot_fallback', `${error}`)
        }
      } else if (mode === MangaDetailTransitionMode.COVER_EXPAND) selectedMode = MangaDetailTransitionMode.SEAMLESS
      card = await uiContext.getComponentSnapshot().get(componentId, { waitUntilRenderFinished: true })
      if (!current()) { abort(); return }
      transition.coverSource = coverSource
      transition.refreshSourceLayout = refreshSourceLayout
      UIUtils.applySync((): void => {
        transition.beginSourceHandoff(selectedMode, componentId, sourceCoverComponentId, sourceSurfaceComponentId,
          preserveBackground, `${componentId}-detail-cover`, x, y, w, h, card!, cx, cy, cw, ch,
          ThemeConstants.RADIUS_COVER, cover, coverSource?.uri ?? '',
          sourceSurfaceStyle?.radius ?? ThemeConstants.RADIUS_COVER, sourceSurfaceStyle?.background)
      })
      card = undefined; cover = undefined
      await frame()
      if (!current()) { abort(); return }
      if (preserveBackground) {
        let replacement: image.PixelMap | undefined = undefined
        try {
          replacement = await uiContext.getComponentSnapshot().get(componentId, { waitUntilRenderFinished: true })
          if (!current()) { replacement.release().catch(() => {}); abort(); return }
          transition.completePreservedSourceCardSnapshot(componentId, replacement)
          replacement = undefined
        } catch (_error) { if (owned()) transition.completePreservedSourceCardSnapshot(componentId, undefined) }
        await frame()
        if (!current()) { abort(); return }
      }
      source = await uiContext.getComponentSnapshot().get(MANGA_DETAIL_ROOT_ID, { waitUntilRenderFinished: true })
      if (!current()) { abort(); return }
      // ArkUI V2 marks dirty in a microtask. Commit the actual collapsed surface before routing,
      // then commit each animation target inside its animateTo scope (official API22 applySync).
      UIUtils.applySync((): void => {
        transition.prepare(galleryId, Math.max(0.08, Math.min(1, w / rw)), Math.max(0.08, Math.min(1, h / rh)),
          x + w / 2 - rw / 2, y + h / 2 - rh / 2, ThemeConstants.RADIUS_CARD, rw, rh, source!)
      })
      source = undefined
      clearTimeout(captureTimeout)
      if (!current()) { abort(); return }
      MangaDetailTransitionCoordinator.opening = false
      dispatched = true
      openDetail()
      const token = transition.routeToken
      setTimeout((): void => {
        if (transition.routeToken === token && transition.pendingToken() !== undefined) transition.finishRouteContext()
      }, 4500)
    } catch (error) {
      const shouldNavigate = current()
      abort()
      DiagnosticLogger.exception('detail-transition', 'snapshot_failed', error as Error)
      if (!dispatched && shouldNavigate && sourceContextCurrent()) {
        dispatched = true
        openDetail()
      }
    } finally {
      clearTimeout(captureTimeout)
      card?.release().catch(() => {})
      cover?.release().catch(() => {})
      source?.release().catch(() => {})
      if (MangaDetailTransitionCoordinator.openingPreparation === preparation) MangaDetailTransitionCoordinator.opening = false
    }
  }

  private static owns(content: NavContentInfo): boolean {
    return content.name === RouteName.MANGA_DETAIL && content.param !== undefined &&
      connectMangaDetailTransition().owns((content.param as MangaDetailRouteParam).transitionToken,
        content.navDestinationId ?? '')
  }

  private static waitForDetailLayout(uiContext: UIContext): Promise<boolean> {
    const transition = connectMangaDetailTransition()
    const token = transition.routeToken
    return new Promise<boolean>((resolve): void => {
      let frames = 0
      const wait = (): void => {
        uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback((): void => {
          if (!transition.owns(token) || transition.phase !== MangaDetailTransitionPhase.OPENING || ++frames > 60) {
            resolve(false)
          } else if (transition.detailLayoutReady) {
            // The ready signal is observed at frame idle, after the real chapter layout has
            // completed. Another requested frame would only delay the already prepared flight.
            resolve(true)
          } else wait()
        }))
      }
      wait()
    })
  }

  static preparePop(uiContext: UIContext, token: number | undefined, pop: (systemAnimation: boolean) => void): boolean {
    const transition = connectMangaDetailTransition()
    if (!transition.owns(token) || transition.phase !== MangaDetailTransitionPhase.OPEN) return false
    if (MangaDetailTransitionCoordinator.popPreparationToken === token) return true
    const refreshSourceLayout = transition.refreshSourceLayout
    if (refreshSourceLayout !== undefined && refreshSourceLayout() === MangaDetailReturnLayout.SOURCE_NOT_VISIBLE) {
      // #359: release ownership before POP, while Navigation can still choose its system animation.
      // Finishing a custom proxy after POP starts would cut straight to the shelf.
      UIUtils.applySync((): void => { transition.finishRouteContext() })
      DiagnosticLogger.info('gallery-detail-transition', 'pop_source_not_visible', 'system_animation')
      pop(true)
      return true
    }
    if (!transition.isCoverExpand()) return false
    MangaDetailTransitionCoordinator.popPreparationToken = token ?? 0
    const prepare = async (): Promise<void> => {
      let snapshot: image.PixelMap | undefined = undefined
      let readyToPop: boolean = false
      try {
        const visible = MangaDetailTransitionCoordinator.syncDetailCoverTarget(uiContext)
        const source = transition.detailCoverSource
        // #362: capture the currently displayed artwork before hiding it.
        // The card remainder excludes this image, so unchanged geometry can
        // retain its existing snapshot while the new cover flies separately.
        if (visible && source !== undefined && !sameTransitionCover(source, transition.coverSource)) {
          snapshot = await uiContext.getComponentSnapshot().get(transition.targetCoverComponentId,
            { waitUntilRenderFinished: true })
          if (!transition.replacePopCover(token, source, snapshot)) return
          snapshot = undefined
        }
        if (!transition.owns(token) || transition.phase !== MangaDetailTransitionPhase.OPEN) return
        UIUtils.applySync((): void => { transition.prepareCoverPop(visible) })
        readyToPop = true
      } catch (error) {
        if (!transition.owns(token)) return
        UIUtils.applySync((): void => { transition.useSeamlessFallback() })
        DiagnosticLogger.info('detail-transition', 'changed_cover_capture_failed', `${error}`)
        readyToPop = true
      } finally {
        snapshot?.release().catch((_error: Error) => {})
        if (!readyToPop && MangaDetailTransitionCoordinator.popPreparationToken === token) MangaDetailTransitionCoordinator.popPreparationToken = 0
      }
      uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback((): void => {
        if (MangaDetailTransitionCoordinator.popPreparationToken === token) MangaDetailTransitionCoordinator.popPreparationToken = 0
        if (transition.owns(token) && transition.phase === MangaDetailTransitionPhase.OPEN) pop(false)
      }))
    }
    void prepare()
    return true
  }
  static transition(
    uiContext: UIContext,
    from: NavContentInfo,
    to: NavContentInfo,
    operation: NavigationOperation,
  ): NavigationAnimatedTransition | undefined {
    const transition = connectMangaDetailTransition()
    if (!transition.eligible) return undefined
    // The captured list card belongs only to the GalleryDetail route opened from that card. A detail
    // may push a parent/newer version onto the same stack; those detail-to-detail operations must use
    // the ordinary navigation transition while the original route retains its later list return.
    const isPush: boolean = operation === NavigationOperation.PUSH &&
      MangaDetailTransitionCoordinator.owns(to)
    const isPop: boolean = operation === NavigationOperation.POP &&
      MangaDetailTransitionCoordinator.owns(from)
    if (!isPush && !isPop) {
      return undefined
    }
    if (isPush && to.navDestinationId !== undefined) {
      transition.bindRouteDestination(to.navDestinationId)
    }
    MangaDetailTransitionCoordinator.transitionSerial += 1
    const transitionSerial: number = MangaDetailTransitionCoordinator.transitionSerial
    const routeToken: number = transition.routeToken
    const current: () => boolean = (): boolean => transition.owns(routeToken) &&
      transitionSerial === MangaDetailTransitionCoordinator.transitionSerial
    return {
      timeout: MANGA_DETAIL_TRANSITION_DURATION_MS * 12,
      transition: async (proxy: NavigationTransitionProxy): Promise<void> => {
        let proxyFinished: boolean = false
        let finishScheduled: boolean = false
        const finishProxy: () => void = (): void => {
          if (proxyFinished) return
          proxyFinished = true
          proxy.finishTransition()
        }
        const finishOnFrame: (settlePush: boolean) => void = (settlePush: boolean): void => {
          if (finishScheduled || proxyFinished) return
          finishScheduled = true
          // Keep the final outgoing card alive until this frame. Finish Native navigation and its
          // V2 cleanup after the animation scope closes, before painting the live source card.
          uiContext.postFrameCallback(new MangaDetailSettleFrameCallback((): void => {
            if (current() && settlePush) UIUtils.applySync((): void => { transition.markPushSettled(true) })
            finishProxy()
          }))
        }
        if (isPush) {
          // 页面的真实元数据/章节布局全部完成后，在独立帧边界启动原350ms动画；不把目录后挂到动画中。
          if (!await MangaDetailTransitionCoordinator.waitForDetailLayout(uiContext)) {
            if (current()) transition.finishRouteContext()
            finishProxy()
            return
          }
          if (!current()) { finishProxy(); return }
          if (
            transition.isCoverExpand() &&
            !MangaDetailTransitionCoordinator.syncDetailCoverTarget(uiContext)
          ) {
            DiagnosticLogger.info(
              'gallery-detail-transition',
              'cover_target_fallback',
              `gid=${transition.galleryId}`,
            )
            UIUtils.applySync((): void => { transition.useSeamlessFallback() })
          }
          const coverExpand: boolean = transition.isCoverExpand()
          const screenRadius = coverExpand ? MangaDetailTransitionCoordinator.screenCornerRadii(uiContext) : 0
          // Remove the preparation-only copy synchronously outside the animation transaction.
          // Otherwise ArkUI gives the removed If node an implicit exit across the whole flight.
          UIUtils.applySync((): void => { transition.animationStarted = true })
          uiContext.animateTo({
            duration: MANGA_DETAIL_TRANSITION_DURATION_MS,
            curve: MANGA_DETAIL_OPEN_CURVE,
            onFinish: (): void => {
              if (current()) {
                finishOnFrame(true)
              }
            },
          }, (): void => {
            UIUtils.applySync((): void => {
              // The full source surface and foreground geometry share one render transaction.
              transition.sourceSurfaceScale = MANGA_DETAIL_SOURCE_SURFACE_SCALE
              transition.expandWindow(screenRadius)
            })
          })
          if (!coverExpand) {
            uiContext.animateTo({
              delay: MANGA_DETAIL_TRANSITION_DURATION_MS * MANGA_DETAIL_OPEN_CARD_EXIT_START_TIME,
              duration: MANGA_DETAIL_TRANSITION_DURATION_MS * (
                MANGA_DETAIL_OPEN_CARD_EXIT_END_TIME - MANGA_DETAIL_OPEN_CARD_EXIT_START_TIME
              ),
              curve: Curve.Linear,
            }, (): void => {
              UIUtils.applySync((): void => { transition.crossfadeToDetail() })
            })
          } else {
            uiContext.animateTo({
              delay: MANGA_DETAIL_TRANSITION_DURATION_MS * MANGA_DETAIL_COVER_OPEN_CARD_EXIT_START_TIME,
              duration: MANGA_DETAIL_TRANSITION_DURATION_MS * (
                MANGA_DETAIL_COVER_OPEN_CARD_EXIT_END_TIME -
                  MANGA_DETAIL_COVER_OPEN_CARD_EXIT_START_TIME
              ),
              curve: Curve.Linear,
            }, (): void => {
              UIUtils.applySync((): void => { transition.hideSourceCard() })
            })
          }
          return
        }
        const animatePopSurface: (onFinish: () => void) => void = (onFinish: () => void): void => {
          if (!current()) {
            finishProxy()
            return
          }
          if (
            transition.isCoverExpand() &&
            !MangaDetailTransitionCoordinator.syncDetailCoverTarget(uiContext)
          ) {
            DiagnosticLogger.info(
              'gallery-detail-transition',
              'cover_pop_fallback',
              `gallery=${transition.galleryId} reason=target_not_visible`,
            )
            // The detail cover may have scrolled out of the viewport. Keep the whole detail surface
            // collapsing into the source card, suppress the stale cover flight, and fade the separately
            // captured source cover in near landing. The hidden source snapshot contains an empty card
            // slot, so the four-slice card remainder cannot restore the cover by itself.
            UIUtils.applySync((): void => { transition.useCoverFadePopFallback() })
          }
          // With a reordered shelf the snapshot in front still covers the live page here. Measure
          // first, then scale that live page under it so the first reveal already matches the motion.
          UIUtils.applySync((): void => { transition.sourceSurfaceScale = MANGA_DETAIL_SOURCE_SURFACE_SCALE })
          const coverExpand: boolean = transition.isCoverExpand()
          uiContext.animateTo({
            duration: MANGA_DETAIL_TRANSITION_DURATION_MS,
            curve: MANGA_DETAIL_CLOSE_CURVE,
            onFinish: (): void => {
              if (current()) {
                onFinish()
              }
            },
          }, (): void => {
            UIUtils.applySync((): void => {
              transition.sourceSurfaceScale = 1
              transition.collapseWindow(ThemeConstants.RADIUS_CARD)
            })
          })
          if (!coverExpand) {
            uiContext.animateTo({
              delay: MANGA_DETAIL_TRANSITION_DURATION_MS * MANGA_DETAIL_CLOSE_CARD_ENTRY_START_TIME,
              duration: MANGA_DETAIL_TRANSITION_DURATION_MS * (
                MANGA_DETAIL_CLOSE_CARD_ENTRY_END_TIME - MANGA_DETAIL_CLOSE_CARD_ENTRY_START_TIME
              ),
              curve: Curve.Linear,
            }, (): void => {
              UIUtils.applySync((): void => { transition.crossfadeToCard() })
            })
          } else {
            uiContext.animateTo({
              delay: MANGA_DETAIL_TRANSITION_DURATION_MS * MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_START_TIME,
              duration: MANGA_DETAIL_TRANSITION_DURATION_MS * (
                MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_END_TIME -
                  MANGA_DETAIL_COVER_CLOSE_CARD_ENTRY_START_TIME
              ),
              curve: Curve.Linear,
            }, (): void => {
              UIUtils.applySync((): void => { transition.revealSourceCard() })
            })
          }
        }
        const screenRadius = transition.isCoverExpand() ? MangaDetailTransitionCoordinator.screenCornerRadii(uiContext) : 0
        const startPopAnimation: () => void = (): void => {
          if (!current()) { finishProxy(); return }
          UIUtils.applySync((): void => { transition.beginPop(screenRadius) })
          animatePopSurface((): void => {
            finishOnFrame(false)
          })
        }
        const startIndependentPopAnimation = (): void => {
          if (!current()) { finishProxy(); return }
          UIUtils.applySync((): void => { transition.beginPop(screenRadius) })
          const animate = (): void => {
            if (!current()) return
            animatePopSurface((): void => {
              const handoffStarted = MangaDetailTransitionCoordinator.finishPostPopHandoff(uiContext, (): void => {
                if (current()) UIUtils.applySync((): void => { transition.finishRouteContext() })
              })
              if (!handoffStarted) UIUtils.applySync((): void => { transition.markPopSettled(true) })
            })
          }
          MangaDetailTransitionCoordinator.finishNavigationBeforeIndependentPop(uiContext, finishProxy, animate)
        }
        const preparePopAnimation = async (sourceLayoutChanged: boolean, afterPopLayout: boolean): Promise<void> => {
          if (sourceLayoutChanged || MangaDetailTransitionCoordinator.sourceGeometryNeedsRefresh(uiContext)) {
            const useIndependentPopSurface: boolean = transition.isCoverExpand()
            if (useIndependentPopSurface &&
              !await MangaDetailTransitionCoordinator.prepareIndependentPopSurface(uiContext, screenRadius)) {
              if (current()) transition.finishRouteContext()
              finishProxy()
              return
            }
            if (!current()) { finishProxy(); return }
            // The destination card and background are captured from the same projection.
            MangaDetailTransitionCoordinator.refreshSourceGeometryForPop(uiContext, (success: boolean): void => {
              if (!current()) { finishProxy(); return }
              if (!success) {
                transition.finishRouteContext()
                finishProxy()
                return
              }
              if (useIndependentPopSurface) startIndependentPopAnimation()
              else startPopAnimation()
            })
          } else if (afterPopLayout) {
            startPopAnimation()
          } else {
            // Native POP's layout marks the outgoing detail dirty. Animate on the next frame to
            // avoid forcing a nested flush while Navigation is still laying out.
            uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(startPopAnimation))
          }
        }
        const refreshSourceLayout = transition.refreshSourceLayout
        if (refreshSourceLayout === undefined) {
          await preparePopAnimation(false, false)
        } else {
          uiContext.postFrameCallback(new MangaDetailCaptureFrameCallback(async (): Promise<void> => {
            if (!current()) { finishProxy(); return }
            let sourceLayoutChanged = false
            try {
              UIUtils.applySync((): void => {
                sourceLayoutChanged = refreshSourceLayout() !== MangaDetailReturnLayout.UNCHANGED
              })
            } catch (error) {
              DiagnosticLogger.info('gallery-detail-transition', 'source_layout_refresh_failed', `${error}`)
              if (current()) transition.finishRouteContext()
              finishProxy()
              return
            }
            await preparePopAnimation(sourceLayoutChanged, true)
          }))
        }
      },
      onTransitionEnd: (success: boolean): void => {
        if (!current()) {
          return
        }
        if (isPush) {
          UIUtils.applySync((): void => { transition.markPushSettled(success) })
        } else if (transition.independentPopSurfaceActive) {
          if (!success) {
            UIUtils.applySync((): void => { transition.finishRouteContext() })
          }
        } else if (success && transition.isCoverExpand()) {
          const handoffStarted: boolean = MangaDetailTransitionCoordinator.finishPostPopHandoff(
            uiContext,
            (): void => {
              if (current()) {
                UIUtils.applySync((): void => { transition.finishRouteContext() })
              }
            },
          )
          if (!handoffStarted) {
            UIUtils.applySync((): void => { transition.markPopSettled(true) })
          }
        } else {
          UIUtils.applySync((): void => { transition.markPopSettled(success) })
        }
      },
    }
  }

}

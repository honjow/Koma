import { common } from '@kit.AbilityKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { ReaderCancellation, ReaderDisplayPolicy, ReaderImageSaveHost, ReaderImageShareHost, ReaderInputPort,
  ReaderObservedPosition, ReaderPagedSession, ReaderUnitKey, ReaderLayout } from '@reader-kit/core'
import { ReaderKeepScreenOn, ReaderLabRequest, ReaderLabSurface, ReaderSurface, ReaderTrialWindow,
  ReaderLabVisibilityState, ReaderSystemImageSaveHost, ReaderVolumeKeys, connectReaderLabVisibility, ReaderTapAction,
  ReaderTapZonePreviewRegion } from '@reader-kit/ui'
import { KomaReaderLabAdapter } from './KomaReaderLabAdapter'
import { KomaReaderLabImageShareHost } from './KomaReaderLabImageShareHost'
import { connectLayoutSafeArea, LayoutSafeAreaState } from '../state/LayoutSafeAreaState'
import { ThemeConstants } from '../theme/ThemeConstants'
import { ReaderColumnMode, ReaderPreferences, ReaderPreferencesStore,
  normalizeReaderTapZonePreset, normalizeReaderTapZoneInvert } from '../model/ReaderPreferencesStore'
import { readerTapZoneRegions, resolveReaderTapZoneAction } from '../model/ReaderTapZoneGeometry'
import { KomaReaderInitialPolicy } from './KomaReaderInitialPolicy'
import { KomaReaderPreferenceBridge } from './KomaReaderPreferenceBridge'
import { connectReaderModeState, ReaderModeState } from '../state/ReaderModeState'
import { ReaderMode } from '../model/ReaderSessionStore'
import { ReaderSettingsContent } from '../components/ReaderSettingsContent'

@ComponentV2
export struct KomaReaderLabPage {
  @Require @Param request: ReaderLabRequest
  @Event readInitialColumn: (work: string, unit: string) => ReaderColumnMode = () => {
    throw new Error('reader_lab_progress_owner_unavailable')
  }
  @Event readInitialPage: (work: string, unit: string) => number = () => {
    throw new Error('reader_lab_progress_owner_unavailable')
  }
  @Event persistObserved: (position: ReaderObservedPosition, column: ReaderColumnMode) => void = () => {}
  @Event flushObserved: () => void = () => {}
  @Event onClose: () => void = () => {}
  @Local private session: ReaderPagedSession | null = null
  @Local private labVisibility: ReaderLabVisibilityState = connectReaderLabVisibility()
  @Local private routeActive: boolean = false
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private error: string = ''
  @Local private chapterBusy: boolean = false
  @Local private readerMode: ReaderModeState = connectReaderModeState()
  @Local private readerSettingsSheetShown: boolean = false
  @Local private hostPreferences: ReaderPreferences | null = null
  @Local private tapZonePreviewRevision: number = 0
  private unitKey: ReaderUnitKey = new ReaderUnitKey('', '', '')
  private initialPageIndex: number = 0
  private trialWindow: ReaderTrialWindow = new ReaderTrialWindow()
  private keepScreenOn: ReaderKeepScreenOn | null = null
  private imageSave: ReaderImageSaveHost | null = null
  private imageShare: ReaderImageShareHost | null = null
  private adapter: KomaReaderLabAdapter | null = null
  private chapterRequest: ReaderCancellation | null = null
  private chapterProbeUsed: boolean = false
  private readerClosed: boolean = false
  private initialization: ReaderCancellation | null = null
  private input: ReaderInputPort = new ReaderInputPort()
  private volumeKeys: ReaderVolumeKeys = new ReaderVolumeKeys(this.input)
  private preferencesStore: ReaderPreferencesStore | null = null
  private preferenceWrites: Promise<void> = Promise.resolve()

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context.applicationInfo.debug) return
    this.initialization?.cancel()
    if (this.request.readingChrome) this.session = null
    this.readerClosed = false
    try {
      const adapter = new KomaReaderLabAdapter(context.filesDir, context.cacheDir)
      this.adapter = adapter
      this.imageSave = new ReaderSystemImageSaveHost(context)
      this.imageShare = new KomaReaderLabImageShareHost(context, adapter)
      this.unitKey = adapter.initialKey(this.request.work, this.request.unit)
      this.initialPageIndex = this.request.pageIndex
      const session = new ReaderPagedSession(adapter, adapter, adapter)
      if (this.request.readingChrome) {
        this.trialWindow.open(context)
        this.keepScreenOn = new ReaderKeepScreenOn(context)
        void this.initializeSession(context, session)
      } else {
        this.session = session
      }
    } catch (_error) {
      this.error = 'reader_lab_library_unavailable'
    }
  }

  private async initializeSession(context: common.UIAbilityContext, session: ReaderPagedSession): Promise<void> {
    const cancellation = new ReaderCancellation()
    this.initialization?.cancel()
    this.initialization = cancellation
    try {
      const preferencesStore = new ReaderPreferencesStore(context)
      const preferences = await preferencesStore.load()
      if (cancellation.isCancelled() || this.readerClosed) return
      this.preferencesStore = preferencesStore
      const column = this.readInitialColumn(this.unitKey.work, this.unitKey.unit)
      preferences.columnMode = column
      this.hostPreferences = preferences
      if (cancellation.isCancelled() || this.readerClosed) return
      if (this.request.progressReadWrite && !this.request.pageIndexProvided) {
        this.initialPageIndex = this.readInitialPage(this.unitKey.work, this.unitKey.unit)
      }
      if (cancellation.isCancelled() || this.readerClosed) return
      session.setPolicy(KomaReaderInitialPolicy.resolve(preferences, column, this.request))
      this.session = session
      this.syncKeepScreenOn()
      this.syncVolumeKeys()
    } catch (_error) {
      if (cancellation.isCancelled() || this.readerClosed) return
      console.warn('[KomaReaderLab] initial_policy_unavailable')
      this.closeReader()
    } finally {
      if (this.initialization === cancellation) this.initialization = null
    }
  }

  private resolveTapZone(x: number, y: number, _layout: ReaderLayout): ReaderTapAction {
    if (this.readerClosed || !this.readerMode.hydrated || !this.routeActive ||
      !this.labVisibility.foreground || this.session === null) return 'none'
    const action = resolveReaderTapZoneAction(
      normalizeReaderTapZonePreset(this.hostPreferences?.tapZonePreset ?? this.readerMode.tapZonePreset),
      normalizeReaderTapZoneInvert(this.hostPreferences?.tapZoneInvert ?? this.readerMode.tapZoneInvert), x, y, 1, 1)
    return action === 'center' ? 'menu' : action
  }

  aboutToDisappear(): void {
    this.readerClosed = true
    this.readerSettingsSheetShown = false
    this.initialization?.cancel()
    this.volumeKeys.close()
    this.cancelChapterRequest()
    this.adapter?.close()
    void this.keepScreenOn?.close()
    if (this.request.readingChrome) this.trialWindow.close()
  }

  @Monitor('routeActive', 'labVisibility.foreground', 'readerMode.hydrated', 'readerMode.keepScreenAwake',
    'readerSettingsSheetShown')
  syncKeepScreenOn(): void {
    this.keepScreenOn?.setActive(this.request.readingChrome && this.session !== null && this.routeActive &&
      this.labVisibility.foreground && this.readerMode.hydrated && !this.readerSettingsSheetShown &&
      (this.hostPreferences?.keepScreenAwake ?? this.readerMode.keepScreenAwake))
  }

  private closeReader(): void {
    this.readerClosed = true
    this.readerSettingsSheetShown = false
    this.initialization?.cancel()
    this.volumeKeys.close()
    this.cancelChapterRequest()
    void this.keepScreenOn?.close()
    if (this.request.progressReadWrite) this.flushObserved()
    this.onClose()
  }

  @Monitor('routeActive', 'labVisibility.foreground', 'readerMode.hydrated',
    'readerMode.volumeKeyNavigationEnabled', 'readerMode.volumeKeyBehavior', 'readerSettingsSheetShown', 'session')
  syncVolumeKeys(): void {
    const enabled = this.request.volumeKeysOverride ??
      (this.hostPreferences?.volumeKeyNavigationEnabled ?? this.readerMode.volumeKeyNavigationEnabled)
    this.volumeKeys.setActive(!this.readerClosed && this.request.readingChrome && this.session !== null &&
      this.routeActive && this.labVisibility.foreground && this.readerMode.hydrated &&
      !this.readerSettingsSheetShown && enabled,
      (this.hostPreferences?.volumeKeyBehavior ?? this.readerMode.volumeKeyBehavior) === 'up_next_down_previous')
  }

  @Monitor('routeActive', 'labVisibility.foreground')
  onChapterActivityChanged(): void {
    if (!this.routeActive || !this.labVisibility.foreground) this.cancelChapterRequest()
  }

  private cancelChapterRequest(): void {
    this.chapterRequest?.cancel()
    this.chapterRequest = null
    this.chapterBusy = false
  }

  private async runChapterPreparationProbe(cancellation: ReaderCancellation): Promise<void> {
    if (this.chapterProbeUsed || this.request.chapterProbe.length === 0) return
    this.chapterProbeUsed = true
    console.info(`[KomaReaderLab] chapter_probe kind=${this.request.chapterProbe}`)
    if (this.request.chapterProbe === 'prepare-fail-once') throw new Error('reader_lab_chapter_prepare_probe')
    await new Promise<void>((resolve): void => { setTimeout(resolve, 3000) })
    cancellation.check()
  }

  private async switchChapter(direction: 'previous' | 'next', sourceUnit: ReaderUnitKey): Promise<void> {
    const session = this.session
    const adapter = this.adapter
    if (session === null || adapter === null || this.chapterBusy || this.readerClosed ||
      !this.routeActive || !this.labVisibility.foreground) return
    const current = session.snapshot()
    if (current.phase !== 'ready' || current.unit === null || !current.unit.key.equals(sourceUnit)) return
    const target = adapter.adjacent(current.unit, direction)
    if (target === null || target.scope !== sourceUnit.scope || target.work !== sourceUnit.work) return
    console.info(`[KomaReaderLab] chapter_boundary direction=${direction} source=${sourceUnit.unit} target=${target.unit}`)
    const source = sourceUnit.copy()
    const cancellation = new ReaderCancellation()
    this.chapterRequest = cancellation
    this.chapterBusy = true
    this.getUIContext().getPromptAction().showToast({ message: $r('app.string.manga_detail_loading_source') })
    const isCurrent = (): boolean => this.chapterRequest === cancellation && !cancellation.isCancelled() &&
      !this.readerClosed && this.routeActive && this.labVisibility.foreground && this.session === session &&
      session.snapshot().unit?.key.equals(source) === true
    try {
      await this.runChapterPreparationProbe(cancellation)
      await adapter.prepare(target, cancellation)
      if (!isCurrent()) return
      await session.open(target)
      const opened = session.snapshot()
      if (!cancellation.isCancelled() && !this.readerClosed && opened.phase === 'ready' &&
        opened.unit?.key.equals(target) === true) {
        console.info(`[KomaReaderLab] chapter_opened direction=${direction} unit=${target.unit}`)
      }
    } catch (_error) {
      if (isCurrent()) {
        console.warn(`[KomaReaderLab] chapter_failed direction=${direction} source=${source.unit} target=${target.unit}`)
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.manga_detail_chapter_pages_load_failed') })
      } else if (cancellation.isCancelled()) {
        console.info(`[KomaReaderLab] chapter_cancelled direction=${direction} source=${source.unit} target=${target.unit}`)
      }
    } finally {
      if (this.chapterRequest === cancellation) {
        this.chapterRequest = null
        this.chapterBusy = false
      }
    }
  }

  private onObservedPosition(position: ReaderObservedPosition): void {
    const session = this.session
    if (!this.request.progressReadWrite || session === null || this.readerClosed || !this.routeActive ||
      !this.labVisibility.foreground) return
    const snapshot = session.snapshot()
    if (snapshot.phase !== 'ready' || snapshot.unit === null ||
      !snapshot.unit.key.equals(position.anchor.unit)) return
    this.persistObserved(position, snapshot.policy.firstPageAlone ? 'even_left' : 'odd_left')
  }

  private enqueuePreferenceWrite(next: ReaderPreferences): void {
    const store = this.preferencesStore
    if (store === null) return
    this.hostPreferences = next
    this.preferenceWrites = this.preferenceWrites.then(async (): Promise<void> => {
      await store.save(next)
    }).catch((): void => {
      console.warn('[KomaReaderLab] preference_persist_failed')
    })
  }

  private onPolicyChanged(policy: ReaderDisplayPolicy): void {
    const current = this.hostPreferences
    if (!this.request.preferencesReadWrite || current === null || this.readerClosed || !this.routeActive ||
      !this.labVisibility.foreground || this.session === null) return
    this.enqueuePreferenceWrite(KomaReaderPreferenceBridge.applyPolicy(current, policy))
  }

  private onCropChanged(enabled: boolean): void {
    const current = this.hostPreferences
    if (!this.request.preferencesReadWrite || current === null || this.readerClosed || !this.routeActive ||
      !this.labVisibility.foreground || this.session === null) return
    this.enqueuePreferenceWrite(KomaReaderPreferenceBridge.applyCrop(current, enabled))
  }

  private openHostSettings(): void {
    if (!this.request.preferencesReadWrite || this.hostPreferences === null || this.readerClosed ||
      !this.routeActive || !this.labVisibility.foreground || this.session === null) return
    this.readerSettingsSheetShown = true
    this.syncKeepScreenOn()
    this.syncVolumeKeys()
  }

  private closeHostSettings(): void {
    this.readerSettingsSheetShown = false
    this.syncKeepScreenOn()
    this.syncVolumeKeys()
  }

  private currentReaderMode(): ReaderMode {
    const mode = this.hostPreferences?.pageMode ?? this.readerMode.pageMode
    if (mode === 'double_page') return ReaderMode.DUAL_PAGE
    if (mode === 'vertical_page') return ReaderMode.VERTICAL_PAGE
    if (mode === 'continuous_scroll') return ReaderMode.CONTINUOUS_SCROLL
    return ReaderMode.SINGLE_PAGE
  }

  private onHostPreferencesChanged(next: ReaderPreferences): void {
    const session = this.session
    if (!this.request.preferencesReadWrite || session === null || this.readerClosed || !this.routeActive ||
      !this.labVisibility.foreground) return
    const previous = this.hostPreferences
    this.hostPreferences = next
    if (previous !== null && (previous.tapZonePreset !== next.tapZonePreset ||
      previous.tapZoneInvert !== next.tapZoneInvert)) this.tapZonePreviewRevision += 1
    session.setPolicy(KomaReaderInitialPolicy.resolveHost(next, next.columnMode))
    this.enqueuePreferenceWrite(next)
    this.syncKeepScreenOn()
    this.syncVolumeKeys()
  }

  private readerCanvasBackground(): ResourceColor {
    const mode = this.hostPreferences?.backgroundMode ?? this.readerMode.backgroundMode
    if (mode === 'gray') return ThemeConstants.READER_BACKGROUND_GRAY
    if (mode === 'white') return ThemeConstants.READER_BACKGROUND_WHITE
    if (mode === 'auto') return ThemeConstants.BG_PRIMARY
    return ThemeConstants.READER_BACKGROUND_BLACK
  }

  private readerCanvasForeground(): ResourceColor {
    const mode = this.hostPreferences?.backgroundMode ?? this.readerMode.backgroundMode
    if (mode === 'black') return ThemeConstants.READER_FOREGROUND_LIGHT
    if (mode === 'auto') return ThemeConstants.TEXT_PRIMARY
    return ThemeConstants.READER_FOREGROUND_DARK
  }

  /** Preserve Koma's existing spacing scale while reader-kit owns only layout. */
  private readerPageGap(): number {
    const mode = this.hostPreferences?.pageGapMode ?? this.readerMode.pageGapMode
    if (mode === 'compact') return 2
    if (mode === 'wide') return 18
    return 8
  }

  private sharedTapZoneAction(action: string): ReaderTapAction {
    if (action === 'previous' || action === 'next' || action === 'left' || action === 'right') return action
    return 'menu'
  }

  private sharedTapZonePreviewRegions(): ReaderTapZonePreviewRegion[] {
    const preferences = this.hostPreferences
    if (preferences === null) return []
    return readerTapZoneRegions(
      normalizeReaderTapZonePreset(preferences.tapZonePreset),
      normalizeReaderTapZoneInvert(preferences.tapZoneInvert),
    ).map((region): ReaderTapZonePreviewRegion => new ReaderTapZonePreviewRegion(
      this.sharedTapZoneAction(region.action), region.left, region.top, region.right, region.bottom))
  }

  @Builder
  private ReaderHostSettingsSheet() {
    if (this.hostPreferences !== null) {
      ReaderSettingsContent({
        readerMode: this.currentReaderMode(),
        preferences: this.hostPreferences,
        onPreferencesChange: (next: ReaderPreferences): void => { this.onHostPreferencesChanged(next) },
        onClose: (): void => { this.closeHostSettings() },
        onRevealTapZones: (): void => { this.closeHostSettings() },
      })
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.session !== null) {
          if (this.request.readingChrome) {
            ReaderSurface({ session: this.session, initialUnit: this.unitKey, initialIndex: this.initialPageIndex,
              imageInterpolation: (this.hostPreferences?.imageScalingQuality ?? this.readerMode.imageScalingQuality) === 'low'
                ? ImageInterpolation.Low :
                (this.hostPreferences?.imageScalingQuality ?? this.readerMode.imageScalingQuality) === 'high'
                  ? ImageInterpolation.High : ImageInterpolation.Medium,
              canvasBackground: this.readerCanvasBackground(), canvasForeground: this.readerCanvasForeground(),
              input: this.input, imageShare: this.imageShare, imageSave: this.imageSave,
              tapZoneResolver: (x: number, y: number, layout: ReaderLayout): ReaderTapAction => this.resolveTapZone(x, y, layout),
              tapZonePreviewRegions: this.sharedTapZonePreviewRegions(),
              tapZonePreviewRevision: this.tapZonePreviewRevision,
              autoReadAvailable: true,
              autoReadSeconds: this.hostPreferences?.autoPageSeconds ?? this.readerMode.autoPageSeconds,
              pageTurnAnimation: this.request.pageTurnAnimationOverride ??
                (this.hostPreferences?.pageTurnAnimation ?? this.readerMode.pageTurnAnimation),
              pageGap: this.readerPageGap(),
              preloadDepth: this.hostPreferences?.preloadPages ?? this.readerMode.preloadPages,
              cropBorders: this.hostPreferences?.trimPageMarginsEnabled ?? this.readerMode.trimPageMarginsEnabled,
              cropAvailable: true,
              hostSettingsAvailable: this.request.preferencesReadWrite,
              onHostSettings: (): void => { this.openHostSettings() },
              active: this.routeActive && this.labVisibility.foreground && !this.readerSettingsSheetShown,
              chapterNavigationAvailable: true, chapterNavigationBusy: this.chapterBusy,
              showPageNumber: this.hostPreferences?.showPageNumber ?? this.readerMode.showPageNumber,
              onObservedPosition: (position: ReaderObservedPosition): void => {
                this.onObservedPosition(position)
              },
              onPolicyChanged: (policy: ReaderDisplayPolicy): void => { this.onPolicyChanged(policy) },
              onCropChanged: (enabled: boolean): void => { this.onCropChanged(enabled) },
              onChapter: (direction: 'previous' | 'next', sourceUnit: ReaderUnitKey): void => {
                void this.switchChapter(direction, sourceUnit)
              },
              topInset: this.safeArea.topAvoidHeight, bottomInset: this.safeArea.bottomAvoidHeight,
              accent: ThemeConstants.BRAND_PRIMARY, onClose: (): void => { this.closeReader() } })
          } else {
            ReaderLabSurface({ session: this.session, initialUnit: this.unitKey, initialIndex: this.request.pageIndex,
              preloadDepth: this.readerMode.preloadPages,
              active: this.routeActive && this.labVisibility.foreground })
          }
        } else {
          Text(this.error)
        }
      }
      .width('100%').height('100%')
      .padding({ top: this.request.readingChrome && this.session !== null ? 0 : this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT,
        bottom: this.request.readingChrome && this.session !== null ? 0 : this.safeArea.bottomAvoidHeight })
      .bindSheet($$this.readerSettingsSheetShown, this.ReaderHostSettingsSheet, {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        showClose: false,
        enableOutsideInteractive: false,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        enableFloatingDragBar: true,
        onDisappear: (): void => { this.closeHostSettings() },
      })
    }.titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      content: { title: { mainTitle: $r('app.string.rkit_lab_title') } },
    })
    .hideTitleBar(this.request.readingChrome && this.session !== null)
    .onBackPressed((): boolean => {
      if (!this.request.readingChrome) return false
      this.closeReader()
      return true
    })
    .onShown((): void => { this.routeActive = true })
    .onHidden((): void => { this.routeActive = false })
  }
}

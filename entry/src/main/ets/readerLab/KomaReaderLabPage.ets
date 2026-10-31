import { connectReaderDisplayPreview, ReaderDisplayPreviewState } from '../state/ReaderDisplayPreviewState'
import { komaReaderImageEffects } from './KomaReaderDisplayEffects'
import { util } from '@kit.ArkTS'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { KomaReaderTranslationConfiguration, KomaReaderTranslationProvider } from './KomaReaderTranslationProvider'
import { KomaTranslationSettings, KomaTranslationSettingsSnapshot, KomaTranslationSettingsState, connectKomaTranslationSettings } from '../readerTranslation/KomaTranslationSettings'
import { komaSheetOptions } from '../theme/KomaPopupOptions'
import { Binding, FrameCallback, LengthMetrics } from '@kit.ArkUI'
import { ReaderTitleContent } from '../components/ReaderTitleContent'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { ReaderDirectionControl, ReaderDirectionChoice } from '../components/ReaderDirectionControl'
import { ReadingDirection } from '../model/ComicModels'
import { common } from '@kit.AbilityKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { ReaderCancellation, ReaderDisplayPolicy, ReaderImageSaveHost, ReaderImageShareHost, ReaderInputPort,
  ReaderObservedPosition, ReaderPagedSession, ReaderUnitKey, ReaderLayout, ReaderVariantPreference, ReaderAsset, ReaderPage, ReaderPagedFrame,
  ReaderProcessingState } from '@reader-kit/core'
import { ReaderActivitySink, ReaderAutoReadPolicy, ReaderCenterAction, ReaderCropPolicy, ReaderChapterNavigation, ReaderHostAction, ReaderHostSettings, ReaderObservationSink, ReaderPreferenceSink, ReaderHostActions, ReaderMediaActions, ReaderKeepScreenOn, ReaderLabRequest, ReaderLabSurface, ReaderSurface, ReaderTrialLayoutCommit, ReaderTrialWindow,
  ReaderLabVisibilityState, ReaderSystemImageSaveHost, ReaderVolumeKeys, connectReaderLabVisibility, ReaderTapAction,
  ReaderTapZonePreviewRegion, ReaderModeControlParams, ReaderTitleParams, ReaderChromeAppearance, ReaderRouteTransition, ReaderVariantPolicy, ReaderTemporaryVariantControl, ReaderHostStatus } from '@reader-kit/ui'
import { KomaReaderLabAdapter, KomaReaderLabChapterChoice } from './KomaReaderLabAdapter'
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
import { KomaModalScaffold } from '../components/KomaModalScaffold'
import { ConciseListRow } from '../components/ui/ConciseListRow'
import { AppStrings } from '../i18n/AppStrings'
import { KomaReaderCatalogHost } from './KomaReaderCatalogHost'
import { KomaReaderSuperResolutionConfiguration, KomaReaderSuperResolutionProvider } from './KomaReaderSuperResolutionProvider'
import { readerSuperResolutionSetInteractionPaused } from '../model/ReaderSuperResolutionService'
import { ReaderPreloadNetworkMonitor, readerRemotePreloadAllowed } from '../model/ReaderPreloadNetwork'

// A surface keeps one non-null session for its whole component lifetime.
// Re-entry replaces the entry, rather than updating a mounted surface to null.
class KomaReaderSessionEntry {
  readonly id: number
  readonly session: ReaderPagedSession
  readonly unit: ReaderUnitKey
  readonly initialIndex: number

  constructor(id: number, session: ReaderPagedSession, unit: ReaderUnitKey, initialIndex: number) {
    this.id = id
    this.session = session
    this.unit = unit
    this.initialIndex = initialIndex
  }
}

// Run after native list layout, without a guessed sheet-animation delay.
class KomaReaderAfterLayout extends FrameCallback {
  private observe: () => void
  constructor(observe: () => void) { super(); this.observe = observe }
  onIdle(_timeLeftInNano: number): void { this.observe() }
}

@ComponentV2
export struct KomaReaderLabPage {
  @Local private displayPreview: ReaderDisplayPreviewState = connectReaderDisplayPreview()
  @Require @Param request: ReaderLabRequest
  @Param productionEntry: boolean = false
  @Param routeTransition: ReaderRouteTransition = new ReaderRouteTransition()
  @Param closeRequestId: number = 0
  @Event prepareInitial: () => Promise<void> = async (): Promise<void> => {}
  @Event onRouteVisibleChange: (visible: boolean) => void = (_visible: boolean) => {}
  @Event onRouteDisappear: () => void = () => {}
  @Local private seriesOverrideActive: boolean = false
  // Original Koma ReaderChrome geometry and action placement. The counter
  // sides follow RTL together with the reversed slider; leaving them fixed
  // made the neighbouring page numbers disagree with the track direction.
  private chromeAppearance: ReaderChromeAppearance = {
    bottomHeight: 104, sliderHeight: 32, controlsHeight: 52,
    controlsPadding: ThemeConstants.SPACE_LG, columnSpacing: 0,
    topActionSpacing: ThemeConstants.SPACE_XS, fixedCounterSides: false, mediaActionsInMenu: true,
    spreadControlsLeading: true,
  }
  @Local private translationSettings: KomaTranslationSettingsSnapshot = new KomaTranslationSettingsSnapshot()
  @Local private translationState: KomaTranslationSettingsState = connectKomaTranslationSettings()
  @Local private translationAutoEnabled: boolean = false
  @Local private translationCurrentIndex: number = -1
  @Local private translationRequestedPages: number[] = []
  @Local private translationHiddenPages: number[] = []
  @Local private translationAutoFailedPages: number[] = []
  @Local private translationBusyPage: number = -1
  @Local private translationErrorPage: number = -1
  @Local private translationRevision: number = 0
  private translationUnit: ReaderUnitKey | null = null
  private translationProjectId: string = ''
  private translationSettingsGeneration: number = 0
  private translationProvider: KomaReaderTranslationProvider | null = null
  private enhancementInteractionTimer: number = -1
  private observedCloseRequestId: number = 0

  @Event readInitialColumn: (work: string, unit: string) => ReaderColumnMode = () => {
    throw new Error('reader_lab_progress_owner_unavailable')
  }
  @Event readInitialPage: (work: string, unit: string) => number = () => {
    throw new Error('reader_lab_progress_owner_unavailable')
  }
  @Event persistObserved: (position: ReaderObservedPosition, column: ReaderColumnMode) => void = () => {}
  @Event observeReadingPages: (work: string, chapter: string, pages: number[]) => void = () => {}
  @Event flushObserved: () => void = () => {}
  @Event onOpenMangaDetail: (work: string) => void = () => {}
  @Event onClose: () => void = () => {}
  @Param catalogHost: KomaReaderCatalogHost | null = null
  @Local private session: ReaderPagedSession | null = null
  @Local private surfaceEntries: KomaReaderSessionEntry[] = []
  private surfaceGeneration: number = 0
  @Local private labVisibility: ReaderLabVisibilityState = connectReaderLabVisibility()
  @Local private routeActive: boolean = false
  @Local private preloadNetworkWifi: boolean = false
  private preloadNetworkMonitor: ReaderPreloadNetworkMonitor | null = null
  @Local private safeArea: LayoutSafeAreaState = connectLayoutSafeArea()
  @Local private error: string = ''
  @Local private chapterBusy: boolean = false
  @Local private readerMode: ReaderModeState = connectReaderModeState()
  @Local private readerSettingsSheetShown: boolean = false
  @Local private hostPreferences: ReaderPreferences | null = null
  @Local private tapZonePreviewRevision: number = 0
  @Local private chapterPickerShown: boolean = false
  @Local private chapterChoices: KomaReaderLabChapterChoice[] = []
  @Local private currentChapterUnit: string = ''
  private unitKey: ReaderUnitKey = new ReaderUnitKey('', '', '')
  private initialPageIndex: number = 0
  private trialWindow: ReaderTrialWindow = new ReaderTrialWindow(null, true,
    undefined, (): boolean => !this.readerClosed && this.routeActive && this.labVisibility.foreground && this.routeTransition.ready())
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
  private chapterPickerTarget: ReaderUnitKey | null = null
  private chapterChoiceIdentity: string = ''
  private observedCatalogUnit: ReaderUnitKey | null = null
  private observedSourceSignature: string = ''
  private chapterPickerScroller: ListScroller = new ListScroller()
  private hostActionDispatch: ReaderHostActions = new ReaderHostActions(
    [new ReaderHostAction('manga-detail', AppStrings.get('reader_action_return_to_detail'))],
    (id: string, source: ReaderUnitKey, navigation: number, sourceIndex: number): void => {
      this.openMangaDetail(id, source, navigation, sourceIndex)
    })

  private chapterPickerSavedUnit: string = ''
  private chapterPickerSavedCatalog: string = ''
  private chapterPickerVisibleIndex: number = 0
  private chapterPickerFirstIndex: number = 0
  private chapterPickerFirstY: number = 0
  private chapterPickerPositionReady: boolean = false
  private chapterPickerOpening: boolean = false
  private chapterPickerLayoutRevision: number = 0

  private hasChapterPickerPosition(): boolean {
    return this.chapterPickerSavedUnit === this.currentChapterUnit &&
      this.chapterPickerSavedCatalog === this.chapterChoiceIdentity
  }

  private chapterPickerInitialIndex(): number {
    if (this.hasChapterPickerPosition()) return this.chapterPickerFirstIndex
    return Math.max(0, this.chapterChoices.findIndex((choice: KomaReaderLabChapterChoice): boolean =>
      choice.key.unit === this.currentChapterUnit))
  }

  private restoreChapterPickerPosition(): void {
    this.chapterPickerPositionReady = false
    this.chapterPickerVisibleIndex = this.chapterPickerInitialIndex()
    const unit = this.currentChapterUnit
    const catalog = this.chapterChoiceIdentity
    const restore = this.hasChapterPickerPosition()
    const index = this.chapterPickerInitialIndex()
    const y = restore ? this.chapterPickerFirstY : 0
    const revision = ++this.chapterPickerLayoutRevision
    this.getUIContext().postFrameCallback(new KomaReaderAfterLayout((): void => {
      if (revision !== this.chapterPickerLayoutRevision || !this.chapterPickerShown || this.readerClosed ||
        unit !== this.currentChapterUnit || catalog !== this.chapterChoiceIdentity) return
      this.chapterPickerScroller.scrollToIndex(index, false, ScrollAlign.START,
        { extraOffset: LengthMetrics.vp(-y) })
      this.getUIContext().postFrameCallback(new KomaReaderAfterLayout((): void => {
        if (revision !== this.chapterPickerLayoutRevision || !this.chapterPickerShown || this.readerClosed ||
          unit !== this.currentChapterUnit || catalog !== this.chapterChoiceIdentity) return
        // Native START alignment includes List content padding. Correct from
        // the measured row position rather than baking that padding into math.
        const rect = this.chapterPickerScroller.getItemRect(index)
        if (restore && rect.height > 0) this.chapterPickerScroller.scrollBy(0, rect.y - y)
        this.chapterPickerPositionReady = !this.chapterPickerOpening
      }))
    }))
  }

  private rememberChapterPickerPosition(index: number): void {
    if (!this.chapterPickerShown || !this.chapterPickerPositionReady || index < 0) return
    const rect = this.chapterPickerScroller.getItemRect(index)
    if (rect.height <= 0) return
    this.chapterPickerSavedUnit = this.currentChapterUnit
    this.chapterPickerSavedCatalog = this.chapterChoiceIdentity
    this.chapterPickerFirstIndex = index
    this.chapterPickerFirstY = rect.y
  }

  private readerPreloadDepth(): number {
    const depth = this.hostPreferences?.preloadPages ?? this.readerMode.preloadPages
    const unit = this.session?.snapshot().unit?.key
    const remote = unit === undefined || this.adapter?.unitUsesRemoteImages(unit) === true
    const wifiOnly = this.hostPreferences?.preloadWifiOnly ?? this.readerMode.preloadWifiOnly
    return wifiOnly && !this.preloadNetworkWifi && remote ? 0 : depth
  }

  aboutToAppear(): void {
    this.preloadNetworkMonitor = new ReaderPreloadNetworkMonitor((wifi: boolean): void => {
      this.preloadNetworkWifi = wifi
      this.session?.setPreloadDepth(this.readerPreloadDepth())
    })
    this.initializeReader()
  }

  @Monitor('request')
  private onEntryRequestChanged(): void {
    if (!this.productionEntry) return
    this.initialization?.cancel()
    this.session?.close()
    this.adapter?.close()
    this.cancelChapterRequest()
    this.readerSettingsSheetShown = false
    this.chapterPickerShown = false
    this.initializeReader()
  }

  @Monitor('closeRequestId')
  private onExternalCloseRequest(): void {
    if (!this.productionEntry || this.closeRequestId === this.observedCloseRequestId) return
    this.observedCloseRequestId = this.closeRequestId
    this.closeReader()
  }

  private initializeReader(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!this.productionEntry && !context.applicationInfo.debug) return
    this.observedCloseRequestId = this.closeRequestId
    this.error = ''
    this.seriesOverrideActive = false
    this.observedCatalogUnit = null
    this.observedSourceSignature = ''
    this.initialization?.cancel()
    this.surfaceEntries = []
    if (this.request.readingChrome) this.session = null
    this.readerClosed = false
    // A replaced entry is a new reading session, even when this component is retained.
    this.translationAutoEnabled = false
    this.translationRequestedPages = []
    this.translationHiddenPages = []
    this.translationAutoFailedPages = []
    this.translationBusyPage = -1
    this.translationErrorPage = -1
    this.translationCurrentIndex = -1
    this.translationUnit = null
    this.translationProjectId = ''
    this.translationRevision += 1
    void this.reloadTranslationSettings()
    try {
      const adapter = new KomaReaderLabAdapter(context.filesDir, context.cacheDir, this.catalogHost, context, this.productionEntry,
        (): string => this.hostPreferences?.cropStrength ?? 'standard',
        (): boolean => readerRemotePreloadAllowed(this.hostPreferences?.preloadWifiOnly === true))
      this.adapter = adapter
      this.imageSave = new ReaderSystemImageSaveHost(context)
      this.imageShare = new KomaReaderLabImageShareHost(context, adapter)
      this.unitKey = adapter.initialKey(this.request.work, this.request.unit)
      this.initialPageIndex = this.request.pageIndex
      const enhancement = new KomaReaderSuperResolutionProvider(context, adapter,
        (): KomaReaderSuperResolutionConfiguration => this.superResolutionConfiguration(),
        (): string => this.hostPreferences?.cropStrength ?? 'standard',
        undefined, (page: ReaderPage, cancellation: ReaderCancellation): Promise<ReaderAsset> =>
          adapter.load(page, 'original', cancellation, false))
      const translation = new KomaReaderTranslationProvider(context, enhancement,
        (page: ReaderPage): KomaReaderTranslationConfiguration => this.translationConfiguration(page),
        (): string => this.hostPreferences?.cropStrength ?? 'standard', undefined,
        (page: ReaderPage, cancellation: ReaderCancellation): Promise<ReaderAsset> => adapter.load(page, 'original', cancellation, false))
      this.translationProvider = translation
      const session = new ReaderPagedSession(adapter, translation, adapter, adapter)
      adapter.onSequenceReady = (): void => { session.refreshAdjacency() }
      if (this.request.readingChrome) {
        this.trialWindow.open(context)
        this.keepScreenOn = new ReaderKeepScreenOn(context)
        void this.initializeSession(context, session)
      } else {
        this.session = session
        this.surfaceEntries = [new KomaReaderSessionEntry(++this.surfaceGeneration, session,
          this.unitKey.copy(), this.initialPageIndex)]
      }
    } catch (_error) {
      DiagnosticLogger.warn('reader', 'initialize_failed', 'reason=library_unavailable')
      this.error = 'reader_lab_library_unavailable'
    }
  }

  private async initializeSession(context: common.UIAbilityContext, session: ReaderPagedSession): Promise<void> {
    const cancellation = new ReaderCancellation()
    this.initialization?.cancel()
    this.initialization = cancellation
    try {
      if (this.productionEntry) await this.prepareInitial()
      if (cancellation.isCancelled() || this.readerClosed) return
      const preferencesStore = new ReaderPreferencesStore(context)
      const preferences = this.productionEntry
        ? await preferencesStore.loadForComic(this.unitKey.work) : await preferencesStore.load()
      if (this.productionEntry) {
        this.seriesOverrideActive = await preferencesStore.seriesModeOverride(this.unitKey.work) !== undefined
      }
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
      this.surfaceEntries = [new KomaReaderSessionEntry(++this.surfaceGeneration, session,
        this.unitKey.copy(), this.initialPageIndex)]
      this.syncKeepScreenOn()
      this.syncVolumeKeys()
    } catch (_error) {
      if (cancellation.isCancelled() || this.readerClosed) return
      DiagnosticLogger.warn('reader', 'initial_policy_unavailable', '[KomaReaderLab] initial_policy_unavailable')
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

  /** Koma owns fullscreen preference semantics; reader-kit only sequences the window lease. */


  aboutToDisappear(): void {
    this.preloadNetworkMonitor?.dispose()
    this.preloadNetworkMonitor = null
    this.releaseEnhancementInteraction()
    this.translationAutoEnabled = false
    this.translationSettingsGeneration += 1
    this.readerClosed = true
    this.readerSettingsSheetShown = false
    this.chapterPickerShown = false
    this.chapterPickerTarget = null
    this.initialization?.cancel()
    this.volumeKeys.close()
    this.cancelChapterRequest()
    this.adapter?.close()
    void this.keepScreenOn?.close()
    if (this.request.readingChrome) this.trialWindow.close()
  }

  @Monitor('routeTransition.phase')
  private replayRouteWindowAdmission(): void {
    if (!this.readerClosed && this.routeActive && this.labVisibility.foreground && this.routeTransition.ready()) {
      // open() retires its started flag while the root transition is pending.
      // Re-admit that same lease; replay alone would remain blocked by it.
      this.trialWindow.open(this.getUIContext().getHostContext() as common.UIAbilityContext)
    }
  }

  @Monitor('routeActive', 'labVisibility.foreground', 'readerMode.hydrated', 'readerMode.keepScreenAwake',
    'readerSettingsSheetShown', 'chapterPickerShown')
  syncKeepScreenOn(): void {
    this.keepScreenOn?.setActive(this.request.readingChrome && this.session !== null && this.routeActive &&
      this.labVisibility.foreground && this.readerMode.hydrated && !this.readerSettingsSheetShown && !this.chapterPickerShown &&
      (this.hostPreferences?.keepScreenAwake ?? this.readerMode.keepScreenAwake))
  }

  private closeReader(): void {
    this.releaseEnhancementInteraction()
    this.translationAutoEnabled = false
    this.translationSettingsGeneration += 1
    this.readerClosed = true
    this.readerSettingsSheetShown = false
    this.chapterPickerShown = false
    this.chapterPickerTarget = null
    this.initialization?.cancel()
    this.volumeKeys.close()
    this.cancelChapterRequest()
    void this.keepScreenOn?.close()
    if (this.request.progressReadWrite) this.flushObserved()
    if (this.productionEntry) {
      void this.preferenceWrites.then(async (): Promise<void> => {
        await this.trialWindow.close()
        this.onClose()
      })
    } else {
      this.onClose()
    }
  }

  @Monitor('routeActive', 'labVisibility.foreground', 'readerMode.hydrated',
    'readerMode.volumeKeyNavigationEnabled', 'readerMode.volumeKeyBehavior', 'readerSettingsSheetShown',
    'chapterPickerShown', 'session')
  syncVolumeKeys(): void {
    const enabled = this.request.volumeKeysOverride ??
      (this.hostPreferences?.volumeKeyNavigationEnabled ?? this.readerMode.volumeKeyNavigationEnabled)
    this.volumeKeys.setActive(!this.readerClosed && this.request.readingChrome && this.session !== null &&
      this.routeActive && this.labVisibility.foreground && this.readerMode.hydrated &&
      !this.readerSettingsSheetShown && !this.chapterPickerShown && enabled,
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
    DiagnosticLogger.info('reader', 'chapter_probe', `[KomaReaderLab] chapter_probe kind=${this.request.chapterProbe}`)
    if (this.request.chapterProbe === 'prepare-fail-once') throw new Error('reader_lab_chapter_prepare_probe')
    await new Promise<void>((resolve): void => { setTimeout(resolve, 3000) })
    cancellation.check()
  }

  private async openChapterTarget(target: ReaderUnitKey, sourceUnit: ReaderUnitKey,
    reason: 'previous' | 'next' | 'picker'): Promise<void> {
    const session = this.session
    const adapter = this.adapter
    if (session === null || adapter === null || this.readerClosed || target.equals(sourceUnit) ||
      !this.routeActive || !this.labVisibility.foreground) return
    const current = session.snapshot()
    if (current.phase !== 'ready' || current.unit === null || !current.unit.key.equals(sourceUnit)) return
    if (target.scope !== sourceUnit.scope || target.work !== sourceUnit.work) return
    this.chapterRequest?.cancel()
    DiagnosticLogger.info('reader', 'chapter_boundary', `[KomaReaderLab] chapter_boundary direction=${reason}`)
    const source = sourceUnit.copy()
    const cancellation = new ReaderCancellation()
    this.chapterRequest = cancellation
    this.chapterBusy = true
    if (!adapter.chapterPrepared(target)) {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.manga_detail_loading_source') })
    }
    const isCurrent = (): boolean => this.chapterRequest === cancellation && !cancellation.isCancelled() &&
      !this.readerClosed && this.routeActive && this.labVisibility.foreground && this.session === session &&
      session.snapshot().unit?.key.equals(source) === true
    try {
      await this.runChapterPreparationProbe(cancellation)
      const prepared = await adapter.prepare(target, cancellation)
      if (!isCurrent()) return
      // Backward continuation enters the prepared chapter at its real final page.
      // Forward continuation and explicit picker selection retain their first-page rule.
      await session.open(target, reason === 'previous' ? prepared.pageCount - 1 : 0)
      const opened = session.snapshot()
      if (!cancellation.isCancelled() && !this.readerClosed && opened.phase === 'ready' &&
        opened.unit?.key.equals(target) === true && this.chapterRequest === cancellation &&
        this.session === session && this.routeActive && this.labVisibility.foreground) {
        this.syncChapterChoices(target)
        const title = adapter.chapterTitle(target).trim()
        if (reason !== 'picker' && title.length > 0) {
          this.getUIContext().getPromptAction().showToast({ message: title })
        }
        DiagnosticLogger.info('reader', 'chapter_opened', `[KomaReaderLab] chapter_opened direction=${reason}`)
      }
    } catch (_error) {
      if (isCurrent()) {
        DiagnosticLogger.warn('reader', 'chapter_failed', `[KomaReaderLab] chapter_failed direction=${reason}`)
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.manga_detail_chapter_pages_load_failed') })
      } else if (cancellation.isCancelled()) {
        DiagnosticLogger.info('reader', 'chapter_cancelled', `[KomaReaderLab] chapter_cancelled direction=${reason}`)
      }
    } finally {
      if (this.chapterRequest === cancellation) {
        this.chapterRequest = null
        this.chapterBusy = false
      }
    }
  }

  private async switchChapter(direction: 'previous' | 'next', sourceUnit: ReaderUnitKey): Promise<void> {
    const session = this.session
    const adapter = this.adapter
    if (session === null || adapter === null || this.chapterBusy) return
    const current = session.snapshot()
    if (current.phase !== 'ready' || current.unit === null || !current.unit.key.equals(sourceUnit)) return
    const target = adapter.adjacent(current.unit, direction)
    if (target !== null) await this.openChapterTarget(target, sourceUnit, direction)
  }

  private syncChapterChoices(unit: ReaderUnitKey): void {
    const choices = this.adapter?.chapterChoices(unit) ?? []
    const identity = JSON.stringify(choices.map((choice: KomaReaderLabChapterChoice): string =>
      `${choice.key.scope}:${choice.key.work}:${choice.key.unit}:${choice.title}`))
    if (identity !== this.chapterChoiceIdentity) {
      this.chapterChoiceIdentity = identity
      this.chapterChoices = choices
    }
    this.currentChapterUnit = unit.unit
  }

  private chapterControlLabel(): string {
    const index = this.chapterChoices.findIndex((choice: KomaReaderLabChapterChoice): boolean =>
      choice.key.unit === this.currentChapterUnit)
    const title = AppStrings.get('reader_control_chapter')
    return index < 0 ? title : `${title} ${index + 1} / ${this.chapterChoices.length}`
  }

  private chapterPickerTitle(choice: KomaReaderLabChapterChoice, index: number): string {
    const title = choice.title.trim()
    return title.length > 0 ? title : `${AppStrings.get('reader_control_chapter')} ${index + 1}`
  }

  private openMangaDetail(id: string, source: ReaderUnitKey, navigation: number, sourceIndex: number): void {
    const snapshot = this.session?.snapshot()
    if (id !== 'manga-detail' || snapshot?.phase !== 'ready' || snapshot.unit === null ||
      !snapshot.unit.key.equals(source) || snapshot.navigationRevision !== navigation ||
      snapshot.anchor?.sourceIndexHint !== sourceIndex) return
    this.onOpenMangaDetail(source.work)
  }

  private openChapterPicker(source: ReaderUnitKey, navigation: number): void {
    const snapshot = this.session?.snapshot()
    if (snapshot?.phase !== 'ready' || snapshot.unit === null || !snapshot.unit.key.equals(source) ||
      snapshot.navigationRevision !== navigation) return
    this.syncChapterChoices(source)
    if (this.chapterChoices.length > 0) {
      // The new List can report its initial index before onAppear. Keep that
      // layout from overwriting the retained position before restoration.
      this.chapterPickerPositionReady = false
      this.chapterPickerOpening = true
      this.chapterPickerShown = true
      this.syncKeepScreenOn()
      this.syncVolumeKeys()
    }
  }

  private selectChapterFromPicker(choice: KomaReaderLabChapterChoice): void {
    this.chapterPickerTarget = choice.key.copy()
    this.chapterPickerShown = false
  }

  private finishChapterPickerDismissal(): void {
    this.chapterPickerPositionReady = false
    this.chapterPickerOpening = false
    this.chapterPickerLayoutRevision++
    const target = this.chapterPickerTarget
    this.chapterPickerTarget = null
    this.chapterPickerShown = false
    this.syncKeepScreenOn()
    this.syncVolumeKeys()
    const snapshot = this.session?.snapshot()
    if (target !== null && snapshot?.phase === 'ready' && snapshot.unit !== null &&
      !snapshot.unit.key.equals(target)) {
      void this.openChapterTarget(target, snapshot.unit.key.copy(), 'picker')
    }
  }

  private onObservedPosition(position: ReaderObservedPosition): void {
    const session = this.session
    if (session === null || this.readerClosed || !this.routeActive ||
      !this.labVisibility.foreground) return
    const snapshot = session.snapshot()
    if (snapshot.phase !== 'ready' || snapshot.unit === null ||
      !snapshot.unit.key.equals(position.anchor.unit)) return
    const column = this.hostPreferences?.columnMode ?? 'odd_left'
    const signature = JSON.stringify([position.anchor.unit.scope, position.anchor.unit.work,
      position.anchor.unit.unit, position.anchor.pageKey, position.anchor.sourceIndexHint,
      position.pageCount, position.terminalSourceDisplayed, column])
    // Koma persists source pages, not pixel offsets. Fractional scroll on the
    // same page must not clone/commit its catalog or invalidate the root page.
    if (signature === this.observedSourceSignature) {
      if (this.request.progressReadWrite) this.observeReadingPages(
        position.anchor.unit.work, position.anchor.unit.unit, position.displayedSourceIndexes)
      return
    }
    session.setPreloadDepth(this.readerPreloadDepth())
    if (this.observedCatalogUnit?.equals(position.anchor.unit) !== true) {
      const chapterChanged = this.observedCatalogUnit !== null
      this.syncChapterChoices(position.anchor.unit)
      const config = this.adapter?.sessionConfig(position.anchor.unit) ?? null
      if (config !== null) this.catalogHost?.commit(position.anchor.unit, config)
      this.observedCatalogUnit = position.anchor.unit.copy()
      if (chapterChanged && !this.chapterBusy) {
        const title = this.adapter?.chapterTitle(position.anchor.unit).trim() ?? ''
        if (title.length > 0) this.getUIContext().getPromptAction().showToast({ message: title })
      }
    }
    this.observeTranslationPosition(position)
    this.observedSourceSignature = signature
    if (!this.request.progressReadWrite) return
    // Publish after the host commits the actual chapter. Statistics count every
    // visible original page; the position write still ignores fractional scroll.
    this.observeReadingPages(position.anchor.unit.work, position.anchor.unit.unit, position.displayedSourceIndexes)
    this.persistObserved(position, snapshot.policy.firstPageAlone ? 'even_left' : 'odd_left')
  }

  private enqueuePreferenceWrite(next: ReaderPreferences): void {
    const store = this.preferencesStore
    if (store === null) return
    const previous = this.hostPreferences
    const work = this.unitKey.work
    this.hostPreferences = next
    this.preferenceWrites = this.preferenceWrites.then(async (): Promise<void> => {
      if (this.productionEntry && previous !== null) {
        await store.saveChangesForComic(work, previous, next)
        const override = await store.seriesModeOverride(work)
        if (!this.readerClosed && this.unitKey.work === work) this.seriesOverrideActive = override !== undefined
      } else {
        await store.save(next)
      }
    }).catch((): void => {
      DiagnosticLogger.warn('reader', 'preference_persist_failed', '[KomaReaderLab] preference_persist_failed')
    })
  }

  private onPolicyChanged(policy: ReaderDisplayPolicy): void {
    const current = this.hostPreferences
    if (!this.request.preferencesReadWrite || current === null || this.readerClosed || !this.routeActive ||
      !this.labVisibility.foreground || this.session === null) return
    this.enqueuePreferenceWrite(KomaReaderPreferenceBridge.applyPolicy(current, policy))
  }

  @Builder
  private HostTitleControl(params: Binding<ReaderTitleParams>) {
    ReaderTitleContent({ title: this.adapter?.workTitle(params.value.unitKey ?? this.unitKey) ?? '',
      chapterTitle: this.adapter?.chapterTitle(params.value.unitKey ?? this.unitKey) ?? '',
      pageIndex: params.value.pageIndex, pageTotal: params.value.pageCount })
  }

  @Builder
  private HostModeControl(params: ReaderModeControlParams) {
    ReaderDirectionControl({
      readingMode: params.policy.layout === 'continuous' ? 'continuous' :
        params.policy.pagingAxis === 'vertical' ? 'vertical_page' : params.policy.direction,
      controlEnabled: params.enabled,
      onDirectionChange: (direction: ReaderDirectionChoice): void => {
        const policy = params.policy.copy()
        policy.layout = direction === 'continuous' ? 'continuous' :
          policy.layout === 'spread' ? 'spread' : 'single'
        policy.pagingAxis = direction === 'vertical_page' ? 'vertical' : 'horizontal'
        if (direction === 'vertical_page') policy.layout = 'single'
        if (direction === 'rtl' || direction === 'ltr') policy.direction = direction
        params.onChange(policy)
      },
      onMenuVisible: (visible: boolean): void => { params.onMenuVisible(visible) },
    })
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

  @Monitor('translationState.revision')
  private translationSettingsChanged(): void {
    if (!this.readerClosed && this.translationState.revision !== this.translationSettings.revision) {
      void this.reloadTranslationSettings()
    }
  }

  private async reloadTranslationSettings(): Promise<void> {
    const generation = ++this.translationSettingsGeneration
    try {
      const settings = await KomaTranslationSettings.load(this.getUIContext().getHostContext() as common.UIAbilityContext)
      if (this.readerClosed || generation !== this.translationSettingsGeneration) return
      this.translationSettings = settings
      this.translationRequestedPages = []
      this.translationHiddenPages = []
      this.translationAutoFailedPages = []
      this.translationBusyPage = -1
      this.translationErrorPage = -1
      if (!settings.configured()) this.translationAutoEnabled = false
      this.translationRevision += 1
    } catch (_error) {
      // An optional feature's unavailable secure storage must not prevent original-image reading.
      DiagnosticLogger.warn('reader', 'translation_configuration_unavailable', 'configuration_read_failed')
    }
  }

  private observeTranslationPosition(position: ReaderObservedPosition): void {
    const unit = position.anchor.unit
    if (this.translationUnit?.equals(unit) !== true) {
      this.translationUnit = unit.copy()
      this.translationProjectId = this.translationProjectForUnit(unit)
      this.translationRequestedPages = []
      this.translationHiddenPages = []
      this.translationAutoFailedPages = []
      this.translationBusyPage = -1
      this.translationErrorPage = -1
    }
    this.translationCurrentIndex = position.anchor.sourceIndexHint
    const priorFailure = this.session?.snapshot().processingStates.find((value: ReaderProcessingState): boolean =>
      value.sourceIndex === this.translationCurrentIndex && value.preference.variant === 'translated' &&
      value.phase === 'unavailable')
    if (this.translationAutoEnabled && priorFailure !== undefined &&
      !this.translationAutoFailedPages.includes(this.translationCurrentIndex)) {
      // A speculative next-chapter failure belongs to that chapter only once it is actually shown.
      this.translationAutoFailedPages = this.translationAutoFailedPages.concat([this.translationCurrentIndex])
      this.translationBusyPage = -1
      this.translationErrorPage = this.translationCurrentIndex
    } else if (this.translationAutoEnabled && !this.translationAutoFailedPages.includes(this.translationCurrentIndex) &&
      !this.translationHiddenPages.includes(this.translationCurrentIndex) &&
      this.translationFrame(this.translationCurrentIndex)?.asset.variant !== 'translated') {
      this.translationBusyPage = this.translationCurrentIndex
    }
    this.translationRevision += 1
  }

  private translationProjectForUnit(unit: ReaderUnitKey): string {
    const digest = cryptoFramework.createMd('SHA256')
    digest.updateSync({ data: new util.TextEncoder().encodeInto(JSON.stringify([unit.scope, unit.work, unit.unit])) })
    return 'koma:' + Array.from(digest.digestSync().data)
      .map((value: number): string => value.toString(16).padStart(2, '0')).join('')
  }

  private translationConfiguration(page: ReaderPage): KomaReaderTranslationConfiguration {
    const settings = this.translationSettings
    const sameUnit = this.translationUnit?.equals(page.unit) === true
    // Automatic translation may prepare the next verified chapter while the
    // current chapter is still displayed. Manual page choices stay unit-local.
    const futureAutomatic = this.translationAutoEnabled && this.translationUnit !== null &&
      this.translationUnit.scope === page.unit.scope && this.translationUnit.work === page.unit.work
    return new KomaReaderTranslationConfiguration(this.request.preferencesReadWrite && settings.configured() &&
      settings.revision === this.translationState.revision &&
      (sameUnit || futureAutomatic), sameUnit ? this.translationProjectId :
        futureAutomatic ? this.translationProjectForUnit(page.unit) : '',
      settings.targetLanguage, settings.sourceLanguage, settings.revision)
  }

  private translationFrame(sourceIndex: number): ReaderPagedFrame | undefined {
    return this.session?.snapshot().frames.find((frame: ReaderPagedFrame): boolean => frame.part.sourceIndex === sourceIndex)
  }

  private enhancementPreference(): ReaderVariantPreference {
    const enhancement = this.superResolutionConfiguration()
    return enhancement.enabled && enhancement.model !== 'none'
      ? new ReaderVariantPreference('enhanced', enhancement.identity()) : new ReaderVariantPreference()
  }

  private translationPreference(page: ReaderPage, automatic: boolean): ReaderVariantPreference {
    const index = page.sourceIndex
    const sameUnit = this.translationUnit?.equals(page.unit) === true
    // An explicit page request belongs to its current chapter only. A later
    // chapter may inherit the automatic setting, never another chapter's page controls.
    const requested = (sameUnit && this.translationRequestedPages.includes(index)) ||
      (this.translationAutoEnabled && automatic && (!sameUnit || !this.translationAutoFailedPages.includes(index)))
    const identity = this.translationConfiguration(page).identity()
    return requested && (!sameUnit || !this.translationHiddenPages.includes(index)) && identity.length > 0
      ? new ReaderVariantPreference('translated', identity) : this.enhancementPreference()
  }

  private variantPreference(index: number): ReaderVariantPreference {
    const state = this.session?.snapshot()
    const page = this.translationFrame(index)?.asset.page ?? state?.pageMetadata.find(
      (value: ReaderPage): boolean => value.sourceIndex === index)
    return page === undefined || page === null ? this.enhancementPreference() :
      this.translationPreference(page, index === this.translationCurrentIndex)
  }

  private translationPolicy(): ReaderVariantPolicy {
    // Enhancement needs the shared processing lane even without translation:
    // fallback-only policies select visible assets and never warm future pages.
    // Keep disabled/default reading cheap and do not call a translation service
    // merely because it is configured (2026-10-26 user preload regression).
    if (!this.translationSettings.configured() || (!this.translationAutoEnabled &&
      this.translationRequestedPages.length === 0 && this.translationHiddenPages.length === 0)) {
      const enhancement = this.enhancementPreference()
      return enhancement.variant === 'enhanced'
        ? new ReaderVariantPolicy(enhancement, 0, null, null,
          (_page: ReaderPage, _automatic: boolean): ReaderVariantPreference => this.enhancementPreference())
        : new ReaderVariantPolicy(enhancement)
    }
    const unit = this.translationUnit?.copy() ?? null
    const settingsRevision = this.translationSettings.revision
    return new ReaderVariantPolicy(this.enhancementPreference(), this.translationRevision,
      (index: number): ReaderVariantPreference => this.variantPreference(index),
      (index: number, preference: ReaderVariantPreference, result: 'changed' | 'unchanged' | 'unavailable' | 'stale'): void => {
        if (preference.variant !== 'translated' || unit === null || this.translationUnit?.equals(unit) !== true ||
          this.session?.snapshot().unit?.key.equals(unit) !== true ||
          this.translationSettings.revision !== settingsRevision || this.readerClosed || result === 'stale') return
        if (this.translationBusyPage === index) this.translationBusyPage = -1
        if (result === 'changed' || result === 'unchanged') {
          if (!this.translationRequestedPages.includes(index)) this.translationRequestedPages = this.translationRequestedPages.concat([index])
          if (this.translationErrorPage === index) this.translationErrorPage = -1
        } else {
          this.translationRequestedPages = this.translationRequestedPages.filter((value: number): boolean => value !== index)
          if (this.translationAutoEnabled && !this.translationAutoFailedPages.includes(index)) {
            this.translationAutoFailedPages = this.translationAutoFailedPages.concat([index])
          }
          if (index === this.translationCurrentIndex) this.translationErrorPage = index
          this.translationRevision += 1
        }
      }, (page: ReaderPage, automatic: boolean): ReaderVariantPreference => this.translationPreference(page, automatic),
      this.translationAutoEnabled)
  }

  private translationActions(): ReaderHostAction[] {
    const index = this.translationCurrentIndex
    if (index < 0 || !this.request.preferencesReadWrite) return []
    const translated = this.translationFrame(index)?.asset.variant === 'translated' && !this.translationHiddenPages.includes(index)
    return [new ReaderHostAction('translate-page', AppStrings.get('reader_comic_translation_action'), index >= 0,
      false, this.translationBusyPage === index),
      new ReaderHostAction('translate-auto', AppStrings.get('reader_comic_translation_auto'), index >= 0, this.translationAutoEnabled),
      new ReaderHostAction('translate-original', AppStrings.get('reader_comic_translation_show_original'), index >= 0 && translated)]
  }

  private translationTargetCurrent(source: ReaderUnitKey, navigation: number, index: number): boolean {
    const state = this.session?.snapshot()
    return !this.readerClosed && this.routeActive && this.labVisibility.foreground && state?.phase === 'ready' &&
      state.unit?.key.equals(source) === true && state.navigationRevision === navigation && state.anchor?.sourceIndexHint === index
  }

  private handleHostAction(id: string, source: ReaderUnitKey, navigation: number, index: number): void {
    if (!id.startsWith('translate-')) { this.hostActionDispatch.request(id, source, navigation, index); return }
    if (!this.translationTargetCurrent(source, navigation, index)) return
    if (id === 'translate-original') {
      if (!this.translationHiddenPages.includes(index)) this.translationHiddenPages = this.translationHiddenPages.concat([index])
      this.translationRequestedPages = this.translationRequestedPages.filter((value: number): boolean => value !== index)
      this.translationErrorPage = -1
      this.translationRevision += 1
      return
    }
    if (id === 'translate-auto' && this.translationAutoEnabled) {
      this.translationAutoEnabled = false; this.translationRevision += 1; return
    }
    if (!this.translationSettings.configured()) {
      this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('reader_comic_translation_provider_unavailable') })
      return
    }
    if (id === 'translate-auto') {
      const revision = this.translationSettings.revision
      this.getUIContext().showAlertDialog({ title: AppStrings.get('reader_comic_translation_auto'),
        message: AppStrings.get('reader_comic_translation_auto_confirm'),
        primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => {} },
        secondaryButton: { value: AppStrings.get('common_on'), action: (): void => {
          if (!this.translationTargetCurrent(source, navigation, index) || this.translationSettings.revision !== revision) return
          this.translationAutoFailedPages = []
          this.translationHiddenPages = this.translationHiddenPages.filter((value: number): boolean => value !== index)
          if (this.translationFrame(index)?.asset.variant !== 'translated') this.translationBusyPage = index
          this.translationAutoEnabled = true; this.translationRevision += 1
        } } })
      return
    }
    if (id !== 'translate-page' || this.translationBusyPage === index) return
    this.translationHiddenPages = this.translationHiddenPages.filter((value: number): boolean => value !== index)
    this.translationAutoFailedPages = this.translationAutoFailedPages.filter((value: number): boolean => value !== index)
    if (!this.translationRequestedPages.includes(index)) this.translationRequestedPages = this.translationRequestedPages.concat([index])
    this.translationBusyPage = index
    this.translationErrorPage = -1
    this.translationRevision += 1
  }

  private translationStatus(): ReaderHostStatus | null {
    const index = this.translationCurrentIndex
    if (index < 0) return null
    if (this.translationBusyPage === index) return new ReaderHostStatus(AppStrings.get('reader_comic_translation_running'), true)
    if (this.translationErrorPage !== index) return null
    const page = this.translationFrame(index)?.asset.page ?? this.session?.snapshot().pageMetadata.find(
      (value: ReaderPage): boolean => value.sourceIndex === index)
    const code = page === null || page === undefined ? '' : this.translationProvider?.lastFailureCode(page) ?? ''
    const key = code === 'provider_configuration' ? 'reader_comic_translation_provider_unavailable' :
      code === 'local_visual_unavailable' ? 'reader_comic_translation_local_visual_unavailable' :
      code === 'no_translatable_text' ? 'reader_comic_translation_no_translatable_text' : ''
    return new ReaderHostStatus(key.length > 0 ? AppStrings.get(key) :
      AppStrings.get('reader_comic_translation_failed').replace('%s', code || 'unavailable'))
  }

  /** Processing follows the store's published runtime snapshot, never an uncommitted sheet draft. */
  private superResolutionConfiguration(): KomaReaderSuperResolutionConfiguration {
    return new KomaReaderSuperResolutionConfiguration(this.readerMode.superResolutionEnabled,
      this.readerMode.superResolutionModel, this.readerMode.superResolutionBackend,
      this.readerMode.superResolutionMaxHeight)
  }

  private setEnhancementInteractionBusy(busy: boolean): void {
    if (this.enhancementInteractionTimer >= 0) clearTimeout(this.enhancementInteractionTimer)
    this.enhancementInteractionTimer = -1
    if (busy) {
      readerSuperResolutionSetInteractionPaused(true)
      return
    }
    // NextE's GPU interaction protection; this never delays navigation or pixels.
    this.enhancementInteractionTimer = setTimeout((): void => {
      this.enhancementInteractionTimer = -1
      readerSuperResolutionSetInteractionPaused(false)
    }, 420)
  }

  private releaseEnhancementInteraction(): void {
    if (this.enhancementInteractionTimer >= 0) clearTimeout(this.enhancementInteractionTimer)
    this.enhancementInteractionTimer = -1
    readerSuperResolutionSetInteractionPaused(false)
  }

  private currentReaderMode(): ReaderMode {
    const policy = this.session?.snapshot().policy
    if (policy !== undefined) {
      if (policy.layout === 'continuous') return ReaderMode.CONTINUOUS_SCROLL
      if (policy.layout === 'spread') return ReaderMode.DUAL_PAGE
      return policy.pagingAxis === 'vertical' ? ReaderMode.VERTICAL_PAGE : ReaderMode.SINGLE_PAGE
    }
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

  private readerLoadingInk(): ResourceColor {
    const mode = this.hostPreferences?.backgroundMode ?? this.readerMode.backgroundMode
    // Loading stays light on black/gray; only a white canvas uses dark ink.
    return mode === 'gray' ? ThemeConstants.READER_FOREGROUND_LIGHT : this.readerCanvasForeground()
  }

  /** Preserve Koma's existing spacing scale while reader-kit owns only layout. */
  private readerPageGap(): number {
    const pageMode = this.hostPreferences?.pageMode ?? this.readerMode.pageMode
    const direction = this.hostPreferences?.readingDirection ?? this.readerMode.readingDirection
    if (pageMode === 'continuous_scroll' ||
      (pageMode !== 'vertical_page' && direction === ReadingDirection.WEBTOON)) return 0
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

  private resetSeriesOverride(): void {
    const store = this.preferencesStore
    if (!this.productionEntry || store === null || this.readerClosed) return
    const work = this.unitKey.work
    this.preferenceWrites = this.preferenceWrites.then(async (): Promise<void> => {
      const effective = await store.clearSeriesOverride(work)
      if (this.readerClosed || this.unitKey.work !== work) return
      effective.columnMode = this.hostPreferences?.columnMode ?? effective.columnMode
      this.hostPreferences = effective
      this.seriesOverrideActive = false
      this.session?.setPolicy(KomaReaderInitialPolicy.resolveHost(effective, effective.columnMode))
    }).catch((): void => { DiagnosticLogger.warn('reader', 'preference_reset_failed', '[KomaReader] preference_reset_failed') })
  }

  @Builder
  private ReaderHostSettingsSheet() {
    if (this.hostPreferences !== null) {
      ReaderSettingsContent({
        readerMode: this.currentReaderMode(),
        preferences: this.hostPreferences,
        seriesOverrideActive: this.seriesOverrideActive,
        cropControlsAvailable: true,
        enhancementControlsAvailable: true,
        onResetSeriesOverride: (): void => { this.resetSeriesOverride() },
        onPreferencesChange: (next: ReaderPreferences): void => { this.onHostPreferencesChanged(next) },
        onClose: (): void => { this.closeHostSettings() },
        onRevealTapZones: (): void => { this.closeHostSettings() },
      })
    }
  }

  @Builder
  private ChapterSelectedCheckmark() {
    SymbolGlyph($r('sys.symbol.checkmark')).fontSize(22).fontWeight(FontWeight.Medium)
      .fontColor([ThemeConstants.BRAND_PRIMARY])
  }

  @Builder
  private ReaderHostChapterPickerSheet() {
    KomaModalScaffold({
      title: $r('app.string.reader_control_chapter'),
      modalSurfaceColor: $r('sys.color.ohos_id_color_sub_background'),
      contentOwnsScrolling: true,
      onClose: (): void => { this.chapterPickerShown = false },
    }) {
      List({ scroller: this.chapterPickerScroller, space: ThemeConstants.SPACE_SM,
        initialIndex: this.chapterPickerInitialIndex() }) {
        ForEach(this.chapterChoices, (choice: KomaReaderLabChapterChoice, index: number) => {
          ListItem() {
            ConciseListRow({
              title: this.chapterPickerTitle(choice, index),
              primaryColor: choice.key.unit === this.currentChapterUnit ? ThemeConstants.BRAND_PRIMARY : undefined,
              showChevron: choice.key.unit !== this.currentChapterUnit,
              suffixBuilderParam: choice.key.unit === this.currentChapterUnit ? (): void => {
                this.ChapterSelectedCheckmark()
              } : undefined,
              action: (): void => { this.selectChapterFromPicker(choice) },
            })
          }.padding({ left: ThemeConstants.SPACE_LG, right: ThemeConstants.SPACE_LG })
        }, (choice: KomaReaderLabChapterChoice): string => choice.key.unit)
      }.width('100%').height('100%')
        .padding({ top: ThemeConstants.SPACE_SM, bottom: ThemeConstants.SPACE_XL })
        .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onAppear((): void => { this.restoreChapterPickerPosition() })
        .onAreaChange((_oldArea: Area, newArea: Area): void => {
          // initialIndex can be clamped against the sheet's earlier viewport.
          // Reconcile while opening; later user resizing/scrolling keeps native ownership.
          if (this.chapterPickerOpening && Number(newArea.height) > 0) this.restoreChapterPickerPosition()
        })
        .onScrollIndex((start: number): void => {
          this.chapterPickerVisibleIndex = start
          this.rememberChapterPickerPosition(start)
        })
        .onDidScroll((): void => { this.rememberChapterPickerPosition(this.chapterPickerVisibleIndex) })
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.session !== null) {
          ForEach(this.surfaceEntries, (entry: KomaReaderSessionEntry) => {
            if (this.request.readingChrome) {
              ReaderSurface({ session: entry.session, initialUnit: entry.unit, initialIndex: entry.initialIndex,
                doubleTapEnabled: this.hostPreferences?.doubleTapZoomEnabled ?? this.readerMode.doubleTapZoomEnabled,
                doubleTapIntervalMs: this.hostPreferences?.doubleTapIntervalMs ?? this.readerMode.doubleTapIntervalMs,
                chromeAppearance: this.chromeAppearance,
                modeControl: (params: ReaderModeControlParams): void => { this.HostModeControl(params) },
                titleControl: (params: Binding<ReaderTitleParams>): void => { this.HostTitleControl(params) },
                catalogFailureText: (): string => this.adapter?.catalogFailureMessage() ?? '',
                imageInterpolation: (this.hostPreferences?.imageScalingQuality ?? this.readerMode.imageScalingQuality) === 'low'
                  ? ImageInterpolation.Low :
                  (this.hostPreferences?.imageScalingQuality ?? this.readerMode.imageScalingQuality) === 'high'
                    ? ImageInterpolation.High : ImageInterpolation.Medium,
                imageEffects: komaReaderImageEffects(this.displayPreview.settings ?? this.hostPreferences?.displaySettings ?? this.readerMode.displaySettings),
                canvasBackground: this.readerCanvasBackground(), canvasForeground: this.readerCanvasForeground(),
                loadingInk: this.readerLoadingInk(),
                input: this.input, mediaActions: new ReaderMediaActions(this.imageShare, this.imageSave),
                tapZoneResolver: (x: number, y: number, layout: ReaderLayout): ReaderTapAction => this.resolveTapZone(x, y, layout),
                tapZonePreviewRegions: this.sharedTapZonePreviewRegions(),
                tapZonePreviewRevision: this.tapZonePreviewRevision,
                autoReadPolicy: new ReaderAutoReadPolicy(true,
                  this.hostPreferences?.autoPageSeconds ?? this.readerMode.autoPageSeconds),
                pageTurnAnimation: this.request.pageTurnAnimationOverride ??
                  (this.hostPreferences?.pageTurnAnimation ?? this.readerMode.pageTurnAnimation),
                pageGap: this.readerPageGap(),
                preloadDepth: this.readerPreloadDepth(),
                activitySink: new ReaderActivitySink(null,
                  (busy: boolean): void => { this.setEnhancementInteractionBusy(busy) }),
                variantPolicy: this.translationPolicy(),
                // NextE's existing per-visible-unit override: this toggles the
                // current page(s), never the saved global enhancement setting.
                temporaryVariantControl: new ReaderTemporaryVariantControl(
                  this.enhancementPreference().variant === 'enhanced'),
                cropPolicy: new ReaderCropPolicy(
                  this.hostPreferences?.trimPageMarginsEnabled ?? this.readerMode.trimPageMarginsEnabled, true,
                  this.hostPreferences?.cropStrength ?? this.readerMode.cropStrength),
                hostSettings: this.request.preferencesReadWrite
                  ? new ReaderHostSettings((): void => { this.openHostSettings() }) : null,
                hostActions: new ReaderHostActions(this.hostActionDispatch.items().concat(this.translationActions()),
                  (id: string, source: ReaderUnitKey, navigation: number, index: number): void => {
                    this.handleHostAction(id, source, navigation, index)
                  }),
                hostStatus: this.translationStatus(),
                active: this.routeActive && this.labVisibility.foreground && !this.readerSettingsSheetShown &&
                  !this.chapterPickerShown,
                centerAction: this.chapterChoices.length > 0
                  ? new ReaderCenterAction(this.chapterControlLabel(),
                    (sourceUnit: ReaderUnitKey, navigation: number): void => {
                      this.openChapterPicker(sourceUnit, navigation)
                    }) : null,
                showPageNumber: this.hostPreferences?.showPageNumber ?? this.readerMode.showPageNumber,
                observation: new ReaderObservationSink(null,
                  (position: ReaderObservedPosition): void => { this.onObservedPosition(position) }),
                preferenceSink: new ReaderPreferenceSink(
                  (policy: ReaderDisplayPolicy): void => { this.onPolicyChanged(policy) },
                  (enabled: boolean): void => { this.onCropChanged(enabled) }),
                chapterNavigation: new ReaderChapterNavigation(this.chapterBusy,
                  (direction: 'previous' | 'next', sourceUnit: ReaderUnitKey): void => {
                    void this.switchChapter(direction, sourceUnit)
                  }),
                windowPresentation: this.trialWindow.presentation,
                windowFullscreen: this.hostPreferences?.fullscreen ?? this.readerMode.fullscreen,
                windowCanvasDark: true,
                topInset: this.safeArea.topAvoidHeight, bottomInset: this.safeArea.bottomAvoidHeight,
                accent: ThemeConstants.BRAND_PRIMARY, onClose: (): void => { this.closeReader() } })
              Row().width(1).height(1).position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
                .bindSheet($$this.chapterPickerShown, this.ReaderHostChapterPickerSheet, komaSheetOptions({
                  detents: [SheetSize.MEDIUM, SheetSize.LARGE],
                  showClose: false,
                  enableOutsideInteractive: false,
                  scrollSizeMode: ScrollSizeMode.CONTINUOUS,
                  enableFloatingDragBar: true,
                  onAppear: (): void => {
                    this.chapterPickerOpening = false
                    this.restoreChapterPickerPosition()
                  },
                  onDisappear: (): void => { this.finishChapterPickerDismissal() },
                }))
            } else {
              ReaderLabSurface({ session: entry.session, initialUnit: entry.unit, initialIndex: entry.initialIndex,
                preloadDepth: this.readerMode.preloadPages,
                active: this.routeActive && this.labVisibility.foreground })
            }
          }, (entry: KomaReaderSessionEntry): string => `${entry.id}`)
        } else if (this.productionEntry) {
          Column() {
            if (this.error.length > 0) {
              Text(AppStrings.get('reader_page_load_failed')).fontSize(16).fontColor(Color.White)
            } else {
              LoadingProgress().width(32).height(32).color(Color.White)
            }
          }.width('100%').height('100%').justifyContent(FlexAlign.Center)
        } else {
          Text(this.error)
        }
      }
      .width('100%').height('100%')
      .backgroundColor(this.productionEntry ? this.readerCanvasBackground() : Color.Transparent)
      .padding({ top: this.productionEntry || this.request.readingChrome && this.session !== null ? 0 : this.safeArea.topAvoidHeight + ThemeConstants.TITLE_BAR_HEIGHT,
        bottom: this.productionEntry || this.request.readingChrome && this.session !== null ? 0 : this.safeArea.bottomAvoidHeight })
      .bindSheet($$this.readerSettingsSheetShown, this.ReaderHostSettingsSheet, komaSheetOptions({
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        showClose: false,
        enableOutsideInteractive: false,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        enableFloatingDragBar: true,
        onDisappear: (): void => { this.closeHostSettings() },
      }))
    }.titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: false,
      content: { title: { mainTitle: $r('app.string.rkit_lab_title') } },
    })
    .hideTitleBar(this.productionEntry || this.request.readingChrome && this.session !== null)
    .translate({ x: this.productionEntry ? this.routeTransition.offset() : '0%' })
    .onBackPressed((): boolean => {
      if (!this.request.readingChrome) return false
      this.closeReader()
      return true
    })
    .onShown((): void => { this.routeActive = true; this.onRouteVisibleChange(true) })
    .onWillHide((): void => { this.routeActive = false; this.onRouteVisibleChange(false) })
    .onHidden((): void => { this.routeActive = false; this.onRouteVisibleChange(false) })
    .onWillDisappear((): void => { this.routeActive = false; this.onRouteVisibleChange(false) })
    .onDisAppear((): void => { this.onRouteDisappear() })
  }
}

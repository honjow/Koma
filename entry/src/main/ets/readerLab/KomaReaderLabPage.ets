import { common } from '@kit.AbilityKit'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { ReaderCancellation, ReaderDisplayPolicy, ReaderImageSaveHost, ReaderImageShareHost, ReaderInputPort,
  ReaderObservedPosition, ReaderPagedSession, ReaderUnitKey, ReaderLayout } from '@reader-kit/core'
import { ReaderHostAction, ReaderKeepScreenOn, ReaderLabRequest, ReaderLabSurface, ReaderSurface, ReaderTrialLayoutCommit, ReaderTrialWindow,
  ReaderLabVisibilityState, ReaderSystemImageSaveHost, ReaderVolumeKeys, connectReaderLabVisibility, ReaderTapAction,
  ReaderTapZonePreviewRegion } from '@reader-kit/ui'
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
  @Event onOpenMangaDetail: (work: string) => void = () => {}
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
  @Local private chapterPickerShown: boolean = false
  @Local private chapterChoices: KomaReaderLabChapterChoice[] = []
  @Local private currentChapterUnit: string = ''
  private unitKey: ReaderUnitKey = new ReaderUnitKey('', '', '')
  private initialPageIndex: number = 0
  private trialWindow: ReaderTrialWindow = new ReaderTrialWindow(null, true)
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
  private chapterPickerScroller: Scroller = new Scroller()

  @Monitor('chapterPickerShown')
  private onChapterPickerVisibilityChanged(): void {
    if (!this.chapterPickerShown) return
    const index = this.chapterChoices.findIndex((choice: KomaReaderLabChapterChoice): boolean =>
      choice.key.unit === this.currentChapterUnit)
    if (index >= 0) {
      setTimeout((): void => { this.chapterPickerScroller.scrollToIndex(index, true, ScrollAlign.CENTER) }, 120)
    }
  }

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

  /** Koma owns fullscreen preference semantics; reader-kit only sequences the window lease. */
  private syncChromeVisible(visible: boolean): void {
    if (visible) return // The before-show gate restores the status area before chrome is painted.
    const fullscreen = this.hostPreferences?.fullscreen ?? this.readerMode.fullscreen
    this.trialWindow.setStatusBarVisible(!fullscreen)
  }

  private async prepareChromeShow(isCurrent: () => boolean): Promise<boolean> {
    const current = (): boolean => isCurrent() && !this.readerClosed && this.routeActive &&
      this.labVisibility.foreground && !this.readerSettingsSheetShown && !this.chapterPickerShown && this.session !== null
    if (!current()) return false
    if (!await this.trialWindow.prepareStatusBarVisible() || !current()) return false
    return ReaderTrialLayoutCommit.wait(this.getUIContext(), (): string =>
      this.safeArea.topAvoidHeight > 0 ? `${this.safeArea.topAvoidHeight}:${this.safeArea.bottomAvoidHeight}` : '', current)
  }

  aboutToDisappear(): void {
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

  @Monitor('routeActive', 'labVisibility.foreground', 'readerMode.hydrated', 'readerMode.keepScreenAwake',
    'readerSettingsSheetShown', 'chapterPickerShown')
  syncKeepScreenOn(): void {
    this.keepScreenOn?.setActive(this.request.readingChrome && this.session !== null && this.routeActive &&
      this.labVisibility.foreground && this.readerMode.hydrated && !this.readerSettingsSheetShown && !this.chapterPickerShown &&
      (this.hostPreferences?.keepScreenAwake ?? this.readerMode.keepScreenAwake))
  }

  private closeReader(): void {
    this.readerClosed = true
    this.readerSettingsSheetShown = false
    this.chapterPickerShown = false
    this.chapterPickerTarget = null
    this.initialization?.cancel()
    this.volumeKeys.close()
    this.cancelChapterRequest()
    void this.keepScreenOn?.close()
    if (this.request.progressReadWrite) this.flushObserved()
    this.onClose()
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
    console.info(`[KomaReaderLab] chapter_probe kind=${this.request.chapterProbe}`)
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
    console.info(`[KomaReaderLab] chapter_boundary direction=${reason} source=${sourceUnit.unit} target=${target.unit}`)
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
        this.syncChapterChoices(target)
        console.info(`[KomaReaderLab] chapter_opened direction=${reason} unit=${target.unit}`)
      }
    } catch (_error) {
      if (isCurrent()) {
        console.warn(`[KomaReaderLab] chapter_failed direction=${reason} source=${source.unit} target=${target.unit}`)
        this.getUIContext().getPromptAction().showToast({ message: $r('app.string.manga_detail_chapter_pages_load_failed') })
      } else if (cancellation.isCancelled()) {
        console.info(`[KomaReaderLab] chapter_cancelled direction=${reason} source=${source.unit} target=${target.unit}`)
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

  private readerHostActions(): ReaderHostAction[] {
    return [new ReaderHostAction('manga-detail', AppStrings.get('reader_action_return_to_detail'))]
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
    this.syncChapterChoices(position.anchor.unit)
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
      List({ scroller: this.chapterPickerScroller, space: ThemeConstants.SPACE_SM }) {
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
        .scrollBar(BarState.Off).edgeEffect(EdgeEffect.Spring)
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
              hostActions: this.readerHostActions(),
              onHostAction: (id: string, source: ReaderUnitKey, navigation: number, sourceIndex: number): void => {
                this.openMangaDetail(id, source, navigation, sourceIndex)
              },
              active: this.routeActive && this.labVisibility.foreground && !this.readerSettingsSheetShown &&
                !this.chapterPickerShown,
              chapterNavigationAvailable: true, chapterNavigationBusy: this.chapterBusy,
              hostCenterActionAvailable: this.chapterChoices.length > 0,
              hostCenterActionLabel: this.chapterControlLabel(),
              onHostCenterAction: (sourceUnit: ReaderUnitKey, navigation: number): void => {
                this.openChapterPicker(sourceUnit, navigation)
              },
              showPageNumber: this.hostPreferences?.showPageNumber ?? this.readerMode.showPageNumber,
              onObservedPosition: (position: ReaderObservedPosition): void => {
                this.onObservedPosition(position)
              },
              onPolicyChanged: (policy: ReaderDisplayPolicy): void => { this.onPolicyChanged(policy) },
              onCropChanged: (enabled: boolean): void => { this.onCropChanged(enabled) },
              onChapter: (direction: 'previous' | 'next', sourceUnit: ReaderUnitKey): void => {
                void this.switchChapter(direction, sourceUnit)
              },
              beforeShowChrome: (isCurrent: () => boolean): Promise<boolean> => this.prepareChromeShow(isCurrent),
              onChromeVisible: (visible: boolean): void => { this.syncChromeVisible(visible) },
              topInset: this.safeArea.topAvoidHeight, bottomInset: this.safeArea.bottomAvoidHeight,
              accent: ThemeConstants.BRAND_PRIMARY, onClose: (): void => { this.closeReader() } })
            Row().width(1).height(1).position({ x: 0, y: 0 }).hitTestBehavior(HitTestMode.None)
              .bindSheet($$this.chapterPickerShown, this.ReaderHostChapterPickerSheet, {
                detents: [SheetSize.MEDIUM, SheetSize.LARGE],
                showClose: false,
                enableOutsideInteractive: false,
                scrollSizeMode: ScrollSizeMode.CONTINUOUS,
                enableFloatingDragBar: true,
                onDisappear: (): void => { this.finishChapterPickerDismissal() },
              })
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

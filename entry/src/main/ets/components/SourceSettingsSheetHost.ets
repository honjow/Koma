import { AppStrings } from '../i18n/AppStrings'
import { komaSheetOptions, komaToastOptions } from "../theme/KomaPopupOptions"
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { sourceHasAuthentication } from '../sourceRuntime/SourceAuthenticationService'
import { SourceSettingDescriptor, SourceSettingsRecord, appSourceSettingsStore,
  loadSourceSettingsDescriptorsAsync } from '../sourceRuntime/SourceSettingsStore'
import { SourceSettingsSheetContent, sourceSettingsDraft } from './SourceSettingsSheetContent'

/** Route-owned presenter: no navigation or index/catalogue loading. */
@ComponentV2
export struct SourceSettingsSheetHost {
  @Param sourceId: string = ''
  @Param sourceName: string = ''
  @Param requestSeq: number = 0
  @Param active: boolean = false
  @Param deferAvailability: boolean = false
  @Event onSettingsSaved: () => void = () => {}
  @Event onAvailabilityChanged: (available: boolean) => void = () => {}
  @Local private shown: boolean = false
  @Local private descriptors: SourceSettingDescriptor[] = []
  @Local private draft: SourceSettingsRecord = {}
  @Local private authenticationAvailable: boolean = false
  private mounted: boolean = false
  private availabilityStarted: boolean = false
  private epoch: number = 0
  private handledRequestSeq: number = 0
  private saved: boolean = false
  private authenticationChanged: boolean = false

  aboutToAppear(): void {
    this.mounted = true
    this.prepareAvailability()
  }

  @Monitor('deferAvailability', 'active')
  private prepareAvailability(): void {
    // The optional settings menu does not need to occupy the source's first
    // foreground slot before its visible catalogue or search result.
    if (!this.mounted || !this.active || this.deferAvailability || this.availabilityStarted) return
    this.availabilityStarted = true
    void this.loadAvailability()
  }

  private async loadAvailability(): Promise<void> {
    const sourceId = this.sourceId
    try {
      const result = await loadSourceSettingsDescriptorsAsync(appSourceRuntimeRegistry, sourceId)
      if (!this.mounted || sourceId !== this.sourceId) return
      this.onAvailabilityChanged(result.ready && (result.descriptors.length > 0 || sourceHasAuthentication(sourceId)))
    } catch (_error) {
      if (this.mounted && sourceId === this.sourceId) this.onAvailabilityChanged(false)
    }
  }

  aboutToDisappear(): void {
    this.mounted = false
    this.availabilityStarted = false
    this.epoch += 1
    this.shown = false
  }

  @Monitor('active')
  private visibilityChanged(): void {
    if (this.active) return
    this.epoch += 1
    this.shown = false
  }

  @Monitor('requestSeq')
  private requestSettings(): void {
    if (this.requestSeq <= this.handledRequestSeq) return
    this.handledRequestSeq = this.requestSeq
    if (!this.mounted || !this.active || this.shown) return
    void this.openSettings()
  }

  private async openSettings(): Promise<void> {
    const epoch = ++this.epoch
    const sourceId = this.sourceId
    let schemaReady = false
    try {
      const result = await loadSourceSettingsDescriptorsAsync(appSourceRuntimeRegistry, sourceId)
      if (!this.mounted || !this.active || epoch !== this.epoch || sourceId !== this.sourceId) return
      if (!result.ready) throw new Error('source_settings_unavailable')
      const descriptors = result.descriptors
      this.authenticationAvailable = sourceHasAuthentication(sourceId)
      this.onAvailabilityChanged(descriptors.length > 0 || this.authenticationAvailable)
      if (descriptors.length === 0 && !this.authenticationAvailable) return
      schemaReady = true
      this.draft = sourceSettingsDraft(descriptors, appSourceSettingsStore.loadForSource(sourceId))
      this.descriptors = descriptors
      this.saved = false
      this.authenticationChanged = false
      this.shown = true
    } catch (_error) {
      if (!this.mounted || !this.active || epoch !== this.epoch) return
      if (schemaReady) {
        this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get('source_pkg_reason_settings_read_failed') }))
      } else {
        this.onAvailabilityChanged(false)
      }
    }
  }

  private finishDismissal(): void {
    this.shown = false
    if ((this.saved || this.authenticationChanged) && this.mounted && this.active) this.onSettingsSaved()
    this.saved = false
    this.authenticationChanged = false
  }

  @Builder
  private SettingsContent() {
    SourceSettingsSheetContent({
      settingsSourceId: this.sourceId,
      settingsSourceName: this.sourceName,
      settingDescriptors: this.descriptors,
      initialDraft: this.draft,
      authenticationAvailable: this.authenticationAvailable,
      active: this.active && this.shown,
      onSaved: () => { this.saved = true },
      onAuthenticationChanged: () => { this.authenticationChanged = true },
      onClose: () => { this.shown = false },
    })
  }

  build() {
    Column() {}
      .width(0)
      .height(0)
      .hitTestBehavior(HitTestMode.None)
      .bindSheet($$this.shown, this.SettingsContent, komaSheetOptions({
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        showClose: false,
        enableOutsideInteractive: false,
        scrollSizeMode: ScrollSizeMode.CONTINUOUS,
        enableFloatingDragBar: true,
        keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
        onDisappear: () => { this.finishDismissal() },
      }))
  }
}

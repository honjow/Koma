import { AppStrings } from '../i18n/AppStrings'
import { komaSheetOptions } from '../theme/KomaPopupOptions'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
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
  @Event onSettingsSaved: () => void = () => {}
  @Event onAvailabilityChanged: (available: boolean) => void = () => {}
  @Local private shown: boolean = false
  @Local private descriptors: SourceSettingDescriptor[] = []
  @Local private draft: SourceSettingsRecord = {}
  private mounted: boolean = false
  private epoch: number = 0
  private handledRequestSeq: number = 0
  private saved: boolean = false

  aboutToAppear(): void {
    this.mounted = true
    void this.loadAvailability()
  }

  private async loadAvailability(): Promise<void> {
    const sourceId = this.sourceId
    try {
      const result = await loadSourceSettingsDescriptorsAsync(appSourceRuntimeRegistry, sourceId)
      if (!this.mounted || sourceId !== this.sourceId) return
      this.onAvailabilityChanged(result.ready && result.descriptors.length > 0)
    } catch (_error) {
      if (this.mounted && sourceId === this.sourceId) this.onAvailabilityChanged(false)
    }
  }

  aboutToDisappear(): void {
    this.mounted = false
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
      this.onAvailabilityChanged(descriptors.length > 0)
      if (descriptors.length === 0) return
      schemaReady = true
      this.draft = sourceSettingsDraft(descriptors, appSourceSettingsStore.loadForSource(sourceId))
      this.descriptors = descriptors
      this.saved = false
      this.shown = true
    } catch (_error) {
      if (!this.mounted || !this.active || epoch !== this.epoch) return
      if (schemaReady) {
        this.getUIContext().getPromptAction().showToast({ message: AppStrings.get('source_pkg_reason_settings_read_failed') })
      } else {
        this.onAvailabilityChanged(false)
      }
    }
  }

  private finishDismissal(): void {
    this.shown = false
    if (this.saved && this.mounted && this.active) this.onSettingsSaved()
    this.saved = false
  }

  @Builder
  private SettingsContent() {
    SourceSettingsSheetContent({
      settingsSourceId: this.sourceId,
      settingsSourceName: this.sourceName,
      settingDescriptors: this.descriptors,
      initialDraft: this.draft,
      onSaved: () => { this.saved = true },
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

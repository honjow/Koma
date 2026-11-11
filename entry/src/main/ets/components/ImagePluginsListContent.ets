import { common } from '@kit.AbilityKit'
import { ImageRuleStore } from '../model/ImageRuleStore'
import { ImageRuleSubscription, ImagePluginCollection, imageRuleKey } from '../model/ImageBannerRules'
import { connectImageRuleState, ImageRuleState } from '../state/ImageRuleState'
import { ImagePluginRow, imagePluginRows } from '../model/ImagePluginManagement'
import { imagePluginDefaults } from '../model/ImageProcessingPlugins'
import { SettingsFieldDescriptor, SettingsFieldValue, SettingsFieldValues } from '../model/SettingsFormFields'
import { AppStrings } from '../i18n/AppStrings'
import { ThemeConstants } from '../theme/ThemeConstants'
import { komaDialogMaterial, komaToastOptions } from '../theme/KomaPopupOptions'
import { ConciseListRow } from './ui/ConciseListRow'
import { SettingsFieldRow } from './ui/SettingsFieldRow'
import { GroupedListSection, ListDivider } from './ui/GroupedListSection'
import { KomaModalScaffold, komaModalSheetOptions } from './KomaModalScaffold'

class ImagePluginActivation {
  readonly enabled: boolean
  saved: boolean = false
  constructor(enabled: boolean) { this.enabled = enabled }
}

interface ImagePluginGroupRows {
  key: string
  rows: ImagePluginRow[]
}

@ComponentV2
export struct ImagePluginsListContent {
  @Param inModal: boolean = false
  @Param subscriptions: ImageRuleSubscription[] = []
  @Param installations: ImagePluginCollection[] = []
  @Local private processingState: ImageRuleState = connectImageRuleState()
  @Local private rows: ImagePluginRow[] = []
  @Local private busyKeys: string[] = []
  @Local private activations: Map<string, ImagePluginActivation> = new Map()
  @Local private error: string = ''
  @Local private editing: ImagePluginRow | null = null
  @Local private editorShown: boolean = false
  @Local private draft: SettingsFieldValues = {}
  private store(): ImageRuleStore { return ImageRuleStore.forContext(this.getUIContext().getHostContext() as common.UIAbilityContext) }
  aboutToAppear(): void { this.rows = imagePluginRows(this.subscriptions, this.installations) }
  @Monitor('subscriptions', 'installations')
  private changed(): void {
    this.rows = imagePluginRows(this.subscriptions, this.installations)
    this.reconcileActivations()
    if (this.editing === null) return
    const current = this.rows.find((row: ImagePluginRow): boolean => row.key() === this.editing!.key())
    if (current === undefined) { this.editorShown = false; return }
    // Refresh activation immediately, while an open configuration draft retains
    // the processor version it was created for and cannot overwrite an update.
    if (this.editing.plugin === undefined && current.plugin !== undefined) {
      this.draft = imagePluginDefaults(current.plugin, current.source.pluginSettings?.[current.plugin.id])
      this.editing = current
    } else {
      const editing = new ImagePluginRow(current.source, this.editing.group)
      editing.plugin = this.editing.plugin; editing.offered = this.editing.offered
      editing.pack = this.editing.pack; editing.rule = this.editing.rule; editing.offeredPack = this.editing.offeredPack
      this.editing = editing
    }
  }
  private title(row: ImagePluginRow): string { return row.plugin?.meta.name ?? row.offered?.meta.name ?? row.rule?.name ?? row.offeredPack?.meta?.name ?? row.rule?.id ?? '' }
  private description(row: ImagePluginRow): string { return row.plugin?.meta.description ?? row.offered?.meta.description ?? row.rule?.description ?? row.offeredPack?.meta?.description ?? '' }
  private subtitle(row: ImagePluginRow): string {
    const version = row.plugin?.version ?? row.offered?.version ?? row.pack?.version ?? row.offeredPack?.version ?? 0
    const versions = row.group === 'updates' ? `v${version} → v${(row.offered?.version ?? row.offeredPack!.version)}` : `v${version}`
    return `${this.description(row)}\n${versions} · ${row.source.name}`
  }
  @Computed
  private get rowsByKey(): Map<string, ImagePluginRow> {
    const indexed = new Map<string, ImagePluginRow>()
    this.rows.forEach((row: ImagePluginRow): void => { indexed.set(row.key(), row) })
    return indexed
  }
  @Computed
  private get pluginGroups(): ImagePluginGroupRows[] {
    return ['updates', 'installed', 'available']
      .map((key: string): ImagePluginGroupRows => ({
        key: key,
        rows: this.rows.filter((row: ImagePluginRow): boolean => row.group === key),
      }))
      .filter((group: ImagePluginGroupRows): boolean => group.rows.length > 0)
  }
  private currentRow(row: ImagePluginRow): ImagePluginRow {
    return this.rowsByKey.get(row.key()) ?? row
  }
  private isPluginEnabled(row: ImagePluginRow): boolean {
    return this.activations.get(row.key())?.enabled ?? this.currentRow(row).enabled()
  }
  private isEditingBusy(key: string): boolean {
    return this.busyKeys.includes(key) || this.activations.get(key)?.saved === false
  }
  private reconcileActivations(): void {
    if (this.activations.size === 0) return
    const current = new Map(this.activations)
    this.activations.forEach((activation: ImagePluginActivation, key: string): void => {
      const row = this.rows.find((item: ImagePluginRow): boolean => item.key() === key)
      if (!row || (activation.saved && row.enabled() === activation.enabled)) current.delete(key)
    })
    if (current.size !== this.activations.size) this.activations = current
  }
  private async togglePlugin(row: ImagePluginRow, enabled: boolean): Promise<void> {
    const key = row.key()
    if (this.busyKeys.includes(key) || this.isPluginEnabled(row) === enabled) return
    const activation = new ImagePluginActivation(enabled)
    this.activations = new Map(this.activations).set(key, activation)
    this.error = ''
    try {
      // Native control gets the user's value immediately. The store serializes
      // writes, while an earlier result must not override a newer click.
      await this.store().setRuleEnabled(row.source.origin, row.id(), row.rule?.id ?? row.id(), enabled)
      if (this.activations.get(key) !== activation) return
      activation.saved = true
      this.activations = new Map(this.activations)
      this.reconcileActivations()
    } catch (error) {
      if (this.activations.get(key) !== activation) return
      const current = new Map(this.activations)
      current.delete(key)
      this.activations = current
      this.showOperationError(error as Error)
    }
  }
  private showOperationError(error: Error): void {
    this.error = AppStrings.get(error.message === 'image_plugin_source_conflict' ?
      'image_plugins_source_conflict' : 'image_plugins_operation_failed')
  }
  private failure(row: ImagePluginRow): string {
    const key = JSON.stringify([row.source.origin, row.id(), row.rule?.id ?? row.id()])
    if (row.source.conflicts?.includes(imageRuleKey(row.id(), row.rule?.id ?? row.id()))) return AppStrings.get('image_plugins_source_conflict')
    return this.processingState.processingFailures[key] ? AppStrings.get('image_plugins_processing_failed') : ''
  }
  private async edit(row: ImagePluginRow, operation: () => Promise<void>): Promise<void> {
    const key = row.key()
    if (this.isEditingBusy(key)) return
    this.busyKeys = this.busyKeys.concat(key); this.error = ''
    try { await operation() }
    catch (error) { this.showOperationError(error as Error) }
    finally { this.busyKeys = this.busyKeys.filter((item: string): boolean => item !== key) }
  }
  private open(selected: ImagePluginRow): void {
    if (this.isEditingBusy(selected.key())) return
    const row = this.currentRow(selected)
    this.editing = row
    this.draft = row.plugin === undefined ? {} : imagePluginDefaults(row.plugin, row.source.pluginSettings?.[row.plugin.id])
    this.editorShown = true
  }
  private updateDraft(id: string, value: SettingsFieldValue): void {
    const next: SettingsFieldValues = {}
    for (const key of Object.keys(this.draft)) next[key] = this.draft[key]
    next[id] = value; this.draft = next
  }
  private async save(): Promise<void> {
    const row = this.editing
    if (row?.plugin === undefined) return
    const values = this.draft
    await this.edit(row, async (): Promise<void> => {
      await this.store().setPluginSettings(row.source.origin, row.plugin!.id, values,
        JSON.stringify([row.plugin!.version, row.plugin!.processor.sha256]))
      this.editorShown = false
    })
  }
  private remove(row: ImagePluginRow): void {
    if ((!row.plugin && !row.pack) || this.isEditingBusy(row.key())) return
    this.getUIContext().showAlertDialog({ systemMaterial: komaDialogMaterial(), title: AppStrings.get('image_plugins_uninstall'),
      message: AppStrings.format('image_plugins_uninstall_message', this.title(row)),
      primaryButton: { value: AppStrings.get('common_cancel'), action: (): void => {} },
      secondaryButton: { value: AppStrings.get('image_plugins_uninstall'), fontColor: ThemeConstants.DANGER,
        action: (): void => { void this.edit(row, async (): Promise<void> => {
          await this.store().uninstallPlugin(row.source.origin, row.id(), row.rule?.id); this.editorShown = false
        }) } } })
  }
  @Builder
  private PluginRow(row: ImagePluginRow) {
    if (row.group === 'available' || row.group === 'updates') {
      ConciseListRow({ title: this.title(row), wrapTitle: true, subtitle: this.subtitle(row), subtitleMaxLines: 6,
        action: (): void => { this.open(row) }, showChevron: false,
        actionButtonText: AppStrings.get(row.group === 'updates' ? 'image_plugins_update' : 'image_plugins_install'),
        actionButtonEnabled: !this.isEditingBusy(row.key()),
        actionButtonAction: (): void => {
          void this.edit(row, async (): Promise<void> => {
            if (row.offered !== undefined) await this.store().installPlugin(row.source.origin, row.offered.id, row.offered.version)
            else await this.store().installRulePack(row.source.origin, row.offeredPack!.id)
            this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get(row.group === 'updates' ? 'image_plugins_updated' : 'image_plugins_installed_notice') }))
          })
        } })
    } else {
      ConciseListRow({ title: this.title(row), wrapTitle: true, subtitle: this.subtitle(row), subtitleMaxLines: 6,
        action: (): void => { this.open(row) }, showChevron: false, hasSwitch: true,
        checked: this.isPluginEnabled(row), isEnabled: !this.busyKeys.includes(row.key()),
        switchAction: (value: boolean): void => { void this.togglePlugin(row, value) } })
    }
  }
  @Builder
  private Editor() {
    KomaModalScaffold({ title: this.editing === null ? '' : this.title(this.editing),
      confirmLabel: (this.editing?.plugin?.settings?.length ?? 0) > 0 ? AppStrings.get('common_save') : undefined,
      confirmEnabled: this.editing !== null && !this.isEditingBusy(this.editing.key()),
      onConfirm: (): void => { void this.save() }, onClose: (): void => { this.editorShown = false } }) {
      if (this.editing !== null) {
        ListItem() {
          Column({ space: ThemeConstants.SPACE_MD }) {
            Text(this.description(this.editing)).fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor(ThemeConstants.TEXT_PRIMARY).width('100%')
            Text(this.subtitle(this.editing).split('\n').slice(-1)[0]).fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY).width('100%')
          }.padding(ThemeConstants.SPACE_LG).width('100%')
        }
        if (this.editing.plugin !== undefined || this.editing.pack !== undefined) {
          ListItem() {
            GroupedListSection({ inModal: true }) {
              ConciseListRow({ title: AppStrings.get('image_plugins_enable'), hasSwitch: true, showChevron: false,
                checked: this.isPluginEnabled(this.editing), isEnabled: !this.busyKeys.includes(this.editing.key()),
                switchAction: (enabled: boolean): void => { void this.togglePlugin(this.editing!, enabled) } })
              ListDivider()
              ConciseListRow({ title: AppStrings.get('image_plugins_uninstall'), destructive: true, showChevron: false,
                isEnabled: !this.isEditingBusy(this.editing.key()), action: (): void => { this.remove(this.editing!) } })
            }
          }
          if ((this.editing.plugin?.settings?.length ?? 0) > 0) {
            ListItem() {
              GroupedListSection({ inModal: true, title: AppStrings.get('image_plugins_settings') }) {
                ForEach(this.editing.plugin?.settings ?? [], (field: SettingsFieldDescriptor, index: number) => {
                  SettingsFieldRow({ descriptor: field, value: this.draft[field.id],
                    onChange: (value: SettingsFieldValue): void => { this.updateDraft(field.id, value) } })
                  if (index + 1 < this.editing!.plugin!.settings!.length) { ListDivider() }
                }, (field: SettingsFieldDescriptor): string => field.id)
              }
            }
          }
        }
        if (this.failure(this.editing)) {
          ListItem() { Text(this.failure(this.editing))
            .fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_LG) }
        }
        if (this.error) {
          ListItem() { Text(this.error).fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_LG) }
        }
      }
    }
  }
  build() {
    Column({ space: ThemeConstants.SPACE_LG }) {
      ForEach(this.pluginGroups, (group: ImagePluginGroupRows) => {
        GroupedListSection({ inModal: this.inModal, title: AppStrings.get('image_plugins_' + group.key) }) {
          ForEach(group.rows, (row: ImagePluginRow, index: number) => {
            this.PluginRow(row)
            if (index + 1 < group.rows.length) { ListDivider() }
          // The row closure holds structural data. Switch state reads the
          // current store projection by key without remounting the native control.
          }, (row: ImagePluginRow): string => JSON.stringify([row.key(), row.group,
            row.plugin?.version, row.pack?.version, row.offered?.version, row.offeredPack?.version,
            row.source.conflicts, row.source.pluginSettings]))
        }
      }, (group: ImagePluginGroupRows): string => group.key)
      if (this.error && !this.editorShown) { Text(this.error).fontColor(ThemeConstants.TEXT_SECONDARY).padding(ThemeConstants.SPACE_MD) }
    }.width('100%')
    .bindSheet($$this.editorShown, this.Editor, komaModalSheetOptions({ height: SheetSize.MEDIUM,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE] }))
  }
}

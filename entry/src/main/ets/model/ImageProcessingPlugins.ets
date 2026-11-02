import { SettingsFieldDescriptor, SettingsFieldValue, SettingsFieldValues } from './SettingsFormFields'

export interface ImagePluginMetadata {
  name: string
  description: string
  author?: string
  website?: string
}
export interface ImagePluginProcessor {
  abi: string
  path: string
  sha256: string
  /** Local installed content, never accepted from a remote manifest. Included in portable backups. */
  moduleBase64?: string
}
export interface ImagePluginSourceHint { kind: string; modes: string[]; sourceIds?: string[] }
export interface ImagePluginApplication { automatic: boolean; sourceHints: ImagePluginSourceHint[] }
export interface ImageProcessingPlugin {
  schemaVersion: number
  id: string
  version: number
  meta: ImagePluginMetadata
  processor: ImagePluginProcessor
  parameters: Object
  application: ImagePluginApplication
  settings?: SettingsFieldDescriptor[]
  output?: ImagePluginOutput
}
export interface ImagePluginOutput { format: string; quality: number }
export interface ImagePluginContext { application: string; sourceHint?: ImagePluginHint }
export interface ImagePluginHint { kind: string; mode: string }
export interface ImagePluginConfiguration { parameters: Object; settings: SettingsFieldValues; context: ImagePluginContext }
export interface ImagePluginPlan { plugin: ImageProcessingPlugin; configuration: ImagePluginConfiguration; revision: string; key?: string }
export interface NativeImageProcessorResult {
  ok: boolean
  changed: boolean
  width: number
  height: number
  pixels: ArrayBuffer
  reason: string
}

/** ABI pixels use straight RGBA. ImageKit may decode to premultiplied RGBA. */
export function imagePluginStraightAlpha(pixels: Uint8Array): void {
  for (let index = 0; index < pixels.length; index += 4) {
    const alpha = pixels[index + 3]
    if (alpha === 0 || alpha === 255) continue
    for (let channel = 0; channel < 3; channel += 1)
      pixels[index + channel] = Math.min(255, Math.round(pixels[index + channel] * 255 / alpha))
  }
}

/** The host validates an executable ABI, not an algorithm-name enum. New algorithms remain external. */
export function validateImageProcessingPlugin(raw: Object): ImageProcessingPlugin {
  const plugin = raw as ImageProcessingPlugin
  if (!plugin || plugin.schemaVersion !== 2 || typeof plugin.id !== 'string' || !plugin.id ||
    !Number.isInteger(plugin.version) || plugin.version < 1 || !plugin.meta?.name?.trim() ||
    !plugin.meta.description?.trim() || plugin.processor?.abi !== 'koma-image-v1' ||
    typeof plugin.processor.path !== 'string' || !plugin.processor.path ||
    !/^[a-f0-9]{64}$/.test(plugin.processor.sha256) || !plugin.parameters || typeof plugin.parameters !== 'object' ||
    Array.isArray(plugin.parameters) || typeof plugin.application?.automatic !== 'boolean' ||
    !Array.isArray(plugin.application.sourceHints)) throw new Error('invalid_image_plugin')
  for (const hint of plugin.application.sourceHints) {
    if (typeof hint.kind !== 'string' || !Array.isArray(hint.modes) ||
      hint.modes.some((mode: string): boolean => typeof mode !== 'string') ||
      (hint.sourceIds !== undefined && (!Array.isArray(hint.sourceIds) ||
        hint.sourceIds.some((id: string): boolean => typeof id !== 'string')))) throw new Error('invalid_image_plugin_application')
  }
  if (plugin.settings !== undefined) {
    if (!Array.isArray(plugin.settings) || plugin.settings.length > 64) throw new Error('invalid_plugin_settings')
    const ids: Set<string> = new Set()
    for (const field of plugin.settings) {
      if (typeof field.id !== 'string' || !field.id || ids.has(field.id) || !field.label?.trim() ||
        !['string', 'boolean', 'select', 'multiselect', 'range'].includes(field.kind) ||
        field.sensitive || field.loginRefKey || field.validation !== undefined) throw new Error('invalid_plugin_setting')
      ids.add(field.id)
      field.supported = true
      field.sensitive = false
      if ((field.kind === 'select' || field.kind === 'multiselect') && (!Array.isArray(field.options) ||
        field.options.some((option): boolean => typeof option.id !== 'string' || !option.label?.trim()) ||
        new Set(field.options.map((option): string => option.id)).size !== field.options.length))
        throw new Error('invalid_plugin_setting_options')
      if (field.kind === 'range' && (!Number.isFinite(field.minValue) || !Number.isFinite(field.maxValue) ||
        (field.maxValue ?? 0) <= (field.minValue ?? 0) || !Number.isFinite(field.step) || (field.step ?? 0) <= 0))
        throw new Error('invalid_plugin_setting_range')
      if (field.defaultValue !== undefined && JSON.stringify(normalizedPluginValue(field.defaultValue, field)) !== JSON.stringify(field.defaultValue))
        throw new Error('invalid_plugin_setting_default')
    }
  }
  if (plugin.output !== undefined && (!['image/jpeg', 'image/png', 'image/webp'].includes(plugin.output.format) ||
    !Number.isInteger(plugin.output.quality) || plugin.output.quality < 0 || plugin.output.quality > 100))
    throw new Error('invalid_image_plugin_output')
  return plugin
}

function normalizedPluginValue(value: SettingsFieldValue | undefined, field: SettingsFieldDescriptor): SettingsFieldValue | undefined {
  if (field.kind === 'boolean') return typeof value === 'boolean' ? value : undefined
  if (field.kind === 'string') return typeof value === 'string' ? value : undefined
  if (field.kind === 'range') return typeof value === 'number' && Number.isFinite(value) ?
    Math.min(field.maxValue ?? value, Math.max(field.minValue ?? value, value)) : undefined
  const options = (field.options ?? []).map((option): string => option.id)
  if (field.kind === 'select') return typeof value === 'string' && options.includes(value) ? value : undefined
  if (field.kind === 'multiselect' && Array.isArray(value))
    return Array.from(new Set(value.filter((id: string): boolean => options.includes(id))))
  return undefined
}

export function imagePluginDefaults(plugin: ImageProcessingPlugin, saved: SettingsFieldValues = {}): SettingsFieldValues {
  const result: SettingsFieldValues = {}
  for (const field of plugin.settings ?? []) {
    const value = normalizedPluginValue(saved[field.id], field) ?? normalizedPluginValue(field.defaultValue, field)
    if (value !== undefined) result[field.id] = value
  }
  return result
}

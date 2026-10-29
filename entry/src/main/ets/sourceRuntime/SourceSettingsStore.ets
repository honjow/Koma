import { writeAppTextFile } from '../model/AppFileTextPersistence'
import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { SourceRuntimeCallResponse } from './NativeSourceRuntime'
import { runRegisteredSourceRequestById, runRegisteredSourceRequestByIdAsync } from './SourceRuntimeService'
import { SourceRuntimeRegistry } from './SourceRuntimeRegistry'
import { appSourceSettingObservationStore } from './SourceSettingObservationStore'
import { SourceSettingObservations } from './SourceSettingObservations'

export type SourceSettingValue = string | boolean | number | string[]
export type SourceSettingsRecord = Record<string, SourceSettingValue>

export interface SourceSettingOption {
  id: string
  label: string
}

export interface SourceSettingValidation {
  kind: string
  message: string
}

export interface SourceSettingDescriptor {
  id: string
  label: string
  kind: string
  description?: string
  validation?: SourceSettingValidation
  defaultValue?: SourceSettingValue
  minValue?: number
  maxValue?: number
  step?: number
  options?: SourceSettingOption[]
  children?: string[]
  loginRefKey?: string
  supported: boolean
  sensitive: boolean
}

export interface SourceSettingsDescriptorResult {
  ready: boolean
  descriptors: SourceSettingDescriptor[]
}

interface SourceSettingsDocument {
  schemaVersion: number
  sources: Record<string, SourceSettingsRecord>
}

interface SourceSettingsRequestArgs {
  settingObservations?: SourceSettingObservations
  settingValues?: SourceSettingsRecord
}

interface SourceSettingsRequestSettings {}

interface SourceSettingsRequestHostHints {
  network: boolean
}

interface SourceSettingsRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceSettingsRequestArgs
  settings: SourceSettingsRequestSettings
  hostHints: SourceSettingsRequestHostHints
}

type RuntimeValue = Object | string | number | boolean | null
type RuntimeRecord = Record<string, RuntimeValue>

const SOURCE_SETTINGS_SCHEMA_VERSION: number = 1
const SOURCE_SETTINGS_ROOT_NAME: string = 'source-runtime'
const SOURCE_SETTINGS_FILE_NAME: string = 'source-settings.json'
const SAFE_SETTING_KINDS: string[] = ['string', 'boolean', 'select', 'multiselect', 'range']
const CREDENTIAL_SETTING_KINDS: string[] = ['loginRef', 'credentialsRef', 'sessionRef', 'credential', 'credentials', 'password', 'token', 'cookie']
const SECRET_ID_MARKERS: string[] = ['password', 'token', 'cookie', 'authorization', 'api_key', 'apikey', 'secret', 'credential', 'session']

function joinSourceSettingsPath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  return left.length === 0 ? right : `${left}/${right}`
}

function ensureDirSync(path: string): void {
  if (fs.accessSync(path)) {
    return
  }
  fs.mkdirSync(path, true)
}

function emptyDocument(): SourceSettingsDocument {
  return {
    schemaVersion: SOURCE_SETTINGS_SCHEMA_VERSION,
    sources: {},
  }
}

function copySettingsRecord(values: SourceSettingsRecord): SourceSettingsRecord {
  const copy: SourceSettingsRecord = {}
  Object.keys(values).forEach((key: string): void => {
    const value = values[key]
    copy[key] = Array.isArray(value) ? value.slice() : value
  })
  return copy
}

function isRuntimeRecord(value: RuntimeValue | undefined): boolean {
  return value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)
}

function optionalString(value: RuntimeValue | undefined): string | undefined {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return undefined
  }
  return value
}

function optionalNumber(value: RuntimeValue | undefined): number | undefined {
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined
}

function displayLabel(record: RuntimeRecord, fallback: string): string {
  return optionalString(record['label']) ?? optionalString(record['name']) ?? optionalString(record['title']) ?? fallback
}

function normalizeSourceSettingKind(kind: string): string {
  if (kind === 'toggle') {
    return 'boolean'
  }
  if (kind === 'text') {
    return 'string'
  }
  return kind
}

function descriptorIsCredentialLike(id: string, kind: string): boolean {
  if (CREDENTIAL_SETTING_KINDS.includes(kind)) {
    return true
  }
  const normalized = id.toLocaleLowerCase().replace(/[-.]/g, '_')
  return SECRET_ID_MARKERS.some((marker: string): boolean => normalized.indexOf(marker) >= 0)
}

function safeSettingValue(value: RuntimeValue | undefined): SourceSettingValue | undefined {
  if (typeof value === 'string' || typeof value === 'boolean') {
    return value
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return value
  }
  if (Array.isArray(value)) {
    const values: string[] = []
    value.forEach((item: RuntimeValue) => {
      if (typeof item === 'string') {
        values.push(item)
      }
    })
    return values
  }
  return undefined
}

function normalizedDefaultValue(value: RuntimeValue | undefined, kind: string): SourceSettingValue | undefined {
  if (kind === 'boolean' && typeof value === 'string') {
    const normalized = value.toLocaleLowerCase()
    if (normalized === 'true') {
      return true
    }
    if (normalized === 'false') {
      return false
    }
  }
  return safeSettingValue(value)
}

function settingOptionIds(descriptor: SourceSettingDescriptor): string[] {
  return (descriptor.options ?? []).map((option: SourceSettingOption): string => option.id)
}

/** Match the source's fixed UUID-list contract; do not execute source-provided regexes. */
export function sourceSettingValidationError(
  descriptor: SourceSettingDescriptor, value: SourceSettingValue | undefined,
): string | undefined {
  if (descriptor.validation?.kind !== 'uuid_list' || value === undefined) return undefined
  if (typeof value !== 'string') return descriptor.validation.message
  if (value.trim().length === 0) return undefined
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
  return value.split(',').every((part: string): boolean => uuid.test(part.trim())) ? undefined : descriptor.validation.message
}

function normalizeSettingValidation(value: RuntimeValue | undefined, kind: string): SourceSettingValidation | undefined {
  if (!isRuntimeRecord(value) || kind !== 'string') return undefined
  const record = value as RuntimeRecord
  const validationKind = optionalString(record['kind'])
  const message = optionalString(record['message'])
  if (validationKind !== 'uuid_list' || message === undefined) return undefined
  return { kind: validationKind, message }
}

function normalizedRangeValue(value: SourceSettingValue, descriptor: SourceSettingDescriptor): number | undefined {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    return undefined
  }
  let normalized = value
  if (descriptor.minValue !== undefined) {
    normalized = Math.max(descriptor.minValue, normalized)
  }
  if (descriptor.maxValue !== undefined) {
    normalized = Math.min(descriptor.maxValue, normalized)
  }
  return normalized
}

function sanitizeDescriptorSettingValue(
  value: SourceSettingValue,
  descriptor: SourceSettingDescriptor
): SourceSettingValue | undefined {
  if (descriptor.kind === 'boolean') {
    return typeof value === 'boolean' ? value : undefined
  }
  if (descriptor.kind === 'string') {
    return typeof value === 'string' ? value : undefined
  }
  if (descriptor.kind === 'select') {
    if (typeof value !== 'string') {
      return undefined
    }
    const optionIds = settingOptionIds(descriptor)
    return optionIds.length === 0 || optionIds.includes(value) ? value : undefined
  }
  if (descriptor.kind === 'multiselect') {
    if (!Array.isArray(value)) {
      return undefined
    }
    const optionIds = settingOptionIds(descriptor)
    const selected: string[] = []
    value.forEach((item: string) => {
      if ((optionIds.length === 0 || optionIds.includes(item)) && !selected.includes(item)) {
        selected.push(item)
      }
    })
    return selected
  }
  if (descriptor.kind === 'range') {
    return normalizedRangeValue(value, descriptor)
  }
  return undefined
}

function normalizeOptions(value: RuntimeValue | undefined): SourceSettingOption[] | undefined {
  if (!Array.isArray(value)) {
    return undefined
  }
  const options: SourceSettingOption[] = []
  value.forEach((raw: RuntimeValue) => {
    if (!isRuntimeRecord(raw)) {
      return
    }
    const record = raw as RuntimeRecord
    const id = optionalString(record['id']) ?? optionalString(record['value'])
    if (id === undefined) {
      return
    }
    options.push({
      id,
      label: displayLabel(record, id),
    })
  })
  return options.length === 0 ? undefined : options
}

function normalizeChildren(value: RuntimeValue | undefined): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined
  }
  const children: string[] = []
  value.forEach((raw: RuntimeValue) => {
    if (typeof raw === 'string' && raw.trim().length > 0) {
      children.push(raw)
      return
    }
    if (isRuntimeRecord(raw)) {
      const childId = optionalString((raw as RuntimeRecord)['id'])
      if (childId !== undefined) {
        children.push(childId)
      }
    }
  })
  return children.length === 0 ? undefined : children
}

export function normalizeSourceSettingDescriptors(response: SourceRuntimeCallResponse | undefined): SourceSettingDescriptor[] {
  if (response === undefined || response.ok !== true) {
    return []
  }
  const data = response.data as RuntimeRecord | undefined
  const rawSettings = data?.['settings'] ?? data?.['items']
  if (!Array.isArray(rawSettings)) {
    return []
  }
  const descriptors: SourceSettingDescriptor[] = []
  rawSettings.forEach((raw: RuntimeValue) => {
    if (!isRuntimeRecord(raw)) {
      return
    }
    const record = raw as RuntimeRecord
    const id = optionalString(record['id'])
    const rawKind = optionalString(record['kind'])
    if (id === undefined || rawKind === undefined) {
      return
    }
    const kind = normalizeSourceSettingKind(rawKind)
    const sensitive = descriptorIsCredentialLike(id, kind)
    const validation = normalizeSettingValidation(record['validation'], kind)
    const descriptor: SourceSettingDescriptor = {
      id,
      label: displayLabel(record, id),
      kind,
      description: optionalString(record['description']),
      defaultValue: normalizedDefaultValue(record['default'], kind),
      minValue: optionalNumber(record['min']),
      maxValue: optionalNumber(record['max']),
      step: optionalNumber(record['step']),
      options: normalizeOptions(record['options']),
      children: normalizeChildren(record['children']),
      loginRefKey: optionalString(record['loginRefKey']) ?? optionalString(record['login_ref_key']),
      supported: SAFE_SETTING_KINDS.includes(kind) && !sensitive,
      sensitive,
    }
    if (validation !== undefined) descriptor.validation = validation
    descriptors.push(descriptor)
  })
  return descriptors
}

export class SourceSettingsStore {
  private storagePath: string = ''
  private scopeRevision: number = 0
  private readonly sourceRevisions: Map<string, number> = new Map<string, number>()
  private document: SourceSettingsDocument | undefined = undefined

  configure(context: common.UIAbilityContext): void {
    appSourceSettingObservationStore.configure(context.filesDir)
    const root = joinSourceSettingsPath(context.filesDir, SOURCE_SETTINGS_ROOT_NAME)
    const nextPath = joinSourceSettingsPath(root, SOURCE_SETTINGS_FILE_NAME)
    if (this.storagePath === nextPath) return
    ensureDirSync(root)
    if (this.storagePath !== nextPath) {
      this.invalidateCachedDocument()
    }
    this.storagePath = nextPath
  }

  /** Current-process validity only; no settings values or credentials enter cache identity. */
  revisionForSource(sourceId: string): string {
    return `${this.scopeRevision}:${this.sourceRevisions.get(sourceId.trim()) ?? 0}`
  }

  private sourceCommitted(sourceId: string): void {
    this.sourceRevisions.set(sourceId, (this.sourceRevisions.get(sourceId) ?? 0) + 1)
  }

  isConfigured(): boolean {
    return this.storagePath.length > 0
  }

  /** All production writes use this owner. Raw transaction rollback must invalidate
   * it too. Readers get copies; a failed commit never publishes a newer snapshot.
   * Reopening Manager or requesting another page must not re-read/parse the file.
   */
  invalidateCachedDocument(): void {
    this.document = undefined
    this.scopeRevision += 1
    this.sourceRevisions.clear()
  }

  loadForSource(sourceId: string): SourceSettingsRecord {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return {}
    }
    const document = this.readDocument()
    return copySettingsRecord(document.sources[normalizedSourceId] ?? {})
  }

  descriptorValuesForSource(sourceId: string): SourceSettingsRecord | undefined {
    if (!this.isConfigured() || sourceId.trim().length === 0) return undefined
    try {
      return this.filterSafeValues(this.loadForSource(sourceId), [])
    } catch (_error) {
      // This optional context must not turn a saved-file read failure into a
      // schema failure. The existing form owns that read error and keeps its entry.
      // Absence differs from a successfully read empty record; never migrate on read.
      return undefined
    }
  }

  saveForSource(sourceId: string, values: SourceSettingsRecord, descriptors: SourceSettingDescriptor[] = []): void {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return
    }
    for (const descriptor of descriptors) {
      if (descriptor.supported && sourceSettingValidationError(descriptor, values[descriptor.id]) !== undefined) {
        // Reject the entire edit before any write; never silently drop a bad field.
        throw new Error('source_settings_invalid_value')
      }
    }
    const safeValues = this.filterSafeValues(values, descriptors)
    const current = this.readDocument()
    const sources: Record<string, SourceSettingsRecord> = {}
    Object.keys(current.sources).forEach((id: string): void => { sources[id] = current.sources[id] })
    sources[normalizedSourceId] = safeValues
    this.writeDocument({ schemaVersion: current.schemaVersion, sources })
    this.sourceCommitted(normalizedSourceId)
  }

  removeSource(sourceId: string): void {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return
    }
    const document = this.readDocument()
    const nextSources: Record<string, SourceSettingsRecord> = {}
    Object.keys(document.sources).forEach((key: string) => {
      if (key !== normalizedSourceId) {
        nextSources[key] = document.sources[key]
      }
    })
    this.writeDocument({ schemaVersion: document.schemaVersion, sources: nextSources })
    this.sourceCommitted(normalizedSourceId)
  }

  exportAll(): Record<string, SourceSettingsRecord> {
    const current = this.readDocument()
    const copy: Record<string, SourceSettingsRecord> = {}
    Object.keys(current.sources).forEach((id: string): void => { copy[id] = copySettingsRecord(current.sources[id]) })
    return copy
  }

  importAll(sources: Record<string, SourceSettingsRecord> | undefined): void {
    if (sources === undefined || !this.isConfigured()) {
      return
    }
    const sanitized: Record<string, SourceSettingsRecord> = {}
    Object.keys(sources).forEach((sourceId: string) => {
      sanitized[sourceId] = this.filterSafeValues(sources[sourceId] ?? {}, [])
    })
    this.writeDocument({
      schemaVersion: SOURCE_SETTINGS_SCHEMA_VERSION,
      sources: sanitized,
    })
    this.scopeRevision += 1
    this.sourceRevisions.clear()
  }

  private filterSafeValues(values: SourceSettingsRecord, descriptors: SourceSettingDescriptor[]): SourceSettingsRecord {
    const descriptorById: Record<string, SourceSettingDescriptor> = {}
    descriptors.forEach((descriptor: SourceSettingDescriptor) => {
      descriptorById[descriptor.id] = descriptor
    })
    const safeValues: SourceSettingsRecord = {}
    Object.keys(values).forEach((key: string) => {
      const descriptor = descriptorById[key]
      if (descriptor !== undefined && (!descriptor.supported || descriptor.sensitive)) {
        return
      }
      if (descriptor === undefined && descriptorIsCredentialLike(key, '')) {
        return
      }
      const value = values[key]
      const safe = safeSettingValue(value as RuntimeValue)
      if (safe === undefined) {
        return
      }
      if (descriptor !== undefined) {
        const sanitized = sanitizeDescriptorSettingValue(safe, descriptor)
        if (sanitized !== undefined) {
          safeValues[key] = sanitized
        }
        return
      }
      safeValues[key] = safe
    })
    return safeValues
  }

  private readDocument(): SourceSettingsDocument {
    if (!this.isConfigured()) {
      return emptyDocument()
    }
    if (this.document !== undefined) return this.document
    try {
      if (!fs.accessSync(this.storagePath)) {
        this.document = emptyDocument()
        return this.document
      }
      const document = JSON.parse(fs.readTextSync(this.storagePath, { encoding: 'utf-8' })) as SourceSettingsDocument
      if (document === null || typeof document !== 'object' || Array.isArray(document) ||
        document.schemaVersion !== SOURCE_SETTINGS_SCHEMA_VERSION || document.sources === undefined ||
        document.sources === null || Array.isArray(document.sources) || typeof document.sources !== 'object') {
        throw new Error('source_settings_invalid')
      }
      Object.keys(document.sources).forEach((sourceId: string) => {
        const values = document.sources[sourceId]
        if (values === undefined || values === null || typeof values !== 'object' || Array.isArray(values)) {
          throw new Error('source_settings_invalid')
        }
        Object.keys(values).forEach((key: string) => {
          const value = values[key]
          const valid = typeof value === 'string' || typeof value === 'boolean' ||
            (typeof value === 'number' && Number.isFinite(value)) ||
            (Array.isArray(value) && value.every((item: RuntimeValue): boolean => typeof item === 'string'))
          if (!valid) throw new Error('source_settings_invalid')
        })
      })
      this.document = document
      return document
    } catch (_error) {
      throw new Error('source_settings_invalid')
    }
  }

  private writeDocument(document: SourceSettingsDocument): void {
    if (!this.isConfigured()) {
      return
    }
    writeAppTextFile(this.storagePath, JSON.stringify(document))
    this.document = document
  }
}

export const appSourceSettingsStore: SourceSettingsStore = new SourceSettingsStore()

export function configureSourceSettingsStore(context: common.UIAbilityContext): void {
  appSourceSettingsStore.configure(context)
}

export function fetchSourceSettingDescriptors(registry: SourceRuntimeRegistry, sourceId: string): SourceSettingDescriptor[] {
  const source = registry.lookup(sourceId).entry
  if (source === undefined || !source.capabilities.includes('settings')) return []
  const args: SourceSettingsRequestArgs = { settingObservations: appSourceSettingObservationStore.snapshotForSource(sourceId) }
  args.settingValues = appSourceSettingsStore.descriptorValuesForSource(sourceId)
  const settings: SourceSettingsRequestSettings = {}
  const hostHints: SourceSettingsRequestHostHints = { network: false }
  const request: SourceSettingsRequest = {
    type: 'request',
    version: 1,
    requestId: `settings-${sourceId}-${Date.now()}`,
    operation: 'get_settings',
    sourceId,
    args,
    settings,
    hostHints,
  }
  const summary = runRegisteredSourceRequestById(registry, sourceId, JSON.stringify(request))
  return normalizeSourceSettingDescriptors(summary.response)
}

export async function loadSourceSettingsDescriptorsAsync(registry: SourceRuntimeRegistry, sourceId: string): Promise<SourceSettingsDescriptorResult> {
  const source = registry.lookup(sourceId).entry
  if (source === undefined) return { ready: false, descriptors: [] }
  // A source which declares no settings is not a failed settings operation.
  // Never call its absent export or advertise an optimistic settings entry.
  if (!source.capabilities.includes('settings')) return { ready: true, descriptors: [] }
  const args: SourceSettingsRequestArgs = {}
  try {
    args.settingObservations = await appSourceSettingObservationStore.loadForSource(sourceId)
  } catch (_error) {
    // Derived public candidates are optional. An unreadable observation file
    // must not hide unrelated, otherwise working source settings.
  }
  if (registry.lookup(sourceId).entry !== source) return { ready: false, descriptors: [] }
  args.settingValues = appSourceSettingsStore.descriptorValuesForSource(sourceId)
  const settings: SourceSettingsRequestSettings = {}
  const hostHints: SourceSettingsRequestHostHints = { network: false }
  const request: SourceSettingsRequest = {
    type: 'request',
    version: 1,
    requestId: `settings-${sourceId}-${Date.now()}`,
    operation: 'get_settings',
    sourceId,
    args,
    settings,
    hostHints,
  }
  const summary = await runRegisteredSourceRequestByIdAsync(registry, sourceId, JSON.stringify(request))
  const response = summary.response
  if (response === undefined) return { ready: false, descriptors: [] }
  if (!response.ok) {
    const code = response.error?.['code'] ?? response.reasonCode
    return { ready: code === 'unsupported_operation' || code === 'unsupported' || code === 'not_implemented' || code === 'not_supported', descriptors: [] }
  }
  const data = response.data as RuntimeRecord | undefined
  const rawSettings = data?.['settings'] ?? data?.['items']
  return { ready: Array.isArray(rawSettings), descriptors: normalizeSourceSettingDescriptors(response) }
}

export async function fetchSourceSettingDescriptorsAsync(registry: SourceRuntimeRegistry, sourceId: string): Promise<SourceSettingDescriptor[]> {
  return (await loadSourceSettingsDescriptorsAsync(registry, sourceId)).descriptors
}

import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { SourceRuntimeCallResponse } from './NativeSourceRuntime'
import { runRegisteredSourceRequestById } from './SourceRuntimeService'
import { SourceRuntimeRegistry } from './SourceRuntimeRegistry'

export type SourceSettingValue = string | boolean | number | string[]
export type SourceSettingsRecord = Record<string, SourceSettingValue>

export interface SourceSettingOption {
  id: string
  label: string
}

export interface SourceSettingDescriptor {
  id: string
  label: string
  kind: string
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

interface SourceSettingsDocument {
  schemaVersion: number
  sources: Record<string, SourceSettingsRecord>
}

interface SourceSettingsRequestArgs {}

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

function closeFileQuietly(file: fs.File | undefined): void {
  if (file === undefined) {
    return
  }
  try {
    fs.closeSync(file)
  } catch (_err) {
  }
}

function ensureDirSync(path: string): void {
  if (fs.accessSync(path)) {
    return
  }
  fs.mkdirSync(path, true)
}

function writeTextSync(path: string, payload: string): void {
  let file: fs.File | undefined = undefined
  try {
    file = fs.openSync(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
  } finally {
    closeFileQuietly(file)
  }
}

function emptyDocument(): SourceSettingsDocument {
  return {
    schemaVersion: SOURCE_SETTINGS_SCHEMA_VERSION,
    sources: {},
  }
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

function settingOptionIds(descriptor: SourceSettingDescriptor): string[] {
  return (descriptor.options ?? []).map((option: SourceSettingOption): string => option.id)
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
      label: optionalString(record['label']) ?? id,
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
    const kind = optionalString(record['kind'])
    if (id === undefined || kind === undefined) {
      return
    }
    const sensitive = descriptorIsCredentialLike(id, kind)
    descriptors.push({
      id,
      label: optionalString(record['label']) ?? id,
      kind,
      defaultValue: safeSettingValue(record['default']),
      minValue: optionalNumber(record['min']),
      maxValue: optionalNumber(record['max']),
      step: optionalNumber(record['step']),
      options: normalizeOptions(record['options']),
      children: normalizeChildren(record['children']),
      loginRefKey: optionalString(record['loginRefKey']) ?? optionalString(record['login_ref_key']),
      supported: SAFE_SETTING_KINDS.includes(kind) && !sensitive,
      sensitive,
    })
  })
  return descriptors
}

export class SourceSettingsStore {
  private storagePath: string = ''

  configure(context: common.UIAbilityContext): void {
    const root = joinSourceSettingsPath(context.filesDir, SOURCE_SETTINGS_ROOT_NAME)
    ensureDirSync(root)
    this.storagePath = joinSourceSettingsPath(root, SOURCE_SETTINGS_FILE_NAME)
  }

  isConfigured(): boolean {
    return this.storagePath.length > 0
  }

  loadForSource(sourceId: string): SourceSettingsRecord {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return {}
    }
    const document = this.readDocument()
    return document.sources[normalizedSourceId] ?? {}
  }

  saveForSource(sourceId: string, values: SourceSettingsRecord, descriptors: SourceSettingDescriptor[] = []): void {
    const normalizedSourceId = sourceId.trim()
    if (normalizedSourceId.length === 0 || !this.isConfigured()) {
      return
    }
    const safeValues = this.filterSafeValues(values, descriptors)
    const document = this.readDocument()
    document.sources[normalizedSourceId] = safeValues
    this.writeDocument(document)
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
    document.sources = nextSources
    this.writeDocument(document)
  }

  exportAll(): Record<string, SourceSettingsRecord> {
    return this.readDocument().sources
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
    if (!this.isConfigured() || !fs.accessSync(this.storagePath)) {
      return emptyDocument()
    }
    try {
      const document = JSON.parse(fs.readTextSync(this.storagePath, { encoding: 'utf-8' })) as SourceSettingsDocument
      if (document.schemaVersion !== SOURCE_SETTINGS_SCHEMA_VERSION || document.sources === undefined ||
        document.sources === null || Array.isArray(document.sources) || typeof document.sources !== 'object') {
        return emptyDocument()
      }
      return document
    } catch (_err) {
      return emptyDocument()
    }
  }

  private writeDocument(document: SourceSettingsDocument): void {
    if (!this.isConfigured()) {
      return
    }
    writeTextSync(this.storagePath, JSON.stringify(document))
  }
}

export const appSourceSettingsStore: SourceSettingsStore = new SourceSettingsStore()

export function configureSourceSettingsStore(context: common.UIAbilityContext): void {
  appSourceSettingsStore.configure(context)
}

export function fetchSourceSettingDescriptors(registry: SourceRuntimeRegistry, sourceId: string): SourceSettingDescriptor[] {
  const args: SourceSettingsRequestArgs = {}
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

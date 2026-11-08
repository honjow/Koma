import { url } from '@kit.ArkTS'

export interface SourceRateLimitSetting {
  key: string
  windowValue?: boolean
  keepUntilRestart?: boolean
  maxPermits?: number
}

export interface SourceRateLimitLabel {
  prefix: string
  decimalSuffix?: boolean
}

export interface SourceRateLimitRule {
  group: string
  permits: number
  periodMs: number
  hosts?: string[]
  firstLabels?: SourceRateLimitLabel[]
  requestHeaders?: string[]
  perOrigin?: boolean
  oncePerRequest?: boolean
  setting?: SourceRateLimitSetting
}

interface SourceRateWindow { permits: number; periodMs: number }

function policyInteger(value: Object | undefined, max: number): boolean {
  return typeof value === 'number' && Number.isInteger(value) && value >= 1 && value <= max
}

function policyObject(value: Object | undefined): boolean {
  return value !== undefined && value !== null && typeof value === 'object' && !Array.isArray(value)
}

function policyStrings(values: Object | undefined, pattern: RegExp): boolean {
  return values === undefined || (Array.isArray(values) && values.length > 0 && values.length <= 16 &&
    values.every((value: Object): boolean => typeof value === 'string' && pattern.test(value)))
}

export function validSourceRequestLimits(value?: Object): boolean {
  if (value === undefined) return true
  if (!Array.isArray(value) || value.length > 8) return false
  const groups = new Set<string>()
  for (const item of value as Object[]) {
    if (!policyObject(item)) return false
    const rule = item as Record<string, Object>
    const group = rule['group']
    if (typeof group !== 'string' || !/^[a-z][a-z0-9_-]{0,31}$/.test(group) || groups.has(group) ||
      !policyInteger(rule['permits'], 2147483647) || !policyInteger(rule['periodMs'], 2147483647000) ||
      !policyStrings(rule['hosts'], /^[a-z0-9][a-z0-9.-]{0,252}$/) ||
      !policyStrings(rule['requestHeaders'], /^[a-z0-9][a-z0-9_-]{0,63}$/)) return false
    groups.add(group)
    const labels = rule['firstLabels']
    if (labels !== undefined) {
      if (!Array.isArray(labels) || labels.length < 1 || labels.length > 8) return false
      for (const item of labels as Object[]) {
        if (!policyObject(item)) return false
        const label = item as Record<string, Object>
        const prefix = label['prefix']
        if (typeof prefix !== 'string' || !/^[a-z0-9][a-z0-9-]{0,30}$/.test(prefix) ||
          (label['decimalSuffix'] !== undefined && typeof label['decimalSuffix'] !== 'boolean')) return false
      }
    }
    if (rule['hosts'] !== undefined && labels !== undefined) return false
    if ((rule['perOrigin'] !== undefined && typeof rule['perOrigin'] !== 'boolean') ||
      (rule['oncePerRequest'] !== undefined && typeof rule['oncePerRequest'] !== 'boolean')) return false
    const setting = rule['setting']
    if (setting !== undefined) {
      if (!policyObject(setting)) return false
      const bind = setting as Record<string, Object>
      const key = bind['key']
      if (typeof key !== 'string' || !/^[A-Za-z][A-Za-z0-9_-]{0,127}$/.test(key) ||
        (bind['maxPermits'] !== undefined && !policyInteger(bind['maxPermits'], 2147483647)) ||
        (bind['windowValue'] !== undefined && typeof bind['windowValue'] !== 'boolean') ||
        (bind['keepUntilRestart'] !== undefined && typeof bind['keepUntilRestart'] !== 'boolean')) return false
    }
  }
  return true
}

class SourceRequestWindow {
  starts: number[] = []
  tail: Promise<void> = Promise.resolve()
}

const configuredRates: WeakMap<SourceRateLimitRule, SourceRateWindow> = new WeakMap()
const requestWindows: WeakMap<SourceRateLimitRule, Map<string, SourceRequestWindow>> = new WeakMap()

/** One transport call keeps this object through its redirect hops. */
export interface SourceRequestAdmission { groups?: Set<string> }

function sourceRequestWindow(rule: SourceRateLimitRule, key: string): SourceRequestWindow {
  let windows = requestWindows.get(rule)
  if (windows === undefined) {
    windows = new Map<string, SourceRequestWindow>()
    requestWindows.set(rule, windows)
  }
  let window = windows.get(key)
  if (window === undefined) {
    window = new SourceRequestWindow()
    windows.set(key, window)
  }
  return window
}

/** Consume settings with the same package snapshot as the source operation. */
export function configureSourceRequestPolicy(rules: SourceRateLimitRule[] | undefined, settings: Object | null | undefined): void {
  const values = policyObject(settings ?? undefined) ? settings as Record<string, Object> : undefined
  for (const rule of rules ?? []) {
    const setting = rule.setting
    if (setting === undefined || (setting.keepUntilRestart && configuredRates.has(rule))) continue
    const value = values?.[setting.key]
    const match = setting.windowValue && typeof value === 'string' ? /^(\d+)\/(\d+)$/.exec(value) : null
    const permits = match !== null ? Number(match[1]) :
      setting.windowValue || (typeof value !== 'number' && typeof value !== 'string') ? 0 : Number(value)
    const periodMs = match === null ? rule.periodMs : Number(match[2]) * 1000
    const valid = policyInteger(permits, setting.maxPermits ?? 2147483647) && policyInteger(periodMs, 2147483647000)
    configuredRates.set(rule, valid ? { permits, periodMs } : { permits: rule.permits, periodMs: rule.periodMs })
  }
}

function matchesRule(rule: SourceRateLimitRule, parsed: url.URL, headers?: Object | string | number | boolean | null): boolean {
  const host = parsed.hostname.toLowerCase()
  if (rule.hosts !== undefined && !rule.hosts.includes(host)) return false
  if (rule.firstLabels !== undefined) {
    const domain = host.startsWith('www.') ? host.slice(4) : host
    const dot = domain.indexOf('.')
    if (dot < 1) return false
    const label = domain.slice(0, dot)
    if (!rule.firstLabels.some((part: SourceRateLimitLabel): boolean => label.startsWith(part.prefix) &&
      (part.decimalSuffix ? /^\d+$/.test(label.slice(part.prefix.length)) : /^\w*$/.test(label.slice(part.prefix.length))))) return false
  }
  if (rule.perOrigin && parsed.protocol !== 'https:') return false
  const required = rule.requestHeaders
  if (required === undefined) return true
  const values = policyObject(headers as Object | undefined) ? headers as Record<string, Object> : undefined
  if (values === undefined) return false
  const keys = Object.keys(values)
  return required.every((name: string): boolean => keys.some((key: string): boolean => {
    const value = values[key]
    return key.toLowerCase() === name && typeof value === 'string' && value.length > 0
  }))
}

/** Metadata and actual image GETs share the installed package's declared window. */
export async function waitForSourceRequestSlot(rules: SourceRateLimitRule[] | undefined, requestUrl: string,
  isCurrent: () => boolean = (): boolean => true,
  headers?: Object | string | number | boolean | null, admission?: SourceRequestAdmission): Promise<void> {
  if (rules === undefined || rules.length === 0) return
  let parsed: url.URL
  try { parsed = new url.URL(requestUrl) } catch (_error) { return }
  const rule = rules.find((candidate: SourceRateLimitRule): boolean => matchesRule(candidate, parsed, headers))
  if (rule === undefined) return
  if (rule.oncePerRequest && admission?.groups?.has(rule.group)) return
  const rate = configuredRates.get(rule) ?? rule
  const window = sourceRequestWindow(rule, rule.perOrigin ? parsed.origin : '')
  const previous = window.tail
  let release: () => void = () => {}
  window.tail = new Promise<void>((resolve) => { release = resolve })
  try {
    await previous
    while (true) {
      if (!isCurrent()) throw new Error('source_request_cancelled')
      const now = Date.now()
      window.starts = window.starts.filter((started: number): boolean => now - started < rate.periodMs)
      if (window.starts.length < rate.permits) {
        window.starts.push(now)
        if (rule.oncePerRequest && admission !== undefined) {
          if (admission.groups === undefined) admission.groups = new Set<string>()
          admission.groups.add(rule.group)
        }
        return
      }
      const wait = Math.max(1, window.starts[0] + rate.periodMs - now)
      await new Promise<void>((resolve) => { setTimeout(resolve, Math.min(1000, wait)) })
    }
  } finally { release() }
}

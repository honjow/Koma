/** Public option candidates learned from successful source responses. They are
 * neither the user's selected settings nor a page/content cache identity. */
export type SourceSettingObservations = Record<string, string[]>
export type SourceSettingObservationSources = Record<string, SourceSettingObservations>

export function checkedSourceSettingObservations(value: Object): SourceSettingObservations {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('source_setting_observations_invalid')
  }
  const record = value as Record<string, Object>
  const keys = Object.keys(record)
  if (keys.length > 16) throw new Error('source_setting_observations_invalid')
  const result: SourceSettingObservations = {}
  keys.forEach((key: string): void => {
    // Only bounded public strings. Credentials/session keys never enter this
    // channel, including when importing a backup from another host.
    if (!/^[a-zA-Z][a-zA-Z0-9_]{0,63}$/.test(key) ||
      /password|token|cookie|authorization|api_?key|secret|credential|session/i.test(key)) {
      throw new Error('source_setting_observations_invalid')
    }
    const values = record[key]
    if (!Array.isArray(values) || values.length > 512) throw new Error('source_setting_observations_invalid')
    const strings: string[] = []
    values.forEach((item: Object): void => {
      if (typeof item !== 'string' || item.length > 256 || /[\u0000-\u001f\u007f]/.test(item)) {
        throw new Error('source_setting_observations_invalid')
      }
      // The reference remembers raw names; trimming/lowercasing belongs only
      // to its blacklist comparison. Candidates are opaque labels and values.
      if (item.trim().length > 0 && !strings.includes(item)) strings.push(item)
    })
    result[key] = strings
  })
  return result
}

export function checkedSourceSettingObservationSources(value: Object): SourceSettingObservationSources {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('source_setting_observations_invalid')
  }
  const record = value as Record<string, Object>
  const ids = Object.keys(record)
  if (ids.length > 256) throw new Error('source_setting_observations_invalid')
  const sources: SourceSettingObservationSources = {}
  ids.forEach((id: string): void => {
    if (!/^[a-zA-Z0-9][a-zA-Z0-9._-]{0,191}$/.test(id)) throw new Error('source_setting_observations_invalid')
    sources[id] = checkedSourceSettingObservations(record[id])
  })
  return sources
}

export function mergedSourceSettingObservations(
  current: SourceSettingObservations,
  incoming: SourceSettingObservations,
): SourceSettingObservations {
  const next = checkedSourceSettingObservations(current)
  Object.keys(incoming).forEach((key: string): void => {
    const values = next[key] ?? []
    incoming[key].forEach((value: string): void => { if (!values.includes(value)) values.push(value) })
    next[key] = values
  })
  return checkedSourceSettingObservations(next)
}

// One value per option: id includes it, !id excludes it, absence ignores it.
// Both native menus and persisted choices use this representation.
export function sourceTriStateValue(values: string[], id: string): number {
  return values.includes(id) ? 1 : values.includes(`!${id}`) ? -1 : 0
}

export function nextSourceTriStateValues(values: string[], id: string): string[] {
  const state = sourceTriStateValue(values, id)
  const next = values.filter((value: string): boolean => value !== id && value !== `!${id}`)
  if (state === 0) next.push(id)
  else if (state === 1) next.push(`!${id}`)
  return next
}

export function normalizeSourceTriStateValues(values: string[], allowed?: string[]): string[] {
  const selected = new Map<string, string>()
  values.forEach((value: string): void => {
    const id = value.startsWith('!') ? value.substring(1) : value
    if (id.length > 0 && !id.startsWith('!') && (allowed === undefined || allowed.includes(id))) {
      selected.set(id, value)
    }
  })
  return Array.from(selected.values())
}

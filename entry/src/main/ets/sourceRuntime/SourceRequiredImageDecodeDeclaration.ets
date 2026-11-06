/** Package capability declaration only; no image/UI dependencies in import/metadata workers. */
export function sourceRequiredImageDecodes(value: Object | undefined): string[] | undefined {
  if (value === undefined) return undefined
  if (!Array.isArray(value) || value.some((kind: Object): boolean => kind !== 'jm_stripes_v1')) {
    throw new Error('source_required_decode_declaration_invalid')
  }
  return Array.from(new Set(value as string[])).sort()
}

export function validSourceRequiredImageDecodes(value: Object | undefined): boolean {
  try { sourceRequiredImageDecodes(value); return true } catch (_error) { return false }
}

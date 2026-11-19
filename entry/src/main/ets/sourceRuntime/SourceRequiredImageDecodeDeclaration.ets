export const SOURCE_IMAGE_PROCESSOR_KIND: string = 'wasm_image_v1'
export const SOURCE_IMAGE_PROCESSOR_FEATURE: string = 'source_required_image_decode_wasm_v1'

/** Package capability declaration only; no image/UI dependencies in import/metadata workers. */
export function sourceRequiredImageDecodes(value: Object | undefined): string[] | undefined {
  if (value === undefined) return undefined
  if (!Array.isArray(value) || value.some((kind: Object): boolean =>
    kind !== 'jm_stripes_v1' && kind !== SOURCE_IMAGE_PROCESSOR_KIND)) {
    throw new Error('source_required_decode_declaration_invalid')
  }
  const kinds = Array.from(new Set(value as string[])).sort()
  if (kinds.length > 1) throw new Error('source_required_decode_declaration_invalid')
  return kinds
}

/** The verified source.wasm owns this section through import, sharing and restoration. */
export function sourceImageProcessorModule(wasm: Uint8Array): Uint8Array {
  const bytes = [0, 97, 115, 109, 1, 0, 0, 0]
  if (!bytes.every((byte: number, index: number): boolean => wasm[index] === byte)) {
    throw new Error('source_required_decode_module_invalid')
  }
  const name = 'koma.image-processor.v1'
  let cursor = bytes.length
  let module: Uint8Array | undefined
  const readLength = (limit: number): number => {
    let length = 0
    for (let shift = 0; shift <= 28 && cursor < limit; shift += 7) {
      const byte = wasm[cursor++]
      if (shift === 28 && byte > 15) break
      length += (byte & 127) * 2 ** shift
      if (byte < 128) return length
    }
    throw new Error('source_required_decode_module_invalid')
  }
  while (cursor < wasm.length) {
    const kind = wasm[cursor++]
    const length = readLength(wasm.length)
    const end = cursor + length
    if (end > wasm.length) throw new Error('source_required_decode_module_invalid')
    if (kind === 0) {
      const nameLength = readLength(end)
      const nameStart = cursor
      cursor += nameLength
      if (cursor > end) throw new Error('source_required_decode_module_invalid')
      if (nameLength === name.length && wasm.subarray(nameStart, cursor).every((byte: number, index: number): boolean =>
        byte === name.charCodeAt(index))) {
        if (module !== undefined || end - cursor < 8 || end - cursor > 2 * 1024 * 1024) {
          throw new Error('source_required_decode_module_invalid')
        }
        module = wasm.subarray(cursor, end)
      }
    }
    cursor = end
  }
  if (module === undefined) throw new Error('source_required_decode_module_missing')
  const embedded = module
  if (!bytes.every((byte: number, index: number): boolean => embedded[index] === byte)) {
    throw new Error('source_required_decode_module_invalid')
  }
  return module
}

export function validSourceRequiredImageDecodes(value: Object | undefined): boolean {
  try { sourceRequiredImageDecodes(value); return true } catch (_error) { return false }
}

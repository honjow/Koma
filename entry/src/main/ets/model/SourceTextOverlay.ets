/** Source-owned plain-text placements in original image pixels. */
export interface SourceTextOverlayBalloon {
  text: string
  x: number
  y: number
  width: number
}

export interface SourceTextOverlay {
  version: number
  balloons: SourceTextOverlayBalloon[]
}

export function sourceTextOverlay(value: Object): SourceTextOverlay {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) throw new Error('source_text_overlay_invalid')
  const record = value as Record<string, Object>
  const raw = record['balloons']
  if (record['version'] !== 1 || !Array.isArray(raw) || raw.length === 0 || raw.length > 128) {
    throw new Error('source_text_overlay_invalid')
  }
  const balloons: SourceTextOverlayBalloon[] = []
  let bytes = 0
  for (const item of raw as Object[]) {
    if (item === null || typeof item !== 'object' || Array.isArray(item)) throw new Error('source_text_overlay_invalid')
    const balloon = item as Record<string, Object>
    const text = balloon['text']
    const x = balloon['x']
    const y = balloon['y']
    const width = balloon['width']
    if (typeof text !== 'string' || typeof x !== 'number' || typeof y !== 'number' || typeof width !== 'number' ||
      !Number.isFinite(x) || !Number.isFinite(y) || !Number.isInteger(width) || x < 0 || y < 0 || width < 1 ||
      x > 65535 || y > 65535 || width > 65535) throw new Error('source_text_overlay_invalid')
    // Count UTF-8 bytes without encoding or exposing the content.
    let size = 0
    for (const character of text) {
      const cp = character.codePointAt(0) ?? 0
      size += cp < 128 ? 1 : (cp < 2048 ? 2 : (cp < 65536 ? 3 : 4))
    }
    bytes += size
    if (size >= 4096 || bytes > 65536) throw new Error('source_text_overlay_invalid')
    balloons.push({ text, x, y, width })
  }
  return { version: 1, balloons }
}

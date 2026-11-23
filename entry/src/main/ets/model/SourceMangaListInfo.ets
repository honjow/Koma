import { normalizeSourceDisplayText } from './SourceTextNormalizer'

/** Source-owned content and order; typography and interaction remain host-owned. */
export interface SourceMangaListInfo {
  type: 'text' | 'tags'
  text?: string
  label?: string
  items?: string[]
}

function summaryText(value: Object | undefined, maxBytes: number): string | undefined {
  if (typeof value !== 'string' || value.length > maxBytes * 6) return undefined
  const text = normalizeSourceDisplayText(value)?.replace(/\s+/g, ' ').trim()
  if (!text || /[\u0000-\u0008\u000E-\u001F\u007F]/.test(text)) return undefined
  let bytes = 0
  for (let index = 0; index < text.length; index++) {
    const unit = text.charCodeAt(index)
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      const next = text.charCodeAt(++index)
      if (!(next >= 0xDC00 && next <= 0xDFFF)) return undefined
      bytes += 4
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return undefined
    } else {
      bytes += unit < 0x80 ? 1 : unit < 0x800 ? 2 : 3
    }
    if (bytes > maxBytes) return undefined
  }
  return text
}

/** Malformed optional metadata must never discard an otherwise usable catalogue. */
export function normalizeSourceMangaListInfo(value: Object | undefined): SourceMangaListInfo[] | undefined {
  if (!Array.isArray(value)) return undefined
  if (value.length === 0) return [] // An explicit empty array opts out of the legacy fallback.
  const rows: SourceMangaListInfo[] = []
  const rawRows = value as Object[]
  for (let index = 0; index < Math.min(rawRows.length, 3); index++) {
    const raw = rawRows[index]
    if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) continue
    const row = raw as Record<string, Object>
    if (row['type'] === 'text') {
      const text = summaryText(row['text'], 512)
      if (text !== undefined) rows.push({ type: 'text', text, label: summaryText(row['label'], 96) })
    } else if (row['type'] === 'tags' && Array.isArray(row['items'])) {
      const rawItems = row['items'] as Object[]
      const items: string[] = []
      for (let tag = 0; tag < Math.min(rawItems.length, 8); tag++) {
        const text = summaryText(rawItems[tag], 96)
        if (text !== undefined && !items.includes(text)) items.push(text)
      }
      if (items.length > 0) rows.push({ type: 'tags', items })
    }
  }
  return rows.length > 0 ? rows : undefined
}

export function sourceMangaListInfoText(info: SourceMangaListInfo): string {
  if (info.type === 'tags') return (info.items ?? []).join(' · ')
  return info.label ? `${info.label}: ${info.text ?? ''}` : info.text ?? ''
}

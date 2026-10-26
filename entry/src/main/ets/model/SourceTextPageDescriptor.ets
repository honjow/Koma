export interface SourceTextPage {
  template: string
  heading: string
  paragraphs: string[]
}

/** A source-owned page resolved through get_image_request, never an invented URL. */
export interface SourceTextPageRequest {
  template: string
}

export function sourceTextPageRequest(value: Object | undefined): SourceTextPageRequest {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value) ||
    (value as Record<string, Object>)['template'] !== 'zaimanhua-chapter-comments') {
    throw new Error('source_text_page_request_invalid')
  }
  return { template: 'zaimanhua-chapter-comments' }
}

/** The source owns JSON/HTML decoding. This boundary only accepts plain Unicode;
 * it never interprets markup or loads fonts, scripts, URLs or credentials.
 */
export function sourceTextPage(value: Object | undefined): SourceTextPage {
  if (value === undefined || value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('source_text_page_invalid')
  }
  const fields = value as Record<string, Object>
  const template = fields['template']
  const heading = fields['heading'] ?? ''
  const paragraphs = fields['paragraphs']
  if ((template !== 'webtoon-author-notes' && template !== 'dm5-chapter-comments' &&
    template !== 'zaimanhua-chapter-comments') ||
    typeof heading !== 'string' || !Array.isArray(paragraphs) || paragraphs.length > 1000) {
    throw new Error('source_text_page_invalid')
  }
  let length: number = heading.length
  const lines: string[] = []
  for (const paragraph of paragraphs as Object[]) {
    if (typeof paragraph !== 'string') throw new Error('source_text_page_invalid')
    length += paragraph.length
    if (length > 64000) throw new Error('source_text_page_too_large')
    lines.push(paragraph)
  }
  if (length === 0 || length > 64000) throw new Error('source_text_page_invalid')
  return { template: template as string, heading, paragraphs: lines }
}

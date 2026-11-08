import { MarkdownDocument, MarkdownInline } from './MarkdownDocument'
import { lexer, MarkedToken } from './vendor/marked/marked.esm'

interface SynopsisStyle {
  bold?: boolean
  italic?: boolean
  code?: boolean
  strike?: boolean
  quote?: boolean
  url?: string
}

/** Project Marked tokens into one selectable native Text. HTML is never rendered. */
export class MarkdownSynopsis {
  static spans(markdown: string): MarkdownInline[] {
    if (!/[*_~`[\]<>#\\]|https?:\/\/|^\s*[-+\d]/m.test(markdown)) return []
    const spans: MarkdownInline[] = []
    try {
      MarkdownSynopsis.blocks(lexer(markdown, { gfm: true, breaks: true }), spans, {}, 0)
    } catch (_error) { return [] }
    const text = spans.map((span: MarkdownInline): string => span.text).join('')
    return text === markdown && !spans.some((span: MarkdownInline): boolean =>
      span.bold || span.italic || span.code || span.strike || span.quote || span.url.length > 0) ? [] : spans
  }

  private static add(spans: MarkdownInline[], text: string, style: SynopsisStyle): void {
    if (text.length === 0) return
    const span = new MarkdownInline()
    span.key = 'synopsis_' + spans.length
    span.text = text
    span.bold = style.bold ?? false
    span.italic = style.italic ?? false
    span.code = style.code ?? false
    span.strike = style.strike ?? false
    span.quote = style.quote ?? false
    span.url = style.url ?? ''
    spans.push(span)
  }

  private static copyStyle(style: SynopsisStyle): SynopsisStyle {
    return { bold: style.bold, italic: style.italic, code: style.code, strike: style.strike,
      quote: style.quote, url: style.url }
  }

  private static blocks(tokens: MarkedToken[], spans: MarkdownInline[], style: SynopsisStyle, depth: number): void {
    if (depth > 32) return
    tokens.forEach((token: MarkedToken, index: number): void => {
      const next = tokens[index + 1]
      if (token.type === 'blockquote') {
        const quote = MarkdownSynopsis.copyStyle(style)
        quote.quote = true
        MarkdownSynopsis.blocks(token.tokens ?? [], spans, quote, depth + 1)
      } else if (token.type === 'list') {
        const items = token.items ?? []
        items.forEach((item: MarkedToken, position: number): void => {
          if (position > 0) MarkdownSynopsis.add(spans, '\n', style)
          const prefix = token.ordered ? String((token.start ?? 1) + position) + '. ' : '• '
          MarkdownSynopsis.add(spans, prefix, style)
          MarkdownSynopsis.blocks(item.tokens ?? [], spans, style, depth + 1)
        })
      } else if (token.type === 'heading') {
        const heading = MarkdownSynopsis.copyStyle(style)
        heading.bold = true
        MarkdownSynopsis.inlines(token.tokens ?? [], spans, heading, depth + 1)
      } else if (token.type === 'code') {
        const code = MarkdownSynopsis.copyStyle(style)
        code.code = true
        MarkdownSynopsis.add(spans, token.text ?? '', code)
      } else if (token.type === 'hr') {
        MarkdownSynopsis.add(spans, '―', style)
      } else if (token.type === 'space') {
        MarkdownSynopsis.add(spans, token.raw ?? '\n', style)
      } else if (token.type !== 'def') {
        if (token.tokens !== undefined) MarkdownSynopsis.inlines(token.tokens, spans, style, depth + 1)
        else MarkdownSynopsis.add(spans, token.text ?? token.raw ?? '', style)
      }
      if (next !== undefined && next.type !== 'space' && token.type !== 'space' && token.type !== 'def') {
        MarkdownSynopsis.add(spans, '\n', style)
      }
    })
  }

  private static inlines(tokens: MarkedToken[], spans: MarkdownInline[], style: SynopsisStyle, depth: number): void {
    if (depth > 32) return
    tokens.forEach((token: MarkedToken): void => {
      const nested = MarkdownSynopsis.copyStyle(style)
      switch (token.type) {
        case 'strong': nested.bold = true; break
        case 'em': nested.italic = true; break
        case 'codespan': nested.code = true; break
        case 'del': nested.strike = true; break
        case 'link': nested.url = MarkdownDocument.externalHttpUrl(token.href ?? ''); break
      }
      if (token.type === 'br') MarkdownSynopsis.add(spans, '\n', nested)
      else if (token.type !== 'image' && token.tokens !== undefined) {
        MarkdownSynopsis.inlines(token.tokens, spans, nested, depth + 1)
      } else MarkdownSynopsis.add(spans, token.text ?? token.raw ?? '', nested)
    })
  }
}

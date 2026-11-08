export interface MarkedToken {
  type: string
  raw?: string
  text?: string
  href?: string
  ordered?: boolean
  start?: number
  tokens?: MarkedToken[]
  items?: MarkedToken[]
}

export interface MarkedLexerOptions {
  gfm: boolean
  breaks: boolean
}

export function lexer(markdown: string, options: MarkedLexerOptions): MarkedToken[]

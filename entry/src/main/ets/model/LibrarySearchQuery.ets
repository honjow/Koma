import { normalizeSearchText, searchTextMatchesQuery } from './CrossSearchText'

/** A query condition, not a change to the user's saved global search range. */
export interface LibrarySearchSource {
  key: string
  name: string
}

export interface LibrarySearchNode {
  kind: string
  value: string
  field: string
  comparison: string
  children: LibrarySearchNode[]
}

export interface LibrarySearchPlan {
  root: LibrarySearchNode
  libraryOnly: boolean
  rankingText: string
}

export interface LibrarySearchFields {
  title: string
  subtitle?: string
  author?: string
  artist?: string
  chapterTitles: string[]
  sourceKey?: string
  sourceNames?: string[]
  tags?: string[]
  notes?: string
  unreadCount?: number
  chapterCount: number
}

interface QueryToken { kind: string; value: string; field: string; comparison: string }
interface QueryValue { value: string; end: number }

function node(kind: string, value: string = '', field: string = '', comparison: string = '',
  children: LibrarySearchNode[] = []): LibrarySearchNode {
  return { kind, value, field, comparison, children }
}

function fieldName(value: string): string {
  const name = value.toLowerCase()
  if (name === 'source' || name === 'src') return 'source'
  if (name === 'tag' || name === 'genre') return 'tag'
  if (name === 'notes' || name === 'note') return 'notes'
  return ['title', 'author', 'artist', 'unread', 'read', 'total'].includes(name) ? name : ''
}

function readValue(input: string, start: number): QueryValue {
  let index = start
  while (index < input.length && /\s/.test(input.charAt(index))) index += 1
  const quote = input.charAt(index)
  if (quote === '"' || quote === "'") {
    index += 1
    let value = ''
    while (index < input.length) {
      const ch = input.charAt(index++)
      if (ch === quote) break
      if (ch === '\\' && index < input.length && [quote, '\\'].includes(input.charAt(index))) {
        value += input.charAt(index++)
      } else value += ch
    }
    return { value, end: index }
  }
  const begin = index
  while (index < input.length && !/[\s,()]/.test(input.charAt(index)) &&
    !['&&', '||'].includes(input.substring(index, index + 2))) index += 1
  return { value: input.substring(begin, index), end: index }
}

function tokenize(input: string): QueryToken[] {
  const tokens: QueryToken[] = []
  let index = 0
  while (index < input.length) {
    const ch = input.charAt(index)
    if (/[\s,]/.test(ch)) { index += 1; continue }
    const pair = input.substring(index, index + 2)
    if (ch === '(' || ch === ')' || ch === '-' || pair === '&&' || pair === '||') {
      const kind = ch === '(' ? 'left' : ch === ')' ? 'right' : ch === '-' ? 'not' : pair === '&&' ? 'and' : 'or'
      tokens.push({ kind, value: '', field: '', comparison: '' })
      index += pair === '&&' || pair === '||' ? 2 : 1
      continue
    }
    const match = /^([a-zA-Z_][a-zA-Z0-9_]*)(:|>=|<=|>|<|=)/.exec(input.substring(index))
    if (match !== null) {
      const field = fieldName(match[1])
      if (field.length > 0) {
        const value = readValue(input, index + match[0].length)
        const comparison = match[2] === ':' ? '=' : match[2]
        tokens.push({ kind: ['unread', 'read', 'total'].includes(field) ? 'compare' : 'field',
          field, comparison, value: value.value })
        index = value.end
        continue
      }
    }
    const value = readValue(input, index)
    tokens.push({ kind: 'text', value: value.value, field: '', comparison: '' })
    index = Math.max(index + 1, value.end)
  }
  return tokens
}

class LibraryQueryParser {
  private index: number = 0
  private tokens: QueryToken[]
  constructor(tokens: QueryToken[]) { this.tokens = tokens }

  parse(): LibrarySearchNode { return this.parseOr() }
  private kind(): string { return this.tokens[this.index]?.kind ?? '' }

  private group(kind: string, children: LibrarySearchNode[]): LibrarySearchNode {
    const values = children.filter((child: LibrarySearchNode): boolean => child.kind !== 'empty')
    return values.length === 0 ? node('empty') : values.length === 1 ? values[0] : node(kind, '', '', '', values)
  }

  private parseOr(): LibrarySearchNode {
    const children: LibrarySearchNode[] = [this.parseAnd()]
    while (this.kind() === 'or') { this.index += 1; children.push(this.parseAnd()) }
    return this.group('or', children)
  }

  private parseAnd(): LibrarySearchNode {
    const children: LibrarySearchNode[] = []
    while (this.index < this.tokens.length && this.kind() !== 'or' && this.kind() !== 'right') {
      if (this.kind() === 'and') { this.index += 1; continue }
      children.push(this.parseTerm())
    }
    return this.group('and', children)
  }

  private parseTerm(): LibrarySearchNode {
    let negated = false
    while (this.kind() === 'not') { negated = !negated; this.index += 1 }
    let result: LibrarySearchNode
    if (this.kind() === 'left') {
      this.index += 1
      result = this.parseOr()
      if (this.kind() === 'right') this.index += 1
    } else {
      const token = this.tokens[this.index++]
      result = token === undefined ? node('empty') : node(token.kind, token.value, token.field, token.comparison)
    }
    return negated && result.kind !== 'empty' ? node('not', '', '', '', [result]) : result
  }
}

function rankingText(value: LibrarySearchNode): string {
  if (value.kind === 'text' || (value.kind === 'field' && value.field === 'title')) return value.value
  if (value.kind === 'and' || value.kind === 'or') return value.children.map(rankingText).filter((v: string): boolean => v.length > 0).join(' ')
  return ''
}

/** Parse before normalization: punctuation here has meaning. Plain queries keep
 * the original phrase/compact matching, including chapter titles and ranking. */
export function parseLibrarySearchQuery(value: string): LibrarySearchPlan {
  const tokens = tokenize(value)
  const libraryOnly = tokens.some((token: QueryToken): boolean => token.kind !== 'text')
  const root = value.trim().length === 0 ? node('all') : libraryOnly ? new LibraryQueryParser(tokens).parse() : node('text', value)
  return { root, libraryOnly, rankingText: rankingText(root) }
}

export function copyLibrarySearchSource(value: LibrarySearchSource | undefined): LibrarySearchSource | undefined {
  return value === undefined ? undefined : { key: value.key, name: value.name }
}

export function libraryQueryNeedsReadState(value: LibrarySearchNode): boolean {
  return (value.kind === 'compare' && value.field !== 'total') || value.children.some(libraryQueryNeedsReadState)
}

function matchesText(text: string | undefined, value: string): boolean {
  const query = normalizeSearchText(value)
  return query.length > 0 && searchTextMatchesQuery(text, query, query.replace(/ /g, ''))
}

export function matchesLibrarySearch(document: LibrarySearchFields, query: LibrarySearchNode): boolean {
  if (query.kind === 'all') return true
  if (query.kind === 'and') return query.children.every((child: LibrarySearchNode): boolean => matchesLibrarySearch(document, child))
  if (query.kind === 'or') return query.children.some((child: LibrarySearchNode): boolean => matchesLibrarySearch(document, child))
  if (query.kind === 'not') return !matchesLibrarySearch(document, query.children[0])
  if (query.kind === 'text') {
    const text = normalizeSearchText(query.value)
    if (text.length === 0) return false
    const compact = text.replace(/ /g, '')
    return searchTextMatchesQuery(document.title, text, compact) ||
      searchTextMatchesQuery(document.subtitle, text, compact) ||
      searchTextMatchesQuery(document.author, text, compact) ||
      document.chapterTitles.some((title: string): boolean => searchTextMatchesQuery(title, text, compact))
  }
  if (query.kind === 'field') {
    if (query.field === 'source') return (document.sourceNames ?? []).some((name: string): boolean => matchesText(name, query.value))
    if (query.field === 'tag') return (document.tags ?? []).some((tag: string): boolean => matchesText(tag, query.value))
    if (query.field === 'title') return matchesText(document.title, query.value)
    if (query.field === 'author') return matchesText(document.author, query.value)
    if (query.field === 'artist') return matchesText(document.artist, query.value)
    if (query.field === 'notes') return matchesText(document.notes, query.value)
  }
  if (query.kind === 'compare') {
    if (!/^\d+$/.test(query.value)) return false
    const value = Number(query.value)
    const actual = query.field === 'total' ? document.chapterCount : query.field === 'unread' ? document.unreadCount :
      document.unreadCount === undefined ? undefined : Math.max(0, document.chapterCount - document.unreadCount)
    if (actual === undefined) return false
    if (query.comparison === '>') return actual > value
    if (query.comparison === '>=') return actual >= value
    if (query.comparison === '<') return actual < value
    if (query.comparison === '<=') return actual <= value
    return actual === value
  }
  return false
}

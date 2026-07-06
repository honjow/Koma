#!/usr/bin/env node
import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const root = resolve(new URL('..', import.meta.url).pathname)

const forbiddenCodePoints = [
  0x2190, 0x2191, 0x2192, 0x2193, 0x2194, 0x2195, 0x2196, 0x2197, 0x2198, 0x2199,
  0x21A9, 0x21AA,
  0x25A0, 0x25A1, 0x25B2, 0x25B3, 0x25B6, 0x25C0, 0x25C6, 0x25C7, 0x25CB, 0x25CF,
  0x25BE, 0x25BF, 0x25C2, 0x25B8,
  0x2605, 0x2606, 0x2610, 0x2611, 0x2612, 0x2630,
  0x2713, 0x2714, 0x2715, 0x2716, 0x2717,
  0x2794, 0x279C,
]

const forbiddenChars = new Set(forbiddenCodePoints.map((codePoint) => String.fromCodePoint(codePoint)))
const codeExtensions = new Set([
  '.ets', '.ts', '.js', '.mjs', '.cjs',
  '.json', '.json5', '.xml', '.hml', '.css',
])

function git(args) {
  return execFileSync('git', args, {
    cwd: root,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
  })
}

function extensionOf(file) {
  const index = file.lastIndexOf('.')
  return index < 0 ? '' : file.slice(index)
}

function isGeneratedOrVendorPath(file) {
  return file.startsWith('.git/') ||
    file.startsWith('.hermes-artifacts/') ||
    file.startsWith('.hvigor/') ||
    file.includes('/build/') ||
    file.includes('/node_modules/') ||
    file.includes('/oh_modules/')
}

function isAppRuntimePath(file) {
  return file.startsWith('entry/') ||
    file.startsWith('feature/') ||
    file.startsWith('shared/') ||
    file.startsWith('AppScope/')
}

function shouldScan(file) {
  return !isGeneratedOrVendorPath(file) && codeExtensions.has(extensionOf(file))
}

function isHighEmojiCodePoint(codePoint) {
  return (codePoint >= 0x1F000 && codePoint <= 0x1FAFF) ||
    (codePoint >= 0x2600 && codePoint <= 0x27BF && !isAllowedTextSymbol(codePoint))
}

function isAllowedTextSymbol(codePoint) {
  return codePoint === 0x3002 ||
    codePoint === 0xFF0C ||
    codePoint === 0xFF1A ||
    codePoint === 0xFF1B ||
    codePoint === 0xFF01 ||
    codePoint === 0xFF1F
}

function isForbiddenChar(char) {
  const codePoint = char.codePointAt(0)
  if (codePoint === undefined) return false
  return forbiddenChars.has(char) || isHighEmojiCodePoint(codePoint)
}

function decodeUnicodeEscape(match) {
  const braced = /^\\u\{([0-9a-fA-F]{1,6})\}$/.exec(match)
  const plain = /^\\u([0-9a-fA-F]{4})$/.exec(match)
  const hex = braced?.[1] ?? plain?.[1]
  if (hex === undefined) return undefined
  const codePoint = Number.parseInt(hex, 16)
  if (!Number.isFinite(codePoint)) return undefined
  try {
    return String.fromCodePoint(codePoint)
  } catch {
    return undefined
  }
}

function lineColumn(content, offset) {
  const prefix = content.slice(0, offset)
  const lines = prefix.split(/\r?\n/)
  return {
    line: lines.length,
    column: lines[lines.length - 1].length + 1,
  }
}

function printable(char) {
  const codePoint = char.codePointAt(0)
  return codePoint === undefined ? char : `U+${codePoint.toString(16).toUpperCase().padStart(4, '0')}`
}

function collectStringRanges(content) {
  const ranges = []
  let i = 0
  let inLineComment = false
  let inBlockComment = false

  while (i < content.length) {
    const char = content[i]
    const next = content[i + 1]

    if (inLineComment) {
      if (char === '\n') inLineComment = false
      i += 1
      continue
    }
    if (inBlockComment) {
      if (char === '*' && next === '/') {
        inBlockComment = false
        i += 2
      } else {
        i += 1
      }
      continue
    }
    if (char === '/' && next === '/') {
      inLineComment = true
      i += 2
      continue
    }
    if (char === '/' && next === '*') {
      inBlockComment = true
      i += 2
      continue
    }
    if (char !== '\'' && char !== '"' && char !== '`') {
      i += 1
      continue
    }

    const quote = char
    const start = i
    i += 1
    while (i < content.length) {
      if (content[i] === '\\') {
        i += 2
        continue
      }
      if (content[i] === quote) {
        i += 1
        break
      }
      i += 1
    }
    ranges.push({ start, end: i })
  }
  return ranges
}

function checkFile(file, content) {
  const issues = []
  for (const match of content.matchAll(/[\s\S]/gu)) {
    const char = match[0]
    if (!isForbiddenChar(char)) continue
    issues.push({
      file,
      offset: match.index ?? 0,
      char,
      reason: 'raw icon character',
    })
  }
  const checkEscapes = isAppRuntimePath(file)
  for (const range of collectStringRanges(content)) {
    const token = content.slice(range.start, range.end)
    if (checkEscapes) {
      for (const match of token.matchAll(/\\u(?:\{[0-9a-fA-F]{1,6}\}|[0-9a-fA-F]{4})/g)) {
        const decoded = decodeUnicodeEscape(match[0])
        if (decoded === undefined || !isForbiddenChar(decoded)) continue
        const offset = range.start + (match.index ?? 0)
        issues.push({ file, offset, char: decoded, reason: 'escaped string icon character' })
      }
    }
  }
  return issues
}

const files = git(['ls-files', '-co', '--exclude-standard'])
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean)
  .filter(shouldScan)

const issues = []
for (const file of files) {
  const path = resolve(root, file)
  let content
  try {
    content = readFileSync(path, 'utf8')
  } catch {
    continue
  }
  issues.push(...checkFile(file, content))
}

if (issues.length > 0) {
  console.error('BLOCKED: string/emoji icon characters found. Use SymbolGlyph, KomaIconButton, or a typed icon API instead.')
  for (const issue of issues.slice(0, 80)) {
    const { line, column } = lineColumn(readFileSync(resolve(root, issue.file), 'utf8'), issue.offset)
    console.error(`- ${issue.file}:${line}:${column} ${issue.reason} ${printable(issue.char)}`)
  }
  if (issues.length > 80) {
    console.error(`... and ${issues.length - 80} more`)
  }
  process.exit(1)
}

console.log('string icon check PASS')

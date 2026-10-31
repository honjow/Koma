import { SourceManga } from './SourceModels'

// Mirrors Mihon's fixed migration search behavior: exact source order breaks
// ties, and the one-result shortcut applies only to a single search query.
function removeBracketed(text: string, forward: boolean): string {
  const opening = forward ? '([<{' : ')]}>'
  const closing = forward ? ')]}>' : '([<{'
  let depth = 0
  let result = ''
  for (let step = 0; step < text.length; step++) {
    const index = forward ? step : text.length - step - 1
    const char = text.charAt(index)
    if (opening.indexOf(char) >= 0) depth++
    else if (closing.indexOf(char) >= 0) { if (depth > 0) depth-- }
    else if (depth === 0) result = forward ? result + char : char + result
  }
  return result
}

function cleanMigrationTitle(title: string): string {
  const lower = title.toLocaleLowerCase()
  let cleaned = removeBracketed(lower, true)
  if (cleaned.length <= 5) cleaned = removeBracketed(lower, false)
  cleaned = cleaned.replace(/((- часть|- глава) \d*)/g, ' ').trim()
  const english = cleaned.replace(/[^a-zA-Z0-9\- ]/g, ' ')
  // Mihon counts replacement spaces as title text; a long Japanese title then
  // becomes empty. Count visible Latin text so real Unicode titles survive.
  cleaned = english.trim().length <= 5 ? cleaned.replace(/[^\p{L}0-9\- ]/gu, ' ') : english
  return cleaned.trim().replace(/ - /g, ' ').replace(/ +/g, ' ').trim()
}

export function migrationSearchQueries(title: string, deepSearch: boolean): string[] {
  if (!deepSearch) return [title]
  const normalized = cleanMigrationTitle(title)
  const cleaned = normalized.length > 0 ? normalized : title.trim()
  if (cleaned.length === 0) return []
  const words = cleaned.split(' ')
  const longest = words.slice().sort((a: string, b: string): number => b.length - a.length)
  const choices = [cleaned, longest.slice(0, 2).join(' '), longest.slice(0, 1).join(' '),
    words.slice(0, 2).join(' '), words.slice(0, 1).join(' ')]
  const result: string[] = []
  choices.forEach((choice: string): void => {
    const query = choice.trim()
    if (query.length > 0 && result.indexOf(query) < 0) result.push(query)
  })
  return result
}

function migrationSimilarity(left: string, right: string): number {
  const maxLength = Math.max(left.length, right.length)
  if (maxLength === 0) return 1
  // Keep only two rows; Java/Kotlin reference operates on UTF-16 code units.
  let previous: number[] = []
  for (let j = 0; j <= right.length; j++) previous.push(j)
  for (let i = 1; i <= left.length; i++) {
    const current: number[] = [i]
    for (let j = 1; j <= right.length; j++) {
      current.push(Math.min(previous[j] + 1, current[j - 1] + 1,
        previous[j - 1] + (left.charAt(i - 1) === right.charAt(j - 1) ? 0 : 1)))
    }
    previous = current
  }
  return 1 - previous[right.length] / maxLength
}

export function chooseMigrationCandidate(title: string, candidates: SourceManga[], deepSearch: boolean): SourceManga | undefined {
  const queryCount = migrationSearchQueries(title, deepSearch).length
  const sourceCleaned = deepSearch ? cleanMigrationTitle(title) : title
  const source = sourceCleaned.length > 0 ? sourceCleaned : title.trim()
  let selected: SourceManga | undefined = undefined
  let best = 0.4
  candidates.forEach((candidate: SourceManga): void => {
    const candidateCleaned = deepSearch ? cleanMigrationTitle(candidate.title) : candidate.title
    const candidateTitle = candidateCleaned.length > 0 ? candidateCleaned : candidate.title.trim()
    const score = queryCount === 1 && candidates.length === 1 ? 1 : migrationSimilarity(source, candidateTitle)
    if (score >= 0.4 && (selected === undefined || score > best)) {
      selected = candidate
      best = score
    }
  })
  return selected
}

export interface MigrationNumberedChapter { chapterNumber?: number }
export function latestMigrationChapter(chapters: MigrationNumberedChapter[]): number | undefined {
  let latest: number | undefined = undefined
  chapters.forEach((chapter: MigrationNumberedChapter): void => {
    const number = chapter.chapterNumber
    if (number !== undefined && Number.isFinite(number) && (latest === undefined || number > latest)) latest = number
  })
  return latest
}

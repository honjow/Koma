/** Display-only formatting: keep a creator's internal spaces together while
 * allowing line breaks between names. Never modify the stored source text. */
export function formatMangaCreatorList(value: string): string {
  let output = ''
  let creator = ''
  let depth = 0
  const appendCreator = (): void => {
    output += creator.trim().replace(/[ \t]+/g, '\u00a0')
    creator = ''
  }
  for (let i = 0; i < value.length; i++) {
    const char = value.charAt(i)
    if (char === '(' || char === '（' || char === '[' || char === '【') depth++
    else if (char === ')' || char === '）' || char === ']' || char === '】') depth = Math.max(0, depth - 1)
    if (depth === 0 && (char === ',' || char === '，' || char === '、')) {
      appendCreator()
      output += char === ',' ? ', ' : `${char}\u200b`
    } else {
      creator += char
    }
  }
  appendCreator()
  return output
}

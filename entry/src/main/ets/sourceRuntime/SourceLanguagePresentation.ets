import { i18n } from '@kit.LocalizationKit'

// Language autonyms, shared by source browsing and package management.
// Only presentation is normalized; package/index identifiers stay untouched.
const names: Map<string, string> = new Map()

export function sourceLanguageName(language: string): string {
  const code = language.trim()
  if (code.length === 0) return ''
  const cached = names.get(code)
  if (cached !== undefined) return cached
  const tag = code.replace(/_/g, '-')
  const normalized = tag.toLowerCase() === 'zh-cn' ? 'zh-Hans' :
    tag.toLowerCase() === 'zh-tw' ? 'zh-Hant' : tag
  let label = code
  try {
    label = i18n.System.getDisplayLanguage(normalized, normalized, true) || code
  } catch (_error) {
    // Unknown/custom codes retain the declaration rather than inventing a language.
  }
  names.set(code, label)
  return label
}

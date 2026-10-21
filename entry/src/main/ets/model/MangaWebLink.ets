export interface SourceMangaWebLink {
  kind?: string
  url?: string
}

/** Only source-supplied HTTP(S) pages are navigable; never derive one from a work ID. */
export function mangaHttpUrl(value: string | undefined): string | undefined {
  if (typeof value !== 'string') return undefined
  const url = value.trim()
  if (url === undefined || !/^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/i.test(url)) return undefined
  return url
}

export function sourceMangaWebUrl(links: SourceMangaWebLink[] | undefined, url: string | undefined): string | undefined {
  if (Array.isArray(links)) {
    for (const link of links) {
      if (link !== null && typeof link === 'object' && link.kind === 'source') {
        const page = mangaHttpUrl(link.url)
        if (page !== undefined) return page
      }
    }
  }
  return mangaHttpUrl(url)
}

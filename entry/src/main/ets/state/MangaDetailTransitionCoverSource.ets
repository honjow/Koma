import { Comic, ComicSourceKind, comicDisplayCover } from '../model/ComicModels'
import { SourceCoverHeaders } from '../model/SourceModels'

/** Keeps the host's exact cover-cache/request identity while the root flight owns its image. */
export class MangaDetailTransitionCoverSource {
  uri: string = ''
  sourceRuntimeId: string = ''
  sourceImageId: string = ''
  sourceMangaUrl: string = ''
  sourceCoverHeaders?: SourceCoverHeaders = undefined
  sourceKind?: ComicSourceKind = undefined
  remoteServerId: string = ''
  decodeMaxEdge: number = 320
}

/** The same display identity used by shelf cards, including local overrides. */
export function comicTransitionCoverSource(comic: Comic, decodeMaxEdge: number): MangaDetailTransitionCoverSource {
  const source = new MangaDetailTransitionCoverSource()
  source.uri = comicDisplayCover(comic) ?? ''
  source.sourceRuntimeId = comic.sourceRuntimeId ?? ''
  source.sourceImageId = comic.remoteResourceId ?? comic.id
  source.sourceMangaUrl = comic.sourcePath
  source.sourceKind = comic.sourceKind
  source.remoteServerId = comic.remoteServerId ?? ''
  source.decodeMaxEdge = decodeMaxEdge
  return source
}

export function sameTransitionCover(a: MangaDetailTransitionCoverSource | undefined,
  b: MangaDetailTransitionCoverSource | undefined): boolean {
  // Decode size is presentation geometry, not artwork identity.
  return a?.uri === b?.uri && a?.sourceRuntimeId === b?.sourceRuntimeId &&
    a?.sourceImageId === b?.sourceImageId && a?.sourceMangaUrl === b?.sourceMangaUrl &&
    a?.sourceKind === b?.sourceKind && a?.remoteServerId === b?.remoteServerId &&
    JSON.stringify(a?.sourceCoverHeaders) === JSON.stringify(b?.sourceCoverHeaders)
}

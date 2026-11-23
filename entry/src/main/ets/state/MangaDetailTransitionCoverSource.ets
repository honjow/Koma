import { ComicSourceKind } from '../model/ComicModels'
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

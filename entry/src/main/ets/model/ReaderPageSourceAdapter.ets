import {
  ReaderSessionConfig,
  getReaderSessionPageUri,
} from './ReaderSessionStore'

export enum ReaderPageRenderKind {
  MOCK_FALLBACK = 'mock_fallback',
  URI_PLACEHOLDER = 'uri_placeholder',
}

export interface ReaderPageRenderSource {
  kind: ReaderPageRenderKind
  uri: string
  fallbackPageIndex: number
}

export function createReaderPageRenderSource(config: ReaderSessionConfig, pageIndex: number): ReaderPageRenderSource {
  const uri = getReaderSessionPageUri(config, pageIndex)
  if (uri.length === 0 || uri.startsWith('mock://')) {
    return {
      kind: ReaderPageRenderKind.MOCK_FALLBACK,
      uri,
      fallbackPageIndex: pageIndex,
    }
  }
  return {
    kind: ReaderPageRenderKind.URI_PLACEHOLDER,
    uri,
    fallbackPageIndex: pageIndex,
  }
}

export type OpdsCatalogId = string

export enum OpdsVersion {
  OPDS_1 = 'opds1',
  OPDS_2 = 'opds2',
}

export enum OpdsLinkKind {
  NAVIGATION = 'navigation',
  ACQUISITION = 'acquisition',
  IMAGE = 'image',
  THUMBNAIL = 'thumbnail',
  SELF = 'self',
  NEXT = 'next',
  PREVIOUS = 'previous',
  ALTERNATE = 'alternate',
  UNSUPPORTED = 'unsupported',
}

export enum OpdsAcquisitionStatus {
  SUPPORTED = 'supported',
  UNSUPPORTED_TYPE = 'unsupported_type',
  UNSUPPORTED_FLOW = 'unsupported_flow',
}

export interface OpdsLink {
  href: string
  rel?: string
  type?: string
  title?: string
  kind: OpdsLinkKind
  acquisitionStatus?: OpdsAcquisitionStatus
}

export interface OpdsNavigationItem {
  id: OpdsCatalogId
  title: string
  href: string
  type?: string
}

export type OpdsCatalogDto = OpdsNavigationItem

export interface OpdsAcquisitionDto {
  href: string
  type?: string
  title?: string
  status: OpdsAcquisitionStatus
}

export interface OpdsImageDto {
  href: string
  type?: string
  title?: string
  isThumbnail: boolean
}

export interface OpdsPublication {
  id: OpdsCatalogId
  title: string
  summary?: string
  author?: string
  acquisitionLinks: OpdsLink[]
  unsupportedLinks: OpdsLink[]
  imageLinks: OpdsLink[]
  thumbnailLinks: OpdsLink[]
  links: OpdsLink[]
}

export type OpdsBookDto = OpdsPublication

export interface OpdsPublicationGroup {
  title: string
  navigation: OpdsCatalogDto[]
  publications: OpdsBookDto[]
}

export interface OpdsParseResult {
  version: OpdsVersion
  feedUrl: string
  title?: string
  navigation: OpdsCatalogDto[]
  publications: OpdsBookDto[]
  groups: OpdsPublicationGroup[]
  links: OpdsLink[]
}

export const OPDS_ACQUISITION_REL_PREFIX: string = 'http://opds-spec.org/acquisition'

export const OPDS_SUPPORTED_ACQUISITION_MIME_TYPES: string[] = [
  'application/zip',
  'application/x-cbz',
  'application/vnd.comicbook+zip',
]

export function createEmptyOpdsParseResult(version: OpdsVersion, feedUrl: string, title?: string): OpdsParseResult {
  return {
    version,
    feedUrl,
    title,
    navigation: [],
    publications: [],
    groups: [],
    links: [],
  }
}

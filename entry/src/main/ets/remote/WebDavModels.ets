export type WebDavServerId = string
export type WebDavCredentialRef = string

export enum WebDavAuthKind {
  NONE = 'none',
  BASIC = 'basic',
}

export enum DavComicCandidateKind {
  ARCHIVE = 'archive',
  IMAGE_FILE = 'image_file',
  IMAGE_COLLECTION = 'image_collection',
  UNSUPPORTED = 'unsupported',
}

export interface WebDavServerConfig {
  id: WebDavServerId
  name?: string
  baseUrl: string
  rootPath?: string
  authKind: WebDavAuthKind
  credentialRef?: WebDavCredentialRef
  allowInsecureHttp?: boolean
}

export interface WebDavResolvedCredential {
  credentialRef: WebDavCredentialRef
  basicToken?: string
}

export interface DavResource {
  href: string
  displayname?: string
  isCollection: boolean
  contentLength?: number
  contentType?: string
  lastModified?: string
  etag?: string
  candidateKind: DavComicCandidateKind
}

export interface DavComicCandidate {
  kind: DavComicCandidateKind
  href: string
  title: string
  resources: DavResource[]
}

export const WEBDAV_ARCHIVE_EXTENSIONS: string[] = [
  '.cbz',
  '.zip',
]

export const WEBDAV_IMAGE_EXTENSIONS: string[] = [
  '.jpg',
  '.jpeg',
  '.png',
  '.webp',
  '.gif',
  '.bmp',
]

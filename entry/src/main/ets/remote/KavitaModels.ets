export type KavitaServerId = string
export type KavitaCredentialRef = string
export type KavitaLibraryId = number
export type KavitaSeriesId = number

export interface KavitaServerConfig {
  id: KavitaServerId
  name: string
  baseUrl: string
  credentialRef: KavitaCredentialRef
}

export interface KavitaResolvedCredential {
  credentialRef: KavitaCredentialRef
  apiKey: string
}

export interface KavitaLibraryDto {
  id: KavitaLibraryId
  name: string
  type?: number
  lastScanned?: string
  coverImage?: string
  includeInSearch?: boolean
}

export interface KavitaSeriesDto {
  id: KavitaSeriesId
  name: string
  localizedName?: string
  sortName?: string
  pages?: number
  pagesRead?: number
  libraryId?: KavitaLibraryId
  libraryName?: string
  coverImage?: string
  lastChapterAdded?: string
  lastChapterAddedUtc?: string
}

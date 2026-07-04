export type KavitaServerId = string
export type KavitaCredentialRef = string
export type KavitaLibraryId = number

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

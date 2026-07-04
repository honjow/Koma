import { common } from '@kit.AbilityKit'
import { Comic } from './ComicModels'
import {
  AniListTrackerClient,
  AniListTrackerTitleSearchResult,
  HarmonyAniListTrackerHttpAdapter,
} from './AniListTrackerClient'
import {
  HarmonyMyAnimeListTrackerHttpAdapter,
  MyAnimeListTrackerClient,
  MyAnimeListTrackerTitleSearchResult,
} from './MyAnimeListTrackerClient'
import {
  AssetStoreTrackerCredentialSecretStore,
  ComicTrackerMapping,
  TrackerAccount,
  TrackerCredentialSecretStore,
  TrackerPreferences,
  TrackerPreferencesStore,
  TrackerProviderId,
  decodeTrackerSecretBytes,
} from './TrackerModels'

export type TrackerMappingSearchStatus = 'mapped' | 'skipped' | 'failed'
export type TrackerMappingSearchReason =
  'query_missing' |
  'account_missing' |
  'credential_missing' |
  'client_unavailable' |
  'confirmed_mapping_exists' |
  'results_empty' |
  'provider_failed'

export interface TrackerMappingSearchResult {
  status: TrackerMappingSearchStatus
  reason?: TrackerMappingSearchReason
  providerId?: TrackerProviderId
  mapping?: ComicTrackerMapping
}

export interface TrackerMappingSearchSummary {
  scannedCount: number
  mappedCount: number
  skippedCount: number
  failedCount: number
  results: TrackerMappingSearchResult[]
}

export interface TrackerMappingSearchServiceOptions {
  secretStore?: TrackerCredentialSecretStore
  aniListClient?: AniListTrackerClient
  myAnimeListClient?: MyAnimeListTrackerClient
}

interface TrackerTitleSearchCandidate {
  providerId: TrackerProviderId
  providerTitleId: string
  title: string
  nativeTitle?: string
}

interface RankedTrackerTitleSearchCandidate {
  candidate: TrackerTitleSearchCandidate
  confidence: number
}

interface TrackerProviderSearchResult {
  ok: boolean
  value?: TrackerTitleSearchCandidate[]
}

export class TrackerMappingSearchService {
  private context: common.UIAbilityContext
  private secretStore: TrackerCredentialSecretStore
  private aniListClient?: AniListTrackerClient
  private myAnimeListClient?: MyAnimeListTrackerClient

  constructor(context: common.UIAbilityContext, options: TrackerMappingSearchServiceOptions = {}) {
    this.context = context
    this.secretStore = options.secretStore ?? new AssetStoreTrackerCredentialSecretStore()
    this.aniListClient = options.aniListClient ?? new AniListTrackerClient(new HarmonyAniListTrackerHttpAdapter())
    this.myAnimeListClient = options.myAnimeListClient ?? new MyAnimeListTrackerClient(new HarmonyMyAnimeListTrackerHttpAdapter())
  }

  async refreshComicMappingCandidates(
    comic: Comic,
    preferredProviderId?: TrackerProviderId,
    now: number = Date.now(),
  ): Promise<TrackerMappingSearchSummary> {
    const query = this.searchQueryForComic(comic)
    const preferences = await this.preferencesStore().load()
    const providerIds = this.searchableProviderIds(preferences, preferredProviderId)
    const summary: TrackerMappingSearchSummary = {
      scannedCount: providerIds.length,
      mappedCount: 0,
      skippedCount: 0,
      failedCount: 0,
      results: [],
    }
    if (query.length === 0) {
      return this.singleSkipped(summary, preferredProviderId, 'query_missing')
    }
    if (providerIds.length === 0) {
      return this.singleSkipped(summary, preferredProviderId, 'account_missing')
    }
    for (let index = 0; index < providerIds.length; index += 1) {
      const providerId = providerIds[index]
      const result = await this.refreshProviderCandidate(preferences, comic, query, providerId, now)
      summary.results.push(result)
      if (result.status === 'mapped') {
        summary.mappedCount += 1
      } else if (result.status === 'failed') {
        summary.failedCount += 1
      } else {
        summary.skippedCount += 1
      }
    }
    return summary
  }

  private async refreshProviderCandidate(
    preferences: TrackerPreferences,
    comic: Comic,
    query: string,
    providerId: TrackerProviderId,
    now: number,
  ): Promise<TrackerMappingSearchResult> {
    const existing = this.findExistingMapping(preferences, comic.id, providerId)
    if (existing !== undefined && existing.mappingState === 'confirmed' && existing.userConfirmed) {
      return this.skipped(providerId, 'confirmed_mapping_exists')
    }
    const account = this.findConnectedAccount(preferences, providerId)
    if (providerId !== 'anilist' && (account === undefined || account.credentialAccountKey === undefined)) {
      return this.skipped(providerId, 'account_missing')
    }
    if (!this.hasSearchClient(providerId)) {
      return this.failed(providerId, 'client_unavailable')
    }
    const accessToken = account === undefined || account.credentialAccountKey === undefined
      ? undefined
      : await this.readAccessToken(account, providerId)
    if (providerId !== 'anilist' && accessToken === undefined) {
      return this.failed(providerId, 'credential_missing')
    }
    const providerResult = await this.searchProvider(providerId, accessToken, query)
    if (!providerResult.ok || providerResult.value === undefined) {
      return this.failed(providerId, 'provider_failed')
    }
    const best = this.bestCandidate(query, providerResult.value)
    if (best === undefined) {
      return this.skipped(providerId, 'results_empty')
    }
    const mapping: ComicTrackerMapping = {
      comicId: comic.id,
      providerId,
      providerTitleId: best.candidate.providerTitleId,
      providerTitle: best.candidate.title,
      mappingState: 'candidate',
      confidence: best.confidence,
      userConfirmed: false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    }
    const saved = await this.preferencesStore().upsertComicMapping(mapping)
    const normalized = this.findExistingMapping(saved, comic.id, providerId) ?? mapping
    return {
      status: 'mapped',
      providerId,
      mapping: normalized,
    }
  }

  private preferencesStore(): TrackerPreferencesStore {
    return new TrackerPreferencesStore(this.context, this.secretStore)
  }

  private searchableProviderIds(preferences: TrackerPreferences, preferredProviderId?: TrackerProviderId): TrackerProviderId[] {
    const ids: TrackerProviderId[] = []
    if (preferredProviderId === undefined || preferredProviderId === 'anilist') {
      ids.push('anilist')
    }
    preferences.accounts.forEach((account: TrackerAccount) => {
      if (account.status !== 'connected') {
        return
      }
      if (preferredProviderId !== undefined && account.providerId !== preferredProviderId) {
        return
      }
      if (!this.isSupportedSearchProvider(account.providerId)) {
        return
      }
      if (ids.indexOf(account.providerId) < 0) {
        ids.push(account.providerId)
      }
    })
    return ids
  }

  private isSupportedSearchProvider(providerId: TrackerProviderId): boolean {
    return providerId === 'anilist' || providerId === 'myanimelist'
  }

  private findExistingMapping(preferences: TrackerPreferences, comicId: string, providerId: TrackerProviderId): ComicTrackerMapping | undefined {
    return preferences.comicMappings.find((mapping: ComicTrackerMapping): boolean => {
      return mapping.comicId === comicId && mapping.providerId === providerId
    })
  }

  private findConnectedAccount(preferences: TrackerPreferences, providerId: TrackerProviderId): TrackerAccount | undefined {
    return preferences.accounts.find((account: TrackerAccount): boolean => {
      return account.providerId === providerId && account.status === 'connected'
    })
  }

  private hasSearchClient(providerId: TrackerProviderId): boolean {
    if (providerId === 'anilist') {
      return this.aniListClient !== undefined
    }
    if (providerId === 'myanimelist') {
      return this.myAnimeListClient !== undefined
    }
    return false
  }

  private async readAccessToken(account: TrackerAccount, providerId: TrackerProviderId): Promise<string | undefined> {
    if (account.credentialAccountKey === undefined) {
      return undefined
    }
    const tokenBytes = await this.secretStore.readToken({
      providerId,
      accountKey: account.credentialAccountKey,
      secretKind: 'access_token',
    })
    if (tokenBytes === undefined || tokenBytes.byteLength === 0) {
      return undefined
    }
    const token = decodeTrackerSecretBytes(tokenBytes).trim()
    return token.length === 0 ? undefined : token
  }

  private async searchProvider(
    providerId: TrackerProviderId,
    accessToken: string | undefined,
    query: string,
  ): Promise<TrackerProviderSearchResult> {
    if (providerId === 'myanimelist') {
      if (this.myAnimeListClient === undefined || accessToken === undefined) {
        return { ok: false }
      }
      const result = await this.myAnimeListClient.searchManga(accessToken, query, 1, 8)
      return {
        ok: result.ok,
        value: result.value?.map((item: MyAnimeListTrackerTitleSearchResult): TrackerTitleSearchCandidate => {
          return {
            providerId: item.providerId,
            providerTitleId: item.providerTitleId,
            title: item.title,
            nativeTitle: item.nativeTitle,
          }
        }),
      }
    }
    if (this.aniListClient === undefined) {
      return { ok: false }
    }
    const result = accessToken === undefined
      ? await this.aniListClient.searchPublicManga(query, 1, 8)
      : await this.aniListClient.searchManga(accessToken, query, 1, 8)
    return {
      ok: result.ok,
      value: result.value?.map((item: AniListTrackerTitleSearchResult): TrackerTitleSearchCandidate => {
        return {
          providerId: item.providerId,
          providerTitleId: item.providerTitleId,
          title: item.title,
          nativeTitle: item.nativeTitle,
        }
      }),
    }
  }

  private bestCandidate(query: string, candidates: TrackerTitleSearchCandidate[]): RankedTrackerTitleSearchCandidate | undefined {
    let best: RankedTrackerTitleSearchCandidate | undefined = undefined
    candidates.forEach((candidate: TrackerTitleSearchCandidate) => {
      const confidence = this.candidateConfidence(query, candidate)
      if (best === undefined || confidence > best.confidence) {
        best = {
          candidate,
          confidence,
        }
      }
    })
    return best
  }

  private candidateConfidence(query: string, candidate: TrackerTitleSearchCandidate): number {
    const normalizedQuery = this.normalizeTitleForMatch(query)
    const title = this.normalizeTitleForMatch(candidate.title)
    const nativeTitle = this.normalizeTitleForMatch(candidate.nativeTitle ?? '')
    if (normalizedQuery.length === 0 || title.length === 0) {
      return 0
    }
    if (title === normalizedQuery) {
      return 0.96
    }
    if (nativeTitle.length > 0 && nativeTitle === normalizedQuery) {
      return 0.9
    }
    if (title.indexOf(normalizedQuery) >= 0 || normalizedQuery.indexOf(title) >= 0) {
      return 0.82
    }
    if (nativeTitle.length > 0 && (nativeTitle.indexOf(normalizedQuery) >= 0 || normalizedQuery.indexOf(nativeTitle) >= 0)) {
      return 0.78
    }
    return 0.62
  }

  private normalizeTitleForMatch(value: string): string {
    return value.trim().toLocaleLowerCase().replace(/[\s._:;'"!?()[\]{}-]+/g, '')
  }

  private searchQueryForComic(comic: Comic): string {
    return comic.title.trim().replace(/\s+/g, ' ').slice(0, 120)
  }

  private singleSkipped(
    summary: TrackerMappingSearchSummary,
    providerId: TrackerProviderId | undefined,
    reason: TrackerMappingSearchReason,
  ): TrackerMappingSearchSummary {
    summary.scannedCount = providerId === undefined ? 0 : 1
    summary.skippedCount = 1
    summary.results = [this.skipped(providerId, reason)]
    return summary
  }

  private skipped(providerId: TrackerProviderId | undefined, reason: TrackerMappingSearchReason): TrackerMappingSearchResult {
    return {
      status: 'skipped',
      providerId,
      reason,
    }
  }

  private failed(providerId: TrackerProviderId, reason: TrackerMappingSearchReason): TrackerMappingSearchResult {
    return {
      status: 'failed',
      providerId,
      reason,
    }
  }
}

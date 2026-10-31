import { HarmonyTrackerJsonAdapter, RemoteTrackerLogin, RemoteTrackerProfile, RemoteTrackerProgress,
  RemoteTrackerResult, RemoteTrackerTitle, TrackerJsonAdapter, TrackerJsonClient } from './AdditionalTrackerClients'

interface KitsuError { message?: string; extensions?: KitsuErrorExtension }
interface KitsuErrorExtension { code?: string }
interface KitsuResponse<T> { data?: T; errors?: KitsuError[] }
interface KitsuGraphRequest { query: string; variables: Object }
interface KitsuToken { access_token?: string }
interface KitsuProfile { name?: string }
interface KitsuAccount { id?: string; profile?: KitsuProfile }
interface KitsuAccountData { currentAccount?: KitsuAccount }
interface KitsuTitles { preferred?: string }
interface KitsuManga { id?: string; titles?: KitsuTitles }
interface KitsuSearch { nodes?: KitsuManga[] }
interface KitsuSearchData { searchMangaByTitle?: KitsuSearch }
interface KitsuEntry { id?: string; progress?: number; status?: string }
interface KitsuMangaEntry { myLibraryEntry?: KitsuEntry }
interface KitsuProgressData { findMangaById?: KitsuMangaEntry }
interface KitsuMutationPayload { errors?: KitsuError[]; libraryEntry?: KitsuEntry }
interface KitsuMutations { create?: KitsuMutationPayload; update?: KitsuMutationPayload }
interface KitsuMutationData { libraryEntry?: KitsuMutations }
interface KitsuSearchVariables { query: string }
interface KitsuIdVariables { id: string }
interface KitsuUpdateInput { id: string; progress: number }
interface KitsuUpdateVariables { input: KitsuUpdateInput }
interface KitsuCreateInput { mediaId: string; mediaType: string; status: string; progress: number; private: boolean }
interface KitsuCreateVariables { input: KitsuCreateInput }

/** Kitsu's official password grant needs no embedded third-party client credentials.
 * Existing entries update only progress: ratings, privacy, dates and state remain remote-owned.
 * Official GraphQL LibraryEntryUpdateInput confirms these other fields are optional.
 */
export class KitsuTrackerClient extends TrackerJsonClient {
  constructor(adapter: TrackerJsonAdapter = new HarmonyTrackerJsonAdapter()) { super(adapter, 'https://kitsu.app/api') }

  async login(email: string, password: string): Promise<RemoteTrackerResult<RemoteTrackerLogin>> {
    if (email.trim().length === 0 || password.length === 0) return { ok: false, errorCode: 'auth_required' }
    const fields: Record<string, string> = {}
    fields['username'] = email.trim()
    fields['password'] = password
    fields['grant_type'] = 'password'
    const result = await this.sendForm<KitsuToken>('/oauth/token', fields)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    const token = result.value?.access_token
    if (!token) return { ok: false, errorCode: 'malformed_response' }
    const profile = await this.fetchProfile(token)
    if (!profile.ok || profile.value === undefined) return { ok: false, errorCode: profile.errorCode }
    const login: RemoteTrackerLogin = { token, profile: profile.value }
    return { ok: true, value: login }
  }

  async fetchProfile(token: string): Promise<RemoteTrackerResult<RemoteTrackerProfile>> {
    if (token.trim().length === 0) return { ok: false, errorCode: 'auth_required' }
    const variables: Record<string, string> = {}
    const result = await this.graph<KitsuAccountData>(
      'query KomaAccount { currentAccount { id profile { name } } }', variables, token)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    const account = result.value?.currentAccount
    if (!account) return { ok: false, errorCode: 'unauthorized' }
    if (!account.id || !account.profile?.name) return { ok: false, errorCode: 'malformed_response' }
    return { ok: true, value: { providerId: 'kitsu', providerUserId: account.id,
      username: account.profile.name, displayName: account.profile.name } }
  }

  async searchManga(token: string, query: string): Promise<RemoteTrackerResult<RemoteTrackerTitle[]>> {
    if (query.trim().length === 0) return { ok: true, value: [] }
    const variables: KitsuSearchVariables = { query: query.trim().slice(0, 120) }
    const result = await this.graph<KitsuSearchData>(
      'query KomaSearch($query: String!) { searchMangaByTitle(title: $query, first: 20) { nodes { id titles { preferred } } } }',
      variables, token)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    const nodes = result.value?.searchMangaByTitle?.nodes
    if (!Array.isArray(nodes)) return { ok: false, errorCode: 'malformed_response' }
    return { ok: true, value: nodes!.filter((manga: KitsuManga): boolean =>
      /^\d+$/.test(manga.id ?? '') && (manga.titles?.preferred?.length ?? 0) > 0)
      .map((manga: KitsuManga): RemoteTrackerTitle => ({ providerId: 'kitsu', providerTitleId: manga.id!,
        title: manga.titles!.preferred! })) }
  }

  private async readEntry(token: string, id: string): Promise<RemoteTrackerResult<KitsuEntry>> {
    if (!/^\d+$/.test(id)) return { ok: false, errorCode: 'not_found' }
    const variables: KitsuIdVariables = { id }
    const result = await this.graph<KitsuProgressData>(
      'query KomaProgress($id: ID!) { findMangaById(id: $id) { myLibraryEntry { id progress status } } }', variables, token)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    if (!result.value?.findMangaById) return { ok: false, errorCode: 'not_found' }
    const entry = result.value.findMangaById.myLibraryEntry
    if (!entry) return { ok: true }
    if (!entry.id || !entry.status || !Number.isFinite(entry.progress)) return { ok: false, errorCode: 'malformed_response' }
    return { ok: true, value: entry }
  }

  async fetchProgress(token: string, id: string): Promise<RemoteTrackerResult<RemoteTrackerProgress | undefined>> {
    const result = await this.readEntry(token, id)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    const entry = result.value
    return entry === undefined ? { ok: true } : { ok: true, value: { providerId: 'kitsu', providerTitleId: id,
      progress: Math.max(0, entry.progress!), completed: entry.status === 'COMPLETED', status: entry.status } }
  }

  async pushProgress(token: string, id: string, progress: number): Promise<RemoteTrackerResult<RemoteTrackerProgress>> {
    const before = await this.readEntry(token, id)
    if (!before.ok) return { ok: false, errorCode: before.errorCode }
    const count = Math.max(0, Math.floor(progress))
    let result: RemoteTrackerResult<KitsuMutationData>
    if (before.value === undefined) {
      const variables: KitsuCreateVariables = { input: { mediaId: id, mediaType: 'MANGA',
        status: count > 0 ? 'CURRENT' : 'PLANNED', progress: count, private: false } }
      result = await this.graph<KitsuMutationData>(
        'mutation KomaAdd($input: LibraryEntryCreateInput!) { libraryEntry { create(input: $input) { errors { message } libraryEntry { id } } } }',
        variables, token)
    } else {
      const variables: KitsuUpdateVariables = { input: { id: before.value.id!, progress: count } }
      result = await this.graph<KitsuMutationData>(
        'mutation KomaUpdate($input: LibraryEntryUpdateInput!) { libraryEntry { update(input: $input) { errors { message } libraryEntry { id } } } }',
        variables, token)
    }
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    const saved = before.value === undefined ? result.value?.libraryEntry?.create : result.value?.libraryEntry?.update
    if (!saved?.libraryEntry?.id || (saved.errors?.length ?? 0) > 0) return { ok: false, errorCode: 'provider_error' }
    const verified = await this.fetchProgress(token, id)
    return verified.ok && verified.value !== undefined ? { ok: true, value: verified.value } :
      { ok: false, errorCode: verified.errorCode ?? 'malformed_response' }
  }

  private async graph<T>(query: string, variables: Object, token: string): Promise<RemoteTrackerResult<T>> {
    const body: KitsuGraphRequest = { query, variables }
    const result = await this.send<KitsuResponse<T>>('POST', '/graphql', token, body)
    if (!result.ok) return { ok: false, errorCode: result.errorCode }
    if ((result.value?.errors?.length ?? 0) > 0) return { ok: false,
      errorCode: result.value!.errors!.some((error: KitsuError): boolean =>
        error.extensions?.code === 'UNAUTHENTICATED') ? 'unauthorized' : 'provider_error' }
    return result.value?.data !== undefined ? { ok: true, value: result.value.data } :
      { ok: false, errorCode: 'malformed_response' }
  }
}

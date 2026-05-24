import { taskpool } from '@kit.ArkTS'
import { SourceManga, SourceMangaList, SourceMangaStatus } from '../model/SourceModels'
import { SourceRuntimeCallResponse } from '../sourceRuntime/NativeSourceRuntime'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import {
  SourceRuntimeRegistryEntry,
  SourceRuntimeRegistry,
  SourceRuntimeRegistryInstalledSourceSummary,
} from '../sourceRuntime/SourceRuntimeRegistry'

export type BrowseSourceSection = 'popular' | 'latest'

type RuntimeValue = Object | string | number | boolean | null
type RuntimeRecord = Record<string, RuntimeValue>

interface SourceOperationPageArg {
  cursor: string | null
  limit: number
}

interface SourceHomeArgs {
}

interface SourceSearchArgs {
  query: string
  page: SourceOperationPageArg
}

interface SourceMangaListFilters {
}

interface SourceMangaListArgs {
  listingId: string
  page: SourceOperationPageArg
  filters: SourceMangaListFilters
}

type SourceOperationArgs = SourceHomeArgs | SourceSearchArgs | SourceMangaListArgs

interface SourceOperationSettings {
}

interface SourceOperationHostHints {
  network: boolean
}

interface SourceOperationRequest {
  type: string
  version: number
  requestId: string
  operation: string
  sourceId: string
  args: SourceOperationArgs
  settings: SourceOperationSettings
  hostHints: SourceOperationHostHints
}

const SOURCE_OPERATION_PAGE_SIZE: number = 20

@Concurrent
async function runBrowseSourceOperationTask(requestJson: string, wasmBytes: Uint8Array): Promise<string> {
  const mod: Record<string, Object> = await import('libkoma_source_runtime.so') as Record<string, Object>
  const nativeRuntime = (mod.default ?? mod) as Record<string, Function>
  return nativeRuntime.runJsonCallFromBytes(requestJson, wasmBytes) as string
}

function optionalString(value: RuntimeValue | undefined): string | undefined {
  if (typeof value !== 'string' || value.trim().length === 0) {
    return undefined
  }
  return value
}

function normalizeStatus(value: RuntimeValue | undefined): SourceMangaStatus {
  const status = optionalString(value)
  if (status === 'ongoing' || status === 'completed' || status === 'hiatus' || status === 'cancelled') {
    return status as SourceMangaStatus
  }
  return 'unknown'
}

function normalizeStringArray(value: RuntimeValue | undefined): string[] | undefined {
  if (!Array.isArray(value)) {
    return undefined
  }
  const tags: string[] = []
  value.forEach((item: RuntimeValue) => {
    if (typeof item === 'string' && item.trim().length > 0) {
      tags.push(item)
    }
  })
  return tags.length > 0 ? tags : undefined
}

function itemRecord(value: RuntimeValue): RuntimeRecord | undefined {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    return undefined
  }
  return value as RuntimeRecord
}

function parseSourceMangaFromItem(sourceId: string, item: RuntimeRecord): SourceManga {
  const title = optionalString(item['title']) ?? optionalString(item['id']) ?? '未命名漫画'
  return {
    id: optionalString(item['id']) ?? title,
    sourceId,
    title,
    author: optionalString(item['author']),
    artist: optionalString(item['artist']),
    description: optionalString(item['description']),
    coverUrl: optionalString(item['cover_url']) ?? optionalString(item['coverUrl']),
    status: normalizeStatus(item['status']),
    contentRating: optionalString(item['content_rating']) ?? optionalString(item['contentRating']),
    tags: normalizeStringArray(item['tags']),
    url: optionalString(item['url']),
  }
}

function parseSourceMangaListFromResponse(sourceId: string, response: SourceRuntimeCallResponse): SourceMangaList {
  if (response.ok !== true) {
    return { manga: [], hasNextPage: false }
  }
  const data = response.data as RuntimeRecord | undefined
  const rawItems = data?.['items']
  const manga: SourceManga[] = []
  if (Array.isArray(rawItems)) {
    rawItems.forEach((rawItem: RuntimeValue) => {
      const directItem = itemRecord(rawItem)
      if (directItem === undefined) {
        return
      }
      const nestedItems = directItem['items']
      if (Array.isArray(nestedItems)) {
        nestedItems.forEach((nestedRawItem: RuntimeValue) => {
          const nestedItem = itemRecord(nestedRawItem)
          if (nestedItem !== undefined) {
            manga.push(parseSourceMangaFromItem(sourceId, nestedItem))
          }
        })
        return
      }
      manga.push(parseSourceMangaFromItem(sourceId, directItem))
    })
  }
  const hasNextPage = data?.['hasNextPage'] === true || data?.['has_more'] === true || data?.['hasMore'] === true
  return { manga, hasNextPage }
}

@Observed
export class BrowseViewModel {
  sources: SourceRuntimeRegistryInstalledSourceSummary[] = []
  popularManga: SourceManga[] = []
  latestManga: SourceManga[] = []
  searchResults: SourceManga[] = []
  selectedSource?: SourceRuntimeRegistryInstalledSourceSummary
  browsePage: number = 1
  searchPage: number = 1
  hasMoreBrowse: boolean = false
  hasMoreSearch: boolean = false
  loadingSources: boolean = false
  loadingBrowse: boolean = false
  loadingSearch: boolean = false
  errorMessage: string = ''
  searchQuery: string = ''

  constructor(registry?: SourceRuntimeRegistry) {
    this.registry = registry ?? appSourceRuntimeRegistry
  }

  private registry: SourceRuntimeRegistry

  loadInstalledSources(): void {
    this.loadingSources = true
    this.errorMessage = ''
    try {
      this.sources = this.registry.listInstalledSourceSummaries()
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : '无法加载源'
      this.sources = []
    } finally {
      this.loadingSources = false
    }
  }

  setSelectedSource(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.selectedSource = source
    this.popularManga = []
    this.latestManga = []
    this.browsePage = 1
    this.hasMoreBrowse = false
    this.errorMessage = ''
  }

  async loadBrowseHome(source: SourceRuntimeRegistryInstalledSourceSummary): Promise<void> {
    this.setSelectedSource(source)
    this.loadingBrowse = true
    this.errorMessage = ''
    try {
      const homeArgs: SourceHomeArgs = {}
      const home = await this.runSourceOperation(source.sourceId, 'get_home', homeArgs, 1)
      this.popularManga = home.manga
      const latest = await this.loadMangaList(source, 'latest', 1)
      this.latestManga = latest.manga
      this.hasMoreBrowse = home.hasNextPage || latest.hasNextPage
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : '源浏览失败'
      this.popularManga = []
      this.latestManga = []
      this.hasMoreBrowse = false
    } finally {
      this.loadingBrowse = false
    }
  }

  async loadMoreBrowse(): Promise<void> {
    if (this.loadingBrowse || !this.hasMoreBrowse || this.selectedSource === undefined) {
      return
    }
    this.loadingBrowse = true
    this.errorMessage = ''
    try {
      this.browsePage += 1
      const more = await this.loadMangaList(this.selectedSource, 'popular', this.browsePage)
      this.popularManga = this.popularManga.concat(more.manga)
      this.hasMoreBrowse = more.hasNextPage
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : '加载更多失败'
      this.hasMoreBrowse = false
    } finally {
      this.loadingBrowse = false
    }
  }

  async runSearch(source: SourceRuntimeRegistryInstalledSourceSummary, query: string): Promise<void> {
    this.selectedSource = source
    this.searchQuery = query
    this.searchPage = 1
    this.loadingSearch = true
    this.errorMessage = ''
    try {
      const normalizedQuery = query.trim()
      if (normalizedQuery.length === 0) {
        this.searchResults = []
        this.hasMoreSearch = false
        return
      }
      const result = await this.searchSource(source, normalizedQuery, 1)
      this.searchResults = result.manga
      this.hasMoreSearch = result.hasNextPage
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : '搜索失败'
      this.searchResults = []
      this.hasMoreSearch = false
    } finally {
      this.loadingSearch = false
    }
  }

  async loadMoreSearch(): Promise<void> {
    if (this.loadingSearch || !this.hasMoreSearch || this.selectedSource === undefined || this.searchQuery.trim().length === 0) {
      return
    }
    this.loadingSearch = true
    this.errorMessage = ''
    try {
      this.searchPage += 1
      const more = await this.searchSource(this.selectedSource, this.searchQuery.trim(), this.searchPage)
      this.searchResults = this.searchResults.concat(more.manga)
      this.hasMoreSearch = more.hasNextPage
    } catch (error) {
      const e = error as Error
      this.errorMessage = e.message.length > 0 ? e.message : '加载更多失败'
      this.hasMoreSearch = false
    } finally {
      this.loadingSearch = false
    }
  }

  async searchSource(source: SourceRuntimeRegistryInstalledSourceSummary, query: string, page: number): Promise<SourceMangaList> {
    const pageArg: SourceOperationPageArg = {
      cursor: page <= 1 ? null : `${page}`,
      limit: SOURCE_OPERATION_PAGE_SIZE,
    }
    const args: SourceSearchArgs = {
      query,
      page: pageArg,
    }
    return this.runSourceOperation(source.sourceId, 'search', args, page)
  }

  async loadMangaList(
    source: SourceRuntimeRegistryInstalledSourceSummary,
    section: BrowseSourceSection,
    page: number,
  ): Promise<SourceMangaList> {
    const pageArg: SourceOperationPageArg = {
      cursor: page <= 1 ? null : `${page}`,
      limit: SOURCE_OPERATION_PAGE_SIZE,
    }
    const filters: SourceMangaListFilters = {}
    const args: SourceMangaListArgs = {
      listingId: section === 'latest' ? 'listing:latest' : 'listing:popular',
      page: pageArg,
      filters,
    }
    return this.runSourceOperation(source.sourceId, 'get_manga_list', args, page)
  }

  private async runSourceOperation(
    sourceId: string,
    operation: string,
    args: SourceOperationArgs,
    page: number,
  ): Promise<SourceMangaList> {
    const lookup = this.registry.lookup(sourceId)
    if (!lookup.ok || lookup.entry === undefined) {
      throw new Error('源未安装或不可用')
    }
    const requestJson = this.buildRequestJson(sourceId, operation, args, page)
    const wasmBytes = this.copyWasmBytes(lookup.entry)
    const responseJson = await taskpool.execute(runBrowseSourceOperationTask, requestJson, wasmBytes) as string
    const response = JSON.parse(responseJson) as SourceRuntimeCallResponse
    if (response.ok !== true) {
      throw new Error(this.runtimeErrorMessage(response))
    }
    return parseSourceMangaListFromResponse(sourceId, response)
  }

  private buildRequestJson(
    sourceId: string,
    operation: string,
    args: SourceOperationArgs,
    page: number,
  ): string {
    const settings: SourceOperationSettings = {}
    const hostHints: SourceOperationHostHints = { network: true }
    const request: SourceOperationRequest = {
      type: 'request',
      version: 1,
      requestId: `browse-${operation}-${sourceId}-${page}-${Date.now()}`,
      operation,
      sourceId,
      args,
      settings,
      hostHints,
    }
    return JSON.stringify(request)
  }

  private copyWasmBytes(entry: SourceRuntimeRegistryEntry): Uint8Array {
    const copy = new Uint8Array(entry.wasmBytes.byteLength)
    copy.set(entry.wasmBytes)
    return copy
  }

  private runtimeErrorMessage(response: SourceRuntimeCallResponse): string {
    if (typeof response.reasonCode === 'string' && response.reasonCode.length > 0) {
      return `源运行失败：${response.reasonCode}`
    }
    const errorMessage = response.error?.['message']
    if (typeof errorMessage === 'string' && errorMessage.length > 0) {
      return `源运行失败：${errorMessage}`
    }
    return '源运行失败'
  }

  sourceLanguageBadge(source: SourceRuntimeRegistryInstalledSourceSummary): string {
    const lowered = source.sourceId.toLocaleLowerCase()
    if (lowered.indexOf('zh') >= 0 || lowered.indexOf('cn') >= 0) {
      return 'ZH'
    }
    if (lowered.indexOf('ja') >= 0 || lowered.indexOf('jp') >= 0) {
      return 'JA'
    }
    if (lowered.indexOf('en') >= 0) {
      return 'EN'
    }
    return 'SRC'
  }
}

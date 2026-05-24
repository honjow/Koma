import { SourceManga, SourceMangaList } from '../model/SourceModels'
import {
  SourceRuntimeRegistry,
  SourceRuntimeRegistryInstalledSourceSummary,
} from '../sourceRuntime/SourceRuntimeRegistry'

export type BrowseSourceSection = 'popular' | 'latest'

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

  constructor(private readonly registry: SourceRuntimeRegistry = new SourceRuntimeRegistry()) {
  }

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

  loadBrowseHome(source: SourceRuntimeRegistryInstalledSourceSummary): void {
    this.setSelectedSource(source)
    this.loadingBrowse = true
    try {
      const popular = this._mockSourceMangaList(source.sourceId, 'popular', 1)
      const latest = this._mockSourceMangaList(source.sourceId, 'latest', 1)
      this.popularManga = popular.manga
      this.latestManga = latest.manga
      this.hasMoreBrowse = popular.hasNextPage || latest.hasNextPage
    } finally {
      this.loadingBrowse = false
    }
  }

  loadMoreBrowse(): void {
    if (this.loadingBrowse || !this.hasMoreBrowse || this.selectedSource === undefined) {
      return
    }
    this.loadingBrowse = true
    try {
      this.browsePage += 1
      const more = this._mockSourceMangaList(this.selectedSource.sourceId, 'popular', this.browsePage)
      this.popularManga = this.popularManga.concat(more.manga)
      this.hasMoreBrowse = more.hasNextPage
    } finally {
      this.loadingBrowse = false
    }
  }

  runSearch(source: SourceRuntimeRegistryInstalledSourceSummary, query: string): void {
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
      const result = this._mockSearchSourceMangaList(source.sourceId, normalizedQuery, 1)
      this.searchResults = result.manga
      this.hasMoreSearch = result.hasNextPage
    } finally {
      this.loadingSearch = false
    }
  }

  loadMoreSearch(): void {
    if (this.loadingSearch || !this.hasMoreSearch || this.selectedSource === undefined || this.searchQuery.trim().length === 0) {
      return
    }
    this.loadingSearch = true
    try {
      this.searchPage += 1
      const more = this._mockSearchSourceMangaList(this.selectedSource.sourceId, this.searchQuery.trim(), this.searchPage)
      this.searchResults = this.searchResults.concat(more.manga)
      this.hasMoreSearch = more.hasNextPage
    } finally {
      this.loadingSearch = false
    }
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

  _mockSourceMangaList(sourceId: string, section: BrowseSourceSection, page: number): SourceMangaList {
    const titles = section === 'latest' ? [
      '今日更新的书店街',
      '星港快递员',
      '雨夜电车',
      '青空修复师',
      '第七间阅览室',
      '海风里的便签',
    ] : [
      '异世界书架管理员',
      '午后三点的龙',
      '纸月亮与灯塔',
      '黑猫编辑部',
      '旧城区侦探手记',
      '银河咖啡馆',
    ]
    const manga: SourceManga[] = titles.map((title: string, index: number): SourceManga => {
      const serial = (page - 1) * titles.length + index + 1
      return {
        id: `${section}-${serial}`,
        sourceId,
        title: page === 1 ? title : `${title} ${page}`,
        author: section === 'latest' ? 'Koma Mock' : 'Source Mock',
        description: 'Mock source manga used until runtime browse integration is enabled.',
        status: index % 2 === 0 ? 'ongoing' : 'unknown',
        tags: section === 'latest' ? ['最新'] : ['热门'],
      }
    })
    return {
      manga,
      hasNextPage: page < 2,
    }
  }

  private _mockSearchSourceMangaList(sourceId: string, query: string, page: number): SourceMangaList {
    const base = this._mockSourceMangaList(sourceId, 'popular', page).manga
    const manga = base.map((item: SourceManga, index: number): SourceManga => {
      return {
        id: `search-${page}-${index}-${query}`,
        sourceId,
        title: `${query} ${item.title}`,
        author: item.author,
        description: item.description,
        status: item.status,
        tags: ['搜索'],
      }
    })
    return {
      manga,
      hasNextPage: page < 2,
    }
  }
}

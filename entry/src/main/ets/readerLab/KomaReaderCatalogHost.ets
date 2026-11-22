import { ReaderCancellation, ReaderUnitKey } from '@reader-kit/core'
import { Comic } from '../model/ComicModels'
import { ReaderSessionConfig, cloneReaderSessionConfig } from '../model/ReaderSessionStore'

export interface KomaReaderChapterCatalogUpdate {
  continuation?: string[]
  chapterIds?: string[]
  chapterTitles?: string[]
}

/** Koma-owned catalog seam; reader-kit never resolves providers, downloads or library state. */
export class KomaReaderCatalogHost {
  private initialResolver: (work: string, unit: string) => ReaderSessionConfig | null
  private prepareResolver: (target: ReaderUnitKey,
    cancellation: ReaderCancellation, forceRefresh: boolean) => Promise<ReaderSessionConfig | null>
  private commitResolver: (target: ReaderUnitKey, config: ReaderSessionConfig) => void
  private sequenceResolver: ((target: ReaderUnitKey, cancellation: ReaderCancellation) =>
    Promise<KomaReaderChapterCatalogUpdate | undefined>) | null
  private workResolver: (work: string) => Comic | undefined

  constructor(
    initialResolver: (work: string, unit: string) => ReaderSessionConfig | null,
    prepareResolver: (target: ReaderUnitKey,
      cancellation: ReaderCancellation, forceRefresh: boolean) => Promise<ReaderSessionConfig | null>,
    commitResolver: (target: ReaderUnitKey, config: ReaderSessionConfig) => void,
    sequenceResolver: ((target: ReaderUnitKey, cancellation: ReaderCancellation) =>
      Promise<KomaReaderChapterCatalogUpdate | undefined>) | null,
    workResolver: (work: string) => Comic | undefined,
  ) {
    this.initialResolver = initialResolver
    this.prepareResolver = prepareResolver
    this.commitResolver = commitResolver
    this.sequenceResolver = sequenceResolver
    this.workResolver = workResolver
  }

  work(work: string): Comic | undefined { return this.workResolver(work) }

  initial(work: string, unit: string): ReaderSessionConfig | null {
    const config = this.initialResolver(work, unit)
    return config === null ? null : cloneReaderSessionConfig(config)
  }

  async prepare(target: ReaderUnitKey, cancellation: ReaderCancellation, forceRefresh: boolean = false): Promise<ReaderSessionConfig | null> {
    cancellation.check()
    const config = await this.prepareResolver(target.copy(), cancellation, forceRefresh)
    cancellation.check()
    return config === null ? null : cloneReaderSessionConfig(config)
  }

  commit(target: ReaderUnitKey, config: ReaderSessionConfig): void {
    if (config.comicId !== target.work || config.chapterId !== target.unit || config.totalPages < 1 ||
      config.pageUris.length !== config.totalPages) return
    this.commitResolver(target.copy(), cloneReaderSessionConfig(config))
  }

  async sequence(target: ReaderUnitKey, cancellation: ReaderCancellation): Promise<KomaReaderChapterCatalogUpdate | undefined> {
    cancellation.check()
    const result = await this.sequenceResolver?.(target.copy(), cancellation)
    cancellation.check()
    return result
  }
}

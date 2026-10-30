import { ReaderCancellation, ReaderUnitKey } from '@reader-kit/core'
import { ReaderSessionConfig, cloneReaderSessionConfig } from '../model/ReaderSessionStore'

/** Koma-owned catalog seam; reader-kit never resolves providers, downloads or library state. */
export class KomaReaderCatalogHost {
  private initialResolver: (work: string, unit: string) => ReaderSessionConfig | null
  private prepareResolver: (target: ReaderUnitKey,
    cancellation: ReaderCancellation, forceRefresh: boolean) => Promise<ReaderSessionConfig | null>
  private commitResolver: (target: ReaderUnitKey, config: ReaderSessionConfig) => void
  private sequenceResolver: ((target: ReaderUnitKey, cancellation: ReaderCancellation) =>
    Promise<string[] | undefined>) | null

  constructor(
    initialResolver: (work: string, unit: string) => ReaderSessionConfig | null,
    prepareResolver: (target: ReaderUnitKey,
      cancellation: ReaderCancellation, forceRefresh: boolean) => Promise<ReaderSessionConfig | null>,
    commitResolver: (target: ReaderUnitKey, config: ReaderSessionConfig) => void,
    sequenceResolver: ((target: ReaderUnitKey, cancellation: ReaderCancellation) =>
      Promise<string[] | undefined>) | null = null,
  ) {
    this.initialResolver = initialResolver
    this.prepareResolver = prepareResolver
    this.commitResolver = commitResolver
    this.sequenceResolver = sequenceResolver
  }

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

  async sequence(target: ReaderUnitKey, cancellation: ReaderCancellation): Promise<string[] | undefined> {
    cancellation.check()
    const result = await this.sequenceResolver?.(target.copy(), cancellation)
    cancellation.check()
    return result?.slice()
  }
}

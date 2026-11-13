import { MangaWebRouteParam } from '../common/RouterHelper'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'

/** One visible reader operation owns the sheet and its one-shot retry. */
export class ReaderSourceWebChallenge {
  readonly params: MangaWebRouteParam
  readonly current: () => boolean
  private resolve: ((verified: boolean) => void) | undefined

  constructor(params: MangaWebRouteParam, current: () => boolean, resolve: (verified: boolean) => void) {
    this.params = params
    this.current = current
    this.resolve = resolve
  }

  finish(verified: boolean): void {
    const resolve = this.resolve
    if (resolve === undefined) return
    this.resolve = undefined
    const session = this.params.sourceSession
    if (!verified && session !== undefined) appSourceWebSessionStore.cancel(session.sourceId, session.sessionId)
    resolve(verified)
  }
}

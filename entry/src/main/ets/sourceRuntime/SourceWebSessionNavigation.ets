import { MangaWebRouteParam, RouterHelper } from '../common/RouterHelper'
import { appSourceRuntimeRegistry } from './SourceRuntimeAppRegistry'
import { appSourceWebSessionStore } from './SourceWebSessionStore'

/** Prepare an origin-checked session without deciding how the host presents it. */
export function prepareSourceWebSession(sourceId: string, title: string): MangaWebRouteParam | undefined {
  try {
    const url = appSourceWebSessionStore.launchUrl(appSourceRuntimeRegistry, sourceId)
    const status = appSourceWebSessionStore.begin(appSourceRuntimeRegistry, sourceId, url)
    if (status.state !== 'pending') return undefined
    return { url, title, sourceSession: { sourceId, sessionId: status.sessionId } }
  } catch (_error) {
    return undefined
  }
}

/** Host-owned action: a source cannot open Web or grant itself access to the cookie jar. */
export function openSourceWebSession(sourceId: string, title: string, onCompleted: () => void): boolean {
  const params = prepareSourceWebSession(sourceId, title)
  if (params === undefined) return false
  params.onSessionCompleted = onCompleted
  try {
    RouterHelper.pushMangaWeb(params)
    return true
  } catch (_error) {
    const session = params.sourceSession
    if (session !== undefined) appSourceWebSessionStore.cancel(session.sourceId, session.sessionId)
    return false
  }
}

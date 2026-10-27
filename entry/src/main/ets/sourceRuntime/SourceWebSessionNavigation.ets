import { MangaWebRouteParam, RouterHelper } from '../common/RouterHelper'
import { appSourceRuntimeRegistry, sourceDisplayName } from './SourceRuntimeAppRegistry'
import { appSourceWebSessionStore } from './SourceWebSessionStore'

/** Prepare an origin-checked session without deciding how the host presents it. */
export function prepareSourceWebSession(sourceId: string, title: string): MangaWebRouteParam | undefined {
  try {
    const url = appSourceWebSessionStore.launchUrl(appSourceRuntimeRegistry, sourceId)
    // Verification sheets and full WebView routes must use the same localized
    // source identity as Browse, Search and the source manager.
    const displayName = sourceDisplayName(sourceId, title)
    const status = appSourceWebSessionStore.begin(appSourceRuntimeRegistry, sourceId, url)
    if (status.state !== 'pending') return undefined
    return { url, title: displayName, sourceSession: { sourceId, sessionId: status.sessionId } }
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

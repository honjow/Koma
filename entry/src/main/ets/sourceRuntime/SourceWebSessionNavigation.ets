import { RouterHelper } from '../common/RouterHelper'
import { appSourceRuntimeRegistry } from './SourceRuntimeAppRegistry'
import { appSourceWebSessionStore } from './SourceWebSessionStore'

/** Host-owned action: a source cannot open Web or grant itself access to the cookie jar. */
export function openSourceWebSession(sourceId: string, title: string, onCompleted: () => void): boolean {
  try {
    const url = appSourceWebSessionStore.launchUrl(appSourceRuntimeRegistry, sourceId)
    const status = appSourceWebSessionStore.begin(appSourceRuntimeRegistry, sourceId, url)
    if (status.state !== 'pending') return false
    RouterHelper.pushMangaWeb({
      url, title,
      sourceSession: { sourceId, sessionId: status.sessionId },
      onSessionCompleted: onCompleted,
    })
    return true
  } catch (_error) {
    return false
  }
}

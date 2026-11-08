import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'

const STORE = 'koma_manga_synopsis_v1'
let pendingFlush: Promise<void> = Promise.resolve()

/** Local presentation state, keyed by the same comic ID as the detail route. */
export class MangaSynopsisPreferences {
  static isExpanded(context: common.Context, comicId: string): boolean {
    try {
      return comicId.length > 0 && preferences.getPreferencesSync(context, { name: STORE }).getSync(comicId, false) === true
    } catch (_error) { return false }
  }

  static save(context: common.Context, comicId: string, expanded: boolean): Promise<void> {
    if (comicId.length === 0) return Promise.resolve()
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE })
      // A quick return to the same detail sees the new value before disk flush.
      if (expanded) store.putSync(comicId, true)
      else store.deleteSync(comicId)
      const write = pendingFlush.then((): Promise<void> => store.flush())
      pendingFlush = write.catch((): void => {})
      return write
    } catch (error) { return Promise.reject(error as Error) }
  }
}

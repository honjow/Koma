import { ReaderDisplayPolicy } from '@reader-kit/core'
import { ReaderLabRequest } from '@reader-kit/ui'
import { ReadingDirection } from '../model/ComicModels'
import { ReaderColumnMode, ReaderPreferences } from '../model/ReaderPreferencesStore'

/** Initial host mapping only; subsequent reader policy belongs to the session. */
export class KomaReaderInitialPolicy {
  static resolveHost(preferences: ReaderPreferences, column: ReaderColumnMode): ReaderDisplayPolicy {
    const policy = new ReaderDisplayPolicy()
    const vertical = preferences.pageMode === 'vertical_page'
    policy.layout = vertical ? 'single' :
      preferences.pageMode === 'continuous_scroll' || preferences.readingDirection === ReadingDirection.WEBTOON
        ? 'continuous' : preferences.pageMode === 'double_page' ? 'spread' : 'single'
    policy.pagingAxis = vertical ? 'vertical' : 'horizontal'
    policy.direction = preferences.readingDirection === ReadingDirection.RIGHT_TO_LEFT ? 'rtl' : 'ltr'
    policy.spreadLayout = preferences.spreadLayoutMode === 'split' ? 'split' : 'joined'
    policy.firstPageAlone = column === 'even_left'
    policy.splitWidePages = preferences.wideImageMode === 'split_wide_pages'
    policy.rotateWidePages = preferences.wideImageMode === 'rotate_wide_pages'
    return policy
  }

  static resolve(preferences: ReaderPreferences, column: ReaderColumnMode,
    request: ReaderLabRequest): ReaderDisplayPolicy {
    const policy = KomaReaderInitialPolicy.resolveHost(preferences, column)
    if (request.entryLayoutOverride === 'single' || request.entryLayoutOverride === 'spread' ||
      request.entryLayoutOverride === 'continuous') {
      policy.layout = request.entryLayoutOverride
      policy.pagingAxis = 'horizontal'
    }
    if (request.entryDirectionOverride === 'ltr' || request.entryDirectionOverride === 'rtl') {
      policy.direction = request.entryDirectionOverride
    }
    if (request.rotateWidePagesOverride !== null) {
      policy.rotateWidePages = request.rotateWidePagesOverride
      if (request.rotateWidePagesOverride) policy.splitWidePages = false
    }
    return policy
  }
}

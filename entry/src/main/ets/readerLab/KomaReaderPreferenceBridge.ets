import { ReaderDisplayPolicy } from '@reader-kit/core'
import { ReadingDirection } from '../model/ComicModels'
import { ReaderPreferences, normalizeReaderPreferences } from '../model/ReaderPreferencesStore'

/** Pure host mapping. reader-kit never imports or persists Koma preferences. */
export class KomaReaderPreferenceBridge {
  private static copy(current: ReaderPreferences): ReaderPreferences {
    return normalizeReaderPreferences({
      pageMode: current.pageMode,
      readingDirection: current.readingDirection,
      themeMode: current.themeMode,
      backgroundMode: current.backgroundMode,
      showProgressControls: current.showProgressControls,
      keepScreenAwake: current.keepScreenAwake,
      fullscreen: current.fullscreen,
      imageFitMode: current.imageFitMode,
      imageScalingQuality: current.imageScalingQuality,
      showPageNumber: current.showPageNumber,
      pageTurnAnimation: current.pageTurnAnimation,
      autoPageSeconds: current.autoPageSeconds,
      preloadPages: current.preloadPages,
      spreadLayoutMode: current.spreadLayoutMode,
      columnMode: current.columnMode,
      tapZonePreset: current.tapZonePreset,
      tapZoneInvert: current.tapZoneInvert,
      pageGapMode: current.pageGapMode,
      trimPageMarginsEnabled: current.trimPageMarginsEnabled,
      wideImageMode: current.wideImageMode,
      volumeKeyNavigationEnabled: current.volumeKeyNavigationEnabled,
      volumeKeyBehavior: current.volumeKeyBehavior,
      readerImplementation: current.readerImplementation === 'legacy' ? 'legacy' : 'shared',
    })
  }

  static applyPolicy(current: ReaderPreferences, policy: ReaderDisplayPolicy): ReaderPreferences {
    const next = KomaReaderPreferenceBridge.copy(current)
    next.pageMode = policy.layout === 'continuous' ? 'continuous_scroll' :
      policy.layout === 'spread' ? 'double_page' : policy.pagingAxis === 'vertical' ? 'vertical_page' : 'single_page'
    next.readingDirection = policy.layout === 'continuous' ? ReadingDirection.WEBTOON :
      policy.direction === 'rtl' ? ReadingDirection.RIGHT_TO_LEFT : ReadingDirection.LEFT_TO_RIGHT
    next.spreadLayoutMode = policy.spreadLayout === 'split' ? 'split' : 'joined'
    next.columnMode = policy.firstPageAlone ? 'even_left' : 'odd_left'
    next.wideImageMode = policy.splitWidePages ? 'split_wide_pages' :
      policy.rotateWidePages ? 'rotate_wide_pages' : 'keep_single'
    return normalizeReaderPreferences(next)
  }

  static applyCrop(current: ReaderPreferences, enabled: boolean): ReaderPreferences {
    const next = KomaReaderPreferenceBridge.copy(current)
    next.trimPageMarginsEnabled = enabled
    return normalizeReaderPreferences(next)
  }
}

import { RouteName } from './Constants'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'
import { SourceManga } from '../model/SourceModels'
import { MangaDetailRouteChromeState } from '../state/MangaDetailRouteChromeState'
import { SourceBrowseRouteChromeState, SourceSearchRouteChromeState } from '../state/SourceRouteChromeState'
import { SearchRouteChromeState } from '../state/SearchRouteChromeState'

export interface MangaDetailRouteParam {
  mangaId: string
  sourceId?: string
  initialManga?: SourceManga
  chrome?: MangaDetailRouteChromeState
}

export interface SearchRouteParam {
  query?: string
  chrome?: SearchRouteChromeState
}

export interface SourceRouteParam {
  source: SourceRuntimeRegistryInstalledSourceSummary
}

export interface SourceBrowseRouteParam {
  source: SourceRuntimeRegistryInstalledSourceSummary
  chrome: SourceBrowseRouteChromeState
}

export interface SourceSearchRouteParam {
  source: SourceRuntimeRegistryInstalledSourceSummary
  chrome: SourceSearchRouteChromeState
}

export class RouterHelper {
  private static appPathStack: NavPathStack | undefined = undefined
  private static pendingLaunchRoute: string | undefined = undefined
  /**
   * Reader sessions opened from a remote browse page are prepared by that
   * page before it asks the app to navigate.  Keep routing ownership in the
   * root host so those sessions receive the same lifecycle as library Reader
   * opens instead of bypassing Index state.
   */
  private static readerOpener: (() => void) | undefined = undefined

  static setAppPathStack(stack: NavPathStack): void {
    RouterHelper.appPathStack = stack
  }

  static setReaderOpener(opener: () => void): void {
    RouterHelper.readerOpener = opener
  }

  static getAppPathStack(): NavPathStack | undefined {
    return RouterHelper.appPathStack
  }

  static openLaunchRoute(routeName: string): void {
    if (routeName === RouteName.READER) {
      RouterHelper.pushReader()
      return
    }
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      RouterHelper.pendingLaunchRoute = routeName
      return
    }
    stack.pushPath({ name: routeName })
  }

  static consumePendingLaunchRoute(): void {
    const routeName = RouterHelper.pendingLaunchRoute
    if (routeName === undefined) {
      return
    }
    RouterHelper.pendingLaunchRoute = undefined
    RouterHelper.openLaunchRoute(routeName)
  }

  static pushReader(): void {
    const opener = RouterHelper.readerOpener
    if (opener !== undefined) {
      opener()
      return
    }
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      RouterHelper.pendingLaunchRoute = RouteName.READER
      return
    }
    stack.pushPath({ name: RouteName.READER })
  }

  static pushImport(): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    stack.pushPath({ name: RouteName.IMPORT })
  }

  static pushLibraryUpdateResults(): void {
    RouterHelper.openLaunchRoute(RouteName.LIBRARY_UPDATE_RESULTS)
  }

  static pushDownloads(): void {
    RouterHelper.openLaunchRoute(RouteName.DOWNLOADS)
  }

  static pushSourcePackageManager(): void {
    RouterHelper.openLaunchRoute(RouteName.SOURCE_PACKAGE_MANAGER)
  }

  static pushTrackerSettings(): void {
    RouterHelper.openLaunchRoute(RouteName.TRACKER_SETTINGS)
  }

  static pushMangaDetail(param: MangaDetailRouteParam): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    RouterHelper.ensureMangaDetailRouteChrome(param)
    stack.pushPath({ name: RouteName.MANGA_DETAIL, param: param })
  }

  static ensureMangaDetailRouteChrome(param: MangaDetailRouteParam): MangaDetailRouteChromeState {
    const existing = param.chrome
    if (existing !== undefined) {
      return existing
    }
    const chrome = new MangaDetailRouteChromeState()
    param.chrome = chrome
    return chrome
  }

  static pushSourceBrowse(param: SourceRouteParam): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    const routeParam: SourceBrowseRouteParam = {
      source: param.source,
      chrome: new SourceBrowseRouteChromeState(),
    }
    stack.pushPath({ name: RouteName.SOURCE_BROWSE, param: routeParam })
  }

  static pushSourceSearch(param: SourceRouteParam): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    const routeParam: SourceSearchRouteParam = {
      source: param.source,
      chrome: new SourceSearchRouteChromeState(param.source.displayName),
    }
    stack.pushPath({ name: RouteName.SOURCE_SEARCH, param: routeParam })
  }

  static ensureSearchRouteChrome(param: SearchRouteParam): SearchRouteChromeState {
    const existing = param.chrome
    if (existing !== undefined) {
      return existing
    }
    const chrome = new SearchRouteChromeState()
    const query = param.query?.trim() ?? ''
    if (query.length > 0) {
      chrome.updateQuery(query)
      chrome.submitQuery(query)
    }
    param.chrome = chrome
    return chrome
  }

  static openSearch(param: SearchRouteParam): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    RouterHelper.ensureSearchRouteChrome(param)
    stack.pushPath({ name: RouteName.SEARCH, param: param })
  }

  static pop(): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    stack.pop(false)
  }
}

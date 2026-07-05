import { RouteName } from './Constants'
import { SourceRuntimeRegistryInstalledSourceSummary } from '../sourceRuntime/SourceRuntimeRegistry'

export interface MangaDetailRouteParam {
  mangaId: string
  sourceId?: string
}

export interface SearchRouteParam {
  query: string
}

export interface SourceRouteParam {
  source: SourceRuntimeRegistryInstalledSourceSummary
}

export class RouterHelper {
  private static appPathStack: NavPathStack | undefined = undefined
  private static pendingLaunchRoute: string | undefined = undefined
  private static searchOpener: ((param: SearchRouteParam) => void) | undefined = undefined

  static setAppPathStack(stack: NavPathStack): void {
    RouterHelper.appPathStack = stack
  }

  static setSearchOpener(opener: (param: SearchRouteParam) => void): void {
    RouterHelper.searchOpener = opener
  }

  static getAppPathStack(): NavPathStack | undefined {
    return RouterHelper.appPathStack
  }

  static openLaunchRoute(routeName: string): void {
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
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
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
    stack.pushPath({ name: RouteName.MANGA_DETAIL, param: param })
  }

  static pushSourceBrowse(param: SourceRouteParam): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    stack.pushPath({ name: RouteName.SOURCE_BROWSE, param: param })
  }

  static pushSourceSearch(param: SourceRouteParam): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    stack.pushPath({ name: RouteName.SOURCE_SEARCH, param: param })
  }

  static openSearch(param: SearchRouteParam): void {
    const opener = RouterHelper.searchOpener
    if (opener === undefined) {
      return
    }
    opener(param)
  }

  static pop(): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    stack.pop(false)
  }
}

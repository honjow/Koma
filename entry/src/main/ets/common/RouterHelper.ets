import { RouteName } from './Constants'

export interface MangaDetailRouteParam {
  mangaId: string
  sourceId?: string
}

export class RouterHelper {
  private static appPathStack: NavPathStack | undefined = undefined
  private static pendingLaunchRoute: string | undefined = undefined

  static setAppPathStack(stack: NavPathStack): void {
    RouterHelper.appPathStack = stack
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

  static pushMangaDetail(param: MangaDetailRouteParam): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    stack.pushPath({ name: RouteName.MANGA_DETAIL, param: param })
  }

  static pop(): void {
    const stack = RouterHelper.appPathStack
    if (stack === undefined) {
      return
    }
    stack.pop(false)
  }
}

import { RouteName } from './Constants'

export interface MangaDetailRouteParam {
  comicId: string
}

export class RouterHelper {
  private static appPathStack: NavPathStack | undefined = undefined

  static setAppPathStack(stack: NavPathStack): void {
    RouterHelper.appPathStack = stack
  }

  static getAppPathStack(): NavPathStack | undefined {
    return RouterHelper.appPathStack
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

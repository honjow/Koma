/**
 * Mihon-style reader tap-zone geometry.
 * Pure geometry only: normalized 0..1 regions, layout presets and invert.
 * Reference: NextE feature/reader ReaderTapZoneResolver (Mihon normalized zones).
 * Hit testing and visual overlay both derive from these regions.
 */

export enum ReaderTapZoneLayout {
  RIGHT_LEFT = 'right_left',
  L_SHAPED = 'l_shaped',
  KINDLE = 'kindle',
}

export enum ReaderTapZoneInvert {
  NONE = 'none',
  HORIZONTAL = 'horizontal',
  VERTICAL = 'vertical',
  BOTH = 'both',
}

export type ReaderTapZoneAction = 'menu' | 'previous' | 'next' | 'left' | 'right'

export interface ReaderTapZoneRegion {
  key: string
  left: number
  top: number
  right: number
  bottom: number
  action: ReaderTapZoneAction
}

export class ReaderTapZoneResolver {
  static normalizeLayout(value: string): ReaderTapZoneLayout {
    if (value === ReaderTapZoneLayout.L_SHAPED ||
      value === ReaderTapZoneLayout.KINDLE) {
      return value
    }
    return ReaderTapZoneLayout.RIGHT_LEFT
  }

  static normalizeInvert(value: string): ReaderTapZoneInvert {
    if (value === ReaderTapZoneInvert.HORIZONTAL ||
      value === ReaderTapZoneInvert.VERTICAL ||
      value === ReaderTapZoneInvert.BOTH) {
      return value
    }
    return ReaderTapZoneInvert.NONE
  }

  /** Resolve the action for a tap in normalized 0..1 coordinates. */
  static resolve(
    layout: ReaderTapZoneLayout,
    invert: ReaderTapZoneInvert,
    x: number,
    y: number,
  ): ReaderTapZoneAction {
    const nx: number = ReaderTapZoneResolver.clamp01(x)
    const ny: number = ReaderTapZoneResolver.clamp01(y)
    const regions: ReaderTapZoneRegion[] = ReaderTapZoneResolver.regions(layout, invert)
    for (let i: number = 0; i < regions.length; i += 1) {
      if (ReaderTapZoneResolver.contains(regions[i], nx, ny)) {
        return regions[i].action
      }
    }
    return 'menu'
  }

  static regions(layout: ReaderTapZoneLayout, invert: ReaderTapZoneInvert): ReaderTapZoneRegion[] {
    const base: ReaderTapZoneRegion[] = ReaderTapZoneResolver.baseRegions(layout)
    if (invert === ReaderTapZoneInvert.NONE) {
      return base
    }
    const out: ReaderTapZoneRegion[] = []
    for (let i: number = 0; i < base.length; i += 1) {
      out.push(ReaderTapZoneResolver.invertRegion(base[i], invert))
    }
    return out
  }

  private static baseRegions(layout: ReaderTapZoneLayout): ReaderTapZoneRegion[] {
    const oneThird: number = 1 / 3
    const twoThirds: number = 2 / 3
    if (layout === ReaderTapZoneLayout.L_SHAPED) {
      return [
        ReaderTapZoneResolver.region('l-prev-top', 0, 0, 1, oneThird, 'previous'),
        ReaderTapZoneResolver.region('l-prev-left', 0, oneThird, oneThird, twoThirds, 'previous'),
        ReaderTapZoneResolver.region('l-menu', oneThird, oneThird, twoThirds, twoThirds, 'menu'),
        ReaderTapZoneResolver.region('l-next-right', twoThirds, oneThird, 1, twoThirds, 'next'),
        ReaderTapZoneResolver.region('l-next-bottom', 0, twoThirds, 1, 1, 'next'),
      ]
    }
    if (layout === ReaderTapZoneLayout.KINDLE) {
      return [
        ReaderTapZoneResolver.region('kindle-menu', 0, 0, 1, oneThird, 'menu'),
        ReaderTapZoneResolver.region('kindle-prev', 0, oneThird, oneThird, 1, 'previous'),
        ReaderTapZoneResolver.region('kindle-next', oneThird, oneThird, 1, 1, 'next'),
      ]
    }
    return [
      ReaderTapZoneResolver.region('right-left-left', 0, 0, oneThird, 1, 'left'),
      ReaderTapZoneResolver.region('right-left-menu', oneThird, 0, twoThirds, 1, 'menu'),
      ReaderTapZoneResolver.region('right-left-right', twoThirds, 0, 1, 1, 'right'),
    ]
  }

  private static region(
    key: string,
    left: number,
    top: number,
    right: number,
    bottom: number,
    action: ReaderTapZoneAction,
  ): ReaderTapZoneRegion {
    return { key: key, left: left, top: top, right: right, bottom: bottom, action: action }
  }

  private static invertRegion(region: ReaderTapZoneRegion, invert: ReaderTapZoneInvert): ReaderTapZoneRegion {
    const horizontal: boolean = invert === ReaderTapZoneInvert.HORIZONTAL || invert === ReaderTapZoneInvert.BOTH
    const vertical: boolean = invert === ReaderTapZoneInvert.VERTICAL || invert === ReaderTapZoneInvert.BOTH
    const left: number = horizontal ? 1 - region.right : region.left
    const right: number = horizontal ? 1 - region.left : region.right
    const top: number = vertical ? 1 - region.bottom : region.top
    const bottom: number = vertical ? 1 - region.top : region.bottom
    return {
      key: `${region.key}-${invert}`,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      action: region.action,
    }
  }

  private static contains(region: ReaderTapZoneRegion, x: number, y: number): boolean {
    const withinX: boolean = x >= region.left && (x < region.right || region.right === 1)
    const withinY: boolean = y >= region.top && (y < region.bottom || region.bottom === 1)
    return withinX && withinY
  }

  private static clamp01(value: number): number {
    if (value < 0) {
      return 0
    }
    if (value > 1) {
      return 1
    }
    return value
  }
}

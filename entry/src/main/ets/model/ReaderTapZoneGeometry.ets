import { ReaderTapZoneInvert, ReaderTapZonePreset } from './ReaderPreferencesStore'

export const READER_TAP_ACTION_PREVIOUS: string = 'previous'
export const READER_TAP_ACTION_NEXT: string = 'next'
export const READER_TAP_ACTION_MENU: string = 'menu'
// Kept as a source-compatible alias for callers written against the pre-NextE
// Koma name; new resolver output uses the exact NextE `menu` action.
export const READER_TAP_ACTION_CENTER: string = READER_TAP_ACTION_MENU

export type ReaderTapZoneAction = 'previous' | 'next' | 'left' | 'right' | 'menu' | 'center'

export interface ReaderTapZoneRegion {
  action: ReaderTapZoneAction
  left: number
  top: number
  right: number
  bottom: number
}

function invertRegion(
  region: ReaderTapZoneRegion,
  invert: ReaderTapZoneInvert,
): ReaderTapZoneRegion {
  if (invert === 'horizontal') {
    return {
      action: region.action,
      left: 1 - region.right,
      top: region.top,
      right: 1 - region.left,
      bottom: region.bottom,
    }
  }
  if (invert === 'vertical') {
    return {
      action: region.action,
      left: region.left,
      top: 1 - region.bottom,
      right: region.right,
      bottom: 1 - region.top,
    }
  }
  if (invert === 'both') {
    return {
      action: region.action,
      left: 1 - region.right,
      top: 1 - region.bottom,
      right: 1 - region.left,
      bottom: 1 - region.top,
    }
  }
  return region
}

export function readerTapZoneRegions(
  preset: ReaderTapZonePreset,
  invert: ReaderTapZoneInvert,
): ReaderTapZoneRegion[] {
  const oneThird = 1 / 3
  const twoThirds = 2 / 3
  let base: ReaderTapZoneRegion[]
  if (preset === 'l_shaped') {
    base = [
      { action: 'previous', left: 0, top: 0, right: 1, bottom: oneThird },
      { action: 'previous', left: 0, top: oneThird, right: oneThird, bottom: twoThirds },
      { action: 'menu', left: oneThird, top: oneThird, right: twoThirds, bottom: twoThirds },
      { action: 'next', left: twoThirds, top: oneThird, right: 1, bottom: twoThirds },
      { action: 'next', left: 0, top: twoThirds, right: 1, bottom: 1 },
    ]
  } else if (preset === 'kindle') {
    base = [
      { action: 'menu', left: 0, top: 0, right: 1, bottom: oneThird },
      { action: 'previous', left: 0, top: oneThird, right: oneThird, bottom: 1 },
      { action: 'next', left: oneThird, top: oneThird, right: 1, bottom: 1 },
    ]
  } else if (preset === 'edge' || preset === 'wide_edges') {
    base = [
      { action: 'next', left: 0, top: 0, right: oneThird, bottom: 1 },
      { action: 'menu', left: oneThird, top: 0, right: twoThirds, bottom: twoThirds },
      { action: 'previous', left: oneThird, top: twoThirds, right: twoThirds, bottom: 1 },
      { action: 'next', left: twoThirds, top: 0, right: 1, bottom: 1 },
    ]
  } else {
    base = [
      { action: 'left', left: 0, top: 0, right: oneThird, bottom: 1 },
      { action: 'menu', left: oneThird, top: 0, right: twoThirds, bottom: 1 },
      { action: 'right', left: twoThirds, top: 0, right: 1, bottom: 1 },
    ]
  }
  return base.map((region: ReaderTapZoneRegion): ReaderTapZoneRegion => {
    return invertRegion(region, invert)
  })
}

export function resolveReaderTapZoneAction(
  preset: ReaderTapZonePreset,
  invert: ReaderTapZoneInvert,
  x: number,
  y: number,
  viewWidth: number,
  viewHeight: number,
): ReaderTapZoneAction {
  if (viewWidth <= 0 || viewHeight <= 0) {
    return 'menu'
  }
  const normalizedX = Math.min(Math.max(x / viewWidth, 0), 1)
  const normalizedY = Math.min(Math.max(y / viewHeight, 0), 1)
  const regions = readerTapZoneRegions(preset, invert)
  for (let index = 0; index < regions.length; index += 1) {
    const region = regions[index]
    if (normalizedX >= region.left && normalizedX < region.right &&
      normalizedY >= region.top && normalizedY < region.bottom) {
      return region.action
    }
  }
  return 'menu'
}

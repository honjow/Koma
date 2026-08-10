import { ReaderTapZoneInvert, ReaderTapZonePreset } from './ReaderPreferencesStore'

export const READER_TAP_ACTION_PREVIOUS: string = 'previous'
export const READER_TAP_ACTION_NEXT: string = 'next'
export const READER_TAP_ACTION_CENTER: string = 'center'

export type ReaderTapZoneAction = 'previous' | 'next' | 'center'

export interface ReaderTapZoneRegion {
  action: ReaderTapZoneAction
  left: number
  top: number
  right: number
  bottom: number
}

function edgeLeftRatio(preset: ReaderTapZonePreset): number {
  return preset === 'wide_edges' ? 0.2 : 0.16
}

function edgeRightRatio(preset: ReaderTapZonePreset): number {
  return preset === 'wide_edges' ? 0.8 : 0.84
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
  const leftRatio = edgeLeftRatio(preset)
  const rightRatio = edgeRightRatio(preset)
  const base: ReaderTapZoneRegion[] = [
    { action: 'previous', left: 0, top: 0, right: leftRatio, bottom: 1 },
    { action: 'center', left: leftRatio, top: 0, right: rightRatio, bottom: 1 },
    { action: 'next', left: rightRatio, top: 0, right: 1, bottom: 1 },
  ]
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
    return 'center'
  }
  const normalizedX = x / viewWidth
  const normalizedY = y / viewHeight
  const regions = readerTapZoneRegions(preset, invert)
  for (let index = 0; index < regions.length; index += 1) {
    const region = regions[index]
    if (normalizedX >= region.left && normalizedX < region.right &&
      normalizedY >= region.top && normalizedY < region.bottom) {
      return region.action
    }
  }
  return 'center'
}

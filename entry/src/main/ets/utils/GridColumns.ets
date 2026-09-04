import { display } from '@kit.ArkUI'

/**
 * Single source of truth for cover-grid column counts. Callers pass design
 * widths (minimum cell width, gap, padding) and a measured container width;
 * column counts are always derived, never stored.
 */
export function gridColumnCount(
  measuredWidth: number,
  minCellWidth: number,
  gap: number,
  horizontalPadding: number,
): number {
  const contentWidth: number = Math.max(minCellWidth, measuredWidth - horizontalPadding * 2)
  const count: number = Math.floor((contentWidth + gap) / (minCellWidth + gap))
  return Math.max(1, count)
}

/**
 * Pre-measurement container estimate in vp for grids that span the window
 * width, so the first frame already uses the same column model.
 */
export function gridFallbackContainerWidth(): number {
  try {
    const displayInfo = display.getDefaultDisplaySync()
    return displayInfo.width / displayInfo.densityPixels
  } catch (_error) {
    return 0
  }
}

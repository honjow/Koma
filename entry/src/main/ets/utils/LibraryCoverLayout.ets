import { ThemeConstants } from '../theme/ThemeConstants'
import { gridColumnCount } from './GridColumns'

export const LIBRARY_GRID_MIN_COLUMN_WIDTH: number = 80
export const LIBRARY_GRID_MAX_COLUMN_WIDTH: number = 300

export function clampLibraryGridColumnWidth(width: number): number {
  return Math.min(LIBRARY_GRID_MAX_COLUMN_WIDTH, Math.max(LIBRARY_GRID_MIN_COLUMN_WIDTH, width))
}

/** Spacing is shared by shelf/source grids, independent of list size and cover
 * width. Column counts remain derived from the current viewport. */
export function libraryCoverGridGap(gridSpacing: string): number {
  if (gridSpacing === 'compact') return ThemeConstants.SPACE_SM
  if (gridSpacing === 'comfortable') return ThemeConstants.SPACE_XL
  return ThemeConstants.SPACE_MD
}

export function libraryCoverGridMinimumWidth(width: number, preferredWidth: number): number {
  if (preferredWidth > 0) return clampLibraryGridColumnWidth(preferredWidth)
  // Preserve the shelf's narrow-window target so standard phone layouts do
  // not collapse to two oversized covers.
  return width > 0 && width < 480 ? 96 : 112
}

export function libraryCoverGridColumnCount(width: number, gridSpacing: string, preferredWidth: number = 0): number {
  const target = libraryCoverGridMinimumWidth(width, preferredWidth)
  const gap = libraryCoverGridGap(gridSpacing)
  return gridColumnCount(width, target, gap, gap)
}

export function libraryCoverGridPinchWidth(width: number, density: string, startWidth: number,
  startColumns: number, scale: number): number {
  const next = clampLibraryGridColumnWidth(startWidth * scale)
  if (Math.abs(libraryCoverGridColumnCount(width, density, next) - startColumns) <= 1) return next
  // Keep the next column step even when a single input event crosses multiple boundaries.
  let allowed = startWidth
  let outside = next
  for (let i = 0; i < 14; i++) {
    const candidate = (allowed + outside) / 2
    if (Math.abs(libraryCoverGridColumnCount(width, density, candidate) - startColumns) <= 1) allowed = candidate
    else outside = candidate
  }
  return allowed
}

import { ThemeConstants } from '../theme/ThemeConstants'
import { gridColumnCount } from './GridColumns'

/** The existing shelf density is also the source-grid policy. Column counts
 * remain derived from the current viewport, never persisted as another setting. */
export function libraryCoverGridGap(density: string): number {
  if (density === 'compact') return ThemeConstants.SPACE_SM
  if (density === 'comfortable') return ThemeConstants.SPACE_XL
  return ThemeConstants.SPACE_MD
}

export function libraryCoverGridColumnCount(width: number, density: string): number {
  // Preserve the shelf's narrow-window target so standard phone layouts do
  // not collapse to two oversized covers.
  const target = density === 'compact' ? 96 : density === 'comfortable' ? 140 :
    width > 0 && width < 480 ? 96 : 112
  const gap = libraryCoverGridGap(density)
  return gridColumnCount(width, target, gap, gap)
}

export type LibraryGridSpacing = 'compact' | 'standard' | 'comfortable'

export interface LibraryGridPreferences {
  gridSpacing: LibraryGridSpacing
  gridColumnWidth: number
}

export function normalizedLibraryGridSpacing(value: string): LibraryGridSpacing {
  return value === 'compact' || value === 'comfortable' ? value : 'standard'
}

/** Before spacing was independent, list density also chose the implicit cover
 * width. Preserve that target once, rather than keeping a hidden density key.
 * An explicit width always wins; standard retains its responsive default. */
export function legacyLibraryGridPreferences(listDensity: string, preferredWidth: number): LibraryGridPreferences {
  const gridSpacing = normalizedLibraryGridSpacing(listDensity)
  return {
    gridSpacing,
    gridColumnWidth: Number.isFinite(preferredWidth) && preferredWidth > 0 ? preferredWidth :
      gridSpacing === 'compact' ? 96 : gridSpacing === 'comfortable' ? 140 : 0,
  }
}

// Mirrors NextE's scroll-origin boundary: programmatic Scroller movement must
// not be reported as a direct user scroll to callers that own visual state.
export function isUserScrollSource(source: ScrollSource): boolean {
  return source === ScrollSource.DRAG ||
    source === ScrollSource.FLING ||
    source === ScrollSource.OTHER_USER_INPUT ||
    source === ScrollSource.SCROLL_BAR ||
    source === ScrollSource.SCROLL_BAR_FLING
}

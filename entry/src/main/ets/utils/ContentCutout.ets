/** Physical coordinates in vp, relative to the main window. */
export interface CutoutRect {
  left: number
  top: number
  width: number
  height: number
}

export interface WindowCutoutLayout {
  window: CutoutRect
  left: CutoutRect
  right: CutoutRect
  topInset: number
  bottomInset: number
}

export interface ContentSidePadding {
  left: number
  right: number
}

function intersect(a: CutoutRect, b: CutoutRect): CutoutRect | undefined {
  const left = Math.max(a.left, b.left)
  const top = Math.max(a.top, b.top)
  const width = Math.min(a.left + a.width, b.left + b.width) - left
  const height = Math.min(a.top + a.height, b.top + b.height) - top
  return width > 0 && height > 0 ? { left, top, width, height } : undefined
}

/** Measure the unpadded viewport. Existing vertical clearance takes priority over side avoidance. */
export function contentSidePadding(layout: WindowCutoutLayout, base: number, viewport?: CutoutRect,
  consumesSystemBars: boolean = true, bottomBarClearance: number = 0): ContentSidePadding {
  const window = layout.window
  const bounds = viewport ?? window
  if (window.width <= window.height) return { left: base, right: base }

  // Lists reserve the inset's height across their width, even if the OS reports a narrow indicator.
  // Only pages with a floating bottom bar reserve additional space for that bar.
  const top = consumesSystemBars ? layout.topInset : 0
  const bottom = consumesSystemBars ? layout.bottomInset + bottomBarClearance : 0
  const visible = intersect(bounds, { left: window.left, top: window.top + top,
    width: window.width, height: window.height - top - bottom })
  if (visible === undefined) return { left: base, right: base }
  const left = intersect(layout.left, visible)
  const right = intersect(layout.right, visible)
  return {
    left: base + (left === undefined ? 0 : left.left + left.width - bounds.left),
    right: base + (right === undefined ? 0 : bounds.left + bounds.width - right.left),
  }
}

export function viewportFromArea(area: Area): CutoutRect | undefined {
  const left = Number(area.globalPosition.x)
  const top = Number(area.globalPosition.y)
  const width = Number(area.width)
  const height = Number(area.height)
  if (!Number.isFinite(left) || !Number.isFinite(top) || !Number.isFinite(width) || !Number.isFinite(height) ||
    width <= 0 || height <= 0) return undefined
  return { left, top, width, height }
}

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
  systemTop: CutoutRect
  systemBottom: CutoutRect
  navigationBottom: CutoutRect
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

function contains(outer: CutoutRect, inner: CutoutRect): boolean {
  return outer.left <= inner.left && outer.top <= inner.top &&
    outer.left + outer.width >= inner.left + inner.width &&
    outer.top + outer.height >= inner.top + inner.height
}

/** Measure before applying our padding so a padded result cannot cancel its own inset. */
export function contentSidePadding(layout: WindowCutoutLayout, base: number, viewport?: CutoutRect,
  consumesSystemBars: boolean = true): ContentSidePadding {
  const bounds = viewport ?? layout.window
  const visible = intersect(bounds, layout.window)
  if (visible === undefined || layout.window.width <= layout.window.height) return { left: base, right: base }
  const left = intersect(layout.left, visible)
  const right = intersect(layout.right, visible)
  const needsInset = (hole: CutoutRect | undefined): boolean => hole !== undefined &&
    (!consumesSystemBars || !(contains(layout.systemTop, hole) || contains(layout.systemBottom, hole) ||
      contains(layout.navigationBottom, hole)))
  return {
    left: needsInset(left) && left !== undefined ? Math.max(base, left.left + left.width - bounds.left) : base,
    right: needsInset(right) && right !== undefined ? Math.max(base, bounds.left + bounds.width - right.left) : base,
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

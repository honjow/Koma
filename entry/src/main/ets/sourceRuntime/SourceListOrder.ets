/** Stable display order only; registry/install order remains untouched. */
export function compareSourceNames(leftName: string, leftId: string, rightName: string, rightId: string): number {
  const byName = leftName.trim().toLowerCase().localeCompare(rightName.trim().toLowerCase(), 'zh-CN')
  if (byName !== 0) return byName
  return leftId < rightId ? -1 : (leftId > rightId ? 1 : 0)
}

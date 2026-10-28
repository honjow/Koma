// The UI runtime owns these callbacks; WASM receives only an opaque ID in its
// host context. A retired search cannot start another HTTP hop even if its
// worker was already waiting for a native runtime slot when the route changed.
let sequence: number = 0
const guards: Map<string, () => boolean> = new Map<string, () => boolean>()

export function newSourceRuntimeOperationGuardId(): string {
  sequence += 1
  return `search-${sequence}`
}

export function registerSourceRuntimeOperationGuard(id: string, current: () => boolean): () => void {
  guards.set(id, current)
  return (): void => {
    if (guards.get(id) === current) guards.delete(id)
  }
}

export function sourceRuntimeOperationIsCurrent(id: string | undefined): boolean {
  if (id === undefined) return true
  const current = guards.get(id)
  if (current === undefined) return false
  try { return current() } catch (_error) { return false }
}

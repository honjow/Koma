import { systemDateTime } from '@kit.BasicServicesKit'

// One in-memory round, with only fixed protocol labels; no remote paths or data.
export function syncMetricUptime(): number {
  try { return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP) } catch (_error) { return 0 }
}
export interface SyncRequestMetrics {
  method: string
  namespace: string
  attempts: number
  successful: number
  retries: number
  elapsedMs: number
  maxMs: number
}

export interface SyncRoundMetrics {
  wallMs: number
  requests: SyncRequestMetrics[]
}

function duration(value: number): number {
  return Number.isFinite(value) && value > 0 ? Math.round(value) : 0
}

/** Elapsed request times overlap under concurrency; wallMs is measured separately. */
export class DeviceSyncMetrics {
  private readonly startMs: number
  private readonly requests: SyncRequestMetrics[] = []

  constructor(startMs: number) { this.startMs = startMs }

  record(method: string, namespace: string, status: number, elapsedMs: number, retry: boolean): void {
    if (!['GET', 'PROPFIND', 'PUT', 'MKCOL', 'DELETE'].includes(method) ||
      !['v1', 'v2', 'v3', 'v4', 'v5', 'directory'].includes(namespace)) return
    let row = this.requests.find((entry: SyncRequestMetrics): boolean =>
      entry.method === method && entry.namespace === namespace)
    if (row === undefined) {
      row = { method, namespace, attempts: 0, successful: 0, retries: 0, elapsedMs: 0, maxMs: 0 }
      this.requests.push(row)
    }
    const ms = duration(elapsedMs)
    row.attempts++
    if (status >= 200 && status < 300) row.successful++
    if (retry) row.retries++
    row.elapsedMs += ms
    row.maxMs = Math.max(row.maxMs, ms)
  }

  snapshot(nowMs: number): SyncRoundMetrics {
    return { wallMs: duration(nowMs - this.startMs), requests: this.requests.map((row: SyncRequestMetrics): SyncRequestMetrics =>
      ({ method: row.method, namespace: row.namespace, attempts: row.attempts, successful: row.successful,
        retries: row.retries, elapsedMs: row.elapsedMs, maxMs: row.maxMs })) }
  }
}

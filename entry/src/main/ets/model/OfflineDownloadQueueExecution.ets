import { OfflineDownloadQueueEntry, OfflineDownloadQueueStore } from './OfflineDownloadQueueStore'
import { OfflineDownloadStatus } from './OfflineDownloadStore'

/** All batch callers select the next chapter from the same durable queue. */
export async function runOrderedDownloadQueueBatch(queue: OfflineDownloadQueueStore,
  targets: OfflineDownloadQueueEntry[], execute: (entry: OfflineDownloadQueueEntry) => Promise<void>,
  canRun: () => boolean): Promise<void> {
  const keys = new Set<string>(targets.map((entry: OfflineDownloadQueueEntry): string => JSON.stringify([entry.comicId, entry.chapterId])))
  const claimed: Set<string> = new Set()
  const worker = async (): Promise<void> => {
    while (canRun()) {
      // Claim synchronously before yielding. Active chapters retain their slots;
      // only the next selection changes when a user reorders the queue.
      const entry = queue.load().find((item: OfflineDownloadQueueEntry): boolean => {
        const key = JSON.stringify([item.comicId, item.chapterId])
        return keys.has(key) && !claimed.has(key) && item.status !== OfflineDownloadStatus.DOWNLOADED
      })
      if (entry === undefined) return
      claimed.add(JSON.stringify([entry.comicId, entry.chapterId]))
      await execute(entry)
    }
  }
  const workers: Promise<void>[] = []
  const limit = queue.loadPreferences().foregroundConcurrencyLimit
  for (let index = 0; index < limit && index < targets.length; index += 1) workers.push(worker())
  const results = await Promise.allSettled(workers)
  for (const result of results) if (result.status === 'rejected') throw result.reason as Error
}

import { OfflineChapterDownloadManifest } from './OfflineDownloadStore'
import { BackupRestoreActivity } from './BackupRestoreActivity'

interface OfflineDownloadExecution {
  filesDir: string
  comicId: string
  promise: Promise<OfflineChapterDownloadManifest>
  pauseRequested: boolean
}

interface OfflineDownloadAdmission {
  limit: () => number
  resolve: () => void
}

interface OfflineDownloadSlots {
  active: number
  waiting: OfflineDownloadAdmission[]
}

// Foreground runtime only. Worker reconciliation must finish before an execution starts.
export class OfflineDownloadRuntime {
  private static initializations: Map<string, Promise<void>> = new Map<string, Promise<void>>()
  private static initialized: Set<string> = new Set<string>()
  private static executions: Map<string, OfflineDownloadExecution> = new Map<string, OfflineDownloadExecution>()
  private static comicRemovals: Map<string, Promise<number>> = new Map<string, Promise<number>>()
  private static slots: Map<string, OfflineDownloadSlots> = new Map<string, OfflineDownloadSlots>()
  private static listeners: Map<string, Set<() => void>> = new Map<string, Set<() => void>>()

  static initialize(filesDir: string, initialize: () => Promise<void>): Promise<void> {
    const existing = OfflineDownloadRuntime.initializations.get(filesDir)
    if (existing !== undefined) {
      return existing
    }
    const pending = BackupRestoreActivity.runWrite(() => Promise.resolve().then(initialize)).then(() => {
      OfflineDownloadRuntime.initialized.add(filesDir)
    }).catch((error: Error) => {
      OfflineDownloadRuntime.initializations.delete(filesDir)
      throw error
    })
    OfflineDownloadRuntime.initializations.set(filesDir, pending)
    return pending
  }

  static key(filesDir: string, comicId: string, chapterId: string): string {
    return JSON.stringify([filesDir, comicId, chapterId])
  }

  static isInitialized(filesDir: string): boolean {
    return OfflineDownloadRuntime.initialized.has(filesDir)
  }

  static isActive(filesDir: string, comicId: string, chapterId: string): boolean {
    return OfflineDownloadRuntime.executions.has(OfflineDownloadRuntime.key(filesDir, comicId, chapterId))
  }

  static async run(
    filesDir: string,
    comicId: string,
    chapterId: string,
    start: () => Promise<OfflineChapterDownloadManifest>,
    concurrencyLimit?: () => number,
  ): Promise<OfflineChapterDownloadManifest> {
    const key = OfflineDownloadRuntime.key(filesDir, comicId, chapterId)
    if (OfflineDownloadRuntime.comicRemovals.has(JSON.stringify([filesDir, comicId]))) {
      throw new Error('download_remove_busy')
    }
    const existing = OfflineDownloadRuntime.executions.get(key)
    if (existing !== undefined) {
      return existing.promise
    }
    const execution: OfflineDownloadExecution = {
      filesDir,
      comicId,
      promise: BackupRestoreActivity.runWrite(async (): Promise<OfflineChapterDownloadManifest> => {
        if (concurrencyLimit !== undefined) {
          await OfflineDownloadRuntime.acquireSlot(filesDir, concurrencyLimit)
        } else {
          await Promise.resolve()
        }
        try {
          return await start()
        } finally {
          if (concurrencyLimit !== undefined) OfflineDownloadRuntime.releaseSlot(filesDir)
        }
      }),
      pauseRequested: false,
    }
    OfflineDownloadRuntime.executions.set(key, execution)
    try {
      return await execution.promise
    } finally {
      OfflineDownloadRuntime.executions.delete(key)
      OfflineDownloadRuntime.publish(filesDir)
    }
  }

  static removeComicDownloads(filesDir: string, comicId: string, remove: () => Promise<number>): Promise<number> {
    const key = JSON.stringify([filesDir, comicId])
    const existing = OfflineDownloadRuntime.comicRemovals.get(key)
    if (existing !== undefined) return existing
    const pending = BackupRestoreActivity.runWrite(async (): Promise<number> => {
      const executions: Promise<OfflineChapterDownloadManifest>[] = []
      OfflineDownloadRuntime.executions.forEach((execution: OfflineDownloadExecution) => {
        if (execution.filesDir === filesDir && execution.comicId === comicId) {
          execution.pauseRequested = true
          executions.push(execution.promise)
        }
      })
      await Promise.allSettled(executions)
      return await remove()
    }).finally(() => {
      OfflineDownloadRuntime.comicRemovals.delete(key)
    })
    OfflineDownloadRuntime.comicRemovals.set(key, pending)
    return pending
  }

  private static acquireSlot(filesDir: string, limit: () => number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      let slots = OfflineDownloadRuntime.slots.get(filesDir)
      if (slots === undefined) {
        slots = { active: 0, waiting: [] }
        OfflineDownloadRuntime.slots.set(filesDir, slots)
      }
      slots.waiting.push({ limit, resolve })
      OfflineDownloadRuntime.admitWaiting(filesDir)
    })
  }

  private static admitWaiting(filesDir: string): void {
    const slots = OfflineDownloadRuntime.slots.get(filesDir)
    if (slots === undefined) return
    while (slots.waiting.length > 0) {
      const next = slots.waiting[0]
      const limit = Math.max(1, Math.min(3, Math.floor(next.limit())))
      if (slots.active >= limit) break
      slots.waiting.shift()
      slots.active += 1
      next.resolve()
    }
  }

  private static releaseSlot(filesDir: string): void {
    const slots = OfflineDownloadRuntime.slots.get(filesDir)
    if (slots === undefined) return
    slots.active -= 1
    OfflineDownloadRuntime.admitWaiting(filesDir)
    if (slots.active === 0 && slots.waiting.length === 0) OfflineDownloadRuntime.slots.delete(filesDir)
  }

  static async runBatch(chapterIds: string[], limit: number,
    execute: (chapterId: string) => Promise<void>): Promise<void> {
    let nextIndex = 0
    const worker = async (): Promise<void> => {
      while (nextIndex < chapterIds.length) {
        const chapterId = chapterIds[nextIndex]
        nextIndex += 1
        await execute(chapterId)
      }
    }
    const workers: Promise<void>[] = []
    const count = Math.max(1, Math.min(3, Math.floor(limit)))
    for (let index = 0; index < count && index < chapterIds.length; index += 1) workers.push(worker())
    const results = await Promise.allSettled(workers)
    for (const result of results) {
      if (result.status === 'rejected') throw result.reason as Error
    }
  }

  static requestPause(filesDir: string): void {
    OfflineDownloadRuntime.executions.forEach((execution: OfflineDownloadExecution) => {
      if (execution.filesDir === filesDir) {
        execution.pauseRequested = true
      }
    })
  }

  static isPauseRequested(key: string): boolean {
    return OfflineDownloadRuntime.executions.get(key)?.pauseRequested ?? false
  }

  static async waitForPausedExecutions(filesDir: string): Promise<void> {
    const pending: Promise<OfflineChapterDownloadManifest>[] = []
    OfflineDownloadRuntime.executions.forEach((execution: OfflineDownloadExecution) => {
      if (execution.filesDir === filesDir && execution.pauseRequested) {
        pending.push(execution.promise)
      }
    })
    await Promise.allSettled(pending)
  }

  static subscribe(filesDir: string, listener: () => void): () => void {
    let listeners = OfflineDownloadRuntime.listeners.get(filesDir)
    if (listeners === undefined) {
      listeners = new Set<() => void>()
      OfflineDownloadRuntime.listeners.set(filesDir, listeners)
    }
    listeners.add(listener)
    return () => {
      OfflineDownloadRuntime.listeners.get(filesDir)?.delete(listener)
    }
  }

  static publish(filesDir: string): void {
    OfflineDownloadRuntime.admitWaiting(filesDir)
    OfflineDownloadRuntime.listeners.get(filesDir)?.forEach((listener: () => void) => listener())
  }
}

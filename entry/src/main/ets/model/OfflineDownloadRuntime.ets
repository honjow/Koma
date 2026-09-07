import { OfflineChapterDownloadManifest } from './OfflineDownloadStore'

interface OfflineDownloadExecution {
  filesDir: string
  promise: Promise<OfflineChapterDownloadManifest>
  pauseRequested: boolean
}

// Foreground runtime only. Worker reconciliation must finish before an execution starts.
export class OfflineDownloadRuntime {
  private static initializations: Map<string, Promise<void>> = new Map<string, Promise<void>>()
  private static initialized: Set<string> = new Set<string>()
  private static executions: Map<string, OfflineDownloadExecution> = new Map<string, OfflineDownloadExecution>()
  private static listeners: Map<string, Set<() => void>> = new Map<string, Set<() => void>>()

  static initialize(filesDir: string, initialize: () => Promise<void>): Promise<void> {
    const existing = OfflineDownloadRuntime.initializations.get(filesDir)
    if (existing !== undefined) {
      return existing
    }
    const pending = Promise.resolve().then(initialize).then(() => {
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
    key: string,
    start: () => Promise<OfflineChapterDownloadManifest>,
  ): Promise<OfflineChapterDownloadManifest> {
    const existing = OfflineDownloadRuntime.executions.get(key)
    if (existing !== undefined) {
      return existing.promise
    }
    const execution: OfflineDownloadExecution = {
      filesDir,
      promise: Promise.resolve().then(start),
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
    OfflineDownloadRuntime.listeners.get(filesDir)?.forEach((listener: () => void) => listener())
  }
}

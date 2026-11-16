// Admission for this app's destructive backup restore, not a task scheduler.
// Existing async mutation owners hold a count across their awaited work.
export class BackupRestoreActivity {
  private static writers: number = 0
  private static restoring: boolean = false
  private static blocked: boolean = false
  private static deviceSyncCommit?: Promise<void>
  private static waitForIdle?: Promise<void>
  private static resolveIdle?: () => void

  static isRestoring(): boolean {
    return BackupRestoreActivity.restoring || BackupRestoreActivity.blocked
  }

  static beginRestore(): void {
    if (BackupRestoreActivity.isBusy()) {
      throw new Error('backup_restore_busy')
    }
    BackupRestoreActivity.restoring = true
  }

  /** A Mihon link replaces two documents together. Existing writes can finish
   * before it takes ownership, including a previous book's progress save. */
  static async beginRestoreWhenIdle(isCurrent?: () => boolean): Promise<boolean> {
    while (isCurrent === undefined || isCurrent()) {
      if (BackupRestoreActivity.blocked) throw new Error('backup_recovery_pending')
      if (!BackupRestoreActivity.isBusy()) {
        BackupRestoreActivity.beginRestore()
        return true
      }
      if (BackupRestoreActivity.waitForIdle === undefined) {
        BackupRestoreActivity.waitForIdle = new Promise<void>((resolve: () => void): void => {
          BackupRestoreActivity.resolveIdle = resolve
        })
      }
      await BackupRestoreActivity.waitForIdle
    }
    return false
  }

  private static isBusy(): boolean {
    return BackupRestoreActivity.isRestoring() || BackupRestoreActivity.writers > 0 ||
      BackupRestoreActivity.deviceSyncCommit !== undefined
  }

  private static notifyIdle(): void {
    if (!BackupRestoreActivity.blocked && BackupRestoreActivity.isBusy()) return
    const resolve = BackupRestoreActivity.resolveIdle
    BackupRestoreActivity.waitForIdle = undefined
    BackupRestoreActivity.resolveIdle = undefined
    resolve?.()
  }

  static finishRestore(): void {
    if (!BackupRestoreActivity.blocked) BackupRestoreActivity.restoring = false
    BackupRestoreActivity.notifyIdle()
  }

  static blockUntilRestart(): void {
    BackupRestoreActivity.blocked = true
  }

  static deviceSyncIsCommitting(): boolean {
    return BackupRestoreActivity.deviceSyncCommit !== undefined
  }

  static hasPendingRecovery(): boolean {
    return BackupRestoreActivity.blocked
  }

  static async runDeviceSyncCommit<T>(write: () => Promise<T>): Promise<T> {
    if (BackupRestoreActivity.isRestoring() || BackupRestoreActivity.writers > 0 ||
      BackupRestoreActivity.deviceSyncCommit !== undefined) throw new Error('sync_local_busy')
    let finish: () => void = () => {}
    BackupRestoreActivity.deviceSyncCommit = new Promise<void>((resolve: () => void): void => { finish = resolve })
    try {
      return await write()
    } finally {
      BackupRestoreActivity.deviceSyncCommit = undefined
      finish()
      BackupRestoreActivity.notifyIdle()
    }
  }

  static async runWrite<T>(write: () => Promise<T>): Promise<T> {
    const syncCommit = BackupRestoreActivity.deviceSyncCommit
    if (syncCommit !== undefined) await syncCommit
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    BackupRestoreActivity.writers += 1
    try {
      return await write()
    } finally {
      BackupRestoreActivity.writers -= 1
      BackupRestoreActivity.notifyIdle()
    }
  }
}

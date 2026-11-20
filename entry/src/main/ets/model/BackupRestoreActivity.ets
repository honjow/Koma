// Admission for this app's destructive backup restore, not a task scheduler.
// Existing async mutation owners hold a count across their awaited work.
export class BackupRestoreActivity {
  private static writers: number = 0
  private static restoring: boolean = false
  private static blocked: boolean = false
  private static syncRollbackPending: boolean = false
  private static syncRollback?: Promise<void>
  private static deviceSyncCommit?: Promise<void>
  private static waitForIdle?: Promise<void>
  private static resolveIdle?: () => void

  static isRestoring(): boolean {
    return BackupRestoreActivity.restoring || BackupRestoreActivity.hasPendingRecovery()
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
      if (BackupRestoreActivity.hasPendingRecovery()) throw new Error('backup_recovery_pending')
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
    if (!BackupRestoreActivity.hasPendingRecovery() && BackupRestoreActivity.isBusy()) return
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
    return BackupRestoreActivity.blocked || BackupRestoreActivity.syncRollbackPending
  }

  static deferDeviceSyncRollback(): void {
    BackupRestoreActivity.syncRollbackPending = true
  }

  static async recoverDeviceSyncRollback(rollback: () => Promise<void>): Promise<void> {
    if (!BackupRestoreActivity.syncRollbackPending) return
    const committing = BackupRestoreActivity.deviceSyncCommit
    if (committing !== undefined) await committing
    if (!BackupRestoreActivity.syncRollbackPending) return
    if (BackupRestoreActivity.blocked || BackupRestoreActivity.restoring) throw new Error('sync_local_recovery_required')
    if (BackupRestoreActivity.syncRollback !== undefined) return BackupRestoreActivity.syncRollback
    // This flag keeps ordinary writers out until the uncommitted journal has
    // restored its files. It cannot clear an unrelated backup recovery block.
    const pending = Promise.resolve().then(rollback).then((): void => {
      BackupRestoreActivity.syncRollbackPending = false
    }).catch((): void => {
      throw new Error('sync_local_rollback_pending')
    }).finally((): void => {
      BackupRestoreActivity.syncRollback = undefined
      BackupRestoreActivity.notifyIdle()
    })
    BackupRestoreActivity.syncRollback = pending
    return pending
  }

  static async runDeviceSyncCommit<T>(write: () => Promise<T>): Promise<T> {
    if (BackupRestoreActivity.hasPendingRecovery()) throw new Error('sync_local_recovery_required')
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

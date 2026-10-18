// Admission for this app's destructive backup restore, not a task scheduler.
// Existing async mutation owners hold a count across their awaited work.
export class BackupRestoreActivity {
  private static writers: number = 0
  private static restoring: boolean = false
  private static blocked: boolean = false

  static isRestoring(): boolean {
    return BackupRestoreActivity.restoring || BackupRestoreActivity.blocked
  }

  static beginRestore(): void {
    if (BackupRestoreActivity.isRestoring() || BackupRestoreActivity.writers > 0) {
      throw new Error('backup_restore_busy')
    }
    BackupRestoreActivity.restoring = true
  }

  static finishRestore(): void {
    if (!BackupRestoreActivity.blocked) BackupRestoreActivity.restoring = false
  }

  static blockUntilRestart(): void {
    BackupRestoreActivity.blocked = true
  }

  static async runWrite<T>(write: () => Promise<T>): Promise<T> {
    if (BackupRestoreActivity.isRestoring()) throw new Error('backup_restore_busy')
    BackupRestoreActivity.writers += 1
    try {
      return await write()
    } finally {
      BackupRestoreActivity.writers -= 1
    }
  }
}

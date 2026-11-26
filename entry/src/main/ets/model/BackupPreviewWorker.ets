import { readLegacyBackupPreviewJson } from './LegacyBackupPreview'

@Concurrent
export async function readLegacyBackupPreviewTask(path: string): Promise<string> {
  // TaskPool rejects a pending Promise returned directly from an async @Concurrent worker.
  return await readLegacyBackupPreviewJson(path)
}

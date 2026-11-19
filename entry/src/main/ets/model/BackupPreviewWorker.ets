import { readLegacyBackupPreviewJson } from './LegacyBackupPreview'

@Concurrent
export async function readLegacyBackupPreviewTask(path: string): Promise<string> {
  return readLegacyBackupPreviewJson(path)
}

import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileShare, fileUri, picker } from '@kit.CoreFileKit'
import { buffer } from '@kit.ArkTS'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

export async function activateBackupDirectory(uri: string): Promise<void> {
  const policies: fileShare.PolicyInfo[] = [{ uri, operationMode:
    fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE }]
  // Only a fresh picker selection may persist a grant. A revoked background grant must stay revoked.
  if (!(await fileShare.checkPersistentPermission(policies))[0]) throw new Error('backup_directory_permission_revoked')
  await fileShare.activatePermission(policies)
}

export interface AutomaticBackupDirectorySelection { uri: string; ownedModes: number }

export async function selectAutomaticBackupDirectory(context: common.UIAbilityContext): Promise<AutomaticBackupDirectorySelection | undefined> {
  const result = await new picker.DocumentViewPicker(context).select({
    maxSelectNumber: 1, selectMode: picker.DocumentSelectMode.FOLDER,
  })
  if (result.length === 0) return undefined
  const uri = result[0]
  const read: fileShare.PolicyInfo = { uri, operationMode: fileShare.OperationMode.READ_MODE }
  const write: fileShare.PolicyInfo = { uri, operationMode: fileShare.OperationMode.WRITE_MODE }
  const previous = await fileShare.checkPersistentPermission([read, write])
  const ownedModes = (previous[0] ? 0 : fileShare.OperationMode.READ_MODE) | (previous[1] ? 0 : fileShare.OperationMode.WRITE_MODE)
  if (ownedModes !== 0) await fileShare.persistPermission([{ uri, operationMode: ownedModes }])
  try { await activateBackupDirectory(uri) }
  catch (error) {
    if (ownedModes !== 0) await releaseAutomaticBackupDirectory(uri, ownedModes, [])
    throw error as Error
  }
  return { uri, ownedModes }
}

export async function releaseAutomaticBackupDirectory(uri: string, ownedModes: number, retainedReadRoots: string[]): Promise<void> {
  const prefix = uri.replace(/\/+$/, '') + '/'
  const keepRead = retainedReadRoots.some((root: string): boolean => root === uri || root.startsWith(prefix))
  const release = keepRead ? ownedModes & ~fileShare.OperationMode.READ_MODE : ownedModes
  if (release !== 0) {
    const policies: fileShare.PolicyInfo[] = [{ uri, operationMode: release }]
    await fileShare.revokePermission(policies)
    if ((await fileShare.checkPersistentPermission(policies))[0]) throw new Error('backup_directory_permission_release_failed')
    DiagnosticLogger.info('backup', 'directory_grant_released', 'owned_modes=' + release)
  }
}

/** Only Koma's dedicated auto-backup files participate in retention; other selected-directory files are untouched. */
export async function writeAutomaticBackupToDirectory(
  uri: string, payload: string, retention: number, at: number = Date.now(),
): Promise<string> {
  await activateBackupDirectory(uri)
  const directory = `${new fileUri.FileUri(uri).path}/Koma-Backups`
  if (!await fs.access(directory)) await fs.mkdir(directory)
  const path = `${directory}/koma-auto-${at}-${Date.now()}.json`
  const temporary = `${path}.tmp`
  const file = await fs.open(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
  try {
    const size = buffer.byteLength(payload, 'utf-8')
    if (await fs.write(file.fd, payload, { encoding: 'utf-8' }) !== size) throw new Error('backup_file_write_incomplete')
    await fs.fsync(file.fd)
  } finally { await fs.close(file) }
  await fs.rename(temporary, path)
  const names = (await fs.listFile(directory)).filter((name: string): boolean =>
    /^koma-auto-\d+-\d+\.json$/.test(name)).sort().reverse()
  for (const name of names.slice(retention)) await fs.unlink(`${directory}/${name}`)
  return path
}

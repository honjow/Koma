import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileShare, fileUri, picker } from '@kit.CoreFileKit'
import { buffer } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

export async function activateBackupDirectory(uri: string): Promise<void> {
  const policies: fileShare.PolicyInfo[] = [{ uri, operationMode:
    fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE }]
  try {
    await fileShare.activatePermission(policies)
    return
  } catch (_error) {}
  // The DOWNLOAD-mode app directory is reached by its public path. Verify the actual write
  // capability instead of treating fileShare activation as the only possible access mode.
  if (!await probeBackupDirectory(uri)) {
    throw new Error('backup_directory_permission_revoked')
  }
}

async function probeBackupDirectory(uri: string): Promise<boolean> {
  const directory = `${new fileUri.FileUri(uri).path}/Koma-Backups`
  const probe = `${directory}/.koma-write-probe-${Date.now()}`
  try {
    if (!await fs.access(directory)) await fs.mkdir(directory)
    const file = await fs.open(probe, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
    try {
      await fs.write(file.fd, 'koma', { encoding: 'utf-8' })
      await fs.fsync(file.fd)
    } finally {
      await fs.close(file)
    }
    await fs.unlink(probe)
    return true
  } catch (_error) {
    try { if (await fs.access(probe)) await fs.unlink(probe) } catch (_cleanupError) {}
    return false
  }
}

export interface AutomaticBackupDirectorySelection { uri: string; ownedModes: number }

function policyList(uri: string, modes: number): fileShare.PolicyInfo[] {
  const policies: fileShare.PolicyInfo[] = []
  if ((modes & fileShare.OperationMode.READ_MODE) !== 0) {
    policies.push({ uri, operationMode: fileShare.OperationMode.READ_MODE })
  }
  if ((modes & fileShare.OperationMode.WRITE_MODE) !== 0) {
    policies.push({ uri, operationMode: fileShare.OperationMode.WRITE_MODE })
  }
  return policies
}

export async function selectAutomaticBackupDirectory(context: common.UIAbilityContext): Promise<AutomaticBackupDirectorySelection | undefined> {
  const result = await new picker.DocumentViewPicker(context).select({
    maxSelectNumber: 1, selectMode: picker.DocumentSelectMode.FOLDER,
  })
  if (result.length === 0) return undefined
  const uri = result[0]
  const read: fileShare.PolicyInfo = { uri, operationMode: fileShare.OperationMode.READ_MODE }
  const write: fileShare.PolicyInfo = { uri, operationMode: fileShare.OperationMode.WRITE_MODE }
  const previous = await fileShare.checkPersistentPermission([read, write])
  const newlyPersistedModes = (previous[0] ? 0 : fileShare.OperationMode.READ_MODE) |
    (previous[1] ? 0 : fileShare.OperationMode.WRITE_MODE)
  for (const policy of policyList(uri, newlyPersistedModes)) {
    await fileShare.persistPermission([policy])
  }
  // A fresh picker selection adopts the grant even when it was already persisted. Otherwise
  // switching away would forget the grant and the next selection would treat it as foreign.
  const effective = await fileShare.checkPersistentPermission([read, write])
  const ownedModes = (effective[0] ? fileShare.OperationMode.READ_MODE : 0) |
    (effective[1] ? fileShare.OperationMode.WRITE_MODE : 0)
  try { await activateBackupDirectory(uri) }
  catch (error) {
    if (newlyPersistedModes !== 0) await releaseAutomaticBackupDirectory(uri, newlyPersistedModes, [])
    throw error as Error
  }
  return { uri, ownedModes }
}

export async function releaseAutomaticBackupDirectory(uri: string, ownedModes: number, retainedReadRoots: string[]): Promise<void> {
  const prefix = uri.replace(/\/+$/, '') + '/'
  const keepRead = retainedReadRoots.some((root: string): boolean => root === uri || root.startsWith(prefix))
  const release = keepRead ? ownedModes & ~fileShare.OperationMode.READ_MODE : ownedModes
  if (release !== 0) {
    for (const policy of policyList(uri, release)) {
      const policies: fileShare.PolicyInfo[] = [policy]
      try {
        await fileShare.revokePermission(policies)
      } catch (error) {
        const businessError = error as BusinessError<fileShare.PolicyErrorResult[]>
        DiagnosticLogger.warn('backup', 'directory_release_error_detail',
          'code=' + businessError.code + ' data=' + JSON.stringify(businessError.data ?? []))
        // For a directory the system can report 13900001 per mode even though the directory-level
        // check still reports another mode. Treat this mode as absent and keep the directory switch usable.
        if (businessError.code !== 13900001) throw error as Error
        DiagnosticLogger.info('backup', 'directory_grant_already_released',
          'mode=' + policy.operationMode)
        continue
      }
      if ((await fileShare.checkPersistentPermission(policies))[0]) {
        throw new Error('backup_directory_permission_release_failed')
      }
      DiagnosticLogger.info('backup', 'directory_grant_released', 'mode=' + policy.operationMode)
    }
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
  try {
    const names = (await fs.listFile(directory)).filter((name: string): boolean =>
      /^koma-auto-\d+-\d+\.json$/.test(name)).sort().reverse()
    for (const name of names.slice(retention)) await fs.unlink(`${directory}/${name}`)
  } catch (error) {
    // The new backup is already durable. A retention cleanup failure must not turn it into a false failure.
    DiagnosticLogger.exception('backup', 'automatic_retention_failed', error as Error)
  }
  return path
}

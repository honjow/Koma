import { common } from '@kit.AbilityKit'
import { fileIo as fs, hash } from '@kit.CoreFileKit'
import { ensureKomaContentStorageBase, hasKomaPublicContentStorage } from './KomaContentStorage'

const activeDirectories = new Map<string, string>()
const pendingDirectories = new Map<string, Promise<string>>()
interface MigratedBackup { path: string; digest: string }

function backupName(name: string): boolean {
  return name.length > 0 && !name.includes('/') && !name.includes('\\') &&
    (name.endsWith('.json') || name.endsWith('.koma-backup'))
}

/** Copy and verify every legacy file before removing any original. On failure the
 * private directory remains complete and the next attempt can resume safely. */
export async function migrateLocalBackups(privateBase: string, publicBase: string): Promise<string> {
  const source = `${privateBase}/backups`
  const target = `${publicBase}/backups`
  if (privateBase === publicBase || !await fs.access(source)) return target
  if (!await fs.access(target)) {
    try { await fs.mkdir(target, true) } catch (error) {
      if (!await fs.access(target) || !(await fs.stat(target)).isDirectory()) throw error as Error
    }
  }
  const names = (await fs.listFile(source)).filter(backupName)
  const copied: MigratedBackup[] = []
  for (const name of names) {
    const original = `${source}/${name}`
    if (!(await fs.stat(original)).isFile()) continue
    const originalHash = await hash.hash(original, 'sha256')
    const extension = name.endsWith('.koma-backup') ? '.koma-backup' : '.json'
    const stem = name.substring(0, name.length - extension.length)
    let destination = `${target}/${name}`
    let suffix = 2
    while (await fs.access(destination)) {
      if (await hash.hash(destination, 'sha256') === originalHash) break
      destination = `${target}/${stem}-${suffix++}${extension}`
    }
    if (!await fs.access(destination)) {
      const temporary = `${destination}.migrating`
      await fs.copyFile(original, temporary)
      const handle = await fs.open(temporary, fs.OpenMode.READ_WRITE)
      try { await fs.fsync(handle.fd) } finally { await fs.close(handle) }
      if (await hash.hash(temporary, 'sha256') !== originalHash) throw new Error('backup_migration_copy_mismatch')
      await fs.rename(temporary, destination)
    }
    copied.push({ path: original, digest: originalHash })
  }
  for (const original of copied) {
    if (await hash.hash(original.path, 'sha256') !== original.digest) throw new Error('backup_migration_source_changed')
  }
  for (const original of copied) await fs.unlink(original.path)
  return target
}

/** Use the system-provided public app root. A failed migration never switches
 * the backup list to a partial destination. */
export function ensureLocalBackupDirectory(context: common.UIAbilityContext): Promise<string> {
  const key = context.filesDir
  const active = activeDirectories.get(key)
  if (active !== undefined) return Promise.resolve(active)
  const pending = pendingDirectories.get(key)
  if (pending !== undefined) return pending
  const operation = (async (): Promise<string> => {
    const base = await ensureKomaContentStorageBase(context)
    // Do not mistake a temporary loss of the migrated public root for an empty backup list.
    if (base === key && hasKomaPublicContentStorage(context)) throw new Error('backup_public_storage_unavailable')
    const directory = await migrateLocalBackups(key, base)
    activeDirectories.set(key, directory)
    return directory
  })()
  pendingDirectories.set(key, operation)
  void operation.finally((): void => { pendingDirectories.delete(key) }).catch((): void => {})
  return operation
}

export function resolvedLocalBackupDirectory(context: common.Context): string {
  return activeDirectories.get(context.filesDir) ?? `${context.filesDir}/backups`
}

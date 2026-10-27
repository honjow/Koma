import { fileIo as fs } from '@kit.CoreFileKit'
import { SourceSettingObservationSources, checkedSourceSettingObservationSources } from './SourceSettingObservations'

// Native-only transitive imports: loading this TaskPool module must never
// evaluate UI decorators, the registry, settings owners or DiagnosticLogger.
@Concurrent
export function readSourceSettingObservationFile(path: string): SourceSettingObservationSources {
  if (!fs.accessSync(path)) return {}
  if (fs.statSync(path).size > 4 * 1024 * 1024) throw new Error('source_setting_observations_invalid')
  const document = JSON.parse(fs.readTextSync(path, { encoding: 'utf-8' })) as Record<string, Object>
  if (document === null || document['schemaVersion'] !== 1) throw new Error('source_setting_observations_invalid')
  return checkedSourceSettingObservationSources(document['sources'])
}

@Concurrent
export function writeSourceSettingObservationFile(path: string, sources: SourceSettingObservationSources): void {
  const temp = `${path}.tmp`
  let file: fs.File | undefined = undefined
  try {
    const checked = checkedSourceSettingObservationSources(sources)
    const document = JSON.stringify({ schemaVersion: 1, sources: checked })
    if (document.length > 4 * 1024 * 1024) throw new Error('source_setting_observations_invalid')
    const parent = path.substring(0, path.lastIndexOf('/'))
    if (!fs.accessSync(parent)) fs.mkdirSync(parent, true)
    file = fs.openSync(temp, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, document, { encoding: 'utf-8' })
    if (fs.statSync(file.fd).size > 4 * 1024 * 1024) throw new Error('source_setting_observations_invalid')
    fs.fsyncSync(file.fd)
    fs.closeSync(file)
    file = undefined
    if (fs.readTextSync(temp, { encoding: 'utf-8' }) !== document) throw new Error('source_setting_observations_write_failed')
    fs.renameSync(temp, path)
  } finally {
    if (file !== undefined) fs.closeSync(file)
    if (fs.accessSync(temp)) fs.unlinkSync(temp)
  }
}

import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { writeAppTextFile } from './AppFileTextPersistence'

interface AutomationEpoch { generation: number; restoring: boolean }
const EPOCH_FILE: string = 'automation-state-epoch.v1.json'

export function automationEpoch(context: common.Context): AutomationEpoch {
  const path = `${context.filesDir}/${EPOCH_FILE}`
  return fs.accessSync(path) ? JSON.parse(fs.readTextSync(path)) as AutomationEpoch : { generation: 0, restoring: false }
}

export function currentAutomationEpoch(context: common.Context, generation: number): boolean {
  const epoch = automationEpoch(context)
  return !epoch.restoring && epoch.generation === generation
}

// Restore changes the data to which generated work belongs. An Extension awaiting a source
// response must not publish that response into the newly restored library, even after rollback.
export function beginAutomationRestore(context: common.Context): void {
  const value: AutomationEpoch = { generation: Math.max(Date.now(), automationEpoch(context).generation + 1), restoring: true }
  writeAppTextFile(`${context.filesDir}/${EPOCH_FILE}`, JSON.stringify(value))
}

export function finishAutomationRestore(context: common.Context): void {
  const value = automationEpoch(context)
  value.restoring = false
  writeAppTextFile(`${context.filesDir}/${EPOCH_FILE}`, JSON.stringify(value))
}

export function resetGeneratedAutomationWork(context: common.Context): void {
  for (const name of ['automatic-download-pending.v1.json', 'read-download-cleanup.v1.json',
    'background-update-cursor.v1.json', 'background-backup-result.v1.json', 'background-backup-snapshot.v1.json']) {
    const path = `${context.filesDir}/${name}`
    if (fs.accessSync(path)) fs.unlinkSync(path)
  }
  const journals = `${context.filesDir}/background-library-results`
  if (fs.accessSync(journals)) {
    for (const name of fs.listFileSync(journals).filter((name: string): boolean => /^\d+-\d+\.json$/.test(name))) {
      fs.unlinkSync(`${journals}/${name}`)
    }
  }
}

const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

async function main() {
  const source = fs.readFileSync(path.join(__dirname,
    '../entry/src/main/ets/state/DownloadCbzConversionQueue.ets'), 'utf8')
    .replace(/@ObservedV2\s*|@Trace\s*/g, '')
  const code = ts.transpileModule(source, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  }).outputText
  const seen = []
  let finishChapter
  const migrationFiles = new Map()
  let migrationScans = 0
  const ports = {
    '@kit.ArkUI': {},
    '@kit.CoreFileKit': { fileIo: {
      accessSync: file => migrationFiles.has(file),
      readTextSync: file => migrationFiles.get(file),
    } },
    '../diagnostics/DiagnosticLogger': { DiagnosticLogger: { exception() {} } },
    '../model/KomaContentStorage': {
      ensureKomaContentStorageBase: async context => context.filesDir,
      komaRuntimeStorageKey: context => context.filesDir,
    },
    '../model/AppFileTextPersistence': { writeAppTextFile: (file, value) => migrationFiles.set(file, value) },
    '../model/DownloadFormatPreferences': { loadDownloadSaveAsCbz: async () => false },
    '../model/OfflineDownloadStore': { OfflineDownloadStore: class {}, createOfflineDownloadStableHash: () => 'root' },
    '../model/OfflineDownloadCbz': {
      async listFlatCbzMigrationWork(_root, _runtimeKey, convertLoose) {
        migrationScans++
        assert.equal(convertLoose, false)
        return [{ comicId: 'legacy', title: 'Legacy work', chapterIds: ['packed'] }]
      },
      async convertDownloadedChaptersToCbz(_store, comicId, chapters, onChapterHandled, migration) {
        if (comicId === 'legacy') assert.equal(migration.convertLoose, false)
        const result = { converted: 0, failed: 0, insufficientSpace: 0 }
        for (const [index, chapterId] of chapters.entries()) {
          assert.equal(finishChapter, undefined, 'Only one chapter may be written at a time')
          seen.push([comicId, chapterId])
          const success = await new Promise(resolve => { finishChapter = resolve })
          if (success) result.converted++
          else {
            result.failed++
            if (comicId === 'legacy') result.insufficientSpace++
          }
          onChapterHandled(index + 1, result)
        }
        return result
      },
    },
  }
  const exports = {}
  new Function('require', 'exports', code)(name => ports[name], exports)
  const queue = new exports.DownloadCbzConversionQueue()
  const context = { filesDir: '/fixture' }
  const tick = () => new Promise(resolve => setImmediate(resolve))
  const finish = async success => {
    assert.equal(typeof finishChapter, 'function')
    const resolve = finishChapter
    finishChapter = undefined
    resolve(success)
    await tick()
  }

  assert.equal(queue.enqueue(context, 'a', 'First work', ['1', '2']), 2)
  await tick()
  assert.equal(queue.enqueue(context, 'a', 'First work', ['1', '3', '3']), 1)
  assert.equal(queue.enqueue(context, 'b', 'Second work', ['1']), 1)
  assert.equal(queue.enqueue(context, 'b', 'Second work', ['1']), 0)
  assert.deepEqual(seen, [['a', '1']])
  assert.equal(queue.status.waiting, 2)
  await finish(true)
  assert.equal(queue.status.processed, 1)
  await finish(false)
  assert.deepEqual(seen, [['a', '1'], ['a', '2'], ['a', '3']])
  await finish(true)
  assert.equal(queue.status.title, 'Second work')
  await finish(true)
  assert.deepEqual(seen.at(-1), ['b', '1'])
  assert.equal(queue.status.running, false)
  assert.equal(queue.status.converted, 3)
  assert.equal(queue.status.failed, 1)
  assert.equal(queue.isScheduled(context, 'a', '2'), false, 'Failed chapters can be queued again')
  queue.dismissResult()
  assert.equal(queue.status, undefined)
  console.log('CBZ conversion queue accepts additional work, deduplicates chapters, and reports progress and failures')

  const initialUpgrade = new exports.DownloadCbzConversionQueue()
  await initialUpgrade.startUpgradeMigration(context, () => true)
  await tick()
  assert.equal(initialUpgrade.status.migrating, true)
  await finish(false)
  assert.equal(initialUpgrade.status.failed, 1)
  assert.equal(initialUpgrade.status.insufficientSpace, 1)
  assert.equal(migrationFiles.size, 0, 'A failed upgrade must be retried after restart')
  const recoveredUpgrade = new exports.DownloadCbzConversionQueue()
  await recoveredUpgrade.startUpgradeMigration(context, () => true)
  await tick()
  await finish(true)
  assert.equal(recoveredUpgrade.status.converted, 1)
  assert.deepEqual([...migrationFiles.values()], ['packed'])
  const cleanLaunch = new exports.DownloadCbzConversionQueue()
  await cleanLaunch.startUpgradeMigration(context, () => true)
  assert.equal(migrationScans, 2)
  assert.equal(cleanLaunch.status, undefined)
  console.log('Upgrade migration retries failed chapters on restart and skips a completed root')
}

main().catch(error => { console.error(error); process.exitCode = 1 })

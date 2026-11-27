const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const { setImmediate: tick } = require('node:timers/promises')
const { test } = require('node:test')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')
const source = (name) => readFileSync(resolve(__dirname, '../entry/src/main/ets/model', name + '.ets'), 'utf8')

function compile(text, dependencies) {
  const { outputText } = ts.transpileModule(text, {
    compilerOptions: { target: ts.ScriptTarget.ES2020, module: ts.ModuleKind.CommonJS },
  })
  const module = { exports: {} }
  new Function('require', 'module', 'exports', outputText)((name) => {
    assert.ok(Object.hasOwn(dependencies, name), 'Unexpected dependency: ' + name)
    return dependencies[name]
  }, module, module.exports)
  return module.exports
}

const serviceFile = ts.createSourceFile('LibraryUpdateService.ts', source('LibraryUpdateService'),
  ts.ScriptTarget.Latest, true, ts.ScriptKind.TS)
const strings = { AppStrings: { get: key => key } }
const automationPolicy = compile(source('LibraryAutomationPolicy'), {
  './ReaderChapterSequence': compile(source('ReaderChapterSequence'), {
    './ChapterSortOrder': compile(source('ChapterSortOrder'), {}),
  }),
  './ComicReleaseSchedule': compile(source('ComicReleaseSchedule'), {}),
})

test('library updates overlap sources, preserve writeback, and drain failures', async () => {
  const models = compile(source('ComicModels'), {})
  const backup = compile(source('BackupRestoreActivity'), {})
  const serviceClass = serviceFile.statements.find(node => node.name?.text === 'LibraryUpdateService')
  const methods = serviceClass.members.filter(node => ['checkLibraryUpdates', 'skippedResult'].includes(node.name?.text))
  const helpers = serviceFile.statements.filter(node => [
    'summarizeResults', 'summarizeLibraryUpdateProviders', 'providerKindForComic',
    'sourceKeyForComic', 'safeLibraryUpdateSourceKey', 'safeLibraryUpdateFailureCode',
  ].includes(node.name?.text))
  const settings = serviceFile.statements.filter(node => ts.isVariableStatement(node))
  const { ParallelCheck } = compile(`
    const { AppStrings, BackupRestoreActivity, ComicSourceKind, sameComicIdentity,
      newlyAddedChapterIds } = require('fixture')
    ${helpers.map(node => node.getText(serviceFile)).join('\n')}
    ${settings.map(node => node.getText(serviceFile)).join('\n')}
    export class ParallelCheck { ${methods.map(node => node.getText(serviceFile)).join('\n')} }
  `, { fixture: { ...strings, ...models, ...backup, ...automationPolicy } })

  const comics = ['b1', 'c1', 'd1', 'e1', 'f1', 'a1', 'a2', 'a3', 'b2'].map(id => ({
    id, sourceRuntimeId: id[0], chapterCount: 1, chapters: [{ id: 'existing' }],
  }))
  const live = new Map(comics.map(comic => [comic.id, comic]))
  const pending = new Map()
  const started = []
  const persisted = []
  const rolledBack = []
  const update = new ParallelCheck()
  update.libraryStore = { listComicSummaries: () => comics, getComic: id => live.get(id) }
  update.persistenceService = {
    persistExistingWorks: (works) => { persisted.push(works) },
    restoreFailedWorkUpdates: (works) => { rolledBack.push(works) },
  }
  update.checkComic = (comic) => {
    started.push(comic.id)
    return new Promise((resolve, reject) => { pending.set(comic.id, { resolve, reject }) })
  }
  const finish = (id, status = 'unchanged') => {
    pending.get(id).resolve({ comicId: id, providerKind: 'source_runtime', sourceKey: id[0],
      status, previousChapterCount: 1, newChapterCount: live.get(id).chapters.length })
    pending.delete(id)
    return tick()
  }

  const batch = update.checkLibraryUpdates()
  assert.deepEqual(started, ['a1', 'b1', 'c1', 'd1', 'e1'])
  live.delete('a3')
  live.set('b2', { ...live.get('b2'), sourceRuntimeId: 'd' })
  await finish('b1', 'failed')
  assert.deepEqual(started, ['a1', 'b1', 'c1', 'd1', 'e1', 'f1'])
  live.set('d1', { ...live.get('d1'), chapters: [{ id: 'existing' }, { id: 'new' }] })
  await finish('d1', 'updated')
  live.set('d1', { ...live.get('d1'), customTitle: 'Edited while other sources are running' })
  assert.equal(persisted.length, 0)
  await finish('e1')
  await finish('f1')
  await finish('c1')
  await finish('a1')
  assert.equal(started.at(-1), 'a2')
  await finish('a2')
  const summary = await batch
  assert.deepEqual(summary.results.map(item => item.comicId), comics.map(comic => comic.id))
  assert.equal(summary.failedCount, 1)
  assert.equal(summary.skippedCount, 2)
  assert.deepEqual(persisted, [[live.get('d1')]])
  assert.deepEqual(summary.results.find(item => item.comicId === 'd1').addedChapterIds, ['new'])

  // An unexpected worker error holds the write barrier until active checks finish.
  const failedBatch = update.checkLibraryUpdates()
  const rejection = assert.rejects(failedBatch, /fixture unexpected failure/)
  pending.get('a1').reject(new Error('fixture unexpected failure'))
  await tick()
  assert.throws(() => backup.BackupRestoreActivity.beginRestore(), /backup_restore_busy/)
  live.set('c1', { ...live.get('c1'), chapters: [{ id: 'existing' }, { id: 'interrupted' }] })
  await finish('c1', 'updated')
  await finish('b1')
  await finish('d1')
  await finish('e1')
  await rejection
  assert.equal(persisted.length, 1)
  assert.deepEqual(rolledBack, [[comics.find(comic => comic.id === 'c1')]])
  backup.BackupRestoreActivity.beginRestore()
  backup.BackupRestoreActivity.finishRestore()
})

test('library checks reuse fresh chapter context and only skip a confirmed recent status', async () => {
  const owner = serviceFile.statements.find(node => node.name?.text === 'LibraryUpdateService')
  const methods = owner.members.filter(node => [
    'checkSourceRuntimeComic', 'fetchSourceRuntimeDetail', 'fetchSourceRuntimeChapters', 'skippedResult',
  ].includes(node.name?.text))
  const helpers = serviceFile.statements.filter(node => ts.isVariableStatement(node) || [
    'sourceMangaIdFromComic', 'sourceKeyForComic', 'safeLibraryUpdateSourceKey', 'providerKindForComic',
    'safeLibraryUpdateFailureCode',
  ].includes(node.name?.text))
  const events = []
  let date = 1_000
  let revision = '0'
  let detailFails = false
  const entry = { sourceId: 'fixture', enabled: true }
  const context = { owner: 'work' }
  const comic = { id: 'fixture:work', sourceRuntimeId: 'fixture', sourcePath: 'https://fixture.invalid/work',
    sourceMetadata: { status: 'ongoing' } }
  const { UpdateCheck } = compile(`
    const { AppStrings, Date, DiagnosticLogger, MangaStatus, appSourceSettingsStore, sourceRuntimeEntryEnabled,
      fetchSourceMangaDetail, resolveSourceChapterList } = require('fixture')
    ${helpers.map(node => node.getText(serviceFile)).join('\n')}
    export class UpdateCheck { ${methods.map(node => node.getText(serviceFile)).join('\n')} }
  `, { fixture: { ...strings, Date: { now: () => date }, DiagnosticLogger: { debug() {} },
    MangaStatus: { UNKNOWN: 'unknown' }, sourceRuntimeEntryEnabled: source => source.enabled,
    appSourceSettingsStore: { revisionForSource: () => revision, loadForSource: () => ({}) },
    fetchSourceMangaDetail: async () => {
      events.push('detail')
      if (detailFails) throw Error('network')
      return { detail: { status: 'ongoing' }, chapterContext: context }
    },
    resolveSourceChapterList: async (_source, _id, _url, isCurrent, chapterContext) => {
      assert.equal(isCurrent(), true)
      events.push(chapterContext === context ? 'chapters with context' : 'chapters without context')
      return { resolved: true, chapters: [] }
    },
  } })
  const update = new UpdateCheck()
  update.sourceRegistry = { lookup: () => ({ ok: true, entry }) }
  update.libraryStore = { getComic: () => undefined }
  const check = async (expected) => {
    assert.equal((await update.checkSourceRuntimeComic(comic, 1)).status, 'skipped')
    assert.deepEqual(events.splice(0), expected)
  }
  await check(['detail', 'chapters with context'])
  await check(['chapters without context'])
  update.refreshWorkInfo = true
  await check(['detail', 'chapters with context'])
  update.refreshWorkInfo = false
  date += 5 * 60 * 1000
  await check(['detail', 'chapters with context'])
  revision = '1'
  detailFails = true
  await check(['detail', 'chapters without context'])
  detailFails = false
  await check(['detail', 'chapters with context'])
})

const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const root = path.resolve(__dirname, '..')
const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/model/OfflineDownloadNotificationStore.ets'), 'utf8')
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText
const requests = []
const notificationManager = {
  SlotType: { CONTENT_INFORMATION: 3 },
  ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 1 },
  isNotificationEnabled: async () => true,
  publish: async (request) => { requests.push(request) },
}
const exported = {}
new Function('exports', 'require', compiled)(exported, name => {
  if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { warn() {}, info() {}, exception() {} } }
  if (name === '@kit.AbilityKit') return { common: {}, wantAgent: { OperationType: { START_ABILITY: 1 },
    WantAgentFlags: { UPDATE_PRESENT_FLAG: 1 }, getWantAgent: async () => ({}) } }
  if (name === '@kit.BasicServicesKit') return {}
  if (name === '@kit.NotificationKit') return { notificationManager }
  if (name === '../common/Constants') return { KOMA_BUNDLE_NAME: 'com.honjow.koma',
    KOMA_LAUNCH_ROUTE_DOWNLOADS: 'downloads', KOMA_LAUNCH_ROUTE_PARAM: 'koma.launchRoute' }
  if (name === '../i18n/AppStrings') return { AppStrings: { get: key => key,
    format: (key, ...values) => key + ':' + values.join(',') } }
  if (name === './OfflineDownloadStore') return { OfflineDownloadStatus: { DOWNLOADED: 'downloaded',
    FAILED: 'failed', PARTIAL: 'partial', BLOCKED: 'blocked' } }
  throw new Error('Unexpected dependency: ' + name)
})

test('chapter completion updates one silent notification instead of alerting for every chapter', async () => {
  const manifest = { comicId: 'comic', chapterId: 'chapter', status: 'downloaded', updatedAt: 1,
    downloadedPageCount: 5, pageCount: 5 }
  const labels = { comicTitle: 'Comic', chapterTitle: 'Chapter' }
  await exported.publishOfflineDownloadNotification(manifest, labels)
  await exported.publishOfflineDownloadNotification({ ...manifest, updatedAt: 2 }, { ...labels, chapterTitle: 'Chapter 2' })

  assert.equal(requests.length, 2)
  for (const request of requests) {
    assert.equal(request.id, 4101)
    assert.equal(request.label, 'koma.downloads')
    assert.equal(request.appMessageId, undefined)
    assert.equal(request.notificationSlotType, 3)
    assert.equal(request.isAlertOnce, true)
    assert.deepEqual(request.notificationFlags, {
      soundEnabled: 2, vibrationEnabled: 2, bannerEnabled: 2, lockScreenEnabled: 2,
    })
  }
})

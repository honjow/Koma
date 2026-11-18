const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const test = require('node:test')
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

const root = path.resolve(__dirname, '..')
function loadModel(name, requireDependency) {
  const source = fs.readFileSync(path.join(root, 'entry/src/main/ets/model', name + '.ets'), 'utf8')
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
  }).outputText
  const exported = {}
  new Function('exports', 'require', compiled)(exported, requireDependency)
  return exported
}

const requests = []
let settings = { enabled: true }
let systemEnabled = true
const notificationManager = {
  SlotType: { SERVICE_INFORMATION: 2 },
  ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 1 },
  isNotificationEnabled: async () => systemEnabled,
  publish: async (request) => { requests.push(request) },
  cancel: async (id, label) => { requests.push({ canceled: [id, label] }) },
  openNotificationSettings: async () => { systemEnabled = true },
}
const exported = loadModel('OfflineDownloadNotificationStore', name => {
  if (name === '../diagnostics/DiagnosticLogger') return { DiagnosticLogger: { warn() {}, info() {}, exception() {} } }
  if (name === '@kit.AbilityKit') return { common: {}, wantAgent: { OperationType: { START_ABILITY: 1 },
    WantAgentFlags: { UPDATE_PRESENT_FLAG: 1 }, getWantAgent: async () => ({}) } }
  if (name === '@kit.BasicServicesKit') return {}
  if (name === '@kit.NotificationKit') return { notificationManager }
  if (name === '../common/Constants') return { KOMA_BUNDLE_NAME: 'com.honjow.koma',
    KOMA_LAUNCH_ROUTE_DOWNLOADS: 'downloads', KOMA_LAUNCH_ROUTE_PARAM: 'koma.launchRoute' }
  if (name === '../i18n/AppStrings') return { AppStrings: { get: key => key,
    format: (key, ...values) => key + ':' + values.join(',') } }
  if (name === './DownloadNotificationPreferences') return { loadDownloadNotificationPreferences: async () => settings }
  if (name === './OfflineDownloadStore') return { OfflineDownloadStatus: { DOWNLOADED: 'downloaded',
    FAILED: 'failed', PARTIAL: 'partial', BLOCKED: 'blocked' } }
  throw new Error('Unexpected dependency: ' + name)
})

test('queue summary respects the app switch and lets the system handle sound and vibration', async () => {
  requests.length = 0
  const context = { filesDir: '/app' }
  assert.equal((await exported.publishOfflineDownloadSummary(context, 0, 0)).code, 'not_needed')
  settings = { enabled: false }
  assert.equal((await exported.publishOfflineDownloadSummary(context, 3, 0)).code, 'disabled')
  settings.enabled = true; systemEnabled = false
  assert.equal((await exported.publishOfflineDownloadSummary(context, 3, 0)).code, 'disabled')
  assert.equal(requests.length, 0)
  systemEnabled = true
  assert.equal((await exported.publishOfflineDownloadSummary(context, 3, 1)).code, 'delivered')
  assert.equal(requests.length, 1)
  const [request] = requests
  assert.equal(request.id, 4101)
  assert.equal(request.notificationSlotType, notificationManager.SlotType.SERVICE_INFORMATION)
  assert.deepEqual(request.notificationFlags, { bannerEnabled: 2, lockScreenEnabled: 2 })
  assert.equal(request.content.normal.text, 'download_notification_summary:3,1')
})

test('disabled summary can be removed and system permission recovery returns the new state', async () => {
  requests.length = 0
  await exported.cancelOfflineDownloadSummary()
  assert.deepEqual(requests, [{ canceled: [4101, 'koma.downloads'] }])
  systemEnabled = false
  assert.equal(await exported.openOfflineDownloadSystemSettings({}), 'enabled')
})

test('the background card reports ongoing progress and closes without a completion update', async () => {
  const events = []
  const deps = {
    '@kit.BackgroundTasksKit': { backgroundTaskManager: {
      startBackgroundRunning: async () => { events.push('start'); return { notificationId: 22 } },
      stopBackgroundRunning: async () => { events.push('stop') },
      on() {}, off() {},
    } },
    '@kit.NotificationKit': { notificationManager: {
      SlotType: { LIVE_VIEW: 7 }, ContentType: { NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW: 5 },
      publish: async request => { events.push([request.id, request.template.data.progressValue]) },
    } },
    './OfflineDownloadNotificationStore': { createOfflineDownloadWantAgent: async () => ({}) },
    '../i18n/AppStrings': { AppStrings: { get: key => key } },
  }
  const { BackgroundDownloadOwner } = loadModel('BackgroundDownloadOwner', name => deps[name] ?? {})
  await BackgroundDownloadOwner.run({}, async () => {
    BackgroundDownloadOwner.progress('chapter one', 1, 2)
    BackgroundDownloadOwner.progress('chapter one', 2, 2)
    BackgroundDownloadOwner.progress('chapter two', 1, 1)
  })
  assert.deepEqual(events, ['start', [22, 50], [22, 99], [22, 99], 'stop'])
})

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
let settings = { enabled: true, sound: 'silent' }
let systemEnabled = true
const notificationManager = {
  SlotType: { CONTENT_INFORMATION: 3 },
  ContentType: { NOTIFICATION_CONTENT_BASIC_TEXT: 1 },
  isNotificationEnabled: async () => systemEnabled,
  publish: async (request) => { requests.push(request) },
  cancel: async (id, label) => { requests.push({ canceled: [id, label] }) },
  openNotificationSettings: async () => { systemEnabled = true },
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
  if (name === './DownloadNotificationPreferences') return { loadDownloadNotificationPreferences: async () => settings }
  if (name === './OfflineDownloadStore') return { OfflineDownloadStatus: { DOWNLOADED: 'downloaded',
    FAILED: 'failed', PARTIAL: 'partial', BLOCKED: 'blocked' } }
  throw new Error('Unexpected dependency: ' + name)
})

test('queue summary respects the app switch, system permission and selected alerts', async () => {
  requests.length = 0
  const context = { filesDir: '/app' }
  assert.equal((await exported.publishOfflineDownloadSummary(context, 0, 0)).code, 'not_needed')
  settings = { enabled: false, sound: 'silent' }
  assert.equal((await exported.publishOfflineDownloadSummary(context, 3, 0)).code, 'disabled')
  settings.enabled = true; systemEnabled = false
  assert.equal((await exported.publishOfflineDownloadSummary(context, 3, 0)).code, 'disabled')
  assert.equal(requests.length, 0)
  systemEnabled = true
  for (const [sound, flags] of [
    ['silent', [2, 2]], ['sound', [0, 2]], ['vibrate', [2, 0]], ['sound_vibrate', [0, 0]],
  ]) {
    settings.sound = sound
    assert.equal((await exported.publishOfflineDownloadSummary(context, 3, 1)).code, 'delivered')
    const request = requests.at(-1)
    assert.equal(request.id, 4101)
    assert.deepEqual([request.notificationFlags.soundEnabled, request.notificationFlags.vibrationEnabled], flags)
    assert.equal(request.content.normal.text, 'download_notification_summary:3,1')
  }
})

test('disabled summary can be removed and system permission recovery returns the new state', async () => {
  requests.length = 0
  await exported.cancelOfflineDownloadSummary()
  assert.deepEqual(requests, [{ canceled: [4101, 'koma.downloads'] }])
  systemEnabled = false
  assert.equal(await exported.openOfflineDownloadSystemSettings({}), 'enabled')
})

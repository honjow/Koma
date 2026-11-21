const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const { transportFixture } = new Function('require', '__dirname',
  fs.readFileSync(path.join(__dirname, 'test_device_sync_journal.cjs'), 'utf8') +
  '\nreturn { transportFixture };')(
  name => name === 'node:test' ? () => {} : require(name), __dirname)

test('maintenance and foreground requests count separately and detach cleanly', async () => {
  const fixture = transportFixture('https://metrics-separation.invalid')
  const provider = fixture.provider([])
  const front = [], maintenance = []
  const foreground = () => {}, background = () => {}
  provider.setRoundMetrics({ record: (...args) => front.push(args) })
  provider.setGuardMetrics(background, { record: (...args) => maintenance.push(args) })
  await provider.readManifest(background)
  assert.ok(maintenance.length > 0)
  assert.equal(front.length, 0)
  await provider.readManifest(foreground)
  assert.ok(front.length > 0)
  const count = maintenance.length
  provider.setGuardMetrics(background, undefined)
  await provider.readManifest(background)
  assert.equal(maintenance.length, count)
})

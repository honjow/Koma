const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')

const { transportFixture, engineFixture, dataset, manifest, pageNumber, A, B } =
  new Function('require', '__dirname',
    fs.readFileSync(path.join(__dirname, 'test_device_sync_journal.cjs'), 'utf8') +
    '\nreturn { transportFixture, engineFixture, dataset, manifest, pageNumber, A, B };')(
    name => name === 'node:test' ? () => {} : require(name), __dirname)

async function connect(scenario, retire) {
  const transport = transportFixture('https://' + scenario + '.invalid')
  class Provider extends transport.SharedWebDav {
    async retireMigratedLegacy(guard) {
      await retire()
      await super.retireMigratedLegacy(guard)
    }
  }
  const old = dataset('reader-settings-records', pageNumber, B, 'false')
  for (const object of old.objects) transport.seedObject(object)
  transport.seedCommit(manifest(new Provider(transport.draft).spaceId(), [old.ref]))
  const { engine } = engineFixture(Provider).replica(A)
  engine.setSelection(['reader-settings'])
  await engine.saveConfiguration(transport.draft)
  engine.setEnabled(true)
  return { engine, transport }
}

async function until(predicate) {
  const end = Date.now() + 3000
  while (!predicate() && Date.now() < end) await new Promise(resolve => setTimeout(resolve, 10))
  assert.ok(predicate(), 'expected legacy cleanup checkpoint')
}

test('an unchanged probe retries legacy cleanup after a temporary failure', async () => {
  let attempts = 0
  const { engine, transport } = await connect('archive-wake', async () => {
    if (++attempts === 1) throw new Error('temporary cleanup failure')
  })
  try {
    await engine.syncNow()
    await until(() => attempts === 1 && !engine.retiringLegacy)
    assert.ok(transport.directories.has(transport.root))
    await engine.syncNow(true)
    await until(() => !transport.directories.has(transport.root) && !engine.retiringLegacy)
    assert.equal(attempts, 2)
  } finally {
    engine.setEnabled(false)
  }
})

test('disabling sync stops pending legacy cleanup before a delete', async () => {
  let began = false
  let resume
  const gate = new Promise(resolve => { resume = resolve })
  const { engine, transport } = await connect('archive-stop', async () => {
    began = true
    await gate
  })
  try {
    await engine.syncNow()
    await until(() => began)
    engine.setEnabled(false)
    resume()
    await until(() => !engine.retiringLegacy)
    assert.ok(transport.directories.has(transport.root))
    assert.equal(transport.trace.some(row => row.method === 'DELETE' && row.address === transport.root), false)
  } finally {
    resume()
    engine.setEnabled(false)
  }
})

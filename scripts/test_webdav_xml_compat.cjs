const test = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const ts = require(process.env.KOMA_TYPESCRIPT_PATH ??
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript')

function compile(name, modules = {}) {
  const source = fs.readFileSync(path.resolve(__dirname, '../entry/src/main/ets/remote', name + '.ets'), 'utf8')
  const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2020,
    module: ts.ModuleKind.CommonJS } }).outputText
  const exports = {}
  new Function('require', 'exports', js)(module => modules[module], exports)
  return exports
}

const models = compile('WebDavModels')
const { WebDavClient } = compile('WebDavClient', { './WebDavModels': models })

test('WebDAV 浏览解析带点的命名空间和结束标签前的空白', async () => {
  const xml = `<?xml version="1.0" encoding="utf-8"?>
    <dav.v1:multistatus xmlns:dav.v1="DAV:">
      <dav.v1:response><dav.v1:href>/dav/漫画/</dav.v1:href >
        <dav.v1:propstat><dav.v1:prop><dav.v1:displayname>漫画</dav.v1:displayname >
          <dav.v1:resourcetype><dav.v1:collection /></dav.v1:resourcetype >
        </dav.v1:prop ><dav.v1:status>HTTP/1.1 200 OK</dav.v1:status ></dav.v1:propstat >
      </dav.v1:response >
      <dav.v1:response><dav.v1:href>/dav/漫画/01.cbz</dav.v1:href >
        <dav.v1:propstat><dav.v1:prop><dav.v1:displayname>第一话</dav.v1:displayname >
          <dav.v1:resourcetype/><dav.v1:getcontentlength>42</dav.v1:getcontentlength >
        </dav.v1:prop ><dav.v1:status>HTTP/1.1 200 OK</dav.v1:status ></dav.v1:propstat >
      </dav.v1:response >
    </dav.v1:multistatus>`
  const client = new WebDavClient({ server: { baseUrl: 'https://example.test/dav', authKind: models.WebDavAuthKind.NONE },
    http: { request: async () => ({ status: 207, body: xml }) } })
  const resources = await client.propfind()
  assert.equal(resources.length, 2)
  assert.equal(resources[0].href, 'https://example.test/dav/漫画/')
  assert.equal(resources[0].displayname, '漫画')
  assert.equal(resources[0].isCollection, true)
  assert.equal(resources[1].displayname, '第一话')
  assert.equal(resources[1].contentLength, 42)
  assert.equal(resources[1].candidateKind, models.DavComicCandidateKind.ARCHIVE)
})

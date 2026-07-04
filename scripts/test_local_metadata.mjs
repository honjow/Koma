import assert from 'node:assert/strict'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'

const root = resolve(import.meta.dirname, '..')
const servicePath = resolve(root, 'entry/src/main/ets/model/LocalLibraryMetadataService.ets')
const folderContractPath = resolve(root, 'entry/src/main/ets/model/LocalLibraryFolderContract.ets')
const comicModelsPath = resolve(root, 'entry/src/main/ets/model/ComicModels.ets')
const libraryPersistencePath = resolve(root, 'entry/src/main/ets/model/LibraryPersistence.ets')
const mangaDetailPagePath = resolve(root, 'entry/src/main/ets/pages/MangaDetailPage.ets')
const backupServicePath = resolve(root, 'entry/src/main/ets/model/BackupService.ets')
const validatorPath = resolve(root, 'scripts/validate-napi-source-runtime-sample.sh')
const artifactPath = resolve(root, '.hermes-artifacts/20260527-d44-local-metadata/fixture-local-metadata.json')

const serviceSource = readFileSync(servicePath, 'utf8')
const folderContractSource = readFileSync(folderContractPath, 'utf8')
const comicModelsSource = readFileSync(comicModelsPath, 'utf8')
const libraryPersistenceSource = readFileSync(libraryPersistencePath, 'utf8')
const mangaDetailPageSource = readFileSync(mangaDetailPagePath, 'utf8')
const backupServiceSource = readFileSync(backupServicePath, 'utf8')
const validatorSource = readFileSync(validatorPath, 'utf8')

function assertExport(source, symbol) {
  assert.match(source, new RegExp(`export (interface|class|function|type|const) ${symbol}\\b`), `${symbol} must be exported`)
}

assertExport(serviceSource, 'LOCAL_LIBRARY_METADATA_CONTRACT_VERSION')
assertExport(serviceSource, 'LOCAL_LIBRARY_METADATA_IO_CONTRACT')
assertExport(serviceSource, 'LOCAL_LIBRARY_METADATA_DESTRUCTIVE_ACTION_CONTRACT')
assertExport(serviceSource, 'LOCAL_LIBRARY_METADATA_FALLBACK_ORDER')
assertExport(serviceSource, 'LocalLibraryMetadataStatus')
assertExport(serviceSource, 'LocalLibraryStoredMetadata')
assertExport(serviceSource, 'LocalLibrarySidecarMetadata')
assertExport(serviceSource, 'LocalLibrarySidecarParseResult')
assertExport(serviceSource, 'validateLocalLibraryCoverOverridePath')
assertExport(serviceSource, 'parseLocalLibrarySidecarMetadata')
assertExport(serviceSource, 'resolveLocalLibraryMetadata')
assertExport(serviceSource, 'createDerivedLocalLibraryMetadata')
assertExport(serviceSource, 'exportLocalLibraryMetadataBackupEntries')
assertExport(serviceSource, 'restoreLocalLibraryMetadataBackupEntries')
assertExport(serviceSource, 'LocalLibraryMetadataService')

assert.match(serviceSource, /LOCAL_LIBRARY_METADATA_IO_CONTRACT = 'MODEL_ONLY_NO_SIDECAR_RUNTIME_IO'/, 'metadata service must not claim runtime sidecar IO')
assert.match(serviceSource, /LOCAL_LIBRARY_METADATA_DESTRUCTIVE_ACTION_CONTRACT = 'NO_DELETE_LIBRARY_ROWS_OR_USER_FILES'/, 'metadata service must document no destructive actions')
assert.match(serviceSource, /'user_override'[\s\S]*'valid_sidecar'[\s\S]*'derived_folder_series'[\s\S]*'existing_library_import'/, 'fallback order must be explicit and stable')
assert.match(serviceSource, /type LocalLibraryMetadataStatus = 'ongoing' \| 'completed' \| 'hiatus' \| 'cancelled'/, 'metadata status must be a closed manga status union')
assert.match(serviceSource, /normalizeLocalLibraryMetadataRelativePath\(path\)/, 'cover override must use the same safe relative path rules without importing the folder scanner')
assert.match(serviceSource, /hasHiddenPathSegment\(normalized\)/, 'cover override must reject hidden path segments')
assert.match(serviceSource, /!isSupportedImagePath\(normalized\)/, 'cover override must reject unsupported cover extensions')
assert.doesNotMatch(serviceSource, /fileIo|fs\.|picker\.|unlink|rmdir|removeComputed|TRUNC|deleteComic|removeComic/, 'metadata service must not perform sidecar IO or destructive cleanup')
assert.doesNotMatch(serviceSource, /from '\.\/LocalLibraryFolderContract'/, 'metadata service must not import the folder contract and create a circular scanner dependency')
assert.match(folderContractSource, /textContent\?: string/, 'local folder entries must allow model-provided sidecar text without claiming runtime file IO')
assert.match(folderContractSource, /sidecarMetadata\?: LocalLibrarySidecarMetadata/, 'local folder scan results must carry valid parsed sidecar metadata per series')
assert.match(folderContractSource, /isLocalLibrarySidecarMetadataPath[\s\S]*metadata\.json[\s\S]*series\.json[\s\S]*comicinfo\.json[\s\S]*koma-metadata\.json/, 'local folder scanner must recognize simple sidecar metadata file names')
assert.match(folderContractSource, /parseLocalLibrarySidecarMetadata\(entry\.textContent\)[\s\S]*sidecarMetadataBySeriesPath\.set\(seriesPath, parsed\.metadata\)/, 'local folder scanner must parse sidecar payloads through the shared metadata parser')
assert.match(folderContractSource, /metadataSeries: LocalLibraryMetadataSeriesInput[\s\S]*resolveLocalLibraryMetadata\(\{[\s\S]*sidecar: series\.sidecarMetadata[\s\S]*derived: createDerivedLocalLibraryMetadata\(metadataSeries\)/, 'local folder comic conversion must resolve title/author/cover through the shared metadata fallback order')
assert.match(folderContractSource, /comic\.localMetadata = \{\}[\s\S]*titleOverride = series\.sidecarMetadata\.title[\s\S]*authors = series\.sidecarMetadata\.authors[\s\S]*status = series\.sidecarMetadata\.status[\s\S]*coverOverridePath = series\.sidecarMetadata\.coverPath/, 'sidecar metadata must persist as normalized local metadata for backup and restore')
assert.match(comicModelsSource, /localMetadata\?: LocalLibraryStoredMetadata/, 'Comic must carry local metadata for store persistence')
assert.match(libraryPersistenceSource, /localMetadata\?: LocalLibraryStoredMetadata/, 'library persistence row must carry local metadata')
assert.match(libraryPersistenceSource, /row\.localMetadata = normalizeLocalLibraryStoredMetadata/, 'persisted local metadata must be normalized before export')
assert.match(libraryPersistenceSource, /comic\.localMetadata = normalizeLocalLibraryStoredMetadata/, 'hydrated local metadata must survive restore')
assert.match(libraryPersistenceSource, /export function updateLocalLibraryMetadataAndPersistLibraryStore[\s\S]*previous\.sourceKind !== ComicSourceKind\.LOCAL_ARCHIVE[\s\S]*previous\.sourceKind !== ComicSourceKind\.LOCAL_FOLDER[\s\S]*normalizeLocalLibraryStoredMetadata\(metadataInput as Object\)[\s\S]*libraryStore\.upsertComic\(next\)[\s\S]*hydrateLibraryStoreFromJson\(libraryStore, previousPayload\)/, 'local metadata override updates must validate, stay local-only, persist once, and rollback on save failure')
assert.match(libraryPersistenceSource, /function localFolderCoverUri\(comic: Comic, coverOverridePath: string[\s\S]*ComicSourceKind\.LOCAL_FOLDER[\s\S]*localFolderSeriesRelativePath\(comic\)[\s\S]*localFolderRootUri\(comic\)[\s\S]*localLibraryFolderUri\(rootUri,/, 'local folder cover override helper must resolve to a safe local folder URI instead of raw absolute paths')
assert.match(libraryPersistenceSource, /const coverUri = localFolderCoverUri\(previous, normalized\.coverOverridePath\)/, 'local metadata persistence must apply cover overrides through the safe local folder URI helper')
assert.match(mangaDetailPageSource, /canEditLocalMetadata\(\): boolean[\s\S]*ComicSourceKind\.LOCAL_ARCHIVE[\s\S]*ComicSourceKind\.LOCAL_FOLDER/, 'MangaDetail local metadata editor must only open for local manga')
assert.match(mangaDetailPageSource, /manga_detail_menu_edit_local_metadata[\s\S]*openLocalMetadataEditor\(\)[\s\S]*LocalMetadataEditor\(\)/, 'MangaDetail must expose a real local metadata editor entry and inline editor')
assert.match(mangaDetailPageSource, /KomaFormTextField\(\{[\s\S]*manga_detail_local_metadata_field_title[\s\S]*manga_detail_local_metadata_field_authors[\s\S]*manga_detail_local_metadata_field_cover/, 'local metadata editor must provide editable title, author, and local-folder cover fields')
assert.match(mangaDetailPageSource, /LocalMetadataStatusMenu\(\)[\s\S]*localMetadataStatus = 'unknown'[\s\S]*localMetadataStatus = 'ongoing'[\s\S]*localMetadataStatus = 'completed'[\s\S]*localMetadataStatus = 'hiatus'[\s\S]*localMetadataStatus = 'cancelled'/, 'local metadata editor must use a status menu rather than free-form status text')
assert.match(mangaDetailPageSource, /saveLocalMetadataOverride\(\): void[\s\S]*updateLocalLibraryMetadataAndPersistLibraryStore[\s\S]*this\.manga = mangaDetailFromComic\(updated\)[\s\S]*this\.onLibraryChanged\(\)/, 'local metadata save must persist through the shared helper and refresh the visible detail state')
assert.match(backupServiceSource, /localLibraryMetadata\?: LocalLibraryMetadataBackupEntry\[\]/, 'backup document must expose local metadata entries')
assert.match(backupServiceSource, /exportLocalLibraryMetadataBackupEntries\(document\.libraryStore\)/, 'backup export must include explicit local metadata entries')
assert.match(backupServiceSource, /restoreLocalLibraryMetadataBackupEntries\(document\.libraryStore, document\.localLibraryMetadata\)/, 'backup import must merge explicit local metadata entries')
assert.match(validatorSource, /LocalLibrary\(FolderContract\|RescanService\|MetadataService\)/, 'NAPI validator whitelist must include the new metadata model narrowly')

const imageExts = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif'])
const fallbackOrder = ['user_override', 'valid_sidecar', 'derived_folder_series', 'existing_library_import']

function extension(path) {
  const base = path.replace(/\\/g, '/').split('/').filter(Boolean).at(-1) ?? ''
  const dot = base.lastIndexOf('.')
  return dot <= 0 || dot === base.length - 1 ? '' : base.substring(dot).toLowerCase()
}

function normalizeRelativePath(path) {
  const normalized = path.replace(/\\/g, '/').trim()
  if (
    normalized.length === 0 ||
    normalized.startsWith('/') ||
    normalized.includes('://') ||
    /^[A-Za-z]:/.test(normalized) ||
    [...normalized].some((char) => char.charCodeAt(0) < 32 || char.charCodeAt(0) === 127)
  ) {
    throw new Error(`Unsafe local library path: ${path}`)
  }
  const parts = normalized.split('/')
  const safeParts = []
  for (const part of parts) {
    const trimmed = part.trim()
    if (trimmed.length === 0 || trimmed === '.' || trimmed === '..' || trimmed.includes(':')) {
      throw new Error(`Unsafe local library path segment: ${path}`)
    }
    safeParts.push(trimmed)
  }
  return safeParts.join('/')
}

function validateCover(path) {
  const normalized = normalizeRelativePath(path)
  if (normalized.split('/').some((segment) => segment.startsWith('.'))) {
    throw new Error(`Unsafe local metadata cover path: ${path}`)
  }
  if (!imageExts.has(extension(normalized))) {
    throw new Error(`Unsupported local metadata cover image: ${path}`)
  }
  return normalized
}

function normalizeText(value) {
  if (value === undefined) return undefined
  const normalized = value.trim().replace(/\s+/g, ' ')
  return normalized.length === 0 ? undefined : normalized
}

function parseSidecar(payload) {
  let source
  if (typeof payload === 'string') {
    try {
      source = JSON.parse(payload)
    } catch {
      return { status: 'failure', failures: [{ field: 'document', reason: 'malformed_json' }] }
    }
  } else {
    source = payload
  }
  if (!source || Array.isArray(source) || typeof source !== 'object') {
    return { status: 'failure', failures: [{ field: 'document', reason: 'expected_object' }] }
  }
  const failures = []
  const metadata = {}
  const titleValue = source.title ?? source.titleOverride
  if (titleValue !== undefined) {
    if (typeof titleValue !== 'string') failures.push({ field: 'title', reason: 'invalid_title' })
    else {
      const title = normalizeText(titleValue)
      if (title === undefined) failures.push({ field: 'title', reason: 'blank_title' })
      else metadata.title = title
    }
  }
  const authorsValue = source.authors ?? source.author
  if (authorsValue !== undefined) {
    if (typeof authorsValue === 'string') {
      const author = normalizeText(authorsValue)
      if (author === undefined) failures.push({ field: 'authors', reason: 'blank_author' })
      else metadata.authors = [author]
    } else if (Array.isArray(authorsValue)) {
      const authors = []
      authorsValue.forEach((item, index) => {
        if (typeof item !== 'string') failures.push({ field: `authors.${index}`, reason: 'invalid_author' })
        else {
          const author = normalizeText(item)
          if (author === undefined) failures.push({ field: `authors.${index}`, reason: 'blank_author' })
          else if (!authors.includes(author)) authors.push(author)
        }
      })
      if (authors.length > 0) metadata.authors = authors
    } else {
      failures.push({ field: 'authors', reason: 'invalid_authors' })
    }
  }
  if (source.status !== undefined) {
    if (!['ongoing', 'completed', 'hiatus', 'cancelled'].includes(source.status)) failures.push({ field: 'status', reason: 'invalid_status' })
    else metadata.status = source.status
  }
  const coverValue = source.coverPath ?? source.cover ?? source.coverOverridePath
  if (coverValue !== undefined) {
    if (typeof coverValue !== 'string') failures.push({ field: 'coverPath', reason: 'invalid_cover_path' })
    else {
      try {
        metadata.coverPath = validateCover(coverValue)
      } catch {
        failures.push({ field: 'coverPath', reason: 'unsafe_cover_path' })
      }
    }
  }
  return failures.length > 0 ? { status: 'failure', failures } : { status: 'ok', metadata, failures: [] }
}

function resolveMetadata(input) {
  const title = normalizeText(input.userOverride?.titleOverride) !== undefined
    ? [normalizeText(input.userOverride.titleOverride), 'user_override']
    : normalizeText(input.sidecar?.title) !== undefined
      ? [normalizeText(input.sidecar.title), 'valid_sidecar']
      : normalizeText(input.derived.title) !== undefined
        ? [normalizeText(input.derived.title), 'derived_folder_series']
        : normalizeText(input.existing?.title) !== undefined
          ? [normalizeText(input.existing.title), 'existing_library_import']
          : ['Untitled', 'none']
  const authors = input.userOverride?.authors?.length > 0
    ? [input.userOverride.authors, 'user_override']
    : input.sidecar?.authors?.length > 0
      ? [input.sidecar.authors, 'valid_sidecar']
      : input.derived.authors?.length > 0
        ? [input.derived.authors, 'derived_folder_series']
        : normalizeText(input.existing?.author) !== undefined
          ? [[normalizeText(input.existing.author)], 'existing_library_import']
          : [[], 'none']
  const status = input.userOverride?.status !== undefined
    ? [input.userOverride.status, 'user_override']
    : input.sidecar?.status !== undefined
      ? [input.sidecar.status, 'valid_sidecar']
      : input.derived.status !== undefined
        ? [input.derived.status, 'derived_folder_series']
        : [undefined, 'none']
  const cover = input.userOverride?.coverOverridePath !== undefined
    ? [input.userOverride.coverOverridePath, 'user_override']
    : input.sidecar?.coverPath !== undefined
      ? [input.sidecar.coverPath, 'valid_sidecar']
      : input.derived.coverPath !== undefined
        ? [input.derived.coverPath, 'derived_folder_series']
        : normalizeText(input.existing?.coverUri) !== undefined
          ? [normalizeText(input.existing.coverUri), 'existing_library_import']
          : [undefined, 'none']
  return {
    title: title[0],
    titleSource: title[1],
    authors: authors[0],
    authorsSource: authors[1],
    status: status[0],
    statusSource: status[1],
    coverReference: cover[0],
    coverReferenceSource: cover[1],
  }
}

function exportMetadataBackupEntries(libraryStorePayload) {
  const document = JSON.parse(libraryStorePayload)
  return (document.comics ?? [])
    .filter((comic) => comic.localMetadata !== undefined)
    .map((comic) => ({ comicId: comic.id, metadata: comic.localMetadata }))
}

function restoreMetadataBackupEntries(libraryStorePayload, entries) {
  if (entries === undefined) return libraryStorePayload
  const document = JSON.parse(libraryStorePayload)
  const byId = new Map(entries.map((entry) => [entry.comicId, entry.metadata]))
  for (const comic of document.comics ?? []) {
    if (byId.has(comic.id)) {
      comic.localMetadata = byId.get(comic.id)
    }
  }
  return JSON.stringify(document)
}

assert.deepEqual(fallbackOrder, ['user_override', 'valid_sidecar', 'derived_folder_series', 'existing_library_import'])

const sidecar = parseSidecar(JSON.stringify({
  title: ' Sidecar Title ',
  authors: ['Author A', 'Author A', 'Author B'],
  status: 'completed',
  coverPath: 'covers/main.webp',
}))
assert.equal(sidecar.status, 'ok')
assert.deepEqual(sidecar.metadata, {
  title: 'Sidecar Title',
  authors: ['Author A', 'Author B'],
  status: 'completed',
  coverPath: 'covers/main.webp',
})

const overridden = resolveMetadata({
  userOverride: { titleOverride: 'User Title', authors: ['User Author'], status: 'hiatus', coverOverridePath: 'covers/user.jpg' },
  sidecar: sidecar.metadata,
  derived: { title: 'Folder Title', authors: ['Derived Author'], status: 'ongoing', coverPath: 'derived.png' },
  existing: { title: 'Imported Title', author: 'Imported Author', coverUri: 'file:///old-cover.jpg' },
})
assert.equal(overridden.title, 'User Title')
assert.equal(overridden.titleSource, 'user_override')
assert.deepEqual(overridden.authors, ['User Author'])
assert.equal(overridden.status, 'hiatus')
assert.equal(overridden.coverReference, 'covers/user.jpg')

const sidecarBeatsDerived = resolveMetadata({
  sidecar: sidecar.metadata,
  derived: { title: 'Folder Title', authors: ['Derived Author'], status: 'ongoing', coverPath: 'derived.png' },
  existing: { title: 'Imported Title', author: 'Imported Author', coverUri: 'file:///old-cover.jpg' },
})
assert.equal(sidecarBeatsDerived.title, 'Sidecar Title')
assert.equal(sidecarBeatsDerived.titleSource, 'valid_sidecar')
assert.deepEqual(sidecarBeatsDerived.authors, ['Author A', 'Author B'])
assert.equal(sidecarBeatsDerived.status, 'completed')

const derivedFallback = resolveMetadata({
  derived: { title: 'Folder Title' },
  existing: { title: 'Imported Title', author: 'Imported Author' },
})
assert.equal(derivedFallback.title, 'Folder Title')
assert.equal(derivedFallback.titleSource, 'derived_folder_series')
assert.deepEqual(derivedFallback.authors, ['Imported Author'])
assert.equal(derivedFallback.authorsSource, 'existing_library_import')

assert.equal(validateCover('cover.jpg'), 'cover.jpg')
assert.equal(validateCover('covers/front.avif'), 'covers/front.avif')
for (const badCover of ['../cover.jpg', '/cover.jpg', 'C:/cover.jpg', 'covers/.hidden/front.jpg', '.cover/front.jpg', 'cover.txt', 'covers/front.svg']) {
  assert.throws(() => validateCover(badCover), /Unsafe|Unsupported/, `${badCover} must be rejected`)
}

assert.equal(parseSidecar({ title: 1 }).status, 'failure')
assert.equal(parseSidecar({ authors: [123] }).status, 'failure')
assert.equal(parseSidecar({ author: '' }).status, 'failure')
assert.equal(parseSidecar({ status: 'finished' }).status, 'failure')
assert.equal(parseSidecar('{bad json').failures[0].reason, 'malformed_json')

const libraryStorePayload = JSON.stringify({
  schemaVersion: 1,
  comics: [{
    id: 'local-folder-series-1',
    title: 'Folder Title',
    sourceKind: 'local_folder',
    sourcePath: '/library/Series',
    localMetadata: {
      titleOverride: 'Backup Title',
      authors: ['Backup Author'],
      status: 'completed',
      coverOverridePath: 'covers/backup.jpg',
    },
  }],
})
const entries = exportMetadataBackupEntries(libraryStorePayload)
assert.deepEqual(entries, [{
  comicId: 'local-folder-series-1',
  metadata: {
    titleOverride: 'Backup Title',
    authors: ['Backup Author'],
    status: 'completed',
    coverOverridePath: 'covers/backup.jpg',
  },
}])

const legacyPayload = JSON.stringify({
  schemaVersion: 1,
  comics: [{ id: 'local-folder-series-1', title: 'Folder Title', sourceKind: 'local_folder', sourcePath: '/library/Series' }],
})
const restored = JSON.parse(restoreMetadataBackupEntries(legacyPayload, entries))
assert.deepEqual(restored.comics[0].localMetadata, entries[0].metadata, 'backup metadata entries must restore into legacy library rows')
assert.equal(restoreMetadataBackupEntries(legacyPayload, undefined), legacyPayload, 'legacy payload without metadata must default safely')

mkdirSync(dirname(artifactPath), { recursive: true })
writeFileSync(artifactPath, `${JSON.stringify({
  verdict: 'PASS',
  fallbackOrder,
  sidecar: sidecar.metadata,
  overridden,
  sidecarBeatsDerived,
  derivedFallback,
  metadataBackupEntries: entries,
  restoredLegacyComic: restored.comics[0],
}, null, 2)}\n`)

console.log(`local metadata fixture written: ${artifactPath}`)

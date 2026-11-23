import { buffer } from '@kit.ArkTS'
import { inflateBackupGzip } from './BackupFileFormat'
import { SourceManga } from './SourceModels'

export interface MihonBackupChapter {
  url: string
  title: string
  scanlator: string
  read: boolean
  bookmarked: boolean
  pageIndex: number
  fetchedAt: number
  uploadedAt: number
  number: number
  sourceOrder: number
  modifiedAt: number
}

export interface MihonBackupHistory {
  chapterUrl: string
  readAt: number
  readDuration: number
}

export interface MihonBackupTracking {
  serviceId: number
  libraryId: string
  mediaId: string
  url: string
  title: string
  lastChapterRead: number
  totalChapters: number
  score: number
  status: number
  startedAt: number
  finishedAt: number
  private: boolean
}

export interface MihonBackupWorkSummary {
  sourceId: string
  url: string
  title: string
  artist: string
  author: string
  description: string
  genres: string[]
  status: number
  coverUrl: string
  addedAt: number
  favorite: boolean
  modifiedAt: number
  favoriteModifiedAt?: number
  // Mihon field 17 stores category order values. Keep the serialized property name for saved imports.
  categoryIds: string[]
  notes: string
}

export interface MihonBackupWork extends MihonBackupWorkSummary {
  chapters: MihonBackupChapter[]
  history: MihonBackupHistory[]
  tracking: MihonBackupTracking[]
}

export interface MihonImportWork {
  id: string
  sourceName: string
  work: MihonBackupWorkSummary
  categoryIds: string[]
  matchedSourceId?: string
  targetComicId?: string
  linkedWork?: SourceManga
}

/** Store the original chapter and tracking facts even after linking a Koma edition. */
export interface MihonImportRecord extends MihonImportWork {
  work: MihonBackupWork
}

export interface MihonBackupSource {
  id: string
  name: string
}

export interface MihonBackupCategory {
  id: string
  name: string
  order: number
}

export interface MihonBackup {
  works: MihonBackupWork[]
  sources: MihonBackupSource[]
  categories: MihonBackupCategory[]
}

/** Decode the portable backup models declared by Mihon in data/backup/models.
 * Keep source and chapter identities as exported until the book source supplies its mapping.
 */
export async function readMihonBackup(bytes: ArrayBuffer): Promise<MihonBackup> {
  const reader = new MihonProtoReader(new Uint8Array(await inflateBackupGzip(bytes)))
  const backup: MihonBackup = { works: [], sources: [], categories: [] }
  while (reader.hasNext()) {
    switch (reader.field()) {
      case 1: backup.works.push(readWork(reader.message())); break
      case 2: backup.categories.push(readCategory(reader.message())); break
      case 101: backup.sources.push(readSource(reader.message())); break
      default: reader.skip()
    }
  }
  if (backup.works.length === 0 && backup.sources.length === 0 && backup.categories.length === 0) {
    throw new Error('mihon_backup_no_library_data')
  }
  return backup
}

class MihonProtoReader {
  private readonly bytes: Uint8Array
  private position: number = 0
  private wire: number = 0

  constructor(bytes: Uint8Array) {
    this.bytes = bytes
  }

  hasNext(): boolean {
    return this.position < this.bytes.length
  }

  private varint(): bigint {
    let value = 0n
    for (let i = 0; i < 10 && this.hasNext(); i++) {
      const byte = this.bytes[this.position++]
      if (i === 9 && byte > 1) break
      value |= BigInt(byte & 127) << BigInt(i * 7)
      if (byte < 128) return value
    }
    throw new Error('mihon_backup_invalid_varint')
  }

  private take(length: number): Uint8Array {
    if (length > this.bytes.length - this.position) throw new Error('mihon_backup_truncated')
    const start = this.position
    this.position += length
    return this.bytes.subarray(start, this.position)
  }

  private requireWire(wire: number): void {
    if (this.wire !== wire) throw new Error('mihon_backup_invalid_field')
  }

  field(): number {
    const key = Number(this.varint())
    if (key < 8 || key > 0xffffffff) throw new Error('mihon_backup_invalid_field')
    this.wire = key & 7
    return key >>> 3
  }

  private int64(): bigint {
    this.requireWire(0)
    return BigInt.asIntN(64, this.varint())
  }

  integer(): number {
    const value = Number(this.int64())
    if (!Number.isSafeInteger(value)) throw new Error('mihon_backup_number_overflow')
    return value
  }

  id(): string {
    return this.int64().toString()
  }

  ids(): string[] {
    if (this.wire === 0) return [this.id()]
    const packed = this.message()
    const values: string[] = []
    while (packed.hasNext()) values.push(packed.id())
    return values
  }

  private delimited(): Uint8Array {
    this.requireWire(2)
    return this.take(Number(this.varint()))
  }

  string(): string {
    const data = this.delimited()
    if (data.byteLength === 0) return ''
    return buffer.from(data.buffer, data.byteOffset, data.byteLength).toString('utf-8')
  }

  message(): MihonProtoReader {
    return new MihonProtoReader(this.delimited())
  }

  float(): number {
    this.requireWire(5)
    const data = this.take(4)
    return new DataView(data.buffer, data.byteOffset, data.byteLength).getFloat32(0, true)
  }

  skip(): void {
    switch (this.wire) {
      case 0: this.varint(); break
      case 1: this.take(8); break
      case 2: this.delimited(); break
      case 5: this.take(4); break
      default: throw new Error('mihon_backup_invalid_field')
    }
  }
}

function readWork(reader: MihonProtoReader): MihonBackupWork {
  const result: MihonBackupWork = {
    sourceId: '', url: '', title: '', artist: '', author: '', description: '', genres: [], status: 0, coverUrl: '',
    addedAt: 0, favorite: true, modifiedAt: 0, chapters: [], categoryIds: [], history: [], tracking: [], notes: '',
  }
  let hasUrl = false
  while (reader.hasNext()) {
    switch (reader.field()) {
      case 1: result.sourceId = reader.id(); break
      case 2: result.url = reader.string(); hasUrl = true; break
      case 3: result.title = reader.string(); break
      case 4: result.artist = reader.string(); break
      case 5: result.author = reader.string(); break
      case 6: result.description = reader.string(); break
      case 7: result.genres.push(reader.string()); break
      case 8: result.status = reader.integer(); break
      case 9: result.coverUrl = reader.string(); break
      case 13: result.addedAt = reader.integer(); break
      case 16: result.chapters.push(readChapter(reader.message())); break
      case 17: result.categoryIds = result.categoryIds.concat(reader.ids()); break
      case 18: result.tracking.push(readTracking(reader.message())); break
      case 100: result.favorite = reader.integer() !== 0; break
      case 104: result.history.push(readHistory(reader.message())); break
      case 106: result.modifiedAt = reader.integer(); break
      case 107: result.favoriteModifiedAt = reader.integer(); break
      case 110: result.notes = reader.string(); break
      default: reader.skip()
    }
  }
  if (!result.sourceId || !hasUrl) throw new Error('mihon_backup_invalid_work')
  return result
}

function readTracking(reader: MihonProtoReader): MihonBackupTracking {
  const result: MihonBackupTracking = {
    serviceId: 0, libraryId: '0', mediaId: '0', url: '', title: '', lastChapterRead: 0, totalChapters: 0,
    score: 0, status: 0, startedAt: 0, finishedAt: 0, private: false,
  }
  let legacyMediaId = '0'
  while (reader.hasNext()) {
    switch (reader.field()) {
      case 1: result.serviceId = reader.integer(); break
      case 2: result.libraryId = reader.id(); break
      case 3: legacyMediaId = reader.id(); break
      case 4: result.url = reader.string(); break
      case 5: result.title = reader.string(); break
      case 6: result.lastChapterRead = reader.float(); break
      case 7: result.totalChapters = reader.integer(); break
      case 8: result.score = reader.float(); break
      case 9: result.status = reader.integer(); break
      case 10: result.startedAt = reader.integer(); break
      case 11: result.finishedAt = reader.integer(); break
      case 12: result.private = reader.integer() !== 0; break
      case 100: result.mediaId = reader.id(); break
      default: reader.skip()
    }
  }
  if (legacyMediaId !== '0') result.mediaId = legacyMediaId
  return result
}

function readChapter(reader: MihonProtoReader): MihonBackupChapter {
  const result: MihonBackupChapter = {
    url: '', title: '', scanlator: '', read: false, bookmarked: false, pageIndex: 0,
    fetchedAt: 0, uploadedAt: 0, number: 0, sourceOrder: 0, modifiedAt: 0,
  }
  while (reader.hasNext()) {
    switch (reader.field()) {
      case 1: result.url = reader.string(); break
      case 2: result.title = reader.string(); break
      case 3: result.scanlator = reader.string(); break
      case 4: result.read = reader.integer() !== 0; break
      case 5: result.bookmarked = reader.integer() !== 0; break
      case 6: result.pageIndex = reader.integer(); break
      case 7: result.fetchedAt = reader.integer(); break
      case 8: result.uploadedAt = reader.integer(); break
      case 9: result.number = reader.float(); break
      case 10: result.sourceOrder = reader.integer(); break
      case 11: result.modifiedAt = reader.integer(); break
      default: reader.skip()
    }
  }
  return result
}

function readHistory(reader: MihonProtoReader): MihonBackupHistory {
  const result: MihonBackupHistory = { chapterUrl: '', readAt: 0, readDuration: 0 }
  while (reader.hasNext()) {
    switch (reader.field()) {
      case 1: result.chapterUrl = reader.string(); break
      case 2: result.readAt = reader.integer(); break
      case 3: result.readDuration = reader.integer(); break
      default: reader.skip()
    }
  }
  return result
}

function readSource(reader: MihonProtoReader): MihonBackupSource {
  const result: MihonBackupSource = { id: '', name: '' }
  while (reader.hasNext()) {
    switch (reader.field()) {
      case 1: result.name = reader.string(); break
      case 2: result.id = reader.id(); break
      default: reader.skip()
    }
  }
  return result
}

function readCategory(reader: MihonProtoReader): MihonBackupCategory {
  const result: MihonBackupCategory = { id: '0', name: '', order: 0 }
  while (reader.hasNext()) {
    switch (reader.field()) {
      case 1: result.name = reader.string(); break
      case 2: result.order = reader.integer(); break
      case 3: result.id = reader.id(); break
      default: reader.skip()
    }
  }
  return result
}

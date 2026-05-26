import { fileIo as fs } from '@kit.CoreFileKit'
import {
  ComicId,
  ReadingProgress,
} from './ComicModels'

export const CHAPTER_READ_STATE_SCHEMA_VERSION: number = 1
export const CHAPTER_READ_STATE_FILE_NAME: string = 'chapter-read-state.v1.json'

export interface ChapterReadStateOverride {
  comicId: ComicId
  chapterId: string
  isRead: boolean
  updatedAt: number
}

interface ChapterReadStateDocument {
  schemaVersion: number
  overrides: ChapterReadStateOverride[]
}

export interface ChapterReadStatePersistenceAdapter {
  load(): string | undefined
  save(payload: string): void
}

function joinChapterReadStatePath(parent: string, child: string): string {
  const left = parent.replace(/\\/g, '/').replace(/\/+$/, '')
  const right = child.replace(/\\/g, '/').replace(/^\/+/, '')
  if (left.length === 0) {
    return right
  }
  return `${left}/${right}`
}

function chapterReadStateKey(comicId: ComicId, chapterId: string): string {
  return `${comicId}::${chapterId}`
}

function sanitizeOverride(row: ChapterReadStateOverride): ChapterReadStateOverride | undefined {
  const comicId = row.comicId.trim()
  const chapterId = row.chapterId.trim()
  if (comicId.length === 0 || chapterId.length === 0) {
    return undefined
  }
  return {
    comicId,
    chapterId,
    isRead: row.isRead === true,
    updatedAt: Number.isFinite(row.updatedAt) ? row.updatedAt : Date.now(),
  }
}

function parseChapterReadStateDocument(payload: string): ChapterReadStateDocument {
  const parsed = JSON.parse(payload) as ChapterReadStateDocument
  if (parsed.schemaVersion !== CHAPTER_READ_STATE_SCHEMA_VERSION || !Array.isArray(parsed.overrides)) {
    throw new Error('Invalid chapter read-state persistence payload')
  }
  return parsed
}

export function isChapterReadFromState(
  comicId: ComicId,
  chapterId: string,
  progress?: ReadingProgress,
  override?: ChapterReadStateOverride
): boolean {
  if (override !== undefined && override.comicId === comicId && override.chapterId === chapterId) {
    return override.isRead
  }
  return progress !== undefined &&
    progress.comicId === comicId &&
    progress.chapterId === chapterId &&
    progress.completed === true
}

export class AppFilesChapterReadStatePersistenceAdapter implements ChapterReadStatePersistenceAdapter {
  private readonly filePath: string

  constructor(filesDir: string, fileName: string = CHAPTER_READ_STATE_FILE_NAME) {
    this.filePath = joinChapterReadStatePath(filesDir, fileName)
  }

  load(): string | undefined {
    if (!fs.accessSync(this.filePath)) {
      return undefined
    }
    return fs.readTextSync(this.filePath, { encoding: 'utf-8' })
  }

  save(payload: string): void {
    let file: fs.File | undefined = undefined
    try {
      file = fs.openSync(this.filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
    } finally {
      if (file !== undefined) {
        fs.closeSync(file)
      }
    }
  }
}

export class ChapterReadStateStore {
  private overrides: Map<string, ChapterReadStateOverride> = new Map<string, ChapterReadStateOverride>()
  private adapter: ChapterReadStatePersistenceAdapter

  constructor(adapter: ChapterReadStatePersistenceAdapter) {
    this.adapter = adapter
    this.restore()
  }

  private restore(): void {
    const payload = this.adapter.load()
    if (payload === undefined || payload.length === 0) {
      return
    }
    const document = parseChapterReadStateDocument(payload)
    document.overrides.forEach((row: ChapterReadStateOverride) => {
      const normalized = sanitizeOverride(row)
      if (normalized !== undefined) {
        this.overrides.set(chapterReadStateKey(normalized.comicId, normalized.chapterId), normalized)
      }
    })
  }

  private persist(): void {
    const document: ChapterReadStateDocument = {
      schemaVersion: CHAPTER_READ_STATE_SCHEMA_VERSION,
      overrides: Array.from(this.overrides.values()).sort((left: ChapterReadStateOverride, right: ChapterReadStateOverride): number => {
        if (left.comicId !== right.comicId) {
          return left.comicId.localeCompare(right.comicId)
        }
        return left.chapterId.localeCompare(right.chapterId)
      }),
    }
    this.adapter.save(JSON.stringify(document))
  }

  get(comicId: ComicId, chapterId: string): ChapterReadStateOverride | undefined {
    return this.overrides.get(chapterReadStateKey(comicId, chapterId))
  }

  isRead(comicId: ComicId, chapterId: string, progress?: ReadingProgress): boolean {
    return isChapterReadFromState(comicId, chapterId, progress, this.get(comicId, chapterId))
  }

  mark(comicId: ComicId, chapterId: string, isRead: boolean): ChapterReadStateOverride | undefined {
    const normalized = sanitizeOverride({
      comicId,
      chapterId,
      isRead,
      updatedAt: Date.now(),
    })
    if (normalized === undefined) {
      return undefined
    }
    this.overrides.set(chapterReadStateKey(normalized.comicId, normalized.chapterId), normalized)
    this.persist()
    return normalized
  }
}

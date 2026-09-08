import {
  MangaChapterItem,
  MangaDetail,
} from './MangaDetailModels'
import { SourceRuntimeRegistryEntry } from '../sourceRuntime/SourceRuntimeRegistry'

export interface SourceMangaDetailSnapshot {
  detail: MangaDetail
  chapters: MangaChapterItem[]
  chaptersResolved: boolean
}

function cloneMangaDetail(detail: MangaDetail): MangaDetail {
  return {
    id: detail.id,
    title: detail.title,
    author: detail.author,
    artist: detail.artist,
    description: detail.description,
    coverUrl: detail.coverUrl,
    status: detail.status,
    tags: detail.tags === undefined ? undefined : detail.tags.slice(),
    sourceId: detail.sourceId,
    sourceImageId: detail.sourceImageId,
    sourceName: detail.sourceName,
    chapterCount: detail.chapterCount,
    isInLibrary: detail.isInLibrary,
    url: detail.url,
  }
}

function cloneMangaChapterItem(chapter: MangaChapterItem): MangaChapterItem {
  return {
    id: chapter.id,
    title: chapter.title,
    chapterNumber: chapter.chapterNumber,
    volumeNumber: chapter.volumeNumber,
    readingGroup: chapter.readingGroup,
    continuationEligible: chapter.continuationEligible,
    scanlator: chapter.scanlator,
    language: chapter.language,
    dateUpload: chapter.dateUpload,
    pageCount: chapter.pageCount,
    isRead: chapter.isRead,
    isDownloaded: chapter.isDownloaded,
    downloadStatus: chapter.downloadStatus,
  }
}

function cloneSnapshot(snapshot: SourceMangaDetailSnapshot): SourceMangaDetailSnapshot {
  return {
    detail: cloneMangaDetail(snapshot.detail),
    chapters: snapshot.chapters.map((chapter: MangaChapterItem): MangaChapterItem => cloneMangaChapterItem(chapter)),
    chaptersResolved: snapshot.chaptersResolved,
  }
}

function sourceMangaDetailSnapshotCacheKey(
  entry: SourceRuntimeRegistryEntry,
  sourceId: string,
  mangaId: string,
): string {
  return [
    sourceId.trim(),
    mangaId.trim(),
    entry.manifestVersion.trim(),
    `${entry.wasmByteCount}`,
  ].join('\u001f')
}

/**
 * Current-process source metadata cache. It deliberately contains only manga
 * metadata and chapter rows: page descriptors can carry short-lived source
 * URLs and must be resolved again by the Reader path.
 */
export class SourceMangaDetailSnapshotCache {
  private readonly snapshots: Map<string, SourceMangaDetailSnapshot> = new Map<string, SourceMangaDetailSnapshot>()

  read(
    entry: SourceRuntimeRegistryEntry,
    sourceId: string,
    mangaId: string,
  ): SourceMangaDetailSnapshot | undefined {
    const snapshot = this.snapshots.get(sourceMangaDetailSnapshotCacheKey(entry, sourceId, mangaId))
    return snapshot === undefined ? undefined : cloneSnapshot(snapshot)
  }

  write(
    entry: SourceRuntimeRegistryEntry,
    sourceId: string,
    mangaId: string,
    snapshot: SourceMangaDetailSnapshot,
  ): void {
    this.snapshots.set(
      sourceMangaDetailSnapshotCacheKey(entry, sourceId, mangaId),
      cloneSnapshot(snapshot),
    )
  }
}

export const sourceMangaDetailSnapshotCache: SourceMangaDetailSnapshotCache = new SourceMangaDetailSnapshotCache()

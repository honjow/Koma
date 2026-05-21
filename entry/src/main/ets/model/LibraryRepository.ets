import { Comic, ComicId } from './ComicModels'
import { LibraryStore } from './LibraryStore'
import {
  LibraryComicPresentation,
  LibraryPresentationByComicId,
  LibraryViewModel,
  createLibraryViewModelFromStores,
} from './MockLibraryData'
import { ReaderSessionStore } from './ReaderSessionStore'

export interface LibraryRepository {
  upsertComic(comic: Comic): LibraryViewModel
  createViewModel(): LibraryViewModel
}

export class StoreBackedLibraryRepository implements LibraryRepository {
  private libraryStore: LibraryStore
  private sessionStore?: ReaderSessionStore
  private presentationByComicId: LibraryPresentationByComicId

  constructor(
    libraryStore: LibraryStore,
    sessionStore?: ReaderSessionStore,
    presentationByComicId: LibraryPresentationByComicId = new Map<ComicId, LibraryComicPresentation>()
  ) {
    this.libraryStore = libraryStore
    this.sessionStore = sessionStore
    this.presentationByComicId = presentationByComicId
  }

  upsertComic(comic: Comic): LibraryViewModel {
    this.libraryStore.upsertComic(comic)
    return this.createViewModel()
  }

  createViewModel(): LibraryViewModel {
    return createLibraryViewModelFromStores(
      this.libraryStore,
      this.sessionStore,
      this.presentationByComicId
    )
  }
}

export function upsertComicAndCreateLibraryViewModel(
  libraryStore: LibraryStore,
  comic: Comic,
  sessionStore?: ReaderSessionStore,
  presentationByComicId: LibraryPresentationByComicId = new Map<ComicId, LibraryComicPresentation>()
): LibraryViewModel {
  libraryStore.upsertComic(comic)
  return createLibraryViewModelFromStores(libraryStore, sessionStore, presentationByComicId)
}

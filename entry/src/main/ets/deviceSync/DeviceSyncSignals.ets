import { SyncEditKind, SyncGroup, SyncVersion } from './DeviceSyncFacts'
import { ReadingProgress } from '../model/ComicModels'

export interface SyncReadingSignal {
  comicId: string
  chapterId: string
  kind: 'read' | 'unread' | 'bookmark' | 'unbookmark' | 'remove-history' | 'clear-history'
}

let restoreStarted: (() => void) | undefined
let restoreFinished: ((committed: boolean) => void) | undefined
let changed: ((group: SyncGroup) => void) | undefined

export function connectDeviceSyncSignals(onChanged: (group: SyncGroup) => void): void {
  changed = onChanged
}

export function signalDeviceSyncChange(group: SyncGroup): void {
  changed?.(group)
}

export function connectDeviceSyncRestore(onStart: () => void, onFinish: (committed: boolean) => void): void {
  restoreStarted = onStart
  restoreFinished = onFinish
}

export function signalDeviceSyncRestoreStart(): void {
  restoreStarted?.()
}

export function signalDeviceSyncRestoreFinish(committed: boolean): void {
  restoreFinished?.(committed)
}

let allowProgress: ((progress: ReadingProgress) => boolean) | undefined

export function connectDeviceSyncProgress(check: (progress: ReadingProgress) => boolean): void {
  allowProgress = check
}

export function allowDeviceSyncReaderProgress(progress: ReadingProgress): boolean {
  return allowProgress?.(progress) ?? true
}

export interface SyncReadingCapture {
  id: string
  space: string
  source: string
  work: string
  comicId: string
  chapterId: string
  page: number
  total: number
  complete: boolean
  date: number
  descriptorHash: string
  observedActions: string[]
  positionSeen: SyncVersion[]
  recentSeen: SyncVersion[]
  recentCleared: SyncVersion[]
  readSeen: SyncVersion[]
}

export function deviceSyncCaptureKey(capture: SyncReadingCapture): string {
  return JSON.stringify([capture.space, capture.comicId, capture.chapterId])
}

export interface SyncCapturedReadingEdit {
  key: string
  kind: SyncEditKind
  value: string
  observed: SyncVersion[]
}

export interface SyncReadingActionCapture {
  id: string
  space: string
  source: string
  work: string
  chapterId: string
  edits: SyncCapturedReadingEdit[]
}

export function deviceSyncActionCaptureKey(capture: SyncReadingActionCapture): string {
  return JSON.stringify([capture.space, capture.id])
}

let captureReading: ((rows: ReadingProgress[]) => SyncReadingCapture[]) | undefined
let capturedReading: ((capture: SyncReadingCapture) => boolean) | undefined
let captureActions: ((actions: SyncReadingSignal[]) => SyncReadingActionCapture[]) | undefined
let capturedAction: ((capture: SyncReadingActionCapture) => boolean) | undefined

export function connectDeviceSyncReadingCapture(stage: (rows: ReadingProgress[]) => SyncReadingCapture[],
  acknowledged: (capture: SyncReadingCapture) => boolean,
  stageActions: (actions: SyncReadingSignal[]) => SyncReadingActionCapture[],
  actionAcknowledged: (capture: SyncReadingActionCapture) => boolean): void {
  captureReading = stage
  capturedReading = acknowledged
  captureActions = stageActions
  capturedAction = actionAcknowledged
}

export function stageDeviceSyncReading(rows: ReadingProgress[]): SyncReadingCapture[] {
  return captureReading?.(rows) ?? []
}

export function deviceSyncReadingAcknowledged(capture: SyncReadingCapture): boolean {
  return capturedReading?.(capture) ?? false
}

export function stageDeviceSyncReadingActions(actions: SyncReadingSignal[]): SyncReadingActionCapture[] {
  return captureActions?.(actions) ?? []
}

export function deviceSyncReadingActionAcknowledged(capture: SyncReadingActionCapture): boolean {
  return capturedAction?.(capture) ?? false
}

export interface SyncLibrarySignal {
  kind: 'add-book' | 'remove-book' | 'remove-category' | 'add-member' | 'remove-member'
  source?: string
  work?: string
  category?: string
}

export interface SyncBookModeSignal {
  comicId: string
  mode?: string
  direction?: string
}

let libraryEdit: ((actions: SyncLibrarySignal[]) => void) | undefined
let readerModeEdit: ((action: SyncBookModeSignal) => void) | undefined
let removedSubscription: ((address: string) => void) | undefined

export function connectDeviceSyncOwnerEdits(library: (actions: SyncLibrarySignal[]) => void,
  readerMode: (action: SyncBookModeSignal) => void, subscription: (address: string) => void): void {
  libraryEdit = library
  readerModeEdit = readerMode
  removedSubscription = subscription
}

export function signalDeviceSyncLibrary(actions: SyncLibrarySignal[]): void {
  libraryEdit?.(actions)
}

export function signalDeviceSyncBookMode(action: SyncBookModeSignal): void {
  readerModeEdit?.(action)
}

export function signalDeviceSyncSubscriptionRemoved(address: string): void {
  removedSubscription?.(address)
}

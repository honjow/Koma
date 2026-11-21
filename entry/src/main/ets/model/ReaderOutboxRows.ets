import type { relationalStore } from '@kit.ArkData'
import type { SyncRecentValue } from '../deviceSync/DeviceSyncData'
import type { SyncEditKind, SyncVersion } from '../deviceSync/DeviceSyncFacts'
import type { SyncCapturedReadingEdit, SyncReadingActionCapture, SyncReadingCapture } from '../deviceSync/DeviceSyncSignals'
import { booleanValue, integerColumn, LocalColumnValue, LocalDataRows, textColumn } from './LocalDataRows'

interface OrderedCapture<T> {
  order: number
  capture: T
}

interface PositionVersionRow extends SyncVersion {
  space: string
  id: string
  field: string
  order: number
}

interface RelatedActionRow {
  space: string
  id: string
  order: number
  actionId: string
}

interface ActionEditRow {
  space: string
  id: string
  order: number
  edit: SyncCapturedReadingEdit
}

interface ActionVersionRow extends SyncVersion {
  space: string
  id: string
  editOrder: number
  order: number
}

const positionCaptures = new LocalDataRows<OrderedCapture<SyncReadingCapture>>('reader_outbox_positions', ['space', 'capture_id'],
  ['list_order', 'source_id', 'source_work_id', 'comic_id', 'chapter_id', 'page_index', 'total_pages', 'completed',
    'saved_at', 'recent_chapter_id', 'recent_chapter_title', 'recent_title', 'recent_source_name', 'recent_source_version',
    'recent_saved_at', 'recent_page_index', 'recent_work_url'], 'list_order',
  (record: OrderedCapture<SyncReadingCapture>): LocalColumnValue[] => {
    const capture = record.capture
    const recent = capture.recent
    return [capture.space, capture.id, record.order, capture.source, capture.work,
      capture.comicId, capture.chapterId, capture.page, capture.total, booleanValue(capture.complete),
      capture.date, recent?.chapter ?? null, recent?.chapterTitle ?? null, recent?.title ?? null,
      recent?.sourceName ?? null, recent?.sourceVersion ?? null, recent?.date ?? null, recent?.savedPage ?? null,
      recent?.workUrl ?? null]
  },
  (row: relationalStore.ResultSet): OrderedCapture<SyncReadingCapture> => {
    const recent: SyncRecentValue | undefined = row.isColumnNull(11) ? undefined : {
      chapter: row.getString(11), chapterTitle: row.getString(12), title: row.getString(13), sourceName: row.getString(14),
      sourceVersion: textColumn(row, 15), date: row.getLong(16), savedPage: integerColumn(row, 17), workUrl: textColumn(row, 18),
    }
    return { order: row.getLong(2), capture: {
      space: row.getString(0), id: row.getString(1), source: row.getString(3), work: row.getString(4),
      comicId: row.getString(5), chapterId: row.getString(6), page: row.getLong(7), total: row.getLong(8),
      complete: row.getLong(9) !== 0, date: row.getLong(10), recent, observedActions: [], positionSeen: [],
      recentSeen: [], recentCleared: [], readSeen: [],
    } }
  })

const positionVersions = new LocalDataRows<PositionVersionRow>('reader_outbox_position_versions',
  ['space', 'capture_id', 'field_kind', 'vector_order'], ['replica', 'sequence'], 'space, capture_id, field_kind, vector_order',
  (row: PositionVersionRow): LocalColumnValue[] => [row.space, row.id, row.field, row.order, row.replica, row.sequence],
  (row: relationalStore.ResultSet): PositionVersionRow => ({
    space: row.getString(0), id: row.getString(1), field: row.getString(2), order: row.getLong(3),
    replica: row.getString(4), sequence: row.getLong(5),
  }))

const positionActions = new LocalDataRows<RelatedActionRow>('reader_outbox_position_observed_actions',
  ['space', 'capture_id', 'action_order'], ['action_id'], 'space, capture_id, action_order',
  (row: RelatedActionRow): LocalColumnValue[] => [row.space, row.id, row.order, row.actionId],
  (row: relationalStore.ResultSet): RelatedActionRow => ({
    space: row.getString(0), id: row.getString(1), order: row.getLong(2), actionId: row.getString(3),
  }))

const actionCaptures = new LocalDataRows<OrderedCapture<SyncReadingActionCapture>>('reader_outbox_actions', ['space', 'capture_id'],
  ['list_order', 'source_id', 'source_work_id', 'chapter_id'], 'list_order',
  (record: OrderedCapture<SyncReadingActionCapture>): LocalColumnValue[] => [
    record.capture.space, record.capture.id, record.order, record.capture.source,
    record.capture.work, record.capture.chapterId,
  ],
  (row: relationalStore.ResultSet): OrderedCapture<SyncReadingActionCapture> => ({
    order: row.getLong(2),
    capture: { space: row.getString(0), id: row.getString(1), source: row.getString(3),
      work: row.getString(4), chapterId: row.getString(5), edits: [] },
  }))

// edit_key/value are WebDAV operation fields. Business reading state lives in
// its own tables. Reconstructing an operation from state would lose its intent.
const actionEdits = new LocalDataRows<ActionEditRow>('reader_outbox_action_edits',
  ['space', 'capture_id', 'edit_order'], ['edit_key', 'edit_kind', 'edit_value'], 'space, capture_id, edit_order',
  (row: ActionEditRow): LocalColumnValue[] => [row.space, row.id, row.order, row.edit.key, row.edit.kind, row.edit.value],
  (row: relationalStore.ResultSet): ActionEditRow => ({
    space: row.getString(0), id: row.getString(1), order: row.getLong(2),
    edit: { key: row.getString(3), kind: row.getString(4) as SyncEditKind, value: row.getString(5), observed: [] },
  }))

const actionVersions = new LocalDataRows<ActionVersionRow>('reader_outbox_action_versions',
  ['space', 'capture_id', 'edit_order', 'vector_order'], ['replica', 'sequence'], 'space, capture_id, edit_order, vector_order',
  (row: ActionVersionRow): LocalColumnValue[] => [row.space, row.id, row.editOrder, row.order, row.replica, row.sequence],
  (row: relationalStore.ResultSet): ActionVersionRow => ({
    space: row.getString(0), id: row.getString(1), editOrder: row.getLong(2), order: row.getLong(3),
    replica: row.getString(4), sequence: row.getLong(5),
  }))

function positionVector(row: SyncReadingCapture, field: string): SyncVersion[] {
  if (field === 'position') return row.positionSeen
  if (field === 'recent') return row.recentSeen
  if (field === 'cleared') return row.recentCleared
  return row.readSeen
}

function captureKey(space: string, id: string): string {
  return JSON.stringify([space, id])
}

export class ReaderOutboxRows {
  private readonly positions: OrderedCapture<SyncReadingCapture>[]
  private readonly actions: OrderedCapture<SyncReadingActionCapture>[]
  private readonly positionVersions: PositionVersionRow[] = []
  private readonly positionActions: RelatedActionRow[] = []
  private readonly actionEdits: ActionEditRow[] = []
  private readonly actionVersions: ActionVersionRow[] = []

  constructor(positions: SyncReadingCapture[], actions: SyncReadingActionCapture[]) {
    this.positions = positions.map((capture: SyncReadingCapture, order: number): OrderedCapture<SyncReadingCapture> => {
      for (const field of ['position', 'recent', 'cleared', 'read']) {
        positionVector(capture, field)?.forEach((version: SyncVersion, index: number): void => {
          this.positionVersions.push({ space: capture.space, id: capture.id, field, order: index,
            replica: version.replica, sequence: version.sequence })
        })
      }
      capture.observedActions?.forEach((actionId: string, index: number): void => {
        this.positionActions.push({ space: capture.space, id: capture.id, order: index, actionId })
      })
      return { order, capture }
    })
    this.actions = actions.map((capture: SyncReadingActionCapture, order: number): OrderedCapture<SyncReadingActionCapture> => {
      capture.edits?.forEach((edit: SyncCapturedReadingEdit, editOrder: number): void => {
        this.actionEdits.push({ space: capture.space, id: capture.id, order: editOrder, edit })
        edit.observed.forEach((version: SyncVersion, index: number): void => {
          this.actionVersions.push({ space: capture.space, id: capture.id, editOrder, order: index,
            replica: version.replica, sequence: version.sequence })
        })
      })
      return { order, capture }
    })
  }

  async importRows(transaction: relationalStore.Transaction): Promise<void> {
    await positionCaptures.importRows(transaction, this.positions)
    await positionVersions.importRows(transaction, this.positionVersions)
    await positionActions.importRows(transaction, this.positionActions)
    await actionCaptures.importRows(transaction, this.actions)
    await actionEdits.importRows(transaction, this.actionEdits)
    await actionVersions.importRows(transaction, this.actionVersions)
  }

  replace(store: relationalStore.RdbStore): void {
    positionCaptures.replace(store, this.positions)
    positionVersions.replace(store, this.positionVersions)
    positionActions.replace(store, this.positionActions)
    actionCaptures.replace(store, this.actions)
    actionEdits.replace(store, this.actionEdits)
    actionVersions.replace(store, this.actionVersions)
  }
}

export function readPositionOutbox(store: relationalStore.RdbStore): SyncReadingCapture[] {
  const captures = positionCaptures.read(store).map((record: OrderedCapture<SyncReadingCapture>): SyncReadingCapture => record.capture)
  const byId = new Map<string, SyncReadingCapture>()
  for (const capture of captures) byId.set(captureKey(capture.space, capture.id), capture)
  for (const row of positionVersions.read(store)) {
    const capture = byId.get(captureKey(row.space, row.id))
    if (capture === undefined) throw new Error('reader_outbox_orphan_position_version')
    positionVector(capture, row.field).push({ replica: row.replica, sequence: row.sequence })
  }
  for (const row of positionActions.read(store)) {
    const capture = byId.get(captureKey(row.space, row.id))
    if (capture === undefined) throw new Error('reader_outbox_orphan_position_action')
    capture.observedActions.push(row.actionId)
  }
  return captures
}

export function readActionOutbox(store: relationalStore.RdbStore): SyncReadingActionCapture[] {
  const captures = actionCaptures.read(store).map((record: OrderedCapture<SyncReadingActionCapture>): SyncReadingActionCapture => record.capture)
  const byId = new Map<string, SyncReadingActionCapture>()
  for (const capture of captures) byId.set(captureKey(capture.space, capture.id), capture)
  for (const row of actionEdits.read(store)) {
    const capture = byId.get(captureKey(row.space, row.id))
    if (capture === undefined) throw new Error('reader_outbox_orphan_action_edit')
    capture.edits.push(row.edit)
  }
  for (const row of actionVersions.read(store)) {
    const capture = byId.get(captureKey(row.space, row.id))
    const edit = capture?.edits[row.editOrder]
    if (edit === undefined) throw new Error('reader_outbox_orphan_action_version')
    edit.observed.push({ replica: row.replica, sequence: row.sequence })
  }
  return captures
}

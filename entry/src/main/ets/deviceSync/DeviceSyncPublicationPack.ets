import { taskpool, util } from '@kit.ArkTS'
import { SyncObject, SyncShardRef } from './DeviceSyncWire'
import { buildPublicationPackBatches, decodePublicationPack, validatePublicationPackLocation,
  SyncPublicationPackBuild, SyncPublicationPackContent, SyncPublicationPackLocation } from './DeviceSyncPublicationPackCodec'

export interface PlannedPublicationPack { location: SyncPublicationPackLocation; body: string }
export interface PublicationPackPlan { packs: PlannedPublicationPack[]; singles: SyncObject[] }
export interface PublicationPackRead { objects: SyncObject[]; missing: SyncShardRef[]; incomplete: boolean }

/** beginUnique must durably reject a path already attempted, before PUT. */
export interface PublicationPackStore {
  beginUnique(path: string): Promise<void>
  completeUnique(path: string): Promise<void>
  put(path: string, body: string): Promise<void>
  get(path: string): Promise<string | undefined>
}

@Concurrent
function buildPackTask(writer: string, objects: SyncObject[]): SyncPublicationPackBuild {
  return buildPublicationPackBatches(writer, objects)
}

@Concurrent
function decodePackTask(location: SyncPublicationPackLocation, body: string): SyncPublicationPackContent {
  return decodePublicationPack(location, body)
}

function packPath(location: SyncPublicationPackLocation, attempt: string): string {
  return location.writer + '/packs/pack-' + attempt + '-' + location.hash + '.json'
}

/** Complete the plan before persisting the publication body and intent; this performs no network writes. */
export async function planPublicationPacks(writer: string, objects: SyncObject[], guard: () => void): Promise<PublicationPackPlan> {
  const built = await taskpool.execute(buildPackTask, writer, objects) as SyncPublicationPackBuild
  guard()
  const packs = built.batches.map((batch): PlannedPublicationPack => {
    const first = util.generateRandomUUID(), second = util.generateRandomUUID()
    if (first === second) throw new Error('sync_pack_invalid')
    return { body: batch.body, location: { writer, hash: batch.hash, bytes: batch.bytes,
      attempts: [first, second], members: batch.members } }
  })
  return { packs, singles: built.singles }
}

/** The caller persists locator + intent first; failed writes never authorize publishing the head. */
export async function writePublicationPacks(store: PublicationPackStore, plan: PublicationPackPlan,
  guard: () => void): Promise<void> {
  for (const pack of plan.packs) {
    for (const attempt of pack.location.attempts) {
      guard()
      const path = packPath(pack.location, attempt)
      await store.beginUnique(path)
      guard()
      await store.put(path, pack.body)
      guard()
      const read = await store.get(path)
      guard()
      if (read === undefined || read !== pack.body) throw new Error('sync_pack_unconfirmed')
      await taskpool.execute(decodePackTask, pack.location, read)
      guard()
      await store.completeUnique(path)
      guard()
    }
  }
}

/** Try one verified copy per referenced pack, then the alternate. Missing refs remain for old-path fallback. */
export async function readPublicationPacks(store: PublicationPackStore, locations: SyncPublicationPackLocation[],
  allRefs: SyncShardRef[], wantedRefs: SyncShardRef[], guard: () => void): Promise<PublicationPackRead> {
  const remaining = new Map<string, SyncShardRef[]>()
  wantedRefs.forEach((ref: SyncShardRef): void => {
    const key = ref.epoch.toString() + ':' + ref.hash
    remaining.set(key, (remaining.get(key) ?? []).concat(ref))
  })
  const objects: SyncObject[] = []
  const packs = new Map<string, SyncPublicationPackContent>()
  let incomplete = false
  for (const location of locations) {
    validatePublicationPackLocation(location, allRefs)
    if (!location.members.some((member): boolean => remaining.has(member.epoch.toString() + ':' + member.hash))) continue
    const packKey = location.writer + ':' + location.hash + ':' + location.bytes.toString()
    let pack: SyncPublicationPackContent | undefined = packs.get(packKey)
    let networkError: Error | undefined
    for (const attempt of location.attempts) {
      if (pack !== undefined) break
      let body: string | undefined
      try { body = await store.get(packPath(location, attempt)) } catch (error) {
        guard()
        const reason = (error as Error).message
        if (reason !== 'sync_network_timeout' && reason !== 'sync_network_failed') throw error as Error
        networkError = error as Error
        continue
      }
      guard()
      if (body === undefined) continue
      try { pack = await taskpool.execute(decodePackTask, location, body) as SyncPublicationPackContent; guard(); break }
      catch (_error) { guard() }
    }
    if (pack === undefined) {
      if (networkError !== undefined) throw networkError
      incomplete = true
      continue
    }
    packs.set(packKey, pack)
    if (location.members.some((member): boolean => !pack!.entries.some((entry): boolean =>
      entry.epoch === member.epoch && entry.hash === member.hash))) throw new Error('sync_pack_damaged')
    for (const entry of pack.entries) {
      const key = entry.epoch.toString() + ':' + entry.hash
      const matches = remaining.get(key)
      if (matches === undefined || !location.members.some((member): boolean =>
        member.epoch === entry.epoch && member.hash === entry.hash)) continue
      for (const ref of matches) {
        if (entry.bytes !== ref.bytes) throw new Error('sync_pack_damaged')
        objects.push({ ref, body: entry.body })
      }
      remaining.delete(key)
    }
  }
  const missing: SyncShardRef[] = []
  remaining.forEach((items: SyncShardRef[]): void => { missing.push(...items) })
  return { objects, missing, incomplete }
}

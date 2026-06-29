import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class RemoteProgressSyncState {
  @Trace syncRevision: number = 0
  @Trace lastSuccessAt: number = 0
}

const REMOTE_PROGRESS_SYNC_V2_KEY: string = 'v2:remoteProgressSync'

export function connectRemoteProgressSyncState(): RemoteProgressSyncState {
  return AppStorageV2.connect(
    RemoteProgressSyncState,
    REMOTE_PROGRESS_SYNC_V2_KEY,
    () => new RemoteProgressSyncState(),
  )!
}

export class RemoteProgressSyncBridge {
  static markSuccess(now: number = Date.now()): void {
    const state = connectRemoteProgressSyncState()
    state.lastSuccessAt = now
    state.syncRevision += 1
  }

  static lastSuccessAt(): number {
    return connectRemoteProgressSyncState().lastSuccessAt
  }
}

import { AppStorageV2 } from '@kit.ArkUI'
import { TrackerProviderId } from '../model/TrackerModels'

@ObservedV2
export class TrackerBrowserAuthorizationState {
  @Trace revision: number = 0
  providerId: TrackerProviderId | undefined = undefined
  connected: boolean = false
}

export function connectTrackerBrowserAuthorization(): TrackerBrowserAuthorizationState {
  return AppStorageV2.connect(TrackerBrowserAuthorizationState, 'v2:trackerBrowserAuthorization',
    () => new TrackerBrowserAuthorizationState())!
}

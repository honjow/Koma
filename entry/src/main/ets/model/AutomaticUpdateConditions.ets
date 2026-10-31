import { batteryInfo } from '@kit.BasicServicesKit'
import { connection } from '@kit.NetworkKit'
import { LibraryAutomationPreferences } from './LibraryAutomationPolicy'

export function automaticUpdateConditionsSatisfied(policy: LibraryAutomationPreferences): boolean {
  if (policy.updateChargingOnly && batteryInfo.pluggedType === batteryInfo.BatteryPluggedType.NONE) return false
  if (!policy.updateWifiOnly) return true
  try {
    const network = connection.getDefaultNetSync()
    return network.netId !== 0 && connection.getNetCapabilitiesSync(network).bearerTypes
      .includes(connection.NetBearType.BEARER_WIFI)
  } catch (_error) { return false }
}

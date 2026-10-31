import { connection } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

/** Host network policy only; visible page loading never uses this gate. */
export function readerPreloadNetworkIsWifi(): boolean {
  try {
    const network = connection.getDefaultNetSync()
    return network.netId !== 0 && connection.getNetCapabilitiesSync(network).bearerTypes
      .includes(connection.NetBearType.BEARER_WIFI)
  } catch (_error) { return false }
}

export function readerRemotePreloadAllowed(wifiOnly: boolean): boolean {
  return !wifiOnly || readerPreloadNetworkIsWifi()
}

/** One subscription for the live reader. It updates demand without replacing its session. */
export class ReaderPreloadNetworkMonitor {
  private network: connection.NetConnection
  private disposed: boolean = false
  constructor(onChange: (wifi: boolean) => void) {
    const publish = (): void => { if (!this.disposed) onChange(readerPreloadNetworkIsWifi()) }
    this.network = connection.createNetConnection()
    this.network.on('netAvailable', publish)
    this.network.on('netCapabilitiesChange', publish)
    this.network.on('netLost', publish)
    this.network.on('netUnavailable', publish)
    this.network.register((error: BusinessError): void => {
      if (error) DiagnosticLogger.exception('reader', 'preload_network_observer_failed', error)
      else publish()
    })
    publish()
  }
  dispose(): void {
    this.disposed = true
    this.network.unregister((error: BusinessError): void => {
      if (error) DiagnosticLogger.exception('reader', 'preload_network_observer_stop_failed', error)
    })
  }
}

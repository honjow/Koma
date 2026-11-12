import { taskpool, util } from '@kit.ArkTS'
import { http } from '@kit.NetworkKit'

export interface DeviceSyncStreamResponse {
  status: number
  body: string
  header: Object
}

@Concurrent
function decodeDeviceSyncStream(chunks: ArrayBuffer[]): string {
  const decoder = util.TextDecoder.create('utf-8', { fatal: true })
  const pieces: string[] = []
  for (const chunk of chunks) {
    pieces.push(decoder.decodeToString(new Uint8Array(chunk), { stream: true }))
  }
  // Flush an unfinished UTF-8 sequence at end-of-response, preserving fatal validation.
  pieces.push(decoder.decodeToString(new Uint8Array(0), { stream: false }))
  return pieces.join('')
}

/** Directory listings may exceed a single shard's HTTP response limit. */
export async function requestDeviceSyncStream(address: string, options: http.HttpRequestOptions,
  guard: () => void): Promise<DeviceSyncStreamResponse> {
  guard()
  const request = http.createHttp()
  let headers: Record<string, string> = {}
  let callbackError: Error | undefined
  let stopped = false
  let guardTimer: number = -1
  let rejectCancellation: (error: Error) => void = (_error: Error): void => {}
  const cancelled = new Promise<void>((_resolve: () => void, reject: (error: Error) => void): void => {
    rejectCancellation = reject
  })
  let watchActivity = false
  let inactivityTimer: number = -1
  let timedOut = false
  let onTimeout: () => void = (): void => {}
  const inactivityMs = options.readTimeout !== undefined && options.readTimeout > 0 ? options.readTimeout : 60000
  const resetInactivity = (): void => {
    if (!watchActivity) return
    if (inactivityTimer >= 0) clearTimeout(inactivityTimer)
    inactivityTimer = setTimeout((): void => { timedOut = true; onTimeout() }, inactivityMs)
  }
  const chunks: ArrayBuffer[] = []
  let complete: () => void = (): void => {}
  const ended = new Promise<void>((resolve: () => void): void => {
    complete = resolve
  })
  const stop = (): void => {
    if (stopped) return
    stopped = true
    try { request.destroy() } catch (_error) {}
  }
  const cancel = (error: Error): void => {
    if (callbackError !== undefined) return
    callbackError = error
    rejectCancellation(error)
    complete()
    stop()
  }
  const checkGuard = (): void => {
    try {
      guard()
      guardTimer = setTimeout(checkGuard, 500)
    } catch (error) {
      cancel(error as Error)
    }
  }
  const onHeaders = (value: Object): void => { headers = value as Record<string, string>; resetInactivity() }
  const onData = (value: ArrayBuffer): void => {
    if (callbackError !== undefined) return
    try {
      guard()
      chunks.push(value)
      resetInactivity()
    } catch (error) {
      cancel(error as Error)
    }
  }
  const onEnd = (): void => { complete() }
  try {
    request.on('headersReceive', onHeaders)
    request.on('dataReceive', onData)
    request.on('dataEnd', onEnd)
    guardTimer = setTimeout(checkGuard, 500)
    const status = await Promise.race([request.requestInStream(address, options), cancelled.then((): number => 0)])
    guard()
    if (callbackError !== undefined) throw callbackError as Error
    // DAV error responses and bodyless success statuses are decided by status;
    // they must not wait for an empty-body dataEnd event some servers omit.
    if (status < 200 || status >= 300 || status === 204 || status === 205) {
      return { status, body: '', header: headers }
    }
    // The status may arrive before the body. Apply the same inactivity policy
    // as the HTTP request, resetting it on each chunk instead of timing out an
    // actively progressing slow response.
    const timeout = new Promise<void>((resolve: () => void): void => {
      onTimeout = resolve
      watchActivity = true
      resetInactivity()
    })
    try {
      await Promise.race([ended, timeout, cancelled])
    } finally {
      watchActivity = false
      if (inactivityTimer >= 0) clearTimeout(inactivityTimer)
    }
    guard()
    if (callbackError !== undefined) throw callbackError as Error
    if (timedOut) throw new Error('sync_network_timeout')
    let body = ''
    try {
      // A taskpool decode can outlive the network request; cancellation must
      // still return promptly. Promise.race also observes a late worker error.
      body = await Promise.race([taskpool.execute(decodeDeviceSyncStream, chunks),
        cancelled.then((): string => '')]) as string
    } catch (_error) {
      throw new Error('sync_response_invalid')
    }
    guard()
    return { status, body, header: headers }
  } catch (error) {
    if (callbackError !== undefined) throw callbackError as Error
    throw error as Error
  } finally {
    if (guardTimer >= 0) clearTimeout(guardTimer)
    if (inactivityTimer >= 0) clearTimeout(inactivityTimer)
    try { request.off('headersReceive', onHeaders) } catch (_error) {}
    try { request.off('dataReceive', onData) } catch (_error) {}
    try { request.off('dataEnd', onEnd) } catch (_error) {}
    stop()
  }
}

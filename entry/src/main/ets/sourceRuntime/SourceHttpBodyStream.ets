import { http } from '@kit.NetworkKit'
import { SourceBodyHost, SourceBodyRef } from './SourceBodyHost'
import { SourcePrivateSessionScope } from './SourcePrivateSessionHost'

export interface SourceBodyHop { status: number; headers: Object; bodyRef: SourceBodyRef }

/** Spool each received chunk, rather than accumulate a complete Base64 envelope.
 * The synchronous source import returns a readable reference after the transfer;
 * it does not promise concurrent reads while the import is still blocked.
 */
export async function requestSourceBodyStream(request: http.HttpRequest, target: string,
  options: http.HttpRequestOptions, scope: SourcePrivateSessionScope, current: () => boolean): Promise<SourceBodyHop> {
  const body = SourceBodyHost.create(scope)
  let headers: Object = {} as Record<string, Object>
  let resolveEnd: () => void = (): void => {}
  const ended = new Promise<void>((resolve) => { resolveEnd = resolve })
  let rejectFailure: (reason: Error) => void = (_reason: Error): void => {}
  const failed = new Promise<SourceBodyHop>((_resolve, reject) => { rejectFailure = reject })
  const timer = setInterval((): void => {
    if (!current()) rejectFailure(new Error('source_request_cancelled'))
  }, 100)
  const deadline = setTimeout((): void => rejectFailure(new Error('timeout')),
    Math.max(1, options.readTimeout ?? 20000) + 1000)
  request.on('headersReceive', (value: Object): void => { headers = value })
  request.on('dataEnd', resolveEnd)
  request.on('dataReceive', (chunk: ArrayBuffer): void => {
    try {
      if (!current()) throw new Error('source_request_cancelled')
      SourceBodyHost.append(scope, body.id, chunk)
      body.length += chunk.byteLength
    } catch (error) { rejectFailure(error as Error) }
  })
  let accepted = false
  try {
    const pending = request.requestInStream(target, options).then(async (status: number): Promise<SourceBodyHop> => {
      await ended
      if (!current()) throw new Error('source_request_cancelled')
      return { status, headers, bodyRef: body }
    })
    const result = await Promise.race([pending, failed])
    accepted = true
    return result
  } finally {
    clearInterval(timer)
    clearTimeout(deadline)
    request.off('dataReceive')
    request.off('dataEnd')
    if (!accepted) SourceBodyHost.close(scope, body.id)
  }
}

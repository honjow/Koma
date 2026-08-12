import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { NativeSourceRuntime } from './NativeSourceRuntime'

interface SourceHttpRequestEnvelope {
  url?: Object | string | number | boolean | null
  method?: Object | string | number | boolean | null
  headers?: Object | string | number | boolean | null
  bodyBase64?: Object | string | number | boolean | null
  body?: Object | string | number | boolean | null
  timeoutMs?: Object | string | number | boolean | null
}

const SOURCE_HTTP_DEFAULT_TIMEOUT_MS: number = 15000
const SOURCE_HTTP_MAX_TIMEOUT_MS: number = 60000

class SourceHttpErrorPayload {
  code: string
  message: string = 'network request failed'
  retryable: boolean

  constructor(code: string, retryable: boolean) {
    this.code = code
    this.retryable = retryable
  }
}

class SourceHttpErrorEnvelope {
  ok: boolean = false
  error: SourceHttpErrorPayload
  networkPerformed: boolean = false

  constructor(code: string, retryable: boolean) {
    this.error = new SourceHttpErrorPayload(code, retryable)
  }
}

class SourceHttpSuccessEnvelope {
  ok: boolean = true
  // Keep this field aligned with the source-host ABI.  Source packages use
  // `status` to distinguish HTTP failures from transport failures.
  status: number
  bodyText: string
  networkPerformed: boolean = true

  constructor(status: number, bodyText: string) {
    this.status = status
    this.bodyText = bodyText
  }
}

function transportError(code: string, retryable: boolean = true): string {
  return JSON.stringify(new SourceHttpErrorEnvelope(code, retryable))
}

function sourceString(value: Object | string | number | boolean | null | undefined): string | undefined {
  if (typeof value !== 'string') {
    return undefined
  }
  return value
}

function sourceTimeout(value: Object | string | number | boolean | null | undefined): number {
  const parsed = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return SOURCE_HTTP_DEFAULT_TIMEOUT_MS
  }
  return Math.min(Math.max(Math.floor(parsed), 1000), SOURCE_HTTP_MAX_TIMEOUT_MS)
}

function sourceHeaders(value: Object | string | number | boolean | null | undefined): Record<string, string> {
  const headers: Record<string, string> = {}
  if (value === undefined || value === null || Array.isArray(value) || typeof value !== 'object') {
    return headers
  }
  const record = value as Record<string, Object | string | number | boolean | null>
  Object.keys(record).forEach((name: string) => {
    const raw = sourceString(record[name])
    if (raw === undefined || name.trim().length === 0 || name.length > 256 || raw.length > 8192) {
      return
    }
    headers[name] = raw
  })
  return headers
}

function sourceMethod(value: Object | string | number | boolean | null | undefined): string | undefined {
  const method = sourceString(value)?.trim().toUpperCase()
  if (method === undefined || !/^[A-Z]{3,12}$/.test(method)) {
    return undefined
  }
  return method
}

function sourceHttpUrl(value: Object | string | number | boolean | null | undefined): string | undefined {
  const url = sourceString(value)?.trim()
  if (url === undefined || (!url.startsWith('https://') && !url.startsWith('http://'))) {
    return undefined
  }
  return url
}

function sourceNetworkMethod(method: string): http.RequestMethod {
  return method === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET
}

async function executeSourceHttpRequest(requestJson: string): Promise<string> {
  let envelope: SourceHttpRequestEnvelope
  try {
    envelope = JSON.parse(requestJson) as SourceHttpRequestEnvelope
  } catch (_error) {
    return transportError('invalid_request', false)
  }
  const url = sourceHttpUrl(envelope.url)
  const method = sourceMethod(envelope.method)
  if (url === undefined || method === undefined) {
    return transportError('invalid_request', false)
  }
  const body = sourceString(envelope.bodyBase64) ?? sourceString(envelope.body) ?? ''
  if (body.length > 1024 * 1024) {
    return transportError('request_too_large', false)
  }
  const request = http.createHttp()
  try {
    const response = await request.request(url, {
      method: sourceNetworkMethod(method),
      customMethod: method === 'GET' || method === 'POST' ? undefined : method,
      extraData: body.length > 0 ? body : undefined,
      expectDataType: http.HttpDataType.STRING,
      usingCache: false,
      header: sourceHeaders(envelope.headers),
      readTimeout: sourceTimeout(envelope.timeoutMs),
      connectTimeout: sourceTimeout(envelope.timeoutMs),
    })
    const responseBody = typeof response.result === 'string' ? response.result : JSON.stringify(response.result)
    return JSON.stringify(new SourceHttpSuccessEnvelope(response.responseCode, responseBody))
  } catch (_error) {
    const error = _error as BusinessError
    return transportError(error.code === undefined ? 'network_error' : 'network_error')
  } finally {
    request.destroy()
  }
}

export function configureSourceRuntimeHttpTransport(): boolean {
  return NativeSourceRuntime.configureHttpTransport(executeSourceHttpRequest)
}

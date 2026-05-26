export type CrossSearchSectionState = 'pending' | 'running' | 'empty' | 'timeout' | 'failed' | 'unsupported' | 'ready'

export interface SearchDiagnostic {
  code: string
  userText: string
}

export function searchStateUserText(state: CrossSearchSectionState, diagnosticCode: string = ''): string {
  if (state === 'pending') {
    return '等待搜索'
  }
  if (state === 'running') {
    return '正在搜索'
  }
  if (state === 'empty') {
    return '没有匹配结果'
  }
  if (state === 'timeout') {
    return '搜索超时，请稍后重试。诊断：timeout'
  }
  if (state === 'unsupported') {
    return diagnosticCode === 'not_configured' ? '未配置此来源' : '此来源暂不支持搜索'
  }
  if (state === 'failed') {
    return '搜索失败。诊断：' + safeDiagnosticCode(diagnosticCode)
  }
  return ''
}

export function safeDiagnosticCode(value: string): string {
  const normalized = value.trim().toLocaleLowerCase()
  if (normalized.length === 0) {
    return 'unknown'
  }
  let safe = ''
  for (let index = 0; index < normalized.length; index += 1) {
    const ch = normalized.charAt(index)
    if ((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || ch === '_' || ch === '-') {
      safe += ch
    }
  }
  return safe.length === 0 ? 'unknown' : safe.substring(0, 48)
}

export function safeSearchDiagnostic(error: Error): SearchDiagnostic {
  const message = error.message.toLocaleLowerCase()
  let code = 'search_failed'
  if (message.indexOf('timeout') >= 0 || message.indexOf('timed out') >= 0 || message.indexOf('超时') >= 0) {
    code = 'timeout'
  } else if (message.indexOf('network') >= 0 || message.indexOf('http') >= 0 || message.indexOf('fetch') >= 0) {
    code = 'network_error'
  } else if (message.indexOf('source') >= 0 || message.indexOf('源') >= 0 || message.indexOf('wasm') >= 0 || message.indexOf('runtime') >= 0) {
    code = 'source_runtime'
  }
  return {
    code,
    userText: searchStateUserText(code === 'timeout' ? 'timeout' : 'failed', code),
  }
}

import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { DiagnosticLogEntry, DiagnosticsRedactor } from './DiagnosticsRedactor'
import { DiagnosticsLogFileSink } from './DiagnosticsLogFileSink'
import { DiagnosticsStore } from './DiagnosticsStore'

const DOMAIN: number = 0xC001
const TAG: string = 'Koma'
export type DiagnosticLogLevel = 'debug' | 'info' | 'warn' | 'error'

/**
 * Structured diagnostics over native hilog plus a redacted local retention sink.
 * Existing call sites keep using category + event + message; the logger owns
 * redaction and export safety so user feedback is not limited to live hilog capture.
 */
export class DiagnosticLogger {
  private static sequence: number = 0
  private static scope: string = Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8)
  private static enabled: boolean = true
  private static minLevel: DiagnosticLogLevel = 'info'

  static configure(enabled: boolean, minLevel: string = 'info'): void {
    try {
      DiagnosticLogger.enabled = enabled
      DiagnosticLogger.minLevel = DiagnosticLogger.normalizeLevel(minLevel)
    } catch (_error) {
    }
  }

  static initializePersistentSink(context: common.UIAbilityContext): void {
    try {
      DiagnosticsLogFileSink.initialize(context)
    } catch (_error) {
    }
  }

  static closePersistentSink(): void {
    try {
      DiagnosticsLogFileSink.close()
    } catch (_error) {
    }
  }

  static debug(category: string, event: string, message: string): void {
    DiagnosticLogger.log('debug', category, event, message)
  }

  static info(category: string, event: string, message: string): void {
    DiagnosticLogger.log('info', category, event, message)
  }

  static warn(category: string, event: string, message: string): void {
    DiagnosticLogger.log('warn', category, event, message)
  }

  static error(category: string, event: string, message: string): void {
    DiagnosticLogger.log('error', category, event, message)
  }

  static exception(category: string, event: string, err: Error): void {
    DiagnosticLogger.log('error', category, event, DiagnosticsRedactor.errorSummary(err))
  }

  static errorSummary(error: Error): string {
    return DiagnosticsRedactor.errorSummary(error)
  }

  static begin(category: string, event: string, detail: string = ''): DiagnosticOperation {
    DiagnosticLogger.sequence += 1
    return new DiagnosticOperation(category, event, DiagnosticLogger.scope + ':' + DiagnosticLogger.sequence, detail)
  }

  static exportText(): string {
    try {
      const latestFileText = DiagnosticsLogFileSink.exportLatestText()
      if (latestFileText.length > 0) {
        return latestFileText
      }
      return DiagnosticsStore.exportText()
    } catch (_error) {
      return ''
    }
  }

  static exportBufferedText(): string {
    try {
      return DiagnosticsStore.exportText()
    } catch (_error) {
      return ''
    }
  }

  static clear(): void {
    try {
      DiagnosticsStore.clear()
    } catch (_error) {
    }
  }

  static count(): number {
    try {
      return DiagnosticsStore.count()
    } catch (_error) {
      return 0
    }
  }

  private static log(level: DiagnosticLogLevel, category: string, event: string, message: string): void {
    try {
      if (!DiagnosticLogger.enabled || !DiagnosticLogger.shouldLog(level)) {
        return
      }
      const entry: DiagnosticLogEntry = DiagnosticsRedactor.sanitizeEvent({
        ts: Date.now(),
        level: level,
        category: category,
        event: event,
        message: message,
      })
      DiagnosticsStore.append(entry)
      DiagnosticsLogFileSink.append(entry)
      DiagnosticLogger.hilogSink(entry)
    } catch (_error) {
      // Diagnostics must never affect app behavior.
    }
  }

  private static hilogSink(entry: DiagnosticLogEntry): void {
    if (entry.level === 'debug') {
      hilog.debug(DOMAIN, TAG, '[%{public}s] %{public}s | %{public}s', entry.category, entry.event, entry.message)
      return
    }
    if (entry.level === 'warn') {
      hilog.warn(DOMAIN, TAG, '[%{public}s] %{public}s | %{public}s', entry.category, entry.event, entry.message)
      return
    }
    if (entry.level === 'error') {
      hilog.error(DOMAIN, TAG, '[%{public}s] %{public}s | %{public}s', entry.category, entry.event, entry.message)
      return
    }
    hilog.info(DOMAIN, TAG, '[%{public}s] %{public}s | %{public}s', entry.category, entry.event, entry.message)
  }

  private static shouldLog(level: DiagnosticLogLevel): boolean {
    return DiagnosticLogger.levelRank(level) >= DiagnosticLogger.levelRank(DiagnosticLogger.minLevel)
  }

  private static levelRank(level: string): number {
    if (level === 'debug') {
      return 10
    }
    if (level === 'warn') {
      return 30
    }
    if (level === 'error') {
      return 40
    }
    return 20
  }

  private static normalizeLevel(level: string): DiagnosticLogLevel {
    if (level === 'debug' || level === 'info' || level === 'warn' || level === 'error') {
      return level
    }
    return 'info'
  }
}

/** A temporary operation number links concurrent events without retaining content identities. */
export class DiagnosticOperation {
  private category: string
  private event: string
  private id: string
  private detail: string
  private started: number = Date.now()
  private ended: boolean = false

  constructor(category: string, event: string, id: string, detail: string) {
    this.category = category
    this.event = event
    this.id = id
    this.detail = detail
    this.info('start', '')
  }

  info(event: string, detail: string): void {
    DiagnosticLogger.info(this.category, this.event + '.' + event, 'op=' + this.id + ' ' + this.detail + ' ' + detail)
  }

  warn(event: string, detail: string): void {
    DiagnosticLogger.warn(this.category, this.event + '.' + event, 'op=' + this.id + ' ' + this.detail + ' ' + detail)
  }

  finish(status: string, detail: string = ''): void {
    if (this.ended) return
    this.ended = true
    const summary = 'status=' + status + ' durationMs=' + Math.max(0, Date.now() - this.started) + ' ' + detail
    if (status === 'failed' || status === 'rejected' || status === 'timeout' || status === 'blocked' || status === 'partial') this.warn('end', summary)
    else this.info('end', summary)
  }

  fail(error: Error): void {
    this.finish('failed', DiagnosticLogger.errorSummary(error))
  }
}

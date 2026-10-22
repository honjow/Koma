import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { connectDiagnostics } from '../state/DiagnosticsState'

export class DiagnosticsSettingsSnapshot {
  enabled: boolean = true
  minLevel: string = 'info'
}

export class DiagnosticsSettings {
  static readonly LEVEL_DEBUG: string = 'debug'
  static readonly LEVEL_INFO: string = 'info'
  static readonly LEVEL_WARN: string = 'warn'
  static readonly LEVEL_ERROR: string = 'error'
  static readonly DEFAULT_ENABLED: boolean = true
  static readonly DEFAULT_MIN_LEVEL: string = DiagnosticsSettings.LEVEL_INFO

  static apply(snapshot: DiagnosticsSettingsSnapshot): void {
    const safeLevel = DiagnosticsSettings.normalizeLevel(snapshot.minLevel)
    const state = connectDiagnostics()
    state.enabled = snapshot.enabled
    state.minLevel = safeLevel
    DiagnosticLogger.configure(snapshot.enabled, safeLevel)
  }

  static current(): DiagnosticsSettingsSnapshot {
    const state = connectDiagnostics()
    const snapshot = new DiagnosticsSettingsSnapshot()
    snapshot.enabled = state.enabled
    snapshot.minLevel = DiagnosticsSettings.normalizeLevel(state.minLevel)
    return snapshot
  }

  static async restore(context: common.UIAbilityContext): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(context, 'koma_diagnostics_settings')
      const snapshot = new DiagnosticsSettingsSnapshot()
      snapshot.enabled = store.getSync('enabled', DiagnosticsSettings.DEFAULT_ENABLED) as boolean
      snapshot.minLevel = DiagnosticsSettings.normalizeLevel(
        store.getSync('minLevel', DiagnosticsSettings.DEFAULT_MIN_LEVEL) as string,
      )
      DiagnosticsSettings.apply(snapshot)
      DiagnosticLogger.info('diagnostics', 'settings_restored', `enabled=${snapshot.enabled} minLevel=${snapshot.minLevel}`)
    } catch (error) {
      DiagnosticLogger.warn('settings', 'diagnostics_restore_failed', 'restored=false')
      DiagnosticsSettings.apply(new DiagnosticsSettingsSnapshot())
    }
  }

  static async save(context: common.UIAbilityContext, snapshot: DiagnosticsSettingsSnapshot): Promise<void> {
    const level = DiagnosticsSettings.normalizeLevel(snapshot.minLevel)
    try {
      // Synchronous preference commit keeps rapid toggles ordered on the UI runtime.
      const store = preferences.getPreferencesSync(context, { name: 'koma_diagnostics_settings' })
      store.putSync('enabled', snapshot.enabled)
      store.putSync('minLevel', level)
      store.flushSync()
      snapshot.minLevel = level
      DiagnosticsSettings.apply(snapshot)
      DiagnosticLogger.info('diagnostics', 'settings_saved', `enabled=${snapshot.enabled} minLevel=${level}`)
    } catch (_error) {
      DiagnosticLogger.warn('diagnostics', 'settings_save_failed', 'saved=false')
      throw new Error('diagnostics_settings_save_failed')
    }
  }

  static exportText(): string {
    return DiagnosticLogger.exportText()
  }

  static count(): number {
    return DiagnosticLogger.count()
  }

  static clearLogs(): void {
    DiagnosticLogger.clear()
    DiagnosticLogger.info('diagnostics', 'logs_cleared', 'current launch memory log cleared')
  }

  static normalizeLevel(level: string): string {
    if (level === DiagnosticsSettings.LEVEL_DEBUG || level === DiagnosticsSettings.LEVEL_INFO ||
      level === DiagnosticsSettings.LEVEL_WARN || level === DiagnosticsSettings.LEVEL_ERROR) {
      return level
    }
    return DiagnosticsSettings.DEFAULT_MIN_LEVEL
  }
}

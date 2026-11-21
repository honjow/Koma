import { WorkSchedulerExtensionAbility, workScheduler } from '@kit.BackgroundTasksKit'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { AppStrings } from '../i18n/AppStrings'
import { executeBackgroundMaintenance } from '../model/BackgroundMaintenanceWorker'
import { bootstrapSourceRuntimeAppRegistry, appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { prepareSourceConfigurationDatabases } from '../sourceRuntime/SourceConfigurationDatabases'
import { configureSourceRuntimeHttpTransport } from '../sourceRuntime/SourceRuntimeHttpTransport'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'

export default class KomaMaintenanceAbility extends WorkSchedulerExtensionAbility {
  private cancelled: Map<number, boolean> = new Map()

  onWorkStart(work: workScheduler.WorkInfo): void {
    DiagnosticLogger.info('maintenance', 'work_started', 'work_id=' + work.workId)
    this.cancelled.set(work.workId, false)
    // Shared adapters require file/resource Context services, never fabricated UIAbility operations.
    const context = this.context
    AppStrings.init(context)
    configureSourceRuntimeHttpTransport()
    void prepareSourceConfigurationDatabases(context, false).then((): Promise<void> => {
      bootstrapSourceRuntimeAppRegistry(context)
      appSourceWebSessionStore.configure(context, appSourceRuntimeRegistry)
      return executeBackgroundMaintenance(context, work.workId, appSourceRuntimeRegistry,
        (): boolean => this.cancelled.get(work.workId) === true)
    })
      .catch((error: Error): void => { DiagnosticLogger.exception('maintenance', 'work_failed', error) })
      .finally(() => {
        // Native stopWork parses the complete WorkInfo, including its conditions and WantParams.
        // These jobs carry no custom parameters; undefined is rejected by this device's parser.
        work.parameters = {}
        try {
          workScheduler.stopWork(work, false)
          DiagnosticLogger.info('maintenance', 'work_stopped', 'work_id=' + work.workId)
        }
        catch (error) { DiagnosticLogger.exception('maintenance', 'work_stop_failed', error as Error) }
        this.cancelled.delete(work.workId)
      })
  }

  onWorkStop(work: workScheduler.WorkInfo): void { this.cancelled.set(work.workId, true) }
}

import { AbilityConstant, common, Want, wantConstant } from '@kit.AbilityKit'
import { commonType, distributedDataObject } from '@kit.ArkData'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { AppStorageV2 } from '@kit.ArkUI'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'
import { AppStrings } from '../i18n/AppStrings'
import { komaToastOptions } from '../theme/KomaPopupOptions'
import { connectContinuationState } from '../state/ContinuationState'
import { canShareInstalledSourcePackage, prepareInstalledSourcePackageShare } from '../sourceRuntime/SourcePackageShare'
import { getInstalledSourcePackage } from '../sourceRuntime/SourceRuntimeAppRegistry'
import {
  CONTINUATION_SCHEMA_VERSION,
  CONTINUATION_SESSION_ID_PARAM,
  ReaderContinuationPayload,
  decodeReaderContinuationPayload,
  encodeReaderContinuationPayload,
  isContinuationTargetVersionCompatible,
} from './ReaderContinuationPayload'

const CONTINUATION_FILE_PREFIX: string = 'koma-continue-'
const CONTINUATION_FILE_STALE_MS: number = 10 * 60 * 1000

class ContinuationTransferObject {
  payloadJson: string | undefined
  sourcePackage: commonType.Asset | undefined

  constructor(payloadJson: string | undefined, sourcePackage: commonType.Asset | undefined) {
    this.payloadJson = payloadJson
    this.sourcePackage = sourcePackage
  }
}

export interface ReaderContinuationSnapshot {
  sourceId: string
  sourceName: string
  mangaId: string
  mangaUrl?: string
  comicId: string
  title: string
  coverUri?: string
  readingFormat?: 'manga' | 'webtoon'
  chapterId: string
  chapterTitle?: string
  pageIndex: number
  totalPages: number
  requiresPrivacyAuth: boolean
  privateCategoryId?: string
}

export interface RestoredContinuationTask {
  id: number
  payload: ReaderContinuationPayload
  sourcePackageUri?: string
  sourcePackagePath?: string
}

@ObservedV2
export class ReaderContinuationRuntimeState {
  @Trace pendingTaskId: number = 0
  @Trace continuedAway: boolean = false
}

export function connectReaderContinuationRuntimeState(): ReaderContinuationRuntimeState {
  return AppStorageV2.connect(ReaderContinuationRuntimeState, 'koma:continuationRuntime',
    () => new ReaderContinuationRuntimeState())!
}

export class ReaderContinuationService {
  private context?: common.UIAbilityContext
  private activeSnapshot?: ReaderContinuationSnapshot
  private currentContinueActive?: boolean
  private missionStateRequest: number = 0
  private sourceTransferPending: boolean = false
  private sourceDistributedObject?: distributedDataObject.DataObject
  private targetDistributedObject?: distributedDataObject.DataObject
  private pendingRestore?: RestoredContinuationTask
  private nextRestoreId: number = 1
  private onContinuedAwayHandler?: () => void
  private restoreGateOpen: boolean = true

  attachContext(context: common.UIAbilityContext): void {
    if (this.context !== context) this.currentContinueActive = undefined
    this.context = context
  }

  attachSourceHandlers(onContinuedAway?: () => void): void {
    this.onContinuedAwayHandler = onContinuedAway
  }

  publishActiveReading(snapshot: ReaderContinuationSnapshot | undefined): void {
    this.activeSnapshot = snapshot
    this.syncMissionContinueState()
  }

  syncMissionContinueState(): void {
    const context = this.context
    if (context === undefined) return
    const runtime = connectReaderContinuationRuntimeState()
    const enabled = connectContinuationState().enabled && this.activeSnapshot !== undefined && !runtime.continuedAway
    if (this.currentContinueActive === enabled) return
    this.currentContinueActive = enabled
    const request = ++this.missionStateRequest
    const nextState = enabled ? AbilityConstant.ContinueState.ACTIVE : AbilityConstant.ContinueState.INACTIVE
    try {
      context.setMissionContinueState(nextState, (err: BusinessError): void => {
        if (err && err.code !== 0) {
          if (this.context === context && this.missionStateRequest === request) this.currentContinueActive = undefined
          DiagnosticLogger.warn('continuation', 'set_state_failed', 'code=' + err.code + ' msg=' + err.message)
        }
      })
    } catch (error) {
      this.currentContinueActive = undefined
      DiagnosticLogger.warn('continuation', 'set_state_exception', (error as Error).message)
    }
  }

  setContinuedAway(away: boolean): void {
    const runtime = connectReaderContinuationRuntimeState()
    if (runtime.continuedAway !== away) {
      runtime.continuedAway = away
    }
    this.syncMissionContinueState()
  }

  setRestoreGateOpen(open: boolean): void {
    this.restoreGateOpen = open
    if (open && this.pendingRestore !== undefined) {
      connectReaderContinuationRuntimeState().pendingTaskId = this.pendingRestore.id
    }
  }

  consumePendingRestore(): RestoredContinuationTask | undefined {
    if (!this.restoreGateOpen) return undefined
    const task = this.pendingRestore
    this.pendingRestore = undefined
    return task
  }

  isCurrentRestore(id: number): boolean {
    return id === this.nextRestoreId
  }

  private isContinuationPackagePath(path: string): boolean {
    const directory = this.context?.distributedFilesDir
    return directory !== undefined && directory.length > 0 &&
      path.startsWith(directory + '/') &&
      /^koma-continue-[0-9a-f-]+\.koma$/.test(path.slice(directory.length + 1))
  }

  cleanupDistributedTempFile(path: string | undefined): void {
    if (path === undefined || !this.isContinuationPackagePath(path)) return
    try {
      fileIo.unlinkSync(path)
    } catch (_error) {
    }
  }

  private cleanupStaleSourceFiles(distributedDir: string): void {
    try {
      const now = Date.now()
      const entries = fileIo.listFileSync(distributedDir)
      for (const name of entries) {
        if (!name.startsWith(CONTINUATION_FILE_PREFIX) || !name.endsWith('.koma')) continue
        const fullPath = distributedDir + '/' + name
        try {
          const stat = fileIo.statSync(fullPath)
          if (now - stat.mtime * 1000 > CONTINUATION_FILE_STALE_MS) {
            fileIo.unlinkSync(fullPath)
          }
        } catch (_err) {
        }
      }
    } catch (_error) {
    }
  }

  private showMismatchToast(context: common.UIAbilityContext): void {
    try {
      context.windowStage.getMainWindowSync().getUIContext().getPromptAction()
        .showToast(komaToastOptions({ message: AppStrings.get('continuation_version_mismatch') }))
    } catch (_error) {
    }
  }

  private async stageSourcePackageForContinuation(
    context: common.UIAbilityContext,
    sourceId: string,
  ): Promise<commonType.Asset | undefined> {
    if (!canShareInstalledSourcePackage(sourceId)) {
      DiagnosticLogger.info('continuation', 'stage_source_package_skipped', 'reason=unshareable source=' + sourceId)
      return undefined
    }
    const distributedDir = context.distributedFilesDir
    if (distributedDir === undefined || distributedDir.length === 0) return undefined
    this.cleanupStaleSourceFiles(distributedDir)
    let sharePath: string | undefined
    let targetPath: string | undefined
    try {
      const share = await prepareInstalledSourcePackageShare(context, sourceId)
      const sourcePath = new fileUri.FileUri(share.uri).path
      sharePath = sourcePath
      const targetName = CONTINUATION_FILE_PREFIX + util.generateRandomUUID() + '.koma'
      targetPath = distributedDir + '/' + targetName
      await fileIo.copyFile(sourcePath, targetPath)
      const stat = await fileIo.stat(targetPath)
      return {
        name: targetName,
        uri: fileUri.getUriFromPath(targetPath),
        path: targetPath,
        createTime: stat.ctime.toString(),
        modifyTime: stat.mtime.toString(),
        size: stat.size.toString(),
      }
    } catch (error) {
      this.cleanupDistributedTempFile(targetPath)
      DiagnosticLogger.warn('continuation', 'stage_source_package_failed', (error as Error).message)
      return undefined
    } finally {
      if (sharePath !== undefined) {
        try {
          fileIo.unlinkSync(sharePath)
        } catch (_err) {
        }
        const slash = sharePath.lastIndexOf('/')
        if (slash > 0) {
          try {
            fileIo.rmdirSync(sharePath.slice(0, slash))
          } catch (_err) {
          }
        }
      }
    }
  }

  async handleOnContinue(
    context: common.UIAbilityContext,
    wantParam: Record<string, Object>,
  ): Promise<AbilityConstant.OnContinueResult> {
    this.attachContext(context)
    const runtime = connectReaderContinuationRuntimeState()
    const snapshot = this.activeSnapshot
    if (!connectContinuationState().enabled || snapshot === undefined || runtime.continuedAway || this.sourceTransferPending) {
      return AbilityConstant.OnContinueResult.REJECT
    }
    if (!isContinuationTargetVersionCompatible(wantParam['version'])) {
      this.showMismatchToast(context)
      return AbilityConstant.OnContinueResult.MISMATCH
    }
    const targetDevice = typeof wantParam['targetDevice'] === 'string' ? wantParam['targetDevice'] as string : ''
    if (targetDevice.length === 0) return AbilityConstant.OnContinueResult.REJECT
    this.sourceTransferPending = true
    const installedSource = getInstalledSourcePackage(snapshot.sourceId)
    const payload: ReaderContinuationPayload = {
      schemaVersion: CONTINUATION_SCHEMA_VERSION,
      sourceId: snapshot.sourceId,
      sourceName: snapshot.sourceName,
      mangaId: snapshot.mangaId,
      comicId: snapshot.comicId,
      title: snapshot.title,
      chapterId: snapshot.chapterId,
      pageIndex: snapshot.pageIndex,
      totalPages: snapshot.totalPages,
      requiresPrivacyAuth: snapshot.requiresPrivacyAuth,
      timestamp: Date.now(),
    }
    if (snapshot.mangaUrl !== undefined && snapshot.mangaUrl.length > 0) payload.mangaUrl = snapshot.mangaUrl
    if (snapshot.coverUri !== undefined && snapshot.coverUri.length > 0) payload.coverUri = snapshot.coverUri
    if (snapshot.readingFormat !== undefined) payload.readingFormat = snapshot.readingFormat
    if (snapshot.chapterTitle !== undefined && snapshot.chapterTitle.length > 0) payload.chapterTitle = snapshot.chapterTitle
    if (snapshot.privateCategoryId !== undefined && snapshot.privateCategoryId.length > 0) {
      payload.privateCategoryId = snapshot.privateCategoryId
    }
    if (installedSource?.version !== undefined && installedSource.version.length > 0) {
      payload.sourceVersion = installedSource.version
    }

    let stagedAsset: commonType.Asset | undefined
    let agreed = false
    const eligible = (): ReaderContinuationSnapshot | undefined => {
      const current = this.activeSnapshot
      return this.context === context && connectContinuationState().enabled && !runtime.continuedAway &&
        current?.comicId === snapshot.comicId && current.chapterId === snapshot.chapterId &&
        current.sourceId === snapshot.sourceId && current.mangaId === snapshot.mangaId &&
        current.requiresPrivacyAuth === snapshot.requiresPrivacyAuth &&
        current.privateCategoryId === snapshot.privateCategoryId ? current : undefined
    }
    try {
      this.releaseSourceDistributedObject()
      const sessionId = distributedDataObject.genSessionId()
      stagedAsset = await this.stageSourcePackageForContinuation(context, snapshot.sourceId)
      const current = eligible()
      if (current === undefined) return AbilityConstant.OnContinueResult.REJECT
      payload.pageIndex = current.pageIndex
      payload.totalPages = current.totalPages
      payload.timestamp = Date.now()
      const transfer = new ContinuationTransferObject(encodeReaderContinuationPayload(payload), stagedAsset)
      const dataObject = distributedDataObject.create(context, transfer)
      this.sourceDistributedObject = dataObject
      await dataObject.setSessionId(sessionId)
      await dataObject.save(targetDevice)
      if (eligible() === undefined) return AbilityConstant.OnContinueResult.REJECT
      wantParam[CONTINUATION_SESSION_ID_PARAM] = sessionId
      wantParam[wantConstant.Params.SUPPORT_CONTINUE_PAGE_STACK_KEY] = false
      wantParam[wantConstant.Params.SUPPORT_CONTINUE_SOURCE_EXIT_KEY] = false
      this.setContinuedAway(true)
      agreed = true
      try {
        this.onContinuedAwayHandler?.()
      } catch (error) {
        DiagnosticLogger.exception('continuation', 'source_continue_notice_failed', error as Error)
        this.setContinuedAway(false)
      }
      DiagnosticLogger.info('continuation', 'source_continue_agreed',
        `source=${payload.sourceId} page=${payload.pageIndex} hasAsset=${stagedAsset !== undefined}`)
      return AbilityConstant.OnContinueResult.AGREE
    } catch (error) {
      DiagnosticLogger.exception('continuation', 'source_continue_failed', error as Error)
      return AbilityConstant.OnContinueResult.REJECT
    } finally {
      this.sourceTransferPending = false
      if (!agreed) {
        this.releaseSourceDistributedObject()
        this.cleanupDistributedTempFile(stagedAsset?.path)
      }
    }
  }

  beginTargetRestore(context: common.UIAbilityContext, want: Want): void {
    this.attachContext(context)
    this.releaseTargetDistributedObject()
    this.cleanupDistributedTempFile(this.pendingRestore?.sourcePackagePath)
    this.pendingRestore = undefined
    const restoreToken = ++this.nextRestoreId
    const rawSessionId = want.parameters?.[CONTINUATION_SESSION_ID_PARAM]
    const sessionId = typeof rawSessionId === 'string' ? rawSessionId.trim() : ''
    if (sessionId.length === 0) {
      DiagnosticLogger.warn('continuation', 'target_missing_session', '')
      return
    }
    // The receiver must leave every property undefined until the distributed
    // object is activated, otherwise its initial values can overwrite the sender.
    const blank = new ContinuationTransferObject(undefined, undefined)
    try {
      const dataObject = distributedDataObject.create(context, blank)
      this.targetDistributedObject = dataObject
      let handled = false
      dataObject.on('status', (_sid: string, _networkId: string, status: string): void => {
        if (handled || status !== 'restored' || this.targetDistributedObject !== dataObject) return
        handled = true
        const payload = decodeReaderContinuationPayload(dataObject['payloadJson'] as Object | undefined)
        const restoredAsset = dataObject['sourcePackage'] as commonType.Asset | undefined
        const assetPath = restoredAsset && typeof restoredAsset.path === 'string' &&
          this.isContinuationPackagePath(restoredAsset.path) ? restoredAsset.path : undefined
        const assetUri = assetPath !== undefined ? fileUri.getUriFromPath(assetPath) : undefined
        this.releaseTargetDistributedObject()
        if (payload === undefined) {
          this.cleanupDistributedTempFile(assetPath)
          DiagnosticLogger.warn('continuation', 'target_payload_invalid', '')
          return
        }
        this.pendingRestore = {
          id: restoreToken,
          payload,
          sourcePackageUri: assetUri,
          sourcePackagePath: assetPath,
        }
        if (this.restoreGateOpen) this.setRestoreGateOpen(true)
        DiagnosticLogger.info('continuation', 'target_restored',
          `source=${payload.sourceId} page=${payload.pageIndex} hasAsset=${assetUri !== undefined} gateOpen=${this.restoreGateOpen}`)
      })
      void dataObject.setSessionId(sessionId).catch((error: BusinessError): void => {
        if (this.targetDistributedObject === dataObject) this.releaseTargetDistributedObject()
        DiagnosticLogger.warn('continuation', 'target_set_session_failed',
          'code=' + error.code + ' msg=' + error.message)
      })
    } catch (error) {
      this.releaseTargetDistributedObject()
      DiagnosticLogger.exception('continuation', 'target_restore_failed', error as Error)
    }
  }

  private releaseSourceDistributedObject(): void {
    const existing = this.sourceDistributedObject
    this.sourceDistributedObject = undefined
    if (existing === undefined) return
    void existing.setSessionId('').catch((): void => {})
  }

  private releaseTargetDistributedObject(): void {
    const existing = this.targetDistributedObject
    this.targetDistributedObject = undefined
    if (existing === undefined) return
    try {
      existing.off('status')
    } catch (_error) {
    }
    void existing.setSessionId('').catch((): void => {})
  }

  dispose(): void {
    this.releaseSourceDistributedObject()
    this.releaseTargetDistributedObject()
    this.cleanupDistributedTempFile(this.pendingRestore?.sourcePackagePath)
    this.pendingRestore = undefined
    this.nextRestoreId += 1
    this.activeSnapshot = undefined
    this.context = undefined
    this.currentContinueActive = undefined
    this.onContinuedAwayHandler = undefined
    connectReaderContinuationRuntimeState().continuedAway = false
  }
}

export const appReaderContinuation: ReaderContinuationService = new ReaderContinuationService()

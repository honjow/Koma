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
  sourcePackage: commonType.Asset

  constructor(payloadJson: string | undefined, sourcePackage: commonType.Asset) {
    this.payloadJson = payloadJson
    this.sourcePackage = sourcePackage
  }
}

function emptyAsset(): commonType.Asset {
  return {
    name: '',
    uri: '',
    path: '',
    createTime: '',
    modifyTime: '',
    size: '',
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
  private sourceDistributedObject?: distributedDataObject.DataObject
  private targetDistributedObject?: distributedDataObject.DataObject
  private pendingRestore?: RestoredContinuationTask
  private nextRestoreId: number = 1
  private onContinuedAwayHandler?: () => void
  private activeRestoreWaiters: Set<() => void> = new Set()
  private restoreGateOpen: boolean = true

  attachContext(context: common.UIAbilityContext): void {
    this.context = context
  }

  attachSourceHandlers(onContinuedAway: () => void): void {
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
    const nextState = enabled ? AbilityConstant.ContinueState.ACTIVE : AbilityConstant.ContinueState.INACTIVE
    try {
      context.setMissionContinueState(nextState, (err: BusinessError): void => {
        if (err && err.code !== 0) {
          DiagnosticLogger.warn('continuation', 'set_state_failed', 'code=' + err.code + ' msg=' + err.message)
        }
      })
    } catch (error) {
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
      const runtime = connectReaderContinuationRuntimeState()
      runtime.continuedAway = false
      runtime.pendingTaskId = this.pendingRestore.id
    }
  }

  consumePendingRestore(): RestoredContinuationTask | undefined {
    const task = this.pendingRestore
    this.pendingRestore = undefined
    return task
  }

  cleanupDistributedTempFile(path: string | undefined): void {
    if (path === undefined || path.length === 0) return
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
    try {
      const share = await prepareInstalledSourcePackageShare(context, sourceId)
      const sourcePath = new fileUri.FileUri(share.uri).path
      sharePath = sourcePath
      const targetName = CONTINUATION_FILE_PREFIX + util.generateRandomUUID() + '.koma'
      const targetPath = distributedDir + '/' + targetName
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
    if (!connectContinuationState().enabled || snapshot === undefined || runtime.continuedAway) {
      return AbilityConstant.OnContinueResult.REJECT
    }
    if (!isContinuationTargetVersionCompatible(wantParam['version'])) {
      this.showMismatchToast(context)
      return AbilityConstant.OnContinueResult.MISMATCH
    }
    const targetDevice = typeof wantParam['targetDevice'] === 'string' ? wantParam['targetDevice'] as string : ''
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

    try {
      this.releaseSourceDistributedObject()
      const sessionId = distributedDataObject.genSessionId()
      const stagedAsset = await this.stageSourcePackageForContinuation(context, snapshot.sourceId)
      const transfer = new ContinuationTransferObject(encodeReaderContinuationPayload(payload), stagedAsset ?? emptyAsset())
      const dataObject = distributedDataObject.create(context, transfer)
      this.sourceDistributedObject = dataObject
      await dataObject.setSessionId(sessionId)
      await dataObject.save(targetDevice)
      wantParam[CONTINUATION_SESSION_ID_PARAM] = sessionId
      wantParam[wantConstant.Params.SUPPORT_CONTINUE_PAGE_STACK_KEY] = false
      wantParam[wantConstant.Params.SUPPORT_CONTINUE_SOURCE_EXIT_KEY] = false
      this.setContinuedAway(true)
      this.onContinuedAwayHandler?.()
      DiagnosticLogger.info('continuation', 'source_continue_agreed',
        `source=${snapshot.sourceId} page=${snapshot.pageIndex} hasAsset=${stagedAsset !== undefined}`)
      return AbilityConstant.OnContinueResult.AGREE
    } catch (error) {
      this.releaseSourceDistributedObject()
      DiagnosticLogger.exception('continuation', 'source_continue_failed', error as Error)
      return AbilityConstant.OnContinueResult.REJECT
    }
  }

  beginTargetRestore(context: common.UIAbilityContext, want: Want): void {
    this.attachContext(context)
    const rawSessionId = want.parameters?.[CONTINUATION_SESSION_ID_PARAM]
    const sessionId = typeof rawSessionId === 'string' ? rawSessionId.trim() : ''
    if (sessionId.length === 0) {
      DiagnosticLogger.warn('continuation', 'target_missing_session', '')
      return
    }
    this.releaseTargetDistributedObject()
    const restoreToken = ++this.nextRestoreId
    const blank = new ContinuationTransferObject(undefined, emptyAsset())
    try {
      const dataObject = distributedDataObject.create(context, blank)
      this.targetDistributedObject = dataObject
      let handled = false
      dataObject.on('status', (_sid: string, _networkId: string, status: string): void => {
        if (handled || status !== 'restored' || this.targetDistributedObject !== dataObject) return
        handled = true
        const payload = decodeReaderContinuationPayload(dataObject['payloadJson'] as Object | undefined)
        const restoredAsset = dataObject['sourcePackage'] as commonType.Asset | undefined
        const assetUri = restoredAsset !== undefined && typeof restoredAsset.uri === 'string' &&
          restoredAsset.uri.length > 0 ? restoredAsset.uri : undefined
        const assetPath = restoredAsset !== undefined && typeof restoredAsset.path === 'string' &&
          restoredAsset.path.length > 0 ? restoredAsset.path :
          (assetUri !== undefined ? new fileUri.FileUri(assetUri).path : undefined)
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
        if (this.restoreGateOpen) {
          const runtime = connectReaderContinuationRuntimeState()
          runtime.continuedAway = false
          runtime.pendingTaskId = restoreToken
        }
        DiagnosticLogger.info('continuation', 'target_restored',
          `source=${payload.sourceId} page=${payload.pageIndex} hasAsset=${assetUri !== undefined} gateOpen=${this.restoreGateOpen}`)
      })
      void dataObject.setSessionId(sessionId).catch((error: BusinessError): void => {
        DiagnosticLogger.warn('continuation', 'target_set_session_failed',
          'code=' + error.code + ' msg=' + error.message)
      })
    } catch (error) {
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
    this.activeRestoreWaiters.clear()
  }
}

export const appReaderContinuation: ReaderContinuationService = new ReaderContinuationService()

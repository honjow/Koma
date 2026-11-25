import { abilityAccessCtrl, common } from '@kit.AbilityKit'
import { AppStorageV2, window } from '@kit.ArkUI'
import { commonEventManager, systemDateTime } from '@kit.BasicServicesKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { userAuth } from '@kit.UserAuthenticationKit'
import { AppStrings } from '../i18n/AppStrings'
import { DiagnosticLogger } from '../diagnostics/DiagnosticLogger'

const BACKGROUND_GRACE_MS = 30000

export enum LibraryPrivacyAuthResult {
  SUCCESS,
  CANCELED,
  UNAVAILABLE,
  FAILED,
}

export function libraryPrivacyAuthMessage(result: LibraryPrivacyAuthResult): string {
  if (result === LibraryPrivacyAuthResult.UNAVAILABLE) return AppStrings.get('library_privacy_auth_unavailable')
  if (result === LibraryPrivacyAuthResult.FAILED) return AppStrings.get('library_privacy_auth_failed')
  return ''
}

function authTypeAvailable(type: userAuth.UserAuthType, level: userAuth.AuthTrustLevel): boolean {
  try {
    userAuth.getAvailableStatus(type, level)
    return true
  } catch (_) {
    return false
  }
}

@ObservedV2
export class LibraryPrivacyState {
  @Trace categoryId: string = ''
  @Trace unlocked: boolean = false
  @Trace authenticating: boolean = false
  @Trace presenting: boolean = true
  @Trace foregroundReauthRevision: number = 0
  @Trace continuationProtected: boolean = false
  private generation: number = 0
  private backgroundSince: number = -1
  private windowPaused: boolean = false
  private windowStage?: window.WindowStage
  private mainWindow?: window.Window
  private lockSubscription?: commonEventManager.CommonEventSubscriber
  private windowTask: Promise<boolean> = Promise.resolve(true)
  private authInstance?: userAuth.UserAuthInstance
  private readonly onStageEvent = (event: window.WindowStageEventType): void => {
    if (event === window.WindowStageEventType.PAUSED || event === window.WindowStageEventType.HIDDEN) {
      this.windowPaused = true
      this.presenting = false
    } else if (event === window.WindowStageEventType.ACTIVE || event === window.WindowStageEventType.RESUMED) {
      this.windowPaused = false
      this.presenting = this.backgroundSince < 0
    }
  }

  get visibleCategoryId(): string {
    return this.unlocked && this.presenting ? this.categoryId : ''
  }

  async attach(mainWindow: window.Window, stage: window.WindowStage): Promise<void> {
    this.detach()
    this.mainWindow = mainWindow
    this.windowStage = stage
    try {
      stage.on('windowStageEvent', this.onStageEvent)
      const subscriber = await commonEventManager.createSubscriber({
        events: [commonEventManager.Support.COMMON_EVENT_SCREEN_LOCKED, commonEventManager.Support.COMMON_EVENT_SCREEN_OFF]
      })
      await commonEventManager.subscribeToEvent(subscriber, () => { this.lock() })
      if (this.mainWindow === mainWindow) this.lockSubscription = subscriber
      else commonEventManager.unsubscribe(subscriber)
    } catch (_) {
      DiagnosticLogger.warn('library_privacy', 'screen_lock_subscription_failed', '')
    }
  }

  detach(): void {
    this.leaveCategory()
    try {
      this.windowStage?.off('windowStageEvent', this.onStageEvent)
    } catch (_) {
      // The stage may already have been destroyed.
    }
    this.windowStage = undefined
    this.windowPaused = false
    this.presenting = this.backgroundSince < 0
    this.mainWindow = undefined
    if (this.lockSubscription !== undefined) commonEventManager.unsubscribe(this.lockSubscription)
    this.lockSubscription = undefined
  }

  private protectWindow(enabled: boolean): Promise<boolean> {
    const mainWindow = this.mainWindow
    this.windowTask = this.windowTask.then(async (): Promise<boolean> => {
      if (mainWindow === undefined || this.mainWindow !== mainWindow) return false
      await mainWindow.setWindowPrivacyMode(enabled)
      return true
    }).catch((): boolean => {
      DiagnosticLogger.warn('library_privacy', 'window_privacy_mode_failed', '')
      return false
    })
    return this.windowTask
  }

  onBackground(): void {
    if (this.backgroundSince >= 0) return
    // Redact the previous frame when leaving, before any later foreground redraw.
    // A short background visit can still reuse the local authentication grant.
    this.presenting = false
    this.backgroundSince = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP)
    this.invalidateRequest()
  }

  onForeground(): void {
    const since = this.backgroundSince
    this.backgroundSince = -1
    if (since >= 0 && systemDateTime.getUptime(systemDateTime.TimeType.STARTUP) - since >= BACKGROUND_GRACE_MS) {
      const expiredGrant = this.unlocked
      this.lock()
      // A screen lock or canceled verification may already have ended the grant.
      if (expiredGrant) this.foregroundReauthRevision += 1
    }
    this.presenting = !this.windowPaused
  }

  private invalidateRequest(): void {
    this.generation += 1
    try {
      this.authInstance?.cancel()
    } catch (_) {
      // An authentication result may already be queued. The generation owns it.
    }
  }

  lock(): void {
    this.invalidateRequest()
    this.unlocked = false
    if (this.continuationProtected) {
      this.continuationProtected = false
      if (this.categoryId.length === 0) void this.protectWindow(false)
    }
  }

  leaveCategory(): void {
    this.lock()
    if (this.categoryId.length === 0) return
    this.categoryId = ''
    void this.protectWindow(false)
  }

  async activateContinuationPrivacy(
    context: common.UIAbilityContext,
    isCurrent: () => boolean,
    categoryId?: string,
    hasLocalCategory: boolean = false,
  ): Promise<LibraryPrivacyAuthResult> {
    if (this.backgroundSince >= 0) return LibraryPrivacyAuthResult.CANCELED
    const generation = this.generation
    const result = await this.verify(context)
    if (result !== LibraryPrivacyAuthResult.SUCCESS) return result
    if (!isCurrent() || this.generation !== generation || this.backgroundSince >= 0) return LibraryPrivacyAuthResult.CANCELED
    const ready = await this.protectWindow(true)
    if (!isCurrent() || this.generation !== generation || this.backgroundSince >= 0) {
      if (this.categoryId.length === 0 && !this.continuationProtected && ready) void this.protectWindow(false)
      return LibraryPrivacyAuthResult.CANCELED
    }
    if (!ready) return LibraryPrivacyAuthResult.UNAVAILABLE
    if (categoryId !== undefined && categoryId.length > 0 && hasLocalCategory) {
      this.categoryId = categoryId
      this.unlocked = true
    } else {
      this.continuationProtected = true
    }
    return LibraryPrivacyAuthResult.SUCCESS
  }

  releaseContinuationPrivacy(): void {
    if (!this.continuationProtected) return
    this.continuationProtected = false
    if (this.categoryId.length === 0) void this.protectWindow(false)
  }

  async openCategory(context: common.UIAbilityContext, id: string, isCurrent: () => boolean): Promise<LibraryPrivacyAuthResult> {
    if (this.visibleCategoryId === id) return LibraryPrivacyAuthResult.SUCCESS
    const generation = this.generation
    const result = await this.verify(context)
    if (result !== LibraryPrivacyAuthResult.SUCCESS) return result
    if (!isCurrent() || this.generation !== generation || this.backgroundSince >= 0) return LibraryPrivacyAuthResult.CANCELED
    // Enable system snapshot protection before private content can enter the window.
    const ready = this.lockSubscription !== undefined && await this.protectWindow(true)
    if (this.generation !== generation || !isCurrent() || this.backgroundSince >= 0) {
      if (this.categoryId.length === 0 && ready) void this.protectWindow(false)
      return LibraryPrivacyAuthResult.CANCELED
    }
    if (!ready) return LibraryPrivacyAuthResult.UNAVAILABLE
    this.categoryId = id
    this.unlocked = true
    return LibraryPrivacyAuthResult.SUCCESS
  }

  async verify(context: common.UIAbilityContext): Promise<LibraryPrivacyAuthResult> {
    if (this.authenticating || this.backgroundSince >= 0) return LibraryPrivacyAuthResult.CANCELED
    this.authenticating = true
    const generation = this.generation
    try {
      const permission = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context,
        ['ohos.permission.ACCESS_BIOMETRIC'])
      if (this.generation !== generation) return LibraryPrivacyAuthResult.CANCELED
      if (permission.authResults[0] !== 0) return LibraryPrivacyAuthResult.UNAVAILABLE
      const strong = userAuth.AuthTrustLevel.ATL3
      const biometricTypes = [userAuth.UserAuthType.FINGERPRINT, userAuth.UserAuthType.FACE]
      const capable = biometricTypes.filter((type: userAuth.UserAuthType): boolean => authTypeAvailable(type, strong))
      const pin = authTypeAvailable(userAuth.UserAuthType.PIN, strong)
      let level = strong
      let separatePin = false
      if (capable.length === 0) {
        level = userAuth.AuthTrustLevel.ATL1
        biometricTypes.forEach((type: userAuth.UserAuthType): void => {
          if (authTypeAvailable(type, level)) capable.push(type)
        })
        separatePin = capable.length > 0 && pin
      }
      if (pin && !separatePin) {
        level = strong
        capable.push(userAuth.UserAuthType.PIN)
      }
      if (capable.length === 0) return LibraryPrivacyAuthResult.UNAVAILABLE
      let code = await this.startAuthentication(capable, level, separatePin)
      if (separatePin && code === userAuth.UserAuthResultCode.CANCELED_FROM_WIDGET && this.generation === generation) {
        code = await this.startAuthentication([userAuth.UserAuthType.PIN], strong, false)
      }
      if (this.generation !== generation || code === userAuth.UserAuthResultCode.CANCELED) return LibraryPrivacyAuthResult.CANCELED
      return code === userAuth.UserAuthResultCode.SUCCESS ? LibraryPrivacyAuthResult.SUCCESS : LibraryPrivacyAuthResult.FAILED
    } catch (_) {
      return LibraryPrivacyAuthResult.UNAVAILABLE
    } finally {
      this.authenticating = false
    }
  }

  private startAuthentication(types: userAuth.UserAuthType[], level: userAuth.AuthTrustLevel, separatePin: boolean): Promise<number> {
    const widget: userAuth.WidgetParam = { title: AppStrings.get('library_privacy_auth_title') }
    if (separatePin) widget.navigationButtonText = AppStrings.get('library_privacy_use_device_password')
    const instance = userAuth.getUserAuthInstance({
      challenge: cryptoFramework.createRandom().generateRandomSync(16).data,
      authType: types,
      authTrustLevel: level,
      skipLockedBiometricAuth: types.includes(userAuth.UserAuthType.PIN),
    }, widget)
    return new Promise<number>((resolve, reject): void => {
      const callback: userAuth.IAuthCallback = {
        onResult: (result: userAuth.UserAuthResult): void => {
          instance.off('result', callback)
          if (this.authInstance === instance) this.authInstance = undefined
          resolve(result.result)
        }
      }
      try {
        instance.on('result', callback)
        this.authInstance = instance
        instance.start()
      } catch (error) {
        this.authInstance = undefined
        try { instance.off('result', callback) } catch (_) {}
        reject(error as Error)
      }
    })
  }
}

export function connectLibraryPrivacyState(): LibraryPrivacyState {
  return AppStorageV2.connect(LibraryPrivacyState, 'v2:libraryPrivacy', () => new LibraryPrivacyState())!
}

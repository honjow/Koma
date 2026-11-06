import { AppStrings } from '../i18n/AppStrings'
import { SourceAuthenticationRequest, SourceAuthenticationService } from '../sourceRuntime/SourceAuthenticationService'
import { appSourceWebSessionStore } from '../sourceRuntime/SourceWebSessionStore'
import { appSourceRuntimeRegistry } from '../sourceRuntime/SourceRuntimeAppRegistry'
import { sourceAuthenticationOrigin } from '../sourceRuntime/SourceAuthenticationDescriptor'
import { MangaWebRouteParam } from '../common/RouterHelper'
import { SourceRuntimeError } from '../model/SourceRuntimeError'
import { komaSheetOptions, komaToastOptions } from '../theme/KomaPopupOptions'
import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { SourceWebSessionSheet } from './SourceWebSessionSheet'
import { KomaFormTextField } from './ui/KomaFormTextField'
import { KomaActionButton } from './ui/KomaActionButton'

/** One route-owned presenter. Only an explicit Host action supplies request; no auto-login or password settings. */
@ComponentV2
export struct SourceAuthenticationSheetHost {
  @Param request: SourceAuthenticationRequest | null = null
  @Param active: boolean = false
  @Param inSettings: boolean = false
  @Event onPresentedChanged: (shown: boolean) => void = (_shown: boolean) => {}
  @Event onAuthenticationChanged: () => void = () => {}
  @Local private shown: boolean = false
  @Local private title: string = ''
  @Local private usernameLabel: string = ''
  @Local private passwordLabel: string = ''
  @Local private loginOrigin: string = ''
  @Local private credentialStorage: string = ''
  @Local private username: string = ''
  @Local private password: string = ''
  @Local private errorText: string = ''
  @Local private busy: boolean = false
  @Local private ready: boolean = false
  @Local private authenticated: boolean = false
  @Local private replacing: boolean = false
  @Local private web: boolean = false
  @Local private webParams: MangaWebRouteParam = { url: '', title: '' }
  private service: SourceAuthenticationService | null = null
  private presented: SourceAuthenticationRequest | null = null
  private handled: SourceAuthenticationRequest | null = null
  private mounted: boolean = false
  private closing: boolean = false
  private opening: boolean = false
  private completed: boolean = false
  private epoch: number = 0

  aboutToAppear(): void { this.mounted = true; this.requestChanged() }
  aboutToDisappear(): void { this.mounted = false; this.close() }

  @Monitor('request', 'active')
  private requestChanged(): void {
    if (!this.mounted || !this.active || this.request === null) { this.close(); return }
    if (this.request === this.handled) return
    if (this.shown || this.closing || this.opening) {
      this.close()
      if (!this.closing) this.open()
      return
    }
    this.open()
  }

  private current(epoch: number): boolean {
    try { return this.mounted && this.active && this.epoch === epoch && this.presented !== null &&
      this.presented === this.request && this.presented.current() && this.service?.isCurrent() === true }
    catch (_error) { return false }
  }

  private open(): void {
    const request = this.request
    if (!this.mounted || !this.active || request === null || !request.current()) return
    this.presented = request; this.handled = request; this.completed = false
    this.username = ''; this.password = ''; this.errorText = ''; this.authenticated = false; this.replacing = false
    this.ready = false
    const epoch = ++this.epoch
    try {
      this.service = new SourceAuthenticationService(request.sourceId,
        (): boolean => this.mounted && this.active && this.epoch === epoch && request === this.request && request.current())
      const descriptor = this.service.descriptor
      this.title = this.service.title
      this.usernameLabel = descriptor.usernameLabel ?? AppStrings.get('common_username')
      this.passwordLabel = descriptor.passwordLabel ?? AppStrings.get('common_password')
      this.loginOrigin = sourceAuthenticationOrigin(descriptor.loginUrl)
      this.credentialStorage = descriptor.credentialStorage ?? ''
      this.web = descriptor.kind === 'web'
      if (this.web) {
        this.opening = true
        void this.openWeb(epoch)
        return
      }
      this.shown = true; this.onPresentedChanged(true)
      if (!this.web) void this.status(epoch)
    } catch (_error) {
      request.cancel(); this.service?.cancel(); this.service = null
      this.errorText = AppStrings.get('source_login_unavailable')
      this.presented = null
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: this.errorText }))
    }
  }

  private async openWeb(epoch: number): Promise<void> {
    try {
      await this.service!.run('get_authentication')
      if (!this.current(epoch)) { if (this.epoch === epoch) this.close(); return }
      const sourceId = this.presented!.sourceId
      const url = this.service!.webLoginUrl
      const status = appSourceWebSessionStore.begin(appSourceRuntimeRegistry, sourceId, url, this.service!.descriptor.userAgent)
      this.webParams = { url, title: this.title, sourceSession: { sourceId, sessionId: status.sessionId } }
      this.opening = false; this.shown = true; this.onPresentedChanged(true)
    } catch (error) {
      if (!this.current(epoch)) { if (this.epoch === epoch) this.close(); return }
      const key = error instanceof Error && error.message === 'source_login_origin_not_allowed'
        ? 'source_login_origin_not_allowed' : 'source_login_unavailable'
      this.getUIContext().getPromptAction().showToast(komaToastOptions({ message: AppStrings.get(key) }))
      this.close()
    }
  }

  private async status(epoch: number): Promise<void> {
    this.busy = true; this.ready = false; this.errorText = ''
    try {
      const authenticated = await this.service!.run('get_authentication')
      if (!this.current(epoch)) { if (this.epoch === epoch) this.close(); return }
      this.authenticated = authenticated; this.ready = true
    } catch (_error) {
      if (this.current(epoch)) this.errorText = AppStrings.get('source_login_unavailable')
      else if (this.epoch === epoch) this.close()
    } finally { if (this.epoch === epoch) this.busy = false }
  }

  private async authenticate(): Promise<void> {
    const epoch = this.epoch
    if (!this.current(epoch)) { this.close(); return }
    if (!this.ready || this.busy) return
    if (this.authenticated && !this.replacing) { this.finish(); return }
    if (this.username.trim().length === 0 || this.password.length === 0) return
    this.busy = true; this.errorText = ''
    try {
      await this.service!.run('authenticate', this.username, this.password)
      if (this.current(epoch)) this.finish(true)
      else if (this.epoch === epoch) this.close()
    } catch (error) {
      if (this.current(epoch)) this.errorText = error instanceof SourceRuntimeError &&
        ['network', 'timeout', 'access', 'rate_limit', 'server'].includes(error.diagnostic.kind)
        ? error.userTextFor(AppStrings.get('source_login_failed')) : AppStrings.get('source_login_failed')
      else if (this.epoch === epoch) this.close()
    } finally { if (this.epoch === epoch) this.busy = false }
  }

  private changeReplacement(replacing: boolean): void {
    if (!this.inSettings || !this.authenticated || !this.ready || this.busy || !this.current(this.epoch)) return
    // authenticate performs the existing atomic replacement; the current login survives cancellation and failure.
    this.username = ''; this.password = ''; this.errorText = ''; this.replacing = replacing
  }

  private async logout(): Promise<void> {
    const epoch = this.epoch
    if (!this.current(epoch) || !this.ready || this.busy) return
    this.busy = true; this.errorText = ''
    try {
      await this.service!.run('logout')
      if (this.current(epoch)) {
        this.authenticated = false; this.username = ''; this.password = ''
        this.onAuthenticationChanged()
      }
      else if (this.epoch === epoch) this.close()
    } catch (_error) {
      if (this.current(epoch)) this.errorText = AppStrings.get('source_login_failed')
      else if (this.epoch === epoch) this.close()
    }
    finally { if (this.epoch === epoch) this.busy = false }
  }

  private finish(changed: boolean = false): void {
    if (!this.current(this.epoch)) return
    if (changed) this.onAuthenticationChanged()
    this.completed = true; this.username = ''; this.password = ''
    if (this.inSettings) this.finishDismissal()
    else { this.closing = true; this.shown = false }
  }

  private close(): void {
    const request = this.presented
    this.opening = false
    this.epoch += 1; this.service?.cancel(); this.username = ''; this.password = ''; this.busy = false
    if (!this.completed) request?.cancel()
    const session = this.webParams.sourceSession
    if (!this.completed && session !== undefined) appSourceWebSessionStore.cancel(session.sourceId, session.sessionId)
    if (this.shown && !this.inSettings) this.closing = true
    this.shown = false
    if (!this.closing) { this.presented = null; this.service = null; this.onPresentedChanged(false) }
  }

  private finishDismissal(): void {
    const request = this.presented
    const complete = this.completed && this.mounted && this.active && request === this.request && request?.current() === true
    this.epoch += 1; this.service?.cancel(); this.service = null; this.presented = null
    this.username = ''; this.password = ''; this.completed = false; this.closing = false; this.shown = false
    this.onPresentedChanged(false)
    // Resolve only after dismissal: Reader has resumed its existing viewport before same-slot reload.
    if (complete) void request!.complete()
    else request?.cancel()
    this.requestChanged()
  }

  @Builder
  private Content() {
    if (this.web) {
      SourceWebSessionSheet({ params: this.webParams, autoRetryOnClearance: false,
        onClose: () => { this.close() }, onCompleted: () => { this.finish(true) } })
    } else {
      KomaModalScaffold({ title: AppStrings.get(this.inSettings ? 'source_account_settings' : 'source_login'), subtitle: this.title,
        onClose: () => { this.close() } }) {
        Column({ space: ThemeConstants.SPACE_MD }) {
          Text(this.authenticated ? AppStrings.get('source_login_connected') : AppStrings.get('source_login_required'))
            .fontSize(ThemeConstants.FONT_SIZE_BODY).fontColor(ThemeConstants.TEXT_SECONDARY)
          Text(AppStrings.format('source_login_destination', this.loginOrigin))
            .fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
          Text(AppStrings.get(this.credentialStorage === 'private' ? 'source_login_storage_private' : 'source_login_storage_memory'))
            .fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
          if (!this.authenticated || this.replacing) {
            KomaFormTextField({ label: this.usernameLabel, value: this.username, isEnabled: this.ready && !this.busy,
              change: (value: string) => { this.username = value } })
            KomaFormTextField({ label: this.passwordLabel, value: this.password, isPassword: true, isEnabled: this.ready && !this.busy,
              change: (value: string) => { this.password = value }, submit: () => { void this.authenticate() } })
          }
          if (this.errorText.length > 0) {
            Text(this.errorText).fontSize(ThemeConstants.FONT_SIZE_META).fontColor(ThemeConstants.TEXT_SECONDARY)
          }
          KomaActionButton({ label: AppStrings.get(this.replacing ? 'source_account_switch' :
            this.authenticated ? (this.inSettings ? 'common_close' : 'source_login_continue') : 'source_login'), kind: 'primary',
            fullWidth: true, busy: this.busy, isEnabled: this.ready && !this.busy &&
              ((this.authenticated && !this.replacing) || (this.username.trim().length > 0 && this.password.length > 0)),
            action: () => { void this.authenticate() } })
          if (this.replacing) {
            KomaActionButton({ label: AppStrings.get('common_cancel'), kind: 'ghost', fullWidth: true,
              isEnabled: !this.busy, action: () => { this.changeReplacement(false) } })
          } else if (this.authenticated) {
            if (this.inSettings) {
              KomaActionButton({ label: AppStrings.get('source_account_switch'), kind: 'ghost', fullWidth: true,
                isEnabled: !this.busy, action: () => { this.changeReplacement(true) } })
            }
            KomaActionButton({ label: AppStrings.get('source_logout'), kind: 'ghost', fullWidth: true,
              isEnabled: !this.busy, action: () => { void this.logout() } })
          } else if (!this.ready && !this.busy) {
            KomaActionButton({ label: AppStrings.get('common_retry'), kind: 'ghost', fullWidth: true,
              action: () => { void this.status(this.epoch) } })
          }
        }.width('100%').padding({ top: ThemeConstants.SPACE_LG, bottom: ThemeConstants.SPACE_LG })
      }
    }
  }

  build() {
    if (this.inSettings) {
      if (this.shown) this.Content()
    } else {
      Column() {}.width(0).height(0).hitTestBehavior(HitTestMode.None)
        .bindSheet($$this.shown, this.Content, komaSheetOptions({ detents: [SheetSize.MEDIUM, SheetSize.LARGE],
          showClose: false, enableOutsideInteractive: false, scrollSizeMode: ScrollSizeMode.CONTINUOUS,
          enableFloatingDragBar: true, keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_SCROLL,
          onDisappear: () => { this.finishDismissal() } }))
    }
  }
}

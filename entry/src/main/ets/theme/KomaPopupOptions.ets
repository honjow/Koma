import { promptAction, uiAppearance, uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'
import { ThemeConstants } from './ThemeConstants'

// Match NextE's native popup materials. Callers continue owning geometry,
// dismissal, keyboard avoidance and every action; this layer only supplies material.
// Both declarative bindings and KomaMenuController consume these defaults;
// imperative openMenu is not a separate visual contract.
function popupMaterial(isSheet: boolean = false): SystemUiMaterial | undefined {
  if (!komaUsesImmersivePopupMaterial()) return undefined
  // Enum arguments are evaluated before a helper's guard. Keep every access
  // to the API-26 namespace here so API-23 startup retains its original surface.
  const style = isSheet ? uiMaterial.ImmersiveStyle.ULTRA_THICK : uiMaterial.ImmersiveStyle.THICK
  return new uiMaterial.ImmersiveMaterial({ style: style })
}

function komaUsesImmersivePopupMaterial(): boolean {
  return deviceInfo.apiAvailable('26.0.0')
}

// Tint only the card fill, so text and icons keep their normal contrast.
export function komaModalCardSurface(): ResourceColor {
  return komaUsesImmersivePopupMaterial() ? ThemeConstants.MODAL_CARD : ThemeConstants.CARD
}

export function komaMenuOptions(options: MenuOptions = {}): MenuOptions {
  options.systemMaterial = popupMaterial()
  return options
}

export function komaContextMenuOptions(options: ContextMenuOptions = {}): ContextMenuOptions {
  options.systemMaterial = popupMaterial()
  return options
}

export function komaSheetOptions(options: SheetOptions): SheetOptions {
  // App sheets have a close action in the shared modal title bar. A second
  // native close button overlaps it on wide windows and uses a different surface.
  options.showClose = false
  options.systemMaterial = popupMaterial(true)
  return options
}

// Native Toasts share the same material owner as the other system popups.
// Keep each caller's text, timing, placement and async API unchanged.
export function komaToastOptions(options: promptAction.ShowToastOptions): promptAction.ShowToastOptions {
  if (deviceInfo.apiAvailable('26.0.0')) options.systemMaterial = popupMaterial()
  return options
}

// Alert, selection and custom-content dialogs keep their native API/shape.
// Their caller supplies this shared surface instead of a separate local style.
// Two-button confirmations use primaryButton for cancel (left), secondaryButton
// for the confirmed action (right), matching the existing input-dialog order.
export function komaDialogMaterial(): SystemUiMaterial | undefined {
  return popupMaterial()
}

// bindSheet owns the material. A solid content root would paint over it.
// Keep the existing solid surface on systems predating the material API.
export function komaModalContentBackground(fallback: ResourceColor): ResourceColor {
  return komaUsesImmersivePopupMaterial() ? Color.Transparent : fallback
}

// Reader toolbar menus use system glass, which follows the system appearance
// even when Koma's content uses a fixed theme. Resolve before opening the menu.
export function komaReaderMenuTextColor(): ResourceColor {
  return uiAppearance.getDarkMode() === uiAppearance.DarkMode.ALWAYS_DARK ? '#F1F3F1' : '#181A18'
}

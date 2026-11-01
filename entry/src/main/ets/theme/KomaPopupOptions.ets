import { promptAction, uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'

// Match NextE's native popup materials. Callers continue owning geometry,
// dismissal, keyboard avoidance and every action; this layer only supplies material.
// Both declarative bindings and KomaMenuController consume these defaults;
// imperative openMenu is not a separate visual contract.
function popupMaterial(isSheet: boolean = false): SystemUiMaterial | undefined {
  if (!deviceInfo.apiAvailable('26.0.0')) return undefined
  // Enum arguments are evaluated before a helper's guard. Keep every access
  // to the API-26 namespace here so API-23 startup retains its original surface.
  const style = isSheet ? uiMaterial.ImmersiveStyle.ULTRA_THICK : uiMaterial.ImmersiveStyle.THICK
  return new uiMaterial.ImmersiveMaterial({ style: style })
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
  return deviceInfo.apiAvailable('26.0.0') ? Color.Transparent : fallback
}

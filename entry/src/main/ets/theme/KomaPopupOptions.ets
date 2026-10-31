import { uiMaterial } from '@kit.ArkUI'
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

// bindSheet owns the material. A solid content root would paint over it.
// Keep the existing solid surface on systems predating the material API.
export function komaModalContentBackground(fallback: ResourceColor): ResourceColor {
  return deviceInfo.apiAvailable('26.0.0') ? Color.Transparent : fallback
}

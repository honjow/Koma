import { uiMaterial } from '@kit.ArkUI'
import { deviceInfo } from '@kit.BasicServicesKit'

// Match NextE's native popup materials. Callers continue owning geometry,
// dismissal, keyboard avoidance and every action; this layer only supplies material.
function popupMaterial(style: uiMaterial.ImmersiveStyle): SystemUiMaterial | undefined {
  if (!deviceInfo.apiAvailable('26.0.0')) return undefined
  return new uiMaterial.ImmersiveMaterial({ style: style })
}

export function komaMenuOptions(options: MenuOptions = {}): MenuOptions {
  options.systemMaterial = popupMaterial(uiMaterial.ImmersiveStyle.THICK)
  return options
}

export function komaContextMenuOptions(options: ContextMenuOptions = {}): ContextMenuOptions {
  options.systemMaterial = popupMaterial(uiMaterial.ImmersiveStyle.THICK)
  return options
}

export function komaSheetOptions(options: SheetOptions): SheetOptions {
  options.systemMaterial = popupMaterial(uiMaterial.ImmersiveStyle.ULTRA_THICK)
  return options
}

// bindSheet owns the material. A solid content root would paint over it.
// Keep the existing solid surface on systems predating the material API.
export function komaModalContentBackground(fallback: ResourceColor): ResourceColor {
  return deviceInfo.apiAvailable('26.0.0') ? Color.Transparent : fallback
}

import { ComponentContent, FrameCallback, UIContext } from '@kit.ArkUI'
import { komaMenuOptions } from '../../theme/KomaPopupOptions'

export interface KomaMenuAction {
  label: string
  selected?: boolean
  isEnabled?: boolean
  children?: KomaMenuAction[]
  action: () => void
}

export interface KomaMenuGroup {
  id: string
  items: KomaMenuAction[]
}

interface KomaMenuParams { groups: KomaMenuGroup[] }

class KomaMenuAfterLayout extends FrameCallback {
  private open: () => void
  constructor(open: () => void) { super(); this.open = open }
  onIdle(_timeLeftInNano: number): void { this.open() }
}

// Delayed submenu callbacks need a component-owned builder context. Flat
// existing menus retain their original builder and lifecycle below.
@ComponentV2
struct KomaNestedMenu {
  @Param groups: KomaMenuGroup[] = []

  @Builder
  private Choices(item: KomaMenuAction) {
    Menu() {
      ForEach(item.children ?? [], (child: KomaMenuAction) => {
        MenuItem({ content: child.label }).selected(child.selected ?? false)
          .selectIcon(child.selected !== undefined).enabled(child.isEnabled ?? true).onClick(child.action)
      }, (child: KomaMenuAction, index: number) => `${index}:${child.label}`)
    }
  }

  @Builder
  private Action(item: KomaMenuAction) {
    if (item.children !== undefined) {
      MenuItem({ content: item.label, builder: () => { this.Choices(item) } })
        .enabled(item.isEnabled ?? true)
    } else {
      MenuItem({ content: item.label }).selected(item.selected ?? false)
        .selectIcon(item.selected !== undefined).enabled(item.isEnabled ?? true).onClick(item.action)
    }
  }

  build() {
    Menu() {
      if (this.groups.length === 1) {
        ForEach(this.groups[0].items, (item: KomaMenuAction) => { this.Action(item) },
          (item: KomaMenuAction, index: number) => `${index}:${item.label}`)
      } else {
        ForEach(this.groups, (group: KomaMenuGroup) => {
          MenuItemGroup() {
            ForEach(group.items, (item: KomaMenuAction) => { this.Action(item) },
              (item: KomaMenuAction, index: number) => `${index}:${item.label}`)
          }
        }, (group: KomaMenuGroup) => group.id)
      }
    }.subMenuExpandingMode(SubMenuExpandingMode.STACK_EXPAND)
  }
}

@Builder
function KomaMenuContent(params: KomaMenuParams) {
  if (params.groups.some((group: KomaMenuGroup): boolean =>
    group.items.some((item: KomaMenuAction): boolean => item.children !== undefined))) {
    KomaNestedMenu({ groups: params.groups })
  } else {
    Menu() {
      if (params.groups.length === 1) {
        ForEach(params.groups[0].items, (item: KomaMenuAction) => {
          MenuItem({ content: item.label }).selected(item.selected ?? false)
            .selectIcon(item.selected !== undefined).enabled(item.isEnabled ?? true).onClick(item.action)
        }, (item: KomaMenuAction, index: number) => `${index}:${item.label}`)
      } else {
        ForEach(params.groups, (group: KomaMenuGroup) => {
          MenuItemGroup() {
            // Keep arrays on the ComponentContent parameter object, as in the
            // original library menu. An array passed through a nested @Builder
            // is not a usable ForEach data source on the device runtime.
            ForEach(group.items, (item: KomaMenuAction) => {
              MenuItem({ content: item.label }).selected(item.selected ?? false)
                .selectIcon(item.selected !== undefined).enabled(item.isEnabled ?? true).onClick(item.action)
            }, (item: KomaMenuAction, index: number) => `${index}:${item.label}`)
          }
        }, (group: KomaMenuGroup) => group.id)
      }
    }
  }
}

// The library title menus and detail overflow share the same native anchored
// menu, system material and disposal lifecycle. Groups add native separators,
// not another page. Material is mandatory here so consumers cannot omit it.
export class KomaMenuController {
  private content?: ComponentContent<KomaMenuParams> = undefined
  private context?: UIContext = undefined
  private pending: boolean = false
  private requestId: number = 0

  private release(content: ComponentContent<KomaMenuParams>): void {
    if (this.content !== content) return
    this.content = undefined
    this.context = undefined
    content.dispose()
  }

  close(): void {
    this.requestId++
    this.pending = false
    const content = this.content
    if (content !== undefined) {
      void this.context?.getPromptAction().closeMenu(content).catch(() => { this.release(content) })
    }
  }

  open(context: UIContext, targetId: string, groups: () => KomaMenuGroup[], onError: () => void): void {
    if (this.content !== undefined || this.pending) return
    const requestId = ++this.requestId
    this.pending = true
    // HDS may rearrange its action nodes while detail availability changes.
    // Resolve the current native node and actions after layout, not the old
    // inspector-id target captured during that update. No timed delay.
    context.postFrameCallback(new KomaMenuAfterLayout((): void => {
      if (requestId !== this.requestId) return
      this.pending = false
      this.openAfterLayout(context, targetId, groups(), onError)
    }))
  }

  private openAfterLayout(context: UIContext, targetId: string, groups: KomaMenuGroup[], onError: () => void): void {
    const visibleGroups = groups.filter((group: KomaMenuGroup): boolean => group.items.length > 0)
    if (visibleGroups.length === 0) return
    const params: KomaMenuParams = { groups: visibleGroups }
    try {
      const target = context.getFrameNodeById(targetId)
      if (target === null) { onError(); return }
      const content = new ComponentContent<KomaMenuParams>(context,
        wrapBuilder<[KomaMenuParams]>(KomaMenuContent), params)
      this.content = content
      this.context = context
      void context.getPromptAction().openMenu(content, { id: target.getUniqueId() }, komaMenuOptions({
        placement: Placement.BottomRight,
        onDisappear: (): void => { this.release(content) },
      })).catch((): void => { this.release(content); onError() })
    } catch (_error) { onError() }
  }
}

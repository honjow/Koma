import { ComponentContent, UIContext } from '@kit.ArkUI'

export interface KomaMenuAction {
  label: string
  selected?: boolean
  isEnabled?: boolean
  action: () => void
}

export interface KomaMenuGroup {
  id: string
  items: KomaMenuAction[]
}

interface KomaMenuParams { groups: KomaMenuGroup[] }

@Builder
function KomaMenuContent(params: KomaMenuParams) {
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

// The library title menus and detail overflow share the same native anchored
// menu and disposal lifecycle. Groups add native separators, not another page.
export class KomaMenuController {
  private content?: ComponentContent<KomaMenuParams> = undefined
  private context?: UIContext = undefined

  private release(content: ComponentContent<KomaMenuParams>): void {
    if (this.content !== content) return
    this.content = undefined
    this.context = undefined
    content.dispose()
  }

  close(): void {
    const content = this.content
    if (content !== undefined) {
      void this.context?.getPromptAction().closeMenu(content).catch(() => { this.release(content) })
    }
  }

  open(context: UIContext, targetId: string, groups: KomaMenuGroup[], onError: () => void): void {
    if (this.content !== undefined) return
    const visibleGroups = groups.filter((group: KomaMenuGroup): boolean => group.items.length > 0)
    if (visibleGroups.length === 0) return
    const params: KomaMenuParams = { groups: visibleGroups }
    try {
      const content = new ComponentContent<KomaMenuParams>(context,
        wrapBuilder<[KomaMenuParams]>(KomaMenuContent), params)
      this.content = content
      this.context = context
      void context.getPromptAction().openMenu(content, { id: targetId }, {
        placement: Placement.BottomRight,
        onDisappear: (): void => { this.release(content) },
      }).catch((): void => { this.release(content); onError() })
    } catch (_error) { onError() }
  }
}

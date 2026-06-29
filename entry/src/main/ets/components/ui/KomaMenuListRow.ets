import { ConciseListRow } from './ConciseListRow'

@ComponentV2
export struct KomaMenuListRow {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr = ''
  @Param subtitleMaxLines: number = 2
  @Param trailingText: ResourceStr = ''
  @Param trailingDropdown: boolean = false
  @Param showChevron: boolean = true
  @Param isEnabled: boolean = true
  @Param isMenuOpen: boolean = false
  @Param menuPlacement: Placement = Placement.BottomRight
  @Event action: () => void = () => {}
  @BuilderParam menuBuilderParam?: () => void

  @Builder
  private MenuContent() {
    if (this.menuBuilderParam) {
      this.menuBuilderParam()
    }
  }

  build() {
    Column() {
      ConciseListRow({
        title: this.title,
        subtitle: this.subtitle,
        subtitleMaxLines: this.subtitleMaxLines,
        trailingText: this.trailingText,
        trailingDropdown: this.trailingDropdown,
        showChevron: this.showChevron,
        isEnabled: this.isEnabled,
        action: () => {
          this.action()
        },
      })
    }
    .width('100%')
    .bindMenu(this.isMenuOpen, this.MenuContent(), {
      placement: this.menuPlacement,
    })
  }
}

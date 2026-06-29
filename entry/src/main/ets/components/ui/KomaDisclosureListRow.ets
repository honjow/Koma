import { ThemeConstants } from '../../theme/ThemeConstants'
import { ConciseListRow } from './ConciseListRow'
import { ListDivider } from './GroupedListSection'

@ComponentV2
export struct KomaDisclosureListRow {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr = ''
  @Param subtitleMaxLines: number = 2
  @Param isExpanded: boolean = false
  @Param isEnabled: boolean = true
  @Event toggle: () => void = () => {}
  @BuilderParam contentBuilderParam?: () => void

  @Builder
  private ExpandedContent() {
    if (this.contentBuilderParam) {
      ListDivider()
      Column() {
        this.contentBuilderParam()
      }
      .width('100%')
      .padding({ top: ThemeConstants.SPACE_XS, bottom: ThemeConstants.SPACE_XS })
    }
  }

  build() {
    Column() {
      ConciseListRow({
        title: this.title,
        subtitle: this.subtitle,
        subtitleMaxLines: this.subtitleMaxLines,
        showChevron: true,
        isEnabled: this.isEnabled,
        action: () => {
          this.toggle()
        },
      })
      if (this.isExpanded) {
        this.ExpandedContent()
      }
    }
    .width('100%')
  }
}

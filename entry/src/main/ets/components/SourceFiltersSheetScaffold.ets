import { ThemeConstants } from '../theme/ThemeConstants'
import { KomaModalScaffold } from './KomaModalScaffold'
import { GroupedListSection } from './ui/GroupedListSection'
import { KomaActionButton } from './ui/KomaActionButton'

@ComponentV2
export struct SourceFiltersSheetScaffold {
  @Param title: ResourceStr = ''
  @Param resetLabel: ResourceStr = ''
  @Param showReset: boolean = false
  @Param resetEnabled: boolean = true
  @Event onClose: () => void = () => {}
  @Event onReset: () => void = () => {}
  @BuilderParam content: () => void

  build() {
    KomaModalScaffold({
      title: this.title,
      onClose: () => {
        this.onClose()
      },
    }) {
      Column({ space: ThemeConstants.SPACE_LG }) {
        GroupedListSection() {
          this.content()
        }
        if (this.showReset) {
          KomaActionButton({
            label: this.resetLabel,
            kind: 'ghost',
            compact: true,
            isEnabled: this.resetEnabled,
            action: () => {
              this.onReset()
            },
          })
        }
        Blank().height(ThemeConstants.SPACE_XL)
      }
      .width('100%')
      .padding(ThemeConstants.SPACE_LG)
    }
  }
}

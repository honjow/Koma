import { KomaModalScaffold } from './KomaModalScaffold'

@ComponentV2
export struct SourceModalScaffold {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr | undefined = undefined
  @Event onClose: () => void = () => {}
  @BuilderParam content: () => void
  private scroller: Scroller = new Scroller()

  build() {
    KomaModalScaffold({
      title: this.title,
      subtitle: this.subtitle,
      scroller: this.scroller,
      onClose: () => {
        this.onClose()
      },
    }) {
      this.content()
    }
  }
}

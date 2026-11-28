/** A long press owns only the favorite action. The wrapped native control keeps its normal tap. */
@ComponentV2
export struct ReaderSettingOption {
  @Require @Param settingKey: string
  @Param onFavorite: ((key: string) => void) | undefined = undefined
  @BuilderParam content: () => void

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .id('reader-setting-' + this.settingKey)
    .priorityGesture(LongPressGesture({ repeat: false })
      .onAction((): void => { this.onFavorite?.(this.settingKey) }))
    .onGestureJudgeBegin((gesture: GestureInfo): GestureJudgeResult =>
      this.onFavorite === undefined && gesture.type === GestureControl.GestureType.LONG_PRESS_GESTURE
        ? GestureJudgeResult.REJECT : GestureJudgeResult.CONTINUE)
  }
}

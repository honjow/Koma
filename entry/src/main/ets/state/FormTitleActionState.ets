// A routed form owns its draft and validation; its navigation host only
// renders the current action state and sends a save request back to it.
@ObservedV2
export class FormTitleActionState {
  @Trace enabled: boolean = false
  @Trace requestSeq: number = 0

  requestSave(): void { if (this.enabled) this.requestSeq += 1 }
}

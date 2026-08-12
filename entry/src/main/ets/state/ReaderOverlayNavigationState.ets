import { AppStorageV2 } from '@kit.ArkUI'
import { RouteName } from '../common/Constants'

/**
 * Owns Reader's full-window navigation stack independently of the root HDS
 * navigation.  The root stays mounted underneath Reader, while this private
 * stack keeps a transparent backdrop alive for both the entry and exit route
 * transitions.
 */
@ObservedV2
export class ReaderOverlayNavigationState {
  @Trace visible: boolean = false
  @Trace stack: NavPathStack = new NavPathStack()
  private pendingReader: boolean = false
  private closing: boolean = false

  open(): void {
    this.stack.clear(false)
    this.stack.pushPath({ name: 'ReaderOverlayBackdrop' }, false)
    this.pendingReader = true
    this.closing = false
    this.visible = true
  }

  presentPendingReader(): void {
    if (!this.visible || this.closing || !this.pendingReader) {
      return
    }
    this.pendingReader = false
    this.stack.pushPath({ name: RouteName.READER }, true)
  }

  close(): void {
    if (!this.visible || this.closing) {
      return
    }
    this.pendingReader = false
    if (this.stack.getAllPathName().length === 0) {
      this.finishClose()
      return
    }
    this.closing = true
    this.stack.pop(true)
  }

  finishClose(): void {
    if (!this.closing) {
      return
    }
    this.closing = false
    this.visible = false
    this.stack.clear(false)
  }

  reset(): void {
    this.pendingReader = false
    this.closing = false
    this.visible = false
    this.stack.clear(false)
  }
}

const READER_OVERLAY_NAVIGATION_KEY: string = 'koma:readerOverlayNavigation'

export function connectReaderOverlayNavigation(): ReaderOverlayNavigationState {
  return AppStorageV2.connect(
    ReaderOverlayNavigationState,
    READER_OVERLAY_NAVIGATION_KEY,
    () => new ReaderOverlayNavigationState(),
  )!
}

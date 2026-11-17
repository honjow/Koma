import nativeVSync from 'libkoma_reader_vsync.so'

interface NativeReaderTurnVSync {
  open(): Object | null
  setRate(receiver: Object, expected: number): boolean
  request(receiver: Object): boolean
  close(receiver: Object): void
}

const vsync: NativeReaderTurnVSync = nativeVSync as NativeReaderTurnVSync
// RenderService drops a NativeVSync vote after roughly 200 ms without a frame
// request. Refresh it at a lower frequency than the animation itself runs.
const REQUEST_INTERVAL_MS: number = 80
const ABANDONED_TURN_TIMEOUT_MS: number = 1000

export class KomaReaderTurnVSync {
  private receiver: Object | null = null
  private keepAlive: number = -1
  private timeout: number = -1

  prepare(): void {
    if (this.receiver === null) this.receiver = vsync.open()
  }

  start(): void {
    if (this.keepAlive >= 0) return
    this.prepare()
    const receiver = this.receiver
    if (receiver === null || !vsync.setRate(receiver, 120)) return
    if (!vsync.request(receiver)) {
      this.clearRate(receiver)
      return
    }
    this.keepAlive = setInterval((): void => {
      if (!vsync.request(receiver)) this.stop()
    }, REQUEST_INTERVAL_MS)
    // Usually stopped by the pager's actual busy-to-idle transition.
    this.timeout = setTimeout((): void => this.stop(), ABANDONED_TURN_TIMEOUT_MS)
    console.info('[KomaReaderTurnVSync] start expected=120')
  }

  stop(): void {
    if (this.keepAlive < 0) return
    clearInterval(this.keepAlive)
    clearTimeout(this.timeout)
    this.keepAlive = -1
    this.timeout = -1
    const receiver = this.receiver
    if (receiver !== null) this.clearRate(receiver)
    console.info('[KomaReaderTurnVSync] stop')
  }

  private clearRate(receiver: Object): void {
    if (vsync.setRate(receiver, 0)) return
    this.receiver = null
    vsync.close(receiver)
  }

  close(): void {
    this.stop()
    const receiver = this.receiver
    this.receiver = null
    if (receiver !== null) vsync.close(receiver)
  }
}

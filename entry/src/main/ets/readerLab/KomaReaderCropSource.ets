import { ReaderImageCropBounds, ReaderImageCropSource } from '@reader-kit/core'
import { ReaderPageCropService } from '../model/ReaderPageCropService'

/** Koma owns detector strength/cache; reader-kit only consumes normalized bounds. */
export class KomaReaderCropSource implements ReaderImageCropSource {
  private path: string
  private strength: () => string

  constructor(path: string, strength: () => string) {
    this.path = path.startsWith('file://') ? path.substring('file://'.length) : path
    this.strength = strength
  }

  async read(): Promise<ReaderImageCropBounds> {
    const bounds = await ReaderPageCropService.detectFile(this.path, this.strength())
    return new ReaderImageCropBounds(bounds.left, bounds.top, bounds.right, bounds.bottom)
  }
}

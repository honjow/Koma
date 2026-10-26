import { http } from '@kit.NetworkKit'
import { fileIo } from '@kit.CoreFileKit'

const MAX_MODEL_ASSET_BYTES: number = 100 * 1024 * 1024

/** Public, pinned model assets have their own transport and never use source/login cookies. */
export class ReaderModelAssetDownload {
  static async download(url: string, path: string, progress: (loaded: number, total: number) => void,
    connectTimeout: number, noProgressTimeout: number, accept: string, maxAttempts: number,
    readTimeout: number): Promise<number> {
    if (!/^https:\/\/[^\s/@?#]+\//.test(url)) throw new Error('reader_model_url_invalid')
    let lastError: Error = new Error('reader_model_download_failed')
    for (let attempt = 0; attempt < Math.max(1, maxAttempts); attempt += 1) {
      const request = http.createHttp()
      let file: fileIo.File | undefined = undefined
      let completed: boolean = false
      let stallTimer: number = -1
      try {
        file = fileIo.openSync(path, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC)
        const descriptor = file.fd
        let written: number = 0
        let receiveError: Error | null = null
        let rejectStream: (error: Error) => void = (_error: Error): void => {}
        const streamFailure = new Promise<number>((_resolve, reject) => { rejectStream = reject })
        const armStallDeadline = (): void => {
          if (stallTimer >= 0) clearTimeout(stallTimer)
          stallTimer = setTimeout((): void => {
            receiveError = new Error('reader_model_download_stalled')
            rejectStream(receiveError as Error)
            request.destroy()
          }, Math.max(connectTimeout, noProgressTimeout))
        }
        armStallDeadline()
        request.on('dataReceive', (chunk: ArrayBuffer): void => {
          if (receiveError !== null) return
          try {
            armStallDeadline()
            if (written + chunk.byteLength > MAX_MODEL_ASSET_BYTES) throw new Error('reader_model_asset_too_large')
            const count = fileIo.writeSync(descriptor, chunk, { offset: written })
            if (count !== chunk.byteLength) throw new Error('reader_model_write_failed')
            written += count
          } catch (error) {
            receiveError = error as Error
            rejectStream(error as Error)
            request.destroy()
          }
        })
        request.on('dataReceiveProgress', (value: http.DataReceiveProgressInfo): void => {
          progress(value.receiveSize, value.totalSize)
        })
        const response = request.requestInStream(url, {
          method: http.RequestMethod.GET, header: { Accept: accept }, usingCache: false,
          connectTimeout, readTimeout,
        })
        const status = await Promise.race([response, streamFailure])
        if (receiveError !== null) throw receiveError as Error
        if (status !== 200 || written <= 0) throw new Error('reader_model_http_failed')
        completed = true
        progress(written, written)
        return written
      } catch (error) {
        lastError = error as Error
      } finally {
        if (stallTimer >= 0) clearTimeout(stallTimer)
        request.destroy()
        if (file !== undefined) fileIo.closeSync(file)
        if (!completed) {
          try { fileIo.unlinkSync(path) } catch (_error) {}
        }
      }
    }
    throw lastError
  }
}

import { taskpool } from '@kit.ArkTS'
import { fileIo } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

/** Keep full-file verification off the caller's UI thread. Only primitive
 * inputs cross the worker boundary; model readiness stays with its service.
 * This preserves the pinned size/digest check, including missing/corrupt files.
 */
@Concurrent
export function validateReaderModelAssetWorker(path: string, expectedBytes: number, expectedSha256: string): boolean {
  try {
    let file: fileIo.File | null = null
    try {
      file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(file.fd)
      if (!stat.isFile() || stat.size !== expectedBytes) return false
      const digest = cryptoFramework.createMd('SHA256')
      const buffer = new ArrayBuffer(256 * 1024)
      while (true) {
        const read = fileIo.readSync(file.fd, buffer, { length: buffer.byteLength })
        if (read <= 0) break
        digest.updateSync({ data: new Uint8Array(buffer, 0, read) })
      }
      return Array.from(digest.digestSync().data)
        .map((value: number): string => value.toString(16).padStart(2, '0')).join('') === expectedSha256
    } finally {
      if (file !== null) fileIo.closeSync(file)
    }
  } catch (_error) {
    return false
  }
}

export function validateReaderModelAsset(path: string, expectedBytes: number, expectedSha256: string): Promise<boolean> {
  return taskpool.execute(validateReaderModelAssetWorker, path, expectedBytes, expectedSha256) as Promise<boolean>
}

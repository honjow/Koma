import { taskpool } from '@kit.ArkTS'
import { fileIo } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

// The processing/cache identity remains content-based. Reading a whole original
// and hashing it is preparation work, including when a derivative is cached.
@Concurrent
export function readerImageFileSha256Worker(path: string): string {
  const digest = cryptoFramework.createMd('SHA256')
  const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
  try {
    const buffer = new ArrayBuffer(256 * 1024)
    while (true) {
      const read = fileIo.readSync(file.fd, buffer, { length: buffer.byteLength })
      if (read <= 0) break
      digest.updateSync({ data: new Uint8Array(buffer, 0, read) })
    }
    return Array.from(digest.digestSync().data)
      .map((value: number): string => value.toString(16).padStart(2, '0')).join('')
  } finally {
    fileIo.closeSync(file)
  }
}

export function readerImageFileSha256(path: string): Promise<string> {
  return taskpool.execute(readerImageFileSha256Worker, path) as Promise<string>
}

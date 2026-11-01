import { fileIo as fs } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

@Concurrent
export function imageFileContentHash(path: string): string {
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
  try {
    const digest = cryptoFramework.createMd('SHA256')
    const buffer = new ArrayBuffer(128 * 1024)
    while (true) {
      const count = fs.readSync(file.fd, buffer, { length: buffer.byteLength })
      if (count <= 0) break
      digest.updateSync({ data: new Uint8Array(buffer, 0, count) })
    }
    return Array.from(digest.digestSync().data).map((value: number): string => value.toString(16).padStart(2, '0')).join('')
  } finally { fs.closeSync(file) }
}

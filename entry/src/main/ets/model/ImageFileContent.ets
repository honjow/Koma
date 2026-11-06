import { fileIo as fs } from '@kit.CoreFileKit'
import { cryptoFramework } from '@kit.CryptoArchitectureKit'

export function isAvifFileType(bytes: ArrayBuffer, available: number): boolean {
  if (available < 16) return false
  const view = new DataView(bytes)
  if (view.getUint32(4) !== 0x66747970) return false // ftyp
  let size = view.getUint32(0)
  let offset = 8
  if (size === 1) {
    if (available < 24 || view.getUint32(8) !== 0) return false
    size = view.getUint32(12)
    offset = 16
  }
  if (size < offset + 8) return false
  const brand = view.getUint32(offset)
  if (brand === 0x61766966 || brand === 0x61766973) return true // avif, avis
  for (let at = offset + 8; at + 4 <= Math.min(size, available); at += 4) {
    const compatible = view.getUint32(at)
    if (compatible === 0x61766966 || compatible === 0x61766973) return true
  }
  return false
}

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

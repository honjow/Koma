import { fileIo as fs } from '@kit.CoreFileKit'
import { zlib } from '@kit.BasicServicesKit'

/** Copy full packed RGBA scanlines using the fixed upstream reverse-stripe contract. */
export function restoreJmStripePixels(pixels: ArrayBuffer, width: number, height: number, rows: number): ArrayBuffer {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width < 1 || height < 1 ||
    !Number.isInteger(rows) || rows < 2 || rows > 20 || rows % 2 !== 0 ||
    width * height * 4 > 256 * 1024 * 1024 || pixels.byteLength !== width * height * 4) {
    throw new Error('source_required_decode_dimensions')
  }
  const input = new Uint8Array(pixels)
  const output = new Uint8Array(pixels.byteLength)
  const line = width * 4
  const size = Math.floor(height / rows)
  const remainder = height % rows
  for (let i = 0; i < rows; i += 1) {
    const count = size + (i === 0 ? remainder : 0)
    const srcY = height - size * (i + 1) - remainder
    const dstY = size * i + (i === 0 ? 0 : remainder)
    output.set(input.subarray(srcY * line, (srcY + count) * line), dstY * line)
  }
  return output.buffer as ArrayBuffer
}

export async function inflateSourceGzip(bytes: ArrayBuffer): Promise<ArrayBuffer> {
  const raw = new Uint8Array(bytes)
  if (raw.length < 18) throw new Error('source_required_decode_gzip')
  const n = raw.length
  const expected = (raw[n - 4] | raw[n - 3] << 8 | raw[n - 2] << 16 | raw[n - 1] << 24) >>> 0
  if (expected === 0 || expected > 128 * 1024 * 1024) throw new Error('source_required_decode_gzip_size')
  const output = new ArrayBuffer(expected)
  const stream: zlib.ZStream = { nextIn: bytes, availableIn: bytes.byteLength, nextOut: output, availableOut: expected }
  const zip = zlib.createZipSync()
  const initialized = await zip.inflateInit2(stream, 31)
  if (initialized !== zlib.ReturnStatus.OK) throw new Error('source_required_decode_gzip_init')
  try {
    const status = await zip.inflate(stream, zlib.CompressFlushMode.FINISH)
    const state = await zip.getZStream()
    if (status !== zlib.ReturnStatus.STREAM_END || state.totalOut !== expected || state.availableIn !== 0) {
      throw new Error('source_required_decode_gzip_incomplete')
    }
    return output
  } finally { await zip.inflateEnd(stream) }
}

@Concurrent
export function readSourceImageBytesTask(path: string): ArrayBuffer {
  const file = fs.openSync(path, fs.OpenMode.READ_ONLY)
  try {
    const size = fs.statSync(file.fd).size
    if (size <= 0 || size > 128 * 1024 * 1024) throw new Error('source_required_decode_input_size')
    const bytes = new ArrayBuffer(size)
    if (fs.readSync(file.fd, bytes) !== size) throw new Error('source_required_decode_incomplete')
    return bytes
  } finally { fs.closeSync(file) }
}

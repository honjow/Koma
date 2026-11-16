import { buffer, util } from '@kit.ArkTS'
import { zlib } from '@kit.BasicServicesKit'
import { fileIo as fs } from '@kit.CoreFileKit'

export const BACKUP_FILE_EXTENSION: string = '.komabk'
export const BACKUP_FILE_HEADER_BYTES: number = 16
const BACKUP_FILE_MAGIC: number = 0x4b4f4d41 // KOMA
const BACKUP_FILE_VERSION: number = 1
const MAX_GZIP_CONTENT_BYTES: number = 512 * 1024 * 1024

export interface BackupFileSummary {
  exportedAt: number
  encrypted: boolean
}

export function backupFileExtension(fileName: string): string {
  if (fileName.endsWith(BACKUP_FILE_EXTENSION)) return BACKUP_FILE_EXTENSION
  if (fileName.endsWith('.koma-backup')) return '.koma-backup'
  return fileName.endsWith('.json') ? '.json' : ''
}

/** Public preview metadata lets the list scan a fixed prefix without inflating the library. */
export function readBackupFileHeader(bytes: ArrayBuffer): BackupFileSummary | undefined {
  const view = new DataView(bytes)
  if (bytes.byteLength < 4 || view.getUint32(0) !== BACKUP_FILE_MAGIC) return undefined
  if (bytes.byteLength < BACKUP_FILE_HEADER_BYTES || view.getUint8(4) !== BACKUP_FILE_VERSION ||
    view.getUint8(5) > 1 || view.getUint16(6) !== 0) {
    throw new Error('backup_invalid_file_header')
  }
  const exportedAt = view.getFloat64(8)
  if (!Number.isSafeInteger(exportedAt) || exportedAt < 0) throw new Error('backup_invalid_file_header')
  return { exportedAt, encrypted: view.getUint8(5) === 1 }
}

function backupUtf8Bytes(text: string): ArrayBuffer {
  const bytes = buffer.from(text, 'utf-8')
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.length)
}

export async function compressBackupJson(text: string): Promise<ArrayBuffer> {
  const input = backupUtf8Bytes(text)
  if (input.byteLength === 0 || input.byteLength > MAX_GZIP_CONTENT_BYTES) throw new Error('backup_invalid_content_size')
  const zip = zlib.createZipSync()
  // compressBound covers the default zlib stream. Reserve the full gzip header and trailer as well.
  const output = new ArrayBuffer(await zip.compressBound(input.byteLength) + 18)
  const stream: zlib.ZStream = { nextIn: input, availableIn: input.byteLength,
    nextOut: output, availableOut: output.byteLength }
  const started = await zip.deflateInit2(stream, zlib.CompressLevel.COMPRESS_LEVEL_DEFAULT_COMPRESSION,
    zlib.CompressMethod.DEFLATED, 31, zlib.MemLevel.MEM_LEVEL_DEFAULT,
    zlib.CompressStrategy.COMPRESS_STRATEGY_DEFAULT_STRATEGY)
  if (started !== zlib.ReturnStatus.OK) throw new Error('backup_compress_failed')
  try {
    const result = await zip.deflate(stream, zlib.CompressFlushMode.FINISH)
    const state = await zip.getZStream()
    const size = state.totalOut ?? 0
    if (result !== zlib.ReturnStatus.STREAM_END || state.availableIn !== 0 || size < 18 || size > output.byteLength) {
      throw new Error('backup_compress_failed')
    }
    return output.slice(0, size)
  } finally {
    await zip.deflateEnd(stream)
  }
}

export async function decompressBackupJson(input: ArrayBuffer): Promise<string> {
  return buffer.from(await inflateBackupGzip(input)).toString('utf-8')
}

export async function inflateBackupGzip(input: ArrayBuffer): Promise<ArrayBuffer> {
  const bytes = new Uint8Array(input)
  if (bytes.byteLength < 18 || bytes[0] !== 0x1f || bytes[1] !== 0x8b) throw new Error('backup_invalid_gzip')
  const size = new DataView(input).getUint32(bytes.byteLength - 4, true)
  if (size === 0 || size > MAX_GZIP_CONTENT_BYTES) throw new Error('backup_invalid_content_size')
  const output = new ArrayBuffer(size)
  const stream: zlib.ZStream = { nextIn: input, availableIn: bytes.byteLength, nextOut: output, availableOut: size }
  const zip = zlib.createZipSync()
  if (await zip.inflateInit2(stream, 31) !== zlib.ReturnStatus.OK) throw new Error('backup_invalid_gzip')
  try {
    const result = await zip.inflate(stream, zlib.CompressFlushMode.FINISH)
    const state = await zip.getZStream()
    if (result !== zlib.ReturnStatus.STREAM_END || state.availableIn !== 0 || state.totalOut !== size) {
      throw new Error('backup_invalid_gzip')
    }
    return output
  } finally {
    await zip.inflateEnd(stream)
  }
}

export async function encodeBackupFile(payload: string, summary: BackupFileSummary): Promise<ArrayBuffer> {
  // The encryption service compresses plaintext before encryption.
  const body = summary.encrypted ? backupUtf8Bytes(payload) : await compressBackupJson(payload)
  const output = new ArrayBuffer(BACKUP_FILE_HEADER_BYTES + body.byteLength)
  const view = new DataView(output)
  view.setUint32(0, BACKUP_FILE_MAGIC)
  view.setUint8(4, BACKUP_FILE_VERSION)
  view.setUint8(5, summary.encrypted ? 1 : 0)
  view.setFloat64(8, summary.exportedAt)
  new Uint8Array(output, BACKUP_FILE_HEADER_BYTES).set(new Uint8Array(body))
  return output
}

export async function decodeBackupFile(bytes: ArrayBuffer): Promise<string> {
  const summary = readBackupFileHeader(bytes)
  if (summary === undefined) return buffer.from(bytes).toString('utf-8')
  if (bytes.byteLength <= BACKUP_FILE_HEADER_BYTES) throw new Error('backup_invalid_file_header')
  if (summary.encrypted) {
    return buffer.from(bytes, BACKUP_FILE_HEADER_BYTES, bytes.byteLength - BACKUP_FILE_HEADER_BYTES).toString('utf-8')
  }
  return decompressBackupJson(bytes.slice(BACKUP_FILE_HEADER_BYTES))
}

export async function readBackupBytes(path: string, limit?: number): Promise<ArrayBuffer> {
  // Opening the descriptor also works for a persisted DocumentViewPicker URI.
  const file = await fs.open(path, fs.OpenMode.READ_ONLY)
  try {
    const stat = await fs.stat(file.fd)
    const size = limit === undefined ? stat.size : Math.min(stat.size, limit)
    const data = new ArrayBuffer(size)
    if (size === 0) return data
    let offset = await fs.read(file.fd, data)
    const bytes = new Uint8Array(data)
    while (offset < size) {
      const rest = new ArrayBuffer(Math.min(65536, size - offset))
      const count = await fs.read(file.fd, rest)
      if (count <= 0) throw new Error('backup_file_read_incomplete')
      bytes.set(new Uint8Array(rest, 0, count), offset)
      offset += count
    }
    return data
  } finally {
    await fs.close(file)
  }
}

export async function writeBackupBytes(path: string, bytes: ArrayBuffer): Promise<void> {
  const file = await fs.open(path, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
  try {
    if (await fs.write(file.fd, bytes) !== bytes.byteLength) throw new Error('backup_file_write_incomplete')
    await fs.fsync(file.fd)
  } finally {
    await fs.close(file)
  }
}

export async function publishBackupFile(path: string, bytes: ArrayBuffer): Promise<void> {
  const temporary = `${path}.${util.generateRandomUUID(true)}.tmp`
  try {
    await writeBackupBytes(temporary, bytes)
    await fs.rename(temporary, path)
  } catch (error) {
    try { await fs.unlink(temporary) } catch (_error) {}
    throw error as Error
  }
}

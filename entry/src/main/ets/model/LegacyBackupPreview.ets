import { util } from '@kit.ArkTS'
import { fileIo as fs } from '@kit.CoreFileKit'

const READ_CHUNK_BYTES = 64 * 1024
const MAX_METADATA_TOKEN_LENGTH = 256
const MAX_JSON_DEPTH = 96

enum MetadataSection {
  Skip,
  Root,
  Kdf,
  Aad,
}

const ROOT_FIELDS: string[] = ['kind', 'schemaVersion', 'exportedAt', 'libraryStore', 'readingProgress',
  'envelopeVersion', 'contentSchemaVersion', 'createdAt', 'algorithm', 'kdf', 'nonce', 'tag', 'aad', 'payload']
const KDF_FIELDS: string[] = ['id', 'iterations', 'salt']
const AAD_FIELDS: string[] = ['kind', 'envelopeVersion', 'contentSchemaVersion', 'algorithm', 'kdfId']
const STRING_TYPE_FIELDS: string[] = ['libraryStore', 'readingProgress', 'nonce', 'tag', 'payload', 'salt']

function invalidBackup(): Error {
  return new Error('backup_invalid_legacy_preview')
}

/** Validate the JSON through EOF while retaining only the fields used for listing and retention.
 * The payload values are deliberately unusable for restore. Full restore reads the original file. */
export async function readLegacyBackupPreviewJson(path: string): Promise<string> {
  const file = await fs.open(path, fs.OpenMode.READ_ONLY)
  try {
    return await new LegacyBackupPreviewReader(file.fd).read()
  } finally {
    await fs.close(file)
  }
}

class LegacyBackupPreviewReader {
  private readonly fd: number
  private readonly data = new ArrayBuffer(READ_CHUNK_BYTES)
  private readonly decoder = util.TextDecoder.create('utf-8', { fatal: true })
  private chunk = ''
  private offset = 0
  private eof = false

  constructor(fd: number) {
    this.fd = fd
  }

  async read(): Promise<string> {
    if (await this.nextToken() !== '{') throw invalidBackup()
    const summary = await this.readObject(MetadataSection.Root, 0)
    if (await this.nextToken() !== '') throw invalidBackup()
    return summary
  }

  private async fill(): Promise<boolean> {
    while (this.offset >= this.chunk.length && !this.eof) {
      const count = await fs.read(this.fd, this.data)
      this.eof = count === 0
      this.chunk = this.decoder.decodeToString(new Uint8Array(this.data, 0, count), { stream: !this.eof })
      this.offset = 0
    }
    return this.offset < this.chunk.length
  }

  private async nextToken(): Promise<string> {
    while (await this.fill()) {
      while (this.offset < this.chunk.length) {
        const char = this.chunk[this.offset]
        if (char !== ' ' && char !== '\t' && char !== '\n' && char !== '\r') return char
        this.offset++
      }
    }
    return ''
  }

  private async readObject(section: MetadataSection, depth: number): Promise<string> {
    this.offset++
    const fields = section === MetadataSection.Skip ? undefined : new Map<string, string>()
    const keys = section === MetadataSection.Root ? ROOT_FIELDS :
      (section === MetadataSection.Kdf ? KDF_FIELDS : (section === MetadataSection.Aad ? AAD_FIELDS : []))
    let next = await this.nextToken()
    if (next !== '}') {
      for (;;) {
        if (next !== '"') throw invalidBackup()
        const rawKey = await this.readString(section !== MetadataSection.Skip)
        const key = section === MetadataSection.Skip ? '' : JSON.parse(rawKey) as string
        if (await this.nextToken() !== ':') throw invalidBackup()
        this.offset++
        const keep = keys.includes(key)
        const child = section === MetadataSection.Root && key === 'kdf' ? MetadataSection.Kdf :
          (section === MetadataSection.Root && key === 'aad' ? MetadataSection.Aad : MetadataSection.Skip)
        const value = await this.readValue(keep, keep && !STRING_TYPE_FIELDS.includes(key), child, depth + 1)
        if (keep) fields?.set(key, value)
        if (!keep && section === MetadataSection.Aad) fields?.set('unexpected', 'true')
        next = await this.nextToken()
        if (next !== ',') break
        this.offset++
        next = await this.nextToken()
      }
      if (next !== '}') throw invalidBackup()
    }
    this.offset++
    if (fields === undefined) return 'null'
    const properties: string[] = []
    fields.forEach((value: string, key: string): void => { properties.push(JSON.stringify(key) + ':' + value) })
    return '{' + properties.join(',') + '}'
  }

  private async readArray(depth: number): Promise<void> {
    this.offset++
    if (await this.nextToken() !== ']') {
      for (;;) {
        await this.readValue(false, false, MetadataSection.Skip, depth + 1)
        const next = await this.nextToken()
        if (next === ']') break
        if (next !== ',') throw invalidBackup()
        this.offset++
      }
    }
    this.offset++
  }

  private async readValue(keep: boolean, keepString: boolean, section: MetadataSection, depth: number): Promise<string> {
    if (depth > MAX_JSON_DEPTH) throw invalidBackup()
    const char = await this.nextToken()
    if (char === '"') return this.readString(keepString)
    if (char === '{') {
      return this.readObject(section, depth)
    }
    if (char === '[') {
      await this.readArray(depth)
      return 'null'
    }
    const value = await this.readScalar()
    return keep ? value : 'null'
  }

  private async readScalar(): Promise<string> {
    let value = ''
    while (await this.fill()) {
      const start = this.offset
      while (this.offset < this.chunk.length && /[0-9a-zE+.\-]/.test(this.chunk[this.offset])) this.offset++
      if (value.length + this.offset - start > MAX_METADATA_TOKEN_LENGTH) throw invalidBackup()
      value += this.chunk.slice(start, this.offset)
      if (this.offset < this.chunk.length) break
    }
    if (!/^(?:null|true|false|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)$/.test(value)) throw invalidBackup()
    return value
  }

  private async readString(retain: boolean): Promise<string> {
    this.offset++
    let captured = '"'
    let escaped = false
    let unicodeDigits = 0
    while (await this.fill()) {
      const start = this.offset
      while (this.offset < this.chunk.length) {
        const code = this.chunk.charCodeAt(this.offset++)
        if (unicodeDigits > 0) {
          if (!((code >= 48 && code <= 57) || (code >= 65 && code <= 70) || (code >= 97 && code <= 102))) {
            throw invalidBackup()
          }
          unicodeDigits--
        } else if (escaped) {
          escaped = false
          if (code === 117) unicodeDigits = 4
          else if (!'"\\/bfnrt'.includes(String.fromCharCode(code))) throw invalidBackup()
        } else if (code === 34) {
          return retain && captured.length + this.offset - start <= MAX_METADATA_TOKEN_LENGTH
            ? captured + this.chunk.slice(start, this.offset) : '""'
        } else if (code === 92) {
          escaped = true
        } else if (code < 32) {
          throw invalidBackup()
        }
      }
      if (retain && captured.length + this.offset - start <= MAX_METADATA_TOKEN_LENGTH) {
        captured += this.chunk.slice(start, this.offset)
      } else {
        retain = false
      }
    }
    throw invalidBackup()
  }
}

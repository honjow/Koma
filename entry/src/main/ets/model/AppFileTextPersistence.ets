import { fileIo as fs } from '@kit.CoreFileKit'

/** Commit a complete same-directory sibling before replacing the live app document. */
export function writeAppTextFile(filePath: string, payload: string): void {
  const tempPath = `${filePath}.tmp`
  let file: fs.File | undefined = undefined
  try {
    // The live document stays intact until the complete sibling is committed.
    file = fs.openSync(tempPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC)
    fs.writeSync(file.fd, payload, { encoding: 'utf-8' })
    fs.fsyncSync(file.fd)
    fs.closeSync(file)
    file = undefined
    if (fs.readTextSync(tempPath, { encoding: 'utf-8' }) !== payload) {
      throw new Error('Incomplete app file persistence write')
    }
    fs.renameSync(tempPath, filePath)
  } finally {
    if (file !== undefined) {
      try {
        fs.closeSync(file)
      } catch (_error) {
      }
    }
    try {
      if (fs.accessSync(tempPath)) {
        fs.unlinkSync(tempPath)
      }
    } catch (_error) {
    }
  }
}

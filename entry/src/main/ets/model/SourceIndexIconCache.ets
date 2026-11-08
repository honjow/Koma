import { common } from '@kit.AbilityKit'
import { fileIo as fs } from '@kit.CoreFileKit'

const SOURCE_INDEX_ICON_CACHE_DIRECTORY_NAME: string = 'source-index-icon-cache'

export interface SourceIndexIconCacheStats {
  totalBytes: number
  fileCount: number
}

function directory(context: common.UIAbilityContext): string {
  return context.filesDir + '/' + SOURCE_INDEX_ICON_CACHE_DIRECTORY_NAME
}

function accumulate(path: string, stats: SourceIndexIconCacheStats): void {
  let names: string[] = []
  try {
    names = fs.listFileSync(path)
  } catch (_error) {
    return
  }
  names.forEach((name: string): void => {
    const child = path + '/' + name
    try {
      const info = fs.statSync(child)
      if (info.isDirectory()) {
        accumulate(child, stats)
      } else {
        stats.totalBytes += info.size
        stats.fileCount += 1
      }
    } catch (_error) {
    }
  })
}

export function getSourceIndexIconCacheStats(context: common.UIAbilityContext): SourceIndexIconCacheStats {
  const stats: SourceIndexIconCacheStats = { totalBytes: 0, fileCount: 0 }
  accumulate(directory(context), stats)
  return stats
}

function remove(path: string): void {
  let names: string[] = []
  try {
    names = fs.listFileSync(path)
  } catch (_error) {
    return
  }
  names.forEach((name: string): void => {
    const child = path + '/' + name
    try {
      const info = fs.statSync(child)
      if (info.isDirectory()) {
        remove(child)
        try { fs.rmdirSync(child) } catch (_error) {}
      } else {
        try { fs.unlinkSync(child) } catch (_error) {}
      }
    } catch (_error) {
    }
  })
}

export function clearSourceIndexIconCache(context: common.UIAbilityContext): SourceIndexIconCacheStats {
  const root = directory(context)
  remove(root)
  try { fs.rmdirSync(root) } catch (_error) {}
  return getSourceIndexIconCacheStats(context)
}

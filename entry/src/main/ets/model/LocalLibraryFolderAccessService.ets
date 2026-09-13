import { BusinessError } from '@kit.BasicServicesKit'
import { fileShare } from '@kit.CoreFileKit'
import { Comic } from './ComicModels'
import { localLibraryFolderRootUrisFromComics } from './LocalLibraryFolderContract'

const LOCAL_LIBRARY_FOLDER_AUTHORIZATION_SYSCAP =
  'SystemCapability.FileManagement.AppFileService.FolderAuthorization'

export type LocalLibraryFolderAccessStatus =
  'persisted' |
  'activated' |
  'not_persisted' |
  'unsupported' |
  'failed'

export interface LocalLibraryFolderAccessResult {
  status: LocalLibraryFolderAccessStatus
  failureCode?: string
}

export interface LocalLibraryFolderAccessSummary {
  rootCount: number
  activatedCount: number
  notPersistedCount: number
  unsupportedCount: number
  failedCount: number
}

function readPolicy(uri: string): fileShare.PolicyInfo {
  return {
    uri,
    operationMode: fileShare.OperationMode.READ_MODE,
  }
}

function safeFailureCode(error: Object): string {
  const businessError = error as BusinessError
  if (businessError.code !== undefined) {
    return `${businessError.code}`
  }
  return 'unknown'
}

export function canImportLocalLibraryFolder(): boolean {
  return canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')
}

export function canRescanLocalLibraryFolder(): boolean {
  return canImportLocalLibraryFolder() && folderAuthorizationAvailable()
}

function folderAuthorizationAvailable(): boolean {
  return canIUse(LOCAL_LIBRARY_FOLDER_AUTHORIZATION_SYSCAP)
}

export async function persistLocalLibraryFolderAccess(rootUri: string): Promise<LocalLibraryFolderAccessResult> {
  if (!folderAuthorizationAvailable()) {
    return { status: 'unsupported' }
  }
  const policies: fileShare.PolicyInfo[] = [readPolicy(rootUri)]
  try {
    const persisted = await fileShare.checkPersistentPermission(policies)
    if (!persisted[0]) {
      await fileShare.persistPermission(policies)
    }
    await fileShare.activatePermission(policies)
    return { status: persisted[0] ? 'activated' : 'persisted' }
  } catch (error) {
    return {
      status: 'failed',
      failureCode: safeFailureCode(error as Object),
    }
  }
}

export async function activateLocalLibraryFolderAccess(rootUri: string): Promise<LocalLibraryFolderAccessResult> {
  if (!folderAuthorizationAvailable()) {
    return { status: 'unsupported' }
  }
  const policies: fileShare.PolicyInfo[] = [readPolicy(rootUri)]
  try {
    const persisted = await fileShare.checkPersistentPermission(policies)
    if (!persisted[0]) {
      return { status: 'not_persisted' }
    }
    await fileShare.activatePermission(policies)
    return { status: 'activated' }
  } catch (error) {
    return {
      status: 'failed',
      failureCode: safeFailureCode(error as Object),
    }
  }
}

export async function activateLocalLibraryFolderAccessForComics(
  comics: Comic[],
): Promise<LocalLibraryFolderAccessSummary> {
  const rootUris = localLibraryFolderRootUrisFromComics(comics)
  const summary: LocalLibraryFolderAccessSummary = {
    rootCount: rootUris.length,
    activatedCount: 0,
    notPersistedCount: 0,
    unsupportedCount: 0,
    failedCount: 0,
  }
  for (const rootUri of rootUris) {
    const result = await activateLocalLibraryFolderAccess(rootUri)
    if (result.status === 'activated' || result.status === 'persisted') {
      summary.activatedCount += 1
    } else if (result.status === 'not_persisted') {
      summary.notPersistedCount += 1
    } else if (result.status === 'unsupported') {
      summary.unsupportedCount += 1
    } else {
      summary.failedCount += 1
    }
  }
  return summary
}

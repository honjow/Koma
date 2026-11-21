import { cleanImageRuleFiles, materializeImageRuleFiles, stageImageRuleFiles } from './ImageRuleAssetFiles'

@Concurrent
export function stageImageRuleRows(directory: string, payload: string): string {
  return stageImageRuleFiles(directory, payload)
}

@Concurrent
export function readImageRuleRows(directory: string, payload: string): string {
  return materializeImageRuleFiles(directory, payload)
}

@Concurrent
export function pruneImageRuleAssets(directory: string, retainedDigests: string[]): void {
  cleanImageRuleFiles(directory, retainedDigests)
}

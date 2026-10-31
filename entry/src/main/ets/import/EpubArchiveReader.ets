import { taskpool } from '@kit.ArkTS'
import { readEpubImages } from './EpubReadingOrder'

@Concurrent
function parseEpubOnWorker(root: string): string[] { return readEpubImages(root) }

export async function readOrderedEpubImages(extractionDir: string): Promise<string[]> {
  return await taskpool.execute(new taskpool.Task(parseEpubOnWorker, extractionDir)) as string[]
}

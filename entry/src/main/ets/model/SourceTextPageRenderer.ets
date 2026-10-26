import { taskpool } from '@kit.ArkTS'
import { drawing, text } from '@kit.ArkGraphics2D'
import { image } from '@kit.ImageKit'
import { sourceTextParagraph } from './SourceTextPageLayout'

import { SourceTextPage } from './SourceTextPageDescriptor'

/** Native shaping preserves CJK/emoji fallback. Match the adopted Keiyoushi
 * templates' sizes, spacing and whole-comment cutoff; HarmonyOS owns glyph metrics.
 * Run before publishing the chapter page table, off the UI thread, not on page flip.
 */
@Concurrent
export async function renderSourceTextPageWorker(spec: SourceTextPage): Promise<ArrayBuffer> {
  const notes: boolean = spec.template === 'webtoon-author-notes'
  const chapterComments: boolean = spec.template === 'zaimanhua-chapter-comments'
  const width: number = notes ? 1000 : 1080
  const x: number = notes || chapterComments ? 50 : 32
  const padding: number = notes || chapterComments ? 25 : 32
  const layouts: text.Paragraph[] = []
  let height: number = padding
  if (notes) {
    if (spec.heading.length > 0) layouts.push(sourceTextParagraph(spec.heading, width - 2 * x, 36, true, true))
    const body: string = spec.paragraphs.join('\n')
    if (body.length > 0) layouts.push(sourceTextParagraph(body, width - 2 * x, 30, false, true))
    for (const layout of layouts) height += Math.ceil(layout.getHeight())
    height += padding
  } else if (chapterComments) {
    // Keiyoushi's Zaimanhua CommentsInterceptor owns a distinct layout: skip an
    // oversized multiline comment, stop at an oversized single line, and keep
    // the image at least square. Do not substitute DM5's cutoff or dimensions.
    const heading = sourceTextParagraph('章末吐槽：', width - 2 * x, 36, true, false)
    layouts.push(heading)
    height += Math.ceil(heading.getHeight())
    for (const comment of spec.paragraphs) {
      const layout = sourceTextParagraph(comment, width - 2 * x, 30, false, false)
      const lineHeight: number = Math.ceil(layout.getHeight()) + 30
      if (height + lineHeight <= 1920) {
        layouts.push(layout)
        height += lineHeight
      } else if (layout.getLineCount() === 1) {
        break
      }
    }
    height = Math.min(1920, Math.max(width, height + padding))
  } else {
    for (const comment of spec.paragraphs) {
      const layout = sourceTextParagraph(comment, width - 2 * x, 32, false, false)
      const lineHeight: number = Math.ceil(layout.getHeight()) + padding
      if (height + lineHeight > 1920) break
      layouts.push(layout)
      height += lineHeight
    }
  }
  if (height > 16384) throw new Error('source_text_page_too_tall')
  const pixelMap = await image.createPixelMap(new ArrayBuffer(width * height * 4), {
    size: { width, height }, pixelFormat: image.PixelMapFormat.RGBA_8888, editable: true,
    alphaType: image.AlphaType.OPAQUE,
  })
  const packer = image.createImagePacker()
  try {
    const canvas = new drawing.Canvas(pixelMap)
    canvas.drawColor(255, 255, 255, 255)
    let y: number = padding
    for (const layout of layouts) {
      layout.paint(canvas, x, y)
      y += Math.ceil(layout.getHeight()) + (notes ? 0 : (chapterComments ? 30 : padding))
    }
    return await packer.packing(pixelMap, { format: 'image/png', quality: 100 })
  } finally {
    await packer.release()
    await pixelMap.release()
  }
}

export function renderSourceTextPage(spec: SourceTextPage): Promise<ArrayBuffer> {
  return taskpool.execute(renderSourceTextPageWorker, spec) as Promise<ArrayBuffer>
}

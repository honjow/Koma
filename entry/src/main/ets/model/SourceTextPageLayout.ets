import { text } from '@kit.ArkGraphics2D'

export function sourceTextParagraph(value: string, width: number, size: number, bold: boolean, notes: boolean): text.Paragraph {
  const style: text.TextStyle = {
    color: { alpha: 255, red: 0, green: 0, blue: 0 },
    fontSize: size,
    fontWeight: bold ? text.FontWeight.W700 : text.FontWeight.W400,
  }
  if (notes) {
    style.heightOnly = true
    style.heightScale = 1.1
    style.lineHeightStyle = text.LineHeightStyle.FONT_HEIGHT
  }
  const builder = new text.ParagraphBuilder({ textStyle: style, lineSpacing: notes ? 2 : 0 },
    text.FontCollection.getGlobalInstance())
  builder.addText(value)
  const result = builder.build()
  result.layoutSync(width)
  return result
}

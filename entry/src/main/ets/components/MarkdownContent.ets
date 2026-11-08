// Ported from the current NextE release-history implementation; native Koma tokens only.
import { ColorMetrics, LengthMetrics } from '@kit.ArkUI'
import { drawing } from '@kit.ArkGraphics2D'
import {
  MarkdownBlock,
  MarkdownDocument,
  MarkdownInline,
  MARKDOWN_BLOCK_BULLET,
  MARKDOWN_BLOCK_CODE,
  MARKDOWN_BLOCK_DIVIDER,
  MARKDOWN_BLOCK_HEADING,
  MARKDOWN_BLOCK_ORDERED,
  MARKDOWN_BLOCK_QUOTE,
} from '../parser/MarkdownDocument'
import { ThemeConstants } from '../theme/ThemeConstants'

function markdownExternalUrl(value: string): string {
  return MarkdownDocument.externalHttpUrl(value)
}

function markdownSpanColor(segment: MarkdownInline, color: ResourceColor): ResourceColor {
  if (markdownExternalUrl(segment.url).length > 0) {
    return $r('sys.color.font_emphasize')
  }
  if (segment.code) {
    return $r('sys.color.font_secondary')
  }
  return segment.quote ? ThemeConstants.TEXT_SECONDARY : color
}

function markdownSpanDecoration(segment: MarkdownInline, underlineLinks: boolean): TextDecorationType {
  if (underlineLinks && markdownExternalUrl(segment.url).length > 0) {
    return TextDecorationType.Underline
  }
  if (segment.strike) {
    return TextDecorationType.LineThrough
  }
  return TextDecorationType.None
}

function markdownSpanWeight(segment: MarkdownInline, emphasized: boolean = false): FontWeight {
  if (segment.bold || emphasized) return FontWeight.Bold
  return segment.code ? FontWeight.Medium : FontWeight.Regular
}

function markdownHeadingSize(level: number): number {
  if (level <= 2) {
    return ThemeConstants.FONT_SIZE_HEADING
  }
  return ThemeConstants.FONT_SIZE_BODY
}

function openMarkdownExternalLink(value: string, onLinkClick: (url: string) => void): void {
  const url: string = markdownExternalUrl(value)
  if (url.length > 0) {
    onLinkClick(url)
  }
}

@Builder
export function MarkdownSpans(
  segments: MarkdownInline[],
  color: ResourceColor,
  emphasized: boolean,
  onLinkClick: (url: string) => void,
  underlineLinks: boolean = true,
) {
  ForEach(segments, (segment: MarkdownInline) => {
    Span(segment.text)
      .fontColor(markdownSpanColor(segment, color))
      .fontWeight(markdownSpanWeight(segment, emphasized))
      .fontStyle(segment.italic ? FontStyle.Italic : FontStyle.Normal)
      .decoration({ type: markdownSpanDecoration(segment, underlineLinks) })
      .onClick(() => {
        openMarkdownExternalLink(segment.url, onLinkClick)
      })
  }, (segment: MarkdownInline) => segment.key)
}

const QUOTE_MARGIN = 10
const QUOTE_RULE_WIDTH = 2

class MarkdownQuoteMargin extends LeadingMarginSpan {
  private marginPx: number
  private widthPx: number

  constructor(marginPx: number, widthPx: number) {
    super()
    this.marginPx = marginPx
    this.widthPx = widthPx
  }

  getLeadingMargin(): LengthMetrics {
    return LengthMetrics.vp(QUOTE_MARGIN)
  }

  onDraw(context: DrawContext, line: LeadingMarginSpanDrawInfo): void {
    const color = ColorMetrics.resourceColor(ThemeConstants.TEXT_TERTIARY)
    const brush = new drawing.Brush()
    brush.setColor(color.alpha, color.red, color.green, color.blue)
    const inset = Math.max(0, line.x - this.marginPx)
    const left = line.direction === TextDirection.RTL ? context.sizeInPixel.width - inset - this.widthPx : inset
    context.canvas.attachBrush(brush)
    context.canvas.drawRect({ left, top: line.top, right: left + this.widthPx, bottom: line.bottom })
    context.canvas.detachBrush()
  }
}

@ComponentV2
export struct MarkdownQuotedSynopsis {
  @Require @Param segments: MarkdownInline[]
  @Param expanded: boolean = false
  @Event onLinkClick: (url: string) => void = (_url: string) => {}
  private controller = new TextController()

  @Monitor('segments')
  private updateText(): void {
    const ui = this.getUIContext()
    const paragraph = new ParagraphStyle({ leadingMarginSpan:
      new MarkdownQuoteMargin(ui.vp2px(QUOTE_MARGIN), ui.vp2px(QUOTE_RULE_WIDTH)) })
    const value = this.segments.map((segment: MarkdownInline): string => segment.text).join('')
    const styled = new MutableStyledString(value, [])
    let offset = 0
    let quoteStart = -1
    for (const segment of this.segments) {
      if (segment.quote && quoteStart < 0) quoteStart = offset
      if (!segment.quote && quoteStart >= 0) {
        this.applyQuote(styled, paragraph, quoteStart, offset)
        quoteStart = -1
      }
      const length = segment.text.length
      styled.setStyle({ start: offset, length, styledKey: StyledStringKey.FONT,
        styledValue: new TextStyle({ fontColor: markdownSpanColor(segment, ThemeConstants.TEXT_PRIMARY),
          fontWeight: markdownSpanWeight(segment), fontStyle: segment.italic ? FontStyle.Italic : FontStyle.Normal,
          fontSize: LengthMetrics.fp(ThemeConstants.FONT_SIZE_BODY) }) })
      if (segment.strike) {
        styled.setStyle({ start: offset, length, styledKey: StyledStringKey.DECORATION,
          styledValue: new DecorationStyle({ type: TextDecorationType.LineThrough }) })
      }
      if (markdownExternalUrl(segment.url).length > 0) {
        styled.setStyle({ start: offset, length, styledKey: StyledStringKey.GESTURE,
          styledValue: new GestureStyle({ onClick: () => { openMarkdownExternalLink(segment.url, this.onLinkClick) } }) })
      }
      offset += length
    }
    if (quoteStart >= 0) this.applyQuote(styled, paragraph, quoteStart, offset)
    this.controller.setStyledString(styled)
  }

  private applyQuote(styled: MutableStyledString, paragraph: ParagraphStyle, start: number, end: number): void {
    // The margin draws with the native line layout, leaving one selectable
    // text node and no decoration characters in the copied text.
    styled.setStyle({ start, length: end - start, styledKey: StyledStringKey.PARAGRAPH_STYLE, styledValue: paragraph })
  }

  build() {
    Text(undefined, { controller: this.controller })
      .width('100%')
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .lineHeight(ThemeConstants.LINE_HEIGHT_TITLE)
      .maxLines(this.expanded ? undefined : 3)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .copyOption(CopyOptions.LocalDevice)
      .animation({ duration: 180, curve: Curve.EaseInOut })
      .onAppear(() => { this.updateText() })
  }
}

// These helpers are global on purpose. `MarkdownContent` can be mounted through a V2 dialog's
// @BuilderParam; a global builder does not rely on an instance `this` surviving that boundary.
@Builder
function MarkdownInlineText(
  segments: MarkdownInline[],
  fontSize: number,
  color: ResourceColor,
  emphasized: boolean,
  onLinkClick: (url: string) => void,
) {
  Text() {
    MarkdownSpans(segments, color, emphasized, onLinkClick)
  }
  .fontSize(fontSize)
  .fontColor(color)
  .width('100%')
}

@Builder
function MarkdownPrefixedBlockView(
  block: MarkdownBlock,
  leftPadding: number,
  onLinkClick: (url: string) => void,
) {
  Row({ space: ThemeConstants.SPACE_XS }) {
    Text(block.prefix)
      .fontSize(ThemeConstants.FONT_SIZE_BODY)
      .fontColor($r('sys.color.font_secondary'))
    Text() {
      MarkdownSpans(
        block.segments,
        $r('sys.color.font_secondary'),
        false,
        onLinkClick,
      )
    }
    .fontSize(ThemeConstants.FONT_SIZE_BODY)
    .fontColor($r('sys.color.font_secondary'))
    .layoutWeight(1)
  }
  .width('100%')
  .alignItems(VerticalAlign.Top)
  .padding({ left: leftPadding })
}

@Builder
function MarkdownBlockView(block: MarkdownBlock, onLinkClick: (url: string) => void) {
  if (block.kind === MARKDOWN_BLOCK_HEADING) {
    MarkdownInlineText(
      block.segments,
      markdownHeadingSize(block.level),
      $r('sys.color.font_primary'),
      true,
      onLinkClick,
    )
  } else if (block.kind === MARKDOWN_BLOCK_BULLET || block.kind === MARKDOWN_BLOCK_ORDERED) {
    MarkdownPrefixedBlockView(
      block,
      block.indent * ThemeConstants.SPACE_MD,
      onLinkClick,
    )
  } else if (block.kind === MARKDOWN_BLOCK_QUOTE) {
    MarkdownPrefixedBlockView(block, ThemeConstants.SPACE_SM, onLinkClick)
  } else if (block.kind === MARKDOWN_BLOCK_CODE) {
    Text(block.text)
      .fontSize(ThemeConstants.FONT_SIZE_CAPTION)
      .fontColor($r('sys.color.font_secondary'))
      .fontWeight(FontWeight.Medium)
      .width('100%')
  } else if (block.kind === MARKDOWN_BLOCK_DIVIDER) {
    Divider()
      .strokeWidth(0.5)
      .color($r('sys.color.ohos_id_color_list_separator'))
  } else {
    MarkdownInlineText(
      block.segments,
      ThemeConstants.FONT_SIZE_BODY,
      $r('sys.color.font_secondary'),
      false,
      onLinkClick,
    )
  }
}

/**
 * Shared native ArkUI Markdown renderer.
 *
 * The input stays raw Markdown so pages do not need their own parser, model,
 * rich-span loop, or block layout. Link ownership remains with the host via
 * `onLinkClick`; only external HTTP(S) URLs are emitted.
 */
@ComponentV2
export struct MarkdownContent {
  @Param markdown: string = ''
  @Event onLinkClick: (url: string) => void = (_url: string) => {}

  private blocks(): MarkdownBlock[] {
    return MarkdownDocument.parse(this.markdown)
  }

  build() {
    Column({ space: ThemeConstants.SPACE_SM }) {
      ForEach(
        this.blocks(),
        (block: MarkdownBlock) => {
          MarkdownBlockView(block, this.onLinkClick)
        },
        (block: MarkdownBlock) => block.key,
      )
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

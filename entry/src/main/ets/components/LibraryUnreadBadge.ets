import { ThemeConstants } from '../theme/ThemeConstants'
import { ColorMetrics, UIContext } from '@kit.ArkUI'
import { coverMainColor } from '../model/CoverMainColor'

const BADGE_SIZE: number = 20
const BADGE_INSET: number = 4

function badgeBackdropHeight(context: UIContext): number {
  return context.px2vp(context.fp2px(BADGE_SIZE))
}

function badgeBackdropWidth(count: number, context: UIContext): number {
  if (count < 10) return badgeBackdropHeight(context)
  // Native text measurement supplies geometry only; it creates no Text node.
  const textWidth = context.getMeasureUtils().measureText({ textContent: `${count}`,
    fontSize: `${ThemeConstants.FONT_SIZE_TAG}fp`, fontWeight: FontWeight.Medium })
  return Math.max(badgeBackdropHeight(context), context.px2vp(textWidth) + 12)
}

// Badge owns the digits, visibility and layout. Only its translucent surface
// samples the cover beneath it; never blur the Badge container or its text.
// Match ArkUI's numeric badge geometry (one-digit circle, otherwise 6vp padding):
// frameworks/core/components_ng/pattern/badge/badge_layout_algorithm.cpp.
@Builder
export function libraryUnreadBadgeBackdrop(count: number | undefined, context: UIContext) {
  if ((count ?? 0) > 0) {
    // A plain empty surface owns the blur. Badge is the only digit renderer;
    // never add duplicate, transparent or shadow text to imitate its glyphs.
    Row()
      .width(badgeBackdropWidth(count ?? 0, context))
      .height(badgeBackdropHeight(context))
      .borderRadius(badgeBackdropHeight(context) / 2)
      .backdropBlur(10)
      .shadow(ShadowStyle.OUTER_DEFAULT_XS)
      .position({ x: BADGE_INSET, y: BADGE_INSET })
      .hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
  }
}

// Shared native Badge configuration for both bookshelf cover presentations.
export function libraryUnreadBadgeOptions(count: number | undefined, color: ResourceColor,
  coverKey: string = ''): BadgeParamWithNumber {
  const background = ColorMetrics.resourceColor(coverMainColor(coverKey, color))
  return {
    count: count ?? 0,
    maxCount: 2147483647,
    position: { x: BADGE_INSET, y: BADGE_INSET },
    style: {
      color: ThemeConstants.TEXT_ON_BRAND,
      fontSize: ThemeConstants.FONT_SIZE_TAG,
      fontWeight: FontWeight.Medium,
      badgeSize: BADGE_SIZE,
      // The user's 50% transparency applies to the surface, not the digits.
      badgeColor: ColorMetrics.rgba(background.red, background.green, background.blue, 0.5).color,
      borderColor: color,
      borderWidth: 0,
    },
  }
}

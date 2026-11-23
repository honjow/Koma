import { ThemeConstants } from '../theme/ThemeConstants'
import { ColorMetrics, UIContext } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import { coverMainColor } from '../model/CoverMainColor'

const BADGE_SIZE: number = 20
export const BADGE_INSET: number = 4
export const UNREAD_BADGE_BLUR_RADIUS: number = 10
// The shelf defaults to a translucent surface. Retain the tested, cropped
// frosting for a deliberate change to the grid appearance.
export const LIBRARY_UNREAD_BADGE_FROSTING_ENABLED: boolean = false

export function badgeBackdropHeight(context: UIContext): number {
  return context.px2vp(context.fp2px(BADGE_SIZE))
}

export function badgeBackdropWidth(count: number, context: UIContext): number {
  if (count < 10) return badgeBackdropHeight(context)
  // Native text measurement supplies geometry only; it creates no Text node.
  const textWidth = context.getMeasureUtils().measureText({ textContent: `${count}`,
    fontSize: `${ThemeConstants.FONT_SIZE_TAG}fp`, fontWeight: FontWeight.Medium })
  return Math.max(badgeBackdropHeight(context), context.px2vp(textWidth) + 12)
}

// Badge owns the digits, visibility and layout. Optional frosting is drawn
// below the Badge. The shadow uses the same capsule geometry in either mode.
// Match ArkUI's numeric badge geometry (one-digit circle, otherwise 6vp padding):
// frameworks/core/components_ng/pattern/badge/badge_layout_algorithm.cpp.
interface LibraryUnreadBadgeBackdropParams {
  count: number | undefined
  context: UIContext
  blurredCover?: image.PixelMap
}

// One object literal passed by reference is required here. A multi-argument
// value builder freezes the old count when Repeat reuses a card: its blur can
// retain the previous width or survive count=0 after the native digits vanish.
@Builder
export function libraryUnreadBadgeBackdrop($$: LibraryUnreadBadgeBackdropParams) {
  if (($$.count ?? 0) > 0) {
    // Badge is the only digit renderer.
    Stack() {
      if ($$.blurredCover !== undefined) {
        Image($$.blurredCover)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Fill)
          .interpolation(ImageInterpolation.Medium)
      }
    }
      .width(badgeBackdropWidth($$.count ?? 0, $$.context))
      .height(badgeBackdropHeight($$.context))
      .borderRadius(badgeBackdropHeight($$.context) / 2)
      .clip($$.blurredCover !== undefined)
      // A centered, unfilled shadow adds contrast along the capsule edge.
      .shadow({ radius: $$.context.vp2px(5), color: '#99000000', fill: false })
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
      // Give the surface 80% opacity and keep the digits at their native opacity.
      badgeColor: ColorMetrics.rgba(background.red, background.green, background.blue, 0.8).color,
      borderColor: color,
      borderWidth: 0,
    },
  }
}

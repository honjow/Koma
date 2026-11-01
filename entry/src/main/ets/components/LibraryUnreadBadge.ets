import { ThemeConstants } from '../theme/ThemeConstants'
import { ColorMetrics } from '@kit.ArkUI'

// Shared native Badge configuration for both bookshelf cover presentations.
export function libraryUnreadBadgeOptions(count: number | undefined, color: ResourceColor): BadgeParamWithNumber {
  const background = ColorMetrics.resourceColor(color)
  return {
    count: count ?? 0,
    maxCount: 2147483647,
    position: { x: 4, y: 4 },
    style: {
      color: ThemeConstants.TEXT_ON_BRAND,
      fontSize: ThemeConstants.FONT_SIZE_TAG,
      fontWeight: FontWeight.Medium,
      badgeSize: 20,
      // The user's 50% transparency applies to the surface, not the digits.
      badgeColor: ColorMetrics.rgba(background.red, background.green, background.blue, 0.5).color,
      borderColor: color,
      borderWidth: 0,
    },
  }
}

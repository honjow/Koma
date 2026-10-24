import { ThemeConstants } from '../theme/ThemeConstants'

// Shared native Badge configuration for both bookshelf cover presentations.
export function libraryUnreadBadgeOptions(count: number | undefined, color: ResourceColor): BadgeParamWithNumber {
  return {
    count: count ?? 0,
    maxCount: 2147483647,
    position: { x: 4, y: 4 },
    style: {
      color: ThemeConstants.TEXT_ON_BRAND,
      fontSize: ThemeConstants.FONT_SIZE_TAG,
      fontWeight: FontWeight.Medium,
      badgeSize: 20,
      badgeColor: color,
      borderColor: color,
      borderWidth: 0,
    },
  }
}

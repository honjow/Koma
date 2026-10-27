/** Host-owned protocol support. Sources must not expose options requiring an absent host feature. */
export function sourceHostFeatures(): string[] {
  // New templates require their own feature: an older text_page_image_v1 host
  // cannot render them, even if a saved source preference remains enabled.
  return ['text_page_image_v1', 'source_rate_limit_v1', 'text_page_image_zaimanhua_comments_v1', 'source_text_page_request_v1', 'source_setting_observations_v1', 'source_chapter_exclusions_v1']
}

export function sourceRequestWithHostFeatures(requestJson: string): string {
  try {
    const request = JSON.parse(requestJson) as Record<string, Object>
    if (request !== null && !Array.isArray(request) &&
      (request['operation'] === 'get_settings' || request['operation'] === 'get_chapters' || request['operation'] === 'get_pages' ||
        request['operation'] === 'get_image_request')) {
      request['hostFeatures'] = sourceHostFeatures()
      return JSON.stringify(request)
    }
  } catch (_error) {
    // Original admission owns malformed requests and their existing reason codes.
  }
  return requestJson
}

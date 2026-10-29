/** Host-owned protocol support. Sources must not expose options requiring an absent host feature. */
export function sourceHostFeatures(): string[] {
  // New templates require their own feature: an older text_page_image_v1 host
  // cannot render them, even if a saved source preference remains enabled.
  return ['text_page_image_v1', 'source_rate_limit_v1', 'text_page_image_zaimanhua_comments_v1', 'source_text_page_request_v1', 'source_setting_observations_v1', 'source_chapter_exclusions_v1', 'source_setting_uuid_list_v1', 'mangabz_language_cookie_v1', 'source_settings_context_v1', 'source_http_batch_v1', 'source_filter_scope_header_v1', 'source_filter_fetching_v1', 'source_filter_tristate_v1', 'chapter_reading_order_v1', 'source_private_session_v1']
}

export function sourceRequestWithHostFeatures(requestJson: string, challengeCause: boolean = false,
  detailChapterContext: boolean = false): string {
  try {
    const request = JSON.parse(requestJson) as Record<string, Object>
    if (request !== null && !Array.isArray(request) &&
      ['search', 'get_manga', 'get_listings', 'get_manga_list', 'get_home', 'get_filters',
        'get_settings', 'get_chapters', 'get_pages', 'get_image_request'].includes(request['operation'] as string)) {
      // Request-scoped preferences can affect metadata as well as pages. All
      // consumers must see the same support; an old Host keeps its old output.
      const features = sourceHostFeatures()
      if (challengeCause) features.push('source_http_challenge_cause_v1')
      if (detailChapterContext) features.push('source_detail_chapter_context_v1')
      request['hostFeatures'] = features
      return JSON.stringify(request)
    }
  } catch (_error) {
    // Original admission owns malformed requests and their existing reason codes.
  }
  return requestJson
}

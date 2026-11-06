import { deviceInfo } from '@kit.BasicServicesKit'
import { COPY_MANGA_API_FEATURE, COPY_MANGA_API_MIN_SDK } from './CopyMangaHostContract'

/** Host-owned protocol support. Sources must not expose options requiring an absent host feature. */
export function sourceHostFeatures(): string[] {
  // New templates require their own feature: an older text_page_image_v1 host
  // cannot render them, even if a saved source preference remains enabled.
  // The legacy rate-limit feature only guaranteed Manhuagui's rules. BuonDua
  // requires its explicit capability, not an inference from that older flag.
  return ['text_page_image_v1', 'source_rate_limit_v1', 'source_rate_limit_buondua_v1', 'text_page_image_zaimanhua_comments_v1', 'source_text_page_request_v1', 'source_setting_observations_v1', 'source_chapter_exclusions_v1', 'source_setting_uuid_list_v1', 'mangabz_language_cookie_v1', 'mangabz_mirror_session_v1', 'source_settings_context_v1', 'source_http_batch_v1', 'source_filter_scope_header_v1', 'source_filter_fetching_v1', 'source_filter_tristate_v1', 'chapter_reading_order_v1', 'source_private_session_v1', 'source_page_image_processing_v1', 'source_baozi_chapter_identity_v1', 'source_java_regex_v1', 'source_page_text_overlay_v1', 'source_authentication_v1', 'source_private_session_process_v1', 'source_private_session_replace_v1', 'source_required_image_decode_jm_stripes_v1', 'source_rate_limit_jm_v1', 'source_rate_limit_hentaiclub_v1', 'source_rate_limit_wnacg_v1', 'source_setting_positive_integer_v1', 'source_dns_pica_channel_v1']
}

export function sourceRequestWithHostFeatures(requestJson: string, challengeCause: boolean = false,
  detailChapterContext: boolean = false): string {
  try {
    const request = JSON.parse(requestJson) as Record<string, Object>
    if (request !== null && !Array.isArray(request) &&
      ['search', 'get_manga', 'get_listings', 'get_manga_list', 'get_home', 'get_filters',
        'get_settings', 'get_chapters', 'get_pages', 'get_image_request',
        'get_authentication', 'authenticate', 'logout'].includes(request['operation'] as string)) {
      // Request-scoped preferences can affect metadata as well as pages. All
      // consumers must see the same support; an old Host keeps its old output.
      const features = sourceHostFeatures()
      features.push('source_public_cover_user_agent_v1')
      if ((deviceInfo?.sdkApiVersion ?? 0) >= COPY_MANGA_API_MIN_SDK) features.push(COPY_MANGA_API_FEATURE)
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

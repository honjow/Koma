import { deviceInfo } from '@kit.BasicServicesKit'
import { SOURCE_FRESH_HTTP_MIN_SDK } from './SourceWebsitePolicy'
import { SOURCE_IMAGE_PROCESSOR_FEATURE } from './SourceRequiredImageDecodeDeclaration'

interface SourceBodyLimits { chunkBytes: number; maxBytes: number; callBytes: number; callObjects: number }
interface SourceHttpLimits { inlineBytes: number; requestBytes: number }
interface SourceCapabilityLimits { version: number; body: SourceBodyLimits; http: SourceHttpLimits }

/** Host-owned protocol support. Sources must not expose options requiring an absent host feature. */
export function sourceHostFeatures(): string[] {
  // Unreleased Web HTTP v1 covers the existing text/bytes/reference wire kinds.
  // Reference operations remain conditional on BodyHost below; this feature
  // never grants a Web session or widens the uniformly 1 MiB Web upload cap.
  // New templates require their own feature: an older text_page_image_v1 host
  // cannot render them, even if a saved source preference remains enabled.
  return ['text_page_image_v1', 'text_page_image_zaimanhua_comments_v1', 'source_text_page_request_v1', 'source_setting_observations_v1', 'source_chapter_exclusions_v1', 'source_setting_uuid_list_v1', 'source_public_cookie_override_v1', 'source_homepage_choices_v1', 'source_settings_context_v1', 'source_http_batch_v1', 'source_filter_scope_header_v1', 'source_filter_fetching_v1', 'source_filter_tristate_v1', 'chapter_reading_order_v1', 'chapter_reading_variants_v1', 'source_private_session_v1', 'source_page_image_processing_v1', 'source_chapter_identity_v1', 'source_java_regex_v1', 'source_page_text_overlay_v1', 'source_authentication_v1', 'source_private_session_process_v1', 'source_private_session_replace_v1', 'source_required_image_decode_jm_stripes_v1', 'source_setting_positive_integer_v1', 'source_dns_bootstrap_v1',
    'source_anonymous_http_v1', 'source_native_cookie_session_v1', 'source_http_response_url_v1',
    'source_http_response_metadata_v1', 'source_web_token_v1',
    'source_http_bytes_v1', 'source_http_cookie_session_v1',
    'source_http_headers_v1', 'source_http_request_bytes_v1',
    'source_related_manga_v1', 'source_manga_list_info_v1', 'source_image_response_errors_v1', 'source_web_document_handoff_v1',
    'source_web_fetch_bridge_v1', 'source_web_http_v1', 'source_comments_v1', SOURCE_IMAGE_PROCESSOR_FEATURE]
}

export function sourceRequestWithHostFeatures(requestJson: string, challengeCause: boolean = false,
  detailChapterContext: boolean = false, requestLimitsDeclared: boolean = false, bodyAvailable: boolean = false): string {
  try {
    const request = JSON.parse(requestJson) as Record<string, Object>
    if (request !== null && !Array.isArray(request) &&
      ['search', 'get_manga', 'get_listings', 'get_manga_list', 'get_home', 'get_filters',
        'get_settings', 'get_chapters', 'get_pages', 'get_comments', 'get_image_request',
        'get_authentication', 'authenticate', 'logout'].includes(request['operation'] as string)) {
      // Request-scoped preferences can affect metadata as well as pages. All
      // consumers must see the same support; an old Host keeps its old output.
      const features = sourceHostFeatures()
      if (bodyAvailable) features.push('source_body_v1', 'source_http_body_v1', 'source_image_body_v1')
      features.push('source_public_cover_user_agent_v1')
      features.push('source_public_cover_client_headers_v1')
      features.push('source_filter_search_without_query_v1')
      features.push('source_listing_filter_scope_v1')
      if ((deviceInfo?.sdkApiVersion ?? 0) >= SOURCE_FRESH_HTTP_MIN_SDK) features.push('source_http_profiles_v1')
      if (challengeCause) features.push('source_http_challenge_cause_v1')
      if (detailChapterContext) features.push('source_detail_chapter_context_v1')
      if (requestLimitsDeclared) features.push('source_request_limits_v1')
      const hints = request['hostHints'] as Record<string, Object> | undefined
      if (challengeCause && request['operation'] === 'search' && hints?.['interactionResumeSupported'] === true) {
        features.push('source_interaction_resume_v1')
      }
      request['hostFeatures'] = features
      // Limits are part of the versioned operation contract, not SDK guesses.
      const limits: SourceCapabilityLimits = { version: 1, body: { chunkBytes: 65536, maxBytes: 134217728,
        callBytes: 268435456, callObjects: 16 }, http: { inlineBytes: 1048576, requestBytes: 1048576 } }
      request['hostCapabilities'] = limits
      return JSON.stringify(request)
    }
  } catch (_error) {
    // Original admission owns malformed requests and their existing reason codes.
  }
  return requestJson
}

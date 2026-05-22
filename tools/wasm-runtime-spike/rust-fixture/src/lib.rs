#![no_std]

extern crate koma_source_sdk;

use koma_source_sdk::result::ResultBuffer;
use koma_source_sdk::source::{
    self, ChapterId, ChapterListRequest, FiltersRequest, HomeRequest, ImageRequestInput,
    JsonPayload, ListingsRequest, MangaId, MangaListRequest, SearchRequest, SettingsRequest,
    Source, SourceCapabilities, SourceError, SourceInfo, SourceResult,
};
use koma_source_sdk::request::contains_bytes;

static mut RESPONSE: ResultBuffer<8192> = ResultBuffer::new();
static mut TEST_BOUNDARY_RESPONSE: [u8; 64] = [0; 64];
static FIXTURE_SOURCE: FixtureSource = FixtureSource;

const MANGA_ID: &[u8] = b"manga:fixture-series";
const CHAPTER_ID: &[u8] = b"chapter:fixture-series:001";
const LISTING_ID_POPULAR: &[u8] = b"listing:popular";
const LISTING_ID_HTTP_FIXTURE: &[u8] = b"listing:http-fixture";
const LISTING_ID_HTML_FIXTURE: &[u8] = b"listing:html-fixture";

const SEARCH_DATA: &[u8] =
    br#"{"requestEcho":"fixture","items":[{"id":"manga:fixture-series","title":"Fixture Series","subtitle":"Rust WAMR runtime smoke","cover":{"kind":"none"},"authors":["Koma Fixture"],"status":"unknown","contentRating":"unknown","sourceTags":["fixture"]}],"page":{"nextCursor":null,"hasMore":false}}"#;
const MANGA_DATA: &[u8] =
    br#"{"manga":{"id":"manga:fixture-series","title":"Fixture Series","alternateTitles":["Fixture Manga"],"description":"Rust WAMR runtime smoke detail.","cover":{"kind":"none"},"authors":["Koma Fixture"],"artists":[],"status":"unknown","contentRating":"unknown","language":"zh-Hans","tags":["fixture"],"links":[]}}"#;
const CHAPTERS_DATA: &[u8] =
    br#"{"items":[{"id":"chapter:fixture-series:001","mangaId":"manga:fixture-series","title":"Chapter 1","chapterNumber":"1","volumeNumber":null,"language":"zh-Hans","publishedAt":null,"updatedAt":null,"pageCount":1}],"page":{"nextCursor":null,"hasMore":false}}"#;
const PAGES_DATA: &[u8] =
    br#"{"chapterId":"chapter:fixture-series:001","pages":[{"id":"page:fixture-series:001:0001","index":0,"image":{"kind":"placeholder","label":"fixture-page-1","width":1200,"height":1800}}]}"#;
const LISTINGS_DATA: &[u8] =
    br#"{"listings":[{"id":"listing:popular","name":"Popular","kind":"popular"},{"id":"listing:latest","name":"Latest","kind":"latest"},{"id":"listing:http-fixture","name":"HTTP Fixture","kind":"custom"},{"id":"listing:html-fixture","name":"HTML Fixture","kind":"custom"}]}"#;
const MANGA_LIST_DATA: &[u8] =
    br#"{"listingId":"listing:popular","items":[{"id":"manga:fixture-series","title":"Fixture Series","subtitle":"Browse fixture result","cover":{"kind":"none"},"authors":["Koma Fixture"],"status":"unknown","contentRating":"unknown","sourceTags":["fixture"]}],"page":{"nextCursor":null,"hasMore":false}}"#;
const HTTP_MANGA_LIST_DATA: &[u8] =
    br#"{"listingId":"listing:http-fixture","items":[{"id":"manga:http-fixture-series","title":"HTTP Fixture Series","subtitle":"Host import static fixture result","cover":{"kind":"none"},"authors":["Koma Fixture"],"status":"unknown","contentRating":"unknown","sourceTags":["fixture","http-host-import-v0.1"]}],"page":{"nextCursor":null,"hasMore":false},"httpFixture":{"allowed":true,"deniedHost":"host_not_allowed","deniedCredentialHeader":"credential_header_denied","networkPerformed":false}}"#;
const HTML_MANGA_LIST_DATA: &[u8] =
    br#"{"listingId":"listing:html-fixture","items":[{"id":"manga:html-fixture-series","title":"HTML Fixture Series","subtitle":"Host HTML parse fixture result","cover":{"kind":"none"},"authors":["Koma Fixture"],"status":"unknown","contentRating":"unknown","sourceTags":["fixture","html-host-import-v0.1"]}],"page":{"nextCursor":null,"hasMore":false},"htmlFixture":{"parse":true,"select":true,"attr":true,"text":true,"chapterId":"chapter:html-fixture-series:001","chapterTitle":"Chapter 1","pageId":"page:html-fixture-series:001:0001","unsupportedSelectorDenied":"unsupported_selector","unsupportedAttrDenied":"attribute_not_allowed","networkPerformed":false}}"#;
const HOME_DATA: &[u8] =
    br#"{"sections":[{"id":"home:featured","title":"Featured","kind":"mangaList","items":[{"id":"manga:fixture-series","title":"Fixture Series","cover":{"kind":"none"}}]},{"id":"home:latest-link","title":"Latest","kind":"listingLink","listingId":"listing:latest"}]}"#;
const FILTERS_DATA: &[u8] =
    br#"{"filters":[{"id":"filter:query","label":"Query","kind":"text"},{"id":"filter:sort","label":"Sort","kind":"sort","options":[{"id":"sort:popular","label":"Popular"},{"id":"sort:latest","label":"Latest"}]}]}"#;
const SETTINGS_DATA: &[u8] =
    br#"{"settings":[{"id":"setting:language","label":"Language","kind":"select","default":"zh-Hans","options":[{"id":"zh-Hans","label":"Chinese"},{"id":"en","label":"English"}]},{"id":"setting:show-adult","label":"Show adult entries","kind":"boolean","default":false},{"id":"setting:display-name","label":"Display name","kind":"string","default":"fixture reader"},{"id":"setting:reader-group","label":"Reader group","kind":"group","children":["setting:language","setting:show-adult","setting:display-name"]},{"id":"setting:login-reference","label":"Login reference","kind":"loginRef","loginRefKey":"login:primary"}]}"#;
const IMAGE_REQUEST_DATA: &[u8] =
    br#"{"imageRequest":{"id":"image-request:fixture-page-1","url":"fixture-image:fixture-page-1","method":"GET","headersRef":"headers:image:fixture-page-1","credentialsRef":"credentials:image:primary","sessionRef":"session:image:primary","cacheKey":"image-cache:fixture-page-1","requiresAuth":true,"resourceRef":"image-resource:fixture-page-1"}}"#;
const HTTP_ALLOWED_REQUEST: &[u8] =
    br#"{"version":1,"method":"GET","url":"https://fixture.koma.local/manga-list/http-fixture","headers":{"Accept":"application/json"},"bodyBase64":null,"timeoutMs":1000,"responseKind":"bodyJson"}"#;
const HTTP_DENIED_HOST_REQUEST: &[u8] =
    br#"{"version":1,"method":"GET","url":"https://not-fixture.example/manga-list/http-fixture","headers":{"Accept":"application/json"},"bodyBase64":null,"timeoutMs":1000,"responseKind":"bodyJson"}"#;
const HTTP_DENIED_CREDENTIAL_HEADER_REQUEST: &[u8] =
    br#"{"version":1,"method":"GET","url":"https://fixture.koma.local/manga-list/http-fixture","headers":{"Authorization":"redacted"},"bodyBase64":null,"timeoutMs":1000,"responseKind":"bodyJson"}"#;
const HTML_FIXTURE_BODY: &[u8] =
    br#"<section data-koma-fixture="html-host-import-v0"><article class="manga-card" data-id="manga:html-fixture-series"><h3 class="title">HTML Fixture Series</h3><a class="chapter" data-id="chapter:html-fixture-series:001" data-page-id="page:html-fixture-series:001:0001">Chapter 1</a></article></section>"#;

struct FixtureSource;

impl Source for FixtureSource {
    fn info(&self) -> SourceInfo {
        SourceInfo {
            id: "local.test.koma.fixture",
            name: "Koma Rust SDK Fixture",
            version: "0.2.0",
            api_version: "0.2",
            language: "zh-Hans",
            author: "Koma Fixture",
            description: "Rust SDK trait ergonomics fixture.",
            content_rating: "unknown",
        }
    }

    fn capabilities(&self) -> SourceCapabilities {
        SourceCapabilities {
            listings: true,
            manga_list: true,
            home: true,
            filters: true,
            settings: true,
            image_request: true,
            ..SourceCapabilities::CORE
        }
    }

    fn search(&self, request: SearchRequest<'_>) -> SourceResult {
        if request.query_is(b"fixture") {
            Ok(JsonPayload::new(SEARCH_DATA))
        } else {
            Err(SourceError::invalid_request(
                "expected fixture search request",
            ))
        }
    }

    fn get_manga(&self, id: MangaId<'_>) -> SourceResult {
        if id.is(MANGA_ID) {
            Ok(JsonPayload::new(MANGA_DATA))
        } else {
            Err(SourceError::invalid_request(
                "expected fixture manga request",
            ))
        }
    }

    fn get_chapters(&self, request: ChapterListRequest<'_>) -> SourceResult {
        if request.manga_id_is(MANGA_ID) {
            Ok(JsonPayload::new(CHAPTERS_DATA))
        } else {
            Err(SourceError::invalid_request(
                "expected fixture chapters request",
            ))
        }
    }

    fn get_pages(&self, id: ChapterId<'_>) -> SourceResult {
        if id.is(CHAPTER_ID) {
            Ok(JsonPayload::new(PAGES_DATA))
        } else {
            Err(SourceError::invalid_request(
                "expected fixture pages request",
            ))
        }
    }

    fn get_listings(&self, _request: ListingsRequest<'_>) -> SourceResult {
        Ok(JsonPayload::new(LISTINGS_DATA))
    }

    fn get_manga_list(&self, request: MangaListRequest<'_>) -> SourceResult {
        if request.listing_id_is(LISTING_ID_POPULAR) {
            Ok(JsonPayload::new(MANGA_LIST_DATA))
        } else if request.listing_id_is(LISTING_ID_HTTP_FIXTURE) && http_fixture_policy_smoke() {
            Ok(JsonPayload::new(HTTP_MANGA_LIST_DATA))
        } else if request.listing_id_is(LISTING_ID_HTML_FIXTURE) && html_fixture_policy_smoke() {
            Ok(JsonPayload::new(HTML_MANGA_LIST_DATA))
        } else {
            Err(SourceError::invalid_request(
                "expected fixture listing request",
            ))
        }
    }

    fn get_home(&self, _request: HomeRequest<'_>) -> SourceResult {
        Ok(JsonPayload::new(HOME_DATA))
    }

    fn get_filters(&self, _request: FiltersRequest<'_>) -> SourceResult {
        Ok(JsonPayload::new(FILTERS_DATA))
    }

    fn get_settings(&self, _request: SettingsRequest<'_>) -> SourceResult {
        Ok(JsonPayload::new(SETTINGS_DATA))
    }

    fn get_image_request(&self, request: ImageRequestInput<'_>) -> SourceResult {
        if request.page_id_is(b"page:fixture-series:001:0001") {
            Ok(JsonPayload::new(IMAGE_REQUEST_DATA))
        } else {
            Err(SourceError::invalid_request(
                "expected fixture image request",
            ))
        }
    }
}

fn http_fixture_policy_smoke() -> bool {
    let mut output = [0_u8; 2048];
    let Ok(allowed_len) = koma_source_sdk::host::http_request(HTTP_ALLOWED_REQUEST, &mut output)
    else {
        return false;
    };
    let allowed = unsafe { core::slice::from_raw_parts(output.as_ptr(), allowed_len) };
    if !contains_bytes(allowed, br#""ok":true"#)
        || !contains_bytes(allowed, br#""status":200"#)
        || !contains_bytes(allowed, br#""bodyJson""#)
        || !contains_bytes(allowed, b"HTTP Fixture Series")
        || !contains_bytes(allowed, br#""networkPerformed":false"#)
    {
        return false;
    }

    let Ok(denied_host_len) =
        koma_source_sdk::host::http_request(HTTP_DENIED_HOST_REQUEST, &mut output)
    else {
        return false;
    };
    let denied_host = unsafe { core::slice::from_raw_parts(output.as_ptr(), denied_host_len) };
    if !contains_bytes(denied_host, br#""ok":false"#)
        || !contains_bytes(denied_host, br#""code":"host_not_allowed""#)
    {
        return false;
    }

    let Ok(denied_header_len) =
        koma_source_sdk::host::http_request(HTTP_DENIED_CREDENTIAL_HEADER_REQUEST, &mut output)
    else {
        return false;
    };
    let denied_header = unsafe { core::slice::from_raw_parts(output.as_ptr(), denied_header_len) };
    contains_bytes(denied_header, br#""ok":false"#)
        && contains_bytes(denied_header, br#""code":"credential_header_denied""#)
}

fn bytes_equal(left: &[u8], right: &[u8]) -> bool {
    left.len() == right.len() && contains_bytes(left, right)
}

fn html_fixture_policy_smoke() -> bool {
    let Ok(document) = koma_source_sdk::host::html_parse(HTML_FIXTURE_BODY) else {
        return false;
    };
    let Ok(card) = koma_source_sdk::host::html_select(document, b"article.manga-card") else {
        let _ = koma_source_sdk::host::html_close(document);
        return false;
    };
    let Ok(title) = koma_source_sdk::host::html_select(card, b"h3.title") else {
        let _ = koma_source_sdk::host::html_close(card);
        let _ = koma_source_sdk::host::html_close(document);
        return false;
    };
    let Ok(chapter) = koma_source_sdk::host::html_select(card, b"a.chapter") else {
        let _ = koma_source_sdk::host::html_close(title);
        let _ = koma_source_sdk::host::html_close(card);
        let _ = koma_source_sdk::host::html_close(document);
        return false;
    };

    let mut output = [0_u8; 128];
    let Ok(manga_id_len) = koma_source_sdk::host::html_attr(card, b"data-id", &mut output)
    else {
        return false;
    };
    let manga_id = unsafe { core::slice::from_raw_parts(output.as_ptr(), manga_id_len) };
    if !bytes_equal(manga_id, b"manga:html-fixture-series") {
        return false;
    }

    let Ok(title_len) = koma_source_sdk::host::html_text(title, &mut output) else {
        return false;
    };
    let title_text = unsafe { core::slice::from_raw_parts(output.as_ptr(), title_len) };
    if !bytes_equal(title_text, b"HTML Fixture Series") {
        return false;
    }

    let Ok(chapter_id_len) = koma_source_sdk::host::html_attr(chapter, b"data-id", &mut output)
    else {
        return false;
    };
    let chapter_id = unsafe { core::slice::from_raw_parts(output.as_ptr(), chapter_id_len) };
    if !bytes_equal(chapter_id, b"chapter:html-fixture-series:001") {
        return false;
    }

    let Ok(chapter_title_len) = koma_source_sdk::host::html_text(chapter, &mut output) else {
        return false;
    };
    let chapter_title = unsafe { core::slice::from_raw_parts(output.as_ptr(), chapter_title_len) };
    if !bytes_equal(chapter_title, b"Chapter 1") {
        return false;
    }

    let Ok(page_id_len) = koma_source_sdk::host::html_attr(chapter, b"data-page-id", &mut output)
    else {
        return false;
    };
    let page_id = unsafe { core::slice::from_raw_parts(output.as_ptr(), page_id_len) };
    if !bytes_equal(page_id, b"page:html-fixture-series:001:0001") {
        return false;
    }

    let unsupported_selector_denied =
        koma_source_sdk::host::html_select(document, b"script").is_err();
    let unsupported_attr_denied =
        koma_source_sdk::host::html_attr(card, b"href", &mut output).is_err();

    let _ = koma_source_sdk::host::html_close(chapter);
    let _ = koma_source_sdk::host::html_close(title);
    let _ = koma_source_sdk::host::html_close(card);
    let _ = koma_source_sdk::host::html_close(document);

    unsupported_selector_denied && unsupported_attr_denied
}

#[panic_handler]
fn panic(_: &core::panic::PanicInfo<'_>) -> ! {
    loop {}
}

fn response_buffer() -> &'static mut ResultBuffer<8192> {
    unsafe { &mut *core::ptr::addr_of_mut!(RESPONSE) }
}

fn test_boundary_response() -> *mut u8 {
    core::ptr::addr_of_mut!(TEST_BOUNDARY_RESPONSE) as *mut u8
}

#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn koma_source_init(_manifest_ptr: u32, manifest_len: u32) -> i32 {
    source::init(
        &FIXTURE_SOURCE,
        manifest_len,
        b"rust fixture init reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_info() -> u32 {
    source::source_info(&FIXTURE_SOURCE, response_buffer())
}

#[no_mangle]
pub extern "C" fn koma_source_search(req_ptr: u32, req_len: u32) -> u32 {
    source::search(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture search reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_manga(req_ptr: u32, req_len: u32) -> u32 {
    source::get_manga(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_manga reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_chapters(req_ptr: u32, req_len: u32) -> u32 {
    source::get_chapters(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_chapters reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_pages(req_ptr: u32, req_len: u32) -> u32 {
    source::get_pages(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_pages reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_listings(req_ptr: u32, req_len: u32) -> u32 {
    source::get_listings(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_listings reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_manga_list(req_ptr: u32, req_len: u32) -> u32 {
    source::get_manga_list(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_manga_list reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_home(req_ptr: u32, req_len: u32) -> u32 {
    source::get_home(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_home reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_filters(req_ptr: u32, req_len: u32) -> u32 {
    source::get_filters(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_filters reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_settings(req_ptr: u32, req_len: u32) -> u32 {
    source::get_settings(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_settings reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_source_get_image_request(req_ptr: u32, req_len: u32) -> u32 {
    source::get_image_request(
        &FIXTURE_SOURCE,
        response_buffer(),
        req_ptr,
        req_len,
        b"rust fixture get_image_request reached host imports",
    )
}

#[no_mangle]
pub extern "C" fn koma_test_oversized_result() -> u32 {
    let base = test_boundary_response();
    unsafe {
        core::ptr::copy_nonoverlapping(0x4B4F4D41_u32.to_le_bytes().as_ptr(), base, 4);
        core::ptr::copy_nonoverlapping(1_u32.to_le_bytes().as_ptr(), base.add(4), 4);
        core::ptr::copy_nonoverlapping(1_048_577_u32.to_le_bytes().as_ptr(), base.add(8), 4);
        core::ptr::copy_nonoverlapping(0_u32.to_le_bytes().as_ptr(), base.add(12), 4);
    }
    base as u32
}

#[no_mangle]
pub extern "C" fn koma_test_malformed_result() -> u32 {
    let payload = b"{\"type\":\"response\",\"version\":1}";
    let base = test_boundary_response();
    unsafe {
        core::ptr::copy_nonoverlapping(0x4B4F4D41_u32.to_le_bytes().as_ptr(), base, 4);
        core::ptr::copy_nonoverlapping(1_u32.to_le_bytes().as_ptr(), base.add(4), 4);
        core::ptr::copy_nonoverlapping((payload.len() as u32).to_le_bytes().as_ptr(), base.add(8), 4);
        core::ptr::copy_nonoverlapping(0_u32.to_le_bytes().as_ptr(), base.add(12), 4);
        core::ptr::copy_nonoverlapping(payload.as_ptr(), base.add(16), payload.len());
    }
    base as u32
}

#[no_mangle]
pub extern "C" fn koma_source_free(result_ptr: u32) {
    response_buffer().free(result_ptr)
}

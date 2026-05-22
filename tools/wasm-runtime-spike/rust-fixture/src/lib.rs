#![no_std]

extern crate koma_source_sdk;

use koma_source_sdk::result::ResultBuffer;
use koma_source_sdk::source::{
    self, ChapterId, ChapterListRequest, FiltersRequest, HomeRequest, JsonPayload,
    ListingsRequest, MangaId, MangaListRequest, SearchRequest, Source, SourceCapabilities,
    SourceError, SourceInfo, SourceResult,
};

static mut RESPONSE: ResultBuffer<4096> = ResultBuffer::new();
static FIXTURE_SOURCE: FixtureSource = FixtureSource;

const MANGA_ID: &[u8] = b"manga:fixture-series";
const CHAPTER_ID: &[u8] = b"chapter:fixture-series:001";
const LISTING_ID_POPULAR: &[u8] = b"listing:popular";

const SEARCH_DATA: &[u8] =
    br#"{"requestEcho":"fixture","items":[{"id":"manga:fixture-series","title":"Fixture Series","subtitle":"Rust WAMR runtime smoke","cover":{"kind":"none"},"authors":["Koma Fixture"],"status":"unknown","contentRating":"unknown","sourceTags":["fixture"]}],"page":{"nextCursor":null,"hasMore":false}}"#;
const MANGA_DATA: &[u8] =
    br#"{"manga":{"id":"manga:fixture-series","title":"Fixture Series","alternateTitles":["Fixture Manga"],"description":"Rust WAMR runtime smoke detail.","cover":{"kind":"none"},"authors":["Koma Fixture"],"artists":[],"status":"unknown","contentRating":"unknown","language":"zh-Hans","tags":["fixture"],"links":[]}}"#;
const CHAPTERS_DATA: &[u8] =
    br#"{"items":[{"id":"chapter:fixture-series:001","mangaId":"manga:fixture-series","title":"Chapter 1","chapterNumber":"1","volumeNumber":null,"language":"zh-Hans","publishedAt":null,"updatedAt":null,"pageCount":1}],"page":{"nextCursor":null,"hasMore":false}}"#;
const PAGES_DATA: &[u8] =
    br#"{"chapterId":"chapter:fixture-series:001","pages":[{"id":"page:fixture-series:001:0001","index":0,"image":{"kind":"placeholder","label":"fixture-page-1","width":1200,"height":1800}}]}"#;
const LISTINGS_DATA: &[u8] =
    br#"{"listings":[{"id":"listing:popular","name":"Popular","kind":"popular"},{"id":"listing:latest","name":"Latest","kind":"latest"}]}"#;
const MANGA_LIST_DATA: &[u8] =
    br#"{"listingId":"listing:popular","items":[{"id":"manga:fixture-series","title":"Fixture Series","subtitle":"Browse fixture result","cover":{"kind":"none"},"authors":["Koma Fixture"],"status":"unknown","contentRating":"unknown","sourceTags":["fixture"]}],"page":{"nextCursor":null,"hasMore":false}}"#;
const HOME_DATA: &[u8] =
    br#"{"sections":[{"id":"home:featured","title":"Featured","kind":"mangaList","items":[{"id":"manga:fixture-series","title":"Fixture Series","cover":{"kind":"none"}}]},{"id":"home:latest-link","title":"Latest","kind":"listingLink","listingId":"listing:latest"}]}"#;
const FILTERS_DATA: &[u8] =
    br#"{"filters":[{"id":"filter:query","label":"Query","kind":"text"},{"id":"filter:sort","label":"Sort","kind":"sort","options":[{"id":"sort:popular","label":"Popular"},{"id":"sort:latest","label":"Latest"}]}]}"#;

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
}

#[panic_handler]
fn panic(_: &core::panic::PanicInfo<'_>) -> ! {
    loop {}
}

fn response_buffer() -> &'static mut ResultBuffer<4096> {
    unsafe { &mut *core::ptr::addr_of_mut!(RESPONSE) }
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
pub extern "C" fn koma_source_free(result_ptr: u32) {
    response_buffer().free(result_ptr)
}

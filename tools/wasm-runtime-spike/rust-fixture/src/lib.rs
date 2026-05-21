#![no_std]

extern crate koma_source_sdk;

use koma_source_sdk::result::ResultBuffer;
use koma_source_sdk::source::{
    self, ChapterId, ChapterListRequest, MangaId, SearchRequest, Source, SourceInfo, SourceResult,
};

static mut RESPONSE: ResultBuffer<2048> = ResultBuffer::new();
static FIXTURE_SOURCE: FixtureSource = FixtureSource;

const MANGA_ID: &[u8] = b"manga:fixture-series";
const CHAPTER_ID: &[u8] = b"chapter:fixture-series:001";

const SEARCH_DATA: &[u8] =
    br#"{"items":[{"id":"manga:fixture-series","title":"Fixture Series","subtitle":"Rust WAMR runtime smoke","cover":{"kind":"none"},"authors":["Koma Fixture"],"status":"unknown","contentRating":"unknown","sourceTags":["fixture"]}],"page":{"nextCursor":null,"hasMore":false}}"#;
const MANGA_DATA: &[u8] =
    br#"{"manga":{"id":"manga:fixture-series","title":"Fixture Series","alternateTitles":["Fixture Manga"],"description":"Rust WAMR runtime smoke detail.","cover":{"kind":"none"},"authors":["Koma Fixture"],"artists":[],"status":"unknown","contentRating":"unknown","language":"zh-Hans","tags":["fixture"],"links":[]}}"#;
const CHAPTERS_DATA: &[u8] =
    br#"{"items":[{"id":"chapter:fixture-series:001","mangaId":"manga:fixture-series","title":"Chapter 1","chapterNumber":"1","volumeNumber":null,"language":"zh-Hans","publishedAt":null,"updatedAt":null,"pageCount":1}],"page":{"nextCursor":null,"hasMore":false}}"#;
const PAGES_DATA: &[u8] =
    br#"{"chapterId":"chapter:fixture-series:001","pages":[{"id":"page:fixture-series:001:0001","index":0,"image":{"kind":"placeholder","label":"fixture-page-1","width":1200,"height":1800}}]}"#;

struct FixtureSource;

impl Source for FixtureSource {
    const INFO: SourceInfo = SourceInfo {
        id: "koma.fixture.rust-sdk",
        name: "Koma Rust SDK Fixture",
        version: "0.1.0",
    };

    fn search(&self, request: SearchRequest<'_>) -> SourceResult {
        if request.query_is(b"fixture") {
            SourceResult::Json(SEARCH_DATA)
        } else {
            SourceResult::BadRequest("expected fixture search request")
        }
    }

    fn get_manga(&self, id: MangaId<'_>) -> SourceResult {
        if id.is(MANGA_ID) {
            SourceResult::Json(MANGA_DATA)
        } else {
            SourceResult::BadRequest("expected fixture manga request")
        }
    }

    fn get_chapters(&self, request: ChapterListRequest<'_>) -> SourceResult {
        if request.manga_id_is(MANGA_ID) {
            SourceResult::Json(CHAPTERS_DATA)
        } else {
            SourceResult::BadRequest("expected fixture chapters request")
        }
    }

    fn get_pages(&self, id: ChapterId<'_>) -> SourceResult {
        if id.is(CHAPTER_ID) {
            SourceResult::Json(PAGES_DATA)
        } else {
            SourceResult::BadRequest("expected fixture pages request")
        }
    }
}

#[panic_handler]
fn panic(_: &core::panic::PanicInfo<'_>) -> ! {
    loop {}
}

fn response_buffer() -> &'static mut ResultBuffer<2048> {
    unsafe { &mut *core::ptr::addr_of_mut!(RESPONSE) }
}

#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn koma_source_init(_manifest_ptr: u32, manifest_len: u32) -> i32 {
    source::init::<FixtureSource>(manifest_len, b"rust fixture init reached host imports")
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
pub extern "C" fn koma_source_free(result_ptr: u32) {
    response_buffer().free(result_ptr)
}

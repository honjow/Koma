#![no_std]

extern crate koma_source_sdk;

use koma_source_sdk::envelope;
use koma_source_sdk::host;
use koma_source_sdk::request::Request;
use koma_source_sdk::result::ResultBuffer;

static mut RESPONSE: ResultBuffer<2048> = ResultBuffer::new();

#[panic_handler]
fn panic(_: &core::panic::PanicInfo<'_>) -> ! {
    loop {}
}

fn make_result(payload: &[u8], ok: bool) -> u32 {
    unsafe { (*core::ptr::addr_of_mut!(RESPONSE)).write(payload, ok) }
}

#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn koma_source_init(_manifest_ptr: u32, manifest_len: u32) -> i32 {
    let message = b"rust fixture init reached host imports";
    host::log_info(message);
    if host::check_cancel() {
        return -2;
    }

    if manifest_len > 0 {
        0
    } else {
        -1
    }
}

#[no_mangle]
pub extern "C" fn koma_source_search(req_ptr: u32, req_len: u32) -> u32 {
    let Some(request) = (unsafe { Request::from_abi(req_ptr, req_len) }) else {
        return make_result(envelope::BAD_EMPTY_REQUEST, false);
    };

    host::log_info(b"rust fixture search reached host imports");
    if !request.contains(br#""operation":"search""#) || !request.contains(br#""query":"fixture""#) {
        return make_result(envelope::BAD_SEARCH_REQUEST, false);
    }

    if host::check_cancel() {
        return make_result(envelope::CANCELLED, false);
    }

    make_result(envelope::FIXTURE_SEARCH_OK, true)
}

#[no_mangle]
pub extern "C" fn koma_source_get_manga(req_ptr: u32, req_len: u32) -> u32 {
    let Some(request) = (unsafe { Request::from_abi(req_ptr, req_len) }) else {
        return make_result(envelope::BAD_EMPTY_REQUEST, false);
    };

    host::log_info(b"rust fixture get_manga reached host imports");
    if !request.contains(br#""operation":"get_manga""#)
        || !request.contains(br#""mangaId":"manga:fixture-series""#)
    {
        return make_result(envelope::BAD_GET_MANGA_REQUEST, false);
    }

    if host::check_cancel() {
        return make_result(envelope::CANCELLED, false);
    }

    make_result(envelope::FIXTURE_GET_MANGA_OK, true)
}

#[no_mangle]
pub extern "C" fn koma_source_get_chapters(req_ptr: u32, req_len: u32) -> u32 {
    let Some(request) = (unsafe { Request::from_abi(req_ptr, req_len) }) else {
        return make_result(envelope::BAD_EMPTY_REQUEST, false);
    };

    host::log_info(b"rust fixture get_chapters reached host imports");
    if !request.contains(br#""operation":"get_chapters""#)
        || !request.contains(br#""mangaId":"manga:fixture-series""#)
    {
        return make_result(envelope::BAD_GET_CHAPTERS_REQUEST, false);
    }

    if host::check_cancel() {
        return make_result(envelope::CANCELLED, false);
    }

    make_result(envelope::FIXTURE_GET_CHAPTERS_OK, true)
}

#[no_mangle]
pub extern "C" fn koma_source_get_pages(req_ptr: u32, req_len: u32) -> u32 {
    let Some(request) = (unsafe { Request::from_abi(req_ptr, req_len) }) else {
        return make_result(envelope::BAD_EMPTY_REQUEST, false);
    };

    host::log_info(b"rust fixture get_pages reached host imports");
    if !request.contains(br#""operation":"get_pages""#)
        || !request.contains(br#""chapterId":"chapter:fixture-series:001""#)
    {
        return make_result(envelope::BAD_GET_PAGES_REQUEST, false);
    }

    if host::check_cancel() {
        return make_result(envelope::CANCELLED, false);
    }

    make_result(envelope::FIXTURE_GET_PAGES_OK, true)
}

#[no_mangle]
pub extern "C" fn koma_source_free(result_ptr: u32) {
    unsafe { (*core::ptr::addr_of_mut!(RESPONSE)).free(result_ptr) }
}

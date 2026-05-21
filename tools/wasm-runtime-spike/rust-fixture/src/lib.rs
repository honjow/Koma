#![no_std]

extern crate koma_source_sdk;

use koma_source_sdk::envelope;
use koma_source_sdk::host;
use koma_source_sdk::request::Request;
use koma_source_sdk::result::ResultBuffer;

static mut RESPONSE: ResultBuffer<1024> = ResultBuffer::new();

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

    if !request.contains(br#""query":"fixture""#) {
        return make_result(envelope::BAD_FIXTURE_QUERY, false);
    }

    if host::check_cancel() {
        return make_result(envelope::CANCELLED, false);
    }

    make_result(envelope::FIXTURE_SEARCH_OK, true)
}

#[no_mangle]
pub extern "C" fn koma_source_free(result_ptr: u32) {
    unsafe { (*core::ptr::addr_of_mut!(RESPONSE)).free(result_ptr) }
}

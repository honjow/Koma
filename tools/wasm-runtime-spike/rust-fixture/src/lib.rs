#![no_std]

const KOMA_MAGIC: u32 = 0x4B4F4D41;
const KOMA_HOST_LOG_INFO: u32 = 1;

#[link(wasm_import_module = "koma_host")]
unsafe extern "C" {
    #[link_name = "log"]
    fn koma_host_log(level: u32, message_ptr: *const u8, message_len: u32);

    #[link_name = "check_cancel"]
    fn koma_host_check_cancel() -> i32;
}

static mut LAST_RESPONSE: u32 = 0;
static mut RESPONSE: [u8; 1024] = [0; 1024];

#[panic_handler]
fn panic(_: &core::panic::PanicInfo<'_>) -> ! {
    loop {}
}

fn contains_bytes(haystack_ptr: u32, haystack_len: u32, needle: &[u8]) -> bool {
    if needle.is_empty() || haystack_len < needle.len() as u32 {
        return false;
    }

    for i in 0..=(haystack_len - needle.len() as u32) {
        let mut matched = true;
        for (j, expected) in needle.iter().enumerate() {
            let actual = unsafe { *((haystack_ptr + i + j as u32) as *const u8) };
            if actual != *expected {
                matched = false;
                break;
            }
        }
        if matched {
            return true;
        }
    }
    false
}

unsafe fn write_u32(buf: *mut u8, offset: usize, value: u32) {
    unsafe {
        core::ptr::copy_nonoverlapping(value.to_le_bytes().as_ptr(), buf.add(offset), 4);
    }
}

fn make_result(payload: &[u8], ok: bool) -> u32 {
    if payload.len() + 16 > 1024 {
        return 0;
    }

    let buf = core::ptr::addr_of_mut!(RESPONSE) as *mut u8;
    unsafe {
        write_u32(buf, 0, KOMA_MAGIC);
        write_u32(buf, 4, if ok { 1 } else { 0 });
        write_u32(buf, 8, payload.len() as u32);
        write_u32(buf, 12, 0);
        core::ptr::copy_nonoverlapping(payload.as_ptr(), buf.add(16), payload.len());
        LAST_RESPONSE = buf as u32;
        LAST_RESPONSE
    }
}

#[no_mangle]
pub extern "C" fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[no_mangle]
pub extern "C" fn koma_source_init(_manifest_ptr: u32, manifest_len: u32) -> i32 {
    let message = b"rust fixture init reached host imports";
    unsafe {
        koma_host_log(
            KOMA_HOST_LOG_INFO,
            message.as_ptr(),
            message.len() as u32,
        );
        if koma_host_check_cancel() != 0 {
            return -2;
        }
    }

    if manifest_len > 0 {
        0
    } else {
        -1
    }
}

#[no_mangle]
pub extern "C" fn koma_source_search(req_ptr: u32, req_len: u32) -> u32 {
    if req_len == 0 {
        return make_result(
            br#"{"ok":false,"error":{"code":"BAD_REQUEST","message":"empty request"},"warnings":[]}"#,
            false,
        );
    }

    if !contains_bytes(req_ptr, req_len, br#""query":"fixture""#) {
        return make_result(
            br#"{"ok":false,"error":{"code":"BAD_REQUEST","message":"expected fixture query"},"warnings":[]}"#,
            false,
        );
    }

    let cancelled = unsafe { koma_host_check_cancel() != 0 };
    if cancelled {
        return make_result(
            br#"{"ok":false,"error":{"code":"CANCELLED","message":"host cancelled"},"warnings":[]}"#,
            false,
        );
    }

    make_result(
        br#"{"ok":true,"data":{"requestEcho":"fixture","items":[{"id":"rust-fixture-series-1","title":"Fixture Series","subtitle":"Rust WAMR ABI spike","cover":{"url":"https://example.local/covers/fixture.jpg","headersRef":"default"}}],"nextPage":null},"hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false},"warnings":[],"elapsedMs":0}"#,
        true,
    )
}

#[no_mangle]
pub extern "C" fn koma_source_free(result_ptr: u32) {
    unsafe {
        if result_ptr == LAST_RESPONSE {
            LAST_RESPONSE = 0;
        }
    }
}

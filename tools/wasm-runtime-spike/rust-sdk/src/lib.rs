#![no_std]

pub mod host {
    pub const LOG_INFO: u32 = 1;

    #[link(wasm_import_module = "koma_host")]
    unsafe extern "C" {
        #[link_name = "log"]
        fn koma_host_log(level: u32, message_ptr: *const u8, message_len: u32);

        #[link_name = "check_cancel"]
        fn koma_host_check_cancel() -> i32;
    }

    pub fn log_info(message: &[u8]) {
        unsafe {
            koma_host_log(LOG_INFO, message.as_ptr(), message.len() as u32);
        }
    }

    pub fn check_cancel() -> bool {
        unsafe { koma_host_check_cancel() != 0 }
    }
}

pub mod request {
    pub struct Request<'a> {
        bytes: &'a [u8],
    }

    impl<'a> Request<'a> {
        pub unsafe fn from_abi(ptr: u32, len: u32) -> Option<Self> {
            if ptr == 0 || len == 0 {
                return None;
            }

            let bytes = unsafe { core::slice::from_raw_parts(ptr as *const u8, len as usize) };
            Some(Self { bytes })
        }

        pub fn contains(&self, needle: &[u8]) -> bool {
            contains_bytes(self.bytes, needle)
        }
    }

    pub fn contains_bytes(haystack: &[u8], needle: &[u8]) -> bool {
        if needle.is_empty() || haystack.len() < needle.len() {
            return false;
        }

        haystack
            .windows(needle.len())
            .any(|window| window == needle)
    }
}

pub mod envelope {
    pub const HOST_ABI: &str = "koma-host-v0.1";
    pub const HOST_HINTS_NETWORK_FALSE: &str = r#""hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false}"#;

    pub const BAD_EMPTY_REQUEST: &[u8] =
        br#"{"ok":false,"error":{"code":"BAD_REQUEST","message":"empty request"},"warnings":[]}"#;
    pub const BAD_FIXTURE_QUERY: &[u8] =
        br#"{"ok":false,"error":{"code":"BAD_REQUEST","message":"expected fixture query"},"warnings":[]}"#;
    pub const CANCELLED: &[u8] =
        br#"{"ok":false,"error":{"code":"CANCELLED","message":"host cancelled"},"warnings":[]}"#;
    pub const FIXTURE_SEARCH_OK: &[u8] =
        br#"{"ok":true,"data":{"requestEcho":"fixture","items":[{"id":"rust-fixture-series-1","title":"Fixture Series","subtitle":"Rust WAMR ABI spike","cover":{"url":"https://example.local/covers/fixture.jpg","headersRef":"default"}}],"nextPage":null},"hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false},"warnings":[],"elapsedMs":0}"#;
}

pub mod result {
    const KOMA_MAGIC: u32 = 0x4B4F4D41;
    const HEADER_LEN: usize = 16;

    pub struct ResultBuffer<const N: usize> {
        last_response: u32,
        bytes: [u8; N],
    }

    impl<const N: usize> ResultBuffer<N> {
        pub const fn new() -> Self {
            Self {
                last_response: 0,
                bytes: [0; N],
            }
        }

        pub fn write(&mut self, payload: &[u8], ok: bool) -> u32 {
            if payload.len() + HEADER_LEN > N {
                return 0;
            }

            let flags = if ok { 1_u32 } else { 0_u32 };
            self.bytes[0..4].copy_from_slice(&KOMA_MAGIC.to_le_bytes());
            self.bytes[4..8].copy_from_slice(&flags.to_le_bytes());
            self.bytes[8..12].copy_from_slice(&(payload.len() as u32).to_le_bytes());
            self.bytes[12..16].copy_from_slice(&0_u32.to_le_bytes());
            self.bytes[HEADER_LEN..HEADER_LEN + payload.len()].copy_from_slice(payload);

            self.last_response = self.bytes.as_mut_ptr() as u32;
            self.last_response
        }

        pub fn free(&mut self, result_ptr: u32) {
            if result_ptr == self.last_response {
                self.last_response = 0;
            }
        }
    }

    impl<const N: usize> Default for ResultBuffer<N> {
        fn default() -> Self {
            Self::new()
        }
    }
}

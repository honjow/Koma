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

        pub fn contains_json_string(&self, key: &[u8], value: &[u8]) -> bool {
            let mut pattern = [0_u8; 96];
            let needed = key.len() + value.len() + 5;
            if needed > pattern.len() {
                return false;
            }

            let pattern_ptr = pattern.as_mut_ptr();
            unsafe {
                *pattern_ptr = b'"';
                core::ptr::copy_nonoverlapping(key.as_ptr(), pattern_ptr.add(1), key.len());
                let mut cursor = 1 + key.len();
                *pattern_ptr.add(cursor) = b'"';
                *pattern_ptr.add(cursor + 1) = b':';
                *pattern_ptr.add(cursor + 2) = b'"';
                cursor += 3;
                core::ptr::copy_nonoverlapping(
                    value.as_ptr(),
                    pattern_ptr.add(cursor),
                    value.len(),
                );
                cursor += value.len();
                *pattern_ptr.add(cursor) = b'"';
            }

            let pattern = unsafe { core::slice::from_raw_parts(pattern.as_ptr(), needed) };
            contains_bytes(self.bytes, pattern)
        }
    }

    pub fn contains_bytes(haystack: &[u8], needle: &[u8]) -> bool {
        if needle.is_empty() || haystack.len() < needle.len() {
            return false;
        }

        let last = haystack.len() - needle.len();
        let mut index = 0_usize;
        while index <= last {
            let mut matched = true;
            let mut offset = 0_usize;
            while offset < needle.len() {
                let hay = unsafe { *haystack.as_ptr().add(index + offset) };
                let expected = unsafe { *needle.as_ptr().add(offset) };
                if hay != expected {
                    matched = false;
                    break;
                }
                offset += 1;
            }
            if matched {
                return true;
            }
            index += 1;
        }

        false
    }
}

pub mod source {
    use crate::host;
    use crate::request::Request;
    use crate::result::ResultBuffer;

    pub struct SourceInfo {
        pub id: &'static str,
        pub name: &'static str,
        pub version: &'static str,
    }

    pub struct SearchRequest<'a> {
        request: Request<'a>,
    }

    pub struct MangaId<'a> {
        request: Request<'a>,
    }

    pub struct ChapterId<'a> {
        request: Request<'a>,
    }

    pub struct ChapterListRequest<'a> {
        request: Request<'a>,
    }

    pub enum SourceResult {
        Json(&'static [u8]),
        BadRequest(&'static str),
    }

    pub trait Source {
        const INFO: SourceInfo;

        fn search(&self, request: SearchRequest<'_>) -> SourceResult;
        fn get_manga(&self, id: MangaId<'_>) -> SourceResult;
        fn get_chapters(&self, request: ChapterListRequest<'_>) -> SourceResult;
        fn get_pages(&self, id: ChapterId<'_>) -> SourceResult;
    }

    impl<'a> SearchRequest<'a> {
        pub fn query_is(&self, query: &[u8]) -> bool {
            self.request.contains_json_string(b"query", query)
        }
    }

    impl<'a> MangaId<'a> {
        pub fn is(&self, id: &[u8]) -> bool {
            self.request.contains_json_string(b"mangaId", id)
        }
    }

    impl<'a> ChapterId<'a> {
        pub fn is(&self, id: &[u8]) -> bool {
            self.request.contains_json_string(b"chapterId", id)
        }
    }

    impl<'a> ChapterListRequest<'a> {
        pub fn manga_id_is(&self, id: &[u8]) -> bool {
            self.request.contains_json_string(b"mangaId", id)
        }
    }

    pub fn init<S: Source>(manifest_len: u32, log_message: &[u8]) -> i32 {
        let _ = S::INFO;
        host::log_info(log_message);
        if host::check_cancel() {
            return -2;
        }

        if manifest_len > 0 {
            0
        } else {
            -1
        }
    }

    pub fn search<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(buffer, req_ptr, req_len, "search", log_message)
        else {
            return buffer.last_ptr();
        };
        write_source_result(buffer, "search", source.search(SearchRequest { request }))
    }

    pub fn get_manga<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(buffer, req_ptr, req_len, "get_manga", log_message)
        else {
            return buffer.last_ptr();
        };
        write_source_result(buffer, "get_manga", source.get_manga(MangaId { request }))
    }

    pub fn get_chapters<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) =
            prepare_operation(buffer, req_ptr, req_len, "get_chapters", log_message)
        else {
            return buffer.last_ptr();
        };
        write_source_result(
            buffer,
            "get_chapters",
            source.get_chapters(ChapterListRequest { request }),
        )
    }

    pub fn get_pages<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(buffer, req_ptr, req_len, "get_pages", log_message)
        else {
            return buffer.last_ptr();
        };
        write_source_result(buffer, "get_pages", source.get_pages(ChapterId { request }))
    }

    fn prepare_operation<'a, const N: usize>(
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        operation: &'static str,
        log_message: &[u8],
    ) -> Option<Request<'a>> {
        let Some(request) = (unsafe { Request::from_abi(req_ptr, req_len) }) else {
            buffer.write_error("unknown", "BAD_REQUEST", "empty request");
            return None;
        };

        host::log_info(log_message);
        if !request.contains_json_string(b"operation", operation.as_bytes()) {
            buffer.write_error(operation, "BAD_REQUEST", "unexpected operation");
            return None;
        }

        if host::check_cancel() {
            buffer.write_error(operation, "CANCELLED", "host cancelled");
            return None;
        }

        Some(request)
    }

    fn write_source_result<const N: usize>(
        buffer: &mut ResultBuffer<N>,
        operation: &str,
        result: SourceResult,
    ) -> u32 {
        match result {
            SourceResult::Json(data) => buffer.write_success(operation, data),
            SourceResult::BadRequest(message) => {
                buffer.write_error(operation, "BAD_REQUEST", message)
            }
        }
    }
}

pub mod envelope {
    pub const HOST_ABI: &str = "koma-host-v0.1";
    pub const HOST_HINTS_NETWORK_FALSE: &str = r#""hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false}"#;

    pub const BAD_EMPTY_REQUEST: &[u8] =
        br#"{"type":"response","version":1,"ok":false,"operation":"unknown","error":{"code":"BAD_REQUEST","message":"empty request"},"hostHints":{"network":false},"warnings":[]}"#;
    pub const BAD_SEARCH_REQUEST: &[u8] =
        br#"{"type":"response","version":1,"ok":false,"operation":"search","error":{"code":"BAD_REQUEST","message":"expected fixture search request"},"hostHints":{"network":false},"warnings":[]}"#;
    pub const BAD_GET_MANGA_REQUEST: &[u8] =
        br#"{"type":"response","version":1,"ok":false,"operation":"get_manga","error":{"code":"BAD_REQUEST","message":"expected fixture manga request"},"hostHints":{"network":false},"warnings":[]}"#;
    pub const BAD_GET_CHAPTERS_REQUEST: &[u8] =
        br#"{"type":"response","version":1,"ok":false,"operation":"get_chapters","error":{"code":"BAD_REQUEST","message":"expected fixture chapters request"},"hostHints":{"network":false},"warnings":[]}"#;
    pub const BAD_GET_PAGES_REQUEST: &[u8] =
        br#"{"type":"response","version":1,"ok":false,"operation":"get_pages","error":{"code":"BAD_REQUEST","message":"expected fixture pages request"},"hostHints":{"network":false},"warnings":[]}"#;
    pub const CANCELLED: &[u8] =
        br#"{"type":"response","version":1,"ok":false,"operation":"unknown","error":{"code":"CANCELLED","message":"host cancelled"},"hostHints":{"network":false},"warnings":[]}"#;
    pub const FIXTURE_SEARCH_OK: &[u8] =
        br#"{"type":"response","version":1,"ok":true,"operation":"search","data":{"requestEcho":"fixture","items":[{"id":"manga:fixture-series","title":"Fixture Series","subtitle":"Rust WAMR runtime smoke","cover":{"kind":"none"},"authors":["Koma Fixture"],"status":"unknown","contentRating":"unknown","sourceTags":["fixture"]}],"page":{"nextCursor":null,"hasMore":false}},"hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false},"warnings":[],"elapsedMs":0}"#;
    pub const FIXTURE_GET_MANGA_OK: &[u8] =
        br#"{"type":"response","version":1,"ok":true,"operation":"get_manga","data":{"manga":{"id":"manga:fixture-series","title":"Fixture Series","alternateTitles":["Fixture Manga"],"description":"Rust WAMR runtime smoke detail.","cover":{"kind":"none"},"authors":["Koma Fixture"],"artists":[],"status":"unknown","contentRating":"unknown","language":"zh-Hans","tags":["fixture"],"links":[]}},"hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false},"warnings":[],"elapsedMs":0}"#;
    pub const FIXTURE_GET_CHAPTERS_OK: &[u8] =
        br#"{"type":"response","version":1,"ok":true,"operation":"get_chapters","data":{"items":[{"id":"chapter:fixture-series:001","mangaId":"manga:fixture-series","title":"Chapter 1","chapterNumber":"1","volumeNumber":null,"language":"zh-Hans","publishedAt":null,"updatedAt":null,"pageCount":1}],"page":{"nextCursor":null,"hasMore":false}},"hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false},"warnings":[],"elapsedMs":0}"#;
    pub const FIXTURE_GET_PAGES_OK: &[u8] =
        br#"{"type":"response","version":1,"ok":true,"operation":"get_pages","data":{"chapterId":"chapter:fixture-series:001","pages":[{"id":"page:fixture-series:001:0001","index":0,"image":{"kind":"placeholder","label":"fixture-page-1","width":1200,"height":1800}}]},"hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false},"warnings":[],"elapsedMs":0}"#;
}

pub mod result {
    const KOMA_MAGIC: u32 = 0x4B4F4D41;
    const HEADER_LEN: usize = 16;
    const RESPONSE_PREFIX_OK: &[u8] = br#"{"type":"response","version":1,"ok":true,"operation":""#;
    const RESPONSE_PREFIX_ERROR: &[u8] =
        br#"{"type":"response","version":1,"ok":false,"operation":""#;
    const DATA_PREFIX: &[u8] = br#"","data":"#;
    const ERROR_PREFIX: &[u8] = br#"","error":{"code":""#;
    const ERROR_MESSAGE_PREFIX: &[u8] = br#"","message":""#;
    const ERROR_SUFFIX: &[u8] = br#""},"hostHints":{"network":false},"warnings":[]}"#;
    const SUCCESS_SUFFIX: &[u8] = br#","hostHints":{"abi":"koma-host-v0.1","maxMemoryPages":2,"maxPayloadBytes":1048576,"network":false},"warnings":[],"elapsedMs":0}"#;

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

        pub fn last_ptr(&self) -> u32 {
            self.last_response
        }

        pub fn write_success(&mut self, operation: &str, data_json: &[u8]) -> u32 {
            self.write_parts(
                true,
                &[
                    RESPONSE_PREFIX_OK,
                    operation.as_bytes(),
                    DATA_PREFIX,
                    data_json,
                    SUCCESS_SUFFIX,
                ],
            )
        }

        pub fn write_error(&mut self, operation: &str, code: &str, message: &str) -> u32 {
            self.write_parts(
                false,
                &[
                    RESPONSE_PREFIX_ERROR,
                    operation.as_bytes(),
                    ERROR_PREFIX,
                    code.as_bytes(),
                    ERROR_MESSAGE_PREFIX,
                    message.as_bytes(),
                    ERROR_SUFFIX,
                ],
            )
        }

        pub fn free(&mut self, result_ptr: u32) {
            if result_ptr == self.last_response {
                self.last_response = 0;
            }
        }

        fn write_parts(&mut self, ok: bool, parts: &[&[u8]]) -> u32 {
            let mut payload_len = 0_usize;
            for part in parts {
                payload_len += part.len();
            }
            if payload_len + HEADER_LEN > N {
                return 0;
            }

            let flags = if ok { 1_u32 } else { 0_u32 };
            let payload_len_u32 = payload_len as u32;
            let zero = 0_u32;
            let base = self.bytes.as_mut_ptr();
            unsafe {
                core::ptr::copy_nonoverlapping(KOMA_MAGIC.to_le_bytes().as_ptr(), base, 4);
                core::ptr::copy_nonoverlapping(flags.to_le_bytes().as_ptr(), base.add(4), 4);
                core::ptr::copy_nonoverlapping(
                    payload_len_u32.to_le_bytes().as_ptr(),
                    base.add(8),
                    4,
                );
                core::ptr::copy_nonoverlapping(zero.to_le_bytes().as_ptr(), base.add(12), 4);

                let mut cursor = HEADER_LEN;
                for part in parts {
                    core::ptr::copy_nonoverlapping(part.as_ptr(), base.add(cursor), part.len());
                    cursor += part.len();
                }
            }

            self.last_response = self.bytes.as_mut_ptr() as u32;
            self.last_response
        }
    }

    impl<const N: usize> Default for ResultBuffer<N> {
        fn default() -> Self {
            Self::new()
        }
    }
}

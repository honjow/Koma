#![cfg_attr(not(test), no_std)]

pub mod host {
    pub const LOG_INFO: u32 = 1;

    #[link(wasm_import_module = "koma_host")]
    unsafe extern "C" {
        #[link_name = "log"]
        fn koma_host_log(level: u32, message_ptr: *const u8, message_len: u32);

        #[link_name = "check_cancel"]
        fn koma_host_check_cancel() -> i32;

        #[link_name = "http_request"]
        fn koma_host_http_request(
            req_ptr: *const u8,
            req_len: u32,
            out_ptr: *mut u8,
            out_cap: u32,
        ) -> i32;

        #[link_name = "html_parse"]
        fn koma_host_html_parse(html_ptr: *const u8, html_len: u32) -> i32;

        #[link_name = "html_select"]
        fn koma_host_html_select(descriptor: i32, selector_ptr: *const u8, selector_len: u32)
            -> i32;

        #[link_name = "html_attr"]
        fn koma_host_html_attr(
            descriptor: i32,
            attr_ptr: *const u8,
            attr_len: u32,
            out_ptr: *mut u8,
            out_cap: u32,
        ) -> i32;

        #[link_name = "html_text"]
        fn koma_host_html_text(descriptor: i32, out_ptr: *mut u8, out_cap: u32) -> i32;

        #[link_name = "html_close"]
        fn koma_host_html_close(descriptor: i32) -> i32;
    }

    pub fn log_info(message: &[u8]) {
        unsafe {
            koma_host_log(LOG_INFO, message.as_ptr(), message.len() as u32);
        }
    }

    pub fn check_cancel() -> bool {
        unsafe { koma_host_check_cancel() != 0 }
    }

    pub fn http_request(request: &[u8], output: &mut [u8]) -> core::result::Result<usize, i32> {
        let written = unsafe {
            koma_host_http_request(
                request.as_ptr(),
                request.len() as u32,
                output.as_mut_ptr(),
                output.len() as u32,
            )
        };
        if written < 0 || written as usize > output.len() {
            Err(written)
        } else {
            Ok(written as usize)
        }
    }

    #[derive(Clone, Copy)]
    pub struct HtmlDescriptor {
        raw: i32,
    }

    impl HtmlDescriptor {
        pub fn raw(&self) -> i32 {
            self.raw
        }
    }

    pub fn html_parse(html: &[u8]) -> core::result::Result<HtmlDescriptor, i32> {
        let descriptor = unsafe { koma_host_html_parse(html.as_ptr(), html.len() as u32) };
        if descriptor <= 0 {
            Err(descriptor)
        } else {
            Ok(HtmlDescriptor { raw: descriptor })
        }
    }

    pub fn html_select(
        descriptor: HtmlDescriptor,
        selector: &[u8],
    ) -> core::result::Result<HtmlDescriptor, i32> {
        let selected = unsafe {
            koma_host_html_select(descriptor.raw, selector.as_ptr(), selector.len() as u32)
        };
        if selected <= 0 {
            Err(selected)
        } else {
            Ok(HtmlDescriptor { raw: selected })
        }
    }

    pub fn html_attr(
        descriptor: HtmlDescriptor,
        attr: &[u8],
        output: &mut [u8],
    ) -> core::result::Result<usize, i32> {
        let written = unsafe {
            koma_host_html_attr(
                descriptor.raw,
                attr.as_ptr(),
                attr.len() as u32,
                output.as_mut_ptr(),
                output.len() as u32,
            )
        };
        if written < 0 || written as usize > output.len() {
            Err(written)
        } else {
            Ok(written as usize)
        }
    }

    pub fn html_text(
        descriptor: HtmlDescriptor,
        output: &mut [u8],
    ) -> core::result::Result<usize, i32> {
        let written =
            unsafe { koma_host_html_text(descriptor.raw, output.as_mut_ptr(), output.len() as u32) };
        if written < 0 || written as usize > output.len() {
            Err(written)
        } else {
            Ok(written as usize)
        }
    }

    pub fn html_close(descriptor: HtmlDescriptor) -> core::result::Result<(), i32> {
        let closed = unsafe { koma_host_html_close(descriptor.raw) };
        if closed < 0 {
            Err(closed)
        } else {
            Ok(())
        }
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

        #[cfg(test)]
        pub(crate) fn from_bytes_for_test(bytes: &'a [u8]) -> Option<Self> {
            if bytes.is_empty() {
                return None;
            }

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

        pub fn contains_json_number(&self, key: &[u8], value: u32) -> bool {
            let mut digits = [0_u8; 10];
            let digits_len = encode_u32_decimal(value, &mut digits);

            let mut pattern = [0_u8; 96];
            let needed = key.len() + digits_len + 3;
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
                cursor += 2;
                core::ptr::copy_nonoverlapping(
                    digits.as_ptr(),
                    pattern_ptr.add(cursor),
                    digits_len,
                );
            }

            let pattern = unsafe { core::slice::from_raw_parts(pattern.as_ptr(), needed) };
            find_with_non_digit_boundary(self.bytes, pattern)
        }
    }

    fn encode_u32_decimal(value: u32, out: &mut [u8; 10]) -> usize {
        if value == 0 {
            out[0] = b'0';
            return 1;
        }

        let mut scratch = [0_u8; 10];
        let mut remaining = value;
        let mut written = 0_usize;
        while remaining > 0 {
            scratch[written] = b'0' + (remaining % 10) as u8;
            remaining /= 10;
            written += 1;
        }

        let mut index = 0_usize;
        while index < written {
            out[index] = scratch[written - 1 - index];
            index += 1;
        }
        written
    }

    fn find_with_non_digit_boundary(haystack: &[u8], needle: &[u8]) -> bool {
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
                let tail = index + needle.len();
                if tail >= haystack.len() {
                    return true;
                }
                let next = unsafe { *haystack.as_ptr().add(tail) };
                if !(next >= b'0' && next <= b'9') {
                    return true;
                }
            }
            index += 1;
        }

        false
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

    #[derive(Clone, Copy)]
    pub struct SourceInfo {
        pub id: &'static str,
        pub name: &'static str,
        pub version: &'static str,
        pub api_version: &'static str,
        pub language: &'static str,
        pub author: &'static str,
        pub description: &'static str,
        pub content_rating: &'static str,
    }

    #[derive(Clone, Copy)]
    pub struct SourceCapabilities {
        pub search: bool,
        pub manga_detail: bool,
        pub chapters: bool,
        pub pages: bool,
        pub listings: bool,
        pub manga_list: bool,
        pub home: bool,
        pub filters: bool,
        pub settings: bool,
        pub image_request: bool,
    }

    impl SourceCapabilities {
        pub const CORE: Self = Self {
            search: true,
            manga_detail: true,
            chapters: true,
            pages: true,
            listings: false,
            manga_list: false,
            home: false,
            filters: false,
            settings: false,
            image_request: false,
        };

        pub const FULL_V02_FIXTURE: Self = Self {
            search: true,
            manga_detail: true,
            chapters: true,
            pages: true,
            listings: true,
            manga_list: true,
            home: true,
            filters: true,
            settings: true,
            image_request: true,
        };
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

    pub struct ListingsRequest<'a> {
        request: Request<'a>,
    }

    pub struct MangaListRequest<'a> {
        request: Request<'a>,
    }

    pub struct HomeRequest<'a> {
        request: Request<'a>,
    }

    pub struct FiltersRequest<'a> {
        request: Request<'a>,
    }

    pub struct SettingsRequest<'a> {
        request: Request<'a>,
    }

    pub struct ImageRequestInput<'a> {
        request: Request<'a>,
    }

    pub struct JsonPayload {
        bytes: &'static [u8],
    }

    impl JsonPayload {
        pub const fn new(bytes: &'static [u8]) -> Self {
            Self { bytes }
        }

        pub fn bytes(&self) -> &'static [u8] {
            self.bytes
        }
    }

    impl From<&'static [u8]> for JsonPayload {
        fn from(bytes: &'static [u8]) -> Self {
            Self::new(bytes)
        }
    }

    #[derive(Clone, Copy)]
    pub enum SourceErrorCode {
        Unimplemented,
        InvalidRequest,
        NotFound,
        Cancelled,
        Timeout,
        NetworkDisabled,
        PermissionDenied,
        ParseError,
        SourceError,
        InternalError,
    }

    impl SourceErrorCode {
        pub fn as_str(&self) -> &'static str {
            match self {
                Self::Unimplemented => "unimplemented",
                Self::InvalidRequest => "invalid_request",
                Self::NotFound => "not_found",
                Self::Cancelled => "cancelled",
                Self::Timeout => "timeout",
                Self::NetworkDisabled => "network_disabled",
                Self::PermissionDenied => "permission_denied",
                Self::ParseError => "parse_error",
                Self::SourceError => "source_error",
                Self::InternalError => "internal_error",
            }
        }
    }

    pub struct SourceError {
        code: SourceErrorCode,
        message: &'static str,
    }

    impl SourceError {
        pub const fn new(code: SourceErrorCode, message: &'static str) -> Self {
            Self { code, message }
        }

        pub const fn unimplemented() -> Self {
            Self::new(SourceErrorCode::Unimplemented, "operation not implemented")
        }

        pub const fn invalid_request(message: &'static str) -> Self {
            Self::new(SourceErrorCode::InvalidRequest, message)
        }

        pub const fn not_found(message: &'static str) -> Self {
            Self::new(SourceErrorCode::NotFound, message)
        }

        pub const fn cancelled() -> Self {
            Self::new(SourceErrorCode::Cancelled, "operation cancelled")
        }

        pub const fn timeout(message: &'static str) -> Self {
            Self::new(SourceErrorCode::Timeout, message)
        }

        pub const fn network_disabled(message: &'static str) -> Self {
            Self::new(SourceErrorCode::NetworkDisabled, message)
        }

        pub const fn permission_denied(message: &'static str) -> Self {
            Self::new(SourceErrorCode::PermissionDenied, message)
        }

        pub const fn parse_error(message: &'static str) -> Self {
            Self::new(SourceErrorCode::ParseError, message)
        }

        pub const fn source_error(message: &'static str) -> Self {
            Self::new(SourceErrorCode::SourceError, message)
        }

        pub const fn internal_error(message: &'static str) -> Self {
            Self::new(SourceErrorCode::InternalError, message)
        }

        pub fn code(&self) -> &'static str {
            self.code.as_str()
        }

        pub fn message(&self) -> &'static str {
            self.message
        }
    }

    pub type SourceResult = core::result::Result<JsonPayload, SourceError>;

    pub trait Source {
        fn info(&self) -> SourceInfo;

        fn capabilities(&self) -> SourceCapabilities {
            SourceCapabilities::CORE
        }

        fn search(&self, request: SearchRequest<'_>) -> SourceResult;
        fn get_manga(&self, id: MangaId<'_>) -> SourceResult;
        fn get_chapters(&self, request: ChapterListRequest<'_>) -> SourceResult;
        fn get_pages(&self, id: ChapterId<'_>) -> SourceResult;

        fn get_listings(&self, _request: ListingsRequest<'_>) -> SourceResult {
            Err(SourceError::unimplemented())
        }

        fn get_manga_list(&self, _request: MangaListRequest<'_>) -> SourceResult {
            Err(SourceError::unimplemented())
        }

        fn get_home(&self, _request: HomeRequest<'_>) -> SourceResult {
            Err(SourceError::unimplemented())
        }

        fn get_filters(&self, _request: FiltersRequest<'_>) -> SourceResult {
            Err(SourceError::unimplemented())
        }

        fn get_settings(&self, _request: SettingsRequest<'_>) -> SourceResult {
            Err(SourceError::unimplemented())
        }

        fn get_image_request(&self, _request: ImageRequestInput<'_>) -> SourceResult {
            Err(SourceError::unimplemented())
        }
    }

    pub trait OperationRequest<'a> {
        const OPERATION: &'static str;

        fn from_request(request: Request<'a>) -> Self;
    }

    impl<'a> SearchRequest<'a> {
        pub fn query_is(&self, query: &[u8]) -> bool {
            self.request.contains_json_string(b"query", query)
        }

        pub fn limit_is(&self, limit: u32) -> bool {
            self.request.contains_json_number(b"limit", limit)
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

    impl<'a> ListingsRequest<'a> {
        pub fn raw_contains(&self, needle: &[u8]) -> bool {
            self.request.contains(needle)
        }
    }

    impl<'a> MangaListRequest<'a> {
        pub fn listing_id_is(&self, id: &[u8]) -> bool {
            self.request.contains_json_string(b"listingId", id)
        }

        pub fn limit_is(&self, limit: u32) -> bool {
            self.request.contains_json_number(b"limit", limit)
        }
    }

    impl<'a> HomeRequest<'a> {
        pub fn raw_contains(&self, needle: &[u8]) -> bool {
            self.request.contains(needle)
        }
    }

    impl<'a> FiltersRequest<'a> {
        pub fn raw_contains(&self, needle: &[u8]) -> bool {
            self.request.contains(needle)
        }
    }

    impl<'a> SettingsRequest<'a> {
        pub fn raw_contains(&self, needle: &[u8]) -> bool {
            self.request.contains(needle)
        }
    }

    impl<'a> ImageRequestInput<'a> {
        pub fn page_id_is(&self, id: &[u8]) -> bool {
            self.request.contains_json_string(b"pageId", id)
        }
    }

    impl<'a> OperationRequest<'a> for SearchRequest<'a> {
        const OPERATION: &'static str = "search";

        fn from_request(request: Request<'a>) -> Self {
            SearchRequest { request }
        }
    }

    impl<'a> OperationRequest<'a> for MangaId<'a> {
        const OPERATION: &'static str = "get_manga";

        fn from_request(request: Request<'a>) -> Self {
            MangaId { request }
        }
    }

    impl<'a> OperationRequest<'a> for ChapterListRequest<'a> {
        const OPERATION: &'static str = "get_chapters";

        fn from_request(request: Request<'a>) -> Self {
            ChapterListRequest { request }
        }
    }

    impl<'a> OperationRequest<'a> for ChapterId<'a> {
        const OPERATION: &'static str = "get_pages";

        fn from_request(request: Request<'a>) -> Self {
            ChapterId { request }
        }
    }

    impl<'a> OperationRequest<'a> for ListingsRequest<'a> {
        const OPERATION: &'static str = "get_listings";

        fn from_request(request: Request<'a>) -> Self {
            ListingsRequest { request }
        }
    }

    impl<'a> OperationRequest<'a> for MangaListRequest<'a> {
        const OPERATION: &'static str = "get_manga_list";

        fn from_request(request: Request<'a>) -> Self {
            MangaListRequest { request }
        }
    }

    impl<'a> OperationRequest<'a> for HomeRequest<'a> {
        const OPERATION: &'static str = "get_home";

        fn from_request(request: Request<'a>) -> Self {
            HomeRequest { request }
        }
    }

    impl<'a> OperationRequest<'a> for FiltersRequest<'a> {
        const OPERATION: &'static str = "get_filters";

        fn from_request(request: Request<'a>) -> Self {
            FiltersRequest { request }
        }
    }

    impl<'a> OperationRequest<'a> for SettingsRequest<'a> {
        const OPERATION: &'static str = "get_settings";

        fn from_request(request: Request<'a>) -> Self {
            SettingsRequest { request }
        }
    }

    impl<'a> OperationRequest<'a> for ImageRequestInput<'a> {
        const OPERATION: &'static str = "get_image_request";

        fn from_request(request: Request<'a>) -> Self {
            ImageRequestInput { request }
        }
    }

    pub fn init<S: Source>(source: &S, manifest_len: u32, log_message: &[u8]) -> i32 {
        let _ = source.info();
        let _ = source.capabilities();
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
        write_source_result(buffer, SearchRequest::OPERATION, source.search(request))
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
        write_source_result(buffer, MangaId::OPERATION, source.get_manga(request))
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
            ChapterListRequest::OPERATION,
            source.get_chapters(request),
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
        write_source_result(buffer, ChapterId::OPERATION, source.get_pages(request))
    }

    pub fn source_info<S: Source, const N: usize>(source: &S, buffer: &mut ResultBuffer<N>) -> u32 {
        let info = source.info();
        let capabilities = source.capabilities();
        buffer.write_source_metadata(&info, &capabilities)
    }

    pub fn get_listings<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(
            buffer,
            req_ptr,
            req_len,
            ListingsRequest::OPERATION,
            log_message,
        ) else {
            return buffer.last_ptr();
        };
        write_source_result(
            buffer,
            ListingsRequest::OPERATION,
            source.get_listings(request),
        )
    }

    pub fn get_manga_list<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(
            buffer,
            req_ptr,
            req_len,
            MangaListRequest::OPERATION,
            log_message,
        ) else {
            return buffer.last_ptr();
        };
        write_source_result(
            buffer,
            MangaListRequest::OPERATION,
            source.get_manga_list(request),
        )
    }

    pub fn get_home<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(
            buffer,
            req_ptr,
            req_len,
            HomeRequest::OPERATION,
            log_message,
        ) else {
            return buffer.last_ptr();
        };
        write_source_result(buffer, HomeRequest::OPERATION, source.get_home(request))
    }

    pub fn get_filters<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(
            buffer,
            req_ptr,
            req_len,
            FiltersRequest::OPERATION,
            log_message,
        ) else {
            return buffer.last_ptr();
        };
        write_source_result(
            buffer,
            FiltersRequest::OPERATION,
            source.get_filters(request),
        )
    }

    pub fn get_settings<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(
            buffer,
            req_ptr,
            req_len,
            SettingsRequest::OPERATION,
            log_message,
        ) else {
            return buffer.last_ptr();
        };
        write_source_result(
            buffer,
            SettingsRequest::OPERATION,
            source.get_settings(request),
        )
    }

    pub fn get_image_request<S: Source, const N: usize>(
        source: &S,
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        log_message: &[u8],
    ) -> u32 {
        let Some(request) = prepare_operation(
            buffer,
            req_ptr,
            req_len,
            ImageRequestInput::OPERATION,
            log_message,
        ) else {
            return buffer.last_ptr();
        };
        write_source_result(
            buffer,
            ImageRequestInput::OPERATION,
            source.get_image_request(request),
        )
    }

    fn prepare_operation<'a, R, const N: usize>(
        buffer: &mut ResultBuffer<N>,
        req_ptr: u32,
        req_len: u32,
        operation: &'static str,
        log_message: &[u8],
    ) -> Option<R>
    where
        R: OperationRequest<'a>,
    {
        let Some(request) = (unsafe { Request::from_abi(req_ptr, req_len) }) else {
            buffer.write_error("unknown", "invalid_request", "empty request");
            return None;
        };

        host::log_info(log_message);
        if !request.contains_json_string(b"operation", operation.as_bytes()) {
            buffer.write_error(operation, "invalid_request", "unexpected operation");
            return None;
        }

        if host::check_cancel() {
            buffer.write_error(operation, "cancelled", "host cancelled");
            return None;
        }

        Some(R::from_request(request))
    }

    fn write_source_result<const N: usize>(
        buffer: &mut ResultBuffer<N>,
        operation: &str,
        result: SourceResult,
    ) -> u32 {
        match result {
            Ok(data) => buffer.write_success(operation, data.bytes()),
            Err(error) => buffer.write_error(operation, error.code(), error.message()),
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
    use crate::source::{SourceCapabilities, SourceInfo};

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

        pub fn write_source_metadata(
            &mut self,
            info: &SourceInfo,
            capabilities: &SourceCapabilities,
        ) -> u32 {
            self.write_success_parts(
                "source_info",
                &[
                    br#"{"sourceInfo":{"id":""#,
                    info.id.as_bytes(),
                    br#"","name":""#,
                    info.name.as_bytes(),
                    br#"","version":""#,
                    info.version.as_bytes(),
                    br#"","apiVersion":""#,
                    info.api_version.as_bytes(),
                    br#"","language":""#,
                    info.language.as_bytes(),
                    br#"","author":""#,
                    info.author.as_bytes(),
                    br#"","description":""#,
                    info.description.as_bytes(),
                    br#"","contentRating":""#,
                    info.content_rating.as_bytes(),
                    br#""},"capabilities":{"search":"#,
                    bool_json(capabilities.search),
                    br#","mangaDetail":"#,
                    bool_json(capabilities.manga_detail),
                    br#","chapters":"#,
                    bool_json(capabilities.chapters),
                    br#","pages":"#,
                    bool_json(capabilities.pages),
                    br#","listings":"#,
                    bool_json(capabilities.listings),
                    br#","mangaList":"#,
                    bool_json(capabilities.manga_list),
                    br#","home":"#,
                    bool_json(capabilities.home),
                    br#","filters":"#,
                    bool_json(capabilities.filters),
                    br#","settings":"#,
                    bool_json(capabilities.settings),
                    br#","imageRequest":"#,
                    bool_json(capabilities.image_request),
                    br#","future":{"process_page_image":false,"page_description":false,"base_url":false,"login":false,"auth":false,"deeplink":false,"migration":false}}}"#,
                ],
            )
        }

        pub fn write_success_parts(&mut self, operation: &str, data_parts: &[&[u8]]) -> u32 {
            self.write_nested_parts(
                true,
                &[RESPONSE_PREFIX_OK, operation.as_bytes(), DATA_PREFIX],
                data_parts,
                &[SUCCESS_SUFFIX],
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

        fn write_nested_parts(
            &mut self,
            ok: bool,
            prefix: &[&[u8]],
            middle: &[&[u8]],
            suffix: &[&[u8]],
        ) -> u32 {
            let mut payload_len = 0_usize;
            for part in prefix {
                payload_len += part.len();
            }
            for part in middle {
                payload_len += part.len();
            }
            for part in suffix {
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
                for parts in [prefix, middle, suffix] {
                    for part in parts {
                        core::ptr::copy_nonoverlapping(part.as_ptr(), base.add(cursor), part.len());
                        cursor += part.len();
                    }
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

    fn bool_json(value: bool) -> &'static [u8] {
        if value {
            b"true"
        } else {
            b"false"
        }
    }
}

// === JSON/Buffer Utilities ===
//
// Byte-level helpers shared by source implementations. These are intentionally
// no_std / no_alloc and operate on caller-provided fixed-size buffers with a
// mutable cursor, matching the WASM source convention.
pub mod json_utils {
    pub fn write_bytes(dst: &mut [u8], cursor: &mut usize, src: &[u8]) -> bool {
        let end = *cursor + src.len();
        if end > dst.len() {
            return false;
        }
        dst[*cursor..end].copy_from_slice(src);
        *cursor = end;
        true
    }

    pub fn write_usize(dst: &mut [u8], cursor: &mut usize, val: usize) -> bool {
        let mut buf = [0u8; 20];
        let mut n = val;
        let mut len = 0;
        if n == 0 {
            buf[0] = b'0';
            len = 1;
        } else {
            while n > 0 {
                buf[len] = b'0' + (n % 10) as u8;
                n /= 10;
                len += 1;
            }
            let mut i = 0;
            let mut j = len - 1;
            while i < j {
                let tmp = buf[i];
                buf[i] = buf[j];
                buf[j] = tmp;
                i += 1;
                j -= 1;
            }
        }
        write_bytes(dst, cursor, &buf[..len])
    }

    pub fn append_json_escaped_byte(dst: &mut [u8], cursor: &mut usize, b: u8) -> bool {
        match b {
            b'"' => write_bytes(dst, cursor, b"\\\""),
            b'\\' => write_bytes(dst, cursor, b"\\\\"),
            b'\n' => write_bytes(dst, cursor, b"\\n"),
            b'\r' => write_bytes(dst, cursor, b"\\r"),
            b'\t' => write_bytes(dst, cursor, b"\\t"),
            0x08 => write_bytes(dst, cursor, b"\\b"),
            0x0c => write_bytes(dst, cursor, b"\\f"),
            _ if b < 0x20 => write_bytes(dst, cursor, b" "),
            _ => {
                if *cursor >= dst.len() {
                    return false;
                }
                dst[*cursor] = b;
                *cursor += 1;
                true
            }
        }
    }

    pub fn append_json_escaped(dst: &mut [u8], cursor: &mut usize, src: &[u8]) -> bool {
        for &b in src {
            if !append_json_escaped_byte(dst, cursor, b) {
                return false;
            }
        }
        true
    }

    pub fn hex_to_u16(hex: &[u8]) -> u16 {
        let mut val = 0u16;
        for &b in hex {
            let digit = match b {
                b'0'..=b'9' => (b - b'0') as u16,
                b'a'..=b'f' => (b - b'a' + 10) as u16,
                b'A'..=b'F' => (b - b'A' + 10) as u16,
                _ => return 0,
            };
            val = val * 16 + digit;
        }
        val
    }

    pub fn encode_utf8(cp: u32, buf: &mut [u8; 4]) -> usize {
        if cp < 0x80 {
            buf[0] = cp as u8;
            1
        } else if cp < 0x800 {
            buf[0] = 0xC0 | (cp >> 6) as u8;
            buf[1] = 0x80 | (cp & 0x3F) as u8;
            2
        } else if cp < 0x10000 {
            buf[0] = 0xE0 | (cp >> 12) as u8;
            buf[1] = 0x80 | ((cp >> 6) & 0x3F) as u8;
            buf[2] = 0x80 | (cp & 0x3F) as u8;
            3
        } else {
            buf[0] = 0xF0 | (cp >> 18) as u8;
            buf[1] = 0x80 | ((cp >> 12) & 0x3F) as u8;
            buf[2] = 0x80 | ((cp >> 6) & 0x3F) as u8;
            buf[3] = 0x80 | (cp & 0x3F) as u8;
            4
        }
    }

    pub fn append_json_unescaped_then_escaped(
        dst: &mut [u8],
        cursor: &mut usize,
        src: &[u8],
    ) -> bool {
        let mut i = 0usize;
        while i < src.len() {
            if src[i] == b'\\' && i + 1 < src.len() {
                let next = src[i + 1];
                match next {
                    b'/' => {
                        if !write_bytes(dst, cursor, b"/") {
                            return false;
                        }
                        i += 2;
                    }
                    b'"' => {
                        if !write_bytes(dst, cursor, b"\\\"") {
                            return false;
                        }
                        i += 2;
                    }
                    b'\\' => {
                        if !write_bytes(dst, cursor, b"\\\\") {
                            return false;
                        }
                        i += 2;
                    }
                    b'n' => {
                        if !write_bytes(dst, cursor, b"\\n") {
                            return false;
                        }
                        i += 2;
                    }
                    b'r' => {
                        if !write_bytes(dst, cursor, b"\\r") {
                            return false;
                        }
                        i += 2;
                    }
                    b't' => {
                        if !write_bytes(dst, cursor, b"\\t") {
                            return false;
                        }
                        i += 2;
                    }
                    b'u' if i + 5 < src.len() => {
                        let hex = &src[i + 2..i + 6];
                        let cp = hex_to_u16(hex);
                        if cp > 0 {
                            let mut utf8 = [0u8; 4];
                            let len = encode_utf8(cp as u32, &mut utf8);
                            let mut j = 0;
                            while j < len {
                                if !append_json_escaped_byte(dst, cursor, utf8[j]) {
                                    return false;
                                }
                                j += 1;
                            }
                            i += 6;
                        } else {
                            if *cursor >= dst.len() {
                                return false;
                            }
                            dst[*cursor] = src[i];
                            *cursor += 1;
                            i += 1;
                        }
                    }
                    _ => {
                        if !append_json_escaped_byte(dst, cursor, next) {
                            return false;
                        }
                        i += 2;
                    }
                }
            } else {
                if !append_json_escaped_byte(dst, cursor, src[i]) {
                    return false;
                }
                i += 1;
            }
        }
        true
    }

    pub fn write_url_encoded(dst: &mut [u8], cursor: &mut usize, src: &[u8]) -> bool {
        const HEX: &[u8; 16] = b"0123456789ABCDEF";
        for &b in src {
            let unreserved = (b >= b'A' && b <= b'Z')
                || (b >= b'a' && b <= b'z')
                || (b >= b'0' && b <= b'9')
                || b == b'-'
                || b == b'_'
                || b == b'.'
                || b == b'~';
            if unreserved {
                if *cursor >= dst.len() {
                    return false;
                }
                dst[*cursor] = b;
                *cursor += 1;
            } else {
                if *cursor + 3 > dst.len() {
                    return false;
                }
                dst[*cursor] = b'%';
                dst[*cursor + 1] = HEX[(b >> 4) as usize];
                dst[*cursor + 2] = HEX[(b & 0x0f) as usize];
                *cursor += 3;
            }
        }
        true
    }

    pub fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
        if needle.is_empty() || haystack.len() < needle.len() {
            return None;
        }
        let last = haystack.len() - needle.len();
        let mut i = 0usize;
        while i <= last {
            let mut matched = true;
            let mut j = 0usize;
            while j < needle.len() {
                if haystack[i + j] != needle[j] {
                    matched = false;
                    break;
                }
                j += 1;
            }
            if matched {
                return Some(i);
            }
            i += 1;
        }
        None
    }

    pub fn contains_bytes(haystack: &[u8], needle: &[u8]) -> bool {
        find_subslice(haystack, needle).is_some()
    }

    pub fn extract_json_string<'a>(data: &'a [u8], key: &[u8]) -> Option<&'a [u8]> {
        let mut pattern = [0u8; 64];
        let needed = key.len() + 4;
        if needed > pattern.len() {
            return None;
        }
        pattern[0] = b'"';
        pattern[1..1 + key.len()].copy_from_slice(key);
        pattern[1 + key.len()] = b'"';
        pattern[2 + key.len()] = b':';
        pattern[3 + key.len()] = b'"';
        let start = find_subslice(data, &pattern[..needed])? + needed;
        let mut i = start;
        while i < data.len() {
            let b = data[i];
            if b == b'\\' {
                i += 2;
                continue;
            }
            if b == b'"' {
                return Some(&data[start..i]);
            }
            i += 1;
        }
        None
    }

    pub fn extract_json_number<'a>(data: &'a [u8], key: &[u8]) -> Option<&'a [u8]> {
        let mut pattern = [0u8; 64];
        let needed = key.len() + 3;
        if needed > pattern.len() {
            return None;
        }
        pattern[0] = b'"';
        pattern[1..1 + key.len()].copy_from_slice(key);
        pattern[1 + key.len()] = b'"';
        pattern[2 + key.len()] = b':';
        let start = find_subslice(data, &pattern[..needed])? + needed;
        let mut i = start;
        while i < data.len()
            && (data[i] == b' ' || data[i] == b'\t' || data[i] == b'\n' || data[i] == b'\r')
        {
            i += 1;
        }
        let num_start = i;
        while i < data.len() && data[i] >= b'0' && data[i] <= b'9' {
            i += 1;
        }
        if i == num_start {
            return None;
        }
        Some(&data[num_start..i])
    }

    /// Iterate objects inside a JSON array under `array_key`.
    pub struct JsonArrayIter<'a> {
        data: &'a [u8],
        pos: usize,
    }

    impl<'a> JsonArrayIter<'a> {
        pub fn new(data: &'a [u8], array_key: &[u8]) -> Option<Self> {
            let mut pattern = [0u8; 64];
            let needed = array_key.len() + 4;
            if needed > pattern.len() {
                return None;
            }
            pattern[0] = b'"';
            pattern[1..1 + array_key.len()].copy_from_slice(array_key);
            pattern[1 + array_key.len()] = b'"';
            pattern[2 + array_key.len()] = b':';
            pattern[3 + array_key.len()] = b'[';
            let start = find_subslice(data, &pattern[..needed])? + needed;
            Some(Self { data, pos: start })
        }

        pub fn next_object(&mut self) -> Option<&'a [u8]> {
            while self.pos < self.data.len() {
                match self.data[self.pos] {
                    b' ' | b'\t' | b'\n' | b'\r' | b',' => self.pos += 1,
                    b']' => return None,
                    b'{' => break,
                    _ => return None,
                }
            }
            if self.pos >= self.data.len() {
                return None;
            }
            let start = self.pos;
            let mut depth = 0i32;
            let mut in_string = false;
            while self.pos < self.data.len() {
                let b = self.data[self.pos];
                if in_string {
                    if b == b'\\' {
                        self.pos += 1;
                    } else if b == b'"' {
                        in_string = false;
                    }
                } else {
                    match b {
                        b'"' => in_string = true,
                        b'{' | b'[' => depth += 1,
                        b'}' | b']' => {
                            depth -= 1;
                            if depth == 0 {
                                self.pos += 1;
                                return Some(&self.data[start..self.pos]);
                            }
                        }
                        _ => {}
                    }
                }
                self.pos += 1;
            }
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::request::Request;
    use crate::source::{MangaListRequest, OperationRequest, SearchRequest, SourceCapabilities};

    #[test]
    fn full_v02_fixture_capabilities_advertise_current_operation_surface() {
        let capabilities = SourceCapabilities::FULL_V02_FIXTURE;

        assert!(capabilities.search);
        assert!(capabilities.manga_detail);
        assert!(capabilities.chapters);
        assert!(capabilities.pages);
        assert!(capabilities.listings);
        assert!(capabilities.manga_list);
        assert!(capabilities.home);
        assert!(capabilities.filters);
        assert!(capabilities.settings);
        assert!(capabilities.image_request);
    }

    fn request_from(bytes: &[u8]) -> Request<'_> {
        Request::from_bytes_for_test(bytes).expect("non-empty request")
    }

    #[test]
    fn contains_json_number_matches_compact_pagination_limit() {
        let bytes: &[u8] =
            br#"{"operation":"get_manga_list","listingId":"all","cursor":"","limit":20}"#;
        let request = request_from(bytes);

        assert!(request.contains_json_number(b"limit", 20));
        assert!(!request.contains_json_number(b"limit", 21));
        assert!(!request.contains_json_number(b"offset", 20));
    }

    #[test]
    fn contains_json_number_rejects_digit_prefix_collision() {
        let bytes: &[u8] = br#"{"limit":200}"#;
        let request = request_from(bytes);

        assert!(request.contains_json_number(b"limit", 200));
        assert!(!request.contains_json_number(b"limit", 20));
    }

    #[test]
    fn manga_list_and_search_limit_is_wrappers_match_compact_pagination() {
        let manga_list_bytes: &[u8] =
            br#"{"operation":"get_manga_list","listingId":"all","cursor":"","limit":20}"#;
        let manga_list = MangaListRequest::from_request(request_from(manga_list_bytes));
        assert!(manga_list.limit_is(20));
        assert!(!manga_list.limit_is(50));

        let search_bytes: &[u8] = br#"{"operation":"search","query":"foo","limit":50}"#;
        let search = SearchRequest::from_request(request_from(search_bytes));
        assert!(search.limit_is(50));
        assert!(!search.limit_is(20));
    }
}

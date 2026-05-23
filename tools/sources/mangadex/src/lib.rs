#![no_std]

extern crate koma_source_sdk;

use koma_source_sdk::host::{self, http_request, log_info};
use koma_source_sdk::request::contains_bytes;
use koma_source_sdk::result::ResultBuffer;
use koma_source_sdk::source::{SourceCapabilities, SourceInfo};

const API_BASE: &[u8] = b"https://api.mangadex.org";
const COVERS_BASE: &[u8] = b"https://uploads.mangadex.org/covers/";
const PAYLOAD_CAP: usize = 128 * 1024;
const HTTP_OUT_CAP: usize = 512 * 1024;
const JSON_BUF_CAP: usize = 256 * 1024;
const HTTP_REQ_CAP: usize = 1024;
const SCRATCH_CAP: usize = 2048;

static mut RESPONSE: ResultBuffer<{ PAYLOAD_CAP + 256 }> = ResultBuffer::new();
static mut PAYLOAD_BUF: [u8; PAYLOAD_CAP] = [0; PAYLOAD_CAP];
static mut HTTP_OUT: [u8; HTTP_OUT_CAP] = [0; HTTP_OUT_CAP];
static mut JSON_BUF: [u8; JSON_BUF_CAP] = [0; JSON_BUF_CAP];
static mut HTTP_REQ_BUF: [u8; HTTP_REQ_CAP] = [0; HTTP_REQ_CAP];
static mut SCRATCH_A: [u8; SCRATCH_CAP] = [0; SCRATCH_CAP];

const SOURCE_INFO: SourceInfo = SourceInfo {
    id: "org.mangadex.koma",
    name: "MangaDex",
    version: "0.1.0",
    api_version: "0.2",
    language: "en",
    author: "Koma",
    description: "MangaDex API source (JSON, no HTML scraping).",
    content_rating: "unknown",
};

const SOURCE_CAPS: SourceCapabilities = SourceCapabilities {
    search: true,
    manga_detail: true,
    chapters: true,
    pages: true,
    listings: true,
    manga_list: true,
    home: false,
    filters: true,
    settings: false,
    image_request: true,
};

#[panic_handler]
fn panic(_: &core::panic::PanicInfo<'_>) -> ! {
    loop {}
}

fn response_buffer() -> &'static mut ResultBuffer<{ PAYLOAD_CAP + 256 }> {
    unsafe { &mut *core::ptr::addr_of_mut!(RESPONSE) }
}
fn payload_buf() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(PAYLOAD_BUF) }
}
fn http_out() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(HTTP_OUT) }
}
fn http_req_buf() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(HTTP_REQ_BUF) }
}
fn scratch_a() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(SCRATCH_A) }
}

fn payload_slice(len: usize) -> &'static [u8] {
    unsafe { core::slice::from_raw_parts(PAYLOAD_BUF.as_ptr(), len) }
}

fn write_error(operation: &str, code: &str, message: &str) -> u32 {
    response_buffer().write_error(operation, code, message)
}

fn write_success_payload(operation: &str, len: usize) -> u32 {
    response_buffer().write_success(operation, payload_slice(len))
}

fn read_request<'a>(req_ptr: u32, req_len: u32) -> Option<&'a [u8]> {
    if req_ptr == 0 || req_len == 0 { return None; }
    Some(unsafe { core::slice::from_raw_parts(req_ptr as *const u8, req_len as usize) })
}

// --- Byte manipulation helpers ---

fn write_bytes(dst: &mut [u8], cursor: &mut usize, src: &[u8]) -> bool {
    let end = *cursor + src.len();
    if end > dst.len() { return false; }
    dst[*cursor..end].copy_from_slice(src);
    *cursor = end;
    true
}

fn write_usize(dst: &mut [u8], cursor: &mut usize, val: usize) -> bool {
    let mut buf = [0u8; 10];
    let mut n = val;
    let mut len = 0;
    if n == 0 { buf[0] = b'0'; len = 1; }
    else {
        while n > 0 { buf[len] = b'0' + (n % 10) as u8; n /= 10; len += 1; }
        let mut i = 0; let mut j = len - 1;
        while i < j { let t = buf[i]; buf[i] = buf[j]; buf[j] = t; i += 1; j -= 1; }
    }
    write_bytes(dst, cursor, &buf[..len])
}

fn append_json_escaped(dst: &mut [u8], cursor: &mut usize, src: &[u8]) -> bool {
    for &b in src {
        let escape: Option<&[u8]> = match b {
            b'"' => Some(b"\\\""),
            b'\\' => Some(b"\\\\"),
            b'\n' => Some(b"\\n"),
            b'\r' => Some(b"\\r"),
            b'\t' => Some(b"\\t"),
            0x08 => Some(b"\\b"),
            0x0c => Some(b"\\f"),
            _ if b < 0x20 => Some(b" "),
            _ => None,
        };
        match escape {
            Some(seq) => { if !write_bytes(dst, cursor, seq) { return false; } }
            None => {
                if *cursor >= dst.len() { return false; }
                dst[*cursor] = b;
                *cursor += 1;
            }
        }
    }
    true
}

fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    if needle.is_empty() || haystack.len() < needle.len() { return None; }
    let last = haystack.len() - needle.len();
    let mut i = 0usize;
    while i <= last {
        if &haystack[i..i+needle.len()] == needle { return Some(i); }
        i += 1;
    }
    None
}

fn write_url_encoded(dst: &mut [u8], cursor: &mut usize, src: &[u8]) -> bool {
    for &b in src {
        let unreserved = (b >= b'A' && b <= b'Z') || (b >= b'a' && b <= b'z')
            || (b >= b'0' && b <= b'9') || b == b'-' || b == b'_' || b == b'.' || b == b'~';
        if unreserved {
            if *cursor >= dst.len() { return false; }
            dst[*cursor] = b;
            *cursor += 1;
        } else {
            if *cursor + 3 > dst.len() { return false; }
            const HEX: &[u8; 16] = b"0123456789ABCDEF";
            dst[*cursor] = b'%';
            dst[*cursor + 1] = HEX[(b >> 4) as usize];
            dst[*cursor + 2] = HEX[(b & 0x0f) as usize];
            *cursor += 3;
        }
    }
    true
}

// --- JSON helpers (manual byte-level parsing for no_std) ---

/// Extract a JSON string value for "key":"value" pattern
fn extract_json_string<'a>(data: &'a [u8], key: &[u8]) -> Option<&'a [u8]> {
    let mut pattern = [0u8; 64];
    let needed = key.len() + 4; // "key":"
    if needed > pattern.len() { return None; }
    pattern[0] = b'"';
    pattern[1..1+key.len()].copy_from_slice(key);
    pattern[1+key.len()] = b'"';
    pattern[2+key.len()] = b':';
    pattern[3+key.len()] = b'"';
    let start = find_subslice(data, &pattern[..needed])? + needed;
    let mut i = start;
    while i < data.len() {
        if data[i] == b'\\' { i += 2; continue; }
        if data[i] == b'"' { return Some(&data[start..i]); }
        i += 1;
    }
    None
}

/// Extract a JSON number for "key":123 pattern
fn extract_json_number<'a>(data: &'a [u8], key: &[u8]) -> Option<&'a [u8]> {
    let mut pattern = [0u8; 64];
    let needed = key.len() + 3; // "key":
    if needed > pattern.len() { return None; }
    pattern[0] = b'"';
    pattern[1..1+key.len()].copy_from_slice(key);
    pattern[1+key.len()] = b'"';
    pattern[2+key.len()] = b':';
    let start = find_subslice(data, &pattern[..needed])? + needed;
    let mut i = start;
    while i < data.len() && (data[i] == b' ' || data[i] == b'\t') { i += 1; }
    let num_start = i;
    while i < data.len() && data[i] >= b'0' && data[i] <= b'9' { i += 1; }
    if i == num_start { return None; }
    Some(&data[num_start..i])
}

fn json_buf() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(JSON_BUF) }
}

// --- HTTP helper ---

fn build_get_request(dst: &mut [u8], url: &[u8]) -> Option<usize> {
    let mut cursor = 0usize;
    let prefix = br#"{"version":1,"method":"GET","url":""#;
    let suffix = br#"","headers":{"User-Agent":"koma-source-dev/0.1"},"timeoutMs":15000,"responseKind":"bodyText"}"#;
    write_bytes(dst, &mut cursor, prefix).then_some(())?;
    append_json_escaped(dst, &mut cursor, url).then_some(())?;
    write_bytes(dst, &mut cursor, suffix).then_some(())?;
    Some(cursor)
}

/// Fetch URL and return raw JSON response body bytes (from bodyText field)
fn fetch_json(url_bytes: &[u8]) -> Option<&'static [u8]> {
    let req_len = build_get_request(http_req_buf(), url_bytes)?;
    let req_slice = &http_req_buf()[..req_len];
    let resp_len = http_request(req_slice, http_out()).ok()?;
    let resp = &http_out()[..resp_len];
    if !contains_bytes(resp, br#""ok":true"#) {
        log_info(b"mangadex: http response not ok");
        return None;
    }
    // Extract bodyText value - it's a JSON string containing the API response
    let body_marker = b"\"bodyText\":\"";
    let body_start = find_subslice(resp, body_marker)? + body_marker.len();
    // Unescape the JSON string into JSON_BUF (large buffer)
    let out = json_buf();
    let mut out_cursor = 0usize;
    let mut i = body_start;
    while i < resp.len() {
        let b = resp[i];
        if b == b'\\' && i + 1 < resp.len() {
            let next = resp[i + 1];
            let unescaped = match next {
                b'"' => b'"', b'\\' => b'\\', b'/' => b'/',
                b'n' => b'\n', b'r' => b'\r', b't' => b'\t',
                _ => next,
            };
            if out_cursor >= out.len() { return None; }
            out[out_cursor] = unescaped;
            out_cursor += 1;
            i += 2;
            continue;
        }
        if b == b'"' { break; }
        if out_cursor >= out.len() { return None; }
        out[out_cursor] = b;
        out_cursor += 1;
        i += 1;
    }
    Some(unsafe { core::slice::from_raw_parts(JSON_BUF.as_ptr(), out_cursor) })
}

// --- Iterator for JSON array objects ---
// Walk through a JSON array and yield start/end byte offsets of each object

struct JsonArrayIter<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> JsonArrayIter<'a> {
    fn new(data: &'a [u8], array_key: &[u8]) -> Option<Self> {
        // Find "key":[ and position after [
        let mut pattern = [0u8; 64];
        let needed = array_key.len() + 4; // "key":[
        if needed > pattern.len() { return None; }
        pattern[0] = b'"';
        pattern[1..1+array_key.len()].copy_from_slice(array_key);
        pattern[1+array_key.len()] = b'"';
        pattern[2+array_key.len()] = b':';
        pattern[3+array_key.len()] = b'[';
        let start = find_subslice(data, &pattern[..needed])? + needed;
        Some(Self { data, pos: start })
    }

    fn next_object(&mut self) -> Option<&'a [u8]> {
        // Skip whitespace and commas
        while self.pos < self.data.len() {
            match self.data[self.pos] {
                b' ' | b'\t' | b'\n' | b'\r' | b',' => self.pos += 1,
                b']' => return None,
                b'{' => break,
                _ => return None,
            }
        }
        if self.pos >= self.data.len() { return None; }
        // Find matching }
        let start = self.pos;
        let mut depth = 0i32;
        let mut in_string = false;
        while self.pos < self.data.len() {
            let b = self.data[self.pos];
            if in_string {
                if b == b'\\' { self.pos += 1; }
                else if b == b'"' { in_string = false; }
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

// --- Operations ---

fn run_search(req: &[u8]) -> u32 {
    let query = match extract_json_string(req, b"query") {
        Some(q) => q,
        None => return write_error("search", "invalid_request", "missing query"),
    };

    // Build URL: /manga?title=...&limit=20&includes[]=cover_art
    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    let ok = write_bytes(url_buf, &mut url_cursor, API_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/manga?title=")
        && write_url_encoded(url_buf, &mut url_cursor, query)
        && write_bytes(url_buf, &mut url_cursor, b"&limit=20&includes%5B%5D=cover_art");
    if !ok { return write_error("search", "internal_error", "url overflow"); }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let api_json = match fetch_json(url_bytes) {
        Some(v) => v,
        None => return write_error("search", "source_error", "fetch failed"),
    };

    // Parse the "data" array
    let payload = payload_buf();
    let mut c = 0usize;
    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("search", "internal_error", "overflow");
    }

    let mut iter = match JsonArrayIter::new(api_json, b"data") {
        Some(it) => it,
        None => return write_error("search", "parse_error", "no data array"),
    };

    let mut written = 0usize;
    while let Some(obj) = iter.next_object() {
        if written >= 20 { break; }
        // Extract: id, title (en or first), status
        let id = match extract_json_string(obj, b"id") {
            Some(v) => v,
            None => continue,
        };
        // Title: look for "en":"..." inside "title":{...}
        let title = extract_json_string(obj, b"en")
            .or_else(|| extract_json_string(obj, b"ja"))
            .or_else(|| extract_json_string(obj, b"ja-ro"))
            .unwrap_or(b"Unknown");
        let status = extract_json_string(obj, b"status").unwrap_or(b"unknown");

        // Cover: find fileName in relationships where type=cover_art
        let cover_fn = extract_cover_filename(obj);

        if written > 0 {
            if !write_bytes(payload, &mut c, b",") { break; }
        }
        let ok = write_bytes(payload, &mut c, br#"{"id":"mdx:"#)
            && append_json_escaped(payload, &mut c, id)
            && write_bytes(payload, &mut c, br#"","title":""#)
            && append_json_escaped(payload, &mut c, title)
            && write_bytes(payload, &mut c, br#"","cover":{"kind":"url","url":""#)
            && write_bytes(payload, &mut c, COVERS_BASE)
            && append_json_escaped(payload, &mut c, id)
            && write_bytes(payload, &mut c, b"/");
        if !ok { break; }
        if let Some(cfn) = cover_fn {
            if !append_json_escaped(payload, &mut c, cfn) { break; }
        } else {
            if !write_bytes(payload, &mut c, b"none.jpg") { break; }
        }
        let ok2 = write_bytes(payload, &mut c, br#""},"authors":[],"status":""#)
            && append_json_escaped(payload, &mut c, status)
            && write_bytes(payload, &mut c, br#"","contentRating":"unknown","sourceTags":["mangadex"]}"#);
        if !ok2 { break; }
        written += 1;
    }

    if !write_bytes(payload, &mut c, br#"],"page":{"nextCursor":null,"hasMore":false}}"#) {
        return write_error("search", "internal_error", "overflow");
    }
    write_success_payload("search", c)
}

fn extract_cover_filename<'a>(obj: &'a [u8]) -> Option<&'a [u8]> {
    // Look for "fileName":"..." after "type":"cover_art"
    let marker = b"\"type\":\"cover_art\"";
    let idx = find_subslice(obj, marker)?;
    // Look for fileName after this point
    let rest = &obj[idx..];
    extract_json_string(rest, b"fileName")
}

fn run_get_manga(req: &[u8]) -> u32 {
    let manga_id = match extract_json_string(req, b"mangaId") {
        Some(v) => v,
        None => return write_error("get_manga", "invalid_request", "missing mangaId"),
    };
    let prefix = b"mdx:";
    if manga_id.len() <= prefix.len() || &manga_id[..prefix.len()] != prefix {
        return write_error("get_manga", "invalid_request", "bad mangaId format");
    }
    let uuid = &manga_id[prefix.len()..];

    // /manga/{id}?includes[]=cover_art&includes[]=author&includes[]=artist
    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    let ok = write_bytes(url_buf, &mut url_cursor, API_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/manga/")
        && write_bytes(url_buf, &mut url_cursor, uuid)
        && write_bytes(url_buf, &mut url_cursor, b"?includes%5B%5D=cover_art&includes%5B%5D=author&includes%5B%5D=artist");
    if !ok { return write_error("get_manga", "internal_error", "url overflow"); }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let api_json = match fetch_json(url_bytes) {
        Some(v) => v,
        None => return write_error("get_manga", "source_error", "fetch failed"),
    };

    // Parse manga object from "data":{...}
    let data_marker = b"\"data\":{";
    let data_start = match find_subslice(api_json, data_marker) {
        Some(idx) => idx + data_marker.len() - 1, // include {
        None => return write_error("get_manga", "parse_error", "no data"),
    };
    // Find the end of this object
    let obj = &api_json[data_start..];

    let title = extract_json_string(obj, b"en")
        .or_else(|| extract_json_string(obj, b"ja"))
        .or_else(|| extract_json_string(obj, b"ja-ro"))
        .unwrap_or(b"Unknown");
    let status = extract_json_string(obj, b"status").unwrap_or(b"unknown");
    let desc = extract_json_string(obj, b"en").unwrap_or(b""); // description.en
    let cover_fn = extract_cover_filename(obj);

    // Extract author names from relationships
    let author_name = extract_author_name(obj);

    // Extract tags
    let payload = payload_buf();
    let mut c = 0usize;
    let ok = write_bytes(payload, &mut c, br#"{"manga":{"id":"mdx:"#)
        && append_json_escaped(payload, &mut c, uuid)
        && write_bytes(payload, &mut c, br#"","title":""#)
        && append_json_escaped(payload, &mut c, title)
        && write_bytes(payload, &mut c, br#"","alternateTitles":[],"description":""#)
        && append_json_escaped(payload, &mut c, desc)
        && write_bytes(payload, &mut c, br#"","cover":{"kind":"url","url":""#)
        && write_bytes(payload, &mut c, COVERS_BASE)
        && append_json_escaped(payload, &mut c, uuid)
        && write_bytes(payload, &mut c, b"/");
    if !ok { return write_error("get_manga", "internal_error", "overflow"); }
    if let Some(cfn) = cover_fn {
        if !append_json_escaped(payload, &mut c, cfn) {
            return write_error("get_manga", "internal_error", "overflow");
        }
    } else {
        if !write_bytes(payload, &mut c, b"none.jpg") {
            return write_error("get_manga", "internal_error", "overflow");
        }
    }
    let ok2 = write_bytes(payload, &mut c, br#""},"authors":["#);
    if !ok2 { return write_error("get_manga", "internal_error", "overflow"); }
    if let Some(author) = author_name {
        let _ = write_bytes(payload, &mut c, b"\"")
            && append_json_escaped(payload, &mut c, author)
            && write_bytes(payload, &mut c, b"\"");
    }
    let ok3 = write_bytes(payload, &mut c, br#"],"artists":[],"status":""#)
        && append_json_escaped(payload, &mut c, status)
        && write_bytes(payload, &mut c, br#"","contentRating":"unknown","language":"en","tags":[],"links":[]}}"#);
    if !ok3 { return write_error("get_manga", "internal_error", "overflow"); }

    write_success_payload("get_manga", c)
}

fn extract_author_name<'a>(obj: &'a [u8]) -> Option<&'a [u8]> {
    let marker = b"\"type\":\"author\"";
    let idx = find_subslice(obj, marker)?;
    let rest = &obj[idx..];
    extract_json_string(rest, b"name")
}

fn run_get_chapters(req: &[u8]) -> u32 {
    let manga_id = match extract_json_string(req, b"mangaId") {
        Some(v) => v,
        None => return write_error("get_chapters", "invalid_request", "missing mangaId"),
    };
    let prefix = b"mdx:";
    if manga_id.len() <= prefix.len() || &manga_id[..prefix.len()] != prefix {
        return write_error("get_chapters", "invalid_request", "bad mangaId");
    }
    let uuid = &manga_id[prefix.len()..];

    // /manga/{id}/feed?limit=100&translatedLanguage[]=en&order[chapter]=desc
    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    let ok = write_bytes(url_buf, &mut url_cursor, API_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/manga/")
        && write_bytes(url_buf, &mut url_cursor, uuid)
        && write_bytes(url_buf, &mut url_cursor, b"/feed?limit=100&translatedLanguage%5B%5D=en&order%5Bchapter%5D=desc");
    if !ok { return write_error("get_chapters", "internal_error", "url overflow"); }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let api_json = match fetch_json(url_bytes) {
        Some(v) => v,
        None => return write_error("get_chapters", "source_error", "fetch failed"),
    };

    let payload = payload_buf();
    let mut c = 0usize;
    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("get_chapters", "internal_error", "overflow");
    }

    let mut iter = match JsonArrayIter::new(api_json, b"data") {
        Some(it) => it,
        None => return write_error("get_chapters", "parse_error", "no data"),
    };

    let mut written = 0usize;
    while let Some(obj) = iter.next_object() {
        if written >= 100 { break; }
        let ch_id = match extract_json_string(obj, b"id") {
            Some(v) => v,
            None => continue,
        };
        let chapter_num = extract_json_string(obj, b"chapter").unwrap_or(b"0");
        let title = extract_json_string(obj, b"title").unwrap_or(b"");
        let lang = extract_json_string(obj, b"translatedLanguage").unwrap_or(b"en");
        let pages = extract_json_number(obj, b"pages");

        if written > 0 {
            if !write_bytes(payload, &mut c, b",") { break; }
        }
        let ok = write_bytes(payload, &mut c, br#"{"id":"ch:"#)
            && append_json_escaped(payload, &mut c, ch_id)
            && write_bytes(payload, &mut c, br#"","mangaId":"mdx:"#)
            && append_json_escaped(payload, &mut c, uuid)
            && write_bytes(payload, &mut c, br#"","title":""#)
            && append_json_escaped(payload, &mut c, title)
            && write_bytes(payload, &mut c, br#"","chapterNumber":""#)
            && append_json_escaped(payload, &mut c, chapter_num)
            && write_bytes(payload, &mut c, br#"","volumeNumber":null,"language":""#)
            && append_json_escaped(payload, &mut c, lang)
            && write_bytes(payload, &mut c, br#"","publishedAt":null,"updatedAt":null,"pageCount":"#);
        if !ok { break; }
        if let Some(p) = pages {
            if !write_bytes(payload, &mut c, p) { break; }
        } else {
            if !write_bytes(payload, &mut c, b"null") { break; }
        }
        if !write_bytes(payload, &mut c, b"}") { break; }
        written += 1;
    }

    if !write_bytes(payload, &mut c, br#"],"page":{"nextCursor":null,"hasMore":false}}"#) {
        return write_error("get_chapters", "internal_error", "overflow");
    }
    write_success_payload("get_chapters", c)
}

fn run_get_pages(req: &[u8]) -> u32 {
    let chapter_id = match extract_json_string(req, b"chapterId") {
        Some(v) => v,
        None => return write_error("get_pages", "invalid_request", "missing chapterId"),
    };
    let prefix = b"ch:";
    if chapter_id.len() <= prefix.len() || &chapter_id[..prefix.len()] != prefix {
        return write_error("get_pages", "invalid_request", "bad chapterId");
    }
    let ch_uuid = &chapter_id[prefix.len()..];

    // /at-home/server/{chapterId}
    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    let ok = write_bytes(url_buf, &mut url_cursor, API_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/at-home/server/")
        && write_bytes(url_buf, &mut url_cursor, ch_uuid);
    if !ok { return write_error("get_pages", "internal_error", "url overflow"); }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let api_json = match fetch_json(url_bytes) {
        Some(v) => v,
        None => return write_error("get_pages", "source_error", "fetch failed"),
    };

    // Extract baseUrl and hash
    let base_url = match extract_json_string(api_json, b"baseUrl") {
        Some(v) => v,
        None => return write_error("get_pages", "parse_error", "no baseUrl"),
    };
    let hash = match extract_json_string(api_json, b"hash") {
        Some(v) => v,
        None => return write_error("get_pages", "parse_error", "no hash"),
    };

    // Parse "data":["file1.png","file2.png",...]
    let payload = payload_buf();
    let mut c = 0usize;
    let ok2 = write_bytes(payload, &mut c, br#"{"chapterId":"ch:"#)
        && append_json_escaped(payload, &mut c, ch_uuid)
        && write_bytes(payload, &mut c, br#"","pages":["#);
    if !ok2 { return write_error("get_pages", "internal_error", "overflow"); }

    // Find "data":[ array and extract filenames
    let data_arr_marker = b"\"data\":[";
    let arr_start = match find_subslice(api_json, data_arr_marker) {
        Some(idx) => idx + data_arr_marker.len(),
        None => return write_error("get_pages", "parse_error", "no data array"),
    };

    let mut i = arr_start;
    let mut page_idx = 0usize;
    while i < api_json.len() {
        // Skip whitespace/commas
        while i < api_json.len() && (api_json[i] == b' ' || api_json[i] == b',' || api_json[i] == b'\n' || api_json[i] == b'\r') {
            i += 1;
        }
        if i >= api_json.len() || api_json[i] == b']' { break; }
        if api_json[i] != b'"' { break; }
        // Read string
        i += 1; // skip opening "
        let str_start = i;
        while i < api_json.len() && api_json[i] != b'"' {
            if api_json[i] == b'\\' { i += 1; }
            i += 1;
        }
        let filename = &api_json[str_start..i];
        i += 1; // skip closing "

        if page_idx > 0 {
            if !write_bytes(payload, &mut c, b",") { break; }
        }
        // Build full URL: {baseUrl}/data/{hash}/{filename}
        let ok3 = write_bytes(payload, &mut c, br#"{"id":"page:"#)
            && write_usize(payload, &mut c, page_idx)
            && write_bytes(payload, &mut c, br#"","index":"#)
            && write_usize(payload, &mut c, page_idx)
            && write_bytes(payload, &mut c, br#","image":{"kind":"url","url":""#)
            && append_json_escaped(payload, &mut c, base_url)
            && write_bytes(payload, &mut c, b"/data/")
            && append_json_escaped(payload, &mut c, hash)
            && write_bytes(payload, &mut c, b"/")
            && append_json_escaped(payload, &mut c, filename)
            && write_bytes(payload, &mut c, br#""}}"#);
        if !ok3 { break; }
        page_idx += 1;
    }

    if !write_bytes(payload, &mut c, b"]}") {
        return write_error("get_pages", "internal_error", "overflow");
    }
    write_success_payload("get_pages", c)
}

fn run_get_listings(_req: &[u8]) -> u32 {
    // Popular new titles: /manga?order[followedCount]=desc&limit=20&includes[]=cover_art
    let url = b"https://api.mangadex.org/manga?order%5BfollowedCount%5D=desc&limit=20&includes%5B%5D=cover_art";

    let api_json = match fetch_json(url) {
        Some(v) => v,
        None => return write_error("get_listings", "source_error", "fetch failed"),
    };

    let payload = payload_buf();
    let mut c = 0usize;
    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("get_listings", "internal_error", "overflow");
    }

    let mut iter = match JsonArrayIter::new(api_json, b"data") {
        Some(it) => it,
        None => return write_error("get_listings", "parse_error", "no data"),
    };

    let mut written = 0usize;
    while let Some(obj) = iter.next_object() {
        if written >= 20 { break; }
        let id = match extract_json_string(obj, b"id") {
            Some(v) => v,
            None => continue,
        };
        let title = extract_json_string(obj, b"en")
            .or_else(|| extract_json_string(obj, b"ja"))
            .unwrap_or(b"Unknown");
        let status = extract_json_string(obj, b"status").unwrap_or(b"unknown");
        let cover_fn = extract_cover_filename(obj);

        if written > 0 {
            if !write_bytes(payload, &mut c, b",") { break; }
        }
        let ok = write_bytes(payload, &mut c, br#"{"id":"mdx:"#)
            && append_json_escaped(payload, &mut c, id)
            && write_bytes(payload, &mut c, br#"","title":""#)
            && append_json_escaped(payload, &mut c, title)
            && write_bytes(payload, &mut c, br#"","cover":{"kind":"url","url":""#)
            && write_bytes(payload, &mut c, COVERS_BASE)
            && append_json_escaped(payload, &mut c, id)
            && write_bytes(payload, &mut c, b"/");
        if !ok { break; }
        if let Some(cfn) = cover_fn {
            if !append_json_escaped(payload, &mut c, cfn) { break; }
        } else {
            if !write_bytes(payload, &mut c, b"none.jpg") { break; }
        }
        let ok2 = write_bytes(payload, &mut c, br#""},"authors":[],"status":""#)
            && append_json_escaped(payload, &mut c, status)
            && write_bytes(payload, &mut c, br#"","contentRating":"unknown","sourceTags":["mangadex"]}"#);
        if !ok2 { break; }
        written += 1;
    }

    if !write_bytes(payload, &mut c, br#"],"page":{"nextCursor":null,"hasMore":false}}"#) {
        return write_error("get_listings", "internal_error", "overflow");
    }
    write_success_payload("get_listings", c)
}

// --- get_filters: return browseable filter definitions ---

fn run_get_filters(_req: &[u8]) -> u32 {
    // MangaDex filters: status, contentRating, publicationDemographic, order
    // We keep a static definition; tags would require an API call to /manga/tag
    // but the most useful browsing filters are these fixed enums.
    const FILTERS_JSON: &[u8] = br#"{"filters":[{"id":"status","name":"Status","kind":"select","options":[{"value":"all","label":"All"},{"value":"ongoing","label":"Ongoing"},{"value":"completed","label":"Completed"},{"value":"hiatus","label":"Hiatus"},{"value":"cancelled","label":"Cancelled"}],"default":"all"},{"id":"contentRating","name":"Content Rating","kind":"select","options":[{"value":"all","label":"All"},{"value":"safe","label":"Safe"},{"value":"suggestive","label":"Suggestive"},{"value":"erotica","label":"Erotica"}],"default":"all"},{"id":"demographic","name":"Demographic","kind":"select","options":[{"value":"all","label":"All"},{"value":"shounen","label":"Shounen"},{"value":"shoujo","label":"Shoujo"},{"value":"seinen","label":"Seinen"},{"value":"josei","label":"Josei"}],"default":"all"},{"id":"order","name":"Order By","kind":"select","options":[{"value":"relevance","label":"Relevance"},{"value":"followedCount","label":"Popularity"},{"value":"latestUploadedChapter","label":"Latest Upload"},{"value":"createdAt","label":"Newest"},{"value":"title","label":"Title"}],"default":"relevance"}]}"#;

    let payload = payload_buf();
    let flen = FILTERS_JSON.len();
    if flen > payload.len() {
        return write_error("get_filters", "internal_error", "payload overflow");
    }
    payload[..flen].copy_from_slice(FILTERS_JSON);
    write_success_payload("get_filters", flen)
}

// --- get_manga_list: browse with filters ---

fn run_get_manga_list(req: &[u8]) -> u32 {
    // Extract filter parameters from request
    let status = extract_json_string(req, b"status").unwrap_or(b"all");
    let content_rating = extract_json_string(req, b"contentRating").unwrap_or(b"all");
    let demographic = extract_json_string(req, b"demographic").unwrap_or(b"all");
    let order = extract_json_string(req, b"order").unwrap_or(b"relevance");
    let page_bytes = extract_json_number(req, b"page");
    let page_num = if let Some(pb) = page_bytes {
        let mut n = 0usize;
        for &b in pb { n = n * 10 + (b - b'0') as usize; }
        if n == 0 { 1 } else { n }
    } else { 1 };
    let offset_val = (page_num - 1) * 20;

    // Build URL: /manga?limit=20&offset=N&includes[]=cover_art + optional filters
    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    let ok = write_bytes(url_buf, &mut url_cursor, API_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/manga?limit=20&includes%5B%5D=cover_art&offset=")
        && write_usize(url_buf, &mut url_cursor, offset_val);
    if !ok { return write_error("get_manga_list", "internal_error", "url overflow"); }

    // Append status filter
    if status != b"all" {
        let ok2 = write_bytes(url_buf, &mut url_cursor, b"&status%5B%5D=")
            && write_bytes(url_buf, &mut url_cursor, status);
        if !ok2 { return write_error("get_manga_list", "internal_error", "url overflow"); }
    }
    // Append contentRating filter
    if content_rating != b"all" {
        let ok2 = write_bytes(url_buf, &mut url_cursor, b"&contentRating%5B%5D=")
            && write_bytes(url_buf, &mut url_cursor, content_rating);
        if !ok2 { return write_error("get_manga_list", "internal_error", "url overflow"); }
    } else {
        // Default: include safe + suggestive
        let ok2 = write_bytes(url_buf, &mut url_cursor, b"&contentRating%5B%5D=safe&contentRating%5B%5D=suggestive");
        if !ok2 { return write_error("get_manga_list", "internal_error", "url overflow"); }
    }
    // Append demographic filter
    if demographic != b"all" {
        let ok2 = write_bytes(url_buf, &mut url_cursor, b"&publicationDemographic%5B%5D=")
            && write_bytes(url_buf, &mut url_cursor, demographic);
        if !ok2 { return write_error("get_manga_list", "internal_error", "url overflow"); }
    }
    // Append order
    if order != b"relevance" {
        let ok2 = write_bytes(url_buf, &mut url_cursor, b"&order%5B")
            && write_bytes(url_buf, &mut url_cursor, order)
            && write_bytes(url_buf, &mut url_cursor, b"%5D=desc");
        if !ok2 { return write_error("get_manga_list", "internal_error", "url overflow"); }
    }

    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let api_json = match fetch_json(url_bytes) {
        Some(v) => v,
        None => return write_error("get_manga_list", "source_error", "fetch failed"),
    };

    // Parse total from response for hasMore
    let total = extract_json_number(api_json, b"total")
        .and_then(|t| {
            let mut n = 0usize;
            for &b in t { n = n * 10 + (b - b'0') as usize; }
            Some(n)
        })
        .unwrap_or(0);
    let has_more = offset_val + 20 < total;

    let payload = payload_buf();
    let mut c = 0usize;
    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("get_manga_list", "internal_error", "overflow");
    }

    let mut iter = match JsonArrayIter::new(api_json, b"data") {
        Some(it) => it,
        None => return write_error("get_manga_list", "parse_error", "no data"),
    };

    let mut written = 0usize;
    while let Some(obj) = iter.next_object() {
        if written >= 20 { break; }
        let id = match extract_json_string(obj, b"id") {
            Some(v) => v,
            None => continue,
        };
        let title = extract_json_string(obj, b"en")
            .or_else(|| extract_json_string(obj, b"ja"))
            .or_else(|| extract_json_string(obj, b"ja-ro"))
            .unwrap_or(b"Unknown");
        let st = extract_json_string(obj, b"status").unwrap_or(b"unknown");
        let cover_fn = extract_cover_filename(obj);

        if written > 0 {
            if !write_bytes(payload, &mut c, b",") { break; }
        }
        let ok = write_bytes(payload, &mut c, br#"{"id":"mdx:"#)
            && append_json_escaped(payload, &mut c, id)
            && write_bytes(payload, &mut c, br#"","title":""#)
            && append_json_escaped(payload, &mut c, title)
            && write_bytes(payload, &mut c, br#"","cover":{"kind":"url","url":""#)
            && write_bytes(payload, &mut c, COVERS_BASE)
            && append_json_escaped(payload, &mut c, id)
            && write_bytes(payload, &mut c, b"/");
        if !ok { break; }
        if let Some(cfn) = cover_fn {
            if !append_json_escaped(payload, &mut c, cfn) { break; }
        } else {
            if !write_bytes(payload, &mut c, b"none.jpg") { break; }
        }
        let ok2 = write_bytes(payload, &mut c, br#""},"authors":[],"status":""#)
            && append_json_escaped(payload, &mut c, st)
            && write_bytes(payload, &mut c, br#"","contentRating":"unknown","sourceTags":["mangadex"]}"#);
        if !ok2 { break; }
        written += 1;
    }

    // Close items array and add pagination info
    let ok_close = write_bytes(payload, &mut c, br#"],"page":{"nextCursor":""#)
        && write_usize(payload, &mut c, page_num + 1)
        && write_bytes(payload, &mut c, br#"","hasMore":"#);
    if !ok_close { return write_error("get_manga_list", "internal_error", "overflow"); }
    if has_more {
        if !write_bytes(payload, &mut c, b"true}}") {
            return write_error("get_manga_list", "internal_error", "overflow");
        }
    } else {
        if !write_bytes(payload, &mut c, b"false}}") {
            return write_error("get_manga_list", "internal_error", "overflow");
        }
    }

    write_success_payload("get_manga_list", c)
}

// --- modify_image_request: pass-through (MangaDex CDN needs no special headers) ---

fn run_image_request(req: &[u8]) -> u32 {
    // Just return the URL and empty headers as-is
    let url = match extract_json_string(req, b"url") {
        Some(u) => u,
        None => return write_error("image_request", "invalid_request", "missing url"),
    };

    let payload = payload_buf();
    let mut c = 0usize;
    let ok = write_bytes(payload, &mut c, br#"{"url":""#)
        && append_json_escaped(payload, &mut c, url)
        && write_bytes(payload, &mut c, br#"","headers":{}}"#);
    if !ok { return write_error("image_request", "internal_error", "overflow"); }
    write_success_payload("image_request", c)
}

// --- Exports ---

#[no_mangle]
pub extern "C" fn koma_source_init(_manifest_ptr: u32, manifest_len: u32) -> i32 {
    log_info(b"mangadex source init");
    if host::check_cancel() { return -2; }
    if manifest_len > 0 { 0 } else { -1 }
}

#[no_mangle]
pub extern "C" fn koma_source_info() -> u32 {
    response_buffer().write_source_metadata(&SOURCE_INFO, &SOURCE_CAPS)
}

#[no_mangle]
pub extern "C" fn koma_source_search(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("search", "invalid_request", "empty"),
    };
    log_info(b"mangadex search");
    run_search(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_manga(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_manga", "invalid_request", "empty"),
    };
    log_info(b"mangadex get_manga");
    run_get_manga(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_chapters(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_chapters", "invalid_request", "empty"),
    };
    log_info(b"mangadex get_chapters");
    run_get_chapters(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_pages(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_pages", "invalid_request", "empty"),
    };
    log_info(b"mangadex get_pages");
    run_get_pages(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_listings(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_listings", "invalid_request", "empty"),
    };
    log_info(b"mangadex get_listings");
    run_get_listings(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_filters(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_filters", "invalid_request", "empty"),
    };
    log_info(b"mangadex get_filters");
    run_get_filters(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_manga_list(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_manga_list", "invalid_request", "empty"),
    };
    log_info(b"mangadex get_manga_list");
    run_get_manga_list(req)
}

#[no_mangle]
pub extern "C" fn koma_source_modify_image_request(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("image_request", "invalid_request", "empty"),
    };
    log_info(b"mangadex modify_image_request");
    run_image_request(req)
}

#[no_mangle]
pub extern "C" fn koma_source_free(result_ptr: u32) {
    response_buffer().free(result_ptr)
}

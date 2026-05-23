#![no_std]

extern crate koma_source_sdk;

use koma_source_sdk::host::{
    self, HtmlDescriptor, html_attr, html_close, html_parse, html_select, html_text, http_request,
    log_info,
};
use koma_source_sdk::request::contains_bytes;
use koma_source_sdk::result::ResultBuffer;
use koma_source_sdk::source::{SourceCapabilities, SourceInfo};

// Additional host import not yet in SDK
#[link(wasm_import_module = "koma_host")]
extern "C" {
    #[link_name = "html_select_all"]
    fn koma_host_html_select_all(
        descriptor: i32,
        selector_ptr: *const u8,
        selector_len: u32,
        out_ptr: *mut u8,
        out_cap: u32,
    ) -> i32;
}

/// Select all matching elements. Returns count; descriptors written to `out` (max out.len()/4).
fn html_select_all(descriptor: i32, selector: &[u8], out: &mut [u8]) -> i32 {
    unsafe {
        koma_host_html_select_all(
            descriptor,
            selector.as_ptr(),
            selector.len() as u32,
            out.as_mut_ptr(),
            out.len() as u32,
        )
    }
}

/// Buffer to hold descriptors returned by html_select_all (up to 50 results)
static mut SELECT_ALL_BUF: [u8; 2000] = [0; 2000]; // 500 * 4 bytes


const SITE_BASE: &[u8] = b"https://www.baozimh.com";
const READER_BASE: &[u8] = b"https://www.twmanga.com";
const PAYLOAD_CAP: usize = 128 * 1024;
const HTTP_OUT_CAP: usize = 512 * 1024;
const HTML_BUF_CAP: usize = 512 * 1024;
const HTTP_REQ_CAP: usize = 1024;
const SCRATCH_CAP: usize = 1024;

static mut RESPONSE: ResultBuffer<{ PAYLOAD_CAP + 256 }> = ResultBuffer::new();
static mut PAYLOAD_BUF: [u8; PAYLOAD_CAP] = [0; PAYLOAD_CAP];
static mut HTTP_OUT: [u8; HTTP_OUT_CAP] = [0; HTTP_OUT_CAP];
static mut HTML_BUF: [u8; HTML_BUF_CAP] = [0; HTML_BUF_CAP];
static mut HTTP_REQ_BUF: [u8; HTTP_REQ_CAP] = [0; HTTP_REQ_CAP];
static mut SCRATCH_A: [u8; SCRATCH_CAP] = [0; SCRATCH_CAP];
static mut SCRATCH_B: [u8; SCRATCH_CAP] = [0; SCRATCH_CAP];

const SOURCE_INFO: SourceInfo = SourceInfo {
    id: "online.baozimh.koma",
    name: "包子漫畫 (Baozimh)",
    version: "0.1.0",
    api_version: "0.2",
    language: "zh-Hant",
    author: "Koma",
    description: "Baozimh (baozimh.com) HTML scraping source.",
    content_rating: "unknown",
};

const SOURCE_CAPS: SourceCapabilities = SourceCapabilities {
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

fn html_buf() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(HTML_BUF) }
}

fn http_req_buf() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(HTTP_REQ_BUF) }
}

fn scratch_a() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(SCRATCH_A) }
}

fn scratch_b() -> &'static mut [u8] {
    unsafe { &mut *core::ptr::addr_of_mut!(SCRATCH_B) }
}

fn read_request<'a>(req_ptr: u32, req_len: u32) -> Option<&'a [u8]> {
    if req_ptr == 0 || req_len == 0 {
        return None;
    }
    Some(unsafe { core::slice::from_raw_parts(req_ptr as *const u8, req_len as usize) })
}

fn write_usize(dst: &mut [u8], cursor: &mut usize, val: usize) -> bool {
    let mut buf = [0u8; 10];
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
        // Reverse
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

fn write_bytes(dst: &mut [u8], cursor: &mut usize, src: &[u8]) -> bool {
    let end = *cursor + src.len();
    if end > dst.len() {
        return false;
    }
    dst[*cursor..end].copy_from_slice(src);
    *cursor = end;
    true
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
            Some(seq) => {
                if !write_bytes(dst, cursor, seq) {
                    return false;
                }
            }
            None => {
                if *cursor >= dst.len() {
                    return false;
                }
                dst[*cursor] = b;
                *cursor += 1;
            }
        }
    }
    true
}

fn find_subslice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
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

fn extract_json_string<'a>(req: &'a [u8], key: &[u8]) -> Option<&'a [u8]> {
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
    let start = find_subslice(req, &pattern[..needed])? + needed;
    let mut i = start;
    while i < req.len() {
        let b = req[i];
        if b == b'\\' {
            i += 2;
            continue;
        }
        if b == b'"' {
            return Some(&req[start..i]);
        }
        i += 1;
    }
    None
}

fn write_url_encoded(dst: &mut [u8], cursor: &mut usize, src: &[u8]) -> bool {
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
            const HEX: &[u8; 16] = b"0123456789ABCDEF";
            dst[*cursor] = b'%';
            dst[*cursor + 1] = HEX[(b >> 4) as usize];
            dst[*cursor + 2] = HEX[(b & 0x0f) as usize];
            *cursor += 3;
        }
    }
    true
}

fn build_get_request(dst: &mut [u8], url: &[u8]) -> Option<usize> {
    let mut cursor = 0usize;
    let prefix = br#"{"version":1,"method":"GET","url":""#;
    let suffix = br#"","headers":{},"timeoutMs":15000,"responseKind":"bodyText"}"#;
    write_bytes(dst, &mut cursor, prefix).then_some(())?;
    append_json_escaped(dst, &mut cursor, url).then_some(())?;
    write_bytes(dst, &mut cursor, suffix).then_some(())?;
    Some(cursor)
}

fn fetch_html(url_bytes: &[u8]) -> Option<usize> {
    let req_len = build_get_request(http_req_buf(), url_bytes)?;
    let req_slice = &http_req_buf()[..req_len];
    let resp_len = http_request(req_slice, http_out()).ok()?;
    let resp = &http_out()[..resp_len];
    if !contains_bytes(resp, br#""ok":true"#) {
        log_info(b"baozimh: http response not ok");
        return None;
    }
    let body_marker = b"\"bodyText\":\"";
    let body_start_idx = find_subslice(resp, body_marker)? + body_marker.len();
    let html_dst = html_buf();
    let mut out_cursor = 0usize;
    let mut i = body_start_idx;
    while i < resp.len() {
        let b = resp[i];
        if b == b'\\' && i + 1 < resp.len() {
            let next = resp[i + 1];
            let unescaped: u8 = match next {
                b'"' => b'"',
                b'\\' => b'\\',
                b'/' => b'/',
                b'n' => b'\n',
                b'r' => b'\r',
                b't' => b'\t',
                b'b' => 0x08,
                b'f' => 0x0c,
                b'u' => {
                    if i + 5 >= resp.len() {
                        return None;
                    }
                    let mut code: u32 = 0;
                    let mut k = 0;
                    while k < 4 {
                        let h = resp[i + 2 + k];
                        let v = match h {
                            b'0'..=b'9' => (h - b'0') as u32,
                            b'a'..=b'f' => 10 + (h - b'a') as u32,
                            b'A'..=b'F' => 10 + (h - b'A') as u32,
                            _ => return None,
                        };
                        code = (code << 4) | v;
                        k += 1;
                    }
                    if code < 0x80 {
                        if out_cursor >= html_dst.len() {
                            return None;
                        }
                        html_dst[out_cursor] = code as u8;
                        out_cursor += 1;
                    } else if code < 0x800 {
                        if out_cursor + 2 > html_dst.len() {
                            return None;
                        }
                        html_dst[out_cursor] = 0xC0 | (code >> 6) as u8;
                        html_dst[out_cursor + 1] = 0x80 | (code & 0x3F) as u8;
                        out_cursor += 2;
                    } else {
                        if out_cursor + 3 > html_dst.len() {
                            return None;
                        }
                        html_dst[out_cursor] = 0xE0 | (code >> 12) as u8;
                        html_dst[out_cursor + 1] = 0x80 | ((code >> 6) & 0x3F) as u8;
                        html_dst[out_cursor + 2] = 0x80 | (code & 0x3F) as u8;
                        out_cursor += 3;
                    }
                    i += 6;
                    continue;
                }
                _ => next,
            };
            if out_cursor >= html_dst.len() {
                return None;
            }
            html_dst[out_cursor] = unescaped;
            out_cursor += 1;
            i += 2;
            continue;
        }
        if b == b'"' {
            return Some(out_cursor);
        }
        if out_cursor >= html_dst.len() {
            return None;
        }
        html_dst[out_cursor] = b;
        out_cursor += 1;
        i += 1;
    }
    None
}

struct OwnedDescriptor(HtmlDescriptor);

impl Drop for OwnedDescriptor {
    fn drop(&mut self) {
        let _ = html_close(self.0);
    }
}

fn attr_into<'a>(
    desc: HtmlDescriptor,
    name: &[u8],
    out: &'a mut [u8],
) -> Option<&'a [u8]> {
    let len = html_attr(desc, name, out).ok()?;
    Some(&out[..len])
}

fn text_into<'a>(desc: HtmlDescriptor, out: &'a mut [u8]) -> Option<&'a [u8]> {
    let len = html_text(desc, out).ok()?;
    Some(&out[..len])
}

fn slug_from_comic_path(path: &[u8], out: &mut [u8]) -> Option<usize> {
    let needle = b"/comic/";
    let idx = find_subslice(path, needle)? + needle.len();
    let mut len = 0usize;
    let mut i = idx;
    while i < path.len() {
        let b = path[i];
        if b == b'?' || b == b'#' || b == b'/' || b == b' ' {
            break;
        }
        if len >= out.len() {
            return None;
        }
        out[len] = b;
        len += 1;
        i += 1;
    }
    if len == 0 { None } else { Some(len) }
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

fn run_search(req: &[u8]) -> u32 {
    let query = match extract_json_string(req, b"query") {
        Some(q) => q,
        None => return write_error("search", "invalid_request", "missing query"),
    };
    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    if !write_bytes(url_buf, &mut url_cursor, SITE_BASE) {
        return write_error("search", "internal_error", "url buffer overflow");
    }
    if !write_bytes(url_buf, &mut url_cursor, b"/search?q=") {
        return write_error("search", "internal_error", "url buffer overflow");
    }
    if !write_url_encoded(url_buf, &mut url_cursor, query) {
        return write_error("search", "internal_error", "url buffer overflow");
    }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let html_len = match fetch_html(url_bytes) {
        Some(len) => len,
        None => return write_error("search", "source_error", "http or body decode failed"),
    };
    let html_bytes = unsafe { core::slice::from_raw_parts(HTML_BUF.as_ptr(), html_len) };

    let document = match html_parse(html_bytes) {
        Ok(d) => OwnedDescriptor(d),
        Err(_) => return write_error("search", "parse_error", "html_parse failed"),
    };

    // Use html_select_all to get all comics-card poster links
    let select_buf = unsafe { &mut *core::ptr::addr_of_mut!(SELECT_ALL_BUF) };
    let count = html_select_all(document.0.raw(), b"a.comics-card__poster", select_buf);


    let payload = payload_buf();
    let mut c = 0usize;

    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("search", "internal_error", "payload overflow");
    }

    let mut written = 0usize;
    let max_items = if count > 0 { count as usize } else { 0 };
    let max_items = if max_items > 500 { 500 } else { max_items };

    for i in 0..max_items {
        let offset = i * 4;
        if offset + 4 > select_buf.len() { break; }
        let desc = i32::from_le_bytes([
            select_buf[offset],
            select_buf[offset + 1],
            select_buf[offset + 2],
            select_buf[offset + 3],
        ]);
        if desc < 0 { continue; }

        let scratch_href = scratch_a();
        let scratch_title = scratch_b();
        let hd: HtmlDescriptor = unsafe { core::mem::transmute(desc) };
        let href_bytes = attr_into(hd, b"href", scratch_href);
        let title_bytes = attr_into(hd, b"title", scratch_title);

        if let (Some(href), Some(title)) = (href_bytes, title_bytes) {
            let mut slug_buf = [0u8; 128];
            if let Some(slug_len) = slug_from_comic_path(href, &mut slug_buf) {
                let slug = &slug_buf[..slug_len];
                if written > 0 {
                    if !write_bytes(payload, &mut c, b",") {
                        return write_error("search", "internal_error", "payload overflow");
                    }
                }
                let ok = write_bytes(payload, &mut c, br#"{"id":"manga:"#)
                    && append_json_escaped(payload, &mut c, slug)
                    && write_bytes(payload, &mut c, br#"","title":""#)
                    && append_json_escaped(payload, &mut c, title)
                    && write_bytes(payload, &mut c, br#"","cover":{"kind":"url","url":"https://static-tw.baozimh.com/cover/"#)
                    && append_json_escaped(payload, &mut c, slug)
                    && write_bytes(payload, &mut c, br#".jpg"},"authors":[],"status":"unknown","contentRating":"unknown","sourceTags":["baozimh"]}"#);
                if !ok {
                    return write_error("search", "internal_error", "payload overflow");
                }
                written += 1;
            }
        }
        // Close the descriptor
        // Safety: HtmlDescriptor is repr(transparent) over i32
        let _ = html_close(unsafe { core::mem::transmute::<i32, HtmlDescriptor>(desc) });
    }

    if !write_bytes(payload, &mut c, br#"],"page":{"nextCursor":null,"hasMore":false}}"#) {
        return write_error("search", "internal_error", "payload overflow");
    }

    write_success_payload("search", c)
}

fn run_get_manga(req: &[u8]) -> u32 {
    let manga_id = match extract_json_string(req, b"mangaId") {
        Some(v) => v,
        None => return write_error("get_manga", "invalid_request", "missing mangaId"),
    };
    let prefix = b"manga:";
    if manga_id.len() <= prefix.len() || &manga_id[..prefix.len()] != prefix {
        return write_error("get_manga", "invalid_request", "unexpected mangaId");
    }
    let slug = &manga_id[prefix.len()..];

    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    if !(write_bytes(url_buf, &mut url_cursor, SITE_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/comic/")
        && write_bytes(url_buf, &mut url_cursor, slug))
    {
        return write_error("get_manga", "internal_error", "url overflow");
    }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let html_len = match fetch_html(url_bytes) {
        Some(n) => n,
        None => return write_error("get_manga", "source_error", "fetch failed"),
    };
    let html_bytes = unsafe { core::slice::from_raw_parts(HTML_BUF.as_ptr(), html_len) };

    let document = match html_parse(html_bytes) {
        Ok(d) => OwnedDescriptor(d),
        Err(_) => return write_error("get_manga", "parse_error", "html_parse failed"),
    };

    let title_desc = html_select(document.0, b"h1.comics-detail__title");
    let author_desc = html_select(document.0, b"h2.comics-detail__author");
    let desc_desc = html_select(document.0, b"p.comics-detail__desc");

    let mut title_buf = [0u8; 256];
    let mut author_buf = [0u8; 256];
    let mut desc_buf = [0u8; 1024];

    let title_text = if let Ok(d) = title_desc {
        let owned = OwnedDescriptor(d);
        text_into(owned.0, &mut title_buf).map(|s| trim_ascii(s))
    } else {
        None
    };
    let author_text = if let Ok(d) = author_desc {
        let owned = OwnedDescriptor(d);
        text_into(owned.0, &mut author_buf).map(|s| trim_ascii(s))
    } else {
        None
    };
    let desc_text = if let Ok(d) = desc_desc {
        let owned = OwnedDescriptor(d);
        text_into(owned.0, &mut desc_buf).map(|s| trim_ascii(s))
    } else {
        None
    };

    let payload = payload_buf();
    let mut c = 0usize;
    let ok = write_bytes(payload, &mut c, br#"{"manga":{"id":"manga:"#)
        && append_json_escaped(payload, &mut c, slug)
        && write_bytes(payload, &mut c, br#"","title":""#)
        && append_json_escaped(payload, &mut c, title_text.unwrap_or(slug))
        && write_bytes(payload, &mut c, br#"","alternateTitles":[],"description":""#)
        && append_json_escaped(payload, &mut c, desc_text.unwrap_or(&[]))
        && write_bytes(payload, &mut c, br#"","cover":{"kind":"url","url":"https://static-tw.baozimh.com/cover/"#)
        && append_json_escaped(payload, &mut c, slug)
        && write_bytes(payload, &mut c, br#".jpg"},"authors":["#);

    if !ok {
        return write_error("get_manga", "internal_error", "payload overflow");
    }
    if let Some(author) = author_text {
        if !author.is_empty() {
            let ok2 = write_bytes(payload, &mut c, b"\"")
                && append_json_escaped(payload, &mut c, author)
                && write_bytes(payload, &mut c, b"\"");
            if !ok2 {
                return write_error("get_manga", "internal_error", "payload overflow");
            }
        }
    }
    // Extract tags (span.tag): [0]=status, [1]=region, [2+]=genre tags
    let select_buf = unsafe { &mut *core::ptr::addr_of_mut!(SELECT_ALL_BUF) };
    let tag_count = html_select_all(document.0.raw(), b"span.tag", select_buf);
    let tag_max = if tag_count > 0 { (tag_count as usize).min(20) } else { 0 };

    // Read all tag texts into a stack buffer
    let mut tag_texts: [[u8; 64]; 20] = [[0u8; 64]; 20];
    let mut tag_lens: [usize; 20] = [0; 20];
    for ti in 0..tag_max {
        let off = ti * 4;
        if off + 4 > select_buf.len() { break; }
        let td = i32::from_le_bytes([select_buf[off], select_buf[off+1], select_buf[off+2], select_buf[off+3]]);
        if td < 0 { continue; }
        let hd: HtmlDescriptor = unsafe { core::mem::transmute(td) };
        let len = html_text(hd, &mut tag_texts[ti]).unwrap_or(0);
        // Trim leading/trailing whitespace
        let mut start = 0;
        let mut end = len;
        while start < end && (tag_texts[ti][start] == b' ' || tag_texts[ti][start] == b'\n' || tag_texts[ti][start] == b'\r' || tag_texts[ti][start] == b'\t') { start += 1; }
        while end > start && (tag_texts[ti][end-1] == b' ' || tag_texts[ti][end-1] == b'\n' || tag_texts[ti][end-1] == b'\r' || tag_texts[ti][end-1] == b'\t') { end -= 1; }
        if start > 0 && end > start {
            // Shift trimmed content to beginning
            let trimmed_len = end - start;
            let mut k = 0;
            while k < trimmed_len { tag_texts[ti][k] = tag_texts[ti][start + k]; k += 1; }
            tag_lens[ti] = trimmed_len;
        } else {
            tag_lens[ti] = end - start;
        }
        let _ = html_close(hd);
    }

    // Determine status from first tag
    let status_bytes = if tag_lens[0] > 0 { &tag_texts[0][..tag_lens[0]] } else { b"unknown" as &[u8] };
    let status_str: &[u8] = if status_bytes == "連載中".as_bytes() || status_bytes == "连载中".as_bytes() {
        b"ongoing"
    } else if status_bytes == "已完結".as_bytes() || status_bytes == "已完结".as_bytes() {
        b"completed"
    } else {
        b"unknown"
    };

    // Write: ],"artists":[],"status":"...","contentRating":"unknown","language":"zh-Hant","tags":[
    let ok3 = write_bytes(payload, &mut c, br#"],"artists":[],"status":""#)
        && write_bytes(payload, &mut c, status_str)
        && write_bytes(payload, &mut c, br#"","contentRating":"unknown","language":"zh-Hant","tags":["#);
    if !ok3 {
        return write_error("get_manga", "internal_error", "payload overflow");
    }

    // Write genre tags (skip [0]=status, [1]=region, start from [2])
    let mut tag_written = 0usize;
    for ti in 2..tag_max {
        if tag_lens[ti] == 0 { continue; }
        if tag_written > 0 {
            if !write_bytes(payload, &mut c, b",") { break; }
        }
        let ok4 = write_bytes(payload, &mut c, br#"""#)
            && append_json_escaped(payload, &mut c, &tag_texts[ti][..tag_lens[ti]])
            && write_bytes(payload, &mut c, br#"""#);
        if !ok4 { break; }
        tag_written += 1;
    }

    if !write_bytes(payload, &mut c, br#"],"links":[]}}"#) {
        return write_error("get_manga", "internal_error", "payload overflow");
    }

    write_success_payload("get_manga", c)
}

fn run_get_chapters(req: &[u8]) -> u32 {
    let manga_id = match extract_json_string(req, b"mangaId") {
        Some(v) => v,
        None => return write_error("get_chapters", "invalid_request", "missing mangaId"),
    };
    let prefix = b"manga:";
    if manga_id.len() <= prefix.len() || &manga_id[..prefix.len()] != prefix {
        return write_error("get_chapters", "invalid_request", "unexpected mangaId");
    }
    let slug = &manga_id[prefix.len()..];

    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    if !(write_bytes(url_buf, &mut url_cursor, SITE_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/comic/")
        && write_bytes(url_buf, &mut url_cursor, slug))
    {
        return write_error("get_chapters", "internal_error", "url overflow");
    }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let html_len = match fetch_html(url_bytes) {
        Some(n) => n,
        None => return write_error("get_chapters", "source_error", "fetch failed"),
    };
    let html_bytes = unsafe { core::slice::from_raw_parts(HTML_BUF.as_ptr(), html_len) };

    let document = match html_parse(html_bytes) {
        Ok(d) => OwnedDescriptor(d),
        Err(_) => return write_error("get_chapters", "parse_error", "html_parse failed"),
    };

    let select_buf = unsafe { &mut *core::ptr::addr_of_mut!(SELECT_ALL_BUF) };
    let count = html_select_all(document.0.raw(), b"a.comics-chapters__item", select_buf);

    let payload = payload_buf();
    let mut c = 0usize;
    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("get_chapters", "internal_error", "payload overflow");
    }

    let max_items = if count > 0 { count as usize } else { 0 };
    let max_items = if max_items > 500 { 500 } else { max_items };
    let mut written = 0usize;

    for i in 0..max_items {
        let offset = i * 4;
        if offset + 4 > select_buf.len() { break; }
        let desc = i32::from_le_bytes([
            select_buf[offset], select_buf[offset+1], select_buf[offset+2], select_buf[offset+3],
        ]);
        if desc < 0 { continue; }

        let hd: HtmlDescriptor = unsafe { core::mem::transmute(desc) };
        let mut title_buf = [0u8; 256];
        let title = text_into(hd, &mut title_buf).map(trim_ascii);
        let mut href_buf = [0u8; 256];
        let href = attr_into(hd, b"href", &mut href_buf);

        let mut chapter_slot_buf = [0u8; 16];
        let chapter_slot = if let Some(h) = href {
            extract_query_param(h, b"chapter_slot", &mut chapter_slot_buf)
        } else {
            None
        };
        let slot = chapter_slot.unwrap_or(b"0");

        if written > 0 {
            if !write_bytes(payload, &mut c, b",") { break; }
        }
        let ok = write_bytes(payload, &mut c, br#"{"id":"chapter:"#)
            && append_json_escaped(payload, &mut c, slug)
            && write_bytes(payload, &mut c, b":")
            && append_json_escaped(payload, &mut c, slot)
            && write_bytes(payload, &mut c, br#"","mangaId":"manga:"#)
            && append_json_escaped(payload, &mut c, slug)
            && write_bytes(payload, &mut c, br#"","title":""#)
            && append_json_escaped(payload, &mut c, title.unwrap_or(b"Chapter"))
            && write_bytes(payload, &mut c, br#"","chapterNumber":""#)
            && append_json_escaped(payload, &mut c, slot)
            && write_bytes(payload, &mut c, br#"","volumeNumber":null,"language":"zh-Hant","publishedAt":null,"updatedAt":null,"pageCount":null}"#);
        if !ok { break; }
        written += 1;
        let _ = html_close(hd);
    }

    if !write_bytes(payload, &mut c, br#"],"page":{"nextCursor":null,"hasMore":false}}"#) {
        return write_error("get_chapters", "internal_error", "payload overflow");
    }
    write_success_payload("get_chapters", c)
}

fn run_get_pages(req: &[u8]) -> u32 {
    let chapter_id = match extract_json_string(req, b"chapterId") {
        Some(v) => v,
        None => return write_error("get_pages", "invalid_request", "missing chapterId"),
    };
    let prefix = b"chapter:";
    if chapter_id.len() <= prefix.len() || &chapter_id[..prefix.len()] != prefix {
        return write_error("get_pages", "invalid_request", "unexpected chapterId");
    }
    let rest = &chapter_id[prefix.len()..];
    let colon_idx = match find_subslice(rest, b":") {
        Some(i) => i,
        None => return write_error("get_pages", "invalid_request", "chapterId missing slot"),
    };
    let slug = &rest[..colon_idx];
    let slot = &rest[colon_idx + 1..];

    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    if !(write_bytes(url_buf, &mut url_cursor, READER_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/comic/chapter/")
        && write_bytes(url_buf, &mut url_cursor, slug)
        && write_bytes(url_buf, &mut url_cursor, b"/0_")
        && write_bytes(url_buf, &mut url_cursor, slot)
        && write_bytes(url_buf, &mut url_cursor, b".html"))
    {
        return write_error("get_pages", "internal_error", "url overflow");
    }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let html_len = match fetch_html(url_bytes) {
        Some(n) => n,
        None => return write_error("get_pages", "source_error", "fetch failed"),
    };
    let html_bytes = unsafe { core::slice::from_raw_parts(HTML_BUF.as_ptr(), html_len) };

    let document = match html_parse(html_bytes) {
        Ok(d) => OwnedDescriptor(d),
        Err(_) => return write_error("get_pages", "parse_error", "html_parse failed"),
    };
    let select_buf = unsafe { &mut *core::ptr::addr_of_mut!(SELECT_ALL_BUF) };
    let count = html_select_all(document.0.raw(), b"amp-img.comic-contain__item", select_buf);

    let payload = payload_buf();
    let mut c = 0usize;
    let ok = write_bytes(payload, &mut c, br#"{"chapterId":"chapter:"#)
        && append_json_escaped(payload, &mut c, slug)
        && write_bytes(payload, &mut c, b":")
        && append_json_escaped(payload, &mut c, slot)
        && write_bytes(payload, &mut c, br#"","pages":["#);
    if !ok {
        return write_error("get_pages", "internal_error", "payload overflow");
    }

    let max_items = if count > 0 { count as usize } else { 0 };
    let max_items = if max_items > 500 { 500 } else { max_items };
    let mut written = 0usize;

    for i in 0..max_items {
        let offset = i * 4;
        if offset + 4 > select_buf.len() { break; }
        let desc = i32::from_le_bytes([
            select_buf[offset], select_buf[offset+1], select_buf[offset+2], select_buf[offset+3],
        ]);
        if desc < 0 { continue; }

        let hd: HtmlDescriptor = unsafe { core::mem::transmute(desc) };
        let mut src_buf = [0u8; 512];
        if let Some(img_src) = attr_into(hd, b"src", &mut src_buf) {
            if written > 0 {
                if !write_bytes(payload, &mut c, b",") { break; }
            }
            // Build index as 4-digit string
            let mut idx_buf = [0u8; 4];
            let idx_val = written as u32;
            idx_buf[0] = b'0' + ((idx_val / 1000) % 10) as u8;
            idx_buf[1] = b'0' + ((idx_val / 100) % 10) as u8;
            idx_buf[2] = b'0' + ((idx_val / 10) % 10) as u8;
            idx_buf[3] = b'0' + (idx_val % 10) as u8;

            let ok2 = write_bytes(payload, &mut c, br#"{"id":"page:"#)
                && append_json_escaped(payload, &mut c, slug)
                && write_bytes(payload, &mut c, b":")
                && append_json_escaped(payload, &mut c, slot)
                && write_bytes(payload, &mut c, b":")
                && write_bytes(payload, &mut c, &idx_buf)
                && write_bytes(payload, &mut c, br#"","index":"#)
                && write_usize(payload, &mut c, written)
                && write_bytes(payload, &mut c, br#","image":{"kind":"url","url":""#)
                && append_json_escaped(payload, &mut c, img_src)
                && write_bytes(payload, &mut c, br#""}}"#);
            if !ok2 { break; }
            written += 1;
        }
        let _ = html_close(hd);
    }

    if !write_bytes(payload, &mut c, b"]}") {
        return write_error("get_pages", "internal_error", "payload overflow");
    }
    write_success_payload("get_pages", c)
}

fn run_get_listings(req: &[u8]) -> u32 {
    // URL: /classify (popular, default page 1)
    let url = b"https://www.baozimh.com/classify";

    let html_len = match fetch_html(url) {
        Some(len) => len,
        None => return write_error("get_listings", "source_error", "fetch failed"),
    };
    let html_bytes = unsafe { core::slice::from_raw_parts(HTML_BUF.as_ptr(), html_len) };

    let document = match html_parse(html_bytes) {
        Ok(d) => OwnedDescriptor(d),
        Err(_) => return write_error("get_listings", "parse_error", "html_parse failed"),
    };

    let select_buf = unsafe { &mut *core::ptr::addr_of_mut!(SELECT_ALL_BUF) };
    let count = html_select_all(document.0.raw(), b"a.comics-card__poster", select_buf);

    let payload = payload_buf();
    let mut c = 0usize;

    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("get_listings", "internal_error", "payload overflow");
    }

    let max_items = if count > 0 { (count as usize).min(500) } else { 0 };
    let mut written = 0usize;

    for i in 0..max_items {
        let offset = i * 4;
        if offset + 4 > select_buf.len() { break; }
        let desc = i32::from_le_bytes([
            select_buf[offset], select_buf[offset+1], select_buf[offset+2], select_buf[offset+3],
        ]);
        if desc < 0 { continue; }

        let hd: HtmlDescriptor = unsafe { core::mem::transmute(desc) };
        let scratch_href = scratch_a();
        let scratch_title = scratch_b();
        let href_bytes = attr_into(hd, b"href", scratch_href);
        let title_bytes = attr_into(hd, b"title", scratch_title);

        if let (Some(href), Some(title)) = (href_bytes, title_bytes) {
            let mut slug_buf = [0u8; 128];
            if let Some(slug_len) = slug_from_comic_path(href, &mut slug_buf) {
                let slug = &slug_buf[..slug_len];
                if written > 0 {
                    if !write_bytes(payload, &mut c, b",") { break; }
                }
                let ok = write_bytes(payload, &mut c, br#"{"id":"manga:"#)
                    && append_json_escaped(payload, &mut c, slug)
                    && write_bytes(payload, &mut c, br#"","title":""#)
                    && append_json_escaped(payload, &mut c, title)
                    && write_bytes(payload, &mut c, br#"","cover":{"kind":"url","url":"https://static-tw.baozimh.com/cover/"#)
                    && append_json_escaped(payload, &mut c, slug)
                    && write_bytes(payload, &mut c, br#".jpg"},"authors":[],"status":"unknown","contentRating":"unknown","sourceTags":["baozimh"]}"#);
                if !ok { break; }
                written += 1;
            }
        }
        let _ = html_close(hd);
    }

    if !write_bytes(payload, &mut c, br#"],"page":{"nextCursor":null,"hasMore":false}}"#) {
        return write_error("get_listings", "internal_error", "payload overflow");
    }

    write_success_payload("get_listings", c)
}

/// Extract a JSON number value for a given key, returns the bytes of the number
fn extract_json_number<'a>(req: &'a [u8], key: &[u8]) -> Option<&'a [u8]> {
    // Build pattern "key":
    let mut pattern = [0u8; 64];
    let needed = key.len() + 3; // "key":
    if needed > pattern.len() {
        return None;
    }
    pattern[0] = b'"';
    pattern[1..1 + key.len()].copy_from_slice(key);
    pattern[1 + key.len()] = b'"';
    pattern[2 + key.len()] = b':';
    let start = find_subslice(req, &pattern[..needed])? + needed;
    // Skip whitespace
    let mut i = start;
    while i < req.len() && (req[i] == b' ' || req[i] == b'\t' || req[i] == b'\n' || req[i] == b'\r') {
        i += 1;
    }
    if i >= req.len() { return None; }
    // Collect digits
    let num_start = i;
    while i < req.len() && (req[i] >= b'0' && req[i] <= b'9') {
        i += 1;
    }
    if i == num_start { return None; }
    Some(&req[num_start..i])
}

fn run_get_filters(_req: &[u8]) -> u32 {
    // Return filter definitions for baozimh classify page
    // Filters: region, state, type (genre)
    // Using &str (not byte string) because labels contain non-ASCII (Chinese)
    const FILTERS_JSON: &str = "{\"filters\":[{\"id\":\"region\",\"name\":\"地區\",\"kind\":\"select\",\"options\":[{\"value\":\"all\",\"label\":\"全部\"},{\"value\":\"cn\",\"label\":\"國漫\"},{\"value\":\"jp\",\"label\":\"日本\"},{\"value\":\"kr\",\"label\":\"韓國\"},{\"value\":\"en\",\"label\":\"歐美\"}],\"default\":\"all\"},{\"id\":\"state\",\"name\":\"狀態\",\"kind\":\"select\",\"options\":[{\"value\":\"all\",\"label\":\"全部\"},{\"value\":\"serial\",\"label\":\"連載中\"},{\"value\":\"pub\",\"label\":\"已完結\"}],\"default\":\"all\"},{\"id\":\"type\",\"name\":\"類型\",\"kind\":\"select\",\"options\":[{\"value\":\"all\",\"label\":\"全部\"},{\"value\":\"lianai\",\"label\":\"戀愛\"},{\"value\":\"chunai\",\"label\":\"純愛\"},{\"value\":\"gufeng\",\"label\":\"古風\"},{\"value\":\"yineng\",\"label\":\"異能\"},{\"value\":\"xuanyi\",\"label\":\"懸疑\"},{\"value\":\"juqing\",\"label\":\"劇情\"},{\"value\":\"kehuan\",\"label\":\"科幻\"},{\"value\":\"qihuan\",\"label\":\"奇幻\"},{\"value\":\"xuanhuan\",\"label\":\"玄幻\"},{\"value\":\"chuanyue\",\"label\":\"穿越\"},{\"value\":\"mouxian\",\"label\":\"冒險\"},{\"value\":\"tuili\",\"label\":\"推理\"},{\"value\":\"wuxia\",\"label\":\"武俠\"},{\"value\":\"gedou\",\"label\":\"格鬥\"},{\"value\":\"zhanzheng\",\"label\":\"戰爭\"},{\"value\":\"rexie\",\"label\":\"熱血\"},{\"value\":\"gaoxiao\",\"label\":\"搞笑\"},{\"value\":\"danuzhu\",\"label\":\"大女主\"},{\"value\":\"dushi\",\"label\":\"都市\"},{\"value\":\"zongcai\",\"label\":\"總裁\"},{\"value\":\"hougong\",\"label\":\"後宮\"},{\"value\":\"richang\",\"label\":\"日常\"},{\"value\":\"hanman\",\"label\":\"韓漫\"},{\"value\":\"shaonian\",\"label\":\"少年\"},{\"value\":\"qita\",\"label\":\"其它\"}],\"default\":\"all\"}]}";
    let filters_bytes = FILTERS_JSON.as_bytes();

    let payload = payload_buf();
    let flen = filters_bytes.len();
    if flen > payload.len() {
        return write_error("get_filters", "internal_error", "payload overflow");
    }
    payload[..flen].copy_from_slice(filters_bytes);
    write_success_payload("get_filters", flen)
}

fn run_get_manga_list(req: &[u8]) -> u32 {
    // Extract filter values from request JSON
    let region = extract_json_string(req, b"region").unwrap_or(b"all");
    let state = extract_json_string(req, b"state").unwrap_or(b"all");
    let manga_type = extract_json_string(req, b"type").unwrap_or(b"all");
    let page_bytes = extract_json_number(req, b"page");
    let page_num = if let Some(pb) = page_bytes {
        let mut n = 0usize;
        for &b in pb {
            n = n * 10 + (b - b'0') as usize;
        }
        if n == 0 { 1 } else { n }
    } else {
        1
    };

    // Build URL: /classify?type=X&region=Y&state=Z&filter=*&page=N
    let url_buf = scratch_a();
    let mut url_cursor = 0usize;
    let ok = write_bytes(url_buf, &mut url_cursor, SITE_BASE)
        && write_bytes(url_buf, &mut url_cursor, b"/classify?type=")
        && write_bytes(url_buf, &mut url_cursor, manga_type)
        && write_bytes(url_buf, &mut url_cursor, b"&region=")
        && write_bytes(url_buf, &mut url_cursor, region)
        && write_bytes(url_buf, &mut url_cursor, b"&state=")
        && write_bytes(url_buf, &mut url_cursor, state)
        && write_bytes(url_buf, &mut url_cursor, b"&filter=%2a&page=")
        && write_usize(url_buf, &mut url_cursor, page_num);
    if !ok {
        return write_error("get_manga_list", "internal_error", "url overflow");
    }
    let url_bytes = unsafe { core::slice::from_raw_parts(SCRATCH_A.as_ptr(), url_cursor) };

    let html_len = match fetch_html(url_bytes) {
        Some(len) => len,
        None => return write_error("get_manga_list", "source_error", "fetch failed"),
    };
    let html_bytes = unsafe { core::slice::from_raw_parts(HTML_BUF.as_ptr(), html_len) };

    let document = match html_parse(html_bytes) {
        Ok(d) => OwnedDescriptor(d),
        Err(_) => return write_error("get_manga_list", "parse_error", "html_parse failed"),
    };

    let select_buf = unsafe { &mut *core::ptr::addr_of_mut!(SELECT_ALL_BUF) };
    let count = html_select_all(document.0.raw(), b"a.comics-card__poster", select_buf);

    let payload = payload_buf();
    let mut c = 0usize;

    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("get_manga_list", "internal_error", "payload overflow");
    }

    let max_items = if count > 0 { (count as usize).min(500) } else { 0 };
    let mut written = 0usize;

    for i in 0..max_items {
        let offset = i * 4;
        if offset + 4 > select_buf.len() { break; }
        let desc = i32::from_le_bytes([
            select_buf[offset], select_buf[offset+1], select_buf[offset+2], select_buf[offset+3],
        ]);
        if desc < 0 { continue; }

        let hd: HtmlDescriptor = unsafe { core::mem::transmute(desc) };
        let scratch_href = scratch_a();
        let scratch_title = scratch_b();
        let href_bytes = attr_into(hd, b"href", scratch_href);
        let title_bytes = attr_into(hd, b"title", scratch_title);

        if let (Some(href), Some(title)) = (href_bytes, title_bytes) {
            let mut slug_buf = [0u8; 128];
            if let Some(slug_len) = slug_from_comic_path(href, &mut slug_buf) {
                let slug = &slug_buf[..slug_len];
                if written > 0 {
                    if !write_bytes(payload, &mut c, b",") { break; }
                }
                let ok = write_bytes(payload, &mut c, br#"{"id":"manga:"#)
                    && append_json_escaped(payload, &mut c, slug)
                    && write_bytes(payload, &mut c, br#"","title":""#)
                    && append_json_escaped(payload, &mut c, title)
                    && write_bytes(payload, &mut c, br#"","cover":{"kind":"url","url":"https://static-tw.baozimh.com/cover/"#)
                    && append_json_escaped(payload, &mut c, slug)
                    && write_bytes(payload, &mut c, br#".jpg"},"authors":[],"status":"unknown","contentRating":"unknown","sourceTags":["baozimh"]}"#);
                if !ok { break; }
                written += 1;
            }
        }
        let _ = html_close(hd);
    }

    // hasMore: true if we got a full page (36+)
    let has_more = if written >= 36 { b"true" as &[u8] } else { b"false" as &[u8] };
    let ok2 = write_bytes(payload, &mut c, br#"],"page":{"nextCursor":""#)
        && write_usize(payload, &mut c, page_num + 1)
        && write_bytes(payload, &mut c, br#"","hasMore":"#)
        && write_bytes(payload, &mut c, has_more)
        && write_bytes(payload, &mut c, b"}}");
    if !ok2 {
        return write_error("get_manga_list", "internal_error", "payload overflow");
    }

    write_success_payload("get_manga_list", c)
}

fn run_modify_image_request(req: &[u8]) -> u32 {
    // baozimh images are freely accessible, no modification needed.
    // Just extract the URL and return an unmodified request
    let url = match extract_json_string(req, b"url") {
        Some(u) => u,
        None => return write_error("modify_image_request", "invalid_request", "missing url"),
    };

    let payload = payload_buf();
    let mut c = 0usize;
    let ok = write_bytes(payload, &mut c, br#"{"url":""#)
        && append_json_escaped(payload, &mut c, url)
        && write_bytes(payload, &mut c, br#"","headers":{}}"#);
    if !ok {
        return write_error("modify_image_request", "internal_error", "payload overflow");
    }
    write_success_payload("modify_image_request", c)
}

// --- get_home: multi-section home page ---
// Uses /classify with different filters to build sections, avoiding the heavy homepage HTML.

fn parse_cards_into_section(payload: &mut [u8], c: &mut usize, section_title: &[u8], url: &[u8], max_items: usize) -> bool {
    let ok = write_bytes(payload, c, br#"{"title":""#)
        && append_json_escaped(payload, c, section_title)
        && write_bytes(payload, c, br#"","items":["#);
    if !ok { return false; }

    let mut item_count = 0usize;

    if let Some(html_len) = fetch_html(url) {
        let html_bytes = unsafe { core::slice::from_raw_parts(HTML_BUF.as_ptr(), html_len) };
        if let Ok(doc_desc) = html_parse(html_bytes) {
            let doc = OwnedDescriptor(doc_desc);
            let select_buf = unsafe { &mut *core::ptr::addr_of_mut!(SELECT_ALL_BUF) };
            let count = html_select_all(doc.0.raw(), b"a.comics-card__poster", select_buf);
            let real_max = if count > 0 { (count as usize).min(max_items) } else { 0 };

            for i in 0..real_max {
                let offset = i * 4;
                if offset + 4 > select_buf.len() { break; }
                let desc = i32::from_le_bytes([
                    select_buf[offset], select_buf[offset+1], select_buf[offset+2], select_buf[offset+3],
                ]);
                if desc < 0 { continue; }

                let hd: HtmlDescriptor = unsafe { core::mem::transmute(desc) };
                let scratch_href = scratch_a();
                let scratch_title = scratch_b();
                let href_bytes = attr_into(hd, b"href", scratch_href);
                let title_bytes = attr_into(hd, b"title", scratch_title);

                if let (Some(href), Some(title)) = (href_bytes, title_bytes) {
                    let mut slug_buf = [0u8; 128];
                    if let Some(slug_len) = slug_from_comic_path(href, &mut slug_buf) {
                        let slug = &slug_buf[..slug_len];
                        if item_count > 0 {
                            if !write_bytes(payload, c, b",") { break; }
                        }
                        let ok2 = write_bytes(payload, c, br#"{"id":"manga:"#)
                            && append_json_escaped(payload, c, slug)
                            && write_bytes(payload, c, br#"","title":""#)
                            && append_json_escaped(payload, c, title)
                            && write_bytes(payload, c, br#"","cover":{"kind":"url","url":"https://static-tw.baozimh.com/cover/"#)
                            && append_json_escaped(payload, c, slug)
                            && write_bytes(payload, c, br#".jpg"}}"#);
                        if !ok2 { break; }
                        item_count += 1;
                    }
                }
                let _ = html_close(hd);
            }
        }
    }

    write_bytes(payload, c, b"]}")
}

fn run_get_home(_req: &[u8]) -> u32 {
    let payload = payload_buf();
    let mut c = 0usize;
    if !write_bytes(payload, &mut c, br#"{"sections":["#) {
        return write_error("get_home", "internal_error", "overflow");
    }

    // Section 1: 熱門 (default classify page)
    if !parse_cards_into_section(payload, &mut c,
        "熱門漫畫".as_bytes(),
        b"https://www.baozimh.com/classify", 12) {
        return write_error("get_home", "internal_error", "overflow");
    }

    // Section 2: 國漫推薦
    if !write_bytes(payload, &mut c, b",") {
        return write_error("get_home", "internal_error", "overflow");
    }
    if !parse_cards_into_section(payload, &mut c,
        "國漫推薦".as_bytes(),
        b"https://www.baozimh.com/classify?type=all&region=cn", 12) {
        return write_error("get_home", "internal_error", "overflow");
    }

    // Section 3: 日本漫畫
    if !write_bytes(payload, &mut c, b",") {
        return write_error("get_home", "internal_error", "overflow");
    }
    if !parse_cards_into_section(payload, &mut c,
        "日本漫畫".as_bytes(),
        b"https://www.baozimh.com/classify?type=all&region=jp", 12) {
        return write_error("get_home", "internal_error", "overflow");
    }

    // Section 4: 韓國漫畫
    if !write_bytes(payload, &mut c, b",") {
        return write_error("get_home", "internal_error", "overflow");
    }
    if !parse_cards_into_section(payload, &mut c,
        "韓國漫畫".as_bytes(),
        b"https://www.baozimh.com/classify?type=all&region=kr", 12) {
        return write_error("get_home", "internal_error", "overflow");
    }

    if !write_bytes(payload, &mut c, b"]}") {
        return write_error("get_home", "internal_error", "overflow");
    }
    write_success_payload("get_home", c)
}

// --- get_settings: source-level user preferences ---

fn run_get_settings(_req: &[u8]) -> u32 {
    const SETTINGS_JSON: &str = "{\"settings\":[{\"id\":\"defaultRegion\",\"name\":\"預設地區\",\"kind\":\"select\",\"options\":[{\"value\":\"all\",\"label\":\"全部\"},{\"value\":\"cn\",\"label\":\"國漫\"},{\"value\":\"jp\",\"label\":\"日本\"},{\"value\":\"kr\",\"label\":\"韓國\"},{\"value\":\"en\",\"label\":\"歐美\"}],\"default\":\"all\"},{\"id\":\"defaultState\",\"name\":\"預設狀態\",\"kind\":\"select\",\"options\":[{\"value\":\"all\",\"label\":\"全部\"},{\"value\":\"serial\",\"label\":\"連載中\"},{\"value\":\"pub\",\"label\":\"已完結\"}],\"default\":\"all\"}]}";

    let settings_bytes = SETTINGS_JSON.as_bytes();
    let payload = payload_buf();
    let flen = settings_bytes.len();
    if flen > payload.len() {
        return write_error("get_settings", "internal_error", "payload overflow");
    }
    payload[..flen].copy_from_slice(settings_bytes);
    write_success_payload("get_settings", flen)
}

fn extract_query_param<'a>(url: &[u8], key: &[u8], out: &'a mut [u8]) -> Option<&'a [u8]> {
    let mut pattern_buf = [0u8; 32];
    if key.len() + 1 > pattern_buf.len() {
        return None;
    }
    pattern_buf[..key.len()].copy_from_slice(key);
    pattern_buf[key.len()] = b'=';
    let pattern = &pattern_buf[..key.len() + 1];
    let start = find_subslice(url, pattern)? + pattern.len();
    let mut len = 0usize;
    let mut i = start;
    while i < url.len() {
        let b = url[i];
        if b == b'&' || b == b'#' {
            break;
        }
        if len >= out.len() {
            return None;
        }
        out[len] = b;
        len += 1;
        i += 1;
    }
    Some(&out[..len])
}

fn trim_ascii(bytes: &[u8]) -> &[u8] {
    let mut start = 0usize;
    let mut end = bytes.len();
    while start < end {
        match bytes[start] {
            b' ' | b'\t' | b'\n' | b'\r' => start += 1,
            _ => break,
        }
    }
    while end > start {
        match bytes[end - 1] {
            b' ' | b'\t' | b'\n' | b'\r' => end -= 1,
            _ => break,
        }
    }
    &bytes[start..end]
}

#[no_mangle]
pub extern "C" fn koma_source_init(_manifest_ptr: u32, manifest_len: u32) -> i32 {
    log_info(b"baozimh source init");
    if host::check_cancel() {
        return -2;
    }
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
        None => return write_error("search", "invalid_request", "empty request"),
    };
    log_info(b"baozimh search");
    run_search(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_manga(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_manga", "invalid_request", "empty request"),
    };
    log_info(b"baozimh get_manga");
    run_get_manga(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_chapters(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_chapters", "invalid_request", "empty request"),
    };
    log_info(b"baozimh get_chapters");
    run_get_chapters(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_pages(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_pages", "invalid_request", "empty request"),
    };
    log_info(b"baozimh get_pages");
    run_get_pages(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_listings(req_ptr: u32, req_len: u32) -> u32 {
    let req = unsafe { core::slice::from_raw_parts(req_ptr as *const u8, req_len as usize) };
    if !contains_bytes(req, br#""operation":"get_listings""#) {
        return write_error("get_listings", "unexpected_operation", "expected get_listings");
    }
    run_get_listings(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_manga_list(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_manga_list", "invalid_request", "empty request"),
    };
    log_info(b"baozimh get_manga_list");
    run_get_manga_list(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_filters(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_filters", "invalid_request", "empty request"),
    };
    log_info(b"baozimh get_filters");
    run_get_filters(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_image_request(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("modify_image_request", "invalid_request", "empty request"),
    };
    log_info(b"baozimh modify_image_request");
    run_modify_image_request(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_home(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_home", "invalid_request", "empty request"),
    };
    log_info(b"baozimh get_home");
    run_get_home(req)
}

#[no_mangle]
pub extern "C" fn koma_source_get_settings(req_ptr: u32, req_len: u32) -> u32 {
    let req = match read_request(req_ptr, req_len) {
        Some(r) => r,
        None => return write_error("get_settings", "invalid_request", "empty request"),
    };
    log_info(b"baozimh get_settings");
    run_get_settings(req)
}

#[no_mangle]
pub extern "C" fn koma_source_free(result_ptr: u32) {
    response_buffer().free(result_ptr)
}

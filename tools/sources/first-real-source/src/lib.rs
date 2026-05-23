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
static mut SELECT_ALL_BUF: [u8; 200] = [0; 200]; // 50 * 4 bytes


const SITE_BASE: &[u8] = b"https://www.baozimh.com";
const PAYLOAD_CAP: usize = 32 * 1024;
const HTTP_OUT_CAP: usize = 200 * 1024;
const HTML_BUF_CAP: usize = 200 * 1024;
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

const SOURCE_CAPS: SourceCapabilities = SourceCapabilities::CORE;

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
    // Debug: log the count
    {
        let mut dbg = [0u8; 64];
        let mut dc = 0usize;
        write_bytes(&mut dbg, &mut dc, b"select_all count=");
        let cnt_str = if count < 0 { b"-1" as &[u8] } else if count == 0 { b"0" } else { b"+" };
        write_bytes(&mut dbg, &mut dc, cnt_str);
        log_info(&dbg[..dc]);
    }

    let payload = payload_buf();
    let mut c = 0usize;

    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("search", "internal_error", "payload overflow");
    }

    let mut written = 0usize;
    let max_items = if count > 0 { count as usize } else { 0 };
    let max_items = if max_items > 50 { 50 } else { max_items };

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
                    && write_bytes(payload, &mut c, br#"","cover":{"kind":"none"},"authors":[],"status":"unknown","contentRating":"unknown","sourceTags":["baozimh"]}"#);
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
        && write_bytes(payload, &mut c, br#"","cover":{"kind":"none"},"authors":["#);

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
    if !write_bytes(
        payload,
        &mut c,
        br#"],"artists":[],"status":"unknown","contentRating":"unknown","language":"zh-Hant","tags":[],"links":[]}}"#,
    ) {
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

    let chapter_anchor = html_select(document.0, b"a.comics-chapters__item");
    let payload = payload_buf();
    let mut c = 0usize;
    if !write_bytes(payload, &mut c, br#"{"items":["#) {
        return write_error("get_chapters", "internal_error", "payload overflow");
    }

    if let Ok(d) = chapter_anchor {
        let owned = OwnedDescriptor(d);
        let mut title_buf = [0u8; 256];
        let title = text_into(owned.0, &mut title_buf).map(trim_ascii);
        let mut href_buf = [0u8; 256];
        let href = attr_into(owned.0, b"href", &mut href_buf);

        let mut chapter_slot_buf = [0u8; 16];
        let chapter_slot = if let Some(h) = href {
            extract_query_param(h, b"chapter_slot", &mut chapter_slot_buf)
        } else {
            None
        };

        let slot = chapter_slot.unwrap_or(b"0");
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
        if !ok {
            return write_error("get_chapters", "internal_error", "payload overflow");
        }
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
    if !(write_bytes(url_buf, &mut url_cursor, SITE_BASE)
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
    let img = html_select(document.0, b"amp-img.comic-contain__item");
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

    if let Ok(d) = img {
        let owned = OwnedDescriptor(d);
        let mut src_buf = [0u8; 512];
        if let Some(src) = attr_into(owned.0, b"src", &mut src_buf) {
            let ok2 = write_bytes(payload, &mut c, br#"{"id":"page:"#)
                && append_json_escaped(payload, &mut c, slug)
                && write_bytes(payload, &mut c, b":")
                && append_json_escaped(payload, &mut c, slot)
                && write_bytes(payload, &mut c, br#":0001","index":0,"image":{"kind":"url","url":""#)
                && append_json_escaped(payload, &mut c, src)
                && write_bytes(payload, &mut c, br#""}}"#);
            if !ok2 {
                return write_error("get_pages", "internal_error", "payload overflow");
            }
        }
    }

    if !write_bytes(payload, &mut c, b"]}") {
        return write_error("get_pages", "internal_error", "payload overflow");
    }
    write_success_payload("get_pages", c)
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
pub extern "C" fn koma_source_free(result_ptr: u32) {
    response_buffer().free(result_ptr)
}

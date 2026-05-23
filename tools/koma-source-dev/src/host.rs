use crate::types::{HttpErrorEnvelope, HttpRequest, HttpResponse};
use anyhow::{anyhow, Context, Result};
use std::path::Path;
use wasmtime::*;

/// State stored inside the wasmtime Store
pub struct HostState {
    /// Accumulated log messages
    pub logs: Vec<String>,
    /// HTML documents held by descriptors
    html_docs: Vec<Option<scraper::Html>>,
}

impl HostState {
    fn new() -> Self {
        Self {
            logs: Vec::new(),
            html_docs: vec![None], // index 0 unused
        }
    }
}

fn read_guest_bytes(memory: &Memory, store: &impl AsContext<Data = HostState>, ptr: u32, len: u32) -> Result<Vec<u8>> {
    let data = memory.data(store);
    let start = ptr as usize;
    let end = start + len as usize;
    if end > data.len() {
        anyhow::bail!("guest memory out of bounds");
    }
    Ok(data[start..end].to_vec())
}

fn write_guest_bytes(memory: &Memory, store: &mut impl AsContextMut<Data = HostState>, ptr: u32, bytes: &[u8]) -> Result<usize> {
    let data = memory.data_mut(store);
    let start = ptr as usize;
    let end = start + bytes.len();
    if end > data.len() {
        anyhow::bail!("guest memory out of bounds for write");
    }
    data[start..end].copy_from_slice(bytes);
    Ok(bytes.len())
}

/// Execute real HTTP request
fn do_http_request(req: &HttpRequest) -> HttpResponse {
    let url_lower = req.url.to_lowercase();
    if !url_lower.starts_with("http://") && !url_lower.starts_with("https://") {
        return HttpResponse {
            ok: false, status: None, headers: None, body_text: None, body_json: None,
            final_url: None, network_performed: false,
            error: Some(HttpErrorEnvelope {
                code: "scheme_not_allowed".into(),
                message: format!("Only http/https allowed"),
                phase: "url".into(), retryable: false,
            }),
        };
    }

    let method_upper = req.method.to_uppercase();
    if matches!(method_upper.as_str(), "CONNECT" | "TRACE") {
        return HttpResponse {
            ok: false, status: None, headers: None, body_text: None, body_json: None,
            final_url: None, network_performed: false,
            error: Some(HttpErrorEnvelope {
                code: "method_not_allowed".into(),
                message: format!("Method {} not allowed", method_upper),
                phase: "method".into(), retryable: false,
            }),
        };
    }

    let mut ureq_req = ureq::request(&method_upper, &req.url);
    ureq_req = ureq_req.timeout(std::time::Duration::from_millis(req.timeout_ms));

    for (key, value) in &req.headers {
        ureq_req = ureq_req.set(key, value);
    }

    if !req.headers.keys().any(|k| k.to_lowercase() == "user-agent") {
        ureq_req = ureq_req.set("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36");
    }

    let result = if let Some(body) = &req.body_base64 {
        ureq_req.send_string(body)
    } else {
        ureq_req.call()
    };

    match result {
        Ok(resp) => build_success_response(&req, resp),
        Err(ureq::Error::Status(code, resp)) => {
            let mut resp_headers = std::collections::HashMap::new();
            for name in resp.headers_names() {
                if let Some(val) = resp.header(&name) {
                    resp_headers.insert(name, val.to_string());
                }
            }
            let body_text = resp.into_string().unwrap_or_default();
            let body_json = if req.response_kind == "bodyJson" {
                serde_json::from_str(&body_text).ok()
            } else { None };
            HttpResponse {
                ok: true, status: Some(code), headers: Some(resp_headers),
                body_text: Some(body_text), body_json,
                final_url: Some(req.url.clone()), network_performed: true, error: None,
            }
        }
        Err(e) => HttpResponse {
            ok: false, status: None, headers: None, body_text: None, body_json: None,
            final_url: None, network_performed: true,
            error: Some(HttpErrorEnvelope {
                code: "network_error".into(),
                message: format!("{}", e),
                phase: "transport".into(), retryable: true,
            }),
        },
    }
}

fn build_success_response(req: &HttpRequest, resp: ureq::Response) -> HttpResponse {
    let status = resp.status();
    let mut resp_headers = std::collections::HashMap::new();
    for name in resp.headers_names() {
        if let Some(val) = resp.header(&name) {
            resp_headers.insert(name, val.to_string());
        }
    }
    let body_text = resp.into_string().unwrap_or_default();
    let body_json = if req.response_kind == "bodyJson" {
        serde_json::from_str(&body_text).ok()
    } else { None };
    HttpResponse {
        ok: true, status: Some(status), headers: Some(resp_headers),
        body_text: Some(body_text), body_json,
        final_url: Some(req.url.clone()), network_performed: true, error: None,
    }
}

pub fn run_source_info(wasm_path: &Path) -> Result<serde_json::Value> {
    let (mut store, instance) = instantiate_source(wasm_path)?;

    let source_info = instance
        .get_typed_func::<(), u32>(&mut store, "koma_source_info")
        .context("Missing export koma_source_info")?;

    let result_ptr = source_info.call(&mut store, ())?;
    let memory = instance.get_memory(&mut store, "memory")
        .ok_or_else(|| anyhow!("no memory export"))?;
    let result = read_result_buffer(&memory, &store, result_ptr)?;

    let logs = &store.data().logs;
    for log in logs {
        eprintln!("[source log] {}", log);
    }

    Ok(result)
}

pub fn run_operation(wasm_path: &Path, op: &str, request_json: &str) -> Result<serde_json::Value> {
    let (mut store, instance) = instantiate_source(wasm_path)?;

    let export_name = match op {
        "search" => "koma_source_search",
        "get_manga" => "koma_source_get_manga",
        "get_chapters" => "koma_source_get_chapters",
        "get_pages" => "koma_source_get_pages",
        "get_listings" => "koma_source_get_listings",
        "get_manga_list" => "koma_source_get_manga_list",
        "get_home" => "koma_source_get_home",
        "get_filters" => "koma_source_get_filters",
        "get_settings" => "koma_source_get_settings",
        "get_image_request" => "koma_source_get_image_request",
        "image_request" | "modify_image_request" => "koma_source_modify_image_request",
        _ => anyhow::bail!("Unknown operation: {}", op),
    };

    let memory = instance.get_memory(&mut store, "memory")
        .ok_or_else(|| anyhow!("no memory export"))?;

    // Auto-inject "operation" field into request JSON if missing
    let enriched_request = {
        let mut parsed: serde_json::Value = serde_json::from_str(request_json)
            .with_context(|| format!("Invalid request JSON: {}", request_json))?;
        if let Some(obj) = parsed.as_object_mut() {
            if !obj.contains_key("operation") {
                obj.insert("operation".into(), serde_json::Value::String(op.to_string()));
            }
        }
        serde_json::to_string(&parsed)?
    };
    let request_bytes = enriched_request.as_bytes();

    // Write request into guest memory
    let (req_ptr, req_len) = if let Ok(alloc) = instance.get_typed_func::<u32, u32>(&mut store, "koma_source_alloc") {
        let ptr = alloc.call(&mut store, request_bytes.len() as u32)?;
        write_guest_bytes(&memory, &mut store, ptr, request_bytes)?;
        (ptr, request_bytes.len() as u32)
    } else {
        // Fallback: write at high offset
        let offset = 0x10000_u32;
        write_guest_bytes(&memory, &mut store, offset, request_bytes)?;
        (offset, request_bytes.len() as u32)
    };

    let op_func = instance
        .get_typed_func::<(u32, u32), u32>(&mut store, export_name)
        .with_context(|| format!("Missing export {}", export_name))?;

    let result_ptr = op_func.call(&mut store, (req_ptr, req_len))?;
    let result = read_result_buffer(&memory, &store, result_ptr)?;

    let logs = &store.data().logs;
    for log in logs {
        eprintln!("[source log] {}", log);
    }

    Ok(result)
}

fn read_result_buffer(memory: &Memory, store: &impl AsContext<Data = HostState>, ptr: u32) -> Result<serde_json::Value> {
    let data = memory.data(store);
    let base = ptr as usize;

    // Result buffer layout: magic(4) + flags(4) + payload_len(4) + reserved(4) + payload
    const HEADER_LEN: usize = 16;
    const KOMA_MAGIC: u32 = 0x4B4F4D41;

    if base + HEADER_LEN > data.len() {
        anyhow::bail!("result pointer out of bounds: ptr={} memsize={}", ptr, data.len());
    }

    let magic = u32::from_le_bytes([data[base], data[base + 1], data[base + 2], data[base + 3]]);
    if magic != KOMA_MAGIC {
        anyhow::bail!("invalid result buffer magic: expected 0x{:08X}, got 0x{:08X}", KOMA_MAGIC, magic);
    }

    let _flags = u32::from_le_bytes([data[base + 4], data[base + 5], data[base + 6], data[base + 7]]);
    let payload_len = u32::from_le_bytes([data[base + 8], data[base + 9], data[base + 10], data[base + 11]]) as usize;

    let json_start = base + HEADER_LEN;
    let json_end = json_start + payload_len;
    if json_end > data.len() {
        anyhow::bail!("result buffer JSON out of bounds: start={} len={} memsize={}", json_start, payload_len, data.len());
    }

    let json_bytes = &data[json_start..json_end];
    let value: serde_json::Value = serde_json::from_slice(json_bytes)
        .with_context(|| {
            let preview = String::from_utf8_lossy(&json_bytes[..json_bytes.len().min(300)]);
            format!("Failed to parse result JSON (len={}): {}", payload_len, preview)
        })?;
    Ok(value)
}

fn instantiate_source(wasm_path: &Path) -> Result<(Store<HostState>, Instance)> {
    let engine = Engine::default();
    let module = Module::from_file(&engine, wasm_path)
        .with_context(|| format!("Failed to load WASM from {:?}", wasm_path))?;

    let mut store = Store::new(&engine, HostState::new());
    let mut linker = Linker::new(&engine);

    register_host_imports(&mut linker)?;

    let instance = linker.instantiate(&mut store, &module)
        .context("Failed to instantiate WASM module")?;

    Ok((store, instance))
}

fn register_host_imports(linker: &mut Linker<HostState>) -> Result<()> {
    // koma_host.log
    linker.func_wrap("koma_host", "log", |mut caller: Caller<'_, HostState>, level: i32, ptr: i32, len: i32| {
        let memory = caller.get_export("memory").and_then(|e| e.into_memory());
        if let Some(memory) = memory {
            let data = memory.data(&caller);
            let start = ptr as usize;
            let end = start + len as usize;
            if end <= data.len() {
                let msg = String::from_utf8_lossy(&data[start..end]).to_string();
                caller.data_mut().logs.push(format!("[level={}] {}", level, msg));
            }
        }
    })?;

    // koma_host.check_cancel
    linker.func_wrap("koma_host", "check_cancel", |_caller: Caller<'_, HostState>| -> i32 {
        0
    })?;

    // koma_host.http_request
    linker.func_wrap("koma_host", "http_request", |mut caller: Caller<'_, HostState>, req_ptr: i32, req_len: i32, out_ptr: i32, out_cap: i32| -> i32 {
        let memory = match caller.get_export("memory").and_then(|e| e.into_memory()) {
            Some(m) => m,
            None => return -8,
        };

        let data = memory.data(&caller);
        let start = req_ptr as usize;
        let end = start + req_len as usize;
        if end > data.len() { return -2; }
        let req_bytes = data[start..end].to_vec();

        let http_req: HttpRequest = match serde_json::from_slice(&req_bytes) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("[dev-runner] failed to parse HTTP request: {}", e);
                return -2;
            }
        };

        eprintln!("[dev-runner] HTTP {} {}", http_req.method, http_req.url);

        let response = do_http_request(&http_req);
        let response_json = match serde_json::to_vec(&response) {
            Ok(j) => j,
            Err(_) => return -8,
        };

        if response_json.len() > out_cap as usize { return -3; }

        let out_start = out_ptr as usize;
        let out_end = out_start + response_json.len();
        let data = memory.data_mut(&mut caller);
        if out_end > data.len() { return -8; }
        data[out_start..out_end].copy_from_slice(&response_json);
        response_json.len() as i32
    })?;

    // koma_host.html_parse
    linker.func_wrap("koma_host", "html_parse", |mut caller: Caller<'_, HostState>, html_ptr: i32, html_len: i32| -> i32 {
        let memory = match caller.get_export("memory").and_then(|e| e.into_memory()) {
            Some(m) => m,
            None => return -1,
        };
        let data = memory.data(&caller);
        let start = html_ptr as usize;
        let end = start + html_len as usize;
        if end > data.len() { return -1; }
        let html_bytes = data[start..end].to_vec();

        let html_str = String::from_utf8_lossy(&html_bytes).to_string();
        let doc = scraper::Html::parse_document(&html_str);

        let state = caller.data_mut();
        let idx = state.html_docs.len();
        state.html_docs.push(Some(doc));
        idx as i32
    })?;

    // koma_host.html_select
    linker.func_wrap("koma_host", "html_select", |mut caller: Caller<'_, HostState>, descriptor: i32, selector_ptr: i32, selector_len: i32| -> i32 {
        let memory = match caller.get_export("memory").and_then(|e| e.into_memory()) {
            Some(m) => m,
            None => return -1,
        };
        let data = memory.data(&caller);
        let sel_start = selector_ptr as usize;
        let sel_end = sel_start + selector_len as usize;
        if sel_end > data.len() { return -1; }
        let sel_bytes = data[sel_start..sel_end].to_vec();
        let selector_str = String::from_utf8_lossy(&sel_bytes).to_string();

        let selector = match scraper::Selector::parse(&selector_str) {
            Ok(s) => s,
            Err(_) => return -1,
        };

        let state = caller.data_mut();
        let idx = descriptor as usize;
        if idx >= state.html_docs.len() { return -1; }

        let first_html = {
            let doc = match &state.html_docs[idx] {
                Some(d) => d,
                None => return -1,
            };
            doc.select(&selector).next().map(|el| el.html())
        };

        match first_html {
            Some(html) => {
                let subdoc = scraper::Html::parse_fragment(&html);
                let new_idx = state.html_docs.len();
                state.html_docs.push(Some(subdoc));
                new_idx as i32
            }
            None => -1,
        }
    })?;

    // koma_host.html_select_all — returns count of matches, stores each as a fragment doc.
    // Guest passes an output buffer (out_ptr, out_cap) to receive descriptor i32s.
    // Returns: number of matches found (descriptors written = min(count, out_cap/4)).
    linker.func_wrap("koma_host", "html_select_all", |mut caller: Caller<'_, HostState>, descriptor: i32, selector_ptr: i32, selector_len: i32, out_ptr: i32, out_cap: i32| -> i32 {
        let memory = match caller.get_export("memory").and_then(|e| e.into_memory()) {
            Some(m) => m,
            None => return -1,
        };
        let data = memory.data(&caller);
        let sel_start = selector_ptr as usize;
        let sel_end = sel_start + selector_len as usize;
        if sel_end > data.len() { return -1; }
        let sel_bytes = data[sel_start..sel_end].to_vec();
        let selector_str = String::from_utf8_lossy(&sel_bytes).to_string();

        let selector = match scraper::Selector::parse(&selector_str) {
            Ok(s) => s,
            Err(_) => return -1,
        };

        let state = caller.data_mut();
        let idx = descriptor as usize;
        if idx >= state.html_docs.len() { return -1; }

        // Collect all matching elements as HTML fragments
        let matched_htmls: Vec<String> = {
            let doc = match &state.html_docs[idx] {
                Some(d) => d,
                None => return -1,
            };
            doc.select(&selector).map(|el| el.html()).collect()
        };

        let count = matched_htmls.len();
        let max_write = (out_cap as usize) / 4; // each descriptor is i32 = 4 bytes

        // Store each match as a fragment doc and write descriptor to guest memory
        let mut descriptors = Vec::new();
        for html in matched_htmls {
            let subdoc = scraper::Html::parse_fragment(&html);
            let new_idx = state.html_docs.len();
            state.html_docs.push(Some(subdoc));
            descriptors.push(new_idx as i32);
        }

        // Write descriptors to guest output buffer
        let memory = match caller.get_export("memory").and_then(|e| e.into_memory()) {
            Some(m) => m,
            None => return count as i32,
        };
        let write_count = descriptors.len().min(max_write);
        let out_start = out_ptr as usize;
        let mem_data = memory.data_mut(&mut caller);
        for (i, desc) in descriptors[..write_count].iter().enumerate() {
            let offset = out_start + i * 4;
            if offset + 4 <= mem_data.len() {
                mem_data[offset..offset + 4].copy_from_slice(&desc.to_le_bytes());
            }
        }

        count as i32
    })?;

    // koma_host.html_attr
    linker.func_wrap("koma_host", "html_attr", |mut caller: Caller<'_, HostState>, descriptor: i32, attr_ptr: i32, attr_len: i32, out_ptr: i32, out_cap: i32| -> i32 {
        let memory = match caller.get_export("memory").and_then(|e| e.into_memory()) {
            Some(m) => m,
            None => return -1,
        };
        let data = memory.data(&caller);
        let a_start = attr_ptr as usize;
        let a_end = a_start + attr_len as usize;
        if a_end > data.len() { return -1; }
        let attr_str = String::from_utf8_lossy(&data[a_start..a_end]).to_string();

        let state = caller.data_mut();
        let idx = descriptor as usize;
        if idx >= state.html_docs.len() { return -1; }

        let val = {
            let doc = match &state.html_docs[idx] {
                Some(d) => d,
                None => return -1,
            };
            let sel = scraper::Selector::parse("*").unwrap();
            doc.select(&sel)
                .find_map(|el| el.value().attr(&attr_str).map(|s| s.to_string()))
                .unwrap_or_default()
        };

        let val_bytes = val.as_bytes();
        if val_bytes.len() > out_cap as usize { return -3; }

        let out_start = out_ptr as usize;
        let out_end = out_start + val_bytes.len();
        // Need to re-borrow memory for write
        let memory = caller.get_export("memory").and_then(|e| e.into_memory()).unwrap();
        let data = memory.data_mut(&mut caller);
        if out_end > data.len() { return -1; }
        data[out_start..out_end].copy_from_slice(val_bytes);
        val_bytes.len() as i32
    })?;

    // koma_host.html_text
    linker.func_wrap("koma_host", "html_text", |mut caller: Caller<'_, HostState>, descriptor: i32, out_ptr: i32, out_cap: i32| -> i32 {
        let state = caller.data_mut();
        let idx = descriptor as usize;
        if idx >= state.html_docs.len() { return -1; }

        let text = {
            let doc = match &state.html_docs[idx] {
                Some(d) => d,
                None => return -1,
            };
            doc.root_element().text().collect::<String>()
        };

        let text_bytes = text.as_bytes();
        if text_bytes.len() > out_cap as usize { return -3; }

        let memory = caller.get_export("memory").and_then(|e| e.into_memory()).unwrap();
        let data = memory.data_mut(&mut caller);
        let out_start = out_ptr as usize;
        let out_end = out_start + text_bytes.len();
        if out_end > data.len() { return -1; }
        data[out_start..out_end].copy_from_slice(text_bytes);
        text_bytes.len() as i32
    })?;

    // koma_host.html_close
    linker.func_wrap("koma_host", "html_close", |mut caller: Caller<'_, HostState>, descriptor: i32| -> i32 {
        let state = caller.data_mut();
        let idx = descriptor as usize;
        if idx < state.html_docs.len() {
            state.html_docs[idx] = None;
        }
        0
    })?;

    Ok(())
}

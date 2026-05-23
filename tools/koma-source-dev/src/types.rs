use serde::{Deserialize, Serialize};

/// HTTP request envelope sent by the WASM source via koma_host.http_request
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HttpRequest {
    pub version: u32,
    pub method: String,
    pub url: String,
    #[serde(default)]
    pub headers: std::collections::HashMap<String, String>,
    #[serde(default)]
    pub body_base64: Option<String>,
    #[serde(default = "default_timeout")]
    pub timeout_ms: u64,
    #[serde(default = "default_response_kind")]
    pub response_kind: String,
}

fn default_timeout() -> u64 {
    30000
}

fn default_response_kind() -> String {
    "bodyText".to_string()
}

/// HTTP response envelope written back to the WASM source
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HttpResponse {
    pub ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<u16>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub headers: Option<std::collections::HashMap<String, String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub body_text: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub body_json: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub final_url: Option<String>,
    pub network_performed: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<HttpErrorEnvelope>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HttpErrorEnvelope {
    pub code: String,
    pub message: String,
    pub phase: String,
    pub retryable: bool,
}

/// Source operation result envelope returned by koma_source_* exports
#[derive(Debug, Serialize, Deserialize)]
pub struct SourceOperationResult {
    #[serde(flatten)]
    pub inner: serde_json::Value,
}

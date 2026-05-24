#include "http_host.h"

#include <cstdint>
#include <chrono>
#include <cstring>
#include <string>
#include <mutex>
#include <condition_variable>

#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define HTTP_LOG(fmt, ...) OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaHttpHost", fmt, ##__VA_ARGS__)
#else
#include <cstdio>
#define HTTP_LOG(fmt, ...) std::fprintf(stderr, "KomaHttpHost: " fmt "\n", ##__VA_ARGS__)
#endif

// HarmonyOS native HTTP API (API 20+)
#if __has_include(<network/netstack/net_http.h>)
#define KOMA_HAS_NATIVE_HTTP 1
#include <network/netstack/net_http.h>
#include <network/netstack/net_http_type.h>
#endif

namespace koma {
namespace http {

namespace {

/// Manually extract a JSON string value for a given key from raw bytes.
/// Expects: "key":"value" pattern. Returns empty string if not found.
std::string ExtractJsonString(const char *json, uint32_t jsonLen, const char *key)
{
    std::string pattern = std::string("\"") + key + "\":\"";
    std::string haystack(json, jsonLen);
    size_t pos = haystack.find(pattern);
    if (pos == std::string::npos) {
        return "";
    }
    pos += pattern.size();
    std::string result;
    while (pos < jsonLen) {
        char ch = json[pos++];
        if (ch == '"') break;
        if (ch == '\\' && pos < jsonLen) {
            result += json[pos++];
        } else {
            result += ch;
        }
    }
    return result;
}

/// Build a JSON response for the WASM guest.
/// Format: {"ok":true,"statusCode":NNN,"bodyText":"<json-escaped body>"}
/// The WASM source SDK expects this exact envelope with bodyText field.
int32_t WriteSuccessResponse(char *out, uint32_t outCap,
    int statusCode, const char *body, uint32_t bodyLen)
{
    // Build JSON prefix
    std::string prefix = "{\"ok\":true,\"statusCode\":" + std::to_string(statusCode) + ",\"bodyText\":\"";
    std::string suffix = "\"}";

    // JSON-escape the body
    std::string result;
    result.reserve(prefix.size() + bodyLen + bodyLen / 4 + suffix.size());
    result += prefix;

    for (uint32_t i = 0; i < bodyLen; i++) {
        unsigned char ch = static_cast<unsigned char>(body[i]);
        switch (ch) {
            case '"':  result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case '\n': result += "\\n";  break;
            case '\r': result += "\\r";  break;
            case '\t': result += "\\t";  break;
            default:
                if (ch < 0x20) {
                    char buf[8];
                    std::snprintf(buf, sizeof(buf), "\\u%04x", ch);
                    result += buf;
                } else {
                    result += static_cast<char>(ch);
                }
                break;
        }
    }

    result += suffix;

    if (result.size() > outCap) {
        return -3;
    }
    std::memcpy(out, result.data(), result.size());
    return static_cast<int32_t>(result.size());
}

int32_t WriteErrorResponse(char *out, uint32_t outCap, const char *code, const char *message)
{
    std::string errJson = std::string("{\"ok\":false,\"error\":{\"code\":\"") +
        code + "\",\"message\":\"" + message +
        "\",\"retryable\":false},\"networkPerformed\":false}";
    uint32_t len = static_cast<uint32_t>(errJson.size());
    if (len > outCap) {
        return -3;
    }
    std::memcpy(out, errJson.data(), len);
    return static_cast<int32_t>(len);
}

} // namespace

#if defined(KOMA_HAS_NATIVE_HTTP)

namespace {

struct HttpSyncContext {
    std::mutex mu;
    std::condition_variable cv;
    bool done = false;
    uint32_t errCode = 0;
    int responseCode = 0;
    std::string responseBody;

    void Reset()
    {
        done = false;
        errCode = 0;
        responseCode = 0;
        responseBody.clear();
    }
};

// The HarmonyOS native HTTP callback API does not expose a caller-owned user
// data pointer. Keep the synchronous host bridge serialized and store callback
// state in process-lifetime storage so NetStack worker callbacks never touch a
// HostRequest stack frame. Response payload bytes are copied during the callback;
// NetStack owns the callback response object and the request is cleaned up with
// OH_Http_Destroy after the callback boundary.
std::mutex g_requestMu;
std::mutex g_activeCtxMu;
HttpSyncContext g_activeCtxStorage;
HttpSyncContext *g_activeCtx = nullptr;

} // namespace

int32_t HostRequest(const char *requestJson, uint32_t requestLen,
    char *out, uint32_t outCap)
{
    if (requestJson == nullptr || requestLen == 0 || out == nullptr || outCap == 0) {
        return -1;
    }

    // Extract URL from request JSON
    std::string url = ExtractJsonString(requestJson, requestLen, "url");
    if (url.empty()) {
        HTTP_LOG("missing url in request");
        return WriteErrorResponse(out, outCap, "invalid_request", "missing url");
    }

    // Validate scheme
    if (url.substr(0, 8) != "https://" && url.substr(0, 7) != "http://") {
        HTTP_LOG("invalid scheme in url: %{public}s", url.c_str());
        return WriteErrorResponse(out, outCap, "invalid_request", "url must be http or https");
    }

    std::string method = ExtractJsonString(requestJson, requestLen, "method");
    if (method.empty()) {
        method = "GET";
    }

    HTTP_LOG("request: %{public}s %{public}s", method.c_str(), url.c_str());

    std::unique_lock<std::mutex> requestLock(g_requestMu);

    // Create request
    Http_Request *req = OH_Http_CreateRequest(url.c_str());
    if (req == nullptr) {
        return WriteErrorResponse(out, outCap, "network_error", "OH_Http_CreateRequest failed");
    }

    // Set method and timeouts
    if (req->options != nullptr) {
        req->options->method = method.c_str();
        req->options->readTimeout = 30000;     // 30s
        req->options->connectTimeout = 15000;  // 15s
    }

    // Synchronous wait context
    HttpSyncContext *ctx = &g_activeCtxStorage;
    {
        std::lock_guard<std::mutex> lock(ctx->mu);
        ctx->Reset();
    }
    {
        std::lock_guard<std::mutex> activeLock(g_activeCtxMu);
        g_activeCtx = ctx;
    }

    Http_ResponseCallback respCb = [](Http_Response *response, uint32_t errCode) {
        HttpSyncContext *c = nullptr;
        {
            std::lock_guard<std::mutex> activeLock(g_activeCtxMu);
            c = g_activeCtx;
        }
        HTTP_LOG("response callback fired: errCode=%{public}u ctx=%{public}p", errCode, c);
        if (c == nullptr) return;

        std::lock_guard<std::mutex> lock(c->mu);
        c->errCode = errCode;
        if (errCode == 0 && response != nullptr) {
            c->responseCode = response->responseCode;
            if (response->body.buffer != nullptr && response->body.length > 0) {
                c->responseBody.assign(response->body.buffer, response->body.length);
            }
            HTTP_LOG("response callback copied: status=%{public}d bodyLen=%{public}u",
                c->responseCode, response->body.length);
        } else {
            HTTP_LOG("response callback without response body: errCode=%{public}u response=%{public}p",
                errCode, response);
        }
        c->done = true;
        c->cv.notify_one();
    };

    Http_EventsHandler eventsHandler = {};

    int ret = OH_Http_Request(req, respCb, eventsHandler);
    if (ret != 0) {
        {
            std::lock_guard<std::mutex> activeLock(g_activeCtxMu);
            if (g_activeCtx == ctx) {
                g_activeCtx = nullptr;
            }
        }
        OH_Http_Destroy(&req);
        HTTP_LOG("OH_Http_Request failed with %{public}d", ret);
        return WriteErrorResponse(out, outCap, "network_error", "OH_Http_Request failed");
    }

    HTTP_LOG("OH_Http_Request dispatched, waiting for callback (timeout 60s)...");

    // Wait for response
    {
        std::unique_lock<std::mutex> lock(ctx->mu);
        ctx->cv.wait_for(lock, std::chrono::seconds(60), [ctx] { return ctx->done; });
    }

    HTTP_LOG("cleanup: destroying request after callback wait");
    OH_Http_Destroy(&req);
    {
        std::lock_guard<std::mutex> activeLock(g_activeCtxMu);
        if (g_activeCtx == ctx) {
            g_activeCtx = nullptr;
        }
    }
    HTTP_LOG("cleanup: request destroyed and callback context cleared");

    std::unique_lock<std::mutex> resultLock(ctx->mu);
    if (!ctx->done) {
        HTTP_LOG("request timed out");
        return WriteErrorResponse(out, outCap, "timeout", "HTTP request timed out");
    }

    if (ctx->errCode != 0) {
        HTTP_LOG("HTTP error code: %{public}u", ctx->errCode);
        return WriteErrorResponse(out, outCap, "network_error", "HTTP request failed");
    }

    HTTP_LOG("response: status=%{public}d bodyLen=%{public}zu",
        ctx->responseCode, ctx->responseBody.size());

    // Write raw body to output buffer (matching dev runner protocol)
    return WriteSuccessResponse(out, outCap, ctx->responseCode,
        ctx->responseBody.data(), static_cast<uint32_t>(ctx->responseBody.size()));
}

#else // !KOMA_HAS_NATIVE_HTTP

int32_t HostRequest(const char *requestJson, uint32_t requestLen,
    char *out, uint32_t outCap)
{
    (void)requestJson;
    (void)requestLen;
    return WriteErrorResponse(out, outCap, "network_disabled",
        "native HTTP not available on this platform");
}

#endif

} // namespace http
} // namespace koma

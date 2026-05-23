#include "http_host.h"

#include <cstdint>
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
/// Format: {"ok":true/false,"statusCode":NNN,"body":"...","headers":{}}
int32_t WriteSuccessResponse(char *out, uint32_t outCap,
    int statusCode, const char *body, uint32_t bodyLen)
{
    // Build: {"ok":true,"statusCode":200,"bodyBytes":NNN,"body":"<base64 or raw>"}
    // For simplicity, we write the raw body bytes directly; the WASM guest
    // expects the HTTP response body in the output buffer, not wrapped in JSON.
    // The dev runner protocol: host writes raw HTTP body, returns length.
    if (bodyLen > outCap) {
        return -3;
    }
    std::memcpy(out, body, bodyLen);
    return static_cast<int32_t>(bodyLen);
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
};

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
    HttpSyncContext ctx;

    // Response callback
    Http_ResponseCallback responseCb = [](Http_Response *response, uint32_t errCode) {
        // NOTE: We cannot capture local variables in a C callback.
        // This won't work. We need a different approach.
    };

    // The OH_Http_Request API uses plain C function pointers, so we can't use
    // C++ lambdas that capture state. We need a thread-local or global context.
    // Use a thread_local approach since WASM calls are single-threaded per module.
    
    static thread_local HttpSyncContext *tl_ctx = nullptr;
    tl_ctx = &ctx;

    Http_ResponseCallback respCb = [](Http_Response *response, uint32_t errCode) {
        HttpSyncContext *c = tl_ctx;
        if (c == nullptr) return;

        std::lock_guard<std::mutex> lock(c->mu);
        c->errCode = errCode;
        if (errCode == 0 && response != nullptr) {
            c->responseCode = response->responseCode;
            if (response->body.buffer != nullptr && response->body.length > 0) {
                c->responseBody.assign(response->body.buffer, response->body.length);
            }
            if (response->destroyResponse != nullptr) {
                response->destroyResponse(&response);
            }
        }
        c->done = true;
        c->cv.notify_one();
    };

    Http_EventsHandler eventsHandler = {};

    int ret = OH_Http_Request(req, respCb, eventsHandler);
    if (ret != 0) {
        OH_Http_Destroy(&req);
        HTTP_LOG("OH_Http_Request failed with %{public}d", ret);
        return WriteErrorResponse(out, outCap, "network_error", "OH_Http_Request failed");
    }

    // Wait for response
    {
        std::unique_lock<std::mutex> lock(ctx.mu);
        ctx.cv.wait_for(lock, std::chrono::seconds(60), [&ctx] { return ctx.done; });
    }

    OH_Http_Destroy(&req);
    tl_ctx = nullptr;

    if (!ctx.done) {
        HTTP_LOG("request timed out");
        return WriteErrorResponse(out, outCap, "timeout", "HTTP request timed out");
    }

    if (ctx.errCode != 0) {
        HTTP_LOG("HTTP error code: %{public}u", ctx.errCode);
        return WriteErrorResponse(out, outCap, "network_error", "HTTP request failed");
    }

    HTTP_LOG("response: status=%{public}d bodyLen=%{public}zu",
        ctx.responseCode, ctx.responseBody.size());

    // Write raw body to output buffer (matching dev runner protocol)
    return WriteSuccessResponse(out, outCap, ctx.responseCode,
        ctx.responseBody.data(), static_cast<uint32_t>(ctx.responseBody.size()));
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

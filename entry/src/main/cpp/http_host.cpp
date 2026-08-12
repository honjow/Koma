#include "http_host.h"

#include <atomic>
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

namespace koma {
namespace http {

namespace {

int32_t WriteResponse(char *out, uint32_t outCap, const std::string &response)
{
    if (response.size() > outCap) {
        return -3;
    }
    std::memcpy(out, response.data(), response.size());
    return static_cast<int32_t>(response.size());
}

int32_t WriteErrorResponse(char *out, uint32_t outCap, const char *code)
{
    return WriteResponse(out, outCap,
        std::string("{\"ok\":false,\"error\":{\"code\":\"") + code +
        "\",\"message\":\"network request failed\",\"retryable\":true},\"networkPerformed\":false}");
}

struct HttpBridgeCall {
    std::mutex mu;
    std::condition_variable cv;
    bool done = false;
    std::string request;
    std::string response;
    std::atomic<uint32_t> refs { 1 };

    void Complete(const std::string &value)
    {
        std::lock_guard<std::mutex> lock(mu);
        if (!done) {
            response = value;
            done = true;
            cv.notify_one();
        }
    }

    void Release()
    {
        if (refs.fetch_sub(1) == 1) {
            delete this;
        }
    }
};

std::mutex g_transportMu;
napi_threadsafe_function g_transport = nullptr;

void CompleteBridgeCall(HttpBridgeCall *call, const std::string &response)
{
    call->Complete(response);
    call->Release();
}

napi_value Undefined(napi_env env)
{
    napi_value value = nullptr;
    napi_get_undefined(env, &value);
    return value;
}

napi_value HttpTransportResolved(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    void *data = nullptr;
    napi_get_cb_info(env, info, &argc, argv, nullptr, &data);
    auto *call = static_cast<HttpBridgeCall *>(data);
    if (call == nullptr) {
        return Undefined(env);
    }
    if (argc < 1) {
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"transport_invalid_response\",\"message\":\"network request failed\",\"retryable\":true}}");
        return Undefined(env);
    }
    size_t length = 0;
    if (napi_get_value_string_utf8(env, argv[0], nullptr, 0, &length) != napi_ok) {
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"transport_invalid_response\",\"message\":\"network request failed\",\"retryable\":true}}");
        return Undefined(env);
    }
    std::string response(length + 1, '\0');
    size_t copied = 0;
    if (napi_get_value_string_utf8(env, argv[0], response.data(), response.size(), &copied) != napi_ok) {
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"transport_invalid_response\",\"message\":\"network request failed\",\"retryable\":true}}");
        return Undefined(env);
    }
    response.resize(copied);
    CompleteBridgeCall(call, response);
    return Undefined(env);
}

napi_value HttpTransportRejected(napi_env env, napi_callback_info info)
{
    size_t argc = 0;
    void *data = nullptr;
    napi_get_cb_info(env, info, &argc, nullptr, nullptr, &data);
    auto *call = static_cast<HttpBridgeCall *>(data);
    if (call != nullptr) {
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"network_error\",\"message\":\"network request failed\",\"retryable\":true}}");
    }
    return Undefined(env);
}

void CallArkTsHttpTransport(napi_env env, napi_value callback, void *context, void *data)
{
    (void)context;
    auto *call = static_cast<HttpBridgeCall *>(data);
    if (call == nullptr) {
        return;
    }
    if (env == nullptr || callback == nullptr) {
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"transport_unavailable\",\"message\":\"network request failed\",\"retryable\":true}}");
        return;
    }

    napi_handle_scope scope = nullptr;
    if (napi_open_handle_scope(env, &scope) != napi_ok) {
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"transport_unavailable\",\"message\":\"network request failed\",\"retryable\":true}}");
        return;
    }
    napi_value input = nullptr;
    napi_value undefined = nullptr;
    napi_value promise = nullptr;
    napi_get_undefined(env, &undefined);
    if (napi_create_string_utf8(env, call->request.c_str(), call->request.size(), &input) != napi_ok ||
        napi_call_function(env, undefined, callback, 1, &input, &promise) != napi_ok) {
        napi_close_handle_scope(env, scope);
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"transport_unavailable\",\"message\":\"network request failed\",\"retryable\":true}}");
        return;
    }
    bool isPromise = false;
    napi_value then = nullptr;
    napi_value resolved = nullptr;
    napi_value rejected = nullptr;
    napi_value callbacks[2] = {nullptr, nullptr};
    if (napi_is_promise(env, promise, &isPromise) != napi_ok || !isPromise ||
        napi_get_named_property(env, promise, "then", &then) != napi_ok ||
        napi_create_function(env, "sourceHttpResolved", NAPI_AUTO_LENGTH, HttpTransportResolved, call, &resolved) != napi_ok ||
        napi_create_function(env, "sourceHttpRejected", NAPI_AUTO_LENGTH, HttpTransportRejected, call, &rejected) != napi_ok) {
        napi_close_handle_scope(env, scope);
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"transport_unavailable\",\"message\":\"network request failed\",\"retryable\":true}}");
        return;
    }
    callbacks[0] = resolved;
    callbacks[1] = rejected;
    if (napi_call_function(env, promise, then, 2, callbacks, nullptr) != napi_ok) {
        napi_close_handle_scope(env, scope);
        CompleteBridgeCall(call, "{\"ok\":false,\"error\":{\"code\":\"transport_unavailable\",\"message\":\"network request failed\",\"retryable\":true}}");
        return;
    }
    napi_close_handle_scope(env, scope);
}

} // namespace

bool ConfigureArkTsHttpTransport(napi_env env, napi_value callback)
{
    napi_valuetype callbackType = napi_undefined;
    if (napi_typeof(env, callback, &callbackType) != napi_ok || callbackType != napi_function) {
        return false;
    }
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "KomaSourceHttpTransport", NAPI_AUTO_LENGTH, &resourceName);
    napi_threadsafe_function next = nullptr;
    if (napi_create_threadsafe_function(env, callback, nullptr, resourceName, 0, 1,
        nullptr, nullptr, nullptr, CallArkTsHttpTransport, &next) != napi_ok) {
        return false;
    }
    napi_threadsafe_function previous = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_transportMu);
        previous = g_transport;
        g_transport = next;
    }
    if (previous != nullptr) {
        napi_release_threadsafe_function(previous, napi_tsfn_abort);
    }
    return true;
}

int32_t HostRequest(const char *requestJson, uint32_t requestLen, char *out, uint32_t outCap)
{
    if (requestJson == nullptr || requestLen == 0 || out == nullptr || outCap == 0) {
        return -1;
    }
    napi_threadsafe_function transport = nullptr;
    {
        std::lock_guard<std::mutex> lock(g_transportMu);
        transport = g_transport;
        if (transport != nullptr && napi_acquire_threadsafe_function(transport) != napi_ok) {
            transport = nullptr;
        }
    }
    if (transport == nullptr) {
        return WriteErrorResponse(out, outCap, "transport_unavailable");
    }
    auto *call = new HttpBridgeCall();
    call->request.assign(requestJson, requestLen);
    call->refs.fetch_add(1);
    const napi_status queued = napi_call_threadsafe_function(transport, call, napi_tsfn_nonblocking);
    napi_release_threadsafe_function(transport, napi_tsfn_release);
    if (queued != napi_ok) {
        call->Release();
        call->Release();
        return WriteErrorResponse(out, outCap, "transport_unavailable");
    }
    std::string response;
    {
        std::unique_lock<std::mutex> lock(call->mu);
        if (!call->cv.wait_for(lock, std::chrono::seconds(60), [call] { return call->done; })) {
            call->Release();
            return WriteErrorResponse(out, outCap, "timeout");
        }
        response = call->response;
    }
    call->Release();
    return WriteResponse(out, outCap, response);
}

} // namespace http
} // namespace koma

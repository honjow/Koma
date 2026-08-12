#pragma once

#include <cstdint>

#include <napi/native_api.h>

namespace koma {
namespace http {

/// Installs the UI-runtime NetworkKit callback used by synchronous WAMR host
/// calls.  The caller is an ArkTS function that accepts one source HTTP
/// request envelope and resolves to the matching response envelope.
///
/// WAMR calls originate on a taskpool worker.  The bridge deliberately sends
/// the request to ArkTS through a thread-safe N-API function, so NetworkKit
/// owns headers, POST bodies, timeouts and transport lifecycle instead of the
/// limited native NetStack request struct.
bool ConfigureArkTsHttpTransport(napi_env env, napi_value callback);

/// Perform a synchronous HTTP request from the WAMR host import.  The source
/// ABI remains synchronous: this function waits on the taskpool worker for
/// the registered ArkTS NetworkKit callback, then writes its response JSON to
/// `out` (up to `outCap` bytes).
/// Returns: bytes written on success, or negative error code.
///   -1: invalid request
///   -2: network error
///   -3: buffer too small
int32_t HostRequest(const char *requestJson, uint32_t requestLen,
    char *out, uint32_t outCap);

} // namespace http
} // namespace koma

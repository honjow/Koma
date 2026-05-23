#pragma once

#include <cstdint>

namespace koma {
namespace http {

/// Perform a synchronous HTTP GET request from the WAMR host import.
/// Parses the request JSON from the WASM guest, makes the HTTP call,
/// and writes the response JSON into `out` (up to `outCap` bytes).
/// Returns: bytes written on success, or negative error code.
///   -1: invalid request
///   -2: network error
///   -3: buffer too small
int32_t HostRequest(const char *requestJson, uint32_t requestLen,
    char *out, uint32_t outCap);

} // namespace http
} // namespace koma

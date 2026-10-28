#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace koma {

std::string RunBundledWasmJsonCall(const std::string &requestJson);
std::string RunWasmJsonCallFromBytes(const std::string &requestJson, const std::vector<uint8_t> &wasmBytes,
    const std::string &httpContextJson = "", const std::string &sourceId = "");

} // namespace koma

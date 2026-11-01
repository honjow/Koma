#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace koma {
struct ImageProcessorResult {
    bool changed = false;
    uint32_t width = 0;
    uint32_t height = 0;
    std::vector<uint8_t> pixels;
    std::string error;
};

// The worker supplies tightly packed RGBA8888. Algorithms and their parameters
// belong to downloaded plugins; this interface contains no named-site behavior.
bool RegisterImageProcessorImports();
std::string InspectImageProcessor(const std::vector<uint8_t> &wasm);
std::string RunImageProcessorInspection(const std::vector<uint8_t> &wasm);
ImageProcessorResult ExecuteImageProcessor(const std::vector<uint8_t> &wasm,
    const uint8_t *rgba, size_t byteCount, uint32_t width, uint32_t height,
    const std::string &configuration);
ImageProcessorResult RunImageProcessor(const std::vector<uint8_t> &wasm,
    const uint8_t *rgba, size_t byteCount, uint32_t width, uint32_t height,
    const std::string &configuration);
} // namespace koma

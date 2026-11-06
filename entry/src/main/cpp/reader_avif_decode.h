#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace koma::reader {
struct AvifPixels {
    uint32_t width;
    uint32_t height;
    std::vector<uint8_t> rgba;
};

AvifPixels DecodeAvifDisplayPixels(const uint8_t *data, size_t size);
}

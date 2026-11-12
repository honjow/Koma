#include "reader_avif_decode.h"
#include <avif/avif.h>
#include <lcms2.h>
#include <array>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <utility>

namespace koma::reader {
namespace {
constexpr uint32_t kMaxPixels = 32 * 1024 * 1024;
constexpr uint32_t kMaxDimension = 16384;
constexpr size_t kMaxEncodedBytes = 64 * 1024 * 1024;

void RequireDisplayProfile(const avifImage &image)
{
    // ImageKit's packed display PNG uses sRGB RGBA8. Preserve profiles that
    // cannot be represented faithfully here through the native source route.
    const bool srgbPrimaries = image.colorPrimaries == AVIF_COLOR_PRIMARIES_BT709 ||
        image.colorPrimaries == AVIF_COLOR_PRIMARIES_UNSPECIFIED;
    const bool srgbTransfer = image.transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_SRGB ||
        image.transferCharacteristics == AVIF_TRANSFER_CHARACTERISTICS_UNSPECIFIED;
    if (image.depth != 8 || (image.icc.size == 0 && (!srgbPrimaries || !srgbTransfer)) || image.gainMap != nullptr ||
        ((image.transformFlags & AVIF_TRANSFORM_PASP) && image.pasp.hSpacing != image.pasp.vSpacing)) {
        throw std::runtime_error("reader_avif_profile_unsupported");
    }
}

void ConvertEmbeddedIccToSrgb(AvifPixels &pixels, const avifImage &image)
{
    constexpr size_t kMaxIccBytes = 4 * 1024 * 1024;
    if (image.icc.size > kMaxIccBytes) throw std::runtime_error("reader_avif_profile_unsupported");

    using Profile = std::unique_ptr<void, decltype(&cmsCloseProfile)>;
    using Transform = std::unique_ptr<void, decltype(&cmsDeleteTransform)>;
    Profile input(cmsOpenProfileFromMem(image.icc.data, image.icc.size), cmsCloseProfile);
    Profile srgb(cmsCreate_sRGBProfile(), cmsCloseProfile);
    if (!input || !srgb || cmsGetDeviceClass(input.get()) == cmsSigLinkClass) {
        throw std::runtime_error("reader_avif_profile_unsupported");
    }
    const auto space = cmsGetColorSpace(input.get());
    const bool gray = space == cmsSigGrayData && image.yuvFormat == AVIF_PIXEL_FORMAT_YUV400;
    if (!gray && space != cmsSigRgbData) throw std::runtime_error("reader_avif_profile_unsupported");

    // AVIF's ICC profile describes the decoded samples. Convert them before
    // ImageKit packs the display-only sRGB PNG, preserving the alpha channel.
    Transform transform(cmsCreateTransform(input.get(), gray ? TYPE_GRAY_8 : TYPE_RGBA_8,
        srgb.get(), gray ? TYPE_RGB_8 : TYPE_RGBA_8, INTENT_RELATIVE_COLORIMETRIC,
        gray ? 0 : cmsFLAGS_COPY_ALPHA), cmsDeleteTransform);
    if (!transform) throw std::runtime_error("reader_avif_profile_unsupported");
    if (!gray) {
        cmsDoTransform(transform.get(), pixels.rgba.data(), pixels.rgba.data(), pixels.rgba.size() / 4);
        return;
    }

    std::array<uint8_t, 256> levels{};
    std::array<std::array<uint8_t, 3>, 256> rgb{};
    for (size_t i = 0; i < levels.size(); ++i) levels[i] = static_cast<uint8_t>(i);
    cmsDoTransform(transform.get(), levels.data(), rgb.data(), levels.size());
    for (size_t i = 0; i < pixels.rgba.size(); i += 4) {
        const auto &color = rgb[pixels.rgba[i]];
        std::memcpy(pixels.rgba.data() + i, color.data(), color.size());
    }
}

AvifPixels ApplyDisplayTransforms(AvifPixels decoded, const avifImage &image)
{
    avifCropRect crop{0, 0, decoded.width, decoded.height};
    if ((image.transformFlags & AVIF_TRANSFORM_CLAP) &&
        !avifCropRectFromCleanApertureBox(&crop, &image.clap, decoded.width, decoded.height, nullptr)) {
        throw std::runtime_error("reader_avif_invalid_crop");
    }
    const auto turn = (image.transformFlags & AVIF_TRANSFORM_IROT) ? image.irot.angle : 0;
    const bool mirror = image.transformFlags & AVIF_TRANSFORM_IMIR;
    if (turn == 0 && !mirror && crop.width == decoded.width && crop.height == decoded.height) return decoded;
    AvifPixels output{turn % 2 ? crop.height : crop.width, turn % 2 ? crop.width : crop.height, {}};
    output.rgba.resize(static_cast<size_t>(output.width) * output.height * 4);
    // MIAF 7.3.6.7 applies clean aperture, then rotation, then mirroring.
    for (uint32_t y = 0; y < crop.height; ++y) {
        for (uint32_t x = 0; x < crop.width; ++x) {
            uint32_t dx = x;
            uint32_t dy = y;
            switch (turn) {
                case 1: dx = y; dy = crop.width - 1 - x; break;
                case 2: dx = crop.width - 1 - x; dy = crop.height - 1 - y; break;
                case 3: dx = crop.height - 1 - y; dy = x; break;
                default: break;
            }
            if (mirror && image.imir.axis == 0) dy = output.height - 1 - dy;
            if (mirror && image.imir.axis == 1) dx = output.width - 1 - dx;
            const auto source = (static_cast<size_t>(y + crop.y) * decoded.width + x + crop.x) * 4;
            const auto destination = (static_cast<size_t>(dy) * output.width + dx) * 4;
            std::memcpy(output.rgba.data() + destination, decoded.rgba.data() + source, 4);
        }
    }
    return output;
}
}

AvifPixels DecodeAvifDisplayPixels(const uint8_t *data, size_t size)
{
    const avifROData input{data, size};
    if (data == nullptr || size > kMaxEncodedBytes || !avifPeekCompatibleFileType(&input)) {
        throw std::runtime_error("reader_avif_invalid_input");
    }
    std::unique_ptr<avifDecoder, decltype(&avifDecoderDestroy)> decoder(avifDecoderCreate(), avifDecoderDestroy);
    if (!decoder) throw std::runtime_error("reader_avif_decode_failed");
    decoder->codecChoice = AVIF_CODEC_CHOICE_AOM;
    decoder->maxThreads = 2;
    decoder->imageSizeLimit = kMaxPixels;
    decoder->imageDimensionLimit = kMaxDimension;
    decoder->imageCountLimit = 1;
    decoder->ignoreExif = AVIF_TRUE;
    decoder->ignoreXMP = AVIF_TRUE;
    if (avifDecoderSetIOMemory(decoder.get(), data, size) != AVIF_RESULT_OK ||
        avifDecoderParse(decoder.get()) != AVIF_RESULT_OK || decoder->imageCount != 1) {
        throw std::runtime_error("reader_avif_decode_failed");
    }
    if (avifDecoderNextImage(decoder.get()) != AVIF_RESULT_OK) throw std::runtime_error("reader_avif_decode_failed");
    const avifImage &image = *decoder->image;
    RequireDisplayProfile(image);
    const size_t pixels = static_cast<size_t>(image.width) * image.height;
    if (pixels == 0 || pixels > kMaxPixels) throw std::runtime_error("reader_avif_dimensions");
    AvifPixels decoded{image.width, image.height, std::vector<uint8_t>(pixels * 4)};
    avifRGBImage rgb{};
    avifRGBImageSetDefaults(&rgb, &image);
    rgb.format = AVIF_RGB_FORMAT_RGBA;
    rgb.alphaPremultiplied = AVIF_FALSE;
    rgb.pixels = decoded.rgba.data();
    rgb.rowBytes = image.width * 4;
    if (avifImageYUVToRGB(&image, &rgb) != AVIF_RESULT_OK) throw std::runtime_error("reader_avif_decode_failed");
    if (image.icc.size != 0) ConvertEmbeddedIccToSrgb(decoded, image);
    return ApplyDisplayTransforms(std::move(decoded), image);
}
}

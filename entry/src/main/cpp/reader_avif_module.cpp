#include "reader_avif_decode.h"
#include <multimedia/image_framework/image/image_packer_native.h>
#include <multimedia/image_framework/image/pixelmap_native.h>
#include <napi/native_api.h>
#include <cstring>
#include <memory>
#include <stdexcept>

namespace {
void Require(Image_ErrorCode status)
{
    if (status != IMAGE_SUCCESS) throw std::runtime_error("reader_avif_png_failed");
}

std::vector<uint8_t> PackDisplayPng(koma::reader::AvifPixels pixels)
{
    OH_Pixelmap_InitializationOptions *rawInit = nullptr;
    Require(OH_PixelmapInitializationOptions_Create(&rawInit));
    std::unique_ptr<OH_Pixelmap_InitializationOptions, decltype(&OH_PixelmapInitializationOptions_Release)>
        init(rawInit, OH_PixelmapInitializationOptions_Release);
    Require(OH_PixelmapInitializationOptions_SetWidth(init.get(), pixels.width));
    Require(OH_PixelmapInitializationOptions_SetHeight(init.get(), pixels.height));
    Require(OH_PixelmapInitializationOptions_SetSrcPixelFormat(init.get(), PIXEL_FORMAT_RGBA_8888));
    Require(OH_PixelmapInitializationOptions_SetPixelFormat(init.get(), PIXEL_FORMAT_RGBA_8888));
    Require(OH_PixelmapInitializationOptions_SetAlphaType(init.get(), PIXELMAP_ALPHA_TYPE_UNPREMULTIPLIED));
    OH_PixelmapNative *rawMap = nullptr;
    Require(OH_PixelmapNative_CreatePixelmap(pixels.rgba.data(), pixels.rgba.size(), init.get(), &rawMap));
    std::unique_ptr<OH_PixelmapNative, decltype(&OH_PixelmapNative_Release)> map(rawMap, OH_PixelmapNative_Release);

    OH_ImagePackerNative *rawPacker = nullptr;
    Require(OH_ImagePackerNative_Create(&rawPacker));
    std::unique_ptr<OH_ImagePackerNative, decltype(&OH_ImagePackerNative_Release)>
        packer(rawPacker, OH_ImagePackerNative_Release);
    OH_PackingOptions *rawOptions = nullptr;
    Require(OH_PackingOptions_Create(&rawOptions));
    std::unique_ptr<OH_PackingOptions, decltype(&OH_PackingOptions_Release)>
        options(rawOptions, OH_PackingOptions_Release);
    char mime[] = "image/png";
    Image_MimeType format{mime, sizeof(mime) - 1};
    Require(OH_PackingOptions_SetMimeType(options.get(), &format));
    // Reserve a bounded margin for row filter bytes, deflate blocks and PNG chunks.
    std::vector<uint8_t> output(pixels.rgba.size() + pixels.rgba.size() / 16 + 131072);
    size_t size = output.size();
    Require(OH_ImagePackerNative_PackToDataFromPixelmap(packer.get(), options.get(), map.get(), output.data(), &size));
    constexpr uint8_t png[] = {137, 80, 78, 71, 13, 10, 26, 10};
    if (size < sizeof(png) || size > output.size() || std::memcmp(output.data(), png, sizeof(png)) != 0) {
        throw std::runtime_error("reader_avif_png_failed");
    }
    output.resize(size);
    return output;
}

// This entry is synchronous inside the Koma TaskPool worker. Neither AV1 decoding nor PNG packing runs on the UI thread.
napi_value DecodeDisplayPng(napi_env env, napi_callback_info info)
{
    size_t count = 1;
    napi_value arg = nullptr;
    void *bytes = nullptr;
    size_t size = 0;
    if (napi_get_cb_info(env, info, &count, &arg, nullptr, nullptr) != napi_ok || count != 1 ||
        napi_get_arraybuffer_info(env, arg, &bytes, &size) != napi_ok) {
        napi_throw_type_error(env, nullptr, "reader_avif_invalid_input");
        return nullptr;
    }
    try {
        const auto png = PackDisplayPng(koma::reader::DecodeAvifDisplayPixels(static_cast<const uint8_t *>(bytes), size));
        napi_value result;
        void *output = nullptr;
        if (napi_create_arraybuffer(env, png.size(), &output, &result) != napi_ok || output == nullptr) {
            throw std::runtime_error("reader_avif_png_failed");
        }
        std::memcpy(output, png.data(), png.size());
        return result;
    } catch (const std::exception &error) {
        napi_throw_error(env, nullptr, error.what());
        return nullptr;
    }
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor entry{"decodeDisplayPng", nullptr, DecodeDisplayPng, nullptr, nullptr, nullptr,
        napi_default, nullptr};
    napi_define_properties(env, exports, 1, &entry);
    return exports;
}

napi_module module{1, 0, nullptr, Init, "koma_reader_avif", nullptr, {0}};
}

extern "C" __attribute__((constructor)) void RegisterReaderAvifModule() { napi_module_register(&module); }

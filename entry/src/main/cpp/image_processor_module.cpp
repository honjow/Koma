#include "image_processor_host.h"
#include <napi/native_api.h>
#include <cstring>
#include <memory>

namespace {
bool Bytes(napi_env env, napi_value value, const uint8_t *&data, size_t &size)
{
    bool typed = false, buffer = false;
    if (napi_is_typedarray(env, value, &typed) != napi_ok) return false;
    void *pointer = nullptr;
    if (typed) {
        napi_typedarray_type type;
        napi_value owner;
        size_t offset = 0;
        if (napi_get_typedarray_info(env, value, &type, &size, &pointer, &owner, &offset) != napi_ok ||
            (type != napi_uint8_array && type != napi_uint8_clamped_array)) return false;
    } else {
        if (napi_is_arraybuffer(env, value, &buffer) != napi_ok || !buffer ||
            napi_get_arraybuffer_info(env, value, &pointer, &size) != napi_ok) return false;
    }
    data = static_cast<const uint8_t *>(pointer);
    return data != nullptr && size > 0;
}
void Boolean(napi_env env, napi_value object, const char *name, bool value)
{
    napi_value property;
    napi_get_boolean(env, value, &property);
    napi_set_named_property(env, object, name, property);
}
void Number(napi_env env, napi_value object, const char *name, uint32_t value)
{
    napi_value property;
    napi_create_uint32(env, value, &property);
    napi_set_named_property(env, object, name, property);
}
} // namespace

napi_value KomaInspectImageProcessor(napi_env env, napi_callback_info info)
{
    size_t count = 2, size = 0;
    napi_value args[2] {};
    const uint8_t *bytes = nullptr;
    bool sourceOwned = false;
    napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    if (count < 1 || !Bytes(env, args[0], bytes, size) || size > 2u * 1024u * 1024u ||
        (count == 2 && napi_get_value_bool(env, args[1], &sourceOwned) != napi_ok)) {
        napi_throw_type_error(env, nullptr, "Invalid image processor module");
        return nullptr;
    }
    const auto reason = koma::RunImageProcessorInspection(std::vector<uint8_t>(bytes, bytes + size), sourceOwned);
    napi_value result;
    napi_create_string_utf8(env, reason.c_str(), reason.size(), &result);
    return result;
}

// Synchronous by design: the ArkTS entry is @Concurrent. Input remains owned by
// the worker's ArrayBuffer for this call; it is not copied into a second native image.
napi_value KomaRunImageProcessor(napi_env env, napi_callback_info info)
{
    size_t count = 6;
    napi_value args[6] {};
    napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    const uint8_t *wasm = nullptr, *pixels = nullptr;
    size_t wasmCount = 0, pixelCount = 0, configurationLength = 0;
    uint32_t width = 0, height = 0;
    bool sourceOwned = false;
    if (count < 5 || !Bytes(env, args[0], wasm, wasmCount) || wasmCount > 2u * 1024u * 1024u ||
        !Bytes(env, args[1], pixels, pixelCount) ||
        (count == 6 && napi_get_value_bool(env, args[5], &sourceOwned) != napi_ok) ||
        napi_get_value_uint32(env, args[2], &width) != napi_ok || napi_get_value_uint32(env, args[3], &height) != napi_ok ||
        napi_get_value_string_utf8(env, args[4], nullptr, 0, &configurationLength) != napi_ok || configurationLength > 4u * 1024u * 1024u) {
        napi_throw_type_error(env, nullptr, "Invalid image processor input");
        return nullptr;
    }
    std::string configuration(configurationLength + 1, '\0');
    napi_get_value_string_utf8(env, args[4], configuration.data(), configuration.size(), &configurationLength);
    configuration.resize(configurationLength);
    auto result = koma::RunImageProcessor(std::vector<uint8_t>(wasm, wasm + wasmCount), pixels, pixelCount,
        width, height, configuration, sourceOwned);
    napi_value object, reason, buffer;
    napi_create_object(env, &object);
    Boolean(env, object, "ok", result.error.empty());
    Boolean(env, object, "changed", result.changed);
    Number(env, object, "width", result.width);
    Number(env, object, "height", result.height);
    napi_create_string_utf8(env, result.error.c_str(), result.error.size(), &reason);
    napi_set_named_property(env, object, "reason", reason);
    if (result.changed && width == 0 && height == 0) {
        // The byte stage may return directly across TaskPool. Give that result
        // ordinary JS buffer ownership without an external native finalizer.
        void *destination = nullptr;
        if (napi_create_arraybuffer(env, result.pixels.size(), &destination, &buffer) != napi_ok) {
            napi_throw_error(env, nullptr, "Cannot return restored image bytes");
            return nullptr;
        }
        std::memcpy(destination, result.pixels.data(), result.pixels.size());
    } else if (result.changed) {
        auto bytes = std::make_unique<std::vector<uint8_t>>(std::move(result.pixels));
        if (napi_create_external_arraybuffer(env, bytes->data(), bytes->size(),
            [](napi_env, void *, void *owner) { delete static_cast<std::vector<uint8_t> *>(owner); }, bytes.get(), &buffer) != napi_ok) {
            napi_throw_error(env, nullptr, "Cannot return processed image");
            return nullptr;
        }
        bytes.release();
    } else {
        void *unused = nullptr;
        napi_create_arraybuffer(env, 0, &unused, &buffer);
    }
    napi_set_named_property(env, object, "pixels", buffer);
    return object;
}

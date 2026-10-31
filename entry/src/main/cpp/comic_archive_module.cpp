#include "comic_archive_extract.h"
#include <napi/native_api.h>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
struct Extraction {
    napi_async_work work = nullptr;
    napi_deferred deferred = nullptr;
    std::string source, destination, error;
};

std::string StringArgument(napi_env env, napi_value value)
{
    size_t size = 0;
    if (napi_get_value_string_utf8(env, value, nullptr, 0, &size) != napi_ok)
        throw std::runtime_error("Archive paths must be strings");
    std::vector<char> buffer(size + 1);
    napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &size);
    return std::string(buffer.data(), size);
}

napi_value Extract(napi_env env, napi_callback_info info)
{
    size_t count = 2;
    napi_value args[2];
    napi_get_cb_info(env, info, &count, args, nullptr, nullptr);
    auto operation = std::make_unique<Extraction>();
    try {
        if (count != 2) throw std::runtime_error("Archive extraction requires source and destination");
        operation->source = StringArgument(env, args[0]);
        operation->destination = StringArgument(env, args[1]);
    } catch (const std::exception &error) { napi_throw_type_error(env, nullptr, error.what()); return nullptr; }
    napi_value promise, label;
    napi_create_promise(env, &operation->deferred, &promise);
    napi_create_string_utf8(env, "ExtractComicArchive", NAPI_AUTO_LENGTH, &label);
    auto result = napi_create_async_work(env, nullptr, label,
        [](napi_env, void *data) {
            auto &request = *static_cast<Extraction *>(data);
            try { ExtractComicArchive(request.source, request.destination); }
            catch (const std::exception &error) { request.error = error.what(); }
        },
        [](napi_env env, napi_status status, void *data) {
            std::unique_ptr<Extraction> request(static_cast<Extraction *>(data));
            napi_value value;
            if (status != napi_ok || !request->error.empty()) {
                napi_value message;
                napi_create_string_utf8(env, request->error.empty() ? "Archive extraction interrupted" : request->error.c_str(), NAPI_AUTO_LENGTH, &message);
                napi_create_error(env, nullptr, message, &value);
                napi_reject_deferred(env, request->deferred, value);
            } else { napi_get_undefined(env, &value); napi_resolve_deferred(env, request->deferred, value); }
            napi_delete_async_work(env, request->work);
        }, operation.get(), &operation->work);
    if (result == napi_ok) result = napi_queue_async_work(env, operation->work);
    if (result != napi_ok) {
        if (operation->work) napi_delete_async_work(env, operation->work);
        napi_throw_error(env, nullptr, "Cannot schedule archive extraction");
        return nullptr;
    }
    operation.release();
    return promise;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor entry {"extract", nullptr, Extract, nullptr, nullptr, nullptr, napi_default, nullptr};
    napi_define_properties(env, exports, 1, &entry);
    return exports;
}
napi_module module {1, 0, nullptr, Init, "koma_archive", nullptr, {0}};
}
extern "C" __attribute__((constructor)) void RegisterComicArchiveModule() { napi_module_register(&module); }

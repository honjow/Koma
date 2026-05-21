#include <napi/native_api.h>

#include <cstddef>
#include <string>

#include "wasm_runtime_adapter.h"

namespace {

constexpr const char *kModuleName = "koma_source_runtime";
constexpr const char *kSampleHello = "Koma native source runtime sample";

napi_value CreateUtf8(napi_env env, const std::string &value)
{
    napi_value result = nullptr;
    napi_create_string_utf8(env, value.c_str(), value.size(), &result);
    return result;
}

std::string GetStringArg(napi_env env, napi_value value)
{
    size_t length = 0;
    napi_get_value_string_utf8(env, value, nullptr, 0, &length);

    std::string result(length + 1, '\0');
    size_t copied = 0;
    napi_get_value_string_utf8(env, value, &result[0], result.size(), &copied);
    result.resize(copied);
    return result;
}

napi_value Hello(napi_env env, napi_callback_info info)
{
    (void)info;
    return CreateUtf8(env, kSampleHello);
}

napi_value Add(napi_env env, napi_callback_info info)
{
    size_t argc = 2;
    napi_value argv[2] = {nullptr, nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    double left = 0;
    double right = 0;
    if (argc > 0) {
        napi_get_value_double(env, argv[0], &left);
    }
    if (argc > 1) {
        napi_get_value_double(env, argv[1], &right);
    }

    napi_value result = nullptr;
    napi_create_double(env, left + right, &result);
    return result;
}

napi_value RunJsonCall(napi_env env, napi_callback_info info)
{
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);

    std::string requestJson;
    if (argc > 0) {
        requestJson = GetStringArg(env, argv[0]);
    }

    const std::string response = koma::RunBundledWasmJsonCall(requestJson);
    return CreateUtf8(env, response);
}

} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor descriptors[] = {
        {"hello", nullptr, Hello, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"add", nullptr, Add, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"runJsonCall", nullptr, RunJsonCall, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(descriptors) / sizeof(descriptors[0]), descriptors);
    return exports;
}
EXTERN_C_END

static napi_module sourceRuntimeModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = kModuleName,
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterKomaSourceRuntimeModule(void)
{
    napi_module_register(&sourceRuntimeModule);
}

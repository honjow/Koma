#include <memory>
#include <napi/native_api.h>
#include <native_vsync/native_vsync.h>

namespace {
using Receiver = std::unique_ptr<OH_NativeVSync, decltype(&OH_NativeVSync_Destroy)>;

void FinalizeReceiver(napi_env, void *data, void *)
{
    delete static_cast<Receiver *>(data);
}

napi_value Open(napi_env env, napi_callback_info)
{
    constexpr char name[] = "KomaReaderVolumeTurn";
    auto receiver = std::make_unique<Receiver>(OH_NativeVSync_Create(name, sizeof(name) - 1), OH_NativeVSync_Destroy);
    napi_value value = nullptr;
    if (*receiver && napi_create_external(env, receiver.get(), FinalizeReceiver, nullptr, &value) == napi_ok) {
        receiver.release();
    } else {
        napi_get_null(env, &value);
    }
    return value;
}

Receiver *ReadReceiver(napi_env env, napi_callback_info info, size_t count, napi_value *args)
{
    size_t actualCount = count;
    void *data = nullptr;
    if (napi_get_cb_info(env, info, &actualCount, args, nullptr, nullptr) != napi_ok || actualCount != count ||
        napi_get_value_external(env, args[0], &data) != napi_ok) {
        return nullptr;
    }
    return static_cast<Receiver *>(data);
}

napi_value SetRate(napi_env env, napi_callback_info info)
{
    napi_value args[2]{};
    auto receiver = ReadReceiver(env, info, 2, args);
    int32_t expected = 0;
    bool ok = false;
    if (receiver && *receiver && napi_get_value_int32(env, args[1], &expected) == napi_ok) {
        OH_NativeVSync_ExpectedRateRange range{0, expected, expected};
        ok = OH_NativeVSync_SetExpectedFrameRateRange(receiver->get(), &range) == 0;
    }
    napi_value value = nullptr;
    napi_get_boolean(env, ok, &value);
    return value;
}

void OnFrame(long long, void *)
{
    // The receiver only requests a timing signal. Swiper owns the content.
}

napi_value Request(napi_env env, napi_callback_info info)
{
    napi_value arg = nullptr;
    auto receiver = ReadReceiver(env, info, 1, &arg);
    bool ok = receiver && *receiver && OH_NativeVSync_RequestFrame(receiver->get(), OnFrame, nullptr) == 0;
    napi_value value = nullptr;
    napi_get_boolean(env, ok, &value);
    return value;
}

napi_value Close(napi_env env, napi_callback_info info)
{
    napi_value arg = nullptr;
    if (auto receiver = ReadReceiver(env, info, 1, &arg)) {
        receiver->reset();
    }
    napi_value value = nullptr;
    napi_get_undefined(env, &value);
    return value;
}

napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor entries[] = {
        {"open", nullptr, Open, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"setRate", nullptr, SetRate, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"request", nullptr, Request, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"close", nullptr, Close, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(entries) / sizeof(entries[0]), entries);
    return exports;
}

napi_module module{1, 0, nullptr, Init, "koma_reader_vsync", nullptr, {0}};
}

extern "C" __attribute__((constructor)) void RegisterReaderVSyncModule()
{
    napi_module_register(&module);
}

#include "wasm_runtime_adapter.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

#if defined(KOMA_ENABLE_WAMR)
#include "source_runtime_fixture_wasm.h"
#include "wasm_export.h"
#endif

#if __has_include(<hilog/log.h>)
#include <hilog/log.h>
#define KOMA_HAS_HILOG 1
#endif

namespace koma {
namespace {

constexpr uint32_t kKomaMagic = 0x4B4F4D41u;
constexpr uint32_t kRuntimeHeapBytes = 8u * 1024u * 1024u;
constexpr uint32_t kWasmStackBytes = 64u * 1024u;
constexpr uint32_t kWasmHeapBytes = 256u * 1024u;
constexpr uint32_t kMaxPayloadBytes = 1024u * 1024u;
constexpr uint32_t kMaxHostLogBytes = 1024u;
constexpr const char *kManifestJson =
    "{\"schemaVersion\":1,\"id\":\"local.example.private\","
    "\"runtime\":\"wasm-v1\",\"entry\":\"source_runtime_fixture.wasm\","
    "\"host\":{\"abi\":\"koma-host-v0.1\",\"imports\":[\"log\",\"check_cancel\"],"
    "\"limits\":{\"maxMemoryPages\":2,\"maxPayloadBytes\":1048576,\"network\":false}},"
    "\"contentPolicy\":{\"publicIndex\":false,\"marketplace\":false}}";

std::string EscapeJsonString(const std::string &value)
{
    std::string escaped;
    escaped.reserve(value.size() + 16);

    for (char ch : value) {
        const auto byte = static_cast<unsigned char>(ch);
        switch (ch) {
            case '\\':
                escaped += "\\\\";
                break;
            case '"':
                escaped += "\\\"";
                break;
            case '\b':
                escaped += "\\b";
                break;
            case '\f':
                escaped += "\\f";
                break;
            case '\n':
                escaped += "\\n";
                break;
            case '\r':
                escaped += "\\r";
                break;
            case '\t':
                escaped += "\\t";
                break;
            default:
                if (byte < 0x20) {
                    constexpr char kHex[] = "0123456789abcdef";
                    escaped += "\\u00";
                    escaped += kHex[(byte >> 4) & 0x0F];
                    escaped += kHex[byte & 0x0F];
                } else {
                    escaped += ch;
                }
                break;
        }
    }

    return escaped;
}

std::string ErrorJson(const std::string &code, const std::string &message)
{
    return std::string("{\"ok\":false,\"runtime\":\"wamr-unavailable\",\"error\":{\"code\":\"") +
        EscapeJsonString(code) + "\",\"message\":\"" + EscapeJsonString(message) + "\"},\"warnings\":[]}";
}

#if defined(KOMA_ENABLE_WAMR)

void HostLog(wasm_exec_env_t execEnv, int32_t level, char *message, uint32_t messageLen)
{
    (void)execEnv;
    const uint32_t safeLen = messageLen > kMaxHostLogBytes ? kMaxHostLogBytes : messageLen;
    std::string sanitized;
    sanitized.reserve(safeLen);
    for (uint32_t i = 0; i < safeLen; i++) {
        const char ch = message[i];
        sanitized += (ch >= 0x20 && ch <= 0x7e) ? ch : '?';
    }

#if defined(KOMA_HAS_HILOG)
    OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaSourceRuntime",
        "HOST_LOG level=%{public}d len=%{public}u message=%{public}s",
        level, messageLen, sanitized.c_str());
#else
    std::fprintf(stderr, "KomaSourceRuntime HOST_LOG level=%d len=%u message=%s\n",
        level, messageLen, sanitized.c_str());
#endif
}

int32_t HostCheckCancel(wasm_exec_env_t execEnv)
{
    (void)execEnv;
#if defined(KOMA_HAS_HILOG)
    OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaSourceRuntime", "HOST_CHECK_CANCEL result=0");
#else
    std::fprintf(stderr, "KomaSourceRuntime HOST_CHECK_CANCEL result=0\n");
#endif
    return 0;
}

NativeSymbol g_komaHostSymbols[] = {
    {"log", reinterpret_cast<void *>(HostLog), "(i*~)", nullptr},
    {"check_cancel", reinterpret_cast<void *>(HostCheckCancel), "()i", nullptr},
};

uint32_t ReadLeU32(const uint8_t *p)
{
    return static_cast<uint32_t>(p[0]) |
        (static_cast<uint32_t>(p[1]) << 8u) |
        (static_cast<uint32_t>(p[2]) << 16u) |
        (static_cast<uint32_t>(p[3]) << 24u);
}

void RequireCall(wasm_exec_env_t execEnv,
    wasm_module_inst_t moduleInst,
    wasm_function_inst_t fn,
    uint32_t argc,
    uint32_t argv[],
    const char *name)
{
    if (!wasm_runtime_call_wasm(execEnv, fn, argc, argv)) {
        const char *exception = wasm_runtime_get_exception(moduleInst);
        throw std::runtime_error(std::string("wasm call failed: ") + name + ": " +
            (exception ? exception : "unknown exception"));
    }
}

bool JsonEnvelopeIsPlausible(const std::string &payload)
{
    if (payload.empty() || payload.front() != '{' || payload.back() != '}') {
        return false;
    }

    int depth = 0;
    bool inString = false;
    bool escaped = false;
    for (char ch : payload) {
        if (inString) {
            if (escaped) {
                escaped = false;
            } else if (ch == '\\') {
                escaped = true;
            } else if (ch == '"') {
                inString = false;
            }
            continue;
        }

        if (ch == '"') {
            inString = true;
        } else if (ch == '{' || ch == '[') {
            depth++;
        } else if (ch == '}' || ch == ']') {
            depth--;
            if (depth < 0) {
                return false;
            }
        }
    }

    return depth == 0 && !inString && payload.find("\"ok\":") != std::string::npos;
}

class Runtime {
public:
    Runtime() : heap_(kRuntimeHeapBytes)
    {
        RuntimeInitArgs initArgs;
        std::memset(&initArgs, 0, sizeof(initArgs));
        initArgs.mem_alloc_type = Alloc_With_Pool;
        initArgs.mem_alloc_option.pool.heap_buf = heap_.data();
        initArgs.mem_alloc_option.pool.heap_size = static_cast<uint32_t>(heap_.size());
        initArgs.native_module_name = "koma_host";
        initArgs.native_symbols = g_komaHostSymbols;
        initArgs.n_native_symbols = static_cast<uint32_t>(sizeof(g_komaHostSymbols) / sizeof(g_komaHostSymbols[0]));

        if (!wasm_runtime_full_init(&initArgs)) {
            throw std::runtime_error("wasm_runtime_full_init failed");
        }
        initialized_ = true;
    }

    ~Runtime()
    {
        if (initialized_) {
            wasm_runtime_destroy();
        }
    }

    Runtime(const Runtime &) = delete;
    Runtime &operator=(const Runtime &) = delete;

private:
    std::vector<uint8_t> heap_;
    bool initialized_ = false;
};

class ThreadEnv {
public:
    ThreadEnv()
    {
        if (!wasm_runtime_init_thread_env()) {
            throw std::runtime_error("wasm_runtime_init_thread_env failed");
        }
        initialized_ = true;
    }

    ~ThreadEnv()
    {
        if (initialized_) {
            wasm_runtime_destroy_thread_env();
        }
    }

    ThreadEnv(const ThreadEnv &) = delete;
    ThreadEnv &operator=(const ThreadEnv &) = delete;

private:
    bool initialized_ = false;
};

class Module {
public:
    Module() : wasmBytes_(kSourceRuntimeFixtureWasm, kSourceRuntimeFixtureWasm + kSourceRuntimeFixtureWasmLen)
    {
        char errorBuf[256] = {0};
        module_ = wasm_runtime_load(
            wasmBytes_.data(),
            static_cast<uint32_t>(wasmBytes_.size()),
            errorBuf,
            sizeof(errorBuf));
        if (!module_) {
            throw std::runtime_error(std::string("wasm_runtime_load failed: ") + errorBuf);
        }

        moduleInst_ = wasm_runtime_instantiate(module_, kWasmStackBytes, kWasmHeapBytes, errorBuf, sizeof(errorBuf));
        if (!moduleInst_) {
            throw std::runtime_error(std::string("wasm_runtime_instantiate failed: ") + errorBuf);
        }

        execEnv_ = wasm_runtime_create_exec_env(moduleInst_, kWasmStackBytes);
        if (!execEnv_) {
            throw std::runtime_error("wasm_runtime_create_exec_env failed");
        }
    }

    ~Module()
    {
        if (execEnv_) {
            wasm_runtime_destroy_exec_env(execEnv_);
        }
        if (moduleInst_) {
            wasm_runtime_deinstantiate(moduleInst_);
        }
        if (module_) {
            wasm_runtime_unload(module_);
        }
    }

    Module(const Module &) = delete;
    Module &operator=(const Module &) = delete;

    std::string RunSearch(const std::string &requestJson)
    {
        ValidateAdd();
        InitWithManifest();

        const uint32_t requestLen = static_cast<uint32_t>(requestJson.size());
        uint64_t requestPtr = wasm_runtime_module_dup_data(moduleInst_, requestJson.data(), requestLen);
        if (requestPtr == 0) {
            throw std::runtime_error("failed to copy request into wasm memory");
        }

        wasm_function_inst_t search = Lookup("koma_source_search");
        uint32_t argv[2] = {static_cast<uint32_t>(requestPtr), requestLen};
        try {
            RequireCall(execEnv_, moduleInst_, search, 2, argv, "koma_source_search");
        } catch (...) {
            wasm_runtime_module_free(moduleInst_, requestPtr);
            throw;
        }
        wasm_runtime_module_free(moduleInst_, requestPtr);

        return ReadEnvelope(argv[0]);
    }

private:
    wasm_function_inst_t Lookup(const char *name)
    {
        wasm_function_inst_t fn = wasm_runtime_lookup_function(moduleInst_, name);
        if (!fn) {
            throw std::runtime_error(std::string("missing export: ") + name);
        }
        return fn;
    }

    void ValidateAdd()
    {
        wasm_function_inst_t add = Lookup("add");
        uint32_t argv[2] = {2, 3};
        RequireCall(execEnv_, moduleInst_, add, 2, argv, "add");
        if (argv[0] != 5) {
            throw std::runtime_error("add(2,3) returned " + std::to_string(argv[0]));
        }
    }

    void InitWithManifest()
    {
        const uint32_t manifestLen = static_cast<uint32_t>(std::strlen(kManifestJson));
        uint64_t manifestPtr = wasm_runtime_module_dup_data(moduleInst_, kManifestJson, manifestLen);
        if (manifestPtr == 0) {
            throw std::runtime_error("failed to copy manifest into wasm memory");
        }

        wasm_function_inst_t init = Lookup("koma_source_init");
        uint32_t argv[2] = {static_cast<uint32_t>(manifestPtr), manifestLen};
        try {
            RequireCall(execEnv_, moduleInst_, init, 2, argv, "koma_source_init");
        } catch (...) {
            wasm_runtime_module_free(moduleInst_, manifestPtr);
            throw;
        }
        wasm_runtime_module_free(moduleInst_, manifestPtr);

        if (static_cast<int32_t>(argv[0]) != 0) {
            throw std::runtime_error("koma_source_init returned " + std::to_string(argv[0]));
        }
    }

    std::string ReadEnvelope(uint32_t resultPtr)
    {
        if (resultPtr == 0) {
            throw std::runtime_error("koma_source_search returned null result pointer");
        }
        if (!wasm_runtime_validate_app_addr(moduleInst_, resultPtr, 16)) {
            throw std::runtime_error("result header is outside wasm memory");
        }

        const uint8_t *header = static_cast<const uint8_t *>(wasm_runtime_addr_app_to_native(moduleInst_, resultPtr));
        const uint32_t magic = ReadLeU32(header);
        const uint32_t flags = ReadLeU32(header + 4);
        const uint32_t len = ReadLeU32(header + 8);
        const uint32_t reserved = ReadLeU32(header + 12);

        if (magic != kKomaMagic) {
            throw std::runtime_error("bad result magic");
        }
        if ((flags & ~1u) != 0) {
            throw std::runtime_error("unexpected result flags " + std::to_string(flags));
        }
        if (reserved != 0) {
            throw std::runtime_error("reserved result header field is non-zero");
        }
        if (len == 0 || len > kMaxPayloadBytes) {
            throw std::runtime_error("unexpected payload length " + std::to_string(len));
        }
        if (!wasm_runtime_validate_app_addr(moduleInst_, resultPtr + 16u, len)) {
            throw std::runtime_error("result payload is outside wasm memory");
        }

        const char *payloadNative = static_cast<const char *>(wasm_runtime_addr_app_to_native(moduleInst_, resultPtr + 16u));
        std::string payload(payloadNative, payloadNative + len);
        if (!JsonEnvelopeIsPlausible(payload)) {
            throw std::runtime_error("result payload is not plausible JSON envelope");
        }

        wasm_function_inst_t freeFn = Lookup("koma_source_free");
        uint32_t freeArgv[1] = {resultPtr};
        RequireCall(execEnv_, moduleInst_, freeFn, 1, freeArgv, "koma_source_free");

        return payload;
    }

    wasm_module_t module_ = nullptr;
    wasm_module_inst_t moduleInst_ = nullptr;
    wasm_exec_env_t execEnv_ = nullptr;
    std::vector<uint8_t> wasmBytes_;
};

#endif

} // namespace

std::string RunBundledWasmJsonCall(const std::string &requestJson)
{
#if defined(KOMA_ENABLE_WAMR)
    try {
        Runtime runtime;
        ThreadEnv threadEnv;
        Module module;
        return module.RunSearch(requestJson);
    } catch (const std::exception &err) {
        return ErrorJson("WAMR_RUNTIME_ERROR", err.what());
    }
#else
    (void)requestJson;
    return ErrorJson("WAMR_NOT_BUILT", "native module was built without WAMR_ROOT_DIR");
#endif
}

} // namespace koma

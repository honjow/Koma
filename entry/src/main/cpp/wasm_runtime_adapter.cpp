#include "wasm_runtime_adapter.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#include "html_host.h"
#include "http_host.h"

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
constexpr uint32_t kMaxFixtureWasmBytes = 1024u * 1024u;
constexpr const char *kTestCancelGuard = "\"testGuard\":\"cancel\"";
constexpr const char *kTestTimeoutGuard = "\"testGuard\":\"timeout\"";
// WAMR runtime initialization and native-import registration are process
// global. Reader page preloading can request several source image tickets at
// once, so every execution must span init through teardown under one lock.
std::mutex g_wamrExecutionMu;
constexpr const char *kManifestJson =
    "{\"schemaVersion\":1,\"id\":\"local.example.private\","
    "\"runtime\":\"wasm-v1\",\"entry\":\"source_runtime_fixture.wasm\","
    "\"host\":{\"abi\":\"koma-host-v0.1\",\"imports\":[\"log\",\"check_cancel\","
    "\"http_request\",\"html_parse\",\"html_select\",\"html_select_all\",\"html_attr\",\"html_text\",\"html_close\"],"
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

std::string RuntimeReasonCode(const std::string &message)
{
    if (message.find("request JSON exceeds operation dispatch boundary") != std::string::npos) {
        return "request_too_large";
    }
    if (message.find("unexpected payload length") != std::string::npos) {
        return "result_too_large";
    }
    if (message.find("result payload is not plausible JSON envelope") != std::string::npos ||
        message.find("bad result magic") != std::string::npos ||
        message.find("unexpected result flags") != std::string::npos ||
        message.find("reserved result header field") != std::string::npos ||
        message.find("result header is outside wasm memory") != std::string::npos ||
        message.find("result payload is outside wasm memory") != std::string::npos) {
        return "malformed_result";
    }
    return "runtime_error";
}

std::string ErrorJson(const std::string &code, const std::string &message, const std::string &reasonCode)
{
    return std::string("{\"ok\":false,\"runtime\":\"wamr-unavailable\",\"error\":{\"code\":\"") +
        EscapeJsonString(code) + "\",\"message\":\"" + EscapeJsonString(message) +
        "\"},\"reasonCode\":\"" + EscapeJsonString(reasonCode) + "\",\"warnings\":[]}";
}

std::string RuntimeErrorJson(const std::string &message)
{
    return ErrorJson("WAMR_RUNTIME_ERROR", "source runtime call rejected", RuntimeReasonCode(message));
}

bool HasTestOnlyGuard(const std::string &requestJson, const char *guard)
{
    return requestJson.find("\"komaTestOnly\":true") != std::string::npos &&
        requestJson.find(guard) != std::string::npos;
}

#if defined(KOMA_ENABLE_WAMR)

bool g_forceCancelForCurrentCall = false;

class ForcedCancelScope {
public:
    explicit ForcedCancelScope(bool enabled) : previous_(g_forceCancelForCurrentCall)
    {
        g_forceCancelForCurrentCall = enabled;
    }

    ~ForcedCancelScope()
    {
        g_forceCancelForCurrentCall = previous_;
    }

    ForcedCancelScope(const ForcedCancelScope &) = delete;
    ForcedCancelScope &operator=(const ForcedCancelScope &) = delete;

private:
    bool previous_;
};

std::vector<uint8_t> LoadWasmBytesFromBundledFixture()
{
    return std::vector<uint8_t>(kSourceRuntimeFixtureWasm, kSourceRuntimeFixtureWasm + kSourceRuntimeFixtureWasmLen);
}

std::vector<uint8_t> LoadWasmBytesFromExternalBytes(const std::vector<uint8_t> &wasmBytes)
{
    if (wasmBytes.size() < 8) {
        throw std::runtime_error("fixture wasm bytes are too short");
    }
    if (wasmBytes.size() > kMaxFixtureWasmBytes) {
        throw std::runtime_error("fixture wasm bytes exceed test boundary limit");
    }
    if (wasmBytes[0] != 0x00 || wasmBytes[1] != 0x61 || wasmBytes[2] != 0x73 || wasmBytes[3] != 0x6d) {
        throw std::runtime_error("fixture wasm bytes are missing wasm magic");
    }
    if (wasmBytes[4] != 0x01 || wasmBytes[5] != 0x00 || wasmBytes[6] != 0x00 || wasmBytes[7] != 0x00) {
        throw std::runtime_error("fixture wasm bytes are not wasm version 1");
    }
    return wasmBytes;
}

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
    const int32_t result = g_forceCancelForCurrentCall ? 1 : 0;
#if defined(KOMA_HAS_HILOG)
    OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaSourceRuntime", "HOST_CHECK_CANCEL result=%{public}d", result);
#else
    std::fprintf(stderr, "KomaSourceRuntime HOST_CHECK_CANCEL result=%d\n", result);
#endif
    return result;
}

int32_t HostHttpRequest(wasm_exec_env_t execEnv, char *request, uint32_t requestLen, char *out, uint32_t outCap)
{
    (void)execEnv;
    return koma::http::HostRequest(request, requestLen, out, outCap);
}

int32_t HostHtmlParse(wasm_exec_env_t execEnv, char *html, uint32_t htmlLen)
{
    (void)execEnv;
    return koma::html::Parse(html, htmlLen);
}

int32_t HostHtmlSelect(wasm_exec_env_t execEnv, int32_t descriptor, char *selector, uint32_t selectorLen)
{
    (void)execEnv;
    return koma::html::Select(descriptor, selector, selectorLen);
}

int32_t HostHtmlSelectAll(wasm_exec_env_t execEnv, int32_t descriptor, char *selector, uint32_t selectorLen, char *out, uint32_t outCap)
{
    (void)execEnv;
    return koma::html::SelectAll(descriptor, selector, selectorLen, out, outCap);
}

int32_t HostHtmlAttr(wasm_exec_env_t execEnv,
    int32_t descriptor,
    char *attr,
    uint32_t attrLen,
    char *out,
    uint32_t outCap)
{
    (void)execEnv;
    return koma::html::Attr(descriptor, attr, attrLen, out, outCap);
}

int32_t HostHtmlText(wasm_exec_env_t execEnv, int32_t descriptor, char *out, uint32_t outCap)
{
    (void)execEnv;
    return koma::html::Text(descriptor, out, outCap);
}

int32_t HostHtmlClose(wasm_exec_env_t execEnv, int32_t descriptor)
{
    (void)execEnv;
    return koma::html::Close(descriptor);
}

NativeSymbol g_komaHostSymbols[] = {
    {"log", reinterpret_cast<void *>(HostLog), "(i*~)", nullptr},
    {"check_cancel", reinterpret_cast<void *>(HostCheckCancel), "()i", nullptr},
    {"http_request", reinterpret_cast<void *>(HostHttpRequest), "(*~*~)i", nullptr},
    {"html_parse", reinterpret_cast<void *>(HostHtmlParse), "(*~)i", nullptr},
    {"html_select", reinterpret_cast<void *>(HostHtmlSelect), "(i*~)i", nullptr},
    {"html_select_all", reinterpret_cast<void *>(HostHtmlSelectAll), "(i*~*~)i", nullptr},
    {"html_attr", reinterpret_cast<void *>(HostHtmlAttr), "(i*~*~)i", nullptr},
    {"html_text", reinterpret_cast<void *>(HostHtmlText), "(i*~)i", nullptr},
    {"html_close", reinterpret_cast<void *>(HostHtmlClose), "(i)i", nullptr},
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

std::string ExtractOperation(const std::string &requestJson)
{
    if (requestJson.size() > kMaxPayloadBytes) {
        throw std::runtime_error("request JSON exceeds operation dispatch boundary");
    }

    const std::string key = "\"operation\"";
    size_t pos = requestJson.find(key);
    if (pos == std::string::npos) {
        throw std::runtime_error("missing operation");
    }
    pos += key.size();
    while (pos < requestJson.size() && (requestJson[pos] == ' ' || requestJson[pos] == '\n' ||
        requestJson[pos] == '\r' || requestJson[pos] == '\t')) {
        pos++;
    }
    if (pos >= requestJson.size() || requestJson[pos] != ':') {
        throw std::runtime_error("invalid operation field");
    }
    pos++;
    while (pos < requestJson.size() && (requestJson[pos] == ' ' || requestJson[pos] == '\n' ||
        requestJson[pos] == '\r' || requestJson[pos] == '\t')) {
        pos++;
    }
    if (pos >= requestJson.size() || requestJson[pos] != '"') {
        throw std::runtime_error("operation must be a string");
    }
    pos++;

    std::string operation;
    while (pos < requestJson.size()) {
        const char ch = requestJson[pos++];
        if (ch == '\\') {
            throw std::runtime_error("escaped operation values are not supported");
        }
        if (ch == '"') {
            if (operation == "source_info" || operation == "search" ||
                operation == "get_manga" || operation == "get_chapters" ||
                operation == "get_pages" || operation == "get_listings" ||
                operation == "get_manga_list" || operation == "get_home" ||
                operation == "get_filters" || operation == "get_settings" ||
                operation == "get_image_request" ||
                operation == "test_oversized_result" ||
                operation == "test_malformed_result") {
                return operation;
            }
            throw std::runtime_error("unsupported operation: " + operation);
        }
        if (operation.size() >= 32) {
            throw std::runtime_error("operation value is too long");
        }
        operation += ch;
    }

    throw std::runtime_error("unterminated operation string");
}

const char *ExportForOperation(const std::string &operation)
{
    if (operation == "source_info") {
        return "koma_source_info";
    }
    if (operation == "search") {
        return "koma_source_search";
    }
    if (operation == "get_manga") {
        return "koma_source_get_manga";
    }
    if (operation == "get_chapters") {
        return "koma_source_get_chapters";
    }
    if (operation == "get_pages") {
        return "koma_source_get_pages";
    }
    if (operation == "get_listings") {
        return "koma_source_get_listings";
    }
    if (operation == "get_manga_list") {
        return "koma_source_get_manga_list";
    }
    if (operation == "get_home") {
        return "koma_source_get_home";
    }
    if (operation == "get_filters") {
        return "koma_source_get_filters";
    }
    if (operation == "get_settings") {
        return "koma_source_get_settings";
    }
    if (operation == "get_image_request") {
        return "koma_source_get_image_request";
    }
    if (operation == "test_oversized_result") {
        return "koma_test_oversized_result";
    }
    if (operation == "test_malformed_result") {
        return "koma_test_malformed_result";
    }
    throw std::runtime_error("unsupported operation: " + operation);
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
    explicit Module(std::vector<uint8_t> wasmBytes) : wasmBytes_(std::move(wasmBytes))
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

    std::string RunOperation(const std::string &requestJson)
    {
        ValidateAdd();
        InitWithManifest();

        const std::string operation = ExtractOperation(requestJson);
        const char *exportName = ExportForOperation(operation);
        const bool forceCancel = HasTestOnlyGuard(requestJson, kTestCancelGuard);
        if (operation == "source_info" ||
            operation == "test_oversized_result" ||
            operation == "test_malformed_result") {
            ForcedCancelScope cancelScope(forceCancel);
            wasm_function_inst_t operationFn = Lookup(exportName);
            uint32_t argv[1] = {0};
            RequireCall(execEnv_, moduleInst_, operationFn, 0, argv, exportName);
            return ReadEnvelope(argv[0], exportName);
        }

        const uint32_t requestLen = static_cast<uint32_t>(requestJson.size());
        uint64_t requestPtr = wasm_runtime_module_dup_data(moduleInst_, requestJson.data(), requestLen);
        if (requestPtr == 0) {
            throw std::runtime_error("failed to copy request into wasm memory");
        }

        wasm_function_inst_t operationFn = Lookup(exportName);
        uint32_t argv[2] = {static_cast<uint32_t>(requestPtr), requestLen};
        try {
            ForcedCancelScope cancelScope(forceCancel);
            RequireCall(execEnv_, moduleInst_, operationFn, 2, argv, exportName);
        } catch (...) {
            wasm_runtime_module_free(moduleInst_, requestPtr);
            throw;
        }
        wasm_runtime_module_free(moduleInst_, requestPtr);

        return ReadEnvelope(argv[0], exportName);
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
        wasm_function_inst_t add = wasm_runtime_lookup_function(moduleInst_, "add");
        if (!add) {
            return;  // real source modules may not export add; skip fixture validation
        }
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

    std::string ReadEnvelope(uint32_t resultPtr, const char *exportName)
    {
        if (resultPtr == 0) {
            throw std::runtime_error(std::string(exportName) + " returned null result pointer");
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
        std::lock_guard<std::mutex> lock(g_wamrExecutionMu);
        Runtime runtime;
        ThreadEnv threadEnv;
        Module module(LoadWasmBytesFromBundledFixture());
        std::string response = module.RunOperation(requestJson);
#if defined(KOMA_HAS_HILOG)
        OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaSourceRuntime", "[SourceRuntime] step=wasm_smoke_ok route=bundled");
#endif
        return response;
    } catch (const std::exception &err) {
        return RuntimeErrorJson(err.what());
    }
#else
    (void)requestJson;
    return ErrorJson("WAMR_NOT_BUILT", "native module was built without WAMR_ROOT_DIR", "wamr_not_built");
#endif
}

std::string RunWasmJsonCallFromBytes(const std::string &requestJson, const std::vector<uint8_t> &wasmBytes)
{
#if defined(KOMA_ENABLE_WAMR)
    try {
        if (HasTestOnlyGuard(requestJson, kTestTimeoutGuard)) {
            return ErrorJson("WAMR_RUNTIME_TIMEOUT", "source runtime call timed out", "timeout");
        }
        std::lock_guard<std::mutex> lock(g_wamrExecutionMu);
        Runtime runtime;
        ThreadEnv threadEnv;
        Module module(LoadWasmBytesFromExternalBytes(wasmBytes));
        std::string response = module.RunOperation(requestJson);
#if defined(KOMA_HAS_HILOG)
        OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaSourceRuntime", "[SourceRuntime] step=wasm_smoke_ok route=bytes wasmBytes=%{public}zu",
            wasmBytes.size());
#endif
        return response;
    } catch (const std::exception &err) {
#if defined(KOMA_HAS_HILOG)
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0x0, "KomaSourceRuntime",
            "RunWasmJsonCallFromBytes exception: %{public}s", err.what());
#endif
        return RuntimeErrorJson(err.what());
    }
#else
    (void)requestJson;
    (void)wasmBytes;
    return ErrorJson("WAMR_NOT_BUILT", "native module was built without WAMR_ROOT_DIR", "wamr_not_built");
#endif
}

} // namespace koma

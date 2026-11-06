#include "wasm_runtime_adapter.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <condition_variable>
#include <chrono>
#include <memory>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <thread>
#include <unordered_set>
#include <utility>
#include <vector>
#include <time.h>
#include <unistd.h>

#include "html_host.h"
#include "http_host.h"
#include "image_processor_host.h"

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
// Independent calls share one runtime and allocator. Size the shared pool at
// the old 8 MiB single-call budget times the limit; it is not partitioned.
constexpr uint32_t kMaxConcurrentSourceCalls = 4;
// Preserve four source slots; two image workers have their own admission and
// module budgets rather than waiting behind source HTTP requests.
constexpr uint32_t kMaxConcurrentImageCalls = 2;
constexpr uint32_t kMaxConcurrentLocalCoverCalls = 2;
constexpr uint32_t kRuntimeHeapBytes =
    (kMaxConcurrentSourceCalls + kMaxConcurrentImageCalls + kMaxConcurrentLocalCoverCalls) * 8u * 1024u * 1024u;
constexpr uint32_t kWasmStackBytes = 64u * 1024u;
constexpr uint32_t kWasmHeapBytes = 256u * 1024u;
constexpr uint32_t kMaxPayloadBytes = 1024u * 1024u;
constexpr uint32_t kMaxHostLogBytes = 1024u;
constexpr uint32_t kMaxFixtureWasmBytes = 1024u * 1024u;
constexpr const char *kTestCancelGuard = "\"testGuard\":\"cancel\"";
constexpr const char *kTestTimeoutGuard = "\"testGuard\":\"timeout\"";
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
    if (message.find("wasm_runtime_load failed") != std::string::npos) return "wasm_load_failed";
    if (message.find("wasm_runtime_instantiate failed") != std::string::npos) return "wasm_instantiate_failed";
    if (message.find("wasm_runtime_full_init failed") != std::string::npos ||
        message.find("wasm_runtime_init_thread_env failed") != std::string::npos ||
        message.find("wasm_runtime_create_exec_env failed") != std::string::npos) return "wasm_environment_failed";
    if (message.find("missing export:") != std::string::npos) return "missing_export";
    if (message.find("wasm call failed:") != std::string::npos) return "wasm_call_failed";
    if (message.find("koma_source_init returned") != std::string::npos) return "source_init_failed";
    if (message.find("unsupported operation:") != std::string::npos) return "unsupported_operation";
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

thread_local bool g_forceCancelForCurrentCall = false;

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

struct CoverLog {
    int32_t level;
    uint32_t originalLength;
    std::string message;
};

struct LocalCoverProbe {
    bool needsOrdinaryCall = false;
    std::vector<CoverLog> logs;
};

// WASM start can reach imports before its exec-env has an HTTP context.
thread_local LocalCoverProbe *g_localCoverProbe = nullptr;

bool RequireOrdinarySourceCall(wasm_exec_env_t execEnv)
{
    if (!g_localCoverProbe) return false;
    g_localCoverProbe->needsOrdinaryCall = true;
    wasm_runtime_set_exception(wasm_runtime_get_module_inst(execEnv), "cover requires ordinary source call");
    return true;
}

void WriteHostLog(int32_t level, uint32_t messageLen, const std::string &sanitized)
{
#if defined(KOMA_HAS_HILOG)
    OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaSourceRuntime",
        "HOST_LOG level=%{public}d len=%{public}u message=%{public}s",
        level, messageLen, sanitized.c_str());
#else
    std::fprintf(stderr, "KomaSourceRuntime HOST_LOG level=%d len=%u message=%s\n",
        level, messageLen, sanitized.c_str());
#endif
}

void HostLog(wasm_exec_env_t execEnv, int32_t level, char *message, uint32_t messageLen)
{
    (void)execEnv;
    constexpr size_t kMaxCoverProbeLogs = 8;
    if (g_localCoverProbe && g_localCoverProbe->logs.size() >= kMaxCoverProbeLogs) return;
    const uint32_t safeLen = messageLen > kMaxHostLogBytes ? kMaxHostLogBytes : messageLen;
    std::string sanitized;
    sanitized.reserve(safeLen);
    for (uint32_t i = 0; i < safeLen; i++) {
        const char ch = message[i];
        sanitized += (ch >= 0x20 && ch <= 0x7e) ? ch : '?';
    }

    if (g_localCoverProbe) {
        g_localCoverProbe->logs.push_back({level, messageLen, std::move(sanitized)});
    } else {
        WriteHostLog(level, messageLen, sanitized);
    }
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
    if (RequireOrdinarySourceCall(execEnv)) return -1;
    const auto *context = static_cast<const std::string *>(wasm_runtime_get_user_data(execEnv));
    return koma::http::HostRequest(request, requestLen, out, outCap, context ? *context : "");
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

int32_t HostUnixTimeMs(wasm_exec_env_t execEnv, char *out, uint32_t outCap)
{
    if (RequireOrdinarySourceCall(execEnv)) return -1;
    auto moduleInst = wasm_runtime_get_module_inst(execEnv);
    if (out == nullptr || outCap != 8 ||
        !wasm_runtime_validate_native_addr(moduleInst, out, 8)) return -1;
    timespec ts {};
    if (clock_gettime(CLOCK_REALTIME, &ts) != 0 || ts.tv_sec < 0 ||
        ts.tv_nsec < 0 || ts.tv_nsec >= 1000000000 ||
        static_cast<uint64_t>(ts.tv_sec) > (UINT64_MAX - 999u) / 1000u) return -2;
    const uint64_t ms = static_cast<uint64_t>(ts.tv_sec) * 1000u +
        static_cast<uint64_t>(ts.tv_nsec) / 1000000u;
    if (ms == 0) return -2;
    for (uint32_t i = 0; i < 8; ++i) out[i] = static_cast<char>(ms >> (8u * i));
    return 8;
}

int32_t HostRandomBytes(wasm_exec_env_t execEnv, char *out, uint32_t outCap)
{
    if (RequireOrdinarySourceCall(execEnv)) return -1;
    auto moduleInst = wasm_runtime_get_module_inst(execEnv);
    if (out == nullptr || outCap == 0 || outCap > 256 ||
        !wasm_runtime_validate_native_addr(moduleInst, out, outCap)) return -1;
    // POSIX interface declared by the current installed Harmony native SDK.
    // OS entropy failure is explicit; never fallback to a seed, clock or rand().
    uint8_t local[256] {};
    if (getentropy(local, outCap) != 0) return -2;
    std::memcpy(out, local, outCap);
    return static_cast<int32_t>(outCap);
}


NativeSymbol g_komaHostSymbols[] = {
    {"unix_time_ms", reinterpret_cast<void *>(HostUnixTimeMs), "(*~)i", nullptr},
    {"random_bytes", reinterpret_cast<void *>(HostRandomBytes), "(*~)i", nullptr},
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
                operation == "get_authentication" || operation == "authenticate" || operation == "logout" ||
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
    if (operation == "get_authentication") {
        return "koma_source_get_authentication";
    }
    if (operation == "authenticate") {
        return "koma_source_authenticate";
    }
    if (operation == "logout") {
        return "koma_source_logout";
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
        if (!RegisterImageProcessorImports()) {
            wasm_runtime_destroy();
            throw std::runtime_error("image processor imports registration failed");
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

// WAMR initialization and its allocator are process-global. Keep them alive
// across a burst of calls, with only one pool and a bounded idle lifetime.
std::mutex g_runtimeLifetimeMu;
std::condition_variable g_runtimeSlotAvailable;
std::unique_ptr<Runtime> g_runtime;
uint32_t g_runtimeUsers = 0;
uint32_t g_imageRuntimeUsers = 0;
uint32_t g_localCoverRuntimeUsers = 0;
std::unordered_set<std::string> g_activeSources;
bool g_unidentifiedSourceActive = false;

class RuntimeIdleReaper {
public:
    static RuntimeIdleReaper &Get()
    {
        static RuntimeIdleReaper reaper;
        return reaper;
    }

    void KeepWarmLocked()
    {
        deadline_ = Clock::now() + std::chrono::seconds(2);
        changed_.notify_one();
    }

    void CancelLocked()
    {
        deadline_.reset();
        changed_.notify_one();
    }

private:
    using Clock = std::chrono::steady_clock;

    RuntimeIdleReaper() : worker_([this] { Reap(); }) {}

    ~RuntimeIdleReaper()
    {
        {
            std::lock_guard<std::mutex> lock(g_runtimeLifetimeMu);
            stopping_ = true;
        }
        changed_.notify_one();
        worker_.join();
    }

    void Reap()
    {
        std::unique_lock<std::mutex> lock(g_runtimeLifetimeMu);
        while (!stopping_) {
            if (!deadline_) {
                changed_.wait(lock, [this] { return stopping_ || deadline_.has_value(); });
                continue;
            }
            const auto deadline = *deadline_;
            if (!changed_.wait_until(lock, deadline, [this, deadline] {
                    return stopping_ || deadline_ != deadline;
                })) {
                if (g_runtimeUsers == 0) g_runtime.reset();
                deadline_.reset();
            }
        }
    }

    bool stopping_ = false;
    std::optional<Clock::time_point> deadline_;
    std::condition_variable changed_;
    std::thread worker_;
};

enum class RuntimeLane { Source, ImagePlugin, LocalCover };

class RuntimeLease {
public:
    explicit RuntimeLease(const std::string &sourceId = "", RuntimeLane lane = RuntimeLane::Source) :
        sourceId_(sourceId), lane_(lane)
    {
        std::unique_lock<std::mutex> lock(g_runtimeLifetimeMu);
        // Preserve per-source serialization, including HTTP wait time. An
        // unidentified call has no safe key, so it remains process-exclusive.
        g_runtimeSlotAvailable.wait(lock, [this] {
            if (lane_ == RuntimeLane::ImagePlugin) {
                return !g_unidentifiedSourceActive && g_imageRuntimeUsers < kMaxConcurrentImageCalls;
            }
            if (lane_ == RuntimeLane::LocalCover) {
                return !g_unidentifiedSourceActive && g_localCoverRuntimeUsers < kMaxConcurrentLocalCoverCalls;
            }
            if (sourceId_.empty()) return g_runtimeUsers == 0;
            return !g_unidentifiedSourceActive && g_activeSources.size() < kMaxConcurrentSourceCalls &&
                g_activeSources.find(sourceId_) == g_activeSources.end();
        });
        try {
            if (lane_ == RuntimeLane::ImagePlugin) ++g_imageRuntimeUsers;
            else if (lane_ == RuntimeLane::LocalCover) ++g_localCoverRuntimeUsers;
            else if (sourceId_.empty()) g_unidentifiedSourceActive = true;
            else g_activeSources.insert(sourceId_);
            if (!g_runtime) {
                g_runtime = std::make_unique<Runtime>();
            } else if (g_runtimeUsers == 0) {
                RuntimeIdleReaper::Get().CancelLocked();
            }
            ++g_runtimeUsers;
        } catch (...) {
            ReleaseSlot();
            lock.unlock();
            g_runtimeSlotAvailable.notify_all();
            throw;
        }
    }

    ~RuntimeLease()
    {
        {
            std::lock_guard<std::mutex> lock(g_runtimeLifetimeMu);
            ReleaseSlot();
            if (--g_runtimeUsers == 0) {
                try {
                    RuntimeIdleReaper::Get().KeepWarmLocked();
                } catch (...) {
                    g_runtime.reset();
                }
            }
        }
        // A same-source waiter may be ineligible while another source is free.
        g_runtimeSlotAvailable.notify_all();
    }

    RuntimeLease(const RuntimeLease &) = delete;
    RuntimeLease &operator=(const RuntimeLease &) = delete;

private:
    void ReleaseSlot()
    {
        if (lane_ == RuntimeLane::ImagePlugin) --g_imageRuntimeUsers;
        else if (lane_ == RuntimeLane::LocalCover) --g_localCoverRuntimeUsers;
        else if (sourceId_.empty()) g_unidentifiedSourceActive = false;
        else g_activeSources.erase(sourceId_);
    }

    std::string sourceId_;
    RuntimeLane lane_;
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

class HtmlScope {
public:
    HtmlScope() { koma::html::Init(); }
    ~HtmlScope() { koma::html::Shutdown(); }

    HtmlScope(const HtmlScope &) = delete;
    HtmlScope &operator=(const HtmlScope &) = delete;
};

bool CanRestrictCoverImports(wasm_module_t module)
{
    // Keep unguarded imports (including WAMR's built-in clock) and any future
    // host imports on the ordinary lane until explicitly reviewed here.
    const char *allowed[] = {"log", "check_cancel", "http_request", "unix_time_ms", "random_bytes",
        "html_parse", "html_select", "html_select_all", "html_attr", "html_text", "html_close"};
    const int32_t count = wasm_runtime_get_import_count(module);
    for (int32_t i = 0; i < count; ++i) {
        wasm_import_t import {};
        wasm_runtime_get_import_type(module, i, &import);
        if (import.kind != WASM_IMPORT_EXPORT_KIND_FUNC || !import.module_name || !import.name ||
            std::strcmp(import.module_name, "koma_host") != 0) return false;
        bool allowedImport = false;
        for (const char *name : allowed) {
            if (std::strcmp(import.name, name) == 0) {
                allowedImport = true;
                break;
            }
        }
        if (!allowedImport) return false;
    }
    return count >= 0;
}

class LocalCoverScope {
public:
    LocalCoverScope() { g_localCoverProbe = &probe_; }
    ~LocalCoverScope() { g_localCoverProbe = nullptr; }
    bool HasDependency() const { return probe_.needsOrdinaryCall; }
    void WriteLogs() const
    {
        for (const auto &log : probe_.logs) WriteHostLog(log.level, log.originalLength, log.message);
    }
private:
    LocalCoverProbe probe_;
};

class Module {
public:
    explicit Module(std::vector<uint8_t> wasmBytes, const std::string &httpContextJson = "") : httpContextJson_(httpContextJson), wasmBytes_(std::move(wasmBytes))
    {
        try {
            char errorBuf[256] = {0};
            module_ = wasm_runtime_load(
                wasmBytes_.data(),
                static_cast<uint32_t>(wasmBytes_.size()),
                errorBuf,
                sizeof(errorBuf));
            if (!module_) {
                throw std::runtime_error(std::string("wasm_runtime_load failed: ") + errorBuf);
            }
            if (g_localCoverProbe && !CanRestrictCoverImports(module_)) {
                throw std::runtime_error("cover has unrestricted imports");
            }

            moduleInst_ = wasm_runtime_instantiate(module_, kWasmStackBytes, kWasmHeapBytes, errorBuf, sizeof(errorBuf));
            if (!moduleInst_) {
                throw std::runtime_error(std::string("wasm_runtime_instantiate failed: ") + errorBuf);
            }

            execEnv_ = wasm_runtime_create_exec_env(moduleInst_, kWasmStackBytes);
            if (!execEnv_) {
                throw std::runtime_error("wasm_runtime_create_exec_env failed");
            }
            wasm_runtime_set_user_data(execEnv_, &httpContextJson_);
        } catch (...) {
            Release();
            throw;
        }
    }

    ~Module() { Release(); }

    Module(const Module &) = delete;
    Module &operator=(const Module &) = delete;

private:
    void Release()
    {
        if (execEnv_) {
            wasm_runtime_destroy_exec_env(execEnv_);
            execEnv_ = nullptr;
        }
        if (moduleInst_) {
            wasm_runtime_deinstantiate(moduleInst_);
            moduleInst_ = nullptr;
        }
        if (module_) {
            wasm_runtime_unload(module_);
            module_ = nullptr;
        }
    }

public:
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
    std::string httpContextJson_;
    std::vector<uint8_t> wasmBytes_;
};

#endif

} // namespace

ImageProcessorResult RunImageProcessor(const std::vector<uint8_t> &wasm, const uint8_t *rgba,
    size_t byteCount, uint32_t width, uint32_t height, const std::string &configuration)
{
#if defined(KOMA_ENABLE_WAMR)
    try {
        RuntimeLease runtime("", RuntimeLane::ImagePlugin);
        ThreadEnv environment;
        return ExecuteImageProcessor(wasm, rgba, byteCount, width, height, configuration);
    } catch (const std::exception &error) {
        ImageProcessorResult result;
        result.error = error.what();
        return result;
    }
#else
    return ExecuteImageProcessor(wasm, rgba, byteCount, width, height, configuration);
#endif
}

std::string RunImageProcessorInspection(const std::vector<uint8_t> &wasm)
{
#if defined(KOMA_ENABLE_WAMR)
    try {
        RuntimeLease runtime("", RuntimeLane::ImagePlugin);
        ThreadEnv environment;
        return InspectImageProcessor(wasm);
    } catch (const std::exception &error) { return error.what(); }
#else
    return "wamr_not_built";
#endif
}

std::string RunBundledWasmJsonCall(const std::string &requestJson)
{
#if defined(KOMA_ENABLE_WAMR)
    try {
        RuntimeLease runtime;
        ThreadEnv threadEnv;
        HtmlScope htmlScope;
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

std::string RunWasmJsonCallFromBytes(const std::string &requestJson, const std::vector<uint8_t> &wasmBytes,
    const std::string &httpContextJson, const std::string &sourceId, bool localCover)
{
#if defined(KOMA_ENABLE_WAMR)
    try {
        if (localCover) {
            if (sourceId.empty() || ExtractOperation(requestJson) != "get_image_request" ||
                HasTestOnlyGuard(requestJson, kTestTimeoutGuard)) return {};
            auto moduleBytes = LoadWasmBytesFromExternalBytes(wasmBytes);
            RuntimeLease runtime(sourceId, RuntimeLane::LocalCover);
            ThreadEnv threadEnv;
            HtmlScope htmlScope;
            LocalCoverScope restriction;
            Module module(std::move(moduleBytes), httpContextJson);
            auto response = module.RunOperation(requestJson);
            if (restriction.HasDependency()) return {};
            restriction.WriteLogs();
#if defined(KOMA_HAS_HILOG)
            OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaSourceRuntime",
                "[SourceRuntime] step=wasm_local_cover_complete source=%{public}s", sourceId.c_str());
#endif
            return response;
        }
        if (HasTestOnlyGuard(requestJson, kTestTimeoutGuard)) {
            return ErrorJson("WAMR_RUNTIME_TIMEOUT", "source runtime call timed out", "timeout");
        }
#if defined(KOMA_HAS_HILOG)
        const auto start = std::chrono::steady_clock::now();
#endif
        auto moduleBytes = LoadWasmBytesFromExternalBytes(wasmBytes);
        std::string response;
        {
            RuntimeLease runtime(sourceId);
            ThreadEnv threadEnv;
            HtmlScope htmlScope;
            Module module(std::move(moduleBytes), httpContextJson);
            response = module.RunOperation(requestJson);
        }
#if defined(KOMA_HAS_HILOG)
        const auto elapsed = std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - start).count();
        OH_LOG_Print(LOG_APP, LOG_INFO, 0x0, "KomaSourceRuntime",
            "[SourceRuntime] step=wasm_smoke_ok route=bytes wasmBytes=%{public}zu durationUs=%{public}lld",
            wasmBytes.size(), static_cast<long long>(elapsed));
#endif
        return response;
    } catch (const std::exception &err) {
        if (localCover) return {};
#if defined(KOMA_HAS_HILOG)
        OH_LOG_Print(LOG_APP, LOG_ERROR, 0x0, "KomaSourceRuntime",
            "RunWasmJsonCallFromBytes exception: %{public}s", err.what());
#endif
        return RuntimeErrorJson(err.what());
    }
#else
    (void)requestJson;
    (void)wasmBytes;
    (void)httpContextJson;
    (void)sourceId;
    if (localCover) return {};
    return ErrorJson("WAMR_NOT_BUILT", "native module was built without WAMR_ROOT_DIR", "wamr_not_built");
#endif
}

} // namespace koma

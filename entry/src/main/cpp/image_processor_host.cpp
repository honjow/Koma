#include "image_processor_host.h"

#include <chrono>
#include <condition_variable>
#include <cstring>
#include <mutex>
#include <stdexcept>
#include <thread>

#if defined(KOMA_ENABLE_WAMR)
#include "wasm_export.h"

namespace koma {
namespace {
constexpr size_t kMaxImageBytes = 256u * 1024u * 1024u;
constexpr size_t kMaxConfigurationBytes = 4u * 1024u * 1024u;
constexpr size_t kMaxModuleBytes = 2u * 1024u * 1024u;
constexpr uint32_t kMaxMemoryPages = 128;
constexpr auto kExecutionTime = std::chrono::seconds(5);

struct ImageCall {
    const uint8_t *input;
    uint32_t width, height;
    const std::string &configuration;
    ImageProcessorResult output;
    uint32_t nextOutputRow = 0;
    std::chrono::steady_clock::time_point deadline = std::chrono::steady_clock::now() + kExecutionTime;
};

ImageCall *Call(wasm_exec_env_t env)
{
    return static_cast<ImageCall *>(wasm_runtime_get_user_data(env));
}

bool Region(uint32_t imageWidth, uint32_t imageHeight, int32_t x, int32_t y,
    int32_t width, int32_t height, uint32_t capacity, size_t &bytes)
{
    if (x < 0 || y < 0 || width <= 0 || height <= 0 ||
        static_cast<uint64_t>(x) + width > imageWidth ||
        static_cast<uint64_t>(y) + height > imageHeight) return false;
    bytes = static_cast<size_t>(width) * static_cast<size_t>(height) * 4;
    return bytes <= capacity;
}

int32_t Width(wasm_exec_env_t env) { const auto *call = Call(env); return call ? call->width : 0; }
int32_t Height(wasm_exec_env_t env) { const auto *call = Call(env); return call ? call->height : 0; }
int32_t Cancelled(wasm_exec_env_t env)
{
    const auto *call = Call(env);
    return !call || std::chrono::steady_clock::now() >= call->deadline ? 1 : 0;
}
int32_t ConfigurationLength(wasm_exec_env_t env)
{
    const auto *call = Call(env);
    return call ? static_cast<int32_t>(call->configuration.size()) : -1;
}
int32_t ReadConfiguration(wasm_exec_env_t env, uint8_t *destination, uint32_t capacity)
{
    const auto *call = Call(env);
    if (!call || !destination || capacity < call->configuration.size()) return -1;
    std::memcpy(destination, call->configuration.data(), call->configuration.size());
    return static_cast<int32_t>(call->configuration.size());
}
int32_t ReadRegion(wasm_exec_env_t env, int32_t x, int32_t y, int32_t width,
    int32_t height, uint8_t *destination, uint32_t capacity)
{
    const auto *call = Call(env);
    size_t bytes = 0;
    if (Cancelled(env) || !destination || !Region(call->width, call->height, x, y, width, height, capacity, bytes)) return -1;
    for (int32_t row = 0; row < height; ++row) {
        std::memcpy(destination + static_cast<size_t>(row) * width * 4,
            call->input + (static_cast<size_t>(y + row) * call->width + x) * 4,
            static_cast<size_t>(width) * 4);
    }
    return static_cast<int32_t>(bytes);
}
int32_t CreateOutput(wasm_exec_env_t env, int32_t width, int32_t height)
{
    auto *call = Call(env);
    if (Cancelled(env) || width <= 0 || height <= 0 || call->output.width != 0 ||
        static_cast<uint64_t>(width) * height * 4 > kMaxImageBytes) return -1;
    try { call->output.pixels.resize(static_cast<size_t>(width) * height * 4); }
    catch (...) { return -1; }
    call->output.width = static_cast<uint32_t>(width);
    call->output.height = static_cast<uint32_t>(height);
    return 0;
}
int32_t WriteOutput(wasm_exec_env_t env, int32_t x, int32_t y, int32_t width,
    int32_t height, const uint8_t *source, uint32_t count)
{
    auto *call = Call(env);
    size_t bytes = 0;
    if (Cancelled(env) || !source || x != 0 || width != static_cast<int32_t>(call->output.width) ||
        y != static_cast<int32_t>(call->nextOutputRow) ||
        !Region(call->output.width, call->output.height, x, y, width, height, count, bytes) || bytes != count) return -1;
    std::memcpy(call->output.pixels.data() + static_cast<size_t>(y) * width * 4, source, bytes);
    call->nextOutputRow += static_cast<uint32_t>(height);
    return static_cast<int32_t>(bytes);
}

NativeSymbol imageSymbols[] = {
    {"width", reinterpret_cast<void *>(Width), "()i", nullptr},
    {"height", reinterpret_cast<void *>(Height), "()i", nullptr},
    {"config_len", reinterpret_cast<void *>(ConfigurationLength), "()i", nullptr},
    {"config_read", reinterpret_cast<void *>(ReadConfiguration), "(*~)i", nullptr},
    {"read_region", reinterpret_cast<void *>(ReadRegion), "(iiii*~)i", nullptr},
    {"output_create", reinterpret_cast<void *>(CreateOutput), "(ii)i", nullptr},
    {"output_write", reinterpret_cast<void *>(WriteOutput), "(iiii*~)i", nullptr},
    {"check_cancel", reinterpret_cast<void *>(Cancelled), "()i", nullptr},
};

// A start function runs before an execution environment can own its deadline.
// Processor ABI v1 therefore has explicit exports only, with no WASM start section.
void ValidateSections(const std::vector<uint8_t> &wasm)
{
    if (wasm.size() < 8 || wasm.size() > kMaxModuleBytes) throw std::runtime_error("invalid_module_size");
    size_t cursor = 8;
    while (cursor < wasm.size()) {
        const uint8_t id = wasm[cursor++];
        uint32_t count = 0, shift = 0;
        uint8_t value = 0;
        do {
            if (cursor == wasm.size() || shift > 28) throw std::runtime_error("invalid_module_section");
            value = wasm[cursor++];
            if (shift == 28 && (value & 0xF0)) throw std::runtime_error("invalid_module_section");
            count |= static_cast<uint32_t>(value & 0x7F) << shift;
            shift += 7;
        } while (value & 0x80);
        if (id == 8) throw std::runtime_error("processor_start_not_allowed");
        if (count > wasm.size() - cursor) throw std::runtime_error("invalid_module_section");
        cursor += count;
    }
}

class Module {
public:
    wasm_module_t module = nullptr;
    wasm_module_inst_t instance = nullptr;
    wasm_exec_env_t environment = nullptr;
    ~Module()
    {
        if (environment) wasm_runtime_destroy_exec_env(environment);
        if (instance) wasm_runtime_deinstantiate(instance);
        if (module) wasm_runtime_unload(module);
    }
    uint32_t Invoke(const char *name)
    {
        auto function = wasm_runtime_lookup_function(instance, name);
        if (!function) throw std::runtime_error("processor_missing_export");
        uint32_t result[1] {0};
        if (!wasm_runtime_call_wasm(environment, function, 0, result))
            throw std::runtime_error(Cancelled(environment) ? "processor_timeout" : "processor_trap");
        return result[0];
    }
};

void PrepareModule(Module &module, std::vector<uint8_t> &moduleBytes)
{
    ValidateSections(moduleBytes);
    char error[256] {};
    module.module = wasm_runtime_load(moduleBytes.data(), moduleBytes.size(), error, sizeof(error));
    if (!module.module) throw std::runtime_error("processor_load_failed");
    const int32_t importCount = wasm_runtime_get_import_count(module.module);
    if (importCount < 0) throw std::runtime_error("processor_import_invalid");
    for (int32_t i = 0; i < importCount; ++i) {
        wasm_import_t item {};
        wasm_runtime_get_import_type(module.module, i, &item);
        if (item.kind != WASM_IMPORT_EXPORT_KIND_FUNC || !item.module_name ||
            std::strcmp(item.module_name, "koma_image") != 0) throw std::runtime_error("processor_import_not_allowed");
    }
    bool hasMemory = false;
    bool hasAbi = false, hasProcess = false;
    for (int32_t i = 0; i < wasm_runtime_get_export_count(module.module); ++i) {
        wasm_export_t item {};
        wasm_runtime_get_export_type(module.module, i, &item);
        if (item.kind == WASM_IMPORT_EXPORT_KIND_FUNC && item.name &&
            (std::strcmp(item.name, "koma_image_processor_abi") == 0 || std::strcmp(item.name, "koma_image_process") == 0)) {
            if (wasm_func_type_get_param_count(item.u.func_type) != 0 ||
                wasm_func_type_get_result_count(item.u.func_type) != 1 ||
                wasm_func_type_get_result_valkind(item.u.func_type, 0) != WASM_I32)
                throw std::runtime_error("processor_export_signature");
            if (std::strcmp(item.name, "koma_image_processor_abi") == 0) hasAbi = true;
            else hasProcess = true;
        }
        if (item.kind != WASM_IMPORT_EXPORT_KIND_MEMORY) continue;
        if (hasMemory || !item.name || std::strcmp(item.name, "memory") != 0 ||
            wasm_memory_type_get_init_page_count(item.u.memory_type) > kMaxMemoryPages ||
            wasm_memory_type_get_max_page_count(item.u.memory_type) > kMaxMemoryPages)
            throw std::runtime_error("processor_memory_limit");
        hasMemory = true;
    }
    if (!hasMemory) throw std::runtime_error("processor_missing_memory");
    if (!hasAbi || !hasProcess) throw std::runtime_error("processor_missing_export");
}

class Deadline {
public:
    explicit Deadline(wasm_module_inst_t instance) : worker_([this, instance] {
        std::unique_lock<std::mutex> lock(mutex_);
        if (!condition_.wait_for(lock, kExecutionTime, [this] { return done_; })) wasm_runtime_terminate(instance);
    }) {}
    ~Deadline()
    {
        { std::lock_guard<std::mutex> lock(mutex_); done_ = true; }
        condition_.notify_one();
        worker_.join();
    }
private:
    std::mutex mutex_;
    std::condition_variable condition_;
    bool done_ = false;
    std::thread worker_;
};
} // namespace

bool RegisterImageProcessorImports()
{
    return wasm_runtime_register_natives("koma_image", imageSymbols,
        static_cast<uint32_t>(sizeof(imageSymbols) / sizeof(imageSymbols[0])));
}

std::string InspectImageProcessor(const std::vector<uint8_t> &wasm)
{
    try {
        std::vector<uint8_t> bytes(wasm);
        Module module;
        PrepareModule(module, bytes);
        return "";
    } catch (const std::exception &error) { return error.what(); }
}

ImageProcessorResult ExecuteImageProcessor(const std::vector<uint8_t> &wasm,
    const uint8_t *rgba, size_t byteCount, uint32_t width, uint32_t height,
    const std::string &configuration)
{
    try {
        if (!rgba || !width || !height || byteCount > kMaxImageBytes ||
            static_cast<uint64_t>(width) * height * 4 != byteCount || configuration.size() > kMaxConfigurationBytes)
            throw std::runtime_error("invalid_image_input");
        std::vector<uint8_t> moduleBytes(wasm);
        Module module;
        PrepareModule(module, moduleBytes);
        char error[256] {};
        module.instance = wasm_runtime_instantiate(module.module, 64 * 1024, 256 * 1024, error, sizeof(error));
        if (!module.instance) throw std::runtime_error("processor_instantiate_failed");
        module.environment = wasm_runtime_create_exec_env(module.instance, 64 * 1024);
        if (!module.environment) throw std::runtime_error("processor_environment_failed");
        ImageCall call {rgba, width, height, configuration};
        wasm_runtime_set_user_data(module.environment, &call);
        Deadline deadline(module.instance);
        if (module.Invoke("koma_image_processor_abi") != 1) throw std::runtime_error("processor_abi_not_supported");
        const int32_t status = static_cast<int32_t>(module.Invoke("koma_image_process"));
        if (Cancelled(module.environment)) throw std::runtime_error("processor_timeout");
        if (status == 0) return {};
        if (status != 1 || !call.output.width || call.nextOutputRow != call.output.height)
            throw std::runtime_error("processor_incomplete_output");
        call.output.changed = true;
        return std::move(call.output);
    } catch (const std::exception &error) {
        ImageProcessorResult result;
        result.error = error.what();
        return result;
    }
}
} // namespace koma
#else
namespace koma {
bool RegisterImageProcessorImports() { return false; }
std::string InspectImageProcessor(const std::vector<uint8_t> &) { return "wamr_not_built"; }
ImageProcessorResult ExecuteImageProcessor(const std::vector<uint8_t> &, const uint8_t *, size_t, uint32_t, uint32_t,
    const std::string &) { ImageProcessorResult result; result.error = "wamr_not_built"; return result; }
}
#endif

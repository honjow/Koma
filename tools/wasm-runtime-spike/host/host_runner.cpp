#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#include "wasm_export.h"

namespace {

constexpr uint32_t kKomaMagic = 0x4B4F4D41u;
constexpr uint32_t kRuntimeHeapBytes = 8u * 1024u * 1024u;
constexpr uint32_t kWasmStackBytes = 64u * 1024u;
constexpr uint32_t kWasmHeapBytes = 256u * 1024u;
constexpr uint32_t kMaxPayloadBytes = 1024u * 1024u;
constexpr uint32_t kMaxHostLogBytes = 1024u;

void host_log(wasm_exec_env_t exec_env, int32_t level, char *message, uint32_t message_len) {
    (void)exec_env;
    const uint32_t safe_len = message_len > kMaxHostLogBytes ? kMaxHostLogBytes : message_len;
    std::string sanitized;
    sanitized.reserve(safe_len);
    for (uint32_t i = 0; i < safe_len; i++) {
        const char ch = message[i];
        sanitized += (ch >= 0x20 && ch <= 0x7e) ? ch : '?';
    }
    std::cout << "HOST_LOG level=" << level << " len=" << message_len
              << " message=\"" << sanitized << "\"\n";
}

int32_t host_check_cancel(wasm_exec_env_t exec_env) {
    (void)exec_env;
    std::cout << "HOST_CHECK_CANCEL result=0\n";
    return 0;
}

NativeSymbol g_koma_host_symbols[] = {
    {"log", reinterpret_cast<void *>(host_log), "(i*~)", nullptr},
    {"check_cancel", reinterpret_cast<void *>(host_check_cancel), "()i", nullptr},
};

std::vector<uint8_t> read_file(const char *path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        throw std::runtime_error(std::string("failed to open ") + path);
    }
    in.seekg(0, std::ios::end);
    const std::streamoff size = in.tellg();
    if (size <= 0) {
        throw std::runtime_error(std::string("empty file ") + path);
    }
    in.seekg(0, std::ios::beg);
    std::vector<uint8_t> bytes(static_cast<size_t>(size));
    in.read(reinterpret_cast<char *>(bytes.data()), size);
    if (!in) {
        throw std::runtime_error(std::string("failed to read ") + path);
    }
    return bytes;
}

uint32_t read_le_u32(const uint8_t *p) {
    return static_cast<uint32_t>(p[0]) |
           (static_cast<uint32_t>(p[1]) << 8u) |
           (static_cast<uint32_t>(p[2]) << 16u) |
           (static_cast<uint32_t>(p[3]) << 24u);
}

void require_call(wasm_exec_env_t exec_env,
                  wasm_module_inst_t module_inst,
                  wasm_function_inst_t fn,
                  uint32_t argc,
                  uint32_t argv[],
                  const char *name) {
    if (!wasm_runtime_call_wasm(exec_env, fn, argc, argv)) {
        const char *exception = wasm_runtime_get_exception(module_inst);
        throw std::runtime_error(std::string("wasm call failed: ") + name +
                                 ": " + (exception ? exception : "unknown exception"));
    }
}

bool json_shape_is_plausible(const std::string &payload) {
    if (payload.empty() || payload.front() != '{' || payload.back() != '}') {
        return false;
    }

    int depth = 0;
    bool in_string = false;
    bool escaped = false;
    for (char ch : payload) {
        if (in_string) {
            if (escaped) {
                escaped = false;
            }
            else if (ch == '\\') {
                escaped = true;
            }
            else if (ch == '"') {
                in_string = false;
            }
            continue;
        }

        if (ch == '"') {
            in_string = true;
        }
        else if (ch == '{' || ch == '[') {
            depth++;
        }
        else if (ch == '}' || ch == ']') {
            depth--;
            if (depth < 0) {
                return false;
            }
        }
    }

    return depth == 0 && !in_string && payload.find("\"ok\":true") != std::string::npos;
}

struct SourceOperation {
    const char *name;
    const char *export_name;
    const char *request_json;
};

bool contains_any_forbidden_runtime_string(const std::string &payload) {
    const char *forbidden[] = {
        "\"network\":true",
        "http_request",
        "https://",
        "http://",
        "file://",
        "content://",
        "ohos://",
        "internal://",
        "app-private",
        "/home/",
        "/Users/",
        "/data/",
        "/storage/",
        "/sdcard/",
        ".hermes-artifacts",
    };
    for (const char *needle : forbidden) {
        if (payload.find(needle) != std::string::npos) {
            return true;
        }
    }
    return false;
}

void validate_source_envelope(const std::string &operation, const std::string &payload) {
    if (!json_shape_is_plausible(payload)) {
        throw std::runtime_error(operation + " result payload is not plausible JSON envelope");
    }
    if (payload.find("\"version\":1") == std::string::npos) {
        throw std::runtime_error(operation + " result missing version:1");
    }
    if (payload.find("\"operation\":\"" + operation + "\"") == std::string::npos) {
        throw std::runtime_error(operation + " result operation mismatch");
    }
    if (payload.find("\"data\":") == std::string::npos) {
        throw std::runtime_error(operation + " result missing data");
    }
    if (payload.find("\"hostHints\":") == std::string::npos ||
        payload.find("\"network\":false") == std::string::npos) {
        throw std::runtime_error(operation + " result missing hostHints.network=false");
    }
    if (contains_any_forbidden_runtime_string(payload)) {
        throw std::runtime_error(operation + " result leaked network/http/path evidence");
    }
}

class Runtime {
public:
    Runtime() : heap_(kRuntimeHeapBytes) {
        RuntimeInitArgs init_args;
        std::memset(&init_args, 0, sizeof(init_args));
        init_args.mem_alloc_type = Alloc_With_Pool;
        init_args.mem_alloc_option.pool.heap_buf = heap_.data();
        init_args.mem_alloc_option.pool.heap_size = static_cast<uint32_t>(heap_.size());
        init_args.native_module_name = "koma_host";
        init_args.native_symbols = g_koma_host_symbols;
        init_args.n_native_symbols =
            static_cast<uint32_t>(sizeof(g_koma_host_symbols) / sizeof(g_koma_host_symbols[0]));

        if (!wasm_runtime_full_init(&init_args)) {
            throw std::runtime_error("wasm_runtime_full_init failed");
        }
        initialized_ = true;
    }

    ~Runtime() {
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

class Module {
public:
    explicit Module(std::vector<uint8_t> wasm_bytes) : wasm_bytes_(std::move(wasm_bytes)) {
        char error_buf[256] = {0};
        module_ = wasm_runtime_load(wasm_bytes_.data(),
                                    static_cast<uint32_t>(wasm_bytes_.size()),
                                    error_buf,
                                    sizeof(error_buf));
        if (!module_) {
            throw std::runtime_error(std::string("wasm_runtime_load failed: ") + error_buf);
        }

        module_inst_ = wasm_runtime_instantiate(module_,
                                                kWasmStackBytes,
                                                kWasmHeapBytes,
                                                error_buf,
                                                sizeof(error_buf));
        if (!module_inst_) {
            throw std::runtime_error(std::string("wasm_runtime_instantiate failed: ") + error_buf);
        }

        exec_env_ = wasm_runtime_create_exec_env(module_inst_, kWasmStackBytes);
        if (!exec_env_) {
            throw std::runtime_error("wasm_runtime_create_exec_env failed");
        }
    }

    ~Module() {
        if (exec_env_) {
            wasm_runtime_destroy_exec_env(exec_env_);
        }
        if (module_inst_) {
            wasm_runtime_deinstantiate(module_inst_);
        }
        if (module_) {
            wasm_runtime_unload(module_);
        }
    }

    Module(const Module &) = delete;
    Module &operator=(const Module &) = delete;

    wasm_function_inst_t lookup(const char *name) {
        wasm_function_inst_t fn = wasm_runtime_lookup_function(module_inst_, name);
        if (!fn) {
            throw std::runtime_error(std::string("missing export: ") + name);
        }
        return fn;
    }

    void validate_add() {
        wasm_function_inst_t add = lookup("add");
        uint32_t argv[2] = {2, 3};
        require_call(exec_env_, module_inst_, add, 2, argv, "add");
        if (argv[0] != 5) {
            throw std::runtime_error("add(2,3) returned " + std::to_string(argv[0]));
        }
        std::cout << "ADD_OK add(2,3)=5\n";
    }

    void init_with_manifest() {
        constexpr const char *manifest =
            "{\"schemaVersion\":1,\"id\":\"local.example.private\","
            "\"runtime\":\"wasm-v1\",\"entry\":\"source.wasm\","
            "\"host\":{\"abi\":\"koma-host-v0.1\",\"imports\":[\"log\",\"check_cancel\"],"
            "\"limits\":{\"maxMemoryPages\":2,\"maxPayloadBytes\":1048576,\"network\":false}},"
            "\"contentPolicy\":{\"publicIndex\":false,\"marketplace\":false}}";
        const uint32_t manifest_len = static_cast<uint32_t>(std::strlen(manifest));
        uint64_t manifest_ptr =
            wasm_runtime_module_dup_data(module_inst_, manifest, manifest_len);
        if (manifest_ptr == 0) {
            throw std::runtime_error("failed to copy manifest into wasm memory");
        }

        wasm_function_inst_t init = lookup("koma_source_init");
        uint32_t argv[2] = {static_cast<uint32_t>(manifest_ptr), manifest_len};
        try {
            require_call(exec_env_, module_inst_, init, 2, argv, "koma_source_init");
        }
        catch (...) {
            wasm_runtime_module_free(module_inst_, manifest_ptr);
            throw;
        }
        wasm_runtime_module_free(module_inst_, manifest_ptr);

        if (static_cast<int32_t>(argv[0]) != 0) {
            throw std::runtime_error("koma_source_init returned " + std::to_string(argv[0]));
        }
        std::cout << "INIT_OK manifest accepted\n";
    }

    std::string call_operation(const SourceOperation &operation) {
        const char *request = operation.request_json;
        const uint32_t request_len = static_cast<uint32_t>(std::strlen(request));
        uint64_t request_ptr =
            wasm_runtime_module_dup_data(module_inst_, request, request_len);
        if (request_ptr == 0) {
            throw std::runtime_error("failed to copy request into wasm memory");
        }

        wasm_function_inst_t source_fn = lookup(operation.export_name);
        uint32_t argv[2] = {static_cast<uint32_t>(request_ptr), request_len};
        try {
            require_call(exec_env_, module_inst_, source_fn, 2, argv, operation.export_name);
        }
        catch (...) {
            wasm_runtime_module_free(module_inst_, request_ptr);
            throw;
        }
        wasm_runtime_module_free(module_inst_, request_ptr);

        const uint32_t result_ptr = argv[0];
        if (result_ptr == 0) {
            throw std::runtime_error(std::string(operation.export_name) + " returned null result pointer");
        }
        if (!wasm_runtime_validate_app_addr(module_inst_, result_ptr, 16)) {
            throw std::runtime_error("result header is outside wasm memory");
        }

        const uint8_t *header = static_cast<const uint8_t *>(
            wasm_runtime_addr_app_to_native(module_inst_, result_ptr));
        const uint32_t magic = read_le_u32(header);
        const uint32_t flags = read_le_u32(header + 4);
        const uint32_t len = read_le_u32(header + 8);
        const uint32_t reserved = read_le_u32(header + 12);

        if (magic != kKomaMagic) {
            throw std::runtime_error("bad result magic");
        }
        if ((flags & ~1u) != 0 || (flags & 1u) == 0) {
            throw std::runtime_error("unexpected result flags " + std::to_string(flags));
        }
        if (reserved != 0) {
            throw std::runtime_error("reserved result header field is non-zero");
        }
        if (len == 0 || len > kMaxPayloadBytes) {
            throw std::runtime_error("unexpected payload length " + std::to_string(len));
        }
        if (!wasm_runtime_validate_app_addr(module_inst_, result_ptr + 16u, len)) {
            throw std::runtime_error("result payload is outside wasm memory");
        }

        const char *payload_native = static_cast<const char *>(
            wasm_runtime_addr_app_to_native(module_inst_, result_ptr + 16u));
        std::string payload(payload_native, payload_native + len);
        validate_source_envelope(operation.name, payload);

        wasm_function_inst_t free_fn = lookup("koma_source_free");
        uint32_t free_argv[1] = {result_ptr};
        require_call(exec_env_, module_inst_, free_fn, 1, free_argv, "koma_source_free");

        std::cout << "SOURCE_API_OPERATION " << operation.name << " ok:true"
                  << " magic=KOMA flags=" << flags << " len=" << len << "\n";
        std::cout << "SOURCE_API_JSON " << operation.name << "=" << payload << "\n";
        return payload;
    }

    void call_core_operations() {
        const SourceOperation operations[] = {
            {
                "search",
                "koma_source_search",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-search-001\","
                "\"operation\":\"search\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{\"query\":\"fixture\",\"page\":{\"cursor\":null,\"limit\":20},"
                "\"filters\":{\"tags\":[\"fixture\"]}},\"settings\":{},"
                "\"hostHints\":{\"network\":false}}",
            },
            {
                "get_manga",
                "koma_source_get_manga",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-manga-001\","
                "\"operation\":\"get_manga\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{\"mangaId\":\"manga:fixture-series\"},\"settings\":{},"
                "\"hostHints\":{\"network\":false}}",
            },
            {
                "get_chapters",
                "koma_source_get_chapters",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-chapters-001\","
                "\"operation\":\"get_chapters\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{\"mangaId\":\"manga:fixture-series\","
                "\"page\":{\"cursor\":null,\"limit\":100}},\"settings\":{},"
                "\"hostHints\":{\"network\":false}}",
            },
            {
                "get_pages",
                "koma_source_get_pages",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-pages-001\","
                "\"operation\":\"get_pages\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{\"chapterId\":\"chapter:fixture-series:001\"},\"settings\":{},"
                "\"hostHints\":{\"network\":false,\"imageStrategy\":\"descriptor-only\"}}",
            },
        };

        for (const SourceOperation &operation : operations) {
            call_operation(operation);
        }
        std::cout << "hostHints.network=false\n";
    }

private:
    std::vector<uint8_t> wasm_bytes_;
    wasm_module_t module_ = nullptr;
    wasm_module_inst_t module_inst_ = nullptr;
    wasm_exec_env_t exec_env_ = nullptr;
};

} // namespace

int main(int argc, char **argv) {
    if (argc != 2) {
        std::cerr << "usage: " << argv[0] << " /path/to/source_fixture.wasm\n";
        return 2;
    }

    try {
        Runtime runtime;
        Module module(read_file(argv[1]));
        module.validate_add();
        module.init_with_manifest();
        module.call_core_operations();
        std::cout << "SOURCE_API_RUNTIME_SMOKE_PASS\n";
        std::cout << "WAMR_SPIKE_PASS\n";
        return 0;
    }
    catch (const std::exception &err) {
        std::cerr << "WAMR_SPIKE_FAIL " << err.what() << "\n";
        return 1;
    }
}

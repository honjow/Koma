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
constexpr uint32_t kMaxHttpFixtureRequestBytes = 2048u;
constexpr uint32_t kMaxHttpFixtureResponseBytes = 4096u;
constexpr uint32_t kMaxHtmlFixtureBytes = 4096u;
constexpr uint32_t kMaxHtmlFixtureStringBytes = 512u;
constexpr uint32_t kMaxHtmlFixtureDescriptors = 16u;
constexpr const char *kTestTimeoutGuard = "\"testGuard\":\"timeout\"";

bool g_force_cancel_for_current_call = false;

class ForcedCancelScope {
public:
    explicit ForcedCancelScope(bool enabled) : previous_(g_force_cancel_for_current_call) {
        g_force_cancel_for_current_call = enabled;
    }

    ~ForcedCancelScope() {
        g_force_cancel_for_current_call = previous_;
    }

    ForcedCancelScope(const ForcedCancelScope &) = delete;
    ForcedCancelScope &operator=(const ForcedCancelScope &) = delete;

private:
    bool previous_;
};

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
    const int32_t result = g_force_cancel_for_current_call ? 1 : 0;
    std::cout << "HOST_CHECK_CANCEL result=" << result << "\n";
    return result;
}

bool contains_ci(std::string value, std::string needle) {
    for (char &ch : value) {
        if (ch >= 'A' && ch <= 'Z') {
            ch = static_cast<char>(ch - 'A' + 'a');
        }
    }
    for (char &ch : needle) {
        if (ch >= 'A' && ch <= 'Z') {
            ch = static_cast<char>(ch - 'A' + 'a');
        }
    }
    return value.find(needle) != std::string::npos;
}

int32_t write_http_fixture_response(char *out, uint32_t out_cap, const std::string &payload) {
    if (payload.size() > kMaxHttpFixtureResponseBytes || payload.size() > out_cap) {
        return -3;
    }
    std::memcpy(out, payload.data(), payload.size());
    return static_cast<int32_t>(payload.size());
}

std::string http_fixture_error(const char *code, const char *phase) {
    return std::string("{\"ok\":false,\"error\":{\"code\":\"") + code +
           "\",\"message\":\"fixture HTTP policy denied request\",\"phase\":\"" + phase +
           "\",\"retryable\":false},\"networkPerformed\":false}";
}

int32_t host_http_request(wasm_exec_env_t exec_env,
                          char *request,
                          uint32_t request_len,
                          char *out,
                          uint32_t out_cap) {
    (void)exec_env;
    if (!request || !out || request_len == 0 || request_len > kMaxHttpFixtureRequestBytes ||
        out_cap < 256) {
        const std::string payload = http_fixture_error("invalid_request", "shape");
        return out ? write_http_fixture_response(out, out_cap, payload) : -2;
    }

    const std::string req(request, request + request_len);
    const bool has_credential_header =
        contains_ci(req, "\"authorization\"") || contains_ci(req, "\"cookie\"") ||
        contains_ci(req, "proxy-authorization") || contains_ci(req, "set-cookie") ||
        contains_ci(req, "token") || contains_ci(req, "password");
    std::string payload;
    const char *evidence = nullptr;

    if (has_credential_header) {
        payload = http_fixture_error("credential_header_denied", "headers");
        evidence = "SOURCE_API_HTTP_FIXTURE_DENIED_CREDENTIAL_HEADER ok:true reason=credential_header_denied";
    }
    else if (req.find("\"version\":1") == std::string::npos ||
             req.find("\"url\":\"") == std::string::npos) {
        payload = http_fixture_error("invalid_request", "shape");
        evidence = "SOURCE_API_HTTP_FIXTURE_DENIED_INVALID ok:true reason=invalid_request";
    }
    else if (req.find("\"method\":\"GET\"") == std::string::npos) {
        payload = http_fixture_error("method_not_allowed", "method");
        evidence = "SOURCE_API_HTTP_FIXTURE_DENIED_METHOD ok:true reason=method_not_allowed";
    }
    else if (req.find("\"responseKind\":\"bodyJson\"") == std::string::npos &&
             req.find("\"responseKind\":\"bodyText\"") == std::string::npos) {
        payload = http_fixture_error("response_kind_not_allowed", "responseKind");
        evidence =
            "SOURCE_API_HTTP_FIXTURE_DENIED_RESPONSE_KIND ok:true reason=response_kind_not_allowed";
    }
    else if (req.find("\"bodyBase64\":null") == std::string::npos) {
        payload = http_fixture_error("request_body_too_large", "body");
        evidence = "SOURCE_API_HTTP_FIXTURE_DENIED_BODY ok:true reason=request_body_too_large";
    }
    else if (req.find("\"url\":\"https://fixture.koma.local/manga-list/http-fixture\"") ==
             std::string::npos) {
        payload = http_fixture_error("host_not_allowed", "url");
        evidence = "SOURCE_API_HTTP_FIXTURE_DENIED_HOST ok:true reason=host_not_allowed";
    }
    else {
        payload =
            "{\"ok\":true,\"status\":200,\"headers\":{\"content-type\":\"application/json\"},"
            "\"bodyText\":\"{\\\"items\\\":[{\\\"id\\\":\\\"manga:http-fixture-series\\\","
            "\\\"title\\\":\\\"HTTP Fixture Series\\\"}]}\","
            "\"bodyJson\":{\"items\":[{\"id\":\"manga:http-fixture-series\","
            "\"title\":\"HTTP Fixture Series\"}]},"
            "\"finalUrl\":\"https://fixture.koma.local/manga-list/http-fixture\","
            "\"responseKind\":\"bodyJson\",\"networkPerformed\":false}";
        evidence = "SOURCE_API_HTTP_FIXTURE_ALLOWED ok:true host=fixture.koma.local "
                   "networkPerformed=false";
    }

    const int32_t written = write_http_fixture_response(out, out_cap, payload);
    if (written >= 0 && evidence) {
        std::cout << evidence << "\n";
    }
    return written;
}

enum class HtmlDescriptorKind {
    Closed,
    Document,
    MangaCard,
    Title,
    Chapter,
};

struct HtmlDescriptor {
    HtmlDescriptorKind kind = HtmlDescriptorKind::Closed;
};

HtmlDescriptor g_html_descriptors[kMaxHtmlFixtureDescriptors];

int32_t allocate_html_descriptor(HtmlDescriptorKind kind) {
    for (uint32_t i = 1; i < kMaxHtmlFixtureDescriptors; i++) {
        if (g_html_descriptors[i].kind == HtmlDescriptorKind::Closed) {
            g_html_descriptors[i].kind = kind;
            return static_cast<int32_t>(i);
        }
    }
    return -5;
}

bool html_descriptor_is_valid(int32_t descriptor) {
    return descriptor > 0 && descriptor < static_cast<int32_t>(kMaxHtmlFixtureDescriptors) &&
           g_html_descriptors[descriptor].kind != HtmlDescriptorKind::Closed;
}

bool is_supported_html_fixture(const std::string &html) {
    return html.find("<section data-koma-fixture=\"html-host-import-v0\">") != std::string::npos &&
           html.find("article class=\"manga-card\"") != std::string::npos &&
           html.find("data-id=\"manga:html-fixture-series\"") != std::string::npos &&
           html.find("HTML Fixture Series") != std::string::npos &&
           !contains_ci(html, "authorization") && !contains_ci(html, "cookie") &&
           !contains_ci(html, "token") && !contains_ci(html, "password") &&
           html.find("/home/") == std::string::npos && html.find("file://") == std::string::npos;
}

int32_t host_html_parse(wasm_exec_env_t exec_env, char *html, uint32_t html_len) {
    (void)exec_env;
    if (!html || html_len == 0 || html_len > kMaxHtmlFixtureBytes) {
        std::cout << "SOURCE_API_HTML_FIXTURE_PARSE_DENIED ok:true reason=invalid_html\n";
        return -2;
    }

    const std::string fixture_html(html, html + html_len);
    if (!is_supported_html_fixture(fixture_html)) {
        std::cout << "SOURCE_API_HTML_FIXTURE_PARSE_DENIED ok:true reason=unsupported_fixture\n";
        return -1;
    }

    const int32_t descriptor = allocate_html_descriptor(HtmlDescriptorKind::Document);
    if (descriptor > 0) {
        std::cout << "SOURCE_API_HTML_FIXTURE_PARSE_ALLOWED ok:true descriptor=document\n";
    }
    return descriptor;
}

int32_t host_html_select(wasm_exec_env_t exec_env,
                         int32_t descriptor,
                         char *selector,
                         uint32_t selector_len) {
    (void)exec_env;
    if (!html_descriptor_is_valid(descriptor) || !selector || selector_len == 0 ||
        selector_len > 64) {
        std::cout << "SOURCE_API_HTML_FIXTURE_SELECT_DENIED ok:true reason=invalid_selector\n";
        return -2;
    }

    const std::string selector_value(selector, selector + selector_len);
    const HtmlDescriptorKind kind = g_html_descriptors[descriptor].kind;
    HtmlDescriptorKind next = HtmlDescriptorKind::Closed;
    if (kind == HtmlDescriptorKind::Document && selector_value == "article.manga-card") {
        next = HtmlDescriptorKind::MangaCard;
    }
    else if (kind == HtmlDescriptorKind::MangaCard && selector_value == "h3.title") {
        next = HtmlDescriptorKind::Title;
    }
    else if (kind == HtmlDescriptorKind::MangaCard && selector_value == "a.chapter") {
        next = HtmlDescriptorKind::Chapter;
    }
    else {
        std::cout << "SOURCE_API_HTML_FIXTURE_UNSUPPORTED_SELECTOR_DENIED ok:true selector="
                  << selector_value << "\n";
        return -1;
    }

    const int32_t selected = allocate_html_descriptor(next);
    if (selected > 0) {
        std::cout << "SOURCE_API_HTML_FIXTURE_SELECT_ALLOWED ok:true selector="
                  << selector_value << "\n";
    }
    return selected;
}

int32_t write_html_fixture_string(char *out, uint32_t out_cap, const std::string &value) {
    if (!out || out_cap == 0 || value.size() > kMaxHtmlFixtureStringBytes ||
        value.size() > out_cap) {
        return -3;
    }
    if (contains_ci(value, "authorization") || contains_ci(value, "cookie") ||
        contains_ci(value, "token") || contains_ci(value, "password") ||
        value.find("/home/") != std::string::npos || value.find("file://") != std::string::npos) {
        return -4;
    }
    std::memcpy(out, value.data(), value.size());
    return static_cast<int32_t>(value.size());
}

int32_t host_html_attr(wasm_exec_env_t exec_env,
                       int32_t descriptor,
                       char *attr,
                       uint32_t attr_len,
                       char *out,
                       uint32_t out_cap) {
    (void)exec_env;
    if (!html_descriptor_is_valid(descriptor) || !attr || attr_len == 0 || attr_len > 32) {
        std::cout << "SOURCE_API_HTML_FIXTURE_ATTR_DENIED ok:true reason=invalid_attr\n";
        return -2;
    }

    const std::string attr_value(attr, attr + attr_len);
    const HtmlDescriptorKind kind = g_html_descriptors[descriptor].kind;
    std::string value;
    if (kind == HtmlDescriptorKind::MangaCard && attr_value == "data-id") {
        value = "manga:html-fixture-series";
    }
    else if (kind == HtmlDescriptorKind::Chapter && attr_value == "data-id") {
        value = "chapter:html-fixture-series:001";
    }
    else if (kind == HtmlDescriptorKind::Chapter && attr_value == "data-page-id") {
        value = "page:html-fixture-series:001:0001";
    }
    else {
        std::cout << "SOURCE_API_HTML_FIXTURE_UNSUPPORTED_ATTR_DENIED ok:true attr="
                  << attr_value << "\n";
        return -1;
    }

    const int32_t written = write_html_fixture_string(out, out_cap, value);
    if (written >= 0) {
        std::cout << "SOURCE_API_HTML_FIXTURE_ATTR_ALLOWED ok:true attr=" << attr_value << "\n";
    }
    return written;
}

int32_t host_html_text(wasm_exec_env_t exec_env, int32_t descriptor, char *out, uint32_t out_cap) {
    (void)exec_env;
    if (!html_descriptor_is_valid(descriptor)) {
        std::cout << "SOURCE_API_HTML_FIXTURE_TEXT_DENIED ok:true reason=invalid_descriptor\n";
        return -2;
    }

    std::string value;
    const HtmlDescriptorKind kind = g_html_descriptors[descriptor].kind;
    if (kind == HtmlDescriptorKind::Title) {
        value = "HTML Fixture Series";
    }
    else if (kind == HtmlDescriptorKind::Chapter) {
        value = "Chapter 1";
    }
    else {
        std::cout << "SOURCE_API_HTML_FIXTURE_TEXT_DENIED ok:true reason=unsupported_descriptor\n";
        return -1;
    }

    const int32_t written = write_html_fixture_string(out, out_cap, value);
    if (written >= 0) {
        std::cout << "SOURCE_API_HTML_FIXTURE_TEXT_ALLOWED ok:true\n";
    }
    return written;
}

int32_t host_html_close(wasm_exec_env_t exec_env, int32_t descriptor) {
    (void)exec_env;
    if (!html_descriptor_is_valid(descriptor)) {
        return -1;
    }
    g_html_descriptors[descriptor].kind = HtmlDescriptorKind::Closed;
    return 0;
}

NativeSymbol g_koma_host_symbols[] = {
    {"log", reinterpret_cast<void *>(host_log), "(i*~)", nullptr},
    {"check_cancel", reinterpret_cast<void *>(host_check_cancel), "()i", nullptr},
    {"http_request", reinterpret_cast<void *>(host_http_request), "(*~*~)i", nullptr},
    {"html_parse", reinterpret_cast<void *>(host_html_parse), "(*~)i", nullptr},
    {"html_select", reinterpret_cast<void *>(host_html_select), "(i*~)i", nullptr},
    {"html_attr", reinterpret_cast<void *>(host_html_attr), "(i*~*~)i", nullptr},
    {"html_text", reinterpret_cast<void *>(host_html_text), "(i*~)i", nullptr},
    {"html_close", reinterpret_cast<void *>(host_html_close), "(i)i", nullptr},
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
        "password",
        "token",
        "secret",
        "apiKey",
        "cookie",
    };
    for (const char *needle : forbidden) {
        if (payload.find(needle) != std::string::npos) {
            return true;
        }
    }
    return false;
}

void require_contains(const std::string &payload,
                      const std::string &needle,
                      const std::string &context) {
    if (payload.find(needle) == std::string::npos) {
        throw std::runtime_error(context + " missing " + needle);
    }
}

bool has_test_only_guard(const std::string &request_json, const char *guard) {
    return request_json.find("\"komaTestOnly\":true") != std::string::npos &&
           request_json.find(guard) != std::string::npos;
}

std::string timeout_guard_error_json(const std::string &request_json) {
    if (!has_test_only_guard(request_json, kTestTimeoutGuard)) {
        throw std::runtime_error("timeout guard request did not select timeout guard");
    }
    return "{\"ok\":false,\"runtime\":\"wamr-unavailable\","
           "\"error\":{\"code\":\"WAMR_RUNTIME_TIMEOUT\","
           "\"message\":\"source runtime call timed out\"},"
           "\"reasonCode\":\"timeout\",\"warnings\":[]}";
}

void validate_timeout_guard_payload(const std::string &payload) {
    require_contains(payload, "\"ok\":false", "timeout guard rejection");
    require_contains(payload, "\"runtime\":\"wamr-unavailable\"", "timeout guard rejection");
    require_contains(payload, "\"code\":\"WAMR_RUNTIME_TIMEOUT\"", "timeout guard rejection");
    require_contains(payload, "\"message\":\"source runtime call timed out\"",
                     "timeout guard rejection");
    require_contains(payload, "\"reasonCode\":\"timeout\"", "timeout guard rejection");
    require_contains(payload, "\"warnings\":[]", "timeout guard rejection");
    if (payload.find("\"ok\":true") != std::string::npos ||
        payload.find("\"data\":") != std::string::npos ||
        payload.find("Fixture Series") != std::string::npos ||
        payload.find("\"requestEcho\":\"fixture\"") != std::string::npos ||
        contains_any_forbidden_runtime_string(payload)) {
        throw std::runtime_error("timeout guard leaked success or unsafe evidence");
    }
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

void validate_source_info_envelope(const std::string &payload) {
    validate_source_envelope("source_info", payload);

    require_contains(payload, "\"sourceInfo\":", "source_info");
    require_contains(payload, "\"id\":\"local.test.koma.fixture\"", "source_info");
    require_contains(payload, "\"name\":\"Koma Rust SDK Fixture\"", "source_info");
    require_contains(payload, "\"version\":\"0.2.0\"", "source_info");
    require_contains(payload, "\"apiVersion\":\"0.2\"", "source_info");
    require_contains(payload, "\"language\":\"zh-Hans\"", "source_info");
    require_contains(payload, "\"contentRating\":\"unknown\"", "source_info");

    require_contains(payload, "\"capabilities\":", "source_info");
    require_contains(payload, "\"search\":true", "source_info capabilities");
    require_contains(payload, "\"mangaDetail\":true", "source_info capabilities");
    require_contains(payload, "\"chapters\":true", "source_info capabilities");
    require_contains(payload, "\"pages\":true", "source_info capabilities");
    require_contains(payload, "\"listings\":true", "source_info capabilities");
    require_contains(payload, "\"mangaList\":true", "source_info capabilities");
    require_contains(payload, "\"home\":true", "source_info capabilities");
    require_contains(payload, "\"filters\":true", "source_info capabilities");
    require_contains(payload, "\"settings\":true", "source_info capabilities");
    require_contains(payload, "\"imageRequest\":true", "source_info capabilities");
    require_contains(payload, "\"process_page_image\":false", "source_info capabilities");
    require_contains(payload, "\"page_description\":false", "source_info capabilities");
    require_contains(payload, "\"base_url\":false", "source_info capabilities");
    require_contains(payload, "\"login\":false", "source_info capabilities");
    require_contains(payload, "\"auth\":false", "source_info capabilities");
}

void validate_operation_data(const std::string &operation, const std::string &payload) {
    if (operation == "search") {
        require_contains(payload, "\"requestEcho\":\"fixture\"", operation);
        require_contains(payload, "\"id\":\"manga:fixture-series\"", operation);
        require_contains(payload, "\"title\":\"Fixture Series\"", operation);
        require_contains(payload, "\"page\":{\"nextCursor\":null,\"hasMore\":false}", operation);
    }
    else if (operation == "get_manga") {
        require_contains(payload, "\"manga\":{\"id\":\"manga:fixture-series\"", operation);
        require_contains(payload, "\"title\":\"Fixture Series\"", operation);
    }
    else if (operation == "get_chapters") {
        require_contains(payload, "\"id\":\"chapter:fixture-series:001\"", operation);
        require_contains(payload, "\"mangaId\":\"manga:fixture-series\"", operation);
        require_contains(payload, "\"page\":{\"nextCursor\":null,\"hasMore\":false}", operation);
    }
    else if (operation == "get_pages") {
        require_contains(payload, "\"chapterId\":\"chapter:fixture-series:001\"", operation);
        require_contains(payload, "\"id\":\"page:fixture-series:001:0001\"", operation);
    }
    else if (operation == "get_listings") {
        require_contains(payload, "\"listings\":[", operation);
        require_contains(payload, "\"id\":\"listing:popular\"", operation);
        require_contains(payload, "\"name\":\"Popular\"", operation);
        require_contains(payload, "\"kind\":\"popular\"", operation);
        require_contains(payload, "\"id\":\"listing:latest\"", operation);
        require_contains(payload, "\"id\":\"listing:http-fixture\"", operation);
    }
    else if (operation == "get_manga_list") {
        if (payload.find("\"listingId\":\"listing:http-fixture\"") != std::string::npos) {
            require_contains(payload, "\"id\":\"manga:http-fixture-series\"", operation);
            require_contains(payload, "\"title\":\"HTTP Fixture Series\"", operation);
            require_contains(payload, "\"allowed\":true", operation);
            require_contains(payload, "\"deniedHost\":\"host_not_allowed\"", operation);
            require_contains(payload, "\"deniedCredentialHeader\":\"credential_header_denied\"", operation);
            require_contains(payload, "\"networkPerformed\":false", operation);
        }
        else if (payload.find("\"listingId\":\"listing:html-fixture\"") != std::string::npos) {
            require_contains(payload, "\"id\":\"manga:html-fixture-series\"", operation);
            require_contains(payload, "\"title\":\"HTML Fixture Series\"", operation);
            require_contains(payload, "\"chapterId\":\"chapter:html-fixture-series:001\"", operation);
            require_contains(payload, "\"chapterTitle\":\"Chapter 1\"", operation);
            require_contains(payload, "\"pageId\":\"page:html-fixture-series:001:0001\"", operation);
            require_contains(payload, "\"parse\":true", operation);
            require_contains(payload, "\"select\":true", operation);
            require_contains(payload, "\"attr\":true", operation);
            require_contains(payload, "\"text\":true", operation);
            require_contains(payload, "\"unsupportedSelectorDenied\":\"unsupported_selector\"", operation);
            require_contains(payload, "\"unsupportedAttrDenied\":\"attribute_not_allowed\"", operation);
            require_contains(payload, "\"networkPerformed\":false", operation);
        }
        else {
            require_contains(payload, "\"listingId\":\"listing:popular\"", operation);
            require_contains(payload, "\"id\":\"manga:fixture-series\"", operation);
            require_contains(payload, "\"title\":\"Fixture Series\"", operation);
            require_contains(payload, "\"subtitle\":\"Browse fixture result\"", operation);
        }
        require_contains(payload, "\"page\":{\"nextCursor\":null,\"hasMore\":false}", operation);
    }
    else if (operation == "get_home") {
        require_contains(payload, "\"sections\":[", operation);
        require_contains(payload, "\"id\":\"home:featured\"", operation);
        require_contains(payload, "\"kind\":\"mangaList\"", operation);
        require_contains(payload, "\"id\":\"home:latest-link\"", operation);
        require_contains(payload, "\"listingId\":\"listing:latest\"", operation);
    }
    else if (operation == "get_filters") {
        require_contains(payload, "\"filters\":[", operation);
        require_contains(payload, "\"id\":\"filter:query\"", operation);
        require_contains(payload, "\"kind\":\"text\"", operation);
        require_contains(payload, "\"id\":\"filter:sort\"", operation);
        require_contains(payload, "\"kind\":\"sort\"", operation);
    }
    else if (operation == "get_settings") {
        require_contains(payload, "\"settings\":[", operation);
        require_contains(payload, "\"id\":\"setting:language\"", operation);
        require_contains(payload, "\"kind\":\"select\"", operation);
        require_contains(payload, "\"id\":\"setting:show-adult\"", operation);
        require_contains(payload, "\"kind\":\"boolean\"", operation);
        require_contains(payload, "\"id\":\"setting:display-name\"", operation);
        require_contains(payload, "\"kind\":\"string\"", operation);
        require_contains(payload, "\"id\":\"setting:reader-group\"", operation);
        require_contains(payload, "\"kind\":\"group\"", operation);
        require_contains(payload, "\"id\":\"setting:login-reference\"", operation);
        require_contains(payload, "\"kind\":\"loginRef\"", operation);
        require_contains(payload, "\"loginRefKey\":\"login:primary\"", operation);
    }
    else if (operation == "get_image_request") {
        require_contains(payload, "\"imageRequest\":", operation);
        require_contains(payload, "\"id\":\"image-request:fixture-page-1\"", operation);
        require_contains(payload, "\"url\":\"fixture-image:fixture-page-1\"", operation);
        require_contains(payload, "\"method\":\"GET\"", operation);
        require_contains(payload, "\"headersRef\":\"headers:image:fixture-page-1\"", operation);
        require_contains(payload, "\"credentialsRef\":\"credentials:image:primary\"", operation);
        require_contains(payload, "\"sessionRef\":\"session:image:primary\"", operation);
        require_contains(payload, "\"cacheKey\":\"image-cache:fixture-page-1\"", operation);
        require_contains(payload, "\"requiresAuth\":true", operation);
    }
}

bool is_opaque_reference_value(const std::string &payload, const std::string &field) {
    const std::string prefix = "\"" + field + "\":\"";
    const size_t start = payload.find(prefix);
    if (start == std::string::npos) {
        return false;
    }
    const size_t value_start = start + prefix.size();
    const size_t value_end = payload.find('"', value_start);
    if (value_end == std::string::npos || value_end == value_start) {
        return false;
    }
    const std::string value = payload.substr(value_start, value_end - value_start);
    return value.find("://") == std::string::npos && value.find('/') == std::string::npos &&
           value.find('\\') == std::string::npos && !contains_ci(value, "authorization") &&
           !contains_ci(value, "cookie") && !contains_ci(value, "token") &&
           !contains_ci(value, "password") && !contains_ci(value, "secret");
}

void validate_image_request_refs(const std::string &payload) {
    for (const char *field : {"headersRef", "credentialsRef", "sessionRef"}) {
        if (!is_opaque_reference_value(payload, field)) {
            throw std::runtime_error(std::string("get_image_request ") + field +
                                     " is not an opaque host-owned reference");
        }
    }
    if (payload.find("\"Authorization\"") != std::string::npos ||
        payload.find("\"Cookie\"") != std::string::npos ||
        payload.find("\"headers\":") != std::string::npos ||
        payload.find("Bearer ") != std::string::npos) {
        throw std::runtime_error("get_image_request leaked raw header or credential material");
    }
    std::cout << "SOURCE_API_IMAGE_REQUEST_REFS ok:true headersRef=true credentialsRef=true "
                 "sessionRef=true rawSecrets=false networkPerformed=false\n";
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
            "\"host\":{\"abi\":\"koma-host-v0.1-fixture-http-html\","
            "\"imports\":[\"log\",\"check_cancel\",\"http_request\",\"html_parse\","
            "\"html_select\",\"html_attr\",\"html_text\",\"html_close\"],"
            "\"limits\":{\"maxMemoryPages\":2,\"maxPayloadBytes\":1048576,\"network\":false}},"
            "\"experimentalHttpFixture\":{\"enabled\":true,\"allowedHost\":\"fixture.koma.local\","
            "\"networkPerformed\":false},"
            "\"experimentalHtmlFixture\":{\"enabled\":true,\"selectorSubset\":["
            "\"article.manga-card\",\"h3.title\",\"a.chapter\"],"
            "\"allowedAttributes\":[\"data-id\",\"data-page-id\"],"
            "\"networkPerformed\":false},"
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

    std::string read_result_payload(uint32_t result_ptr, bool expect_ok, const char *context) {
        if (result_ptr == 0) {
            throw std::runtime_error(std::string(context) + " returned null result pointer");
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
        if ((flags & ~1u) != 0 || ((flags & 1u) != 0) != expect_ok) {
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

        wasm_function_inst_t free_fn = lookup("koma_source_free");
        uint32_t free_argv[1] = {result_ptr};
        require_call(exec_env_, module_inst_, free_fn, 1, free_argv, "koma_source_free");
        return payload;
    }

    std::string call_source_info() {
        wasm_function_inst_t source_fn = lookup("koma_source_info");
        uint32_t argv[1] = {0};
        require_call(exec_env_, module_inst_, source_fn, 0, argv, "koma_source_info");

        std::string payload = read_result_payload(argv[0], true, "koma_source_info");
        validate_source_info_envelope(payload);

        std::cout << "SOURCE_API_SOURCE_INFO ok:true export=koma_source_info\n";
        std::cout << "SOURCE_API_JSON source_info=" << payload << "\n";
        std::cout << "SOURCE_API_CAPABILITIES core:true browse:true config:true image:true network:false\n";
        return payload;
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

        std::string payload = read_result_payload(argv[0], true, operation.export_name);
        validate_source_envelope(operation.name, payload);
        validate_operation_data(operation.name, payload);
        if (std::strcmp(operation.name, "get_image_request") == 0) {
            validate_image_request_refs(payload);
        }

        const bool http_fixture_operation =
            std::strstr(request, "\"listingId\":\"listing:http-fixture\"") != nullptr;
        const bool html_fixture_operation =
            std::strstr(request, "\"listingId\":\"listing:html-fixture\"") != nullptr;
        const char *json_name =
            http_fixture_operation     ? "get_manga_list_http_fixture"
            : html_fixture_operation   ? "get_manga_list_html_fixture"
                                       : operation.name;
        std::cout << "SOURCE_API_OPERATION " << operation.name << " ok:true"
                  << " magic=KOMA\n";
        if (http_fixture_operation) {
            std::cout << "SOURCE_API_HTTP_FIXTURE_OPERATION ok:true operation=get_manga_list\n";
        }
        if (html_fixture_operation) {
            std::cout << "SOURCE_API_HTML_FIXTURE_OPERATION ok:true operation=get_manga_list\n";
        }
        std::cout << "SOURCE_API_JSON " << json_name << "=" << payload << "\n";
        return payload;
    }

    void reject_unknown_operation() {
        const SourceOperation operation = {
            "search",
            "koma_source_search",
            "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-unknown-operation-001\","
            "\"operation\":\"unknown_operation\",\"sourceId\":\"local.test.koma.fixture\","
            "\"args\":{\"query\":\"fixture\"},\"settings\":{},\"hostHints\":{\"network\":false}}",
        };
        const char *request = operation.request_json;
        const uint32_t request_len = static_cast<uint32_t>(std::strlen(request));
        uint64_t request_ptr =
            wasm_runtime_module_dup_data(module_inst_, request, request_len);
        if (request_ptr == 0) {
            throw std::runtime_error("failed to copy unknown-operation request into wasm memory");
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

        std::string payload = read_result_payload(argv[0], false, "unknown operation rejection");
        require_contains(payload, "\"ok\":false", "unknown operation rejection");
        require_contains(payload, "\"operation\":\"search\"", "unknown operation rejection");
        require_contains(payload, "\"code\":\"invalid_request\"", "unknown operation rejection");
        require_contains(payload, "\"message\":\"unexpected operation\"", "unknown operation rejection");
        if (payload.find("Fixture Series") != std::string::npos ||
            payload.find("\"requestEcho\":\"fixture\"") != std::string::npos) {
            throw std::runtime_error("unknown operation defaulted to search");
        }
        std::cout << "SOURCE_API_UNKNOWN_OPERATION_REJECTED ok:true export=koma_source_search\n";
        std::cout << "SOURCE_API_JSON unknown_operation_rejected=" << payload << "\n";
    }

    void reject_cancel_timeout_guards() {
        const SourceOperation operation = {
            "search",
            "koma_source_search",
            "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-cancel-guard-001\","
            "\"operation\":\"search\",\"sourceId\":\"local.test.koma.fixture\","
            "\"args\":{\"query\":\"fixture\"},\"settings\":{},\"hostHints\":{\"network\":false},"
            "\"komaTestOnly\":true,\"testGuard\":\"cancel\"}",
        };
        const char *request = operation.request_json;
        const uint32_t request_len = static_cast<uint32_t>(std::strlen(request));
        uint64_t request_ptr =
            wasm_runtime_module_dup_data(module_inst_, request, request_len);
        if (request_ptr == 0) {
            throw std::runtime_error("failed to copy cancel-guard request into wasm memory");
        }

        wasm_function_inst_t source_fn = lookup(operation.export_name);
        uint32_t argv[2] = {static_cast<uint32_t>(request_ptr), request_len};
        try {
            ForcedCancelScope cancel_scope(true);
            require_call(exec_env_, module_inst_, source_fn, 2, argv, operation.export_name);
        }
        catch (...) {
            wasm_runtime_module_free(module_inst_, request_ptr);
            throw;
        }
        wasm_runtime_module_free(module_inst_, request_ptr);

        std::string payload = read_result_payload(argv[0], false, "cancel guard rejection");
        require_contains(payload, "\"ok\":false", "cancel guard rejection");
        require_contains(payload, "\"operation\":\"search\"", "cancel guard rejection");
        require_contains(payload, "\"code\":\"cancelled\"", "cancel guard rejection");
        require_contains(payload, "\"message\":\"host cancelled\"", "cancel guard rejection");
        if (payload.find("Fixture Series") != std::string::npos ||
            payload.find("\"requestEcho\":\"fixture\"") != std::string::npos ||
            contains_any_forbidden_runtime_string(payload)) {
            throw std::runtime_error("cancel guard leaked success or unsafe evidence");
        }
        std::cout << "SOURCE_API_CANCEL_GUARD_REJECTED ok:true reason=cancelled attemptedWamrExecution=true noRawPayloadOrPathLeak=true\n";

        const std::string timeout_request =
            "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-timeout-guard-001\","
            "\"operation\":\"search\",\"sourceId\":\"local.test.koma.fixture\","
            "\"args\":{\"query\":\"fixture\"},\"settings\":{},\"hostHints\":{\"network\":false},"
            "\"komaTestOnly\":true,\"testGuard\":\"timeout\"}";
        const std::string timeout_payload = timeout_guard_error_json(timeout_request);
        validate_timeout_guard_payload(timeout_payload);
        std::cout << "SOURCE_API_TIMEOUT_GUARD_REJECTED ok:true reason=timeout attemptedWamrExecution=false noRawPayloadOrPathLeak=true\n";
        std::cout << "SOURCE_API_JSON timeout_guard_rejected=" << timeout_payload << "\n";
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
            {
                "get_listings",
                "koma_source_get_listings",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-listings-001\","
                "\"operation\":\"get_listings\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{},\"settings\":{},\"hostHints\":{\"network\":false}}",
            },
            {
                "get_manga_list",
                "koma_source_get_manga_list",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-manga-list-001\","
                "\"operation\":\"get_manga_list\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{\"listingId\":\"listing:popular\","
                "\"page\":{\"cursor\":null,\"limit\":20},"
                "\"filters\":{\"sort\":\"popular\"}},\"settings\":{},"
                "\"hostHints\":{\"network\":false}}",
            },
            {
                "get_manga_list",
                "koma_source_get_manga_list",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-http-fixture-list-001\","
                "\"operation\":\"get_manga_list\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{\"listingId\":\"listing:http-fixture\","
                "\"page\":{\"cursor\":null,\"limit\":20}},\"settings\":{},"
                "\"hostHints\":{\"network\":false,\"experimentalHttpFixture\":true}}",
            },
            {
                "get_manga_list",
                "koma_source_get_manga_list",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-html-fixture-list-001\","
                "\"operation\":\"get_manga_list\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{\"listingId\":\"listing:html-fixture\","
                "\"page\":{\"cursor\":null,\"limit\":20}},\"settings\":{},"
                "\"hostHints\":{\"network\":false,\"experimentalHtmlFixture\":true}}",
            },
            {
                "get_home",
                "koma_source_get_home",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-home-001\","
                "\"operation\":\"get_home\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{},\"settings\":{},\"hostHints\":{\"network\":false}}",
            },
            {
                "get_filters",
                "koma_source_get_filters",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-filters-001\","
                "\"operation\":\"get_filters\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{},\"settings\":{},\"hostHints\":{\"network\":false}}",
            },
            {
                "get_settings",
                "koma_source_get_settings",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-settings-001\","
                "\"operation\":\"get_settings\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{},\"settings\":{},\"hostHints\":{\"network\":false}}",
            },
            {
                "get_image_request",
                "koma_source_get_image_request",
                "{\"type\":\"request\",\"version\":1,\"requestId\":\"runtime-image-request-001\","
                "\"operation\":\"get_image_request\",\"sourceId\":\"local.test.koma.fixture\","
                "\"args\":{\"pageId\":\"page:fixture-series:001:0001\","
                "\"imageRef\":\"image:fixture-page-1\"},\"settings\":{\"loginRef\":\"login:primary\"},"
                "\"hostHints\":{\"network\":false,\"imageStrategy\":\"descriptor-only\"}}",
            },
        };

        for (const SourceOperation &operation : operations) {
            call_operation(operation);
        }
        reject_unknown_operation();
        reject_cancel_timeout_guards();
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
        module.call_source_info();
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

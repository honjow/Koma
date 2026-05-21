#include <stdint.h>

#define KOMA_MAGIC 0x4B4F4D41u
#define KOMA_HOST_LOG_INFO 1

__attribute__((import_module("koma_host"), import_name("log")))
void koma_host_log(uint32_t level, uint32_t message_ptr, uint32_t message_len);

__attribute__((import_module("koma_host"), import_name("check_cancel")))
int32_t koma_host_check_cancel(void);

extern unsigned char __heap_base;
static uint32_t bump = 0;
static uint32_t last_response = 0;

static uint32_t align8(uint32_t v) {
    return (v + 7u) & ~7u;
}

static void *koma_alloc(uint32_t size) {
    if (bump == 0) {
        bump = align8((uint32_t)(uintptr_t)&__heap_base);
    }
    uint32_t ptr = bump;
    bump = align8(bump + size);
    return (void *)(uintptr_t)ptr;
}

static uint32_t str_len(const char *s) {
    uint32_t n = 0;
    while (s[n] != 0) {
        n++;
    }
    return n;
}

static void mem_copy(uint8_t *dst, const char *src, uint32_t len) {
    for (uint32_t i = 0; i < len; i++) {
        dst[i] = (uint8_t)src[i];
    }
}

static int contains_bytes(const uint8_t *haystack, uint32_t haystack_len, const char *needle) {
    uint32_t needle_len = str_len(needle);
    if (needle_len == 0 || haystack_len < needle_len) {
        return 0;
    }

    for (uint32_t i = 0; i <= haystack_len - needle_len; i++) {
        uint32_t matched = 1;
        for (uint32_t j = 0; j < needle_len; j++) {
            if (haystack[i + j] != (uint8_t)needle[j]) {
                matched = 0;
                break;
            }
        }
        if (matched) {
            return 1;
        }
    }
    return 0;
}

static uint32_t make_result(const char *payload, uint32_t ok) {
    uint32_t len = str_len(payload);
    uint8_t *buf = (uint8_t *)koma_alloc(16u + len);
    uint32_t *header = (uint32_t *)(void *)buf;
    header[0] = KOMA_MAGIC;
    header[1] = ok ? 1u : 0u;
    header[2] = len;
    header[3] = 0u;
    mem_copy(buf + 16u, payload, len);
    last_response = (uint32_t)(uintptr_t)buf;
    return last_response;
}

__attribute__((export_name("add")))
int32_t add(int32_t a, int32_t b) {
    return a + b;
}

__attribute__((export_name("koma_source_init")))
int32_t koma_source_init(uint32_t manifest_ptr, uint32_t manifest_len) {
    (void)manifest_ptr;
    static const char message[] = "fixture init reached host imports";
    koma_host_log(KOMA_HOST_LOG_INFO, (uint32_t)(uintptr_t)message, sizeof(message) - 1u);
    if (koma_host_check_cancel() != 0) {
        return -2;
    }
    return manifest_len > 0 ? 0 : -1;
}

__attribute__((export_name("koma_source_search")))
uint32_t koma_source_search(uint32_t req_ptr, uint32_t req_len) {
    if (req_len == 0) {
        return make_result("{\"ok\":false,\"error\":{\"code\":\"BAD_REQUEST\",\"message\":\"empty request\"},\"warnings\":[]}", 0);
    }

    if (!contains_bytes((const uint8_t *)(uintptr_t)req_ptr, req_len, "\"query\":\"fixture\"")) {
        return make_result("{\"ok\":false,\"error\":{\"code\":\"BAD_REQUEST\",\"message\":\"expected fixture query\"},\"warnings\":[]}", 0);
    }

    if (koma_host_check_cancel() != 0) {
        return make_result("{\"ok\":false,\"error\":{\"code\":\"CANCELLED\",\"message\":\"host cancelled\"},\"warnings\":[]}", 0);
    }

    return make_result(
        "{\"ok\":true,\"data\":{\"requestEcho\":\"fixture\",\"items\":[{\"id\":\"fixture-series-1\",\"title\":\"Fixture Series\",\"subtitle\":\"WAMR ABI spike\",\"cover\":{\"url\":\"https://example.local/covers/fixture.jpg\",\"headersRef\":\"default\"}}],\"nextPage\":null},\"hostHints\":{\"abi\":\"koma-host-v0.1\",\"maxMemoryPages\":2,\"maxPayloadBytes\":1048576,\"network\":false},\"warnings\":[],\"elapsedMs\":0}",
        1);
}

__attribute__((export_name("koma_source_free")))
void koma_source_free(uint32_t result_ptr) {
    if (result_ptr == last_response) {
        last_response = 0;
    }
}

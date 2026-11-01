#include "image_processor_host.h"
#include "wasm_export.h"
#include <fstream>
#include <iostream>
#include <iterator>
#include <cstring>

std::vector<uint8_t> Read(const char *path)
{
    std::ifstream file(path, std::ios::binary);
    if (!file) throw std::runtime_error("input file unavailable");
    return {std::istreambuf_iterator<char>(file), std::istreambuf_iterator<char>()};
}
int main(int count, char **args)
{
    const bool inspect = count == 3 && std::strcmp(args[1], "--inspect") == 0;
    if (!inspect && count != 7) return 2;
    auto wasm = Read(args[inspect ? 2 : 1]);
    std::vector<uint8_t> heap(48u * 1024u * 1024u);
    RuntimeInitArgs init {};
    init.mem_alloc_type = Alloc_With_Pool;
    init.mem_alloc_option.pool.heap_buf = heap.data();
    init.mem_alloc_option.pool.heap_size = heap.size();
    if (!wasm_runtime_full_init(&init) || !koma::RegisterImageProcessorImports()) return 3;
    if (!wasm_runtime_init_thread_env()) return 4;
    if (inspect) {
        std::cout << "{\"error\":\"" << koma::InspectImageProcessor(wasm) << "\"}\n";
        wasm_runtime_destroy_thread_env();
        wasm_runtime_destroy();
        return 0;
    }
    auto pixels = Read(args[2]), configuration = Read(args[5]);
    auto result = koma::ExecuteImageProcessor(wasm, pixels.data(), pixels.size(), std::stoul(args[3]), std::stoul(args[4]),
        std::string(configuration.begin(), configuration.end()));
    if (result.changed) {
        std::ofstream file(args[6], std::ios::binary);
        file.write(reinterpret_cast<const char *>(result.pixels.data()), result.pixels.size());
    }
    std::cout << "{\"changed\":" << (result.changed ? "true" : "false") << ",\"width\":" << result.width
        << ",\"height\":" << result.height << ",\"error\":\"" << result.error << "\"}\n";
    wasm_runtime_destroy_thread_env();
    wasm_runtime_destroy();
    return 0;
}

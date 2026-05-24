cmake_minimum_required(VERSION 3.5.0)
project(KomaSourceRuntimeSample C CXX ASM)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

set(KOMA_SOURCE_RUNTIME_SOURCES
    source_runtime_sample.cpp
    wasm_runtime_adapter.cpp
    html_host.cpp
    http_host.cpp)

add_library(koma_source_runtime SHARED ${KOMA_SOURCE_RUNTIME_SOURCES})
target_compile_features(koma_source_runtime PRIVATE cxx_std_17)
target_include_directories(koma_source_runtime PRIVATE ${NATIVERENDER_ROOT_PATH})
target_link_libraries(koma_source_runtime PUBLIC libace_napi.z.so libhilog_ndk.z.so)

# Link native HTTP library (API 20+) if available
find_library(NET_HTTP_LIB net_http)
if(NET_HTTP_LIB)
    target_link_libraries(koma_source_runtime PUBLIC ${NET_HTTP_LIB})
endif()

if(DEFINED ENV{WAMR_ROOT_DIR} AND NOT DEFINED WAMR_ROOT_DIR)
    set(WAMR_ROOT_DIR "$ENV{WAMR_ROOT_DIR}")
endif()
if(NOT DEFINED WAMR_ROOT_DIR)
    set(WAMR_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/wasm-micro-runtime")
endif()

if(EXISTS "${WAMR_ROOT_DIR}/build-scripts/runtime_lib.cmake")
    find_program(KOMA_HOST_CLANG clang)
    find_program(KOMA_HOST_XXD xxd)

    if(NOT KOMA_HOST_XXD)
        message(FATAL_ERROR "xxd is required to generate source runtime wasm fixture header")
    endif()

    set(KOMA_FIXTURE_WASM_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/../resources/rawfile/test/rust_source_runtime_fixture.wasm)
    set(KOMA_GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
    set(KOMA_FIXTURE_HEADER ${KOMA_GENERATED_DIR}/source_runtime_fixture_wasm.h)

    add_custom_command(
        OUTPUT ${KOMA_FIXTURE_HEADER}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KOMA_GENERATED_DIR}
        COMMAND /bin/sh -c
            "${KOMA_HOST_XXD} -i -n kSourceRuntimeFixtureWasm ${KOMA_FIXTURE_WASM_SOURCE} > ${KOMA_FIXTURE_HEADER}.tmp"
        COMMAND /bin/sh -c
            "sed -e 's/unsigned char kSourceRuntimeFixtureWasm/static const unsigned char kSourceRuntimeFixtureWasm/' -e 's/unsigned int kSourceRuntimeFixtureWasm_len/static const unsigned int kSourceRuntimeFixtureWasmLen/' ${KOMA_FIXTURE_HEADER}.tmp > ${KOMA_FIXTURE_HEADER}"
        DEPENDS ${KOMA_FIXTURE_WASM_SOURCE}
        VERBATIM)

    add_custom_target(koma_source_runtime_fixture DEPENDS ${KOMA_FIXTURE_HEADER})
    add_dependencies(koma_source_runtime koma_source_runtime_fixture)
    target_include_directories(koma_source_runtime PRIVATE ${KOMA_GENERATED_DIR})

    # --- lexbor (HTML parser with CSS selectors) ---
    set(LEXBOR_ROOT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/lexbor)
    set(LEXBOR_BUILD_SHARED OFF CACHE BOOL "" FORCE)
    set(LEXBOR_BUILD_STATIC ON CACHE BOOL "" FORCE)
    set(LEXBOR_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(LEXBOR_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(LEXBOR_BUILD_TESTS_CPP OFF CACHE BOOL "" FORCE)
    set(LEXBOR_BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
    set(LEXBOR_BUILD_UTILS OFF CACHE BOOL "" FORCE)
    set(LEXBOR_INSTALL_HEADERS OFF CACHE BOOL "" FORCE)
    add_subdirectory(${LEXBOR_ROOT_DIR} ${CMAKE_CURRENT_BINARY_DIR}/lexbor EXCLUDE_FROM_ALL)
    target_include_directories(koma_source_runtime PRIVATE ${LEXBOR_ROOT_DIR}/source)
    target_link_libraries(koma_source_runtime PRIVATE lexbor_static)
    target_compile_definitions(koma_source_runtime PRIVATE KOMA_ENABLE_LEXBOR=1)

    # --- WAMR ---
    set(WAMR_BUILD_PLATFORM "linux")
    if(NOT DEFINED WAMR_BUILD_TARGET)
        if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)")
            set(WAMR_BUILD_TARGET "AARCH64")
        elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
            set(WAMR_BUILD_TARGET "X86_64")
        else()
            set(WAMR_BUILD_TARGET "X86_32")
        endif()
    endif()
    set(WAMR_BUILD_INTERP 1)
    set(WAMR_BUILD_AOT 0)
    set(WAMR_BUILD_JIT 0)
    set(WAMR_BUILD_FAST_JIT 0)
    set(WAMR_BUILD_LIBC_BUILTIN 1)
    set(WAMR_BUILD_LIBC_WASI 0)
    set(WAMR_BUILD_MULTI_MODULE 0)
    set(WAMR_BUILD_MINI_LOADER 0)
    # Rust-generated URL-installed .koma source wasm packages require reference types.
    set(WAMR_BUILD_REF_TYPES 1)
    set(WAMR_BUILD_SIMD 0)
    set(WAMR_BUILD_SHARED_MEMORY 0)
    set(WAMR_BUILD_THREAD_MGR 0)
    set(WAMR_BUILD_LIB_PTHREAD 0)
    set(WAMR_BUILD_BULK_MEMORY 1)
    set(WAMR_DISABLE_HW_BOUND_CHECK 1)

    include(${WAMR_ROOT_DIR}/build-scripts/runtime_lib.cmake)
    add_library(koma_wamr_runtime STATIC ${WAMR_RUNTIME_LIB_SOURCE})
    target_include_directories(koma_wamr_runtime PUBLIC ${WAMR_ROOT_DIR}/core/iwasm/include)
    target_compile_features(koma_wamr_runtime PRIVATE c_std_99)
    target_compile_definitions(koma_source_runtime PRIVATE KOMA_ENABLE_WAMR=1)
    target_link_libraries(koma_source_runtime PRIVATE koma_wamr_runtime)
else()
    message(FATAL_ERROR "WAMR runtime source not found at ${WAMR_ROOT_DIR}")
endif()

cmake_minimum_required(VERSION 3.5.0)
project(KomaSourceRuntimeSample C CXX ASM)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

set(KOMA_SOURCE_RUNTIME_SOURCES
    source_runtime_sample.cpp
    wasm_runtime_adapter.cpp)

add_library(koma_source_runtime SHARED ${KOMA_SOURCE_RUNTIME_SOURCES})
target_compile_features(koma_source_runtime PRIVATE cxx_std_17)
target_include_directories(koma_source_runtime PRIVATE ${NATIVERENDER_ROOT_PATH})
target_link_libraries(koma_source_runtime PUBLIC libace_napi.z.so libhilog_ndk.z.so)

if(DEFINED ENV{WAMR_ROOT_DIR} AND NOT DEFINED WAMR_ROOT_DIR)
    set(WAMR_ROOT_DIR "$ENV{WAMR_ROOT_DIR}")
endif()

if(DEFINED WAMR_ROOT_DIR AND EXISTS "${WAMR_ROOT_DIR}/build-scripts/runtime_lib.cmake")
    find_program(KOMA_HOST_CLANG clang)
    find_program(KOMA_HOST_XXD xxd)

    if(NOT KOMA_HOST_CLANG)
        message(FATAL_ERROR "clang is required to generate source runtime wasm fixture")
    endif()
    if(NOT KOMA_HOST_XXD)
        message(FATAL_ERROR "xxd is required to generate source runtime wasm fixture header")
    endif()

    set(KOMA_FIXTURE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR}/../../../../tools/wasm-runtime-spike/wasm/source_fixture.c)
    set(KOMA_GENERATED_DIR ${CMAKE_CURRENT_BINARY_DIR}/generated)
    set(KOMA_FIXTURE_WASM ${KOMA_GENERATED_DIR}/source_runtime_fixture.wasm)
    set(KOMA_FIXTURE_HEADER ${KOMA_GENERATED_DIR}/source_runtime_fixture_wasm.h)

    add_custom_command(
        OUTPUT ${KOMA_FIXTURE_HEADER}
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KOMA_GENERATED_DIR}
        COMMAND ${KOMA_HOST_CLANG} --target=wasm32 -O2 -nostdlib
            -Wl,--no-entry
            -Wl,--export=add
            -Wl,--export=koma_source_init
            -Wl,--export=koma_source_search
            -Wl,--export=koma_source_free
            -Wl,--allow-undefined
            -Wl,--export-memory
            -Wl,--initial-memory=131072
            -Wl,--max-memory=131072
            -o ${KOMA_FIXTURE_WASM}
            ${KOMA_FIXTURE_SOURCE}
        COMMAND /bin/sh -c
            "${KOMA_HOST_XXD} -i -n kSourceRuntimeFixtureWasm ${KOMA_FIXTURE_WASM} > ${KOMA_FIXTURE_HEADER}.tmp"
        COMMAND /bin/sh -c
            "sed -e 's/unsigned char kSourceRuntimeFixtureWasm/static const unsigned char kSourceRuntimeFixtureWasm/' -e 's/unsigned int kSourceRuntimeFixtureWasm_len/static const unsigned int kSourceRuntimeFixtureWasmLen/' ${KOMA_FIXTURE_HEADER}.tmp > ${KOMA_FIXTURE_HEADER}"
        DEPENDS ${KOMA_FIXTURE_SOURCE}
        VERBATIM)

    add_custom_target(koma_source_runtime_fixture DEPENDS ${KOMA_FIXTURE_HEADER})
    add_dependencies(koma_source_runtime koma_source_runtime_fixture)
    target_include_directories(koma_source_runtime PRIVATE ${KOMA_GENERATED_DIR})

    set(WAMR_BUILD_PLATFORM "linux")
    set(WAMR_BUILD_TARGET "AARCH64")
    set(WAMR_BUILD_INTERP 1)
    set(WAMR_BUILD_AOT 0)
    set(WAMR_BUILD_JIT 0)
    set(WAMR_BUILD_FAST_JIT 0)
    set(WAMR_BUILD_LIBC_BUILTIN 1)
    set(WAMR_BUILD_LIBC_WASI 0)
    set(WAMR_BUILD_MULTI_MODULE 0)
    set(WAMR_BUILD_MINI_LOADER 0)
    set(WAMR_BUILD_REF_TYPES 0)
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
    message(STATUS "WAMR_ROOT_DIR not set; koma_source_runtime builds WAMR unavailable response path")
endif()

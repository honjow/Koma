cmake_minimum_required(VERSION 3.16)
project(koma_wasm_runtime_spike C CXX)

if(NOT DEFINED WAMR_ROOT_DIR)
  message(FATAL_ERROR "Set WAMR_ROOT_DIR to a wasm-micro-runtime checkout")
endif()

string(TOLOWER ${CMAKE_HOST_SYSTEM_NAME} WAMR_BUILD_PLATFORM)

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
set(WAMR_BUILD_REF_TYPES 0)
set(WAMR_BUILD_SIMD 0)
set(WAMR_BUILD_SHARED_MEMORY 0)
set(WAMR_BUILD_THREAD_MGR 0)
set(WAMR_BUILD_LIB_PTHREAD 0)
set(WAMR_BUILD_BULK_MEMORY 1)

include(${WAMR_ROOT_DIR}/build-scripts/runtime_lib.cmake)

add_library(vmlib STATIC ${WAMR_RUNTIME_LIB_SOURCE})
target_include_directories(vmlib PUBLIC ${WAMR_ROOT_DIR}/core/iwasm/include)

target_compile_features(vmlib PRIVATE c_std_99)

target_compile_options(vmlib PRIVATE -Wall -Wextra)

add_executable(koma_wamr_spike host_runner.cpp)
target_compile_features(koma_wamr_spike PRIVATE cxx_std_17)
target_compile_options(koma_wamr_spike PRIVATE -Wall -Wextra -Wpedantic)
target_link_libraries(koma_wamr_spike PRIVATE vmlib pthread m dl)

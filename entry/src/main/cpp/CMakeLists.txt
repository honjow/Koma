cmake_minimum_required(VERSION 3.5.0)
project(KomaSourceRuntimeSample)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

add_library(koma_source_runtime SHARED source_runtime_sample.cpp)
target_include_directories(koma_source_runtime PRIVATE ${NATIVERENDER_ROOT_PATH})
target_link_libraries(koma_source_runtime PUBLIC libace_napi.z.so)

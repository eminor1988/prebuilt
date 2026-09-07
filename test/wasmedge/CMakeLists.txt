cmake_minimum_required(VERSION 3.20)
project(test-wasmedge LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(WASMEDGE_DIR "" CACHE PATH "Path to WasmEdge install prefix (contains include/wasmedge/ and lib/)")

if(NOT WASMEDGE_DIR OR NOT EXISTS "${WASMEDGE_DIR}/include/wasmedge/wasmedge.h")
    message(FATAL_ERROR "WASMEDGE_DIR must be set to a valid WasmEdge install prefix")
endif()

add_executable(test_wasm test_wasm.cpp)
target_include_directories(test_wasm PRIVATE "${WASMEDGE_DIR}/include")
target_link_directories(test_wasm PRIVATE "${WASMEDGE_DIR}/lib")

if(WIN32)
    target_link_libraries(test_wasm PRIVATE wasmedge)
    target_link_options(test_wasm PRIVATE -static -static-libgcc -static-libstdc++ -fuse-ld=lld)
else()
    target_link_libraries(test_wasm PRIVATE wasmedge c++)
    target_link_options(test_wasm PRIVATE -fuse-ld=lld -static)
endif()

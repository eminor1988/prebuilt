cmake_minimum_required(VERSION 3.20)
project(test-libuv LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(LIBUV_DIR "" CACHE PATH "Path to libuv install prefix (contains include/uv.h and lib/)")

if(NOT LIBUV_DIR OR NOT EXISTS "${LIBUV_DIR}/include/uv.h")
    message(FATAL_ERROR "LIBUV_DIR must be set to a valid libuv install prefix")
endif()

add_executable(test_libuv test_libuv.cpp)
target_include_directories(test_libuv PRIVATE "${LIBUV_DIR}/include")
target_link_directories(test_libuv PRIVATE "${LIBUV_DIR}/lib")

if(WIN32)
    target_link_libraries(test_libuv PRIVATE uv ws2_32 kernel32 advapi32 userenv iphlpapi user32)
    target_link_options(test_libuv PRIVATE -static -static-libgcc -static-libstdc++)
else()
    target_link_libraries(test_libuv PRIVATE uv pthread)
endif()

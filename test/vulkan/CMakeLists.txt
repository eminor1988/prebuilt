cmake_minimum_required(VERSION 3.20)
project(test-vulkan LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(VULKAN_HEADERS_DIR "" CACHE PATH "Path to Vulkan-Headers (contains include/vulkan/)")
set(VULKAN_LOADER_DIR "" CACHE PATH "Path to Vulkan-Loader install prefix (contains lib/)")

if(NOT VULKAN_HEADERS_DIR OR NOT EXISTS "${VULKAN_HEADERS_DIR}/include/vulkan/vulkan.h")
    message(FATAL_ERROR "VULKAN_HEADERS_DIR must be set to Vulkan-Headers directory")
endif()

if(NOT VULKAN_LOADER_DIR OR NOT EXISTS "${VULKAN_LOADER_DIR}/lib")
    message(FATAL_ERROR "VULKAN_LOADER_DIR must be set to Vulkan-Loader install prefix")
endif()

add_executable(test_vulkan test_vulkan.cpp)
target_include_directories(test_vulkan PRIVATE "${VULKAN_HEADERS_DIR}/include")
target_link_directories(test_vulkan PRIVATE "${VULKAN_LOADER_DIR}/lib")

if(WIN32)
    target_link_libraries(test_vulkan PRIVATE vulkan-1)
    target_link_options(test_vulkan PRIVATE -static -static-libgcc -static-libstdc++)
else()
    target_link_libraries(test_vulkan PRIVATE vulkan)
endif()

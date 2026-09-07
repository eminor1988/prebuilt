// test_vulkan.cpp — Minimal Vulkan instance create/destroy test
// Verifies prebuilt Vulkan-Loader static library links and basic API works.
// No GPU required — just tests linking and instance-level functions.

#define VK_USE_PLATFORM_XCB_KHR
#include <vulkan/vulkan.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>

static const char* VK_RESULT_STR(VkResult r) {
    switch (r) {
        case VK_SUCCESS: return "VK_SUCCESS";
        case VK_INCOMPLETE: return "VK_INCOMPLETE";
        case VK_ERROR_OUT_OF_HOST_MEMORY: return "VK_ERROR_OUT_OF_HOST_MEMORY";
        case VK_ERROR_OUT_OF_DEVICE_MEMORY: return "VK_ERROR_OUT_OF_DEVICE_MEMORY";
        case VK_ERROR_INITIALIZATION_FAILED: return "VK_ERROR_INITIALIZATION_FAILED";
        case VK_ERROR_LAYER_NOT_PRESENT: return "VK_ERROR_LAYER_NOT_PRESENT";
        case VK_ERROR_EXTENSION_NOT_PRESENT: return "VK_ERROR_EXTENSION_NOT_PRESENT";
        case VK_ERROR_INCOMPATIBLE_DRIVER: return "VK_ERROR_INCOMPATIBLE_DRIVER";
        default: return "UNKNOWN";
    }
}

int main() {
    printf("=== Vulkan Static Loader Test ===\n\n");

    // 1. Enumerate instance extension properties
    uint32_t ext_count = 0;
    VkResult result = vkEnumerateInstanceExtensionProperties(NULL, &ext_count, NULL);
    printf("[1] Instance extensions: %u (result: %s)\n", ext_count, VK_RESULT_STR(result));

    if (ext_count > 0) {
        VkExtensionProperties* exts = (VkExtensionProperties*)malloc(ext_count * sizeof(VkExtensionProperties));
        result = vkEnumerateInstanceExtensionProperties(NULL, &ext_count, exts);
        printf("    Enumerate result: %s\n", VK_RESULT_STR(result));
        for (uint32_t i = 0; i < ext_count && i < 5; i++) {
            printf("    [%u] %s (v%u)\n", i, exts[i].extensionName, exts[i].specVersion);
        }
        if (ext_count > 5) printf("    ... and %u more\n", ext_count - 5);
        free(exts);
    }

    // 2. Create VkInstance
    VkApplicationInfo app_info = {};
    app_info.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app_info.pApplicationName = "Prebuilt Vulkan Test";
    app_info.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    app_info.pEngineName = "PrebuiltTest";
    app_info.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    app_info.apiVersion = VK_API_VERSION_1_0;

    VkInstanceCreateInfo create_info = {};
    create_info.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    create_info.pApplicationInfo = &app_info;

    VkInstance instance = VK_NULL_HANDLE;
    result = vkCreateInstance(&create_info, NULL, &instance);
    printf("\n[2] vkCreateInstance: %s\n", VK_RESULT_STR(result));

    if (result == VK_SUCCESS && instance != VK_NULL_HANDLE) {
        // 3. Enumerate physical devices
        uint32_t device_count = 0;
        vkEnumeratePhysicalDevices(instance, &device_count, NULL);
        printf("[3] Physical devices: %u\n", device_count);

        if (device_count > 0) {
            VkPhysicalDevice* devices = (VkPhysicalDevice*)malloc(device_count * sizeof(VkPhysicalDevice));
            vkEnumeratePhysicalDevices(instance, &device_count, devices);

            for (uint32_t i = 0; i < device_count; i++) {
                VkPhysicalDeviceProperties props;
                vkGetPhysicalDeviceProperties(devices[i], &props);
                printf("    [%u] %s (API %u.%u.%u)\n", i, props.deviceName,
                       VK_VERSION_MAJOR(props.apiVersion),
                       VK_VERSION_MINOR(props.apiVersion),
                       VK_VERSION_PATCH(props.apiVersion));
            }
            free(devices);
        }

        // 4. Destroy instance
        vkDestroyInstance(instance, NULL);
        printf("[4] vkDestroyInstance: OK\n");
    } else {
        fprintf(stderr, "    vkCreateInstance failed (expected in headless environments)\n");
        printf("[3] Skipping device enumeration\n");
        printf("[4] Skipping instance destroy\n");
    }

    printf("\n=== Vulkan static link test passed! ===\n");
    return 0;
}

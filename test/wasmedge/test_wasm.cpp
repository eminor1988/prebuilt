// test_wasm.cpp — WasmEdge WASM execution test
// Verifies prebuilt WasmEdge static library links and executes WASM correctly.

#include <wasmedge/wasmedge.h>
#include <cstdio>
#include <cstdlib>

int main() {
    printf("=== WasmEdge Static Library Test ===\n\n");

    // 1. Create VM context with default config
    printf("[1] Creating WasmEdge VM context...\n");
    WasmEdge_ConfigureContext *conf = WasmEdge_ConfigureCreate();
    WasmEdge_VMContext *vm = WasmEdge_VMCreate(conf, NULL);
    if (vm == NULL) {
        fprintf(stderr, "  Failed to create VM context\n");
        WasmEdge_ConfigureDelete(conf);
        return 1;
    }
    printf("  VM context created successfully\n");

    // 2. Load and run hello.wasm
    printf("[2] Loading hello.wasm...\n");
    WasmEdge_String func_name = WasmEdge_StringCreateByCString("main");
    WasmEdge_Value results[1];

    WasmEdge_Result res = WasmEdge_VMRunWasmFile(vm, "hello.wasm", func_name, results, 1);

    if (!WasmEdge_ResultOK(res)) {
        char msg[256];
        WasmEdge_ResultGetMessage(res, msg, sizeof(msg));
        fprintf(stderr, "  Run failed: %s\n", msg);
        WasmEdge_StringDelete(func_name);
        WasmEdge_VMDelete(vm);
        WasmEdge_ConfigureDelete(conf);
        return 1;
    }

    int32_t val = WasmEdge_ValueGetI32(results[0]);
    printf("  Execution result: %d\n", val);

    // 3. Verify result
    printf("[3] Verifying result...\n");
    if (val == 42) {
        printf("  Expected 42, got %d — PASS\n", val);
    } else {
        fprintf(stderr, "  Expected 42, got %d — FAIL\n", val);
        WasmEdge_StringDelete(func_name);
        WasmEdge_VMDelete(vm);
        WasmEdge_ConfigureDelete(conf);
        return 1;
    }

    // 4. Cleanup
    printf("[4] Cleaning up...\n");
    WasmEdge_StringDelete(func_name);
    WasmEdge_VMDelete(vm);
    WasmEdge_ConfigureDelete(conf);
    printf("  Resources released\n");

    printf("\n=== All WasmEdge tests passed! ===\n");
    return 0;
}

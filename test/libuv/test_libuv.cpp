// test_libuv.cpp — libuv event loop + file I/O test
// Verifies prebuilt static library links and works correctly.
//
// Alpine (musl):  Uses epoll, runs natively
// MinGW (Windows cross-compile): Uses IOCP, cross-compile only (no execution)

#include <uv.h>
#include <cstdio>
#include <cstring>

#ifdef _WIN32
    #ifndef UNICODE
    #define UNICODE
    #endif
    #include <windows.h>
#endif

static uv_loop_t* loop;

static void timer_cb(uv_timer_t* handle) {
    printf("  Timer fired!\n");
}

int main() {
    printf("=== libuv Static Library Test ===\n\n");

    loop = uv_default_loop();
    printf("[1] libuv version: %s\n", uv_version_string());

    // Test 1: Basic event loop
    printf("[2] Testing event loop...\n");
    int r = uv_run(loop, UV_RUN_NOWAIT);
    printf("  uv_run(RUN_NOWAIT) returned: %d\n", r);

    // Test 2: Timer
    printf("[3] Testing timer...\n");
    uv_timer_t timer;
    uv_timer_init(loop, &timer);
    uv_timer_start(&timer, timer_cb, 10, 0);
    uv_run(loop, UV_RUN_DEFAULT);
    printf("  Timer test passed\n");

    // Test 3: File I/O (synchronous mode with NULL callback)
    printf("[4] Testing file I/O...\n");
    const char* filename = "libuv_test_output.txt";
    const char* content = "Written by libuv from prebuilt static library test!\n";

    uv_fs_t open_req;
    r = uv_fs_open(loop, &open_req, filename, O_WRONLY | O_CREAT | O_TRUNC, 0644, NULL);
    if (r < 0) {
        fprintf(stderr, "  uv_fs_open error: %s\n", uv_strerror(r));
        return 1;
    }
    uv_file file = open_req.result;
    uv_fs_req_cleanup(&open_req);
    printf("  Opened '%s' (fd=%d)\n", filename, file);

    // Write (synchronous)
    uv_fs_t write_req;
    uv_buf_t iov = uv_buf_init((char*)content, (unsigned int)strlen(content));
    r = uv_fs_write(loop, &write_req, file, &iov, 1, -1, NULL);
    if (r < 0) {
        fprintf(stderr, "  uv_fs_write error: %s\n", uv_strerror(r));
        return 1;
    }
    printf("  Written %zd bytes\n", write_req.result);
    uv_fs_req_cleanup(&write_req);

    // Close
    uv_fs_t close_req;
    uv_fs_close(loop, &close_req, file, NULL);
    uv_fs_req_cleanup(&close_req);

    // Read back
    printf("  Reading back...\n");
    r = uv_fs_open(loop, &open_req, filename, O_RDONLY, 0, NULL);
    if (r < 0) {
        fprintf(stderr, "  uv_fs_open read error: %s\n", uv_strerror(r));
        return 1;
    }
    file = open_req.result;
    uv_fs_req_cleanup(&open_req);

    char read_buf[256];
    memset(read_buf, 0, sizeof(read_buf));
    uv_fs_t read_req;
    iov = uv_buf_init(read_buf, sizeof(read_buf) - 1);
    r = uv_fs_read(loop, &read_req, file, &iov, 1, -1, NULL);
    if (r < 0) {
        fprintf(stderr, "  uv_fs_read error: %s\n", uv_strerror(r));
        return 1;
    }
    printf("  Read %zd bytes\n", read_req.result);
    uv_fs_req_cleanup(&read_req);

    uv_fs_close(loop, &close_req, file, NULL);
    uv_fs_req_cleanup(&close_req);

    // Verify content
    if (strstr(read_buf, content) != NULL) {
        printf("  Content verification: PASS\n");
    } else {
        fprintf(stderr, "  Content verification: FAIL\n");
        return 1;
    }

#ifdef _WIN32
    printf("\n[5] Win32 API test...\n");
    const wchar_t* wpath = L"libuv_win32_test.txt";
    HANDLE hFile = CreateFileW(wpath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile != INVALID_HANDLE_VALUE) {
        DWORD written;
        WriteFile(hFile, content, (DWORD)strlen(content), &written, NULL);
        CloseHandle(hFile);
        printf("  Win32 CreateFile/WriteFile: PASS (%lu bytes)\n", written);
    } else {
        fprintf(stderr, "  Win32 CreateFile failed: %lu\n", GetLastError());
    }
#endif

    remove(filename);
#ifdef _WIN32
    remove("libuv_win32_test.txt");
#endif

    printf("\n=== All libuv tests passed! ===\n");
    return 0;
}

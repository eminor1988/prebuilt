// test_libuv.cpp — libuv event loop + file I/O test
// Verifies prebuilt libuv static library links and works correctly.
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
static char read_buf[256];

static void on_close(uv_fs_t* req) {
    printf("  File closed\n");
    uv_fs_req_cleanup(req);
}

static void on_read(uv_fs_t* req) {
    if (req->result < 0) {
        fprintf(stderr, "  Read error: %s\n", uv_strerror((int)req->result));
    } else if (req->result == 0) {
        printf("  EOF reached\n");
    } else {
        printf("  libuv read: %.*s", (int)req->result, read_buf);
    }
    uv_fs_req_cleanup(req);
}

static void on_write(uv_fs_t* req) {
    if (req->result < 0) {
        fprintf(stderr, "  Write error: %s\n", uv_strerror((int)req->result));
    } else {
        printf("  libuv wrote %zd bytes\n", req->result);
    }
    uv_fs_req_cleanup(req);
}

int main() {
    printf("=== libuv Static Library Test ===\n\n");

    loop = uv_default_loop();
    printf("libuv version: %s\n", uv_version_string());
    printf("Event loop backend: %s\n\n", uv_backend_name(loop));

    // Write file using libuv
    const char* filename = "libuv_test_output.txt";
    const char* content = "Written by libuv from prebuilt static library test!\n";

    uv_file file;
    uv_fs_t req;
    uv_buf_t iov;
    int r;

    // Open for write
    r = uv_fs_open(loop, &req, filename, O_WRONLY | O_CREAT | O_TRUNC, 0644, NULL);
    if (r < 0) {
        fprintf(stderr, "uv_fs_open error: %s\n", uv_strerror(r));
        return 1;
    }
    file = req.result;
    uv_fs_req_cleanup(&req);
    printf("[1] Opened '%s' for writing (fd=%d)\n", filename, file);

    // Write
    iov = uv_buf_init((char*)content, (unsigned int)strlen(content));
    r = uv_fs_write(loop, &req, file, &iov, 1, -1, on_write);

    // Close write handle
    uv_fs_close(loop, &req, file, NULL);
    uv_fs_req_cleanup(&req);

    // Open for read
    r = uv_fs_open(loop, &req, filename, O_RDONLY, 0, NULL);
    if (r < 0) {
        fprintf(stderr, "uv_fs_open read error: %s\n", uv_strerror(r));
        return 1;
    }
    file = req.result;
    uv_fs_req_cleanup(&req);
    printf("[2] Opened '%s' for reading (fd=%d)\n", filename, file);

    // Read
    memset(read_buf, 0, sizeof(read_buf));
    iov = uv_buf_init(read_buf, sizeof(read_buf) - 1);
    r = uv_fs_read(loop, &req, file, &iov, 1, -1, on_read);

    // Close read handle
    uv_fs_close(loop, &req, file, on_close);
    uv_fs_req_cleanup(&req);

    // Run event loop
    printf("\n[3] Running event loop...\n");
    uv_run(loop, UV_RUN_DEFAULT);
    printf("  Event loop finished\n");

    // Verify content
    if (strstr(read_buf, content) != NULL) {
        printf("\n[4] Content verification: PASS\n");
    } else {
        fprintf(stderr, "\n[4] Content verification: FAIL\n");
        return 1;
    }

#ifdef _WIN32
    // Win32 API test on MinGW
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

    // Cleanup
    remove(filename);
#ifdef _WIN32
    remove("libuv_win32_test.txt");
#endif

    printf("\n=== All libuv tests passed! ===\n");
    return 0;
}

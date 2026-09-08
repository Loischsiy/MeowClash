#include <cstdint>
#include <cstring>
#include <iostream>

// Pointer-only ABI used by flutter_js QuickJsRuntime2. This checks the actual
// library, not just the architecture of a Flutter/core executable.
extern "C" {
struct JSContext;
typedef void* JSChannel(JSContext* ctx, size_t type, void* argv);
void* jsNewRuntime(JSChannel channel);
void jsFreeRuntime(void* rt);
void* jsNewContext(void* rt);
void jsFreeContext(void* ctx);
void* jsEval(void* ctx, const char* input, size_t len, const char* file, int32_t flags);
int32_t jsIsException(void* value);
const char* jsToCString(void* ctx, void* value);
void jsFreeCString(void* ctx, const char* value);
void jsFreeValue(void* ctx, void* value, int32_t freeHeap);
}
int main() {
  for (int i = 0; i < 10; ++i) {
    void* rt = jsNewRuntime(nullptr);
    if (!rt) return 1;
    void* ctx = jsNewContext(rt);
    if (!ctx) return 2;
    const char* code = "JSON.stringify({rules:['MATCH,DIRECT'],answer:6*7})";
    void* value = jsEval(ctx, code, std::strlen(code), "smoke.js", 0);
    if (!value || jsIsException(value)) return 3;
    const char* result = jsToCString(ctx, value);
    const bool ok = result && std::strcmp(result,
        "{\"rules\":[\"MATCH,DIRECT\"],\"answer\":42}") == 0;
    if (result) jsFreeCString(ctx, result);
    jsFreeValue(ctx, value, 1);
    jsFreeContext(ctx);
    jsFreeRuntime(rt);
    if (!ok) return 4;
  }
  std::cout << "QuickJS bridge ABI and evaluation OK\n";
}

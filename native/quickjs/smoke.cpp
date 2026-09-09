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

namespace {
bool evalEquals(void* ctx, const char* code, const char* expected) {
  void* value = jsEval(ctx, code, std::strlen(code), "smoke.js", 0);
  if (!value || jsIsException(value)) return false;
  const char* result = jsToCString(ctx, value);
  const bool ok = result && std::strcmp(result, expected) == 0;
  if (result) jsFreeCString(ctx, result);
  jsFreeValue(ctx, value, 1);
  return ok;
}
}  // namespace

int main() {
  for (int i = 0; i < 10; ++i) {
    void* rt = jsNewRuntime(nullptr);
    if (!rt) return 1;
    void* ctx = jsNewContext(rt);
    if (!ctx) return 2;
    const bool ok =
        evalEquals(ctx, "JSON.stringify({rules:['MATCH,DIRECT'],answer:6*7})",
                   "{\"rules\":[\"MATCH,DIRECT\"],\"answer\":42}") &&
        // The static Math table is what MSVC rejects on windows-arm64, so the
        // ARM64 math shim must not change any of its results either.
        evalEquals(ctx,
                   "[Math.sqrt(16),Math.floor(-2.5),Math.ceil(2.1),"
                   "Math.abs(-7),Math.trunc(4.9),Math.cos(0),Math.exp(0),"
                   "Math.log2(8).toFixed(6),Math.cbrt(27).toFixed(6),"
                   "Math.atan2(1,1).toFixed(6)].join('|')",
                   "4|-3|3|7|4|1|1|3.000000|3.000000|0.785398");
    jsFreeContext(ctx);
    jsFreeRuntime(rt);
    if (!ok) return 4;
  }
  std::cout << "QuickJS bridge ABI, Math table and evaluation OK\n";
}

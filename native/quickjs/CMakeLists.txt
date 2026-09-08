cmake_minimum_required(VERSION 3.15)
project(meow_quickjs LANGUAGES C CXX)

# flutter_js 0.8.3 ships x86-64 DLL/SO files even on ARM64. Build its original
# bridge ABI for the target instead. Never modify the global Dart pub cache.
# Pin BOTH the revision and archive hash. Nix supplies the same unpacked archive.
set(MEOW_QUICKJS_SOURCE "$ENV{MEOW_QUICKJS_SOURCE}" CACHE PATH "QuickJS bridge source (offline builds)")
if(NOT MEOW_QUICKJS_SOURCE)
  include(FetchContent)
  FetchContent_Declare(meow_quickjs_source
    URL https://codeload.github.com/abner/quickjs-c-bridge/tar.gz/7204d9bf1afbe0550d51d7decdcce398b2c22e1a
    URL_HASH SHA256=42ac9ba20a994e5778443af6bb9216e648ee3fdd1d67860ca06570205e58ed38)
  FetchContent_MakeAvailable(meow_quickjs_source)
  set(MEOW_QUICKJS_SOURCE "${meow_quickjs_source_SOURCE_DIR}")
endif()
set(QJS "${MEOW_QUICKJS_SOURCE}/cxx/quickjs")
file(STRINGS "${QJS}/VERSION" QUICKJS_VERSION)

# One DLL, not a bridge DLL depending on an unbundled quickjs.dll.
add_library(meow_quickjs SHARED
  "${QJS}/cutils.c" "${QJS}/libregexp.c" "${QJS}/libunicode.c"
  "${QJS}/quickjs.c"
  "${MEOW_QUICKJS_SOURCE}/cxx/libfastdev_quickjs_runtime.cpp")
target_compile_features(meow_quickjs PRIVATE cxx_std_17)
target_compile_definitions(meow_quickjs PRIVATE CONFIG_VERSION="${QUICKJS_VERSION}")
set_target_properties(meow_quickjs PROPERTIES
  POSITION_INDEPENDENT_CODE ON
  CXX_VISIBILITY_PRESET hidden)
if(WIN32)
  set_target_properties(meow_quickjs PROPERTIES OUTPUT_NAME quickjs_c_bridge)
  target_compile_definitions(meow_quickjs PRIVATE _CRT_SECURE_NO_WARNINGS)
  target_compile_options(meow_quickjs PRIVATE /utf-8)
else()
  set_target_properties(meow_quickjs PROPERTIES OUTPUT_NAME quickjs_c_bridge_plugin)
  target_compile_definitions(meow_quickjs PRIVATE _GNU_SOURCE)
  target_link_libraries(meow_quickjs PRIVATE m dl pthread)
  # This pinned upstream C code predates modern GCC's default error here.
  target_compile_options(meow_quickjs PRIVATE $<$<COMPILE_LANGUAGE:C>:-Wno-int-conversion>)
endif()

# Buildable without Flutter for ABI/evaluation smoke tests.
include(CTest)
if(BUILD_TESTING)
  add_executable(meow_quickjs_smoke smoke.cpp)
  target_link_libraries(meow_quickjs_smoke PRIVATE meow_quickjs)
  add_test(NAME quickjs_bridge_evaluate COMMAND meow_quickjs_smoke)
endif()

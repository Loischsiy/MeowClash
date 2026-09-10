# Target-native flutter_js bridge

Windows and Linux build the original `abner/quickjs-c-bridge` source at
`7204d9bf1afbe0550d51d7decdcce398b2c22e1a`, verified by SHA-256. The exported
pointer-based ABI matches `flutter_js` 0.8.3 / QuickJsRuntime2. Apple platforms
continue to use system JavaScriptCore; Android keeps its existing bundled ABIs.

The final install rule deliberately replaces the dependency's x86-64-only
prebuilt file **after** plugin installation. No files in the shared pub cache
are changed. A single Windows DLL contains both QuickJS and the bridge.

On MSVC the C sources are compiled with `/FImsvc_arm64_math.h`. That header
wraps the libm symbols whose addresses QuickJS keeps in its static `Math` table,
because MSVC emits them as inline ARM64 intrinsics and then refuses the table
with `C2099` on windows-arm64. Those wrappers compile to nothing on x64 and in
C++.

The same header maps `alloca` onto the `_alloca` intrinsic. `libregexp.c` and
`quickjs.c` call `alloca()` without ever including `<malloc.h>`, and MSVC only
recognises the bare name as an intrinsic on x86/x64. windows-arm64 therefore
compiled cleanly and then failed to link with `LNK2019`/`LNK2001` on `alloca`
and `LNK1120: 1 unresolved externals` for `quickjs_c_bridge.dll`. That mapping
is active on every MSVC architecture and stays out of the C++ bridge file.

The force-include is set on the C source files and repeated target-wide. The
Visual Studio generator used by `flutter build windows` drops target-wide
`$<$<COMPILE_LANGUAGE:C>:...>` options on a mixed C/C++ target, so that spelling
never reached `cl.exe` and windows-arm64 kept failing.

```sh
cmake -S native/quickjs -B build/quickjs -DCMAKE_BUILD_TYPE=Release
cmake --build build/quickjs --config Release
ctest --test-dir build/quickjs -C Release --output-on-failure
```

Run those commands on each native x64/ARM64 host. For offline builds set
`MEOW_QUICKJS_SOURCE` to the unpacked, checksum-verified source archive (Nix does
this automatically). The QuickJS source carries the Bellard/Gordon MIT notice
in its file headers; the original notices are retained in the fetched source.

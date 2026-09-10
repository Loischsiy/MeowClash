# Testing

Router: `AGENTS.md`. CI wiring: `.agents/ci-and-release.md`.

Every test lives in `test/`, except the Go tests and two files that cannot move (see below).

```bash
flutter test                                        # ~33 Dart test files
flutter test test/build_platforms_test.dart         # focused run
CGO_ENABLED=0 go -C core test ./...                 # Go core tests
go -C core test -race ./mobilebridge                # iOS bridge, race detector
python3 -m unittest discover -s test -p 'test_*.py' # release-asset naming
nix build .#checks.x86_64-linux.nixos-vm -L         # NixOS VM test (test/nixos-module.nix)
```

## Layout rules

- **Dart** (`test/*_test.dart`): proxy chains, delay queue/snapshots, provider refresh and payloads,
  profile-script evaluation, subscription crypto, IP details, iOS core protocol, UI
  lifecycle/suspension, polling, backup/recovery and build-target wiring.
  `test/performance_test_support.dart` is a shared helper, not a suite; the `*_performance_test.dart`
  files are host workload checks and do **not** measure device FPS.
- **Go tests stay in `core/`** (`core/*_test.go`, `core/mobilebridge/bridge_test.go`). Go requires test
  files in the same package directory as the code under test, so moving them into `test/` would break
  `go test ./...`.
- **`macos/RunnerTests/RunnerTests.swift` stays put** — it is an Xcode test target wired into
  `macos/Runner.xcodeproj`.
- **`native/quickjs/smoke.cpp` is not a test-runner test** but a CMake target (`meow_quickjs_smoke`)
  that `platform-checks.yaml` builds and executes to prove the bridge ABI works.
- **`test/build_platforms_test.dart` asserts on source text**, not behavior: it greps `setup.dart`,
  `windows/packaging/exe/inno_setup.iss`, `native/quickjs/CMakeLists.txt` and
  `native/quickjs/msvc_arm64_math.h` for specific strings. Editing any of those files without updating
  that test turns CI red, and vice versa — it proves the text is present, not that the build works.
- The CI gate is `platform-checks.yaml` — do not assume tests run only locally.

## Quick verification checklist (before committing)

```bash
flutter pub get
# If you changed models/providers:
dart run build_runner build --delete-conflicting-outputs
# If you changed ARB files:
flutter pub run intl_utils:generate
# Lint:
flutter analyze
# Tests (Dart, Go, Python):
flutter test
CGO_ENABLED=0 go -C core test ./...
go -C core test -race ./mobilebridge
python3 -m unittest discover -s test -p 'test_*.py'
```

For Nix packaging changes, additionally evaluate/build on NixOS or a Linux Nix host:

```bash
nix flake check --no-build                     # fast: flake + NixOS module evaluation
nix build .#core -L                            # Go core only
nix build .#meowclash -L                       # full Flutter app
nix build .#checks.x86_64-linux.nixos-vm -L    # boots real NixOS VMs (needs KVM)
# or simply:
make nixAll
```

# AGENTS.md — MeowClash

Router file: rules that always apply, plus pointers to `.agents/<topic>.md`. Read the guide that matches
your task instead of everything. Keep this file under ~150 lines.

## Project overview

Multi-platform Flutter proxy client (Android, Windows, macOS, Linux, iOS/iPadOS 15+), fork of FlClashX,
wrapping the [mihomo](https://github.com/MetaCubeX/mihomo) Go core. It also ships a Rust Windows service
helper (`services/helper/`) and a rebuilt QuickJS C bridge (`native/quickjs/`).

Every platform ships **x64 and ARM64** (Windows arm64, Linux arm64, `aarch64-linux` via Nix, Android
arm64-v8a, iOS arm64). iOS is physical devices only — simulator builds are rejected — and the IPA is
**unsigned** by design.

## Tech stack

- Flutter **3.35.7** and **3.44.1**, Go **1.24.0** and **1.26.0** — two versions of each coexist; check
  the workflow you are touching (`.agents/ci-and-release.md`).
- Rust (`services/helper/`), Java 17 + Android NDK for Android, Nix (nixpkgs unstable) for Linux/NixOS.
- Riverpod + freezed + json_serializable, `flutter_intl` from `arb/`, FFI to the Go core.

## Project structure

- `lib/` Flutter app · `core/` Go mihomo wrapper (+ `core/mobilebridge/` for iOS) · `ios/` Runner + PacketTunnel
- `native/quickjs/` rebuilt QuickJS C bridge · `services/helper/` Rust Windows service · `nix/` + `flake.nix`
- `test/` all Dart/Python/NixOS tests · `scripts/` + `tool/` generators · `arb/` translations
- Full ownership map: `.agents/project-structure.md`

## Commands

```bash
dart setup.dart <platform> --arch <arch>   # the build entry point, not raw `flutter build`
make android_arm64 | ios_arm64 | windows_arm64 | linux_arm64 | macLocal | nixAll
flutter analyze && flutter test
CGO_ENABLED=0 go -C core test ./...
python3 -m unittest discover -s test -p 'test_*.py'
```

Full command matrix and build behaviors: `.agents/build.md`. Pre-commit checklist: `.agents/testing.md`.

## Code style

- Follow the patterns already in `lib/`; do not add a dependency for something the repo already solves.
- `analysis_options.yaml` is stricter than `flutter_lints` (`avoid_print`, `prefer_const_constructors`,
  `use_build_context_synchronously`, `unawaited_futures`, `always_declare_return_types`), and
  `custom_lint` + `riverpod_lint` are configured. Details: `.agents/codegen-and-lint.md`.
- Generated files are checked in — regenerate them, never hand-edit: `lib/core_version.dart`,
  `lib/models/generated/**`, `lib/providers/generated/**`, `lib/clash/generated/**`, `lib/l10n/**`.

## Invariants

- **The core version has one source:** `core/constant/version.go`. Never hardcode it elsewhere; a bump
  touches four files including `vendorHash` (`.agents/core-version.md`).
- **`test/build_platforms_test.dart` asserts on source text** of `setup.dart`,
  `windows/packaging/exe/inno_setup.iss`, `native/quickjs/CMakeLists.txt` and
  `native/quickjs/msvc_arm64_math.h`. Editing those without updating the test turns CI red, and vice
  versa — it proves the text is present, not that the build works.
- **The QuickJS MSVC math shim is not architecture-gated.** Never re-add an `_M_ARM64` guard
  (`.agents/platform-gotchas.md`).
- The CI gate is `.github/workflows/platform-checks.yaml`; there is no `test.yaml`.

## Testing

```bash
flutter test                                        # ~33 Dart test files
CGO_ENABLED=0 go -C core test ./...                 # Go core
go -C core test -race ./mobilebridge                # iOS bridge, race detector
python3 -m unittest discover -s test -p 'test_*.py' # release-asset naming
```

Every test lives in `test/`, except the Go tests, `macos/RunnerTests/RunnerTests.swift` and
`native/quickjs/smoke.cpp` — see `.agents/testing.md` for why and for the full pre-commit checklist.

## Documentation policy — there is no `docs/` folder

- Agent-facing reasoning, gotchas and internal mechanics: this file for short always-on rules, a topic
  guide in `.agents/` for anything longer.
- When a section outgrows this router, move the prose into `.agents/<topic>.md` and leave a one-line
  pointer here. Keep guides focused; link between them instead of duplicating.
- User-facing docs (requirements, build/signing steps, platform limits) go in the **six READMEs**
  (`README.md`, `README_RU.md`, `README_UK.md`, `README_FI.md`, `README_JA.md`, `README_ZH.md`) — edit
  all six.
- Component-level native notes live next to the code (`native/quickjs/README.md`).
- Do not create standalone `.md` files outside `.agents/` and those READMEs, and never track one-off
  validation reports, device checklists, dated fork comparisons, test counts or analyzer diagnostic
  counts — they are stale on the next commit, so they belong in the PR description or `CHANGELOG.md`.
- `CLAUDE.md` and `GEMINI.md` are thin pointers to this file; never duplicate rules into them.

## Keeping these instructions current

- Review the real project structure before acting. If you find technology not described here, say so and
  update the docs.
- **You are expected to edit this file and its `.agents/` guides** whenever a change makes them wrong, or
  when a new rule would improve future work. Ship the doc update in the same commit as the code.
- On "Analyze and update AGENTS.md": rescan the project, refresh the Tech stack and Project structure
  sections here, and update the affected guides.

## Safety and permissions

- Never commit secrets. `ios/Config/Signing.xcconfig` is gitignored; keep certificates, private keys and
  provisioning profiles out of the repo.
- `dist/`, `build/`, `libclash/` and `plugins/flutter_distributor/` are build outputs — never commit them.
- Long/expensive jobs (`nix build`, the NixOS VM test, full `setup.dart` runs) take tens of minutes; ask
  before starting one.

## File routing

| Read when the task touches | Guide |
|---|---|
| Folder ownership, `lib/` layout | `.agents/project-structure.md` |
| Building, packaging, env vars, running locally | `.agents/build.md` |
| Bumping mihomo / core version, `vendorHash` | `.agents/core-version.md` |
| Nix, NixOS module, VM check, TUN mode | `.agents/nix.md` |
| build_runner, ffigen, intl, CLDR data, lint config | `.agents/codegen-and-lint.md` |
| Writing or running tests, pre-commit checklist | `.agents/testing.md` |
| Workflows, toolchain versions, release assets | `.agents/ci-and-release.md` |
| Windows/MSVC/Inno/QuickJS/iOS build gotchas | `.agents/platform-gotchas.md` |
| iOS Runner vs PacketTunnel behavior | `.agents/ios-runtime.md` |
| Delay tests, provider refresh, UI suspension, memory, IP details | `.agents/runtime-contracts.md` |
| History of the removed `meowclash-*` overrides | `.agents/fork-changes.md` |

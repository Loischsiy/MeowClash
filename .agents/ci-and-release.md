# CI, toolchain versions and release

Router: `AGENTS.md`.

## Languages / tool versions (CI is the source of truth)

**Two Flutter versions and two Go versions coexist — check the workflow you are touching.**

| Tool    | CI version | Notes |
|---------|------------|-------|
| Flutter | **3.35.7** + **3.44.1** | `3.35.7` (`channel: stable`) for the legacy Android/macOS/Linux-x64 jobs in `build.yaml` and `release-all.yaml`. `3.44.1` for Windows ARM64, iOS and everything in `platform-checks.yaml`. ARM/iOS hosts use `channel: master` because no stable host archive exists — that is a pinned checkout mechanism, not "track master". |
| Go      | **1.24.0** + **1.26.0** | `1.24.0` in `build.yaml`; `1.26.0` in `platform-checks.yaml` and the iOS job of `release-all.yaml`. The mihomo version itself always comes from `core/constant/version.go`, never from the toolchain. |
| Rust    | latest     | `services/helper/` is a Cargo project. |
| Java    | 17         | CI uses Temurin 17 for Android builds. |
| Android NDK | latest | Must set `ANDROID_NDK` for Android builds. |
| Nix     | nixpkgs unstable | `flake.nix` packages Linux builds and exposes a NixOS module. |

## Workflows

- `.github/workflows/platform-checks.yaml` — **the test workflow and the gate**. Runs on PRs touching
  `core/**`, `lib/**`, `ios/**`, `native/**`, `scripts/**`, `test/**`, `setup.dart` or
  `.github/workflows/**`, plus manual dispatch. It builds and runs the real native JS bridge on Windows
  and Linux (x64 + ARM64), cross-builds the desktop Go cores, runs `flutter analyze`, `flutter test`,
  the Python tests and `flutter test test/desktop_native_js_test.dart`, and compiles both iOS targets
  unsigned on a macOS/Xcode runner. There is no `test.yaml`.
- `.github/workflows/build.yaml` — triggers on tags `v*` or manual `workflow_dispatch`.
- `.github/workflows/release-all.yaml` — release-all workflow.
- `.github/workflows/nixos.yaml` — NixOS verification. Runs on pushes/PRs touching Nix-relevant paths,
  weekly on a schedule, and on manual dispatch.
  - Job `eval`: `nix flake check --no-build` + `checks.x86_64-linux.nixos-module-eval`. Fast, should
    always be green.
  - Job `build`: frees runner disk space, enables KVM, builds `.#core` and `.#meowclash`, then runs
    `checks.x86_64-linux.nixos-vm`. Dispatch with `skip_vm_test: true` to skip the VM stage.
  - There is no binary cache configured, so `build` compiles Flutter and Go from source and is slow.
    Adding a Cachix cache is the obvious speedup.

## Release

- CI clones `flutter_distributor` fresh each run (`plugins/flutter_distributor` is gitignored).
- Artifacts are uploaded to GitHub Releases and GitLab Releases. The READMEs also advertise a
  **GitVerse** page (`https://gitverse.ru/Loischsiy/meowclash/releases`), but **no workflow publishes
  there** — it is a manual mirror. If you automate it, add the step next to `Publish GitLab release` in
  `release-all.yaml`.
- Release notes are rendered from `.github/release_template.md` by both `build.yaml` and
  `release-all.yaml` via `sed "s|VERSION|$version|g"`, so the literal `VERSION`/`vVERSION` placeholders
  must stay in the template. It links one download badge per published asset; when packaging adds or
  drops a file, update the template and `RELEASE_ASSETS` in `test/test_release_assets.py`.
- Releases do **not** ship `.sha256` sidecars — GitHub already exposes a digest for every asset. Both
  workflows delete stray `*.sha256` files from `dist` before uploading, because packaging tools emit
  some of them.
- The changelog is auto-generated from commits between tags.

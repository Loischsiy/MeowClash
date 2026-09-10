# Code generation and lint

Router: `AGENTS.md`.

Generated files are **checked in**, but you must regenerate them after editing their sources.

| Generator | Input | Output | Command |
|-----------|-------|--------|---------|
| `build_runner` | `lib/models/*.dart`, `lib/providers/*.dart` | `lib/models/generated/*.{g,freezed}.dart`, `lib/providers/generated/*.g.dart` | `dart run build_runner build --delete-conflicting-outputs` |
| `ffigen` | `libclash/android/arm64-v8a/libclash.h` | `lib/clash/generated/clash_ffi.dart` | `dart run ffigen --config ffigen.yaml` (if the config exists) or via the pubspec ffigen section |
| `flutter_intl` | `arb/*.arb` | `lib/l10n/l10n.dart` | IDE plugin or `flutter pub run intl_utils:generate` |
| Country names | Unicode CLDR, via Node with full ICU | `lib/common/ip_country_names.dart` | `node tool/generate_ip_country_names.cjs`, then `dart format lib/common/ip_country_names.dart`. Keep `LICENSES/unicode.txt` — the bundled data is CLDR-licensed. |
| Nix pub lock JSON | `pubspec.lock` | `nix/pubspec.lock.json` | `ruby -e 'require "yaml"; require "json"; File.write("nix/pubspec.lock.json", JSON.pretty_generate(YAML.load_file("pubspec.lock")) + "\n")'` |

The ffigen header path is hardcoded in `pubspec.yaml` to `libclash/android/arm64-v8a/libclash.h`, so
regenerating FFI bindings requires the Android core to have been built first.

## Analysis / lint quirks

- `analysis_options.yaml` enables **many** extra lints beyond `flutter_lints`. Notable strict ones:
  `avoid_print`, `prefer_const_constructors`, `use_build_context_synchronously`, `unawaited_futures`,
  `always_declare_return_types`.
- `custom_lint` is configured for `riverpod_lint`. Run `dart run custom_lint` to verify Riverpod rules.
- `analyzer.exclude` ignores `build/`, `lib/generated_plugin_registrant.dart`, `lib/clash/generated/**`,
  `lib/l10n/**`, `plugins/flutter_distributor/**`.

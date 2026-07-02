package zapret

// Version is the single source of truth for the bundled zapret2 engine
// (github.com/bol-van/zapret2) version. setup.dart reads it at build time and
// generates lib/zapret_version.dart so the Flutter side shows and cache-keys
// the exact same version. Update this when bumping the bundled zapret2 build;
// never hardcode the version anywhere else (mirrors core/constant/version.go).
var Version = "v1.0.2"

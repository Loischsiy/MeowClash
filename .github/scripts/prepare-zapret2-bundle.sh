#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: prepare-zapret2-bundle.sh <windows|linux>}"
version="${ZAPRET2_VERSION:-$(sed -nE 's/^var Version = "([^"]+)".*/\1/p' zapret/version.go)}"
bundle="${ZAPRET2_BUNDLE_DIR:-${RUNNER_TEMP:-/tmp}/zapret2-bundle}"
dest="$bundle/$target"

mkdir -p "$dest"
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "ZAPRET2_BUNDLE_DIR=$bundle" >> "$GITHUB_ENV"
fi

python_bin="$(command -v python3 || command -v python)"

download() {
  local repo="$1"
  local tag="$2"
  local out="$3"
  mkdir -p "$out"
  if command -v gh >/dev/null 2>&1; then
    if [ "$tag" = "latest" ]; then
      GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" gh release download --repo "$repo" --dir "$out" --clobber
    else
      GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}" gh release download "$tag" --repo "$repo" --dir "$out" --clobber
    fi
    return
  fi
  "$python_bin" - "$repo" "$tag" "$out" <<'PY'
import json, os, pathlib, sys, urllib.request

repo, tag, out = sys.argv[1:]
url = f"https://api.github.com/repos/{repo}/releases/latest" if tag == "latest" else f"https://api.github.com/repos/{repo}/releases/tags/{tag}"
headers = {"Accept": "application/vnd.github+json"}
token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
if token:
    headers["Authorization"] = f"Bearer {token}"
data = json.load(urllib.request.urlopen(urllib.request.Request(url, headers=headers)))
assets = data.get("assets", [])
if not assets:
    raise SystemExit(f"no release assets found for {repo}@{tag}")
pathlib.Path(out).mkdir(parents=True, exist_ok=True)
for asset in assets:
    name = asset["name"]
    urllib.request.urlretrieve(asset["browser_download_url"], str(pathlib.Path(out) / name))
PY
}

extract_all() {
  local assets="$1"
  local out="$2"
  mkdir -p "$out"
  "$python_bin" - "$assets" "$out" <<'PY'
import pathlib, sys, tarfile, zipfile

assets, out = map(pathlib.Path, sys.argv[1:])
for path in assets.iterdir():
    if not path.is_file():
        continue
    try:
        if zipfile.is_zipfile(path):
            zipfile.ZipFile(path).extractall(out)
        elif tarfile.is_tarfile(path):
            tarfile.open(path).extractall(out)
    except Exception as exc:
        print(f"skip {path.name}: {exc}")
PY
}

copy_lua() {
  curl -fsSL "https://raw.githubusercontent.com/bol-van/zapret2/$version/lua/zapret-lib.lua" -o "$dest/zapret-lib.lua"
  curl -fsSL "https://raw.githubusercontent.com/bol-van/zapret2/$version/lua/zapret-antidpi.lua" -o "$dest/zapret-antidpi.lua"
}

copy_lua

case "$target" in
  linux)
    assets="${RUNNER_TEMP:-/tmp}/zapret2-linux-assets"
    extracted="${RUNNER_TEMP:-/tmp}/zapret2-linux"
    download bol-van/zapret2 "$version" "$assets"
    extract_all "$assets" "$extracted"
    case "$(uname -m)" in
      x86_64) arch_re='x86_64|amd64|x64|x86-64' ;;
      aarch64|arm64) arch_re='aarch64|arm64' ;;
      *) arch_re='' ;;
    esac
    nfqws=""
    if [ -n "$arch_re" ]; then
      nfqws="$(find "$extracted" -type f \( -name nfqws -o -name nfqws2 \) | grep -Ei "$arch_re" | head -n 1 || true)"
    fi
    if [ -z "$nfqws" ]; then
      nfqws="$(find "$extracted" -type f \( -name nfqws -o -name nfqws2 \) | head -n 1)"
    fi
    test -n "$nfqws"
    cp "$nfqws" "$dest/nfqws"
    chmod +x "$dest/nfqws"
    ;;
  windows)
    assets="${RUNNER_TEMP:-/tmp}/zapret2-windows-assets"
    extracted="${RUNNER_TEMP:-/tmp}/zapret2-windows"
    download bol-van/zapret-win-bundle "$version" "$assets" || download bol-van/zapret-win-bundle latest "$assets"
    extract_all "$assets" "$extracted"
    winws="$(find "$extracted" -type f \( -iname winws.exe -o -iname winws2.exe \) | grep -Ei 'x86_64|amd64|x64|win64|64' | head -n 1 || true)"
    if [ -z "$winws" ]; then
      winws="$(find "$extracted" -type f \( -iname winws.exe -o -iname winws2.exe \) | head -n 1)"
    fi
    test -n "$winws"
    cp "$winws" "$dest/winws.exe"
    win_dir="$(dirname "$winws")"
    find "$win_dir" -type f \( -iname 'WinDivert*.dll' -o -iname 'WinDivert*.sys' \) -exec cp {} "$dest/" \;
    if [ -z "$(find "$dest" -maxdepth 1 -type f -iname 'WinDivert*' -print -quit)" ]; then
      find "$extracted" -type f \( -iname 'WinDivert*.dll' -o -iname 'WinDivert*.sys' \) -exec cp {} "$dest/" \;
    fi
    ;;
  *)
    ;;
esac

echo "Prepared zapret2 bundle in $dest"

#!/usr/bin/env python3
"""Normalize release names once, identically for manual and all-platform builds.

Refuse architecture ambiguity and collisions rather than overwriting ARM64 with
an x64 asset. No upload/publishing occurs in this script.
"""
import argparse
from pathlib import Path
import re


def target_name(filename: str, version: str) -> str | None:
    name = filename.lower()
    suffix = '.tar.gz' if name.endswith('.tar.gz') else Path(name).suffix
    if suffix not in {'.apk', '.exe', '.zip', '.dmg', '.deb', '.rpm', '.appimage', '.tar.gz', '.ipa'}:
        return None
    prefix = f'MeowClash-{version}'
    if 'android' in name and suffix == '.apk':
        if 'arm64' in name or 'aarch64' in name: arch = 'arm64-v8a'
        elif any(x in name for x in ('x86_64', 'amd64', 'x64', 'x86-64')): arch = 'x86_64'
        elif any(x in name for x in ('armeabi-v7a', 'armv7', 'android-arm')): arch = 'armeabi-v7a'
        else: arch = 'universal'
        return f'{prefix}-android-{arch}.apk'
    platform = next((p for p in ('windows', 'linux', 'macos', 'ios') if p in name), None)
    if platform is None and 'darwin' in name: platform = 'macos'
    if platform is None: return None
    if 'arm64' in name or 'aarch64' in name: arch = 'arm64'
    elif any(x in name for x in ('amd64', 'x86_64', 'x64', 'x86-64')): arch = 'amd64'
    else: raise ValueError(f'Missing architecture in release asset: {filename}')
    if platform == 'ios':
        if arch != 'arm64' or suffix != '.ipa': raise ValueError(f'Unsupported iOS artifact: {filename}')
        return f'{prefix}-ios-arm64-unsigned.ipa'
    if platform == 'windows' and suffix == '.exe': suffix = '-setup.exe'
    if platform == 'linux' and suffix == '.tar.gz': suffix = '-portable.tar.gz'
    if suffix == '.appimage': suffix = '.AppImage'
    return f'{prefix}-{platform}-{arch}{suffix}'


def normalize(directory: Path, version: str) -> list[tuple[Path, Path]]:
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?', version):
        raise ValueError('Invalid release version')
    planned: dict[Path, Path] = {}
    for source in sorted(directory.rglob('*')):
        if not source.is_file(): continue
        name = target_name(source.name, version)
        if name is None: continue
        target = directory / name
        if target in planned and planned[target] != source:
            raise ValueError(f'Artifact collision: {source} and {planned[target]} -> {target}')
        if target.exists() and target != source:
            raise ValueError(f'Refusing to overwrite existing artifact: {target}')
        planned[target] = source
    result = []
    for target, source in planned.items():
        if target != source:
            source.rename(target)
            # Hashes are generated after renaming, never ship stale filenames.
            source.with_name(source.name + '.sha256').unlink(missing_ok=True)
            result.append((source, target))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('version')
    parser.add_argument('--directory', type=Path, default=Path('dist'))
    args = parser.parse_args()
    for source, target in normalize(args.directory, args.version):
        print(f'{source} -> {target}')

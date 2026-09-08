import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('assets', Path(__file__).with_name('rename_release_assets.py'))
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)

class ReleaseAssetsTest(unittest.TestCase):
    def test_architectures_are_distinct(self):
        for platform, suffix in [('windows', '.zip'), ('windows', '-setup.exe'), ('linux', '.deb'), ('linux', '.rpm'), ('linux', '.AppImage'), ('linux', '-portable.tar.gz'), ('macos', '.dmg')]:
            for arch in ['amd64', 'arm64']:
                name = f'MeowClash-1.0.8-{platform}-{arch}{suffix}'
                self.assertEqual(assets.target_name(name, '2.0.0'), f'MeowClash-2.0.0-{platform}-{arch}{suffix}')

    def test_android_and_ios(self):
        for arch in ['universal', 'arm64-v8a', 'armeabi-v7a', 'x86_64']:
            self.assertEqual(assets.target_name(f'app-android-{arch}.apk', '1.0.0'), f'MeowClash-1.0.0-android-{arch}.apk')
        self.assertEqual(assets.target_name('MeowClash-1.0.8-ios-arm64-unsigned.ipa', '1.0.0'), 'MeowClash-1.0.0-ios-arm64-unsigned.ipa')

    def test_unknown_arch_fails(self):
        with self.assertRaises(ValueError): assets.target_name('MeowClash-windows-setup.exe', '1.0.0')

    def test_collision_does_not_mutate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ['old-windows-arm64.zip', 'new-windows-arm64.zip']: (root / name).write_text(name)
            with self.assertRaises(ValueError): assets.normalize(root, '1.0.0')
            self.assertEqual(len(list(root.iterdir())), 2)
            self.assertTrue((root / 'old-windows-arm64.zip').exists())

    def test_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'MeowClash-1.0.0-linux-arm64-portable.tar.gz').write_text('archive')
            self.assertEqual(assets.normalize(root, '1.0.0'), [])

if __name__ == '__main__': unittest.main()

import importlib.util
from pathlib import Path
import re
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

# Every asset the `release all platforms` workflow uploads, written the way the
# release notes template spells it. Keep in sync with setup.dart packaging.
RELEASE_ASSETS = [
    'MeowClash-VERSION-android-universal.apk',
    'MeowClash-VERSION-android-arm64-v8a.apk',
    'MeowClash-VERSION-android-armeabi-v7a.apk',
    'MeowClash-VERSION-android-x86_64.apk',
    'MeowClash-VERSION-ios-arm64-unsigned.ipa',
    'MeowClash-VERSION-windows-amd64-setup.exe',
    'MeowClash-VERSION-windows-arm64-setup.exe',
    'MeowClash-VERSION-windows-amd64.zip',
    'MeowClash-VERSION-windows-arm64.zip',
    'MeowClash-VERSION-macos-arm64.dmg',
    'MeowClash-VERSION-macos-amd64.dmg',
    'MeowClash-VERSION-linux-amd64.AppImage',
    'MeowClash-VERSION-linux-arm64.AppImage',
    'MeowClash-VERSION-linux-amd64-portable.tar.gz',
    'MeowClash-VERSION-linux-arm64-portable.tar.gz',
    'MeowClash-VERSION-linux-amd64.deb',
    'MeowClash-VERSION-linux-arm64.deb',
    'MeowClash-VERSION-linux-amd64.rpm',
    'MeowClash-VERSION-linux-arm64.rpm',
]

spec = importlib.util.spec_from_file_location('assets', ROOT / 'scripts' / 'rename_release_assets.py')
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

class ReleaseTemplateTest(unittest.TestCase):
    def setUp(self):
        self.template = (ROOT / '.github' / 'release_template.md').read_text()

    def test_every_built_asset_has_a_download_button(self):
        linked = re.findall(r'releases/download/vVERSION/([^"]+)', self.template)
        self.assertEqual(sorted(set(linked)), sorted(RELEASE_ASSETS))
        self.assertEqual(len(linked), len(set(linked)))

    def test_linked_names_survive_asset_normalization(self):
        for template_name in RELEASE_ASSETS:
            name = template_name.replace('VERSION', '1.2.3')
            self.assertEqual(assets.target_name(name, '1.2.3'), name)

    def test_download_urls_target_this_repository(self):
        hrefs = re.findall(r'href="([^"]+)"', self.template)
        self.assertTrue(hrefs)
        for href in hrefs:
            self.assertTrue(href.startswith('https://github.com/Loischsiy/MeowClash/'), href)

    def test_version_substitution_cannot_corrupt_badge_logos(self):
        rendered = self.template.replace('VERSION', '1.2.3')
        logos = re.findall(r'base64,([A-Za-z0-9+/=]+)', self.template)
        self.assertTrue(logos)
        for logo in logos:
            self.assertIn(logo, rendered)

class ReleaseWorkflowTest(unittest.TestCase):
    def test_workflows_never_publish_checksum_sidecars(self):
        for workflow in ['release-all.yaml', 'build.yaml']:
            text = (ROOT / '.github' / 'workflows' / workflow).read_text()
            self.assertNotIn('sha256sum', text, workflow)
            self.assertIn("find ./dist -type f -name '*.sha256' -print -delete", text, workflow)

if __name__ == '__main__': unittest.main()

import importlib.util
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[1]

spec = importlib.util.spec_from_file_location('icons', ROOT / 'scripts' / 'generate_windows_icons.py')
icons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(icons)

PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def read_frames(path):
    data = path.read_bytes()
    reserved, kind, count = struct.unpack_from('<HHH', data, 0)
    assert (reserved, kind) == (0, 1), f'{path} is not an .ico file'
    frames = []
    for index in range(count):
        width, height, _, _, _, bpp, size, offset = struct.unpack_from('<BBBBHHII', data, 6 + 16 * index)
        frames.append((width or 256, height or 256, bpp, data[offset:offset + size]))
    return frames


class WindowsIconsTest(unittest.TestCase):
    """Windows stretches the nearest frame when an .ico lacks the size the
    current display scale asks for, which is what made the tray and taskbar
    icons look pixelated. Regenerate with scripts/generate_windows_icons.py."""

    def test_every_icon_has_the_full_dpi_ladder(self):
        for output, _, dib_max in icons.ICONS:
            with self.subTest(icon=output):
                frames = read_frames(ROOT / output)
                self.assertEqual([f[0] for f in frames], list(icons.SIZES))
                for width, height, bpp, blob in frames:
                    self.assertEqual((width, height, bpp), (width, width, 32))
                    if width <= dib_max:
                        header_size, dib_width, dib_height = struct.unpack_from('<Iii', blob, 0)
                        self.assertEqual((header_size, dib_width, dib_height), (40, width, width * 2))
                    else:
                        self.assertEqual(blob[:8], PNG_SIGNATURE)
                        self.assertEqual(struct.unpack_from('>II', blob, 16), (width, width))

    def test_runtime_icons_are_generated(self):
        generated = {output for output, _, _ in icons.ICONS}
        tray = set(re.findall(r'assets/images/\w+\.ico', (ROOT / 'lib/common/utils.dart').read_text()))
        self.assertTrue(tray)
        self.assertLessEqual(tray, generated)
        runner_rc = (ROOT / 'windows/runner/Runner.rc').read_text(encoding='utf-8', errors='replace')
        self.assertIn('resources\\\\app_icon.ico', runner_rc)
        self.assertIn('windows/runner/resources/app_icon.ico', generated)


if __name__ == '__main__':
    unittest.main()

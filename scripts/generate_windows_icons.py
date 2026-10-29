#!/usr/bin/env python3
"""Regenerate the Windows .ico files from their high-resolution PNG masters.

Windows never asks an .ico for "the icon": it asks for one exact pixel size
that depends on the display scale. The tray icon is SM_CXSMICON (16 px at
100 %, 20 at 125 %, 24 at 150 %, 28 at 175 %, ...), the window / taskbar icon
is SM_CXICON (32, 40, 48, 56, ...) and Explorer and the Windows 11 taskbar use
yet other sizes (24 * scale, 48 * scale, 256). When the file has no frame of
the requested size, LoadIcon / LoadImage stretch the nearest frame without
filtering, which is the "pixelated icon" users see on scaled displays.

Every file therefore carries the full ``SIZES`` ladder, each frame downscaled
with Lanczos straight from the 512 / 1024 px master. Run after changing any
master PNG (needs Pillow):

    python3 scripts/generate_windows_icons.py

``test/test_windows_icons.py`` checks the committed files against ``SIZES``.
"""

from __future__ import annotations

import io
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Every size Windows requests between 100 % and 350 % display scale: tray
# (16 * scale), taskbar (24 * scale), window / Alt+Tab (32 * scale), Explorer
# medium / large (48 * scale, 96) and the 256 px jumbo frame.
SIZES = (16, 20, 24, 28, 30, 32, 36, 40, 42, 48, 56, 60, 64, 72, 80, 96, 128, 256)

# (output .ico, master PNG, largest frame stored as a classic 32-bit DIB).
# app_icon.ico is embedded into the exe by Runner.rc and reused by the
# installer, so its small frames stay uncompressed DIBs like Flutter's
# template; the tray icons are loaded from disk by tray_manager and keep the
# PNG-compressed frames they always had.
ICONS = (
    ('windows/runner/resources/app_icon.ico', 'assets/images/icon.png', 64),
    ('assets/images/icon.ico', 'assets/images/icon.png', 0),
    ('assets/images/icon_stop_white.ico', 'assets/images/icon_stop_white.png', 0),
    ('assets/images/icon_stop_black.ico', 'assets/images/icon_stop_black.png', 0),
    ('assets/images/icon_white.ico', 'assets/images/icon_white.png', 0),
    ('assets/images/icon_black.ico', 'assets/images/icon_black.png', 0),
)


def _png_frame(image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format='PNG', optimize=True)
    return buffer.getvalue()


def _dib_frame(image) -> bytes:
    from PIL import Image

    width, height = image.size
    # BITMAPINFOHEADER: the height covers the colour bitmap plus the AND mask.
    header = struct.pack('<IiiHHIIiiII', 40, width, height * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    bottom_up = image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    colour = bottom_up.tobytes('raw', 'BGRA')
    # 1-bit AND mask (1 = transparent). Windows uses the alpha channel of a
    # 32-bit frame, but legacy readers still expect a well-formed mask.
    alpha = bottom_up.getchannel('A').tobytes()
    stride = ((width + 31) // 32) * 4
    mask = bytearray(stride * height)
    for y in range(height):
        for x in range(width):
            if alpha[y * width + x] == 0:
                mask[y * stride + x // 8] |= 0x80 >> (x % 8)
    return header + colour + bytes(mask)


def build_ico(master, dib_max: int) -> bytes:
    from PIL import Image

    master = master.convert('RGBA')
    frames = []
    for size in SIZES:
        # Pillow resamples RGBA in premultiplied alpha, so edges stay clean.
        image = master.resize((size, size), Image.Resampling.LANCZOS)
        data = _dib_frame(image) if size <= dib_max else _png_frame(image)
        frames.append((size, data))

    directory = struct.pack('<HHH', 0, 1, len(frames))
    offset = len(directory) + 16 * len(frames)
    entries = b''
    for size, data in frames:
        # ICONDIRENTRY stores 256 as 0.
        entries += struct.pack('<BBBBHHII', size % 256, size % 256, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    return directory + entries + b''.join(data for _, data in frames)


def main() -> None:
    from PIL import Image

    for output, source, dib_max in ICONS:
        with Image.open(ROOT / source) as master:
            if master.width != master.height or master.width < SIZES[-1]:
                raise SystemExit(f'{source}: need a square master of at least {SIZES[-1]} px')
            data = build_ico(master, dib_max)
        (ROOT / output).write_bytes(data)
        print(f'{output}: {len(SIZES)} frames, {len(data)} bytes')


if __name__ == '__main__':
    main()

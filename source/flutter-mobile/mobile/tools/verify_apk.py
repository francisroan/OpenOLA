"""Verify a built OpenOLA APK really contains the newest source before install.

A stopped or interrupted `flutter build` can leave a stale kernel behind, so an
APK can pass every test yet lack recent changes. This script unpacks the APK,
searches the compiled Dart (libapp.so) and dex for marker strings, and prints
size and SHA-256.

    python tools/verify_apk.py [path/to/app-arm64-v8a-release.apk] [extra marker ...]

Exit status is non-zero if any marker is missing. Markers live in
tools/release_markers.txt (one per line, ASCII or UTF-8 text; non-ASCII text is
also searched as UTF-16 because Dart stores it that way).
"""
import hashlib
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_APK = HERE.parent / 'build/app/outputs/flutter-apk/app-arm64-v8a-release.apk'


def main(argv):
    apk = Path(argv[1]) if len(argv) > 1 and not argv[1].startswith('--') else DEFAULT_APK
    extra = [a for a in argv[2:]]
    markers = [m.strip() for m in (HERE / 'release_markers.txt').read_text(encoding='utf-8').splitlines()
               if m.strip() and not m.startswith('#')] + extra
    if not apk.is_file():
        print(f'APK not found: {apk}')
        return 2
    with zipfile.ZipFile(apk) as z:
        blobs = [z.read(n) for n in z.namelist()
                 if n.endswith('libapp.so') or n.endswith('.dex')]
    missing = []
    for m in markers:
        needles = [m.encode('utf-8'), m.encode('utf-16-le')]
        ok = any(n in b for b in blobs for n in needles)
        print(('  ok      ' if ok else '  MISSING ') + m)
        if not ok:
            missing.append(m)
    data = apk.read_bytes()
    print(f'\n{apk}\n  {len(data):,} bytes\n  SHA-256 {hashlib.sha256(data).hexdigest().upper()}')
    if missing:
        print(f'\nSTALE BUILD: {len(missing)} marker(s) missing. Clear .dart_tool/flutter_build and '
              'build/app/intermediates/flutter, rebuild, and verify again before installing.')
        return 1
    print('\nAll markers present.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))

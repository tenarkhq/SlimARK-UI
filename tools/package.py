#!/usr/bin/env python3
"""Builds the release zip, SlimARK-UI-<version>.zip, with the two addon folders.

Run from the repository root:  python3 tools/package.py [--out DIR]

What goes in: every file git tracks under SlimARK-UI/ and !SlimARK_Media/, except upstream oUF's
developer scripts in SlimARK-UI/Libs/oUF/utils/ (never loaded by the game). The repository's
LICENSE (MIT, the SlimARK code) goes into both addon folders as LICENSE.txt; the libraries keep
their own licence files. The version comes from the four TOC files, which must agree. The zip is
reproducible: sorted entries, the last commit's time on every entry, fixed permissions.

.pkgmeta lists the same exclusion for CurseForge's packager; tests/package_release.py checks
that both stay in step and that the zip holds everything the TOC and XML files load.
"""
import argparse
import os
import re
import subprocess
import sys
import time
import zipfile

ADDONS = ['SlimARK-UI', '!SlimARK_Media']
# Upstream oUF's own tools (docs and changelog generators): not part of the addon.
EXCLUDE = ['SlimARK-UI/Libs/oUF/utils/']
TOCS = [
    'SlimARK-UI/SlimARK-UI.toc',
    'SlimARK-UI/SlimARK-UI_Forever.toc',
    '!SlimARK_Media/!SlimARK_Media.toc',
    '!SlimARK_Media/!SlimARK_Media_Forever.toc',
]
LICENSE = 'LICENSE'


def root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def git(*args):
    return subprocess.run(['git', *args], cwd=root(), capture_output=True, text=True, check=True).stdout


def version():
    """The ## Version of the TOC files; all four must say the same."""
    found = {}
    for toc in TOCS:
        with open(os.path.join(root(), toc), encoding='utf-8') as f:
            match = re.search(r'^## Version:\s*(\S+)\s*$', f.read(), re.M)
        if not match:
            raise SystemExit(f'{toc}: no ## Version line')
        found[toc] = match.group(1)
    if len(set(found.values())) != 1:
        raise SystemExit('the TOC files disagree on the version: ' + ', '.join(f'{k}={v}' for k, v in found.items()))
    return next(iter(found.values()))


def excluded(path):
    return any(path.startswith(prefix) for prefix in EXCLUDE)


def files():
    """(name in the zip, file on disk) for every packaged file, sorted by name."""
    tracked = git('ls-files', '-z', '--', *ADDONS).split('\0')
    entries = [(path, path) for path in tracked if path and not excluded(path)]
    for addon in ADDONS:
        entries.append((f'{addon}/LICENSE.txt', LICENSE))
    return sorted(entries)


def build(out_dir):
    """Writes the zip into out_dir and returns its path."""
    name = f'SlimARK-UI-{version()}.zip'
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, name)
    stamp = time.gmtime(int(git('log', '-1', '--format=%ct').strip() or 0))[:6]
    stamp = max(stamp, (1980, 1, 1, 0, 0, 0))
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for arcname, source in files():
            info = zipfile.ZipInfo(arcname, date_time=stamp)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            with open(os.path.join(root(), source), 'rb') as f:
                zf.writestr(info, f.read())
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--out', default='dist', help='folder for the zip (default: dist)')
    args = parser.parse_args()
    out = args.out if os.path.isabs(args.out) else os.path.join(root(), args.out)
    path = build(out)
    with zipfile.ZipFile(path) as zf:
        count = len(zf.namelist())
    shown = os.path.relpath(path, root())
    print(f'{path if shown.startswith("..") else shown}: {count} files')


if __name__ == '__main__':
    sys.exit(main())

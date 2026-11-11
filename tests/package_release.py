#!/usr/bin/env python3
"""Checks the release zip that tools/package.py builds (audit F25, F21).

Run from the repository root:  python3 tests/package_release.py

The zip is built into a temporary folder twice and checked:
  - its name carries the TOC version; it holds the two addon folders and nothing else;
  - every file a TOC or an XML include loads is in it, and every Lua and XML file in it is loaded;
  - upstream oUF's developer scripts (Libs/oUF/utils) are left out, every other tracked addon file
    is in it, and so are the licence files;
  - every Interface\\AddOns\\... path the code and the TOCs name (font, textures, icon) is in it;
  - the two builds are byte for byte the same;
  - .pkgmeta excludes the same folder and moves out the same two addon folders.
Exits with 1 and the list of problems when anything is wrong.
"""
import hashlib
import importlib.util
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

spec = importlib.util.spec_from_file_location('package', os.path.join(ROOT, 'tools', 'package.py'))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)

problems = []
checks = 0


def check(cond, message):
    global checks
    checks += 1
    if not cond:
        problems.append(message)


def toc_files(text, base):
    """The files a TOC loads, as zip paths."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        out.append(base + '/' + line.split()[0].replace('\\', '/'))
    return out


def xml_files(data, base):
    """The files an XML file loads (Script and Include), as zip paths."""
    out = []
    for element in ET.fromstring(data).iter():
        tag = element.tag.split('}')[-1]
        if tag in ('Script', 'Include') and element.get('file'):
            out.append(os.path.normpath(base + '/' + element.get('file').replace('\\', '/')).replace(os.sep, '/'))
    return out


def media_paths():
    """Every Interface\\AddOns\\<addon>\\... path named in the addon code and the TOCs."""
    found = set()
    pattern = re.compile(r'Interface[\\/]+AddOns[\\/]+((?:SlimARK-UI|!SlimARK_Media)[\\/][^\'"\]\s|]+)', re.I)
    for addon in package.ADDONS:
        for folder, _, names in os.walk(os.path.join(ROOT, addon)):
            for name in names:
                if name.endswith(('.lua', '.toc', '.xml')):
                    with open(os.path.join(folder, name), encoding='utf-8', errors='replace') as f:
                        for match in pattern.finditer(f.read()):
                            found.add(re.sub(r'[\\/]+', '/', match.group(1)))
    return sorted(found)


def main():
    version = package.version()
    with tempfile.TemporaryDirectory() as tmp:
        first = package.build(os.path.join(tmp, 'a'))
        second = package.build(os.path.join(tmp, 'b'))
        check(os.path.basename(first) == f'SlimARK-UI-{version}.zip', f'zip name {os.path.basename(first)} does not carry version {version}')
        digest = [hashlib.sha256(open(p, 'rb').read()).hexdigest() for p in (first, second)]
        check(digest[0] == digest[1], 'two builds of the same tree differ (the zip is not reproducible)')
        with zipfile.ZipFile(first) as zf:
            names = zf.namelist()
            contents = {n: zf.read(n) for n in names}

    name_set = set(names)
    check(len(names) == len(name_set), 'the zip holds a file twice')
    tops = {n.split('/')[0] for n in names}
    check(tops == set(package.ADDONS), f'top level of the zip is {sorted(tops)}, expected {package.ADDONS}')

    # Upstream oUF's developer scripts are out; nothing else of the addon folders is lost.
    check(not [n for n in names if n.startswith('SlimARK-UI/Libs/oUF/utils/')], 'Libs/oUF/utils is in the zip')
    tracked = [p for p in package.git('ls-files', '-z', '--', *package.ADDONS).split('\0') if p]
    for path in tracked:
        if path.startswith('SlimARK-UI/Libs/oUF/utils/'):
            continue
        check(path in name_set, f'tracked addon file missing from the zip: {path}')
    for licence in ['SlimARK-UI/LICENSE.txt', '!SlimARK_Media/LICENSE.txt',
                    'SlimARK-UI/Libs/oUF/LICENSE.txt', 'SlimARK-UI/Media/SlimARK-font-OFL.txt']:
        check(licence in name_set, f'licence file missing from the zip: {licence}')

    # Everything the TOC and XML files load is there, and every Lua and XML file is loaded.
    loaded = set()
    for toc in package.TOCS:
        check(toc in name_set, f'TOC missing from the zip: {toc}')
        if toc not in name_set:
            continue
        base = toc.split('/')[0]
        queue = toc_files(contents[toc].decode('utf-8'), base)
        while queue:
            path = queue.pop()
            if path in loaded:
                continue
            loaded.add(path)
            check(path in name_set, f'{toc} loads {path}, which is not in the zip')
            if path.endswith('.xml') and path in name_set:
                queue.extend(xml_files(contents[path], os.path.dirname(path)))
    for name in names:
        if name.endswith(('.lua', '.xml')):
            check(name in loaded, f'{name} is in the zip but no TOC or XML loads it')

    # Every file path the code names under Interface\AddOns is in the zip (textures may leave out
    # the extension, the game then looks for .tga and .blp).
    for path in media_paths():
        options = [path] if os.path.splitext(path)[1] else [path + ext for ext in ('.tga', '.blp', '.png')]
        check(any(option in name_set for option in options), f'the code names {path}, which is not in the zip')

    # .pkgmeta: the same exclusion and the same two addon folders.
    with open(os.path.join(ROOT, '.pkgmeta'), encoding='utf-8') as f:
        pkgmeta = f.read()
    ignore = re.search(r'^ignore:\s*\n((?:\s+-\s*.*\n?)+)', pkgmeta, re.M)
    ignored = [line.strip()[1:].strip().strip('"') for line in ignore.group(1).splitlines()] if ignore else []
    for prefix in package.EXCLUDE:
        check(prefix.rstrip('/') in ignored, f'.pkgmeta does not ignore {prefix}')
    for addon in package.ADDONS:
        check(re.search(r'^\s+SlimARK-UI/' + re.escape(addon) + r':\s*"?' + re.escape(addon) + r'"?\s*$', pkgmeta, re.M) is not None,
              f'.pkgmeta does not move out {addon}')
    for addon in package.ADDONS:
        check(not any(i == addon or i.startswith(addon + '/') and not any(i == p.rstrip('/') for p in package.EXCLUDE) for i in ignored),
              f'.pkgmeta ignores part of {addon} beyond the exclusion')

    if problems:
        print(f'package_release: {len(problems)} of {checks} checks failed')
        for problem in problems:
            print('  FAIL ' + problem)
        return 1
    print(f'package_release: {checks} checks passed ({len(names)} files in SlimARK-UI-{version}.zip)')
    return 0


if __name__ == '__main__':
    sys.exit(main())

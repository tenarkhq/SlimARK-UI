#!/usr/bin/env python3
"""Checks the game API SlimARK-UI uses against each client's own UI source (audit F21).

Needs the network (or ready checkouts) and luacheck; it is not part of tests/run.py.

    python3 tools/apicheck.py --fetch                     # clone or update the sources, then check
    python3 tools/apicheck.py --source DIR                # use DIR/live, DIR/ptr, DIR/forever
    python3 tools/apicheck.py --luacheck /path/to/luacheck

The sources are the branches of https://github.com/Gethe/wow-ui-source (a mirror of the game's
own UI files): live = retail, ptr = the public test realm, forever = WoW Forever. For each client
the report gives the branch's commit and version.txt, then the result of every check:

  - every global the addon reads (luacheck's W113 list, own globals left out) is defined there:
    in a Lua file the client loads for its game type (live and ptr: standard, forever: camelot,
    read from the TOC files' AllowLoadGameType / ExcludeLoadGameType), in the generated API
    documentation, as a named XML frame, or at least used by Blizzard's own code (C-side and
    GlobalStrings names, which the mirror does not define);
  - DEPRECATED: a global defined only in a Blizzard_Deprecated* file. Those load only while the
    loadDeprecationFallbacks CVar is on and are announced for removal;
  - NOT LOADED: defined only in files the client does not load for its game type;
  - every C_Namespace.Function and Enum.Name.Field the addon names exists in that client.

A few names are allowed on purpose (ALLOWED below, each with its reason); they are listed in the
report. Exit code 0 when no client has a problem.
"""
import argparse
import glob
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = 'https://github.com/Gethe/wow-ui-source.git'
CLIENTS = {'live': 'standard', 'ptr': 'standard', 'forever': 'camelot'}
FAMILIES = {
    'mainline': {'mainline', 'standard', 'camelot', 'wowlabs', 'wowhack', 'plunderstorm'},
    'classic': {'classic', 'vanilla', 'tbc', 'wrath', 'cata', 'mists'},
}
FAMILY_OF = {gt: fam for fam, types in FAMILIES.items() for gt in types}
# [Game] in a TOC line stands for the game type's folder name.
GAME_FOLDER = {'standard': 'Standard', 'camelot': 'Camelot'}

ALLOWED = {
    'ShowChallengesKeystoneFrame': 'Keystone.lua calls it only after "if ShowChallengesKeystoneFrame" (WoW Forever has no Mythic+ UI)',
    'DoReadyCheck': 'MarkerBar.lua falls back to it only without C_PartyInfo.DoReadyCheck',
    'ConfirmReadyCheck': 'ReadyCheck.lua falls back to it only without C_PartyInfo.ConfirmReadyCheck',
    'SendChatMessage': 'Keystone.lua falls back to it only without C_ChatInfo.SendChatMessage',
    'GameTooltipTextLeft1': 'made at run time from GameTooltip\'s $parentTextLeft1 template',
    'GameTooltipTextLeft2': 'made at run time from GameTooltip\'s $parentTextLeft2 template',
    'ITEM_SPELL_TRIGGER_ONUSE': 'a GlobalStrings constant; the mirror has no GlobalStrings.lua',
}
OWN = re.compile(r'^(SlimARK|SLASH_SLIMARK|LibStub$)')


def sh(*cmd, cwd=None):
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=True).stdout


def fetch(source):
    os.makedirs(source, exist_ok=True)
    for branch in CLIENTS:
        path = os.path.join(source, branch)
        if os.path.isdir(os.path.join(path, '.git')):
            sh('git', 'fetch', '-q', '--depth', '1', 'origin', branch, cwd=path)
            sh('git', 'reset', '-q', '--hard', 'FETCH_HEAD', cwd=path)
        else:
            sh('git', 'clone', '-q', '--depth', '1', '--single-branch', '-b', branch, REPO, path)


def own_code():
    return sorted(glob.glob(os.path.join(ROOT, 'SlimARK-UI', '*.lua')))


def used_globals(luacheck):
    out = subprocess.run([luacheck, '--no-config', '--std', 'lua51', '--formatter', 'plain', '--codes', *own_code()],
                         capture_output=True, text=True).stdout
    reads, sets = set(), set()
    for code, name in re.findall(r'\((W11[13])\) \w+ (?:non-standard |undefined )?(?:global )?variable \'([^\']+)\'', out):
        (reads if code == 'W113' else sets).add(name)
    if not reads:
        raise SystemExit('luacheck gave no global list; is it working?\n' + out[-2000:])
    return {n for n in reads if not OWN.match(n) and n not in sets}


def strip_comments(text):
    text = re.sub(r'--\[(=*)\[.*?\]\1\]', '', text, flags=re.S)
    return re.sub(r'--[^\n]*', '', text)


def used_members():
    capi, enums = set(), set()
    for path in own_code():
        with open(path, encoding='utf-8') as f:
            text = strip_comments(f.read())
        capi |= set(re.findall(r'\b(C_[A-Za-z]+\.[A-Za-z_]+)', text))
        enums |= set(re.findall(r'\bEnum\.([A-Za-z]+(?:\.[A-Za-z_]+)?)', text))
    return capi, enums


def allowed_by_line(annotations, game_type):
    """Applies the [AllowLoadGameType ...] / [ExcludeLoadGameType ...] parts of a TOC line."""
    ok = True
    for kind, types in re.findall(r'\[(Allow|Exclude)LoadGameType\s+([^\]]+)\]', annotations):
        names = {t.strip() for t in types.split(',')}
        expanded = set()
        for name in names:
            expanded |= FAMILIES.get(name, {name})
        if kind == 'Allow' and game_type not in expanded:
            ok = False
        if kind == 'Exclude' and (game_type in names or FAMILY_OF.get(game_type) in names):
            ok = False
    return ok


TOC_SUFFIXES = ('Mainline', 'Standard', 'Camelot', 'Classic', 'Vanilla', 'TBC', 'Wrath', 'Cata', 'Mists')


def pick_toc(folder, game_type):
    """The TOC the client reads for an addon folder: one named for its game type, else for its
    family, else the plain one (the client's own TOC suffix rule)."""
    addon = os.path.basename(folder)
    family = 'Mainline' if FAMILY_OF.get(game_type) == 'mainline' else 'Classic'
    for suffix in (GAME_FOLDER.get(game_type, game_type.title()), family, None):
        path = os.path.join(folder, f'{addon}_{suffix}.toc' if suffix else f'{addon}.toc')
        if os.path.exists(path):
            return path
    plain = [p for p in glob.glob(os.path.join(folder, '*.toc'))
             if not os.path.basename(p)[:-4].endswith(tuple('_' + s for s in TOC_SUFFIXES))]
    return plain[0] if plain else None


def loaded_files(addons, game_type):
    """The Lua and XML files of Blizzard's addons that load for this game type."""
    family = 'Mainline' if FAMILY_OF.get(game_type) == 'mainline' else 'Classic'
    loaded = set()
    for folder in sorted(glob.glob(os.path.join(addons, '*'))):
        toc = os.path.isdir(folder) and pick_toc(folder, game_type)
        if not toc:
            continue
        with open(toc, encoding='utf-8', errors='replace') as f:
            text = f.read()
        top = re.search(r'^## AllowLoadGameType:\s*(.+)$', text, re.M)
        if top and not allowed_by_line('[AllowLoadGameType ' + top.group(1).strip() + ']', game_type):
            continue
        folder = os.path.dirname(toc)
        for line in text.splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split(None, 1)
            name, rest = parts[0], parts[1] if len(parts) > 1 else ''
            if not allowed_by_line(rest, game_type):
                continue
            name = name.replace('[Family]', family).replace('[Game]', GAME_FOLDER.get(game_type, game_type.title()))
            loaded.add(os.path.normcase(os.path.normpath(os.path.join(folder, name.replace('\\', os.sep)))))
    # A loaded XML file loads its <Script file> and <Include file> too: the path is taken from the
    # XML file's folder, or (as Blizzard's own files do) from the addon's folder.
    queue = [p for p in loaded if p.endswith('.xml')]
    while queue:
        xml = queue.pop()
        try:
            with open(xml, encoding='utf-8', errors='replace') as f:
                text = f.read()
        except OSError:
            continue
        rel_parts = os.path.relpath(xml, addons).split(os.sep)
        addon_folder = os.path.join(addons, rel_parts[0])
        for ref in re.findall(r'<(?:Script|Include)\s+file="([^"]+)"', text):
            ref = ref.replace('\\', os.sep)
            path = os.path.normpath(os.path.join(os.path.dirname(xml), ref))
            if not os.path.exists(path):
                path = os.path.normpath(os.path.join(addon_folder, ref))
            path = os.path.normcase(path)
            if path not in loaded:
                loaded.add(path)
                if path.endswith('.xml'):
                    queue.append(path)
    return loaded


def index(tree, game_type):
    addons = os.path.join(tree, 'Interface', 'AddOns')
    loaded = loaded_files(addons, game_type)
    defined, tokens, frames, docs_funcs, docs_enums = {}, set(), set(), set(), {}
    define = re.compile(r'^\s*(?:function\s+([A-Za-z_][\w.]*)\s*\(|([A-Za-z_][\w.]*)\s*=[^=])', re.M)

    def add_tokens(text):
        # Every name, and every dotted prefix of a dotted one (C_X, C_X.F; Enum.X, Enum.X.Y).
        for token in set(re.findall(r'[A-Za-z_]\w*(?:\.[A-Za-z_]\w*)*', text)):
            pieces = token.split('.')
            for i in range(1, len(pieces) + 1):
                tokens.add('.'.join(pieces[:i]))
            tokens.update(pieces)
    for path in glob.glob(os.path.join(addons, '**', '*.lua'), recursive=True):
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
        add_tokens(text)
        generated = 'Blizzard_APIDocumentationGenerated' in path
        if generated:
            namespace = re.search(r'Namespace\s*=\s*"([^"]+)"', text)
            prefix = namespace.group(1) + '.' if namespace else ''
            if namespace:
                docs_funcs.add(namespace.group(1))
            for name in re.findall(r'Name\s*=\s*"([^"]+)",\s*\n\s*Type\s*=\s*"Function"', text):
                docs_funcs.add(prefix + name)
            for name, body in re.findall(r'Name\s*=\s*"([^"]+)",\s*\n\s*Type\s*=\s*"Enumeration".*?Fields\s*=\s*\{(.*?)\n\t\t\t\},', text, re.S):
                docs_enums[name] = set(re.findall(r'Name\s*=\s*"([^"]+)"', body))
            continue
        for a, b in define.findall(text):
            defined.setdefault(a or b, set()).add(path)
    for path in glob.glob(os.path.join(addons, '**', '*.xml'), recursive=True):
        with open(path, encoding='utf-8', errors='replace') as f:
            text = f.read()
        frames |= set(re.findall(r'\bname="([A-Za-z_]\w*)"', text))
        add_tokens(text)
    return {'loaded': loaded, 'defined': defined, 'tokens': tokens, 'frames': frames,
            'funcs': docs_funcs, 'enums': docs_enums}


def deprecated(path):
    return re.search(r'[\\/]Blizzard_Deprecated\w*[\\/]', path) is not None


def check_client(name, tree, game_type, globals_, capi, enums):
    idx = index(tree, game_type)
    problems, allowed = [], []
    for g in sorted(globals_):
        files = idx['defined'].get(g, set())
        loaded = {f for f in files if os.path.normcase(os.path.normpath(f)) in idx['loaded']}
        verdict = None
        if loaded and not all(deprecated(f) for f in loaded):
            continue
        if loaded:
            verdict = 'DEPRECATED: only the CVar-gated fallback ' + ', '.join(sorted(os.path.relpath(f, tree) for f in loaded))
        elif files:
            verdict = 'NOT LOADED for ' + game_type + ': defined only in ' + ', '.join(sorted(os.path.relpath(f, tree) for f in files))
        elif g in idx['funcs'] or g in idx['frames'] or g in idx['tokens']:
            continue
        else:
            verdict = 'MISSING: not in this client\'s UI source'
        (allowed if g in ALLOWED else problems).append(f'{g}: {verdict}' + (f' (allowed: {ALLOWED[g]})' if g in ALLOWED else ''))
    for member in sorted(capi):
        if member in idx['funcs'] or member in idx['defined'] or member in idx['tokens']:
            continue
        problems.append(f'{member}: MISSING: no such C_ function in this client')
    for enum in sorted(enums):
        parts = enum.split('.')
        fields = idx['enums'].get(parts[0])
        if fields is not None and (len(parts) == 1 or parts[1] in fields):
            continue
        if 'Enum.' + enum in idx['tokens'] or (len(parts) == 2 and parts[1] in idx['tokens'] and parts[0] in idx['tokens']):
            continue
        problems.append(f'Enum.{enum}: MISSING: no such enum value in this client')
    return problems, allowed


def main():
    parser = argparse.ArgumentParser(description='Checks the game API SlimARK-UI uses against each client\'s UI source.')
    parser.add_argument('--source', default=os.path.join(ROOT, '.cache', 'wow-ui-source'),
                        help='folder with the live, ptr and forever checkouts (default: .cache/wow-ui-source)')
    parser.add_argument('--fetch', action='store_true', help='clone or update the checkouts first (needs the network)')
    parser.add_argument('--luacheck', default='luacheck', help='the luacheck command')
    args = parser.parse_args()
    if args.fetch:
        fetch(args.source)
    globals_ = used_globals(args.luacheck)
    capi, enums = used_members()
    print(f'SlimARK-UI reads {len(globals_)} game globals, {len(capi)} C_ functions, {len(enums)} Enum names')
    failed = False
    for name, game_type in CLIENTS.items():
        tree = os.path.join(args.source, name)
        if not os.path.isdir(os.path.join(tree, 'Interface')):
            print(f'\n[{name}] no checkout in {tree} (use --fetch)')
            failed = True
            continue
        commit = sh('git', 'rev-parse', 'HEAD', cwd=tree).strip() if os.path.isdir(os.path.join(tree, '.git')) else '?'
        version = open(os.path.join(tree, 'version.txt')).read().strip() if os.path.exists(os.path.join(tree, 'version.txt')) else '?'
        problems, allowed = check_client(name, tree, game_type, globals_, capi, enums)
        print(f'\n[{name}] game type {game_type}, version {version}, {REPO} @ {commit}')
        for line in allowed:
            print('  allowed  ' + line)
        for line in problems:
            print('  PROBLEM  ' + line)
        print(f'  {len(problems)} problem(s), {len(allowed)} allowed')
        failed = failed or bool(problems)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Runs every SlimARK-UI check. From the repository root:  python3 tests/run.py

1. Syntax: every Lua file of both addons (vendored libraries included) compiles in Lua 5.1 and
   in LuaJIT.
2. TOC files: the four agree on ## Version, which is also the newest CHANGELOG.md heading; the
   interface numbers are the expected ones; the retail and the Forever TOC of an addon load the
   same files; every file a TOC or an XML include loads exists (exact case); every Lua and XML
   file of the addons is loaded by something.
3. Lua tests: tests/claude/*.lua and tests/codex/*.lua (not the lib/ helpers), each in its own
   process, from the repository root, once with Lua 5.1 and once with LuaJIT. A test passes when
   it exits with 0.
4. Python tests: tests/package_*.py, each in its own process.

The Lua engines are lupa's (pinned in requirements-test.txt): no system Lua is needed.
Exit code 0 only when every check passes. A short summary on success; the full output of every
failing check otherwise.

Options: --engine lua51|luajit (repeat to pick; default both), --only TEXT (run only the tests
whose path holds TEXT), -v (show the output of passing tests too).
"""
import argparse
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINES = {'lua51': 'lupa.lua51', 'luajit': 'lupa.luajit21'}
ADDONS = ['SlimARK-UI', '!SlimARK_Media']
# Change these with the game clients: retail and PTR in one TOC, WoW Forever in the other.
INTERFACE = {'retail': '120105, 120107', 'forever': '16001'}
TOCS = {
    'SlimARK-UI/SlimARK-UI.toc': 'retail',
    'SlimARK-UI/SlimARK-UI_Forever.toc': 'forever',
    '!SlimARK_Media/!SlimARK_Media.toc': 'retail',
    '!SlimARK_Media/!SlimARK_Media_Forever.toc': 'forever',
}
TEST_DIRS = ['tests/claude', 'tests/codex']
TIMEOUT = 300


def runtime(engine):
    import importlib
    try:
        module = importlib.import_module(ENGINES[engine])
    except ImportError as err:
        raise SystemExit(f'{ENGINES[engine]} is missing ({err}). Install the test requirements: '
                         'python3 -m pip install -r requirements-test.txt')
    return module.LuaRuntime(unpack_returned_tuples=True)


def child(engine, path):
    """Runs one Lua test file in this process (called by the parent in a new process)."""
    os.chdir(ROOT)
    lua = runtime(engine)
    run = lua.eval('''function(path)
        arg = { [0] = path }
        local ok, err = xpcall(function() dofile(path) end, debug.traceback)
        if not ok then
            io.stderr:write(tostring(err), '\\n')
            io.stderr:flush()
            os.exit(1)
        end
        io.stdout:flush()
    end''')
    run(path)
    return 0


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, '/')


def addon_files(ext):
    out = []
    for addon in ADDONS:
        for folder, _, names in os.walk(os.path.join(ROOT, addon)):
            for name in names:
                if name.endswith(ext):
                    out.append(rel(os.path.join(folder, name)))
    return sorted(out)


def check_syntax(engines):
    problems, count = [], 0
    files = addon_files('.lua')
    for engine in engines:
        lua = runtime(engine)
        compile_ = lua.eval('function(src, name) local f, err = loadstring(src, name) return f ~= nil, err end')
        for path in files:
            with open(os.path.join(ROOT, path), encoding='utf-8') as f:
                ok, err = compile_(f.read(), '@' + path)
            count += 1
            if not ok:
                problems.append(f'{engine}: {err}')
    return count, problems


def toc_headers(text):
    return dict(re.findall(r'^##\s*([^:]+?)\s*:\s*(.*?)\s*$', text, re.M))


def toc_files(text):
    out = []
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            out.append(line.split()[0].replace('\\', '/'))
    return out


def exists_exact(path):
    """True when the path exists with exactly this case (the game on macOS and Linux cares)."""
    current = ROOT
    for part in path.split('/'):
        if part not in os.listdir(current):
            return False
        current = os.path.join(current, part)
    return True


def check_tocs():
    problems, count = [], 0
    versions, lists, loaded = {}, {}, set()
    for toc, flavor in TOCS.items():
        count += 1
        if not exists_exact(toc):
            problems.append(f'{toc} is missing')
            continue
        with open(os.path.join(ROOT, toc), encoding='utf-8') as f:
            text = f.read()
        headers = toc_headers(text)
        versions[toc] = headers.get('Version')
        count += 1
        if headers.get('Interface') != INTERFACE[flavor]:
            problems.append(f'{toc}: ## Interface is {headers.get("Interface")!r}, expected {INTERFACE[flavor]!r} ({flavor})')
        if toc.startswith('SlimARK-UI/'):
            count += 1
            if headers.get('X-SlimARK-Flavor') != flavor:
                problems.append(f'{toc}: ## X-SlimARK-Flavor is {headers.get("X-SlimARK-Flavor")!r}, expected {flavor!r}')
        base = toc.split('/')[0]
        files = toc_files(text)
        lists.setdefault(base, {})[flavor] = files
        queue = [base + '/' + f for f in files]
        while queue:
            path = queue.pop()
            if path in loaded:
                continue
            loaded.add(path)
            count += 1
            if not exists_exact(path):
                problems.append(f'{toc} loads {path}, which does not exist (exact case)')
                continue
            if path.endswith('.xml'):
                tree = ET.parse(os.path.join(ROOT, path))
                for element in tree.iter():
                    if element.tag.split('}')[-1] in ('Script', 'Include') and element.get('file'):
                        target = os.path.normpath(os.path.join(os.path.dirname(path), element.get('file').replace('\\', '/')))
                        queue.append(target.replace(os.sep, '/'))
    count += 1
    if len(set(versions.values())) != 1 or None in versions.values():
        problems.append('the TOC files disagree on ## Version: ' + ', '.join(f'{k}={v}' for k, v in versions.items()))
    with open(os.path.join(ROOT, 'CHANGELOG.md'), encoding='utf-8') as f:
        newest = re.search(r'^##\s+(\S+)', f.read(), re.M)
    count += 1
    version = next(iter(versions.values()), None)
    if not newest or newest.group(1) != version:
        problems.append(f'the newest CHANGELOG.md heading is {newest and newest.group(1)!r}, the TOC version {version!r}')
    for base, by_flavor in lists.items():
        count += 1
        if by_flavor.get('retail') != by_flavor.get('forever'):
            problems.append(f'{base}: the retail and the Forever TOC load different files')
    for path in addon_files('.lua') + addon_files('.xml'):
        count += 1
        if path not in loaded:
            problems.append(f'{path} is not loaded by any TOC or XML file')
    return count, problems


def discover(only):
    lua_tests, py_tests = [], []
    for folder in TEST_DIRS:
        full = os.path.join(ROOT, folder)
        if os.path.isdir(full):
            lua_tests += [f'{folder}/{n}' for n in sorted(os.listdir(full)) if n.endswith('.lua')]
    py_tests = sorted(f'tests/{n}' for n in os.listdir(os.path.join(ROOT, 'tests'))
                      if n.startswith('package_') and n.endswith('.py'))
    if only:
        lua_tests = [t for t in lua_tests if only in t]
        py_tests = [t for t in py_tests if only in t]
    return lua_tests, py_tests


def run(cmd):
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=TIMEOUT)
        return proc.returncode, proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as err:
        return 124, f'timed out after {TIMEOUT} s\n{err.stdout or ""}{err.stderr or ""}'


def summary(output):
    match = re.findall(r'(\d+) passed, (\d+) failed', output)
    if match:
        return f'{match[-1][0]} checks'
    match = re.findall(r'(\d+) checks passed', output)
    return f'{match[-1]} checks' if match else 'ok'


def main():
    if len(sys.argv) == 4 and sys.argv[1] == '--child':
        return child(sys.argv[2], sys.argv[3])
    parser = argparse.ArgumentParser(description='Runs every SlimARK-UI check.')
    parser.add_argument('--engine', action='append', choices=sorted(ENGINES), help='Lua engine (default: both)')
    parser.add_argument('--only', help='run only the tests whose path holds this text')
    parser.add_argument('-v', '--verbose', action='store_true', help='show the output of passing tests too')
    args = parser.parse_args()
    engines = args.engine or ['lua51', 'luajit']
    failures = []

    count, problems = check_syntax(engines)
    print(f'syntax      {count - len(problems)}/{count} Lua files compile ({", ".join(engines)})')
    failures += [('syntax', p) for p in problems]

    count, problems = check_tocs()
    print(f'toc         {count - len(problems)}/{count} TOC checks pass')
    failures += [('toc', p) for p in problems]

    lua_tests, py_tests = discover(args.only)
    passed = 0
    for path in lua_tests:
        for engine in engines:
            code, output = run([sys.executable, os.path.join(ROOT, 'tests', 'run.py'), '--child', engine, path])
            if code == 0:
                passed += 1
                if args.verbose:
                    print(f'  ok   {engine:6} {path}  {summary(output)}\n{output}')
            else:
                failures.append((f'{engine} {path} (exit {code})', output))
    print(f'lua tests   {passed}/{len(lua_tests) * len(engines)} runs pass ({len(lua_tests)} files x {len(engines)} engines)')

    passed = 0
    for path in py_tests:
        code, output = run([sys.executable, os.path.join(ROOT, path)])
        if code == 0:
            passed += 1
            if args.verbose:
                print(f'  ok   {path}\n{output}')
        else:
            failures.append((f'{path} (exit {code})', output))
    print(f'py tests    {passed}/{len(py_tests)} pass')

    if failures:
        print(f'\nFAILED: {len(failures)} problem(s)')
        for title, detail in failures:
            print(f'\n--- {title}\n{detail.rstrip()}')
        return 1
    print('\nall checks passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Release tooling must fail visibly and preserve a developer's local source edits."""
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('apicheck', ROOT / 'tools/apicheck.py')
apicheck = importlib.util.module_from_spec(spec)
spec.loader.exec_module(apicheck)


def git(folder, *args):
    return subprocess.run(
        ['git', '-c', 'user.name=Tooling test', '-c', 'user.email=tooling-test@example.invalid', *args],
        cwd=folder, capture_output=True, text=True, check=True,
    ).stdout.strip()


class SelectionTests(unittest.TestCase):
    def test_missing_filter_fails(self):
        result = subprocess.run(
            [sys.executable, 'tests/run.py', '--engine', 'lua51', '--only', 'no-such-test-7db58049'],
            cwd=ROOT, capture_output=True, text=True, timeout=60,
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('No tests match --only', result.stdout + result.stderr)

    def test_matching_filter_still_runs(self):
        result = subprocess.run(
            [sys.executable, 'tests/run.py', '--engine', 'lua51', '--only', 'config-settings.lua'],
            cwd=ROOT, capture_output=True, text=True, timeout=60,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('1/1 runs pass', result.stdout)


class CheckoutTests(unittest.TestCase):
    def setUp(self):
        cache = ROOT / '.cache'
        cache.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(prefix='tooling-test-', dir=cache)
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        self.origin = base / 'origin'
        self.origin.mkdir()
        git(self.origin, 'init', '-q', '-b', 'live')
        (self.origin / 'note.txt').write_text('old upstream\n', encoding='utf-8')
        git(self.origin, 'add', 'note.txt')
        git(self.origin, 'commit', '-qm', 'initial source')
        self.sources = base / 'sources'
        self.sources.mkdir()
        self.checkout = self.sources / 'live'
        git(self.sources, 'clone', '-q', str(self.origin), str(self.checkout))
        self.before = git(self.checkout, 'rev-parse', 'HEAD')
        (self.origin / 'note.txt').write_text('new upstream\n', encoding='utf-8')
        git(self.origin, 'commit', '-qam', 'source update')
        self.after = git(self.origin, 'rev-parse', 'HEAD')
        original_clients, original_repo = apicheck.CLIENTS, apicheck.REPO
        apicheck.CLIENTS = {'live': 'standard'}
        apicheck.REPO = str(self.origin)
        self.addCleanup(setattr, apicheck, 'CLIENTS', original_clients)
        self.addCleanup(setattr, apicheck, 'REPO', original_repo)

    def assert_preserved(self):
        status = git(self.checkout, 'status', '--porcelain')
        with self.assertRaisesRegex(SystemExit, 'local changes'):
            apicheck.fetch(str(self.sources))
        self.assertEqual(git(self.checkout, 'rev-parse', 'HEAD'), self.before)
        self.assertEqual(git(self.checkout, 'status', '--porcelain'), status)

    def test_tracked_edits_survive(self):
        (self.checkout / 'note.txt').write_text('local working edit\n', encoding='utf-8')
        self.assert_preserved()
        self.assertEqual((self.checkout / 'note.txt').read_text(), 'local working edit\n')

    def test_staged_edits_survive(self):
        (self.checkout / 'note.txt').write_text('local staged edit\n', encoding='utf-8')
        git(self.checkout, 'add', 'note.txt')
        self.assert_preserved()
        self.assertEqual(git(self.checkout, 'show', ':note.txt'), 'local staged edit')
        self.assertEqual((self.checkout / 'note.txt').read_text(), 'local staged edit\n')

    def test_untracked_files_survive(self):
        # This name also exists upstream: reset --hard would remove the local file.
        (self.origin / 'new.txt').write_text('upstream file\n', encoding='utf-8')
        git(self.origin, 'add', 'new.txt')
        git(self.origin, 'commit', '-qm', 'add file')
        (self.checkout / 'new.txt').write_text('untracked local file\n', encoding='utf-8')
        self.assert_preserved()
        self.assertEqual((self.checkout / 'new.txt').read_text(), 'untracked local file\n')

    def test_clean_checkout_updates(self):
        apicheck.fetch(str(self.sources))
        self.assertEqual(git(self.checkout, 'rev-parse', 'HEAD'), self.after)
        self.assertEqual((self.checkout / 'note.txt').read_text(), 'new upstream\n')

    def test_absent_checkout_clones(self):
        fresh = self.sources / 'fresh'
        apicheck.fetch(str(fresh))
        self.assertEqual(git(fresh / 'live', 'rev-parse', 'HEAD'), self.after)
        self.assertEqual((fresh / 'live/note.txt').read_text(), 'new upstream\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)

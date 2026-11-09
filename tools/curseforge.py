#!/usr/bin/env python3
"""Makes CURSEFORGE.md from README.md.

README.md is the one description. CurseForge needs a paste-in text whose pictures have full
links, so this script:
  - leaves out the parts between <!-- github-only --> and <!-- /github-only -->, and every
    other HTML comment;
  - turns each picture path assets/... into a raw.githubusercontent.com link, pinned to the
    last commit that changed that picture (push that commit before pasting).

Run from the repository root: python3 tools/curseforge.py
"""
import re
import subprocess
import sys

REPO = 'tenarkhq/SlimARK-UI'


def last_commit(path):
    out = subprocess.run(['git', 'log', '-1', '--format=%H', '--', path], capture_output=True, text=True, check=True).stdout.strip()
    if not out:
        sys.exit(f'{path} is not committed yet: commit it first')
    return out


def main():
    text = open('README.md', encoding='utf-8').read()
    text = re.sub(r'<!-- github-only -->.*?<!-- /github-only -->\n*', '', text, flags=re.S)
    text = re.sub(r'<!--.*?-->\n?', '', text, flags=re.S)

    def link(match):
        path = match.group(2)
        return f'{match.group(1)}(https://raw.githubusercontent.com/{REPO}/{last_commit(path)}/{path})'

    text = re.sub(r'(!\[[^\]]*\])\((assets/[^)\s]+)\)', link, text)
    left = re.findall(r'\]\((?!https?://|#)([^)]+)\)', text)
    if left:
        sys.exit('relative links left, CurseForge cannot open them: ' + ', '.join(left))
    text = re.sub(r'\n{3,}', '\n\n', text).strip() + '\n'
    open('CURSEFORGE.md', 'w', encoding='utf-8').write(text)
    print('CURSEFORGE.md written')


if __name__ == '__main__':
    main()

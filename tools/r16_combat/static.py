#!/usr/bin/env python3
"""Parser, global writes and all five Lua 5.1 sweeps; no PUC execution."""
import os
import pathlib
import subprocess
repo = pathlib.Path(__file__).resolve().parents[2]
paths = subprocess.check_output(['git', 'diff', '--name-only', '--ignore-submodules=all', '9a387332', '--', '*.lua'], cwd=repo, text=True).splitlines()
paths += subprocess.check_output(['git', 'ls-files', '--others', '--exclude-standard', '--', '*.lua'], cwd=repo, text=True).splitlines()
paths = sorted(set(paths))
parser = os.environ.get('GRUG_LUAC51', str(repo / 'tools/bin/luac51'))
for path in paths:
    subprocess.run([parser, '-p', path], cwd=repo, check=True)
    listing = subprocess.check_output([parser, '-l', '-p', path], cwd=repo, text=True)
    for line in listing.splitlines():
        if 'SETGLOBAL' in line:
            print('GLOBAL', path, line.strip())
print('PARSER PASS files=' + str(len(paths)))
patterns = [r'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::',
 r'\\u\{|\\x[0-9A-Fa-f]|\\z',
 r'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.',
 r'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]',
 r'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.']
roots = [str(path.relative_to(repo)) for path in repo.glob('mods/*/grug_*')]
roots += [path for path in paths if path.startswith('tools/')]
for number, pattern in enumerate(patterns, 1):
    result = subprocess.run(['rg', '-n', '--glob', '*.lua', '--', pattern] + roots,
                            cwd=repo, text=True, capture_output=True)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr)
    print('SWEEP', number)
    print(result.stdout.rstrip() or 'no hits')
print('Review globals and comment/string-only matches explicitly.')

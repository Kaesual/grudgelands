#!/usr/bin/env python3
"""Final parser, explicit global-write inventory, and five source sweeps."""
import pathlib, subprocess
repo = pathlib.Path(__file__).resolve().parents[2]
tracked = subprocess.check_output(["git", "diff", "--name-only", "2c0f4446", "--", "*.lua"], cwd=repo, text=True).splitlines()
new = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard", "--", "*.lua"], cwd=repo, text=True).splitlines()
files = sorted(p for p in set(tracked + new) if (repo / p).is_file())
patterns = [r"(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::",
 r"\\u\{|\\x[0-9A-Fa-f]|\\z",
 r"table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.",
 r'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]',
 r"\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\."]
for path in files:
 subprocess.run([str(repo / "tools/bin/luac51"), "-p", path], cwd=repo, check=True)
 listing = subprocess.check_output([str(repo / "tools/bin/luac51"), "-l", "-p", path], cwd=repo, text=True)
 for line in listing.splitlines():
  if "SETGLOBAL" in line: print("GLOBAL", path, line.strip())
print("PARSER PASS files=" + str(len(files)))
for index, pattern in enumerate(patterns, 1):
 result = subprocess.run(["rg", "-n", "--", pattern] + files, cwd=repo, text=True, capture_output=True)
 if result.returncode not in (0, 1): raise RuntimeError(result.stderr)
 print("SWEEP " + str(index))
 print(result.stdout.rstrip() or "no hits")
print("Inspect all global writes and sweep hits; strings/comments may match.")

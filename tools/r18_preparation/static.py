#!/usr/bin/env python3
"""Final parser, explicit global-write inventory, and five source sweeps."""
import os, pathlib, subprocess
repo = pathlib.Path(__file__).resolve().parents[2]
parser = os.environ.get("LUAC51", str(repo / "tools/bin/luac51"))
files = ["mods/CORE/grug_core/starts_preload.lua", "tools/r18_preparation/fixture.lua"]
sweep_files = sorted(str(p.relative_to(repo)) for pack in (repo / "mods").iterdir()
 for mod in pack.glob("grug_*") for p in mod.rglob("*.lua")) + files[1:]
patterns = [r"(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::",
 r"\\u\{|\\x[0-9A-Fa-f]|\\z",
 r"table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.",
 r'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]',
 r"\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\."]
for path in files:
 subprocess.run([parser, "-p", path], cwd=repo, check=True)
 listing = subprocess.check_output([parser, "-l", "-p", path], cwd=repo, text=True)
 for line in listing.splitlines():
  if "SETGLOBAL" in line: print("GLOBAL", path, line.strip())
print("PARSER PASS files=" + str(len(files)))
for index, pattern in enumerate(patterns, 1):
 result = subprocess.run(["rg", "-n", "--", pattern] + sweep_files, cwd=repo, text=True, capture_output=True)
 if result.returncode not in (0, 1): raise RuntimeError(result.stderr)
 print("SWEEP " + str(index))
 print(result.stdout.rstrip() or "no hits")
print("Inspect all global writes and sweep hits; strings/comments may match.")

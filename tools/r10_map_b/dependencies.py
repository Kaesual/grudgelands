#!/usr/bin/env python3
"""Check shipped hard dependencies before starting an isolated engine witness."""
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
mods = {}
for path in sorted((root / "mods").rglob("mod.conf")):
    fields = {}
    for line in path.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip()
    name = fields.get("name", path.parent.name)
    assert name not in mods, f"duplicate mod: {name}"
    mods[name] = [value.strip() for value in fields.get("depends", "").split(",") if value.strip()]
visited = set()
active = []
def visit(name):
    assert name in mods, f"missing hard dependency: {name}"
    assert name not in active, "hard dependency cycle: " + " -> ".join(active + [name])
    if name in visited:
        return
    active.append(name)
    for dependency in sorted(mods[name]):
        visit(dependency)
    active.pop()
    visited.add(name)
for name in sorted(mods):
    visit(name)
print(f"PASS hard dependency graph: {len(mods)} mods")

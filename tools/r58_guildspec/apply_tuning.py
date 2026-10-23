#!/usr/bin/env python3
"""Write the tuning page's accepted numbers into the guild catalogue.

    python3 tools/r58_guildspec/apply_tuning.py PICKS.json [--dry-run]

PICKS.json is the page's document `picks/tuning` ({"values": {key: number},
...}). Every key of `values` that names a line `["key"] = <number>,` of
mods/PLAYER/grug_guild/catalog.lua VALUES gets the new number; the page's
model assumptions (`model.*`) are not catalogue numbers and are skipped. A
key the catalogue does not have is reported and changes nothing. Numbers are
written as integers (every catalogue number is a whole number). Afterwards:
`luajit tools/r58_guildspec/portable_test.lua .` (catalogue shape, the
anti-loop check) and `luajit tools/r58_guildspec/write_doc.lua .` (the spec's
generated model tables).
"""
from pathlib import Path
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "mods/PLAYER/grug_guild/catalog.lua"
LINE = re.compile(r'^(\t\["(?P<key>[^"]+)"\] = )(?P<value>-?[0-9.]+)(,.*)$')


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    picks = json.loads(Path(argv[1]).read_text(encoding="utf-8"))
    values = picks.get("values", picks)
    lines = CATALOG.read_text(encoding="utf-8").split("\n")
    index = {}
    for number, line in enumerate(lines):
        match = LINE.match(line)
        if match:
            index[match.group("key")] = number
    changed, unknown = [], []
    for key, new in sorted(values.items()):
        if key.startswith("model."):
            continue
        if key not in index:
            unknown.append(key)
            continue
        if not isinstance(new, (int, float)) or new != new or new < 0 or new != int(new):
            raise SystemExit(f"not a whole number for {key}: {new!r}")
        match = LINE.match(lines[index[key]])
        if float(match.group("value")) != float(new):
            changed.append(f"{key}: {match.group('value')} -> {int(new)}")
            lines[index[key]] = match.group(1) + str(int(new)) + match.group(4)
    for line in changed:
        print("changed " + line)
    for key in unknown:
        print("unknown key (ignored) " + key)
    if "--dry-run" not in argv:
        CATALOG.write_text("\n".join(lines), encoding="utf-8")
    print(f"{len(changed)} value(s) changed, {len(unknown)} unknown")


if __name__ == "__main__":
    main(sys.argv)

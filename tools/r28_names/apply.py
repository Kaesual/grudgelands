#!/usr/bin/env python3
"""Round 28 Lane N1: write the proposed display names of
docs/planning/round28/mobs/names-proposal.json into the catalogue data.

Touches only `display`, `display_by_zone` values (subtypes.json) and `name`
(items.json), in the shipped game data and in the design catalogue copy, so
the copies stay byte-identical. Ids, levels and every other field are left
as they are. Idempotent.

    python3 tools/r28_names/apply.py
"""
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TARGETS = [REPO / "mods/ENTITIES/grug_mobs/data", REPO / "docs/planning/round28/design/catalog"]


def dump(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main():
    proposal = json.loads((REPO / "docs/planning/round28/mobs/names-proposal.json").read_text(encoding="utf-8"))
    roles = {r["role"]: r for r in proposal["roles"]}
    items = {i["id"]: i for i in proposal["items"]}
    for base in TARGETS:
        changed = 0
        path = base / "subtypes.json"
        subtypes = json.loads(path.read_text(encoding="utf-8"))
        for st in subtypes:
            p = roles[st["role"]]
            if st["display"] != p["proposed"]:
                st["display"] = p["proposed"]
                changed += 1
            for zone, v in (p.get("by_zone") or {}).items():
                if st["display_by_zone"][zone] != v["proposed"]:
                    st["display_by_zone"][zone] = v["proposed"]
                    changed += 1
        dump(path, subtypes)
        path = base / "items.json"
        rows = json.loads(path.read_text(encoding="utf-8"))
        for row in rows:
            if row["name"] != items[row["id"]]["proposed"]:
                row["name"] = items[row["id"]]["proposed"]
                changed += 1
        dump(path, rows)
        print("%s: %d names written" % (base.relative_to(REPO), changed))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Round 28 Lane B4 content migration, step 2 (one-off; ran on main 7af1aaf2).

Splits today's 240 registered quests (legacy_raw.json from dump_legacy.lua)
mechanically into one quest file per zone, the format of
docs/planning/round28-design-frame.md section 4.7 with the legacy-only fields
of B4's split (fixed `xp`, kill objectives with `mobs` entity names and
`zone`, `faction` and `race` gates). A quest goes into the zone file of its
giver (the zone atlas docs/planning/round28/zones/ says where each quest NPC
stands); a hub is the giver's settlement. Every giver gets the line `legacy`;
the 31-40 outpost givers and each capital's envoy also declare the reserved
line `front` (frame 2.1), so the front lane's files validate against these
host files. Also writes the quest NPC table (npcs.lua).

Ruling 29: the generator's two target lists naming grug_mobs:wild_turkey (a
critter) reach the registry once: r14_human_05 hunts foxes instead (they take
the flock) and its text names them. The other list (chain step 6) was never
registered: step 6 is the travel quest r14_human_06, a talk objective.

Usage (repo root): python3 tools/r28_b4_quests/migrate/split_quests.py RAW_JSON
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "r28_design"))
import r28common as C  # noqa: E402

OUT = REPO / "mods" / "PLAYER" / "grug_quests" / "data" / "zones"
NPCS = REPO / "mods" / "PLAYER" / "grug_quests" / "npcs.lua"
TURKEY = "grug_mobs:wild_turkey"
RULING_29 = {
    "r14_human_05_the_missing_flock": (
        ["grug_mobs:fox"],
        "Wild turkeys draw off Dawnmere's village flock by day.",
        "Foxes draw off Dawnmere's village flock by day."),
}


def objective(raw):
    out = {"type": raw["type"]}
    if raw["type"] == "kill":
        out["mobs"] = raw["mobs"]
        if raw.get("zone"):
            out["zone"] = raw["zone"]
    elif raw["type"] == "item":
        out["item"] = raw["item"]
    else:
        out["npc"] = raw["npc"]
        assert raw["count"] == 1
        return out
    out["count"] = raw["count"]
    return out


def main(raw_path):
    calls = json.loads(Path(raw_path).read_text())
    atlas = C.Atlas(REPO / "docs" / "planning" / "round28" / "zones")
    npcs = [c for c in calls if c["kind"] == "npc"]
    quests = [c for c in calls if c["kind"] == "quest"]
    files = {}
    for call in quests:
        qid, d = call["id"], call["def"]
        giver = d["npc"]
        zone = atlas.npc_zone[giver]
        where = atlas.zones[zone]["npcs"][giver]
        data = files.setdefault(zone, {"zone": zone, "hubs": {}, "quests": []})
        hub = data["hubs"].setdefault(where["settlement"], {
            "id": where["settlement"], "anchor": where["settlement"], "givers": {}})
        hub["givers"].setdefault(giver, {"npc": giver, "lines": ["legacy"]})
        text = d["description"]
        objectives = [objective(o) for o in d["objectives"]]
        if qid in RULING_29:
            mobs, old, new = RULING_29[qid]
            assert TURKEY in objectives[0]["mobs"] and old in text
            objectives[0]["mobs"] = mobs
            text = text.replace(old, new)
        for o in objectives:
            assert TURKEY not in o.get("mobs", []), qid
        q = {"id": qid, "line": "legacy", "giver": giver,
             "turnin": d.get("turnin_npc") or giver,
             "min_level": d["min_level"], "level": d["target_level"],
             "requires": d["prerequisites"], "faction": d["faction"]}
        if d.get("race"):
            q["race"] = d["race"]
        q.update({"title": d["title"], "text": text, "objectives": objectives,
                  "rewards": {"xp": d["rewards"]["xp"], "copper": d["rewards"]["copper"],
                              "items": d["rewards"].get("items") or []}})
        data["quests"].append(q)
    OUT.mkdir(parents=True, exist_ok=True)
    count = 0
    for zone, data in sorted(files.items()):
        info = atlas.zones[zone]
        for hub in data["hubs"].values():
            for npc, giver in hub["givers"].items():
                kind = info["anchor_kinds"].get(info["npcs"][npc]["anchor"])
                contested_outpost = info["role"] == "contested" and kind == "outpost" and len(info["npcs"]) > 1
                capital_envoy = info["role"] == "capital" and npc.endswith("_capital_envoy")
                if contested_outpost or capital_envoy:
                    giver["lines"].append("front")
            hub["givers"] = list(hub["givers"].values())
        out = {"zone": zone,
               "notes": "Mechanical split of the pre-Round-28 quests (legacy fields, line 'legacy'); "
                        "the zone's design replaces this file.",
               "hubs": list(data["hubs"].values()), "quests": data["quests"]}
        (OUT / ("%s.quests.json" % zone)).write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n")
        count += len(data["quests"])
    rows = ["-- Quest NPCs bound to authored settlement quest sockets (Round 14, 15 and 20",
            "-- casts). Coordinates remain owned by the sockets; new givers at free quest",
            "-- sockets come from the zone quest files (loader.lua).",
            "local Q = grug_quests",
            "for _, row in ipairs({"]
    for call in npcs:
        d = call["def"]
        rows.append('\t{"%s", "%s", "%s", "%s"},' % (call["id"], d["settlement"], d["socket"], d["title"]))
    rows += ["}) do",
             "\tQ.register_npc(row[1], {settlement = row[2], socket = row[3], title = row[4]})",
             "end", ""]
    NPCS.write_text("\n".join(rows))
    print("wrote %d quests into %d zone files, %d NPCs" % (count, len(files), len(npcs)))


if __name__ == "__main__":
    main(sys.argv[1])

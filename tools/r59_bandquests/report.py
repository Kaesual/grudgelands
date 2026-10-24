#!/usr/bin/env python3
"""Round 59 lane BANDQUESTS: the band 11-20's numbers, before and after.

Per band zone: the quests it offers (shared variants and local quests,
the Round 58 guild report and camp hunt among them), the objective kinds
(kill, kill-for-drop, item, travel, use) and the distinct mob names its
kill and kill-for-drop objectives count (the names of data/names.json's
slots of their roles in the zone), and the reward table (choice rewards
with item levels and enchants). Numbers to compare, not targets.

    python3 tools/r59_bandquests/report.py [--before REF]

--before REF reads the quest files of git revision REF as well (e.g. the
lane's base commit) and prints both. Python 3 standard library only.
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = "mods/PLAYER/grug_quests/data/zones"
NAMES = REPO / "mods/ENTITIES/grug_mobs/data/names.json"
ZONES = ["elandor_copperfell_foothills", "elandor_goldmead_vale", "elandor_starbough_vale",
         "kragmar_mournfen", "kragmar_redtusk_savanna", "kragmar_raincall_basin"]
KINDS = ("kill", "kill-for-drop", "item", "travel", "use")


def load(ref):
    """{zone file: data} of every quest file, from the tree or git `ref`."""
    out = {}
    if ref is None:
        for path in sorted((REPO / QUESTS).glob("*.quests.json")):
            out[path.name] = json.loads(path.read_text(encoding="utf-8"))
        return out
    names = subprocess.run(["git", "-C", str(REPO), "ls-tree", "--name-only", ref, QUESTS + "/"],
                           check=True, capture_output=True, text=True).stdout.split()
    for name in names:
        if name.endswith(".quests.json"):
            text = subprocess.run(["git", "-C", str(REPO), "show", "%s:%s" % (ref, name)],
                                  check=True, capture_output=True, text=True).stdout
            out[Path(name).name] = json.loads(text)
    return out


def offered(files, zone):
    """[(quest, shared?, variant or None)] the zone offers."""
    out = []
    for data in files.values():
        for q in data.get("quests") or []:
            if q.get("variants"):
                for v in q["variants"]:
                    if v["zone"] == zone:
                        out.append((q, True, v))
            elif data["zone"] == zone:
                out.append((q, False, None))
    return out


def objective_kind(o):
    if o["type"] == "kill":
        return "kill"
    if o["type"] == "item":
        return "kill-for-drop" if o.get("roles") else "item"
    return {"talk": "travel", "use": "use"}[o["type"]]


def mob_names(zone, roles, names):
    out = set()
    for slot, name in names.items():
        parts = slot.split("/")
        if parts[0] == zone and parts[1] in roles:
            out.add(name)
    return out


def summary(files, names):
    rows = {}
    for zone in ZONES:
        quests = offered(files, zone)
        kinds = dict.fromkeys(KINDS, 0)
        mobs = set()
        for q, _, v in quests:
            for i, o in enumerate(q["objectives"]):
                kinds[objective_kind(o)] += 1
                own = (v or {}).get("objectives") or []
                roles = (own[i] if i < len(own) else {}).get("roles", o.get("roles"))
                if roles and o["type"] in ("kill", "item"):
                    mobs |= mob_names(zone, set(roles), names)
        rows[zone] = {"quests": len(quests), "shared": sum(1 for _, s, _ in quests if s),
                      "local": sum(1 for _, s, _ in quests if not s), "kinds": kinds, "mobs": sorted(mobs)}
    return rows


def print_summary(title, rows):
    print("## %s" % title)
    print()
    print("| Zone | Quests (shared + local) | kill | kill-for-drop | item | travel | use | kill share | "
          "mob names |")
    print("|---|---|---|---|---|---|---|---|---|")
    total = dict.fromkeys(KINDS, 0)
    for zone, r in rows.items():
        n = sum(r["kinds"].values())
        share = 100.0 * (r["kinds"]["kill"] + r["kinds"]["kill-for-drop"]) / n if n else 0
        for k in KINDS:
            total[k] += r["kinds"][k]
        print("| %s | %d (%d + %d) | %s | %.0f %% | %d: %s |" % (
            zone, r["quests"], r["shared"], r["local"], " | ".join(str(r["kinds"][k]) for k in KINDS), share,
            len(r["mobs"]), ", ".join(r["mobs"])))
    n = sum(total.values())
    print("| all six | | %s | %.0f %% | |" % (" | ".join(str(total[k]) for k in KINDS),
                                            100.0 * (total["kill"] + total["kill-for-drop"]) / n if n else 0))
    print()


def reward_table(files):
    print("## Choice rewards (after)")
    print()
    print("| Zone | Quest | Level | Choices |")
    print("|---|---|---|---|")
    for zone in ZONES:
        for q, _, _ in offered(files, zone):
            choices = (q.get("rewards") or {}).get("choices")
            if not choices or q["id"].startswith(("guild_", "camp_")):
                continue
            parts = []
            for c in choices:
                affixes = "+".join("%s %s" % (a["channel"], a["stat"]) for a in c.get("affixes") or [])
                parts.append("%s%s%s" % (c["item"].split(":")[1], " x%d" % c["count"] if c.get("count") else "",
                                         " (%s)" % affixes if affixes else ""))
            print("| %s | %s | %d | %s |" % (zone.split("_", 1)[1], q["id"], q["level"], "; ".join(parts)))
    print()


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--before", help="git revision of the quest files before")
    args = ap.parse_args(argv)
    names = json.loads(NAMES.read_text(encoding="utf-8"))["names"]
    if args.before:
        print_summary("Before (%s)" % args.before, summary(load(args.before), names))
    after = load(None)
    print_summary("After", summary(after, names))
    reward_table(after)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

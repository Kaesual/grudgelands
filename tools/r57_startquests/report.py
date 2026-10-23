#!/usr/bin/env python3
"""Round 57 lane STARTQUESTS: the start zones' numbers, before and after.

Per start zone: the quests it offers (shared variants and local quests),
their reward weight in kill equivalents and the quest copper of the loader's
formula (quests.md "Copper": round_half_up(0.08 x 25 x weight) at T1, at
least 1c for a weight above 0); and the reward table (the choices, their
item level and enchants). "Before" reads the six files at a git ref, "after"
the working tree. The XP to level 10 comes from tools/r28_design/ledger.py
(--game --track <race>), which this script does not repeat.

    python3 tools/r57_startquests/report.py [--before REF]

Numbers to compare, not targets. Python 3 standard library only.
"""
import argparse
import json
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DIR = "mods/PLAYER/grug_quests/data/zones"
ZONES = ["elandor_dawnmere_fields", "elandor_hearthpine_vale", "elandor_silverleaf_glades",
         "kragmar_sunscar_flats", "kragmar_kapok_cradle", "kragmar_stillgrave_hollow"]
P_T1 = 25  # the WP44 cutover price P(T) of tier band 1-10


def copper(rewards):
    if "copper" in rewards:
        return rewards["copper"]
    weight = rewards.get("weight", 0)
    if weight <= 0:
        return 0
    return max(1, int(0.08 * P_T1 * weight + 0.5))


def load(ref):
    files = {}
    for zone in ZONES:
        path = "%s/%s.quests.json" % (DIR, zone)
        if ref:
            text = subprocess.run(["git", "show", "%s:%s" % (ref, path)], cwd=REPO, check=True,
                                  capture_output=True, text=True).stdout
        else:
            text = (REPO / path).read_text()
        files[zone] = json.loads(text)
    return files


def offered(files):
    """{zone: [(quest, shared?)]} the quests each start zone offers."""
    out = {zone: [] for zone in ZONES}
    for zone, data in files.items():
        for quest in data["quests"]:
            if quest.get("variants"):
                for variant in quest["variants"]:
                    if variant["zone"] in out:
                        out[variant["zone"]].append((quest, True))
            else:
                out[zone].append((quest, False))
    return out


def summary(files):
    rows, ids = [], set()
    for zone, quests in offered(files).items():
        shared = sum(1 for _, s in quests if s)
        weight = sum(q["rewards"].get("weight", 0) for q, _ in quests)
        coin = sum(copper(q["rewards"]) for q, _ in quests)
        rows.append((zone, len(quests), shared, len(quests) - shared, weight, coin))
        ids.update(q["id"] for q, _ in quests)
    return rows, len(ids)


def affix_text(choice):
    return "+".join("%s %s" % (a["channel"], a["stat"]) for a in choice.get("affixes") or []) or "-"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--before", default="a90990d5", help="git ref of the shipped files before")
    args = parser.parse_args()
    before, after = load(args.before), load(None)
    (b_rows, b_ids), (a_rows, a_ids) = summary(before), summary(after)
    print("# Start zones before (%s) and after\n" % args.before)
    print("| Zone | Quests before | after (shared + local) | Weight before | after | Quest copper before | after |")
    print("|---|---|---|---|---|---|---|")
    for b, a in zip(b_rows, a_rows):
        print("| %s | %d | %d (%d + %d) | %.1f | %.1f | %dc | %dc |" % (a[0], b[1], a[1], a[2], a[3], b[4], a[4],
                                                                 b[5], a[5]))
    print("\nQuest ids in the six files: %d before, %d after.\n" % (b_ids, a_ids))
    print("## Reward table (after)\n")
    print("| Zone | Quest | Level | Choice (item level = quest level) |")
    print("|---|---|---|---|")
    for zone, quests in offered(after).items():
        for quest, _ in sorted(quests, key=lambda row: (row[0]["level"], row[0]["id"])):
            choices = quest["rewards"].get("choices")
            if not choices:
                continue
            text = "; ".join("%s%s [%s]" % (c["item"].split(":")[1], " x%d" % c["count"] if c.get("count") else "",
                                            affix_text(c)) for c in choices)
            print("| %s | %s | %d | %s |" % (zone, quest["id"], quest["level"], text))


if __name__ == "__main__":
    main()

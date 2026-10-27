#!/usr/bin/env python3
"""Round 58 lane GUILDQUESTS: the guild quests' counts and numbers.

  * the reward table: every guild quest with its tier, levels, reward weight
    in kill equivalents, the reward XP (grug_xp.quest_reward: weight x
    M(level), before the race bonus) and the copper of the loader's formula
    (quests.md "Copper"), its variants and givers;
  * per camp: the quests its foreman offers its faction (the gather quests
    of its tier and above, the follow-ups, its hunt, the raid) against the
    zone's own quests (the zone file's quests that are no guild quest), as
    counts, reward XP and copper.

Numbers to compare, not targets. The leveling route (ledger.py --game
--track <race>) is run separately; it reads the guild files outside every
route. Python 3 standard library only.

    python3 tools/r58_guildquests/report.py
"""
import json
import re
import statistics
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"
sys.path.insert(0, str(REPO / "tools/r28_design"))
import r28common as C  # noqa: E402

PRICE = (25, 65, 160, 400, 1000, 2500)  # quests.md "Copper": P(T) per tier band


def copper(level, rewards):
    if "copper" in rewards:
        return rewards["copper"]
    weight = rewards.get("weight", 0)
    if weight <= 0:
        return 0
    tier = max(1, min(6, (level - 1) // 10 + 1))
    return max(1, (8 * PRICE[tier - 1] * int(round(weight * 100)) + 5000) // 10000)


def money(c):
    out = []
    for unit, size in (("g", 10000), ("s", 100)):
        if c >= size:
            out.append("%d%s" % (c // size, unit))
            c %= size
    if c or not out:
        out.append("%dc" % c)
    return " ".join(out)


def ours(q):
    return re.match(r"^(guild_|camp_)", q.get("id", "")) is not None


def main():
    files = {}
    for path in sorted(QUESTS.glob("*.quests.json")):
        if not path.name.endswith(".front.quests.json"):
            files[path.name[:-len(".quests.json")]] = json.loads(path.read_text(encoding="utf-8"))
    quests = {q["id"]: q for data in files.values() for q in data.get("quests") or [] if ours(q)}
    camps = C.mining_camps()

    print("## Reward table (%d quests)\n" % len(quests))
    print("| Quest | Kind | Opens / reward level | Weight (KE) | XP | Copper | Variants | Givers |")
    print("|---|---|---|---:|---:|---:|---:|---:|")
    for qid in sorted(quests, key=lambda i: (quests[i]["level"], i)):
        q = quests[qid]
        kind = "follow-up (story)" if q.get("story") else ("gather" if qid.startswith("guild_") else
                                                          ("raid" if "raid" in qid else "hunt"))
        givers = sum(len(v["givers"]) for v in q["variants"])
        roles = all(isinstance(g, dict) for v in q["variants"] for g in v["givers"])
        print("| `%s` | %s | %d / %d | %s | %d | %s | %d | %s |" % (
            qid, kind, C.acceptance_level(q["level"]), q["level"], q["rewards"]["weight"],
            C.quest_xp(q["rewards"]["weight"], q["level"]), money(copper(q["level"], q["rewards"])),
            len(q["variants"]), "%d roles" % givers if roles else givers))

    print("\n## Per camp: the foreman's quests for its faction against the zone's own quests\n")
    print("| Camp | Tier | Foreman's quests (gather + follow-up + hunt + raid) | Their XP | Their copper | "
          "Zone's own quests | Their XP | Their copper | Median XP of a zone quest |")
    print("|---|---:|---|---:|---:|---:|---:|---:|---:|")
    for camp in sorted(camps, key=lambda c: (c["tier"], c["key"])):
        foreman = "r58_foreman_" + camp["key"]
        offered = []
        for q in quests.values():
            for variant in q["variants"]:
                hit = foreman in variant["givers"] or any(
                    isinstance(g, dict) and g.get("faction") == camp["faction"] and
                    g.get("role") == "foreman_t%d" % camp["tier"] for g in variant["givers"])
                if hit:
                    offered.append(q)
                    break
        kinds = {"gather": 0, "follow": 0, "hunt": 0, "raid": 0}
        for q in offered:
            kinds["follow" if q.get("story") else "gather" if q["id"].startswith("guild_") else
                  "raid" if "raid" in q["id"] else "hunt"] += 1
        xp = sum(C.quest_xp(q["rewards"]["weight"], q["level"]) for q in offered)
        cu = sum(copper(q["level"], q["rewards"]) for q in offered)
        own = [q for q in (files.get(camp["zone"]) or {}).get("quests") or [] if not ours(q)]
        own_xp = [C.quest_xp(q["rewards"]["weight"], q["level"]) for q in own]
        own_cu = sum(copper(q["level"], q["rewards"]) for q in own)
        print("| %s | %d | %d (%d + %d + %d + %d) | %d | %s | %s | %s | %s | %s |" % (
            camp["key"], camp["tier"], len(offered), kinds["gather"], kinds["follow"], kinds["hunt"],
            kinds["raid"], xp, money(cu), len(own) if own else "no file", sum(own_xp) if own else "-",
            money(own_cu) if own else "-", int(statistics.median(own_xp)) if own_xp else "-"))
    print("\n(The follow-ups count once both gather quests of their tier are done; a Battlegrounds zone "
          "has no quest file of its own before Round 58.)")
    variants = sum(len(q["variants"]) for q in quests.values())
    print("\nQuests %d, variants %d; per tier: %s" % (len(quests), variants, ", ".join(
        "T%d %d" % (t, sum(1 for q in quests.values() if (C.acceptance_level(q["level"]) - 1) // 10 + 1 == t))
        for t in range(2, 7))))
    return 0


if __name__ == "__main__":
    sys.exit(main())

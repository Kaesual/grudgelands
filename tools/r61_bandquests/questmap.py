#!/usr/bin/env python3
"""Round 61 lane BANDQUESTS: the band 31-40's structure page.

Writes a draft folder whose data/zones holds the band 31-40 alone, then runs
tools/r56_questmap/questmap.lua --data on it (the real loader over the
draft; tools/r60_capitals/questmap.py is the Round 60 pattern):

  * the six contested zones' files as they ship (their hubs and their
    31-40 quests, chapter 3 among them), but a shared quest keeps only its
    variants in these six zones (the guild reports' Battlegrounds variants
    are camps of other zones), and the 41-60 main line, the fortress
    quests' `front` line and the Warmasters' main-line lines are left out
    (Round 62's);
  * chapter 2's last steps A4 (`story_accord_04`, Frostbarrow Shelf) and T3
    (`story_throng_04`, Nhal Veyr), which A5 and T4 require, alone in their
    files with their own prerequisites left out;
  * the two guild files with only the gather quests the guild reports
    require.

The intro carries the ledger 30->40 (tools/r28_design/ledger.py --game
--track <race>, solo) of the shipped files.

    python3 tools/r61_bandquests/questmap.py [--out FILE]

FILE defaults to ~/projects/grudgelands-orchestration/r61/questmap/index.html
(the folder is made). Python 3 standard library only; LuaJIT runs the page
builder.
"""
import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"
DEFAULT_OUT = Path.home() / "projects/grudgelands-orchestration/r61/questmap/index.html"
BAND = ("elandor_stormvault_heights", "elandor_ashenward_march", "elandor_glassroot_wilds",
        "kragmar_blackwind_rise", "kragmar_bannerbreak_mesa", "kragmar_thunderroot_wilds")
# Chapter 2's last steps, in their own files (their giver's hub only).
CHAPTER2 = {"elandor_frostbarrow_shelf": "story_accord_04", "kragmar_nhal_veyr": "story_throng_04"}
GUILD_FILES = ("charter_of_stone", "oathdelvers")
RACES = ("human", "dwarf", "elf", "orc", "troll", "undead")
FORTRESS = ("r31_accord_warmaster", "r31_accord_drillmaster", "r31_accord_outrider",
            "r31_throng_warmaster", "r31_throng_drillmaster", "r31_throng_outrider")


def ledger():
    """{race: (reward XP, questing share)} of the band 30->40, solo."""
    out = {}
    for race in RACES:
        text = subprocess.run([sys.executable, "tools/r28_design/ledger.py", "--game", "--track", race,
                               "--party", "solo"], cwd=REPO, capture_output=True, text=True).stdout
        for line in text.splitlines():
            if line.startswith("| 30 → 40 |"):
                cells = [c.strip() for c in line.strip("|").split("|")]
                out[race] = (cells[2], cells[7])
                break
    return out


def load(name):
    return json.loads((QUESTS / ("%s.quests.json" % name)).read_text(encoding="utf-8"))


def write(zones, name, data):
    (zones / ("%s.quests.json" % name)).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n",
                                                   encoding="utf-8")


def draft(root):
    zones = root / "data" / "zones"
    zones.mkdir(parents=True)
    shown = set(BAND)
    count, required = 0, set()
    for name in BAND:
        data = load(name)
        quests = []
        for q in data["quests"]:
            if q["level"] > 40:
                continue
            if q.get("variants"):
                q["variants"] = [v for v in q["variants"] if v["zone"] in shown]
                if not q["variants"]:
                    continue
            required.update(q.get("requires") or [])
            quests.append(q)
        data["quests"] = quests
        data["hubs"] = [h for h in data["hubs"] if not any(g["npc"] in FORTRESS for g in h["givers"])]
        for hub in data["hubs"]:
            for giver in hub["givers"]:
                giver["lines"] = [line for line in giver["lines"] if line != "front"]
        count += len(quests)
        write(zones, name, data)
    for name, qid in CHAPTER2.items():
        data = load(name)
        quest = [q for q in data["quests"] if q["id"] == qid][0]
        quest["requires"] = []
        giver = quest.get("giver")
        data["hubs"] = [h for h in data["hubs"] if any(g["npc"] == giver for g in h["givers"])]
        for hub in data["hubs"]:
            hub["givers"] = [g for g in hub["givers"] if g["npc"] == giver]
            for g in hub["givers"]:
                g["lines"] = [quest["line"]]
        data["quests"] = [quest]
        count += 1
        write(zones, name, data)
    for name in GUILD_FILES:
        data = load(name)
        data["quests"] = [q for q in data["quests"] if q["id"] in required]
        count += len(data["quests"])
        write(zones, name, data)
    return count


def intro(numbers):
    rows = ", ".join("%s %s XP (%s)" % (race, xp, share) for race, (xp, share) in numbers.items())
    return (
        "Round 61: the band 31-40 (lane BANDQUESTS: Stormvault Heights, Ashenward March, Glassroot Wilds; "
        "Blackwind Rise, Bannerbreak Mesa, Thunderroot Wilds), every file reworked: free play, only the violet "
        "story quests chain. Texts are placeholders ([PH]); the new storm vessel and the Runner's Packet have "
        "placeholder looks until the art pick. "
        "Chapter 3, The Accord: A5 (34) Toren Waterbarrel sends the player to the Ashenward Broken Load to secure "
        "the raided transport's record and on to Audra Wainholt, the Ashenward camp's foreman, after A4 and "
        "Scrip's free quest; A6 (39) any of the three Accord band foremen sends the player with the raid's "
        "report to Nella Hedgeward, after A5 and the free camp raid; Nella points to the Warmaster (the free "
        "fortress call at 40 takes the player there). The Throng: T4 (35) Drek Rampbinder to the Bannerbreak "
        "Scattered Load and on to Greda Stonehaul, the Bannerbreak camp's foreman, after T3 and Rattle's free "
        "quest; T5 (40) any Throng band foreman to Yarra Standardmender, after T4 and the raid. "
        "Shared quests (one level, one title, the hosts' line `border`): Corn (Toren, Drek), Melons (Faeris, "
        "Rumela), Chests (Faeris, Orrel, Rumela), the Runner's Packet from the bandit archers of each zone's "
        "bandit camp (all six hosts' zones, a soulbound quest drop), the reserve at the own guild camp's loading "
        "ground (Nella, Yarra). Each zone's weapon sits on its solo quest (Scrip, Rattle, the four new places); "
        "each zone has one optional Party quest on its elite leader (free, standalone, a trinket choice). The "
        "zones without front work at 40 end with a free departure to Nella, Drek or Yarra. Shown here: the six "
        "files' 31-40 quests, the shared guild quests' variants in these zones with the gather quests they "
        "require, A4 and T3 for context, without the main line 41-60 and the fortress quests. "
        "Ledger 30->40, solo (reward XP, questing share, the shipped files): " + rows + ".")


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    args = ap.parse_args(argv)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    numbers = ledger()
    with tempfile.TemporaryDirectory(prefix="r61_questmap_") as tmp:
        count = draft(Path(tmp))
        result = subprocess.run(["luajit", "tools/r56_questmap/questmap.lua", ".", "--data", tmp, "--out", args.out,
                                 "--intro", intro(numbers)], cwd=REPO, capture_output=True, text=True)
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        print("questmap draft: %d quests" % count)
        return result.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

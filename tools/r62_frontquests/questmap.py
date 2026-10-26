#!/usr/bin/env python3
"""Round 62 lane FRONTQUESTS: the front 41-60's structure page.

Writes a draft folder whose data/zones holds the front 41-60 alone, then runs
tools/r56_questmap/questmap.lua --data on it (the real loader over the
draft; tools/r61_bandquests/questmap.py is the Round 61 pattern):

  * the ten `.front` files and the four Battlegrounds files as they ship;
  * the hosts' and envoys' base files (the four contested hosts, the six
    capitals) with their hubs and only their quests of reward level 41-60
    (the main line and the shared front quests);
  * the two guild files with only the gather quests the front's guild
    reports require.

The intro carries the ledger 40->50 and 50->60 (tools/r28_design/ledger.py
--game --track <race>, solo) of the shipped files.

    python3 tools/r62_frontquests/questmap.py [--out FILE]

FILE defaults to ~/projects/grudgelands-orchestration/r62/questmap/index.html
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
DEFAULT_OUT = Path.home() / "projects/grudgelands-orchestration/r62/questmap/index.html"
HOSTS = ("elandor_ashenward_march", "elandor_stormvault_heights", "elandor_lethariel", "elandor_dur_brannoc",
         "elandor_highcourt", "kragmar_bannerbreak_mesa", "kragmar_blackwind_rise", "kragmar_kezamba",
         "kragmar_gor_drazhak", "kragmar_nhal_veyr")
BATTLEGROUNDS = ("front_broken_causeway", "front_shattered_line", "front_gravesalt_escarpment",
                 "front_skyglass_canopy")
GUILD_FILES = ("charter_of_stone", "oathdelvers")
RACES = ("human", "dwarf", "elf", "orc", "troll", "undead")


def ledger():
    """{race: {band: questing share}} of 40->50 and 50->60, solo."""
    out = {}
    for race in RACES:
        text = subprocess.run([sys.executable, "tools/r28_design/ledger.py", "--game", "--track", race,
                               "--party", "solo"], cwd=REPO, capture_output=True, text=True).stdout
        row = {}
        for line in text.splitlines():
            for band in ("40 → 50", "50 → 60"):
                if line.startswith("| %s |" % band) and band not in row:
                    row[band] = [c.strip() for c in line.strip("|").split("|")][7]
        out[race] = row
    return out


def load(name):
    return json.loads((QUESTS / name).read_text(encoding="utf-8"))


def write(zones, name, data):
    (zones / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def draft(root):
    zones = root / "data" / "zones"
    zones.mkdir(parents=True)
    count, required = 0, set()
    for name in HOSTS:
        data = load("%s.quests.json" % name)
        data["quests"] = [q for q in data["quests"] if q["level"] > 40]
        front = load("%s.front.quests.json" % name)
        for q in data["quests"] + front["quests"]:
            required.update(q.get("requires") or [])
        count += len(data["quests"]) + len(front["quests"])
        write(zones, "%s.quests.json" % name, data)
        write(zones, "%s.front.quests.json" % name, front)
    for name in BATTLEGROUNDS:
        data = load("%s.quests.json" % name)
        for q in data["quests"]:
            required.update(q.get("requires") or [])
        count += len(data["quests"])
        write(zones, "%s.quests.json" % name, data)
    for name in GUILD_FILES:
        data = load("%s.quests.json" % name)
        data["quests"] = [q for q in data["quests"] if q["id"] in required]
        count += len(data["quests"])
        write(zones, "%s.quests.json" % name, data)
    return count


def intro(numbers):
    rows = "; ".join("%s %s / %s" % (race, row.get("40 → 50"), row.get("50 → 60")) for race, row in numbers.items())
    return (
        "Round 62: the front 41-60 (lane FRONTQUESTS), every file reworked: the violet story quests are the main "
        "line, the story path (The Accord's 17 steps, The Throng's 14, the climaxes on Senn, Ninepins, Huskell and "
        "Chirr among them; each requires only spine steps, The Throng's Chirr step after Huskell's); every other "
        "quest is free play (a level only; the fortress raids' second camp and the island bounty pairs are the "
        "one follow-ups). Texts are placeholders ([PH]); the spine keeps its texts and gets placeholder "
        "completions. The fortress quests (Warmaster, Drillmaster, Outrider) ship as Round 31 made them. Shared "
        "front quests on the hosts' line `border` (one level, one title): seed potatoes, the return lantern and "
        "the ford's stranded load (Toren, Drek), the relief count, the salt and the old wire (Nella, Yarra), "
        "Stormkelp (Alna, Orrel), the optional group quests on Engine Nine (Nella, Yarra) and Last-Toll (Alna, "
        "Orrel) at 50 (free, standalone, a trinket choice), and the departure at 50 (Nella or Alna to Borin, "
        "Yarra to Nalo). Departures: Alna to Dorrin (45, K1 A), Drek to Thorga (42), Borin to Eriath (51), Orrel to "
        "Vaska (52), Vaska to Ossa (53). The Throng's island pair at Thorga: Kraits on Stormscale, then the group "
        "quest on Last-Offering (K9 A). Rewards per faction and band: six armor choices (one enchant, every slot), "
        "three weapon choices (solo), three trinket choices, Potion V/VI; tier 5 at 41-50, tier 6 at 51-60; the "
        "final turn-ins a weapon choice. Eight new quest places in the Battlegrounds zones. Shown here: the ten "
        "front files, the hosts' and envoys' 41-60 quests of their base files, the four Battlegrounds files and "
        "the guild gathers their reports require. Ledger solo, questing share 40->50 / 50->60 (the shipped "
        "files): " + rows + ".")


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    args = ap.parse_args(argv)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    numbers = ledger()
    with tempfile.TemporaryDirectory(prefix="r62_questmap_") as tmp:
        count = draft(Path(tmp))
        result = subprocess.run(["luajit", "tools/r56_questmap/questmap.lua", ".", "--data", tmp, "--out", args.out,
                                 "--intro", intro(numbers)], cwd=REPO, capture_output=True, text=True)
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        print("questmap draft: %d quests" % count)
        return result.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

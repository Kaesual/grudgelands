#!/usr/bin/env python3
"""Round 60 lanes BANDQUESTS and CAPITALS: the joint structure page.

Writes a draft folder whose data/zones holds the band 21-30 and the six
capitals alone, then runs tools/r56_questmap/questmap.lua --data on it (the
real loader over the draft):

  * the eight band zones' and the six capitals' files as they ship (their
    hubs and quests: chapter 1 and chapter 2, the Alchemy quest), but a
    shared quest keeps only its variants in these fourteen zones (the guild
    reports' and the camp hunts' other variants are camps of other zones),
    and the envoys' `front` line (the 41-60 main line) is left out;
  * the two guild files with only the gather quests those quests require.

The intro carries the ledger 20->30 (tools/r28_design/ledger.py --game
--track <race>, solo) of the shipped files.

    python3 tools/r60_capitals/questmap.py [--out FILE]

FILE defaults to ~/projects/grudgelands-orchestration/r60/questmap/index.html
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
DEFAULT_OUT = Path.home() / "projects/grudgelands-orchestration/r60/questmap/index.html"
BAND = ("elandor_frostbarrow_shelf", "elandor_whitebridge_shire", "elandor_lorindor", "elandor_moonfall_wood",
        "kragmar_ossuary_reach", "kragmar_speargrass_reach", "kragmar_whispering_reedlands",
        "kragmar_totemwater_reach")
CAPITALS = ("elandor_highcourt", "elandor_dur_brannoc", "elandor_lethariel",
            "kragmar_gor_drazhak", "kragmar_kezamba", "kragmar_nhal_veyr")
GUILD_FILES = ("charter_of_stone", "oathdelvers")
RACES = ("human", "dwarf", "elf", "orc", "troll", "undead")


def ledger():
    """{race: (reward XP, questing share)} of the band 20->30, solo."""
    out = {}
    for race in RACES:
        text = subprocess.run([sys.executable, "tools/r28_design/ledger.py", "--game", "--track", race,
                               "--party", "solo"], cwd=REPO, capture_output=True, text=True).stdout
        for line in text.splitlines():
            if line.startswith("| 20 → 30 |"):
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
    shown = set(BAND) | set(CAPITALS)
    count, required = 0, set()
    for name in BAND + CAPITALS:
        data = load(name)
        quests = []
        for q in data["quests"]:
            if q.get("variants"):
                q["variants"] = [v for v in q["variants"] if v["zone"] in shown]
                if not q["variants"]:
                    continue
            required.update(q.get("requires") or [])
            quests.append(q)
        data["quests"] = quests
        for hub in data["hubs"]:
            for giver in hub["givers"]:
                giver["lines"] = [line for line in giver["lines"] if line != "front"]
        count += len(quests)
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
        "Round 60: the band 21-30 (lane BANDQUESTS: Frostbarrow Shelf, Whitebridge Shire, Lorindor, Moonfall "
        "Wood; Ossuary Reach, Speargrass Reach, Whispering Reedlands, Totemwater Reach) and the six capitals "
        "(lane CAPITALS), every file reworked: free play, only the violet story quests chain. Texts are "
        "placeholders ([PH]); new quest objects have placeholder looks until the art pick. "
        "Chapter 2, The Accord: A3 (24) Brodd Deeppeg, the Frostbarrow camp's foreman, sends the player to the "
        "held load in the camp (secure the record and release the load) and on to Kelda Screesort; Nib's free "
        "finale drops the Dispatch Folio; A4 (29) Kelda to Hadrin Beamset in Dur Brannoc's guild house, after "
        "A3 and Nib. The Throng: T2a (24) Rellis Shalemark, the Ossuary camp's foreman, to the claim rest in "
        "the barrowlands and on to Mereth Rubbinghand; T3 (29) Ossa Quietregister sends the player to post the "
        "claim notice at the public register in front of Nhal Veyr's Miner's Guild house (a town place on its "
        "forecourt, west of the door) and to report to Iven Lastshift, after T2a, the free travel quest "
        "\"A Chisel Leaves Its Signature\" (Mereth or Rellis to Neris) and the free Hush quest. Chapter 1 "
        "(Round 59) is unchanged. "
        "The capitals: every envoy asks for Torches (20) and, at the first visit (19), for an Elixir of "
        "Precision I: learn Alchemy from the capital's trainer, fetch Sunleaf and a Boar Tusk where you started "
        "(the start village's waystone), brew it at the capital's Brewing Stand; four envoys share a short night "
        "task (2 Debtbound Zombies, Potion III choice), four cooks a Raw Meat delivery; each capital's named "
        "leader is a free local finale (choice of 3 Heavy Leather, 3 Heavy Cloth or 2 Steel Bars); the cooks' "
        "travels into the band and the envoys' departures at 29 are free handovers. Varda's Mire Carp is the "
        "band's fish quest. Shown here: the fourteen files, the shared guild quests' variants in these zones "
        "with the gather quests they require, without the envoys' front line (41-60). Ledger 20->30, solo "
        "(reward XP, questing share, the shipped files): " + rows + ".")


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    args = ap.parse_args(argv)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    numbers = ledger()
    with tempfile.TemporaryDirectory(prefix="r60_questmap_") as tmp:
        count = draft(Path(tmp))
        result = subprocess.run(["luajit", "tools/r56_questmap/questmap.lua", ".", "--data", tmp, "--out", args.out,
                                 "--intro", intro(numbers)], cwd=REPO, capture_output=True, text=True)
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        print("questmap draft: %d quests" % count)
        return result.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

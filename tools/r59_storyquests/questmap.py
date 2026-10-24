#!/usr/bin/env python3
"""Round 59 lanes BANDQUESTS and STORYQUESTS: the joint structure page.

Writes a draft folder whose data/zones holds the band 11-20 and chapter 1
alone, then runs tools/r56_questmap/questmap.lua --data on it (the real
loader over the draft):

  * the six band zones' files as they ship (their hubs and quests), but the
    guild report follow-ups `guild_t2_report_*` keep only their variants in
    the band zones (their other variants are the camps of the other zones);
  * the two guild files with only the T2 gather quests those follow-ups
    require;
  * the six capital files with only chapter 1's story quests and the hubs
    of their givers (the envoy on the line `envoy`, the guild leader); the
    capitals' other quests (unflagged, their band's rework is Round 60) and
    the envoys' front line are left out.

The intro carries the ledger 10->20 (tools/r28_design/ledger.py --game
--track <race>, solo) of the shipped files.

    python3 tools/r59_storyquests/questmap.py [--out FILE]

FILE defaults to ~/projects/grudgelands-orchestration/r59/questmap/index.html
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
DEFAULT_OUT = Path.home() / "projects/grudgelands-orchestration/r59/questmap/index.html"
BAND = ("elandor_copperfell_foothills", "elandor_goldmead_vale", "elandor_starbough_vale",
        "kragmar_mournfen", "kragmar_redtusk_savanna", "kragmar_raincall_basin")
CAPITALS = ("elandor_highcourt", "elandor_dur_brannoc", "elandor_lethariel",
            "kragmar_gor_drazhak", "kragmar_kezamba", "kragmar_nhal_veyr")
GUILD_FILES = ("charter_of_stone", "oathdelvers")
RACES = ("human", "dwarf", "elf", "orc", "troll", "undead")


def ledger():
    """{race: (reward XP, questing share)} of the band 10->20, solo."""
    out = {}
    for race in RACES:
        text = subprocess.run([sys.executable, "tools/r28_design/ledger.py", "--game", "--track", race,
                               "--party", "solo"], cwd=REPO, capture_output=True, text=True).stdout
        for line in text.splitlines():
            if line.startswith("| 10 → 20 |"):
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
    count, required = 0, set()
    for name in BAND:
        data = load(name)
        for q in data["quests"]:
            if q["id"].startswith("guild_t2_report_"):
                q["variants"] = [v for v in q["variants"] if v["zone"] in BAND]
                required.update(q.get("requires") or [])
        count += len(data["quests"])
        write(zones, name, data)
    for name in GUILD_FILES:
        data = load(name)
        data["quests"] = [q for q in data["quests"] if q["id"] in required]
        count += len(data["quests"])
        write(zones, name, data)
    for name in CAPITALS:
        data = load(name)
        quests = [q for q in data["quests"] if q.get("story") and q["id"].startswith("story_")]
        givers = set()
        # The givers of every chapter quest given in this capital.
        for other in CAPITALS:
            for q in load(other)["quests"]:
                if q["id"].startswith("story_"):
                    for v in q["variants"]:
                        if v["zone"] == name:
                            givers.update(v["givers"])
        hubs = []
        for hub in data["hubs"]:
            kept = []
            for giver in hub["givers"]:
                if giver["npc"] in givers:
                    giver = dict(giver, lines=[line for line in giver["lines"] if line != "front"])
                    kept.append(giver)
            if kept:
                hubs.append(dict(hub, givers=kept))
        out = {"zone": data["zone"]}
        if "identity" in data:
            out["identity"] = data["identity"]
        out["hubs"], out["quests"] = hubs, quests
        count += len(quests)
        write(zones, name, out)
    return count


def intro(numbers):
    rows = ", ".join("%s %s XP (%s)" % (race, xp, share) for race, (xp, share) in numbers.items())
    return ("Round 59: the band 11-20 (lane BANDQUESTS: Copperfell Foothills, Goldmead Vale, Starbough Vale; "
            "Mournfen, Redtusk Savanna, Raincall Basin; every file reworked, free play) and chapter 1 of the story "
            "arc in the six capitals (lane STORYQUESTS: the violet story quests). Texts are placeholders ([PH]). "
            "Chapter 1: at 19 each capital's envoy gives \"A Hearing for the Absent\" (The Accord) or \"Our Word, "
            "Our Witness\" (The Throng), a walk to the Miner's Guild leader of the same capital; at 20 that "
            "leader gives \"What a Seal Allows\" or \"Whose Word Is This?\": secure a record (a 3 s hold) at a spot "
            "in the town (the town place, socket:<capital>/<plot>/<socket>: Highcourt's dispatch yard by the "
            "butcher's, Dur Brannoc's loading apron at the ore yard, Lethariel's timber check by the bowyer's, "
            "Gor Drazhak's water depot at the cook court, Kezamba's witness landing by the shore store, Nhal "
            "Veyr's receiving court outside the mourners' hall) and bring it back; rewards weight 1, then weight "
            "3 with 2 Healing or 2 Mana Potion II. The band: shared quests (repairs, the load record, the held "
            "supplies), each zone's witness, perpetrator, departure and errands (the crafted and gathered items, "
            "K15, are a first version for your pick), its potion, two armor and one weapon choices. Shown here: "
            "the band files, the guild report follow-ups' band variants with the two T2 gather quests they "
            "require, and of the capitals only the chapter (their other quests stay until Round 60). Ledger "
            "10->20, solo (reward XP, questing share, the shipped files): " + rows + ".")


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    args = ap.parse_args(argv)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    numbers = ledger()
    with tempfile.TemporaryDirectory(prefix="r59_questmap_") as tmp:
        count = draft(Path(tmp))
        result = subprocess.run(["luajit", "tools/r56_questmap/questmap.lua", ".", "--data", tmp, "--out", args.out,
                                 "--intro", intro(numbers)], cwd=REPO, capture_output=True, text=True)
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        print("questmap draft: %d quests" % count)
        return result.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

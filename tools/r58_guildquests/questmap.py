#!/usr/bin/env python3
"""Round 58 lane GUILDQUESTS: the structure page for the user.

Writes a draft folder whose data/zones holds only the Miner's Guild's quests
(the two guild files, the four Battlegrounds files, and of each camp zone's
file its camp's hub and the guild quests homed there), then runs
tools/r56_questmap/questmap.lua --data on it (the real loader over the
draft), so the page shows the guild's structure alone: the By zone view
lists each camp zone with its foreman's hunt, raid and follow-ups (a shared
quest in every zone it is given in), the guild files the gather quests;
the Chains view shows each tier's two gather quests with their follow-ups.

    python3 tools/r58_guildquests/questmap.py [--out FILE]

FILE defaults to ~/projects/grudgelands-orchestration/r58/questmap/index.html.
Python 3 standard library only; LuaJIT runs the page builder.
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"
DEFAULT_OUT = Path.home() / "projects/grudgelands-orchestration/r58/questmap/index.html"
INTRO = ("Round 58: the Miner's Guild's quests alone (placeholder texts, [PH]). The guild files (The Charter "
         "of Stone, The Oathdelvers) hold the gather quests by depth tier, given by every own camp whose lift "
         "reaches the tier (the foreman roles foreman_tk ... foreman_t6). Each camp zone shows its foreman: "
         "its hunt (line camp; by day, or after dark where the zone's quests already hunt every day role), the raid of a T4 camp, and the follow-ups of every tier its lift reaches "
         "(line guild; they open once both gather quests of the tier are done and travel to the guild leader "
         "of the zone's race region). The Chains view shows each tier's two gather quests with the two "
         "follow-ups (one per faction). Rewards: XP and the quest copper, no reputation; the camp hunts add a "
         "choice of the tier's leather, cloth or bar; the raid asks for the camp's four guards and its captain.")


def ours(q):
    return re.match(r"^(guild_|camp_)", q.get("id", "")) is not None


def draft(root):
    zones = root / "data" / "zones"
    zones.mkdir(parents=True)
    count = 0
    for path in sorted(QUESTS.glob("*.quests.json")):
        if path.name.endswith(".front.quests.json"):
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        hubs = [h for h in data.get("hubs") or [] if any(g.get("npc", "").startswith("r58_") for g in h["givers"])]
        quests = [q for q in data.get("quests") or [] if ours(q)]
        if not hubs and not quests and not data.get("zone") in ("charter_of_stone", "oathdelvers"):
            continue
        out = {"zone": data["zone"]}
        for key in ("reworked", "identity"):
            if key in data:
                out[key] = data[key]
        out["hubs"], out["quests"] = hubs, quests
        (zones / path.name).write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        count += len(quests)
    return count


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    args = ap.parse_args(argv)
    with tempfile.TemporaryDirectory(prefix="r58_guildquests_") as tmp:
        count = draft(Path(tmp))
        result = subprocess.run(["luajit", "tools/r56_questmap/questmap.lua", ".", "--data", tmp, "--out", args.out,
                                 "--intro", INTRO], cwd=REPO, capture_output=True, text=True)
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        print("questmap draft: %d guild quests" % count)
        return result.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

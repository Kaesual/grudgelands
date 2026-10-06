#!/usr/bin/env python3
"""Round 40 PX: the server cost of the built player-skill effects.

Reads tools/r40_v3/data.json (run tools/r40_v3/effects.py first; its
emitters carry the build's numbers) and prints, per grug_particle_scale, the
per-effect cost of one occurrence and the busy fight of the V3 page: NEAR
players near each other on a server of ALL players, split evenly over the
four classes, each using every effect of their kit at its own pace (an upper
bound). Cost model and constants: tools/r40_v3/cost_model.py (plan §2.12);
every number is an estimate except the measured Lua call costs.

    python3 tools/r40_px/costs.py [--near 20] [--all 100]
"""
import argparse
import json
from pathlib import Path

DATA = Path(__file__).resolve().parents[1] / "r40_v3" / "data.json"
# The page's kits (V3 template.html): the player-side effects per class.
KITS = {
    "warrior": ["charge", "mighty_blow", "hamstring", "taunt", "hold_ground", "proc"],
    "mage": ["ice_nova", "fireball", "blink", "cinderfall", "glacial_ward", "proc"],
    "priest": ["smite", "heal", "shield_spell", "mend", "word_of_ruin", "proc"],
    "scout": ["skill_arrow", "snare_hit", "pinning_hit", "sidestep", "sprint", "opening", "proc"],
}


def occurrence(c, near, all_):
    """Bytes out of the server, bytes into one nearby player, main-thread us."""
    out = c["near_wire"] * near + c["all_wire"] * all_
    inb = c["near_wire"] + c["all_wire"]
    us = c["lua_us"] + c["near_us"] * near + c["all_us"] * all_ + c["player_check_us"] * all_
    return out, inb, us


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--near", type=int, default=20)
    ap.add_argument("--all", type=int, default=100)
    args = ap.parse_args()
    data = json.loads(DATA.read_text())
    by_id = {e["id"]: e for e in data["effects"]}
    print("per occurrence at 1.0 (near %d, all %d):" % (args.near, args.all))
    print("%-14s %5s %4s %5s %8s %9s %9s" % ("effect", "parts", "spwn", "single", "B/near", "B out", "us"))
    for kit in KITS.values():
        for eid in kit:
            if eid == "proc" and kit is not KITS["warrior"]:
                continue
            c = by_id[eid]["cost"]["1.0"]
            out, inb, us = occurrence(c, args.near, args.all)
            print("%-14s %5d %4d %5d %8d %9d %9.1f" % (eid, c["particles"], c["spawners"], c["singles"],
                                                       inb, out, us))
    per = args.near / 4
    for scale in data["scales"]:
        out = inb = us = parts = t_inb = 0.0
        for kit in KITS.values():
            for eid in kit:
                e = by_id[eid]
                rate = per * (e.get("pace") or 0)
                c = e["cost"][scale]
                o, i, u = occurrence(c, args.near, args.all)
                out, inb, us, parts = out + rate * o, inb + rate * i, us + rate * u, parts + rate * c["particles"]
                if e.get("today_cost"):
                    t_inb += rate * occurrence(e["today_cost"], args.near, args.all)[1]
        print("busy fight at %s: %.1f KB/s out of the server, %.1f KB/s into each nearby player, "
              "%.0f us/s main thread (%.2f %% of a core), %.0f particles/s started; today %.1f KB/s "
              "into each player for the skills that already show particles" % (
                  scale, out / 1000, inb / 1000, us, us / 10000, parts, t_inb / 1000))


if __name__ == "__main__":
    main()

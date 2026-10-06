#!/usr/bin/env python3
"""Round 40 PM: the server cost of the built boss and mob-special effects.

Reads tools/r40_v3/data.json (run tools/r40_v3/effects.py first; its boss and
mob emitters carry the build's numbers) and adds the looks PM moved onto the
helper unchanged (KEPT, the same emitters as grug_core/particle_effects.lua).
Prints, per grug_particle_scale, the cost of each boss and mob while it
fights: every effect at the pace its card names (an upper bound: every
signature, breath and aura on cooldown), NEAR players watching on a server of
ALL players, next to what the same encounter sends today. Cost model and
constants: tools/r40_v3/cost_model.py (plan §2.12); every number is an
estimate except the measured Lua call costs.

    python3 tools/r40_pm/costs.py [--near 20] [--all 100]
"""
import argparse
import json
import sys
from pathlib import Path

V3 = Path(__file__).resolve().parents[1] / "r40_v3"
sys.path.insert(0, str(V3))
import cost_model as cm  # noqa: E402
import effects as fx  # noqa: E402

sp, single = fx.sp, fx.single
SNOW = "default_snow.png^[colorize:#8ee8ff:120"
ROCK_YELLOW = "grug_mobs_rock.png^[colorize:#fff27a:230"

# The looks PM moved onto the helper unchanged (particle_effects.lua), and
# the two mob looks the catalogue left out: a poison tick and the Oerkki's
# kept arrival puff (its origin is the card).
KEPT = {
    "elite_windup": [sp(24, 0.4, "#ff5a1e", ("box", [-0.7, 0.2, -0.7], [0.7, 1.8, 0.7]),
                        vel=[[-0.5, 1, -0.5], [0.5, 3, 0.5]], exp=(0.3, 0.7), size=(2.5, 4), glow=8,
                        fade=False)],
    "breath_burst": [sp(54, 0.35, "#8ee8ff", ("box", [-2, 0, -2], [2, 3, 2]), vel=[[-3, 0.5, -3], [3, 5, 3]],
                        exp=(0.4, 1.6), size=(2, 6), glow=10, tex=SNOW, fade=False)],
    "dragon_patch": [sp(36, 0.25, "#8ee8ff", ("box", [-1, 0, -1], [1, 0.5, 1]), vel=[[-1, 0.2, -1], [1, 1.5, 1]],
                        exp=(0.4, 1.2), size=(1.5, 3.5), glow=8, tex=SNOW, fade=False)],
    "lightning_ring": [single(32, "#fff27a", ("disc", [0, 0.1, 0], 2.0, True), exp=(1.5, 1.5), size=(3, 3),
                              glow=12, tex=ROCK_YELLOW, fade=False)],
    "dragon_takeoff": [sp(48, 0.4, "#d8eef4", ("box", [-4, 0, -4], [4, 3, 4]), vel=[[-3, 0.5, -3], [3, 5, 3]],
                          exp=(0.4, 1.6), size=(2, 6), glow=3, fade=False,
                          tex="default_item_smoke.png^[colorize:#d8eef4:130")],
    "dive_windup": [sp(80, 1.0, "#ffd24a", ("box", [-5, 0, -5], [5, 4, 5]), vel=[[-3, 0.5, -3], [3, 5, 3]],
                       exp=(0.4, 1.6), size=(2, 6), glow=10, fade=False,
                       tex="default_item_smoke.png^[colorize:#ffd24a:190")],
    "poison_tick": [single(2, "#7ac943", ("disc", [0, 0.8, 0], 0.4, False), vel=[[0, 0.8, 0], [0, 1.4, 0]],
                           exp=(0.5, 0.7), size=(2, 2.5), glow=4,
                           tex="mobs_bubble_particle.png^[multiply:#7ac943", at="target")],
    "oerkki_arrival": [sp(12, 0.2, "#7030a0", ("box", [-0.4, 0, -0.4], [0.4, 1.4, 0.4]), exp=(0.2, 0.5),
                          size=(1, 2), glow=4, fade=False)],
}

# Today's looks at the same moments (the base code), where they differ:
# the V3 page's TODAY plus the kept looks, which are the same before and after.
TODAY_EXTRA = {
    "breath_bolt": fx.TODAY["breath_bolt"],
    "lightning_strike": fx.TODAY["lightning_strike"],
    "gust": fx.TODAY["gust"],
    "dive": fx.TODAY["dive"],
    "enrage": fx.TODAY["enrage"],
}

ELITE = [("elite_windup", 1 / 10), ("elite_cone", 1 / 10)]
DRAGON = [("breath_windup", 1 / 6), ("breath_bolt", 1 / 6), ("breath_burst", 1 / 6),
          ("dragon_patch", 2 / 6), ("gust", 1 / 12), ("dragon_takeoff", 1 / 15),
          ("dive_windup", 1 / 15), ("dive", 1 / 15)]
# Encounter -> (effect, occurrences per second); "x0.5" scales an effect's
# cost (Bone Call: two of the card's four resolve bursts).
ENCOUNTERS = {
    "Dwarf king (Shatter)": [("king_windup_ring", 1 / 8), ("king_shatter", 1 / 8)] + ELITE,
    "Orc king (Cleave)": [("king_cleave", 1 / 8)] + ELITE,
    "Human king (Rally)": [("king_aura", 1 / 8), ("king_resolve", 1 / 8)] + ELITE,
    "Elf king (Volley)": [("king_aura", 1 / 8), ("projectile_impact", 3 / 8)] + ELITE,
    "Undead king (Bone Call)": [("king_aura", 1 / 8), ("king_resolve", 0.5 / 8)] + ELITE,
    "Troll king (Regrowth)": [("king_aura", 1 / 8), ("king_resolve", 0.25 / 8)] + ELITE,
    "Any elite or rare": ELITE,
    "Ice dragon": DRAGON,
    "Storm dragon": [(e, r / 2 if e.startswith("breath") or e == "dragon_patch" else r) for e, r in DRAGON]
    + [("lightning_ring", 1 / 14), ("lightning_strike", 1 / 14)],
    "Kraken": [("kraken_drag", 1 / 3)] + ELITE,
    "Spider (web)": [("web", 1 / 3)],
    "Serpent, Scorpion, Viper (poison)": [("poison", 1 / 6), ("poison_tick", 3 / 6)],
    "Panther, Tiger, Leopard, Boar (pounce)": [("pounce", 1 / 8)],
    "Bog Ooze (aura)": [("ooze_aura", 1)],
    "Treant (aura)": [("treant_aura", 1 / 2)],
    "Oerkki (blink)": [("oerkki_blink", 1 / 5), ("oerkki_arrival", 1 / 5)],
    "Wisp (blink)": [("wisp_blink", 1 / 4)],
    "Ranged mob (impacts)": [("projectile_impact", 1 / 2)],
}
ONCE = ["enrage", "whelps", "ambush"]


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
    data = json.loads((V3 / "data.json").read_text())
    by_id = {e["id"]: e for e in data["effects"]}

    def cost(eid, scale):
        if eid in KEPT:
            return cm.effect_cost(KEPT[eid], float(scale))
        return by_id[eid]["cost"][scale]

    def today(eid):
        if eid == "poison_tick":
            return None  # new: the catalogue's poison card covers both moments
        if eid in KEPT:
            return cm.effect_cost(KEPT[eid], 1.0)
        if eid == "oerkki_blink":
            return None  # the origin puff is new; the arrival is in KEPT
        if eid in TODAY_EXTRA:
            return cm.effect_cost(TODAY_EXTRA[eid], 1.0)
        return None

    print("once per fight at 1.0 (near %d, all %d):" % (args.near, args.all))
    for eid in ONCE:
        c = cost(eid, "1.0")
        out, inb, us = occurrence(c, args.near, args.all)
        t = today(eid)
        print("  %-10s %3d particles, %5d B into each nearby player, %6d B out, %6.1f us%s" % (
            eid, c["particles"], inb, out, us,
            ("; today %d B" % occurrence(t, args.near, args.all)[1]) if t else "; today none"))
    for scale in data["scales"]:
        print("while fighting at %s (near %d, all %d): KB/s out of the server, KB/s into each nearby "
              "player, us/s main thread, particles/s started; today KB/s into each player" % (
                  scale, args.near, args.all))
        for name, parts in ENCOUNTERS.items():
            out = inb = us = parts_s = t_inb = 0.0
            for eid, rate in parts:
                c = cost(eid, scale)
                o, i, u = occurrence(c, args.near, args.all)
                out, inb, us, parts_s = out + rate * o, inb + rate * i, us + rate * u, \
                    parts_s + rate * c["particles"]
                t = today(eid)
                if t:
                    t_inb += rate * occurrence(t, args.near, args.all)[1]
            print("  %-40s %7.1f %6.2f %7.0f %6.1f   today %5.2f" % (
                name, out / 1000, inb / 1000, us, parts_s, t_inb / 1000))


if __name__ == "__main__":
    main()

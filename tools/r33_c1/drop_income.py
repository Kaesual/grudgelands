#!/usr/bin/env python3
"""Round 33 lane C1: gear-drop sale income per level band, before and after.

The income model (tools/r29_e4/income.py) counts signature and material loot
only. This adds what a player gets for SELLING the gear that drops, with the
same kills per band:

  before  Round 32: a normal kill 3 % Uncommon, an elite 20 % Uncommon + 3 %
          Rare, one uniform pick over the tier's 18 catalogue items (weapons,
          armour); a vendor paid the Common payout whatever the quality.
  after   Round 33 (round33-plan.md section 2.1): a normal kill 5/2/1 %
          white/blue/gold, an elite or named rare 10/10/5 %, one pick over the
          26 items of grug_gear.drop_pool (plus shield, spellbook, six
          trinkets); blue sells x3, gold x6.

MEAN_PAYOUT is the mean Common payout of each tier's pool, measured in the
engine by the probe tools/r33_c1/grug_probe_r33_c1 (the real resolved
grug_traders.sell_price; shields, spellbooks and trinkets pay 0 today).
Kills per band are income.py's, every kill counted as a normal mob (the
model's own assumption for loot); the elite column is per kill.

Usage: drop_income.py   (prints a Markdown table)
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "r29_e4"))
import income  # noqa: E402

# tier -> (mean payout over the 18 catalogue items, over the 26 pool items)
MEAN_PAYOUT = {1: (1.22, 0.85), 2: (2.22, 1.54), 3: (4.44, 3.08),
               4: (12.67, 8.77), 5: (31.61, 21.88), 6: (81.44, 56.38)}

BEFORE = {"normal": ((3, 1),), "elite": ((20, 1), (3, 1))}  # (percent, sale factor)
AFTER = {"normal": ((5, 1), (2, 3), (1, 6)), "elite": ((10, 1), (10, 3), (5, 6))}


def per_kill(rows, mean):
    return sum(percent / 100.0 * factor for percent, factor in rows) * mean


def main():
    bands = income.estimate()
    out = ["| Band | Kills | Normal kill before / after | Band gear income before / after "
           "| Share of net income before / after | Elite kill before / after |",
           "|---|---:|---:|---:|---:|---:|"]
    for index, band in enumerate(bands):
        before_mean, after_mean = MEAN_PAYOUT[index + 1]
        nb, na = per_kill(BEFORE["normal"], before_mean), per_kill(AFTER["normal"], after_mean)
        eb, ea = per_kill(BEFORE["elite"], before_mean), per_kill(AFTER["elite"], after_mean)
        gb, ga = band["kills"] * nb, band["kills"] * na
        out.append("| %s | %.0f | %.2fc / %.2fc | %.0fc / %.0fc | %.1f %% / %.1f %% | %.2fc / %.2fc |" % (
            band["band"], band["kills"], nb, na, gb, ga,
            100 * gb / (band["net"] + gb), 100 * ga / (band["net"] + ga), eb, ea))
    print("\n".join(out))


if __name__ == "__main__":
    main()

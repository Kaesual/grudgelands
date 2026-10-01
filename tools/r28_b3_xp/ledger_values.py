"""Round 28 Lane B3: print the design ledger's XP numbers (r28common.py) as
plain lines for tools/r28_b3_xp/portable_test.lua, which recomputes every
line with the real grug_xp / grug_mobs code and requires equality.

Usage (repo root): python3 tools/r28_b3_xp/ledger_values.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "r28_design"))
import r28common as C  # noqa: E402

PLAYER_LEVELS = (1, 2, 4, 5, 9, 10, 11, 15, 20, 25, 30, 40, 45, 50, 55, 59, 60)
WEIGHTS = (0.25, 0.4, 0.5, 1, 1.25, 1.5, 2, 2.5, 3.3, 4, 6.75, 10)


def main():
    out = []
    for level in range(1, C.LEVEL_CAP + 1):
        out.append("mob %d %d" % (level, C.M(level)))
        out.append("start %d %d" % (level, C.CUMULATIVE[level]))
        if level < C.LEVEL_CAP:
            out.append("level_xp %d %d" % (level, C.level_xp(level)))
        # level_of on both sides of every threshold
        for xp in (C.CUMULATIVE[level] - 1, C.CUMULATIVE[level], C.CUMULATIVE[level] + 1):
            if xp >= 0:
                out.append("level_of %d %d" % (xp, C.level_of(xp)))
        for weight in WEIGHTS:
            for human in (0, 1):
                out.append("quest %r %d %d %d" % (weight, level, human,
                                                  C.quest_xp(weight, level, bool(human))))
    for player in PLAYER_LEVELS:
        for mob in range(1, 71):
            for tier in ("normal", "elite", "rare"):
                for n in (1, 2, 3):
                    out.append("kill %d %d %s %d %d" % (mob, player, tier, n,
                                                       C.kill_xp(mob, player, tier, n)))
        for kind in ("ore", "gem", "fish"):
            for tier in range(1, 7):
                out.append("gather %s %d %d %d" % (kind, tier, player,
                                                   C.gathering_xp(kind, tier, player)))
    print("\n".join(out))


if __name__ == "__main__":
    main()

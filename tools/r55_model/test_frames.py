#!/usr/bin/env python3
"""The offhand frame convention, proven on a built model (Round 55 lane
MODEL; docs/technical/offhand-format.md §2, §9).

Builds the player and NPC models in memory with tools/r33_c3/gen_cloak_model.py
from REFERENCE (the CONTRACT's params.json, 2026-10-21, whose numbers §9 of the
format doc quotes; the back cards as of main 7e2df348) and from variants of it, and reads every position back
through the engine's B3D maths (gen_cloak_model.Rig), in the catalog frame:

  R  §9's reference points to 1e-3 px: the size-2 shield's top centre and
     point at rest and with the Block key [90, 0, 0] before the arm moves
     (the top forwards), the book's front cover corner at rest;
  K  a keyed entry: linear per component between keys, wrapping round a
     looping clip, holding the last key in a one-shot clip; a translation
     key moves the pivot in the catalog frame;
  S  steadiness: s = 1 holds the item at the clip's mean angle relative to
     Body over walking frames, s = 0 swings with the arm, s = 0.5 between;
     the pivot follows the arm either way;
  I  identity: every frame without an entry (another clip, the single
     frames between ranges) holds the bone rigid on the arm, in both models.

    python3 tools/r55_model/test_frames.py      # exit 1 on a failure

The committed models need not equal REFERENCE: the finish step replaces
params.json, and this test keeps its own copy. Pure Python 3.
"""
import copy
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools/r33_c3"))
import gen_cloak_model as g  # noqa: E402

oh, om = g.oh, g.om
REFERENCE = {
    "format": 1,
    "shield": {
        "shape": {"width": 10, "height": 13, "top": 0.42, "shoulder": 0.45, "taper": 0.75, "ridge": 1.5,
                  "thick": 1},
        "boss": {"radius": 1.25, "height": 1, "lift": 0.15},
        "sizes": [0.85, 0.92, 1.0],
        "tier_step": {"1": 0, "2": 0, "3": 1, "4": 1, "5": 2, "6": 2},
        "place": {"bone": "Offhand_Shield", "pos": [8.5, 14, 0], "rot": [0, 70, 0], "order": "YXZ"},
    },
    "book": {
        "shape": {"width": 5.5, "height": 7, "pages": 2.5, "cover": 0.5, "open": 150, "inset": 0.4,
                  "spine_min": 0.3},
        "ribbon": {"x0": 0.05, "x1": 0.45, "below": 2.5, "into": 0.4, "half_depth": 0.2},
        "place": {"bone": "Offhand_Book", "pos": [7.9886, 13.5792, 0], "rot": [0, 180, 45], "order": "YXZ"},
    },
    "back": {"size": 12, "body": {"pos": [0, 18, -3], "rot": [0, 180, 0], "order": "YXZ"},
             "cloak": {"pos": [0, 18, -3.25], "rot": [0, 180, 0], "order": "YXZ"}},
    "wings": {"width": 3, "angle": 20, "drop": 0, "thick": 0.35},
    "bones": {
        "Offhand_Shield": {"pivot": [8, 13, 0], "clips": {
            "block": {"rot": [90, 0, 0], "order": "XYZ"},
            "block_walk": {"rot": [90, 0, 0], "order": "XYZ"}}},
        "Offhand_Book": {"pivot": [8, 13, 0], "clips": {}},
    },
}
TOL = 1e-3          # px (§9 quotes three decimals)

failures = []
checks = 0


def check(ok, label):
    global checks
    checks += 1
    if not ok:
        failures.append(label)
        print("FAIL " + label)


def model(params, kind="player"):
    if oh.validate(params):
        raise SystemExit("test_frames: invalid params: %s" % oh.validate(params))
    _, info = g.build(kind, (params, oh.pack(params)))
    return info, g.Rig(info["root"])


def to_catalog(p):
    return (-p[0] / g.PX, p[1] / g.PX, p[2] / g.PX)


def find(info, label, want):
    """The index (in the offhand part) of the vertex of `label` nearest to a
    catalog point at rest, and its distance."""
    _, part = info["parts"]["offhand"]
    best = min((math.dist(part.verts[i][0], want), i) for i, lb in enumerate(part.labels) if lb == label)
    return best[1], best[0]


def on_arm(info, rig, bone, index, frame):
    """A vertex at an engine frame with the arm's own motion taken out (the
    bone key alone), in the catalog frame."""
    _, part = info["parts"]["offhand"]
    v = g.to_model(part.verts[index][0])
    arm = rig.skin("Arm_Left", frame + 1)
    moved = g.apply(g.mul(g.inverse_rigid(arm), rig.skin(bone, frame + 1)), v)
    return to_catalog(moved)


def relative_turn(rig, bone, frame, parent):
    """The bone's rotation relative to `parent`'s at a frame, catalog frame."""
    a = g.rotation(rig.skin(parent, frame + 1))
    b = g.rotation(rig.skin(bone, frame + 1))
    return g.flip(om.mat_mul(om.transpose(a), b))


def angle_between(a, b):
    """Degrees between two rotation matrices."""
    r = om.mat_mul(om.transpose(a), b)
    c = max(-1.0, min(1.0, (r[0][0] + r[1][1] + r[2][2] - 1) / 2))
    return math.degrees(math.acos(c))


def clip(info, name):
    for n, first, last, period in g.clip_ranges(info["kind"], info["layout"]):
        if n == name:
            return first, last, period
    raise KeyError(name)


def close(a, b, tol=TOL):
    return max(abs(x - y) for x, y in zip(a, b)) <= tol


def fmt(p):
    return "(%s)" % ", ".join("%.4f" % c for c in p)


def main():
    # --- R: the format doc's reference points -------------------------------
    info, rig = model(REFERENCE)
    top_rest, bottom_rest = (10.849, 19.46, 0.855), (10.849, 6.46, 0.855)
    top_block, bottom_block = (10.849, 12.145, 6.46), (10.849, 12.145, -6.54)
    i_top, d_top = find(info, "shield_2", top_rest)
    i_bot, d_bot = find(info, "shield_2", bottom_rest)
    check(d_top <= TOL, "R shield top centre at rest %s (off by %.2g)" % (fmt(top_rest), d_top))
    check(d_bot <= TOL, "R shield point at rest %s (off by %.2g)" % (fmt(bottom_rest), d_bot))
    block = clip(info, "block")[0]
    for index, want, what in ((i_top, top_block, "top centre"), (i_bot, bottom_block, "point")):
        got = on_arm(info, rig, "Offhand_Shield", index, block)
        check(close(got, want), "R shield %s with the Block key before the arm moves: %s, want %s" % (
            what, fmt(got), fmt(want)))
        print("R shield %s: rest %s, Block %s" % (
            what, fmt(on_arm(info, rig, "Offhand_Shield", index, 0)), fmt(got)))
        rest = on_arm(info, rig, "Offhand_Shield", index, 0)
        check(close(rest, info["parts"]["offhand"][1].verts[index][0]),
              "R stand frame 0: the shield %s rigid on the arm" % what)
    got = on_arm(info, rig, "Offhand_Shield", i_top, block)
    check(got[2] > 0, "R the Block key turns the shield's top forwards (+z)")
    i_book, d_book = find(info, "book_cover_f", (10.652, 15.865, -5.766))
    print("R book cover corner: rest %s" % fmt(on_arm(info, rig, "Offhand_Book", i_book, 0)))
    check(d_book <= TOL, "R book front cover corner at rest (off by %.2g)" % d_book)

    # --- K: keyed entries ---------------------------------------------------------
    p = copy.deepcopy(REFERENCE)
    clips = p["bones"]["Offhand_Book"]["clips"]
    clips["walk"] = {"keys": [{"frame": 0, "rot": [0, 0, 0]}, {"frame": 10, "rot": [40, 0, 0], "pos": [0, 2, 0]}],
                     "order": "XYZ"}
    clips["swing"] = {"keys": [{"frame": 2, "rot": [0, 0, 10]}, {"frame": 6, "rot": [0, 0, 30]}], "order": "XYZ"}
    info, rig = model(p)
    first, last, period = clip(info, "walk")
    for i, want_deg in ((0, 0), (5, 20), (10, 40), (period - 1, 40 * 1 / 9), (period, 0)):
        if first + i > last:
            continue
        turn = relative_turn(rig, "Offhand_Book", first + i, "Arm_Left")
        want = oh.euler([want_deg, 0, 0], "XYZ")
        check(angle_between(turn, want) < 1e-3, "K walk frame %d: %.2f deg about x (got %.4f deg off)" % (
            i, want_deg, angle_between(turn, want)))
    # the pivot moved by the interpolated translation (frame 5: [0, 1, 0])
    pivot = g.to_model(p["bones"]["Offhand_Book"]["pivot"])
    for i, dy in ((5, 1.0), (10, 2.0)):
        f = first + i
        moved = g.apply(g.mul(g.inverse_rigid(rig.skin("Arm_Left", f + 1)), rig.skin("Offhand_Book", f + 1)),
                        pivot)
        got = to_catalog(moved)
        want = om.add(p["bones"]["Offhand_Book"]["pivot"], (0, dy, 0))
        check(close(got, want), "K walk frame %d: the pivot moved %s, want %s" % (i, fmt(got), fmt(want)))
    first, last, period = clip(info, "swing")
    check(period is None, "K swing is a one-shot clip")
    for i, want_deg in ((0, 10), (2, 10), (4, 20), (6, 30), (last - first, 30)):
        turn = relative_turn(rig, "Offhand_Book", first + i, "Arm_Left")
        want = oh.euler([0, 0, want_deg], "XYZ")
        check(angle_between(turn, want) < 1e-3, "K swing frame %d: %.0f deg about z" % (i, want_deg))

    # --- S: steadiness ---------------------------------------------------------------
    spreads = {}
    for s in (0, 0.5, 1):
        p = copy.deepcopy(REFERENCE)
        p["bones"]["Offhand_Shield"]["clips"]["walk"] = {"rot": [0, 0, 0], "order": "XYZ", "steady": s}
        info, rig = model(p)
        first, last, _ = clip(info, "walk")
        turns = [relative_turn(rig, "Offhand_Shield", f, "Body") for f in range(first, last + 1)]
        spreads[s] = max(angle_between(turns[0], t) for t in turns)
        if s == 1:
            arm = [g.arm_motion(rig, f) for f in range(first, last + 1)]
            mean = g.flip(om.quat_matrix(om.quat_mean(arm)))
            check(angle_between(turns[0], mean) < 1e-3, "S steady 1: the item at the walk's mean arm angle")
        # the pivot still follows the arm
        pivot = g.to_model(p["bones"]["Offhand_Shield"]["pivot"])
        worst = max(math.dist(g.apply(rig.skin("Offhand_Shield", f + 1), pivot),
                              g.apply(rig.skin("Arm_Left", f + 1), pivot)) for f in range(first, last + 1))
        check(worst < 1e-4, "S steady %s: the pivot follows the arm (off by %.2g)" % (s, worst))
    check(spreads[1] < 1e-3, "S steady 1: no swing over the walk (%.4f deg)" % spreads[1])
    check(spreads[0] > 20, "S steady 0: the item swings with the arm (%.1f deg)" % spreads[0])
    check(0.3 * spreads[0] < spreads[0.5] < 0.7 * spreads[0],
          "S steady 0.5: about half the swing (%.1f of %.1f deg)" % (spreads[0.5], spreads[0]))

    # --- I: identity without an entry, in both models ---------------------------------
    for kind in ("player", "npc"):
        info, rig = model(REFERENCE, kind)
        frames = len(info["curves"]["front"])
        entries = {n: (a, b) for n, a, b, _ in g.clip_ranges(kind, info["layout"])}
        keyed = set()
        for name in REFERENCE["bones"]["Offhand_Shield"]["clips"]:
            if name in entries:
                keyed |= set(range(entries[name][0], entries[name][1] + 1))
        worst = 0.0
        for bone in g.OFFHAND_BONES:
            for f in range(frames):
                if bone == "Offhand_Shield" and f in keyed:
                    continue
                turn = relative_turn(rig, bone, f, "Arm_Left")
                worst = max(worst, angle_between(turn, ((1, 0, 0), (0, 1, 0), (0, 0, 1))))
        check(worst < 1e-3, "I %s: every frame without an entry rigid on the arm (%.2g deg)" % (kind, worst))
        check(frames == (485 if kind == "player" else 221), "I %s: %d frames" % (kind, frames))

    if failures:
        print("R55 MODEL FRAMES FAIL failures=%d checks=%d" % (len(failures), checks))
        return 1
    print("R55 MODEL FRAMES PASS checks=%d" % checks)
    return 0


if __name__ == "__main__":
    sys.exit(main())

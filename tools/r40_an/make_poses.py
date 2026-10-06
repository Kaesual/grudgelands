#!/usr/bin/env python3
"""Bake the Round 40 pose proposals into per-frame bone keys (lane V2, the
animation preview page; round40-plan.md §3.2, §4.1 V2, §4.2 AN1).

The poses are written below as a readable spec: per bone, keyframes of three
angles in degrees about the CHARACTER's axes (not the bone's own):

  pitch > 0  turns the bone's front upward: the head looks up, a hanging arm
             swings forward and up (90 = straight ahead, 180 = straight up),
             the torso leans back;
  yaw   > 0  turns toward the character's left;
  roll  > 0  tilts toward the character's right: a hanging arm swings toward
             the character's left (out for the left arm, in for the right).

The delta D = yaw * pitch * roll (roll applied first) acts at the bone's
pivot in the model frame as it stands in the bind pose, on top of a base
rotation: `hold` takes the base from stand frame 0 (the bone stops following
the clip, e.g. an arm that no longer swings while walking), `add` from the
base clip's own frame (the head keeps its bob, the legs keep walking). A
child of Body moves with Body's delta as usual; `counter` cancels Body's
delta on a bone (the legs stay upright while the torso leans).

Every pose is baked twice: over `stand` (unposed bones from stand frame 0)
and over `walk` (unposed bones from walk frames 168-187, a one-shot running
on through the walk cycle). The output `poses.json` holds, per pose and
base, one key per engine frame and bone in the B3D's own frame -- position
(x, y, z) and rotation (w, x, y, z) in the parent's space, exactly what
`tools/r33_c3/gen_cloak_model.py` writes into a KEYS chunk (engine frame
N is file frame N + 1). Lane AN1 appends the picked ones after frame 219;
the preview page converts them with the glb's z-mirror (build_glb.gl_quat,
gl_vec) and plays them on the glb. The cloak keys here are the base clip's;
AN1 replaces them with a cloak rule.

The maths runs in glTF space, where the converted model is verified to equal
the engine's B3D (tools/web_data/model/check_glb.py), and converts back with
the exact inverse of build_glb.gl_quat.

    python3 tools/r40_an/make_poses.py           # write poses.json
    python3 tools/r40_an/make_poses.py --check   # exit 1 if stale

Pure Python 3, no third-party module.
"""
import argparse
import json
import math
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools/web_data/model"))
sys.path.insert(0, str(REPO / "tools/r33_c3"))
import build_glb as bg  # noqa: E402  (gl_quat, gl_vec, node_trs, node_keys)
import gen_cloak_model as b3d  # noqa: E402  (the B3D chunk reader)

TARGET = Path(__file__).resolve().parent / "poses.json"
FPS = 30
STAND_FRAME = 0
WALK = (168, 187)

# --- the proposals ----------------------------------------------------------
# kind: "held" loops while the action runs (LENGTH frames, the spec wraps);
# "oneshot" plays once (its last key returns to the base pose).
# bone spec: {"mode": "hold"|"add", "counter": bool, "keys": [[frame, pitch, yaw, roll], ...]}
HELD_LENGTH = 20


def held(*keys):
    return [list(k) for k in keys]


POSES = [
    {"pose": "cast1", "variant": "A", "label": "Cast, one hand: palm forward",
     "use": "single-target spells (Fireball, Smite, Word of Ruin, Cinderfall)", "kind": "held",
     "bones": {
         "Arm_Right": {"mode": "hold", "keys": held((0, 82, 12, 0), (10, 90, 12, 0))},
         "Arm_Left": {"mode": "hold", "keys": held((0, 12, 0, 6))},
         "Head": {"mode": "add", "keys": held((0, -4, 0, 0))},
     }},
    {"pose": "cast1", "variant": "B", "label": "Cast, one hand: hand raised",
     "use": "single-target spells", "kind": "held",
     "bones": {
         "Arm_Right": {"mode": "hold", "keys": held((0, 148, 6, 0), (10, 154, 6, 0))},
         "Arm_Left": {"mode": "hold", "keys": held((0, 18, 0, 6))},
         "Head": {"mode": "add", "keys": held((0, 6, 0, 0))},
     }},
    {"pose": "cast2", "variant": "A", "label": "Cast, two hands: both forward",
     "use": "Ice Nova, Glacial Ward", "kind": "held",
     "bones": {
         "Arm_Right": {"mode": "hold", "keys": held((0, 72, 16, 0), (10, 80, 16, 0))},
         "Arm_Left": {"mode": "hold", "keys": held((0, 72, -16, 0), (10, 80, -16, 0))},
     }},
    {"pose": "cast2", "variant": "B", "label": "Cast, two hands: arms raised",
     "use": "Heal, Mend, Shield", "kind": "held",
     "bones": {
         # Pitch after roll: on a raised arm a negative pitch tips it forward.
         "Arm_Left": {"mode": "hold", "keys": held((0, -18, 0, 135), (10, -18, 0, 145))},
         "Arm_Right": {"mode": "hold", "keys": held((0, -18, 0, -135), (10, -18, 0, -145))},
         "Head": {"mode": "add", "keys": held((0, 14, 0, 0))},
     }},
    {"pose": "swing", "variant": "A", "label": "Overhead chop",
     "use": "Mighty Blow", "kind": "oneshot", "length": 14,
     "bones": {
         "Arm_Right": {"mode": "hold", "keys": [[0, 0, 0, 0], [4, 168, 0, 0], [7, 40, 4, 0], [10, 22, 4, 0], [13, 0, 0, 0]]},
         "Arm_Left": {"mode": "hold", "keys": [[0, 0, 0, 0], [4, 40, 0, 10], [7, 30, -6, 0], [13, 0, 0, 0]]},
         "Body": {"mode": "add", "keys": [[0, 0, 0, 0], [4, 8, 0, 0], [7, -14, 0, 0], [10, -10, 0, 0], [13, 0, 0, 0]]},
         "Leg_Left": {"mode": "add", "counter": True, "keys": [[0, 0, 0, 0]]},
         "Leg_Right": {"mode": "add", "counter": True, "keys": [[0, 0, 0, 0]]},
     }},
    {"pose": "swing", "variant": "B", "label": "Diagonal cut",
     "use": "Mighty Blow (matches the diagonal slash trail)", "kind": "oneshot", "length": 14,
     "bones": {
         "Arm_Right": {"mode": "hold", "keys": [[0, 0, 0, 0], [4, 155, 0, -40], [7, 55, 0, 30], [10, 35, 0, 38], [13, 0, 0, 0]]},
         "Arm_Left": {"mode": "hold", "keys": [[0, 0, 0, 0], [4, 25, 0, 12], [7, 20, 0, 0], [13, 0, 0, 0]]},
         "Body": {"mode": "add", "keys": [[0, 0, 0, 0], [4, 4, -18, 0], [7, -10, 20, 0], [10, -8, 16, 0], [13, 0, 0, 0]]},
         "Leg_Left": {"mode": "add", "counter": True, "keys": [[0, 0, 0, 0]]},
         "Leg_Right": {"mode": "add", "counter": True, "keys": [[0, 0, 0, 0]]},
         "Head": {"mode": "add", "keys": [[0, 0, 0, 0], [4, 0, 14, 0], [7, 0, -16, 0], [13, 0, 0, 0]]},
     }},
    {"pose": "bow", "variant": "A", "label": "Bow: drawn and held",
     "use": "Scout shots while the bow is drawn", "kind": "held",
     "bones": {
         "Body": {"mode": "add", "keys": held((0, 0, -22, 0))},
         "Leg_Left": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Leg_Right": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Head": {"mode": "add", "keys": held((0, 0, 22, 0))},
         "Arm_Left": {"mode": "hold", "keys": held((0, 90, 22, 0))},
         "Arm_Right": {"mode": "hold", "keys": held((0, 88, 62, 0), (10, 90, 64, 0))},
     }},
    {"pose": "block", "variant": "A", "label": "Guard: arms crossed in front",
     "use": "Hold Ground", "kind": "held",
     "bones": {
         "Arm_Left": {"mode": "hold", "keys": held((0, 78, -30, 0))},
         "Arm_Right": {"mode": "hold", "keys": held((0, 84, 30, 0))},
         "Body": {"mode": "add", "keys": held((0, -5, 0, 0))},
         "Leg_Left": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Leg_Right": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
     }},
    {"pose": "block", "variant": "B", "label": "Guard: shield arm raised",
     "use": "Hold Ground, a shield in the off hand", "kind": "held",
     "bones": {
         "Arm_Left": {"mode": "hold", "keys": held((0, 96, -24, 0))},
         "Arm_Right": {"mode": "hold", "keys": held((0, 30, 0, 0))},
         "Body": {"mode": "add", "keys": held((0, -5, 0, 0))},
         "Leg_Left": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Leg_Right": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Head": {"mode": "add", "keys": held((0, -6, 0, 0))},
     }},
    {"pose": "charge", "variant": "A", "label": "Charge: head-down rush",
     "use": "Charge, while dashing", "kind": "held",
     "bones": {
         "Body": {"mode": "add", "keys": held((0, -24, 0, 0))},
         "Leg_Left": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Leg_Right": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Head": {"mode": "add", "keys": held((0, 20, 0, 0))},
         "Arm_Right": {"mode": "hold", "keys": held((0, 42, 0, 0))},
         "Arm_Left": {"mode": "hold", "keys": held((0, -32, 0, 0))},
     }},
    {"pose": "charge", "variant": "B", "label": "Charge: shoulder first",
     "use": "Charge, while dashing", "kind": "held",
     "bones": {
         "Body": {"mode": "add", "keys": held((0, -14, -26, 0))},
         "Leg_Left": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Leg_Right": {"mode": "add", "counter": True, "keys": held((0, 0, 0, 0))},
         "Head": {"mode": "add", "keys": held((0, 12, 26, 0))},
         "Arm_Left": {"mode": "hold", "keys": held((0, 22, -10, 0))},
         "Arm_Right": {"mode": "hold", "keys": held((0, -22, 0, 0))},
     }},
    {"pose": "flinch", "variant": "A", "label": "Light hit flinch",
     "use": "taking a hit (rate-limited)", "kind": "oneshot", "length": 10,
     "bones": {
         "Body": {"mode": "add", "keys": [[0, 0, 0, 0], [2, 9, 0, 0], [5, 5, 0, 0], [9, 0, 0, 0]]},
         "Leg_Left": {"mode": "add", "counter": True, "keys": [[0, 0, 0, 0]]},
         "Leg_Right": {"mode": "add", "counter": True, "keys": [[0, 0, 0, 0]]},
         "Head": {"mode": "add", "keys": [[0, 0, 0, 0], [2, 16, 0, 0], [5, 8, 0, 0], [9, 0, 0, 0]]},
         "Arm_Left": {"mode": "add", "keys": [[0, 0, 0, 0], [2, 12, 0, 18], [9, 0, 0, 0]]},
         "Arm_Right": {"mode": "add", "keys": [[0, 0, 0, 0], [2, 12, 0, -18], [9, 0, 0, 0]]},
     }},
]


# --- quaternion maths in glTF space (x, y, z, w), Hamilton product ----------
def qmul(a, b):
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz)


def qinv(q):
    x, y, z, w = q
    return (-x, -y, -z, w)


def qaxis(axis, degrees):
    h = math.radians(degrees) / 2
    s = math.sin(h)
    return (axis[0] * s, axis[1] * s, axis[2] * s, math.cos(h))


# The character's axes in glTF space: it faces -z, up is +y, its right is +x
# (tools/web_data/model/README.md "Coordinates").
PITCH_AXIS = (1.0, 0.0, 0.0)
YAW_AXIS = (0.0, 1.0, 0.0)
ROLL_AXIS = (0.0, 0.0, -1.0)


def delta(pitch, yaw, roll):
    return qmul(qaxis(YAW_AXIS, yaw), qmul(qaxis(PITCH_AXIS, pitch), qaxis(ROLL_AXIS, roll)))


def b3d_quat(q):
    """The exact inverse of build_glb.gl_quat: glTF (x, y, z, w) -> B3D (w, x, y, z)."""
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w)
    return (w / n, x / n, y / n, -z / n)


def sample(keys, frame, period):
    """Linear interpolation of [frame, pitch, yaw, roll] keys; wraps if period."""
    keys = sorted(keys)
    if len(keys) == 1:
        return keys[0][1:]
    if period:
        frame = frame % period
        ext = keys + [[keys[0][0] + period] + keys[0][1:]]
    else:
        ext = keys
        if frame >= keys[-1][0]:
            return keys[-1][1:]
    for a, b in zip(ext, ext[1:]):
        if a[0] <= frame <= b[0]:
            t = (frame - a[0]) / (b[0] - a[0])
            return [a[i] + (b[i] - a[i]) * t for i in (1, 2, 3)]
    return keys[0][1:]


# --- the bake -----------------------------------------------------------------
def load_rig():
    data = bg.SOURCE.read_bytes()
    root = b3d.parse(data, 0, len(data))
    player = b3d.find_node(root, "Player")
    bones = bg.bones_of(player)
    names = [b3d.node_name(chunk) for chunk, _ in bones]
    keys = [bg.node_keys(chunk) for chunk, _ in bones]
    binds = [bg.node_trs(chunk) for chunk, _ in bones]
    root_rot = bg.gl_quat(bg.node_trs(player)[2])
    # World rotation of each bone's parent in the bind pose (glTF space).
    world = []
    parent_world = []
    for i, (_, parent) in enumerate(bones):
        pw = tuple(root_rot) if parent is None else world[parent]
        parent_world.append(pw)
        world.append(qmul(pw, tuple(bg.gl_quat(binds[i][2]))))
    return names, keys, parent_world, [p for _, p in bones]


def bake(pose, base, rig):
    names, keys, parent_world, parents = rig
    oneshot = pose["kind"] == "oneshot"
    length = pose["length"] if oneshot else HELD_LENGTH
    period = None if oneshot else HELD_LENGTH
    walk_len = WALK[1] - WALK[0] + 1
    out = {}
    for b, name in enumerate(names):
        spec = pose["bones"].get(name)
        rows, prev = [], None
        for i in range(length):
            clip_frame = STAND_FRAME if base == "stand" else WALK[0] + i % walk_len
            pos, _, rot = keys[b][clip_frame]
            if spec and spec.get("mode") == "hold":
                rot = keys[b][STAND_FRAME][2]
            q = tuple(bg.gl_quat(rot))
            if spec:
                d = delta(*sample(spec["keys"], i, period))
                if spec.get("counter"):
                    bspec = pose["bones"].get("Body")
                    if bspec:
                        d = qmul(qinv(delta(*sample(bspec["keys"], i, period))), d)
                pw = parent_world[b]
                q = qmul(qinv(pw), qmul(d, qmul(pw, q)))
            w = b3d_quat(q)
            # Same rotation, sign chosen next to the previous key, so a linear
            # interpolation between keys takes the short way.
            if prev and sum(a * c for a, c in zip(prev, w)) < 0:
                w = tuple(-c for c in w)
            prev = w
            rows.append([round(c, 6) for c in (*pos, *w)])
        out[name] = rows
    return {"frames": length, "keys": out}


def build():
    rig = load_rig()
    poses = []
    for pose in POSES:
        entry = {"id": "%s_%s" % (pose["pose"], pose["variant"].lower())}
        entry.update({k: pose[k] for k in ("pose", "variant", "label", "use", "kind")})
        entry["spec"] = pose["bones"]
        entry["clips"] = {base: bake(pose, base, rig) for base in ("stand", "walk")}
        poses.append(entry)
    doc = {
        "about": "Round 40 pose proposals, baked by tools/r40_an/make_poses.py; "
                 "keys per engine frame in the B3D's frame: position x, y, z and "
                 "rotation w, x, y, z in the parent bone's space.",
        "fps": FPS,
        "bones": rig[0],
        "base_frames": {"stand": [STAND_FRAME, STAND_FRAME], "walk": list(WALK)},
        "poses": poses,
    }
    text = json.dumps(doc, indent=1)
    # One line per key row and per spec key: the file stays diffable and small.
    text = re.sub(r"\[\s+(-?[\d.]+(?:,\s+-?[\d.]+)*)\s+\]",
                  lambda m: "[" + ", ".join(m.group(1).split(",\n")).replace(" ", "")
                  .replace(",", ", ") + "]", text)
    return text + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 if poses.json is stale")
    args = ap.parse_args()
    text = build()
    if args.check:
        if not TARGET.exists() or TARGET.read_text() != text:
            print("make_poses: poses.json is stale; rerun tools/r40_an/make_poses.py")
            return 1
        print("make_poses: poses.json is current")
        return 0
    TARGET.write_text(text)
    print("make_poses: wrote %s (%d bytes)" % (TARGET.relative_to(REPO), len(text)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

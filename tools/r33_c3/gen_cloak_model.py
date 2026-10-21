#!/usr/bin/env python3
"""Build the player model and the armored NPC model (Round 33 lane C3,
round33-plan.md §2.10; Round 40 pose clips; Round 54 armor, round54-plan.md
§4 MODEL; rules in docs/design/character_visuals.md §5b and
docs/technical/armor-format.md).

The cloak is the technique VoxeLibre's capes use (mcl_armor_character.b3d: a
thin box behind the body on its own `Cape` bone under the body, keyed per
animation frame so it hangs at rest and swings out while walking), applied to
OUR model: `mods/BASE/player_api/models/character.b3d` is read, a cloak box
and a `Cloak` bone are appended, and the result is written as
`mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d`. Nothing of the
original mesh, bones or keys changes, so every bone the game reads
(wield_geometry.lua) is the same. No VoxeLibre byte is copied: the geometry
and the swing curve are derived here from our own model.

Differences from VoxeLibre, and why:
  * the cloak is its OWN mesh buffer (a second TRIS chunk), so it is the
    model's SECOND texture -- `textures = {skin, cloak, ...}`. The skin stays
    the 64x32 composition every humanoid shares; the cloak texture is a
    separate 32x32 image (outer face left, lining right), and "no cloak" is a
    fully transparent one. VoxeLibre paints its cape into an 8x12 corner of
    the skin itself;
  * it is longer (shoulders to above the knee, VoxeLibre's ends at the hip),
    so the swing is derived from the legs' own keys and a clearance check
    below proves the swinging legs never pass through it.

Texture format (what a painter needs): 32x32 PNG. Columns 0-15 are the OUTER
face as seen from behind (left = the character's left), rows 0-31 shoulder
to hem. Columns 16-31 are the LINING as seen from the front (left = the
character's right). The cloak's thin edges take the outer face's border
pixels (column 0, column 15, row 0, row 31). Transparent pixels are holes
(alpha test, as on the skin); keep the outer face opaque.

Round 40 (lane AN1, round40-plan.md §2.14, §4.2) appends the picked pose
clips after these frames: every bone's keys come from
tools/r40_an/poses.json (each pose baked over `stand` and over `walk`), the
cloak's from the cloak rule below, and the clearance check covers them too.
The frames up to engine frame 220 stay byte-identical. The ranges are
registered in mods/PLAYER/grug_visuals/apply.lua (POSE_CLIPS), which
`--check` holds to the layout baked here.

Round 54 (lane MODEL) adds the armor and the weapon card:
  * the ARMOR buffer: every box of tools/r54_armor/data/catalog.json
    (mirrored copies included) as 24 vertices, rigid on its bone, in one mesh
    buffer with one texture, the armor atlas (128x64, data/atlas.json: each
    face samples its rectangle in the sheet orientation of armor-format.md
    §4). A box a piece does not wear is transparent in the atlas, so the
    model never changes with the gear;
  * two SWING BONES under Body, `Panel_Front` and `Panel_Back`, hinged at
    the belt, for the front and back panels (skirt, tabard, robe), keyed in
    every frame from the legs (panel_swing below); the cloak never swings
    less than the back panel;
  * the WEAPON card: a two-sided quad on Arm_Right in its own buffer, placed
    where grug_visuals' wield entity holds a diagonal tool at stature 1
    (wield_geometry.lua, read here), UV 0..1 over the whole image. The game
    sets it to blank.png in the world (the wield entity shows the weapon
    there) and to the held item's image in the inventory view, whose model[]
    element has no attachments.
Round 55 (lane MODEL, round55-plan.md §4 MODEL) adds the offhand look, every
number from tools/r55_offhand/params.json (docs/technical/offhand-format.md;
the geometry and key maths in offhand_model.py next to this file):
  * the OFFHAND buffer: the shield three times (one copy per size step,
    each sampling its own sheet of the offhand atlas, so a texture shows one
    copy) and the open book, on two bones under Arm_Left, `Offhand_Shield`
    and `Offhand_Book`, keyed here in every frame of every range from the
    parameter file (identity where a clip has no entry and between ranges;
    poses.json knows nothing of them);
  * the BACK buffer, two two-sided cards showing an item image, one riding
    the Cloak and one on Body (the NPC model: the body card only), each
    sampling its half of the back texture, and the two cloak WINGS on the
    Cloak bone (player only).
  Every part is always in the model; an empty slot is blank.png.
Texture slots: the player model {skin, cloak, armor, weapon, offhand, back,
wings}; the NPC model `grug_visuals_npc.b3d` {skin, armor, weapon, offhand,
back}: the same body, armor (the boxes of NPC_BOXES), card, offhand and back
card, no cloak and no wings, player_api's frames 0-220 only.

    python3 tools/r33_c3/gen_cloak_model.py           # write both models
    python3 tools/r33_c3/gen_cloak_model.py --check   # compare, exit 1 if stale
    python3 tools/r33_c3/gen_cloak_model.py --report  # counts, swings and gaps,
                                                      # the offhand clearance

Pure Python 3, no third-party module.
"""
import argparse
import json
import math
import re
import struct
import sys
from pathlib import Path

import offhand_model as om  # noqa: E402  (Round 55: the offhand parts, the contract's offhand.py)

oh = om.oh
REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "mods/BASE/player_api/models/character.b3d"
TARGET = REPO / "mods/PLAYER/grug_visuals/models/grug_visuals_character.b3d"
NPC_TARGET = REPO / "mods/PLAYER/grug_visuals/models/grug_visuals_npc.b3d"
POSES = REPO / "tools/r40_an/poses.json"
APPLY = REPO / "mods/PLAYER/grug_visuals/apply.lua"
CATALOG = REPO / "tools/r54_armor/data/catalog.json"
ATLAS = REPO / "tools/r54_armor/data/atlas.json"
WIELD = REPO / "mods/PLAYER/grug_visuals/wield_geometry.lua"

# --- the cloak box, in model units (10 = one node) -------------------------
# The body box is x -2.1..2.1, y 6.3..12.6, z -1.05..1.05; +z is forward
# (wield_geometry.lua section 3), so the back is z = -1.05.
HALF_W = 2.05            # 0.05 inside the body width: the arms' inner faces
                         # (x = +-2.1) never share a plane with the cloak
TOP = 12.6               # the shoulders
LENGTH = 8.4             # 16 skin pixels: shoulders to just above the knee
GAP = 0.10               # behind the body's back face
THICK = 0.35
Z_IN = -1.05 - GAP
Z_OUT = Z_IN - THICK
PIVOT = (0.0, TOP, (Z_IN + Z_OUT) / 2)   # the hinge along the shoulders

# --- the swing (degrees away from the back, per Lua animation frame) ------
BASE = 8.5               # at rest the hem stands a little off the legs and,
                         # since Round 54, behind the back panel, whose belt
                         # hinge sits 1 px further back than the cloak's
                         # (below 8 degrees the two meet; 3.0 before)
WALK_FACTOR = 0.6        # of the legs' own swing: legs reach 45 deg -> 30 deg
SIT = 35.0               # sitting: the hem rests behind the seat, not in it
STAND_SWAY = 3.0         # a slow sway over the 80-frame idle loop
MINE_SWAY = 4.0          # the punch nudges it

# Animation ranges of player_api's registration (player_api/init.lua).
STAND, SIT_R, LAY, WALK, MINE, WALK_MINE = (0, 79), (81, 160), (162, 166), \
    (168, 187), (189, 198), (200, 219)
# The seated keys: the sit range and the spare frame after it, which repeats
# its last key (the panels' sit rule covers both).
SEATED = (81, 161)
BASE_RANGES = (("stand", STAND), ("sit", SIT_R), ("lay", LAY), ("walk", WALK),
               ("mine", MINE), ("walk_mine", WALK_MINE))

# --- the Round 40 pose clips -------------------------------------------------
# The user's picks (round40-plan.md §2.14): pose -> variant in poses.json.
# Each pose gets two ranges, `<pose>` baked over stand and `<pose>_walk` over
# walk, in this order from FIRST_POSE_FRAME on (engine frame 220, the last
# frame of the source, stays a spare like the other single frames).
PICKS = (("cast1", "a"), ("cast2", "b"), ("swing", "b"), ("bow", "a"),
         ("block", "b"), ("charge", "b"), ("flinch", "a"))
FIRST_POSE_FRAME = 221
TWIST_LIFT = 0.2         # of the torso's twist the cloak swings out (pose_swing)

# --- Round 54: the armor -------------------------------------------------------
PX = 0.525               # model units per skin pixel (armor-format.md §1)
# Catalog bone -> the model's bone (NODE) name. A mirrored box's left copy
# rides the `_l` bone (or Body for a Body box).
BONE_NODE = {"body": "Body", "head": "Head", "arm_r": "Arm_Right", "arm_l": "Arm_Left",
             "leg_r": "Leg_Right", "leg_l": "Leg_Left",
             "panel_f": "Panel_Front", "panel_b": "Panel_Back"}
SWING_BONES = ("panel_f", "panel_b")
# The boxes NPCs wear (armor-format.md §2): every catalog box for now, since
# NPCs wear every tier. A box left out here is simply not in the NPC model.
NPC_BOXES = ("helm", "visor", "chest", "belt", "panel_f", "panel_b", "tasset",
             "sleeve", "bracer", "pauldron", "reinforce", "flare", "spike",
             "thigh", "knee", "boot", "toe")
FACES = ("top", "bottom", "right", "front", "left", "back")
FACE_NORMAL = {"front": (0, 0, 1), "back": (0, 0, -1), "right": (-1, 0, 0), "left": (1, 0, 0),
               "top": (0, 1, 0), "bottom": (0, -1, 0)}
# The panels' swing (round54-plan.md §4 MODEL, measured on the prototype):
# radians off vertical, the hem moving away from the leg it clears.
PANEL_BASE = math.degrees(0.06)
PANEL_FRONT_FACTOR = 1.2     # of the leg swinging forward
PANEL_BACK_FACTOR = 1.1      # of the leg swinging back
PANEL_TWIST_LIFT = 0.2       # of the torso's twist in a pose clip (panel_swing)
# A torso twisting over WALKING legs (the walking twins of the diagonal cut,
# the drawn bow and Charge) turns a panel's top corner, next to the hinge,
# into the thigh swinging forward; no swing angle moves that corner, so the
# check tolerates this much overlap there (model units, about one skin
# pixel) and the report prints the depth.
TWIST_WALK_OVERLAP = 0.5
CARD_GAP = 0.01          # each face of the weapon card off its plane (model units)
ZFIGHT_GAP = 0.25 * PX   # nearer same-facing faces z-fight (armor-format.md §1)
ZFIGHT_MIN_EXTENT = 0.1 * PX   # a thinner overlap is a sub-texel sliver
# Z-fighting the catalog itself causes, reported to the round's coordinator
# (the catalog changes only through them; Round 54 MODEL report): the real
# hat layer is +-4.38 px wide from y 23.62 (the catalog's `body` hat says
# +-4.5 from 23.5), 0.13 px outside the chest shell's sides where the shell
# rises above the shoulders; a tasset's top corner, turned up by its 22.5
# degrees, shares the arm's front and back planes (z +-2) for 0.19 px.
# Round 55: the wings' bottom edge starts at the cloak's hem (y 8) and inside
# the cloak (the hinge inset of format doc §3.4), so for the inset's 0.17 px it
# shares the plane of the cloak's bottom face: a sliver seen only from below,
# accepted by the coordinator. (The body card's draft z -3 px z-fought the
# bracers and reinforce boxes; params.json moved it to -3.55, clear of both.)
KNOWN_ZFIGHT = {("chest", "hat"), ("arm", "tasset"), ("arm_l", "tasset_l"),
                ("cloak", "wing_l"), ("cloak", "wing_r")}

# --- Round 55: the offhand ---------------------------------------------------------
OFFHAND_BONES = oh.BONES     # Offhand_Shield, Offhand_Book: children of Arm_Left


def exclusive(label):
    """The exclusive group of the z-fight check (round55-plan.md §3): the
    three shield copies and the book never show together, so a pair of two
    different members is skipped (the book's own boxes still meet each other)."""
    if label.startswith("shield_"):
        return label
    if label.startswith("book_"):
        return "book"
    return None


# --- b3d chunk tree ----------------------------------------------------------
class Chunk:
    def __init__(self, tag, head=b"", kids=None, raw=b""):
        self.tag, self.head, self.kids, self.raw = tag, head, kids, raw

    def encode(self):
        if self.kids is None:
            body = self.raw
        else:
            body = self.head + b"".join(kid.encode() for kid in self.kids)
        return self.tag.encode() + struct.pack("<i", len(body)) + body


def read_cstring(data, offset):
    end = data.index(b"\0", offset)
    return data[offset:end + 1], end + 1


def parse(data, offset, end):
    chunks = []
    while offset < end:
        tag = data[offset:offset + 4].decode()
        size = struct.unpack("<i", data[offset + 4:offset + 8])[0]
        start, stop = offset + 8, offset + 8 + size
        if tag == "BB3D":
            chunks.append(Chunk(tag, data[start:start + 4], parse(data, start + 4, stop)))
        elif tag == "NODE":
            name, cursor = read_cstring(data, start)
            head = name + data[cursor:cursor + 40]
            chunks.append(Chunk(tag, head, parse(data, cursor + 40, stop)))
        elif tag == "MESH":
            chunks.append(Chunk(tag, data[start:start + 4], parse(data, start + 4, stop)))
        else:
            chunks.append(Chunk(tag, raw=data[start:stop]))
        offset = stop
    return chunks


def node_name(chunk):
    return chunk.head[:chunk.head.index(b"\0")].decode()


def find_node(chunks, name):
    for chunk in chunks:
        if chunk.tag in ("BB3D", "NODE"):
            if chunk.tag == "NODE" and node_name(chunk) == name:
                return chunk
            hit = find_node(chunk.kids, name)
            if hit:
                return hit
    return None


def kid(chunk, tag):
    for k in chunk.kids:
        if k.tag == tag:
            return k
    raise SystemExit("gen_cloak_model: no %s chunk in %s" % (tag, chunk.tag))


# --- quaternions and matrices in Irrlicht's convention ----------------------
# The same math tools/r28_a3/mesh_bounds.py documents: a NODE's local matrix
# is T * R * S with R from quaternion::getMatrix_transposed.
def quat_matrix(w, x, y, z):
    n = math.sqrt(w * w + x * x + y * y + z * z) or 1.0
    w, x, y, z = w / n, x / n, y / n, z / n
    d = [0.0] * 16
    d[0] = 1 - 2 * y * y - 2 * z * z
    d[4] = 2 * x * y + 2 * z * w
    d[8] = 2 * x * z - 2 * y * w
    d[1] = 2 * x * y - 2 * z * w
    d[5] = 1 - 2 * x * x - 2 * z * z
    d[9] = 2 * z * y + 2 * x * w
    d[2] = 2 * x * z + 2 * y * w
    d[6] = 2 * z * y - 2 * x * w
    d[10] = 1 - 2 * x * x - 2 * y * y
    d[15] = 1.0
    return d


def local_matrix(pos, rot):
    m = quat_matrix(*rot)
    m[12], m[13], m[14] = pos
    return m


def mul(a, b):
    out = [0.0] * 16
    for col in range(4):
        for row in range(4):
            out[4 * col + row] = sum(a[4 * k + row] * b[4 * col + k] for k in range(4))
    return out


def apply(m, v):
    return tuple(m[row] * v[0] + m[4 + row] * v[1] + m[8 + row] * v[2] + m[12 + row]
                 for row in range(3))


def turn(m, v):
    """The rotation part of m applied to a direction."""
    return tuple(m[row] * v[0] + m[4 + row] * v[1] + m[8 + row] * v[2] for row in range(3))


def inverse_rigid(m):
    # rotation part transposed, translation -R^T t (every matrix here is rigid)
    r = [m[0], m[4], m[8], 0, m[1], m[5], m[9], 0, m[2], m[6], m[10], 0, 0, 0, 0, 1]
    t = (m[12], m[13], m[14])
    for row in range(3):
        r[12 + row] = -(r[row] * t[0] + r[4 + row] * t[1] + r[8 + row] * t[2])
    return r


def node_bind(chunk):
    name_len = chunk.head.index(b"\0") + 1
    values = struct.unpack("<10f", chunk.head[name_len:name_len + 40])
    return values[0:3], values[6:10]


def node_keys(chunk):
    keys = {}
    for k in chunk.kids:
        if k.tag != "KEYS":
            continue
        flags = struct.unpack("<i", k.raw[:4])[0]
        assert flags == 7, "expected pos+scale+rot keys"
        for i in range((len(k.raw) - 4) // 44):
            frame, *rest = struct.unpack("<i10f", k.raw[4 + 44 * i:48 + 44 * i])
            keys[frame] = (tuple(rest[0:3]), tuple(rest[6:10]))
    return keys


class Rig:
    """The bones of a parsed model: bind and animated matrices in model
    space, and the skinning matrix of a bone at a file frame."""

    def __init__(self, root):
        self.parent, self.chunk = {}, {}

        def walk(chunks, parent):
            for chunk in chunks:
                if chunk.tag == "NODE":
                    name = node_name(chunk)
                    self.parent[name], self.chunk[name] = parent, chunk
                    walk(chunk.kids, name)
                elif chunk.tag == "BB3D":
                    walk(chunk.kids, parent)
        walk(root, None)
        self.keys = {name: node_keys(chunk) for name, chunk in self.chunk.items()}
        self.bind_cache, self.frame_cache = {}, {}

    def bind(self, name):
        if name not in self.bind_cache:
            local = local_matrix(*node_bind(self.chunk[name]))
            parent = self.parent[name]
            self.bind_cache[name] = local if parent is None else mul(self.bind(parent), local)
        return self.bind_cache[name]

    def at(self, name, file_frame):
        key = (name, file_frame)
        if key not in self.frame_cache:
            k = self.keys[name].get(file_frame)
            local = local_matrix(*k) if k else local_matrix(*node_bind(self.chunk[name]))
            parent = self.parent[name]
            self.frame_cache[key] = local if parent is None else mul(self.at(parent, file_frame), local)
        return self.frame_cache[key]

    def skin(self, name, file_frame):
        return mul(self.at(name, file_frame), inverse_rigid(self.bind(name)))


# --- the swing curve ----------------------------------------------------------
def leg_swing(leg_keys, frame):
    """Degrees the leg stands off vertical at Lua frame `frame` (file frame + 1)."""
    _, rot = leg_keys[frame + 1]
    w = max(-1.0, min(1.0, abs(rot[0])))
    return 180.0 - 2 * math.degrees(math.acos(w))


def swing(frame, leg_keys):
    if STAND[0] <= frame <= STAND[1]:
        return BASE + STAND_SWAY * math.sin(math.pi * frame / 80.0) ** 2
    if SIT_R[0] <= frame <= SIT_R[1]:
        return SIT
    if WALK[0] <= frame <= WALK[1] or WALK_MINE[0] <= frame <= WALK_MINE[1]:
        return BASE + WALK_FACTOR * abs(leg_swing(leg_keys, frame))
    if MINE[0] <= frame <= MINE[1]:
        return BASE + MINE_SWAY * math.sin(math.pi * (frame - MINE[0]) / 9.0)
    return BASE  # lay and the single frames between the ranges


# --- the pose clips and their cloak rule ---------------------------------------
def pose_layout():
    """The picked clips in frame order and poses.json's bone list. A clip is
    {name, pose (the poses.json entry), base, first, last, once}."""
    doc = json.loads(POSES.read_text())
    by_id = {entry["id"]: entry for entry in doc["poses"]}
    layout, frame = [], FIRST_POSE_FRAME
    for pose, variant in PICKS:
        entry = by_id["%s_%s" % (pose, variant)]
        for base in ("stand", "walk"):
            frames = entry["clips"][base]["frames"]
            layout.append({"name": pose if base == "stand" else pose + "_walk",
                           "pose": entry, "base": base, "first": frame,
                           "last": frame + frames - 1, "once": entry["kind"] == "oneshot"})
            frame += frames
    return layout, doc["bones"]


def spec_angle(keys, frame, period, axis):
    """One angle (1 pitch, 2 yaw, 3 roll) of poses.json spec keys at a clip
    frame: linear between keys, wrapping over `period` for a held clip --
    the interpolation tools/r40_an/make_poses.py baked the bones with."""
    keys = sorted(keys)
    if len(keys) == 1:
        return keys[0][axis]
    if period:
        frame = frame % period
        if frame < keys[0][0]:
            frame += period
        keys = keys + [[keys[0][0] + period] + keys[0][1:]]
    elif frame >= keys[-1][0]:
        return keys[-1][axis]
    for a, b in zip(keys, keys[1:]):
        if a[0] <= frame <= b[0]:
            return a[axis] + (b[axis] - a[axis]) * (frame - a[0]) / (b[0] - a[0])
    return keys[0][axis]


def pose_twist(clip, i):
    """Degrees the torso twists (yaw) at frame i of a pose clip, 0 without a
    Body spec. A held clip's last frame repeats its first (make_poses.py
    HELD_LENGTH)."""
    body = clip["pose"]["spec"].get("Body")
    if not body:
        return 0.0
    period = None if clip["once"] else clip["last"] - clip["first"]
    return abs(spec_angle(body["keys"], i, period, 2))


def pose_swing(clip, i, leg_keys):
    """The cloak rule of a pose clip at its frame i. The cloak swings as in
    the base clip the pose was baked over (stand frame 0, or the walk frame
    whose legs the clip carries) and, while the torso leans BACK, hangs out by
    that lean too, so it stays plumb instead of following the back into the
    legs. A forward lean adds nothing: the cloak lies on the back as at rest
    and the hem moves away from the legs with the torso. A torso twisting on
    upright legs (bow, Charge, the diagonal cut) would sweep the cloak's lower
    corner into a leg, so it swings out by TWIST_LIFT of the twist: the
    closest leg gap of every pose clip stays at or above the base clips'."""
    if clip["base"] == "stand":
        base = swing(STAND[0], leg_keys)
    else:
        base = swing(WALK[0] + i % (WALK[1] - WALK[0] + 1), leg_keys)
    body = clip["pose"]["spec"].get("Body")
    if not body:
        return base
    # A held clip's last frame repeats its first (make_poses.py HELD_LENGTH).
    period = None if clip["once"] else clip["last"] - clip["first"]
    lean = max(0.0, spec_angle(body["keys"], i, period, 1))
    return base + lean + TWIST_LIFT * pose_twist(clip, i)


def registered_clips():
    """{pose: ((x, y) stand, (x, y) walk, once)} as apply.lua registers them."""
    pattern = (r"(\w+) = \{stand = \{x = (\d+), y = (\d+)\}, "
               r"walk = \{x = (\d+), y = (\d+)\}(, once = true)?\}")
    return {m.group(1): ((int(m.group(2)), int(m.group(3))),
                         (int(m.group(4)), int(m.group(5))), bool(m.group(6)))
            for m in re.finditer(pattern, APPLY.read_text())}


def expected_clips(layout):
    out = {}
    for stand, walk in zip(layout[0::2], layout[1::2]):
        out[stand["name"]] = ((stand["first"], stand["last"]),
                              (walk["first"], walk["last"]), stand["once"])
    return out


def clips_lua(clips):
    """The POSE_CLIPS rows apply.lua should hold, for the error message."""
    return "\n".join("\t%s = {stand = {x = %d, y = %d}, walk = {x = %d, y = %d}%s}," % (
        name, s[0], s[1], w[0], w[1], ", once = true" if once else "")
        for name, (s, w, once) in clips.items())


# --- the panels' swing ---------------------------------------------------------
def leg_angles(rig, file_frame):
    """Signed degrees each leg stands off the body's own vertical at a file
    frame, forward positive: the foot's offset from the hip after undoing the
    body's motion (a pose clip's lean counter-rotates the legs, so a leaning
    torso shows up here as legs swung the other way)."""
    body_rest = mul(rig.bind("Body"), inverse_rigid(rig.at("Body", file_frame)))
    out = []
    for name in ("Leg_Right", "Leg_Left"):
        hip = apply(rig.bind(name), (0, 0, 0))
        foot = (hip[0], 0.0, hip[2])
        move = mul(body_rest, rig.skin(name, file_frame))
        now_hip, now_foot = apply(move, hip), apply(move, foot)
        down = now_hip[1] - now_foot[1]
        forward = now_foot[2] - now_hip[2]
        out.append(math.degrees(math.atan2(forward, down)))
    return out


def panel_swing(rig, frame, twist):
    """(front, back) degrees off vertical at engine frame `frame`, each hem
    moving away from the body (front forward, back backward). The front panel
    follows the leg swinging forward, the back panel the leg swinging back
    (0.06 rad + 1.2x / 1.1x that leg's angle: on the walk cycle, whose legs
    mirror each other, that is the plan's |leg angle|). A torso twist in a
    pose clip turns a panel's corner toward a thigh, so both lift by
    PANEL_TWIST_LIFT of it. Sitting is not leg-driven: the thighs lie level
    through the belt line, so no front panel angle clears them (the hinge
    itself is inside the seated thigh); both panels hang straight down, the
    front one inside the thighs and the seat, the back one under the seat,
    and only the back panel's leg clearance is checked there."""
    if SEATED[0] <= frame <= SEATED[1]:
        return PANEL_BASE, PANEL_BASE
    angles = leg_angles(rig, frame + 1)
    forward = max([0.0] + angles)
    back = max([0.0] + [-a for a in angles])
    lift = PANEL_TWIST_LIFT * twist
    return (PANEL_BASE + PANEL_FRONT_FACTOR * forward + lift,
            PANEL_BASE + PANEL_BACK_FACTOR * back + lift)


# --- clearance: separating-axis test between two convex boxes ---------------
def box_axes(corners):
    # corners in the order of BOX_CORNERS below: three edge directions
    o = corners[0]
    return [tuple(corners[i][k] - o[k] for k in range(3)) for i in (1, 2, 4)]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def overlap(box_a, box_b, margin=0.0):
    axes = box_axes(box_a) + box_axes(box_b)
    axes += [cross(a, b) for a in box_axes(box_a) for b in box_axes(box_b)]
    for axis in axes:
        if sum(c * c for c in axis) < 1e-9:
            continue
        pa = [sum(p[k] * axis[k] for k in range(3)) for p in box_a]
        pb = [sum(p[k] * axis[k] for k in range(3)) for p in box_b]
        length = math.sqrt(sum(c * c for c in axis))
        if max(pa) + margin * length < min(pb) or max(pb) + margin * length < min(pa):
            return False
    return True


def gap(box_a, box_b):
    """The widest separation along the test axes (positive: apart by at least
    that much; the true distance can only be larger)."""
    axes = box_axes(box_a) + box_axes(box_b)
    axes += [cross(a, b) for a in box_axes(box_a) for b in box_axes(box_b)]
    best = None
    for axis in axes:
        length = math.sqrt(sum(c * c for c in axis))
        if length < 1e-9:
            continue
        pa = [sum(p[k] * axis[k] for k in range(3)) for p in box_a]
        pb = [sum(p[k] * axis[k] for k in range(3)) for p in box_b]
        sep = max(min(pb) - max(pa), min(pa) - max(pb)) / length
        best = sep if best is None else max(best, sep)
    return best


def corners_of(x0, x1, y0, y1, z0, z1):
    # index bits: 1 = x1, 2 = y1, 4 = z1
    return [(x1 if i & 1 else x0, y1 if i & 2 else y0, z1 if i & 4 else z0) for i in range(8)]


# --- building ------------------------------------------------------------------
def cloak_geometry():
    """24 vertices (4 per face, own normals and UVs) and 12 triangles."""
    x0, x1 = -HALF_W, HALF_W
    y0, y1 = TOP - LENGTH, TOP
    px = 1.0 / 32.0
    faces = [
        # (normal, four corners as (x, y, z, u, v)), corner order around the
        # face; triangles (0,1,2) and (0,2,3) must face outward, checked below.
        ((0, 0, -1), [(x0, y0, Z_OUT, 0.0, 1.0), (x0, y1, Z_OUT, 0.0, 0.0),
                      (x1, y1, Z_OUT, 0.5, 0.0), (x1, y0, Z_OUT, 0.5, 1.0)]),
        ((0, 0, 1), [(x1, y0, Z_IN, 0.5, 1.0), (x1, y1, Z_IN, 0.5, 0.0),
                     (x0, y1, Z_IN, 1.0, 0.0), (x0, y0, Z_IN, 1.0, 1.0)]),
        ((-1, 0, 0), [(x0, y0, Z_IN, px, 1.0), (x0, y1, Z_IN, px, 0.0),
                      (x0, y1, Z_OUT, 0.0, 0.0), (x0, y0, Z_OUT, 0.0, 1.0)]),
        ((1, 0, 0), [(x1, y0, Z_OUT, 0.5, 1.0), (x1, y1, Z_OUT, 0.5, 0.0),
                     (x1, y1, Z_IN, 0.5 - px, 0.0), (x1, y0, Z_IN, 0.5 - px, 1.0)]),
        ((0, 1, 0), [(x0, y1, Z_OUT, 0.0, 0.0), (x0, y1, Z_IN, 0.0, px),
                     (x1, y1, Z_IN, 0.5, px), (x1, y1, Z_OUT, 0.5, 0.0)]),
        ((0, -1, 0), [(x0, y0, Z_IN, 0.0, 1.0 - px), (x0, y0, Z_OUT, 0.0, 1.0),
                      (x1, y0, Z_OUT, 0.5, 1.0), (x1, y0, Z_IN, 0.5, 1.0 - px)]),
    ]
    verts, tris = [], []
    for normal, quad in faces:
        base = len(verts)
        for x, y, z, u, v in quad:
            verts.append(((x, y, z), normal, (u, v)))
        for a, b, c in ((0, 1, 2), (0, 2, 3)):
            p = [quad[i][:3] for i in (a, b, c)]
            n = cross(tuple(p[1][k] - p[0][k] for k in range(3)),
                      tuple(p[2][k] - p[0][k] for k in range(3)))
            # the source mesh winds so that cross(v1-v0, v2-v0) points outward
            if sum(n[k] * normal[k] for k in range(3)) <= 0:
                raise SystemExit("gen_cloak_model: inward triangle")
            tris.append((base + a, base + b, base + c))
    return verts, tris


# --- Round 54: catalog boxes in the model ---------------------------------------
def face_point(box, face, u, v):
    """A point of a box face at face coordinates u, v in 0..1 (u = the sheet's
    column direction, v = its row direction, row 0 on top), in catalog
    coordinates -- armor-format.md §4, the same function as
    tools/r54_armor/armorlib.py, so a face shows its sheet the way the render
    tool draws it."""
    x0, y0, z0, x1, y1, z1 = box
    w, h, d = x1 - x0, y1 - y0, z1 - z0
    return {
        "front": (x0 + u * w, y1 - v * h, z1),
        "back": (x1 - u * w, y1 - v * h, z0),
        "right": (x0, y1 - v * h, z0 + u * d),
        "left": (x1, y1 - v * h, z1 - u * d),
        "top": (x0 + u * w, y1, z0 + v * d),
        "bottom": (x0 + u * w, y0, z1 - v * d),
    }[face]


def rotate_about(p, rot):
    """A catalog rotation (axis, degrees, origin) applied to a point;
    armorlib's _rot."""
    axis, deg, o = rot
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    x, y, z = p[0] - o[0], p[1] - o[1], p[2] - o[2]
    if axis == "z":
        x, y = x * c - y * s, x * s + y * c
    elif axis == "x":
        y, z = y * c - z * s, y * s + z * c
    elif axis == "y":
        x, z = x * c + z * s, -x * s + z * c
    return (x + o[0], y + o[1], z + o[2])


def to_model(p):
    """Catalog (skin px, the character's right at -x) -> model units, the
    character's right at +x (armor-format.md §1)."""
    return (-PX * p[0], PX * p[1], PX * p[2])


def instances(box):
    """[(bone, mirrored)] of a catalog box: the box itself and, when mirrored,
    its left copy on the `_l` bone (Body for a Body box)."""
    out = [(box["bone"], False)]
    if box["mirror"]:
        out.append(("body" if box["bone"] == "body" else box["bone"].replace("_r", "_l"), True))
    return out


def placed(box, mirrored, p):
    """A catalog point of a box (local, unrotated) where the instance puts it,
    in model units."""
    if box.get("rot"):
        p = rotate_about(p, box["rot"])
    if mirrored:
        p = (-p[0], p[1], p[2])
    return to_model(p)


def placed_direction(box, mirrored, n):
    if box.get("rot"):
        n = rotate_about(n, (box["rot"][0], box["rot"][1], (0, 0, 0)))
    if mirrored:
        n = (-n[0], n[1], n[2])
    return (-n[0], n[1], n[2])


def box_corners(box, mirrored, coords=None):
    """The 8 corners of a placed box in the BOX_CORNERS order (bit 1 = x1,
    2 = y1, 4 = z1 of its own unrotated box), model units."""
    x0, y0, z0, x1, y1, z1 = coords or box["box"]
    return [placed(box, mirrored, c) for c in corners_of(x0, x1, y0, y1, z0, z1)]


def catalog():
    cat = json.loads(CATALOG.read_text())
    atlas = json.loads(ATLAS.read_text())
    return cat, atlas


def armor_geometry(box_ids):
    """The armor buffer: per catalog box (catalog order) and instance, six
    faces of 4 vertices with their own normals and the atlas UVs of the
    box's sheet. Returns (verts, tris, bones) with bones[i] the catalog
    bone of vertex i."""
    cat, atlas = catalog()
    aw, ah = atlas["size"]
    verts, tris, bones = [], [], []
    for box in cat["boxes"]:
        if box["id"] not in box_ids:
            continue
        rects = atlas["boxes"][box["id"]]["faces"]
        for bone, mirrored in instances(box):
            for face in FACES:
                rx, ry, rw, rh = rects[face]
                normal = placed_direction(box, mirrored, FACE_NORMAL[face])
                base = len(verts)
                for u, v in ((0, 0), (1, 0), (1, 1), (0, 1)):
                    verts.append((placed(box, mirrored, face_point(box["box"], face, u, v)),
                                  normal, ((rx + u * rw) / aw, (ry + v * rh) / ah)))
                    bones.append(bone)
                # face_point goes clockwise seen from outside in the catalog's
                # right-handed frame, so (0,1,2) faces inward there. Every x
                # flip turns that over: to_model flips once, the mirrored
                # copy once more.
                order = ((0, 1, 2), (0, 2, 3)) if not mirrored else ((0, 2, 1), (0, 3, 2))
                for tri in order:
                    p = [verts[base + i][0] for i in tri]
                    n = cross(tuple(p[1][k] - p[0][k] for k in range(3)),
                              tuple(p[2][k] - p[0][k] for k in range(3)))
                    if dot(n, normal) <= 0:
                        raise SystemExit("gen_cloak_model: inward triangle on %s %s" % (box["id"], face))
                    tris.append(tuple(base + i for i in tri))
    return verts, tris, bones


def wield_numbers():
    """SIZE, TILT_UP, HAND, GRIP_U/V and SPRITE_PIXELS from
    wield_geometry.lua, the one source of the hand's numbers."""
    text = WIELD.read_text()

    def num(pattern):
        m = re.search(pattern, text, re.M)
        if not m:
            raise SystemExit("gen_cloak_model: wield_geometry.lua has no %s" % pattern)
        return [float(g) for g in m.groups()]
    return {
        "size": num(r"^local SIZE = ([\d.]+)")[0],
        "tilt": num(r"^local TILT_UP = (-?[\d.]+)")[0],
        "hand": num(r"^local HAND = \{x = (-?[\d.]+), y = (-?[\d.]+), z = (-?[\d.]+)\}"),
        "grip": num(r"^local GRIP_U, GRIP_V = ([\d.]+), ([\d.]+)"),
        "pixels": num(r"^local SPRITE_PIXELS = (\d+)")[0],
    }


def euler_matrix(x, y, z):
    """set_attach's rotation, Rz(z) * Ry(y) * Rx(x) in degrees, right-handed
    about the bone's axes (wield_geometry.lua section 7), as rows."""
    def rx(a):
        c, s = math.cos(a), math.sin(a)
        return ((1, 0, 0), (0, c, -s), (0, s, c))

    def ry(a):
        c, s = math.cos(a), math.sin(a)
        return ((c, 0, s), (0, 1, 0), (-s, 0, c))

    def rz(a):
        c, s = math.cos(a), math.sin(a)
        return ((c, -s, 0), (s, c, 0), (0, 0, 1))

    def mm(a, b):
        return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))
    return mm(rz(math.radians(z)), mm(ry(math.radians(y)), rx(math.radians(x))))


def card_geometry(rig):
    """The weapon card: the 16x16 sprite square of the world wield entity at
    stature 1 in the diagonal tool pose (wield_geometry.lua wield_transform(1,
    "tool")), two triangle pairs facing each way, each CARD_GAP off the plane
    to its own side so a viewer without back-face culling (model[]) shows
    the side facing it. Image u runs along the entity's +x, image v along -y
    (wieldmesh.cpp createExtrusionMesh); the fist grips image pixel (GRIP_U,
    GRIP_V), so a corner is HAND + R * (corner - GRIP) in the bone's frame.
    Returns (verts, tris) in model units."""
    w = wield_numbers()
    edge = 40 * w["size"] / 2
    grip = ((w["grip"][0] / w["pixels"] - 0.5) * edge, (0.5 - w["grip"][1] / w["pixels"]) * edge, 0.0)
    rot = euler_matrix(90, -(45 + w["tilt"]), 90)
    bone = mul(rig.bind("Body"), local_matrix(*node_bind(rig.chunk["Arm_Right"])))

    def to_bone_model(p):
        q = tuple(p[k] - grip[k] for k in range(3))
        local = tuple(w["hand"][i] + sum(rot[i][k] * q[k] for k in range(3)) for i in range(3))
        return apply(bone, local)
    normal = turn(bone, tuple(rot[i][2] for i in range(3)))
    half = edge / 2
    # image corners (u, v) -> entity (x, y): u along +x, v along -y
    corners = [((u - 0.5) * 2 * half, (0.5 - v) * 2 * half, (u, v))
               for u, v in ((0, 0), (1, 0), (1, 1), (0, 1))]
    verts, tris = [], []
    for side in (1, -1):
        n = tuple(side * c for c in normal)
        base = len(verts)
        for x, y, uv in corners:
            p = to_bone_model((x, y, 0.0))
            verts.append((tuple(p[k] + CARD_GAP * n[k] for k in range(3)), n, uv))
        # (0,1,2) runs clockwise seen from the entity's +z, so it faces -z;
        # a rotation keeps that, so the front (+z) pair winds the other way.
        order = ((0, 2, 1), (0, 3, 2)) if side == 1 else ((0, 1, 2), (0, 2, 3))
        for tri in order:
            p = [verts[base + i][0] for i in tri]
            c = cross(tuple(p[1][k] - p[0][k] for k in range(3)),
                      tuple(p[2][k] - p[0][k] for k in range(3)))
            if dot(c, n) <= 0:
                raise SystemExit("gen_cloak_model: inward weapon card triangle")
            tris.append(tuple(base + i for i in tri))
    return verts, tris


def check_source_winding(vrts, tris_chunk):
    """The convention every appended buffer follows, read off the source:
    cross(v1-v0, v2-v0) points along the vertex normal (outward)."""
    count = len(tris_chunk.raw[4:]) // 12
    for i in range(count):
        tri = struct.unpack_from("<3i", tris_chunk.raw, 4 + 12 * i)
        p = [struct.unpack_from("<8f", vrts.raw, 12 + 32 * v) for v in tri]
        c = cross(tuple(p[1][k] - p[0][k] for k in range(3)), tuple(p[2][k] - p[0][k] for k in range(3)))
        if dot(c, p[0][3:6]) <= 0:
            raise SystemExit("gen_cloak_model: the source does not wind outward")


def append_buffer(mesh, vrts, verts, tris, after):
    """Append vertices to the one VRTS and their triangles as a new TRIS chunk
    (a new mesh buffer, i.e. the model's next material and texture --
    CB3DMeshFileLoader: one buffer per TRIS chunk, its texture slot its
    index) right after the TRIS chunk `after`. Returns (first vertex, the
    new chunk)."""
    first = (len(vrts.raw) - 12) // 32
    vrts.raw += b"".join(struct.pack("<8f", *pos, *normal, *uv) for pos, normal, uv in verts)
    chunk = Chunk("TRIS", raw=struct.pack("<i", 0) + b"".join(
        struct.pack("<3i", *(first + i for i in t)) for t in tris))
    mesh.kids.insert(mesh.kids.index(after) + 1, chunk)
    return first, chunk


def swing_bone(name, pivot, body, first, count, curve, sign):
    """A bone under Body hinged at `pivot` (model units), identity rotation,
    weight 1 on `count` vertices from `first`, and one key per file frame:
    a rotation about the bone's x by sign * curve[frame] degrees. Under
    Body's half turn about y that axis is model -x, so a positive angle lifts
    the hem to -z (backwards) -- asserted by the clearance pass."""
    local_pivot = apply(inverse_rigid(local_matrix(*node_bind(body))), pivot)
    bone = struct.pack("<10f", *local_pivot, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
    weights = b"".join(struct.pack("<if", first + i, 1.0) for i in range(count))
    keys = []
    for file_frame in range(1, len(curve) + 1):
        half = math.radians(sign * curve[file_frame - 1]) / 2
        keys.append(struct.pack("<i10f", file_frame, *local_pivot, 1.0, 1.0, 1.0,
                                math.cos(half), math.sin(half), 0.0, 0.0))
    return Chunk("NODE", name.encode() + b"\0" + bone, [
        Chunk("BONE", raw=weights),
        Chunk("KEYS", raw=struct.pack("<i", 7) + b"".join(keys)),
    ])


# --- Round 55: the offhand parts in the model -------------------------------------
def offhand_contract():
    """(params, atlas) of the contract: params.json validated, data/atlas.json
    current (offhand.py --check's two conditions)."""
    try:
        params = oh.load()
    except oh.ContractError as e:
        raise SystemExit("gen_cloak_model: %s" % e)
    atlas = json.loads(oh.ATLAS.read_text())
    if atlas != json.loads(json.dumps(oh.pack(params))):
        raise SystemExit("gen_cloak_model: tools/r55_offhand/data/atlas.json is stale "
                         "(python3 tools/r55_offhand/offhand.py --check)")
    return params, atlas


def model_part(part):
    """An offhand_model Part (catalog frame) as model vertices and triangles:
    to_model flips x, so every triangle turns over; asserted outward."""
    verts = [(to_model(p), (-n[0], n[1], n[2]), uv) for p, n, uv in part.verts]
    tris = []
    for a, b, c in part.tris:
        p = [verts[i][0] for i in (a, c, b)]
        n = cross(tuple(p[1][k] - p[0][k] for k in range(3)), tuple(p[2][k] - p[0][k] for k in range(3)))
        if dot(n, verts[a][1]) <= 0:
            raise SystemExit("gen_cloak_model: inward triangle on %s" % part.labels[a])
        tris.append((a, c, b))
    return verts, tris


def rotation(m):
    """The 3x3 rotation (rows) of a column-major 4x4."""
    return tuple(tuple(m[4 * c + r] for c in range(3)) for r in range(3))


def flip(r):
    """A catalog rotation as a model rotation: F * R * F, F = diag(-1, 1, 1)."""
    f = (-1, 1, 1)
    return tuple(tuple(f[i] * r[i][j] * f[j] for j in range(3)) for i in range(3))


def file_quat(r):
    """The KEYS/NODE quaternion (w, x, y, z) whose quat_matrix is the model
    rotation r: Irrlicht's matrix is the standard one of the conjugate."""
    w, x, y, z = om.quat_from_matrix(r)
    return (w, -x, -y, -z)


def clip_ranges(kind, layout):
    """[(name, first, last, period)] of every clip the model plays: player_api's
    ranges loop over last - first frames (the engine wraps there, AnimSpec),
    a held pose clip too (its last frame repeats its first), a one-shot holds
    its last key (period None)."""
    out = [(name, a, b, b - a) for name, (a, b) in BASE_RANGES]
    if kind == "player":
        out += [(c["name"], c["first"], c["last"], None if c["once"] else c["last"] - c["first"])
                for c in layout]
    return out


def arm_motion(rig, frame):
    """A_f: Arm_Left's rotation relative to Body at an engine frame, from rest
    (model frame), as a standard quaternion."""
    body = rotation(rig.skin("Body", frame + 1))
    arm = rotation(rig.skin("Arm_Left", frame + 1))
    return om.quat_from_matrix(om.mat_mul(om.transpose(body), arm))


def offhand_pose(params, bone, entry, i, period, arm_q=None, mean=None):
    """The model-space rest transform of an offhand bone's key at clip frame i:
    (pivot + t, R) with an item point v going to pivot + t + R (v - pivot)
    before the arm carries it (format doc §2.3). With steadiness the rotation
    is A_f^-1 * slerp(A_f, mean, s) * R, so the item turns as
    Body_f * slerp(A_f, mean, s) * R while its pivot still follows the arm."""
    rot, pos = om.entry_at(entry, i, period)
    r = flip(oh.euler(rot, entry["order"]))
    s = entry.get("steady", 0)
    if s:
        r = om.mat_mul(om.transpose(om.quat_matrix(arm_q)),
                       om.mat_mul(om.quat_matrix(om.slerp(arm_q, mean, s)), r))
    pivot = to_model(params["bones"][bone]["pivot"])
    return om.add(pivot, to_model(pos)), r


def offhand_keys(rig, kind, layout, params, bone, frame_count):
    """(pivot in Arm_Left's frame, [(position, file quaternion)] per engine
    frame) of an offhand bone: identity where no clip entry applies."""
    arm_bind = rig.bind("Arm_Left")
    rb = rotation(arm_bind)
    pivot_local = apply(inverse_rigid(arm_bind), to_model(params["bones"][bone]["pivot"]))
    keys = [(pivot_local, (1.0, 0.0, 0.0, 0.0))] * frame_count
    for name, first, last, period in clip_ranges(kind, layout):
        entry = params["bones"][bone]["clips"].get(name)
        if not entry:
            continue
        arm_q = mean = None
        if entry.get("steady", 0):
            arm_q = {f: arm_motion(rig, f) for f in range(first, last + 1)}
            mean = om.quat_mean([arm_q[f] for f in range(first, last + 1)])
        for f in range(first, last + 1):
            at, r = offhand_pose(params, bone, entry, f - first, period, arm_q and arm_q[f], mean)
            # into Arm_Left's frame: L = G_bind^-1 * M * G_bind, with M the
            # model-space transform above and G_bind the arm's bind
            local_r = om.mat_mul(om.transpose(rb), om.mat_mul(r, rb))
            local_at = apply(inverse_rigid(arm_bind), at)
            keys[f] = (local_at, file_quat(local_r))
    return pivot_local, keys


def offhand_bone(name, pivot_local, keys, ids):
    """A NODE under Arm_Left: bind at the pivot with no turn, weight 1 on
    `ids`, one key per file frame."""
    bone = struct.pack("<10f", *pivot_local, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0)
    weights = b"".join(struct.pack("<if", i, 1.0) for i in ids)
    rows = b"".join(struct.pack("<i10f", f + 1, *pos, 1.0, 1.0, 1.0, *q) for f, (pos, q) in enumerate(keys))
    return Chunk("NODE", name.encode() + b"\0" + bone, [
        Chunk("BONE", raw=weights),
        Chunk("KEYS", raw=struct.pack("<i", 7) + rows),
    ])


def offhand_bone_of(params, label):
    """The bone an offhand vertex rides: its item's placement bone."""
    return params["shield" if label.startswith("shield_") else "book"]["place"]["bone"]


def build(kind="player", contract=None):
    """One model: "player" (skin, cloak, armor, weapon, offhand, back, wings;
    the pose clips) or "npc" (skin, armor, weapon, offhand, back; player_api's
    frames only). `contract` = (params, atlas) of the offhand, default the
    committed ones. Returns the bytes and what the checks need."""
    params, oatlas = contract or offhand_contract()
    data = SOURCE.read_bytes()
    root = parse(data, 0, len(data))
    player = find_node(root, "Player")
    body = find_node(root, "Body")
    legs = {name: node_keys(find_node(root, name)) for name in ("Leg_Left", "Leg_Right")}
    mesh = kid(player, "MESH")
    vrts = kid(mesh, "VRTS")
    flags, sets, size = struct.unpack("<3i", vrts.raw[:12])
    assert (flags, sets, size) == (1, 1, 2), "expected normals + one UV set"
    skin_tris = kid(mesh, "TRIS")
    check_source_winding(vrts, skin_tris)
    if len(node_keys(body)) != FIRST_POSE_FRAME:
        raise SystemExit("gen_cloak_model: the source has %d frames, the poses start at %d"
                         % (len(node_keys(body)), FIRST_POSE_FRAME))

    layout = []
    if kind == "player":
        # The pose clips: every source bone's keys appended after its own, one
        # per engine frame (file frame = engine frame + 1), exactly as poses.json
        # holds them; the source's keys stay as they are.
        layout, pose_bones = pose_layout()
        # poses.json also bakes the cloak (the preview page's base clip); the
        # generator keys the cloak by its own rule, so only the source's bones.
        source_bones = [b for b in pose_bones if find_node(root, b) is not None]
        for name in source_bones:
            chunk = kid(find_node(root, name), "KEYS")
            rows = []
            for clip in layout:
                for i, row in enumerate(clip["pose"]["clips"][clip["base"]]["keys"][name]):
                    rows.append(struct.pack("<i10f", clip["first"] + i + 1, *row[0:3],
                                            1.0, 1.0, 1.0, *row[3:7]))
            chunk.raw += b"".join(rows)
        if len(node_keys(body)) != layout[-1]["last"] + 1:
            raise SystemExit("gen_cloak_model: the pose clips are not contiguous")
        # ANIM's frame count is not read by the engine (CB3DMeshFileLoader::
        # readChunkANIM); kept as the source has it, the last engine frame.
        anim = kid(player, "ANIM")
        anim_flags, _, anim_fps = struct.unpack("<iif", anim.raw)
        anim.raw = struct.pack("<iif", anim_flags, len(node_keys(body)) - 1, anim_fps)
    frame_count = len(node_keys(body))
    rig = Rig(root)

    # The swing curves, per engine frame: the panels from the legs, the cloak
    # from its own rule and never below the back panel.
    twist, cloak_rule, twisted_walk = {}, {}, set()
    for clip in layout:
        for i in range(clip["last"] - clip["first"] + 1):
            twist[clip["first"] + i] = pose_twist(clip, i)
            if clip["base"] == "walk" and twist[clip["first"] + i] > 0:
                twisted_walk.add(clip["first"] + i)
            cloak_rule[clip["first"] + i] = pose_swing(clip, i, legs["Leg_Left"])
    front, back, cloak = [], [], []
    for frame in range(frame_count):
        f, b = panel_swing(rig, frame, twist.get(frame, 0.0))
        front.append(f)
        back.append(b)
        rule = cloak_rule.get(frame)
        cloak.append(max(swing(frame, legs["Leg_Left"]) if rule is None else rule, b))

    buffers = {"skin": (168, len(skin_tris.raw[4:]) // 12)}
    labels = []          # the box of every appended vertex
    last = skin_tris
    if kind == "player":
        verts, tris = cloak_geometry()
        first, last = append_buffer(mesh, vrts, verts, tris, last)
        body.kids.append(swing_bone("Cloak", PIVOT, body, first, len(verts), cloak, 1))
        buffers["cloak"] = (len(verts), len(tris))
        labels += ["cloak"] * len(verts)

    # The armor buffer: rigid boxes join their bone's BONE chunk with weight
    # 1; the two panels get their swing bones.
    box_ids = NPC_BOXES if kind == "npc" else tuple(b["id"] for b in catalog()[0]["boxes"])
    verts, tris, bones = armor_geometry(box_ids)
    first, last = append_buffer(mesh, vrts, verts, tris, last)
    buffers["armor"] = (len(verts), len(tris))
    cat = catalog()[0]
    for box in cat["boxes"]:
        if box["id"] in box_ids:
            for _, mirrored in instances(box):
                labels += [box["id"] + ("_l" if mirrored else "")] * 24
    for bone in ("body", "head", "arm_r", "arm_l", "leg_r", "leg_l"):
        weights = b"".join(struct.pack("<if", first + i, 1.0) for i, b in enumerate(bones) if b == bone)
        if weights:
            chunk = kid(find_node(root, BONE_NODE[bone]), "BONE")
            chunk.raw += weights
    for bone, sign, curve in (("panel_f", -1, front), ("panel_b", 1, back)):
        at = [i for i, b in enumerate(bones) if b == bone]
        if not at:
            continue
        if at != list(range(at[0], at[-1] + 1)):
            raise SystemExit("gen_cloak_model: %s vertices are not contiguous" % bone)
        pivot = to_model(cat["bones"][bone])
        body.kids.append(swing_bone(BONE_NODE[bone], pivot, body, first + at[0], len(at), curve, sign))

    verts, tris = card_geometry(rig)
    first, last = append_buffer(mesh, vrts, verts, tris, last)
    chunk = kid(find_node(root, "Arm_Right"), "BONE")
    chunk.raw += b"".join(struct.pack("<if", first + i, 1.0) for i in range(len(verts)))
    buffers["weapon"] = (len(verts), len(tris))
    labels += ["weapon"] * len(verts)

    # Round 55: the offhand buffer (three shield copies and the book) on the
    # two offhand bones under Arm_Left, keyed in every frame.
    parts = {}
    part = om.Part()
    for step in range(len(params["shield"]["sizes"])):
        part.extend(om.shield_copy(params, oatlas, step))
    part.extend(om.book(params, oatlas, face_point))
    verts, tris = model_part(part)
    first, last = append_buffer(mesh, vrts, verts, tris, last)
    buffers["offhand"] = (len(verts), len(tris))
    labels += part.labels
    parts["offhand"] = (first, part)
    arm = find_node(root, "Arm_Left")
    for name in OFFHAND_BONES:
        ids = [first + i for i, label in enumerate(part.labels) if offhand_bone_of(params, label) == name]
        pivot_local, keys = offhand_keys(rig, kind, layout, params, name, frame_count)
        arm.kids.append(offhand_bone(name, pivot_local, keys, ids))
    # the back cards: the cloak card on the Cloak, the body card on Body (the
    # NPC model has no cloak: the body card only)
    part = om.Part()
    for card in (("cloak", "body") if kind == "player" else ("body",)):
        part.extend(om.back_card(params, CARD_GAP / PX, card))
    verts, tris = model_part(part)
    first, last = append_buffer(mesh, vrts, verts, tris, last)
    for card, bone in oh.BACK_CARDS.items():
        if "back_" + card not in part.labels:
            continue
        kid(find_node(root, bone), "BONE").raw += b"".join(
            struct.pack("<if", first + i, 1.0) for i, label in enumerate(part.labels) if label == "back_" + card)
    buffers["back"] = (len(verts), len(tris))
    labels += part.labels
    parts["back"] = (first, part)
    if kind == "player":
        # the wings, hinged on the cloak's sides
        part = om.wings(params, HALF_W / PX, (Z_IN + Z_OUT) / 2 / PX, (TOP - LENGTH) / PX, TOP / PX)
        verts, tris = model_part(part)
        first, last = append_buffer(mesh, vrts, verts, tris, last)
        kid(find_node(root, "Cloak"), "BONE").raw += b"".join(
            struct.pack("<if", first + i, 1.0) for i in range(len(verts)))
        buffers["wings"] = (len(verts), len(tris))
        labels += part.labels
        parts["wings"] = (first, part)

    out = b"".join(chunk.encode() for chunk in root)
    curves = {"front": front, "back": back}
    if kind == "player":
        curves["cloak"] = cloak
    return out, {"kind": kind, "root": root, "curves": curves, "layout": layout,
                 "buffers": buffers, "box_ids": box_ids, "twisted_walk": twisted_walk,
                 "labels": labels, "params": params, "parts": parts}


# --- the checks on a built model -------------------------------------------------
def collision_boxes(box_ids):
    """Catalog boxes as {bone node: [(label, 8 corners in model units)]},
    the body's own boxes (catalog `body`) included."""
    cat, _ = catalog()
    out = {}
    for b in cat["body"]:
        for bone, mirrored in instances(b):
            out.setdefault(BONE_NODE[bone], []).append(
                (b["id"] + ("_l" if mirrored else ""), box_corners(b, mirrored)))
    for b in cat["boxes"]:
        if b["id"] not in box_ids:
            continue
        for bone, mirrored in instances(b):
            out.setdefault(BONE_NODE[bone], []).append(
                (b["id"] + ("_l" if mirrored else ""), box_corners(b, mirrored)))
    return out


def cloak_corners():
    return corners_of(-HALF_W, HALF_W, TOP - LENGTH, TOP, Z_OUT, Z_IN)


def check_clearance(info):
    """Every frame: the cloak and the panels must stay clear of both legs
    (the bare legs and every leg armor box) and of the body's boxes, and a
    positive swing must move each hem away from the body. Two documented
    exceptions: the seated front panel (panel_swing) and a panel's top
    corner in a twisting walking pose clip, which may overlap a leg by
    TWIST_WALK_OVERLAP. Returns per frame the closest gaps {cloak, front,
    back, cloak_back} (model units, negative for a tolerated overlap; the
    cloak must clear the back panel, hanging behind it) and the sit
    range's lowest cloak hem."""
    rig = Rig(info["root"])
    boxes = collision_boxes(info["box_ids"])
    legs = [(name, label, c) for name in ("Leg_Right", "Leg_Left") for label, c in boxes[name]]
    torso = [("Body", label, c) for label, c in boxes["Body"]
             if label not in ("panel_f", "panel_b")]
    movers = {"front": ("Panel_Front", boxes["Panel_Front"][0][1], 1),
              "back": ("Panel_Back", boxes["Panel_Back"][0][1], -1)}
    if "cloak" in info["curves"]:
        movers["cloak"] = ("Cloak", cloak_corners(), -1)
    gaps, sit_low = [], None
    frames = len(info["curves"]["front"])
    for frame in range(frames):
        file_frame = frame + 1
        body_rest = mul(rig.bind("Body"), inverse_rigid(rig.at("Body", file_frame)))
        placed_now = {}
        row = {}
        for key, (bone, corners, away) in movers.items():
            skin = rig.skin(bone, file_frame)
            now = [apply(skin, p) for p in corners]
            placed_now[key] = now
            angle = info["curves"][key][frame]
            # The hem's middle, seen from the body's own frame: forward for
            # the front panel, backward for the back panel and the cloak.
            hem = tuple(sum(c[k] for c in corners[:2]) / 2 for k in range(3))
            moved = apply(mul(body_rest, skin), hem)
            if angle > 1 and not (moved[2] - hem[2]) * away > 0:
                raise SystemExit("gen_cloak_model: a positive %s swing does not move the hem away "
                                 "from the body (frame %d)" % (key, frame))
            closest = None
            for name, label, c in legs + torso:
                if key == "front" and name != "Body" and SEATED[0] <= frame <= SEATED[1]:
                    continue  # panel_swing: no front panel angle clears seated thighs
                if key == "cloak" and name == "Body" and label not in ("torso",):
                    continue  # the cloak lies over the back: only the bare torso is checked
                other = [apply(rig.skin(name, file_frame), p) for p in c]
                g = gap(now, other)
                allowed = 0.0
                if key != "cloak" and name != "Body" and frame in info["twisted_walk"]:
                    allowed = -TWIST_WALK_OVERLAP
                if g <= allowed:
                    raise SystemExit("gen_cloak_model: %s meets %s %s at frame %d (swing %.1f)"
                                     % (key, name, label, frame, angle))
                if name != "Body":
                    closest = g if closest is None else min(closest, g)
            row[key] = closest
        if "cloak" in placed_now:
            row["cloak_back"] = gap(placed_now["cloak"], placed_now["back"])
            if row["cloak_back"] <= 0:
                raise SystemExit("gen_cloak_model: the cloak meets the back panel at frame %d "
                                 "(cloak %.1f, back panel %.1f)" % (
                                     frame, info["curves"]["cloak"][frame], info["curves"]["back"][frame]))
            if SIT_R[0] <= frame <= SIT_R[1]:
                low = min(p[1] for p in placed_now["cloak"])
                sit_low = low if sit_low is None else min(sit_low, low)
        gaps.append(row)
    return gaps, sit_low


def vertex_labels(root):
    """The box each vertex belongs to, for messages and KNOWN_ZFIGHT: the
    source body by bone (the Head bone's outer layer is the `hat`), then the
    appended buffers in order (cloak, the catalog boxes with `_l` for a
    left copy, the weapon card)."""
    rig = Rig(root)
    vrts = kid(kid(find_node(root, "Player"), "MESH"), "VRTS")
    count = (len(vrts.raw) - 12) // 32
    raw = [struct.unpack_from("<8f", vrts.raw, 12 + 32 * i) for i in range(count)]
    bone_of = {}
    for name, chunk in rig.chunk.items():
        for k in chunk.kids:
            if k.tag == "BONE":
                for i in range(len(k.raw) // 8):
                    vid, w = struct.unpack_from("<if", k.raw, 8 * i)
                    if w > 0:
                        bone_of[vid] = name
    body = {"Body": "torso", "Arm_Right": "arm", "Arm_Left": "arm_l", "Leg_Right": "leg",
            "Leg_Left": "leg_l"}
    labels = []
    for i in range(168):
        if bone_of[i] == "Head":
            x, y, z = raw[i][0:3]
            labels.append("hat" if max(abs(x), abs(z)) > 2.2 or not 12.5 < y < 16.9 else "head")
        else:
            labels.append(body[bone_of[i]])
    return labels, raw, bone_of


def rest_triangles(info):
    """Every triangle of the model with its face normal and box label,
    skinned to engine frame 0 (the stand clip's first frame: the rigid bones
    at their bind, the swing bones at their rest angle)."""
    root = info["root"]
    rig = Rig(root)
    labels, raw, bone_of = vertex_labels(root)
    labels += info["labels"]
    pos = [apply(rig.skin(bone_of[i], 1), raw[i][0:3]) for i in range(len(raw))]
    mesh = kid(find_node(root, "Player"), "MESH")
    out = []
    for chunk in (k for k in mesh.kids if k.tag == "TRIS"):
        for i in range(len(chunk.raw[4:]) // 12):
            tri = struct.unpack_from("<3i", chunk.raw, 4 + 12 * i)
            p = [pos[v] for v in tri]
            n = cross(tuple(p[1][k] - p[0][k] for k in range(3)), tuple(p[2][k] - p[0][k] for k in range(3)))
            length = math.sqrt(dot(n, n))
            if length < 1e-9:
                continue
            out.append((labels[tri[0]], p, tuple(c / length for c in n)))
    return out


def zfight(info):
    """Pairs of boxes with same-facing triangles closer than ZFIGHT_GAP whose
    outlines overlap by at least ZFIGHT_MIN_EXTENT (a thinner sliver is
    below one texel), over all bones in the rest pose, in the model's own
    coordinates (the rotated boxes, the cloak and the card included).
    Returns {(label, label): (distance, overlap)} with the nearest pair."""
    tris = rest_triangles(info)
    found = {}
    for i, (la, pa, na) in enumerate(tris):
        for lb, pb, nb in tris[i + 1:]:
            if la == lb or dot(na, nb) < 0.9999:
                continue
            if exclusive(la) and exclusive(lb) and exclusive(la) != exclusive(lb):
                continue  # never shown together (round55-plan.md §3)
            distance = abs(dot(na, tuple(pb[0][k] - pa[0][k] for k in range(3))))
            if distance >= ZFIGHT_GAP - 1e-4:  # float32 positions
                continue
            # the outlines in na's plane; the overlap's narrowest extent over
            # the separating axes (the edge normals of both triangles)
            u = tuple(pa[1][k] - pa[0][k] for k in range(3))
            ulen = math.sqrt(dot(u, u))
            u = tuple(c / ulen for c in u)
            v = cross(na, u)
            a2 = [(dot(p, u), dot(p, v)) for p in pa]
            b2 = [(dot(p, u), dot(p, v)) for p in pb]
            extent = None
            for poly in (a2, b2):
                for j in range(3):
                    e = (poly[(j + 1) % 3][0] - poly[j][0], poly[(j + 1) % 3][1] - poly[j][1])
                    length = math.hypot(*e)
                    axis = (-e[1] / length, e[0] / length)
                    sa = [q[0] * axis[0] + q[1] * axis[1] for q in a2]
                    sb = [q[0] * axis[0] + q[1] * axis[1] for q in b2]
                    span = min(max(sa), max(sb)) - max(min(sa), min(sb))
                    extent = span if extent is None else min(extent, span)
            if extent >= ZFIGHT_MIN_EXTENT:
                key = tuple(sorted((la, lb)))
                if key not in found or distance < found[key][0]:
                    found[key] = (distance, extent)
    return found


def check_offhand(info):
    """The written offhand keys, read back through the engine's B3D maths
    (Rig), do what the format doc says (§2.3): at the first and the middle
    frame of every clip, each vertex of an offhand bone lies where Arm_Left
    carries pivot + t + R (v - pivot) (R with the steadiness folded in;
    identity without an entry). Returns the worst deviation (model units)."""
    rig = Rig(info["root"])
    params = info["params"]
    _, part = info["parts"]["offhand"]
    worst = 0.0
    for bone in OFFHAND_BONES:
        points = [to_model(part.verts[i][0]) for i, label in enumerate(part.labels)
                  if offhand_bone_of(params, label) == bone]
        if not points:
            continue
        pivot = to_model(params["bones"][bone]["pivot"])
        for name, first, last, period in clip_ranges(info["kind"], info["layout"]):
            entry = params["bones"][bone]["clips"].get(name)
            arm_q = mean = None
            if entry and entry.get("steady", 0):
                arm_q = {f: arm_motion(rig, f) for f in range(first, last + 1)}
                mean = om.quat_mean([arm_q[f] for f in range(first, last + 1)])
            for f in sorted({first, (first + last) // 2}):
                arm = rig.skin("Arm_Left", f + 1)
                skin = rig.skin(bone, f + 1)
                if entry:
                    at, r = offhand_pose(params, bone, entry, f - first, period, arm_q and arm_q[f], mean)
                else:
                    at, r = pivot, ((1, 0, 0), (0, 1, 0), (0, 0, 1))
                for v in points:
                    want = apply(arm, om.add(at, om.mat_vec(r, om.sub(v, pivot))))
                    got = apply(skin, v)
                    worst = max(worst, max(abs(a - b) for a, b in zip(want, got)))
    if worst > 1e-4:
        raise SystemExit("gen_cloak_model: the %s model's offhand keys move the items %.2g off the "
                         "format doc's rule" % (info["kind"], worst))
    return worst


# --- the offhand clearance (reported, not gated) ---------------------------------------
def convex_axes(points):
    """Face normals of the convex hull of a few points (brute force over
    triples) and the edge directions between them (crosses of face normal
    pairs): with a box's axes and edges, the separating-axis candidates."""
    normals = []
    n = len(points)
    for i in range(n):
        for j in range(i + 1, n):
            for k in range(j + 1, n):
                c = cross(om.sub(points[j], points[i]), om.sub(points[k], points[i]))
                length = math.sqrt(dot(c, c))
                if length < 1e-9:
                    continue
                c = om.scale(c, 1 / length)
                side = [dot(c, om.sub(p, points[i])) for p in points]
                if (max(side) <= 1e-6 or min(side) >= -1e-6) and \
                        not any(abs(dot(c, m)) > 1 - 1e-9 for m in normals):
                    normals.append(c)
    edges = []
    for a in range(len(normals)):
        for b in range(a + 1, len(normals)):
            e = cross(normals[a], normals[b])
            if dot(e, e) > 1e-12:
                edges.append(om.unit(e))
    return normals, edges


def sat_gap(pa, pb, axes):
    """The widest separation of two convex point sets along the axes
    (negative: the smallest overlap), as gap() does for two boxes."""
    best = None
    for axis in axes:
        sa = [dot(p, axis) for p in pa]
        sb = [dot(p, axis) for p in pb]
        sep = max(min(sb) - max(sa), min(sa) - max(sb))
        best = sep if best is None else max(best, sep)
    return best


def offhand_clearance(info):
    """{item: {clip: (gap px, engine frame, box)}}: the closest distance of
    the offhand parts per clip (negative = overlap, a separating-axis lower
    bound as the cloak's leg gaps): each shield copy and the book against the
    body and every armor box; the body card against every box, the boxes on
    the torso and the back panel ("torso") and the swinging cloak; the cloak
    card against the cloak it rides; the wings against the arms and the
    shoulder boxes."""
    rig = Rig(info["root"])
    params = info["params"]
    boxes = [(bone, label, c) for bone, rows in collision_boxes(info["box_ids"]).items() for label, c in rows]
    if info["kind"] == "player":
        boxes.append(("Cloak", "cloak", cloak_corners()))
    shoulder = {"arm", "sleeve", "bracer", "pauldron", "reinforce", "flare", "spike"}
    targets = {"all": [b for b in boxes if b[1] != "cloak"], "cloak": [b for b in boxes if b[1] == "cloak"],
               "arms": [b for b in boxes if b[1].replace("_l", "") in shoulder],
               "torso": [b for b in boxes if b[0] in ("Body", "Panel_Back")]}
    items = []      # (item, target set, bone, points, axes)
    for name, (_, part) in info["parts"].items():
        for piece in part.pieces:
            label = part.labels[piece[0]]
            if name == "offhand":
                item, bone, against = (label if label.startswith("shield_") else "book",
                                       offhand_bone_of(params, label), ("all",))
            elif name == "back" and label == "back_body":
                item, bone, against = "back_body", "Body", ("all", "torso", "cloak")
            elif name == "back":
                item, bone, against = "back_cloak", "Cloak", ("cloak",)
            else:
                item, bone, against = "wings", "Cloak", ("arms",)
            points = [to_model(part.verts[i][0]) for i in piece]
            normals, edges = convex_axes(points)
            for which in against:
                tag = item if which in ("all", "arms") or item == "back_cloak" else item + "/" + which
                items.append((tag, which, bone, points, normals, edges))
    box_axes_rest = {id(c): box_axes(c) for _, _, c in boxes}
    out = {}
    for name, first, last, _ in clip_ranges(info["kind"], info["layout"]):
        for f in range(first, last + 1):
            skins = {}

            def skin(bone):
                if bone not in skins:
                    skins[bone] = rig.skin(bone, f + 1)
                return skins[bone]
            placed_boxes = {}
            for item, which, bone, points, normals, edges in items:
                if not targets[which]:
                    continue
                m = skin(bone)
                pa = [apply(m, p) for p in points]
                na = [turn(m, n) for n in normals]
                ea = [turn(m, e) for e in edges]
                ca = tuple(sum(p[k] for p in pa) / len(pa) for k in range(3))
                ra = max(math.dist(p, ca) for p in pa)
                order = []
                for bone_b, label, corners in targets[which]:
                    key = (bone_b, label)
                    if key not in placed_boxes:
                        mb = skin(bone_b)
                        pb = [apply(mb, p) for p in corners]
                        cb = tuple(sum(p[k] for p in pb) / 8 for k in range(3))
                        axes_b = [om.unit(turn(mb, a)) for a in box_axes_rest[id(corners)]]
                        placed_boxes[key] = (pb, cb, max(math.dist(p, cb) for p in pb), axes_b)
                    pb, cb, rb, axes_b = placed_boxes[key]
                    order.append((math.dist(ca, cb) - ra - rb, label, pb, axes_b))
                order.sort(key=lambda row: row[0])
                best = out.setdefault(item, {}).get(name)
                for bound, label, pb, axes_b in order:
                    if best is not None and bound > best[0] * PX:
                        break
                    axes = na + axes_b + [cross(a, e) for a in axes_b for e in ea]
                    axes = [om.unit(a) for a in axes if dot(a, a) > 1e-12]
                    g = sat_gap(pa, pb, axes) / PX
                    if best is None or g < best[0]:
                        best = (g, f, label)
                out[item][name] = best
    return out


def frame_name(frame, layout):
    for name, (a, b) in BASE_RANGES:
        if a <= frame <= b:
            return name
    for clip in layout:
        if clip["first"] <= frame <= clip["last"]:
            return clip["name"]
    return None


def report(info, gaps):
    kind = info["kind"]
    total_v = sum(v for v, _ in info["buffers"].values())
    total_t = sum(t for _, t in info["buffers"].values())
    print("%s model: %s; total %d vertices, %d triangles" % (
        kind, ", ".join("%s %d v / %d t" % (name, v, t) for name, (v, t) in info["buffers"].items()),
        total_v, total_t))
    ranges = list(BASE_RANGES) + [(c["name"], (c["first"], c["last"])) for c in info["layout"]]
    keys = [k for k in ("front", "back", "cloak") if k in info["curves"]]
    print("  %-12s %-9s %s  closest leg gap (model units) %s" % (
        "clip", "frames", "  ".join("%-11s" % (k + " deg") for k in keys),
        "  ".join(keys + (["cloak/back panel"] if "cloak" in keys else []))))
    for name, (a, b) in ranges:
        span = range(a, b + 1)
        swings = "  ".join("%4.1f-%5.1f  " % (min(info["curves"][k][f] for f in span),
                                               max(info["curves"][k][f] for f in span)) for k in keys)
        closest = []
        for k in keys:
            values = [gaps[f][k] for f in span if gaps[f][k] is not None]
            closest.append("%5.2f" % min(values) if values else "  -  ")
        if "cloak" in keys:
            closest.append("%5.2f" % min(gaps[f]["cloak_back"] for f in span))
        print("  %-12s %3d-%3d   %s  %s" % (name, a, b, swings, "  ".join(closest)))


def stand_bounds(root):
    """The bounding box (min xyz, max xyz; model units) of every vertex at
    engine frame 0, hidden geometry included: what the engine's camera fit
    of a model[] element measures (the Character tab)."""
    rig = Rig(root)
    _, raw, bone_of = vertex_labels(root)
    pos = [apply(rig.skin(bone_of[i], 1), raw[i][0:3]) for i in range(len(raw))]
    return [min(p[k] for p in pos) for k in range(3)] + [max(p[k] for p in pos) for k in range(3)]


def wing_seam(info):
    """The wing against the cloak it rides (format doc §3.4), per checked
    engine frame (stand 0 and walk 178) in the cloak's own frame:
    `hinge`, how deep the wing's hinge edge lies inside the cloak's side
    face (px; positive = no gap between cloak and wing), and `faces`, the
    smallest margin of the wing inside the cloak's outer and lining faces
    over the part of the wing within the cloak's width (px; negative = it
    pokes through)."""
    rig = Rig(info["root"])
    _, part = info["parts"]["wings"]
    half = HALF_W
    out = {}
    for frame in (STAND[0], 178):
        inv = inverse_rigid(rig.skin("Cloak", frame + 1))
        hinge = faces = None
        for piece in part.pieces:
            # the wing's corners skinned to the frame, back in the cloak's rest frame
            pts = [apply(inv, apply(rig.skin("Cloak", frame + 1), to_model(part.verts[i][0]))) for i in piece]
            pts = [(abs(p[0]), p[1], p[2]) for p in pts]          # both wings as the left one
            corners = []
            for p in pts:
                if not any(math.dist(p, q) < 1e-9 for q in corners):
                    corners.append(p)
            inner = sorted(corners, key=lambda p: p[0])
            # the hinge edge: the corners nearest the cloak's centre line
            hinge_pts = [p for p in corners if p[0] <= inner[3][0] + 1e-9][:4]
            depth = min(half - p[0] for p in hinge_pts)
            hinge = depth if hinge is None else min(hinge, depth)
            # the wing within the cloak's width: corners inside plus edge crossings
            inside = [p for p in corners if p[0] <= half]
            for a in range(len(corners)):
                for b in range(a + 1, len(corners)):
                    p, q = corners[a], corners[b]
                    if (p[0] - half) * (q[0] - half) < 0:
                        t = (half - p[0]) / (q[0] - p[0])
                        inside.append(tuple(p[k] + (q[k] - p[k]) * t for k in range(3)))
            margin = min(min(p[2] - Z_OUT, Z_IN - p[2]) for p in inside)
            faces = margin if faces is None else min(faces, margin)
        out[frame] = (hinge / PX, faces / PX)
    return out


def report_clearance(info):
    """The offhand clearance table: per clip and part the closest gap in skin
    pixels (negative = overlap), its engine frame and the box."""
    table = offhand_clearance(info)
    items = [k for k in ("shield_0", "shield_1", "shield_2", "book", "back_body", "back_body/torso",
                         "back_body/cloak", "back_cloak", "wings") if k in table]
    print("  offhand clearance (skin px, negative = overlap; gap@frame box):")
    print("  %-12s %s" % ("clip", "".join("%-22s" % k for k in items)))
    for name, _, _, _ in clip_ranges(info["kind"], info["layout"]):
        cells = []
        for k in items:
            g, f, label = table[k][name]
            cells.append("%-22s" % ("%6.2f@%d %s" % (g, f, label)))
        print("  %-12s %s" % (name, "".join(cells)))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--check", action="store_true",
                        help="compare with the shipped models, exit 1 if one differs")
    parser.add_argument("--report", action="store_true",
                        help="print buffer counts, each range's swings and closest leg gaps")
    args = parser.parse_args()
    built = {}
    status = 0
    for kind, target in (("player", TARGET), ("npc", NPC_TARGET)):
        out, info = build(kind)
        gaps, sit_low = check_clearance(info)
        check_offhand(info)
        found = zfight(info)
        for (a, b), (distance, extent) in sorted(found.items()):
            if (a, b) not in KNOWN_ZFIGHT:
                print("gen_cloak_model: %s model z-fight in the rest pose: %s / %s, %.3f apart "
                      "over %.3f (model units)" % (kind, a, b, distance, extent))
                status = 1
        built[kind] = (out, info, gaps, sit_low, target)
        if args.report:
            report(info, gaps)
            box = stand_bounds(info["root"])
            print("  stand frame 0 bounding box (model units): x %.3f..%.3f, y %.3f..%.3f, z %.3f..%.3f" % (
                box[0], box[3], box[1], box[4], box[2], box[5]))
            report_clearance(info)
            if "wings" in info["parts"]:
                print("  wings on the cloak: " + "; ".join(
                    "frame %d: hinge edge %.3f px inside the cloak's side, %.3f px inside its outer and "
                    "lining faces" % (f, h, m) for f, (h, m) in sorted(wing_seam(info).items())))
            print("  file %d bytes; z-fight in the rest pose: %s" % (len(out), ", ".join(
                "%s/%s %.3f apart over %.3f%s" % (a, b, d, e, " (known)" if (a, b) in KNOWN_ZFIGHT else "")
                for (a, b), (d, e) in sorted(found.items())) or "none"))
    layout = built["player"][1]["layout"]
    clips, registered = expected_clips(layout), registered_clips()
    if registered != clips:
        print("gen_cloak_model: grug_visuals/apply.lua POSE_CLIPS differ from the baked "
              "layout; they must read:\n" + clips_lua(clips))
        return 1
    if status:
        return status
    if args.check:
        for kind, (out, _, _, _, target) in built.items():
            if not target.exists() or target.read_bytes() != out:
                print("gen_cloak_model: %s is stale, re-run without --check" %
                      target.relative_to(REPO))
                status = 1
        if not status:
            print("gen_cloak_model: models up to date")
        return status
    for kind, (out, info, gaps, sit_low, target) in built.items():
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(out)
        curves = info["curves"]
        walk = range(WALK[0], WALK[1] + 1)
        line = ("gen_cloak_model: wrote %s (%d bytes); panels walk front %.1f-%.1f, back %.1f-%.1f"
                % (target.relative_to(REPO), len(out), min(curves["front"][f] for f in walk),
                   max(curves["front"][f] for f in walk), min(curves["back"][f] for f in walk),
                   max(curves["back"][f] for f in walk)))
        if "cloak" in curves:
            line += ("; cloak stand %.1f-%.1f, walk %.1f-%.1f, sit %.1f (hem at y %.2f), %d pose "
                     "ranges from frame %d" % (
                         min(curves["cloak"][STAND[0]:STAND[1] + 1]),
                         max(curves["cloak"][STAND[0]:STAND[1] + 1]),
                         min(curves["cloak"][f] for f in walk), max(curves["cloak"][f] for f in walk),
                         SIT, sit_low, len(layout), FIRST_POSE_FRAME))
        print(line + "; legs clear in all %d frames" % len(curves["front"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())

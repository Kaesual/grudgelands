#!/usr/bin/env python3
"""Round 40 V3: the particle effect proposals and their server cost.

Each effect is a list of emitters in the engine's own terms (a spawner or a
loop of single particles) with the parameters the page's sketch plays.
Coordinates in metres: the caster stands at the origin facing +x, a target
at TARGET unless an emitter says otherwise; y is up. Sizes are the engine's
`size` (1 = 0.1 m). `cost_model.py` turns the emitters into bytes and
microseconds; the preview page (V3) read data.json.

    python3 effects.py   # writes data.json

Round 40 PX built this catalogue in grug_core/particle_effects.lua. Where the
build differs, the emitters here carry the built numbers (marked "PX"): the
exact rings that mark a radius (Ice Nova, Bellow) fly at the speed that lands
on the radius, (R - 0.4) / life; Mighty Blow's kept blood keeps today's look
(no fade); Heal adds Hearten's four motes on a splashed ally; Mend plays on
the cast as well as on each tick. tools/r40_px/costs.py prints the
per-effect and busy-fight totals of the build.

Round 40 PM built the boss and mob cards the same way (marked "PM"): the
rings that burst out to a radius (Shatter, the gust's release, the dive's
slam) land on it, (R - r0) / life; the gust's warning ring keeps today's
look; the breath gathers at its launch point (eye height above the dragon's
centre, where the bolts and the muzzle burst start). tools/r40_pm/costs.py
prints the per-boss and per-mob totals of the build, with the looks PM moved
onto the helper unchanged.
"""
import json
from pathlib import Path

import cost_model as cm

HERE = Path(__file__).resolve().parent
TARGET = [6.0, 0.0, 0.0]
SMOKE = "default_item_smoke.png^[multiply:"
FIRE = "mobs_fire_particle.png"


def tint(c):
    return SMOKE + c


def sp(n, time, color, spawn, *, vel=None, acc=None, drag=None, attract=None, exp=(0.3, 0.6),
       size=(1.5, 3.0), glow=8, attached=False, tex=None, sprite="sq", fade=True, at="caster",
       radial=None, delay=0.0, kept=False):
    """A particle spawner in the engine's terms.

    spawn: ("box", min, max) -> `pos` range; ("line", from, to) -> `pos`
    tweened over `time`; ("disc", centre, r, _) -> `pos` = centre with
    `radius` {r, 0, r}; ("sphere", centre, r, True) -> `radius` {r, r, r}
    (a shell); ("sphere", centre, r, False) -> a `pos` box of +-r.
    The engine places a `radius` offset by rotating (|radius|, 0, 0) at
    random and scaling it per axis (client/particles.cpp:384-396): a flat
    radius gives a disc heavy towards the edge, not an exact ring.
    radial: (speed_min, speed_max) wanted at the spawn radius, built as an
    `attract` of kind point at the spawn centre with negative strength
    speed / r; the engine gives each particle |strength| x its distance once
    at birth (client/particles.cpp:448-458), so inner particles are slower.
    attract: (origin, strength, die_on_contact) in the engine's own terms
    (birth velocity strength x distance towards the origin; with
    die_on_contact the life is cut to 1 / strength).
    delay: seconds after the effect starts (a second spawner fired later)."""
    kind, centre = spawn[0], None
    engine = {"pos": None, "tween": None, "radius": None}
    if kind == "box":
        engine["pos"] = [spawn[1], spawn[2]]
        centre = [(spawn[1][k] + spawn[2][k]) / 2 for k in range(3)]
    elif kind == "line":
        engine["tween"] = [spawn[1], spawn[2]]
    elif kind == "disc":
        engine["pos"] = [spawn[1], spawn[1]]
        engine["radius"] = [spawn[2], 0, spawn[2]]
        centre = spawn[1]
    elif kind == "sphere" and spawn[3]:
        engine["pos"] = [spawn[1], spawn[1]]
        engine["radius"] = [spawn[2]] * 3
        centre = spawn[1]
    else:
        r = spawn[2]
        engine["pos"] = [[spawn[1][k] - r for k in range(3)], [spawn[1][k] + r for k in range(3)]]
        centre = spawn[1]
    e = {"kind": "spawner", "n": n, "time": time, "color": color, "spawn": spawn, "engine": engine,
         "vel": vel or [[0, 0, 0], [0, 0, 0]], "acc": acc or [0, 0, 0], "drag": drag or [0, 0, 0],
         "exp": list(exp), "size": list(size), "glow": glow, "attached": attached,
         "texture": tex or tint(color), "sprite": sprite, "fade": fade, "at": at, "delay": delay,
         "kept": kept}
    if radial:
        r = spawn[2] if kind in ("disc", "sphere") else 1.0
        e["radial"] = list(radial)
        e["pull"] = {"origin": centre, "strength": -radial[1] / r, "strength_min": -radial[0] / r,
                     "kill": False}
        e["attract"] = "point"
    if attract:
        e["pull"] = {"origin": attract[0], "strength": attract[1], "strength_min": attract[1],
                     "kill": attract[2]}
        e["attract"] = "point"
    return e


def single(n, color, spawn, *, steps=1, **kw):
    """A loop of add_particle calls; the Lua loop computes exact shapes
    (a ring is a ring) and a radial speed directly. `steps`: spread over that
    many server steps (a trail), one batch per step and player."""
    radial = kw.pop("radial", None)
    e = sp(n, 0.0, color, ("box", [0, 0, 0], [0, 0, 0]), **kw)
    e.update({"kind": "single", "spawn": spawn, "engine": None, "steps": steps})
    e.pop("pull", None)
    e.pop("attract", None)
    if radial:
        e["radial"] = list(radial)
    return e


def fx(id, group, name, skill, hook, today, look, emitters, *, simple=None, art=None,
       marker=None, pace=None, pace_text="", target=None, unchanged=False, note=""):
    return {"id": id, "group": group, "name": name, "skill": skill, "hook": hook, "today": today,
            "look": look, "emitters": emitters, "simple": simple, "art": art, "marker": marker,
            "pace": pace, "pace_text": pace_text, "target": target or TARGET, "note": note}


def simple(why, emitters):
    return {"why": why, "emitters": emitters}


T = TARGET
# Today's blood on a landed Mighty Blow (kits.lua:393), kept with the slash.
BLOOD6 = sp(6, 0.2, "#a01010", ("box", [-0.5, 0, -0.5], [0.5, 1, 0.5]), vel=[[-2, 0, -2], [2, 3, 2]],
            exp=(0.3, 0.7), size=(1.5, 3.0), glow=10, tex="mobs_blood.png", at="target", kept=True,
            fade=False)  # PX: today's look, no fade
# PX: an exact ring that marks radius R flies at (R - r0) / life.
NOVA_RING = (5 - 0.4) / 0.34
BELLOW_RING = (8 - 0.4) / 0.4
# PM: the boss rings that burst out to a radius, the same way.
SHATTER_RING = (6 - 0.6) / 0.34
GUST_RING = (8 - 1.0) / 0.39
DIVE_RING = (7 - 1.0) / 0.34
GUST_KEPT = "default_item_smoke.png^[colorize:#d8eef4:150"
EFFECTS = [
    # ---------------------------------------------------------------- requested
    fx("ice_nova", "requested", "Ice Nova: frost ring", "Ice Nova (Frostbind: the same ring at the target)",
       "kits.lua:698 (the burst today)", "20 pale smoke puffs within 1 m; the 5 m radius is invisible",
       "A flat ring of pale-blue frost motes shoots out from the mage's feet to the 5 m edge in a third "
       "of a second and fades there, over a low mist that spreads more slowly.",
       [single(48, "#bfe8ff", ("disc", [0, 0.25, 0], 0.4, True), radial=(NOVA_RING, NOVA_RING), exp=(0.34, 0.34),
               size=(2.5, 2.5), glow=10),
        sp(16, 0.1, "#e6f6ff", ("disc", [0, 0.15, 0], 0.6, False), radial=(3, 5), exp=(0.6, 0.8),
           size=(4.0, 6.0), glow=4)],
       simple=simple("One spawner of 24: fewer bytes and much less server time, but a spawner fills the ring "
                     "into a disc that is denser at the edge, and no mist.",
                     [sp(24, 0.05, "#bfe8ff", ("disc", [0, 0.25, 0], 0.4, True), radial=(14, 15),
                         exp=(0.33, 0.36), size=(2.5, 3.5), glow=10)]),
       art="Snowflake sprite (VoxeLibre weather_pack_snow_snowflake1/2, 5×5, CC BY-SA 3.0 TeddyDesTodes) "
           "for the ring; draconis ice motes (3×3, MIT) as glitter.",
       marker={"radius": 5}, pace=1 / 12, pace_text="once per 12 s cooldown",
       note="The ring is 48 single particles placed by Lua on an exact circle, all at the same speed: about "
            "the bytes of one spawner, which could only make a disc."),
    fx("fireball", "requested", "Fireball: fiery splash", "Fireball impact (Brand's 2 m splash reuses it)",
       "kits.lua:529 (on_hit)", "nothing on impact", "Embers spray out of the impact point in a half "
       "dome and fall back, with a short dark smoke puff.",
       [sp(28, 0.05, "#ff8a2a", ("sphere", [0, 1.0, 0], 0.2, False), vel=[[-5, 1, -5], [5, 6, 5]],
           acc=[0, -12, 0], exp=(0.4, 0.8), size=(1.0, 2.0), glow=14, tex=FIRE, at="target"),
        sp(10, 0.1, "#3a2a22", ("sphere", [0, 1.0, 0], 0.4, False), vel=[[-0.6, 0.5, -0.6], [0.6, 1.5, 0.6]],
           exp=(0.8, 1.2), size=(3.0, 5.0), glow=0, at="target")],
       simple=simple("The embers alone, 20 of them: one spawner instead of two.",
                     [sp(20, 0.05, "#ff8a2a", ("sphere", [0, 1.0, 0], 0.2, False),
                         vel=[[-5, 1, -5], [5, 6, 5]], acc=[0, -12, 0], exp=(0.4, 0.8), size=(1.5, 2.5),
                         glow=14, tex=FIRE, at="target")]),
       art="draconis_fire_animated (16×128, 8 frames, MIT) for the splash.",
       pace=1 / 1.5, pace_text="about one cast per 1.5 s (no cooldown)"),
    fx("smite", "requested", "Smite: holy fall", "Smite", "kits.lua:793-794 (beam and burst today)",
       "a line of ~2 single particles per metre from priest to target plus a 12-mote burst",
       "No projectile. Yellow-white motes appear in a ring 2.5 m above the target, slam down onto it and "
       "vanish on contact; a small flash ring at its feet.",
       [sp(24, 0.12, "#fff4c2", ("disc", [0, 3.3, 0], 0.9, False), attract=([0, 1.0, 0], 5, True),
           exp=(0.25, 0.3), size=(2.0, 3.0), glow=14, at="target"),
        sp(12, 0.05, "#ffe9a0", ("disc", [0, 0.15, 0], 0.3, True), radial=(4, 5), exp=(0.2, 0.3),
           size=(2.0, 2.5), glow=14, at="target")],
       simple=simple("The fall alone, 16 motes: one spawner.",
                     [sp(16, 0.12, "#fff4c2", ("disc", [0, 3.3, 0], 0.8, False),
                         attract=([0, 1.0, 0], 5, True), exp=(0.25, 0.3), size=(2.5, 3.5), glow=14,
                         at="target")]),
       art="A small four-point holy spark (art order).",
       pace=0.5, pace_text="once per 2 s cooldown",
       note="Replaces today's beam (about 24 single particles at 12 m) and burst."),
    fx("mighty_blow", "requested", "Mighty Blow: red slash", "Mighty Blow (a landed swing)",
       "kits.lua:392 (post)", "6 blood drops on the target (kept)",
       "A diagonal trail of red particles hangs in the air in front of the warrior, from upper right to "
       "lower left, about 1.6 m long; it does not move and fades within a third of a second.",
       [sp(20, 0.08, "#d8263a", ("line", [1.2, 2.0, -0.5], [1.2, 0.6, 0.6]), exp=(0.3, 0.4),
           size=(3.0, 4.0), glow=10),
        BLOOD6],
       simple=simple("Ten bigger motes: the same single spawner, half the particles on screen "
                     "(the server cost does not change: a spawner's packet is the same size).",
                     [sp(10, 0.08, "#d8263a", ("line", [1.2, 2.0, -0.5], [1.2, 0.6, 0.6]), exp=(0.3, 0.4),
                         size=(4.0, 5.0), glow=10), BLOOD6]),
       art="A stretched slash-streak sprite (art order).",
       pace=1 / 3, pace_text="about every 3 s (rage-bound)"),
    fx("skill_arrow", "requested", "Skill arrow trail", "Loose, Snare Shot, Pinning Shot (and Twin Shot)",
       "grug_projectiles spawn_one after add_entity (opt-in per skill)", "nothing",
       "A thin trail of motes behind the arrow, tinted per skill (Loose pale, Snare Shot green, Pinning "
       "Shot teal); the motes drift a little and fade within 0.4 s.",
       [sp(30, 0.55, "#e9e4d0", ("line", [0.3, 1.45, 0], [25, 1.2, 0]), vel=[[-0.2, -0.1, -0.2], [0.2, 0.2, 0.2]],
           exp=(0.3, 0.45), size=(1.0, 1.5), glow=6)],
       simple=simple("Twelve motes along the same line.",
                     [sp(12, 0.55, "#e9e4d0", ("line", [0.3, 1.45, 0], [25, 1.2, 0]),
                         vel=[[-0.2, -0.1, -0.2], [0.2, 0.2, 0.2]], exp=(0.3, 0.45), size=(1.5, 2.0), glow=6)]),
       pace=1, pace_text="about one shot per second",
       target=[25, 0, 0],
       note="Arrows fly 40-55 m/s, so the trail's spawner lives about half a second. Built as an unattached "
            "spawner along the launch line (time = flight time, at most 1 s), so only "
            "nearby players receive it. A spawner attached to the arrow follows a curving flight exactly but "
            "goes to every player on the server."),
    # ---------------------------------------------------------------- player (proposed)
    fx("charge", "player", "Charge: dust trail and impact", "Charge (the dash)", "CH's carrier (wave 2)",
       "nothing (today a teleport)",
       "Dust kicked up along the ground path of the dash, and on arrival a low dust ring around the target.",
       [sp(18, 0.5, "#b8a27a", ("line", [0, 0.1, 0], [4.7, 0.1, 0]), vel=[[-0.5, 0.3, -0.5], [0.5, 1.2, 0.5]],
           exp=(0.4, 0.7), size=(2.5, 4.0), glow=0),
        sp(14, 0.05, "#b8a27a", ("disc", [0, 0.1, 0], 0.5, True), radial=(4, 5), exp=(0.3, 0.45),
           size=(3.0, 4.0), glow=0, at="target")],
       simple=simple("Only the arrival ring: one spawner.",
                     [sp(14, 0.05, "#b8a27a", ("disc", [0, 0.1, 0], 0.5, True), radial=(4, 5),
                         exp=(0.3, 0.45), size=(3.0, 4.0), glow=0, at="target")]),
       pace=0.1, pace_text="once per 10 s cooldown",
       note="The path is known at the cast, so the trail is an unattached spawner along it (nearby players only)."),
    fx("hamstring", "player", "Hamstring: leg cut", "Hamstring (landed)", "kits.lua:450 (blood today)",
       "4 blood drops", "A short low red cut across the target's legs at shin height.",
       [single(6, "#c0303f", ("line", [-0.4, 0.4, -0.3], [0.4, 0.35, 0.3]), exp=(0.25, 0.3), size=(2.5, 3.0),
               glow=8, at="target")],
       pace=1 / 6, pace_text="once per 6 s charge"),
    fx("taunt", "player", "Taunt: mark above the target", "Taunt (single target)", "kits.lua:495",
       "6 orange smoke puffs", "A few orange motes jump up above the target's head and hang there briefly.",
       [single(6, "#ff8a3a", ("box", [-0.2, 2.1, -0.2], [0.2, 2.3, 0.2]), vel=[[-0.2, 1.2, -0.2], [0.2, 2.0, 0.2]],
               exp=(0.5, 0.7), size=(2.5, 3.0), glow=12, at="target")],
       pace=1 / 8, pace_text="once per 8 s cooldown"),
    fx("bellow", "player", "Bellow: shout wave", "Taunt with the Bellow talent (6–10 m)", "kits.lua:468-479",
       "nothing", "An orange shock ring runs along the ground from the warrior out to the Bellow radius.",
       [single(40, "#ff8a3a", ("disc", [0, 0.2, 0], 0.4, True), radial=(BELLOW_RING, BELLOW_RING), exp=(0.4, 0.4),
               size=(2.5, 2.5), glow=10)],
       simple=simple("One spawner of 20: less server time, a disc instead of an exact ring.",
                     [sp(20, 0.05, "#ff8a3a", ("disc", [0, 0.2, 0], 0.4, True), radial=(20, 21),
                         exp=(0.38, 0.42), size=(3.0, 4.0), glow=10)]),
       marker={"radius": 8}, pace=1 / 8, pace_text="once per 8 s cooldown"),
    fx("hold_ground", "player", "Hold Ground: golden stance", "Hold Ground", "kits.lua:1037",
       "14 tan smoke puffs", "A golden ring of motes at the warrior's feet that rises slowly.",
       [sp(24, 0.1, "#e8c06a", ("disc", [0, 0.1, 0], 1.0, True), vel=[[0, 0.5, 0], [0, 1.2, 0]], exp=(0.7, 0.9),
           size=(2.0, 2.5), glow=12)],
       simple=simple("Twelve motes.", [sp(12, 0.1, "#e8c06a", ("disc", [0, 0.1, 0], 1.0, True),
                                          vel=[[0, 0.5, 0], [0, 1.2, 0]], exp=(0.7, 0.9), size=(2.5, 3.0), glow=12)]),
       pace=1 / 60, pace_text="once per 60 s cooldown"),
    fx("blink", "player", "Blink: implode and burst", "Blink", "kits.lua:734, 737", "10 violet puffs at each end",
       "Violet motes rush into the spot the mage leaves and vanish there; at the arrival point a violet burst.",
       [sp(14, 0.1, "#b06aff", ("sphere", [0, 1.0, 0], 1.0, True), attract=([0, 1.0, 0], 3, True), exp=(0.3, 0.4),
           size=(2.0, 2.5), glow=12),
        sp(14, 0.05, "#b06aff", ("sphere", [0, 1.0, 0], 0.2, False), radial=(3, 4), exp=(0.3, 0.4),
           size=(2.0, 2.5), glow=12, at="target")],
       simple=simple("Today's two bursts, recoloured only (same cost as today).", [
           sp(10, 0.2, "#b06aff", ("box", [-0.5, 0, -0.5], [0.5, 1, 0.5]), vel=[[-2, 0, -2], [2, 3, 2]],
              exp=(0.3, 0.7), size=(1.5, 3), glow=10),
           sp(10, 0.2, "#b06aff", ("box", [-0.5, 0, -0.5], [0.5, 1, 0.5]), vel=[[-2, 0, -2], [2, 3, 2]],
              exp=(0.3, 0.7), size=(1.5, 3), glow=10, at="target")]),
       target=[10, 0, 0], pace=1 / 15, pace_text="once per 15 s cooldown"),
    fx("cinderfall", "player", "Cinderfall: ember rain", "Cinderfall", "kits.lua:1066",
       "18 fire sprites within 1 m (the 3 m radius is invisible)",
       "Embers rain into the real 3 m circle from four metres up and wink out on the ground.",
       [sp(36, 0.4, "#ff7a2a", ("box", [-2.1, 4.0, -2.1], [2.1, 4.0, 2.1]), vel=[[-0.3, -10, -0.3], [0.3, -8, 0.3]],
           exp=(0.4, 0.5), size=(1.5, 2.5), glow=14, tex=FIRE, at="target")],
       simple=simple("Eighteen embers, the count of today.", [
           sp(18, 0.4, "#ff7a2a", ("box", [-2.1, 4.0, -2.1], [2.1, 4.0, 2.1]), vel=[[-0.3, -10, -0.3], [0.3, -8, 0.3]],
              exp=(0.4, 0.5), size=(2.0, 3.0), glow=14, tex=FIRE, at="target")]),
       marker={"radius": 3, "at": "target"}, pace=0.1, pace_text="once per 10 s cooldown"),
    fx("glacial_ward", "player", "Glacial Ward: frost shell", "Glacial Ward", "kits.lua:1083", "14 blue bubbles",
       "Frost motes appear on a shell around the mage and drift inward onto it.",
       [sp(20, 0.2, "#bfe8ff", ("sphere", [0, 1.0, 0], 1.1, True), attract=([0, 1.0, 0], 2.5, True),
           exp=(0.4, 0.5), size=(2.0, 2.5), glow=10)],
       simple=simple("Ten motes.", [sp(10, 0.2, "#bfe8ff", ("sphere", [0, 1.0, 0], 1.1, True),
                                       attract=([0, 1.0, 0], 2.5, True), exp=(0.4, 0.5), size=(2.5, 3.0), glow=10)]),
       art="Snowflake sprite as for Ice Nova.", pace=1 / 30, pace_text="once per 30 s cooldown"),
    fx("heal", "player", "Heal: rising light", "Heal (Hearten: four motes on each splashed ally)",
       "kits.lua:865", "8 hearts", "Golden-green motes rise around the healed player.",
       [sp(12, 0.1, "#d8f0a0", ("disc", [0, 0.1, 0], 0.5, False), vel=[[0, 1.5, 0], [0, 2.5, 0]],
           exp=(0.7, 0.9), size=(2.0, 2.5), glow=12, at="target"),
        # PX: Hearten's splash, four motes on each splashed ally (one shown).
        sp(4, 0.1, "#d8f0a0", ("disc", [0, 0.1, 0], 0.5, False), vel=[[0, 1.5, 0], [0, 2.5, 0]],
           exp=(0.7, 0.9), size=(2.0, 2.5), glow=12, at="target")],
       simple=simple("Today's hearts (8): no change.", [
           sp(8, 0.2, "#ff6080", ("box", [-0.5, 0, -0.5], [0.5, 1, 0.5]), vel=[[-2, 0, -2], [2, 3, 2]],
              exp=(0.3, 0.7), size=(1.5, 3), glow=10, tex="mobs_heart_particle.png", at="target")]),
       target=[4, 0, 0], pace=0.25, pace_text="once per 4 s cooldown"),
    fx("shield_spell", "player", "Shield: golden shell", "Shield", "kits.lua:916", "8 pale gold puffs",
       "A pale-gold shell of motes flashes around the shielded player.",
       [sp(18, 0.05, "#ffe9a0", ("sphere", [0, 1.0, 0], 0.9, True), exp=(0.35, 0.45), size=(2.0, 2.5),
           glow=12, at="target")],
       simple=simple("Ten motes.", [sp(10, 0.05, "#ffe9a0", ("sphere", [0, 1.0, 0], 0.9, True),
                                       exp=(0.35, 0.45), size=(2.5, 3.0), glow=12, at="target")]),
       target=[4, 0, 0], pace=0.1, pace_text="once per 10 s cooldown"),
    fx("mend", "player", "Mend: small rising light per tick", "Mend (each of 4 ticks)", "kits.lua:975, 999",
       "5 hearts on the cast, 3 per tick", "Three golden-green motes rise from the player on each tick.",
       [single(3, "#d8f0a0", ("disc", [0, 0.6, 0], 0.4, False), vel=[[0, 1.2, 0], [0, 1.8, 0]], exp=(0.6, 0.8),
               size=(2.0, 2.5), glow=12, at="target")],
       target=[4, 0, 0], pace=5 / 12, pace_text="the cast and four ticks per 12 s while it runs (PX)",
       note="Three particles are cheaper as single particles than as a spawner."),
    fx("word_of_ruin", "player", "Word of Ruin: drain", "Word of Ruin", "kits.lua:1093-1122", "nothing",
       "Dark violet motes peel off the target and stream to the priest.",
       [sp(16, 0.3, "#6a2a9a", ("sphere", [0, 1.0, 0], 0.5, False), attract=([-6, 1.2, 0], 2, True),
           exp=(0.6, 0.7), size=(2.0, 2.5), glow=6, at="target")],
       simple=simple("A dark burst on the target only.", [
           sp(10, 0.05, "#6a2a9a", ("sphere", [0, 1.0, 0], 0.3, False), radial=(2, 3), exp=(0.4, 0.5),
              size=(2.5, 3.0), glow=6, at="target")]),
       pace=1 / 12, pace_text="once per 12 s cooldown"),
    fx("snare_hit", "player", "Snare Shot: net on the legs", "Snare Shot (landed)", "scout.lua:115", "nothing",
       "A green ring of motes springs out around the target's legs and hangs a moment.",
       [sp(10, 0.05, "#79a65a", ("disc", [0, 0.4, 0], 0.2, True), radial=(2, 2.5), exp=(0.4, 0.5),
           size=(2.0, 2.5), glow=6, at="target")],
       pace=1 / 12, pace_text="once per 12 s cooldown"),
    fx("pinning_hit", "player", "Pinning Shot: pinned", "Pinning Shot (landed)", "scout.lua:116", "nothing",
       "Teal motes drop onto the target's feet and stay a moment.",
       [single(8, "#4f8f67", ("disc", [0, 1.6, 0], 0.5, False), vel=[[0, -8, 0], [0, -6, 0]], exp=(0.2, 0.25),
               size=(2.0, 2.5), glow=8, at="target")],
       pace=1 / 30, pace_text="once per 30 s cooldown"),
    fx("sidestep", "player", "Sidestep: shimmer", "Sidestep", "grug_classes/scout.lua:20-33", "status icon only",
       "A pale-green shimmer around the scout for a moment.",
       [single(8, "#a8e0c0", ("sphere", [0, 1.0, 0], 0.6, True), vel=[[0, 0.2, 0], [0, 0.6, 0]], exp=(0.35, 0.45),
               size=(2.0, 2.5), glow=10)],
       pace=1 / 30, pace_text="once per 30 s cooldown"),
    fx("sprint", "player", "Sprint: dust kick", "Sprint", "scout.lua:529-545", "status icon only",
       "A puff of dust kicked up behind the scout as the sprint starts.",
       [single(8, "#b8a27a", ("box", [-0.6, 0.05, -0.3], [-0.2, 0.2, 0.3]), vel=[[-2, 0.5, -0.5], [-1, 1.5, 0.5]],
               exp=(0.4, 0.6), size=(3.0, 4.0), glow=0)],
       pace=1 / 300, pace_text="once per 300 s cooldown"),
    fx("opening", "player", "Opening: flash", "Opening (landed)", "scout.lua:593-601", "nothing",
       "A brief white flash of sparks at the target.",
       [single(6, "#ffffff", ("sphere", [0, 1.1, 0], 0.15, False), vel=[[-2, -1, -2], [2, 2, 2]], exp=(0.15, 0.2),
               size=(1.5, 2.0), glow=14, at="target")],
       pace=1 / 12, pace_text="once per 12 s charge"),
    fx("proc", "player", "Proc flash (shared)", "Ruination, Whitehot, Last Word, Unbroken, Untouchable, "
       "Last Light, Reclaimer, Battlebeat", "the proc sites (kits.lua:402, 534, 1103; talents.lua:1123; "
       "grug_classes/scout.lua:75; grug_trinkets/init.lua:115-143)", "status icons only",
       "A quick ring of motes in the proc's colour rises around the player.",
       [single(8, "#ffcf40", ("disc", [0, 0.3, 0], 0.6, True), vel=[[0, 1.5, 0], [0, 2.2, 0]], exp=(0.4, 0.5),
               size=(2.0, 2.5), glow=12)],
       pace=1 / 15, pace_text="rare: about once per 15 s"),
    # ---------------------------------------------------------------- bosses
    fx("king_windup_ring", "boss", "King wind-up: ground ring", "Dwarf king's Shatter wind-up (2 s)",
       "bosses.lua:508-514", "sound and animation only",
       "A ring of stone dust marks the 6 m blast radius on the ground for the whole wind-up, rising a little.",
       [single(40, "#b0a090", ("disc", [0, 0.1, 0], 6.0, True), vel=[[0, 0.1, 0], [0, 0.1, 0]], exp=(2.0, 2.0),
               size=(3.5, 3.5), glow=4, fade=False, at="target")],
       simple=simple("Twenty-four motes, the same exact ring.", [
           single(24, "#b0a090", ("disc", [0, 0.1, 0], 6.0, True), vel=[[0, 0.1, 0], [0, 0.1, 0]],
                  exp=(2.0, 2.0), size=(4.5, 4.5), glow=4, fade=False, at="target")]),
       marker={"radius": 6, "at": "target"}, target=[0, 0, 0], pace=1 / 8, pace_text="every 8 s",
       note="Single particles placed by Lua on an exact circle, each living the whole two seconds: a spawner's "
            "radius gives a disc, not a ring, and a spawner longer than 1 s would go to every player on the "
            "server. Nearly stationary single particles compress well."),
    fx("king_shatter", "boss", "King Shatter: ground burst", "Dwarf king's Shatter", "bosses.lua:442",
       "nothing", "Stone dust bursts outward along the ground to 6 m, with chunks thrown up.",
       [single(48, "#b0a090", ("disc", [0, 0.2, 0], 0.6, True), radial=(SHATTER_RING, SHATTER_RING),
               exp=(0.34, 0.34), size=(3.5, 3.5), glow=0, at="target"),  # PM: lands on 6 m
        sp(12, 0.05, "#7a6a5a", ("sphere", [0, 0.3, 0], 1.0, False), vel=[[-3, 4, -3], [3, 7, 3]],
           acc=[0, -12, 0], exp=(0.7, 0.9), size=(3.0, 4.0), glow=0, tex="grug_mobs_rock.png", at="target")],
       simple=simple("The exact ring only, 32 motes, no thrown chunks.", [
           single(32, "#b0a090", ("disc", [0, 0.2, 0], 0.6, True), radial=(17, 17), exp=(0.34, 0.34),
                  size=(4.0, 4.0), glow=0, at="target")]),
       marker={"radius": 6, "at": "target"}, target=[0, 0, 0], pace=1 / 8, pace_text="every 8 s"),
    fx("king_cleave", "boss", "King Cleave: cone sweep", "Orc king's Cleave (and its wind-up)", "bosses.lua:469",
       "nothing", "During the wind-up, red motes rise across the 60° cone in front of the king; on the hit a "
       "red arc sweeps across the cone at 4 m.",
       [sp(16, 1.0, "#c03030", ("box", [1.0, 0.1, -2.5], [6.0, 0.3, 2.5]), vel=[[0, 0.4, 0], [0, 1.0, 0]],
           exp=(0.6, 0.9), size=(3.0, 4.0), glow=6),
        sp(16, 1.0, "#c03030", ("box", [1.0, 0.1, -2.5], [6.0, 0.3, 2.5]), vel=[[0, 0.4, 0], [0, 1.0, 0]],
           exp=(0.6, 0.9), size=(3.0, 4.0), glow=6, delay=1.0),
        sp(30, 0.12, "#e03a3a", ("line", [3.5, 1.2, -2.0], [3.5, 1.0, 2.0]), exp=(0.3, 0.4), size=(3.5, 4.5),
           glow=10, delay=2.0)],
       simple=simple("Only the hit arc, 16 motes.", [
           sp(16, 0.12, "#e03a3a", ("line", [3.5, 1.2, -2.0], [3.5, 1.0, 2.0]), exp=(0.3, 0.4), size=(4.0, 5.0),
              glow=10)]),
       marker={"cone": [6, 60]}, pace=1 / 8, pace_text="every 8 s"),
    fx("king_aura", "boss", "King wind-up: aura", "Human, elf, undead and troll kings' wind-up",
       "bosses.lua:508-514", "sound and animation only",
       "Motes in the race's colour rise around the king during the wind-up (gold for Rally, green for "
       "Regrowth, grey-green for Bone Call, pale for Volley).",
       [sp(20, 1.0, "#e8c06a", ("disc", [0, 0.2, 0], 1.0, False), vel=[[0, 0.8, 0], [0, 1.6, 0]], exp=(0.7, 0.9),
           size=(2.5, 3.0), glow=10),
        sp(20, 1.0, "#e8c06a", ("disc", [0, 0.2, 0], 1.0, False), vel=[[0, 0.8, 0], [0, 1.6, 0]], exp=(0.7, 0.9),
           size=(2.5, 3.0), glow=10, delay=1.0)],
       simple=simple("The first second only.", [
           sp(20, 1.0, "#e8c06a", ("disc", [0, 0.2, 0], 1.0, False), vel=[[0, 0.8, 0], [0, 1.6, 0]],
              exp=(0.9, 1.2), size=(2.5, 3.0), glow=10)]),
       pace=1 / 8, pace_text="every 8 s"),
    fx("king_resolve", "boss", "Rally, Regrowth, Bone Call: the moment", "The resolve of the other kits",
       "bosses.lua:443-474", "nothing",
       "On the resolve: a gold rise on every rallied guard, a green spiral up the troll, a grey-green dust "
       "eruption at each summoned raider. Shown here: one burst per affected creature (up to four).",
       [sp(12, 0.1, "#e8c06a", ("disc", [0, 0.1, 0], 0.6, False), vel=[[0, 1.5, 0], [0, 2.5, 0]],
           exp=(0.6, 0.8), size=(2.5, 3.0), glow=10, at="target") for _ in range(4)],
       simple=simple("One burst on the king only.", [
           sp(16, 0.1, "#e8c06a", ("disc", [0, 0.1, 0], 0.8, False), vel=[[0, 1.5, 0], [0, 2.5, 0]],
              exp=(0.6, 0.8), size=(2.5, 3.0), glow=10)]),
       target=[3, 0, 0], pace=1 / 8, pace_text="every 8 s"),
    fx("elite_cone", "boss", "Elite cone hit", "Every elite and rare (kings, guards, golems, the Kraken, "
       "the rift boss, named rares)", "telegraph.lua:95-148 (resolve)", "smoke during the wind-up, nothing "
       "on the hit", "An orange arc sweeps across the 90° cone in front of the elite at its reach.",
       [sp(20, 0.12, "#ff6a2a", ("line", [3.0, 1.1, -2.6], [3.0, 1.0, 2.6]), exp=(0.3, 0.4), size=(3.0, 4.0),
           glow=10)],
       simple=simple("Twelve motes.", [sp(12, 0.12, "#ff6a2a", ("line", [3.0, 1.1, -2.6], [3.0, 1.0, 2.6]),
                                         exp=(0.3, 0.4), size=(4.0, 5.0), glow=10)]),
       marker={"cone": [4.5, 90]}, pace=1 / 10, pace_text="about every 10 s per elite in a fight"),
    fx("breath_windup", "boss", "Dragon breath wind-up", "Both dragons, breath (1.25 s)",
       "boss_dragons.lua:733-747", "growl and animation only",
       "Glowing motes (frost or fire) gather at the dragon's mouth and vanish into it.",
       [sp(20, 1.0, "#8ee8ff", ("sphere", [0, 5.0, 0], 1.6, True), attract=([0, 5.0, 0], 1.5, True),
           exp=(0.7, 0.9), size=(2.5, 3.5), glow=14)],  # PM: at the launch point
       art="draconis ice and fire motes (MIT).", pace=1 / 6, pace_text="about every 6 s"),
    fx("breath_bolt", "boss", "Dragon breath bolts", "Both dragons, the three breath bolts",
       "boss_dragons.lua:403-446", "a tinted rock sprite with up to 18 single trail particles each",
       "The bolts get a frost or fire sprite instead of the tinted rock; the trail keeps single particles "
       "but fewer (12 per bolt).",
       [single(36, "#8ee8ff", ("line", [3, 3.5, 0], [12, 0.5, 0]), vel=[[-0.3, -0.3, -0.3], [0.3, 0.3, 0.3]],
               exp=(0.3, 0.5), size=(3.0, 4.0), glow=12, steps=12)],
       simple=simple("The sprite only; six trail particles per bolt.", [
           single(18, "#8ee8ff", ("line", [3, 3.5, 0], [12, 0.5, 0]), vel=[[-0.3, -0.3, -0.3], [0.3, 0.3, 0.3]],
                  exp=(0.3, 0.5), size=(3.5, 4.5), glow=12, steps=6)]),
       art="draconis_ice_particle / draconis_fire_particle as the bolt sprite.", target=[12, 0, 0],
       pace=1 / 6, pace_text="about every 6 s",
       note="The trail adds one particle per bolt and server step, so each step is its own compressed packet "
            "per player. A spawner attached to each bolt would follow the homing bolt exactly, but goes to every "
            "player on the server. The 54-mote burst when the breath fires (boss_dragons.lua:612-614) stays."),
    fx("lightning_strike", "boss", "Storm lightning: the strike", "Stormscale, lightning impact",
       "boss_dragons.lua:632-644", "a burst of 96 yellow motes",
       "A white-yellow bolt column drops from 8 m onto the spot, with a smaller ground burst (48).",
       [sp(24, 0.08, "#ffffff", ("line", [0, 8, 0], [0, 0.2, 0]), exp=(0.15, 0.25), size=(4.0, 5.0), glow=14,
           at="target"),
        sp(48, 0.05, "#fff27a", ("disc", [0, 0.2, 0], 0.4, True), radial=(6, 7), exp=(0.3, 0.4), size=(2.5, 3.5),
           glow=14, at="target")],
       simple=simple("The ground burst of 48 alone.", [
           sp(48, 0.05, "#fff27a", ("disc", [0, 0.2, 0], 0.4, True), radial=(6, 7), exp=(0.3, 0.4),
              size=(2.5, 3.5), glow=14, at="target")]),
       marker={"radius": 2, "at": "target"}, target=[0, 0, 0], pace=1 / 8, pace_text="about every 8 s"),
    fx("gust", "boss", "Wing gust", "Both dragons, wing gust", "boss_dragons.lua:770-804",
       "a 40-particle single ring (wind-up) and a burst of 96",
       "The 8 m warning ring stays as today (40 single particles, an exact circle); on release a pale ring "
       "of 48 blows outward to 8 m, instead of today's 96-mote burst.",
       [single(40, "#d8eef4", ("disc", [0, 0.2, 0], 8.0, True), vel=[[0, 0.3, 0], [0, 0.3, 0]],
               exp=(1.25, 1.25), size=(4.0, 4.0), glow=6, fade=False, at="target",
               tex=GUST_KEPT),  # PM: today's ring, kept
        single(48, "#d8eef4", ("disc", [0, 0.5, 0], 1.0, True), radial=(GUST_RING, GUST_RING),
               exp=(0.39, 0.39), size=(3.5, 3.5), glow=6, at="target", delay=1.25)],
       simple=simple("The wind-up ring and a release spawner of 40 (a disc, less server time).", [
           single(40, "#d8eef4", ("disc", [0, 0.3, 0], 8.0, True), exp=(1.25, 1.25), size=(3.5, 3.5), glow=6,
                  fade=False, at="target"),
           sp(40, 0.05, "#d8eef4", ("disc", [0, 0.5, 0], 1.0, True), radial=(18, 19), exp=(0.4, 0.45),
              size=(3.5, 4.5), glow=6, at="target", delay=1.25)]),
       marker={"radius": 8, "at": "target"}, target=[0, 0, 0], pace=1 / 10, pace_text="about every 10 s"),
    fx("dive", "boss", "Dragon dive slam", "Both dragons, dive", "boss_dragons.lua:755-824",
       "80 gold motes at the wind-up and 120 at the slam",
       "Keep the wind-up; the slam as an exact ground ring out to 7 m (48) and a dust cloud (32) instead of 120.",
       [single(48, "#e8c06a", ("disc", [0, 0.2, 0], 1.0, True), radial=(DIVE_RING, DIVE_RING),
               exp=(0.34, 0.34), size=(4.0, 4.0), glow=10, at="target"),  # PM: lands on 7 m
        sp(32, 0.2, "#a89a80", ("disc", [0, 0.2, 0], 3.0, False), vel=[[-1, 0.5, -1], [1, 2, 1]], exp=(0.8, 1.2),
           size=(5.0, 7.0), glow=0, at="target")],
       simple=simple("The ring only.", [single(48, "#e8c06a", ("disc", [0, 0.2, 0], 1.0, True), radial=(18, 18),
                                             exp=(0.34, 0.34), size=(4.0, 4.0), glow=10, at="target")]),
       marker={"radius": 7, "at": "target"}, target=[0, 0, 0], pace=1 / 15, pace_text="about every 15 s"),
    fx("enrage", "boss", "Dragon enrage", "Both dragons at half health", "boss_dragons.lua:710-731",
       "a burst of 180 red motes", "The same red burst with 96 motes.",
       [sp(96, 0.5, "#e03030", ("box", [-7, 0, -7], [7, 4, 7]), vel=[[-3, 0.5, -3], [3, 5, 3]], exp=(0.4, 1.6),
           size=(2.0, 6.0), glow=10, at="target")],
       target=[0, 0, 0], pace=0, pace_text="once per fight"),
    fx("whelps", "boss", "Whelp arrival", "Dragon enrage summon", "boss_dragons.lua:691-708", "nothing",
       "A dark puff where each of the two whelps appears.",
       [sp(16, 0.1, "#40384a", ("sphere", [0, 0.8, 0], 0.6, False), vel=[[-1, 0.5, -1], [1, 2, 1]],
           exp=(0.6, 0.9), size=(4.0, 6.0), glow=0, at="target") for _ in range(2)],
       target=[3, 0, 0], pace=0, pace_text="once per fight"),
    fx("kraken_drag", "boss", "Kraken drag", "The Kraken's landed drag", "kraken.lua:121-131", "nothing",
       "A burst of bubbles around the dragged player.",
       [sp(16, 0.1, "#cfe8ff", ("sphere", [0, 1.0, 0], 0.6, False), vel=[[-0.5, 1.0, -0.5], [0.5, 2.5, 0.5]],
           exp=(0.5, 0.8), size=(2.0, 3.0), glow=0, tex="mobs_bubble_particle.png", at="target")],
       target=[2, 0, 0], pace=1 / 3, pace_text="on each landed hit, about every 3 s"),
    # ---------------------------------------------------------------- mobs
    fx("web", "mob", "Web on the legs", "Crevice, Bonelurker and Jungle Spider, spiderlings",
       "verbs.lua:149-160 (slow_player)", "nothing", "White strands burst at the player's legs and sink slowly.",
       [single(8, "#f0f0f0", ("box", [-0.3, 0.2, -0.3], [0.3, 0.6, 0.3]), vel=[[-1, -0.2, -1], [1, 0.3, 1]],
               acc=[0, -1, 0], exp=(0.7, 0.9), size=(2.0, 3.0), glow=0, at="target")],
       target=[1.5, 0, 0], pace=1 / 3, pace_text="on a landed bite, about every 3 s"),
    fx("poison", "mob", "Poison: apply and tick", "Serpent, Scorpion, Viper", "verbs.lua:216-280",
       "a status icon only", "Green bubbles rise from the player when poisoned, and two on each tick.",
       [single(6, "#7ac943", ("disc", [0, 0.8, 0], 0.4, False), vel=[[0, 0.8, 0], [0, 1.4, 0]], exp=(0.5, 0.7),
               size=(2.0, 2.5), glow=4, tex="mobs_bubble_particle.png^[multiply:#7ac943", at="target")],
       target=[1.5, 0, 0], pace=1 / 2, pace_text="apply plus a tick about every 2 s"),
    fx("pounce", "mob", "Pounce and charge", "Panther, Speargrass Tiger, Snow Leopard, Boar",
       "verbs.lua:402-439", "nothing", "Dust at the take-off and a dust puff where the pounce lands.",
       [single(6, "#b8a27a", ("box", [-0.4, 0.05, -0.4], [0.4, 0.2, 0.4]), vel=[[-1.5, 0.4, -1.5], [1.5, 1.2, 1.5]],
               exp=(0.4, 0.6), size=(3.0, 4.0), glow=0),
        single(6, "#b8a27a", ("box", [-0.4, 0.05, -0.4], [0.4, 0.2, 0.4]), vel=[[-1.5, 0.4, -1.5], [1.5, 1.2, 1.5]],
               exp=(0.4, 0.6), size=(3.0, 4.0), glow=0, at="target")],
       target=[5, 0, 0], pace=1 / 8, pace_text="about every 8 s per stalker"),
    fx("ambush", "mob", "Ambush release", "Crocodile", "verbs.lua:459-475", "nothing",
       "A splash (water) or dirt burst where the ambusher breaks cover.",
       [sp(14, 0.05, "#9cc8e0", ("disc", [0, 0.2, 0], 0.6, False), vel=[[-2, 2, -2], [2, 4, 2]], acc=[0, -10, 0],
           exp=(0.5, 0.7), size=(2.5, 3.5), glow=0, at="target")],
       target=[2, 0, 0], pace=0, pace_text="once per ambush"),
    fx("ooze_aura", "mob", "Ooze damage aura", "Bog Ooze (2 m, every 1 s)", "verbs.lua:559-580", "nothing",
       "On each aura tick that hurts someone, a few green bubbles pop on the ground within 2 m.",
       [single(5, "#6aa83a", ("disc", [0, 0.1, 0], 2.0, False), vel=[[0, 0.3, 0], [0, 0.8, 0]], exp=(0.5, 0.7),
               size=(2.5, 3.5), glow=2, tex="mobs_bubble_particle.png^[multiply:#6aa83a", at="target")],
       marker={"radius": 2, "at": "target"}, target=[0, 0, 0], pace=1, pace_text="once per second while it hurts someone"),
    fx("treant_aura", "mob", "Treant slowing aura", "Ashen and Gravewood Treant (3 m)", "night_families.lua:205-222",
       "nothing", "Brown leaves drift down within the 3 m aura while a player is slowed by it.",
       [single(5, "#7a5a32", ("disc", [0, 3.0, 0], 3.0, False), vel=[[-0.3, -0.8, -0.3], [0.3, -0.5, 0.3]],
               exp=(1.8, 2.2), size=(2.5, 3.0), glow=0, at="target")],
       marker={"radius": 3, "at": "target"}, target=[0, 0, 0], pace=0.5, pace_text="every 2 s while it slows someone"),
    fx("oerkki_blink", "mob", "Oerkki blink origin", "Oerkki", "oerkki.lua:51-56", "12 violet puffs at the arrival only",
       "A matching violet puff where the Oerkki leaves.",
       [sp(12, 0.2, "#7030a0", ("box", [-0.5, 0, -0.5], [0.5, 1, 0.5]), vel=[[-2, 0, -2], [2, 3, 2]],
           exp=(0.3, 0.7), size=(1.5, 3), glow=10)],
       target=[3, 0, 0], pace=1 / 5, pace_text="every 5 s"),
    fx("wisp_blink", "mob", "Wisp blink", "Wisp (2.5 m step every 4 s)", "night_families.lua:160-178", "nothing",
       "Pale puffs where the wisp leaves and arrives.",
       [single(5, "#dff4ff", ("sphere", [0, 1.0, 0], 0.3, False), vel=[[-0.8, 0, -0.8], [0.8, 1, 0.8]],
               exp=(0.4, 0.6), size=(2.0, 3.0), glow=12),
        single(5, "#dff4ff", ("sphere", [0, 1.0, 0], 0.3, False), vel=[[-0.8, 0, -0.8], [0.8, 1, 0.8]],
               exp=(0.4, 0.6), size=(2.0, 3.0), glow=12, at="target")],
       target=[2.5, 0, 0], pace=1 / 4, pace_text="every 4 s"),
    fx("projectile_impact", "mob", "Mob projectile impact", "Arrows, rocks, crystal shards, embers, fire hurls",
       "the arrows' hit callbacks (verbs.lua register_simple_arrow / register_homing_arrow)", "nothing on impact",
       "A small puff where a mob projectile hits: splinters (arrow), grey dust (rock), cyan glints (shard), "
       "orange sparks (ember, fire).",
       [single(5, "#a08860", ("sphere", [0, 1.0, 0], 0.15, False), vel=[[-1.5, -0.5, -1.5], [1.5, 1.5, 1.5]],
               acc=[0, -8, 0], exp=(0.3, 0.45), size=(1.5, 2.0), glow=0, at="target")],
       target=[1, 0, 0], pace=1 / 2, pace_text="about every 2 s per ranged mob"),
]

UNCHANGED = [
    ("Storm lightning warning ring", "boss_dragons.lua:617-630",
     "stays 32 single particles: an exact circle, and about 0.36 KB per nearby player against 0.67 KB as a spawner"),
    ("Critical hit sparks", "combat.lua:1012-1024", "8 gold motes"),
    ("Absorb soak", "combat.lua:1527-1538", "6 pale-gold motes"),
    ("Stun cross", "movement.lua:409-424", "procedural yellow cross"),
    ("Root crystals", "movement.lua:439-453", "procedural pale-blue crystal"),
    ("Rift pulse, spawn and crack", "rift.lua:173-191, 230-240, 443", "already spawners"),
    ("Hex bottle", "bog_witch.lua:20-27", "16 violet puffs"),
    ("Dragon ground patches", "boss_dragons.lua:251-266", "36 per patch"),
    ("Rift Spawn explosion", "rift_spawn.lua:46-71", "32 violet smoke"),
    ("Blood, death and fall smoke (mob engine)", "mobs/api.lua:1074, 3259, 3648-3664", "as today"),
]

REJECTED_ART = ("VoxeLibre's crit, totem, effect and generic smoke sprites come from a resource pack made for a "
                "commercial game; using them would copy that game's particle look (AGENTS.md: never copy assets "
                "one to one).")

# What fires today at the same moment, for the comparison (kits.lua burst()
# is a 0.2 s spawner, beam() single particles every 0.5 m).
def _burst(n, tex="x" * 40):
    return sp(n, 0.2, "#ffffff", ("box", [0, 0, 0], [1, 1, 1]), tex=tex)


TODAY = {
    "ice_nova": [_burst(20)], "smite": [single(24, "#ffe9a0", ("line", [0, 1.5, 0], [6, 1, 0]), exp=(0.25, 0.25), size=(2.5, 2.5)), _burst(12)],
    "mighty_blow": [BLOOD6], "hamstring": [_burst(4, "mobs_blood.png")],
    "taunt": [_burst(6)], "hold_ground": [_burst(14)], "blink": [_burst(10), _burst(10)],
    "cinderfall": [_burst(18, FIRE)], "glacial_ward": [_burst(14)], "heal": [_burst(8, "mobs_heart_particle.png")],
    "shield_spell": [_burst(8)], "mend": [_burst(3, "mobs_heart_particle.png")],
    "lightning_strike": [_burst(96)], "gust": [single(40, "#d8eef4", ("disc", [0, 0.3, 0], 8, True), exp=(1.25, 1.25), size=(3.5, 3.5)), _burst(96)],
    "dive": [_burst(120)], "enrage": [_burst(180)],
    "breath_bolt": [single(54, "#8ee8ff", ("line", [3, 3.5, 0], [12, 0.5, 0]), steps=18,
                           vel=[[-0.3, -0.3, -0.3], [0.3, 0.3, 0.3]])],
}

SCALES = (1.0, 0.5, 0.25)


def main():
    out = []
    for e in EFFECTS:
        entry = dict(e)
        entry["cost"] = {str(s): cm.effect_cost(e["emitters"], s) for s in SCALES}
        entry["emitter_costs"] = [cm.emitter_cost(x) for x in e["emitters"]]
        if e["id"] in TODAY:
            entry["today_cost"] = cm.effect_cost(TODAY[e["id"]], 1.0)
        if e["simple"]:
            entry["simple"] = dict(e["simple"])
            entry["simple"]["cost"] = {str(s): cm.effect_cost(e["simple"]["emitters"], s) for s in SCALES}
        out.append(entry)
    doc = {"effects": out, "unchanged": UNCHANGED, "rejected_art": REJECTED_ART,
           "constants": {"lua_spawner_us": cm.LUA_SPAWNER_US, "lua_spawner_attract_us": cm.LUA_SPAWNER_ATTRACT_US,
                         "lua_particle_us": cm.LUA_PARTICLE_US, "est_spawner_send_us": cm.EST_SPAWNER_SEND_US,
                         "est_particle_serialize_us": cm.EST_PARTICLE_SERIALIZE_US,
                         "est_distance_check_us": cm.EST_DISTANCE_CHECK_US,
                         "spawner_wire": cm.wire_bytes(cm.spawner_packet(tint("#ffe9a0")))[0]},
           "scales": [str(s) for s in SCALES]}
    (HERE / "data.json").write_text(json.dumps(doc, indent=1))
    print("effects:", len(out))
    for e in out:
        c = e["cost"]["1.0"]
        print("%-18s particles %3d spawners %d singles %3d  near %5d B  all %5d B  lua %.1f us" % (
            e["id"], c["particles"], c["spawners"], c["singles"], c["near_wire"], c["all_wire"], c["lua_us"]))


if __name__ == "__main__":
    main()

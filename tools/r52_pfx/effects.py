#!/usr/bin/env python3
"""Round 52 PFX: the particle effect cards for the 44 reworked skills.

    python3 -I tools/r52_pfx/effects.py      # writes data.json and emitters.lua

One card per effect moment of a skill (cast, trail, impact, area warning,
fall and impact, status tick, readiness window, ultimate). A card's emitters
are written in grug_core/particles.lua's own emitter format (kind, n, time,
at, shape, vel, acc, radial, attract, exp, size, glow, color or tex, fade, and
since the look pass mote, blend and after), so
round K registers a picked card in particle_effects.lua by copying it:

    status "keep"    today's catalogue id, unchanged (check_limits.lua proves
                     the emitters equal the shipped ones)
    status "retint"  today's catalogue id with the family colour (every field
                     but the colour equal, also proved)
    status "new"     a new catalogue id (`id`), registered as written
    status "none"    no particle effect (a reason is given)

A card whose emitters depend on the frame (an area's radius, a delay, the
fall height) is written as a Python function of the frame, like the Lua
function effects; `sample` is the frame it is evaluated with for the costs,
the check and the page, and `dynamic` says in one line what round K reads
from the frame.

Coordinates as particles.lua: metres in the anchor's frame, +x the caster's
facing, +y up, +z the caster's left. The caster stands at the origin facing
+x; a card's target stands at `target`. Sizes are the engine's (1 = 0.1 m,
client/particles.cpp:238).

Page texts (look, today, note) are German: the page is for the user.
"""
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import cost  # noqa: E402

SMOKE = "default_item_smoke.png^[multiply:"
MOTE = "grug_core_mote.png^[multiply:"
FIRE = "mobs_fire_particle.png"
BLOOD = "mobs_blood.png"
TARGET = [6.0, 0.0, 0.0]
MELEE = [1.8, 0.0, 0.0]

# --------------------------------------------------------------------------
# The eight families (the user, 2026-10-19; one per talent tree). `anchor`:
# the art palette (tools/r52_art/artb/drop-01/STYLE.md on r52-artb); `tints`:
# the particle colours derived from it. A tint multiplies the light grey smoke
# puff and glows, so it sits lighter than the icon anchor.
# --------------------------------------------------------------------------
FAMILIES = {
    "ember": {"name": "Ember", "de": "Feuer", "anchor": ["#F68B28", "#BC321E"],
              "tints": {"core": "#ffb347", "hot": "#ff8a3a", "white": "#fff0c8"},
              "motion": "steigt und sprüht, Funken fallen mit Schwerkraft zurück"},
    "rime": {"name": "Rime", "de": "Frost", "anchor": ["#A5D9F2", "#F1FBFF"],
             "tints": {"pale": "#bfe8ff", "white": "#f1fbff", "mist": "#e6f6ff"},
             "motion": "scharfe Ringe und Fächer, dann langsames Sinken"},
    "bulwark": {"name": "Bulwark", "de": "Stahl", "anchor": ["#99A3AE", "#B08A4D"],
                "tints": {"steel": "#c4ccd6", "bronze": "#d0a060", "white": "#e6ebf3"},
                "motion": "fest am Boden: Ringe um die Füße, kurze harte Funken"},
    "ruin": {"name": "Ruin", "de": "Wut", "anchor": ["#B52F3B", "#140E15"],
             "tints": {"crimson": "#d8263a", "hot": "#ff6a4a", "flare": "#e8402a"},
             "motion": "schnelle Hiebe, die stehen bleiben und verlöschen"},
    "mercy": {"name": "Mercy", "de": "Heilendes Licht", "anchor": ["#E8BC5C", "#FFF0CE"],
              "tints": {"gold": "#ffe08a", "ivory": "#fff0c8", "shield": "#ffe9a0"},
              "motion": "sanft aufsteigend, weich verblassend"},
    "reckoning": {"name": "Reckoning", "de": "Richtendes Gold", "anchor": ["#D5AD52", "#A32A32"],
                  "tints": {"gold": "#ffd257", "white": "#fff6dd", "fall": "#fff2c0"},
                  "motion": "von oben herab, gerade und hart"},
    "quarry": {"name": "Quarry", "de": "Wildnis", "anchor": ["#91AA55", "#94603A"],
               "tints": {"green": "#a8c86a", "wood": "#c8a878", "glint": "#f0e6b8",
                         "snare": "#79a65a", "trail": "#e9e4d0", "earth": "#b89a68"},
               "motion": "Spuren entlang der Flugbahn, Splitter und Erde"},
    "veil": {"name": "Veil", "de": "Schatten", "anchor": ["#8162B1", "#343568"],
             "tints": {"violet": "#b9a2e6", "smoke": "#5a4a9a", "silver": "#e6ebf3"},
             "motion": "Rauch, der sinkt; kurze silberne Funken"},
    "none": {"name": "—", "de": "keine", "anchor": ["#888888", "#444444"], "tints": {},
             "motion": ""},
}
T = {k: v["tints"] for k, v in FAMILIES.items()}

# --------------------------------------------------------------------------
# The look pass (after Round 54; the user's pick on 2026-10-21, "leuchtend +
# kräftig" for every skill effect, on the R52 page's colour lab). Every card
# goes through look(): a tinted emitter moves onto the white mote
# (grug_core_mote.png, `mote`) in its family's vivid tint; every light,
# spark, magic and fire emitter adds (`blend = "add"`) with glow 14; dust,
# earth, wood splinters, smoke, mist (MATTE) and blood keep the plain blend
# and their glow. particle_effects.lua writes the result, so the keep and
# retint checks still compare like with like. tools/r541_glow tests it.
# --------------------------------------------------------------------------
VIVID = {
    "ember": {"#fff0c8": "#ffd86a", "#ffb347": "#ff9a1a", "#ff8a3a": "#ff5a12"},
    "rime": {"#bfe8ff": "#4cc3ff", "#f1fbff": "#9fe2ff", "#e6f6ff": "#8fd3ff"},
    "bulwark": {"#c4ccd6": "#9cbce6", "#e6ebf3": "#dfeaff", "#d0a060": "#f0a030"},
    "ruin": {"#d8263a": "#ff1f3a", "#c0303f": "#ff2a48", "#e8402a": "#ff4214", "#ff6a4a": "#ff7a1a"},
    "mercy": {"#ffe08a": "#ffcf2a", "#ffe9a0": "#ffe04a", "#fff0c8": "#ffe680"},
    "reckoning": {"#fff2c0": "#ffe270", "#ffd257": "#ffb800", "#fff6dd": "#fff0a8"},
    "quarry": {"#a8c86a": "#98e03a", "#a8e0c0": "#50f0a8", "#f0e6b8": "#ffe680", "#79a65a": "#5cd03a"},
    "veil": {"#e6ebf3": "#e4e8ff", "#b9a2e6": "#9a66ff"},
}
MATTE = {"ember": {"#3a2a22"}, "rime": {"#e6f6ff"}, "ruin": {"#b8a27a"},
         "quarry": {"#b8a27a", "#c8a878", "#b89a68"}, "veil": {"#5a4a9a"}}


def vivid(family, color):
    return VIVID.get(family, {}).get(color, color)


def look(e, family):
    """One emitter after the look pass (see above)."""
    e = dict(e)
    tex = e.get("tex")
    if tex and tex.startswith("mobs_blood"):
        return e
    old = e.get("color")
    if not tex:
        e["color"] = vivid(family, old)
        e["mote"] = True
    if tex or old not in MATTE.get(family, ()):
        e["blend"] = "add"
        e["glow"] = 14
    return e


# Falls that start late and land with the delay: vertical speed in m/s.
METEOR_FALL_SPEED = 14
CENSURE_FALL_SPEED = 12


def S(n, time, **kw):
    """A spawner (particles.lua kind "spawner")."""
    d = {"kind": "spawner", "n": n, "time": time}
    d.update(kw)
    return d


def P(n, **kw):
    """A loop of single particles (particles.lua kind "single")."""
    d = {"kind": "single", "n": n}
    d.update(kw)
    return d


def recolor(emitters, color):
    out = []
    for e in emitters:
        e = dict(e)
        if "tex" not in e:
            e["color"] = color
        out.append(e)
    return out


# --------------------------------------------------------------------------
# Today's catalogue (mods/CORE/grug_core/particle_effects.lua at 87a4970c),
# transcribed for the ids a card keeps, recolours or replaces.
# check_limits.lua compares every keep and retint card with the shipped
# registry, so a transcription error fails the check.
# --------------------------------------------------------------------------
BLOOD6 = S(6, 0.2, at="target", tex=BLOOD, fade=False, shape=["box", [-0.5, 0, -0.5], [0.5, 1, 0.5]],
           vel=[[-2, 0, -2], [2, 3, 2]], exp=[0.3, 0.7], size=[1.5, 3], glow=10)


def _area_warning(f):
    life = f.get("time") or 1.5
    return [P(20, at="target", color="#ffb347", fade=False,
              shape=["disc", [0, 0.15, 0], f.get("reach") or 3, True], exp=[life, life],
              size=[3, 3], glow=12)]


def _area_fall(f):
    life = f.get("time") or 1.5
    height = f.get("height") or 12
    speed = -height / life
    return [P(6, at="target", color="#ff7a2a", fade=False,
              shape=["disc", [0, height, 0], 0.6 * (f.get("reach") or 3), False],
              vel=[[0, speed, 0], [0, speed, 0]], exp=[life, life], size=[8, 10], glow=14)]


def _area_impact(f):
    reach = f.get("reach") or 3
    return [P(40, at="target", color="#ffb347", shape=["disc", [0, 0.2, 0], 0.4, True],
              radial="reach", exp=[0.35, 0.35], size=[2.5, 3], glow=12),
            S(30, 0.15, at="target", color="#ff7a2a", shape=["disc", [0, 0.3, 0], 0.8 * reach, False],
              vel=[[-1, 2, -1], [1, 5, 1]], acc=[0, -9, 0], exp=[0.5, 0.9], size=[2, 3.5], glow=14)]


TODAY = {
    "fireball": [
        S(28, 0.05, at="target", tex=FIRE, shape=["sphere", [0, 1, 0], 0.2, False],
          vel=[[-5, 1, -5], [5, 6, 5]], acc=[0, -12, 0], exp=[0.4, 0.8], size=[1, 2], glow=14),
        S(10, 0.1, at="target", color="#3a2a22", shape=["sphere", [0, 1, 0], 0.4, False],
          vel=[[-0.6, 0.5, -0.6], [0.6, 1.5, 0.6]], exp=[0.8, 1.2], size=[3, 5], glow=0)],
    "ice_nova": [
        P(48, color="#bfe8ff", shape=["disc", [0, 0.25, 0], 0.4, True], radial="reach",
          exp=[0.34, 0.34], size=[2.5, 2.5], glow=10),
        S(16, 0.1, color="#e6f6ff", shape=["disc", [0, 0.15, 0], 0.6, False], radial=[3, 5],
          exp=[0.6, 0.8], size=[4, 6], glow=4)],
    "smite": [
        S(24, 0.12, at="target", color="#fff4c2", shape=["disc", [0, 3.3, 0], 0.9, False],
          attract={"origin": [0, 1, 0], "strength": 5, "kill": True}, exp=[0.25, 0.3],
          size=[2, 3], glow=14),
        S(12, 0.05, at="target", color="#ffe9a0", shape=["disc", [0, 0.15, 0], 0.3, True],
          radial=[4, 5], exp=[0.2, 0.3], size=[2, 2.5], glow=14)],
    "mighty_blow": [
        S(20, 0.08, color="#d8263a", shape=["line", [1.2, 2, -0.5], [1.2, 0.6, 0.6]],
          exp=[0.3, 0.4], size=[3, 4], glow=10),
        BLOOD6],
    "skill_arrow": [
        S(30, "frame", color="#e9e4d0", shape=["line", "frame"],
          vel=[[-0.2, -0.1, -0.2], [0.2, 0.2, 0.2]], exp=[0.3, 0.45], size=[1, 1.5], glow=6)],
    "charge_ring": [
        S(14, 0.05, at="target", color="#b8a27a", shape=["disc", [0, 0.1, 0], 0.5, True],
          radial=[4, 5], exp=[0.3, 0.45], size=[3, 4], glow=0)],
    "charge_dust": [
        S(18, "frame", color="#b8a27a", shape=["line", "frame"],
          vel=[[-0.5, 0.3, -0.5], [0.5, 1.2, 0.5]], exp=[0.4, 0.7], size=[2.5, 4], glow=0)],
    "hamstring": [
        P(6, at="target", color="#c0303f", shape=["line", [-0.4, 0.4, -0.3], [0.4, 0.35, 0.3]],
          exp=[0.25, 0.3], size=[2.5, 3], glow=8)],
    "taunt": [
        P(6, at="target", color="#ff8a3a", shape=["box", [-0.2, 2.1, -0.2], [0.2, 2.3, 0.2]],
          vel=[[-0.2, 1.2, -0.2], [0.2, 2, 0.2]], exp=[0.5, 0.7], size=[2.5, 3], glow=12)],
    "bellow": [
        P(40, color="#ff8a3a", shape=["disc", [0, 0.2, 0], 0.4, True], radial="reach",
          exp=[0.4, 0.4], size=[2.5, 2.5], glow=10)],
    "hold_ground": [
        S(24, 0.1, color="#e8c06a", shape=["disc", [0, 0.1, 0], 1, True],
          vel=[[0, 0.5, 0], [0, 1.2, 0]], exp=[0.7, 0.9], size=[2, 2.5], glow=12)],
    "blink": [
        S(14, 0.1, color="#b06aff", shape=["sphere", [0, 1, 0], 1, True],
          attract={"origin": [0, 1, 0], "strength": 3, "kill": True}, exp=[0.3, 0.4],
          size=[2, 2.5], glow=12),
        S(14, 0.05, at="target", color="#b06aff", shape=["sphere", [0, 1, 0], 0.2, False],
          radial=[3, 4], exp=[0.3, 0.4], size=[2, 2.5], glow=12)],
    "glacial_ward": [
        S(20, 0.2, color="#bfe8ff", shape=["sphere", [0, 1, 0], 1.1, True],
          attract={"origin": [0, 1, 0], "strength": 2.5, "kill": True}, exp=[0.4, 0.5],
          size=[2, 2.5], glow=10)],
    "heal": [
        S(12, 0.1, at="target", color="#d8f0a0", shape=["disc", [0, 0.1, 0], 0.5, False],
          vel=[[0, 1.5, 0], [0, 2.5, 0]], exp=[0.7, 0.9], size=[2, 2.5], glow=12)],
    "heal_splash": [
        S(4, 0.1, at="target", color="#d8f0a0", shape=["disc", [0, 0.1, 0], 0.5, False],
          vel=[[0, 1.5, 0], [0, 2.5, 0]], exp=[0.7, 0.9], size=[2, 2.5], glow=12)],
    "shield_spell": [
        S(18, 0.05, at="target", color="#ffe9a0", shape=["sphere", [0, 1, 0], 0.9, True],
          exp=[0.35, 0.45], size=[2, 2.5], glow=12)],
    "mend": [
        P(3, at="target", color="#d8f0a0", shape=["disc", [0, 0.6, 0], 0.4, False],
          vel=[[0, 1.2, 0], [0, 1.8, 0]], exp=[0.6, 0.8], size=[2, 2.5], glow=12)],
    "word_of_ruin": [
        S(16, 0.3, at="target", color="#6a2a9a", shape=["sphere", [0, 1, 0], 0.5, False],
          attract={"at": "caster", "origin": [0, 1.2, 0], "strength": 2, "kill": True},
          exp=[0.6, 0.7], size=[2, 2.5], glow=6)],
    "snare_hit": [
        S(10, 0.05, at="target", color="#79a65a", shape=["disc", [0, 0.4, 0], 0.2, True],
          radial=[2, 2.5], exp=[0.4, 0.5], size=[2, 2.5], glow=6)],
    "sidestep": [
        P(8, color="#a8e0c0", shape=["sphere", [0, 1, 0], 0.6, True],
          vel=[[0, 0.2, 0], [0, 0.6, 0]], exp=[0.35, 0.45], size=[2, 2.5], glow=10)],
    "sprint": [
        P(8, color="#b8a27a", shape=["box", [-0.6, 0.05, -0.3], [-0.2, 0.2, 0.3]],
          vel=[[-2, 0.5, -0.5], [-1, 1.5, 0.5]], exp=[0.4, 0.6], size=[3, 4], glow=0)],
    "opening": [
        P(6, at="target", color="#ffffff", shape=["sphere", [0, 1.1, 0], 0.15, False],
          vel=[[-2, -1, -2], [2, 2, 2]], exp=[0.15, 0.2], size=[1.5, 2], glow=14)],
    "proc": [
        P(8, color="#ffcf40", shape=["disc", [0, 0.3, 0], 0.6, True],
          vel=[[0, 1.5, 0], [0, 2.2, 0]], exp=[0.4, 0.5], size=[2, 2.5], glow=12)],
    "area_warning": _area_warning,
    "area_fall": _area_fall,
    "area_impact": _area_impact,
}
# Shipped function effects and the sample frame particles.register checks
# them with (particle_effects.lua).
TODAY_SAMPLE = {"area_warning": {"reach": 3, "time": 1.5},
                "area_fall": {"reach": 3, "time": 1.5, "height": 12},
                "area_impact": {"reach": 3}}

# --------------------------------------------------------------------------
# Skills (node-list.md §2-§4, skill-inventory.md §4): class, tree, family,
# cooldown or interval, occupied time after the cast (B2), and the builds of
# the scenario that use them. A build is one main tree (8 builds, one eighth
# of the fight's players each); its starters come in their transformed form
# where the tree transforms them (Cold Spark, Ice Nova, Retort, Bellow,
# Broadstroke, Bladecraft).
# --------------------------------------------------------------------------
CLASSES = [("mage", "Magier", ["ember", "rime"]), ("warrior", "Krieger", ["bulwark", "ruin"]),
           ("priest", "Priester", ["mercy", "reckoning"]), ("scout", "Späher", ["quarry", "veil"])]
SKILLS = {}


def skill(sid, name, cls, tree, unlock, cd=None, occ=0.0, builds=(), basic=None, use=None):
    SKILLS[sid] = {"id": sid, "name": name, "class": cls, "tree": tree, "family": tree if tree else "none",
                   "unlock": unlock, "cd": cd, "occ": occ, "builds": list(builds), "basic": basic,
                   "use": use}


# Mage
skill("fiery_spark", "Fiery Spark", "mage", "ember", "Start (ersetzt Strike)", occ=1.0, builds=["ember"], basic=1.0)
skill("ice_wave", "Ice Wave", "mage", "rime", "Start", cd=12, occ=1.0, builds=["ember"])
skill("fireball", "Fireball", "mage", "ember", "Ember F4", cd=5, occ=1.0, builds=["ember"])
skill("flame_lance", "Flame Lance", "mage", "ember", "Ember F5", cd=8, occ=1.5, builds=["ember"])
skill("meteor", "Meteor", "mage", "ember", "Ember F8", cd=18, occ=1.0, builds=["ember"])
skill("fire_rain", "Fire Rain", "mage", "ember", "Ember F12, Ultimate", cd=60, occ=1.5, builds=["ember"])
skill("cold_spark", "Cold Spark", "mage", "rime", "Rime R1, verwandelt Fiery Spark", occ=1.0, builds=["rime"], basic=1.0)
skill("blink", "Blink", "mage", "rime", "Rime R4", cd=20, builds=["rime"])
skill("rime_mantle", "Rime Mantle", "mage", "rime", "Rime R7", cd=24, builds=["rime"])
skill("ice_nova", "Ice Nova", "mage", "rime", "Rime R9, verwandelt Ice Wave", cd=18, occ=1.0, builds=["rime"])
skill("winter_field", "Winter Field", "mage", "rime", "Rime R13, Ultimate", cd=60, occ=1.0, builds=["rime"])
# Warrior (self casts 0.35 s; swing procs replace a swing)
skill("strike", "Strike", "warrior", "bulwark", "Start (universell)", builds=[])
skill("charge", "Charge", "warrior", "ruin", "Start", cd=10, occ=0.35, builds=["bulwark", "ruin"])
skill("retort", "Retort", "warrior", "bulwark", "Bulwark B1, verwandelt Strike", builds=["bulwark"], use=1 / 6)
skill("hold_ground", "Hold Ground", "warrior", "bulwark", "Bulwark B4", cd=24, occ=0.35, builds=["bulwark"])
skill("taunt", "Taunt", "warrior", "bulwark", "Bulwark B7", cd=8, occ=0.35, builds=[])
skill("bellow", "Bellow", "warrior", "bulwark", "Bulwark B9, verwandelt Taunt", cd=8, occ=0.35, builds=["bulwark"])
skill("unbroken", "Unbroken", "warrior", "bulwark", "Bulwark B12, Ultimate", cd=60, occ=0.35, builds=["bulwark"])
skill("mighty_blow", "Mighty Blow", "warrior", "ruin", "Ruin U1", builds=[], use=1 / 3)
skill("hamstring", "Hamstring", "warrior", "ruin", "Ruin U4", builds=["ruin"], use=1 / 8)
skill("broadstroke", "Broadstroke", "warrior", "ruin", "Ruin U7, verwandelt Mighty Blow", builds=["ruin"], use=1 / 3)
skill("ruination", "Ruination", "warrior", "ruin", "Ruin U12, Ultimate", cd=60, occ=0.35, builds=["ruin"])
# Priest (casts 1 s unless the inventory says otherwise)
skill("smite", "Smite", "priest", "reckoning", "Start (ersetzt Strike)", occ=1.0, builds=["mercy", "reckoning"], basic=1.0)
skill("heal", "Heal", "priest", "mercy", "Start", cd=5, occ=1.5, builds=["mercy", "reckoning"])
skill("shield", "Shield", "priest", "mercy", "Mercy M3", cd=12, occ=1.0, builds=["mercy"])
skill("mend", "Mend", "priest", "mercy", "Mercy M6", cd=8, occ=1.0, builds=["mercy"])
skill("hearten", "Hearten", "priest", "mercy", "Mercy M10", cd=20, occ=1.5, builds=["mercy"])
skill("haven", "Haven", "priest", "mercy", "Mercy M13, Ultimate", cd=60, occ=1.5, builds=["mercy"])
skill("rebuke", "Rebuke", "priest", "reckoning", "Reckoning RK3", cd=6, occ=1.0, builds=["reckoning"])
skill("word_of_ruin", "Word of Ruin", "priest", "reckoning", "Reckoning RK6", cd=16, occ=1.0, builds=["reckoning"])
skill("censure", "Censure", "priest", "reckoning", "Reckoning RK9", cd=18, occ=1.0, builds=["reckoning"])
skill("final_word", "Final Word", "priest", "reckoning", "Reckoning RK13, Ultimate", cd=60, occ=1.5, builds=["reckoning"])
# Scout
skill("loose", "Loose", "scout", "quarry", "Start", occ=0.85, builds=["quarry"], basic=0.85)
skill("sidestep", "Sidestep", "scout", "quarry", "Start", cd=18, occ=0.25, builds=["quarry", "veil"])
skill("sprint", "Sprint", "scout", "quarry", "Start (angeboren)", cd=300, builds=["quarry", "veil"])
skill("true_draw", "True Draw", "scout", "quarry", "Quarry Q4", cd=6, occ=1.35, builds=["quarry"])
skill("snare_shot", "Snare Shot", "scout", "quarry", "Quarry Q6", cd=14, occ=0.85, builds=["quarry"])
skill("split_shot", "Split Shot", "scout", "quarry", "Quarry Q8", cd=10, occ=1.0, builds=["quarry"])
skill("arrowfall", "Arrowfall", "scout", "quarry", "Quarry Q12, Ultimate", cd=60, occ=2.5, builds=["quarry"])
skill("bladecraft", "Bladecraft", "scout", "veil", "Veil V1, verwandelt Loose", builds=["veil"], use=0.2)
skill("opening", "Opening", "scout", "veil", "Veil V4", cd=8, builds=["veil"])
skill("parry", "Parry", "scout", "veil", "Veil V6", cd=12, occ=0.5, builds=["veil"])
skill("flourish", "Flourish", "scout", "veil", "Veil V8", cd=12, occ=1.0, builds=["veil"])
skill("close_dance", "Close Dance", "scout", "veil", "Veil V12, Ultimate", cd=60, occ=0.25, builds=["veil"])
assert len(SKILLS) == 44, len(SKILLS)


def build_rates():
    """Uses per second of each skill in each build at full pace: a cooldown
    skill once per cooldown, a proc at its own pace, the basic attack in the
    time the build's other casts leave free (their occupied time)."""
    rates = {}
    for b in ("ember", "rime", "bulwark", "ruin", "mercy", "reckoning", "quarry", "veil"):
        busy, basic = 0.0, None
        for s in SKILLS.values():
            if b not in s["builds"]:
                continue
            if s["basic"]:
                basic = s
            elif s["cd"]:
                rates[(b, s["id"])] = 1 / s["cd"]
                busy += s["occ"] / s["cd"]
            elif s["use"]:
                rates[(b, s["id"])] = s["use"]
        if basic:
            rates[(b, basic["id"])] = max(0.0, 1 - busy) / basic["basic"]
    return rates


RATES = build_rates()

# --------------------------------------------------------------------------
# The cards
# --------------------------------------------------------------------------
CARDS = []


def card(skill_id, moment, status, look, emitters=(), *, id=None, hook="", today="", today_id=None,
         note="", sprite=None, sample=None, dynamic="", target=None, per_use=1.0, t0=0.0,
         context=(), flight=None, marker=None, color=None, family=None, rate=None):
    """moment: cast, trail, impact, hit, warning, fall, tick, window, recipient,
    swing, dash, arrival, none. per_use: how often the moment happens per use
    of the skill (ticks, recipients, secondaries). t0: seconds after the use
    (the page plays the card at that time after its context). context: keys of
    the same skill's cards the preview plays dimmed around it. rate: uses per
    second of the moment per player of a using build, when it is not the
    skill's own (windows)."""
    s = SKILLS[skill_id]
    CARDS.append({"skill": skill_id, "moment": moment, "status": status, "look": look,
                  "emitters": emitters, "id": id, "hook": hook, "today": today, "today_id": today_id,
                  "note": note, "sprite": sprite, "sample": sample or {}, "dynamic": dynamic,
                  "target": target or TARGET, "per_use": per_use, "t0": t0, "context": list(context),
                  "flight": flight, "marker": marker, "color": color,
                  "family": family or s["family"], "rate": rate,
                  "key": "pfx.%s.%s" % (skill_id, moment)})


E, R, B, U = T["ember"], T["rime"], T["bulwark"], T["ruin"]
M, K, Q, V = T["mercy"], T["reckoning"], T["quarry"], T["veil"]

# ---- Mage · Ember --------------------------------------------------------
card("fiery_spark", "impact", "new", id="spark_hit",
     look="Wo der Funke trifft, springen fünf Glutfunken heraus und fallen zurück. Klein genug für den "
          "Grundangriff, der jede Sekunde fliegt.",
     emitters=[P(5, at="target", tex=FIRE, shape=["sphere", [0, 1, 0], 0.15, False],
                 vel=[[-1.5, 0.5, -1.5], [1.5, 2.5, 1.5]], acc=[0, -9, 0], exp=[0.3, 0.45],
                 size=[1.2, 1.8], glow=14)],
     hook="Fiery Spark's projectile on_hit (kits_mage.lua: the new spark projectile, before the damage), "
          "like today's fireball on_hit (kits_mage.lua:33)",
     today="Der Grundangriff ist Fireball: bei jedem Treffer der volle Fireball-Spritzer (38 Partikel, "
           "zwei Spawner), etwa einmal pro Sekunde.", today_id="fireball",
     flight={"speed": 20, "size": 0.45, "color": "#ffb347"},
     note="Das Geschoss selbst ist ein Objekt (der Feuer-Sprite), kein Partikel: kleiner als beim Fireball "
          "(0,45 statt 0,7) kostet nichts extra.")
card("fireball", "impact", "keep", id="fireball",
     look="Glut spritzt in einer Halbkugel aus dem Einschlag und fällt zurück, dazu ein kurzer dunkler Rauch. "
          "Der angenommene Spritzer aus Runde 40, jetzt nur noch alle 5 s statt jede Sekunde.",
     emitters=TODAY["fireball"], hook="the Fireball projectile's on_hit (kits_mage.lua:33)",
     today="genau dieser Spritzer (heute bei jedem Grundangriff)", today_id="fireball",
     flight={"speed": 20, "size": 0.7, "color": "#ff8a3a"})
card("flame_lance", "trail", "new", id="flame_lance_trail",
     look="Eine weißglühende Flammenspur entlang der Flugbahn: die Lanze zieht für einen Augenblick eine "
          "gerade Feuerlinie, die sofort verglüht.",
     emitters=[S(24, "frame", tex=FIRE, shape=["line", "frame"],
                 vel=[[-0.3, -0.1, -0.3], [0.3, 0.4, 0.3]], exp=[0.2, 0.3], size=[2, 3], glow=14)],
     sample={"from": [0.5, 1.4, 0], "to": [12, 1.0, 0], "time": 0.33}, target=[12, 0, 0],
     dynamic="line frame.from..frame.to over frame.time: grug_projectiles' trail (init.lua:262-284), "
             "params.trail = {effect = \"flame_lance_trail\"}",
     hook="Flame Lance's launch: grug_projectiles.spawn(..., {trail = ...}) as the skill arrows do "
          "(scout.lua:11-15, grug_projectiles/init.lua:269)",
     flight={"speed": 35, "size": 0.6, "color": "#fff0c8"},
     note="Ein ungebundener Spawner längs der Fluglinie (höchstens 1 s): nur Spieler in der Nähe bekommen ihn. "
          "Ein an das Geschoss gehängter Spawner ginge an jeden Spieler des Servers.")
card("flame_lance", "impact", "new", id="flame_lance_hit",
     look="Ein kurzer weißgelber Blitz aus acht Funken am Ziel, schneller und heller als der Fireball, ohne "
          "Rauch.",
     emitters=[P(8, at="target", color=E["white"], shape=["sphere", [0, 1, 0], 0.15, False],
                 vel=[[-3, 0, -3], [3, 3, 3]], acc=[0, -6, 0], exp=[0.2, 0.35], size=[2, 3], glow=14)],
     target=[12, 0, 0], t0=0.33, context=["pfx.flame_lance.trail"],
     hook="Flame Lance's projectile on_hit (kits_mage.lua, new def)")
card("meteor", "warning", "keep", id="area_warning",
     look="Ein Ring aus 20 glühenden Punkten markiert den Einschlag (3 m) und steht die ganze Verzögerung "
          "von 1,5 s. CORE-Bs Warnring, unverändert.",
     emitters=_area_warning, sample={"reach": 3, "time": 1.5}, target=[10, 0, 0],
     dynamic="reach = the radius (3 m + Broad Impact), time = the delay; no spec.color (area.delayed "
             "would pass it to warning, fall and impact alike; the default warning is already #ffb347)",
     hook="area.delayed (grug_core/area.lua:318): spec.warning default", context=["pfx.meteor.fall"],
     marker={"radius": 3, "at": "target"})
card("meteor", "fall", "new", id="meteor_fall",
     look="Ein brennender Brocken stürzt schräg aus der Höhe genau zum Ende der Verzögerung auf den Punkt: ein "
          "großer Kopf und zwei kleiner werdende Glutstücke dahinter, alle gleich schnell, wie ein Komet. Er "
          "erscheint erst spät und fällt mit 14 m/s, ohne zu verblassen (überarbeitet am 21.10.).",
     emitters=lambda f: _comet(f, FIRE, [14, 9, 5], METEOR_FALL_SPEED), sample={"reach": 3, "time": 1.5, "height": 10},
     target=[10, 0, 0],
     dynamic="height = area.fall_height (below the first solid node, at most 12), time = the delay; "
             "none below 1.5 m (area.lua MIN_FALL); it falls at METEOR_FALL_SPEED for "
             "min(time, height / speed) and starts after the rest of the delay",
     hook="area.delayed spec.fall = \"meteor_fall\"", context=["pfx.meteor.warning"],
     sprite={"name": "Meteor-Brocken", "stand_in": "rock",
             "text": "Ein brennender Gesteinsbrocken (16×16, dunkle Kruste, glühende Risse) für den Kopf; "
                     "bis dahin der Feuer-Sprite."},
     today="Cinderfall heute: 36 Glutpartikel regnen 0,4 s lang auf den Kreis.",
     note="Drei einzelne Partikel statt eines Regens: \"Größe statt Anzahl\". Große fallende Partikel erlaubt "
          "C3 ausdrücklich.", marker={"radius": 3, "at": "target"})
card("meteor", "impact", "new", id="meteor_impact",
     look="Beim Einschlag schießt ein Glutring bis an den 3-m-Rand und Funken spritzen hoch und fallen zurück.",
     emitters=lambda f: [P(32, at="target", color=E["core"], shape=["disc", [0, 0.2, 0], 0.4, True],
                           radial="reach", exp=[0.3, 0.3], size=[3, 3], glow=12),
                         S(20, 0.1, at="target", tex=FIRE, shape=["disc", [0, 0.3, 0], 0.8 * f["reach"], False],
                           vel=[[-1.5, 2, -1.5], [1.5, 5, 1.5]], acc=[0, -9, 0], exp=[0.4, 0.7],
                           size=[2, 3.5], glow=14)],
     sample={"reach": 3}, target=[10, 0, 0], t0=1.5,
     context=["pfx.meteor.warning", "pfx.meteor.fall"],
     dynamic="reach = the radius (ring lands on it; spray disc 0.8 x reach)",
     hook="area.delayed spec.burst = \"meteor_impact\"",
     today="CORE-Bs Vorgabe area_impact: 40 Ringpunkte und 30 Spritzer in einer Farbe.",
     today_id="area_impact", marker={"radius": 3, "at": "target"})
card("fire_rain", "warning", "keep", id="area_warning",
     look="Derselbe Warnring wie beim Meteor, auf 5 m: 20 Punkte für 1,5 s.",
     emitters=_area_warning, sample={"reach": 5, "time": 1.5}, target=[10, 0, 0],
     dynamic="reach = the radius (5 m + Spreading Rain), time = the delay; no spec.color (the default "
             "warning is already #ffb347)",
     hook="area.delayed spec.warning default", context=["pfx.fire_rain.fall"],
     marker={"radius": 5, "at": "target"})
card("fire_rain", "fall", "new", id="fire_rain_fall",
     look="Ein Feuerregen: eine Sekunde lang fallen 40 Flammen senkrecht über dem Kreis, jede 0,5 s unterwegs, "
          "so dass der Regen ab der halben Verzögerung auf den Boden trifft und mit dem Einschlag endet.",
     emitters=lambda f: [S(40, 1, at="target", tex=FIRE,
                           shape=["box", [-0.7 * f["reach"], min(f["height"], 8), -0.7 * f["reach"]],
                                  [0.7 * f["reach"], min(f["height"], 8), 0.7 * f["reach"]]],
                           vel=[[0, -2 * min(f["height"], 8), 0], [0, -2 * min(f["height"], 8), 0]],
                           exp=[0.5, 0.5], size=[4, 6], glow=14)],
     sample={"reach": 5, "time": 1.5, "height": 8}, target=[10, 0, 0],
     dynamic="height = min(area.fall_height, 8): starts there, falls 2 x height per second (0.5 s); "
             "the box spans 0.7 x reach",
     hook="area.delayed spec.fall = \"fire_rain_fall\"", context=["pfx.fire_rain.warning"],
     today="Cinderfall heute: 36 Glutpartikel in 0,4 s aus 4 m (dasselbe Muster, hier größer und länger).",
     marker={"radius": 5, "at": "target"},
     note="Ein Spawner über die volle erlaubte Sekunde. Die Partikel fallen nur senkrecht, also sieht er aus "
          "jeder Blickrichtung gleich aus (die Bereiche eines Spawners drehen nicht mit).")
card("fire_rain", "impact", "new", id="fire_rain_impact",
     look="Der große Einschlag: ein Glutring rast bis an den 5-m-Rand, Flammen springen über die ganze Fläche "
          "hoch.",
     emitters=lambda f: [P(40, at="target", color=E["hot"], shape=["disc", [0, 0.2, 0], 0.5, True],
                           radial="reach", exp=[0.35, 0.35], size=[3, 3.5], glow=12),
                         S(36, 0.15, at="target", tex=FIRE, shape=["disc", [0, 0.3, 0], 0.8 * f["reach"], False],
                           vel=[[-2, 3, -2], [2, 6, 2]], acc=[0, -9, 0], exp=[0.5, 0.9], size=[2.5, 4],
                           glow=14)],
     sample={"reach": 5}, target=[10, 0, 0], t0=1.5,
     context=["pfx.fire_rain.warning", "pfx.fire_rain.fall"],
     dynamic="reach = the radius", hook="area.delayed spec.burst = \"fire_rain_impact\"",
     marker={"radius": 5, "at": "target"})
card("ice_wave", "cast", "new", id="ice_wave",
     look="Ein Fächer aus Frostflocken fährt vor dem Magier über den 70°-Kegel und verlischt am 5-m-Rand.",
     emitters=[P(10, color=R["pale"], shape=["box", [0.4, 1.0, -0.2], [0.6, 1.3, 0.2]],
                 vel=[[9, -0.5, -6], [12, 0.5, 6]], exp=[0.38, 0.42], size=[2.5, 3.5], glow=10)],
     hook="Ice Wave's cast after its last refusal (kits_mage.lua, new def)",
     marker={"cone": [5, 70]}, family="rime",
     note="Einzelne Partikel, weil ihre Geschwindigkeit mit der Blickrichtung dreht (die eines Spawners "
          "bliebe an der Welt ausgerichtet und flöge immer nach Osten).",
     sprite={"name": "Schneeflocke", "stand_in": "flake",
             "text": "Eine kleine Schneeflocke (5×5 oder 8×8) für alle Frost-Effekte; die Runde-40-Notiz nennt "
                     "VoxeLibres weather_pack_snow_snowflake (CC BY-SA 3.0)."})
# ---- Mage · Rime ---------------------------------------------------------
card("cold_spark", "impact", "new", id="cold_spark_hit",
     look="Vier Frostsplitter springen am Ziel kurz auf und sinken langsam.",
     emitters=[P(4, at="target", color=R["white"], shape=["sphere", [0, 1, 0], 0.15, False],
                 vel=[[-1, 0.3, -1], [1, 1.5, 1]], acc=[0, -4, 0], exp=[0.35, 0.5], size=[1.5, 2],
                 glow=10)],
     hook="Cold Spark's projectile on_hit (kits_mage.lua, new def)",
     flight={"speed": 20, "size": 0.45, "color": "#bfe8ff"},
     note="Das Geschoss ist der Funken-Sprite in Frostfarbe (eine Objekteigenschaft, kostenlos).",
     sprite={"name": "Schneeflocke", "stand_in": "flake", "text": "dieselbe Schneeflocke"})
card("cold_spark", "window", "keep", id="proc",
     look="Cold Shock bereit (eine Nova hat getroffen): der bekannte Bereitschaftsring aus acht Punkten steigt "
          "um den Magier auf, in Frostblau.",
     emitters=recolor(TODAY["proc"], R["pale"]), color=R["pale"],
     hook="grug_classes.open_window (talent_windows.lua:93) for Cold Shock: grug_core.proc_flash(player, "
          "\"cold_shock\") with PROC_COLORS.cold_shock = \"#bfe8ff\"",
     rate=1 / 18, today="der Proc-Ring (heute in Gelb für White-Hot)",
     note="Der Proc-Ring bleibt der eine Bereitschaftseffekt; jede Bereitschaft bekommt nur ihre Farbe.")
card("blink", "cast", "retint", id="blink",
     look="Frostflocken stürzen in die Stelle, die der Magier verlässt, und platzen am Ankunftsort auseinander. "
          "Die Form aus Runde 40, jetzt Frost statt Violett.",
     emitters=recolor(TODAY["blink"], R["pale"]), target=[10, 0, 0],
     hook="Blink's cast (kits_mage.lua:243)", today="dieselbe Form in Violett (#b06aff)")
card("rime_mantle", "cast", "keep", id="glacial_ward",
     look="Frostflocken erscheinen auf einer Hülle um den Magier und ziehen nach innen: Glacial Wards Effekt, "
          "unverändert für Rime Mantle.",
     emitters=TODAY["glacial_ward"], hook="Rime Mantle's cast (as Glacial Ward, kits_mage.lua:289)",
     today="genau dieser Effekt bei Glacial Ward")
card("ice_nova", "cast", "keep", id="ice_nova",
     look="Ein flacher Ring aus Frostflocken schießt bis an den 5-m-Rand, darunter ein langsamer Nebel. "
          "Unverändert aus Runde 40; die Wurzelkristalle an jedem festgehaltenen Gegner bleiben auch.",
     emitters=TODAY["ice_nova"], sample={"reach": 5},
     dynamic="reach = the nova's radius (5 m + Far Frost)", hook="Ice Nova's cast (kits_mage.lua:205)",
     marker={"radius": 5}, today="genau dieser Effekt")
card("winter_field", "warning", "new", id="winter_field_warning",
     look="Der Warnring auf 4 m, eine Sekunde lang, in Frostblau: CORE-Bs Warnring in Frostfarbe.",
     emitters=lambda f: recolor(_area_warning(f), R["pale"]),
     sample={"reach": 4, "time": 1.0}, target=[10, 0, 0],
     dynamic="a recolour of area_warning: reach = 4 m, time = the delay (1 s); no spec.color, which "
             "would repaint the fall and the impact too (area.lua:327-355)",
     hook="area.delayed spec.warning = \"winter_field_warning\"", context=["pfx.winter_field.fall"],
     marker={"radius": 4, "at": "target"})
card("winter_field", "fall", "new", id="winter_field_fall",
     look="Ein Schneegestöber: eine Sekunde lang rieseln 36 große Flocken aus bis zu 5 m Höhe in den Kreis, "
          "langsam und leicht seitlich treibend; sie fallen über den Einschlag hinaus weiter.",
     emitters=lambda f: [S(36, 1, at="target", color=R["white"],
                           shape=["box", [-0.7 * f["reach"], min(f["height"], 5), -0.7 * f["reach"]],
                                  [0.7 * f["reach"], min(f["height"], 5), 0.7 * f["reach"]]],
                           vel=[[-0.4, -4, -0.4], [0.4, -3, 0.4]], exp=[1.2, 1.6], size=[3, 4], glow=8)],
     sample={"reach": 4, "time": 1.0, "height": 8}, target=[10, 0, 0],
     dynamic="height = min(area.fall_height, 5); the box spans 0.7 x reach",
     hook="area.delayed spec.fall = \"winter_field_fall\"", context=["pfx.winter_field.warning"],
     marker={"radius": 4, "at": "target"},
     sprite={"name": "Schneeflocke", "stand_in": "flake", "text": "dieselbe Schneeflocke, hier groß"})
card("winter_field", "impact", "new", id="winter_field_impact",
     look="Ein Frostring schnellt auf 4 m hinaus, danach liegt ein flacher Frostnebel kurz über dem Feld.",
     emitters=lambda f: [P(40, at="target", color=R["pale"], shape=["disc", [0, 0.2, 0], 0.4, True],
                           radial="reach", exp=[0.35, 0.35], size=[2.5, 3], glow=10),
                         S(24, 0.2, at="target", color=R["mist"], shape=["disc", [0, 0.15, 0], 0.8 * f["reach"], False],
                           vel=[[-0.3, 0.1, -0.3], [0.3, 0.4, 0.3]], exp=[1.2, 1.8], size=[4, 6], glow=6)],
     sample={"reach": 4}, target=[10, 0, 0], t0=1.0,
     context=["pfx.winter_field.warning", "pfx.winter_field.fall"],
     dynamic="reach = the radius", hook="area.delayed spec.burst = \"winter_field_impact\"",
     marker={"radius": 4, "at": "target"})
# ---- Warrior · Bulwark ---------------------------------------------------
card("strike", "swing", "none",
     look="Kein Effekt: Strike bekommt keinen (Runde-40-Regel), auch nicht als Rückfall einer Fähigkeit, die "
          "gerade abklingt.", family="none")
card("retort", "window", "keep", id="proc",
     look="Retort bereit (ein Treffer hat Leben gekostet): der Bereitschaftsring in Stahlgrau.",
     emitters=recolor(TODAY["proc"], B["steel"]), color=B["steel"],
     hook="grug_classes.open_window for Retort (the settled-hit hook): grug_core.proc_flash(player, \"retort\")",
     rate=1 / 6, note="Höchstens alle 6 s (die interne Abklingzeit).")
card("retort", "hit", "new", id="retort_hit",
     look="Der vorbereitete Gegenschlag landet: sechs stahlweiße Funken springen vom Ziel ab, ein kurzes "
          "metallisches Aufblitzen.",
     emitters=[P(6, at="target", color=B["white"], shape=["sphere", [0, 1.1, 0], 0.1, False],
                 vel=[[-2.5, -0.5, -2.5], [2.5, 2.5, 2.5]], acc=[0, -8, 0], exp=[0.15, 0.25],
                 size=[1.2, 1.8], glow=14)],
     target=MELEE, hook="Retort's landed readied swing (the window consumed), kits_warrior.lua",
     sprite={"name": "Funke", "stand_in": "spark",
             "text": "Ein kleiner vierzackiger Funke (5×5) für Stahl, Schatten-Silber und das Gericht; die "
                     "Runde-40-Notiz wollte ihn für Smite."})
card("charge", "dash", "keep", id="charge_dust",
     look="Staub, der entlang des Sturmwegs am Boden aufwirbelt. Unverändert.",
     emitters=TODAY["charge_dust"], sample={"from": [0, 0.1, 0], "to": [4.7, 0.1, 0], "time": 0.5},
     dynamic="line frame.from..frame.to over frame.time (grug_abilities.charge_dust)",
     hook="charge.lua:127 (charge_dust)", family="ruin", target=[6, 0, 0], context=["pfx.charge.arrival"],
     today="genau dieser Effekt")
card("charge", "arrival", "keep", id="charge_ring",
     look="Bei der Ankunft ein flacher Staubring um das Ziel. Unverändert.",
     emitters=TODAY["charge_ring"], hook="charge.lua:158", family="ruin", t0=0.5,
     context=["pfx.charge.dash"], today="genau dieser Effekt")
card("hold_ground", "cast", "retint", id="hold_ground",
     look="Ein Bronzering um die Füße, der langsam aufsteigt: die Form aus Runde 40 in Bronze statt Gold.",
     emitters=recolor(TODAY["hold_ground"], B["bronze"]), hook="Hold Ground's cast (kits_warrior.lua:237)",
     today="dieselbe Form in Gold (#e8c06a)")
card("taunt", "cast", "retint", id="taunt",
     look="Ein paar Bronzefunken springen über dem Kopf des Gegners hoch und hängen kurz dort.",
     emitters=recolor(TODAY["taunt"], B["bronze"]), hook="Taunt's cast (kits_warrior.lua:218)",
     today="dieselbe Form in Orange (#ff8a3a)")
card("bellow", "cast", "retint", id="bellow",
     look="Ein stahlgrauer Stoßring läuft am Boden vom Krieger bis an den 6-m-Rand.",
     emitters=recolor(TODAY["bellow"], B["steel"]), sample={"reach": 6},
     dynamic="reach = the Bellow radius (6 m)", hook="Bellow's cast (kits_warrior.lua:200)",
     marker={"radius": 6}, today="dieselbe Form in Orange")
card("unbroken", "cast", "new", id="unbroken",
     look="Stahlsplitter schlagen von einer Hülle nach innen auf den Krieger ein, gleichzeitig drückt ein "
          "Bronzering an den Füßen nach außen: er steht.",
     emitters=[S(22, 0.15, color=B["steel"], shape=["sphere", [0, 1, 0], 1.2, True],
                 attract={"origin": [0, 1, 0], "strength": 3, "kill": True}, exp=[0.3, 0.35],
                 size=[2, 3], glow=12),
               S(16, 0.05, color=B["bronze"], shape=["disc", [0, 0.1, 0], 0.5, True], radial=[3, 4],
                 exp=[0.35, 0.45], size=[2.5, 3], glow=10)],
     hook="Unbroken's cast (kits_warrior.lua, new def)",
     today="der heutige passive Unbroken-Proc spielt den Proc-Ring (fällt in Runde K weg)", today_id="proc")
# ---- Warrior · Ruin ------------------------------------------------------
card("mighty_blow", "swing", "keep", id="mighty_blow",
     look="Eine rote Diagonale hängt vor dem Krieger und verlischt in einer Drittelsekunde, dazu die sechs "
          "Blutstropfen am Ziel. Unverändert.",
     emitters=TODAY["mighty_blow"], target=MELEE, hook="kits_warrior.lua:111 (the landed proc)",
     today="genau dieser Effekt")
card("broadstroke", "swing", "new", id="broadstroke",
     look="Ein waagrechter roter Hieb läuft in 0,12 s von links nach rechts über die ganze Front. Ohne die "
          "sechs extra Blutstropfen von Mighty Blow: die Gegner bluten bei jedem Treffer ohnehin.",
     emitters=[S(22, 0.12, color=U["crimson"], shape=["line", [1.4, 1.2, 1.9], [1.4, 1.0, -1.9]],
                 exp=[0.3, 0.4], size=[3, 4], glow=10)],
     target=MELEE, hook="Broadstroke's landed proc (kits_warrior.lua, where mighty_blow plays today)",
     marker={"cone": [3, 100]}, today="Mighty Blows Diagonale", today_id="mighty_blow",
     note="Die Linie dreht mit der Blickrichtung (nur ihre Enden, das reicht), und weil der Spawner seine "
          "Position über die Zeit verschiebt, sieht man den Hieb wandern.")
card("hamstring", "swing", "keep", id="hamstring",
     look="Ein kurzer, tiefer roter Schnitt über die Beine des Ziels. Unverändert.",
     emitters=TODAY["hamstring"], target=MELEE, hook="kits_warrior.lua:170", today="genau dieser Effekt")
card("ruination", "cast", "new", id="ruination",
     look="Eine rote Lohe schießt um die Füße des Kriegers hoch: 30 heiße Funken, die steil aufsteigen und "
          "verglühen.",
     emitters=[S(30, 0.2, color=U["flare"], shape=["disc", [0, 0.1, 0], 0.7, False],
                 vel=[[0, 2.5, 0], [0, 4.5, 0]], exp=[0.35, 0.55], size=[2, 3], glow=14)],
     hook="Ruination's cast (kits_warrior.lua, new def; replaces the ruination proc flash, "
          "kits_warrior.lua:121)", today="der Proc-Ring in Rot (#ff5a3a)", today_id="proc")
card("ruination", "swing", "new", id="ruination_swing",
     look="Solange Ruination läuft, wirft jeder gelandete Schlag drei heiße Funken vom Ziel.",
     emitters=[P(3, at="target", color=U["hot"], shape=["sphere", [0, 1.1, 0], 0.2, False],
                 vel=[[-1, 0.5, -1], [1, 2, 1]], acc=[0, -6, 0], exp=[0.25, 0.35], size=[1.5, 2], glow=14)],
     target=MELEE, per_use=8, t0=0.6, context=["pfx.ruination.cast"],
     hook="the swing path's landed hit while the Ruination window is active (kits.lua strike_def)",
     note="Etwa acht Schläge im 8-s-Fenster.")
# ---- Priest · Mercy ------------------------------------------------------
card("heal", "cast", "retint", id="heal",
     look="Warmgoldene Punkte steigen um den Geheilten auf. Die Form aus Runde 40, Gold statt Grüngelb.",
     emitters=recolor(TODAY["heal"], M["gold"]), hook="Heal's cast (kits_priest.lua:135)",
     today="dieselbe Form in Grüngelb (#d8f0a0)")
card("shield", "cast", "keep", id="shield_spell",
     look="Eine blassgoldene Hülle aus Punkten blitzt um den Geschützten auf. Unverändert.",
     emitters=TODAY["shield_spell"], hook="kits_priest.lua:186", today="genau dieser Effekt")
card("mend", "tick", "retint", id="mend",
     look="Drei warmgoldene Punkte steigen beim Wirken und bei jedem der vier Ticks auf.",
     emitters=recolor(TODAY["mend"], M["gold"]), per_use=8 / 3,
     hook="Mend's cast and on_tick (kits_priest.lua:244, 249)", today="dieselbe Form in Grüngelb",
     note="Im Szenario tickt Mend dauernd auf einem Ziel (alle 3 s) und wird alle 8 s neu gewirkt.")
card("smite", "window", "keep", id="proc",
     look="Clear Conscience bereit (nach Heal, Shield oder Mend): der Bereitschaftsring in Elfenbein.",
     emitters=recolor(TODAY["proc"], M["ivory"]), color=M["ivory"],
     hook="grug_classes.open_window for Clear Conscience: grug_core.proc_flash(player, \"clear_conscience\")",
     rate=1 / 8, family="mercy", note="Höchstens alle 8 s (die interne Abklingzeit).")
card("hearten", "cast", "new", id="hearten",
     look="Ein weicher Goldring breitet sich vom Priester bis an den 6-m-Rand aus: so weit reicht die Heilung.",
     emitters=[P(24, color=M["gold"], shape=["disc", [0, 0.3, 0], 0.4, True], radial="reach",
                 exp=[0.5, 0.5], size=[2.5, 2.5], glow=12)],
     sample={"reach": 6}, dynamic="reach = 6 m", hook="Hearten's cast (kits_priest.lua, new def)",
     marker={"radius": 6})
card("hearten", "recipient", "new", id="hearten_recipient",
     look="Jeder Geheilte (bis zu vier, der Priester eingeschlossen): vier Goldpunkte steigen auf.",
     emitters=[P(4, at="target", color=M["gold"], shape=["disc", [0, 0.1, 0], 0.4, False],
                 vel=[[0, 1.5, 0], [0, 2.2, 0]], exp=[0.6, 0.8], size=[2, 2.5], glow=12)],
     target=[3, 0, 0], per_use=4, t0=0.05, context=["pfx.hearten.cast"],
     hook="Hearten's loop over area.group's recipients",
     today="Heals Spritzer (Hearten-Talent) heute: ein Spawner aus 4 Partikeln je Verbündetem",
     today_id="heal_splash",
     note="Vier Partikel als einzelne kosten ein Drittel eines Spawners, der für 4 Partikel ein ganzes "
          "Paket schickt.")
card("haven", "cast", "new", id="haven",
     look="Eine Säule aus warmem Licht steigt um den Priester auf, während ein Ring aus Elfenbein bis an den "
          "8-m-Rand läuft.",
     emitters=[P(40, color=M["ivory"], shape=["disc", [0, 0.3, 0], 0.5, True], radial="reach",
                 exp=[0.7, 0.7], size=[3, 3], glow=12),
               S(24, 0.3, color=M["gold"], shape=["disc", [0, 0.1, 0], 1.0, False],
                 vel=[[0, 2, 0], [0, 3.5, 0]], exp=[0.8, 1.0], size=[2, 3], glow=12)],
     sample={"reach": 8}, dynamic="reach = 8 m", hook="Haven's cast (kits_priest.lua, new def)",
     marker={"radius": 8})
card("haven", "tick", "new", id="haven_tick",
     look="Jeder Tick der Heilung über Zeit: zwei Elfenbeinpunkte steigen am Träger auf (bis zu fünf Träger, "
          "sechs Ticks).",
     emitters=[P(2, at="target", color=M["ivory"], shape=["disc", [0, 0.8, 0], 0.35, False],
                 vel=[[0, 1, 0], [0, 1.5, 0]], exp=[0.6, 0.8], size=[2, 2.5], glow=12)],
     target=[3, 0, 0], per_use=30, hook="the haven status' on_tick (grug_core.set_status)",
     note="Zwei statt Mends drei, damit beide Heilungen über Zeit auf einem Spieler unterscheidbar bleiben.")
# ---- Priest · Reckoning --------------------------------------------------
card("smite", "hit", "new", id="smite_hit",
     look="Eine kleine, harmlosere Final Word: ein kurzer Lichtstrahl schießt aus 3 m Höhe auf das Ziel, unten "
          "springt ein kleiner goldener Ring auf (etwa 1 m statt 2 m). 13 einzelne Partikel, kein Spawner: Smite "
          "ist der Grundangriff (überarbeitet am 21.10.).",
     emitters=[P(5, at="target", color=K["white"], shape=["line", [0, 3.2, 0], [0, 1.6, 0]],
                 vel=[[0, -9, 0], [0, -9, 0]], exp=[0.16, 0.18], size=[3, 3.5], glow=14),
               P(8, at="target", color=K["gold"], shape=["disc", [0, 0.15, 0], 0.3, True],
                 radial=[3, 3.5], exp=[0.25, 0.3], size=[2.5, 2.5], glow=14)],
     hook="Smite's cast (kits_priest.lua:61)",
     today="der Runde-40-Lichtfall: 24 fallende Punkte und ein 12er-Blitzring, zwei Spawner (bei 2 s "
           "Abklingzeit angenommen; jetzt ist Smite der Grundangriff, einmal pro Sekunde)", today_id="smite",
     note="Der alte Lichtfall wandert vergrößert zu Final Word.",
     sprite={"name": "Funke", "stand_in": "spark", "text": "der vierzackige Funke, golden"})
card("rebuke", "hit", "new", id="rebuke",
     look="Ein goldener Splitter zuckt aus der Hand des Priesters ins Ziel: eine Spur, die in 0,08 s von der "
          "Hand zum Gegner wandert und sofort erlischt.",
     emitters=[S(14, 0.08, color=K["gold"], shape=["line", "frame"],
                 vel=[[-0.2, -0.2, -0.2], [0.2, 0.2, 0.2]], exp=[0.12, 0.18], size=[2, 3], glow=14)],
     sample={"from": [0.4, 1.4, 0], "to": [6, 1.0, 0]},
     dynamic="line frame.from (the priest's hand: eye height minus a little) .. frame.to (the target's body)",
     hook="Rebuke's cast (kits_priest.lua, new def)")
card("word_of_ruin", "hit", "retint", id="word_of_ruin",
     look="Goldenes Licht löst sich vom Ziel und strömt zur Brust des Priesters zurück. Die Form aus Runde 40, "
          "Gold statt Dunkelviolett.",
     emitters=recolor(TODAY["word_of_ruin"], K["gold"]), hook="kits_priest.lua:266",
     today="dieselbe Form in Dunkelviolett (#6a2a9a)")
card("censure", "warning", "new", id="censure_warning",
     look="Der Warnring auf 3 m in hartem Gold, eine Dreiviertelsekunde lang: CORE-Bs Warnring in Gold.",
     emitters=lambda f: recolor(_area_warning(f), K["gold"]),
     sample={"reach": 3, "time": 0.75}, target=[8, 0, 0],
     dynamic="a recolour of area_warning: reach = the radius (3 m + Broad Judgment), time = the delay; "
             "no spec.color, which would repaint the seal and the impact too (area.lua:327-355)",
     hook="area.delayed spec.warning = \"censure_warning\"", context=["pfx.censure.fall"],
     marker={"radius": 3, "at": "target"})
card("censure", "fall", "new", id="censure_fall",
     look="Ein großes Siegel aus Licht fällt senkrecht und schlägt genau mit dem Ende der Verzögerung auf. Es "
          "erscheint etwas später und fällt mit 12 m/s, ohne zu verblassen (überarbeitet am 21.10.).",
     emitters=lambda f: _seal(f, K["white"]),
     sample={"reach": 3, "time": 0.75, "height": 6}, target=[8, 0, 0],
     dynamic="height = area.fall_height, time = the delay: it falls at CENSURE_FALL_SPEED for "
             "min(time, height / speed) and starts after the rest of the delay",
     hook="area.delayed spec.fall = \"censure_fall\"", context=["pfx.censure.warning"],
     marker={"radius": 3, "at": "target"},
     sprite={"name": "Siegel", "stand_in": "seal",
             "text": "Ein rundes Siegel mit Strahlenkranz (16×16, Gold auf Weiß) für dieses eine große Partikel; "
                     "bis dahin ein großer leuchtender Punkt."})
card("censure", "impact", "new", id="censure_impact",
     look="Ein harter Goldring schnappt bis an den 3-m-Rand.",
     emitters=[P(32, at="target", color=K["gold"], shape=["disc", [0, 0.2, 0], 0.3, True], radial="reach",
                 exp=[0.3, 0.3], size=[3, 3], glow=14)],
     sample={"reach": 3}, target=[8, 0, 0], t0=0.75, context=["pfx.censure.warning", "pfx.censure.fall"],
     dynamic="reach = the radius", hook="area.delayed spec.burst = \"censure_impact\"",
     marker={"radius": 3, "at": "target"})
card("final_word", "hit", "new", id="final_word",
     look="Eine Lichtsäule schlägt aus 7 m senkrecht auf das Ziel, ein goldener Ring springt am Boden auseinander.",
     emitters=[S(26, 0.1, at="target", color=K["white"], shape=["line", [0, 7, 0], [0, 0.2, 0]],
                 exp=[0.2, 0.3], size=[4, 5], glow=14),
               S(20, 0.05, at="target", color=K["gold"], shape=["disc", [0, 0.15, 0], 0.4, True],
                 radial=[5, 6], exp=[0.25, 0.35], size=[2.5, 3], glow=14)],
     hook="Final Word's cast (kits_priest.lua, new def)",
     today="Smites heutiger Lichtfall (dieses Muster, größer)", today_id="smite")
# ---- Scout · Quarry ------------------------------------------------------
card("loose", "shot", "none",
     look="Kein Effekt: der Grundangriff des Bogens fliegt ohne Spur. Der Pfeil ist zu sehen, und ein Treffer "
          "zeigt das Blut des Gegners. Die Spur bleibt den Bogenfähigkeiten mit Abklingzeit.",
     hook="scout.lua:11-15 (ARROW_TRAILS: drop the loose entry)",
     today="heute zieht jeder Loose die Pfeilspur (ein Spawner aus 30 Partikeln)", today_id="skill_arrow",
     note="Bei 50 Spielern kosteten die Loose-Spuren allein etwa so viel wie alle anderen Späher-Effekte "
          "zusammen; der Grundangriff muss der billigste Effekt sein.")
card("loose", "window", "keep", id="proc",
     look="Follow the Line bereit (ein True Draw hat getroffen): der Bereitschaftsring in Grün.",
     emitters=recolor(TODAY["proc"], Q["green"]), color=Q["green"],
     hook="grug_classes.open_window for Follow the Line: grug_core.proc_flash(player, \"follow_the_line\")",
     rate=1 / 6)
card("sidestep", "cast", "keep", id="sidestep",
     look="Ein blassgrünes Flimmern um den Späher. Unverändert.",
     emitters=TODAY["sidestep"], hook="scout.lua:577", today="genau dieser Effekt")
card("sprint", "cast", "keep", id="sprint",
     look="Ein Staubstoß hinter dem Späher. Unverändert.",
     emitters=TODAY["sprint"], hook="scout.lua:602", today="genau dieser Effekt")
card("true_draw", "trail", "keep", id="skill_arrow",
     look="Die Pfeilspur aus Runde 40 in hellem Gold-Elfenbein: der voll gespannte Schuss glänzt.",
     emitters=recolor(TODAY["skill_arrow"], Q["glint"]), color=Q["glint"],
     sample={"from": [0.3, 1.45, 0], "to": [25, 1.2, 0], "time": 0.55}, target=[25, 0, 0],
     dynamic="line frame.from..frame.to over the flight time; frame.color per shot (ARROW_TRAILS)",
     hook="scout.lua ARROW_TRAILS.true_draw = {effect = \"skill_arrow\", color = \"#f0e6b8\"}",
     flight={"speed": 45, "size": 0.25, "color": "#d8c8a0"})
card("snare_shot", "trail", "keep", id="skill_arrow",
     look="Die Pfeilspur in Grün, wie heute.",
     emitters=recolor(TODAY["skill_arrow"], Q["snare"]), color=Q["snare"],
     sample={"from": [0.3, 1.45, 0], "to": [25, 1.2, 0], "time": 0.62}, target=[25, 0, 0],
     dynamic="as True Draw", hook="scout.lua ARROW_TRAILS.snare_shot (kept)",
     flight={"speed": 40, "size": 0.25, "color": "#d8c8a0"}, today="genau dieser Effekt")
card("snare_shot", "hit", "keep", id="snare_hit",
     look="Ein grüner Ring springt um die Beine des getroffenen Ziels auf. Unverändert.",
     emitters=TODAY["snare_hit"], hook="scout.lua:146", target=[25, 0, 0], t0=0.62,
     context=["pfx.snare_shot.trail"], today="genau dieser Effekt")
card("split_shot", "trail", "keep", id="skill_arrow",
     look="Die Pfeilspur in Wiesengrün.",
     emitters=recolor(TODAY["skill_arrow"], Q["green"]), color=Q["green"],
     sample={"from": [0.3, 1.45, 0], "to": [20, 1.2, 0], "time": 0.5}, target=[20, 0, 0],
     dynamic="as True Draw", hook="scout.lua ARROW_TRAILS.split_shot = {..., color = \"#a8c86a\"}",
     flight={"speed": 40, "size": 0.25, "color": "#d8c8a0"})
card("split_shot", "splinter", "new", id="split_shot_splinter",
     look="Vom getroffenen Ziel zuckt je eine kurze Splitterlinie zu den bis zu zwei Gegnern daneben, die "
          "ebenfalls Schaden nehmen.",
     emitters=[P(5, color=Q["wood"], shape=["line", "frame"],
                 vel=[[-0.3, 0, -0.3], [0.3, 0.5, 0.3]], exp=[0.25, 0.3], size=[1.5, 2], glow=4)],
     sample={"from": [20, 1.1, 0], "to": [21.5, 1.0, 2.2]}, target=[20, 0, 0], per_use=2, t0=0.5,
     context=["pfx.split_shot.trail"],
     dynamic="line frame.from (the struck target) .. frame.to (one secondary), once per secondary",
     hook="Split Shot's splash loop, once per secondary hit (the Fireball splash pattern, kits_mage.lua:44-51)")
card("arrowfall", "trail", "new", id="arrowfall_trail",
     look="Die vier Pfeile fliegen zusammen: eine einzige, dichtere und breitere Spur für die ganze Salve.",
     emitters=[S(40, "frame", color=Q["glint"], shape=["line", "frame"],
                 vel=[[-0.4, -0.2, -0.4], [0.4, 0.4, 0.4]], exp=[0.3, 0.45], size=[1.5, 2.2], glow=8)],
     sample={"from": [0.3, 1.45, 0], "to": [20, 1.2, 0], "time": 0.45}, target=[20, 0, 0],
     dynamic="line frame.from..frame.to over the flight time; played once for the volley",
     hook="Arrowfall's launch batch (scout.lua launch(count)): the trail on the first arrow only",
     flight={"speed": 45, "size": 0.35, "color": "#d8c8a0"},
     note="Vier Spuren wären vier Spawner-Pakete pro Empfänger; die Pfeile fliegen fast dieselbe Bahn.")
card("arrowfall", "impact", "new", id="arrowfall_impact",
     look="Die Salve schlägt ein: Holzsplitter und Erde spritzen am Ziel hoch und fallen zurück.",
     emitters=[S(24, 0.08, at="target", color=Q["earth"], shape=["sphere", [0, 0.5, 0], 0.3, False],
                 vel=[[-3, 1, -3], [3, 5, 3]], acc=[0, -10, 0], exp=[0.4, 0.7], size=[1.5, 2.5], glow=2)],
     target=[20, 0, 0], t0=0.45, context=["pfx.arrowfall.trail"],
     hook="Arrowfall's first arrow on_hit (scout.lua)")
# ---- Scout · Veil --------------------------------------------------------
card("bladecraft", "swing", "none",
     look="Kein eigener Effekt: der Klingenschlag (Linksklick) bleibt wie Strike ohne Effekt, der Schuss "
          "(Rechtsklick) ist ein Loose und fliegt ohne Spur.")
card("opening", "hit", "keep", id="opening",
     look="Ein kurzer weißer Funkenblitz am Ziel. Unverändert; das Weiß liest sich als Schatten-Silber.",
     emitters=TODAY["opening"], target=MELEE, hook="scout.lua:663", today="genau dieser Effekt")
card("parry", "cast", "new", id="parry",
     look="Wo zwei Klingen sich treffen, sprüht vor dem Späher auf Handhöhe ein kurzer Silberfunke.",
     emitters=[P(8, color=V["silver"], shape=["box", [0.6, 1.2, -0.1], [0.7, 1.4, 0.1]],
                 vel=[[-1, -0.5, -2], [1, 2, 2]], exp=[0.15, 0.25], size=[1.2, 1.8], glow=14)],
     hook="Parry's cast (scout.lua, new def)",
     sprite={"name": "Funke", "stand_in": "spark", "text": "der vierzackige Funke, silbern"})
card("flourish", "cast", "new", id="flourish",
     look="Ein schneller violetter Schwung läuft in 0,1 s über die 90°-Front vor dem Späher.",
     emitters=[S(18, 0.1, color=V["violet"], shape=["line", [1.5, 1.2, 1.5], [1.5, 1.0, -1.5]],
                 exp=[0.25, 0.35], size=[2.5, 3.5], glow=10)],
     target=MELEE, marker={"cone": [3, 90]}, hook="Flourish's cast (scout.lua, new def)")
card("close_dance", "cast", "new", id="close_dance",
     look="Violetter Rauch drückt sich um die Füße des Spähers nach außen und sinkt, ein paar Silberfunken "
          "steigen daraus auf.",
     emitters=[S(20, 0.15, color=V["smoke"], shape=["disc", [0, 0.3, 0], 0.6, False], radial=[1.5, 2.5],
                 acc=[0, -0.5, 0], exp=[0.6, 0.9], size=[4, 6], glow=2),
               P(6, color=V["silver"], shape=["disc", [0, 0.4, 0], 0.6, False],
                 vel=[[0, 1.5, 0], [0, 2.5, 0]], exp=[0.3, 0.45], size=[1.2, 1.6], glow=14)],
     hook="Close Dance's cast (scout.lua, new def)")
card("close_dance", "swing", "new", id="close_dance_swing",
     look="Solange Close Dance läuft, blitzen bei jedem gelandeten Klingenschlag zwei Silberfunken am Ziel.",
     emitters=[P(2, at="target", color=V["silver"], shape=["sphere", [0, 1.1, 0], 0.15, False],
                 vel=[[-1.5, 0, -1.5], [1.5, 1.5, 1.5]], exp=[0.15, 0.2], size=[1.2, 1.6], glow=14)],
     target=MELEE, per_use=6, t0=0.5, context=["pfx.close_dance.cast"],
     hook="the blade swing's landed hit while the Close Dance window is active")


# --------------------------------------------------------------------------
# Helpers the card functions use
# --------------------------------------------------------------------------
def _fall_time(f, speed):
    """How long a fall at `speed` m/s from frame height takes, at most the
    delay; the rest of the delay is its `after`."""
    life = f["time"]
    fall = min(life, f["height"] / speed)
    return fall, life - fall


def _comet(f, tex, sizes, speed):
    """Three single particles in a row along a slanted fall, all at one
    velocity, that appear late and fall fast so the head reaches the anchor
    when the delay ends; no fade, so the head lands whole."""
    h = f["height"]
    fall, after = _fall_time(f, speed)
    slope = 0.35  # horizontal metres per metre of fall
    vx, vy = slope * h / fall, -h / fall
    path = math.hypot(vx, vy)
    ux, uy = -vx / path, -vy / path  # back along the path
    out = []
    for k, size in enumerate(sizes):
        back = 0.7 * k
        p = [-slope * h + ux * back, h + uy * back, 0]
        p = [round(p[0], 3), round(p[1], 3), 0]
        out.append(P(1, at="target", tex=tex, fade=False, after=after, shape=["box", p, p],
                     vel=[[round(vx, 3), round(vy, 3), 0], [round(vx, 3), round(vy, 3), 0]],
                     exp=[fall, fall], size=[size, size], glow=14))
    return out


def _seal(f, color):
    """Censure's one large seal: straight down at CENSURE_FALL_SPEED, late
    enough to land with the delay; no fade."""
    h = f["height"]
    fall, after = _fall_time(f, CENSURE_FALL_SPEED)
    return [P(1, at="target", color=color, fade=False, after=after, shape=["box", [0, h, 0], [0, h, 0]],
              vel=[[0, -h / fall, 0], [0, -h / fall, 0]], exp=[fall, fall], size=[16, 16], glow=14)]


# --------------------------------------------------------------------------
# Evaluation: frames, the sim form, checks, costs
# --------------------------------------------------------------------------
LIMITS = {"MAX_TIME": 1, "MAX_COUNT": 128, "MAX_EXPTIME": 3}
# The frequent moments whose effect this lane makes cheaper than today's.
CUT = ("pfx.loose.shot", "pfx.smite.hit", "pfx.fiery_spark.impact", "pfx.hearten.recipient")


def emitters_of(c):
    em = c["emitters"]
    ems = em(c["sample"]) if callable(em) else list(em)
    return [look(e, c["family"]) for e in ems]


def check(emitters):
    """particles.lua's particles.check, rule for rule (check_limits.lua runs
    the real one on the same lists)."""
    if not emitters:
        return "no emitters"
    for i, e in enumerate(emitters, 1):
        lab = "emitter %d: " % i
        if e["kind"] not in ("spawner", "single"):
            return lab + "kind"
        if not isinstance(e["n"], int) or not 1 <= e["n"] <= LIMITS["MAX_COUNT"]:
            return lab + "n must be an integer 1..128"
        if e["kind"] == "spawner" and e["time"] != "frame" and not 0 < e["time"] <= LIMITS["MAX_TIME"]:
            return lab + "a spawner's time must be in (0, 1]"
        exp = e.get("exp")
        if not exp or exp[1] > LIMITS["MAX_EXPTIME"] or exp[0] <= 0 or exp[0] > exp[1]:
            return lab + "exp must be {min, max} within (0, 3]"
        if e["shape"][0] not in ("box", "line", "disc", "sphere"):
            return lab + "unknown shape"
        if e.get("at", "caster") not in ("caster", "target"):
            return lab + "at"
        if e.get("attract") and e["kind"] != "spawner":
            return lab + "attract is a spawner field"
        if e.get("radial") == "reach" and e["kind"] != "single":
            return lab + "radial reach needs single particles"
        if e.get("attached") or e.get("playername"):
            return lab + "never attached, never private"
        if e.get("blend", "alpha") not in ("alpha", "add"):
            return lab + "blend must be alpha or add"
        if not 0 <= e.get("after", 0) <= 3:
            return lab + "after must be in [0, 3]"
    return None


def facing_problem(e):
    """A spawner's box extents and velocity/acceleration ranges stay
    world-aligned while its centre turns with the caster (particles.lua
    header), so they must look the same for every facing: equal x and z
    half extents, x and z ranges symmetric and equal."""
    if e["kind"] != "spawner":
        return None
    sh = e["shape"]
    if sh[0] == "box":
        hx, hz = (sh[2][0] - sh[1][0]) / 2, (sh[2][2] - sh[1][2]) / 2
        if abs(hx - hz) > 1e-9:
            return "box x/z half extents differ"
    for field in ("vel",):
        v = e.get(field)
        if v and (abs(v[0][0] + v[1][0]) > 1e-9 or abs(v[0][2] + v[1][2]) > 1e-9
                  or abs(v[1][0] - v[1][2]) > 1e-9):
            return "vel x/z range not symmetric"
    a = e.get("acc")
    if a and (a[0] or a[2]):
        return "acc has a horizontal part"
    return None


def color_of(e, frame):
    return frame.get("color") or e.get("color") or "#ffffff"


def texture_of(e, frame):
    return e.get("tex") or (MOTE if e.get("mote") else SMOKE) + color_of(e, frame)


def tex_key(e):
    t = e.get("tex", "")
    if t.startswith("mobs_fire"):
        return "fire"
    if t.startswith("mobs_blood"):
        return "blood"
    return "smoke"


def to_sim(e, frame, caster, target, delay):
    """An emitter in world coordinates for the cost model and the page's
    simulation (caster at the origin facing +x)."""
    anchor = target if e.get("at") == "target" else caster
    add = lambda v: [round(anchor[k] + v[k], 4) for k in range(3)]
    sh = e["shape"]
    time = e.get("time", 0)
    if time == "frame":
        time = min(1.0, frame.get("time", 1.0))
    if sh[0] == "line" and sh[1] == "frame":
        shape = ["line", frame["from"], frame["to"]]
    elif sh[0] == "line":
        shape = ["line", add(sh[1]), add(sh[2])]
    elif sh[0] == "box":
        shape = ["box", add(sh[1]), add(sh[2])]
    else:
        shape = [sh[0], add(sh[1]), sh[2], bool(sh[3])]
    after = e.get("after", 0)
    s = {"kind": e["kind"], "n": e["n"], "time": time if e["kind"] == "spawner" else 0, "delay": delay + after,
         "after": after, "mote": bool(e.get("mote")), "blend": e.get("blend", "alpha"),
         "shape": shape, "vel": e.get("vel") or [[0, 0, 0], [0, 0, 0]], "acc": e.get("acc") or [0, 0, 0],
         "exp": e["exp"], "size": e["size"], "glow": e.get("glow", 0), "color": color_of(e, frame),
         "texture": texture_of(e, frame), "tex": tex_key(e), "fade": e.get("fade", True),
         "attract": None, "pull": None, "radial": None, "reach": None, "engine": None}
    if e["kind"] == "spawner":
        eng = {"pos": None, "tween": None, "radius": None}
        if shape[0] == "box":
            eng["pos"] = [shape[1], shape[2]]
            centre = [(shape[1][k] + shape[2][k]) / 2 for k in range(3)]
        elif shape[0] == "line":
            eng["tween"] = [shape[1], shape[2]]
            centre = [(shape[1][k] + shape[2][k]) / 2 for k in range(3)]
        elif shape[0] == "disc" or shape[3]:
            r = shape[2]
            eng["pos"] = [shape[1], shape[1]]
            eng["radius"] = [r, 0, r] if shape[0] == "disc" else [r, r, r]
            centre = shape[1]
        else:
            r = shape[2]
            eng["pos"] = [[shape[1][k] - r for k in range(3)], [shape[1][k] + r for k in range(3)]]
            centre = shape[1]
        s["engine"] = eng
        if e.get("radial"):
            r = shape[2] if shape[0] in ("disc", "sphere") else 1
            s["pull"] = {"origin": centre, "smin": -e["radial"][1] / r, "smax": -e["radial"][0] / r,
                         "kill": False}
            s["attract"] = "point"
        elif e.get("attract"):
            a = e["attract"]
            oa = target if a.get("at", e.get("at")) == "target" else caster
            s["pull"] = {"origin": [oa[k] + a["origin"][k] for k in range(3)], "smin": a["strength"],
                         "smax": a["strength"], "kill": bool(a.get("kill"))}
            s["attract"] = "point"
    else:
        if e.get("radial") == "reach":
            s["reach"] = frame.get("reach", 3)
        elif e.get("radial"):
            s["radial"] = e["radial"]
    return s


def lua_value(v, indent=""):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v) if isinstance(v, int) else ("%.10g" % v)
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return "{" + ", ".join(lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join("%s = %s" % (k, lua_value(v[k])) for k in sorted(v)) + "}"
    raise TypeError(v)


def lua_pretty(ems):
    """The emitters as particle_effects.lua would write them (one per line)."""
    if not ems:
        return ""
    rows = []
    for e in ems:
        e = dict(e)
        kind, n = e.pop("kind"), e.pop("n")
        if kind == "spawner":
            t = e.pop("time")
            head = "spawner(%d, %s, " % (n, json.dumps(t) if isinstance(t, str) else lua_value(t))
        else:
            head = "single(%d, " % n
        rows.append("\t" + head + lua_value(e) + "),")
    return "{\n" + "\n".join(rows) + "\n}"


def main():
    data_cards, lua_rows, problems = [], [], []
    by_key = {}
    for i, c in enumerate(CARDS):
        if c["key"] in by_key:
            raise SystemExit("duplicate key " + c["key"])
        by_key[c["key"]] = c
    for num, c in enumerate(CARDS, 1):
        s = SKILLS[c["skill"]]
        ems = emitters_of(c)
        frame = dict(c["sample"])
        if c["color"]:
            frame["color"] = vivid(c["family"], c["color"])
        if c["status"] != "none":
            p = check(ems)
            if p:
                problems.append("%s: %s" % (c["key"], p))
            for e in ems:
                fp = facing_problem(e)
                if fp:
                    problems.append("%s: %s" % (c["key"], fp))
        sim = [to_sim(e, frame, [0, 0, 0], c["target"], 0.0) for e in ems]
        cc = cost.card_cost(sim, seed=num) if sim else None
        # uses per second per player of the fight at full pace
        builds = s["builds"]
        rate = 0.0
        for b in builds:
            r = c["rate"] if c["rate"] is not None else RATES.get((b, c["skill"]), 0.0)
            rate += r / 8
        rate *= c["per_use"]
        today = None
        if c["today_id"] and c["today_id"] in TODAY:
            t = TODAY[c["today_id"]]
            t = t(TODAY_SAMPLE[c["today_id"]]) if callable(t) else t
            tsim = [to_sim(e, {"from": [0.3, 1.45, 0], "to": [25, 1.2, 0], "time": 0.55}, [0, 0, 0],
                           c["target"], 0.0) for e in t]
            today = cost.card_cost(tsim, seed=900 + num)
        contexts = []
        for k in c["context"]:
            o = by_key[k]
            of = dict(o["sample"])
            if o["color"]:
                of["color"] = vivid(o["family"], o["color"])
            contexts.append({"key": k, "t0": o["t0"],
                             "emitters": [to_sim(e, of, [0, 0, 0], o["target"], 0.0) for e in emitters_of(o)],
                             "flight": o["flight"]})
        fam = FAMILIES[c["family"]]
        data_cards.append({
            "n": num, "key": c["key"], "skill": c["skill"], "name": s["name"], "class": s["class"],
            "tree": s["tree"], "unlock": s["unlock"], "family": c["family"], "family_name": fam["name"],
            "family_de": fam["de"], "moment": c["moment"], "status": c["status"], "id": c["id"],
            "look": c["look"], "hook": c["hook"], "today": c["today"], "note": c["note"],
            "sprite": c["sprite"], "dynamic": c["dynamic"], "sample": c["sample"], "target": c["target"],
            "lua": ems, "lua_text": lua_pretty(ems), "sim": sim, "cost": cc, "today_cost": today, "rate": round(rate, 6),
            "per_use": c["per_use"], "t0": c["t0"], "context": contexts, "flight": c["flight"],
            "marker": c["marker"], "cd": s["cd"], "builds": builds})
        if ems:
            lua_rows.append("  {key = %s, id = %s, status = %s, frame_color = %s, sample = %s,\n"
                            "   emitters = %s},"
                            % (json.dumps(c["key"]), json.dumps(c["id"] or ""), json.dumps(c["status"]),
                               "true" if c["color"] else "false",
                               lua_value(c["sample"]) if c["sample"] else "{}", lua_value(ems)))
    missing = sorted(set(SKILLS) - {c["skill"] for c in CARDS})
    if missing:
        problems.append("skills without a card: " + ", ".join(missing))
    if problems:
        raise SystemExit("card problems:\n  " + "\n  ".join(problems))
    # Page order: class, then tree, then the order above; the visible number
    # follows it. A card without a tree family (Strike) sits in its class's
    # first tree.
    tree_order = [t for _, _, trees in CLASSES for t in trees]
    def group(d):
        fam = d["family"] if d["family"] in tree_order else d["tree"]
        return tree_order.index(fam)
    order = sorted(range(len(data_cards)), key=lambda i: (group(data_cards[i]), i))
    data_cards = [data_cards[i] for i in order]
    for n, d in enumerate(data_cards, 1):
        d["n"] = n
        d["group"] = tree_order[group(d)]
    cards_for_scn = [(d["cost"], d["rate"]) for d in data_cards if d["cost"]]
    scenarios = {}
    for players in (5, 20, 50):
        for scale in (1.0, 0.5):
            scenarios["%d@%s" % (players, scale)] = {
                k: round(v, 3) for k, v in cost.scenario(cards_for_scn, players, 1.0, scale).items()}
    # The same fights if the four frequent moments kept today's effect (the
    # cuts this lane makes: Loose's trail, Smite's two spawners, Fireball's
    # splash on every Fiery Spark, a spawner per Hearten recipient).
    uncut = []
    for d in data_cards:
        c = d["today_cost"] if d["key"] in CUT and d["today_cost"] else d["cost"]
        if c:
            uncut.append((c, d["rate"]))
    for players in (5, 20, 50):
        scenarios["%d@1.0 uncut" % players] = {
            k: round(v, 3) for k, v in cost.scenario(uncut, players, 1.0, 1.0).items()}
    # Which cards dominate the 50-player fight: share of bytes and of alive particles.
    dom = []
    for d in data_cards:
        if not d["cost"] or not d["rate"]:
            continue
        r = d["rate"] * 50
        dom.append({"key": d["key"], "bytes": round(r * d["cost"]["wire"], 1),
                    "alive": round(r * d["cost"]["i1"], 2)})
    doc = {
        "cards": data_cards,
        "families": {k: {kk: vv for kk, vv in v.items()} for k, v in FAMILIES.items()},
        "classes": [{"id": c, "de": de, "trees": trees} for c, de, trees in CLASSES],
        "skills": {k: {"name": v["name"], "class": v["class"], "tree": v["tree"], "cd": v["cd"],
                       "occ": v["occ"], "unlock": v["unlock"], "builds": v["builds"]} for k, v in SKILLS.items()},
        "rates": {"%s/%s" % k: round(v, 6) for k, v in sorted(RATES.items())},
        "scenarios": scenarios,
        "dominant": sorted(dom, key=lambda x: -x["bytes"])[:10],
        "dominant_alive": sorted(dom, key=lambda x: -x["alive"])[:10],
        "constants": {"zframe": cost.ZFRAME, "steps_per_s": round(cost.STEPS_PER_S, 4),
                      "spawner_us": cost.SPAWNER_US, "particle_us": cost.PARTICLE_US,
                      "check_us": cost.CHECK_US, "lua_spawner_us": cost.cm.LUA_SPAWNER_US,
                      "lua_spawner_attract_us": cost.cm.LUA_SPAWNER_ATTRACT_US,
                      "lua_particle_us": cost.cm.LUA_PARTICLE_US, "chunk": cost.cm.CHUNK_MAX,
                      "split_hdr": cost.cm.SPLIT_HDR, "base_hdr": cost.cm.BASE + cost.cm.RELIABLE + cost.cm.IP_UDP,
                      "original_hdr": cost.cm.ORIGINAL_HDR},
        "limits": LIMITS,
    }
    (HERE / "data.json").write_text(json.dumps(doc, indent=1, ensure_ascii=False, sort_keys=True) + "\n")
    (HERE / "emitters.lua").write_text(
        "-- Generated by tools/r52_pfx/effects.py: every card's emitters in\n"
        "-- particles.lua's format, for check_limits.lua. Do not edit.\n"
        "return {\n" + "\n".join(lua_rows) + "\n}\n")
    print("cards: %d (%s)" % (len(data_cards), ", ".join(
        "%s %d" % (st, sum(1 for d in data_cards if d["status"] == st)) for st in ("keep", "retint", "new", "none"))))
    for k in ("5@1.0", "20@1.0", "50@1.0", "50@0.5", "50@1.0 uncut"):
        s = scenarios[k]
        print("%-12s %6.1f KB/s per receiver  %5.1f packets/s %5.1f datagrams/s  alive mean %4.0f peak %4.0f  started %4.0f/s  "
              "server %.2f ms/s" % (k, s["bytes"] / 1024, s["packets"], s["datagrams"], s["mean"], s["peak"], s["started"],
                                     s["server_us"] / 1000))
    print("dominant (50 players, bytes/s per receiver):")
    for x in doc["dominant"][:6]:
        print("   %-34s %7.0f B/s  alive %5.1f" % (x["key"], x["bytes"], x["alive"]))
    print("dominant (alive):")
    for x in doc["dominant_alive"][:6]:
        print("   %-34s %7.0f B/s  alive %5.1f" % (x["key"], x["bytes"], x["alive"]))


if __name__ == "__main__":
    main()

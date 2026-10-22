"""Armor box catalog of Round 54 (the contract, frozen from the phase 1-2 prototype). Units: skin pixels (the model's
0.525 units; 32 px = the 1.68-node character). Coordinates are the REST pose in
model space: y up from the soles, +z forward (the face), the character's right
is -x. A box: [x0, y0, z0, x1, y1, z1]. `bone` is the bone it rides on;
`mirror` adds the mirrored copy on the other side (arm_l / leg_l, or the body
for a body-bone box). `rot`: (axis, degrees, origin) about `origin`, in fixed
22.5-degree steps. Every box is 24 vertices in the model whatever is painted.

Bones (pivots read out of mods/BASE/player_api/models/character.b3d):
  body (0,12,0), head (0,24,0), arm_r (-6,22,0), leg_r (-2,12,0);
  panel_f / panel_b: swing bones hinged at the belt (like the cloak's).
"""

BONES = {
    "body": (0, 12, 0), "head": (0, 24, 0),
    "arm_r": (-6, 22, 0), "arm_l": (6, 22, 0),
    "leg_r": (-2, 12, 0), "leg_l": (2, 12, 0),
    "panel_f": (0, 12.75, 3.5), "panel_b": (0, 12.75, -3.5),
}

# area, id, German label, bone, box, extras
SHAPES = [
    # Head (helmet): shell, visor (crest and hood point tried and dropped, 2026-10-20)
    ("head", "helm", "Helmschale", "head", [-4.75, 23.25, -4.75, 4.75, 32.75, 4.75], {}),
    ("head", "visor", "Visier", "head", [-4.25, 24.5, 5.0, 4.25, 30.5, 5.75], {}),
    # Torso: shell (down over the hip joint), belt
    ("torso", "chest", "Brustschale", "body", [-4.25, 10.25, -2.25, 4.25, 24.5, 2.25], {}),
    ("torso", "belt", "Gürtel", "body", [-4.75, 11.5, -2.75, 4.75, 13.75, 2.75], {}),
    # Hip: swinging front/back panel (skirt, tabard, later the robe), side tassets
    ("hip", "panel_f", "Schoß vorne", "panel_f", [-3.5, 1.5, 3.25, 3.5, 12.75, 3.75], {}),
    ("hip", "panel_b", "Schoß hinten", "panel_b", [-3.5, 1.5, -3.75, 3.5, 12.75, -3.25], {}),
    ("hip", "tasset", "Beintasche", "body", [-5.5, 6.0, -2.0, -5.0, 12.0, 2.0],
     {"mirror": True, "rot": ("z", -22.5, (-5.0, 12.0, 0.0))}),
    # Shoulders and arms (right side, mirrored)
    ("arms", "sleeve", "Ärmelschale", "arm_r", [-8.5, 11.75, -2.5, -3.75, 24.25, 2.5], {"mirror": True}),
    ("arms", "bracer", "Armschiene", "arm_r", [-9.0, 11.25, -3.0, -3.0, 16.5, 3.0], {"mirror": True}),
    ("shoulders", "pauldron", "Schulter Kern", "arm_r", [-8.75, 18.25, -2.75, -3.25, 24.75, 2.75], {"mirror": True}),
    ("shoulders", "reinforce", "Schulter Verstärkung", "arm_r", [-9.25, 19.75, -3.25, -2.75, 25.25, 3.25], {"mirror": True}),
    ("shoulders", "flare", "Schulter Flügel", "arm_r", [-10.25, 18.0, -3.0, -9.5, 24.5, 3.0],
     {"mirror": True, "rot": ("z", -22.5, (-9.5, 24.5, 0.0))}),
    ("shoulders", "spike", "Schulter Stachel", "arm_r", [-6.75, 25.0, -0.75, -5.25, 28.0, 0.75],
     {"mirror": True, "rot": ("z", 22.5, (-6.0, 25.0, 0.0))}),
    # Legs and feet (right side, mirrored; the inner side stays inside the leg so the two legs' armor never overlaps)
    ("legs", "thigh", "Oberschenkel", "leg_r", [-4.5, 6.0, -2.5, -0.25, 10.25, 2.5], {"mirror": True}),
    ("legs", "knee", "Kniekachel", "leg_r", [-4.75, 4.0, -2.75, -0.5, 7.25, 3.0], {"mirror": True}),
    ("feet", "boot", "Stiefelschale", "leg_r", [-4.5, -0.25, -2.5, -0.25, 6.0, 2.5], {"mirror": True}),
    ("feet", "toe", "Zehenkappe", "leg_r", [-4.75, -0.5, 1.5, -0.5, 2.0, 3.25], {"mirror": True}),
]

# Polygon parts (Round 56, armor-format.md §1a): convex planar faces from a schema file, on one bone.
# area, id, German label, the box whose surface closes the part (its `shell`), the schema file (repo path)
POLY_PARTS = [
    ("head", "hood", "Kapuze", "helm", "tools/r56_hood/hood.json"),
]

AREAS = [("head", "Kopf"), ("torso", "Torso"), ("shoulders", "Schultern"), ("arms", "Arme"),
         ("hip", "Hüfte"), ("legs", "Beine"), ("feet", "Füße")]

# Placeholder palettes (never shipped): material light/mid/dark, trim (zone B neutral).
PALETTES = {
    "bronze": {"name": "Bronze", "light": "#e8b06a", "mid": "#b97a3c", "dark": "#7a4a22", "trim": "#d8b860"},
    "iron": {"name": "Eisen", "light": "#c4c2bc", "mid": "#8f8d88", "dark": "#55534f", "trim": "#b89a5a"},
    "steel": {"name": "Stahl", "light": "#dfe4ea", "mid": "#a6aeb8", "dark": "#646d78", "trim": "#c8b070"},
    "silversteel": {"name": "Silberstahl", "light": "#ffffff", "mid": "#d2d8e2", "dark": "#8e98a8", "trim": "#e8eef8"},
    "embersteel": {"name": "Glutstahl", "light": "#8a6458", "mid": "#4e3530", "dark": "#2a1a18", "trim": "#ff9a3c", "glow": "#ffb347"},
    "abyssal_steel": {"name": "Abgrundstahl", "light": "#6a5a8e", "mid": "#352c4a", "dark": "#17131f", "trim": "#a58cf0"},
    "light": {"name": "Leichtes Leder", "light": "#c9a27a", "mid": "#a37b52", "dark": "#6e4e30", "trim": "#b8a070"},
    "cured": {"name": "Gegerbtes Leder", "light": "#a87a52", "mid": "#835a38", "dark": "#553820", "trim": "#c0a060"},
    "heavy_leather": {"name": "Schweres Leder", "light": "#7e5a3c", "mid": "#5e4029", "dark": "#3a2616", "trim": "#c8a464"},
    "hardened": {"name": "Hartleder (T4, neuer Name)", "light": "#8a5a3a", "mid": "#6a3e26", "dark": "#40220f", "trim": "#d0b070"},
    "sleek": {"name": "Glattleder", "light": "#7a808c", "mid": "#4f545e", "dark": "#2c2f36", "trim": "#c0c8d0"},
    "nightscale": {"name": "Nachtschuppe", "light": "#5c5480", "mid": "#332d4e", "dark": "#18152a", "trim": "#9a8cd8"},
    "patch": {"name": "Flickenstoff", "light": "#a89a82", "mid": "#857862", "dark": "#5a5040", "trim": "#a08860"},
    "woven": {"name": "Webstoff", "light": "#8fa07c", "mid": "#6c7c5a", "dark": "#48543a", "trim": "#c8b880"},
    "heavy_cloth": {"name": "Schwerer Stoff", "light": "#7488ac", "mid": "#53668a", "dark": "#34425e", "trim": "#d8c890"},
    "silkweave": {"name": "Seidenwebart", "light": "#ece4d2", "mid": "#d2c6ac", "dark": "#a0947a", "trim": "#c09040"},
    "silk": {"name": "Seide", "light": "#ffffff", "mid": "#e6e6f0", "dark": "#b4b4c8", "trim": "#e0b850"},
    "stormweave": {"name": "Sturmgewebe", "light": "#4a5c94", "mid": "#2c3a6a", "dark": "#18203e", "trim": "#d8e4ff"},
}
CLOTH = "#b9a888"      # zone A neutral: undyed linen
LEATHER = ("#8a5e3a", "#5e3c22")
TROUSERS = "#5f5446"

# Enchant colours (mods/ITEMS/grug_gear/enchant_colors.lua), drawn at 50 %.
ENCHANT = [("str", "Stärke", "#9a2b10"), ("dex", "Geschick", "#20dea2"), ("int", "Intelligenz", "#4648a0"),
           ("max_hp_percent", "Max. Leben", "#b55370"), ("max_mana_percent", "Max. Mana", "#40dafd"),
           ("crit_percent", "Krit", "#eede22"), ("attack_speed_percent", "Tempo", "#e0803c"),
           ("dodge_percent", "Ausweichen", "#937ffc"), ("armor_rating", "Rüstung", "#ffffff")]

# Lines. `paint`: one placeholder paint per box per line (style + cut + flags);
# a tier's `paint` overrides it (the "second paint variant"). `inner`: bands on
# the skin (part, first row, end row, style), rows from the top of the part.
# `on`: the user's saved selection of 2026-10-20 (metal bulkiest, leather less, cloth smooth).
# Styles: plate, mail, soft (material), hard (boiled leather plate), scale,
# cloth (zone A), leather (belt leather), trim (zone B).
LINES = {
    "metal": {
        "name": "Metall", "who": "Krieger",
        "paint": {
            "helm": {"style": "plate", "cut": "open_face"}, "visor": {"style": "plate", "cut": "full", "slit": True},
            "chest": {"style": "plate", "cut": "full", "rivets": True},
            "belt": {"style": "leather", "cut": "full", "buckle": True},
            "panel_f": {"style": "plate", "cut": "skirt"}, "panel_b": {"style": "plate", "cut": "skirt"},
            "tasset": {"style": "plate", "cut": "full"}, "sleeve": {"style": "mail", "cut": "full"},
            "bracer": {"style": "plate", "cut": "full"}, "pauldron": {"style": "plate", "cut": "full"},
            "reinforce": {"style": "plate", "cut": "full", "rivets": True}, "flare": {"style": "plate", "cut": "full"},
            "spike": {"style": "plate", "cut": "full"}, "thigh": {"style": "plate", "cut": "full"},
            "knee": {"style": "plate", "cut": "full", "rivets": True}, "boot": {"style": "plate", "cut": "full"},
            "toe": {"style": "plate", "cut": "full"},
            },
        "tiers": [
            {"tier": "T1", "pal": "bronze", "on": ["helm", "chest", "thigh", "boot"],
             "inner": [("torso", 0, 12, "cloth"), ("arm", 0, 6, "cloth"), ("leg", 0, 8, "trousers"), ("leg", 8, 12, "leather")],
             "paint": {"helm": {"style": "plate", "cut": "cap"}, "chest": {"style": "plate", "cut": "breast", "rivets": True},
                       "boot": {"style": "leather", "cut": "full", "shin": True}}},
            {"tier": "T2", "pal": "iron", "on": ["helm", "chest", "belt", "pauldron", "thigh", "boot"],
             "inner": [("torso", 0, 12, "cloth"), ("arm", 0, 6, "cloth"), ("leg", 0, 8, "trousers"), ("leg", 8, 12, "leather")],
             "paint": {"helm": {"style": "plate", "cut": "cap"}, "chest": {"style": "plate", "cut": "breast", "rivets": True},
                       "boot": {"style": "leather", "cut": "full", "shin": True}}},
            {"tier": "T3", "pal": "steel", "on": ["helm", "chest", "belt", "panel_f", "panel_b", "sleeve", "pauldron", "thigh", "boot"],
             "inner": [("torso", 0, 12, "mail"), ("arm", 0, 12, "mail"), ("leg", 0, 12, "mail")]},
            {"tier": "T4", "pal": "silversteel", "on": ["helm", "chest", "belt", "panel_f", "panel_b", "tasset", "sleeve", "bracer", "pauldron", "thigh", "boot", "toe"],
             "inner": [("torso", 0, 12, "mail"), ("arm", 0, 12, "mail"), ("leg", 0, 12, "mail")]},
            {"tier": "T5", "pal": "embersteel", "on": ["helm", "visor", "chest", "belt", "panel_f", "panel_b", "tasset", "sleeve", "bracer", "pauldron", "reinforce", "flare", "thigh", "knee", "boot", "toe"],
             "inner": [("torso", 0, 12, "mail"), ("arm", 0, 12, "mail"), ("leg", 0, 12, "mail")],
             "paint": {"helm": {"style": "plate", "cut": "open_face", "edge": "trim"}, "reinforce": {"style": "plate", "cut": "full", "edge": "trim"},
                       "flare": {"style": "plate", "cut": "full", "edge": "trim"}, "panel_f": {"style": "cloth", "cut": "tabard"},
                       "panel_b": {"style": "cloth", "cut": "tabard"}}},
            {"tier": "T6", "pal": "abyssal_steel", "on": ["helm", "visor", "chest", "belt", "panel_f", "panel_b", "tasset", "sleeve", "bracer", "pauldron", "reinforce", "flare", "spike", "thigh", "knee", "boot", "toe"],
             "inner": [("torso", 0, 12, "mail"), ("arm", 0, 12, "mail"), ("leg", 0, 12, "mail")],
             "paint": {"helm": {"style": "plate", "cut": "open_face", "edge": "trim"}, "reinforce": {"style": "plate", "cut": "full", "edge": "trim"},
                       "flare": {"style": "plate", "cut": "full", "edge": "trim"}, "panel_f": {"style": "cloth", "cut": "tabard"},
                       "panel_b": {"style": "cloth", "cut": "tabard"}}},
        ],
    },
    "leather": {
        "name": "Leder", "who": "Späher",
        "idea": "Weich, warm, matt; Riemen und Lagen statt Platten. Kappe → Kapuze → Kapuze mit Maske; Weste → Wams → Schuppenwams; langer Mantelschoß hinten, Schultermantel oben.",
        "paint": {
            "helm": {"style": "soft", "cut": "hood", "lining": True}, 
            "chest": {"style": "soft", "cut": "full", "strap": True}, "belt": {"style": "leather", "cut": "full", "buckle": True},
            "panel_f": {"style": "soft", "cut": "coat_short"}, "panel_b": {"style": "soft", "cut": "coat", "hem": True},
            "tasset": {"style": "hard", "cut": "full"}, "sleeve": {"style": "soft", "cut": "full"},
            "bracer": {"style": "hard", "cut": "full", "laces": True}, "pauldron": {"style": "hard", "cut": "full"},
            "reinforce": {"style": "scale", "cut": "full"}, "flare": {"style": "hard", "cut": "full"},
            "spike": {"style": "hard", "cut": "full"}, "thigh": {"style": "hard", "cut": "full", "laces": True},
            "knee": {"style": "hard", "cut": "full"}, "boot": {"style": "soft", "cut": "full", "cuff": True},
            "toe": {"style": "hard", "cut": "full"}, "visor": {"style": "hard", "cut": "full"},
        },
        "tiers": [
            {"tier": "T1", "pal": "light", "on": ["helm", "chest", "thigh", "boot"],
             "inner": [("torso", 0, 12, "cloth"), ("arm", 0, 8, "cloth"), ("leg", 0, 12, "trousers")],
             "paint": {"helm": {"style": "soft", "cut": "capsoft"}, "chest": {"style": "soft", "cut": "vest"}}},
            {"tier": "T2", "pal": "cured", "on": ["helm", "chest", "belt", "pauldron", "thigh", "boot"],
             "inner": [("torso", 0, 12, "cloth"), ("arm", 0, 8, "cloth"), ("leg", 0, 12, "trousers")],
             "paint": {"helm": {"style": "soft", "cut": "capsoft"}, "chest": {"style": "soft", "cut": "vest"}}},
            {"tier": "T3", "pal": "heavy_leather", "on": ["helm", "chest", "belt", "panel_f", "panel_b", "sleeve", "pauldron", "thigh", "boot"],
             "inner": [("torso", 0, 12, "cloth"), ("arm", 0, 12, "cloth"), ("leg", 0, 12, "trousers")]},
            {"tier": "T4", "pal": "hardened", "on": ["helm", "chest", "belt", "panel_f", "panel_b", "sleeve", "bracer", "pauldron", "thigh", "boot"],
             "inner": [("torso", 0, 12, "cloth"), ("arm", 0, 12, "cloth"), ("leg", 0, 12, "trousers")]},
            {"tier": "T5", "pal": "sleek", "on": ["helm", "visor", "chest", "belt", "panel_f", "panel_b", "tasset", "sleeve", "bracer", "pauldron", "thigh", "knee", "boot"],
             "inner": [("torso", 0, 12, "cloth"), ("arm", 0, 12, "cloth"), ("leg", 0, 12, "trousers")],
             "paint": {"helm": {"style": "soft", "cut": "hood_mask", "lining": True}, "chest": {"style": "scale", "cut": "full", "strap": True}}},
            {"tier": "T6", "pal": "nightscale", "on": ["helm", "visor", "chest", "belt", "panel_f", "panel_b", "tasset", "sleeve", "bracer", "pauldron", "thigh", "knee", "boot"],
             "inner": [("torso", 0, 12, "cloth"), ("arm", 0, 12, "cloth"), ("leg", 0, 12, "trousers")],
             "paint": {"helm": {"style": "soft", "cut": "hood_mask", "lining": True}, "chest": {"style": "scale", "cut": "full", "strap": True},
                       "thigh": {"style": "scale", "cut": "full"}}},
        ],
    },
    "cloth": {
        "name": "Stoff", "who": "Magier, Priester",
        "idea": "Ruhig, große Farbflächen, senkrechte Bahnen; Tunika → Robe (Schöße lang) → Robe mit Kragenmantel. Stola vorne als Zone A, Saum und Edelstein als Zone B, Kapuze mit Spitze.",
        "paint": {
            "helm": {"style": "soft", "cut": "hood", "lining": True}, 
            "chest": {"style": "soft", "cut": "full", "stole": True}, "belt": {"style": "cloth", "cut": "full", "buckle": True},
            "panel_f": {"style": "soft", "cut": "robe", "stole": True, "hem": True}, "panel_b": {"style": "soft", "cut": "robe", "hem": True},
            "tasset": {"style": "soft", "cut": "full", "hem": True}, "sleeve": {"style": "soft", "cut": "full"},
            "bracer": {"style": "soft", "cut": "full", "hem": True}, "pauldron": {"style": "soft", "cut": "full", "hem": True},
            "reinforce": {"style": "soft", "cut": "full", "hem": True}, "flare": {"style": "soft", "cut": "full", "hem": True},
            "spike": {"style": "trim", "cut": "full"}, "thigh": {"style": "soft", "cut": "full"},
            "knee": {"style": "soft", "cut": "full"}, "boot": {"style": "soft", "cut": "full"},
            "toe": {"style": "soft", "cut": "full"}, "visor": {"style": "soft", "cut": "full"},
        },
        "tiers": [
            {"tier": "T1", "pal": "patch", "on": ["helm", "chest", "thigh", "boot"],
             "inner": [("torso", 0, 12, "robe"), ("arm", 0, 12, "robe"), ("leg", 0, 12, "trousers")],
             "paint": {"chest": {"style": "soft", "cut": "full", "patches": True}, "belt": {"style": "leather", "cut": "full"}}},
            {"tier": "T2", "pal": "woven", "on": ["helm", "chest", "belt", "thigh", "boot"],
             "inner": [("torso", 0, 12, "robe"), ("arm", 0, 12, "robe"), ("leg", 0, 12, "trousers")],
             "paint": {"belt": {"style": "leather", "cut": "full"}}},
            {"tier": "T3", "pal": "heavy_cloth", "on": ["helm", "chest", "belt", "panel_f", "panel_b", "sleeve", "thigh", "boot"],
             "inner": [("torso", 0, 12, "robe"), ("arm", 0, 12, "robe"), ("leg", 0, 12, "robe")]},
            {"tier": "T4", "pal": "silkweave", "on": ["helm", "chest", "belt", "panel_f", "panel_b", "sleeve", "thigh", "boot"],
             "inner": [("torso", 0, 12, "robe"), ("arm", 0, 12, "robe"), ("leg", 0, 12, "robe")]},
            {"tier": "T5", "pal": "silk", "on": ["helm", "visor", "chest", "belt", "panel_f", "panel_b", "tasset", "sleeve", "thigh", "boot"],
             "inner": [("torso", 0, 12, "robe"), ("arm", 0, 12, "robe"), ("leg", 0, 12, "robe")]},
            {"tier": "T6", "pal": "stormweave", "on": ["helm", "visor", "chest", "belt", "panel_f", "panel_b", "tasset", "sleeve", "thigh", "boot"],
             "inner": [("torso", 0, 12, "robe"), ("arm", 0, 12, "robe"), ("leg", 0, 12, "robe")]},
        ],
    },
}

BUDGET_BOXES = 45
BODY_VERTICES = 192   # grug_visuals_character.b3d: body 168 + cloak 24


def boxes():
    """Every box of the model (mirrored copies counted), as dicts."""
    out = []
    for area, sid, label, bone, box, ex in SHAPES:
        out.append({"area": area, "id": sid, "label": label, "bone": bone, "box": box,
                    "mirror": bool(ex.get("mirror")), "rot": ex.get("rot")})
    return out


def poly_parts():
    """[(area, id, label, shell, schema dict, repo path)] of the polygon parts."""
    import json
    from pathlib import Path
    repo = Path(__file__).resolve().parents[2]
    return [(area, pid, label, shell, json.loads((repo / path).read_text()), path)
            for area, pid, label, shell, path in POLY_PARTS]


def box_count():
    return sum(2 if s["mirror"] else 1 for s in boxes())

"""Compose one default look per race (skin tone, body, eyes, hair, feature) as
in mods/PLAYER/grug_visuals/looks.lua `look_texture`, with and without hair
(a helmet hides the hair in the game)."""
from PIL import Image
from pathlib import Path
T = Path(__file__).resolve().parents[2] / "mods" / "PLAYER" / "grug_visuals" / "textures"
P = "grug_visuals_"

LOOKS = {  # race: tone, hair colour, style, eyes colour, feature, feature tint ("hair"/"tone"/None)
    "human": ("#e0b08c", "#603c22", "crop", "#2a3c62", "stubble", "hair"),
    "dwarf": ("#d8a07c", "#9c3a1c", "braid", "#4a2e16", "full", "hair"),
    "elf": ("#eedec8", "#e4d8a8", "long", "#6c9878", "pointed", "tone"),
    "orc": ("#6c9448", "#222024", "topknot", "#d04830", "tusks_small", None),
    "troll": ("#608496", "#2e3a60", "crest", "#eec44c", "tusks_large", None),
    "undead": ("#96a48c", "#58525e", "stringy", "#c6de70", "jaw", None),
}
STATURE = {"human": 1.0, "dwarf": 0.9, "elf": 1.06, "undead": 0.94, "orc": 1.08, "troll": 1.12}


def load(name):
    return Image.open(T / (P + name + ".png")).convert("RGBA")


def tint(img, hexcol):
    c = tuple(int(hexcol[i:i + 2], 16) for i in (1, 3, 5))
    out = img.copy(); px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r * c[0] // 255, g * c[1] // 255, b * c[2] // 255, a)
    return out


def first(*names):
    for n in names:
        if (T / (P + n + ".png")).exists():
            return n
    return None


def compose(race, hair=True):
    tone, haircol, style, eyes, feature, ftint = LOOKS[race]
    img = tint(load("skin_mask"), tone)
    img.alpha_composite(load(f"{race}_body"))
    em = first(f"eyes_{race}_mask") or ("eyes_undead_mask" if race == "undead" else "eyes_mask")
    img.alpha_composite(tint(load(em), eyes))
    if hair and style:
        stem = first(f"{race}_hair_{style}")
        if stem:
            if (T / (P + stem + "_mask.png")).exists():
                img.alpha_composite(tint(load(stem + "_mask"), haircol))
            img.alpha_composite(load(stem))
    stem = first(f"{race}_feature_{feature}")
    if stem:
        if ftint and (T / (P + stem + "_mask.png")).exists():
            img.alpha_composite(tint(load(stem + "_mask"), haircol if ftint == "hair" else tone))
        img.alpha_composite(load(stem))
    return img

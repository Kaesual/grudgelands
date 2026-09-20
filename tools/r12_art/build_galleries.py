#!/usr/bin/env python3
"""Build labelled native and nearest-neighbour before/after review plates."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import hashlib

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
EVIDENCE = HERE / "evidence"
COOK = ROOT / "mods/ITEMS/grug_cooking/textures"
GEAR = ROOT / "mods/ITEMS/grug_gear/textures"

TIERS = ["#a97945", "#bb8055", "#8f6b52", "#72928a", "#667f91", "#80649b"]
DISHES = [
    ("hearty_stew", "hearty", 1), ("sweetroot_mash", "caster", 1),
    ("corn_crusted_fish", "hunter", 1), ("pumpkin_stew", "hearty", 2),
    ("berry_preserve", "caster", 2), ("fruit_glazed_roast", "hunter", 2),
    ("foragers_pot", "hearty", 3), ("mushroom_skewer", "caster", 3),
    ("onion_seared_steak", "hunter", 3), ("marsh_roast", "hearty", 4),
    ("marshbloom_chowder", "caster", 4), ("hunters_feast", "hunter", 4),
    ("kelp_wrapped_roast", "hearty", 5), ("stormkelp_broth", "caster", 5),
    ("salt_crusted_fish", "hunter", 5), ("grand_feast", "hearty", 6),
    ("jungle_cocoa", "caster", 6), ("cocoa_rubbed_game", "hunter", 6),
]
RAW = ["raw_stew_pot", "raw_pumpkin_pot", "raw_foragers_pot",
       "raw_marsh_roast", "raw_kelp_roast", "raw_grand_feast"]
MATERIALS = ["bronze", "iron", "steel", "silversteel", "embersteel", "abyssal_steel"]


def colorize(source, color, amount):
    src = Image.open(source).convert("RGBA")
    overlay = Image.new("RGBA", src.size, color)
    mixed = Image.blend(src, overlay, amount / 255.0)
    mixed.putalpha(src.getchannel("A"))
    return mixed


def sheet(rows, scale, path, columns=3):
    cell_w, cell_h = max(190, scale * 32 + 32), max(54, scale * 16 + 34)
    result = Image.new("RGBA", (cell_w * columns,
        cell_h * ((len(rows) + columns - 1) // columns)), "#202020")
    draw = ImageDraw.Draw(result)
    for index, (label, before, after) in enumerate(rows):
        x = (index % columns) * cell_w
        y = (index // columns) * cell_h
        before = before.resize((16 * scale, 16 * scale), Image.Resampling.NEAREST)
        after = after.resize((16 * scale, 16 * scale), Image.Resampling.NEAREST)
        result.alpha_composite(before, (x + 4, y + 14))
        result.alpha_composite(after, (x + 12 + 16 * scale, y + 14))
        draw.text((x + 4, y + 2), label, fill="white")
        draw.text((x + 4, y + 14 + 16 * scale), "before  ->  after", fill="#bfc4c8")
    result.save(path)


def main():
    bases = {
        "hearty": ROOT / "mods/BASE/default/textures/default_clay_lump.png",
        "caster": ROOT / "mods/BASE/default/textures/default_apple.png",
        "hunter": ROOT / "mods/ENTITIES/grug_mobs/textures/grug_mobs_item_raw_fish.png",
    }
    food_rows = []
    for name, role, tier in DISHES:
        before = colorize(bases[role], TIERS[tier - 1], 125)
        after = Image.open(COOK / ("grug_cooking_dish_" + name + ".png")).convert("RGBA")
        food_rows.append((name, before, after))
    clay = ROOT / "mods/BASE/default/textures/default_clay_lump.png"
    for tier, name in enumerate(RAW, 1):
        food_rows.append((name, colorize(clay, TIERS[tier - 1], 175),
            Image.open(COOK / ("grug_cooking_" + name + ".png")).convert("RGBA")))
    food_rows.append(("bread", colorize(clay, "#d8a552", 145),
        Image.open(COOK / "grug_cooking_bread.png").convert("RGBA")))
    meat_path = ROOT / "mods/ENTITIES/mobs/textures/mobs_meat.png"
    fish_path = ROOT / "mods/ENTITIES/grug_mobs/textures/grug_mobs_item_raw_fish.png"
    meat = Image.open(meat_path).convert("RGBA")
    fish = Image.open(fish_path).convert("RGBA")
    cooked_fish = ImageChops.multiply(fish, Image.new("RGBA", fish.size, "#d59a5a"))
    food_rows.extend([("cooked_meat (retained)", meat, meat),
        ("cooked_fish (retained)", cooked_fish, cooked_fish)])
    sheet(food_rows, 1, EVIDENCE / "food-before-after-native.png")
    sheet(food_rows, 6, EVIDENCE / "food-before-after-6x.png", 2)

    weapon_rows = []
    mese = ROOT / "mods/BASE/default/textures/default_mese_crystal_fragment.png"
    for material in MATERIALS:
        wand = Image.open(GEAR / ("grug_gear_item_wand_" + material + ".png")).convert("RGBA")
        # Old registration colorized one Mese fragment; the base silhouette is
        # the important before evidence and is preserved exactly here.
        weapon_rows.append(("wand_" + material, Image.open(mese).convert("RGBA"), wand))
    for material in MATERIALS:
        old = Image.open(EVIDENCE / "before" / ("grug_gear_item_greataxe_" + material + ".png")).convert("RGBA")
        new = Image.open(GEAR / ("grug_gear_item_greataxe_" + material + ".png")).convert("RGBA")
        weapon_rows.append(("greataxe_" + material, old, new))
    sheet(weapon_rows, 1, EVIDENCE / "weapons-before-after-native.png")
    sheet(weapon_rows, 8, EVIDENCE / "weapons-before-after-8x.png", 2)
    # Regenerate all supplemental plates, so no superseded visual remains.
    sheet([(label, after, after) for label, before, after in food_rows],
          8, EVIDENCE / "food-after-8x.png", 2)
    sheet([(label, after, after) for label, before, after in weapon_rows],
          10, EVIDENCE / "weapons-after-10x.png", 2)

    files = sorted(list(COOK.glob("grug_cooking_dish_*.png")) +
        list(COOK.glob("grug_cooking_raw_*.png")) + [COOK / "grug_cooking_bread.png"] +
        list(GEAR.glob("grug_gear_item_wand_*.png")) +
        list(GEAR.glob("grug_gear_item_greataxe_*.png")) + [meat_path, fish_path])
    lines = []
    for path in files:
        lines.append(hashlib.sha256(path.read_bytes()).hexdigest() + "  " +
            str(path.relative_to(ROOT)))
    (EVIDENCE / "assets.sha256").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__": main()

"""Check the Round 88 bottle manifest against the Lua sources and approved PNGs."""

import json
import re
from pathlib import Path

from PIL import Image

from draw_proposals import filename, ranked

HERE = Path(__file__).resolve().parent
MODS = HERE.parents[1] / "mods"
ALCHEMY = MODS / "ITEMS/grug_alchemy"
TRADERS = MODS / "ENTITIES/grug_traders"
PICKS = {
    "healing": "A", "vigor": "A", "mana": "A", "focus": "A", "precision": "A",
    "stoneskin": "B", "antivenom": "B", "swiftness": "A", "cave": "A",
    "deepwater": "A", "merchant": "B",
}


def lua(path):
    return re.sub(r"--[^\n]*", "", path.read_text())


def captures(pattern, source):
    match = re.search(pattern, source, re.MULTILINE)
    if not match:
        raise ValueError(f"Missing Lua registration pattern: {pattern}")
    return match.groups()


def registrations():
    """Expand the three recipe constructors into (item id, recipe tier) pairs."""
    recipes = lua(ALCHEMY / "recipes.lua")
    effects = lua(ALCHEMY / "effects.lua")
    namespace, = captures(r'core\.register_craftitem\("([^"]+:)"\s*\.\.\s*id,', effects)
    potion, = captures(r'^local function potion\(tier, kind\)([\s\S]*?)^end\b', recipes)
    elixir, = captures(r'^local function elixir\(tier, def\)([\s\S]*?)^end\b', recipes)
    special, = captures(r'^local function special\(tier, def\)([\s\S]*?)^end\b', recipes)
    for constructor, argument in ((potion, "id"), (elixir, "id"), (special, r"def\.id")):
        captures(r"grug_alchemy\.register_consumable\(" + argument + ",", constructor)

    first, last, loop = captures(r'^for tier = (\d+), (\d+) do([\s\S]*?)^end\b', recipes)
    condition, yes, no = captures(
        r'local id = \(kind == "(\w+)" and "(\w+)" or "(\w+)"\) \.\. tier', potion
    )
    kinds = re.findall(r'potion\(tier, "(\w+)"\)', loop)
    stems = [yes if kind == condition else no for kind in kinds]
    prefix, suffix = captures(r'local id = "(\w+)" \.\. def\.key \.\. "(\w+)" \.\. tier', elixir)
    elixirs, = captures(r'^local ELIXIRS = \{([\s\S]*?)^\}', recipes)
    captures(r'ipairs\(ELIXIRS\) do\s*catalog\[#catalog \+ 1\] = elixir\(tier, def\)', loop)
    stems.extend(prefix + key + suffix for key in re.findall(r'\bkey = "(\w+)"', elixirs))
    tiers = range(int(first), int(last) + 1)
    items = {(namespace + stem + str(tier), tier) for stem in stems for tier in tiers}

    utility, = captures(r'^local UTILITY = \{([\s\S]*?)^\}', recipes)
    captures(r'ipairs\(UTILITY\[tier\] or \{\}\) do\s*catalog\[#catalog \+ 1\] = special\(tier, def\)', loop)
    for tier, rows in re.findall(r'\[(\d+)\] = \{([\s\S]*?)^\s*\},', utility, re.MULTILINE):
        if int(tier) in tiers:
            items.update((namespace + name, int(tier)) for name in re.findall(r'\bid = "(\w+)"', rows))

    trader_items = re.findall(r'core\.register_craftitem\("([^"]+)"', lua(TRADERS / "potion.lua"))
    items.update((name, None) for name in trader_items)
    return items


def pixels(path):
    with Image.open(path) as image:
        if (image.format, image.size, image.mode) != ("PNG", (16, 16), "RGBA"):
            raise ValueError(f"{path}: expected a 16 × 16 RGBA PNG")
        return image.tobytes()


def main():
    rows = json.loads((HERE / "game_textures.json").read_text())
    by_texture = {row["texture"]: row for row in rows}
    if len(rows) != len(by_texture):
        raise ValueError("Duplicate texture in manifest")
    registered = registrations()
    for family, letter in PICKS.items():
        for rank in range(1, 7) if ranked(family) else (None,):
            suffix = f"_t{rank}" if rank else ""
            if family == "merchant":
                owner = TRADERS
                texture = "grug_traders_potion_healing_weak_bottle.png"
                names = {"grug_traders:potion_healing_weak"}
            else:
                owner = ALCHEMY
                texture = f"grug_alchemy_{family}{suffix}.png"
                names = {f"grug_alchemy:{kind}_{family}{suffix}" for kind in ("potion", "elixir")}
            row = by_texture.pop(texture)
            item, tier = row["item_id"], row["tier"]
            if row["family"] != family or item not in names or (item, tier) not in registered:
                raise ValueError(f"{texture}: incorrect family, item id or recipe tier in {row}")
            proposal = HERE / "proposals" / filename(family, letter, rank)
            if pixels(owner / "textures" / texture) != pixels(proposal):
                raise ValueError(f"{texture}: pixels differ from {proposal.name}")
    if by_texture:
        raise ValueError(f"Unexpected textures in manifest: {sorted(by_texture)}")
    print(f"PASS: {len(rows)} picked 16 × 16 RGBA PNGs, all pixels and registered item ids match.")


if __name__ == "__main__":
    main()

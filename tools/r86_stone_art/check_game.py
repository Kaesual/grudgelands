"""Verify the game assets against the pick and write renders/game_files.png.

Run from the repository root with python3 -B tools/r86_stone_art/check_game.py.
"""

import json
import re
import subprocess

from PIL import Image

from build import sheet
from paint import KINDS, ROOT, STATES
from render import cell_set, world_view

REPO = ROOT.parents[1]
HOUSING = REPO / "mods/PLAYER/grug_housing"
TEXTURES = HOUSING / "textures"
MAP = REPO / "mods/PLAYER/grug_map"
PICK = ROOT / "art/roof"


def load_table():
    # An empty environment also catches accidental dependencies on game globals.
    lua = """
        local read_art = assert(loadfile("mods/PLAYER/grug_housing/stone_art.lua"))
        local env = {}
        setfenv(read_art, env)
        local art = read_art()
        assert(next(env) == nil)
        print(dofile("tools/r28_b4_quests/json.lua").encode(art))
    """
    return json.loads(subprocess.check_output([REPO / "tools/bin/lua51", "-e", lua], cwd=REPO))


def grid_boxes(shape):
    assert shape["type"] == "fixed" and shape["fixed"], shape
    boxes = []
    for box in shape["fixed"]:
        assert len(box) == 6 and all(-0.5 <= n <= 0.5 and n * 16 % 1 == 0 for n in box), box
        assert all(box[i] < box[i + 3] for i in range(3)), box
        boxes.append(tuple(int(n * 16) for n in box))
    return boxes


def png(path, size):
    with Image.open(path) as im:
        assert (im.format, im.size, im.mode) == ("PNG", (size, size), "RGBA"), path
        return im.copy()


def read_faces(specs, state):
    tiles, names = [], []
    assert len(specs) == 6, specs
    opacity = 255
    for spec in specs:
        name, _, finish = spec.partition("^")
        names.append(name)
        tile = png(TEXTURES / name, 16)
        if state == "draft":
            wash = re.fullmatch(r"\[colorize:(#[0-9a-f]{6}):(\d+)\^\[opacity:(\d+)", finish)
            assert wash, spec
            colour, strength, alpha = wash.groups()
            opacity = int(alpha)
            assert opacity == 150 and 0 <= int(strength) <= 255, spec
            tile = Image.blend(tile, Image.new("RGBA", tile.size, colour), int(strength) / 255)
        else:
            assert spec == name, spec
        tiles.append(tile)
    return tiles, names, opacity


def check():
    art = load_table()
    assert set(art) == {"", "account"}
    scenes, icons, used = {}, {}, set()
    masters = json.loads((PICK / "nodes.json").read_text())["variants"]
    picked_sheet = Image.open(ROOT / "renders/roof.png").convert("RGB")

    for row, kind in enumerate(KINDS):
        variant = art["" if kind == "personal" else kind]
        for col, state in enumerate(STATES):
            node = variant[state]
            boxes = grid_boxes(node["node_box"])
            tiles, names, opacity = read_faces(node["tiles"], state)
            used.update(names)
            scene, _ = world_view(boxes, tiles, opacity)
            scenes[kind, state] = scene

            # Compare every occupied cell and every face, including those
            # hidden in the three-quarter view. Masters are comparison inputs.
            master = masters[kind]["active" if state == "draft" else state]
            cells = cell_set(master["boxes"])
            assert cell_set(boxes) == cells, (kind, state, "node_box")
            for key in ("selection_box", "collision_box"):
                assert cell_set(grid_boxes(node[key])) == cells, (kind, state, key)
            for name, original in zip(names, master["tiles"]):
                assert (TEXTURES / name).read_bytes() == (PICK / original).read_bytes(), name

            x, y = 118 + 385 * col, 150 + 247 * row
            panel = picked_sheet.crop((x, y, x + scene.width, y + scene.height))
            assert scene.tobytes() == panel.tobytes(), (kind, state, "different from the pick")

        item = variant["inventory_image"]
        used.add(item)
        icons[kind] = png(TEXTURES / item, 16)
        assert variant["wield_image"] == item
        original_item = png(PICK / masters[kind]["active"]["inventory_image"], 16)
        assert icons[kind].tobytes() == original_item.tobytes(), item
        assert variant["marker_texture"] == variant["active"]["tiles"][5]

    assert used == {path.name for path in TEXTURES.glob("grug_housing_stone_*.png")}
    licence = (HOUSING / "LICENSE-media.md").read_text()
    assert all(f"`textures/{name}`" in licence for name in used)
    # Ruling 19: home names keep the shipped cottage; the drawn doorway
    # (art/home_name.png) is not in the game.
    assert not (MAP / "textures/grug_map_home_name.png").exists()
    house = png(MAP / "textures/grug_map_home.png", 32)

    marker = png(TEXTURES / art[""]["marker_texture"], 16)
    counts = [len(art[k]["active"]["node_box"]["fixed"]) for k in ("", "account")]
    caption = f"Game files · Personal and account carvings use {counts[0]} and {counts[1]} fixed boxes."
    sheet("roof", scenes, icons, marker, house, caption).save(ROOT / "renders/game_files.png")
    print(f"PASS: 6 pixel-identical views, boxes on-grid and in bounds, "
          f"{len(used)} stone PNGs; the shipped cottage for home names.")


if __name__ == "__main__":
    check()

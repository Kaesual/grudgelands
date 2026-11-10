#!/usr/bin/env python3
"""Focused static contract for display persistence through the reset packer."""
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
sys.path.insert(0, str(root))
from tools.migration import codec, pack  # noqa: E402
packed = (root / "mods/PLAYER/grug_housing/packed.lua").read_text()
pack_tool = (root / "tools/migration/pack.py").read_text()
nodes = {
    "grug_decor:xdecor_itemframe": {"item": 1},
    "grug_displays:frame_iron": {"item": 1},
    "grug_displays:frame_carved": {"item": 1},
    "grug_displays:frame_brass": {"item": 1},
    "grug_displays:armor_stand": {"head": 1, "chest": 1, "legs": 1, "feet": 1},
    "grug_displays:armor_stand_iron": {"head": 1, "chest": 1, "legs": 1, "feet": 1},
    "grug_displays:armor_stand_carved": {"head": 1, "chest": 1, "legs": 1, "feet": 1},
    "grug_displays:weapon_holder": {"item": 1},
}
checks = 0
for name, lists in nodes.items():
    match = re.search(r'\["' + re.escape(name) + r'"\]\s*=\s*\{([^}]*)\}', packed)
    assert match, f"missing packed-container row for {name}"
    for listname, size in lists.items():
        assert re.search(rf"\b{listname}\s*=\s*{size}\b", match.group(1)), (name, listname)
        checks += 1
assert "if meta.lists:" in pack_tool and "list(inv.items)" in pack_tool
checks += 2

# The generic scanner/packer must preserve the complete serialized stack,
# including per-stack appearance metadata, in its original display slot.
enchanted = 'grug_gear:head_metal_iron 1 1234 "\\u0001inventory_image\\u0002rare.png\\u0003"'
container = pack.Container((1, 2, 3), "grug_displays:armor_stand", {
    "head": [enchanted], "chest": [""], "legs": [""], "feet": [""]})
stack = codec.ItemStack.parse(pack.packed_string(container, 7))
decoded = codec.deserialize(stack.meta["lists"])
assert decoded["head"][0] == enchanted and stack.meta["node"] == container.node
checks += 2

# Unpack fills the node lists and calls its put callback, which is the display
# refresh seam; no display-specific unpack branch is needed.
assert "def.on_metadata_inventory_put(pos, listname" in packed
checks += 1
print(f"r75 displays pack: {checks} passed, 0 failed")

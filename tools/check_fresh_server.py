#!/usr/bin/env python3
"""Guard the explicitly removed old-world compatibility mechanisms."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
removed = (
    "mods/BASE/default/aliases.lua",
    "mods/BASE/default/legacy.lua",
    "mods/ENTITIES/mobs/compatibility.lua",
    "mods/ITEMS/grug_nodes/ore_respawn.lua",
    "mods/ITEMS/grug_materials/migration.lua",
)
errors = [f"obsolete file remains: {path}" for path in removed if (ROOT / path).exists()]
for path in (ROOT / "mods").rglob("*.lua"):
    source = path.read_text()
    relative = path.relative_to(ROOT)
    for number, line in enumerate(source.splitlines(), 1):
        code = line.split("--", 1)[0]
        if re.search(r"legacy_(?:mineral|facedir_simple|wallmounted)\s*=", code):
            errors.append(f"{relative}:{number}: old mapblock conversion flag")
        if any(token in code for token in (
            "LEGACY_ALIASES", "compatibility_check", "function mobs:alias_mob",
            "default:3dtorch", "default:convert_saplings_to_node_timer",
            "enable_stairs_replace_abm", "group:slabs_replace",
            '"grug_nodes:depleted_vein"', '"grug_mobs:camp_fire"',
            "function creative.is_enabled_for",
        )):
            errors.append(f"{relative}:{number}: retired compatibility mechanism")
        if re.search(r"\b(?:core|minetest)\.register_alias(?:_force)?\s*\(", code):
            # Native mapgen aliases are used on every fresh world by C++.
            if relative.as_posix() != "mods/BASE/default/mapgen.lua":
                errors.append(f"{relative}:{number}: unexpected item-name alias")

# These are normal current-version activation, not migration; do not remove
# them by indiscriminately deleting every load-time callback.
assert '"close opened chests on load"' in (ROOT / "mods/BASE/default/chests.lua").read_text()
assert "register_sapling_growth" in (ROOT / "mods/BASE/default/trees.lua").read_text()
assert "core.serialize(clean_staticdata(self))" in (ROOT / "mods/ENTITIES/mobs/api.lua").read_text()
if errors:
    raise SystemExit("\n".join(errors))
print("Fresh-server source audit: PASS")

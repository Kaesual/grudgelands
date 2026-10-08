#!/usr/bin/env python3
"""Guard the removed development-era compatibility mechanisms.

Release mode (since 0.41.0, AGENTS.md "Release mode"): worlds survive upgrades
through the hosting platform's contract, never through data migrations. The
mechanisms the fresh-server development mode removed stay removed. Ids of
quests, items, achievements and waypoints stay stable; a renamed item may keep
its old name with `register_alias`, so aliases are no longer refused here.

Also (Round 44): the baked map art's Lua copy is current
(tools/r44_mb/gen_baked_art.py --check and its decoder self-test), since art
changed without regenerating grug_map/baked_art.lua would keep the old art
under the old map cache key.
"""
from pathlib import Path
import re
import sys

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
            "LEGACY_ALIASES", "def.attacks_monsters", "compatibility_check", "function mobs:alias_mob",
            "default:3dtorch", "default:convert_saplings_to_node_timer",
            "enable_stairs_replace_abm", "group:slabs_replace",
            '"grug_nodes:depleted_vein"', '"grug_mobs:camp_fire"',
            "function creative.is_enabled_for",
        )):
            errors.append(f"{relative}:{number}: retired compatibility mechanism")

# These are normal current-version activation, not migration; do not remove
# them by indiscriminately deleting every load-time callback.
assert '"close opened chests on load"' in (ROOT / "mods/BASE/default/chests.lua").read_text()
assert "register_sapling_growth" in (ROOT / "mods/BASE/default/trees.lua").read_text()
assert "core.serialize(clean_staticdata(self))" in (ROOT / "mods/ENTITIES/mobs/api.lua").read_text()
sys.path.insert(0, str(ROOT / "tools/r44_mb"))
import gen_baked_art  # noqa: E402

errors += ["baked art decoder self-test: " + failure for failure in gen_baked_art.self_test()]
baked = ROOT / gen_baked_art.OUTPUT
if not baked.exists() or baked.read_text(encoding="utf-8") != gen_baked_art.build(gen_baked_art.DEFAULT_ART):
    errors.append(f"{gen_baked_art.OUTPUT} is stale: run python3 tools/r44_mb/gen_baked_art.py")
if errors:
    raise SystemExit("\n".join(errors))
print("Release-mode source audit and baked map art: PASS")

"""The node facts the authoring helpers need (Round 73 TOOLS), from the registry
tools/building_templates/nodes.json, read once.

    import registry
    registry.walkable("grug_nodes:moss_carpet")     # False: it may lie on a walking cell
    registry.light("grug_decor:xdecor_candle")       # 12
    registry.stair_sets()                            # the 31 materials with a stair set
"""
import json
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# The mod's own nodes are not in the registry (template.py OWN_NODES): walkable all.
OWN = ("grug_expeditions:waystone", "grug_expeditions:reward_chest", "grug_expeditions:reward_door")


@lru_cache(maxsize=1)
def nodes():
    data = json.loads((ROOT / "tools/building_templates/nodes.json").read_text())
    return data["nodes"] if "nodes" in data else data


def definition(name):
    if name in OWN:
        return {"walkable": True, "drawtype": "normal", "paramtype": "none"}
    if name not in nodes():
        raise ValueError(f"a node the registry does not know: {name}")
    return nodes()[name]


def walkable(name):
    return name != "air" and definition(name).get("walkable", True)


def light(name):
    """A node's own light, the engine's cap of 14 applied."""
    return min(definition(name).get("light_source", 0) or 0, 14)


def lets_light(name):
    """Light passes into the node (c_content.cpp: light_propagates = paramtype light)."""
    return definition(name).get("paramtype") == "light"


def liquid(name):
    return definition(name).get("liquidtype", "none") != "none"


def harvest(name):
    """A gathering source or a crop: loot outside the chest (concept §4.7)."""
    groups = definition(name).get("groups", {})
    return (name.startswith(("grug_gathering:", "grug_farming:")) or
            (name.startswith("grug_mapgen:") and name.endswith("_source")) or
            groups.get("plant", 0) > 0 or groups.get("crop", 0) > 0)


@lru_cache(maxsize=1)
def stair_sets():
    """The materials with all three stair shapes (concept §4.1.8)."""
    names = nodes()
    prefix = "stairs:stair_"
    return tuple(sorted(n[len(prefix):] for n in names
                        if n.startswith(prefix) and not n.startswith((prefix + "inner_", prefix + "outer_"))
                        and prefix + "inner_" + n[len(prefix):] in names
                        and prefix + "outer_" + n[len(prefix):] in names))

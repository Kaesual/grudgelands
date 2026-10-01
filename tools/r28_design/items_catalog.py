#!/usr/bin/env python3
"""Build the Round 28 designers' catalogue of existing items.

Input: the raw registry dump written by the disposable engine probe
(tools/r28_design/items_probe, run through tools/r28_design/dump_items.sh).
Output: <out_dir>/existing.json (machine-readable, read by validate.py and
ledger.py) and <out_dir>/existing.md (the designer's reference).

Usage: items_catalog.py DUMP_JSON OUT_DIR
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

# Engine/dig/placement groups that say nothing about what kind of thing an
# item is; never offered as quest "group" objectives.
MECHANICAL_GROUPS = {
    "cracky", "snappy", "choppy", "crumbly", "oddly_breakable_by_hand",
    "dig_immediate", "level", "flammable", "attached_node", "falling_node",
    "not_in_creative_inventory", "handy", "axey", "pickaxey", "fleshy",
    "stair", "slab", "door", "fence", "wall", "pane", "node", "liquid",
    "cools_lava", "igniter", "slippery", "snowy", "spreading_dirt_type",
    "crossbrace_connectable", "growing", "leafdecay", "leafdecay_drop",
    "connect_to_raillike", "on_sound", "grug_bound_guard",
    "grug_soulbound_guard", "grug_natural", "grug_loose", "grug_bound_skill",
    "grug_ability", "grug_soulbound", "grug_camp", "grug_claim_stone_node",
    "grug_claim_stone", "grug_farming_crop_helper", "grug_crop_soil",
    "grug_crop_soil_wet", "field", "bed", "torch", "vessel", "lava", "water",
    "grug_stratum", "grug_capital_display", "eatable", "food",
}

# Groups that make sense as "bring N of any ..." objectives. Others with at
# least two carryable members are listed too, but these come first.
RECOMMENDED_GROUPS = {
    "tree": "any log (trunk node)",
    "wood": "any planks",
    "leaves": "any leaves",
    "sapling": "any sapling",
    "stick": "sticks",
    "flora": "any flower or small plant",
    "grass": "any grass tuft",
    "sand": "any sand",
    "stone": "any plain stone / cobble",
    "wool": "any wool",
    "dye": "any dye",
    "seed": "any seed",
    "grug_farming_seed": "any farming seed",
    "grug_food_raw": "any raw food",
    "grug_food_dish": "any cooked dish",
    "food_fish_raw": "any raw fish",
    "grug_leather": "any leather",
    "grug_material": "profession/loot material",
    "grug_profession_material": "processed profession material",
    "grug_healing_herb": "any healing herb",
    "grug_plant_item": "any gathered plant item",
    "grug_cooking_berry": "any berry",
    "grug_cooking_fruit": "any fruit",
    "grug_potion": "any potion",
    "grug_wood_grade": "any seasoned wood grade",
    "grug_tailor_bolt": "any cloth bolt",
}


def tier_of(item):
    """Explicit tier only, with the field it came from; None when unknown."""
    fields = item.get("fields") or {}
    groups = item.get("groups") or {}
    resource = item.get("resource") or {}
    processed = item.get("processed") or {}
    candidates = [
        ("ingredient_tier", item.get("ingredient_tier")),
        ("processed.tier", processed.get("tier")),
        ("resource.harvest_tier", resource.get("tier")),
        ("_grug_tier", fields.get("_grug_tier") if isinstance(fields.get("_grug_tier"), (int, float)) else None),
        ("grug_food_tier", groups.get("grug_food_tier")),
        ("grug_pick_tier", groups.get("grug_pick_tier")),
        ("grug_axe_tier", groups.get("grug_axe_tier")),
        ("grug_shovel_tier", groups.get("grug_shovel_tier")),
        ("_grug_mount_tier", fields.get("_grug_mount_tier")),
    ]
    fishing = [row for row in item.get("fishing") or [] if row.get("fish")]
    if fishing:
        candidates.append(("fishing.band", fishing[0].get("band")))
    for source, value in candidates:
        if isinstance(value, (int, float)) and value > 0:
            return int(value), source
    return None, None


def category_of(name, item):
    groups = item.get("groups") or {}
    mod = name.split(":", 1)[0]
    kind = item.get("type")
    if groups.get("grug_bound_skill") or groups.get("grug_ability") or groups.get("grug_mount"):
        return "skill"
    if kind == "node" and groups.get("grug_resource"):
        return "ore_node"
    if item.get("resource"):
        return "ore_gem_raw"
    if (item.get("processed") or {}).get("kind") == "bar" or item.get("alloy_inputs"):
        return "bar"
    if ":cut_" in name:
        return "gem_cut"
    if groups.get("grug_gear") or any(g.startswith("grug_equip_") for g in groups):
        return "gear"
    if kind == "tool" or groups.get("grug_gathering_tool") or groups.get("grug_farming_hoe"):
        return "tool"
    if any(row.get("fish") for row in item.get("fishing") or []) or groups.get("food_fish_raw"):
        return "fish"
    if item.get("mob_drops") or mod == "grug_mobs":
        return "mob_drop"
    if item.get("food") or groups.get("grug_food"):
        return "food"
    if groups.get("tree") or groups.get("wood") or groups.get("grug_wood_grade") or groups.get("stick"):
        return "wood"
    if (groups.get("grug_profession_material") or groups.get("grug_material") or
            groups.get("grug_leather") or groups.get("grug_tailor_bolt") or
            groups.get("grug_jewellery_setting") or mod == "grug_professions"):
        return "profession_material"
    if mod in ("grug_gathering",) or groups.get("grug_plant_item") or groups.get("grug_healing_herb"):
        return "gathering"
    if mod == "grug_farming":
        return "farming"
    if mod in ("grug_alchemy", "grug_brewing"):
        return "alchemy"
    if kind == "craft":
        return "other_item"
    return "node"


CATEGORY_TITLES = [
    ("ore_gem_raw", "Ores and gems (mined raw items)",
     "Gathering XP: ore 0.10 KE, gem 0.20 KE at the reference level 10 x harvest tier."),
    ("bar", "Bars and alloys", "Normal furnace: one lump, one bar. Dual furnace: two inputs, one alloy bar."),
    ("gem_cut", "Cut gems", ""),
    ("mob_drop", "Mob drops and mob materials", "Today's static drops (chance = 1 in N). Ruling 36 replaces them with band tables."),
    ("fish", "Fish", "Gathering XP: fish 0.33 KE at the reference level 10 x the water's band."),
    ("food", "Food (raw, cooked, found)", ""),
    ("wood", "Wood (logs, planks, sticks, seasoned wood)", ""),
    ("profession_material", "Profession materials", ""),
    ("gathering", "Gathered herbs and plants", ""),
    ("farming", "Farming (seeds, crops, crop nodes)", ""),
    ("alchemy", "Alchemy and brewing", ""),
    ("tool", "Tools", ""),
    ("gear", "Gear (weapons, armour, offhands, trinkets)", ""),
    ("other_item", "Other craft items", ""),
    ("skill", "Skill items (soulbound; never quest items or rewards)", ""),
    ("ore_node", "Ore and gem nodes (dig for the raw item; not quest items)", ""),
    ("node", "Other nodes (building, decor, terrain)", "Names only; see existing.json for groups and descriptions."),
]


def sources_of(item):
    out = []
    for recipe in item.get("engine_recipes") or []:
        method = recipe.get("method")
        tag = {"normal": "grid", "cooking": "furnace"}.get(method, method)
        if tag not in out:
            out.append(tag)
    for route in item.get("profession_recipes") or []:
        tag = "%s T%s" % (route.get("profession"), route.get("tier"))
        if tag not in out:
            out.append(tag)
    if item.get("alloy_inputs"):
        out.append("dual furnace")
    if item.get("resource"):
        out.append("mining")
    if item.get("mob_drops"):
        out.append("mob drop")
    if any(row.get("fish") for row in item.get("fishing") or []):
        out.append("fishing")
    elif item.get("fishing"):
        out.append("fishing junk")
    if item.get("node_drops"):
        out.append("dig")
    return out


def md_escape(text):
    return (text or "").replace("|", "\\|").replace("\n", " ")


def build(dump):
    raw_items = dump["items"]
    curation = dump.get("curation") or {}
    curated_out = []
    for row in curation.get("removed") or []:
        curated_out.append({"name": row["name"], "reason": "content_curation: unregistered (retired tier/duplicate)",
                            "registered": row.get("registered", False)})
    for row in curation.get("removed_mobs_utilities") or []:
        curated_out.append({"name": row["name"], "reason": "content_curation: mobs_redo utility not registered",
                            "registered": row.get("registered", False)})
    for row in curation.get("no_recipe") or []:
        curated_out.append({"name": row["name"], "reason": "content_curation: registered for authored builds, no recipe and no world source",
                            "registered": row.get("registered", True)})
    curated_names = {row["name"] for row in curated_out}

    items = {}
    groups = defaultdict(list)
    for name in sorted(raw_items):
        raw = raw_items[name]
        tier, tier_source = tier_of(raw)
        item_groups = {k: v for k, v in (raw.get("groups") or {}).items() if v}
        fields = raw.get("fields") or {}
        entry = {
            "type": raw.get("type"),
            "mod": name.split(":", 1)[0],
            "description": raw.get("description") or "",
            "category": category_of(name, raw),
            "groups": item_groups,
            "tier": tier,
            "tier_source": tier_source,
            "sources": sources_of(raw),
        }
        if raw.get("food"):
            entry["food"] = True
        if fields.get("_grug_ilvl") is not None:
            entry["ilvl"] = fields["_grug_ilvl"]
        if fields.get("_grug_req_level") is not None:
            entry["req_level"] = fields["_grug_req_level"]
        if raw.get("resource"):
            entry["gathering"] = {"kind": raw["resource"]["kind"], "tier": raw["resource"]["tier"],
                                  "node": raw["resource"].get("node"), "scope": raw["resource"].get("scope")}
        fish = [row for row in raw.get("fishing") or [] if row.get("fish")]
        if fish:
            entry["gathering"] = {"kind": "fish", "tier": fish[0]["band"]}
        if raw.get("alloy_inputs"):
            entry["alloy_inputs"] = raw["alloy_inputs"]
        smelt = [r for r in raw.get("engine_recipes") or [] if r.get("method") == "cooking"]
        if smelt:
            entry["furnace_inputs"] = [r["inputs"] for r in smelt]
        if raw.get("mob_drops"):
            entry["mob_drops"] = sorted(raw["mob_drops"], key=lambda r: r["mob"])
        if raw.get("profession_recipes"):
            entry["profession_recipes"] = raw["profession_recipes"]
        if item_groups.get("not_in_creative_inventory"):
            entry["hidden"] = True
        if name in curated_names:
            entry["curated_out"] = True
        items[name] = entry
        for group in item_groups:
            groups[group].append(name)

    group_table = {}
    for group, members in sorted(groups.items()):
        # Ore nodes drop their raw item, so a player never carries one.
        carryable = any(items[m]["category"] != "ore_node" for m in members)
        group_table[group] = {
            "count": len(members),
            "members": members,
            "objective": (carryable and group not in MECHANICAL_GROUPS and len(members) >= 2
                          and not group.startswith("color_")),
            "recommended": carryable and group in RECOMMENDED_GROUPS,
            "note": RECOMMENDED_GROUPS.get(group, ""),
        }

    entities = {}
    for name in sorted(dump.get("entities") or {}):
        raw = dump["entities"][name]
        entities[name] = {
            "type": raw.get("type"),
            "description": raw.get("description") or "",
            "disposition": raw.get("disposition"),
            "drops": raw.get("drops") or [],
        }
    return {
        "about": "Existing items, item groups and mob entities from a headless engine probe "
                 "(tools/r28_design/dump_items.sh), without the design catalogue's own sub-types and "
                 "new loot items. Regenerate; do not edit by hand.",
        "tiers": [{"id": t["id"], "key": t["key"], "levels": [t["min_level"], t["max_level"]],
                   "bar": t["bar_item"]} for t in dump.get("tiers") or []],
        "items": items,
        "groups": group_table,
        "aliases": dict(sorted((dump.get("aliases") or {}).items())),
        "curated_out": curated_out,
        "entities": entities,
        "quest_npcs": dict(sorted((dump.get("quest_npcs") or {}).items())),
        "legacy_quests": {qid: {"npc": q.get("npc"), "turnin": q.get("turnin_npc"),
                                "min_level": q.get("min_level"), "xp": q.get("xp"),
                                "title": q.get("title")}
                          for qid, q in sorted((dump.get("quests") or {}).items())},
    }


def render_md(cat):
    items = cat["items"]
    lines = [
        "# Round 28 — existing items (designer reference)",
        "",
        "Generated from the real item registry by a headless engine probe",
        "(`tools/r28_design/dump_items.sh`, which also writes",
        "[existing.json](existing.json)). Do not edit by hand; rerun the tool.",
        "The design catalogue's own sub-types and new loot items are left out",
        "(see [the catalogue](../design/catalog/README.md)).",
        "",
        "Use these ids in quest item objectives, rewards, drop tables and enchant",
        "inputs. New items go into `catalog/items.json`. Never reference an item",
        "under [Curated out](#curated-out). **Tier** is the explicit tier the code",
        "declares (profession ingredient tier, material tier, harvest tier, food",
        "tier, tool tier, fishing band); blank means the code declares none.",
        "**Sources**: grid / furnace (engine recipes), `<profession> T<n>`",
        "(profession recipe), dual furnace, mining, mob drop, fishing, dig (another",
        "node drops it). Nodes without a source (logs, sand, stone …) drop",
        "themselves when dug.",
        "",
        "Item groups usable in quest `group` objectives: [Item groups](#item-groups).",
        "Mob entities and today's drops: [Mob entities](#mob-entities).",
        "",
    ]
    counts = defaultdict(int)
    for entry in items.values():
        counts[entry["category"]] += 1
    lines.append("| Section | Entries |")
    lines.append("|---|---|")
    for key, title, _ in CATEGORY_TITLES:
        lines.append("| [%s](#%s) | %d |" % (title, anchor(title), counts[key]))
    lines.append("")
    for key, title, note in CATEGORY_TITLES:
        names = [n for n, e in items.items() if e["category"] == key and not e.get("curated_out")]
        lines.append("## " + title)
        lines.append("")
        if note:
            lines.append(note)
            lines.append("")
        if key == "node":
            by_mod = defaultdict(list)
            for n in names:
                by_mod[items[n]["mod"]].append(n)
            for mod in sorted(by_mod):
                lines.append("- **%s** (%d): %s" % (mod, len(by_mod[mod]),
                             ", ".join("`%s`" % n.split(":", 1)[1] for n in by_mod[mod])))
            lines.append("")
            continue
        extra = key in ("mob_drop",)
        header = "| Item | Name | Tier | Sources | Groups |"
        if extra:
            header = "| Item | Name | Tier | Sources | Dropped by (1 in N) |"
        lines.append(header)
        lines.append("|---|---|---|---|---|")
        for n in names:
            e = items[n]
            groups = ", ".join(g for g in sorted(e["groups"]) if g not in MECHANICAL_GROUPS)
            tier = "" if e["tier"] is None else str(e["tier"])
            if extra:
                drops = ", ".join("%s %s" % (r["mob"].split(":", 1)[1], r["chance"]) for r in e.get("mob_drops") or [])
                tail = drops
            else:
                tail = groups
            lines.append("| `%s` | %s | %s | %s | %s |" % (n, md_escape(e["description"]), tier,
                                                          ", ".join(e["sources"]), md_escape(tail)))
        lines.append("")

    lines.append("## Item groups")
    lines.append("")
    lines.append("A quest objective `{\"type\": \"item\", \"group\": \"tree\", \"count\": 5}` accepts any member.")
    lines.append("Recommended groups first; the second table lists every other group with two or")
    lines.append("more members that describes a kind of item. Engine dig and placement groups")
    lines.append("(cracky, choppy, stair, …) are not objective groups.")
    lines.append("")
    lines.append("| Group | Meaning | Members |")
    lines.append("|---|---|---|")
    groups = cat["groups"]
    for g in sorted(groups):
        row = groups[g]
        if row["recommended"]:
            lines.append("| `group:%s` | %s | %s |" % (g, row["note"], member_list(row["members"])))
    lines.append("")
    lines.append("| Group | Members |")
    lines.append("|---|---|")
    for g in sorted(groups):
        row = groups[g]
        if row["objective"] and not row["recommended"]:
            lines.append("| `group:%s` | %s |" % (g, member_list(row["members"])))
    lines.append("")

    lines.append("## Mob entities")
    lines.append("")
    lines.append("Every registered mob entity (existing roles are the name without `grug_mobs:`).")
    lines.append("Disposition from `grug_mobs/disposition.lua`; drops are today's static rows.")
    lines.append("")
    lines.append("| Entity | Name | Type | Disposition | Drops (1 in N) |")
    lines.append("|---|---|---|---|---|")
    for n, e in cat["entities"].items():
        drops = ", ".join("%s %s" % (r["item"], r["chance"]) for r in e["drops"])
        lines.append("| `%s` | %s | %s | %s | %s |" % (n, md_escape(e["description"]), e["type"] or "",
                                                      e["disposition"] or "", drops))
    lines.append("")

    lines.append("## Quest NPCs")
    lines.append("")
    lines.append("Registered quest NPC ids today (settlement / socket). The zone atlas says")
    lines.append("which zone and hub each belongs to.")
    lines.append("")
    lines.append("| NPC id | Name | Settlement | Socket |")
    lines.append("|---|---|---|---|")
    for n, e in cat["quest_npcs"].items():
        lines.append("| `%s` | %s | %s | %s |" % (n, md_escape(str(e.get("name") or e.get("title") or "")),
                                                e.get("settlement", ""), e.get("socket", "")))
    lines.append("")

    lines.append("## Curated out")
    lines.append("")
    lines.append("Never reference these (`mods/ITEMS/grug_materials/content_curation.lua`).")
    lines.append("")
    lines.append("| Item | Why |")
    lines.append("|---|---|")
    for row in cat["curated_out"]:
        lines.append("| `%s` | %s |" % (row["name"], row["reason"]))
    lines.append("")
    if cat["aliases"]:
        lines.append("## Aliases")
        lines.append("")
        lines.append("Alias names resolve to another item; always write the target id.")
        lines.append("")
        for k, v in cat["aliases"].items():
            lines.append("- `%s` → `%s`" % (k, v))
        lines.append("")
    return "\n".join(lines)


def member_list(members, limit=40):
    shown = ", ".join("`%s`" % m for m in members[:limit])
    if len(members) > limit:
        shown += ", … (%d more)" % (len(members) - limit)
    return shown


def anchor(title):
    out = []
    for ch in title.lower():
        if ch.isalnum() or ch in "-_":
            out.append(ch)
        elif ch == " ":
            out.append("-")
    return "".join(out)


def dump_json(cat):
    """Two-level JSON: one line per item, group, alias and entity, so a rerun
    diffs line by line and the file stays small."""
    parts = ["{"]
    keys = list(cat)
    for index, key in enumerate(keys):
        value = cat[key]
        comma = "," if index < len(keys) - 1 else ""
        if isinstance(value, dict) and value:
            parts.append("  %s: {" % json.dumps(key))
            rows = list(value.items())
            for row_index, (name, row) in enumerate(rows):
                row_comma = "," if row_index < len(rows) - 1 else ""
                parts.append("    %s: %s%s" % (json.dumps(name), json.dumps(row, ensure_ascii=False), row_comma))
            parts.append("  }" + comma)
        elif isinstance(value, list) and value:
            parts.append("  %s: [" % json.dumps(key))
            for row_index, row in enumerate(value):
                row_comma = "," if row_index < len(value) - 1 else ""
                parts.append("    %s%s" % (json.dumps(row, ensure_ascii=False), row_comma))
            parts.append("  ]" + comma)
        else:
            parts.append("  %s: %s%s" % (json.dumps(key), json.dumps(value, ensure_ascii=False), comma))
    parts.append("}")
    return "\n".join(parts) + "\n"


def main(argv):
    if len(argv) != 3:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    dump = json.loads(Path(argv[1]).read_text())
    out_dir = Path(argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    cat = build(dump)
    (out_dir / "existing.json").write_text(dump_json(cat))
    (out_dir / "existing.md").write_text(render_md(cat) + "\n")
    print("existing items: %d items, %d groups (%d objective), %d entities, %d curated out" % (
        len(cat["items"]), len(cat["groups"]),
        sum(1 for g in cat["groups"].values() if g["objective"]),
        len(cat["entities"]), len(cat["curated_out"])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

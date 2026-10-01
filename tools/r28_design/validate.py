#!/usr/bin/env python3
"""Round 28 design validator: checks every design JSON file against the data
formats of docs/planning/round28-design-frame.md section 4 and the limits of
section 2.5, and cross-checks references between files.

Reads the whole design directory (references cross files): catalog/*.json and
zones/<zone>.spawns.json / zones/<zone>.quests.json. Existing items, mob
entities and quest NPCs come from docs/planning/round28/items/existing.json;
zone ids, anchors, NPCs, biomes and level bands from the zone atlas when one
is given (--atlas); without it those checks are skipped with one warning.

Every finding has a code ([E-...] error, [W-...] warning), the file and the
JSON path. Exit code 0 = no errors, 1 = errors (or warnings with --strict),
2 = files could not be read.

Usage:
  validate.py [--design DIR] [--existing FILE] [--atlas FILE_OR_DIR]
              [--zone ZONE ...] [--legacy] [--strict] [--quiet]
  validate.py --self-test
"""
import argparse
import copy
import json
import math
import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import r28common as C  # noqa: E402

# A kill target's level range [lo, hi] fits a quest of level L when
# lo - LEVEL_SLACK <= L <= hi + LEVEL_SLACK.
LEVEL_SLACK = 3
MAX_GIVERS_PER_HUB = 2
MAX_LINES_PER_GIVER = 2
MAX_SIGNATURE_PER_BAND = 2
MAX_REAGENTS_PER_TIER = 2
SIZE_RANGE = (0.75, 1.3)
CAMP_RADIUS = (30, 45)

SUBTYPE_KEYS = {"role", "family", "base", "display", "display_by_zone", "tint_by_zone", "size",
                "disposition", "tier", "leader", "levels", "drops", "notes"}
SUBTYPE_REQUIRED = ("role", "family", "base", "display", "size", "disposition", "levels", "drops")
ITEM_KEYS = {"id", "name", "tier", "family", "kind", "description", "uses", "icon", "notes"}
ITEM_REQUIRED = ("id", "name", "tier", "kind", "description")
ITEM_KINDS = ("signature", "generic", "reagent", "quest")
REAGENT_KEYS = {"id", "name", "tier", "method", "inputs", "output_count", "uses", "notes"}
AREA_KEYS = {"id", "anchor", "offset", "shape", "hosts", "clock", "levels", "species", "cap",
             "camp", "fallback", "notes"}
AREA_REQUIRED = ("id", "anchor", "shape", "hosts", "clock", "levels", "species")
LEADER_KEYS = {"role", "anchor", "offset", "level", "respawn", "notes"}
QUEST_KEYS = {"id", "line", "giver", "turnin", "min_level", "level", "requires", "title", "text",
              "objectives", "rewards", "quest_drops", "repeatable", "lesson", "duration_min",
              "optional", "climax", "group", "notes"}
QUEST_REQUIRED = ("id", "line", "giver", "turnin", "min_level", "level", "title", "text",
                  "objectives", "rewards")
LEGACY_QUEST_KEYS = ("xp", "faction", "race")
LEGACY_OBJECTIVE_KEYS = ("mobs", "mob", "zone", "role")
CLOCKS = ("day", "night", "both")
DISPOSITIONS = ("neutral", "aggressive", "critter")
SHAPES = ("circle", "ring", "band", "zone")
FIXED_ANCHORS = ("start", "capital", "zone")
FRONT_LINE = "front"
FAMILIES = ("sword", "dagger", "greataxe", "metal_armor", "shield", "leather_armor", "cloth_armor",
            "bow", "caster_weapon", "spellbook", "trinket")
# Area or leader centres further outside the atlas's rough zone outline than
# this are errors; closer ones are warnings (borders are warped).
ZONE_MARGIN = 96


class Findings:
    def __init__(self):
        self.rows = []

    def add(self, level, code, where, path, msg):
        self.rows.append((level, code, str(where), path, msg))

    def errors(self):
        return [r for r in self.rows if r[0] == "E"]

    def warnings(self):
        return [r for r in self.rows if r[0] == "W"]

    def codes(self):
        return {r[1] for r in self.rows}


def is_int(value, lo=None, hi=None):
    return (isinstance(value, int) and not isinstance(value, bool)
            and (lo is None or value >= lo) and (hi is None or value <= hi))


def is_num(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def level_range(value):
    return (isinstance(value, list) and len(value) == 2 and all(is_int(v, 1, C.LEVEL_CAP) for v in value)
            and value[0] <= value[1])


def sentences(text):
    return len([s for s in re.split(r"[.!?]+(?:\s|$)", text.strip()) if s.strip()])


class Validator:
    def __init__(self, design, existing, atlas=None, legacy=False, zones=None):
        self.d = design
        self.ex = existing or {}
        self.atlas = atlas
        self.legacy = legacy
        self.only_zones = set(zones or [])
        self.f = Findings()
        self.subtypes = {}
        self.catalog_items = {}
        self.drop_families = {}
        self.quest_ids = {}
        self.ex_items = self.ex.get("items") or {}
        self.ex_entities = self.ex.get("entities") or {}
        self.ex_groups = self.ex.get("groups") or {}
        self.curated = {row.get("name") for row in self.ex.get("curated_out") or []
                        if row.get("reason", "").startswith("content_curation: unregistered")
                        or row.get("reason", "").startswith("content_curation: mobs_redo")
                        or row.get("registered") is False}
        self.no_source = {row.get("name") for row in self.ex.get("curated_out") or []
                          if row.get("registered") is not False and row.get("name") not in self.curated}
        self.aliases = self.ex.get("aliases") or {}
        self.npcs = set(self.ex.get("quest_npcs") or {})
        if atlas:
            self.npcs |= atlas.all_npcs()

    # -- small helpers ---------------------------------------------------
    def E(self, code, where, path, msg):
        self.f.add("E", code, where, path, msg)

    def W(self, code, where, path, msg):
        self.f.add("W", code, where, path, msg)

    def unknown_keys(self, row, allowed, where, path):
        for key in row:
            if key not in allowed:
                self.W("W-unknown-key", where, path, "unknown field %r (typo?)" % key)

    def required(self, row, keys, where, path):
        ok = True
        for key in keys:
            if key not in row:
                self.E("E-required", where, path, "missing required field %r" % key)
                ok = False
        return ok

    def item_known(self, item):
        return item in self.catalog_items or item in self.ex_items

    def check_item_ref(self, item, where, path, what="item"):
        if not isinstance(item, str) or not C.ITEM_ID.match(item):
            self.E("E-id", where, path, "%s %r is not a 'mod:name' item id" % (what, item))
            return False
        if item in self.curated:
            self.E("E-curated", where, path, "%s %s is curated out (grug_materials/content_curation.lua)"
                   % (what, item))
            return False
        if item in self.no_source:
            self.W("W-no-source", where, path, "%s has no recipe and no world source (content curation)"
                   % item)
        if item in self.aliases and item not in self.ex_items:
            self.W("W-alias", where, path, "%s %s is an alias of %s; write the target id"
                   % (what, item, self.aliases[item]))
            return True
        if not self.item_known(item):
            self.E("E-unknown-item", where, path, "%s %s is neither in catalog/items.json nor an existing item"
                   % (what, item))
            return False
        if (self.ex_items.get(item) or {}).get("category") == "skill":
            self.E("E-skill-item", where, path, "%s %s is a soulbound skill item" % (what, item))
            return False
        return True

    def role_def(self, role):
        """(source, record): source 'subtype' or 'existing'; None if unknown."""
        if role in self.subtypes:
            return "subtype", self.subtypes[role]
        entity = self.ex_entities.get("grug_mobs:" + str(role))
        if entity:
            return "existing", entity
        return None, None

    def role_disposition(self, role):
        source, rec = self.role_def(role)
        return rec.get("disposition") if rec else None

    def role_levels(self, role):
        source, rec = self.role_def(role)
        if source == "subtype" and level_range(rec.get("levels")):
            return rec["levels"]
        return None

    def zone_info(self, zone):
        return self.atlas.zones.get(zone) if self.atlas else None

    def check_anchor(self, anchor, zone, where, path):
        """Returns the atlas anchor id ('zone' for the hub) or None."""
        if not isinstance(anchor, str) or not anchor:
            self.E("E-anchor", where, path, "anchor must be a non-empty string")
            return None
        info = self.zone_info(zone)
        if info is None:
            return None
        resolved = self.atlas.resolve_anchor(zone, anchor)
        if resolved is None:
            refs = sorted(r for r in info["anchors"] if not r.startswith("anchor_") and not r.startswith("r20_"))
            self.E("E-unknown-anchor", where, path, "anchor %r is not an anchor of %s (anchor id, settlement "
                   "key or slot; this zone has: %s, or 'zone')" % (anchor, zone, ", ".join(refs) or "none"))
        return resolved

    def check_npc(self, npc, where, path):
        if not isinstance(npc, str) or not npc:
            self.E("E-npc", where, path, "NPC id must be a non-empty string")
        elif npc not in self.npcs:
            self.E("E-unknown-npc", where, path, "NPC %r is not a registered quest NPC%s"
                   % (npc, " or atlas NPC" if self.atlas else " (no atlas given)"))

    # -- catalogues ------------------------------------------------------
    def catalogs(self):
        d = self.d
        where = d.root / "catalog"
        for i, row in enumerate(d.items or []):
            path = "items.json[%d]" % i
            if not isinstance(row, dict):
                self.E("E-type", where / "items.json", path, "entry must be an object")
                continue
            self.unknown_keys(row, ITEM_KEYS, where / "items.json", path)
            self.required(row, ITEM_REQUIRED, where / "items.json", path)
            iid = row.get("id")
            if not isinstance(iid, str) or not C.ITEM_ID.match(iid):
                self.E("E-id", where / "items.json", path, "id %r must be 'mod:snake_case'" % iid)
                continue
            if iid in self.catalog_items:
                self.E("E-duplicate", where / "items.json", path, "duplicate item id %s" % iid)
            self.catalog_items[iid] = row
            if iid in self.curated:
                self.E("E-curated", where / "items.json", path, "%s is curated out" % iid)
            if row.get("kind") not in ITEM_KINDS:
                self.E("E-enum", where / "items.json", path, "kind %r not in %s" % (row.get("kind"), ITEM_KINDS))
            if not is_int(row.get("tier"), 1, 6):
                self.E("E-tier", where / "items.json", path, "tier must be 1..6")
            if iid not in self.ex_items and not row.get("icon"):
                self.W("W-icon", where / "items.json", path, "new item %s has no icon description" % iid)
        for i, row in enumerate(d.subtypes or []):
            path = "subtypes.json[%d]" % i
            file = where / "subtypes.json"
            if not isinstance(row, dict):
                self.E("E-type", file, path, "entry must be an object")
                continue
            self.unknown_keys(row, SUBTYPE_KEYS, file, path)
            self.required(row, SUBTYPE_REQUIRED, file, path)
            role = row.get("role")
            if not isinstance(role, str) or not C.SNAKE.match(role):
                self.E("E-id", file, path, "role %r must be snake_case" % role)
                continue
            path = "subtypes.json[%s]" % role
            if role in self.subtypes:
                self.E("E-duplicate", file, path, "duplicate role %s" % role)
            self.subtypes[role] = row
            if "grug_mobs:" + role in self.ex_entities:
                self.E("E-role-collides", file, path, "role %s collides with the existing entity grug_mobs:%s "
                       "(use the existing mob unchanged without a sub-type, or pick a new role)" % (role, role))
            if row.get("base") not in self.ex_entities:
                self.E("E-unknown-base", file, path, "base %r is not a registered mob entity" % row.get("base"))
            size = row.get("size")
            if not is_num(size) or not SIZE_RANGE[0] <= size <= SIZE_RANGE[1]:
                self.E("E-size", file, path, "size %r outside %.2f-%.2f" % (size, SIZE_RANGE[0], SIZE_RANGE[1]))
            if row.get("disposition") not in DISPOSITIONS:
                self.E("E-enum", file, path, "disposition %r not in %s" % (row.get("disposition"), DISPOSITIONS))
            tier = row.get("tier", "normal")
            if tier not in ("normal", "elite"):
                self.E("E-enum", file, path, "tier %r must be normal or elite" % tier)
            if not level_range(row.get("levels")):
                self.E("E-levels", file, path, "levels must be [lo, hi] within 1..60")
            elif row.get("leader") and tier == "elite" and row["levels"][0] < 31:
                self.E("E-leader-tier", file, path, "elite leaders only from level 31 (frame 2.4)")
            if "leader" in row and not isinstance(row["leader"], bool):
                self.E("E-type", file, path, "leader must be true or false")
            for zone, tint in (row.get("tint_by_zone") or {}).items():
                if d.tints is not None and tint not in d.tints:
                    self.E("E-unknown-tint", file, path, "tint %r (zone %s) not in catalog/tints.json" % (tint, zone))
            for key in ("display_by_zone", "tint_by_zone"):
                for zone in row.get(key) or {}:
                    if self.atlas and zone not in self.atlas.zones:
                        self.E("E-unknown-zone", file, path, "%s names unknown zone %r" % (key, zone))
        used_families = {row.get("drops") for row in self.subtypes.values()}
        for i, row in enumerate(d.drops or []):
            file = where / "drops.json"
            path = "drops.json[%d]" % i
            if not isinstance(row, dict) or not isinstance(row.get("family"), str):
                self.E("E-required", file, path, "entry needs a 'family'")
                continue
            family = row["family"]
            path = "drops.json[%s]" % family
            if family in self.drop_families:
                self.E("E-duplicate", file, path, "duplicate family %s" % family)
            self.drop_families[family] = row
            if self.subtypes and family not in used_families:
                self.W("W-unused-family", file, path, "no sub-type uses drop family %s" % family)
            bands = row.get("bands")
            if not isinstance(bands, dict) or not bands:
                self.E("E-required", file, path, "'bands' must be an object keyed '1'..'6'")
                bands = {}
            for band, rows in bands.items():
                bpath = "%s.bands[%s]" % (path, band)
                if band not in [str(n) for n in range(1, 7)]:
                    self.E("E-band", file, bpath, "band key %r must be '1'..'6'" % band)
                    continue
                signature = set()
                for j, drop in enumerate(rows if isinstance(rows, list) else []):
                    self.drop_row(drop, file, "%s[%d]" % (bpath, j))
                    item = drop.get("item") if isinstance(drop, dict) else None
                    entry = self.catalog_items.get(item) or {}
                    if entry.get("kind") == "signature":
                        signature.add(item)
                    tier = entry.get("tier") or (self.ex_items.get(item) or {}).get("tier")
                    if (self.ex_items.get(item) or {}).get("category") == "bar":
                        if tier and tier != int(band):
                            self.E("E-metal-tier", file, "%s[%d]" % (bpath, j),
                                   "metal %s is tier %s, dropped in band %s (tier-matched only)" % (item, tier, band))
                        if is_int(drop.get("chance")) and drop["chance"] < 10:
                            self.W("W-metal-rare", file, "%s[%d]" % (bpath, j),
                                   "metal drop 1 in %d is not rare" % drop["chance"])
                if len(signature) > MAX_SIGNATURE_PER_BAND:
                    self.E("E-signature-limit", file, bpath, "%d signature items (max %d): %s"
                           % (len(signature), MAX_SIGNATURE_PER_BAND, ", ".join(sorted(signature))))
            for j, drop in enumerate(row.get("leader_bonus") or []):
                self.drop_row(drop, file, "%s.leader_bonus[%d]" % (path, j))
        if d.drops is not None:
            for role, row in self.subtypes.items():
                if row.get("drops") not in self.drop_families:
                    self.E("E-unknown-family", where / "subtypes.json", "subtypes.json[%s]" % role,
                           "drop family %r is not in catalog/drops.json" % row.get("drops"))
        reagent_tiers = {}
        for i, row in enumerate(d.reagents or []):
            file = where / "reagents.json"
            path = "reagents.json[%d]" % i
            if not isinstance(row, dict):
                self.E("E-type", file, path, "entry must be an object")
                continue
            self.unknown_keys(row, REAGENT_KEYS, file, path)
            self.required(row, ("id", "name", "tier", "method", "inputs", "output_count"), file, path)
            if row.get("method") not in ("grid", "furnace"):
                self.E("E-enum", file, path, "method %r must be grid or furnace" % row.get("method"))
            for j, item in enumerate(row.get("inputs") or []):
                self.check_item_ref(item, file, "%s.inputs[%d]" % (path, j), "input")
            if not is_int(row.get("output_count"), 1):
                self.E("E-type", file, path, "output_count must be an integer >= 1")
            if (self.catalog_items.get(row.get("id")) or {}).get("kind") != "reagent":
                self.E("E-reagent-item", file, path, "reagent %s needs an items.json entry of kind reagent"
                       % row.get("id"))
            reagent_tiers.setdefault(row.get("tier"), []).append(row.get("id"))
        for tier, ids in reagent_tiers.items():
            if len(ids) > MAX_REAGENTS_PER_TIER:
                self.W("W-reagent-limit", where / "reagents.json", "tier %s" % tier,
                       "%d universal reagents (about %d per tier): %s" % (len(ids), MAX_REAGENTS_PER_TIER,
                                                                         ", ".join(map(str, ids))))
        for i, row in enumerate(d.enchants or []):
            file = where / "enchants.json"
            path = "enchants.json[%d]" % i
            if not isinstance(row, dict):
                self.E("E-type", file, path, "entry must be an object")
                continue
            if not is_int(row.get("tier"), 1, 6):
                self.E("E-tier", file, path, "tier must be 1..6")
            for stat, item in (row.get("stat_loot") or {}).items():
                spath = "%s.stat_loot.%s" % (path, stat)
                if stat not in C.STATS:
                    self.E("E-stat", file, spath, "unknown stat %r (%s)" % (stat, ", ".join(C.STATS)))
                if self.check_item_ref(item, file, spath, "stat loot"):
                    if (self.catalog_items.get(item) or {}).get("kind") != "signature":
                        self.E("E-enchant-loot", file, spath, "stat loot %s must be a signature drop "
                               "(catalog/items.json kind signature)" % item)
            for family, item in (row.get("family_input") or {}).items():
                fpath = "%s.family_input.%s" % (path, family)
                if family not in FAMILIES:
                    self.E("E-family", file, fpath, "unknown equipment family %r (%s)" % (family, ", ".join(FAMILIES)))
                if self.check_item_ref(item, file, fpath, "family input"):
                    routes = (self.ex_items.get(item) or {}).get("profession_recipes") or []
                    if routes:
                        self.W("W-profession-product", file, fpath,
                               "%s is a %s product; only that profession's own families may use it"
                               % (item, "/".join(sorted({r.get("profession", "?") for r in routes}))))

    def drop_row(self, drop, file, path):
        if not isinstance(drop, dict):
            self.E("E-type", file, path, "drop row must be an object")
            return
        self.check_item_ref(drop.get("item"), file, path, "drop")
        if not is_int(drop.get("chance"), 1):
            self.E("E-chance", file, path, "chance (1 in N) must be an integer >= 1")
        lo, hi = drop.get("min", 1), drop.get("max", 1)
        if not (is_int(lo, 1) and is_int(hi, 1) and lo <= hi):
            self.E("E-type", file, path, "min/max must be integers with 1 <= min <= max")

    # -- zones -----------------------------------------------------------
    def spawns(self, zone, data):
        file = self.d.root / "zones" / ("%s.spawns.json" % zone)
        if not isinstance(data, dict):
            self.E("E-type", file, "$", "spawns file must be an object")
            return
        if data.get("zone") != zone:
            self.E("E-zone-mismatch", file, "zone", "zone %r does not match the file name %s" % (data.get("zone"), zone))
        info = self.zone_info(zone)
        if self.atlas and info is None:
            self.E("E-unknown-zone", file, "zone", "zone %s is not in the atlas" % zone)
        for i, role in enumerate(data.get("critters") or []):
            if self.role_disposition(role) != "critter":
                self.E("E-critter", file, "critters[%d]" % i, "%r is not a critter role" % role)
        areas = data.get("areas")
        if not isinstance(areas, list):
            self.E("E-required", file, "areas", "'areas' must be a list (empty keeps today's palette)")
            areas = []
        seen = set()
        fallbacks = 0
        front = bool(info and info.get("role") in ("front", "island"))
        for i, area in enumerate(areas):
            path = "areas[%d]" % i
            if not isinstance(area, dict):
                self.E("E-type", file, path, "area must be an object")
                continue
            aid = area.get("id")
            if isinstance(aid, str):
                path = "areas[%s]" % aid
            self.unknown_keys(area, AREA_KEYS, file, path)
            self.required(area, AREA_REQUIRED, file, path)
            if not isinstance(aid, str) or not C.SNAKE.match(aid):
                self.E("E-id", file, path, "area id %r must be snake_case" % aid)
            elif aid in seen:
                self.E("E-duplicate", file, path, "duplicate area id %s" % aid)
            seen.add(aid)
            self.check_anchor(area.get("anchor"), zone, file, path + ".anchor")
            self.check_offset(area.get("offset"), file, path)
            self.check_shape(area.get("shape"), front, file, path + ".shape")
            self.check_in_zone(zone, area.get("anchor"), area.get("offset"), area.get("shape"), file, path)
            hosts = area.get("hosts")
            if not isinstance(hosts, dict) or not isinstance(hosts.get("biomes"), list) or not hosts["biomes"]:
                self.E("E-hosts", file, path + ".hosts", "hosts needs a non-empty 'biomes' list ('any' allowed)")
            else:
                if "shore" in hosts and not isinstance(hosts["shore"], bool):
                    self.E("E-hosts", file, path + ".hosts", "shore must be true or false")
                if info is not None and info["biomes"]:
                    for biome in hosts["biomes"]:
                        if biome != "any" and C.biome_id(biome) not in info["biomes"]:
                            self.E("E-unknown-biome", file, path + ".hosts", "biome %r is not a biome of %s (%s)"
                                   % (biome, zone, ", ".join(sorted(info["biomes"]))))
            if area.get("clock") not in CLOCKS:
                self.E("E-enum", file, path + ".clock", "clock %r not in %s" % (area.get("clock"), CLOCKS))
            levels = area.get("levels")
            if not level_range(levels):
                self.E("E-levels", file, path + ".levels", "levels must be [lo, hi] within 1..60")
                levels = None
            elif info is not None and info.get("levels"):
                zlo, zhi = info["levels"]
                if levels[0] < zlo or levels[1] > zhi:
                    self.E("E-area-levels", file, path + ".levels", "levels %s outside the zone band %s"
                           % (levels, info["levels"]))
            species = area.get("species")
            if not isinstance(species, list) or not species:
                self.E("E-required", file, path + ".species", "species must be a non-empty list")
                species = []
            for j, sp in enumerate(species):
                spath = "%s.species[%d]" % (path, j)
                role = sp.get("role") if isinstance(sp, dict) else None
                if not self.role_def(role)[0]:
                    self.E("E-unknown-role", file, spath, "role %r is neither a sub-type nor an existing mob" % role)
                    continue
                if not is_num(sp.get("weight")) or sp["weight"] <= 0:
                    self.E("E-type", file, spath, "weight must be a positive number")
                if self.role_disposition(role) == "critter":
                    self.W("W-critter-area", file, spath, "critter %s belongs in 'critters'" % role)
                elif self.role_disposition(role) is None:
                    self.E("E-not-a-mob", file, spath, "%s is an NPC or guard, not an ambient mob" % role)
                rlevels = self.role_levels(role)
                if levels and rlevels and (levels[0] < rlevels[0] or levels[1] > rlevels[1]):
                    self.E("E-area-role-levels", file, spath, "area levels %s outside %s's levels %s"
                           % (levels, role, rlevels))
            if "cap" in area and not is_int(area["cap"], 1):
                self.E("E-type", file, path + ".cap", "cap must be an integer >= 1")
            if "camp" in area:
                self.check_camp(area, file, path)
            if area.get("fallback") is True:
                fallbacks += 1
            elif "fallback" in area and not isinstance(area["fallback"], bool):
                self.E("E-type", file, path + ".fallback", "fallback must be true or false")
        if areas and fallbacks != 1:
            self.E("E-fallback", file, "areas", "a zone with areas needs exactly one fallback area (has %d)" % fallbacks)
        for i, leader in enumerate(data.get("leaders") or []):
            path = "leaders[%d]" % i
            if not isinstance(leader, dict):
                self.E("E-type", file, path, "leader must be an object")
                continue
            self.unknown_keys(leader, LEADER_KEYS, file, path)
            self.required(leader, ("role", "anchor", "level", "respawn"), file, path)
            role = leader.get("role")
            source, rec = self.role_def(role)
            if not source:
                self.E("E-unknown-role", file, path, "role %r is neither a sub-type nor an existing mob" % role)
            elif source == "subtype" and not rec.get("leader"):
                self.W("W-leader-flag", file, path, "sub-type %s is not marked \"leader\": true" % role)
            self.check_anchor(leader.get("anchor"), zone, file, path + ".anchor")
            self.check_offset(leader.get("offset"), file, path)
            self.check_in_zone(zone, leader.get("anchor"), leader.get("offset"), {"kind": "point"}, file, path)
            level = leader.get("level")
            if not is_int(level, 1, C.LEVEL_CAP):
                self.E("E-levels", file, path, "level must be an integer 1..60")
            else:
                rlevels = self.role_levels(role)
                if rlevels and not rlevels[0] <= level <= rlevels[1]:
                    self.E("E-leader-level", file, path, "level %d outside %s's levels %s" % (level, role, rlevels))
                if source == "subtype" and rec.get("tier") == "elite" and level < 31:
                    self.E("E-leader-tier", file, path, "elite leaders only from level 31 (frame 2.4)")
            if not is_int(leader.get("respawn"), 1):
                self.E("E-type", file, path, "respawn must be seconds (integer >= 1)")

    def check_in_zone(self, zone, anchor, offset, shape, file, path):
        """Frame 4.6: anchor + offset (the centre of a circle, ring or leader
        spot) lies in the zone; most of a circle, ring or band should too.
        Uses the atlas's rough outline (extent box and border lines)."""
        if not self.atlas or not isinstance(shape, dict) or shape.get("kind") == "zone":
            return
        base = self.atlas.position(zone, anchor) if isinstance(anchor, str) else None
        if base is None:
            return
        if not (isinstance(offset, list) and len(offset) == 2 and all(is_int(v) for v in offset)):
            offset = [0, 0]
        cx, cz = base[0] + offset[0], base[1] + offset[1]
        kind = shape.get("kind")
        samples = []
        if kind == "band":
            fwd, side = shape.get("forward"), shape.get("side")
            if not (isinstance(fwd, list) and isinstance(side, list) and len(fwd) == 2 and len(side) == 2
                    and all(is_num(v) for v in fwd + side)):
                return
            sign = self.atlas.zones[zone]["front_sign"]
            for i in range(5):
                for j in range(5):
                    f = fwd[0] + (fwd[1] - fwd[0]) * i / 4.0
                    sd = side[0] + (side[1] - side[0]) * j / 4.0
                    samples.append((cx + sd, cz + sign * f))
            inside = [p for p in samples if self.atlas.outside_by(zone, *p) <= 0]
            if not inside:
                self.E("E-outside-zone", file, path, "the band lies entirely outside %s" % zone)
            elif len(inside) * 2 < len(samples):
                self.W("W-area-outside", file, path, "most of the band lies outside %s (%d of %d sample points "
                       "inside)" % (zone, len(inside), len(samples)))
            return
        out = self.atlas.outside_by(zone, cx, cz)
        near_anchor = any(abs(cx - ax) <= 24 and abs(cz - az) <= 24
                          for ax, az in self.atlas.zones[zone]["anchor_pos"].values())
        if out > ZONE_MARGIN and not near_anchor:
            self.E("E-outside-zone", file, path, "centre (%d, %d) lies about %d nodes outside %s"
                   % (cx, cz, out, zone))
            return
        if out > 0 and not near_anchor:
            self.W("W-area-outside", file, path, "centre (%d, %d) lies near or just outside the border of %s "
                   "(about %d nodes; borders are approximate)" % (cx, cz, zone, out))
        radii = []
        if kind == "circle" and is_num(shape.get("r")):
            radii = [shape["r"] / 2.0, shape["r"]]
        elif kind == "ring" and isinstance(shape.get("r"), list) and len(shape["r"]) == 2 \
                and all(is_num(v) for v in shape["r"]):
            radii = [shape["r"][0], sum(shape["r"]) / 2.0, shape["r"][1]]
        for r in radii:
            for k in range(8):
                angle = math.pi * k / 4.0
                samples.append((cx + r * math.cos(angle), cz + r * math.sin(angle)))
        if samples:
            inside = sum(1 for p in samples if self.atlas.outside_by(zone, *p) <= 0)
            if inside * 2 < len(samples):
                self.W("W-area-outside", file, path, "most of the %s lies outside %s (%d of %d sample points "
                       "inside)" % (kind, zone, inside, len(samples)))

    def check_offset(self, offset, file, path):
        if offset is None:
            return
        if not (isinstance(offset, list) and len(offset) == 2 and all(is_int(v) for v in offset)):
            self.E("E-offset", file, path + ".offset", "offset must be [x, z] integers (world axes)")

    def check_shape(self, shape, front, file, path):
        if not isinstance(shape, dict) or shape.get("kind") not in SHAPES:
            self.E("E-shape", file, path, "shape needs kind %s" % "/".join(SHAPES))
            return
        kind = shape["kind"]
        if kind == "circle" and not (is_num(shape.get("r")) and shape["r"] > 0):
            self.E("E-shape", file, path, "circle needs r > 0")
        elif kind == "ring":
            r = shape.get("r")
            if not (isinstance(r, list) and len(r) == 2 and all(is_num(v) for v in r) and 0 <= r[0] < r[1]):
                self.E("E-shape", file, path, "ring needs r: [min, max] with 0 <= min < max")
        elif kind == "band":
            for key in ("forward", "side"):
                v = shape.get(key)
                if not (isinstance(v, list) and len(v) == 2 and all(is_num(x) for x in v) and v[0] < v[1]):
                    self.E("E-shape", file, path, "band needs %s: [from, to] with from < to" % key)
            if front:
                self.E("E-band-front", file, path, "front zones and islands may not use band (no front axis)")

    def check_camp(self, area, file, path):
        camp = area["camp"]
        if not isinstance(camp, dict):
            self.E("E-camp", file, path + ".camp", "camp must be an object")
            return
        if not is_int(camp.get("slots"), 1):
            self.E("E-camp", file, path + ".camp", "camp.slots must be an integer >= 1")
        r = camp.get("respawn")
        if not (isinstance(r, list) and len(r) == 2 and all(is_int(v, 1) for v in r) and r[0] <= r[1]):
            self.E("E-camp", file, path + ".camp", "camp.respawn must be [min, max] seconds")
        if not is_num(camp.get("min_player_distance")):
            self.E("E-camp", file, path + ".camp", "camp.min_player_distance must be a number")
        shape = area.get("shape") or {}
        if shape.get("kind") == "circle" and is_num(shape.get("r")) and not CAMP_RADIUS[0] <= shape["r"] <= CAMP_RADIUS[1]:
            self.W("W-camp-radius", file, path + ".shape", "camp radius %s; about 35-40 so two players do not "
                   "block it" % shape["r"])

    def quests(self, zone, data, all_areas, hub_givers):
        file = self.d.root / "zones" / ("%s.quests.json" % zone)
        if not isinstance(data, dict):
            self.E("E-type", file, "$", "quests file must be an object")
            return
        if data.get("zone") != zone:
            self.E("E-zone-mismatch", file, "zone", "zone %r does not match the file name %s" % (data.get("zone"), zone))
        if self.atlas and self.zone_info(zone) is None:
            self.E("E-unknown-zone", file, "zone", "zone %s is not in the atlas" % zone)
        giver_lines = {}
        for i, hub in enumerate(data.get("hubs") or []):
            path = "hubs[%d]" % i
            if not isinstance(hub, dict):
                self.E("E-type", file, path, "hub must be an object")
                continue
            if isinstance(hub.get("id"), str):
                path = "hubs[%s]" % hub["id"]
            if not isinstance(hub.get("id"), str) or not C.SNAKE.match(hub.get("id") or ""):
                self.E("E-id", file, path, "hub id must be snake_case")
            hub_anchor = self.check_anchor(hub.get("anchor"), zone, file, path + ".anchor")
            givers = hub.get("givers") or []
            if len(givers) > MAX_GIVERS_PER_HUB:
                self.E("E-givers", file, path, "%d givers (at most %d per hub)" % (len(givers), MAX_GIVERS_PER_HUB))
            for j, giver in enumerate(givers):
                gpath = "%s.givers[%d]" % (path, j)
                npc = giver.get("npc") if isinstance(giver, dict) else None
                self.check_npc(npc, file, gpath)
                where_npc = self.atlas.zones[self.atlas.npc_zone[npc]]["npcs"][npc] \
                    if self.atlas and npc in self.atlas.npc_zone else None
                if where_npc is not None:
                    if self.atlas.npc_zone[npc] != zone:
                        self.E("E-giver-zone", file, gpath, "%s stands in %s, not in this zone"
                               % (npc, self.atlas.npc_zone[npc]))
                    elif hub_anchor not in (None, "zone") and where_npc["anchor"] != hub_anchor:
                        self.E("E-giver-hub", file, gpath, "%s stands at %s (%s), not at the hub's anchor %s"
                               % (npc, where_npc["settlement"], where_npc["anchor"], hub.get("anchor")))
                lines = giver.get("lines") if isinstance(giver, dict) else None
                if not isinstance(lines, list) or not lines:
                    self.E("E-lines", file, gpath, "giver needs a non-empty 'lines' list")
                    lines = []
                if len(lines) > MAX_LINES_PER_GIVER:
                    self.E("E-lines", file, gpath, "%d lines (at most %d per giver)" % (len(lines), MAX_LINES_PER_GIVER))
                if npc in hub_givers:
                    self.E("E-giver-twice", file, gpath, "NPC %s already gives quests in hub %s"
                           % (npc, hub_givers[npc]))
                hub_givers[npc] = "%s/%s" % (zone, hub.get("id"))
                giver_lines[npc] = set(lines)
        for i, q in enumerate(data.get("quests") or []):
            path = "quests[%d]" % i
            if not isinstance(q, dict):
                self.E("E-type", file, path, "quest must be an object")
                continue
            if isinstance(q.get("id"), str):
                path = "quests[%s]" % q["id"]
            if q.get("line") == FRONT_LINE:
                self.E("E-front-line", file, path + ".line", "line 'front' belongs to the front file "
                       "zones/%s.front.quests.json (front design lane)" % zone)
            self.quest(zone, q, file, path, giver_lines, all_areas)
        self.front_reserve(zone, giver_lines, file)
        return giver_lines

    def front_reserve(self, zone, giver_lines, file):
        """Frame 2.1: each 31-40 outpost giver reserves one of its two lines
        for the front lane. A contested zone with a single quest NPC carries
        its own lines and is exempt."""
        info = self.zone_info(zone)
        if info is None or info["role"] != "contested" or len(info["npcs"]) <= 1:
            return
        for npc, lines in giver_lines.items():
            where = info["npcs"].get(npc)
            if where and info["anchor_kinds"].get(where["anchor"]) == "outpost" and FRONT_LINE not in lines:
                self.E("E-front-reserve", file, "hubs", "outpost giver %s must declare the line 'front' "
                       "(one of its two lines, reserved for the front lane)" % npc)

    def front_quests(self, host, data, all_areas, giver_lines):
        """zones/<host>.front.quests.json: front quests given by the host
        zone's givers, only on a line `front` the host's quests.json declares."""
        file = self.d.root / "zones" / ("%s.front.quests.json" % host)
        if not isinstance(data, dict):
            self.E("E-type", file, "$", "front quests file must be an object")
            return
        if data.get("zone") != host:
            self.E("E-zone-mismatch", file, "zone", "zone %r does not match the host zone %s of the file name"
                   % (data.get("zone"), host))
        if self.atlas and self.zone_info(host) is None:
            self.E("E-unknown-zone", file, "zone", "host zone %s is not in the atlas" % host)
        for key in data:
            if key not in ("zone", "quests", "notes"):
                self.W("W-unknown-key", file, "$", "unknown field %r (a front file holds zone and quests)" % key)
        if giver_lines is None:
            self.W("W-front-host-missing", file, "$", "zones/%s.quests.json does not exist yet: front givers "
                   "are checked against the atlas only" % host)
            info = self.zone_info(host)
            giver_lines = {npc: {FRONT_LINE} for npc in (info["npcs"] if info else self.npcs)}
        front_lines = {npc: lines & {FRONT_LINE} for npc, lines in giver_lines.items()}
        for i, q in enumerate(data.get("quests") or []):
            path = "quests[%d]" % i
            if not isinstance(q, dict):
                self.E("E-type", file, path, "quest must be an object")
                continue
            if isinstance(q.get("id"), str):
                path = "quests[%s]" % q["id"]
            if q.get("line") != FRONT_LINE:
                self.E("E-front-line", file, path + ".line", "front quests use the line 'front' (not %r)"
                       % q.get("line"))
            elif q.get("giver") in giver_lines and FRONT_LINE not in giver_lines[q["giver"]]:
                self.E("E-front-line", file, path + ".giver", "%s does not declare the line 'front' in "
                       "zones/%s.quests.json" % (q["giver"], host))
                continue
            self.quest(host, q, file, path, front_lines, all_areas)

    def quest(self, zone, q, file, path, giver_lines, all_areas):
        allowed = set(QUEST_KEYS) | (set(LEGACY_QUEST_KEYS) if self.legacy else set())
        self.unknown_keys(q, allowed, file, path)
        for key in LEGACY_QUEST_KEYS:
            if key in q and not self.legacy:
                self.E("E-legacy", file, path, "%r is legacy-only (B4's split of today's quests)" % key)
        required = QUEST_REQUIRED if not self.legacy else tuple(k for k in QUEST_REQUIRED if k != "rewards")
        self.required(q, required, file, path)
        qid = q.get("id")
        if not isinstance(qid, str) or not C.SNAKE.match(qid):
            self.E("E-id", file, path, "quest id %r must be snake_case" % qid)
        elif qid in self.quest_ids and self.quest_ids[qid] != (zone, path):
            self.E("E-duplicate", file, path, "quest id %s also in %s" % (qid, self.quest_ids[qid][0]))
        giver = q.get("giver")
        if giver not in giver_lines:
            self.E("E-giver-not-hub", file, path + ".giver", "giver %r is not a giver of a hub in this zone" % giver)
        elif q.get("line") not in giver_lines[giver]:
            self.E("E-line", file, path + ".line", "line %r is not one of %s's lines %s"
                   % (q.get("line"), giver, sorted(giver_lines[giver])))
        self.check_npc(q.get("turnin"), file, path + ".turnin")
        min_level, level = q.get("min_level"), q.get("level")
        if not is_int(min_level, 1, C.LEVEL_CAP):
            self.E("E-levels", file, path + ".min_level", "min_level must be an integer 1..60")
            min_level = None
        if not is_int(level, 1, C.LEVEL_CAP):
            self.E("E-levels", file, path + ".level", "level must be an integer 1..60")
            level = None
        if min_level and level and level < min_level:
            self.W("W-level-order", file, path, "reward level %d below min_level %d" % (level, min_level))
        requires = q.get("requires", [])
        if not isinstance(requires, list):
            self.E("E-type", file, path + ".requires", "requires must be a list of quest ids")
            requires = []
        for req in requires:
            if req not in self.quest_ids:
                self.E("E-unknown-requires", file, path + ".requires", "unknown quest %r" % req)
        title, text = q.get("title"), q.get("text")
        if not isinstance(title, str) or not title.strip():
            self.E("E-text", file, path + ".title", "title must be a non-empty string")
        if not isinstance(text, str) or not text.strip():
            self.E("E-text", file, path + ".text", "text must be a non-empty string")
        elif not 2 <= sentences(text) <= 4:
            self.W("W-text", file, path + ".text", "text has %d sentences (two to four)" % sentences(text))
        objectives = q.get("objectives")
        if not isinstance(objectives, list) or not objectives:
            self.E("E-objective", file, path + ".objectives", "objectives must be a non-empty list")
            objectives = []
        item_objectives = set()
        for j, obj in enumerate(objectives):
            opath = "%s.objectives[%d]" % (path, j)
            if not isinstance(obj, dict):
                self.E("E-objective", file, opath, "objective must be an object")
                continue
            kind = obj.get("type")
            if kind == "talk":
                if len(objectives) != 1:
                    self.E("E-talk-only", file, opath, "a talk objective must be the quest's only objective")
                self.check_npc(obj.get("npc"), file, opath + ".npc")
                if obj.get("npc") != q.get("turnin"):
                    self.E("E-talk-turnin", file, opath, "travel quests turn in at the talk target (%s, not %s)"
                           % (obj.get("npc"), q.get("turnin")))
                continue
            if not is_int(obj.get("count"), 1):
                self.E("E-objective", file, opath, "count must be an integer >= 1")
            if kind == "kill":
                self.kill_objective(zone, q, obj, level, file, opath, all_areas)
            elif kind == "item":
                has_item, has_group = "item" in obj, "group" in obj
                if has_item == has_group:
                    self.E("E-objective", file, opath, "an item objective names exactly one of 'item' or 'group'")
                elif has_item:
                    self.check_item_ref(obj["item"], file, opath, "item")
                    item_objectives.add(obj["item"])
                else:
                    group = obj["group"]
                    if isinstance(group, str) and group.startswith("group:"):
                        group = group[6:]
                    row = self.ex_groups.get(group)
                    if row is None:
                        self.E("E-unknown-group", file, opath, "item group %r does not exist" % obj["group"])
                    elif not row.get("objective"):
                        self.W("W-group", file, opath, "group %r is not a recommended item kind "
                               "(see items/existing.md, Item groups)" % group)
                for key in LEGACY_OBJECTIVE_KEYS:
                    if key in obj:
                        self.W("W-unknown-key", file, opath, "unknown field %r on an item objective" % key)
            else:
                self.E("E-objective", file, opath, "type %r must be kill, item or talk" % kind)
        drops = q.get("quest_drops") or []
        dropped = set()
        for j, drop in enumerate(drops if isinstance(drops, list) else []):
            dpath = "%s.quest_drops[%d]" % (path, j)
            if not isinstance(drop, dict):
                self.E("E-type", file, dpath, "quest drop must be an object")
                continue
            item = drop.get("item")
            dropped.add(item)
            if (self.catalog_items.get(item) or {}).get("kind") != "quest":
                self.E("E-quest-drop-kind", file, dpath, "%s needs a catalog/items.json entry of kind quest" % item)
            if item not in item_objectives:
                self.E("E-quest-drop-pair", file, dpath, "quest drop %s has no item objective in this quest" % item)
            if not is_int(drop.get("chance"), 1):
                self.E("E-chance", file, dpath, "chance (1 in N) must be an integer >= 1")
            roles = drop.get("roles")
            if not isinstance(roles, list) or not roles:
                self.E("E-required", file, dpath, "quest drop needs a non-empty 'roles' list")
                roles = []
            area_ref = drop.get("area")
            area = self.resolve_area(area_ref, zone, file, dpath, all_areas) if area_ref else None
            for role in roles:
                if self.target_role_ok(role, file, dpath, "quest-drop source"):
                    levels = self.target_levels(zone, role, area_ref, area, file, dpath, all_areas)
                    self.check_level_fit(role, levels, level, file, dpath)
        for item in item_objectives:
            if (self.catalog_items.get(item) or {}).get("kind") == "quest" and item not in dropped:
                self.E("E-quest-item-source", file, path, "quest item %s needs a quest_drops entry" % item)
        repeatable = q.get("repeatable")
        if repeatable is not None and not (isinstance(repeatable, dict) and is_int(repeatable.get("cooldown"), 1)):
            self.E("E-repeatable", file, path + ".repeatable", "repeatable must be {\"cooldown\": seconds}")
        rewards = q.get("rewards")
        if rewards is not None:
            if not isinstance(rewards, dict):
                self.E("E-rewards", file, path + ".rewards", "rewards must be an object")
            else:
                if "xp" in rewards and not self.legacy:
                    self.E("E-legacy", file, path + ".rewards", "fixed 'xp' is legacy-only; use 'weight'")
                if "weight" in rewards:
                    if not is_num(rewards["weight"]) or rewards["weight"] < 0:
                        self.E("E-rewards", file, path + ".rewards", "weight must be a number >= 0 (KE)")
                elif not self.legacy:
                    self.E("E-required", file, path + ".rewards", "rewards need a 'weight' (KE at level)")
                if "copper" in rewards and not is_int(rewards["copper"], 0):
                    self.E("E-rewards", file, path + ".rewards", "copper must be an integer >= 0")
                for j, item in enumerate(rewards.get("items") or []):
                    ipath = "%s.rewards.items[%d]" % (path, j)
                    name, count = None, 1
                    if isinstance(item, dict):
                        name, count = item.get("item"), item.get("count", 1)
                    elif isinstance(item, str):
                        parts = item.split()
                        name = parts[0]
                        count = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 1
                    self.check_item_ref(name, file, ipath, "reward item")
                    if not is_int(count, 1):
                        self.E("E-rewards", file, ipath, "reward count must be an integer >= 1")
        for key in ("optional", "climax", "group"):
            if key in q and not isinstance(q[key], bool):
                self.E("E-type", file, path + "." + key, "%s must be true or false" % key)
        self.check_destinations(zone, q, file, path)

    def check_destinations(self, zone, q, file, path):
        """Ruling 44: no quest sends players into another race's 11-20 zone;
        and none into the other faction's zones (atlas only)."""
        if not self.atlas or zone not in self.atlas.zones:
            return
        targets = []
        for obj in q.get("objectives") or []:
            if not isinstance(obj, dict):
                continue
            if obj.get("type") == "kill" and isinstance(obj.get("area"), str):
                targets.append((C.split_area_ref(obj["area"], zone)[0], "kill area " + obj["area"]))
            elif obj.get("type") == "talk" and obj.get("npc") in self.atlas.npc_zone:
                targets.append((self.atlas.npc_zone[obj["npc"]], "travel target " + obj["npc"]))
        for drop in q.get("quest_drops") or []:
            if isinstance(drop, dict) and isinstance(drop.get("area"), str):
                targets.append((C.split_area_ref(drop["area"], zone)[0], "quest-drop area " + drop["area"]))
        if q.get("turnin") in self.atlas.npc_zone:
            targets.append((self.atlas.npc_zone[q["turnin"]], "turn-in " + q["turnin"]))
        own = self.atlas.zones[zone]
        for target, what in targets:
            info = self.atlas.zones.get(target)
            if info is None or target == zone:
                continue
            if info["role"] == "home" and info["race"] != own["race"]:
                self.E("E-race-track", file, path, "%s lies in %s, another race's 11-20 zone (%s; Ruling 44)"
                       % (what, target, info["race"]))
            elif info["faction"] and own["faction"] and info["faction"] != own["faction"]:
                self.W("W-faction", file, path, "%s lies in %s, a zone of the other faction (%s)"
                       % (what, target, info["faction"]))

    def area_roles(self, area):
        return {sp.get("role") for sp in area.get("species") or [] if isinstance(sp, dict)}

    def resolve_area(self, ref, zone, file, path, all_areas):
        if not isinstance(ref, str) or not ref:
            self.E("E-area", file, path, "area must be 'zone_id/area_id'")
            return None
        azone, aid = C.split_area_ref(ref, zone)
        area = (all_areas.get(azone) or {}).get(aid)
        if "/" not in ref:
            if area is None:
                self.E("E-unknown-area", file, path, "area %r not in %s (cross-zone areas are written "
                       "'zone_id/area_id')" % (ref, zone))
                return None
            self.W("W-area-qualify", file, path, "write the area zone-qualified: %s/%s" % (zone, ref))
            return area
        if area is None:
            self.E("E-unknown-area", file, path, "area %s does not exist (zone %s has %s)" % (
                ref, azone, ", ".join(sorted(all_areas.get(azone) or {})) or "no spawns file / no areas"))
        return area

    def target_levels(self, zone, role, area_ref, area, file, path, all_areas):
        """Level range a kill or quest-drop target is met at: a named leader
        of the zone has its fixed level (and no area), an area its levels,
        otherwise the zone's areas hosting the role, else the role's levels."""
        target_zone = C.split_area_ref(area_ref, zone)[0] if isinstance(area_ref, str) else zone
        leader = self.d.leaders(target_zone).get(role)
        if leader is not None:
            if area_ref:
                self.E("E-leader-area", file, path, "%s is a leader at a fixed spot of %s, not in an area: "
                       "drop the area" % (role, target_zone))
            return (leader["level"], leader["level"]) if is_int(leader.get("level"), 1) else None
        if area_ref:
            if area is None:
                return None
            if role not in self.area_roles(area):
                self.E("E-role-not-in-area", file, path, "%s does not spawn in %s" % (role, area_ref))
            return tuple(area["levels"]) if level_range(area.get("levels")) else None
        hosting = [a for a in (all_areas.get(zone) or {}).values()
                   if role in self.area_roles(a) and level_range(a.get("levels"))]
        if hosting:
            return (min(a["levels"][0] for a in hosting), max(a["levels"][1] for a in hosting))
        if all_areas.get(zone):
            self.W("W-role-not-in-zone", file, path, "%s does not spawn in any area or as a leader of %s"
                   % (role, zone))
        levels = self.role_levels(role)
        return tuple(levels) if levels else None

    def check_level_fit(self, role, levels, level, file, path):
        """Containment: every level the target is met at lies within the
        quest's reward level +- LEVEL_SLACK."""
        if levels and level and not (levels[0] >= level - LEVEL_SLACK and levels[1] <= level + LEVEL_SLACK):
            self.E("E-level-fit", file, path, "%s is met at levels %d-%d; all must lie within quest level %d "
                   "±%d (%d-%d)" % (role, levels[0], levels[1], level, LEVEL_SLACK,
                                    level - LEVEL_SLACK, level + LEVEL_SLACK))

    def target_role_ok(self, role, file, path, what="kill target"):
        if not self.role_def(role)[0]:
            self.E("E-unknown-role", file, path, "role %r is neither a sub-type nor an existing mob" % role)
            return False
        disposition = self.role_disposition(role)
        if disposition == "critter":
            self.E("E-critter-target", file, path, "critter %s is never a %s (Ruling 29)" % (role, what))
            return False
        if disposition is None:
            self.E("E-not-a-mob", file, path, "%s is an NPC or guard, not a %s" % (role, what))
            return False
        return True

    def kill_roles(self, obj, file, path):
        roles = obj.get("roles")
        if self.legacy and roles is None and (obj.get("mobs") or obj.get("mob")):
            # B4's mechanical split keeps today's entity names.
            mobs = obj.get("mobs") or [obj.get("mob")]
            return [m.split(":", 1)[1] if isinstance(m, str) and m.startswith("grug_mobs:") else m
                    for m in mobs]
        if not isinstance(roles, list) or not roles:
            self.E("E-objective", file, path, "kill objective needs a non-empty 'roles' list")
            return []
        return roles

    def kill_objective(self, zone, q, obj, level, file, path, all_areas):
        for key in LEGACY_OBJECTIVE_KEYS:
            if key in obj and not self.legacy:
                self.E("E-legacy", file, path, "%r on a kill objective is legacy-only; use 'roles'/'area'" % key)
        roles = self.kill_roles(obj, file, path)
        area_ref = obj.get("area")
        area = self.resolve_area(area_ref, zone, file, path + ".area", all_areas) if "area" in obj else None
        for role in roles:
            if self.target_role_ok(role, file, path):
                levels = self.target_levels(zone, role, area_ref, area, file, path, all_areas)
                self.check_level_fit(role, levels, level, file, path)

    # -- driver ----------------------------------------------------------
    def run(self):
        for err in self.d.errors:
            self.E("E-json", err.split(":")[0], "$", err)
        if not self.atlas:
            self.W("W-no-atlas", self.d.root, "$", "no zone atlas given (--atlas): zone, anchor, biome and "
                   "zone-band checks skipped; NPCs checked against today's quest registry only")
        self.catalogs()
        all_areas = {zone: self.d.areas(zone) for zone in self.d.spawns}
        # Quest ids of every zone (front files included) first: requires may
        # cross zones.
        for suffix, files in ((".quests.json", self.d.quests), (".front.quests.json", self.d.front)):
            for zone, data in files.items():
                for q in (data or {}).get("quests") or [] if isinstance(data, dict) else []:
                    if isinstance(q, dict) and isinstance(q.get("id"), str):
                        path = "quests[%s]" % q["id"]
                        if q["id"] in self.quest_ids:
                            self.E("E-duplicate", self.d.root / "zones" / (zone + suffix), path,
                                   "quest id %s also in %s" % (q["id"], self.quest_ids[q["id"]][0]))
                        else:
                            self.quest_ids[q["id"]] = (zone, path)
        for zone, data in self.d.spawns.items():
            if not self.only_zones or zone in self.only_zones:
                self.spawns(zone, data)
        hub_givers, lines_by_zone = {}, {}
        for zone, data in self.d.quests.items():
            if not self.only_zones or zone in self.only_zones:
                lines_by_zone[zone] = self.quests(zone, data, all_areas, hub_givers)
        for host, data in self.d.front.items():
            if not self.only_zones or host in self.only_zones:
                self.front_quests(host, data, all_areas, lines_by_zone.get(host))
        self.cycles()
        self.loot_coverage()
        return self.f

    # Which zones of a race track serve each tier's loot (T5/T6: the front).
    TIER_ROLES = {1: ("start",), 2: ("home",), 3: ("capital", "heartland"), 4: ("contested",),
                  5: ("front", "island"), 6: ("front", "island")}

    def zone_drops(self, zone, tier):
        """Items a designed zone's areas drop in band `tier`; None when the
        zone has no spawn areas yet (today's palette, not checked)."""
        areas = self.d.areas(zone)
        if not areas:
            return None
        out = set()
        for area in areas.values():
            levels = area.get("levels")
            if not level_range(levels):
                continue
            if tier not in range((levels[0] - 1) // 10 + 1, (levels[1] - 1) // 10 + 2):
                continue
            for role in self.area_roles(area):
                source, rec = self.role_def(role)
                if source == "subtype":
                    family = self.drop_families.get(rec.get("drops")) or {}
                    rows = list((family.get("bands") or {}).get(str(tier)) or [])
                elif source == "existing":
                    rows = rec.get("drops") or []
                else:
                    rows = []
                out |= {row.get("item") for row in rows if isinstance(row, dict)}
        return out

    def loot_coverage(self):
        """Frame 2.5: every stat loot input of a tier is obtainable in every
        race track's zones of that band (warnings; designed zones only)."""
        if not self.atlas or not self.d.enchants:
            return
        file = self.d.root / "catalog" / "enchants.json"
        races = sorted({z["race"] for z in self.atlas.zones.values() if z["race"]})
        for row in self.d.enchants:
            tier = row.get("tier") if isinstance(row, dict) else None
            if not is_int(tier, 1, 6):
                continue
            roles = self.TIER_ROLES[tier]
            if tier >= 5:
                groups = {"front": [z for z, i in self.atlas.zones.items() if i["role"] in roles]}
            else:
                groups = {race: [z for z, i in self.atlas.zones.items()
                                 if i["role"] in roles and i["race"] == race] for race in races}
            unchecked, drops = [], {}
            for group, zones in groups.items():
                found = [d for d in (self.zone_drops(z, tier) for z in zones) if d is not None]
                if found:
                    drops[group] = set().union(*found)
                else:
                    unchecked.append(group)
            for stat, item in sorted((row.get("stat_loot") or {}).items()):
                missing = [g for g in sorted(drops) if item not in drops[g]]
                if missing:
                    self.W("W-loot-track", file, "enchants.json[tier %d].stat_loot.%s" % (tier, stat),
                           "%s drops in no designed T%d zone of: %s" % (item, tier, ", ".join(missing)))
            if unchecked and drops:
                self.W("W-loot-unchecked", file, "enchants.json[tier %d]" % tier,
                       "no designed T%d zones yet for: %s (stat loot not checked there)"
                       % (tier, ", ".join(unchecked)))

    def cycles(self):
        graph = {}
        for zone, data in self.d.quests.items():
            for q in (data or {}).get("quests") or [] if isinstance(data, dict) else []:
                if isinstance(q, dict) and isinstance(q.get("id"), str):
                    graph[q["id"]] = [r for r in q.get("requires") or [] if isinstance(r, str)]
        state = {}

        def visit(node, stack):
            state[node] = 1
            for nxt in graph.get(node, []):
                if state.get(nxt) == 1:
                    cycle = stack[stack.index(nxt):] + [nxt] if nxt in stack else [node, nxt]
                    self.E("E-cycle", self.d.root / "zones", "requires", "prerequisite cycle: %s" % " -> ".join(cycle))
                elif nxt in graph and not state.get(nxt):
                    visit(nxt, stack + [nxt])
            state[node] = 2

        for node in sorted(graph):
            if not state.get(node):
                visit(node, [node])


def print_findings(findings, root, quiet=False):
    root = str(root)
    for level, code, where, path, msg in sorted(findings.rows, key=lambda r: (r[0] != "E", r[2], r[3])):
        if quiet and level == "W":
            continue
        shown = where[len(root) + 1:] if where.startswith(root + "/") else where
        print("%s [%s] %s: %s: %s" % ("error" if level == "E" else "warning", code, shown, path, msg))
    print("validate: %d error(s), %d warning(s)" % (len(findings.errors()), len(findings.warnings())))


def parse(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--design", default=str(C.DEFAULT_DESIGN))
    ap.add_argument("--existing", default=str(C.DEFAULT_EXISTING))
    ap.add_argument("--atlas", help="zone atlas JSON file or directory (optional)")
    ap.add_argument("--zone", action="append", help="check only these zones' files (all are still loaded)")
    ap.add_argument("--legacy", action="store_true", help="allow legacy-only fields (B4's mechanical split)")
    ap.add_argument("--strict", action="store_true", help="warnings fail too")
    ap.add_argument("--quiet", action="store_true", help="print errors only")
    ap.add_argument("--self-test", action="store_true")
    return ap.parse_args(argv)


def validate(design_dir, existing_path, atlas_path=None, legacy=False, zones=None):
    design = C.Design(design_dir)
    existing = C.load_existing(existing_path)
    atlas = C.Atlas(atlas_path) if atlas_path else None
    return Validator(design, existing, atlas, legacy, zones).run()


def main(argv):
    args = parse(argv)
    if args.self_test:
        return self_test()
    if not Path(args.design).is_dir():
        print("validate: design directory %s not found" % args.design, file=sys.stderr)
        return 2
    try:
        findings = validate(args.design, args.existing, args.atlas, args.legacy, args.zone)
    except C.LoadError as err:
        print("validate: %s" % err, file=sys.stderr)
        return 2
    print_findings(findings, Path(args.design).resolve(), args.quiet)
    if any(r[1] == "E-json" for r in findings.rows):
        return 2
    if findings.errors() or (args.strict and findings.warnings()):
        return 1
    return 0


# --- self-test ----------------------------------------------------------------

def _load(path):
    return json.loads(Path(path).read_text())


def _save(path, data):
    Path(path).write_text(json.dumps(data, indent=2) + "\n")


def _mutations():
    """(name, file, mutate(data), expected code). Each runs on a fresh copy of
    samples/valid; the expected code must appear."""
    Q = "zones/elandor_dawnmere_fields.quests.json"
    S = "zones/elandor_dawnmere_fields.spawns.json"

    def quest(data, qid):
        return next(q for q in data["quests"] if q["id"] == qid)

    def area(data, aid):
        return next(a for a in data["areas"] if a["id"] == aid)

    def add_giver(d):
        d["hubs"][0]["givers"].append({"npc": "r14_human_steward", "lines": ["extra"]})

    def three_lines(d):
        d["hubs"][0]["givers"][0]["lines"].append("third")

    def critter_target(d):
        quest(d, "sample_hunt_01")["objectives"][0] = {"type": "kill", "roles": ["wild_turkey"], "count": 5}

    def wrong_area_role(d):
        quest(d, "sample_hunt_02")["objectives"][0]["area"] = "elandor_dawnmere_fields/home_fields_day"

    def level_fit(d):
        quest(d, "sample_hunt_01")["level"] = 9
        quest(d, "sample_hunt_01")["min_level"] = 9

    def bare_cross(d):
        quest(d, "sample_hunt_01")["objectives"][0]["area"] = "other_zone_area"

    def missing_area(d):
        quest(d, "sample_hunt_01")["objectives"][0]["area"] = "elandor_goldmead_vale/meadow"

    def unpaired_drop(d):
        quest(d, "sample_hunt_04")["objectives"].pop()

    def drop_not_quest_kind(d):
        q = quest(d, "sample_pantry_01")
        q["quest_drops"] = [{"item": "grug_mobs:rat_tail", "roles": ["large_rat"], "chance": 2}]

    def unknown_item(d):
        quest(d, "sample_kitchen_02")["objectives"][0]["item"] = "default:mystery_lump"

    def curated_item(d):
        quest(d, "sample_kitchen_02")["objectives"][0]["item"] = "default:bronze_ingot"

    def unknown_npc(d):
        d["hubs"][0]["givers"][1]["npc"] = "nobody_npc"

    def unknown_group(d):
        quest(d, "sample_tools_02")["objectives"][0]["group"] = "logs"

    def legacy_xp(d):
        quest(d, "sample_tools_01")["rewards"]["xp"] = 50

    def bad_requires(d):
        quest(d, "sample_hunt_02")["requires"] = ["sample_missing"]

    def cycle(d):
        quest(d, "sample_hunt_01")["requires"] = ["sample_hunt_03"]

    def talk_not_only(d):
        quest(d, "sample_travel_01")["objectives"].append({"type": "item", "item": "default:coal_lump", "count": 1})

    def line_not_giver(d):
        quest(d, "sample_kitchen_01")["line"] = "hunt"

    def no_fallback(d):
        area(d, "fallback")["fallback"] = False

    def area_role_levels(d):
        area(d, "home_fields_day")["levels"] = [1, 6]

    def bad_shape(d):
        area(d, "home_beach_night")["shape"] = {"kind": "ring", "r": [120, 20]}

    def bad_biome(d):
        area(d, "home_fields_night")["hosts"]["biomes"] = ["desert"]

    def bad_anchor(d):
        area(d, "home_fields_night")["anchor"] = "nowhere"

    def critter_list(d):
        d["critters"].append("small_boar")

    def size(d):
        d[0]["size"] = 1.6

    def collides(d):
        d[1]["role"] = "boar"

    def three_signatures(d):
        d[1]["bands"]["1"].append({"item": "grug_mobs:boar_tusk", "chance": 5})

    def iron_in_band1(d):
        d[2]["bands"]["1"].append({"item": "grug_materials:iron_bar", "chance": 30})

    def enchant_generic(d):
        d[0]["stat_loot"]["str"] = "mobs:meat_raw"

    def bad_stat(d):
        d[0]["stat_loot"]["luck"] = "grug_mobs:rat_tail"

    def other_race_home(d):
        q = quest(d, "sample_travel_01")
        q["objectives"][0]["npc"] = q["turnin"] = "r14_dwarf_steward"

    def other_race_area(d):
        quest(d, "sample_hunt_01")["objectives"][0]["area"] = "elandor_copperfell_foothills/foothills"

    def other_faction(d):
        q = quest(d, "sample_travel_01")
        q["objectives"][0]["npc"] = q["turnin"] = "r14_troll_elder"

    def foreign_giver(d):
        d["hubs"][0]["givers"][1]["npc"] = "r14_human_scout"
        for q in d["quests"]:
            if q["giver"] == "r20_human_start_cook":
                q["giver"] = "r14_human_scout"
            if q["turnin"] == "r20_human_start_cook":
                q["turnin"] = "r14_human_scout"

    def settlement_anchor_ok(d):
        area(d, "home_fields_night")["anchor"] = "dawnmere"

    def bandits_outside(d):
        area(d, "border_bandits")["offset"] = [120, 560]

    def leader_outside(d):
        d["leaders"][0]["offset"] = [120, 560]

    def band_outside(d):
        area(d, "home_fields_day")["shape"]["forward"] = [600, 900]

    def level_containment(d):
        quest(d, "sample_hunt_01")["level"] = 6
        quest(d, "sample_hunt_01")["min_level"] = 5

    def drop_level(d):
        q = quest(d, "sample_tools_03")
        q["objectives"].append({"type": "item", "item": "grug_mobs:crop_ledger", "count": 1})
        q["quest_drops"] = [{"item": "grug_mobs:crop_ledger", "roles": ["confused_bandit_chief"], "chance": 1}]

    def kill_leader(d):
        quest(d, "sample_hunt_04")["objectives"].append(
            {"type": "kill", "roles": ["confused_bandit_chief"], "count": 1})

    def kill_leader_area(d):
        quest(d, "sample_hunt_04")["objectives"].append(
            {"type": "kill", "roles": ["confused_bandit_chief"], "count": 1,
             "area": "elandor_dawnmere_fields/border_bandits"})

    def bad_family(d):
        d[0]["family_input"]["axe"] = "grug_materials:tin_bar"

    def no_tusk(d):
        d[0]["bands"]["1"] = [row for row in d[0]["bands"]["1"] if row["item"] != "grug_mobs:boar_tusk"]

    return [
        ("three givers in a hub", Q, add_giver, "E-givers"),
        ("three lines for a giver", Q, three_lines, "E-lines"),
        ("critter kill target", Q, critter_target, "E-critter-target"),
        ("target not in area", Q, wrong_area_role, "E-role-not-in-area"),
        ("target levels do not fit quest level", Q, level_fit, "E-level-fit"),
        ("bare area id not in own zone", Q, bare_cross, "E-unknown-area"),
        ("cross-zone area missing", Q, missing_area, "E-unknown-area"),
        ("quest drop without item objective", Q, unpaired_drop, "E-quest-drop-pair"),
        ("quest drop item not kind quest", Q, drop_not_quest_kind, "E-quest-drop-kind"),
        ("unknown item", Q, unknown_item, "E-unknown-item"),
        ("curated-out item", Q, curated_item, "E-curated"),
        ("unknown NPC", Q, unknown_npc, "E-unknown-npc"),
        ("unknown item group", Q, unknown_group, "E-unknown-group"),
        ("legacy xp field", Q, legacy_xp, "E-legacy"),
        ("unknown prerequisite", Q, bad_requires, "E-unknown-requires"),
        ("prerequisite cycle", Q, cycle, "E-cycle"),
        ("talk with another objective", Q, talk_not_only, "E-talk-only"),
        ("line of another giver", Q, line_not_giver, "E-line"),
        ("no fallback area", S, no_fallback, "E-fallback"),
        ("area levels outside role levels", S, area_role_levels, "E-area-role-levels"),
        ("bad ring", S, bad_shape, "E-shape"),
        ("biome not in zone (atlas)", S, bad_biome, "E-unknown-biome"),
        ("anchor not in zone (atlas)", S, bad_anchor, "E-unknown-anchor"),
        ("non-critter in critters", S, critter_list, "E-critter"),
        ("sub-type size", "catalog/subtypes.json", size, "E-size"),
        ("role collides with existing entity", "catalog/subtypes.json", collides, "E-role-collides"),
        ("three signature items in a band", "catalog/drops.json", three_signatures, "E-signature-limit"),
        ("iron bar in band 1", "catalog/drops.json", iron_in_band1, "E-metal-tier"),
        ("enchant loot not a signature drop", "catalog/enchants.json", enchant_generic, "E-enchant-loot"),
        ("unknown stat", "catalog/enchants.json", bad_stat, "E-stat"),
        ("travel into another race's 11-20 zone", Q, other_race_home, "E-race-track"),
        ("kill area in another race's 11-20 zone", Q, other_race_area, "E-race-track"),
        ("travel into the other faction", Q, other_faction, "W-faction"),
        ("giver from another zone", Q, foreign_giver, "E-giver-zone"),
        ("anchor by settlement key", S, settlement_anchor_ok, None),
        ("stat loot not dropped in the track", "catalog/drops.json", no_tusk, "W-loot-track"),
        ("area centre outside the zone", S, bandits_outside, "E-outside-zone"),
        ("leader outside the zone", S, leader_outside, "E-outside-zone"),
        ("band entirely outside the zone", S, band_outside, "E-outside-zone"),
        ("target levels not contained in quest level ±3", Q, level_containment, "E-level-fit"),
        ("quest-drop source levels not contained", Q, drop_level, "E-level-fit"),
        ("kill objective on a leader, no area", Q, kill_leader, "!W-role-not-in-zone"),
        ("kill objective on a leader with an area", Q, kill_leader_area, "E-leader-area"),
        ("unknown enchant family", "catalog/enchants.json", bad_family, "E-family"),
    ]


Q_FILE = "zones/elandor_dawnmere_fields.quests.json"
COOK = "r20_human_start_cook"


def _front_host(target):
    """The cook declares the line `front` (kitchen quests move to pantry)."""
    data = _load(target / Q_FILE)
    for giver in data["hubs"][0]["givers"]:
        if giver["npc"] == COOK:
            giver["lines"] = ["pantry", "front"]
    for q in data["quests"]:
        if q["line"] == "kitchen":
            q["line"] = "pantry"
    _save(target / Q_FILE, data)


def _simple_quest(qid, giver, line, level):
    return {"id": qid, "line": line, "giver": giver, "turnin": giver, "min_level": level, "level": level,
            "requires": [], "title": "Supplies", "text": "The front needs coal. Dig five lumps and bring them here.",
            "objectives": [{"type": "item", "item": "default:coal_lump", "count": 5}],
            "rewards": {"weight": 1, "copper": 5, "items": []}}


def _scenarios():
    """(name, setup(target_dir), legacy, expectation). Expectation: a code
    that must appear, None for "no error", or "!CODE" for "no error and no
    CODE"."""
    def front_file(target, line="front", giver=COOK, host="elandor_dawnmere_fields"):
        _save(target / "zones" / ("%s.front.quests.json" % host),
              {"zone": host, "quests": [_simple_quest("sample_front_01", giver, line, 10)]})

    def front_ok(target):
        _front_host(target)
        front_file(target)

    def front_wrong_line(target):
        _front_host(target)
        front_file(target, line="pantry")

    def front_in_host(target):
        _front_host(target)
        data = _load(target / Q_FILE)
        data["quests"].append(_simple_quest("sample_front_02", COOK, "front", 10))
        _save(target / Q_FILE, data)

    def front_undeclared(target):
        _front_host(target)
        front_file(target, giver="r14_human_elder")

    def front_host_missing(target):
        front_file(target, giver="r14_human_steward", host="elandor_goldmead_vale")

    def contested(zone, npc, lines):
        def setup(target):
            _save(target / "zones" / ("%s.quests.json" % zone), {
                "zone": zone, "hubs": [{"id": "outpost", "anchor": "outpost_1",
                                        "givers": [{"npc": npc, "lines": lines}]}],
                "quests": [_simple_quest("sample_%s_01" % zone.split("_")[1], npc, lines[0], 31)]})
        return setup

    def legacy_kill(target):
        data = _load(target / Q_FILE)
        for q in data["quests"]:
            if q["id"] == "sample_hunt_01":
                q["objectives"] = [{"type": "kill", "mobs": ["grug_mobs:small_boar"], "zone": False, "count": 3}]
        _save(target / Q_FILE, data)

    return [
        ("front file on a declared front line", front_ok, False, "!W-front-host-missing"),
        ("front file quest on another line", front_wrong_line, False, "E-front-line"),
        ("host quests.json uses line front", front_in_host, False, "E-front-line"),
        ("front giver without a front line", front_undeclared, False, "E-front-line"),
        ("front file before its host quests.json", front_host_missing, False, "W-front-host-missing"),
        ("outpost giver without a front line", contested("elandor_ashenward_march", "r20_anchor_031_host",
                                                         ["watch"]), False, "E-front-reserve"),
        ("single-NPC contested zone is exempt", contested("elandor_glassroot_wilds", "r20_anchor_036_host",
                                                          ["watch", "roots"]), False, "!E-front-reserve"),
        ("legacy kill objective with mobs", legacy_kill, True, None),
        ("legacy kill objective without --legacy", legacy_kill, False, "E-legacy"),
    ]


def _expect(name, got, code, failures):
    if code is None or code.startswith("!"):
        if got.errors() or (code and code[1:] in got.codes()):
            failures.append("%s: expected no error%s, got %s" % (
                name, " and no " + code[1:] if code else "", sorted(got.codes())))
    elif code not in got.codes():
        failures.append("%s: expected %s, got %s" % (name, code, sorted(got.codes()) or "nothing"))


def self_test():
    here = Path(__file__).resolve().parent
    valid = here / "samples" / "valid"
    existing = here / "samples" / "existing_min.json"
    atlas = here / "samples" / "atlas"
    failures = []
    findings = validate(valid, existing, atlas)
    # Only Dawnmere is designed: the other race tracks' T1 loot is unchecked.
    if findings.errors() or findings.codes() != {"W-loot-unchecked"}:
        print_findings(findings, valid)
        failures.append("the valid sample gives exactly W-loot-unchecked with the atlas")
    no_atlas = validate(valid, existing, None)
    if no_atlas.errors() or no_atlas.codes() != {"W-no-atlas"}:
        print_findings(no_atlas, valid)
        failures.append("without an atlas the valid sample gives exactly W-no-atlas")
    cases = [(name, rel, mutate, False, code) for name, rel, mutate, code in _mutations()]
    cases += [(name, None, setup, legacy, code) for name, setup, legacy, code in _scenarios()]
    for name, rel, change, legacy, code in cases:
        tmp = Path(tempfile.mkdtemp(prefix="r28_validate_"))
        try:
            target = tmp / "design"
            shutil.copytree(valid, target)
            if rel is None:
                change(target)
            else:
                data = copy.deepcopy(_load(target / rel))
                change(data)
                _save(target / rel, data)
            _expect(name, validate(target, existing, atlas, legacy), code, failures)
        finally:
            shutil.rmtree(tmp)
    if failures:
        for f in failures:
            print("FAIL " + f)
        print("validate self-test: FAIL (%d)" % len(failures))
        return 1
    print("validate self-test: PASS (valid sample as expected; %d variants each give their finding)" % len(cases))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

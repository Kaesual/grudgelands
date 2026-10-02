#!/usr/bin/env python3
"""Round 28 design validator: checks every design JSON file against the data
formats of docs/planning/round28-design-frame.md section 4 and the limits of
section 2.5, and cross-checks references between files.

Reads the whole design directory (references cross files): catalog/*.json and
zones/<zone>.spawns.json / zones/<zone>.quests.json. A spawns file holds the
zone's spawn RECIPE (rules, no coordinates; docs/design/spawn_regions.md),
parsed like the game's spawn_regions_core.lua (r28common.parse_recipe); a
quest's area (`zone_id/area_id`) is a kind or camp of that recipe, met at
the union of its roles' levels, and a leader at its computed level.
Existing items, mob entities and quest NPCs come from
docs/planning/round28/items/existing.json; zone ids, anchors, neighbours,
NPCs and level bands from the zone atlas when one is given (--atlas);
without it those checks are skipped with one warning.

Every finding has a code ([E-...] error, [W-...] warning), the file and the
JSON path. Exit code 0 = no errors, 1 = errors (or warnings with --strict),
2 = files could not be read.

Usage:
  validate.py [--design DIR] [--game] [--existing FILE] [--atlas FILE_OR_DIR]
              [--zone ZONE ...] [--legacy] [--strict] [--quiet]
  validate.py --self-test
"""
import argparse
import copy
import json
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

SUBTYPE_KEYS = {"role", "family", "base", "display", "display_by_zone", "tint_by_zone", "size",
                "disposition", "tier", "leader", "levels", "drops", "notes"}
SUBTYPE_REQUIRED = ("role", "family", "base", "display", "size", "disposition", "levels", "drops")
ITEM_KEYS = {"id", "name", "tier", "family", "kind", "description", "uses", "icon", "notes"}
ITEM_REQUIRED = ("id", "name", "tier", "kind", "description")
ITEM_KINDS = ("signature", "generic", "reagent", "quest")
REAGENT_KEYS = {"id", "name", "tier", "method", "inputs", "output_count", "uses", "notes"}
QUEST_KEYS = {"id", "line", "giver", "turnin", "min_level", "level", "requires", "title", "text",
              "objectives", "rewards", "quest_drops", "repeatable", "lesson", "duration_min",
              "optional", "climax", "group", "notes"}
QUEST_REQUIRED = ("id", "line", "giver", "turnin", "min_level", "level", "title", "text",
                  "objectives", "rewards")
LEGACY_QUEST_KEYS = ("xp", "faction", "race")
LEGACY_OBJECTIVE_KEYS = ("mobs", "mob", "zone", "role")
# Today's contested-zone quests ask for enemy faction guards (the level-40
# guard kills). B4's mechanical split keeps them; only legacy kill objectives
# (`mobs`) may name these two, a new design names mobs only.
LEGACY_GUARD_TARGETS = ("guard_accord", "guard_throng")
DISPOSITIONS = ("neutral", "aggressive", "critter")
FRONT_LINE = "front"
FAMILIES = ("sword", "dagger", "greataxe", "metal_armor", "shield", "leather_armor", "cloth_armor",
            "bow", "caster_weapon", "spellbook", "trinket")

# Quest text placeholders and the compass-word rule (Round 29 Q1; the game's
# rules in mods/PLAYER/grug_quests/labels.lua): placeholder -> argument count.
PLACEHOLDER_KINDS = {"dir_from_giver": 1, "dir_of": 2, "zone_area": 1, "name": 1}
PLACEHOLDER_DIRECTIONS = ("dir_from_giver", "dir_of", "zone_area")
PLACEHOLDER_ID = re.compile(r"^[a-z][a-z0-9_]*$")
PLACEHOLDER_TARGET = re.compile(r"^[a-z][a-z0-9_]*(/[a-z][a-z0-9_]*)?$")
COMPASS = {base + suffix for base in ("north", "south", "east", "west", "northeast", "northwest",
                                      "southeast", "southwest")
           for suffix in ("", "ern", "erly", "ward", "wards", "bound", "most", "ernmost", "erner", "erners")}


def scan_placeholders(text):
    """([(kind, args, raw)], [syntax error]) of a title or text, as the
    game's placeholders.scan: a brace outside a well-formed placeholder, an
    unknown kind, a wrong argument count or a malformed id is an error."""
    found, errors = [], []
    pos = 0
    while True:
        m = re.compile(r"[{}]").search(text, pos)
        if not m:
            break
        s = m.start()
        e = re.compile(r"[{}]").search(text, s + 1) if text[s] == "{" else None
        if e is None or text[e.start()] != "}":
            errors.append("unmatched brace at character %d" % (s + 1))
            pos = s + 1
            continue
        e = e.start()
        raw = text[s:e + 1]
        parts = text[s + 1:e].split(":")
        kind, args = parts[0], parts[1:]
        if kind not in PLACEHOLDER_KINDS:
            errors.append("%s: unknown placeholder" % raw)
        elif len(args) != PLACEHOLDER_KINDS[kind]:
            n = PLACEHOLDER_KINDS[kind]
            errors.append("%s: takes %d argument%s" % (raw, n, "" if n == 1 else "s"))
        elif not PLACEHOLDER_TARGET.match(args[-1]) or (kind == "dir_of" and not PLACEHOLDER_ID.match(args[0])):
            errors.append("%s: ids are snake_case (a target may be zone_id/id)" % raw)
        else:
            found.append((kind, args, raw))
        pos = e + 1
    return found, errors


def compass_words(text):
    """The fixed compass words of a title or text (whole words, any case;
    "north-east" reads as two words), placeholders left out."""
    return [w for w in re.findall(r"[A-Za-z]+", re.sub(r"\{[^{}]*\}", " ", text)) if w.lower() in COMPASS]


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
    def __init__(self, design, existing, atlas=None, legacy=False, zones=None, mob_facts=None):
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
        self.new_npcs, self.used_sockets = {}, {}
        self.item_files, self.role_files, self.zone_roles = {}, {}, {}
        self.mob_facts = mob_facts or {}
        self.mob_facts_warned = False
        if atlas:
            self.npcs |= atlas.all_npcs()
        self.registered_npcs = set(self.npcs)

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
            rel, zone_of = d.item_origin[i] if i < len(d.item_origin) else ("catalog/items.json", None)
            file = d.root / rel
            path = "items[%d]" % i if zone_of else "items.json[%d]" % i
            if not isinstance(row, dict):
                self.E("E-type", file, path, "entry must be an object")
                continue
            self.unknown_keys(row, ITEM_KEYS, file, path)
            self.required(row, ITEM_REQUIRED, file, path)
            iid = row.get("id")
            if not isinstance(iid, str) or not C.ITEM_ID.match(iid):
                self.E("E-id", file, path, "id %r must be 'mod:snake_case'" % iid)
                continue
            if iid in self.catalog_items:
                self.E("E-duplicate", file, path, "duplicate item id %s (also in %s)"
                       % (iid, self.item_files.get(iid)))
            self.catalog_items[iid] = row
            self.item_files[iid] = rel
            if iid in self.curated:
                self.E("E-curated", file, path, "%s is curated out" % iid)
            if row.get("kind") not in ITEM_KINDS:
                self.E("E-enum", file, path, "kind %r not in %s" % (row.get("kind"), ITEM_KINDS))
            elif zone_of and row["kind"] != "quest":
                self.E("E-zone-catalog", file, path, "a zone catalogue adds only quest-only items (kind quest); "
                       "%s belongs in catalog/items.json" % iid)
            if not is_int(row.get("tier"), 1, 6):
                self.E("E-tier", file, path, "tier must be 1..6")
            if iid not in self.ex_items and not row.get("icon"):
                self.W("W-icon", file, path, "new item %s has no icon description" % iid)
        for i, row in enumerate(d.subtypes or []):
            rel, zone_of = d.subtype_origin[i] if i < len(d.subtype_origin) else ("catalog/subtypes.json", None)
            file = d.root / rel
            path = "subtypes[%d]" % i if zone_of else "subtypes.json[%d]" % i
            if not isinstance(row, dict):
                self.E("E-type", file, path, "entry must be an object")
                continue
            self.unknown_keys(row, SUBTYPE_KEYS, file, path)
            self.required(row, SUBTYPE_REQUIRED, file, path)
            role = row.get("role")
            if not isinstance(role, str) or not C.SNAKE.match(role):
                self.E("E-id", file, path, "role %r must be snake_case" % role)
                continue
            path = ("subtypes[%s]" if zone_of else "subtypes.json[%s]") % role
            if role in self.subtypes:
                self.E("E-duplicate", file, path, "duplicate role %s (also in %s)" % (role, self.role_files.get(role)))
            self.subtypes[role] = row
            self.role_files[role] = rel
            if zone_of:
                self.zone_roles[role] = zone_of
                if row.get("leader") is not True:
                    self.E("E-zone-catalog", file, path, "a zone catalogue adds only leader roles (\"leader\": true); "
                           "%s belongs in catalog/subtypes.json" % role)
            self.check_base(row, file, path)
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
        # An existing mob's drop family is its own role (grug_mobs/subtypes.lua).
        used_families = ({row.get("drops") for row in self.subtypes.values()}
                         | {name.split(":", 1)[1] for name in self.ex_entities})
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

    def base_facts(self, base):
        """(disposition, attack_type) of a base entity: the mob catalogue,
        else existing.json (which has no attack_type)."""
        mob = self.mob_facts.get(base)
        if mob is not None:
            return mob.get("disposition"), (mob.get("combat") or {}).get("attack_type")
        entity = self.ex_entities.get(base) or {}
        return entity.get("disposition"), None

    def check_base(self, row, file, path):
        """A sub-type never changes a critter base, and an aggressive role
        needs a base that can attack (B2 enforces both in the game)."""
        base = row.get("base")
        if base not in self.ex_entities and base not in self.mob_facts:
            return
        disposition, attack_type = self.base_facts(base)
        role_disposition = row.get("disposition")
        if disposition == "critter" and role_disposition != "critter":
            self.E("E-critter-base", file, path, "base %s is a critter; a sub-type of it stays a critter "
                   "(not %r)" % (base, role_disposition))
        if role_disposition == "aggressive" and base in self.mob_facts and not attack_type:
            self.E("E-attack-type", file, path, "aggressive role on base %s, which has no attack_type "
                   "(it cannot fight)" % base)
        elif role_disposition == "aggressive" and base not in self.mob_facts and not self.mob_facts_warned:
            self.mob_facts_warned = True
            self.W("W-no-mob-catalogue", file, path, "no mob catalogue entry for %s: attack_type not checked "
                   "(--mobs docs/planning/round28/mobs/catalogue.json)" % base)

    def zone_leaders_placed(self):
        """A zone-added leader role is a leader of its own zone."""
        for role, zone in sorted(self.zone_roles.items()):
            file = self.d.root / self.role_files[role]
            for other, data in self.d.spawns.items():
                if other != zone and role in self.d.leaders(other):
                    self.E("E-zone-leader", self.d.zone_file("%s.spawns.json" % other), "recipe.leaders",
                           "%s was added by %s's zone catalogue and is a leader of %s only" % (role, zone, zone))
            if role not in self.d.leaders(zone):
                self.W("W-zone-leader", file, "subtypes[%s]" % role, "zone-added leader %s is not placed in "
                       "zones/%s.spawns.json recipe.leaders" % (role, zone))

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
        """zones/<zone>.spawns.json: {"zone", "recipe", "palette"?, "notes"?}.
        The recipe is parsed like the game (r28common.parse_recipe mirrors
        spawn_regions_core.lua); its roles, critters, leaders and, with an
        atlas, its band, `from` anchor and `to` borders are checked here."""
        file = self.d.zone_file("%s.spawns.json" % zone)
        if not isinstance(data, dict):
            self.E("E-type", file, "$", "spawns file must be an object")
            return
        for key in data:
            if key not in C.SPAWNS_FILE_KEYS:
                self.E("E-recipe-key", file, "$", "unknown field %r (%s)" % (key, ", ".join(C.SPAWNS_FILE_KEYS)))
        if data.get("zone") != zone:
            self.E("E-zone-mismatch", file, "zone", "zone %r does not match the file name %s" % (data.get("zone"), zone))
        info = self.zone_info(zone)
        if self.atlas and info is None:
            self.E("E-unknown-zone", file, "zone", "zone %s is not in the atlas" % zone)
        palette = data.get("palette")
        if palette is not None:
            if not isinstance(palette, dict):
                self.E("E-type", file, "palette", "palette must be an object")
            else:
                for key in palette:
                    if key not in C.PALETTE_KEYS:
                        self.E("E-recipe-key", file, "palette", "unknown field %r (%s)"
                               % (key, ", ".join(C.PALETTE_KEYS)))
        if "recipe" not in data:
            if palette is None:
                self.E("E-required", file, "recipe", "a spawns file needs a recipe (a shipped file without one "
                       "keeps its palette)")
            return
        band = info["levels"] if info is not None and info.get("levels") else None
        parsed, errors = C.parse_recipe(zone, data["recipe"], band, self.role_levels,
                                        lambda role: (self.subtypes.get(role) or {}).get("leader") is True,
                                        info["pois"] if info is not None else None)
        for err in errors:
            self.E(err.code, file, "recipe." + err.path if err.path != "recipe" else "recipe", err.msg)
        if parsed is None:
            return
        # Roles exist and are ambient mobs.
        for unit in parsed["kinds"] + parsed["camps"]:
            path = "recipe.%s[%s]" % ("camps" if unit["unit"] == "camp" else "kinds", unit["id"])
            for role in unit["roles"]:
                source = self.role_def(role)[0]
                disposition = self.role_disposition(role)
                if not source:
                    self.E("E-unknown-role", file, path, "role %r is neither a sub-type nor an existing mob" % role)
                elif disposition == "critter":
                    self.W("W-critter-area", file, path, "critter %s belongs in 'critters'" % role)
                elif disposition is None:
                    self.E("E-not-a-mob", file, path, "%s is an NPC or guard, not an ambient mob" % role)
        for i, role in enumerate(parsed["critters"]):
            path = "recipe.critters[%d]" % i
            if not self.role_def(role)[0]:
                self.E("E-unknown-role", file, path, "role %r is neither a sub-type nor an existing mob" % role)
            elif self.role_disposition(role) != "critter":
                self.E("E-critter", file, path, "%r is not a critter role" % role)
        for leader in parsed["leaders"]:
            role = leader["role"]
            path = "recipe.leaders[%s]" % role
            source, rec = self.role_def(role)
            if not source:
                self.E("E-unknown-role", file, path, "role %r is neither a sub-type nor an existing mob" % role)
                continue
            if source == "subtype" and rec.get("tier") == "elite" and leader["level"] is not None \
                    and leader["level"] < 31:
                self.E("E-leader-tier", file, path, "elite leaders only from level 31 (frame 2.4); this one "
                       "stands at level %d" % leader["level"])
            for other in sorted(self.d.spawns):
                if other != zone and role in self.d.leaders(other):
                    self.E("E-duplicate", file, path, "leader %s is also placed by %s (a leader stands in one "
                           "zone)" % (role, other))
        # The atlas: `from` names anchors of the zone or its neighbours, `to`
        # its neighbours.
        if info is None:
            return
        for anchor in (parsed["from"] or {}).get("anchor") or []:
            if anchor not in info["anchor_refs"]:
                refs = sorted(r for r in info["anchor_refs"] if not r.startswith("anchor_") and not r.startswith("r20_"))
                self.E("E-unknown-anchor", file, "recipe.from.anchor", "anchor %r is not an anchor of %s (anchor "
                       "id or slot; this zone has: %s)" % (anchor, zone, ", ".join(refs) or "none"))
        borders = [("from", i, other) for i, other in enumerate((parsed["from"] or {}).get("border") or [])]
        borders += [("to", i, other) for i, other in enumerate((parsed["to"] or {}).get("border") or [])]
        for key, i, other in borders:
            path = "recipe.%s.border[%d]" % (key, i)
            if other not in self.atlas.zones:
                self.E("E-unknown-zone", file, path, "zone %r is not in the atlas" % other)
            elif other not in info["neighbours"]:
                self.W("W-border-neighbour", file, path, "%s is not a neighbour of %s in the atlas (neighbours: "
                       "%s); the game needs a land border with it" % (other, zone,
                                                                      ", ".join(sorted(info["neighbours"])) or "none"))

    def quests(self, zone, data, all_areas, hub_givers):
        file = self.d.zone_file("%s.quests.json" % zone)
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
                if isinstance(giver, dict) and "new" in giver:
                    self.check_new_giver(zone, hub, hub_anchor, giver, file, gpath)
                else:
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

    def collect_new_givers(self):
        """New givers declared at free quest sockets (`"new": {...}`) are valid
        giver and turn-in NPCs everywhere in the design."""
        for zone, data in self.d.quests.items():
            for hub in (data or {}).get("hubs") or [] if isinstance(data, dict) else []:
                for giver in (hub or {}).get("givers") or [] if isinstance(hub, dict) else []:
                    if isinstance(giver, dict) and "new" in giver and isinstance(giver.get("npc"), str):
                        if giver["npc"] not in self.new_npcs:
                            self.new_npcs[giver["npc"]] = zone

    def check_new_giver(self, zone, hub, hub_anchor, giver, file, path):
        npc, new = giver.get("npc"), giver.get("new")
        if not isinstance(npc, str) or not C.SNAKE.match(npc):
            self.E("E-new-giver", file, path, "a new giver's npc id %r must be snake_case" % npc)
        elif npc in self.registered_npcs:
            self.E("E-new-giver", file, path, "%s is already a registered quest NPC; drop 'new'" % npc)
        elif self.new_npcs.get(npc) != zone:
            self.E("E-duplicate", file, path, "new giver %s is also declared in %s" % (npc, self.new_npcs.get(npc)))
        if not isinstance(new, dict):
            self.E("E-new-giver", file, path, "'new' must be {\"name\", \"race\", \"socket\"}")
            return
        for key in ("name", "race", "socket"):
            if not isinstance(new.get(key), str) or not new[key].strip():
                self.E("E-new-giver", file, path, "new giver needs a non-empty %r" % key)
        for key in new:
            if key not in ("name", "race", "socket"):
                self.W("W-unknown-key", file, path + ".new", "unknown field %r" % key)
        if isinstance(new.get("race"), str) and new["race"] not in C.RACE_FACTION:
            self.W("W-new-giver", file, path, "race %r is not one of %s" % (new["race"], ", ".join(sorted(C.RACE_FACTION))))
        info = self.zone_info(zone)
        if info is None or not isinstance(new.get("socket"), str):
            return
        key = (hub_anchor, new["socket"])
        if key not in info["free_sockets"]:
            free = sorted("%s at %s" % (sock, info["free_sockets"][(anc, sock)]["settlement"])
                          for anc, sock in info["free_sockets"])
            self.E("E-new-giver", file, path, "socket %r is not a free quest socket of the hub's settlement "
                   "(%s; free in %s: %s)" % (new["socket"], hub.get("anchor"), zone, "; ".join(free) or "none"))
        elif key in self.used_sockets:
            self.E("E-duplicate", file, path, "free socket %s is already used by %s" % (new["socket"],
                                                                                     self.used_sockets[key]))
        else:
            self.used_sockets[key] = npc

    def npc_zone(self, npc):
        if self.atlas and npc in self.atlas.npc_zone:
            return self.atlas.npc_zone[npc]
        return self.new_npcs.get(npc) if self.atlas else None

    def front_reserve(self, zone, giver_lines, file):
        """Frame 2.1: each 31-40 outpost giver and one quest giver per capital
        reserve one of their two lines, `front`, for the front lane. A
        contested zone with a single quest NPC keeps both lines (exempt)."""
        info = self.zone_info(zone)
        if info is not None and info["role"] == "capital" and giver_lines and \
                not any(FRONT_LINE in lines for lines in giver_lines.values()):
            self.E("E-front-reserve", file, "hubs", "one quest giver of the capital declares the line 'front' "
                   "(reserved for the front lane)")
        if info is None or info["role"] != "contested" or len(info["npcs"]) <= 1:
            return
        for npc in sorted(info["npcs"]):
            if info["anchor_kinds"].get(info["npcs"][npc]["anchor"]) != "outpost":
                continue
            if npc not in giver_lines:
                self.E("E-front-reserve", file, "hubs", "outpost quest NPC %s must be declared as a giver "
                       "(with the line 'front', reserved for the front lane)" % npc)
            elif FRONT_LINE not in giver_lines[npc]:
                self.E("E-front-reserve", file, "hubs", "outpost giver %s must declare the line 'front' "
                       "(one of its two lines, reserved for the front lane)" % npc)

    def front_quests(self, host, data, all_areas, giver_lines):
        """zones/<host>.front.quests.json: front quests given by the host
        zone's givers, only on a line `front` the host's quests.json declares."""
        file = self.d.zone_file("%s.front.quests.json" % host)
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
        self.check_texts(zone, q, file, path, all_areas)
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
                if "roles" in obj or "area" in obj:
                    self.item_source(zone, obj, level, file, opath, all_areas)
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
                    if not isinstance(item, dict):
                        self.E("E-rewards", file, ipath, "reward items are {\"item\": id, \"count\": n}")
                        continue
                    name, count = item.get("item"), item.get("count", 1)
                    self.check_item_ref(name, file, ipath, "reward item")
                    if not is_int(count, 1):
                        self.E("E-rewards", file, ipath, "reward count must be an integer >= 1")
        for key in ("optional", "climax", "group"):
            if key in q and not isinstance(q[key], bool):
                self.E("E-type", file, path + "." + key, "%s must be true or false" % key)
        self.check_destinations(zone, q, file, path)

    def placeholder_target(self, zone, ref, all_areas):
        """A placeholder target: a leader role (any zone), else a kind or
        camp of the zone's recipe (a bare id: the quest's zone). The area
        summary, {"type": "leader"} or None."""
        qualified, _, rest = ref.partition("/")
        target_zone, tid = (qualified, rest) if rest else (zone, ref)
        found = self.d.find_leader(tid, target_zone if rest else None)
        if found is not None and (not rest or found[0] == target_zone):
            return {"type": "leader"}
        return (all_areas.get(target_zone) or {}).get(tid)

    def check_texts(self, zone, q, file, path, all_areas):
        """Round 29 Q1: placeholders in the title and text resolve (a title
        takes only {name:...}), places exist (with --atlas), "from here"
        points at a compact target, and no fixed compass word is written."""
        for key in ("title", "text"):
            value = q.get(key)
            if not isinstance(value, str):
                continue
            kpath = "%s.%s" % (path, key)
            found, problems = scan_placeholders(value)
            for problem in problems:
                self.E("E-placeholder", file, kpath, problem)
            for kind, args, raw in found:
                if key == "title" and kind in PLACEHOLDER_DIRECTIONS:
                    self.E("E-placeholder", file, kpath, "%s: a title takes only {name:...}; directions "
                           "belong in the text" % raw)
                target = self.placeholder_target(zone, args[-1], all_areas)
                if target is None:
                    self.E("E-placeholder-target", file, kpath, "%s: %s is no kind, camp or leader of %s"
                           % (raw, args[-1], args[-1].split("/")[0] if "/" in args[-1] else zone))
                elif kind == "dir_from_giver" and target.get("type") == "open":
                    self.W("W-placeholder-spread", file, kpath, "%s: %s is an open kind spread over many "
                           "patches; use {zone_area:...} or {dir_of:<place>:...}" % (raw, args[-1]))
                if kind == "dir_of" and self.atlas and args[0] not in self.atlas.places:
                    self.E("E-placeholder-place", file, kpath, "%s: %s is not a settlement key or anchor id"
                           % (raw, args[0]))
            for word in compass_words(value):
                self.E("E-compass", file, kpath, "fixed compass word %r; write a direction placeholder or "
                       "neutral wording" % word)

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
            elif obj.get("type") == "talk" and self.npc_zone(obj.get("npc")):
                targets.append((self.npc_zone(obj["npc"]), "travel target " + obj["npc"]))
        for drop in q.get("quest_drops") or []:
            if isinstance(drop, dict) and isinstance(drop.get("area"), str):
                targets.append((C.split_area_ref(drop["area"], zone)[0], "quest-drop area " + drop["area"]))
        if self.npc_zone(q.get("turnin")):
            targets.append((self.npc_zone(q["turnin"]), "turn-in " + q["turnin"]))
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
        """The roles a quest area (a recipe kind or camp) spawns, day and night."""
        return set(area.get("roles") or [])

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
                ref, azone, ", ".join(sorted(all_areas.get(azone) or {})) or "no spawns recipe: no kinds or camps"))
        return area

    def target_levels(self, zone, role, area_ref, area, file, path, all_areas):
        """Level range a kill or quest-drop target is met at: a named leader
        (of this zone, else of any zone: leader roles are unique fixed spots)
        has its fixed level and no area; an area (a kind or camp of the
        recipe) its levels, the union over its roles (as the game's quest
        validator), otherwise the zone's kinds and camps hosting the role,
        else the role's levels."""
        found = self.d.find_leader(role, zone)
        if found is not None:
            leader_zone, leader = found
            if area_ref:
                self.E("E-leader-area", file, path, "%s is a leader at a fixed spot of %s, not in an area: "
                       "drop the area" % (role, leader_zone))
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

    def target_role_ok(self, role, file, path, what="kill target", legacy_guard=False):
        if not self.role_def(role)[0]:
            self.E("E-unknown-role", file, path, "role %r is neither a sub-type nor an existing mob" % role)
            return False
        disposition = self.role_disposition(role)
        if disposition == "critter":
            self.E("E-critter-target", file, path, "critter %s is never a %s (Ruling 29)" % (role, what))
            return False
        if disposition is None and legacy_guard and role in LEGACY_GUARD_TARGETS:
            return True
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
        legacy_guard = self.legacy and obj.get("roles") is None
        for role in roles:
            if self.target_role_ok(role, file, path, legacy_guard=legacy_guard):
                levels = self.target_levels(zone, role, area_ref, area, file, path, all_areas)
                self.check_level_fit(role, levels, level, file, path)
        self.check_recipe_targets(zone, obj, roles, file, path, all_areas)

    def item_source(self, zone, obj, level, file, path, all_areas):
        """An item objective's optional source (Lane Q0): the roles that drop
        it, optionally in one area. Checked like a quest drop's source; the
        game shows their level range with the objective."""
        roles = obj.get("roles")
        if roles is None:
            self.E("E-area", file, path, "an item's source area is 'zone_id/area_id' next to its 'roles'")
            return
        if not isinstance(roles, list) or not roles:
            self.E("E-objective", file, path, "an item's source 'roles' must be a non-empty list")
            return
        area_ref = obj.get("area")
        area = self.resolve_area(area_ref, zone, file, path + ".area", all_areas) if area_ref else None
        for role in roles:
            if self.target_role_ok(role, file, path, "item source"):
                levels = self.target_levels(zone, role, area_ref, area, file, path, all_areas)
                self.check_level_fit(role, levels, level, file, path)

    def check_recipe_targets(self, zone, obj, roles, file, path, all_areas):
        """A kill objective without an area in a zone with a spawn recipe,
        none of whose targets the recipe spawns (a kind or a camp of the
        zone) and none of which is a leader (of any zone: a leader stands at
        its own spot, so a front file may name another zone's leader; with a
        `zone` filter only the filter zone's leaders): only
        the recipe's roles appear on that zone's surface. A warning (the
        targets may live in another zone on purpose); the game's quest loader
        logs the same (grug_quests/validate.lua)."""
        if "area" in obj or not roles:
            return
        kill_zone = obj.get("zone") if isinstance(obj.get("zone"), str) else zone
        areas = all_areas.get(kill_zone) or {}
        if not areas:
            return
        spawned = set()
        for unit in areas.values():
            spawned |= set(unit.get("roles") or ())
        bare = {r.split(":", 1)[1] if r.startswith("grug_mobs:") else r for r in roles if isinstance(r, str)}
        # A zone-filtered (legacy) objective counts only kills in that zone.
        filtered = isinstance(obj.get("zone"), str)
        for r in bare:
            found = self.d.find_leader(r)
            if found and (not filtered or found[0] == kill_zone):
                spawned.add(r)
        # Guards stand at their guard posts, never in a recipe's regions.
        if bare & set(LEGACY_GUARD_TARGETS):
            return
        if not bare & spawned:
            self.W("W-recipe-target", file, path, "no kill target (%s) is spawned by %s's spawn recipe"
                   % (", ".join(sorted(bare)), kill_zone))

    # -- driver ----------------------------------------------------------
    def run(self):
        for err in self.d.errors:
            self.E("E-json", err.split(":")[0], "$", err)
        if not self.atlas:
            self.W("W-no-atlas", self.d.root, "$", "no zone atlas given (--atlas): zone, anchor, border and "
                   "zone-band checks skipped; NPCs checked against today's quest registry only")
        self.catalogs()
        self.collect_new_givers()
        self.npcs |= set(self.new_npcs)
        all_areas = {zone: self.d.areas(zone) for zone in self.d.spawns}
        # Quest ids of every zone (front files included) first: requires may
        # cross zones.
        for suffix, files in ((".quests.json", self.d.quests), (".front.quests.json", self.d.front)):
            for zone, data in files.items():
                for q in (data or {}).get("quests") or [] if isinstance(data, dict) else []:
                    if isinstance(q, dict) and isinstance(q.get("id"), str):
                        path = "quests[%s]" % q["id"]
                        if q["id"] in self.quest_ids:
                            self.E("E-duplicate", self.d.zone_file(zone + suffix), path,
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
        self.zone_leaders_placed()
        for zone, data in self.d.zone_catalogs.items():
            file = self.d.zone_file("%s.catalog.json" % zone)
            if not isinstance(data, dict):
                self.E("E-type", file, "$", "a zone catalogue is {\"subtypes\": [...], \"items\": [...]}")
                continue
            for key in data:
                if key not in ("subtypes", "items", "notes"):
                    self.W("W-unknown-key", file, "$", "unknown field %r (subtypes, items)" % key)
            if self.atlas and zone not in self.atlas.zones:
                self.E("E-unknown-zone", file, "$", "zone %s is not in the atlas" % zone)
        return self.f

    # Which zones of a race track serve each tier's loot (T5/T6: the front).
    TIER_ROLES = {1: ("start",), 2: ("home",), 3: ("capital", "heartland"), 4: ("contested",),
                  5: ("front", "island"), 6: ("front", "island")}

    def zone_drops(self, zone, tier):
        """Items a designed zone's kinds and camps drop in band `tier`; None
        when the zone has no recipe yet (today's palette, not checked)."""
        areas = self.d.areas(zone)
        if not areas:
            return None
        out = set()
        for area in areas.values():
            for role, levels in sorted(area["levels_by_role"].items()):
                if tier not in range((levels[0] - 1) // 10 + 1, (levels[1] - 1) // 10 + 2):
                    continue
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
        for zone, data in list(self.d.quests.items()) + list(self.d.front.items()):
            for q in (data or {}).get("quests") or [] if isinstance(data, dict) else []:
                if isinstance(q, dict) and isinstance(q.get("id"), str):
                    graph[q["id"]] = [r for r in q.get("requires") or [] if isinstance(r, str)]
        state = {}

        def visit(node, stack):
            state[node] = 1
            for nxt in graph.get(node, []):
                if state.get(nxt) == 1:
                    cycle = stack[stack.index(nxt):] + [nxt] if nxt in stack else [node, nxt]
                    self.E("E-cycle", self.d.zone_dirs[-1], "requires", "prerequisite cycle: %s" % " -> ".join(cycle))
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
        shown = where
        for base in (root, str(C.REPO)):
            if where.startswith(base + "/"):
                shown = where[len(base) + 1:]
                break
        print("%s [%s] %s: %s: %s" % ("error" if level == "E" else "warning", code, shown, path, msg))
    print("validate: %d error(s), %d warning(s)" % (len(findings.errors()), len(findings.warnings())))


def parse(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--design", default=str(C.DEFAULT_DESIGN))
    ap.add_argument("--existing", default=str(C.DEFAULT_EXISTING))
    ap.add_argument("--atlas", help="zone atlas JSON file or directory (optional)")
    ap.add_argument("--mobs", default=str(C.DEFAULT_MOBS),
                    help="mob catalogue (attack_type of sub-type bases)")
    ap.add_argument("--game", action="store_true",
                    help="read the zone files from the game (grug_mobs and grug_quests data/zones) "
                         "instead of the design's zones/; the catalogue stays the design's")
    ap.add_argument("--zone", action="append", help="check only these zones' files (all are still loaded)")
    ap.add_argument("--legacy", action="store_true", help="allow legacy-only fields (B4's mechanical split)")
    ap.add_argument("--strict", action="store_true", help="warnings fail too")
    ap.add_argument("--quiet", action="store_true", help="print errors only")
    ap.add_argument("--self-test", action="store_true")
    return ap.parse_args(argv)


def load_mob_facts(path):
    """{entity: catalogue row} from the mob catalogue (attack_type etc.)."""
    if not path or not Path(path).exists():
        return {}
    data = C.read_json(path)
    return {row["entity"]: row for row in (data.get("mobs") or []) if isinstance(row, dict) and row.get("entity")}


def validate(design_dir, existing_path, atlas_path=None, legacy=False, zones=None, mobs_path=C.DEFAULT_MOBS,
             zone_dirs=None):
    design = C.Design(design_dir, zone_dirs)
    existing = C.load_existing(existing_path)
    atlas = C.Atlas(atlas_path) if atlas_path else None
    return Validator(design, existing, atlas, legacy, zones, load_mob_facts(mobs_path)).run()


def main(argv):
    args = parse(argv)
    if args.self_test:
        return self_test()
    if not Path(args.design).is_dir():
        print("validate: design directory %s not found" % args.design, file=sys.stderr)
        return 2
    try:
        findings = validate(args.design, args.existing, args.atlas, args.legacy, args.zone, args.mobs,
                            C.GAME_ZONE_DIRS if args.game else None)
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


def _add_subtype(**fields):
    """A mutation appending one sub-type row to catalog/subtypes.json."""
    def change(d):
        row = {"role": "odd_role", "family": "boar", "base": "grug_mobs:boar", "display": "Odd",
               "size": 1.0, "disposition": "neutral", "levels": [1, 3], "drops": "boar"}
        row.update(fields)
        d.append(row)
    return change


def _mutations():
    """(name, file, mutate(data), expected code). Each runs on a fresh copy of
    samples/valid; the expected code must appear."""
    Q = "zones/elandor_dawnmere_fields.quests.json"
    S = "zones/elandor_dawnmere_fields.spawns.json"

    def quest(data, qid):
        return next(q for q in data["quests"] if q["id"] == qid)

    def belt(data, bid):
        return next(b for b in data["recipe"]["belts"] if b["id"] == bid)

    def add_giver(d):
        d["hubs"][0]["givers"].append({"npc": "r14_human_steward", "lines": ["extra"]})

    def three_lines(d):
        d["hubs"][0]["givers"][0]["lines"].append("third")

    def critter_target(d):
        quest(d, "sample_hunt_01")["objectives"][0] = {"type": "kill", "roles": ["wild_turkey"], "count": 5}

    def base_role_only(d):
        quest(d, "sample_hunt_01")["objectives"][0] = {"type": "kill", "roles": ["fox"], "count": 3}

    def wrong_area_role(d):
        quest(d, "sample_hunt_02")["objectives"][0]["area"] = "elandor_dawnmere_fields/home_beach"

    def level_fit(d):
        quest(d, "sample_hunt_01")["level"] = 9
        quest(d, "sample_hunt_01")["min_level"] = 9

    def item_source_area(d):
        quest(d, "sample_pantry_01")["objectives"][0].update(
            {"roles": ["large_rat"], "area": "elandor_dawnmere_fields/home_beach"})

    def item_source_no_roles(d):
        quest(d, "sample_pantry_01")["objectives"][0]["area"] = "elandor_dawnmere_fields/home_fields"

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

    def shares(d):
        belt(d, "l9_10")["share"] = 25

    def no_open(d):
        kinds = belt(d, "l3_5")["kinds"]
        kinds["forest"] = kinds.pop("open")
        kinds["forest"]["day"] = [{"role": "small_boar", "weight": 1}]

    def open_in_open(d):
        belt(d, "l1_3")["kinds"]["open"]["night"] = "open"

    def missing_night(d):
        del belt(d, "l1_3")["kinds"]["open"]["night"]

    def big_minor(d):
        belt(d, "l3_5")["kinds"]["open"]["day"][1]["weight"] = 2

    def three_roles(d):
        belt(d, "l3_5")["kinds"]["open"]["day"].append({"role": "large_rat", "weight": 1})

    def twice_role(d):
        belt(d, "l3_5")["kinds"]["open"]["day"][1]["role"] = "small_boar"

    def no_level_overlap(d):
        belt(d, "l9_10")["kinds"]["open"]["day"] = [{"role": "small_boar", "weight": 1}]

    def outside_band(d):
        belt(d, "l9_10")["levels"] = [9, 12]

    def cover_gap(d):
        belt(d, "l3_5")["kinds"]["open"]["day"] = [{"role": "small_boar", "weight": 1}]

    def camp_below_top(d):
        d["recipe"]["camps"][0]["belt"] = "l3_5"
        d["recipe"]["camps"][0]["roster"] = [{"role": "small_boar", "weight": 1}]

    def last_belt_below_band(d):
        belt(d, "l9_10")["levels"] = [9, 9]

    def bad_belt_levels(d):
        belt(d, "l9_10")["levels"] = [10, 9]

    def unknown_role(d):
        belt(d, "l1_3")["kinds"]["open"]["night"] = [{"role": "giant_squirrel", "weight": 1}]

    def unknown_leader_role(d):
        d["recipe"]["leaders"][0]["role"] = "nobody_chief"

    def leader_flag(d):
        d["recipe"]["leaders"][0]["role"] = "confused_bandit"

    def leader_twice(d):
        d["recipe"]["leaders"].append(dict(d["recipe"]["leaders"][0]))

    def leader_camp_ref(d):
        d["recipe"]["leaders"][0]["at"] = {"camp": "nowhere_camp"}

    def leader_kind_ref(d):
        d["recipe"]["leaders"][0]["at"] = {"kind": "nowhere_kind", "pick": "farthest_from_roads"}

    def leader_kind_names_camp(d):
        d["recipe"]["leaders"][0]["at"] = {"kind": "border_bandits", "pick": "farthest_from_roads"}

    def leader_pick(d):
        d["recipe"]["leaders"][0]["at"] = {"kind": "borderlands", "pick": "random"}

    def leader_at_kind(d):
        d["recipe"]["leaders"][0]["at"] = {"kind": "borderlands", "pick": "farthest_from_roads"}

    def camp_belt_ref(d):
        d["recipe"]["camps"][0]["belt"] = "l20"

    def camp_numbers(d):
        d["recipe"]["camps"][0]["respawn"] = [60, 30]

    def duplicate_unit(d):
        d["recipe"]["camps"][0]["id"] = "borderlands"

    def duplicate_belt(d):
        belt(d, "l3_5")["id"] = "l1_3"

    def bad_density(d):
        belt(d, "l1_3")["kinds"]["open"]["density"] = "crowded"

    def bad_type(d):
        belt(d, "l1_3")["kinds"]["desert"] = dict(belt(d, "l1_3")["kinds"]["open"], id="dunes", day="open")

    def kind_key(d):
        belt(d, "l1_3")["kinds"]["open"]["levels"] = [1, 3]

    def file_key(d):
        d["areas"] = []

    def recipe_key(d):
        d["recipe"]["fallback"] = True

    def no_recipe(d):
        del d["recipe"]

    def bad_anchor(d):
        d["recipe"]["from"]["anchor"] = "nowhere"

    def settlement_anchor(d):
        d["recipe"]["from"]["anchor"] = "dawnmere"

    def anchor_id(d):
        d["recipe"]["from"]["anchor"] = "anchor_002"

    def own_border(d):
        d["recipe"]["to"]["border"] = "elandor_dawnmere_fields"

    def unknown_border(d):
        d["recipe"]["to"]["border"] = ["elandor_goldmead_vale", "elandor_nowhere"]

    def far_border(d):
        d["recipe"]["to"]["border"] = ["elandor_highcourt"]

    def critter_list(d):
        d["recipe"]["critters"].append("small_boar")

    def from_border_core(d):
        d["recipe"]["from"] = {"border": "elandor_goldmead_vale"}
        d["recipe"]["to"] = {"core": True}

    def from_anchor_list(d):
        d["recipe"]["from"] = {"anchor": ["start", "anchor_002"]}

    def from_anchor_and_border(d):
        # A capital's entry (Round 28 W1): the city and a border, both sources.
        d["recipe"]["from"] = {"anchor": "start", "border": "elandor_goldmead_vale"}
        d["recipe"]["to"] = {"core": True}

    def from_anchor_and_exit_border(d):
        d["recipe"]["from"] = {"anchor": "start", "border": "elandor_goldmead_vale"}

    def from_anchor_and_unknown_border(d):
        d["recipe"]["from"] = {"anchor": "start", "border": "elandor_nowhere"}

    def from_empty(d):
        d["recipe"]["from"] = {}

    def from_border_unknown(d):
        d["recipe"]["from"] = {"border": "elandor_nowhere"}
        d["recipe"]["to"] = {"core": True}

    def entry_is_exit(d):
        d["recipe"]["from"] = {"border": "elandor_goldmead_vale"}

    def core_not_true(d):
        d["recipe"]["to"] = {"core": 1}

    def no_to_three_belts(d):
        del d["recipe"]["to"]

    def camp_on_missing_poi(d):
        d["recipe"]["camps"][0]["site"] = {"poi": "bandit"}
        del d["recipe"]["camps"][0]["apart"]

    def camp_on_guard_post(d):
        d["recipe"]["camps"][0]["site"] = {"poi": "guard post"}
        del d["recipe"]["camps"][0]["apart"]

    def critter_in_roster(d):
        belt(d, "l3_5")["kinds"]["shore"]["day"] = [{"role": "rabbit", "weight": 1}]

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

    def text_set(qid, key, value):
        def change(d):
            quest(d, qid)[key] = value
        return change

    return [
        ("placeholder: unknown kind", Q, text_set("sample_hunt_01", "text", "Go {where:home_fields}. Now."),
         "E-placeholder"),
        ("placeholder: unmatched brace", Q, text_set("sample_hunt_01", "text", "Go {name:home_fields. Now."),
         "E-placeholder"),
        ("placeholder: wrong argument count", Q, text_set("sample_hunt_01", "text", "Go {dir_of:meadows}. Now."),
         "E-placeholder"),
        ("placeholder: direction in a title", Q, text_set("sample_hunt_01", "title", "Crops {zone_area:meadows}"),
         "E-placeholder"),
        ("placeholder: unknown target", Q, text_set("sample_hunt_01", "text", "Go {zone_area:castle}. Now."),
         "E-placeholder-target"),
        ("placeholder: target in another zone", Q,
         text_set("sample_hunt_01", "text", "Go {zone_area:elandor_goldmead_vale/meadows}. Now."), "E-placeholder-target"),
        ("placeholder: unknown name in a title", Q, text_set("sample_hunt_01", "title", "The {name:castle}"),
         "E-placeholder-target"),
        ("placeholder: unknown place (atlas)", Q,
         text_set("sample_hunt_01", "text", "Go {dir_of:rivendell:meadows}. Now."), "E-placeholder-place"),
        ("placeholder: from here on an open kind", Q,
         text_set("sample_hunt_01", "text", "Go {dir_from_giver:meadows}. Now."), "W-placeholder-spread"),
        ("compass word in a text", Q, text_set("sample_hunt_01", "text", "Boars come from the south-east. Stop them."),
         "E-compass"),
        ("compass word in a title", Q, text_set("sample_hunt_01", "title", "Eastern Fields"), "E-compass"),
        ("compass word -bound", Q, text_set("sample_hunt_01", "text", "Take the northbound road. Hurry."),
         "E-compass"),
        ("three givers in a hub", Q, add_giver, "E-givers"),
        ("three lines for a giver", Q, three_lines, "E-lines"),
        ("critter kill target", Q, critter_target, "E-critter-target"),
        ("kill target the recipe zone never spawns", Q, base_role_only, "W-recipe-target"),
        ("target not in area", Q, wrong_area_role, "E-role-not-in-area"),
        ("target levels do not fit quest level", Q, level_fit, "E-level-fit"),
        ("item source not in its area", Q, item_source_area, "E-role-not-in-area"),
        ("item source area without roles", Q, item_source_no_roles, "E-area"),
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
        ("belt shares do not add up to 100", S, shares, "E-recipe-shares"),
        ("belt without kinds.open", S, no_open, "E-recipe-open"),
        ("\"open\" in the open kind", S, open_in_open, "E-recipe-open"),
        ("kind without a night roster", S, missing_night, "E-recipe-roster"),
        ("minor role above 25 %", S, big_minor, "E-recipe-roster"),
        ("three roles in a roster", S, three_roles, "E-recipe-roster"),
        ("role twice in a roster", S, twice_role, "E-recipe-roster"),
        ("role levels never meet the belt", S, no_level_overlap, "E-recipe-levels"),
        ("belt levels leave the zone band (atlas)", S, outside_band, "E-recipe-levels"),
        ("a kind's roster leaves part of its belt uncovered", S, cover_gap, "E-recipe-cover"),
        ("a camp's roster stops below its belt's top", S, camp_below_top, "E-recipe-cover"),
        ("the last belt ends below the zone band's top (atlas)", S, last_belt_below_band, "E-recipe-cover"),
        ("belt levels not a range", S, bad_belt_levels, "E-recipe-levels"),
        ("unknown roster role", S, unknown_role, "E-unknown-role"),
        ("unknown leader role", S, unknown_leader_role, "E-unknown-role"),
        ("leader role not flagged a leader", S, leader_flag, "E-leader-flag"),
        ("leader placed twice", S, leader_twice, "E-duplicate"),
        ("leader at an unknown camp", S, leader_camp_ref, "E-recipe-ref"),
        ("leader at an unknown kind", S, leader_kind_ref, "E-recipe-ref"),
        ("leader kind names a camp", S, leader_kind_names_camp, "E-recipe-ref"),
        ("leader with an unknown pick", S, leader_pick, "E-recipe-ref"),
        ("leader deep in a kind", S, leader_at_kind, None),
        ("camp on an unknown belt", S, camp_belt_ref, "E-recipe-ref"),
        ("camp respawn not [min, max]", S, camp_numbers, "E-recipe"),
        ("camp id equals a kind id", S, duplicate_unit, "E-duplicate"),
        ("belt id used twice", S, duplicate_belt, "E-duplicate"),
        ("unknown density", S, bad_density, "E-enum"),
        ("kinds key not a terrain type", S, bad_type, "E-recipe-key"),
        ("unknown field in a kind", S, kind_key, "E-recipe-key"),
        ("old area list in the file", S, file_key, "E-recipe-key"),
        ("unknown field in the recipe", S, recipe_key, "E-recipe-key"),
        ("no recipe and no palette", S, no_recipe, "E-required"),
        ("from anchor not in zone (atlas)", S, bad_anchor, "E-unknown-anchor"),
        ("from anchor by settlement key (the game takes id or slot)", S, settlement_anchor, "E-unknown-anchor"),
        ("from anchor by anchor id", S, anchor_id, None),
        ("border is the zone itself", S, own_border, "E-recipe-ref"),
        ("border zone not in the atlas", S, unknown_border, "E-unknown-zone"),
        ("border zone not a neighbour (warning)", S, far_border, "W-border-neighbour"),
        ("non-critter in critters", S, critter_list, "E-critter"),
        ("from by border, to the core", S, from_border_core, None),
        ("from a list of anchors", S, from_anchor_list, None),
        ("from names an anchor and a border (both sources)", S, from_anchor_and_border, None),
        ("from anchor and border, the border is the exit", S, from_anchor_and_exit_border, "E-recipe-ref"),
        ("from anchor and a border not in the atlas", S, from_anchor_and_unknown_border, "E-unknown-zone"),
        ("from names neither an anchor nor a border", S, from_empty, "E-recipe"),
        ("from border zone not in the atlas", S, from_border_unknown, "E-unknown-zone"),
        ("entry border is the exit border", S, entry_is_exit, "E-recipe-ref"),
        ("to core not true", S, core_not_true, "E-recipe"),
        ("three belts without to", S, no_to_three_belts, "E-recipe"),
        ("camp on a POI type the zone lacks (atlas)", S, camp_on_missing_poi, "E-recipe-poi"),
        ("camp on a guard post", S, camp_on_guard_post, "E-recipe-poi"),
        ("critter in a roster", S, critter_in_roster, "W-critter-area"),
        ("sub-type size", "catalog/subtypes.json", size, "E-size"),
        ("role collides with existing entity", "catalog/subtypes.json", collides, "E-role-collides"),
        ("three signature items in a band", "catalog/drops.json", three_signatures, "E-signature-limit"),
        ("iron bar in band 1", "catalog/drops.json", iron_in_band1, "E-metal-tier"),
        ("enchant loot not a signature drop", "catalog/enchants.json", enchant_generic, "E-enchant-loot"),
        ("unknown stat", "catalog/enchants.json", bad_stat, "E-stat"),
        ("sub-type turns a critter base neutral", "catalog/subtypes.json",
         _add_subtype(role="big_rabbit", base="grug_mobs:rabbit"), "E-critter-base"),
        ("critter sub-type of a critter base", "catalog/subtypes.json",
         _add_subtype(role="fat_rabbit", base="grug_mobs:rabbit", disposition="critter"), "!E-critter-base"),
        ("aggressive role on a base without attack_type", "catalog/subtypes.json",
         _add_subtype(role="angry_dummy", base="grug_mobs:training_dummy", disposition="aggressive"), "E-attack-type"),
        ("travel into another race's 11-20 zone", Q, other_race_home, "E-race-track"),
        ("kill area in another race's 11-20 zone", Q, other_race_area, "E-race-track"),
        ("travel into the other faction", Q, other_faction, "W-faction"),
        ("giver from another zone", Q, foreign_giver, "E-giver-zone"),
        ("stat loot not dropped in the track", "catalog/drops.json", no_tusk, "W-loot-track"),
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

    def contested(zone, npc, lines, anchor="outpost_1", level=31):
        def setup(target):
            _save(target / "zones" / ("%s.quests.json" % zone), {
                "zone": zone, "hubs": [{"id": "hub", "anchor": anchor,
                                        "givers": [{"npc": npc, "lines": lines}]}],
                "quests": [_simple_quest("sample_%s_01" % zone.split("_")[1], npc, lines[0], level)]})
        return setup

    def outposts(declared):
        def setup(target):
            zone = "elandor_ashenward_march"
            hubs = [{"id": "hub_%d" % i, "anchor": anchor, "givers": [{"npc": npc, "lines": ["watch", "front"]}]}
                    for i, (anchor, npc) in enumerate(declared)]
            _save(target / "zones" / ("%s.quests.json" % zone), {
                "zone": zone, "hubs": hubs,
                "quests": [_simple_quest("sample_ashenward_%d" % i, npc, "watch", 31)
                           for i, (_, npc) in enumerate(declared)]})
        return setup

    LORE = "r28_highcourt_lorekeeper"

    def new_giver(socket, npc=LORE):
        def setup(target):
            _save(target / "zones" / "elandor_highcourt.quests.json", {
                "zone": "elandor_highcourt",
                "hubs": [{"id": "court", "anchor": "capital", "givers": [
                    {"npc": npc, "new": {"name": "Odile Quill", "race": "human", "socket": socket},
                     "lines": ["lore", "front"]}]}],
                "quests": [_simple_quest("sample_highcourt_01", npc, "lore", 22)]})
            # The new NPC is a valid travel target anywhere in the design.
            data = _load(target / Q_FILE)
            for q in data["quests"]:
                if q["id"] == "sample_travel_01":
                    q["objectives"][0]["npc"] = q["turnin"] = npc
            _save(target / Q_FILE, data)
        return setup

    def goldmead_recipe(leaders):
        """A one-belt Goldmead (band 11-20) recipe; its only belt runs to L20."""
        return {"zone": "elandor_goldmead_vale", "recipe": {
            "from": {"anchor": "village_1"}, "to": {"border": "elandor_highcourt"},
            "belts": [{"id": "l11_20", "share": 100, "levels": [11, 20], "kinds": {
                "open": {"id": "vale", "name": "Goldmead Vale", "day": [{"role": "boar", "weight": 1}],
                         "night": [{"role": "bandit", "weight": 1}], "density": "normal"}}}],
            "leaders": leaders}}

    def leader_elsewhere(target, move_catalogue=True):
        """The bandit chief (levels 10-11) becomes Goldmead's leader at level
        11; Dawnmere's quest drop still names it (a zone-added role is usable
        from other zones)."""
        spawns_file = target / "zones" / "elandor_dawnmere_fields.spawns.json"
        spawns = _load(spawns_file)
        leader = spawns["recipe"].pop("leaders")[0]
        _save(spawns_file, spawns)
        leader["at"] = {"kind": "vale", "pick": "farthest_from_roads"}
        _save(target / "zones" / "elandor_goldmead_vale.spawns.json", goldmead_recipe([leader]))
        cat = target / "zones" / "elandor_dawnmere_fields.catalog.json"
        data = _load(cat)
        data["subtypes"][0]["levels"] = [10, 11]
        if move_catalogue:
            _save(target / "zones" / "elandor_goldmead_vale.catalog.json",
                  {"subtypes": data.pop("subtypes"), "items": []})
        _save(cat, data)

    def leader_in_two_zones(target):
        """Goldmead places Dawnmere's chief too."""
        leader_elsewhere(target, False)
        spawns_file = target / "zones" / "elandor_dawnmere_fields.spawns.json"
        spawns = _load(spawns_file)
        spawns["recipe"]["leaders"] = [{"role": "confused_bandit_chief", "at": {"camp": "border_bandits"},
                                        "respawn": 300}]
        _save(spawns_file, spawns)

    def kill_leader_elsewhere(target):
        """Dawnmere's hunt kills the chief, now Goldmead's leader, without an
        area (a front file's case): a leader of any zone counts as spawned."""
        leader_elsewhere(target)
        data = _load(target / Q_FILE)
        for q in data["quests"]:
            if q["id"] == "sample_hunt_04":
                q["objectives"].append({"type": "kill", "roles": ["confused_bandit_chief"], "count": 1})
        _save(target / Q_FILE, data)

    def kill_leader_elsewhere_filtered(target):
        """The same kill as a legacy objective with Dawnmere's zone filter:
        only kills in Dawnmere count, so Goldmead's chief is not met there."""
        leader_elsewhere(target)
        data = _load(target / Q_FILE)
        for q in data["quests"]:
            if q["id"] == "sample_hunt_04":
                q["objectives"].append({"type": "kill", "mobs": ["grug_mobs:confused_bandit_chief"],
                                        "zone": "elandor_dawnmere_fields", "count": 1})
        _save(target / Q_FILE, data)

    def goldmead_camps(camps, leaders=None, change=None):
        """Goldmead's one-belt recipe with camps (its atlas: one bandit camp
        POI, one guard post)."""
        def setup(target):
            data = goldmead_recipe(leaders or [])
            data["recipe"]["camps"] = camps
            if change:
                change(data["recipe"])
            _save(target / "zones" / "elandor_goldmead_vale.spawns.json", data)
        return setup

    def poi_camp(**fields):
        row = {"id": "vale_bandits", "name": "Goldmead Bandits", "site": {"poi": "bandit"},
               "belt": "l11_20", "roster": [{"role": "bandit", "weight": 1}], "slots": 5,
               "respawn": [30, 60], "min_player_distance": 16}
        row.update(fields)
        return {k: v for k, v in row.items() if v is not None}

    def no_from_to(recipe):
        del recipe["from"]
        del recipe["to"]

    def no_from(recipe):
        del recipe["from"]

    def palette_only(target):
        """A shipped file without a recipe: only today's palette."""
        _save(target / "zones" / "elandor_goldmead_vale.spawns.json",
              {"zone": "elandor_goldmead_vale", "palette": {"families": ["fox", "poacher"], "boar": "grug_mobs:boar"}})

    def zone_cat(change):
        def setup(target):
            path = target / "zones" / "elandor_dawnmere_fields.catalog.json"
            data = _load(path)
            change(data)
            _save(path, data)
        return setup

    def elite_chief(d):
        d["subtypes"][0]["tier"] = "elite"

    def non_leader_role(d):
        d["subtypes"].append({"role": "dawnmere_scarecrow", "family": "bandit", "base": "grug_mobs:bandit",
                              "display": "Scarecrow", "size": 1.0, "disposition": "aggressive",
                              "levels": [5, 5], "drops": "bandit"})

    def non_quest_item(d):
        d["items"].append({"id": "grug_mobs:scarecrow_hat", "name": "Scarecrow Hat", "tier": 1,
                           "kind": "signature", "description": "Straw.", "icon": "A straw hat."})

    def duplicate_role(d):
        dup = dict(d["subtypes"][0])
        dup["role"] = "small_boar"
        d["subtypes"].append(dup)

    def duplicate_item(d):
        dup = dict(d["items"][0])
        dup["id"] = "grug_mobs:rat_tail"
        d["items"].append(dup)


    def front_cycle(target):
        front_ok(target)
        path = target / "zones" / "elandor_dawnmere_fields.front.quests.json"
        data = _load(path)
        data["quests"][0]["requires"] = ["sample_front_01"]
        _save(path, data)

    def legacy_kill(target):
        data = _load(target / Q_FILE)
        for q in data["quests"]:
            if q["id"] == "sample_hunt_01":
                q["objectives"] = [{"type": "kill", "mobs": ["grug_mobs:small_boar"], "zone": False, "count": 3}]
        _save(target / Q_FILE, data)

    def guard_kill(field):
        def setup(target):
            data = _load(target / Q_FILE)
            for q in data["quests"]:
                if q["id"] == "sample_hunt_01":
                    q["objectives"] = [{"type": "kill", field: ["grug_mobs:guard_throng" if field == "mobs"
                                                                else "guard_throng"], "count": 3}]
            _save(target / Q_FILE, data)
        return setup

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
        ("capital without a front giver", contested("elandor_highcourt", "r20_human_capital_envoy", ["civic"],
                                                    "capital", 22), False, "E-front-reserve"),
        ("capital with a front giver", contested("elandor_highcourt", "r20_human_capital_envoy",
                                                 ["civic", "front"], "capital", 22), False, "!E-front-reserve"),
        ("both outpost givers declared with front", outposts([("outpost_1", "r20_anchor_031_host"),
                                                              ("outpost_2", "r20_anchor_032_host")]),
         False, "!E-front-reserve"),
        ("an outpost quest NPC not declared", outposts([("outpost_1", "r20_anchor_031_host")]), False,
         "E-front-reserve"),
        ("new giver at a free quest socket", new_giver("lore_shrine/lore_shrine_quest"), False, None),
        ("new giver at an occupied socket", new_giver("chapel_quest"), False, "E-new-giver"),
        ("new giver reusing a registered id", new_giver("lore_shrine/lore_shrine_quest",
                                                        "r20_human_capital_envoy"), False, "E-new-giver"),
        ("leader of another zone as a drop source", leader_elsewhere, False, "!W-role-not-in-zone"),
        ("zone-added leader placed in another zone", lambda t: leader_elsewhere(t, False), False,
         "E-zone-leader"),
        ("leader role in two zones' recipes", leader_in_two_zones, False, "E-duplicate"),
        ("kill of another zone's leader without an area", kill_leader_elsewhere, False, "!W-recipe-target"),
        ("zone-filtered kill of another zone's leader", kill_leader_elsewhere_filtered, True, "W-recipe-target"),
        ("a palette-only spawns file (shipped form)", palette_only, False, None),
        ("camp on the zone's bandit POI", goldmead_camps([poi_camp()]), False, None),
        ("camp on a POI named by its name", goldmead_camps([poi_camp(
            site={"poi": "bandit", "name": "Goldmead Bandit Camp"})]), False, None),
        ("camp on a POI without a belt", goldmead_camps([poi_camp(belt=None)]), False, "E-recipe-ref"),
        ("camp on a POI whose roster never meets its stated belt", goldmead_camps([poi_camp(
            roster=[{"role": "confused_bandit", "weight": 1}])]), False, "E-recipe-levels"),
        ("camp on a POI name the zone lacks", goldmead_camps([poi_camp(
            site={"poi": "bandit", "name": "Nowhere Camp"})]), False, "E-recipe-poi"),
        ("camp on the zone's guard post", goldmead_camps([poi_camp(site={"poi": "guard post"})]), False,
         "E-recipe-poi"),
        ("apart on a camp on a POI", goldmead_camps([poi_camp(apart=8)]), False, "E-recipe-key"),
        ("two camps on one POI", goldmead_camps([poi_camp(), poi_camp(id="more_bandits")]), False,
         "E-recipe-poi"),
        ("generated camp without a belt", goldmead_camps([poi_camp(site="generate", apart=8, belt=None)]),
         False, "E-recipe-ref"),
        ("one-belt recipe without from and to", goldmead_camps([], change=no_from_to), False, None),
        ("to without from", goldmead_camps([], change=no_from), False, "E-recipe"),
        ("elite leader below level 31", zone_cat(elite_chief), False, "E-leader-tier"),
        ("zone catalogue adds a non-leader role", zone_cat(non_leader_role), False, "E-zone-catalog"),
        ("zone catalogue adds a non-quest item", zone_cat(non_quest_item), False, "E-zone-catalog"),
        ("zone catalogue role collides with the global one", zone_cat(duplicate_role), False, "E-duplicate"),
        ("zone catalogue item collides with the global one", zone_cat(duplicate_item), False, "E-duplicate"),
        ("prerequisite cycle in a front file", front_cycle, False, "E-cycle"),
        ("legacy kill objective with mobs", legacy_kill, True, None),
        ("legacy kill objective without --legacy", legacy_kill, False, "E-legacy"),
        ("legacy enemy guard kill (split of today's quests)", guard_kill("mobs"), True, "!E-not-a-mob"),
        ("legacy guard kill in a recipe zone: guards are no recipe spawn", guard_kill("mobs"), True,
         "!W-recipe-target"),
        ("guard as a designed kill role", guard_kill("roles"), True, "E-not-a-mob"),
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
    mobs = here / "samples" / "mobs_min.json"
    findings = validate(valid, existing, atlas, mobs_path=mobs)
    # Only Dawnmere is designed: the other race tracks' T1 loot is unchecked.
    if findings.errors() or findings.codes() != {"W-loot-unchecked"}:
        print_findings(findings, valid)
        failures.append("the valid sample gives exactly W-loot-unchecked with the atlas")
    no_atlas = validate(valid, existing, None, mobs_path=mobs)
    if no_atlas.errors() or no_atlas.codes() != {"W-no-atlas"}:
        print_findings(no_atlas, valid)
        failures.append("without an atlas the valid sample gives exactly W-no-atlas")
    # Compass words: whole words in any case and hyphenation; names that
    # only contain one pass (the game's placeholders.compass_words).
    got = compass_words("Head north, then South-East, the southeastern ford, Westward; {zone_area:west}.")
    if got != ["north", "South", "East", "southeastern", "Westward"]:
        failures.append("compass words: %s" % got)
    got = compass_words("the northbound road, the southernmost farm, Easterners, a westerner, Northmost")
    if got != ["northbound", "southernmost", "Easterners", "westerner", "Northmost"]:
        failures.append("compass words -bound, -most, -erner(s): %s" % got)
    got = compass_words("Northfold, Westbrook, Eastmarch, Southwatch, beast, Easter, Westerling")
    if got:
        failures.append("names that only contain a compass word pass: %s" % got)
    found, errors = scan_placeholders("{dir_of:highcourt:elandor_lorindor/woods} and {name:chief}, {x}")
    if [f[0] for f in found] != ["dir_of", "name"] or len(errors) != 1:
        failures.append("placeholder scan: %s %s" % (found, errors))
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
            _expect(name, validate(target, existing, atlas, legacy, mobs_path=mobs), code, failures)
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

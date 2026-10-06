#!/usr/bin/env python3
"""Round 38 lane I: the inventory of every mob name slot.

A *slot* is one name a player can see on a mob, today and after the round:
per zone one slot for every (sub-type role, level band) its spawn recipe
produces (kinds, camps, leaders), the recipe's critters and Rift Spawn rows,
and every other place that names a mob (rares, kings and royal guards,
dragons and whelps, the rift boss, the undead king's summons, PvP
garrisons, settlement and outpost guards, the underground casts, the water
mobs, registered sub-types nothing places). Every value is read from the
shipped data and code; README.md (written next to the outputs) lists each
source with file:line.

    python3 tools/r38_names/inventory.py [--out DIR] [--repo REPO]
    python3 tools/r38_names/inventory.py --check [--out DIR]   # stale? exit 1

As a module (later lanes reuse the model instead of a second loader):

    import inventory
    model = inventory.build()            # or build(repo_path)
    model.slots                          # list of slot dicts, sorted by key
    model.slot_by_key["kragmar_stillgrave_hollow/small_boar/L1-2"]
    model.objectives                     # quest objectives aimed at mobs
    model.drop_tier(27)                  # 3

Python 3 standard library only; deterministic output (sorted keys, no
timestamps).
"""
import argparse
import filecmp
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_OUT = Path(os.path.expanduser("~/projects/grudgelands-orchestration/r38/inventory"))
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

MOBS = "mods/ENTITIES/grug_mobs"
SUBTYPES = MOBS + "/data/subtypes.json"
RECIPES = MOBS + "/data/zones"
PVP_NAMES = MOBS + "/data/pvp_names.json"
QUESTS = "mods/PLAYER/grug_quests/data/zones"
SIMPLE_MAP = "mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua"
POI_CATALOG = "mods/MAPGEN/grug_mapgen/wp40/r20_poi_catalog.lua"
PVP_CATALOG = "mods/MAPGEN/grug_mapgen/wp40/r31_pvp_catalog.lua"
SIGNAL_SOURCE = "docs/planning/round28/mobs/names-proposal.json"
NEIGHBOURS = "tools/r38_names/neighbours.tsv"
SEEDS = ["42", "7", "2026", "1234", "99999", "314159"]

TIER_WORDS = {"normal": 2, "critter": 2, "guard": 2, "elite": 3, "named": 3, "boss": 3}
CONTINENT = {"elandor_mainland": "Elandor", "kragmar_mainland": "Kragmar",
             "holy_grounds": "Battlegrounds", "wyrmglass_island": "Island",
             "stormscale_island": "Island"}


# --- small helpers -----------------------------------------------------------

class Repo:
    """File access with file:line citations relative to the repository."""

    def __init__(self, root):
        self.root = Path(root).resolve()
        self._text = {}
        self.read_files = set()

    def text(self, rel):
        if rel not in self._text:
            self._text[rel] = (self.root / rel).read_text(encoding="utf-8")
            self.read_files.add(rel)
        return self._text[rel]

    def json(self, rel):
        return json.loads(self.text(rel))

    def line_of(self, rel, offset):
        return self.text(rel).count("\n", 0, offset) + 1

    def cite(self, rel, pattern, flags=0):
        """`rel:line` of the first match of `pattern` (a regex); fails loudly."""
        m = re.search(pattern, self.text(rel), flags)
        if not m:
            raise SystemExit("inventory: pattern %r not found in %s (the code moved; "
                             "update tools/r38_names/inventory.py)" % (pattern, rel))
        return "%s:%d" % (rel, self.line_of(rel, m.start()))

    def search(self, rel, pattern, flags=0):
        m = re.search(pattern, self.text(rel), flags)
        if not m:
            raise SystemExit("inventory: pattern %r not found in %s (the code moved; "
                             "update tools/r38_names/inventory.py)" % (pattern, rel))
        return m


def balanced(text, start):
    """The text from `start` (an opening bracket) to its matching close,
    skipping Lua strings and comments."""
    pairs = {"{": "}", "(": ")", "[": "]"}
    stack, i, n = [], start, len(text)
    while i < n:
        c = text[i]
        if c == "-" and text.startswith("--", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        if c in "\"'":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            i = j + 1
            continue
        if c in pairs:
            stack.append(pairs[c])
        elif stack and c == stack[-1]:
            stack.pop()
            if not stack:
                return text[start:i + 1]
        i += 1
    raise SystemExit("inventory: unbalanced bracket at %d" % start)


def drop_tier(level):
    """The drop tier of a mob level, exactly as the loot code derives it:
    grug_mobs.level_band (subtypes.lua: floor((L - 1) / 10) + 1, clamped to
    1..6) picks the family drop table, and grug_items.enchant_tier of
    min(L, 60) (grug_quality/init.lua: ceil(L / 10)) the gear pool; both
    give the same tier for every mob level 1..60 (and 6 above 60)."""
    return max(1, min(6, (int(level) - 1) // 10 + 1))


def tiers_of(lo, hi):
    return sorted({drop_tier(level) for level in range(lo, hi + 1)})


def depth_level(y):
    """wp40/zones.lua depth_level: the level of a depth (below y = 0)."""
    if y <= -992:
        return 60
    numerator = -3 * y
    base = numerator // 50
    remainder = numerator - base * 50
    value = base + 1 if remainder >= 25 else base
    return max(1, min(60, value))


def words(name):
    return name.split()


def tokens(name):
    return [t for t in re.split(r"[\s\-']+", name) if t]


def band_key(lo, hi):
    return "L%d-%d" % (lo, hi)


# --- the model ---------------------------------------------------------------

class Model:
    def __init__(self, repo):
        self.repo = Repo(repo)
        self.sources = []          # [{id, what, where}] every name source
        self.zones = {}            # zone id -> zone facts
        self.zone_order = []
        self.slots = []
        self.slot_by_key = {}
        self.objectives = []
        self.surfaces = []
        self.drop_tier = drop_tier
        self.tiers_of = tiers_of

    # sources ------------------------------------------------------------------
    def source(self, sid, what, where):
        self.sources.append({"id": sid, "what": what, "where": where})
        return sid

    # zones --------------------------------------------------------------------
    def load_zones(self):
        r = self.repo
        text = r.text(SIMPLE_MAP)
        pat = re.compile(r'zone\((\d+),"(\w+)","([^"]+)","(\w+)",(false|"\w+"),"(\w+)","(\w+)",'
                         r'(\d+),(\d+),"(\w+)",(-?\d+),(-?\d+),\{([^}]*)\}(,true)?\)')
        for m in pat.finditer(text):
            num = int(m.group(1))
            if num <= 16:
                macro = "elandor_mainland"
            elif num <= 32:
                macro = "kragmar_mainland"
            elif num == 33:
                macro = "wyrmglass_island"
            elif num <= 37:
                macro = "holy_grounds"
            else:
                macro = "stormscale_island"
            zid = m.group(2)
            lo, hi = int(m.group(8)), int(m.group(9))
            civic = bool(m.group(14))
            territory = m.group(6)
            if civic:
                role = "capital"
            elif lo == 1:
                role = "start"
            elif territory.endswith("_home"):
                role = "home %d-%d" % ((lo - 1) // 10 * 10 + 1, (lo - 1) // 10 * 10 + 10)
            elif macro in ("elandor_mainland", "kragmar_mainland"):
                role = "frontier %d-%d" % (lo, hi)
            elif macro == "holy_grounds":
                role = "battlegrounds %d-%d" % (lo, hi)
            else:
                role = "dragon island"
            self.zones[zid] = {
                "id": zid, "numeric_id": num, "name": m.group(3), "race_region": m.group(4),
                "faction": m.group(5).strip('"') if m.group(5) != "false" else None,
                "territory": territory, "pvp": m.group(7), "level_min": lo, "level_max": hi,
                "relief": m.group(10), "macro_region": macro, "continent": CONTINENT[macro],
                "role": role, "civic": civic,
                "biomes": [b.strip().strip('"') for b in m.group(13).split(",") if b.strip()],
                "record": "%s:%d" % (SIMPLE_MAP, r.line_of(SIMPLE_MAP, m.start())),
            }
            self.zone_order.append(zid)
        if len(self.zones) != 38:
            raise SystemExit("inventory: expected 38 zone records in %s, got %d" % (SIMPLE_MAP, len(self.zones)))
        self.source("zone_records", "zone level band, race region, macro region (continent)",
                    r.cite(SIMPLE_MAP, r"source\.zones = \{"))
        self.source("macro_region", "continent rule (numeric id -> macro region)",
                    r.cite(SIMPLE_MAP, r'macro_region = "elandor_mainland"'))
        # neighbours (seed-dependent, geometric)
        path = r.root / NEIGHBOURS
        if not path.exists():
            raise SystemExit("inventory: %s missing; rebuild it with "
                             "`luajit tools/r38_names/neighbours.lua . > %s`" % (NEIGHBOURS, NEIGHBOURS))
        per = defaultdict(dict)
        for line in path.read_text(encoding="utf-8").splitlines()[1:]:
            seed, zid, nbs = line.split("\t")
            per[zid][seed] = [n for n in nbs.split(",") if n]
        self.repo.read_files.add(NEIGHBOURS)
        for zid, z in self.zones.items():
            seeds = per.get(zid, {})
            if sorted(seeds) != sorted(SEEDS):
                raise SystemExit("inventory: %s lacks seeds for %s" % (NEIGHBOURS, zid))
            sets = [set(v) for v in seeds.values()]
            always = set.intersection(*sets)
            some = set.union(*sets) - always
            z["neighbours"] = sorted(always, key=self.zone_order.index)
            z["neighbours_some_seeds"] = sorted(some, key=self.zone_order.index)
        self.source("neighbours", "zone neighbours on six seeds (geometric, simple_map.lua neighbor_min_border)",
                    NEIGHBOURS + " (tools/r38_names/neighbours.lua)")

    # data ---------------------------------------------------------------------
    def load_data(self):
        r = self.repo
        self.subtypes = {s["role"]: s for s in r.json(SUBTYPES)}
        self.sub_line = {}
        text = r.text(SUBTYPES)
        for role in self.subtypes:
            m = re.search(r'"role":\s*"%s"' % re.escape(role), text)
            self.sub_line[role] = "%s:%d" % (SUBTYPES, r.line_of(SUBTYPES, m.start()))
        self.recipes = {}
        for zid in self.zone_order:
            rel = "%s/%s.spawns.json" % (RECIPES, zid)
            data = r.json(rel)
            if "recipe" not in data:
                raise SystemExit("inventory: %s has no recipe" % rel)
            self.recipes[zid] = data["recipe"]
        prop = r.json(SIGNAL_SOURCE)
        self.signal = {}
        for kind, ws in prop["signal_words"].items():
            for w in ws:
                self.signal[w.lower()] = kind
        self.source("signal_words", "signal words (size, age, strength, temperament, wits, condition)",
                    r.cite(SIGNAL_SOURCE, r'"signal_words"') + "; rule text docs/design/biomes_mobs.md:" +
                    str(r.line_of("docs/design/biomes_mobs.md",
                                  r.text("docs/design/biomes_mobs.md").index("**Names (user, 2026-10-02):**"))))
        # dispositions
        disp = {}
        dtext = r.text(MOBS + "/disposition.lua")
        for m in re.finditer(r'classify\("(\w+)",\s*\{([^}]*)\}', dtext):
            for name in re.findall(r'"(\w+)"', m.group(2)):
                disp[name] = m.group(1)
        self.base_disposition = disp
        self.pvp_names = r.json(PVP_NAMES)
        self.mob_files = sorted(p.name for p in (r.root / MOBS).glob("*.lua"))

    # drop tier / level rule citations ------------------------------------------
    def cite_rules(self):
        r = self.repo
        self.source("drop_tier", "drop tier of a mob level (family drop table band)",
                    r.cite(MOBS + "/subtypes.lua", r"function grug_mobs\.level_band"))
        self.source("drop_tier_gear", "gear pool tier of a mob level (same tiers 1..60)",
                    r.cite("mods/ITEMS/grug_quality/init.lua", r"function grug_items\.enchant_tier") + ", used at " +
                    r.cite("mods/ITEMS/grug_quality/init.lua", r"grug_gear\.drop_pool\[grug_items\.enchant_tier"))
        self.source("level_rule", "a region spawn's level: random in belt range x role range",
                    r.cite(MOBS + "/spawn_regions_core.lua", r"local function role_range") + ", " +
                    r.cite(MOBS + "/spawn_regions.lua", r"grug_mobs\.relevel\(ent, math\.random\(range"))
        self.source("leader_level", "a leader's fixed level: top of role range x its belt",
                    r.cite(MOBS + "/spawn_regions_core.lua", r"leader\.level = range\[2\]"))
        self.source("region_level", "region level (overlay) = middle of its belt; mobs without a spawn level",
                    r.cite(MOBS + "/spawn_regions_core.lua", r"r\.level = floor\(\(levels\[1\] \+ levels\[2\]\) / 2 \+ 0\.5\)") +
                    ", " + r.cite("mods/CORE/grug_core/zone_authority.lua", r"function grug_core\.mob_level_at"))
        self.source("depth_level", "underground level = max(surface field, depth level)",
                    r.cite("mods/MAPGEN/grug_mapgen/wp40/zones.lua", r"local function depth_level") + ", " +
                    r.cite("mods/MAPGEN/grug_mapgen/wp40/zones.lua", r"function session\.mob_level_at"))
        self.source("level_resolve", "level resolution order (critter 1, spawn level, fixed, field, def clamp)",
                    r.cite(MOBS + "/levels.lua", r"local function resolve_level"))
        self.source("tag_text", "the nametag: tier prefix + description + [Lv n] + HP",
                    r.cite(MOBS + "/levels.lua", r"function grug_mobs\.tag_text"))
        self.source("tier_prefix", "tier prefixes 'Elite ', star (rare), 'Boss '",
                    r.cite(MOBS + "/levels.lua", r"local TIERS = \{"))

    # base entity facts ---------------------------------------------------------
    def entity_def(self, entity):
        """(file, def text, name, name citation) of a grug_mobs base entity,
        read from its register_mob call."""
        r = self.repo
        pat = re.compile(r'register_mob\(\s*"grug_mobs:%s"\s*,\s*' % re.escape(entity))
        for fname in self.mob_files:
            rel = MOBS + "/" + fname
            text = r.text(rel)
            m = None
            for cand in pat.finditer(text):
                if "--" not in text[text.rfind("\n", 0, cand.start()) + 1:cand.start()]:
                    m = cand
                    break
            if not m:
                continue
            rest = text[m.end():]
            pos = m.end()
            lit = re.match(r'[\w.]+\(\s*"([^"]+)"', rest)
            if rest.startswith("{"):
                body = balanced(text, pos)
                d = re.search(r'description\s*=\s*"([^"]+)"', body)
                return rel, body, d.group(1), "%s:%d" % (rel, r.line_of(rel, pos + d.start()))
            if lit:
                func = re.match(r"([\w.]+)\(", rest).group(1)
                body = balanced(text, pos + rest.index("("))
                fm = re.search(r"local function %s\(" % re.escape(func.split(".")[-1]), text)
                fbody = text[fm.start():fm.start() + 4000] if fm else ""
                return rel, body + "\n" + fbody, lit.group(1), "%s:%d" % (rel, r.line_of(rel, pos))
            ident = re.match(r"(\w+)\s*\)", rest)
            if ident:
                var = ident.group(1)
                vm = None
                for vm in re.finditer(r"local %s\s*=\s*" % re.escape(var), text[:pos]):
                    pass
                if not vm:
                    raise SystemExit("inventory: no `local %s =` for %s in %s" % (var, entity, rel))
                after = text[vm.end():]
                call = re.match(r'([\w.]+)\(\s*"([^"]+)"', after)
                if call:
                    body = balanced(text, vm.end() + after.index("("))
                    fm = re.search(r"local function %s\(" % re.escape(call.group(1).split(".")[-1]), text)
                    fbody = text[fm.start():fm.start() + 4000] if fm else ""
                    return rel, body + "\n" + fbody, call.group(2), "%s:%d" % (rel, r.line_of(rel, vm.start()))
                brace = vm.end() + after.index("{")
                body = balanced(text, brace)
                d = re.search(r'description\s*=\s*"([^"]+)"', body)
                if not d:
                    raise SystemExit("inventory: no description for %s in %s" % (entity, rel))
                return rel, body, d.group(1), "%s:%d" % (rel, r.line_of(rel, brace + d.start()))
            raise SystemExit("inventory: cannot read the register_mob call of %s in %s" % (entity, rel))
        raise SystemExit("inventory: no register_mob for grug_mobs:%s" % entity)

    def base_facts(self, entity):
        rel, body, name, where = self.entity_def(entity)
        tier = re.search(r'_grug_tier\s*=\s*"(\w+)"', body)
        fixed = re.search(r"_grug_fixed_level\s*=\s*(\d+)", body)
        lmin = re.search(r"_grug_min_level\s*=\s*(\d+)", body)
        clock = re.search(r'clock\s*=\s*"(\w+)"', body)
        disp = self.base_disposition.get(entity)
        tier = tier.group(1) if tier else ("critter" if disp == "critter" else "normal")
        return {"file": rel, "name": name, "where": where, "tier": tier,
                "fixed": int(fixed.group(1)) if fixed else None,
                "min": int(lmin.group(1)) if lmin else 1,
                "clock": clock.group(1) if clock else "any", "disposition": disp}

    def spawn_rows(self):
        """Every mobs:spawn row of grug_mobs: entity -> [(min_height, max_height, where)]."""
        r = self.repo
        rows = defaultdict(list)
        for fname in self.mob_files:
            rel = MOBS + "/" + fname
            text = r.text(rel)
            for m in re.finditer(r"mobs:spawn\(", text):
                block = balanced(text, m.end() - 1)
                lo = re.search(r"min_height\s*=\s*(-?\d+)", block)
                hi = re.search(r"max_height\s*=\s*(-?\d+)", block)
                if not lo or not hi:
                    continue
                names = re.findall(r'name\s*=\s*"grug_mobs:(\w+)"', block)
                if not names and re.search(r'"grug_mobs:"\s*\.\.\s*row\.name', block):
                    loop = None
                    for loop in re.finditer(r"for _, row in ipairs\(\{", text[:m.start()]):
                        pass
                    names = re.findall(r'name\s*=\s*"(\w+)"', balanced(text, loop.end() - 1))
                for name in names:
                    rows[name].append((int(lo.group(1)), int(hi.group(1)),
                                       "%s:%d" % (rel, r.line_of(rel, m.start()))))
        return rows

    # slots ----------------------------------------------------------------------
    def add_slot(self, slot):
        key = slot["key"]
        if key in self.slot_by_key:
            raise SystemExit("inventory: duplicate slot key %s" % key)
        lo, hi = slot["levels"]
        slot["drop_tiers"] = tiers_of(lo, hi)
        name = slot["name"]
        slot["words"] = len(words(name))
        slot["signal_words"] = [t for t in tokens(name) if t.lower() in self.signal]
        zone = self.zones.get(slot["zone"]) if slot["zone"] else None
        slot["race_region"] = zone["race_region"] if zone else None
        slot["continent"] = zone["continent"] if zone else None
        slot["zone_name"] = zone["name"] if zone else None
        slot["zone_role"] = zone["role"] if zone else None
        slot["zone_band"] = [zone["level_min"], zone["level_max"]] if zone else None
        slot["neighbours"] = zone["neighbours"] if zone else []
        slot["neighbours_some_seeds"] = zone["neighbours_some_seeds"] if zone else []
        slot.setdefault("units", [])
        slot.setdefault("notes", [])
        slot.setdefault("tags", [])
        slot["quest_targets"] = []
        slot["quest_mentions"] = []
        self.slot_by_key[key] = slot
        self.slots.append(slot)
        return slot

    def sub_fields(self, role, zone):
        sub = self.subtypes[role]
        by_zone = sub.get("display_by_zone") or {}
        if zone in by_zone:
            name, src = by_zone[zone], "subtypes.json display_by_zone"
        else:
            name, src = sub["display"], "subtypes.json display"
        leader = bool(sub.get("leader"))
        tier = "named" if leader else ("elite" if sub["tier"] == "elite" else "normal")
        return {"name": name, "name_source": src, "name_where": self.sub_line[role],
                "entity": "grug_mobs:" + role, "role": role, "family": sub["family"],
                "base": sub["base"], "tier": tier, "authored_tier": sub["tier"], "leader": leader,
                "disposition": sub["disposition"],
                "size": 1.15 if leader else sub["size"], "drops": sub.get("drops") or sub["family"],
                "role_levels": list(sub["levels"])}

    def build_recipe_slots(self):
        r = self.repo
        self.source("recipe_kinds", "surface roles per belt, terrain kind and clock (`open` inheritance)",
                    r.cite(MOBS + "/spawn_regions_core.lua", r"function M\.parse_recipe") + "; data " + RECIPES + "/<zone>.spawns.json")
        self.source("recipe_camps", "camp rosters (camp belt x role range), members tagged with the camp",
                    r.cite(MOBS + "/camps.lua", r"function grug_mobs\.region_camp_tick"))
        self.source("recipe_leaders", "named leaders at a camp or kind, fixed level, no area tag",
                    r.cite(MOBS + "/spawn_regions.lua", r"-- Leaders \(ruling 38\)"))
        self.source("zone_display", "zone display name of a sub-type (display_by_zone, read at first activation)",
                    r.cite(MOBS + "/subtypes.lua", r"local function apply_zone_variant"))
        self.source("subtype_registration", "sub-type description = display",
                    r.cite(MOBS + "/subtypes.lua", r"def\.description = sub\.display"))
        self.source("critters", "a recipe zone keeps its critter ABM rows (critter tier: level 1)",
                    r.cite(MOBS + "/spawn_policy.lua", r"zone_critter\(zone_id, mob_name\)"))
        for zid in self.zone_order:
            recipe = self.recipes[zid]
            groups = defaultdict(list)   # (role, lo, hi) -> units
            belts = recipe["belts"]
            for b in belts:
                kinds = b["kinds"]
                for t in ("open", "shore", "bank", "swamp", "forest", "highland"):
                    k = kinds.get(t)
                    if not k:
                        continue
                    per_role = defaultdict(set)
                    inherited = defaultdict(set)
                    for clock in ("day", "night"):
                        value = k[clock]
                        roster = kinds["open"][clock] if value == "open" else value
                        for e in roster:
                            per_role[e["role"]].add(clock)
                            if value == "open":
                                inherited[e["role"]].add(clock)
                    for role, clocks in per_role.items():
                        own = self.subtypes[role]["levels"]
                        lo, hi = max(b["levels"][0], own[0]), min(b["levels"][1], own[1])
                        groups[(role, lo, hi)].append({
                            "unit": "kind", "id": k["id"], "tag": zid + "/" + k["id"], "name": k["name"],
                            "type": t, "belt": b["id"], "belt_levels": list(b["levels"]),
                            "clocks": sorted(clocks), "inherited_clocks": sorted(inherited.get(role, ())),
                            "density": k["density"]})
            belt_by_id = {b["id"]: b for b in belts}
            for c in recipe.get("camps", []):
                b = belt_by_id[c["belt"]]
                for e in c["roster"]:
                    own = self.subtypes[e["role"]]["levels"]
                    lo, hi = max(b["levels"][0], own[0]), min(b["levels"][1], own[1])
                    site = c.get("site", "generate")
                    groups[(e["role"], lo, hi)].append({
                        "unit": "camp", "id": c["id"], "tag": zid + "/" + c["id"], "name": c["name"],
                        "type": "camp", "belt": c["belt"], "belt_levels": list(b["levels"]),
                        "clocks": ["day", "night"], "inherited_clocks": [],
                        "site": site if isinstance(site, str) else "poi:" + site.get("poi", ""),
                        "slots": c["slots"]})
            for (role, lo, hi), units in sorted(groups.items()):
                f = self.sub_fields(role, zid)
                clocks = sorted({c for u in units for c in u["clocks"]})
                slot = dict(f, key="%s/%s/%s" % (zid, role, band_key(lo, hi)), zone=zid,
                            source="recipe", levels=[lo, hi], clocks=clocks,
                            units=sorted(units, key=lambda u: (u["unit"], u["id"])),
                            tags=sorted({u["tag"] for u in units}))
                if f["leader"]:
                    slot["notes"] = ["leader role also spawned by a roster"]
                self.add_slot(slot)
            for lead in recipe.get("leaders", []):
                role = lead["role"]
                at = lead["at"]
                if "camp" in at:
                    c = next(c for c in recipe["camps"] if c["id"] == at["camp"])
                    b = belt_by_id[c["belt"]]
                    unit = {"unit": "leader", "id": at["camp"], "tag": None, "name": c["name"],
                            "type": "camp", "belt": c["belt"], "belt_levels": list(b["levels"]),
                            "clocks": ["day", "night"], "inherited_clocks": [], "respawn": lead["respawn"]}
                else:
                    b, k = None, None
                    for bb in belts:
                        for kk in bb["kinds"].values():
                            if kk["id"] == at["kind"]:
                                b, k = bb, kk
                    unit = {"unit": "leader", "id": at["kind"], "tag": None, "name": k["name"],
                            "type": "kind", "belt": b["id"], "belt_levels": list(b["levels"]),
                            "clocks": ["day", "night"], "inherited_clocks": [], "respawn": lead["respawn"]}
                own = self.subtypes[role]["levels"]
                level = min(b["levels"][1], own[1])
                f = self.sub_fields(role, zid)
                self.add_slot(dict(f, key="%s/%s/%s" % (zid, role, band_key(level, level)), zone=zid,
                                   source="leader", levels=[level, level], clocks=["any"], units=[unit],
                                   tags=[], notes=["named leader: rule-placed spot, fixed level, respawn %d s, "
                                                   "carries no area tag" % lead["respawn"]]))
            for critter in recipe.get("critters", []):
                bf = self.base_facts(critter)
                self.add_slot({"key": "%s/%s/L1-1" % (zid, critter), "zone": zid, "source": "critter",
                               "name": bf["name"], "name_source": "entity description",
                               "name_where": bf["where"], "entity": "grug_mobs:" + critter, "role": critter,
                               "family": critter, "base": "grug_mobs:" + critter, "tier": "critter",
                               "authored_tier": "critter", "leader": False, "disposition": "critter",
                               "size": 1.0, "drops": None, "role_levels": [1, 1], "levels": [1, 1],
                               "clocks": [bf["clock"]],
                               "notes": ["critter ABM row kept by the recipe; one name for every zone today "
                                         "(entity description, no per-zone name)"]})

    def belt_mids(self, zid):
        return sorted({(b["levels"][0] + b["levels"][1]) // 2 + ((b["levels"][0] + b["levels"][1]) % 2)
                       for b in self.recipes[zid]["belts"]})

    def build_special_slots(self):
        r = self.repo
        rows = self.spawn_rows()
        policy = MOBS + "/spawn_policy.lua"
        ptext = r.text(policy)

        # Rift Spawn surface rows (RECIPE_ZONE_ROWS) and its cave row.
        block = balanced(ptext, ptext.index("{", ptext.index("local RECIPE_ZONE_ROWS")))
        rift_zones = re.findall(r"(\w+)\s*=\s*true", re.search(r'"grug_mobs:rift_spawn"\]\s*=\s*(\{[^}]*\})', block).group(1))
        self.source("rift_spawn_rows", "Rift Spawn surface rows kept in four recipe zones (night, region level)",
                    r.cite(policy, r"local RECIPE_ZONE_ROWS"))
        bf = self.base_facts("rift_spawn")
        for zid in rift_zones:
            for level in self.belt_mids(zid):
                self.add_slot({"key": "%s/rift_spawn/L%d-%d" % (zid, level, level), "zone": zid,
                               "source": "abm_row", "name": bf["name"], "name_source": "entity description",
                               "name_where": bf["where"], "entity": "grug_mobs:rift_spawn", "role": "rift_spawn",
                               "family": "rift_spawn", "base": "grug_mobs:rift_spawn", "tier": bf["tier"],
                               "authored_tier": bf["tier"], "leader": False,
                               "disposition": bf["disposition"], "size": 1.0, "drops": None,
                               "role_levels": [1, 60], "levels": [level, level], "clocks": [bf["clock"]],
                               "notes": ["surface ABM row; level = the region level (middle of the belt) "
                                         "where it spawns; which belts it reaches is seed-dependent"]})

        # Underground casts.
        under = re.findall(r'\["grug_mobs:(\w+)"\]\s*=\s*true',
                           balanced(ptext, ptext.index("{", ptext.index("local UNDERGROUND_MOBS"))))
        self.source("underground", "underground cast (closed list; rows below y = -40)",
                    r.cite(policy, r"local UNDERGROUND_MOBS"))
        for entity in under:
            bf = self.base_facts(entity)
            cave = [row for row in rows.get(entity, []) if row[1] <= -40]
            if not cave:
                raise SystemExit("inventory: no cave spawn row for %s" % entity)
            top = max(row[1] for row in cave)
            bottom = min(row[0] for row in cave)
            if bf["tier"] == "critter":
                lo = hi = 1
            elif bf["fixed"]:
                lo = hi = bf["fixed"]
            else:
                lo, hi = max(bf["min"], depth_level(top)), 60
            self.add_slot({"key": "world/%s/%s" % (entity, band_key(lo, hi)), "zone": None,
                           "source": "underground", "name": bf["name"], "name_source": "entity description",
                           "name_where": bf["where"], "entity": "grug_mobs:" + entity, "role": entity,
                           "family": entity, "base": "grug_mobs:" + entity,
                           "tier": "elite" if bf["tier"] == "elite" else bf["tier"],
                           "authored_tier": bf["tier"], "leader": False, "disposition": bf["disposition"],
                           "size": 1.0, "drops": None, "role_levels": [lo, hi], "levels": [lo, hi],
                           "clocks": ["cave"], "depth": [bottom, top],
                           "rows": sorted({row[2] for row in cave}),
                           "notes": ["level = max(the zone field's surface level above, depth level), "
                                     "y %d..%d; under every zone" % (bottom, top)]})

        # Independent water authorities.
        for entity in re.findall(r'\["grug_mobs:(\w+)"\]\s*=\s*true',
                                 balanced(ptext, ptext.index("{", ptext.index("local INDEPENDENT_AUTHORITY")))):
            bf = self.base_facts(entity)
            level = 1 if bf["tier"] == "critter" else (bf["fixed"] or bf["min"])
            self.add_slot({"key": "world/%s/L%d-%d" % (entity, level, level), "zone": None, "source": "water",
                           "name": bf["name"], "name_source": "entity description", "name_where": bf["where"],
                           "entity": "grug_mobs:" + entity, "role": entity, "family": entity,
                           "base": "grug_mobs:" + entity, "tier": bf["tier"], "authored_tier": bf["tier"],
                           "leader": False, "disposition": bf["disposition"], "size": 1.0, "drops": None,
                           "role_levels": [level, level], "levels": [level, level], "clocks": [bf["clock"]],
                           "notes": ["independent spawn authority (water), every zone's water"]})
        self.source("water", "independent water authorities (Kraken: deep ocean, Reed Angelfish)",
                    r.cite(policy, r"local INDEPENDENT_AUTHORITY"))

        # Named rares: anchors 91..100 in the order of EXPECTED_RARE_IDS.
        auth = "mods/CORE/grug_core/zone_authority.lua"
        ids = re.findall(r'"(\w+)"', balanced(r.text(auth), r.text(auth).index("{", r.text(auth).index("EXPECTED_RARE_IDS"))))
        cat = r.text(POI_CATALOG)
        anchors = [(int(m.group(1)), m.group(2), m.group(3)) for m in re.finditer(
            r'number=(\d+),key="\w+",label="[^"]*",race="\w+",slot="(\w+)",zone_id="(\w+)",[^\n]*kind="rare_route"', cat)]
        anchors.sort()
        if len(anchors) != len(ids):
            raise SystemExit("inventory: %d rare ids, %d rare_route anchors" % (len(ids), len(anchors)))
        rtext = r.text(MOBS + "/rares.lua")
        self.source("rares", "named rares (name, base mob); level = the region level at its route",
                    r.cite(MOBS + "/rares.lua", r"function grug_mobs\.register_rare"))
        for rid, (_, slot_name, zid) in zip(ids, anchors):
            if slot_name not in ("rare_" + rid, "rare_captain_bonerattle"):
                raise SystemExit("inventory: rare %s does not match anchor slot %s" % (rid, slot_name))
            m = re.search(r'register_rare\("%s",\s*\{\s*name\s*=\s*"([^"]+)",\s*mob\s*=\s*"grug_mobs:(\w+)"' % rid, rtext)
            base = m.group(2)
            mids = self.belt_mids(zid)
            lo, hi = mids[0], mids[-1]
            bmin = self.base_facts(base)["min"]
            lo, hi = max(lo, bmin), max(hi, bmin)
            self.add_slot({"key": "%s/rare.%s/%s" % (zid, rid, band_key(lo, hi)), "zone": zid, "source": "rare",
                           "name": m.group(1), "name_source": "rares.lua spec.name",
                           "name_where": "%s:%d" % (MOBS + "/rares.lua", r.line_of(MOBS + "/rares.lua", m.start())),
                           "entity": "grug_mobs:" + base, "role": base, "family": self.family_of(base),
                           "base": "grug_mobs:" + base, "tier": "named", "authored_tier": "rare", "leader": False,
                           "disposition": self.base_disposition.get(base), "size": 1.0, "drops": None,
                           "role_levels": [lo, hi], "levels": [lo, hi], "clocks": ["any"],
                           "notes": ["rare tier (x2 scale, star prefix); level = the region level at the route "
                                     "point (a belt middle of the zone, seed-dependent); no area tag"]})

        # Kings, royal guards, the undead king's summons.
        btext = r.text(MOBS + "/bosses.lua")
        races = balanced(btext, btext.index("{", btext.index("local RACES")))
        self.source("kings", "the six kings (RACES[race].name), level 65 elite, and their royal guards "
                    "(name .. ' Royal Guard', level 60 elite)", r.cite(MOBS + "/bosses.lua", r"local RACES = \{"))
        capital = {"dwarf": "elandor_dur_brannoc", "human": "elandor_highcourt", "elf": "elandor_lethariel",
                   "undead": "kragmar_nhal_veyr", "orc": "kragmar_gor_drazhak", "troll": "kragmar_kezamba"}
        for m in re.finditer(r'(\w+)\s*=\s*\{name\s*=\s*"([^"]+)",\s*faction\s*=\s*"(\w+)",\s*\n\s*kit\s*=\s*"(\w+)"', races):
            race, kname, faction, kit = m.groups()
            zid = capital[race]
            if self.zones[zid]["race_region"] != race or not self.zones[zid]["civic"]:
                raise SystemExit("inventory: capital of %s is not %s" % (race, zid))
            where = "%s:%d" % (MOBS + "/bosses.lua", r.line_of(MOBS + "/bosses.lua", btext.index("local RACES") + m.start()))
            common = {"zone": zid, "authored_tier": "elite", "leader": False, "disposition": "aggressive",
                      "size": 1.0, "drops": None, "clocks": ["any"], "family": "humanoid"}
            self.add_slot(dict(common, key="%s/king_%s/L65-65" % (zid, race), source="boss", name=kname,
                               name_source="bosses.lua RACES.name", name_where=where,
                               entity="grug_mobs:king_" + race, role="king_" + race, base="king",
                               tier="boss", role_levels=[65, 65], levels=[65, 65],
                               notes=["king encounter (boss ledger); fixed level 65, elite tier"]))
            self.add_slot(dict(common, key="%s/royal_guard_%s/L60-60" % (zid, race), source="boss_guard",
                               name=kname + " Royal Guard", name_source="bosses.lua row.name .. ' Royal Guard'",
                               name_where=r.cite(MOBS + "/bosses.lua", r'row\.name \.\. " Royal Guard"'),
                               entity="grug_mobs:royal_guard_" + race, role="royal_guard_" + race, base="guard",
                               tier="elite", role_levels=[60, 60], levels=[60, 60],
                               notes=["four per king; fixed level 60, elite tier"]))
            if kit == "bone_call":
                mids = self.belt_mids(zid)
                sk = self.base_facts("skeleton_raider")
                self.add_slot(dict(common, key="%s/skeleton_raider/%s" % (zid, band_key(mids[0], mids[-1])),
                                   source="summon", name=sk["name"], name_source="entity description",
                                   name_where=sk["where"], entity="grug_mobs:skeleton_raider",
                                   role="skeleton_raider", base="grug_mobs:skeleton_raider",
                                   family="skeleton_raider", tier="normal", authored_tier=sk["tier"],
                                   role_levels=[mids[0], mids[-1]], levels=[mids[0], mids[-1]],
                                   notes=["the king's bone call summons (%s); level = the region level at the "
                                          "hall (seed-dependent belt middle)" %
                                          r.cite(MOBS + "/bosses.lua", r"local function bone_call")]))

        # Dragons and whelps.
        dtext = r.text(MOBS + "/boss_dragons.lua")
        whelp_level = int(re.search(r"whelp_level\s*=\s*(\d+)", dtext).group(1))
        self.source("dragons", "the two dragons (level 70 boss tier) and their whelps (name .. ' Whelp', level %d)" % whelp_level,
                    r.cite(MOBS + "/boss_dragons.lua", r'description = opts\.description \.\. " Whelp"'))
        dzones = {"ice": "front_wyrmglass_crown", "storm": "front_stormscale_summit"}
        for m in re.finditer(r'register_mob\("grug_mobs:(\w+)",\s*whelp_def\((\w+)\)\)', dtext):
            whelp, opts = m.groups()
            om = re.search(r"local %s = \{" % opts, dtext) or re.search(r"%s\s*=\s*\{" % opts, dtext)
            obody = balanced(dtext, om.end() - 1)
            dname = re.search(r'description\s*=\s*"([^"]+)"', obody).group(1)
            dentity = re.search(r'register_mob\("grug_mobs:(\w+)",\s*dragon_def\("\w+",\s*%s\b' % opts, dtext)
            dent = dentity.group(1) if dentity else None
            zid = dzones[opts]
            dwhere = "%s:%d" % (MOBS + "/boss_dragons.lua", r.line_of(MOBS + "/boss_dragons.lua", om.end() + obody.index("description")))
            common = {"zone": zid, "leader": False, "disposition": "aggressive", "size": 1.0, "drops": None,
                      "clocks": ["any"]}
            if dent:
                self.add_slot(dict(common, key="%s/%s/L70-70" % (zid, dent), source="boss", name=dname,
                                   name_source="boss_dragons.lua description", name_where=dwhere,
                                   entity="grug_mobs:" + dent, role=dent, base=dent, family="dragon",
                                   tier="boss", authored_tier="boss", role_levels=[70, 70], levels=[70, 70],
                                   notes=["dragon encounter; fixed level 70, boss tier"]))
            self.add_slot(dict(common, key="%s/%s/L%d-%d" % (zid, whelp, whelp_level, whelp_level), source="summon",
                               name=dname + " Whelp", name_source="boss_dragons.lua opts.description .. ' Whelp'",
                               name_where=dwhere, entity="grug_mobs:" + whelp, role=whelp, base=whelp,
                               family="dragon", tier="normal", authored_tier="normal",
                               role_levels=[whelp_level, whelp_level], levels=[whelp_level, whelp_level],
                               notes=["two summoned per dragon; fixed level %d (DRAGON_TUNING.whelp_level)" % whelp_level]))

        # The rift boss.
        core_rel = MOBS + "/rift_core.lua"
        site = re.search(r'M\.SITE = "(\w+)"', r.text(core_rel)).group(1)
        szone = re.search(r'key="%s"[^\n]*zone_id="(\w+)"' % site, cat).group(1)
        bm = r.search(core_rel, r'M\.BOSS_NAME = "([^"]+)"')
        rfix = int(re.search(r"_grug_fixed_level = (\d+)", balanced(r.text(MOBS + "/rift.lua"),
                   r.text(MOBS + "/rift.lua").index("(", r.text(MOBS + "/rift.lua").index('register_mob("grug_mobs:rift_boss"')))).group(1))
        self.add_slot({"key": "%s/rift_boss/L%d-%d" % (szone, rfix, rfix), "zone": szone, "source": "boss",
                       "name": bm.group(1), "name_source": "rift_core.lua M.BOSS_NAME",
                       "name_where": "%s:%d" % (core_rel, r.line_of(core_rel, bm.start())),
                       "entity": "grug_mobs:rift_boss", "role": "rift_boss", "family": "rift_boss",
                       "base": "grug_mobs:dungeon_master", "tier": "boss", "authored_tier": "elite",
                       "leader": False, "disposition": "aggressive", "size": 1.0, "drops": None,
                       "role_levels": [rfix, rfix], "levels": [rfix, rfix], "clocks": ["any"],
                       "notes": ["the rift at clash site %s; fixed level %d elite, boss ledger" % (site, rfix)]})
        self.source("rift_boss", "the rift boss name and site", r.cite(core_rel, r"M\.BOSS_NAME") + ", " +
                    r.cite(core_rel, r"M\.SITE = "))

        # Guards: settlements and outposts (one name per faction everywhere).
        gtext = r.text(MOBS + "/guard.lua")
        self.source("guards", "faction guards of settlements and outposts (guard level field 20..70, "
                    "capital 60; elite from level 60)",
                    r.cite(MOBS + "/guard.lua", r'guard_def\("accord", "') + ", " +
                    r.cite("mods/MAPGEN/grug_mapgen/wp40/zones.lua", r"function session\.guard_level_at"))
        for faction in ("accord", "throng"):
            gm = re.search(r'guard_def\("%s", "([^"]+)"' % faction, gtext)
            self.add_slot({"key": "world/guard_%s/L20-60" % faction, "zone": None, "source": "guard",
                           "name": gm.group(1), "name_source": "guard.lua guard_def description",
                           "name_where": "%s:%d" % (MOBS + "/guard.lua", r.line_of(MOBS + "/guard.lua", gm.start())),
                           "entity": "grug_mobs:guard_" + faction, "role": "guard_" + faction, "family": "guard",
                           "base": "guard", "tier": "guard", "authored_tier": "normal", "leader": False,
                           "disposition": None, "size": 1.0, "drops": None, "role_levels": [20, 70],
                           "levels": [20, 60], "clocks": ["any"], "faction": faction,
                           "notes": ["settlement posts and patrols (start towns, capitals, villages) and outpost "
                                     "banners; level = clamp(surface level, 20, 70), 60 in a capital; promoted to "
                                     "elite at level 60; same entity as the PvP garrison guards below"]})

        # PvP garrisons (fortresses and Battlegrounds camps).
        ptxt = r.text(PVP_CATALOG)
        self.source("pvp_garrisons", "PvP fortress and camp garrisons (guards, captains per race, "
                    "commanders, Generals, bodyguards); captain/commander/General names from pvp_names.json",
                    r.cite(MOBS + "/pvp_garrison.lua", r"function G\.slot") + ", " + PVP_NAMES)
        gdef = r.text(MOBS + "/pvp_garrison.lua")
        lv = {k: int(v) for k, v in re.findall(r"M\.(\w+_LEVEL) = (\d+)", gdef)}
        fortress = {"accord": "elandor_ashenward_march", "throng": "kragmar_bannerbreak_mesa"}
        for faction, zid in sorted(fortress.items()):
            if not re.search(r'key = "pvp_fortress_%s",[^\n]*zone_id = "%s"' % (faction, zid), ptxt):
                raise SystemExit("inventory: fortress %s is not in %s" % (faction, zid))
            key = "pvp_fortress_" + faction
            fac = faction.capitalize()
            common = {"zone": zid, "leader": False, "disposition": None, "size": 1.0, "drops": None,
                      "clocks": ["any"], "faction": faction, "tags": [zid + "/" + key]}
            gname = re.search(r'guard_def\("%s", "([^"]+)"' % faction, gtext).group(1)
            self.add_slot(dict(common, key="%s/%s.guard/L60-60" % (zid, key), source="pvp_garrison",
                               name=gname, name_source="guard.lua guard_def description",
                               name_where=r.cite(MOBS + "/guard.lua", r'guard_def\("%s", "' % faction),
                               entity="grug_mobs:guard_" + faction, role="guard_" + faction, family="guard",
                               base="guard", tier="elite", authored_tier="elite", role_levels=[60, 60],
                               levels=[lv["FORTRESS_GUARD_LEVEL"]] * 2, notes=["fortress gate and inner posts"]))
            general = self.pvp_names["generals"][faction]
            self.add_slot(dict(common, key="%s/%s.general/L%d-%d" % (zid, key, lv["GENERAL_LEVEL"], lv["GENERAL_LEVEL"]),
                               source="pvp_garrison", name=general, name_source="pvp_names.json generals",
                               name_where=r.cite(PVP_NAMES, r'"%s": "%s"' % (faction, re.escape(general))),
                               entity="grug_mobs:general_" + faction, role="general_" + faction, family="humanoid",
                               base="king", tier="boss", authored_tier="elite", disposition="aggressive",
                               role_levels=[lv["GENERAL_LEVEL"]] * 2, levels=[lv["GENERAL_LEVEL"]] * 2,
                               notes=["fortress General, a king's chassis; boss gear on an enemy player's kill"]))
            bname = "%s Bodyguard" % fac
            self.add_slot(dict(common, key="%s/%s.bodyguard/L60-60" % (zid, key), source="pvp_garrison",
                               name=bname, name_source="bosses.lua (Accord|Throng) .. ' Bodyguard'",
                               name_where=r.cite(MOBS + "/bosses.lua", r'" Bodyguard"'),
                               entity="grug_mobs:bodyguard_" + faction, role="bodyguard_" + faction, family="guard",
                               base="guard", tier="elite", authored_tier="elite",
                               role_levels=[lv["BODYGUARD_LEVEL"]] * 2, levels=[lv["BODYGUARD_LEVEL"]] * 2,
                               notes=["the General's two bodyguards"]))
        # A captain's and a commander's registered description is a generic
        # label the quest log shows (labels.lua mob_label reads the entity's
        # description); the mob itself shows its pvp_names.json name.
        self.label_alias_of = {}
        for faction in ("accord", "throng"):
            fac = faction.capitalize()
            self.label_alias_of["captain_" + faction] = fac + " Captain"
            self.label_alias_of["commander_" + faction] = fac + " War Commander"
        self.source("garrison_labels", "captain/commander registered description ('<Faction> Captain', "
                    "'<Faction> War Commander'): the quest label; the mob shows its pvp_names.json name",
                    r.cite(MOBS + "/guard.lua", r'" Captain",') + ", " + r.cite(MOBS + "/guard.lua", r'" War Commander",') +
                    ", " + r.cite(MOBS + "/start_npcs.lua", r"entity\.description = spec\.name"))
        bg = re.findall(r'\{zone_id = "(\w+)", name = "[^"]+"\}', ptxt)
        for zid in bg:
            zl = self.zones[zid]
            for faction in ("accord", "throng"):
                fac = faction.capitalize()
                for band in ("low", "high"):
                    key = "pvp_camp_%s_%s_%s" % (zid.replace("front_", ""), faction, band)
                    lo, hi = (zl["level_min"], zl["level_min"] + 2) if band == "low" else (zl["level_max"] - 2, zl["level_max"])
                    common = {"zone": zid, "leader": False, "disposition": None, "size": 1.0, "drops": None,
                              "clocks": ["any"], "faction": faction, "tags": [zid + "/" + key]}
                    gname = re.search(r'guard_def\("%s", "([^"]+)"' % faction, gtext).group(1)
                    self.add_slot(dict(common, key="%s/%s.guard/%s" % (zid, key, band_key(lo, hi)),
                                       source="pvp_garrison", name=gname,
                                       name_source="guard.lua guard_def description",
                                       name_where=r.cite(MOBS + "/guard.lua", r'guard_def\("%s", "' % faction),
                                       entity="grug_mobs:guard_" + faction, role="guard_" + faction,
                                       family="guard", base="guard", tier="guard", authored_tier="normal",
                                       role_levels=[lo, hi], levels=[lo, hi],
                                       notes=["camp guards (%s camp)" % band]))
                    for race, cname in sorted(self.pvp_names["captains"][key].items()):
                        self.add_slot(dict(common, key="%s/%s.captain-%s/L%d-%d" % (zid, key, race, hi, hi),
                                           source="pvp_garrison", name=cname,
                                           name_source="pvp_names.json captains",
                                           name_where=r.cite(PVP_NAMES, r'"%s"' % re.escape(cname)),
                                           entity="grug_mobs:captain_" + faction, role="captain_" + faction,
                                           family="guard", base="guard", tier="named", authored_tier="normal",
                                           role_levels=[hi, hi], levels=[hi, hi], race=race,
                                           notes=["the camp's captain if the world rolled a %s camp "
                                                  "(one race per camp, seed-dependent)" % race]))
                    cname = (self.pvp_names.get("commanders") or {}).get(key)
                    if cname:
                        cl = lv["COMMANDER_LEVEL"]
                        self.add_slot(dict(common, key="%s/%s.commander/L%d-%d" % (zid, key, cl, cl),
                                           source="pvp_garrison", name=cname,
                                           name_source="pvp_names.json commanders",
                                           name_where=r.cite(PVP_NAMES, r'"%s"' % re.escape(cname)),
                                           entity="grug_mobs:commander_" + faction, role="commander_" + faction,
                                           family="guard", base="guard", tier="named", authored_tier="elite",
                                           role_levels=[cl, cl], levels=[cl, cl],
                                           notes=["war commander, level 60 elite"]))

        # Registered sub-types nothing places.
        placed = {s["role"] for s in self.slots}
        for role in sorted(set(self.subtypes) - placed):
            f = self.sub_fields(role, None)
            lo, hi = f["role_levels"]
            self.add_slot(dict(f, key="world/%s/%s" % (role, band_key(lo, hi)), zone=None, source="unplaced",
                               levels=[lo, hi], clocks=[],
                               notes=["registered in subtypes.json, but no recipe, camp, leader or other spawner "
                                      "places it today: never seen in the game"]))
        self.source("unplaced", "sub-types no spawner places", SUBTYPES)
        self.source("summons", "the undead king's bone call (base Skeleton Raider, level from the field)",
                    r.cite(MOBS + "/bosses.lua", r"local function bone_call"))
        self.source("rare_zones", "a rare's zone: its rare_route anchor (anchors 91..100 in EXPECTED_RARE_IDS order)",
                    r.cite(POI_CATALOG, r'slot="rare_grimtusk"') + ", " + r.cite(auth, r"local EXPECTED_RARE_IDS"))
        # Searched, no slot: they name no creature or are dormant.
        self.source("no_slot_npcs", "(no slot) settlement residents, elders, vendors, quartermasters, the "
                    "Crownbinder, quest givers: job titles of non-combat NPCs",
                    r.cite(MOBS + "/start_villagers.lua", r"self\.description = text") + ", " +
                    r.cite("mods/ENTITIES/grug_traders/vendors.lua", r'nametag = "Crownbinder"') + ", " +
                    r.cite("mods/PLAYER/grug_quests/npc.lua", r'nametag = ""'))
        self.source("no_slot_labels", "(no slot) gear displays, use-point labels, player tags",
                    r.cite(MOBS + "/capital_displays.lua", r"local function configure_display_tag") + ", " +
                    r.cite("mods/PLAYER/grug_quests/use.lua", r"nametag = point\.objective\.label") + ", " +
                    r.cite("mods/PLAYER/grug_factions/init.lua", r"set_tag_carrier_text\(carrier, state\.text\)"))
        self.source("no_slot_dormant", "(no slot) Elder Bear / Silverback spawn rolls of base bears and apes, "
                    "whose ABM rows are retired in recipe zones (every zone has one); the legacy "
                    "bandit/mirefolk fires are scenery in a recipe zone",
                    r.cite(MOBS + "/bear.lua", r"ent\.description = elder_name") + ", " +
                    r.cite(MOBS + "/jungle_ape.lua", r'ent\.description = "Silverback"') + ", " +
                    r.cite(policy, r"function grug_mobs\.spawn_row_kept") + ", " +
                    r.cite(MOBS + "/camps.lua", r"is scenery in a recipe zone"))
        self.source("start_footprint", "(no slot) start towns refuse hostile spawns; start-zone mobs are "
                    "the start recipes' roles", r.cite(policy, r"function grug_mobs\.in_start_footprint"))
        self.source("dawn", "(no slot) night region mobs leave at dawn (the clocks column)",
                    r.cite(MOBS + "/dawn.lua", r"function grug_mobs\.dawn_leaves"))

    def family_of(self, entity):
        sub = self.subtypes.get(entity)
        return sub["family"] if sub else entity

    # quests --------------------------------------------------------------------
    def build_quests(self):
        r = self.repo
        self.quest_files = sorted(p.name for p in (r.root / QUESTS).glob("*.json"))
        self.source("quest_kill_credit", "kill credit: role match, area tag match (`_grug_area`)",
                    r.cite("mods/PLAYER/grug_quests/state.lua", r"local function mob_counts"))
        self.source("quest_label", "objective label = the role's display name in its target zone "
                    "(leader zone, else the area's zone, else the quest's zone)",
                    r.cite("mods/PLAYER/grug_quests/labels.lua", r"local function mob_label") + ", " +
                    r.cite("mods/PLAYER/grug_quests/labels.lua", r"function Q\.target_zones"))
        self.source("quest_placeholders", "{name:T} placeholders fill a leader's or area's name at runtime",
                    r.cite("mods/PLAYER/grug_quests/labels.lua", r"P\.KINDS = "))
        by_role = defaultdict(list)
        for s in self.slots:
            by_role[s["role"]].append(s)
        leaders = {s["role"]: s["zone"] for s in self.slots if s["source"] == "leader"}
        by_name = defaultdict(list)
        for s in self.slots:
            by_name[s["name"].lower()].append(s)
        for fname in self.quest_files:
            rel = QUESTS + "/" + fname
            data = r.json(rel)
            qzone = data["zone"]
            for qi, q in enumerate(data["quests"]):
                rows = [("objectives", i, o) for i, o in enumerate(q["objectives"])]
                rows += [("quest_drops", i, o) for i, o in enumerate(q.get("quest_drops") or [])]
                for field, oi, o in rows:
                    roles = o.get("roles") or []
                    if not roles:
                        continue
                    kind = o.get("type", "quest_drop")
                    area = o.get("area")
                    targets, labels = [], {}
                    for role in roles:
                        tzone = leaders.get(role) or (area.split("/")[0] if area else qzone)
                        sub = self.subtypes.get(role)
                        if sub:
                            label = (sub.get("display_by_zone") or {}).get(tzone, sub["display"])
                        elif role in self.label_alias_of:
                            label = self.label_alias_of[role]
                        else:
                            cands = [s for s in by_role.get(role, []) if s["zone"] == tzone] or by_role.get(role, [])
                            label = cands[0]["name"] if cands else role
                        labels[role] = label
                    # A spawn source is (slot, area tag); a leader, rare,
                    # critter or cave mob carries no tag (None).
                    def sources(s):
                        return [(s, t) for t in (s["tags"] or [None])]
                    counted = [(s, t) for role in roles for s in by_role.get(role, []) for s, t in sources(s)
                               if area is None or t == area]
                    counted_ids = {(s["key"], t) for s, t in counted}
                    targets = sorted({s["key"] for s, _ in counted})
                    label_names = {v.lower() for v in labels.values()}
                    target_zones = {leaders.get(role) or (area.split("/")[0] if area else qzone) for role in roles}

                    def ref(s, t):
                        return s["key"] + ("@" + t.split("/", 1)[1] if t else "")
                    same_not = sorted({ref(s, t) for n in label_names for s0 in by_name.get(n, [])
                                       for s, t in sources(s0) if (s["key"], t) not in counted_ids})
                    same_not_zone = sorted({ref(s, t) for n in label_names for s0 in by_name.get(n, [])
                                            for s, t in sources(s0) if (s["key"], t) not in counted_ids
                                            and s["zone"] in target_zones})
                    other = sorted({ref(s, t) for s, t in counted if s["name"].lower() not in label_names})
                    obj = {"quest": q["id"], "file": rel, "quest_zone": qzone, "path": "%s[%d]" % (field, oi),
                           "kind": kind, "item": o.get("item"), "roles": roles, "area": area,
                           "count": o.get("count"), "labels": labels, "targets": targets,
                           "same_name_not_counted": same_not, "same_name_not_counted_in_zone": same_not_zone,
                           "counted_other_name": other, "title": q.get("title", "")}
                    self.objectives.append(obj)
                    for key in obj["targets"]:
                        self.slot_by_key[key]["quest_targets"].append({
                            "quest": q["id"], "file": rel, "path": obj["path"], "kind": kind,
                            "area": area, "same_name_not_counted": same_not,
                            "same_name_not_counted_in_zone": same_not_zone,
                            "counted_other_name": other})
        self.objectives.sort(key=lambda o: (o["file"], o["quest"], o["path"]))

    # text surfaces ---------------------------------------------------------------
    def build_surfaces(self):
        r = self.repo
        alias_slots = defaultdict(list)
        for s in self.slots:
            alias = self.label_alias_of.get(s["role"])
            if alias:
                alias_slots[alias].append(s["key"])
        names = sorted({s["name"] for s in self.slots} | set(alias_slots))
        variants = {}
        for n in names:
            forms = {n, n + "s", n + "es", n + "'s"}
            if n.endswith("f"):
                forms.add(n[:-1] + "ves")
            if n.endswith("y"):
                forms.add(n[:-1] + "ies")
            for f in forms:
                variants.setdefault(f.lower(), n)
        # Names of two or more words (or a hyphenated one) match in any case;
        # one-word names case-sensitively, in game files only. Words are
        # runs of letters, digits, hyphens and apostrophes; the words of a
        # name are separated by white space only (a line break counts).
        multi = {v: n for v, n in variants.items() if " " in n or "-" in n}
        single_cs = {}
        for v, n in variants.items():
            if v not in multi:
                for f in (n, n + "s", n + "es", n + "'s"):
                    single_cs[f] = n
        firsts = {v.split()[0] for v in multi}
        longest = max(len(v.split()) for v in multi)
        word = re.compile(r"[A-Za-z0-9][A-Za-z0-9'\-]*")
        name_slots = defaultdict(list)
        for s in self.slots:
            name_slots[s["name"]].append(s["key"])
        for alias, keys in alias_slots.items():
            name_slots[alias].extend(keys)

        def hits(text, game):
            toks = [(m.start(), m.end(), m.group()) for m in word.finditer(text)]
            out, i, count = [], 0, len(toks)
            while i < count:
                found = 0
                if toks[i][2].lower() in firsts:
                    for n in range(min(longest, count - i), 0, -1):
                        if any(not text[toks[j][1]:toks[j + 1][0]].isspace() for j in range(i, i + n - 1)):
                            continue
                        phrase = " ".join(t[2] for t in toks[i:i + n])
                        name = multi.get(phrase.lower())
                        if name:
                            out.append((toks[i][0], name, text[toks[i][0]:toks[i + n - 1][1]]))
                            found = n
                            break
                if not found and game and toks[i][2] in single_cs:
                    out.append((toks[i][0], single_cs[toks[i][2]], toks[i][2]))
                    found = 1
                i += found or 1
            return out

        def snippet(text, pos):
            a, b = max(0, pos - 50), min(len(text), pos + 70)
            return re.sub(r"\s+", " ", text[a:b]).strip()

        surfaces = []
        mods = r.root / "mods"
        files = []
        for p in sorted(mods.rglob("*")):
            rel = p.relative_to(r.root).as_posix()
            if rel.startswith(("mods/BASE/", "mods/ENTITIES/mobs/")) or not p.is_file():
                continue
            if p.suffix in (".lua", ".json", ".conf", ".txt", ".tr"):
                files.append((rel, True))
        for pat in ("docs/design/*.md", "docs/planning/round36/story-bible.md", "README.md"):
            files += [(p.relative_to(r.root).as_posix(), False) for p in sorted(r.root.glob(pat))]
        for p in sorted((r.root / "tools").rglob("*")):
            rel = p.relative_to(r.root).as_posix()
            if p.is_file() and p.suffix in (".lua", ".py", ".sh") and not rel.startswith("tools/r38_names/"):
                files.append((rel, False))
        for rel, game in files:
            text = (r.root / rel).read_text(encoding="utf-8", errors="replace")
            if rel.endswith(".json"):
                try:
                    data = json.loads(text)
                except ValueError:
                    data = None
                if data is not None:
                    for path, value in walk_json(data, ""):
                        for pos, name, matched in hits(value, True):
                            surfaces.append(self.surface(rel, path, name, matched, snippet(value, pos)))
                    continue
            for pos, name, matched in hits(text, game):
                line = text.count("\n", 0, pos) + 1
                surfaces.append(self.surface(rel, "line %d" % line, name, matched, snippet(text, pos)))
        surfaces.sort(key=lambda s: (s["kind"], s["file"], natural(s["location"]), s["name"]))
        self.surfaces = surfaces
        for s in surfaces:
            s["slots"] = len(name_slots[s["name"]])
            if s["kind"] == "quest_text":
                quest = s["location"].split("]")[0].split("=")[-1] if s["location"].startswith("quests[") else None
                for key in name_slots[s["name"]]:
                    self.slot_by_key[key]["quest_mentions"].append({
                        "file": s["file"], "path": s["location"], "quest": quest, "matched": s["matched"]})

    def surface(self, rel, location, name, matched, snip):
        if rel.startswith(QUESTS):
            kind = "quest_text"
        elif rel == SUBTYPES and re.search(r"\.(display|display_by_zone\.\w+)$", location):
            kind = "name_source"
        elif rel.startswith("mods/") and rel.endswith(".json"):
            kind = "game_data"
        elif rel.startswith("mods/"):
            kind = "game_code"
        elif rel == "docs/design/zone_mobs.md":
            kind = "generated_doc"
        elif rel.startswith("docs/") or rel == "README.md":
            kind = "doc"
        else:
            kind = "tool"
        return {"kind": kind, "file": rel, "location": location, "name": name,
                "matched": " ".join(matched.split()),
                "snippet": snip}

    def finish(self):
        self.slots.sort(key=lambda s: s["key"])
        for s in self.slots:
            if s["role"] in self.label_alias_of:
                s["quest_label"] = self.label_alias_of[s["role"]]
        for s in self.slots:
            s["quest_targets"].sort(key=lambda q: (q["file"], q["quest"], q["path"]))
            s["quest_mentions"].sort(key=lambda q: (q["file"], q["path"]))
        self.sources.sort(key=lambda s: s["id"])


def natural(text):
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", text)]


def walk_json(value, path):
    """(path, string) for every string value that is prose, not an id."""
    skip = {"id", "role", "roles", "area", "item", "npc", "giver", "turnin", "requires", "line", "base",
            "family", "drops", "tags", "place", "object", "zone", "type", "tint", "texture", "anchor",
            "belt", "group", "kind", "lines", "givers", "key", "notes", "icon"}
    if isinstance(value, dict):
        for k in sorted(value):
            if k in skip:
                continue
            v = value[k]
            yield from walk_json(v, "%s.%s" % (path, k) if path else k)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            label = i
            if isinstance(v, dict):
                if isinstance(v.get("id"), str):
                    label = "id=" + v["id"]
                elif isinstance(v.get("role"), str):
                    label = "role=" + v["role"]
            yield from walk_json(v, "%s[%s]" % (path, label))
    elif isinstance(value, str):
        yield path, value


def build(repo=REPO, surfaces=True):
    m = Model(repo)
    m.load_zones()
    m.load_data()
    m.cite_rules()
    m.build_recipe_slots()
    m.build_special_slots()
    m.build_quests()
    if surfaces:
        m.build_surfaces()
    m.finish()
    return m


# --- outputs -----------------------------------------------------------------

TSV_COLUMNS = ["key", "zone", "race_region", "continent", "source", "today_name", "words", "signal_words",
               "tier", "disposition", "family", "base", "size", "levels", "drop_tiers", "clocks", "units",
               "camps", "quest_targets", "quest_mentions", "same_name_not_counted", "entity", "name_where",
               "neighbours", "notes"]


def tsv_row(s):
    kinds = sorted({"%s:%s(%s)" % (u["id"], u["type"], "/".join(u["clocks"]))
                    for u in s["units"] if u["unit"] == "kind"})
    camps = sorted({u["id"] for u in s["units"] if u["unit"] in ("camp", "leader") and u["type"] == "camp"})
    nn = {k for q in s["quest_targets"] for k in q["same_name_not_counted"]}
    nz = {k for q in s["quest_targets"] for k in q["same_name_not_counted_in_zone"]}
    row = {
        "key": s["key"], "zone": s["zone"] or "", "race_region": s["race_region"] or "",
        "continent": s["continent"] or "", "source": s["source"], "today_name": s["name"],
        "words": str(s["words"]), "signal_words": ",".join(s["signal_words"]), "tier": s["tier"],
        "disposition": s["disposition"] or "", "family": s["family"], "base": s["base"],
        "size": "%g" % s["size"], "levels": "%d-%d" % tuple(s["levels"]),
        "drop_tiers": ",".join("T%d" % t for t in s["drop_tiers"]), "clocks": ",".join(s["clocks"]),
        "units": " ".join(kinds), "camps": " ".join(camps),
        "quest_targets": ",".join(sorted({q["quest"] for q in s["quest_targets"]})),
        "quest_mentions": ",".join(sorted({q["quest"] or q["path"] for q in s["quest_mentions"]})),
        "same_name_not_counted": "%d/%d" % (len(nz), len(nn)) if nn else "", "entity": s["entity"], "name_where": s["name_where"],
        "neighbours": ",".join(s["neighbours"]),
        "notes": " | ".join(s["notes"]),
    }
    return "\t".join(row[c].replace("\t", " ").replace("\n", " ") for c in TSV_COLUMNS)


def write_tsv(path, rows):
    with open(path, "w", encoding="utf-8") as f:
        f.write("\t".join(TSV_COLUMNS) + "\n")
        for s in rows:
            f.write(tsv_row(s) + "\n")


def today_proposals(model):
    """Today's names in the proposal format, one file per zone plus world.json."""
    out = defaultdict(dict)
    for s in model.slots:
        out[s["zone"] or "world"][s["key"]] = {"name": s["name"], "keep": True, "reason": "today's name"}
    return {group: {"zone": group, "slots": dict(sorted(slots.items()))} for group, slots in out.items()}


def input_digest(model):
    h = hashlib.sha256()
    for rel in sorted(model.repo.read_files):
        h.update(rel.encode())
        h.update((model.repo.root / rel).read_bytes())
    return h.hexdigest()[:16]


def write(model, out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    (out / "by_zone").mkdir(exist_ok=True)
    (out / "today").mkdir(exist_ok=True)
    meta = {"generator": "tools/r38_names/inventory.py", "input_digest": input_digest(model),
            "slot_key_format": "<zone id or 'world'>/<source id>/L<lo>-<hi>",
            "counts": {"slots": len(model.slots), "objectives": len(model.objectives),
                       "surfaces": len(model.surfaces)}}
    doc = {"meta": meta, "zones": {z: model.zones[z] for z in model.zone_order}, "slots": model.slots,
           "objectives": model.objectives, "sources": model.sources}
    (out / "slots.json").write_text(json.dumps(doc, indent=1, sort_keys=True, ensure_ascii=False) + "\n",
                                    encoding="utf-8")
    write_tsv(out / "slots.tsv", model.slots)
    groups = defaultdict(list)
    for s in model.slots:
        groups[s["zone"] or "world"].append(s)
    for old in (out / "by_zone").glob("*.tsv"):
        old.unlink()
    for group, rows in groups.items():
        write_tsv(out / "by_zone" / (group + ".tsv"), rows)
    for old in (out / "today").glob("*.json"):
        old.unlink()
    for group, prop in today_proposals(model).items():
        (out / "today" / (group + ".json")).write_text(
            json.dumps(prop, indent=1, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
    zcols = ["zone", "name", "race_region", "continent", "role", "levels", "faction", "pvp", "relief",
             "biomes", "neighbours", "neighbours_some_seeds", "slots"]
    zslots = defaultdict(int)
    for s in model.slots:
        zslots[s["zone"]] += 1
    with open(out / "zones.tsv", "w", encoding="utf-8") as f:
        f.write("\t".join(zcols) + "\n")
        for zid in model.zone_order:
            z = model.zones[zid]
            f.write("\t".join([zid, z["name"], z["race_region"], z["continent"], z["role"],
                               "%d-%d" % (z["level_min"], z["level_max"]), z["faction"] or "", z["pvp"],
                               z["relief"], ",".join(z["biomes"]), ",".join(z["neighbours"]),
                               ",".join(z["neighbours_some_seeds"]), str(zslots[zid])]) + "\n")
    cols = ["kind", "name", "slots", "file", "location", "matched", "snippet"]
    with open(out / "surfaces.tsv", "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for s in model.surfaces:
            f.write("\t".join(str(s[c]).replace("\t", " ") for c in cols) + "\n")
    import check_rules  # noqa: E402  (sibling modules)
    import report  # noqa: E402
    problems, notes = check_rules.check(model, check_rules.today_entries(model))
    (out / "today_check.txt").write_text("\n".join(problems + notes) + "\n", encoding="utf-8")
    (out / "README.md").write_text(report.readme(model, meta), encoding="utf-8")
    (out / "summary.md").write_text(report.summary(model), encoding="utf-8")
    (out / "lists.md").write_text(report.lists(model), encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--out", default=str(DEFAULT_OUT))
    ap.add_argument("--repo", default=str(REPO))
    ap.add_argument("--check", action="store_true", help="exit 1 when --out differs from a fresh build")
    args = ap.parse_args(argv)
    model = build(args.repo)
    if not args.check:
        write(model, args.out)
        print("inventory: %d slots, %d objectives, %d surfaces -> %s" %
              (len(model.slots), len(model.objectives), len(model.surfaces), args.out))
        return 0
    tmp = tempfile.mkdtemp(prefix="r38_inventory_")
    try:
        write(model, tmp)
        cmp = filecmp.dircmp(tmp, args.out)
        stale = []

        def walk(c, prefix):
            stale.extend(prefix + n for n in c.left_only + c.right_only + c.diff_files)
            for name, sub in c.subdirs.items():
                walk(sub, prefix + name + "/")
        walk(cmp, "")
        for name in stale:
            print("stale: %s" % name)
        return 1 if stale else 0
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    sys.exit(main())

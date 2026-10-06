#!/usr/bin/env python3
"""Round 38: the quest-name guarantee, proved statically from the data.

The property (round38-mob-names-plan.md section 2.1): for every kill
objective and every quest drop, every mob that bears the name the quest names
counts -- whatever its level, wherever it is, wherever it spawned -- and no
mob of another name counts.

The tool builds the world's BEARERS (every place a mob gets a name: the spawn
recipes' kinds and camps, their leaders, the PvP garrisons, the faction
guards of settlements and guard posts, the named rares and the rift boss),
then asks, for every objective, which bearers COUNT under a counting rule and
which names the quest SHOWS (the objective label of
mods/PLAYER/grug_quests/labels.lua), and reports where the two disagree:

  missed   a bearer shows a name the quest shows, but does not count
  foreign  a bearer counts, but shows a name the quest does not show
  ghost    the quest shows a name that no counting bearer bears

Two counting rules (--mode):

  today    the shipped rule (grug_quests/state.lua mob_counts): the entity
           name is one of the objective's roles and, with an `area`, the
           mob's spawn tag `_grug_area` equals it. Labels as labels.lua.
  names    the Round 38 rule under proposal: the objective's roles and
           area only SELECT the names the quest shows; a mob counts when its
           name is one of them. missed/foreign/ghost are then empty by
           construction; what can still break is listed by the checks below
           (no bearer selected, one role shown under two names, a name that
           breaks the objective's level fit, a name a critter bears, a name
           a runtime lookup cannot decide, a name the quest text never says).

Item objectives with source `roles` are family loot, not a counting rule;
they are reported apart (--items) because the plan's open question is whether
the guarantee covers them.

The mob names come from `name_of` (today: subtypes.json display_by_zone,
else display; pvp_names.json; the entity descriptions of the garrison and
rift code). When lane I's model (tools/r38_names/inventory.py) and the build
lane's names data exist, `bearers()` and `name_of` read them instead; the
checks stay.

    python3 tools/r38_names/guarantee.py                 # both modes, summary
    python3 tools/r38_names/guarantee.py --mode today -v # every finding
    python3 tools/r38_names/guarantee.py --mode names --check   # exit 1 on a break
    python3 tools/r38_names/guarantee.py --out DIR       # findings.tsv, pairs.tsv, summary.json

Python 3 standard library only; reads tools/r28_design/r28common.py's
recipe, zone and PvP readers (the game's Lua stays the reference).
"""
import argparse
import collections
import glob
import json
import os
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "r28_design"))
import r28common as C  # noqa: E402

MOBS = REPO / "mods" / "ENTITIES" / "grug_mobs"
MOB_DATA = MOBS / "data"
QUEST_ZONES = REPO / "mods" / "PLAYER" / "grug_quests" / "data" / "zones"
R37_TSV = Path.home() / "projects" / "grudgelands-orchestration" / "r38" / "naming-analysis" / "multi_region_roles.tsv"
LEVEL_SLACK = 3  # grug_quests validate.lua V.LEVEL_SLACK
FACTIONS = ("accord", "throng")
FACTION_WORD = {"accord": "Accord", "throng": "Throng"}


class LoadError(Exception):
    pass


def read_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def drop_tier(level):
    """grug_mobs.level_band (subtypes.lua): 1-10 -> 1 ... 51-60 -> 6."""
    return max(1, min(6, (level - 1) // 10 + 1))


# --- the fixed names of entities that are no sub-type -------------------------

def entity_names():
    """{entity role: name} of the quest-relevant entities that are no sub-type:
    the faction guards (guard.lua guard_def), captains and war commanders
    (guard.lua), bodyguards (bosses.lua), Generals (pvp_names.json) and the
    rift boss (rift_core.lua). Each read fails loudly when the code differs."""
    out = {}
    guard = (MOBS / "guard.lua").read_text(encoding="utf-8")
    for faction, name in re.findall(r'register_mob\("grug_mobs:guard_(\w+)",\s*guard_def\("\w+", "([^"]+)"', guard):
        out["guard_" + faction] = name
    for suffix, word in (("captain", '" Captain"'), ("commander", '" War Commander"')):
        if ('%s_entity(faction)' % suffix) not in guard or word not in guard:
            raise LoadError("guard.lua: the %s name differs from what this reader takes" % suffix)
        for faction in FACTIONS:
            out["%s_%s" % (suffix, faction)] = FACTION_WORD[faction] + word.strip('"')
    bosses = (MOBS / "bosses.lua").read_text(encoding="utf-8")
    if '.. " Bodyguard"' not in bosses:
        raise LoadError("bosses.lua: the bodyguard name differs from what this reader takes")
    names = read_json(MOB_DATA / "pvp_names.json")
    for faction in FACTIONS:
        out["bodyguard_" + faction] = FACTION_WORD[faction] + " Bodyguard"
        out["general_" + faction] = names["generals"][faction]
    m = re.search(r'M\.BOSS_NAME\s*=\s*"([^"]+)"', (MOBS / "rift_core.lua").read_text(encoding="utf-8"))
    if not m:
        raise LoadError("rift_core.lua: M.BOSS_NAME not found")
    out["rift_boss"] = m.group(1)
    if not all(("guard_" + f) in out for f in FACTIONS):
        raise LoadError("guard.lua: the faction guard registrations differ")
    return out


def rares():
    """[(id, name, entity role)] of rares.lua's registrations."""
    text = (MOBS / "rares.lua").read_text(encoding="utf-8")
    rows = re.findall(r'register_rare\("(\w+)", \{\s*name = "([^"]+)",\s*mob = "grug_mobs:(\w+)"', text)
    if len(rows) != text.count("grug_mobs.register_rare(\""):
        raise LoadError("rares.lua: a registration differs from what this reader takes")
    return rows


# --- the model: bearers --------------------------------------------------------

class World:
    """Every bearer of a mob name, and the quests. A bearer is a dict:
    source    kind | camp | leader | garrison | settlement | rare | rift
    zone      the zone it is met in (None: anywhere / not static)
    role      the entity name without "grug_mobs:"
    levels    (lo, hi) or None (not static)
    area      the `_grug_area` tag it carries ("zone/kind", "zone/camp",
              "zone/<PvP POI key>") or None
    belt      the recipe belt id (kinds and camps)
    variant   a group of alternatives of which one exists per world (a
              camp captain's race names), else None
    faction   the faction of a faction NPC, else None
    name      the name it shows (name_of)
    key       a readable slot key"""

    def __init__(self):
        self.subtypes = {row["role"]: row for row in read_json(MOB_DATA / "subtypes.json")}
        self.zones = C.zone_records()
        self.fixed = entity_names()
        self.pvp_names = read_json(MOB_DATA / "pvp_names.json")
        self.recipes = {}
        self.bearers = []
        self.quest_files = []
        self.drops = {row["family"]: row for row in read_json(MOB_DATA / "drops.json")}
        self._build()
        self._read_quests()

    # The name a bearer shows. Today: a sub-type's display in its zone
    # (subtypes.lua apply_zone_variant: the zone of its spawn position),
    # else its display; a garrison captain or commander its pvp_names.json
    # name (start_npcs.lua install_garrison); a rare its own name; every
    # other entity its registered description.
    def name_of(self, bearer):
        if bearer.get("own_name"):
            return bearer["own_name"]
        sub = self.subtypes.get(bearer["role"])
        if sub is not None:
            return (sub.get("display_by_zone") or {}).get(bearer["zone"], sub["display"])
        return self.fixed.get(bearer["role"], bearer["role"])

    def disposition(self, role):
        sub = self.subtypes.get(role)
        return sub["disposition"] if sub else None

    def _add(self, **row):
        row.setdefault("variant", None)
        row.setdefault("faction", None)
        row.setdefault("belt", None)
        row.setdefault("area", None)
        row["name"] = self.name_of(row)
        lv = row["levels"]
        row["key"] = "%s/%s/%s%s" % (row["zone"] or "*", row["role"],
                                     ("L%d-%d" % tuple(lv)) if lv else "L?",
                                     ("/" + row["slot"]) if row.get("slot") else "")
        self.bearers.append(row)

    def _build(self):
        role_levels = lambda r: (self.subtypes.get(r) or {}).get("levels")  # noqa: E731
        is_leader = lambda r: (self.subtypes.get(r) or {}).get("leader") is True  # noqa: E731
        for path in sorted(glob.glob(str(MOB_DATA / "zones" / "*.spawns.json"))):
            data = read_json(path)
            zone = data["zone"]
            if "recipe" not in data:
                continue
            record = self.zones.get(zone)
            band = list(record["levels"]) if record else None
            parsed, errors = C.parse_recipe(zone, data["recipe"], band, role_levels, is_leader)
            if errors:
                raise LoadError("%s: recipe errors: %s" % (path, "; ".join(errors[:3])))
            self.recipes[zone] = parsed
            for unit in parsed["kinds"] + parsed["camps"]:
                clocks = collections.defaultdict(set)
                for clock in ("day", "night"):
                    for row in (unit["rosters"][clock] or {}).get("list") or []:
                        clocks[row["role"]].add("both" if unit["unit"] == "camp" else clock)
                for role in unit["roles"]:
                    self._add(source=unit["unit"], zone=zone, role=role,
                              levels=tuple(unit["levels_by_role"][role]),
                              area="%s/%s" % (zone, unit["id"]), belt=unit["belt"], unit=unit["id"],
                              clocks=sorted(clocks.get(role, ())))
            for leader in parsed["leaders"]:
                self._add(source="leader", zone=zone, role=leader["role"],
                          levels=(leader["level"], leader["level"]), unit=None, clocks=["fixed"])
        captains = self.pvp_names.get("captains") or {}
        commanders = self.pvp_names.get("commanders") or {}
        for key, poi in sorted(C.pvp_pois().items()):
            faction = poi["faction"]
            area = "%s/%s" % (poi["zone"], key)
            for role, levels in sorted(poi["roles"].items()):
                common = dict(source="garrison", zone=poi["zone"], role=role, levels=tuple(levels), area=area,
                              faction=faction, unit=key, clocks=["fixed"])
                if role.startswith("captain_"):
                    for race, name in sorted((captains.get(key) or {}).items()):
                        self._add(own_name=name, variant=key, slot=key + "/" + race, **common)
                elif role.startswith("commander_"):
                    self._add(own_name=commanders[key], slot=key, **common)
                else:
                    self._add(slot=key, **common)
        # The faction guards of start towns, capitals and guard posts
        # (start_npcs.lua's guard resolvers, camps.lua's guard_<faction>
        # camp types): the garrison guards' entity and name, no area.
        for faction in FACTIONS:
            self._add(source="settlement", zone=None, role="guard_" + faction, levels=None,
                      faction=faction, unit=None, clocks=["fixed"], slot="settlements")
        for rid, name, mob in rares():
            self._add(source="rare", zone=None, role=mob, levels=None, own_name=name, unit=rid,
                      clocks=["scheduled"], slot="rare:" + rid)
        self._add(source="rift", zone=None, role="rift_boss", levels=None, unit=None, clocks=["event"])
        self._index()

    def _index(self):
        self.by_name = collections.defaultdict(list)
        self.by_role = collections.defaultdict(list)
        for b in self.bearers:
            self.by_name[b["name"]].append(b)
            self.by_role[b["role"]].append(b)

    def _read_quests(self):
        for path in sorted(QUEST_ZONES.glob("*.quests.json")):
            front = path.name.endswith(".front.quests.json")
            zone = path.name[:-len(".front.quests.json" if front else ".quests.json")]
            self.quest_files.append({"name": path.name, "zone": zone, "front": front, "data": read_json(path)})

    def leader_zone(self, role):
        for b in self.by_role.get(role, ()):
            if b["source"] == "leader":
                return b["zone"]
        return None

    def objectives(self):
        """Every kill objective and quest drop: dict(file, zone, quest, index,
        what ("kill" | "drop" | "item"), roles, area (qualified or None),
        count, item)."""
        out = []
        for f in self.quest_files:
            for q in f["data"].get("quests") or []:
                for i, o in enumerate(q.get("objectives") or [], 1):
                    if o.get("type") == "kill" or (o.get("type") == "item" and o.get("roles")):
                        out.append({"file": f["name"], "zone": f["zone"], "quest": q, "index": i,
                                    "what": "kill" if o["type"] == "kill" else "item", "roles": list(o["roles"]),
                                    "area": area_ref(o.get("area"), f["zone"]), "count": o.get("count", 1),
                                    "item": o.get("item")})
                for i, d in enumerate(q.get("quest_drops") or [], 1):
                    out.append({"file": f["name"], "zone": f["zone"], "quest": q, "index": i, "what": "drop",
                                "roles": list(d.get("roles") or []), "area": area_ref(d.get("area"), f["zone"]),
                                "count": None, "item": d.get("item")})
        return out


def area_ref(ref, zone):
    """grug_quests validate.lua V.area_ref: "zone/area"; bare means the file's zone."""
    if not isinstance(ref, str) or not ref:
        return None
    return ref if "/" in ref else "%s/%s" % (zone, ref)


# --- the counting rules --------------------------------------------------------

def today_counts(obj, bearer):
    """grug_quests state.lua mob_counts."""
    if obj["area"] and bearer["area"] != obj["area"]:
        return False
    return bearer["role"] in obj["roles"]


def today_shown(world, obj):
    """labels.lua objective_subject: per role, its name in a leader's zone,
    else the area's zone, else the quest file's zone."""
    shown = []
    area_zone = obj["area"].split("/", 1)[0] if obj["area"] else None
    for role in obj["roles"]:
        zone = world.leader_zone(role) or area_zone or obj["zone"]
        shown.append(world.name_of({"role": role, "zone": zone}))
    return shown


def selected(world, obj):
    """The bearers an objective's roles and area pick (today's counting set)."""
    return [b for b in world.bearers if today_counts(obj, b)]


def names_shown(world, obj):
    """The proposed rule's label: the names of the selected bearers, per role
    in the objective's order (a world-variant group counts once: on a given
    world one captain stands there)."""
    out = []
    for role in obj["roles"]:
        names = []
        for b in selected(world, obj):
            if b["role"] == role and b["name"] not in names:
                names.append(b["name"])
        out.append(names)
    return out


# --- checks --------------------------------------------------------------------

def where(obj):
    return "%s %s %s %d" % (obj["file"], obj["quest"]["id"], obj["what"], obj["index"])


def check_today(world, objs):
    """missed / foreign / ghost per kill objective and quest drop."""
    findings = []
    for obj in objs:
        if obj["what"] == "item":
            continue
        shown = today_shown(world, obj)
        counting = [b for b in world.bearers if today_counts(obj, b)]
        shown_set = set(shown)
        for b in world.bearers:
            if b["name"] in shown_set and not today_counts(obj, b):
                findings.append(dict(code="missed", obj=obj, bearer=b, shown=shown))
        for b in counting:
            if b["name"] not in shown_set:
                findings.append(dict(code="foreign", obj=obj, bearer=b, shown=shown))
        for name in shown:
            if not any(b["name"] == name for b in counting):
                findings.append(dict(code="ghost", obj=obj, bearer=None, shown=shown, name=name))
    return findings


def plural_forms(name):
    last = name.split()[-1]
    stem = name[:len(name) - len(last)]
    forms = {last, last + "s", last + "es"}
    if last.endswith("y"):
        forms.add(last[:-1] + "ies")
    if last.endswith("f"):
        forms.add(last[:-1] + "ves")
    if last.endswith("fe"):
        forms.add(last[:-2] + "ves")
    if last.endswith("man"):
        forms.add(last[:-3] + "men")
    return [(stem + f).lower() for f in forms]


def text_says(quest, name, world=None):
    """Whether the quest's title or text says `name` (or its plural); a
    {name:<leader role>} placeholder (labels.lua) says its leader's name."""
    text = " ".join(str(quest.get(k) or "") for k in ("title", "text"))
    if world is not None:
        def fill(m):
            role = m.group(1).split("/")[-1]
            names = {b["name"] for b in world.by_role.get(role, ()) if b["source"] == "leader"}
            return " ".join(sorted(names)) or m.group(0)
        text = re.sub(r"\{name:([a-z0-9_/]+)\}", fill, text)
    text = text.lower()
    return any(re.search(r"(?<![a-z])%s(?![a-z])" % re.escape(form), text) for form in plural_forms(name))


def check_names(world, objs):
    """The proposed rule: what can still break once a mob counts by its name."""
    findings = []
    for obj in objs:
        if obj["what"] == "item":
            continue
        picked = selected(world, obj)
        per_role = names_shown(world, obj)
        names = sorted({n for ns in per_role for n in ns})
        if not picked:
            findings.append(dict(code="E-no-bearer", obj=obj, detail="the roles and area pick no mob"))
            continue
        for role, ns in zip(obj["roles"], per_role):
            groups = {b["variant"] or b["name"] for b in picked if b["role"] == role}
            if len(groups) > 1:
                findings.append(dict(code="W-two-names", obj=obj, detail="%s is shown as %s" % (
                    role, " or ".join(ns))))
        counting = [b for b in world.bearers if b["name"] in names]
        level = obj["quest"].get("level")
        lv = [b["levels"] for b in counting if b["levels"]]
        if lv and isinstance(level, int):
            lo, hi = min(x[0] for x in lv), max(x[1] for x in lv)
            if lo < level - LEVEL_SLACK or hi > level + LEVEL_SLACK:
                outside = sorted({b["key"] for b in counting if b["levels"] and (
                    b["levels"][0] < level - LEVEL_SLACK or b["levels"][1] > level + LEVEL_SLACK)})
                findings.append(dict(code="W-level-fit", obj=obj, detail="%s met at L%d-%d, quest level %d+-%d; "
                                     "outside: %s" % (" / ".join(names), lo, hi, level, LEVEL_SLACK,
                                                      ", ".join(outside[:4]) + (" ..." if len(outside) > 4 else ""))))
        for b in counting:
            if world.disposition(b["role"]) == "critter":
                findings.append(dict(code="E-critter-name", obj=obj, detail="%s is also a critter (%s)" % (
                    b["name"], b["key"])))
        unstatic = sorted({b["key"] for b in counting if b["levels"] is None and b not in picked})
        if unstatic:
            findings.append(dict(code="I-not-static", obj=obj, detail="%s also borne by %s (level or place not "
                                 "static)" % (" / ".join(names), ", ".join(unstatic))))
        # One finding per name; a world-variant group (a camp captain: one
        # of its race names stands there) once, when the text says none.
        groups = collections.defaultdict(set)
        for b in picked:
            groups[b["variant"] or b["name"]].add(b["name"])
        for group, members in sorted(groups.items()):
            if not any(text_says(obj["quest"], name, world) for name in members):
                findings.append(dict(code="W-text-name", obj=obj, detail="title and text never say %s" % (
                    " / ".join(repr(n) for n in sorted(members)) + (" (one per world: a placeholder)"
                                                                    if len(members) > 1 else ""))))
        extra = [b for b in counting if b not in picked]
        if extra:
            findings.append(dict(code="I-now-counts", obj=obj, detail="%d more bearer(s) of %s count: %s" % (
                len(extra), " / ".join(names), ", ".join(sorted(b["key"] for b in extra)[:4]) +
                (" ..." if len(extra) > 4 else ""))))
    # A runtime name lookup by (zone, role, level) must be unambiguous.
    by_slot = collections.defaultdict(list)
    for b in world.bearers:
        if b["source"] in ("kind", "camp", "leader") and b["levels"]:
            by_slot[(b["zone"], b["role"])].append(b)
    for (zone, role), rows in sorted(by_slot.items()):
        for i, a in enumerate(rows):
            for b in rows[i + 1:]:
                if a["name"] != b["name"] and a["levels"][0] <= b["levels"][1] and b["levels"][0] <= a["levels"][1]:
                    findings.append(dict(code="E-name-lookup", obj=None, detail="%s %s: %s (%s) and %s (%s) "
                                         "overlap in level" % (zone, role, a["name"], a["key"], b["name"], b["key"])))
    return findings


def role_drops_item(world, role, levels, item):
    sub = world.subtypes.get(role)
    if not sub or not levels:
        return None
    fam = world.drops.get(sub.get("drops") or sub["family"]) or {}
    bands = fam.get("bands") or {}
    rows = []
    for tier in range(drop_tier(levels[0]), drop_tier(levels[1]) + 1):
        rows += bands.get(str(tier)) or []
    if sub.get("leader"):
        rows += fam.get("leader_bonus") or []
    return any(r["item"] == item for r in rows)


def check_items(world, objs):
    """Item objectives with source roles (family loot): every source drops
    the item; which other names drop it in the same zone."""
    findings = []
    for obj in objs:
        if obj["what"] != "item" or not obj["item"]:
            continue
        picked = selected(world, obj)
        names = sorted({b["name"] for b in picked})
        for b in picked:
            if role_drops_item(world, b["role"], b["levels"], obj["item"]) is False:
                findings.append(dict(code="I-source-no-drop", obj=obj, detail="%s (%s) never drops %s" % (
                    b["name"], b["key"], obj["item"])))
        zone = obj["area"].split("/", 1)[0] if obj["area"] else obj["zone"]
        others = sorted({b["name"] for b in world.bearers if b["zone"] == zone and b["name"] not in names and
                         role_drops_item(world, b["role"], b["levels"], obj["item"])})
        if others:
            findings.append(dict(code="I-other-droppers", obj=obj, detail="%s also drops from %s (sources: %s)" % (
                obj["item"], ", ".join(others), ", ".join(names))))
    return findings


# --- the Round 37 comparison ---------------------------------------------------

def missed_pairs(world, findings):
    """(zone, role) pairs of area-targeted objectives with a missed same-named
    bearer, split by where the missed bearer is."""
    pairs = collections.defaultdict(lambda: {"same_zone": set(), "other_zone": set(), "objs": set(),
                                             "same_belt": False, "kinds": set(), "camps": set()})
    for f in findings:
        if f["code"] != "missed" or not f["obj"]["area"]:
            continue
        obj, b = f["obj"], f["bearer"]
        zone = obj["area"].split("/", 1)[0]
        for role in obj["roles"]:
            if b["role"] != role and world.name_of({"role": role, "zone": zone}) != b["name"]:
                continue
            p = pairs[(zone, role)]
            p["objs"].add("%s#%d" % (obj["quest"]["id"], obj["index"]))
            if b["zone"] == zone:
                p["same_zone"].add(b["key"] + "@" + (b.get("unit") or ""))
                target = [x for x in world.bearers if x["area"] == obj["area"] and x["role"] == role]
                if any(t["belt"] and t["belt"] == b["belt"] and b["source"] == "kind" for t in target):
                    p["same_belt"] = True
            else:
                p["other_zone"].add(b["key"])
    for (zone, role), p in pairs.items():
        for b in world.by_role.get(role, ()):
            if b["zone"] == zone:
                (p["kinds"] if b["source"] == "kind" else p["camps"] if b["source"] == "camp" else set()).add(b["unit"])
    return pairs


def compare_r37(pairs, path):
    if not Path(path).exists():
        return None
    rows = list(csvrows(path))
    r37 = {(r["zone"], r["role"]) for r in rows if r["area_quests"]}
    r37_kinds2 = {(r["zone"], r["role"]) for r in rows if r["area_quests"] and int(r["kinds"]) >= 2}
    r37_same = {(r["zone"], r["role"]) for r in rows if r["area_quests"] and int(r["kinds"]) >= 2 and
                int(r["targeted_area_shares_belt_with_other_kind"]) > 0}
    mine = {k for k, p in pairs.items() if p["same_zone"]}
    return {"r37_targeted": len(r37), "r37_kinds2": len(r37_kinds2), "r37_kinds2_same_belt": len(r37_same),
            "mine_same_zone": len(mine), "only_r37": sorted(r37 - mine), "only_mine": sorted(mine - r37)}


def csvrows(path):
    with open(path, encoding="utf-8") as handle:
        header = handle.readline().rstrip("\n").split("\t")
        keys = ["band", "zone", "role", "display", "kinds", "camps", "belts", "levels", "area_quests",
                "area_tags", "targeted_area_shares_belt_with_other_kind", "mentions", "regions"]
        if len(header) != len(keys):
            raise LoadError("%s: unexpected columns" % path)
        for line in handle:
            yield dict(zip(keys, line.rstrip("\n").split("\t")))


# --- facts that decide between the options --------------------------------------

def option_facts(world):
    """Counts the proposal cites: how the names would have to be keyed."""
    region = [b for b in world.bearers if b["source"] in ("kind", "camp", "leader")]
    bands = collections.defaultdict(set)
    zones_of = collections.defaultdict(set)
    for b in region:
        bands[(b["zone"], b["role"])].add(b["levels"])
        zones_of[b["role"]].add(b["zone"])

    def stretch_ok(ranges):
        ranges = sorted(ranges)
        tiers = {drop_tier(lo) for lo, hi in ranges} | {drop_tier(hi) for lo, hi in ranges}
        if len(tiers) > 1:
            return False
        reach = ranges[0][1]
        for lo, hi in ranges[1:]:
            if lo > reach + 1:
                return False
            reach = max(reach, hi)
        return True

    multi = {k: v for k, v in bands.items() if len(v) > 1}
    forced = {k: v for k, v in bands.items() if not stretch_ok(v)}
    role_forced = {r for r in zones_of if not stretch_ok({lv for z in zones_of[r] for lv in bands[(z, r)]})}
    return {
        "region_bearers": len(region),
        "zone_role_pairs": len(bands),
        "zone_role_pairs_multi_band": len(multi),
        "zone_role_pairs_rule_224_forces_two_names": len(forced),
        "forced_examples": sorted("%s/%s %s" % (z, r, " ".join("L%d-%d" % x for x in sorted(v)))
                                  for (z, r), v in forced.items())[:6],
        "roles_in_several_zones": sum(1 for r in zones_of if len(zones_of[r]) > 1),
        "roles_rule_224_forces_two_names_world_wide": len(role_forced),
        "slots_zone_role_band": sum(len(v) for v in bands.values()),
    }


# --- output ------------------------------------------------------------------------

def summarize(world, objs, mode, findings):
    counts = collections.Counter(f["code"] for f in findings)
    objs_by = collections.defaultdict(set)
    for f in findings:
        if f.get("obj") is not None:
            objs_by[f["code"]].add(where(f["obj"]))
    return {"mode": mode, "findings": dict(sorted(counts.items())),
            "objectives_affected": {k: len(v) for k, v in sorted(objs_by.items())}}


def finding_line(f):
    obj = f.get("obj")
    head = "%-16s %s" % (f["code"], where(obj) if obj else "-")
    if f["code"] in ("missed", "foreign"):
        b = f["bearer"]
        return "%s: shows %s; %s %r (%s, %s, area %s)" % (head, " or ".join(f["shown"]), "also" if f["code"] ==
                                                          "missed" else "counts", b["name"], b["key"], b["source"],
                                                          b["area"])
    if f["code"] == "ghost":
        return "%s: shows %r, which no counting mob bears" % (head, f["name"])
    return "%s: %s" % (head, f["detail"])


def self_test():
    """Tiny synthetic worlds: each case must raise exactly its codes."""
    def world(subtypes, rows, quests):
        w = object.__new__(World)
        w.subtypes = {r["role"]: dict({"disposition": "aggressive", "family": r["role"]}, **r) for r in subtypes}
        w.fixed, w.drops, w.bearers = {}, {}, []
        w.quest_files = [{"name": "z.quests.json", "zone": "z", "front": False, "data": {"quests": quests}}]
        for row in rows:
            w._add(**dict({"area": None, "belt": None, "unit": None, "clocks": []}, **row))
        w._index()
        return w

    boar = {"role": "boar", "display": "Pig", "levels": [1, 4]}
    kind = lambda unit, lv, **kw: dict(source="kind", zone="z", role="boar", levels=lv,  # noqa: E731
                                       area="z/" + unit, belt="b" + unit, unit=unit, **kw)
    quest = lambda **obj: {"id": "q", "level": 2, "title": "Pigs", "text": "Defeat pigs.",  # noqa: E731
                           "objectives": [dict({"type": "kill", "count": 1, "roles": ["boar"]}, **obj)]}
    cases = [
        ("area filter, same name elsewhere", "today", [boar], [kind("a", (1, 2)), kind("c", (1, 2))],
         [quest(area="a")], {"missed"}),
        ("no area: every bearer counts", "today", [boar], [kind("a", (1, 2)), kind("c", (3, 4))],
         [quest()], set()),
        ("renamed individual", "today", [], [dict(source="garrison", zone="z", role="captain_x", levels=(5, 5),
                                                  area="z/camp", own_name="Captain Ka", unit="camp")],
         [{"id": "q", "level": 5, "title": "t", "text": "Defeat Captain Ka.",
           "objectives": [{"type": "kill", "roles": ["captain_x"], "area": "z/camp"}]}], {"foreign", "ghost"}),
        ("names: one name, two levels", "names", [dict(boar, display_by_zone={})],
         [kind("a", (1, 2)), dict(kind("c", (1, 2)), own_name="Hog")], [quest(area="a")], {"E-name-lookup"}),
        ("names: nothing selected", "names", [boar], [kind("a", (1, 2))], [quest(area="zz")], {"E-no-bearer"}),
        ("names: area selects, all of the name count", "names", [boar], [kind("a", (1, 2)), kind("c", (1, 2))],
         [quest(area="a")], {"I-now-counts"}),
    ]
    failed = 0
    for label, mode, subs, rows, quests, want in cases:
        w = world(subs, rows, quests)
        objs = w.objectives()
        got = {f["code"] for f in (check_today(w, objs) if mode == "today" else check_names(w, objs))}
        ok = got == want
        failed += not ok
        print("%s %s: %s" % ("ok  " if ok else "FAIL", label, sorted(got) if not ok else mode))
    return 1 if failed else 0


ERRORS_TODAY = ("missed", "foreign", "ghost")
ERRORS_NAMES = ("E-no-bearer", "E-critter-name", "E-name-lookup")


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--mode", choices=("today", "names", "both"), default="both")
    ap.add_argument("--items", action="store_true", help="also report item objectives' family loot")
    ap.add_argument("--check", action="store_true",
                    help="exit 1 when the guarantee breaks (today: missed/foreign/ghost; names: E- codes)")
    ap.add_argument("--r37", default=str(R37_TSV), help="Round 37 multi_region_roles.tsv to compare with")
    ap.add_argument("--out", help="write findings.tsv, pairs.tsv and summary.json here")
    ap.add_argument("-v", "--verbose", action="store_true", help="print every finding")
    ap.add_argument("--self-test", action="store_true", help="run the synthetic cases and exit")
    args = ap.parse_args(argv)
    if args.self_test:
        return self_test()
    try:
        world = World()
    except (LoadError, C.LoadError, KeyError) as err:
        print("guarantee: %s" % err, file=sys.stderr)
        return 2
    objs = world.objectives()
    src = collections.Counter(b["source"] for b in world.bearers)
    kinds = collections.Counter(o["what"] for o in objs)
    print("Bearers: %d (%s); names: %d" % (len(world.bearers), ", ".join(
        "%s %d" % kv for kv in sorted(src.items())), len(world.by_name)))
    print("Objectives: kill %d (with area %d), quest drops %d, item objectives with source roles %d" % (
        kinds["kill"], sum(1 for o in objs if o["what"] == "kill" and o["area"]), kinds["drop"], kinds["item"]))
    report = {"bearers": dict(src), "objectives": dict(kinds), "facts": option_facts(world)}
    all_findings = []
    failed = False
    if args.mode in ("today", "both"):
        found = check_today(world, objs)
        all_findings += found
        s = summarize(world, objs, "today", found)
        pairs = missed_pairs(world, found)
        same = {k: p for k, p in pairs.items() if p["same_zone"]}
        other_only = {k: p for k, p in pairs.items() if not p["same_zone"] and p["other_zone"]}
        s["pairs"] = {
            "area_targeted_zone_role_with_missed_same_zone": len(same),
            "of_which_role_in_2plus_kinds": sum(1 for p in same.values() if len(p["kinds"]) >= 2),
            "of_which_camp_involved_only": sum(1 for p in same.values() if len(p["kinds"]) < 2),
            "of_which_same_belt_duplicate": sum(1 for p in same.values() if p["same_belt"]),
            "missed_only_in_other_zones": len(other_only),
            "with_any_missed": len(pairs),
        }
        cmp = compare_r37(pairs, args.r37)
        if cmp:
            s["r37"] = cmp
        report["today"] = s
        print("\n[today] count by role + `_grug_area`, label by the zone's display name")
        for code in ERRORS_TODAY:
            print("  %-8s %5d findings in %4d objectives" % (code, s["findings"].get(code, 0),
                                                            s["objectives_affected"].get(code, 0)))
        for k, v in s["pairs"].items():
            print("  %-48s %d" % (k, v))
        if cmp:
            print("  Round 37 analysis: %d area-targeted pairs (%d with the role in 2+ kinds, %d of them with a "
                  "same-belt duplicate); this tool, same zone: %d; only in R37: %s; only here: %s" % (
                      cmp["r37_targeted"], cmp["r37_kinds2"], cmp["r37_kinds2_same_belt"], cmp["mine_same_zone"],
                      cmp["only_r37"] or "none", cmp["only_mine"] or "none"))
        failed = failed or any(s["findings"].get(c) for c in ERRORS_TODAY)
        if args.out:
            os.makedirs(args.out, exist_ok=True)
            with open(os.path.join(args.out, "pairs.tsv"), "w", encoding="utf-8") as h:
                h.write("zone\trole\tkinds\tcamps\tsame_belt\tobjectives\tmissed_same_zone\tmissed_other_zones\n")
                for (zone, role), p in sorted(pairs.items()):
                    h.write("%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\n" % (
                        zone, role, len(p["kinds"]), len(p["camps"]), "yes" if p["same_belt"] else "no",
                        ",".join(sorted(p["objs"])), ",".join(sorted(p["same_zone"])),
                        ",".join(sorted(p["other_zone"]))))
    if args.mode in ("names", "both"):
        found = check_names(world, objs)
        all_findings += found
        s = summarize(world, objs, "names", found)
        report["names"] = s
        print("\n[names] count by the shown name (proposed); roles + area select the names")
        for code, n in s["findings"].items():
            print("  %-15s %5d findings in %4d objectives" % (code, n, s["objectives_affected"].get(code, 0)))
        failed = failed or any(s["findings"].get(c) for c in ERRORS_NAMES)
    if args.items:
        found = check_items(world, objs)
        all_findings += found
        s = summarize(world, objs, "items", found)
        report["items"] = s
        print("\n[items] item objectives with source roles (family loot, reported apart)")
        for code, n in s["findings"].items():
            print("  %-18s %5d findings in %4d objectives" % (code, n, s["objectives_affected"].get(code, 0)))
    f = report["facts"]
    print("\n[facts] region bearers %d; (zone, role) pairs %d, %d with 2+ level bands, %d where rule 2.2.4 "
          "forces two names; roles in several zones %d; slots (zone, role, band) %d" % (
              f["region_bearers"], f["zone_role_pairs"], f["zone_role_pairs_multi_band"],
              f["zone_role_pairs_rule_224_forces_two_names"], f["roles_in_several_zones"],
              f["slots_zone_role_band"]))
    if args.verbose:
        print()
        for x in all_findings:
            print(finding_line(x))
    if args.out:
        os.makedirs(args.out, exist_ok=True)
        with open(os.path.join(args.out, "findings.tsv"), "w", encoding="utf-8") as h:
            for x in all_findings:
                h.write(finding_line(x).replace(": ", "\t", 1) + "\n")
        with open(os.path.join(args.out, "summary.json"), "w", encoding="utf-8") as h:
            json.dump(report, h, indent=1, sort_keys=True, default=list)
            h.write("\n")
    return 1 if (args.check and failed) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

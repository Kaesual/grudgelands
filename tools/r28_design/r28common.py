"""Shared helpers for the Round 28 design tools (ledger.py, validate.py).

Python 3 standard library only. Formulas follow the Round 28 plan, Rulings
30-33, and the design frame docs/planning/round28-design-frame.md section 2.2:

  M(L)            = 25 + 5 L                (XP of one normal kill at level L)
  XP(L -> L + 1)  = round(M(L) * k(L), tens), k(L) = 8 + 0.29 (L - 1)
  kill XP         = M(min(mob level, player level + 5)) * tier multiplier,
                    0 when mob level <= player level - 10 (gray rule),
                    floor-divided by the number of eligible participants
  quest XP        = round(weight * M(quest level)); human +10 % on top
  gathering XP    = round(ratio * M(min(10 * tier, player level + 5))),
                    ratio ore 0.10, gem 0.20, fish 0.33
"""
import json
import math
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
DEFAULT_DESIGN = REPO / "docs" / "planning" / "round28" / "design"
DEFAULT_EXISTING = REPO / "docs" / "planning" / "round28" / "items" / "existing.json"

LEVEL_CAP = 60
TIER_MULT = {"normal": 1, "elite": 4, "rare": 6}
GATHER_RATIO = {"ore": 0.10, "gem": 0.20, "fish": 0.33}
GRAY_GAP = 10
LEVEL_OFFSET = 5
HUMAN_QUEST_BONUS = 1.1

STATS = ("str", "dex", "int", "attack_speed_percent", "crit_percent",
         "max_hp_percent", "max_mana_percent", "dodge_percent", "armor_rating")

# Bands of the frame's table (section 2.2): (from level, to level, questing
# target, reward-share target). "start" applies to the 1 -> 10 band.
BANDS = [
    (1, 10, 0.90, 0.40),
    (10, 20, 0.80, 0.40),
    (20, 30, 0.80, 0.40),
    (30, 40, 0.80, 0.40),
    (40, 50, 0.70, 0.35),
    (50, 60, 0.70, 0.35),
]

SNAKE = re.compile(r"^[a-z][a-z0-9_]*$")
ITEM_ID = re.compile(r"^[a-z][a-z0-9_]*:[a-z0-9_]+$")


def round_half_up(x):
    return int(math.floor(x + 0.5))


def M(level):
    return 25 + 5 * level


def k_factor(level):
    return 8 + 0.29 * (level - 1)


def level_xp(level):
    """XP needed to go from `level` to `level + 1`."""
    return 10 * int(math.floor(M(level) * k_factor(level) / 10 + 0.5))


CUMULATIVE = [0, 0]  # CUMULATIVE[L] = total XP at which level L starts
for _level in range(1, LEVEL_CAP):
    CUMULATIVE.append(CUMULATIVE[-1] + level_xp(_level))


def level_of(total_xp):
    level = 1
    while level < LEVEL_CAP and total_xp >= CUMULATIVE[level + 1]:
        level += 1
    return level


def xp_between(lo, hi):
    """XP to go from the start of level lo to the start of level hi."""
    return CUMULATIVE[hi] - CUMULATIVE[lo]


def ke_between(lo, hi):
    return sum(level_xp(level) / M(level) for level in range(lo, hi))


def kill_xp(mob_level, player_level, tier="normal", participants=1):
    if mob_level <= player_level - GRAY_GAP:
        return 0
    level = min(mob_level, player_level + LEVEL_OFFSET)
    return int(M(level) * TIER_MULT.get(tier, 1)) // participants


def expected_kill_xp(level_range, player_level, tier="normal", participants=1):
    lo, hi = level_range
    values = [kill_xp(level, player_level, tier, participants) for level in range(lo, hi + 1)]
    return sum(values) / len(values)


def quest_xp(weight, quest_level, human=False):
    xp = round_half_up(weight * M(quest_level))
    if human:
        xp = round_half_up(xp * HUMAN_QUEST_BONUS)
    return xp


def gathering_xp(kind, tier, player_level):
    reference = 10 * tier
    return round_half_up(GATHER_RATIO[kind] * M(min(reference, player_level + LEVEL_OFFSET)))


def band_of_level(level):
    for band in BANDS:
        if band[0] <= level < band[1]:
            return band
    return BANDS[-1]


# --- loading ---------------------------------------------------------------

class LoadError(Exception):
    pass


def read_json(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except json.JSONDecodeError as err:
        raise LoadError("%s: invalid JSON (line %d, column %d): %s" % (path, err.lineno, err.colno, err.msg))


def records(data, wanted_keys=()):
    """A catalogue file may be a list of records, an object holding one list
    (e.g. {"subtypes": [...]}), or a single record. Returns a list."""
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in wanted_keys:
            if isinstance(data.get(key), list):
                return data[key]
        lists = [value for value in data.values() if isinstance(value, list)
                 and value and all(isinstance(row, dict) for row in value)]
        if len(lists) == 1 and not any(key in data for key in ("role", "id", "family", "tier")):
            return lists[0]
        return [data]
    return []


def load_existing(path):
    path = Path(path)
    if not path.exists():
        raise LoadError("%s not found (run tools/r28_design/dump_items.sh)" % path)
    return read_json(path)


class Design:
    """Every design file under one design directory, loaded leniently; the
    validator reports structural problems, the ledger only needs the data."""

    def __init__(self, root):
        self.root = Path(root)
        self.files = {}
        self.errors = []
        catalog = self.root / "catalog"
        self.subtypes = self._catalog(catalog / "subtypes.json", ("subtypes", "roles"))
        self.items = self._catalog(catalog / "items.json", ("items",))
        self.drops = self._catalog(catalog / "drops.json", ("drops", "families"))
        self.enchants = self._catalog(catalog / "enchants.json", ("enchants", "tiers"))
        self.reagents = self._catalog(catalog / "reagents.json", ("reagents",))
        self.tints = self._tints(catalog / "tints.json")
        self.spawns = {}
        self.quests = {}
        zones = self.root / "zones"
        if zones.is_dir():
            for path in sorted(zones.glob("*.spawns.json")):
                zone = path.name[:-len(".spawns.json")]
                data = self._read(path)
                if data is not None:
                    self.spawns[zone] = data
            for path in sorted(zones.glob("*.quests.json")):
                zone = path.name[:-len(".quests.json")]
                data = self._read(path)
                if data is not None:
                    self.quests[zone] = data

    def _read(self, path):
        try:
            data = read_json(path)
        except LoadError as err:
            self.errors.append(str(err))
            return None
        self.files[str(path)] = data
        return data

    def _catalog(self, path, keys):
        if not path.exists():
            return None
        data = self._read(path)
        if data is None:
            return []
        return records(data, keys)

    def _tints(self, path):
        if not path.exists():
            return None
        data = self._read(path)
        if isinstance(data, dict) and not any(isinstance(v, list) for v in data.values()):
            return set(data)
        return {row.get("id") for row in records(data, ("tints",)) if isinstance(row, dict)}

    # Index helpers -------------------------------------------------------
    def subtype_map(self):
        return {row.get("role"): row for row in self.subtypes or [] if isinstance(row, dict)}

    def item_map(self):
        return {row.get("id"): row for row in self.items or [] if isinstance(row, dict)}

    def drop_map(self):
        return {row.get("family"): row for row in self.drops or [] if isinstance(row, dict)}

    def areas(self, zone):
        data = self.spawns.get(zone) or {}
        return {area.get("id"): area for area in data.get("areas") or [] if isinstance(area, dict)}


def split_area_ref(ref, own_zone):
    """'zone/area' -> (zone, area); a bare 'area' means the own zone."""
    if "/" in ref:
        zone, area = ref.split("/", 1)
        return zone, area
    return own_zone, ref


# --- zone atlas (optional) ------------------------------------------------

# The atlas's `role` text -> the short zone role the tools use.
ZONE_ROLES = (
    ("start zone", "start"),
    ("home zone 11-20", "home"),
    ("capital zone", "capital"),
    ("home zone 21-30", "heartland"),
    ("contested", "contested"),
    ("front zone", "front"),
    ("dragon island", "island"),
)
RACE_FACTION = {"dwarf": "accord", "human": "accord", "elf": "accord",
                "undead": "throng", "orc": "throng", "troll": "throng"}


def biome_id(name):
    """Atlas biome ids carry the `grug_` prefix; designers may omit it."""
    return name[5:] if isinstance(name, str) and name.startswith("grug_") else name


class Atlas:
    """The Round 28 zone atlas (docs/planning/round28/zones/<zone_id>.json,
    written by tools/r28_zone_atlas): zone ids, roles, level bands, faction
    and race track, anchors, quest NPCs, biomes and today's palette. Accepts
    the zones directory or one zone file."""

    def __init__(self, path):
        self.zones = {}
        path = Path(path)
        files = sorted(path.glob("*.json")) if path.is_dir() else [path]
        for file in files:
            data = read_json(file)
            if isinstance(data, dict) and isinstance(data.get("id"), str) and "anchors" in data:
                self._zone(data)
        if not self.zones:
            raise LoadError("%s: no zone atlas JSON (<zone_id>.json with id and anchors)" % path)
        self.npc_zone = {}
        for zid, zone in self.zones.items():
            for npc in zone["npcs"]:
                self.npc_zone[npc] = zid

    def _zone(self, rec):
        role_text = str(rec.get("role") or "")
        role = next((short for prefix, short in ZONE_ROLES if role_text.startswith(prefix)), role_text)
        race = rec.get("race_track")
        faction = rec.get("faction")
        if faction not in ("accord", "throng"):
            # Contested 31-40 zones belong to their race's faction (shared per
            # faction); front zones and islands to nobody.
            faction = RACE_FACTION.get(race) if role == "contested" else None
        anchors, anchor_kinds = {}, {}
        for anchor in rec.get("anchors") or []:
            aid = anchor.get("id")
            if not aid:
                continue
            anchor_kinds[aid] = anchor.get("kind")
            for ref in (aid, anchor.get("settlement_key"), anchor.get("slot")):
                if ref:
                    anchors.setdefault(ref, aid)
        npcs = {}
        for settlement in rec.get("settlements") or []:
            for npc in settlement.get("npcs") or []:
                if npc.get("npc_id") and npc.get("role") == "quest":
                    npcs[npc["npc_id"]] = {"settlement": settlement.get("key"),
                                           "anchor": settlement.get("anchor_id"),
                                           "socket": npc.get("socket"), "name": npc.get("npc_name")}
        biomes = {biome_id(b.get("id")) for b in (rec.get("biomes_authored") or []) +
                  (rec.get("biomes_measured") or []) if b.get("id")}
        palette = {}
        for spawn in rec.get("spawns") or []:
            ranges = [spawn[c]["levels"] for c in ("day", "night")
                      if isinstance(spawn.get(c), dict) and spawn[c].get("levels")]
            if spawn.get("mob") and ranges:
                palette[spawn["mob"]] = [min(r[0] for r in ranges), max(r[1] for r in ranges)]
        levels = None
        if isinstance(rec.get("level_min"), int) and isinstance(rec.get("level_max"), int):
            levels = [rec["level_min"], rec["level_max"]]
        self.zones[rec["id"]] = {
            "name": rec.get("name"), "role": role, "levels": levels, "faction": faction,
            "race": race, "anchors": anchors, "anchor_kinds": anchor_kinds, "npcs": npcs,
            "biomes": biomes, "palette": palette,
        }

    def all_npcs(self):
        return set(self.npc_zone)

    def resolve_anchor(self, zone, ref):
        """Anchor id for a reference (anchor id, settlement key or slot such
        as `start`, `capital`, `village_1`); `zone` means the zone hub."""
        info = self.zones.get(zone)
        if info is None:
            return None
        if ref == "zone":
            return "zone"
        return info["anchors"].get(ref)

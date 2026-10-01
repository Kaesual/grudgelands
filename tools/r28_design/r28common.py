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

ANCHOR_KEYS = ("anchors", "pois", "villages", "outposts", "mines", "camps",
               "hubs", "settlements", "rare_pads", "sockets_by_anchor")
NPC_KEYS = ("npcs", "quest_npcs", "givers", "quest_givers")


class Atlas:
    """Zone atlas facts the validator cross-checks: zone ids, anchor ids,
    quest NPC ids, logical biome ids, level bands. The loader is tolerant
    about the exact layout: a JSON file with a `zones` list/object, a single
    zone record, or a directory of per-zone JSON files."""

    def __init__(self, path):
        self.zones = {}
        path = Path(path)
        if path.is_dir():
            for file in sorted(path.rglob("*.json")):
                self._absorb(read_json(file), file.stem)
        else:
            self._absorb(read_json(path), path.stem)

    def _absorb(self, data, fallback_id):
        if isinstance(data, dict) and "zones" in data:
            zones = data["zones"]
            if isinstance(zones, dict):
                for zid, rec in zones.items():
                    if isinstance(rec, dict):
                        self._zone(rec, zid)
            elif isinstance(zones, list):
                for rec in zones:
                    if isinstance(rec, dict):
                        self._zone(rec, None)
        elif isinstance(data, dict) and (data.get("id") or data.get("zone")):
            self._zone(data, fallback_id)

    @staticmethod
    def _ids(value):
        out = set()
        if isinstance(value, dict):
            for key, row in value.items():
                out.add(row.get("id", key) if isinstance(row, dict) else key)
        elif isinstance(value, list):
            for row in value:
                if isinstance(row, str):
                    out.add(row)
                elif isinstance(row, dict):
                    rid = row.get("id") or row.get("npc") or row.get("anchor")
                    if rid:
                        out.add(rid)
        return out

    def _zone(self, rec, fallback_id):
        zid = rec.get("id") or rec.get("zone") or fallback_id
        if not isinstance(zid, str):
            return
        zone = self.zones.setdefault(zid, {"anchors": set(), "npcs": set(), "biomes": set(),
                                           "levels": None, "kind": None})
        for key in ANCHOR_KEYS:
            zone["anchors"] |= self._ids(rec.get(key))
        for key in NPC_KEYS:
            zone["npcs"] |= self._ids(rec.get(key))
        # NPCs may also sit inside hub/anchor records.
        for key in ANCHOR_KEYS:
            value = rec.get(key)
            rows = value.values() if isinstance(value, dict) else value if isinstance(value, list) else []
            for row in rows:
                if isinstance(row, dict):
                    for npc_key in NPC_KEYS:
                        zone["npcs"] |= self._ids(row.get(npc_key))
        zone["biomes"] |= self._ids(rec.get("biomes"))
        levels = rec.get("levels") or rec.get("band")
        if isinstance(levels, list) and len(levels) == 2 and all(isinstance(v, int) for v in levels):
            zone["levels"] = levels
        zone["kind"] = rec.get("kind") or rec.get("type") or zone["kind"]

    def all_npcs(self):
        out = set()
        for zone in self.zones.values():
            out |= zone["npcs"]
        return out

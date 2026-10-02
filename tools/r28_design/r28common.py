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
DEFAULT_MOBS = REPO / "docs" / "planning" / "round28" / "mobs" / "catalogue.json"

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
        # Where each catalogue row comes from: (file name, zone or None).
        # Zone catalogues (zones/<zone>.catalog.json) add leader roles and
        # quest-only items of one zone to the same catalogue.
        self.subtype_origin = [("catalog/subtypes.json", None)] * len(self.subtypes or [])
        self.item_origin = [("catalog/items.json", None)] * len(self.items or [])
        self.zone_catalogs = {}
        self._recipes = {}
        self.spawns = {}
        self.quests = {}
        # zones/<host_zone>.front.quests.json: front quests (owned by the
        # front design lane) given by the host zone's givers on line `front`.
        self.front = {}
        zones = self.root / "zones"
        if zones.is_dir():
            for path in sorted(zones.glob("*.spawns.json")):
                zone = path.name[:-len(".spawns.json")]
                data = self._read(path)
                if data is not None:
                    self.spawns[zone] = data
            for path in sorted(zones.glob("*.quests.json")):
                front = path.name.endswith(".front.quests.json")
                zone = path.name[:-len(".front.quests.json" if front else ".quests.json")]
                data = self._read(path)
                if data is not None:
                    (self.front if front else self.quests)[zone] = data
            for path in sorted(zones.glob("*.catalog.json")):
                zone = path.name[:-len(".catalog.json")]
                data = self._read(path)
                if data is None:
                    continue
                self.zone_catalogs[zone] = data
                if not isinstance(data, dict):
                    continue
                rel = "zones/" + path.name
                for key, rows, origin in (("subtypes", "subtypes", "subtype_origin"),
                                          ("items", "items", "item_origin")):
                    added = [row for row in data.get(key) or [] if isinstance(row, dict)]
                    if added:
                        setattr(self, rows, (getattr(self, rows) or []) + added)
                        setattr(self, origin, getattr(self, origin) + [(rel, zone)] * len(added))

    def zone_quests(self, zone, lines=None):
        """The zone's own quests plus its front file's, optionally only the
        given lines. Each quest is returned as stored."""
        out = []
        for data in (self.quests.get(zone), self.front.get(zone)):
            if isinstance(data, dict):
                out.extend(q for q in data.get("quests") or [] if isinstance(q, dict))
        if lines:
            out = [q for q in out if q.get("line") in lines]
        return out

    def quest_zones(self):
        return sorted(set(self.quests) | set(self.front))

    def role_levels(self, role):
        """A role's catalogue levels [lo, hi] (global or zone catalogue), or
        None (an existing mob without a sub-type row: unrestricted)."""
        levels = (self.subtype_map().get(role) or {}).get("levels")
        return levels if is_level_pair(levels) else None

    def is_leader(self, role):
        return (self.subtype_map().get(role) or {}).get("leader") is True

    def recipe(self, zone):
        """The zone's parsed recipe (see parse_recipe) and its errors; (None,
        []) without a recipe. Parsed in the catalogue's context, without the
        zone band (the validator adds that with an atlas)."""
        if zone not in self._recipes:
            data = self.spawns.get(zone)
            if not isinstance(data, dict) or "recipe" not in data:
                self._recipes[zone] = (None, [])
            else:
                self._recipes[zone] = parse_recipe(zone, data["recipe"], None, self.role_levels,
                                                   self.is_leader)
        return self._recipes[zone]

    def areas(self, zone):
        """The zone's quest areas: its recipe's kinds and camps, normalized
        (id -> unit_summary). A file without a recipe has none."""
        parsed = self.recipe(zone)[0]
        if parsed is None:
            return {}
        return {unit["id"]: unit_summary(unit) for unit in parsed["kinds"] + parsed["camps"]}

    def leaders(self, zone):
        """{role: {"role", "level", "respawn", "at"}}; level is None when the
        recipe gives the leader no level (a parse error)."""
        parsed = self.recipe(zone)[0]
        if parsed is None:
            return {}
        return {row["role"]: {"role": row["role"], "level": row["level"], "respawn": row["respawn"],
                              "at": row["at"]} for row in parsed["leaders"]}

    def find_leader(self, role, zone=None):
        """(zone, leader) for a leader role: the given zone first, then every
        zone (leader roles are unique fixed spots). None if no zone has it."""
        if zone is not None and role in self.leaders(zone):
            return zone, self.leaders(zone)[role]
        for other in sorted(self.spawns):
            if role in self.leaders(other):
                return other, self.leaders(other)[role]
        return None

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



def split_area_ref(ref, own_zone):
    """'zone/area' -> (zone, area); a bare 'area' means the own zone."""
    if "/" in ref:
        zone, area = ref.split("/", 1)
        return zone, area
    return own_zone, ref


# --- spawn recipe -----------------------------------------------------------
# Mirrors M.parse_recipe in mods/ENTITIES/grug_mobs/spawn_regions_core.lua
# (the game's parser and the reference). The game stops at the first error;
# this one collects as many as practical and skips the broken part.

RECIPE_TYPES = ("shore", "bank", "swamp", "forest", "highland", "open")
DENSITIES = ("sparse", "normal", "dense")
MAX_MINOR = 0.25  # a roster's minor role: at most this share of the weight
LEADER_PICKS = ("farthest_from_roads",)
SPAWNS_FILE_KEYS = ("zone", "palette", "recipe", "notes")
PALETTE_KEYS = ("families", "exact_mobs", "night_fallback", "boar", "lookalikes")
RECIPE_KEYS = ("from", "to", "belts", "camps", "leaders", "critters", "notes")
BELT_KEYS = ("id", "share", "levels", "max_from", "kinds", "notes")
KIND_KEYS = ("id", "name", "day", "night", "density", "notes")
CAMP_KEYS = ("id", "name", "belt", "site", "roster", "slots", "respawn", "min_player_distance", "apart",
             "notes")
# Camp POIs a recipe camp may stand on (the zone atlas's `camps` types);
# guard posts keep their guards.
CAMP_POIS = ("bandit", "mirefolk")
LEADER_KEYS = ("role", "at", "respawn", "notes")


class RecipeError(str):
    """One recipe finding: a string "path: message" that also carries the
    finding code (`code`), the JSON path inside the recipe (`path`) and the
    bare message (`msg`)."""

    def __new__(cls, code, path, msg):
        self = str.__new__(cls, "%s: %s" % (path or "recipe", msg))
        self.code, self.path, self.msg = code, path, msg
        return self


def _is_int(value, lo=None, hi=None):
    return (isinstance(value, int) and not isinstance(value, bool)
            and (lo is None or value >= lo) and (hi is None or value <= hi))


def _is_num(value):
    return (isinstance(value, (int, float)) and not isinstance(value, bool)
            and math.isfinite(value))


def is_level_pair(value):
    return (isinstance(value, list) and len(value) == 2 and all(_is_int(v, 1, LEVEL_CAP) for v in value)
            and value[0] <= value[1])


def parse_recipe(zone, recipe, band=None, role_levels=None, is_leader=None, pois=None):
    """Parses a zone's spawn recipe like the game. `band` = the zone's
    levels [lo, hi] (None: 1..60), `role_levels(role)` -> [lo, hi] or None
    (no catalogue row: unrestricted), `is_leader(role)` -> bool (None: not
    checked), `pois` = the zone's camp POIs [{"poi", "name", "anchor"}] (the
    atlas's `camps`; None: unknown, a camp site's POI is not checked).
    Returns (parsed, errors): parsed is None when the recipe is not an
    object, else {"zone", "from", "to", "belts", "kinds", "camps",
    "leaders", "critters"}; "from" is {"anchor": [ids]} or {"border":
    [zones]} or None, "to" {"border": [zones]} or {"core": True} or None; a
    kind is {"id", "name", "unit": "kind", "type", "belt", "density",
    "rosters": {"day", "night"}, "inherits", "levels_by_role", "roles",
    "levels"}, a camp the same with "unit": "camp", one roster for both
    clocks, its camp numbers and "site" ("generate" or {"poi", "name"}); a
    camp on a POI without its own belt has "belt" None and its roles' levels
    within the zone's band (the game cuts them to the belt the POI lies in
    on each seed); a leader is {"role", "at", "respawn", "level"}. errors:
    RecipeError strings."""
    errors = []
    band_known = band is not None
    band = band or [1, LEVEL_CAP]

    def err(code, path, msg):
        errors.append(RecipeError(code, path, msg))

    def cover(unit, value, levels, from_bottom, path):
        """Every zone runs to its round level (the user, 2026-10-02): a kind's
        roster covers its whole belt at each clock (no gap, bottom to top); a
        camp may start above its belt's bottom but has no gap and reaches the
        top. Rosters with a role that never meets the belt are reported
        already."""
        if value is None or levels is None:
            return
        rows = value.get("list") or []
        ranges = sorted(unit["levels_by_role"][r["role"]] for r in rows if r["role"] in unit["levels_by_role"])
        if not ranges or len(ranges) < len(rows):
            return
        reached = (levels[0] if from_bottom else ranges[0][0]) - 1
        for lo, hi in ranges:
            if lo > reached + 1:
                break
            reached = max(reached, hi)
        if reached < levels[1]:
            parts = ", ".join("L%d" % lo if lo == hi else "L%d-%d" % (lo, hi) for lo, hi in ranges)
            err("E-recipe-cover", path, "roles cover %s of the belt's L%d-%d: %s" % (
                parts, levels[0], levels[1], "every kind covers its whole belt at each clock" if from_bottom
                else "a camp has no gap and reaches its belt's top"))

    def known(row, allowed, path):
        bad = sorted(str(k) for k in row if k not in allowed)
        if bad:
            err("E-recipe-key", path, "unknown field %s" % ", ".join(bad))

    def snake(value):
        return isinstance(value, str) and SNAKE.match(value) is not None

    def roster(value, path):
        if not isinstance(value, list) or not 1 <= len(value) <= 2:
            err("E-recipe-roster", path, "a roster lists one main role and at most one minor role")
            return None
        out, seen = [], set()
        for i, row in enumerate(value):
            rpath = "%s[%d]" % (path, i)
            if not isinstance(row, dict) or not isinstance(row.get("role"), str) or not row["role"] \
                    or not _is_num(row.get("weight")) or row["weight"] <= 0:
                err("E-recipe-roster", rpath, "roster entries need a role and a positive weight")
                return None
            known(row, ("role", "weight"), rpath)
            if row["role"] in seen:
                err("E-recipe-roster", rpath, "role %s is listed twice" % row["role"])
                return None
            seen.add(row["role"])
            out.append({"role": row["role"], "weight": row["weight"]})
        total = sum(r["weight"] for r in out)
        if len(out) == 2 and min(r["weight"] for r in out) > total * MAX_MINOR + 1e-9:
            err("E-recipe-roster", path, "the minor role may hold at most %d %% of the weight"
                % round(MAX_MINOR * 100))
            return None
        return {"list": out, "total": total}

    def role_range(role, levels, path):
        """Levels of `role` inside `levels` (a belt); None when they never meet."""
        own = role_levels(role) if role_levels else None
        if not own:
            return [levels[0], levels[1]]
        lo, hi = max(levels[0], own[0]), min(levels[1], own[1])
        if lo > hi:
            err("E-recipe-levels", path, "%s (levels %d-%d) never meets the belt's levels %d-%d"
                % (role, own[0], own[1], levels[0], levels[1]))
            return None
        return [lo, hi]

    def unit_levels(unit, rosters, levels, path):
        unit["levels_by_role"], roles = {}, []
        for value in rosters:
            for row in (value or {}).get("list") or []:
                if row["role"] in roles:
                    continue
                roles.append(row["role"])
                if levels is None:
                    continue
                rng = role_range(row["role"], levels, path)
                if rng:
                    unit["levels_by_role"][row["role"]] = rng
        unit["roles"] = roles
        ranges = list(unit["levels_by_role"].values())
        unit["levels"] = [min(r[0] for r in ranges), max(r[1] for r in ranges)] if ranges else None

    if not isinstance(recipe, dict):
        err("E-recipe", "recipe", "recipe must be an object")
        return None, errors
    known(recipe, RECIPE_KEYS, "recipe")
    out = {"zone": zone, "from": None, "to": None, "belts": [], "kinds": [], "camps": [],
           "leaders": [], "critters": []}
    ids = {}  # kind and camp ids -> unit
    # from / to (Round 28 S2): `from` names anchors of the zone or the zones
    # whose land border is the entry; `to` the exit border or the zone's
    # core. A one-belt recipe may omit `to` (and then `from`).
    def zone_list(value, path):
        value = [value] if isinstance(value, str) else value
        if not isinstance(value, list) or not value:
            err("E-recipe", path, "needs a zone id or a list of zone ids")
            return []
        out_ids = []
        for i, other in enumerate(value):
            if not isinstance(other, str) or not other or other == zone:
                err("E-recipe-ref", "%s[%d]" % (path, i), "border entries are other zones' ids (not %r)" % other)
            else:
                out_ids.append(other)
        return out_ids

    one_belt = isinstance(recipe.get("belts"), list) and len(recipe["belts"]) == 1
    src, dst = recipe.get("from"), recipe.get("to")
    if dst is None and not one_belt:
        err("E-recipe", "to", "needs {\"border\": <zone id or list>} or {\"core\": true} (only a one-belt "
            "recipe may omit it)")
    if src is None and dst is not None:
        err("E-recipe", "from", "needs {\"anchor\": <slot or anchor id, or a list>} or {\"border\": <zone id "
            "or list>}")
    if src is not None:
        if not isinstance(src, dict) or ("anchor" in src) == ("border" in src):
            err("E-recipe", "from", "needs {\"anchor\": <slot or anchor id, or a list>} or {\"border\": "
                "<zone id or list>}")
        else:
            known(src, ("anchor", "border"), "from")
            if "anchor" in src:
                anchors = [src["anchor"]] if isinstance(src["anchor"], str) else src["anchor"]
                if not isinstance(anchors, list) or not anchors or \
                        not all(isinstance(a, str) and a for a in anchors):
                    err("E-recipe", "from.anchor", "anchor is a slot or anchor id, or a list of them")
                else:
                    out["from"] = {"anchor": list(anchors)}
            else:
                out["from"] = {"border": zone_list(src["border"], "from.border")}
    if dst is not None:
        if not isinstance(dst, dict) or ("border" in dst) == ("core" in dst):
            err("E-recipe", "to", "needs {\"border\": <zone id or list>} or {\"core\": true}")
        else:
            known(dst, ("border", "core"), "to")
            if "core" in dst:
                if dst["core"] is not True:
                    err("E-recipe", "to.core", "core must be true")
                else:
                    out["to"] = {"core": True}
            else:
                out["to"] = {"border": zone_list(dst["border"], "to.border")}
                for other in out["to"]["border"]:
                    if other in ((out["from"] or {}).get("border") or []):
                        err("E-recipe-ref", "to.border", "%s is both the entry and the exit border" % other)
    # belts
    belts = recipe.get("belts")
    if not isinstance(belts, list) or not belts:
        err("E-recipe", "belts", "belts must be a non-empty list")
        belts = []
    share_sum, belt_by_id = 0, {}
    for b, row in enumerate(belts):
        bpath = "belts[%d]" % b
        if not isinstance(row, dict):
            err("E-recipe", bpath, "belt must be an object")
            continue
        known(row, BELT_KEYS, bpath)
        if not snake(row.get("id")):
            err("E-id", bpath, "belt id %r must be snake_case" % row.get("id"))
            continue
        if row["id"] in belt_by_id:
            err("E-duplicate", bpath, "belt id %s is used twice" % row["id"])
            continue
        bpath = "belts[%s]" % row["id"]
        belt = {"index": b, "id": row["id"], "share": row.get("share"), "levels": None,
                "max_from": row.get("max_from"), "kinds": {}}
        belt_by_id[row["id"]] = belt
        out["belts"].append(belt)
        if not _is_num(row.get("share")) or row["share"] <= 0:
            err("E-recipe-shares", bpath + ".share", "share must be a positive percentage")
        else:
            share_sum += row["share"]
        if not is_level_pair(row.get("levels")):
            err("E-recipe-levels", bpath + ".levels", "levels must be [lo, hi] integers within 1..60")
        else:
            belt["levels"] = list(row["levels"])
            if row["levels"][0] < band[0] or row["levels"][1] > band[1]:
                err("E-recipe-levels", bpath + ".levels", "levels %d-%d leave the zone's band %d-%d"
                    % (row["levels"][0], row["levels"][1], band[0], band[1]))
        if row.get("max_from") is not None and (not _is_num(row["max_from"]) or row["max_from"] <= 0):
            err("E-recipe", bpath + ".max_from", "max_from must be a positive distance in nodes")
        kinds = row.get("kinds")
        if not isinstance(kinds, dict) or not isinstance(kinds.get("open"), dict):
            err("E-recipe-open", bpath + ".kinds", "every belt defines kinds.open (the parent of its other types)")
            kinds = kinds if isinstance(kinds, dict) else {}
        for t in sorted(kinds):
            if t not in RECIPE_TYPES:
                err("E-recipe-key", bpath + ".kinds", "kinds.%s is not a terrain type (%s)"
                    % (t, ", ".join(RECIPE_TYPES)))
        # The open entry first (the others inherit from it), then the rest.
        for t in ("open",) + tuple(x for x in RECIPE_TYPES if x != "open"):
            krow = kinds.get(t)
            if krow is None:
                continue
            kpath = "%s.kinds.%s" % (bpath, t)
            if not isinstance(krow, dict):
                err("E-recipe", kpath, "kind must be an object")
                continue
            known(krow, KIND_KEYS, kpath)
            if not snake(krow.get("id")):
                err("E-id", kpath, "kind id %r must be snake_case" % krow.get("id"))
                continue
            if krow["id"] in ids:
                err("E-duplicate", kpath, "kind id %s is used twice in the zone" % krow["id"])
                continue
            if not isinstance(krow.get("name"), str) or not krow["name"].strip():
                err("E-recipe", kpath, "kind needs a display name")
            if krow.get("density") not in DENSITIES:
                err("E-enum", kpath + ".density", "density %r must be sparse, normal or dense"
                    % krow.get("density"))
            kind = {"id": krow["id"], "name": krow.get("name"), "unit": "kind", "type": t,
                    "belt": belt["id"], "density": krow.get("density"), "rosters": {}, "inherits": []}
            for clock in ("day", "night"):
                value = krow.get(clock)
                if value == "open":
                    if t == "open":
                        err("E-recipe-open", "%s.%s" % (kpath, clock),
                            "%s \"open\" names the parent; the open kind lists roles" % clock)
                        kind["rosters"][clock] = None
                    else:
                        parent = belt["kinds"].get("open")
                        kind["rosters"][clock] = parent["rosters"].get(clock) if parent else None
                        kind["inherits"].append(clock)
                elif value is None:
                    err("E-recipe-roster", kpath, "needs a %s roster (a role list, or \"open\")" % clock)
                    kind["rosters"][clock] = None
                else:
                    kind["rosters"][clock] = roster(value, "%s.%s" % (kpath, clock))
            unit_levels(kind, [kind["rosters"]["day"], kind["rosters"]["night"]], belt["levels"], kpath)
            for clock in ("day", "night"):
                cover(kind, kind["rosters"][clock], belt["levels"], True, "%s.%s" % (kpath, clock))
            belt["kinds"][t] = kind
            out["kinds"].append(kind)
            ids[kind["id"]] = kind
    if belts and abs(share_sum - 100) > 1e-6:
        err("E-recipe-shares", "belts", "belt shares must add up to 100 (they add up to %s)" % share_sum)
    # The last belt (the exit) ends at the top of the zone's band, where the
    # band is known (the validator passes it with an atlas).
    last = out["belts"][-1] if out["belts"] else None
    if band_known and last and last["levels"] and last["levels"][1] != band[1]:
        err("E-recipe-cover", "belts[%s].levels" % last["id"], "the last belt ends at L%d, the zone's band at "
            "L%d: every zone runs to its round level" % (last["levels"][1], band[1]))
    # A camp's site: "generate" (default) or {"poi": <type>, "name": <POI
    # name>}, checked against the zone's camp POIs when they are known.
    poi_used = {}

    def camp_site(site, path):
        if site is None or site == "generate":
            return "generate"
        if not isinstance(site, dict) or not isinstance(site.get("poi"), str):
            err("E-recipe", path, "site is \"generate\" or {\"poi\": <type>, \"name\": <POI name>}")
            return None
        known(site, ("poi", "name"), path)
        if site["poi"] not in CAMP_POIS:
            err("E-recipe-poi", path + ".poi", "%r is not a mob camp POI (%s; guard posts keep their guards)"
                % (site["poi"], " or ".join(CAMP_POIS)))
            return None
        name = site.get("name")
        if name is not None and (not isinstance(name, str) or not name):
            err("E-recipe", path + ".name", "site.name must be the POI's name")
            return None
        out_site = {"poi": site["poi"], "name": name}
        if pois is None:
            return out_site
        names = [p["name"] for p in pois if p["poi"] == site["poi"]]
        found = [p for p in pois if p["poi"] == site["poi"] and (name is None or p["name"] == name)]
        if not found:
            err("E-recipe-poi", path, "the zone has no %s POI%s" % (site["poi"], (
                " named %s (its %s POIs: %s)" % (name, site["poi"], ", ".join(names) or "none")) if name else ""))
            return None
        if len(found) > 1:
            err("E-recipe-poi", path, "the zone has %d %s POIs (%s): site.name picks one"
                % (len(found), site["poi"], ", ".join(names)))
            return None
        key = found[0].get("anchor") or found[0]["name"]
        if key in poi_used:
            err("E-recipe-poi", path, "POI %s already holds camp %s" % (found[0]["name"], poi_used[key]))
            return None
        poi_used[key] = path
        out_site["name"] = found[0]["name"]
        return out_site

    # camps
    camps = recipe.get("camps")
    if camps is not None and not isinstance(camps, list):
        err("E-recipe", "camps", "camps must be a list")
        camps = []
    for c, row in enumerate(camps or []):
        cpath = "camps[%d]" % c
        if not isinstance(row, dict):
            err("E-recipe", cpath, "camp must be an object")
            continue
        known(row, CAMP_KEYS, cpath)
        if not snake(row.get("id")):
            err("E-id", cpath, "camp id %r must be snake_case" % row.get("id"))
            continue
        if row["id"] in ids:
            err("E-duplicate", cpath, "camp id %s is used twice among the zone's kinds and camps" % row["id"])
            continue
        cpath = "camps[%s]" % row["id"]
        if not isinstance(row.get("name"), str) or not row["name"].strip():
            err("E-recipe", cpath, "camp needs a display name")
        site = camp_site(row.get("site"), cpath + ".site")
        belt = belt_by_id.get(row.get("belt"))
        if belt is None and (row.get("belt") is not None or site == "generate"):
            err("E-recipe-ref", cpath + ".belt", "belt %r is not a belt of the recipe" % row.get("belt"))
        if not _is_int(row.get("slots"), 1):
            err("E-recipe", cpath + ".slots", "slots must be an integer >= 1")
        respawn = row.get("respawn")
        if not (isinstance(respawn, list) and len(respawn) == 2 and _is_int(respawn[0], 1)
                and _is_int(respawn[1], respawn[0])):
            err("E-recipe", cpath + ".respawn", "respawn must be [min, max] seconds")
        if not _is_num(row.get("min_player_distance")) or row["min_player_distance"] < 0:
            err("E-recipe", cpath + ".min_player_distance", "min_player_distance must be a distance in nodes")
        if site != "generate":
            if row.get("apart") is not None:
                err("E-recipe-key", cpath + ".apart", "apart places a generated site; a camp on a POI stands "
                    "where the POI is")
        elif not _is_int(row.get("apart"), 1):
            err("E-recipe", cpath + ".apart", "apart (cells between two camps) must be an integer >= 1")
        value = roster(row.get("roster"), cpath + ".roster")
        camp = {"id": row["id"], "name": row.get("name"), "unit": "camp", "type": None,
                "belt": belt["id"] if belt else None, "density": "dense",
                "rosters": {"day": value, "night": value}, "inherits": [], "slots": row.get("slots"),
                "respawn": respawn, "min_player_distance": row.get("min_player_distance"),
                "apart": row.get("apart"), "site": site}
        if belt is None and site not in (None, "generate"):
            # The POI's belt differs per seed: the roles' levels within the
            # zone's band here (the game cuts them to the belt and checks the
            # cover there).
            unit_levels(camp, [value], band, cpath)
        else:
            unit_levels(camp, [value], belt["levels"] if belt else None, cpath)
            cover(camp, value, belt["levels"] if belt else None, False, cpath + ".roster")
        out["camps"].append(camp)
        ids[camp["id"]] = camp
    # leaders
    leaders = recipe.get("leaders")
    if leaders is not None and not isinstance(leaders, list):
        err("E-recipe", "leaders", "leaders must be a list")
        leaders = []
    placed = set()
    for i, row in enumerate(leaders or []):
        lpath = "leaders[%d]" % i
        if not isinstance(row, dict) or not isinstance(row.get("role"), str) or not row["role"]:
            err("E-recipe", lpath, "leader needs a role")
            continue
        known(row, LEADER_KEYS, lpath)
        role = row["role"]
        lpath = "leaders[%s]" % role
        if role in placed:
            err("E-duplicate", lpath, "leader %s is placed twice" % role)
            continue
        placed.add(role)
        if is_leader is not None and not is_leader(role):
            err("E-leader-flag", lpath, "the catalogue does not mark %s a leader (\"leader\": true)" % role)
        if not _is_int(row.get("respawn"), 1):
            err("E-recipe", lpath + ".respawn", "respawn must be seconds (integer >= 1)")
        at = row.get("at")
        leader = {"role": role, "at": None, "respawn": row.get("respawn"), "level": None}
        out["leaders"].append(leader)
        if not isinstance(at, dict):
            err("E-recipe", lpath + ".at", "needs at: {\"camp\": id} or {\"kind\": id, \"pick\": ...}")
            continue
        known(at, ("camp", "kind", "pick"), lpath + ".at")
        belt = None
        if "camp" in at:
            if "kind" in at or "pick" in at:
                err("E-recipe", lpath + ".at", "at names a camp or a kind, not both")
                continue
            unit = ids.get(at["camp"]) if isinstance(at["camp"], str) else None
            if unit is None or unit["unit"] != "camp":
                err("E-recipe-ref", lpath + ".at.camp", "camp %r is not a camp of the recipe" % at["camp"])
                continue
            if unit["belt"] is None and unit["site"] not in (None, "generate"):
                # A leader's level is fixed (ruling 38); a POI's belt may
                # differ per seed.
                err("E-leader-camp-belt", lpath + ".at.camp", "camp %s states no belt: a leader's camp states its belt, "
                    "so the leader's level is the same on every seed" % unit["id"])
                continue
            leader["at"] = {"camp": at["camp"]}
        else:
            unit = ids.get(at.get("kind")) if isinstance(at.get("kind"), str) else None
            if unit is None or unit["unit"] != "kind":
                err("E-recipe-ref", lpath + ".at.kind", "kind %r is not a kind of the recipe" % at.get("kind"))
                continue
            if at.get("pick") not in LEADER_PICKS:
                err("E-recipe-ref", lpath + ".at.pick", "pick must be %s" % " or ".join(LEADER_PICKS))
                continue
            leader["at"] = {"kind": at["kind"], "pick": at["pick"]}
        belt = belt_by_id.get(unit["belt"])
        if belt and belt["levels"]:
            # The top of the leader's region, within the leader role's levels.
            rng = role_range(role, belt["levels"], lpath)
            if rng:
                leader["level"] = rng[1]
    # critters
    critters = recipe.get("critters")
    if critters is not None and not isinstance(critters, list):
        err("E-recipe", "critters", "critters must be a list of roles")
        critters = []
    for i, role in enumerate(critters or []):
        if not isinstance(role, str) or not role:
            err("E-recipe", "critters[%d]" % i, "critters must be a list of roles")
        elif role not in out["critters"]:
            out["critters"].append(role)
    return out, errors


def unit_summary(unit):
    """A kind or camp as a quest area: {"id", "name", "unit" ("kind" or
    "camp"), "kind", "camp" (flags), "belt", "type", "levels" ([lo, hi] or
    None), "levels_by_role", "roles", "species" ([{"role", "weight",
    "clock"}]: the day and night rosters; a camp's one roster has clock
    "both"), "density"}."""
    species = []
    if unit["unit"] == "camp":
        species = [dict(row, clock="both") for row in (unit["rosters"]["day"] or {}).get("list") or []]
    else:
        for clock in ("day", "night"):
            species += [dict(row, clock=clock) for row in (unit["rosters"][clock] or {}).get("list") or []]
    return {"id": unit["id"], "name": unit["name"], "unit": unit["unit"], "kind": unit["unit"] == "kind",
            "camp": unit["unit"] == "camp", "belt": unit["belt"], "type": unit["type"],
            "levels": unit["levels"], "levels_by_role": dict(unit["levels_by_role"]),
            "roles": list(unit["roles"]), "species": species, "density": unit["density"]}


def species_text(area):
    """"day: small_fox 3, aggressive_boar 1; night: rabid_rat 1" (a camp:
    "confused_bandit 1")."""
    parts = []
    for clock in ("both", "day", "night"):
        rows = [s for s in area.get("species") or [] if s.get("clock") == clock]
        if rows:
            text = ", ".join("%s %s" % (s["role"], s["weight"]) for s in rows)
            parts.append(text if clock == "both" else "%s: %s" % (clock, text))
    return "; ".join(parts)


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
        anchors, anchor_kinds, anchor_pos, anchor_refs = {}, {}, {}, {}
        for anchor in rec.get("anchors") or []:
            aid = anchor.get("id")
            if not aid:
                continue
            anchor_kinds[aid] = anchor.get("kind")
            # The spawn recipe's `from` names an anchor by id or slot only.
            for ref in (aid, anchor.get("slot")):
                if ref:
                    anchor_refs.setdefault(ref, aid)
            if isinstance(anchor.get("x"), int) and isinstance(anchor.get("z"), int):
                anchor_pos[aid] = (anchor["x"], anchor["z"])
            for ref in (aid, anchor.get("settlement_key"), anchor.get("slot")):
                if ref:
                    anchors.setdefault(ref, aid)
        npcs, free_sockets = {}, {}
        for settlement in rec.get("settlements") or []:
            for npc in settlement.get("npcs") or []:
                if npc.get("role") != "quest":
                    continue
                where = {"settlement": settlement.get("key"), "anchor": settlement.get("anchor_id"),
                         "socket": npc.get("socket"), "name": npc.get("npc_name")}
                if npc.get("npc_id"):
                    npcs[npc["npc_id"]] = where
                elif npc.get("socket"):
                    # A quest socket nobody occupies yet: a design may place a
                    # new giver there.
                    free_sockets[(settlement.get("anchor_id"), npc["socket"])] = where
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
        ext = rec.get("extent") or {}
        extent = None
        if all(isinstance(ext.get(k), int) for k in ("min_x", "max_x", "min_z", "max_z")):
            extent = (ext["min_x"], ext["max_x"], ext["min_z"], ext["max_z"])
        hub = rec.get("hub") or {}
        borders = [(b.get("zone"), (b["midpoint"]["x"], b["midpoint"]["z"]))
                   for b in rec.get("borders") or []
                   if isinstance(b.get("midpoint"), dict) and b.get("zone")]
        axis = str((rec.get("front") or {}).get("axis") or "")
        self.zones[rec["id"]] = {
            "name": rec.get("name"), "role": role, "levels": levels, "faction": faction,
            "race": race, "anchors": anchors, "anchor_kinds": anchor_kinds, "npcs": npcs,
            "anchor_refs": anchor_refs, "neighbours": {b.get("zone") for b in rec.get("borders") or [] if b.get("zone")},
            "biomes": biomes, "palette": palette, "anchor_pos": anchor_pos, "extent": extent,
            "hub": (hub["x"], hub["z"]) if isinstance(hub.get("x"), int) else None,
            "borders": borders, "front_sign": -1 if axis.startswith("-") else 1,
            "free_sockets": free_sockets,
            # Camp POIs (bandit, mirefolk, guard post) for a recipe camp's
            # site; None for an atlas file without `camps`.
            "pois": [{"poi": c.get("type"), "name": c.get("name"), "anchor": c.get("anchor")}
                     for c in rec["camps"] if isinstance(c, dict)] if isinstance(rec.get("camps"), list) else None,
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

    def position(self, zone, ref):
        """World (x, z) of an anchor reference, or the zone hub for `zone`."""
        info = self.zones.get(zone)
        if info is None:
            return None
        if ref == "zone":
            return info["hub"]
        aid = info["anchors"].get(ref)
        return info["anchor_pos"].get(aid) if aid else None

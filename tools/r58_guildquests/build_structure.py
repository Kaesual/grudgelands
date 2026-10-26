#!/usr/bin/env python3
"""Round 58 lane GUILDQUESTS: write the Miner's Guild's quest structure.

The guild and camp quests (docs/design/miners_guild.md §11, quests.md "The
Miner's Guild's quests") on the Round 57 quest foundation, with placeholder
texts ("[PH] ..."):

  * the gather quests, one id per tier T2-T6 and resource (two per tier), a
    variant per faction whose givers are the foreman roles foreman_tk ...
    foreman_t6 of that faction (every own camp whose lift reaches the tier);
    they live in the two guild files `charter_of_stone.quests.json` (every
    quest; its first variant is The Accord's) and `oathdelvers.quests.json`
    (the second variant's home: no quest of its own), whose zones are the
    guilds' ids, not map zones;
  * the follow-up per tier and faction (`guild_t<k>_report_<faction>`, a
    story quest): it requires both gather quests of its tier and is a travel
    quest to the guild leader of the giver zone's race region, one variant
    per zone with an own camp of tier >= k (the zone's foremen give it);
  * the camp hunts, one shared quest per camp band and clock (a variant per
    camp zone, the zone's foremen giving it): a role near the camp that the
    zone's own quests do not hunt yet, 8 by day or 3 after dark;
  * the raid on the enemy camp under construction (one quest, a variant per
    contested T4 zone, given by the own T4 foreman): its four guards and its captain.

The 20 surface camp zones' files get a hub with the camp's foreman and the
quests whose first variant is theirs; the four Battlegrounds zones (34-37)
get a quest file of their own (hubs for their eight foremen each) that holds
their camps' quests. Rerunning the script replaces every quest and hub it
wrote (ids `guild_*`, `camp_*`; hubs named after a camp) and leaves the rest
of each file as it is. After lane GUILDTEXT has written the real texts the
JSON files are the source of the texts: rerunning overwrites them with the
placeholders.

    python3 tools/r58_guildquests/build_structure.py [--check]

--check exits 1 when the files differ from what the script would write.
Since the texts landed the files differ by their texts, and since Round 59
reworked the band 11-20 the T2 camp hunt's target would be picked anew from
the band's new quests (the hunt is kept as shipped, round59-plan.md §2a
point 4): `--check --ids` compares what still holds, the guild and camp
quest ids each file carries and its hub ids.
Python 3 standard library only.
"""
import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QUESTS = REPO / "mods/PLAYER/grug_quests/data/zones"
SPAWNS = REPO / "mods/ENTITIES/grug_mobs/data/zones"
NAMES = REPO / "mods/ENTITIES/grug_mobs/data/names.json"
WP40 = REPO / "mods/MAPGEN/grug_mapgen/wp40"
NPCS = REPO / "mods/PLAYER/grug_quests/npcs.lua"
sys.path.insert(0, str(REPO / "tools/r28_design"))
import r28common as C  # noqa: E402

PH = "[PH] "
TBD = " Real text to follow."
FACTIONS = ("accord", "throng")
GUILD = {"accord": ("charter_of_stone", "The Charter of Stone"),
         "throng": ("oathdelvers", "The Oathdelvers")}
# A race region's capital, whose guild house holds that region's leader.
CAPITAL = {"dwarf": "dur_brannoc", "human": "highcourt", "elf": "lethariel",
           "undead": "nhal_veyr", "orc": "gor_drazhak", "troll": "kezamba"}
# The race columns across the front (the zones' hub x: -1800, 0, 1800): a
# Battlegrounds zone's race region is one faction's; the other faction's
# camps there report to the capital of the race across from it.
ACROSS = {"dwarf": "undead", "undead": "dwarf", "human": "orc", "orc": "human",
          "elf": "troll", "troll": "elf"}
DEPTH = {2: "second", 3: "third", 4: "fourth", 5: "fifth", 6: "sixth"}

# Two gather quests per tier: the tier's signature resource (the next tier's
# ingredient that peaks here) and its gem, by the item each digs out.
# (id suffix, item, count, display name). Counts are rough: about a quarter
# hour's digging in the tier's lower half (the yield model, miners_guild.md
# §9: ~7,000-9,000 rock seen an hour over one host per 96-256 / 512 nodes).
GATHER = {
    2: [("iron", "default:iron_lump", 20, "Iron Lump"), ("jade", "grug_materials:rough_jade", 4, "Rough Jade")],
    3: [("anthracite", "grug_materials:anthracite", 20, "Anthracite"),
        ("garnet", "grug_materials:rough_garnet", 4, "Rough Garnet")],
    4: [("silver", "grug_materials:silver_lump", 15, "Silver"),
        ("sapphire", "grug_materials:rough_sapphire", 4, "Rough Sapphire")],
    5: [("emberglass", "grug_materials:emberglass", 15, "Emberglass"),
        ("ruby", "grug_materials:rough_ruby", 4, "Rough Ruby")],
    6: [("crystal", "grug_materials:abyssal_crystal", 10, "Abyssal Crystal"),
        ("diamond", "grug_materials:rough_diamond", 4, "Rough Diamond")],
}
GATHER_WEIGHT = 4
REPORT_WEIGHT = 1.5
HUNT_WEIGHT = 3.5
HUNT_COUNT = 8
HUNT_NIGHT_COUNT = 3  # ruling 12: a night-only target asks about a third of the day count
HUNT_NIGHT_WEIGHT = 2.5
RAID_WEIGHT = 4  # four guards and the captain, as a higher war camp's raid
RAID_GUARDS = 4  # the camp's two gate and two yard posts
# The hunts' choice reward (the user, 2026-10-23: materials for the hunt):
# per camp tier one of the tier's hunted leather, its cloth or a bar of its
# metal, modest amounts; no vendor sells any of them (Round 57 ruling 28),
# so the hunts are a real source. (item, count)
HUNT_CHOICES = {
    2: [("grug_mobs:light_leather", 4), ("grug_mobs:linen_cloth", 3), ("grug_materials:iron_bar", 2)],
    3: [("grug_mobs:heavy_leather", 3), ("grug_mobs:heavy_cloth", 3), ("grug_materials:steel_bar", 2)],
    4: [("grug_mobs:scaled_hide", 3), ("grug_mobs:spider_silk", 3), ("grug_materials:silversteel_bar", 2)],
    5: [("grug_mobs:sleek_pelt", 3), ("grug_mobs:spider_silk", 4), ("grug_materials:embersteel_bar", 2)],
    6: [("grug_mobs:sleek_pelt", 4), ("grug_mobs:spider_silk", 5), ("grug_materials:abyssal_steel_bar", 1)],
}
RAID_LEVELS = (36, 40)  # min level, reward level (the camp site's captain is 40)

# The one small story seed per tier (story-arc decision §5), for GUILDTEXT.
SEEDS = {
    2: "The foreman sends a recommendation to the guild house, so that the player's name is known among "
       "the reliable helpers.",
    3: "The player carries an ordinary delivery copy confirmed by the guild and the supply office; the "
       "leader explains their joint seal (Charter of Stone) or their joint register marks (Oathdelvers).",
    4: "A short camp report names the affected drivers and workers beside the lost cargo and shows why the "
       "guild collects news from the border.",
    5: "A regular receipt records that a war camp's pay supplies both its fighters and its workers.",
    6: "A salvage record lists recovered names and personal belongings apart from usable material, and "
       "the guild house files it accordingly.",
}


# --- the world's camps ---------------------------------------------------
def short_id(zone_id):
    return re.sub(r"^(elandor|kragmar)_", "", zone_id)


def tier_of(level_min):
    return max(1, min(6, (level_min - 1) // 10 + 1))


def camp_rows():
    """(mining camps, war camps, camps under construction, zone records):
    the camps of grug_mapgen.mining_camps and its camps under construction
    as r28common reads them from the camp and PvP catalogues, dicts {id,
    zone, faction, race (None: a war camp's, rolled per world), band, tier}."""
    records = C.zone_records()
    camps = [dict(c, id=c["key"]) for c in C.mining_camps(records=records)]
    mining = [c for c in camps if c["key"].startswith("mining_camp_")]
    war = [c for c in camps if not c["key"].startswith("mining_camp_")]
    sites = [dict(s, id=s["key"]) for s in C.camp_sites()]
    assert (len(mining), len(war), len(sites)) == (20, 16, 6), "the camp catalogues differ"
    return mining, war, sites, records


def leaders():
    """{capital key: leader name} of npcs.lua's Round 58 block."""
    text = NPCS.read_text(encoding="utf-8")
    out = dict(re.findall(r'\{capital = "(\w+)", title = "([^"]+)"\}', text))
    assert len(out) == 6, "npcs.lua's guild leaders differ"
    return out


def foreman(camp_id):
    return "r58_foreman_" + camp_id


def leader_id(capital):
    return "r58_guild_leader_" + capital


def leader_of(zone_race, faction):
    """The capital whose leader a camp of `faction` in a zone of race region
    `zone_race` reports to: its own region's, else the region across the
    front from it (a Battlegrounds zone)."""
    race = zone_race if C.RACE_FACTION[zone_race] == faction else ACROSS[zone_race]
    assert C.RACE_FACTION[race] == faction
    return CAPITAL[race]


# --- the mob names the texts quote ---------------------------------------
_names = None


def mob_name(zone, role, lo, hi):
    """The name a role shows in `zone` at levels lo..hi (data/names.json)."""
    global _names
    if _names is None:
        _names = json.loads(NAMES.read_text(encoding="utf-8"))["names"]
    found = set()
    for key, name in _names.items():
        m = re.match(r"^([\w]+)/([\w.\-]+)/L(\d+)-(\d+)$", key)
        if m and m.group(1) == zone and m.group(2) == role and int(m.group(3)) <= hi and int(m.group(4)) >= lo:
            found.add(name)
    assert len(found) == 1, "%s/%s L%d-%d: names %s" % (zone, role, lo, hi, sorted(found))
    return found.pop()


_recipes = {}


def recipe(zone):
    if zone not in _recipes:
        path = SPAWNS / ("%s.spawns.json" % zone)
        _recipes[zone] = json.loads(path.read_text(encoding="utf-8"))["recipe"] if path.exists() else None
    return _recipes[zone]


def area_levels(zone, area_id):
    """The belt levels of a recipe kind or camp, or None (a garrison)."""
    r = recipe(zone)
    belts = {b["id"]: b for b in r["belts"]} if r else {}
    for belt in belts.values():
        if any(k["id"] == area_id for k in belt["kinds"].values()):
            return tuple(belt["levels"])
    for camp in (r or {}).get("camps") or []:
        if camp["id"] == area_id and camp.get("belt") in belts:
            return tuple(belts[camp["belt"]]["levels"])
    return None


def names_of(zone, role, lo, hi):
    """Every name a role shows in `zone` at levels lo..hi (data/names.json)."""
    global _names
    if _names is None:
        _names = json.loads(NAMES.read_text(encoding="utf-8"))["names"]
    out = set()
    for key, name in _names.items():
        m = re.match(r"^([\w]+)/([\w.\-]+)/L(\d+)-(\d+)$", key)
        if m and m.group(1) == zone and m.group(2) == role and int(m.group(3)) <= hi and int(m.group(4)) >= lo:
            out.add(name)
    return out


_hunted = None


def hunted(zone):
    """(roles, names) the zone's own quests already hunt: every kill
    objective of a quest that is no guild quest (zone and front files) whose
    area lies in `zone` (an objective without an area: its file's zone)."""
    global _hunted
    if _hunted is None:
        _hunted = {}
        for path in sorted(QUESTS.glob("*.quests.json")):
            data = json.loads(path.read_text(encoding="utf-8"))
            for q in data.get("quests") or []:
                if ours_quest(q):
                    continue
                for variant in q.get("variants") or [{"zone": data["zone"]}]:
                    overrides = variant.get("objectives") or []
                    for index, objective in enumerate(q["objectives"]):
                        if objective["type"] != "kill":
                            continue
                        own = overrides[index] if index < len(overrides) else {}
                        roles, area = own.get("roles", objective["roles"]), own.get("area", objective.get("area"))
                        where, area_id = (area.split("/", 1) if "/" in area else (variant["zone"], area)) \
                            if area else (variant["zone"], None)
                        if not recipe(where):
                            continue
                        levels = area_levels(where, area_id) if area_id else (1, 60)
                        if not levels:
                            continue
                        entry = _hunted.setdefault(where, (set(), set()))
                        for role in roles:
                            entry[0].add(role)
                            entry[1].update(names_of(where, role, levels[0], levels[1]))
    return _hunted.get(zone, (set(), set()))


LAND = ("open", "forest", "highland")


def hunt_candidates(zone, band):
    """[(night, kind id, role, levels, name)] for a camp's hunt, best first:
    in the zone's lowest belt (a mining camp and a war camp's low band sit
    in the zone's lowest level third) or its highest (a war camp's high
    band), every role of a quest-target kind's rosters that the zone's own
    quests do not hunt yet (by role and by name); a role met by day first
    (`night` false), then land kinds (open, forest, highland), the roster's
    main role before its minor one."""
    belt = recipe(zone)["belts"][-1 if band == "high" else 0]
    levels = tuple(belt["levels"])
    roles_done, names_done = hunted(zone)
    out = []
    for slot, kind in belt["kinds"].items():
        if slot.startswith(("sea", "lake", "river")) or not kind.get("quest_target"):
            continue

        def roster(clock):
            value = kind.get(clock)
            if value == "open":
                value = (belt["kinds"].get("open") or {}).get(clock)
            return value if isinstance(value, list) else []
        day = {r["role"] for r in roster("day")}
        for clock in ("day", "night"):
            for row in roster(clock):
                role = row["role"]
                names = names_of(zone, role, levels[0], levels[1])
                if role in roles_done or names & names_done or len(names) != 1:
                    continue
                night = role not in day
                rank = (night, slot not in LAND, -row["weight"], LAND.index(slot) if slot in LAND else 9)
                out.append((rank, (night, kind["id"], role, levels, next(iter(names)))))
    out.sort(key=lambda r: r[0])
    seen, best = set(), []
    for _, cand in out:
        if (cand[1], cand[2]) not in seen:
            seen.add((cand[1], cand[2]))
            best.append(cand)
    return best


def hunt_targets(zone, bands):
    """{band: candidate or None} for the camps of one zone (None: the zone's
    quests hunt every role near the camp; the first quest-target kind's main
    day role then stays, a duplicate the report names). A war camp zone's
    low and high camps hunt different names, fewest night hunts first."""
    lists = [hunt_candidates(zone, band) for band in bands]
    if len(bands) == 2 and lists[0] and lists[1]:
        pairs = [(lo[0] + hi[0], i + j, lo, hi) for i, lo in enumerate(lists[0]) for j, hi in enumerate(lists[1])
                 if lo[4] != hi[4]]
        if pairs:
            pairs.sort(key=lambda p: (p[0], p[1]))
            return {bands[0]: pairs[0][2], bands[1]: pairs[0][3]}
    return {band: (candidates[0] if candidates else None) for band, candidates in zip(bands, lists)}


def fallback_target(zone, band):
    """The first quest-target land kind's main day role (a duplicate of a
    zone quest's target)."""
    belt = recipe(zone)["belts"][-1 if band == "high" else 0]
    levels = tuple(belt["levels"])
    for slot in LAND:
        kind = belt["kinds"].get(slot)
        if kind and kind.get("quest_target") and isinstance(kind.get("day"), list):
            role = max(kind["day"], key=lambda r: r["weight"])["role"]
            return (False, kind["id"], role, levels, mob_name(zone, role, levels[0], levels[1]))
    raise AssertionError("%s: no quest-target land kind in belt %s" % (zone, belt["id"]))


# --- the quests ------------------------------------------------------------
def kill(roles, count, area):
    return {"type": "kill", "roles": list(roles), "count": count, "area": area}


def role_rows(tier, faction):
    return [{"role": "foreman_t%d" % k, "faction": faction} for k in range(tier, 7)]


def gather_quests():
    out = []
    for tier in range(2, 7):
        lo = (tier - 1) * 10 + 1
        for suffix, item, count, name in GATHER[tier]:
            variants = []
            for faction in FACTIONS:
                guild_zone, guild_name = GUILD[faction]
                variants.append({"zone": guild_zone, "givers": role_rows(tier, faction),
                                 "text": PH + "%s needs %s × %d from the %s depth. Take the camp's lift down to "
                                 "the tier's rooms and dig." % (guild_name, name, count, DEPTH[tier]) + TBD})
            out.append({
                "id": "guild_t%d_%s" % (tier, suffix), "line": "guild", "min_level": lo, "level": lo + 2,
                "requires": [], "title": PH + "%s × %d from the Depth" % (name, count),
                "text": PH + "The Miner's Guild needs %s × %d from the %s depth." % (name, count, DEPTH[tier]) + TBD,
                "objectives": [{"type": "item", "item": item, "count": count}],
                "variants": variants, "rewards": {"weight": GATHER_WEIGHT},
                "notes": "Round 58 gather quest, tier %d: offered at every own camp whose lift reaches the tier "
                         "(foreman_t%d ... foreman_t6), taken and turned in only there." % (tier, tier),
            })
    return out


def report_quests(mining, war, records, names):
    """The follow-up per tier and faction: one variant per zone with an own
    camp of tier >= k, a travel quest to that zone's leader."""
    out = []
    camps = mining + war
    for tier in range(2, 7):
        lo = (tier - 1) * 10 + 1
        gathers = ["guild_t%d_%s" % (tier, g[0]) for g in GATHER[tier]]
        for faction in FACTIONS:
            guild_name = GUILD[faction][1]
            zones = []
            for camp in sorted(camps, key=lambda c: (records[c["zone"]]["number"], c["id"])):
                if camp["faction"] == faction and camp["tier"] >= tier and camp["zone"] not in zones:
                    zones.append(camp["zone"])
            variants = []
            for zone in zones:
                capital = leader_of(records[zone]["race"], faction)
                givers = [foreman(c["id"]) for c in camps
                          if c["zone"] == zone and c["faction"] == faction and c["tier"] >= tier]
                variants.append({
                    "zone": zone, "givers": sorted(givers), "turnins": [leader_id(capital)],
                    "objectives": [{"npc": leader_id(capital)}],
                    "text": PH + "Both %s orders of the %s depth are filled. Take the camp's word to %s at the "
                    "Miner's Guild house." % (guild_name, DEPTH[tier], names[capital]) + TBD,
                    "completion": PH + "%s takes the camp's word for %s." % (names[capital], guild_name) + TBD,
                })
            first = variants[0]
            out.append({
                "id": "guild_t%d_report_%s" % (tier, faction), "line": "guild", "story": True,
                "min_level": lo, "level": lo + 2, "requires": gathers,
                "title": PH + "Word to the Guild House (%s depth)" % DEPTH[tier].capitalize(),
                "text": PH + "Take the camp's word to the Miner's Guild house." + TBD,
                "completion": PH + "The guild house takes the camp's word." + TBD,
                "objectives": [{"type": "talk", "npc": first["turnins"][0]}],
                "variants": variants, "rewards": {"weight": REPORT_WEIGHT},
                "notes": "Round 58 follow-up of tier %d (%s): story seed: %s" % (tier, guild_name, SEEDS[tier]),
            })
    return out


DUPLICATES = []  # (quest id, zone, role): a hunt that repeats a zone quest's target

# Hunts kept as shipped although the zone's reworked quests would let the
# script pick anew (round60-plan.md §3: the T3 camp hunts keep working):
# (tier, zone) -> (night, kind id, role). Round 60: Totemwater's quests no
# longer hunt its tapirs, so the script would move its night hunt to a day
# one; the shipped night hunt stays. Round 61: the band 31-40's quests hunt
# none of the zones' first-belt roles any more, so the script would pick the
# T4 hunts anew; the shipped ones stay (round61-plan.md §2 point 6).
KEPT_HUNTS = {(3, "kragmar_totemwater_reach"): (True, "jungle", "sullen_bog_ooze"),
              (4, "elandor_stormvault_heights"): (False, "eagle_crags", "storm_ridge_ram"),
              (4, "elandor_ashenward_march"): (False, "cinderwood", "briarpack_wolf"),
              (4, "elandor_glassroot_wilds"): (False, "fringe", "watchful_stag"),
              (4, "kragmar_blackwind_rise"): (True, "bonewood", "grave_web_spider"),
              (4, "kragmar_bannerbreak_mesa"): (False, "badlands", "marching_husk"),
              (4, "kragmar_thunderroot_wilds"): (True, "canopy", "stalking_panther")}


def hunt_quests(mining, war, records):
    """The camp hunts: per camp band (T2, T3 and T4 mining camps in the
    zone's lowest belt, T5 and T6 war camps by band: low the lowest belt,
    high the highest) one shared quest of the camps that hunt by day and
    one of those that can only hunt by night (a night-only target, a third
    of the day count, ruling 12), a variant per camp zone."""
    bands = [(tier, None, [c for c in mining if c["tier"] == tier]) for tier in (2, 3, 4)]
    for tier in (5, 6):
        for band in ("low", "high"):
            bands.append((tier, band, [c for c in war if c["tier"] == tier and c["band"] == band]))
    out = []
    del DUPLICATES[:]
    for tier, band, camps in bands:
        zones = []
        for camp in sorted(camps, key=lambda c: (records[c["zone"]]["number"], c["id"])):
            if camp["zone"] not in zones:
                zones.append(camp["zone"])
        groups = {False: [], True: []}
        for zone in zones:
            pick = hunt_targets(zone, ("low", "high") if band else (None,))[band]
            kept = None if band else KEPT_HUNTS.get((tier, zone))
            if kept:
                levels = tuple(recipe(zone)["belts"][0]["levels"])
                pick = (kept[0], kept[1], kept[2], levels, mob_name(zone, kept[2], levels[0], levels[1]))
            if pick is None:
                pick = fallback_target(zone, band)
                DUPLICATES.append(("t%d%s" % (tier, "_" + band if band else ""), zone, pick[2]))
            groups[pick[0]].append((zone, pick))
        for night in (False, True):
            if not groups[night]:
                continue
            qid = "camp_hunt_t%d%s%s" % (tier, "_" + band if band else "", "_night" if night else "")
            count = HUNT_NIGHT_COUNT if night else HUNT_COUNT
            when = "after dark" if night else "by day"
            variants, levels, base = [], set(), None
            for zone, (_, kind, role, belt, name) in groups[night]:
                levels.add(belt)
                area = "%s/%s" % (zone, kind)
                if base is None:
                    base = kill([role], count, area)
                variants.append({
                    "zone": zone, "givers": sorted(foreman(c["id"]) for c in camps if c["zone"] == zone),
                    "objectives": [{"roles": [role], "area": area}],
                    "text": PH + "Defeat %s × %d %s in the {name:%s}, which lie {zone_area:%s}, so the camp's "
                    "haulers can pass." % (name, count, when, kind, kind) + TBD,
                })
            assert len(levels) == 1, "%s: the variants' belts differ: %s" % (qid, sorted(levels))
            lo, hi = levels.pop()
            out.append({
                "id": qid, "line": "camp", "min_level": lo, "level": (lo + hi) // 2, "requires": [],
                "title": PH + "Clear the Camp's Surroundings (%s)" % qid.replace("camp_hunt_", "").replace("_", " "),
                "text": PH + "Beasts by the camp keep the haulers from the lift. Thin them out %s." % when + TBD,
                "objectives": [kill(base["roles"], count, base["area"])],
                "variants": variants, "rewards": {"weight": HUNT_NIGHT_WEIGHT if night else HUNT_WEIGHT,
                                                  "choices": [{"item": item, "count": n}
                                                              for item, n in HUNT_CHOICES[tier]]},
                "notes": "Round 58 camp hunt: one shared quest per camp band and clock, given by the camps' "
                         "foremen; a role near the camp (the camps' level belt L%d-%d) that the zone's own quests "
                         "do not hunt yet%s." % (lo, hi, ", met only at night (a third of the day count)"
                                                 if night else ", met by day"),
            })
    return out


def raid_quest(mining, sites, records):
    """The raid on the enemy camp under construction of each contested T4
    zone, given by that zone's own T4 foreman: its captain."""
    variants = []
    for site in sorted(sites, key=lambda s: records[s["zone"]]["number"]):
        own = [c for c in mining if c["zone"] == site["zone"]]
        assert len(own) == 1 and own[0]["faction"] != site["faction"] and own[0]["tier"] == 4
        variants.append({
            "zone": site["zone"], "givers": [foreman(own[0]["id"])],
            "objectives": [{"roles": ["guard_" + site["faction"]], "area": "%s/%s" % (site["zone"], site["id"])},
                           {"roles": ["captain_" + site["faction"]], "area": "%s/%s" % (site["zone"], site["id"])}],
            "text": PH + "The enemy raises the {name:%s} {dir_from_giver:%s}. Defeat %d of its %s Stakeguards "
            "and {captain:%s} before their banner holds." % (site["id"], site["id"], RAID_GUARDS,
                                                           site["faction"].capitalize(), site["id"]) + TBD,
        })
    guards, captain = variants[0]["objectives"]
    return {
        "id": "camp_site_raid", "line": "camp", "min_level": RAID_LEVELS[0], "level": RAID_LEVELS[1],
        "requires": [], "title": PH + "The Camp Under Construction",
        "text": PH + "The enemy raises a camp in our zone. Defeat its guards and its captain." + TBD,
        "objectives": [kill(guards["roles"], RAID_GUARDS, guards["area"]), kill(captain["roles"], 1, captain["area"])],
        "variants": variants, "rewards": {"weight": RAID_WEIGHT},
        "notes": "Round 58 raid: the camp under construction of each contested T4 zone, given by the own T4 "
                 "foreman; its four guards and its captain, as a war camp's raid.",
    }


# --- the files -------------------------------------------------------------
def ours_quest(q):
    return isinstance(q.get("id"), str) and re.match(r"^(guild_|camp_)", q["id"]) is not None


def build():
    mining, war, sites, records = camp_rows()
    names = leaders()
    quests = gather_quests() + report_quests(mining, war, records, names) + \
        hunt_quests(mining, war, records) + [raid_quest(mining, sites, records)]
    # A quest lives in the file of its first variant's zone.
    homes = {}
    for q in quests:
        homes.setdefault(q["variants"][0]["zone"], []).append(q)
    camp_hubs = {}
    for camp in mining + war:
        camp_hubs.setdefault(camp["zone"], []).append(camp)
    files = {}
    # The guild files (zones of their own: the guilds' ids).
    for faction in FACTIONS:
        zone, name = GUILD[faction]
        files[zone] = {"zone": zone, "reworked": True,
                       "identity": "%s's gather quests by depth tier, given at every own mining camp whose "
                                   "lift reaches the tier (Round 58); no map zone." % name,
                       "hubs": [], "quests": homes.pop(zone, [])}
    # The Battlegrounds zones: a file of their own, one hub per faction's camps.
    for zone in sorted({c["zone"] for c in war}, key=lambda z: records[z]["number"]):
        hubs = []
        for faction in FACTIONS:
            own = sorted((c for c in war if c["zone"] == zone and c["faction"] == faction), key=lambda c: c["id"])
            hubs.append({"id": "%s_%s_camps" % (short_id(zone).replace("front_", ""), faction), "anchor": "zone",
                         "givers": [{"npc": foreman(c["id"]), "lines": ["camp", "guild"]} for c in own]})
        files[zone] = {"zone": zone,
                       "identity": "The Battlegrounds' war camps of both factions, mining camps of the Miner's "
                                   "Guild since Round 58: their foremen's quests.",
                       "hubs": hubs, "quests": homes.pop(zone, [])}
    # The surface camp zones: the existing file plus the camp's hub and its quests.
    for camp in mining:
        zone = camp["zone"]
        path = QUESTS / ("%s.quests.json" % zone)
        data = json.loads(path.read_text(encoding="utf-8"))
        data["hubs"] = [h for h in data.get("hubs") or [] if h.get("id") != camp["id"]]
        data["hubs"].append({"id": camp["id"], "anchor": "zone",
                             "givers": [{"npc": foreman(camp["id"]), "lines": ["camp", "guild"]}]})
        data["quests"] = [q for q in data.get("quests") or [] if not ours_quest(q)] + homes.pop(zone, [])
        files[zone] = data
    assert not homes, "quests without a home file: %s" % sorted(homes)
    return {QUESTS / ("%s.quests.json" % zone): json.dumps(data, indent=2, ensure_ascii=False) + "\n"
            for zone, data in files.items()}


def ids(text):
    """A file's guild and camp quest ids and its hub ids."""
    data = json.loads(text)
    return (sorted(q["id"] for q in data.get("quests") or [] if ours_quest(q)),
            sorted(h["id"] for h in data.get("hubs") or []))


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 when the files differ")
    ap.add_argument("--ids", action="store_true", help="with --check: compare only the quest and hub ids")
    args = ap.parse_args(argv)
    files = build()
    same = (lambda a, b: ids(a) == ids(b)) if args.ids else (lambda a, b: a == b)
    differ = [p for p, text in sorted(files.items())
              if not p.exists() or not same(p.read_text(encoding="utf-8"), text)]
    if args.check:
        for p in differ:
            print("differs: %s" % p.relative_to(REPO))
        print("build_structure: %d files, %d differ%s" % (len(files), len(differ), " (ids)" if args.ids else ""))
        return 1 if differ else 0
    for p in differ:
        p.write_text(files[p], encoding="utf-8")
    print("build_structure: %d files, %d written" % (len(files), len(differ)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

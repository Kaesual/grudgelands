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
  * the camp hunts, one shared quest per camp band (a variant per camp zone,
    the zone's foremen giving it): 8 of the main day role of the zone's
    quest-target kind in the camp's level band;
  * the raid on the enemy camp under construction (one quest, a variant per
    contested T4 zone, given by the own T4 foreman): its captain.

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
RAID_WEIGHT = 3
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


def hunt_candidates(zone, band):
    """[(kind id, role, levels, name)] for a camp's hunt: in the zone's
    lowest belt (a mining camp and a war camp's low band sit in the zone's
    lowest level third) or its highest (a war camp's high band), every
    quest-target kind with a land day roster (open before forest and
    highland) and its main day role."""
    recipe = json.loads((SPAWNS / ("%s.spawns.json" % zone)).read_text(encoding="utf-8"))["recipe"]
    belt = recipe["belts"][-1 if band == "high" else 0]
    out = []
    for slot in ("open", "forest", "highland"):
        kind = belt["kinds"].get(slot)
        if kind and kind.get("quest_target") and isinstance(kind.get("day"), list):
            role = max(kind["day"], key=lambda r: r["weight"])["role"]
            levels = tuple(belt["levels"])
            out.append((kind["id"], role, levels, mob_name(zone, role, levels[0], levels[1])))
    assert out, "%s: no quest-target land kind in belt %s" % (zone, belt["id"])
    return out


def hunt_targets(zone, bands):
    """{band: candidate} for the camps of one zone: the first candidate per
    band, the bands' names told apart where the zone allows (a war camp
    zone's low and high camps hunt different names)."""
    lists = [hunt_candidates(zone, band) for band in bands]
    if len(bands) == 2:
        for low in lists[0]:
            for high in lists[1]:
                if low[3] != high[3]:
                    return {bands[0]: low, bands[1]: high}
    return {band: candidates[0] for band, candidates in zip(bands, lists)}


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
                                 "text": PH + "%s needs %d %s from the %s depth. Take the camp's lift down to "
                                 "the tier's rooms and dig." % (guild_name, count, name, DEPTH[tier]) + TBD})
            out.append({
                "id": "guild_t%d_%s" % (tier, suffix), "line": "guild", "min_level": lo, "level": lo + 2,
                "requires": [], "title": PH + "%d %s from the Depth" % (count, name),
                "text": PH + "The Miner's Guild needs %d %s from the %s depth." % (count, name, DEPTH[tier]) + TBD,
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


def hunt_quests(mining, war, records):
    """One shared hunt per camp band: T2, T3 and T4 mining camps (the
    zone's lowest belt), T5 and T6 war camps by band (low: the lowest belt,
    high: the highest)."""
    groups = []
    for tier in (2, 3, 4):
        groups.append(("camp_hunt_t%d" % tier, [c for c in mining if c["tier"] == tier], None))
    for tier in (5, 6):
        for band in ("low", "high"):
            groups.append(("camp_hunt_t%d_%s" % (tier, band),
                           [c for c in war if c["tier"] == tier and c["band"] == band], band))
    out = []
    for qid, camps, band in groups:
        zones = []
        for camp in sorted(camps, key=lambda c: (records[c["zone"]]["number"], c["id"])):
            if camp["zone"] not in zones:
                zones.append(camp["zone"])
        variants, levels = [], set()
        base = None
        for zone in zones:
            bands = ("low", "high") if band else (None,)
            kind, role, belt, name = hunt_targets(zone, bands)[band]
            levels.add(belt)
            givers = sorted(foreman(c["id"]) for c in camps if c["zone"] == zone)
            area = "%s/%s" % (zone, kind)
            if base is None:
                base = kill([role], HUNT_COUNT, area)
            variants.append({
                "zone": zone, "givers": givers,
                "objectives": [{"roles": [role], "area": area}],
                "text": PH + "Defeat %s × %d by day in the {name:%s}, which lie {zone_area:%s}, so the camp's "
                "haulers can pass." % (name, HUNT_COUNT, kind, kind) + TBD,
            })
        assert len(levels) == 1, "%s: the variants' belts differ: %s" % (qid, sorted(levels))
        lo, hi = levels.pop()
        level = (lo + hi) // 2
        out.append({
            "id": qid, "line": "camp", "min_level": lo, "level": level, "requires": [],
            "title": PH + "Clear the Camp's Surroundings (%s)" % qid.replace("camp_hunt_", "").replace("_", " "),
            "text": PH + "Beasts by the camp keep the haulers from the lift. Thin them out." + TBD,
            "objectives": [kill(base["roles"], HUNT_COUNT, base["area"])],
            "variants": variants, "rewards": {"weight": HUNT_WEIGHT},
            "notes": "Round 58 camp hunt: one shared quest per camp band, given by the camps' foremen; the main "
                     "day role of the zone's quest-target kind in the camps' level belt L%d-%d." % (lo, hi),
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
            "objectives": [{"roles": ["captain_" + site["faction"]], "area": "%s/%s" % (site["zone"], site["id"])}],
            "text": PH + "The enemy raises the {name:%s} {dir_from_giver:%s}. Defeat {captain:%s} before "
            "their banner holds." % (site["id"], site["id"], site["id"]) + TBD,
        })
    first = variants[0]["objectives"][0]
    return {
        "id": "camp_site_raid", "line": "camp", "min_level": RAID_LEVELS[0], "level": RAID_LEVELS[1],
        "requires": [], "title": PH + "The Camp Under Construction",
        "text": PH + "The enemy raises a camp in our zone. Defeat its captain." + TBD,
        "objectives": [kill(first["roles"], 1, first["area"])],
        "variants": variants, "rewards": {"weight": RAID_WEIGHT},
        "notes": "Round 58 raid: the camp under construction of each contested T4 zone, given by the own T4 "
                 "foreman; its captain (its guards carry no name slot yet).",
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


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 when the files differ")
    args = ap.parse_args(argv)
    files = build()
    differ = [p for p, text in sorted(files.items())
              if not p.exists() or p.read_text(encoding="utf-8") != text]
    if args.check:
        for p in differ:
            print("differs: %s" % p.relative_to(REPO))
        print("build_structure: %d files, %d differ" % (len(files), len(differ)))
        return 1 if differ else 0
    for p in differ:
        p.write_text(files[p], encoding="utf-8")
    print("build_structure: %d files, %d written" % (len(files), len(differ)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

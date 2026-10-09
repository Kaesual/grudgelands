#!/usr/bin/env python3
"""Round 45 lane MS: the end-to-end test of the migration step 0.45.0
(tools/migration/steps/v0_45_0.py and its join part in
grug_core/migrations.lua; contract R8, round workflow section 3 "Migration
steps"). It reuses Round 43 IT's harness (tools/r43_it/it.py: boots, the
container tool runs, the database dumps and the PASS table; client.py for
the joins).

  export   the 0.44.0 commit (OLD below) through `git archive` into the run
           directory: its game and its headless launcher
  boot S   the 0.44.0 game on a new world (SQLite player, auth and mod
           storage): "smith", "scribe" and "sleeper" join, the probe
           (grug_probe_r45_ms) builds them (see its header) and lists the
           0.44.0 registrations, against which the step's frozen tables are
           checked
  boot R   this checkout's game on the 0.44.0 world without the tool:
           refused by the guard, nothing written
  tool     the shipped command line in the platform runner's environment
           (Debian trixie, python3 3.13; tools/r43_it/Containerfile):
           --check, the migration, --check again; every slot of every list
           of every character compared with what the step must leave
  boot A   this checkout's game on the migrated world: smith and scribe
           join (sleeper stays offline); the probe records the inventory as
           loaded (before grug_core's runner) and as the join left it, every
           gear stack's item level, requirement, damage and tooltip, the
           armour, what is wearable and what was dropped

Prints the PASS/FAIL table, writes it with the trimmed evidence to the
evidence directory (default tools/r45_ms/evidence) and exits 0 only when
every check passed.

Usage: tools/r45_ms/run.sh [EVIDENCE_DIR]   (through the round's process
queue, one slot: the boots and the container runs go one at a time)
"""

import json
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import it  # noqa: E402  (tools/r43_it/it.py)
from migration import cli, data, world as worldmod  # noqa: E402
from migration.codec import ItemStack  # noqa: E402

STEP = cli._load_step("0.45.0", cli.STEPS / "v0_45_0.py")
OLD = "c913dbbe"           # main at 0.44.0, pushed (origin/main)
OLD_VERSION = "0.44.0"
GAME = it.GAME
DECLARED = json.loads((REPO / "tools" / "web_data" / "upgrade.json").read_text())["migrate"]
DUE = [v for v in DECLARED if cli.parse_version(v) > cli.parse_version(OLD_VERSION)]
PROBE = HERE / "grug_probe_r45_ms"
it.PROBE = PROBE
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern + r"|\[r45_ms_probe\]")
check = it.check
CHARACTERS = ("scribe", "sleeper", "smith")
MARKER = "grug_core:migrate:0.45.0"
SEEN = "grug_jobs:seen_items"

# The 0.44.0 item level and requirement of every unmodified item the probe
# places, written out here (not read from the step): the brackets were
# 3/1, 10/10, 20/20, 30/30, 40/40, 50/50 (grug_gear.BRACKETS at 0.44.0).
OLD_LEVELS = {
    "grug_gear:sword_bronze": (3, 1), "grug_gear:bow_bronze": (3, 1),
    "grug_gear:greataxe_bronze": (3, 1), "grug_gear:feet_metal_bronze": (3, 1),
    "grug_gear:shield_bronze": (3, 1), "grug_gear:chest_metal_iron": (10, 10),
    "grug_gear:manawell_t2": (10, 10), "grug_gear:bow_iron": (10, 10),
    "grug_gear:head_metal_steel": (20, 20), "grug_gear:wand_steel": (20, 20),
    "grug_gear:dagger_silversteel": (30, 30), "grug_gear:spellbook_embersteel": (40, 40),
    "grug_gear:chest_cloth_silk": (40, 40), "grug_gear:mercy_seal_t6": (50, 50),
    "grug_gear:legs_cloth_stormweave": (50, 50),
}
# Where the step moves the craft stacks (craft slot -> (list, slot), 1-based):
# smith's two free slots are the ones its mixtures leave (main[13], bag 1
# slot 2), everything else stays in the grid; scribe and sleeper have room.
MOVES = {
    "smith": {2: ("main", 13), 3: ("grug_bag1_content", 2)},
    "scribe": {2: ("main", 10), 3: ("main", 11)},
    "sleeper": {5: ("main", 10)},
}
# ST's mixture ids (r45 ST report): 40.
MIXTURES = sorted(
    ["grug_alchemy:mixture_%s_t%d" % (kind, tier)
     for kind in ("potion_healing", "potion_mana", "elixir_vigor", "elixir_focus",
                  "elixir_precision", "elixir_stoneskin") for tier in range(1, 7)]
    + ["grug_alchemy:mixture_" + name for name in ("potion_antivenom", "potion_swiftness",
                                                   "potion_cave", "elixir_deepwater")])


# -- reading the world (the server stopped) ----------------------------------

def state(world):
    """Every character's inventory (list -> [item strings]), list sizes and
    player meta, read through the tool's data API."""
    backends = worldmod.open_world(str(world))
    try:
        api = data.World(backends, "read")
        out = {}
        for name in api.characters():
            lists = api.get_inventory(name)
            out[name] = {
                "inv": {k: [s.to_string() for s in v.items] for k, v in lists.items()},
                "meta": api.get_meta(name),
            }
        return out
    finally:
        worldmod.close_world(backends)


def parse(text):
    return ItemStack.parse(text) if text else ItemStack("", 0)


def name_of(text):
    return parse(text).name


def same(a, b):
    """Two item strings hold the same stack."""
    if not a or not b:
        return (a or "") == (b or "")
    x, y = parse(a), parse(b)
    return (x.name, x.count, x.wear, x.meta) == (y.name, y.count, y.wear, y.meta)


LEVEL_KEYS = ("grug_ilvl", "grug_req_level", "grug_ench", "tool_capabilities",
              "_grug_repair_caps")


def same_levels(a, b, keys=LEVEL_KEYS):
    """Two item strings hold the same item, count, wear, item level,
    requirement, enchants and capabilities (tooltips may differ; the game's
    tooltip refresh also writes a missing quality as Common)."""
    x, y = parse(a), parse(b)
    return (x.name, x.count, x.wear) == (y.name, y.count, y.wear) and all(
        x.meta.get(k) == y.meta.get(k) for k in keys)


def same_lists(a, b, lists=None):
    names = lists if lists is not None else sorted(set(a) | set(b))
    bad = []
    for listname in names:
        x, y = a.get(listname), b.get(listname)
        if x is None or y is None or len(x) != len(y):
            bad.append("%s: size %s vs %s" % (listname, x and len(x), y and len(y)))
            continue
        bad += ["%s[%d]: %r vs %r" % (listname, i + 1, p[:70], q[:70])
                for i, (p, q) in enumerate(zip(x, y)) if not same(p, q)]
    return bad


def mixtures_in(inv):
    return ["%s[%d]" % (k, i + 1) for k, stacks in inv.items()
            for i, text in enumerate(stacks) if name_of(text).startswith(STEP.MIXTURE_PREFIX)]


def probe_lists(observed):
    return {k: v.get("stacks") or [] for k, v in (observed or {}).items()}


def with_pin(text, ilvl, req):
    stack = parse(text)
    stack.meta["grug_ilvl"] = str(ilvl)
    stack.meta["grug_req_level"] = str(req)
    return stack.to_string()


def expected_after(name, before, layout):
    """What the step must leave of `name`'s inventory: built from the probe's
    layout and the tables above."""
    inv = {k: list(v) for k, v in before.items()}
    for e in layout:
        slot = e["slot"] - 1
        if e["role"] == "mixture":
            inv[e["list"]][slot] = ""
        elif e["role"] == "pin":
            inv[e["list"]][slot] = with_pin(inv[e["list"]][slot], *OLD_LEVELS[name_of(e["item"])])
    for craft_slot, (listname, slot) in MOVES[name].items():
        text = inv["craft"][craft_slot - 1]
        if name_of(text) in OLD_LEVELS:
            text = with_pin(text, *OLD_LEVELS[name_of(text)])
        inv[listname][slot - 1] = text
        inv["craft"][craft_slot - 1] = ""
    if not any(inv["craft"]):
        inv["craft"] = []
    inv["craftpreview"] = [""] * len(inv.get("craftpreview", []))
    return inv


# -- the scenario -------------------------------------------------------------

def export_old(run):
    target = run.root / "v0_44_0"
    target.mkdir()
    archive = subprocess.run(
        ["git", "-C", str(REPO), "archive", OLD, "game.conf", "mods", "minetest.conf",
         "settingtypes.txt", "menu", "tools/luanti_headless.sh"],
        capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    version = re.search(r"^version\s*=\s*(\S+)", (target / "game.conf").read_text(), re.M)
    check("setup", "the 0.44.0 commit %s exported (its game and launcher)" % OLD,
          version and version.group(1) == OLD_VERSION, version and version.group(1))
    return target / "tools" / "luanti_headless.sh"


def check_names(reg, game):
    leveled = reg.get("leveled") or {}
    gear = {n: (v.get("ilvl"), v.get("req")) for n, v in leveled.items() if v.get("equip")}
    if game == OLD_VERSION:
        diff = sorted(set(gear.items()) ^ set(STEP.GEAR.items()))
        check("names", "0.44.0: the equipment with an item level is exactly the step's %d "
                       "gear items with their (item level, requirement)" % len(STEP.GEAR),
              gear and not diff, json.dumps(diff[:8]))
        check("names", "0.44.0: no equipment without an item level of its definition",
              not reg.get("unleveled_equipment"), json.dumps(reg.get("unleveled_equipment")))
        check("names", "0.44.0: the bags and their sizes are the step's",
              reg.get("bags") == STEP.BAG_SLOTS, json.dumps(reg.get("bags")))
        check("names", "0.44.0: the hotbar has %d slots and there are %d bag slots, as the "
                       "step's move order assumes" % (STEP.HOTBAR, STEP.BAG_COUNT),
              reg.get("hotbar_size") == STEP.HOTBAR and reg.get("bag_count") == STEP.BAG_COUNT)
    else:
        same_values = sorted(n for n, v in STEP.GEAR.items() if gear.get(n) == v)
        check("names", "%s: every gear item of the step now has another definition value "
                       "(the pin keeps each)" % game,
              set(gear) >= set(STEP.GEAR) and not same_values, json.dumps(same_values[:8]))
        check("names", "%s: the bag sizes are unchanged (the join sizes bag lists by them)"
              % game, reg.get("bags") == STEP.BAG_SLOTS, json.dumps(reg.get("bags")))
    check("names", "%s: the items under %s (and the mixture group) are ST's 40 mixtures"
          % (game, STEP.MIXTURE_PREFIX),
          reg.get("mixtures") == MIXTURES, json.dumps(reg.get("mixtures")))
    check("names", "%s: no alias names a gear item, a mixture or a bag" % game,
          not reg.get("aliases"), json.dumps(reg.get("aliases")))


def gear_at(observed, listname, slot):
    lists = (observed or {}).get("inventory") or {}
    return ((lists.get(listname) or {}).get("gear") or {}).get(str(slot)) or {}


def stack_at(observed, listname, slot):
    lists = (observed or {}).get("inventory") or {}
    stacks = (lists.get(listname) or {}).get("stacks") or []
    return stacks[slot - 1] if slot <= len(stacks) else ""


def find(observed, item):
    """(list, slot) of every stack of `item` the character holds."""
    out = []
    for listname, entry in ((observed or {}).get("inventory") or {}).items():
        for i, text in enumerate(entry.get("stacks") or []):
            if name_of(text) == item:
                out.append((listname, i + 1))
    return out


def tooltip_ok(facts, ilvl, req):
    text = facts.get("description") or ""
    return ("Item level %d" % ilvl) in text and (
        req <= 1 and "Requires level" not in text or ("Requires level %d" % req) in text)


def scenario(run):
    w = run.root / "w"
    it.write_world_mt(w, mod_storage=True)

    # Boot S: the 0.44.0 game builds the world.
    it.LAUNCHER = export_old(run)
    s = it.boot(run, w, "setup_0.44.0", joins=CHARACTERS)
    obs = s.obs or {}
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    layouts = {n: (joins.get(n) or {}).get("layout") or {} for n in CHARACTERS}
    check("setup", "boot S (0.44.0): a new world, smith, scribe and sleeper joined, were "
                   "built and left",
          s.rc == 0 and obs.get("leaves") == 3 and sorted(joins) == list(CHARACTERS)
          and all(layouts[n].get("entries") for n in CHARACTERS)
          and it.storage(w, "grug_core").get("world_version") == OLD_VERSION,
          "rc %d joins %s layout %s" % (s.rc, s.joins,
                                        json.dumps([layouts[n].get("error") for n in CHARACTERS])))
    if not all(layouts[n].get("entries") for n in CHARACTERS):
        return
    check_names(obs.get("registrations") or {}, OLD_VERSION)

    before = state(w)
    misplaced = []
    for n in CHARACTERS:
        inv = before.get(n, {}).get("inv", {})
        for e in layouts[n]["entries"]:
            got = (inv.get(e["list"]) or [""] * e["slot"])[e["slot"] - 1]
            # The 0.44.0 game's own refreshes may rewrite tooltips and looks.
            if not same_levels(got, e["item"]):
                misplaced.append("%s %s[%d] %s: %r" % (n, e["list"], e["slot"], e["item"][:50],
                                                       got[:50]))
    check("setup", "saved: every placed stack as built (%d stacks)" % sum(
        len(layouts[n]["entries"]) for n in CHARACTERS), not misplaced, json.dumps(misplaced[:6]))
    smith_built = (joins.get("smith") or {}).get("built") or {}
    check("setup", "saved: smith is a level-10 warrior wearing an Iron Chestplate a fresh "
                   "copy of which 0.44.0 also allows (10 / 10)",
          layouts["smith"].get("class") == "warrior" and smith_built.get("level") == 10
          and (smith_built.get("equipment") or {}).get("grug_chest", {}).get("fresh_wearable"),
          json.dumps({"class": layouts["smith"].get("class"),
                      "level": smith_built.get("level")}))
    check("setup", "saved: the grids hold 9 (smith), 3 (scribe) and 1 (sleeper) stacks; "
                   "seen-items meta on smith and sleeper",
          [sum(1 for x in before[n]["inv"].get("craft", []) if x) for n in CHARACTERS]
          == [3, 1, 9] and all(before[n]["meta"].get(SEEN) for n in ("smith", "sleeper")))
    dump_before = it.dump(w)

    # Boot R: the new game without the tool.
    it.LAUNCHER = REPO / "tools" / "luanti_headless.sh"
    r = it.boot(run, w, "refused_%s" % GAME)
    names = ", ".join(DUE)
    check("guard", "boot R (%s): the 0.44.0 world without the tool is refused, naming the "
                   "step and the command line" % GAME,
          it.refused_with(r, "This world is at version %s and needs the migration step%s %s "
                             "before this game's version %s can start it"
                          % (OLD_VERSION, "s" if len(DUE) > 1 else "", names, GAME),
                          "python3 tools/migrate.py --world %s" % w), "rc %d" % r.rc)
    check("guard", "the refused start wrote nothing", it.dump(w) == dump_before)

    # The tool, as the platform runs it.
    rc, ev = it.tool(run, "check_before", w, "-", check_mode=True, shipped=True)
    done = it.last(ev)
    check("tool", "--check: world %s, due %s, write access on all three backends, nothing "
                  "written" % (OLD_VERSION, names),
          rc == 0 and done.get("world_version") == OLD_VERSION and done.get("due") == DUE
          and done.get("write_checked") == ["player", "auth", "mod_storage"]
          and it.dump(w) == dump_before, "exit %d %s" % (rc, json.dumps(done)))
    rc, ev = it.tool(run, "migrate", w, "-", shipped=True)
    kinds = [e.get("event") for e in ev]
    first = next((e for e in ev if e.get("event") == "step_done"), {})
    check("tool", "migrate: the events start, step_start/step_done per due step, done; exit 0",
          rc == 0 and kinds == ["start"] + ["step_start", "step_done"] * len(DUE) + ["done"]
          and it.last(ev).get("applied") == DUE
          and next(e for e in ev if e.get("event") == "step_start").get("from") == OLD_VERSION,
          "exit %d %s" % (rc, kinds))
    check("tool", "step 0.45.0 wrote three inventories, two seen-items deletions and three "
                  "markers, nothing else",
          first.get("step") == "0.45.0" and first.get("counts") == {
              "characters": 3, "player_meta": 2, "inventories": 3, "positions": 0,
              "privileges": 0, "mod_storage": 0, "markers": 3}, json.dumps(first))
    check("tool", "the record is %s" % DUE[-1],
          it.storage(w, "grug_core").get("world_version") == DUE[-1])
    after = state(w)
    for n in CHARACTERS:
        want = expected_after(n, before[n]["inv"], layouts[n]["entries"])
        got = after.get(n, {}).get("inv", {})
        bad = same_lists(want, got)
        check("step", "%s: every slot of every list as the step must leave it (mixtures gone, "
                      "craft moved, unmodified gear pinned, everything else unchanged)" % n,
              not bad, json.dumps(bad[:6]))
    smith = after["smith"]["inv"]
    check("step", "smith: two craft stacks moved into the slots the mixtures freed, six "
                  "left in the grid (size 9)",
          len(smith["craft"]) == 9 and sum(1 for x in smith["craft"] if x) == 6
          and name_of(smith["main"][12]) == "grug_gear:greataxe_bronze"
          and name_of(smith["grug_bag1_content"][1]) == "default:cobble")
    check("step", "scribe and sleeper: the grid stored with size 0; craftpreview empty for all",
          after["scribe"]["inv"]["craft"] == [] and after["sleeper"]["inv"]["craft"] == []
          and not any(x for n in CHARACTERS for x in after[n]["inv"].get("craftpreview", [])))
    check("step", "no mixture left in any list of any character",
          not any(mixtures_in(after[n]["inv"]) for n in CHARACTERS)
          and all(mixtures_in(before[n]["inv"]) for n in CHARACTERS))
    meta_ok = all(after[n]["meta"].get(MARKER) == "1" and SEEN not in after[n]["meta"]
                  and {k: v for k, v in after[n]["meta"].items() if k != MARKER}
                  == {k: v for k, v in before[n]["meta"].items() if k != SEEN}
                  for n in CHARACTERS)
    check("step", "player meta: the marker on all three, seen-items gone, nothing else changed",
          meta_ok)
    dump_after = it.dump(w)
    it.world_diff(run, "tool_0.45.0", dump_before, dump_after)
    changed = sorted(set(dump_before) ^ set(dump_after))
    check("step", "nothing else changed: only the characters' item and meta rows and the "
                  "record (positions, auth, other mod storage untouched)",
          changed and all(re.match(r"'(item|meta)' \| '(smith|scribe|sleeper)' \|", line)
                          or line.startswith("'storage' | 'grug_core' | 'world_version' |")
                          for line in changed), json.dumps(changed[:6]))
    rc, ev = it.tool(run, "check_after", w, "-", check_mode=True, shipped=True)
    done = it.last(ev)
    check("tool", "--check after: world %s, nothing due" % DUE[-1],
          rc == 0 and done.get("world_version") == DUE[-1] and done.get("due") == [],
          "exit %d %s" % (rc, json.dumps(done)))

    # Boot A: the new game on the migrated world.
    a = it.boot(run, w, "after_%s" % GAME, joins=("smith", "scribe"))
    obs = a.obs or {}
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    load = obs.get("load") or {}
    check("boot", "boot A (%s): starts from %s with nothing due; smith and scribe joined and "
                  "left; the record is %s" % (GAME, DUE[-1], GAME),
          a.rc == 0 and load.get("from") == DUE[-1] and load.get("new_world") is False
          and obs.get("leaves") == 2 and sorted(joins) == ["scribe", "smith"]
          and it.storage(w, "grug_core").get("world_version") == GAME,
          "rc %d load %s joins %s" % (a.rc, json.dumps(load), a.joins))
    check_names(obs.get("registrations") or {}, GAME)
    for n in ("smith", "scribe"):
        loaded = probe_lists((joins.get(n) or {}).get("loaded"))
        bad = same_lists(after[n]["inv"], loaded, [k for k in after[n]["inv"] if k != "craft"])
        craft_ok = len(loaded.get("craft", [])) == len(after[n]["inv"]["craft"]) and not any(
            not same(x, y) for x, y in zip(loaded.get("craft", []), after[n]["inv"]["craft"]))
        check("boot", "%s's join: the engine loaded the migrated inventory (the grid with "
                      "its stored size) and the marker" % n,
              not bad and craft_ok and (joins.get(n) or {}).get("loaded_meta_marker") == "1",
              json.dumps(bad[:4]))
    sm = (joins.get("smith") or {}).get("settled") or {}
    sc = (joins.get("scribe") or {}).get("settled") or {}
    sm_lists, sc_lists = probe_lists(sm.get("inventory")), probe_lists(sc.get("inventory"))
    check("boot", "after the join: no mixture, the craft grid gone (size 0), the marker "
                  "cleared, for smith and scribe",
          sm and sc and not mixtures_in(sm_lists) and not mixtures_in(sc_lists)
          and not sm_lists.get("craft") and not sc_lists.get("craft")
          and sm.get("marker") == "" and sc.get("marker") == "")
    torch = parse(stack_at(sm, "main", 1))
    check("boot", "smith: the leftover torches merged through the give helper (main[1] 13)",
          (torch.name, torch.count) == ("default:torch", 13), stack_at(sm, "main", 1))
    out = [(parse(x).name, parse(x).count) for x in sm_lists.get("grug_craft_out", [])]
    check("boot", "smith: the next four leftovers fill the output area in grid order",
          out == [("default:stick", 6), ("default:paper", 2), ("default:book", 1),
                  ("default:coal_lump", 5)], json.dumps(out))
    drops = [(parse(d["item"]).name, parse(d["item"]).count)
             for d in (joins.get("smith") or {}).get("drops") or []]
    check("boot", "smith: the last leftover dropped at the feet, nothing else dropped",
          drops == [("default:clay_lump", 3)], json.dumps(drops))
    # The gear.
    built = smith_built
    pins = [e for e in layouts["smith"]["entries"] if e["role"] == "pin"]
    pins.append({"list": "main", "slot": 13, "item": "grug_gear:greataxe_bronze"})
    bad_level, bad_tip = [], []
    for e in pins:
        ilvl, req = OLD_LEVELS[name_of(e["item"])]
        facts = gear_at(sm, e["list"], e["slot"])
        if name_of(stack_at(sm, e["list"], e["slot"])) != name_of(e["item"]) or \
                (facts.get("ilvl"), facts.get("req")) != (ilvl, req):
            bad_level.append("%s[%d] %s: %s" % (e["list"], e["slot"], e["item"][:40],
                                                (facts.get("ilvl"), facts.get("req"))))
        elif not tooltip_ok(facts, ilvl, req):
            bad_tip.append("%s[%d]: %r" % (e["list"], e["slot"],
                                           (facts.get("description") or "")[:120]))
    check("boot", "smith: every unmodified piece keeps its 0.44.0 item level and requirement "
                  "in its slot (%d pieces: equipped, main, bag, the moved battle axe)"
          % len(pins), not bad_level, json.dumps(bad_level[:6]))
    check("boot", "smith: their tooltips are rebuilt (\"Item level <old>\", the old "
                  "requirement line)", not bad_tip, json.dumps(bad_tip[:4]))
    equipped = sm.get("equipment") or {}
    check("boot", "smith: everything stays equipped and wearable at level 10; a fresh Iron "
                  "Chestplate would need level 11 now",
          sm.get("level") == 10 and sorted(equipped) == sorted(
              ["grug_weapon", "grug_chest", "grug_feet", "grug_legs", "grug_offhand",
               "grug_trinket1", "grug_trinket2"])
          and all(v.get("wearable") for v in equipped.values())
          and equipped.get("grug_chest", {}).get("fresh_wearable") is False,
          json.dumps(equipped))
    check("boot", "smith: the equipped armour is what 0.44.0 counted (%s)" % built.get("armor"),
          sm.get("armor") is not None and sm.get("armor") == built.get("armor"),
          "%s vs %s" % (sm.get("armor"), built.get("armor")))
    t1 = []
    for listname, slot, built_at in (("grug_weapon", 1, ("grug_weapon", 1)),
                                     ("main", 13, ("craft", 2))):
        now, then = gear_at(sm, listname, slot), gear_at(built, *built_at)
        t1.append((listname, now.get("damage"), then.get("damage")))
    check("boot", "smith: the first-tier sword and battle axe deal their 0.44.0 damage "
                  "(5 and 8, not the new definition's 4 and 6)",
          t1 == [("grug_weapon", 5, 5), ("main", 8, 8)], json.dumps(t1))
    bow = gear_at(sm, "main", 12)
    check("boot", "smith: the broken bow stays broken and keeps its 0.44.0 damage (5) for "
                  "the repair", bow.get("wear") == 65535 and bow.get("damage") == 0
          and bow.get("repair_damage") == 5, json.dumps(bow))
    untouched = []
    for e in layouts["smith"]["entries"]:
        if e["role"] != "modified":
            continue
        then = before["smith"]["inv"][e["list"]][e["slot"] - 1]
        if not same_levels(stack_at(sm, e["list"], e["slot"]), then,
                           LEVEL_KEYS + ("grug_quality",)):
            untouched.append("%s[%d]" % (e["list"], e["slot"]))
    check("boot", "smith: crafted and rolled gear keeps its own item level, requirement, "
                  "enchants and capabilities", not untouched, json.dumps(untouched))
    # Scribe.
    helm = find(sc, "grug_gear:head_metal_steel")
    helm_facts = gear_at(sc, *helm[0]) if len(helm) == 1 else {}
    check("boot", "scribe: the helm left in the shift-click slot came back into the "
                  "inventory at the join, pinned at 20 / 20",
          len(helm) == 1 and helm[0][0] == "main" and not any(sc_lists.get("grug_shift", []))
          and (helm_facts.get("ilvl"), helm_facts.get("req")) == (20, 20)
          and tooltip_ok(helm_facts, 20, 20), json.dumps({"at": helm, "facts": helm_facts}))
    rows = [("main", 10, "grug_gear:bow_iron", (10, 10)), ("main", 9, "grug_gear:mercy_seal_t6",
                                                            (50, 50)),
            ("grug_weapon", 1, "grug_gear:sword_bronze", (3, 1))]
    bad = []
    for listname, slot, item, levels in rows:
        facts = gear_at(sc, listname, slot)
        if name_of(stack_at(sc, listname, slot)) != item or \
                (facts.get("ilvl"), facts.get("req")) != levels or not tooltip_ok(facts, *levels):
            bad.append("%s[%d] %s" % (listname, slot, json.dumps(facts)[:120]))
    apple = parse(stack_at(sc, "main", 11))
    check("boot", "scribe: the moved bow, the trinket and the equipped sword at their old "
                  "levels with rebuilt tooltips; the moved apples in main[11]",
          not bad and (apple.name, apple.count) == ("default:apple", 3), json.dumps(bad))
    weapon = gear_at(sc, "grug_weapon", 1)
    check("boot", "scribe: the plain first-tier sword deals 5 and is wearable at level 1",
          weapon.get("damage") == 5 and sc.get("level") == 1
          and (sc.get("equipment") or {}).get("grug_weapon", {}).get("wearable"),
          json.dumps(weapon))
    final = state(w)
    check("boot", "saved after boot A: the markers of smith and scribe are gone; sleeper "
                  "(offline) keeps its marker and its migrated inventory",
          MARKER not in final["smith"]["meta"] and MARKER not in final["scribe"]["meta"]
          and final["sleeper"]["meta"].get(MARKER) == "1"
          and not same_lists(after["sleeper"]["inv"], final["sleeper"]["inv"]),
          json.dumps(same_lists(after["sleeper"]["inv"], final["sleeper"]["inv"])[:4]))
    check("boot", "saved after boot A: no mixture for any character",
          not any(mixtures_in(final[n]["inv"]) for n in CHARACTERS))


def main(argv):
    evidence = Path(argv[0]).resolve() if argv else HERE / "evidence"
    if evidence.exists():
        subprocess.run(["rm", "-rf", "--", str(evidence)], check=True)
    evidence.mkdir(parents=True)
    run = it.Run(evidence)
    print("run directory %s, port %d, game %s, due %s" % (run.root, run.port, GAME, DUE),
          flush=True)
    try:
        try:
            scenario(run)
        except Exception as err:
            check("harness", "scenario", False, "%s: %s" % (type(err).__name__, err))
            raise
    finally:
        results = it.results
        table = ["%-4s  %-6s %s" % ("PASS" if ok else "FAIL", group, name)
                 for group, name, ok, _ in results]
        failed = [r for r in results if not r[2]]
        summary = "%d checks, %d failed" % (len(results), len(failed))
        text = "\n".join(table + ["", summary] + ["FAIL %s: %s" % (r[1], r[3]) for r in failed])
        (evidence / "results.txt").write_text(text + "\n")
        print("\n" + text)
        if it.os.environ.get("KEEP") == "1":
            print("kept: %s" % run.root)
        else:
            it.shutil.rmtree(run.root, ignore_errors=True)
            it.shutil.rmtree("/tmp/grudgelands-headless-failed/" + run.root.name,
                             ignore_errors=True)
    return 0 if it.results and not failed else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

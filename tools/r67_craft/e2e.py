#!/usr/bin/env python3
"""Round 67 lane CRAFT: the end-to-end test of the migration step 0.67.0
(tools/migration/steps/v0_67_0.py, offline only; contract R8, round
workflow section 3 "Migration steps"). It reuses Round 43 IT's harness
(tools/r43_it/it.py: boots, the database dumps and the PASS table;
client.py for the joins).

  export   the 0.66.1 commit (OLD below) through `git archive`: its game
           and launcher
  boot S   the 0.66.1 game on a new world (SQLite player, auth and mod
           storage): smith and sleeper join and the probe
           (grug_probe_r67_craft) builds them: rods in smith's main, on
           the other hotbar and in the crafting overflow, a finished
           running job and a waiting one that took rods, a letter with
           rods, three Claim Stone entries (a rod stack, a packed chest not
           cleaned yet, a cleaned one with its content key); rods in
           sleeper's main (sleeper stays offline afterwards)
  boot R   this checkout's game on the 0.66.1 world without the tool:
           refused by the guard naming the step 0.67.0, nothing written
  tool     the shipped tool in the platform runner's environment (Debian
           trixie, python3 3.13; tools/r43_it/Containerfile): --check, the
           migration, --check again; every rod refunded as ceil(N / 2) bars
           in place in each store, nothing else changed
  boot A   this checkout's game on the migrated world: smith joins: no rod
           anywhere, the two jobs end at the join and give their consumed
           stacks back as bars (their recipes are gone), the overflow
           drains, the letter, the entries and the packed contents hold
           bars; sleeper's migrated inventory stays as the tool left it

Prints the PASS/FAIL table, writes it with the trimmed evidence to the
evidence directory (default tools/r67_craft/evidence) and exits 0 only when
every check passed.

Usage: tools/r67_craft/run.sh [EVIDENCE_DIR]   (through the round's process
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
from migration import codec, data, world as worldmod  # noqa: E402
from migration.codec import ItemStack  # noqa: E402

OLD = "9fcf8093"           # main at 0.66.1 (the Round 67 base)
OLD_VERSION = "0.66.1"
NEW_VERSION = "0.67.0"
PROBE = HERE / "grug_probe_r67_craft"
it.PROBE = PROBE
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern + r"|\[r67_craft_probe\]")
check = it.check
CHARACTERS = ("smith", "sleeper")
ROD = "grug_professions:metal_rod_"
BAR = "grug_materials:%s_bar"


def bar(metal, count):
    return ItemStack(BAR % metal, count).to_string()


def state(world):
    backends = worldmod.open_world(str(world))
    try:
        api = data.World(backends, "read")
        return {name: {"inv": {k: [s.to_string() for s in v.items]
                               for k, v in api.get_inventory(name).items()},
                       "meta": api.get_meta(name)} for name in api.characters()}
    finally:
        worldmod.close_world(backends)


def rods_in(text):
    return ROD in (text or "")


def totals(lists):
    """Bar counts per item name over every list (item strings)."""
    out = {}
    for items in (lists or {}).values():
        for item in items or []:
            if item:
                stack = ItemStack.parse(item)
                out[stack.name] = out.get(stack.name, 0) + stack.count
    return out


def export_old(run):
    target = run.root / "v0_66_1"
    target.mkdir()
    archive = subprocess.run(
        ["git", "-C", str(REPO), "archive", OLD, "game.conf", "mods", "minetest.conf",
         "settingtypes.txt", "menu", "tools/luanti_headless.sh"],
        capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    version = re.search(r"^version\s*=\s*(\S+)", (target / "game.conf").read_text(), re.M)
    check("setup", "the 0.66.1 commit %s exported (its game and launcher)" % OLD,
          version and version.group(1) == OLD_VERSION, version and version.group(1))
    return target / "tools" / "luanti_headless.sh"


def tool(run, case, world, check_mode=False):
    args = ["python3", "tools/migrate.py", "--world", str(world)] + \
        (["--check"] if check_mode else [])
    cmd = ["podman", "run", "--rm", "--network=none", "--security-opt", "label=disable",
           "-v", "%s:%s:ro" % (REPO, REPO), "-v", "%s:%s" % (run.root, run.root),
           "-w", str(REPO), it.IMAGE] + args
    proc = subprocess.run(cmd, capture_output=True, text=True)
    events = []
    for line in proc.stdout.splitlines():
        try:
            events.append(json.loads(line))
        except ValueError:
            pass
    out = run.evidence / "tool"
    out.mkdir(parents=True, exist_ok=True)
    (out / ("%s.jsonl" % case)).write_text(
        re.sub(r"/tmp/grudgelands-headless\.\w+", "<run>", proc.stdout))
    if proc.returncode not in (0, 1, 2) or not events:
        print(proc.stderr[-2000:])
    return proc.returncode, events


def joins_of(boot):
    return {j.get("name"): j for j in (boot.obs or {}).get("joins") or []}


def scenario(run):
    w = run.root / "w"
    it.write_world_mt(w, mod_storage=True)

    # Boot S: the 0.66.1 game builds the world.
    it.LAUNCHER = export_old(run)
    s = it.boot(run, w, "setup_0.66.1", joins=CHARACTERS)
    obs = s.obs or {}
    setup = joins_of(s)
    check("setup", "boot S (0.66.1): a new world, both characters joined, were built and left",
          s.rc == 0 and obs.get("leaves") == len(CHARACTERS) and sorted(setup) ==
          sorted(CHARACTERS) and all((setup.get(n) or {}).get("built_ok") for n in CHARACTERS)
          and obs.get("rods_registered") is True
          and it.storage(w, "grug_core").get("world_version") == OLD_VERSION,
          "rc %d joins %s %s" % (s.rc, s.joins, json.dumps(
              [((setup.get(n) or {}).get("build") or {}).get("error") for n in CHARACTERS])))
    before = state(w)
    housing_before = it.storage(w, "grug_housing")
    mail_before = it.storage(w, "grug_mail")
    smith = before.get("smith", {"inv": {}, "meta": {}})
    check("setup", "0.66.1 saved smith's rods in main, the other hotbar and the overflow, and "
                   "sleeper's in main",
          rods_in(json.dumps(smith["inv"].get("main"))) and
          rods_in(json.dumps(smith["inv"].get("grug_hotbar_store"))) and
          rods_in(json.dumps(smith["inv"].get("grug_craft_out"))) and
          rods_in(json.dumps((before.get("sleeper") or {"inv": {}})["inv"].get("main"))),
          json.dumps(smith["inv"])[:400])
    check("setup", "0.66.1 saved the running and the waiting job with rods in `consumed`",
          rods_in(smith["meta"].get("grug_jobs:job")) and
          rods_in(smith["meta"].get("grug_jobs:queue")))
    check("setup", "0.66.1 saved the letter and the three Claim Stone entries with rods",
          rods_in(mail_before.get("box:smith")) and
          rods_in(housing_before.get("recovered:smith:1:1")) and
          rods_in(housing_before.get("recovered:smith:1:2")) and
          rods_in(housing_before.get("packed:smith:1:3")))
    dump_before = it.dump(w)

    # Boot R: the new game without the tool.
    it.LAUNCHER = REPO / "tools" / "luanti_headless.sh"
    r = it.boot(run, w, "refused_%s" % NEW_VERSION)
    check("guard", "boot R (%s): the 0.66.1 world without the tool is refused, naming the "
                   "step 0.67.0 and the command line" % NEW_VERSION,
          it.refused_with(r, "This world is at version %s and needs the migration step %s "
                             "before this game's version %s can start it"
                          % (OLD_VERSION, NEW_VERSION, NEW_VERSION),
                          "python3 tools/migrate.py --world %s" % w), "rc %d" % r.rc)
    check("guard", "the refused start wrote nothing", it.dump(w) == dump_before)

    # The tool.
    rc, ev = tool(run, "check_before", w, check_mode=True)
    done = it.last(ev)
    check("tool", "--check: world %s, due [%s], nothing written" % (OLD_VERSION, NEW_VERSION),
          rc == 0 and done.get("world_version") == OLD_VERSION
          and done.get("due") == [NEW_VERSION] and it.dump(w) == dump_before,
          "exit %d %s" % (rc, json.dumps(done)))
    rc, ev = tool(run, "migrate", w)
    kinds = [e.get("event") for e in ev]
    step_done = next((e for e in ev if e.get("event") == "step_done"), {})
    check("tool", "migrate: start, step_start, step_done, done; exit 0",
          rc == 0 and kinds == ["start", "step_start", "step_done", "done"]
          and it.last(ev).get("applied") == [NEW_VERSION], "exit %d %s" % (rc, kinds))
    check("tool", "step 0.67.0: two inventories, two job keys, four storage rows, no marker",
          step_done.get("step") == NEW_VERSION and step_done.get("counts") == {
              "characters": 2, "player_meta": 2, "inventories": 2, "positions": 0,
              "privileges": 0, "mod_storage": 4, "markers": 0}, json.dumps(step_done))
    after = state(w)
    a_smith, b_smith = after["smith"], before["smith"]
    want = {}
    for lst, items in b_smith["inv"].items():
        want[lst] = list(items)
        for i, item in enumerate(items):
            if rods_in(item):
                stack = ItemStack.parse(item)
                want[lst][i] = bar(stack.name[len(ROD):], (stack.count + 1) // 2)
    check("step", "smith's inventory: each rod stack in place as ceil(N / 2) bars (iron 5 -> "
                  "3, abyssal steel 1 -> 1, steel 2 -> 1, embersteel 4 -> 2), the rest as it was",
          a_smith["inv"] == want and a_smith["inv"]["main"][8] == bar("iron", 3)
          and a_smith["inv"]["main"][9] == bar("abyssal_steel", 1)
          and a_smith["inv"]["grug_hotbar_store"][1] == bar("steel", 1)
          and a_smith["inv"]["grug_craft_out"][0] == bar("embersteel", 2),
          json.dumps(a_smith["inv"])[:400])
    check("step", "sleeper's inventory: bronze rods 3 -> 2 bars",
          after["sleeper"]["inv"]["main"][8] == bar("bronze", 2),
          json.dumps(after["sleeper"]["inv"].get("main"))[:200])
    job = codec.deserialize(a_smith["meta"]["grug_jobs:job"])
    queue = codec.deserialize(a_smith["meta"]["grug_jobs:queue"])
    check("step", "the jobs' consumed stacks: iron rod 1 -> 1 bar, steel rods 3 -> 2 bars; "
                  "every other field kept",
          job["consumed"] == ["grug_materials:iron_bar 2", BAR % "iron"]
          and queue[0]["consumed"] == ["grug_materials:steel_bar 1", bar("steel", 2)]
          and {k: v for k, v in job.items() if k != "consumed"} ==
          {k: v for k, v in codec.deserialize(b_smith["meta"]["grug_jobs:job"]).items()
           if k != "consumed"}, json.dumps([job, queue])[:400])
    housing = it.storage(w, "grug_housing")
    mail = it.storage(w, "grug_mail")
    packed2 = ItemStack.parse(housing["recovered:smith:1:2"])
    letters = codec.deserialize(mail["box:smith"])["letters"]
    check("step", "storage: the rod entry (9 -> 5 bars), the uncleaned chest's lists, the "
                  "content key and the letter hold bars",
          housing["recovered:smith:1:1"] == bar("iron", 5)
          and codec.deserialize(packed2.meta["lists"])["main"][1] == bar("embersteel", 4)
          and codec.deserialize(housing["packed:smith:1:3"])["main"][1] == BAR % "bronze"
          and letters[0]["items"] == [bar("silversteel", 3), "default:apple 2"])
    check("step", "storage: nothing else changed (the cleaned chest's entry, other keys)",
          housing["recovered:smith:1:3"] == housing_before["recovered:smith:1:3"]
          and {k for k in housing} == {k for k in housing_before}
          and {k for k in mail} == {k for k in mail_before}
          and all(housing[k] == housing_before[k] for k in housing
                  if k not in ("recovered:smith:1:1", "recovered:smith:1:2",
                               "packed:smith:1:3")))
    check("step", "the record is %s" % NEW_VERSION,
          it.storage(w, "grug_core").get("world_version") == NEW_VERSION)
    dump_after = it.dump(w)
    it.world_diff(run, "tool_0.67.0", dump_before, dump_after)
    changed = sorted(set(dump_before) ^ set(dump_after))
    check("step", "nothing else changed: the characters' item and job rows, the four storage "
                  "rows and the record",
          changed and all(re.match(r"'item' \| '(smith|sleeper)' \|", line)
                          or re.match(r"'meta' \| 'smith' \| 'grug_jobs:(job|queue)' \|", line)
                          or re.match(r"'storage' \| 'grug_(housing|mail)' \| "
                                      r"'(recovered:smith:1:[12]|packed:smith:1:3|box:smith)' \|",
                                      line)
                          or line.startswith("'storage' | 'grug_core' | 'world_version' |")
                          for line in changed), json.dumps(changed[:6]))
    rc, ev = tool(run, "check_after", w, check_mode=True)
    done = it.last(ev)
    check("tool", "--check after: world %s, nothing due" % NEW_VERSION,
          rc == 0 and done.get("world_version") == NEW_VERSION and done.get("due") == [],
          "exit %d %s" % (rc, json.dumps(done)))

    # Boot A: the new game on the migrated world.
    a = it.boot(run, w, "after_%s" % NEW_VERSION, joins=("smith",))
    obs = a.obs or {}
    joined = joins_of(a).get("smith") or {}
    settled = joined.get("settled") or {}
    stores = joined.get("stores") or {}
    check("boot", "boot A (%s): starts from %s, rods unregistered; smith joined and left"
                  % (NEW_VERSION, NEW_VERSION),
          a.rc == 0 and (obs.get("load") or {}).get("from") == NEW_VERSION
          and obs.get("rods_registered") is False and obs.get("leaves") == 1,
          "rc %d %s %s" % (a.rc, json.dumps(obs.get("load")), a.joins))
    check("boot", "after the join: no rod in any list, both jobs done (job and queue empty)",
          settled and not rods_in(json.dumps(settled.get("lists")))
          and settled.get("job") == "" and settled.get("queue") in ("", None),
          json.dumps(settled)[:400])
    got = totals(settled.get("lists"))
    want_totals = {BAR % "iron": 3 + 2 + 1, BAR % "steel": 1 + 1 + 2, BAR % "embersteel": 2,
                   BAR % "abyssal_steel": 1}
    check("boot", "the jobs gave their consumed stacks back as bars and the overflow drained: "
                  "iron 6, steel 4, embersteel 2, abyssal steel 1 in all",
          all(got.get(k) == v for k, v in want_totals.items()), json.dumps(got))
    check("boot", "the game reads the Claim Stone entries, the packed contents and the letter "
                  "with bars and no rod",
          stores and not stores.get("error") and not rods_in(json.dumps(stores))
          and len(stores.get("recovered") or []) == 3
          and [l.get("items") for l in stores.get("letters") or []] ==
          [[bar("silversteel", 3), "default:apple 2"]], json.dumps(stores)[:400])
    final = state(w)
    check("boot", "saved after boot A: sleeper (offline) keeps its migrated inventory",
          final["sleeper"]["inv"] == after["sleeper"]["inv"])


def main(argv):
    evidence = Path(argv[0]).resolve() if argv else HERE / "evidence"
    if evidence.exists():
        subprocess.run(["rm", "-rf", "--", str(evidence)], check=True)
    evidence.mkdir(parents=True)
    run = it.Run(evidence)
    print("run directory %s, port %d, checkout game %s" % (run.root, run.port, it.GAME),
          flush=True)
    failed = []
    try:
        try:
            scenario(run)
        except Exception as err:
            check("harness", "scenario", False, "%s: %s" % (type(err).__name__, err))
            raise
    finally:
        results = it.results
        table = ["%-4s  %-7s %s" % ("PASS" if ok else "FAIL", group, name)
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

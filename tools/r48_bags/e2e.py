#!/usr/bin/env python3
"""Round 48 lane BAGS: the end-to-end test of the migration step 0.48.0
(tools/migration/steps/v0_48_0.py and its join part in
grug_core/migrations.lua; contract R8, round workflow section 3 "Migration
steps"). It reuses Round 43 IT's harness (tools/r43_it/it.py: boots, the
database dumps and the PASS table; client.py for the joins).

  export   the 0.47.0 commit (OLD below, origin/main) through `git archive`:
           its game and launcher
  boot S   the 0.47.0 game on a new world (SQLite player, auth and mod
           storage): "hoarder", "light" and "sleeper" join and the probe
           (grug_probe_r48_bags) builds them (see its header: four full
           32-slot bags and a full main for hoarder, no bags for light, one
           full 8-slot bag for sleeper)
  boot R   this checkout's game on the 0.47.0 world without the tool:
           refused by the guard naming the step 0.48.0, nothing written
  tool     the shipped tool in the platform runner's environment (Debian
           trixie, python3 3.13; tools/r43_it/Containerfile): --check, the
           migration, --check again; only the markers and the record change
  boot A   this checkout's game on the migrated world: hoarder and light
           join (sleeper stays offline); the probe records the inventory as
           loaded (before grug_core's runner: the 32-slot lists) and as the
           join left it: main[9..] and the bags (16 slots each) full, the
           hotbar unchanged, the Claim Stone in main, the rest in 16 "Lost
           and Found" letters of at most four stacks (read from grug_mail's
           mod storage after the boot), nothing lost or duplicated, one feed
           line; light only loses its marker
  boot B   hoarder joins again: nothing changes, no new letter

Prints the PASS/FAIL table, writes it with the trimmed evidence to the
evidence directory (default tools/r48_bags/evidence) and exits 0 only when
every check passed.

Usage: tools/r48_bags/run.sh [EVIDENCE_DIR]   (through the round's process
queue, one slot: the boots and the container runs go one at a time)
"""

import json
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path[:0] = [str(REPO / "tools"), str(REPO / "tools" / "r43_it")]

import it  # noqa: E402  (tools/r43_it/it.py)
from migration import codec, data, world as worldmod  # noqa: E402

OLD = "6a8afb9f"           # origin/main at 0.47.0
OLD_VERSION = "0.47.0"
NEW_VERSION = "0.48.0"
PROBE = HERE / "grug_probe_r48_bags"
it.PROBE = PROBE
it.EVIDENCE_LINE = re.compile(it.EVIDENCE_LINE.pattern + r"|\[r48_bags_probe\]")
check = it.check
CHARACTERS = ("hoarder", "light", "sleeper")
MARKER = "grug_core:migrate:0.48.0"
CONTENT = ["grug_bag%d_content" % i for i in range(1, 5)]
CARRIED = ["main"] + CONTENT
SENDER, SUBJECT = "Lost and Found", "Your bags got smaller"
BODY_START = "Bags in the realm now hold half as much as before."


def state(world):
    backends = worldmod.open_world(str(world))
    try:
        api = data.World(backends, "read")
        return {name: {"inv": {k: [s.to_string() for s in v.items]
                               for k, v in api.get_inventory(name).items()},
                       "meta": api.get_meta(name)} for name in api.characters()}
    finally:
        worldmod.close_world(backends)


def export_old(run):
    target = run.root / "v0_47_0"
    target.mkdir()
    archive = subprocess.run(
        ["git", "-C", str(REPO), "archive", OLD, "game.conf", "mods", "minetest.conf",
         "settingtypes.txt", "menu", "tools/luanti_headless.sh"],
        capture_output=True, check=True).stdout
    subprocess.run(["tar", "-x", "-C", str(target)], input=archive, check=True)
    version = re.search(r"^version\s*=\s*(\S+)", (target / "game.conf").read_text(), re.M)
    check("setup", "the 0.47.0 commit %s exported (its game and launcher)" % OLD,
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


def identity(item):
    """An item string without its count: (name, wear, meta)."""
    stack = codec.ItemStack.parse(item)
    return (stack.name, stack.wear, json.dumps(stack.meta, sort_keys=True)), stack.count


def normal(lists):
    """Every list's stacks as (name, count, wear, meta): the game's join
    rebuilds gear tooltips, which may store the same meta in another order."""
    out = {}
    for name, stacks in (lists or {}).items():
        out[name] = []
        for item in stacks:
            stack = codec.ItemStack.parse(item) if item else None
            out[name].append(stack and (stack.name, stack.count, stack.wear,
                                        json.dumps(stack.meta, sort_keys=True)))
    return out


def census(items):
    total = Counter()
    for item in items:
        if item:
            key, count = identity(item)
            total[key] += count
    return total


def carried(lists, hotbar=True):
    out = []
    for name in CARRIED:
        for index, item in enumerate(lists.get(name) or []):
            if name == "main" and index < 8 and not hotbar:
                continue
            out.append(item)
    return out


def letters_of(world, name):
    """The letters grug_mail stores for `name` (its mod storage), each as
    {"kind", "from", "subject", "body", "stacks"}."""
    return read_letters(it.storage(world, "grug_mail"), name)


def read_letters(storage, name):
    """grug_mail/store.lua: key `box:<name>`, core.serialize of the mailbox
    (model.lua `new_box`: {letters = {...}}, newest first); a letter's
    attachments are item strings in `items`."""
    raw = storage.get("box:" + name)
    if not raw:
        return []
    box = codec.deserialize(raw)
    letters = box.get("letters") or [] if isinstance(box, dict) else []
    if isinstance(letters, dict):
        letters = [letters[k] for k in sorted(letters)]
    out = []
    for letter in letters:
        items = letter.get("items") or []
        if isinstance(items, dict):
            items = [items[k] for k in sorted(items)]
        out.append({"kind": letter.get("kind"), "from": letter.get("from"),
                    "subject": letter.get("subject"), "body": letter.get("body"),
                    "stacks": list(items)})
    return out


def scenario(run):
    w = run.root / "w"
    it.write_world_mt(w, mod_storage=True)

    # Boot S: the 0.47.0 game builds the world.
    it.LAUNCHER = export_old(run)
    s = it.boot(run, w, "setup_0.47.0", joins=CHARACTERS)
    obs = s.obs or {}
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    check("setup", "boot S (0.47.0): a new world, hoarder, light and sleeper joined, were "
                   "built and left",
          s.rc == 0 and obs.get("leaves") == 3 and sorted(joins) == sorted(CHARACTERS)
          and all((joins.get(n) or {}).get("built_ok") for n in CHARACTERS)
          and it.storage(w, "grug_core").get("world_version") == OLD_VERSION,
          "rc %d joins %s %s" % (s.rc, s.joins, json.dumps(
              [(joins.get(n) or {}).get("build_error") for n in CHARACTERS])))
    before = state(w)
    hoard = before.get("hoarder", {}).get("inv", {})
    sizes = [len(hoard.get(c) or []) for c in CONTENT]
    full = sum(1 for item in carried(hoard, hotbar=False) if item)
    check("setup", "0.47.0 saved hoarder with four 32-slot bags and 152 stacks in main[9..] "
                   "and the bags",
          sizes == [32] * 4 and full == 152, "sizes %s, stacks %d" % (sizes, full))
    dump_before = it.dump(w)

    # Boot R: the new game without the tool.
    it.LAUNCHER = REPO / "tools" / "luanti_headless.sh"
    r = it.boot(run, w, "refused_%s" % NEW_VERSION)
    check("guard", "boot R (%s): the 0.47.0 world without the tool is refused, naming the "
                   "step 0.48.0 and the command line" % NEW_VERSION,
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
    check("tool", "step 0.48.0 wrote three markers and nothing else",
          step_done.get("step") == NEW_VERSION and step_done.get("counts") == {
              "characters": 3, "player_meta": 0, "inventories": 0, "positions": 0,
              "privileges": 0, "mod_storage": 0, "markers": 3}, json.dumps(step_done))
    after = state(w)
    check("step", "every character carries the marker; inventories and the other meta "
                  "unchanged; the record is %s" % NEW_VERSION,
          all(after[n]["meta"].get(MARKER) == "1" and after[n]["inv"] == before[n]["inv"]
              and {k: v for k, v in after[n]["meta"].items() if k != MARKER}
              == before[n]["meta"] for n in CHARACTERS)
          and it.storage(w, "grug_core").get("world_version") == NEW_VERSION)
    dump_after = it.dump(w)
    it.world_diff(run, "tool_0.48.0", dump_before, dump_after)
    changed = sorted(set(dump_before) ^ set(dump_after))
    check("step", "nothing else changed: the three meta rows and the record",
          changed and all(re.match(r"'meta' \| '(hoarder|light|sleeper)' \|", line)
                          or line.startswith("'storage' | 'grug_core' | 'world_version' |")
                          for line in changed), json.dumps(changed[:6]))
    rc, ev = tool(run, "check_after", w, check_mode=True)
    done = it.last(ev)
    check("tool", "--check after: world %s, nothing due" % NEW_VERSION,
          rc == 0 and done.get("world_version") == NEW_VERSION and done.get("due") == [],
          "exit %d %s" % (rc, json.dumps(done)))

    # Boot A: the new game on the migrated world.
    a = it.boot(run, w, "after_%s" % NEW_VERSION, joins=("hoarder", "light"))
    obs = a.obs or {}
    joins = {j.get("name"): j for j in obs.get("joins") or []}
    hoarder = joins.get("hoarder") or {}
    loaded, settled = hoarder.get("loaded") or {}, hoarder.get("settled") or {}
    check("boot", "boot A (%s): starts from %s; hoarder and light joined with the marker "
                  "and left" % (NEW_VERSION, NEW_VERSION),
          a.rc == 0 and (obs.get("load") or {}).get("from") == NEW_VERSION
          and obs.get("leaves") == 2 and loaded.get("marker") == "1"
          and ((joins.get("light") or {}).get("loaded") or {}).get("marker") == "1",
          "rc %d %s %s" % (a.rc, json.dumps(obs.get("load")), a.joins))
    check("boot", "as loaded (before the runner): four 32-slot content lists",
          [(loaded.get("sizes") or {}).get(c) for c in CONTENT] == [32] * 4,
          json.dumps(loaded.get("sizes")))
    lists = settled.get("lists") or {}
    check("boot", "after the join: the marker cleared, four 16-slot content lists",
          settled.get("marker") == "" and
          [(settled.get("sizes") or {}).get(c) for c in CONTENT] == [16] * 4,
          json.dumps(settled.get("sizes")))
    kept = carried(lists, hotbar=False)
    check("boot", "after the join: main[9..] and the four bags full (88 stacks)",
          len(kept) == 88 and all(kept), "%d cells, %d full" % (len(kept), sum(map(bool, kept))))
    check("boot", "after the join: the hotbar untouched",
          (lists.get("main") or [])[:8] == ((loaded.get("lists") or {}).get("main") or [])[:8])
    stone = [i for i, item in enumerate(lists.get("main") or []) if
             item.startswith("grug_housing:claim_stone")]
    check("boot", "after the join: the Claim Stone in main[9..]",
          len(stone) == 1 and stone[0] >= 8, json.dumps(stone))
    check("boot", "after the join: one feed line naming 16 letters",
          len(settled.get("feed") or []) == 1 and "16 letters" in settled["feed"][0],
          json.dumps(settled.get("feed")))
    check("boot", "after the join: 16 unread letters",
          settled.get("unread") == 16, json.dumps(settled.get("unread")))
    light = joins.get("light") or {}
    check("boot", "light (no bags): the marker cleared, the inventory unchanged, no letter",
          (light.get("settled") or {}).get("marker") == ""
          and (light.get("settled") or {}).get("lists") == (light.get("loaded") or {}).get("lists")
          and (light.get("settled") or {}).get("unread") in (0, False),
          json.dumps((light.get("settled") or {}).get("feed")))
    letters = letters_of(w, "hoarder")
    stacks = [item for letter in letters for item in letter["stacks"]]
    check("mail", "16 npc letters from %s, \"%s\", the coordinator's text, 15 of four "
                  "stacks and one of three"
          % (SENDER, SUBJECT),
          len(letters) == 16 and all(l["from"] == SENDER and l["subject"] == SUBJECT
                                     and l["kind"] == "npc" and BODY_START in (l["body"] or "")
                                     for l in letters)
          and sorted(len(l["stacks"]) for l in letters) == [3] + [4] * 15,
          json.dumps([(l["from"], len(l["stacks"])) for l in letters])[:300])
    check("mail", "nothing lost or duplicated: the inventory before equals the inventory "
                  "after plus the letters (count, wear and meta)",
          census(carried(hoard)) == census(carried(lists) + stacks))
    check("mail", "no letter for light", letters_of(w, "light") == [])
    final = state(w)
    check("boot", "saved after boot A: hoarder's and light's markers gone; sleeper (offline) "
                  "keeps its marker and its 8-slot bag of 8 stacks",
          MARKER not in final["hoarder"]["meta"] and MARKER not in final["light"]["meta"]
          and final["sleeper"]["meta"].get(MARKER) == "1"
          and final["sleeper"]["inv"] == after["sleeper"]["inv"])

    # Boot B: a second join changes nothing.
    b = it.boot(run, w, "again_%s" % NEW_VERSION, joins=("hoarder",))
    obs = b.obs or {}
    again = ((obs.get("joins") or [{}])[0]).get("settled") or {}
    check("again", "boot B: hoarder joins again: the inventory as boot A left it (meta "
                   "compared as a table), no feed line, still 16 letters",
          b.rc == 0 and normal(again.get("lists")) == normal(lists) and not again.get("feed")
          and len(letters_of(w, "hoarder")) == 16, "rc %d" % b.rc)


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

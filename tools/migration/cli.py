"""The command line of tools/migrate.py (contract R3).

Flow: read the checkout (game.conf's version, the declaration's `migrate`
list, the step files), open the world (world.mt, the three backends, their
layouts; with `--map-reset` the map too, read-only), read the record, then
either prove write access (`--check`; with `--map-reset` also one map block
read and decoded) or run the pre-reset pass first (`--map-reset`, pack.py)
and then every due step in its own transactions.

Exit codes: 0 migrated, nothing to do or checked; 2 refused or failed before
anything was written; 1 failed after writing began (the first step's
transactions were open), the world is undefined and must be restored.

stdout carries one JSON object per line; the last one is the result:
  {"event": "start", "mode": "migrate"|"check", "world": <dir>}
  {"event": "refusal", "reason": <code>, "message": <text>}            exit 2
  {"event": "pack_start", "seq": <n>, "claims": <n>}            --map-reset
  {"event": "pack_done", "seq", "counts": {"claims", "players", "containers",
   "items", "charcoal", "blocks_read"}, "nodes", "empty", "seconds"}
  {"event": "step_start", "step": <v>, "from": <version>}
  {"event": "step_done", "step": <v>, "counts": {<kind>: <n>, ...}}
  {"event": "failed", "step": <v>|null, "reason": <code>, "message": <text>}  exit 1
  {"event": "done", "mode", "world_version", "record", "new_world", "target",
   "due", "applied" (migrate) or "write_checked" (check), "backends"; with
   --map-reset also "map_reset": true and "pack_seq" (migrate) or
   "map_checked" and "pack" (check: the pass's dry run, {"seq", "counts",
   "nodes", "empty", "seconds"} as pack_done would carry them)}  exit 0
Refusal reasons: usage, checkout, world_mt, backend, database_missing,
connection, layout, lock, write_access, record, world_newer, pack_baseline,
pack_pending, map_block, map_empty, internal.
Failure reasons: lock, step, rule, commit, pack. stderr carries the same as
text.

The test hook (plan section 3, ruling 5): `main(argv, test_steps={version:
module})` runs undeclared steps as if declared. Only Python reaches it; the
shipped command line has no way to name a step.
"""

import argparse
import importlib.util
import json
import re
import sys
import time
import traceback
from pathlib import Path

from . import data, mapblock, pack, world as worldmod
from .world import Refusal

REPO = Path(__file__).resolve().parents[2]
GAME_CONF = REPO / "game.conf"
DECLARATION = REPO / "tools" / "web_data" / "upgrade.json"
STEPS = Path(__file__).resolve().parent / "steps"
BASELINE = "0.41.0"
# Round 50 ruling 9: the pre-reset pass is planned from the production
# version on.
PACK_BASELINE = "0.48.1"
# The wall clock of the pass (the fuel's remaining time); tests replace it.
clock = time.time
VERSION = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")

DESCRIPTION = """\
Migrate a stopped Grudgelands world to this checkout's version (game.conf):
run every due migration step in ascending order, each in one transaction per
database backend, and record the world version after each step.

The server must be stopped. The tool cannot detect a running server: Luanti
holds no lasting SQLite lock and PostgreSQL has none. Back up the world (its
directory and, for PostgreSQL, its databases) first.

Run it from the repository root of the checkout:
  python3 tools/migrate.py --world <dir>          migrate
  python3 tools/migrate.py --world <dir> --check  report the world version and
      the due steps, prove write access with a write that is rolled back
  python3 tools/migrate.py --world <dir> --map-reset
      before the map is emptied: pack every container of every housing claim
      for its owner (read from the map, which is never written), then migrate
  python3 tools/migrate.py --world <dir> --check --map-reset
      also read and decode one map block

Exit codes: 0 migrated or nothing to do (or checked); 2 refused or failed
before anything was written; 1 failed after writing began: restore the
backup. stdout: one JSON object per line; stderr: the same as text.
Every event and its fields: tools/README.md, "The migration tool".
"""


class Failure(Exception):
    """Failed after writing began: exit 1."""

    def __init__(self, reason, message, step=None):
        super().__init__(message)
        self.reason = reason
        self.message = message
        self.step = step


class _Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Refusal("usage", message)


def parse_version(text):
    match = VERSION.match(text) if isinstance(text, str) else None
    return tuple(int(part) for part in match.groups()) if match else None


class Output:
    def __init__(self, out, err):
        self.out, self.err = out, err

    def event(self, name, text=None, **fields):
        self.out.write(json.dumps(dict(event=name, **fields)) + "\n")
        self.out.flush()
        if text:
            self.say(text)

    def say(self, text):
        self.err.write("migrate: " + text + "\n")
        self.err.flush()


def read_checkout(test_steps):
    """game.conf's version and the steps it carries: [(version, module)]."""
    try:
        conf = GAME_CONF.read_text(encoding="utf-8")
        decl = json.loads(DECLARATION.read_text(encoding="utf-8"))
    except (OSError, ValueError) as err:
        raise Refusal("checkout", "cannot read the checkout: %s" % err) from None
    target = None
    for line in conf.splitlines():
        match = re.match(r"^\s*version\s*=\s*(.*?)\s*$", line)
        if match and not line.lstrip().startswith("#"):
            target = match.group(1)
            break
    if parse_version(target) is None:
        raise Refusal("checkout", "game.conf has no major.minor.patch version")
    declared = decl.get("migrate", []) if isinstance(decl, dict) else None
    if not isinstance(declared, list) or any(parse_version(v) is None for v in declared):
        raise Refusal("checkout", "the declaration's migrate list is malformed")
    steps = {}
    for version in declared:
        if parse_version(version) > parse_version(target):
            continue
        path = STEPS / ("v%s.py" % version.replace(".", "_"))
        steps[version] = _load_step(version, path)
    for version, module in (test_steps or {}).items():
        if parse_version(version) is None or parse_version(version) > parse_version(target) \
                or version in steps:
            raise Refusal("checkout", "test step %r is no free version up to %s"
                          % (version, target))
        if not callable(getattr(module, "migrate", None)):
            raise Refusal("checkout", "test step %s has no migrate(world)" % version)
        steps[version] = module
    return target, sorted(steps.items(), key=lambda item: parse_version(item[0]))


def _load_step(version, path):
    if not path.is_file():
        raise Refusal("checkout", "the step file of %s is missing: %s" % (version, path))
    try:
        spec = importlib.util.spec_from_file_location(
            "migration.steps.v%s" % version.replace(".", "_"), path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    except Exception as err:
        raise Refusal("checkout", "cannot load the step %s: %s" % (version, err)) from None
    if not callable(getattr(module, "migrate", None)):
        raise Refusal("checkout", "the step %s has no migrate(world)" % version)
    return module


def world_version(backends, world_dir):
    """The record read like the game: missing on an existing world is the
    baseline 0.41.0; a new world (data.is_new_world) has no version yet."""
    record = data.read_record(backends)
    if record is not None:
        if parse_version(record) is None:
            raise Refusal("record", "grug_core's world_version %r is no "
                          "major.minor.patch version" % record)
        return record, record, False
    if data.is_new_world(backends, world_dir):
        return None, None, True
    return BASELINE, None, False


def _lock_or_access(err, kind):
    text = str(err)
    if "locked" in text or "lock timeout" in text or "busy" in text:
        return "lock", "%s backend: cannot take the write lock: %s" % (kind, text)
    return "write_access", "%s backend: cannot write: %s" % (kind, text)


def check_writes(backends, target):
    """A real write on every backend, rolled back."""
    checked = []
    for kind in worldmod.KINDS:
        backend = backends[kind]
        if not backend.present:
            continue
        try:
            backend.begin()
            try:
                if kind == "mod_storage":
                    data.write_record(backends, target)
                elif kind == "player":
                    backend.execute(
                        "INSERT INTO player (name, pitch, yaw, posX, posY, posZ, hp, breath) "
                        "VALUES (?, 0, 0, 0, 0, 0, 0, 0)", ("\x01migrate-check",))
                else:
                    # An explicit id leaves PostgreSQL's id sequence alone.
                    backend.execute(
                        "INSERT INTO auth (id, name, password, last_login) "
                        "SELECT COALESCE(MAX(id), 0) + 1, ?, '', 0 FROM auth",
                        ("\x01migrate-check",))
            finally:
                backend.rollback()
        except worldmod.db_errors() as err:
            raise Refusal(*_lock_or_access(err, kind)) from None
        checked.append(kind)
    return checked


def run_step(backends, version, module, out):
    """One step in one transaction per backend; returns its counts."""
    present = [backends[kind] for kind in worldmod.KINDS if backends[kind].present]
    begun = []
    try:
        for backend in present:
            backend.begin()
            begun.append(backend)
        world = data.World(backends, version)
        before = world.snapshot()
        module.migrate(world)
        if world.snapshot() != before:
            raise data.StepError("the step created, renamed or deleted a character or an "
                                 "auth entry, or changed a table layout")
        data.write_record(backends, version)
    except BaseException as err:
        for backend in begun:
            try:
                backend.rollback()
            except Exception:
                pass
        if len(begun) < len(present) and isinstance(err, worldmod.db_errors()):
            raise Failure("lock", "%s: %s" % (version, _lock_or_access(
                err, present[len(begun)].kind)[1]), version) from None
        out.say("".join(traceback.format_exception(err)).rstrip())
        reason = "rule" if isinstance(err, data.StepError) else "step"
        raise Failure(reason, "step %s failed: %s: %s" % (version, type(err).__name__, err),
                      version) from None
    # Mod storage last: the record moves only once the others are in.
    for backend in present:
        try:
            backend.commit()
        except worldmod.db_errors() as err:
            raise Failure("commit", "step %s: committing the %s backend failed: %s"
                          % (version, backend.kind, err), version) from None
    return world.counts


def check_map(map_reader):
    """`--check --map-reset`: zstd importable, one stored block decoded."""
    mapblock.zstd()
    try:
        found = map_reader.any_block()
    except mapblock.map_errors() as err:
        raise Refusal("connection", "map backend: cannot read: %s" % err) from None
    if found is None:
        return 0
    pos, row = found
    try:
        mapblock.decode(row)
    except mapblock.BlockError as err:
        raise Refusal("map_block", "map block (%d, %d, %d): %s" % (pos + (err,))) from None
    return 1


def read_pass(backends, map_reader, out, dry=False):
    """The pass's reads, before anything is written: its number, the claims
    and what their areas hold. Refusals only. `dry` (the check) announces
    no pass."""
    store = backends["mod_storage"]
    pending = pack.pending_markers(store)
    if pending:
        raise Refusal("pack_pending", "grug_core holds %s: an earlier pass was never loaded "
                      "by the game, so its map may still be here or already gone; restore "
                      "the backup taken before that pass, or start the game once"
                      % ", ".join(pending))
    text = pack.storage_get(store, pack.HOUSING, pack.SEQ_KEY)
    if text is not None and not text.isdigit():
        raise Refusal("internal", "grug_housing pack_seq %r is no number" % text)
    seq = int(text or 0) + 1
    claims, bad = pack.read_claims(store)
    if bad:
        out.say("%d claim record(s) do not decode and are skipped, as the game does" % bad)
    if not dry:
        out.event("pack_start", "pass %d: %d claim(s)" % (seq, len(claims)),
                  seq=seq, claims=len(claims))
    try:
        if claims and map_reader.any_block() is None:
            raise Refusal("map_empty", "the map holds no block but there are %d claim(s): "
                          "the pass must run before the map is emptied" % len(claims))
        scans = []
        for claim in claims:
            started = time.monotonic()
            scans.append(pack.scan_claim(map_reader, claim))
            out.say("claim %d (%s): %d blocks, %d container(s), %.3f s" % (
                claim.id, claim.owner, scans[-1].blocks, len(scans[-1].containers),
                time.monotonic() - started))
    except pack.PackError as err:
        raise Refusal("map_block", str(err)) from None
    except mapblock.map_errors() as err:
        raise Refusal("connection", "map backend: cannot read: %s" % err) from None
    return seq, scans


def prepare_pass(backends, map_reader, out, dry=False):
    """Everything of the pass before its transaction, for the pass and its
    dry run (`--check --map-reset`) alike: the reads, every block of every
    claim decoded, the entries built and proved to read back, none of their
    keys taken. Refusals only; writes nothing. Returns (seq, entries,
    report) with report = {seq, counts, nodes, empty}."""
    seq, scans = read_pass(backends, map_reader, out, dry)
    entries, counts = pack.build(scans, seq, int(clock()))
    try:
        pack.verify(entries, scans, seq)
    except (AssertionError, ValueError) as err:
        raise Refusal("internal", "the packed entries do not read back: %s" % err) from None
    taken = pack.taken_keys(backends["mod_storage"], entries)
    if taken:
        raise Refusal("internal", "grug_housing already holds %s: pack_seq is behind its "
                      "entries" % ", ".join(taken[:3]))
    nodes, empty = pack.by_node(scans)
    return seq, entries, dict(seq=seq, counts=counts, nodes=nodes, empty=empty)


def run_pass(backends, map_reader, new_world, out):
    """The pre-reset pass (pack.py): prepare_pass, then one mod-storage
    transaction. Returns the pass number."""
    started = time.monotonic()
    seq, entries, report = prepare_pass(backends, map_reader, out)
    counts = report["counts"]
    if new_world:
        out.say("a new world: nothing to pack, nothing written")
    else:
        store = backends["mod_storage"]
        try:
            store.begin()
        except worldmod.db_errors() as err:
            raise Refusal(*_lock_or_access(err, "mod_storage")) from None
        try:
            pack.write(store, entries, seq)
            store.commit()
        except BaseException as err:
            try:
                store.rollback()
            except Exception:
                pass
            out.say("".join(traceback.format_exception(err)).rstrip())
            raise Failure("pack", "the pass %d failed: %s: %s"
                          % (seq, type(err).__name__, err)) from None
    out.event("pack_done", "pass %d done: %s" % (seq, json.dumps(counts)),
              seconds=round(time.monotonic() - started, 3), **report)
    return seq


def main(argv, test_steps=None, stdout=None, stderr=None):
    out = Output(stdout or sys.stdout, stderr or sys.stderr)
    parser = _Parser(prog="python3 tools/migrate.py", description=DESCRIPTION,
                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--world", required=True, metavar="DIR",
                        help="the world directory (the one holding world.mt)")
    parser.add_argument("--check", action="store_true",
                        help="report and prove write access; change nothing")
    parser.add_argument("--map-reset", action="store_true",
                        help="before the map is emptied: pack the claims' containers, then "
                        "migrate (with --check: also decode one map block)")
    backends = {}
    map_reader = None
    writing = False
    try:
        args = parser.parse_args(argv)
        mode = "check" if args.check else "migrate"
        world_dir = str(Path(args.world).absolute())
        out.event("start", "%s %s" % (mode, world_dir), mode=mode, world=world_dir)
        target, steps = read_checkout(test_steps)
        backends = worldmod.open_world(world_dir)
        if args.map_reset:
            map_reader = mapblock.open_map(
                world_dir, worldmod.read_world_mt(Path(world_dir, "world.mt")))
        try:
            current, record, new_world = world_version(backends, world_dir)
        except worldmod.db_errors() as err:
            raise Refusal("connection", "cannot read the world: %s" % err) from None
        if current is not None and parse_version(current) > parse_version(target):
            raise Refusal("world_newer", "the world is at %s, newer than this checkout's "
                          "%s: use the checkout of %s or newer" % (current, target, current))
        if args.map_reset and current is not None and \
                parse_version(current) < parse_version(PACK_BASELINE):
            raise Refusal("pack_baseline", "the world is at %s: the pre-reset pass is "
                          "planned only from %s on" % (current, PACK_BASELINE))
        due = [] if new_world else [
            v for v, _ in steps if parse_version(current) < parse_version(v)]
        result = dict(mode=mode, world_version=current, record=record, new_world=new_world,
                      target=target, due=due,
                      backends={k: (b.engine if b.present else "absent")
                                for k, b in backends.items()})
        if map_reader is not None:
            result["backends"]["map"] = map_reader.engine if map_reader.present else "absent"
            result["map_reset"] = True
        if new_world:
            out.say("a new world (no character, no mod storage): the game records "
                    "its version at the first start")
        else:
            out.say("world version %s%s, target %s, due steps: %s" % (
                current, "" if record else " (no record: the baseline)", target,
                ", ".join(due) or "none"))
        if args.check:
            text = ""
            if map_reader is not None:
                # The pass's dry run: the same code up to its transaction.
                result["map_checked"] = check_map(map_reader)
                started = time.monotonic()
                result["pack"] = prepare_pass(backends, map_reader, out, dry=True)[2]
                result["pack"]["seconds"] = round(time.monotonic() - started, 3)
                text = "; %d map block decoded; the pass would write: %s" % (
                    result["map_checked"], json.dumps(result["pack"]["counts"]))
            result["write_checked"] = check_writes(backends, target)
            out.event("done", "checked: write access on %s%s"
                      % (", ".join(result["write_checked"]), text), **result)
            return 0
        if map_reader is not None:
            # Refused before its transaction begins; a failure inside it is
            # a Failure (exit 1): from then on the world counts as written.
            result["pack_seq"] = run_pass(backends, map_reader, new_world, out)
            writing = not new_world
        applied = []
        previous = current
        for version, module in steps:
            if version not in due:
                continue
            out.event("step_start", "step %s (from %s)" % (version, previous),
                      step=version, **{"from": previous})
            written, writing = writing, True
            try:
                counts = run_step(backends, version, module, out)
            except Failure as fail:
                # The first step's locks not taken: nothing was written.
                if fail.reason == "lock" and not applied and not written:
                    raise Refusal("lock", fail.message) from None
                raise
            applied.append(version)
            previous = version
            out.event("step_done", "step %s done: %s" % (version, json.dumps(counts)),
                      step=version, counts=counts)
        result["applied"] = applied
        text = "migrated to %s" % previous if applied else "nothing to do"
        if map_reader is not None:
            text = "packed (pass %d), %s" % (result["pack_seq"], text)
        out.event("done", text, **result)
        return 0
    except Refusal as refusal:
        out.event("refusal", "refused: " + refusal.message, reason=refusal.reason,
                  message=refusal.message)
        return 2
    except Failure as fail:
        out.event("failed", "FAILED: %s; the world is undefined, restore the backup"
                  % fail.message, step=fail.step, reason=fail.reason, message=fail.message)
        return 1
    except Exception as err:
        out.say("".join(traceback.format_exception(err)).rstrip())
        message = "%s: %s" % (type(err).__name__, err)
        if writing:
            out.event("failed", "FAILED: %s; restore the backup" % message,
                      step=None, reason="step", message=message)
            return 1
        out.event("refusal", "refused: " + message, reason="internal", message=message)
        return 2
    finally:
        if map_reader is not None:
            map_reader.close()
        worldmod.close_world(backends)

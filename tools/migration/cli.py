"""The command line of tools/migrate.py (contract R3).

Flow: read the checkout (game.conf's version, the declaration's `migrate`
list, the step files), open the world (world.mt, the three backends, their
layouts), read the record, then either prove write access (`--check`) or
run every due step in its own transactions.

Exit codes: 0 migrated, nothing to do or checked; 2 refused or failed before
anything was written; 1 failed after writing began (the first step's
transactions were open), the world is undefined and must be restored.

stdout carries one JSON object per line; the last one is the result:
  {"event": "start", "mode": "migrate"|"check", "world": <dir>}
  {"event": "refusal", "reason": <code>, "message": <text>}            exit 2
  {"event": "step_start", "step": <v>, "from": <version>}
  {"event": "step_done", "step": <v>, "counts": {<kind>: <n>, ...}}
  {"event": "failed", "step": <v>|null, "reason": <code>, "message": <text>}  exit 1
  {"event": "done", "mode", "world_version", "record", "new_world", "target",
   "due", "applied" (migrate) or "write_checked" (check), "backends"}  exit 0
Refusal reasons: usage, checkout, world_mt, backend, database_missing,
connection, layout, lock, write_access, record, world_newer, internal.
Failure reasons: lock, step, rule, commit. stderr carries the same as text.

The test hook (plan section 3, ruling 5): `main(argv, test_steps={version:
module})` runs undeclared steps as if declared. Only Python reaches it; the
shipped command line has no way to name a step.
"""

import argparse
import importlib.util
import json
import re
import sys
import traceback
from pathlib import Path

from . import data, world as worldmod
from .world import Refusal

REPO = Path(__file__).resolve().parents[2]
GAME_CONF = REPO / "game.conf"
DECLARATION = REPO / "tools" / "web_data" / "upgrade.json"
STEPS = Path(__file__).resolve().parent / "steps"
BASELINE = "0.41.0"
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

Exit codes: 0 migrated or nothing to do (or checked); 2 refused or failed
before anything was written; 1 failed after writing began: restore the
backup. stdout: one JSON object per line; stderr: the same as text.
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
        self.out.write(json.dumps(dict(event=name, **fields), ensure_ascii=False) + "\n")
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


def world_version(backends):
    """The record read like the game: missing on an existing world is the
    baseline 0.41.0; a new world (data.is_new_world) has no version yet."""
    record = data.read_record(backends)
    if record is not None:
        if parse_version(record) is None:
            raise Refusal("record", "grug_core's world_version %r is no "
                          "major.minor.patch version" % record)
        return record, record, False
    if data.is_new_world(backends):
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


def main(argv, test_steps=None, stdout=None, stderr=None):
    out = Output(stdout or sys.stdout, stderr or sys.stderr)
    parser = _Parser(prog="python3 tools/migrate.py", description=DESCRIPTION,
                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--world", required=True, metavar="DIR",
                        help="the world directory (the one holding world.mt)")
    parser.add_argument("--check", action="store_true",
                        help="report and prove write access; change nothing")
    backends = {}
    writing = False
    try:
        args = parser.parse_args(argv)
        mode = "check" if args.check else "migrate"
        world_dir = str(Path(args.world).absolute())
        out.event("start", "%s %s" % (mode, world_dir), mode=mode, world=world_dir)
        target, steps = read_checkout(test_steps)
        backends = worldmod.open_world(world_dir)
        try:
            current, record, new_world = world_version(backends)
        except worldmod.db_errors() as err:
            raise Refusal("connection", "cannot read the world: %s" % err) from None
        if current is not None and parse_version(current) > parse_version(target):
            raise Refusal("world_newer", "the world is at %s, newer than this checkout's "
                          "%s: use the checkout of %s or newer" % (current, target, current))
        due = [] if new_world else [
            v for v, _ in steps if parse_version(current) < parse_version(v)]
        result = dict(mode=mode, world_version=current, record=record, new_world=new_world,
                      target=target, due=due,
                      backends={k: (b.engine if b.present else "absent")
                                for k, b in backends.items()})
        if new_world:
            out.say("a new world (no character, no mod storage): the game records "
                    "its version at the first start")
        else:
            out.say("world version %s%s, target %s, due steps: %s" % (
                current, "" if record else " (no record: the baseline)", target,
                ", ".join(due) or "none"))
        if args.check:
            result["write_checked"] = check_writes(backends, target)
            out.event("done", "checked: write access on %s"
                      % ", ".join(result["write_checked"]), **result)
            return 0
        applied = []
        previous = current
        for version, module in steps:
            if version not in due:
                continue
            out.event("step_start", "step %s (from %s)" % (version, previous),
                      step=version, **{"from": previous})
            writing = True
            try:
                counts = run_step(backends, version, module, out)
            except Failure as fail:
                # The first step's locks not taken: nothing was written.
                if fail.reason == "lock" and not applied:
                    raise Refusal("lock", fail.message) from None
                raise
            applied.append(version)
            previous = version
            out.event("step_done", "step %s done: %s" % (version, json.dumps(counts)),
                      step=version, counts=counts)
        result["applied"] = applied
        out.event("done", "migrated to %s" % previous if applied else "nothing to do",
                  **result)
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
        worldmod.close_world(backends)

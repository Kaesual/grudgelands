#!/usr/bin/env python3
"""Check the upgrade declaration (tools/web_data/upgrade.json).

The hosting platform reads this file to decide how a world moves to a newer
Grudgelands version (the upgrade contract, docs/technical/upgrade-contract.md):
compatible, map reset, migrate or new server. The rules checked here:

- the shape is exactly {"schema": 2, "version": "x.y.z", "map_reset": [...],
  "new_server": [...], "migrate": [...]}; versions are major.minor.patch,
  compared numerically per component;
- `version` equals game.conf's `version`;
- each list is strictly ascending and every entry is at most `version`;
- the game's step registry (`versions` in mods/CORE/grug_core/migrations.lua,
  which the start guard reads) equals the `migrate` list;
- every `migrate` entry has its step file tools/migration/steps/vX_Y_Z.py;
- against the last pushed commit (default `origin/main`): the version never
  decreases, entries are never edited or removed, a new entry comes only
  together with a version bump, and the step file of every pushed `migrate`
  entry is unchanged. A missing earlier declaration is accepted (the first
  declaration); a pushed schema-1 declaration has no `migrate` list.

`outcome()` is the platform's reading: a move from `a` to `b` crosses every
entry v with a < v <= b; crossing a `new_server` entry needs a new server
(whatever else is crossed), else crossing `map_reset` and `migrate` entries
needs both (the map is emptied first, then the tool runs), one of them alone
that one, else the move is compatible.

Usage (repository root; a check runs the self-test of these rules first):
  python3 tools/check_upgrade.py [--base REF]
  python3 tools/check_upgrade.py --self-test
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DECLARATION = "tools/web_data/upgrade.json"
REGISTRY = "mods/CORE/grug_core/migrations.lua"
STEPS = "tools/migration/steps"
SCHEMA = 2
KEYS = ("schema", "version", "map_reset", "new_server", "migrate")
LISTS = ("map_reset", "new_server", "migrate")
VERSION = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")


def parse_version(text):
    match = VERSION.match(text) if isinstance(text, str) else None
    return tuple(int(part) for part in match.groups()) if match else None


def game_conf_version(text):
    for line in text.splitlines():
        match = re.match(r"^\s*version\s*=\s*(.*?)\s*$", line)
        if match and not line.lstrip().startswith("#"):
            return match.group(1)
    return None


def step_file(version):
    """The step file of a `migrate` entry: 0.44.0 -> tools/migration/steps/v0_44_0.py."""
    return "%s/v%s.py" % (STEPS, version.replace(".", "_"))


def registry_versions(source):
    """The `versions` list of grug_core/migrations.lua: (list, None) or (None, error).

    The list must be one table of double-quoted string literals; anything else
    there is refused rather than guessed."""
    code = "\n".join(line.split("--", 1)[0] for line in source.splitlines())
    tables = re.findall(r"(?m)^\s*versions\s*=\s*\{([^{}]*)\}", code)
    if len(tables) != 1:
        return None, "%s must hold exactly one `versions = {...}` table" % REGISTRY
    inner = tables[0].strip()
    items = [item.strip() for item in inner.split(",")] if inner else []
    if items and items[-1] == "":
        items.pop()
    versions = []
    for item in items:
        match = re.fullmatch(r'"([^"\\]*)"', item)
        if not match:
            return None, "%s: `versions` holds %r, not a string literal" % (REGISTRY, item)
        versions.append(match.group(1))
    return versions, None


def validate(decl, conf_version):
    """The declaration's own rules; returns a list of errors."""
    if not isinstance(decl, dict) or sorted(decl) != sorted(KEYS):
        return ["the declaration must hold exactly the keys " + ", ".join(KEYS)]
    errors = []
    if type(decl["schema"]) is not int or decl["schema"] != SCHEMA:
        errors.append("schema must be %d" % SCHEMA)
    version = parse_version(decl["version"])
    if version is None:
        errors.append("version must be major.minor.patch: %r" % (decl["version"],))
    elif decl["version"] != conf_version:
        errors.append("version %s differs from game.conf's %s" % (decl["version"], conf_version))
    for name in LISTS:
        entries = decl[name]
        if not isinstance(entries, list):
            errors.append(name + " must be a list")
            continue
        last = None
        for entry in entries:
            parsed = parse_version(entry)
            if parsed is None:
                errors.append("%s: %r is no major.minor.patch version" % (name, entry))
                continue
            if last is not None and parsed <= last:
                errors.append("%s must be strictly ascending at %s" % (name, entry))
            if version is not None and parsed > version:
                errors.append("%s: %s is above the version %s" % (name, entry, decl["version"]))
            last = parsed
    return errors


def compare(old, new):
    """The rules against the last pushed declaration; returns a list of errors.
    A pushed schema-1 declaration has no `migrate` list (an empty one)."""
    errors = []
    old_version, new_version = parse_version(old.get("version")), parse_version(new["version"])
    if old_version is None:
        return ["the pushed declaration has no valid version"]
    if new_version < old_version:
        errors.append("the version decreased from %s to %s" % (old["version"], new["version"]))
    changed = False
    for name in LISTS:
        before, after = list(old.get(name) or []), new[name]
        if after[:len(before)] != before:
            errors.append("%s: pushed entries were edited or removed (%s -> %s)" %
                          (name, before, after))
        if after != before:
            changed = True
    if changed and not new_version > old_version:
        errors.append("a new entry needs a version bump (still %s)" % new["version"])
    return errors


def registry_errors(decl, source):
    """The game's step registry against the declaration's `migrate` list."""
    versions, error = registry_versions(source)
    if error:
        return [error]
    if versions != decl["migrate"]:
        return ["%s lists the steps %s, the declaration's migrate list is %s" %
                (REGISTRY, versions, decl["migrate"])]
    return []


def step_errors(migrate, pushed_migrate, read_current, read_pushed):
    """Every declared step file exists; a pushed step's file is unchanged.
    read_current(path) and read_pushed(path) return bytes, or None when absent."""
    errors = []
    for version in migrate:
        path = step_file(version)
        current = read_current(path)
        if current is None:
            errors.append("migrate %s: its step file %s is missing" % (version, path))
            continue
        if version in pushed_migrate:
            pushed = read_pushed(path)
            if pushed is None:
                errors.append("migrate %s: the pushed commit has no step file %s" % (version, path))
            elif pushed != current:
                errors.append("migrate %s: the pushed step file %s was changed "
                              "(a fix is a later, new step)" % (version, path))
    return errors


def outcome(decl, from_version, to_version):
    """compatible, map_reset, migrate, map_reset+migrate or new_server for a
    move between two versions."""
    a, b = parse_version(from_version), parse_version(to_version)
    if a is None or b is None or b < a:
        raise ValueError("upgrades only go forward: %s -> %s" % (from_version, to_version))

    def crossed(name):
        return any(a < parse_version(entry) <= b for entry in decl.get(name) or [])

    if crossed("new_server"):
        return "new_server"
    reset, migrate = crossed("map_reset"), crossed("migrate")
    if reset and migrate:
        return "map_reset+migrate"
    if reset:
        return "map_reset"
    if migrate:
        return "migrate"
    return "compatible"


def resolve_base(ref):
    probe = subprocess.run(["git", "rev-parse", "--verify", "--quiet", ref + "^{commit}"],
                           cwd=ROOT, capture_output=True, text=True)
    if probe.returncode != 0:
        raise SystemExit("check_upgrade: unknown base %s (fetch it or pass --base)" % ref)


def read_at(ref, path):
    """A file's bytes at `ref`, or None when it does not exist there."""
    shown = subprocess.run(["git", "show", "%s:%s" % (ref, path)], cwd=ROOT, capture_output=True)
    return shown.stdout if shown.returncode == 0 else None


def read_file(path):
    full = ROOT / path
    return full.read_bytes() if full.is_file() else None


def pushed_declaration(ref):
    """The declaration at `ref`: (dict or None, note)."""
    shown = read_at(ref, DECLARATION)
    if shown is None:
        return None, "no declaration at %s: accepted once, as the first declaration" % ref
    return json.loads(shown), "compared with %s" % ref


def check(base):
    decl = json.loads((ROOT / DECLARATION).read_text())
    conf_version = game_conf_version((ROOT / "game.conf").read_text())
    errors = validate(decl, conf_version)
    note = ""
    if not errors:
        errors = registry_errors(decl, (ROOT / REGISTRY).read_text())
        resolve_base(base)
        old, note = pushed_declaration(base)
        if old is not None:
            errors += compare(old, decl)
        pushed_migrate = (old or {}).get("migrate") or []
        errors += step_errors(decl["migrate"], pushed_migrate, read_file,
                              lambda path: read_at(base, path))
    if errors:
        raise SystemExit("Upgrade declaration: FAIL\n" + "\n".join(errors))
    print("Upgrade declaration %s: PASS (%s)" % (decl["version"], note))


def self_test():
    failures = []

    def expect(ok, label):
        if not ok:
            failures.append(label)

    first = {"schema": 2, "version": "0.41.0", "map_reset": ["0.40.1"], "new_server": [],
             "migrate": []}
    expect(validate(first, "0.41.0") == [], "a schema-2 declaration is valid")
    expect(validate(first, "0.40.1") != [], "version must equal game.conf's")
    expect(validate(dict(first, extra=1), "0.41.0") != [], "no extra key")
    expect(validate({k: v for k, v in first.items() if k != "new_server"}, "0.41.0") != [],
           "no missing key")
    expect(validate({k: v for k, v in first.items() if k != "migrate"}, "0.41.0") != [],
           "schema 2 has the migrate list")
    expect(validate(dict(first, schema=1), "0.41.0") != [], "schema 2 only")
    expect(validate(dict(first, schema=True), "0.41.0") != [], "schema is an integer")
    expect(validate(dict(first, version="0.41"), "0.41") != [], "major.minor.patch")
    expect(validate(dict(first, version="0.041.0"), "0.041.0") != [], "no leading zero")
    expect(validate(dict(first, map_reset=["0.40.1", "0.40.1"]), "0.41.0") != [],
           "strictly ascending")
    expect(validate(dict(first, map_reset=["0.40.10", "0.40.9"]), "0.41.0") != [],
           "compared numerically, not as text")
    expect(validate(dict(first, map_reset=["0.40.9", "0.40.10"]), "0.41.0") == [],
           "0.40.9 < 0.40.10")
    expect(validate(dict(first, new_server=["0.41.1"]), "0.41.0") != [],
           "an entry above the version")
    expect(validate(dict(first, new_server=["0.41.0"]), "0.41.0") == [],
           "an entry at the version")
    expect(validate(dict(first, map_reset="0.40.1"), "0.41.0") != [], "lists are lists")
    expect(validate(dict(first, migrate="0.41.0"), "0.41.0") != [], "migrate is a list")
    expect(validate(dict(first, migrate=["0.41.0"]), "0.41.0") == [], "a migrate entry")
    expect(validate(dict(first, migrate=["0.40.5", "0.40.5"]), "0.41.0") != [],
           "migrate is strictly ascending")
    expect(validate(dict(first, migrate=["0.40.10", "0.40.9"]), "0.41.0") != [],
           "migrate compares numerically")
    expect(validate(dict(first, migrate=["0.41.1"]), "0.41.0") != [],
           "a migrate entry above the version")
    expect(validate(dict(first, migrate=["0.41"]), "0.41.0") != [],
           "a migrate entry is major.minor.patch")

    bump = dict(first, version="0.42.0")
    expect(compare(first, first) == [], "unchanged")
    expect(compare(first, bump) == [], "a plain bump")
    expect(compare(first, dict(first, version="0.40.9")) != [], "the version never decreases")
    expect(compare(first, dict(bump, map_reset=[])) != [], "an entry is never removed")
    expect(compare(first, dict(bump, map_reset=["0.40.2"])) != [], "an entry is never edited")
    expect(compare(first, dict(bump, map_reset=["0.40.1", "0.42.0"])) == [],
           "a new entry with a bump")
    expect(compare(first, dict(first, new_server=["0.41.0"])) != [],
           "a new entry without a bump")
    expect(compare(first, dict(bump, new_server=["0.42.0"])) == [],
           "a new new_server entry with a bump")
    expect(compare(first, dict(bump, migrate=["0.42.0"])) == [],
           "a new migrate entry with a bump")
    expect(compare(first, dict(first, migrate=["0.41.0"])) != [],
           "a new migrate entry without a bump")
    stepped = dict(bump, migrate=["0.42.0"])
    expect(compare(stepped, dict(stepped, version="0.43.0", migrate=[])) != [],
           "a migrate entry is never removed")
    expect(compare(stepped, dict(stepped, version="0.43.0", migrate=["0.42.1"])) != [],
           "a migrate entry is never edited")
    schema1 = {"schema": 1, "version": "0.42.0", "map_reset": ["0.40.1"], "new_server": []}
    expect(compare(schema1, dict(first, version="0.42.0")) == [],
           "a pushed schema-1 declaration is accepted")
    expect(compare(schema1, dict(first, version="0.43.0", migrate=["0.43.0"])) == [],
           "the first migrate entry after a schema-1 declaration, with a bump")
    expect(compare(schema1, dict(first, version="0.42.0", migrate=["0.42.0"])) != [],
           "the first migrate entry after a schema-1 declaration needs a bump")

    expect(outcome(first, "0.40.0", "0.41.0") == "map_reset", "0.40.0 -> 0.41.0 resets the map")
    expect(outcome(first, "0.40.1", "0.41.0") == "compatible", "0.40.1 crosses nothing")
    expect(outcome(first, "0.41.0", "0.41.0") == "compatible", "no move")
    expect(outcome(schema1, "0.40.0", "0.42.0") == "map_reset", "a schema-1 declaration reads")
    both = {"schema": 2, "version": "0.46.0", "map_reset": ["0.40.1", "0.43.0"],
            "new_server": ["0.42.0"], "migrate": ["0.44.0", "0.45.0"]}
    expect(outcome(both, "0.40.0", "0.46.0") == "new_server", "every list crossed: new server")
    expect(outcome(both, "0.41.0", "0.44.0") == "new_server", "new server wins over migrate")
    expect(outcome(both, "0.42.0", "0.43.0") == "map_reset", "only a map reset crossed")
    expect(outcome(both, "0.43.0", "0.45.0") == "migrate", "only migrate entries crossed")
    expect(outcome(both, "0.42.0", "0.44.0") == "map_reset+migrate",
           "map reset and migrate combine")
    expect(outcome(both, "0.41.0", "0.42.0") == "new_server", "an entry at the target counts")
    expect(outcome(both, "0.44.0", "0.44.0") == "compatible", "an entry at the start does not")
    expect(outcome(both, "0.45.0", "0.46.0") == "compatible", "nothing after the last step")
    try:
        outcome(first, "0.41.0", "0.40.0")
        expect(False, "a downgrade is refused")
    except ValueError:
        pass

    expect(registry_versions("x = {\n\tversions = {},\n}\n") == ([], None), "an empty registry")
    expect(registry_versions('\tversions = {"0.44.0", "0.45.0",},\n') ==
           (["0.44.0", "0.45.0"], None), "a registry with steps")
    expect(registry_versions('\tversions = {\n\t\t"0.44.0", -- the UI rework\n\t},\n') ==
           (["0.44.0"], None), "a registry with a comment")
    expect(registry_versions('-- versions = {"9.9.9"}\n\tversions = {},\n') == ([], None),
           "a commented-out table does not count")
    expect(registry_versions("\tversions = {V},\n")[1] is not None, "only string literals")
    expect(registry_versions("\tversions = {},\n\tversions = {},\n")[1] is not None,
           "exactly one table")
    expect(registry_versions("\thandlers = {},\n")[1] is not None, "a missing table")
    expect(registry_errors(dict(first, migrate=["0.41.0"]), '\tversions = {"0.41.0"},\n') == [],
           "the registry equals the declaration")
    expect(registry_errors(dict(first, migrate=["0.41.0"]), "\tversions = {},\n") != [],
           "a declared step missing from the registry")
    expect(registry_errors(first, '\tversions = {"0.41.0"},\n') != [],
           "an undeclared step in the registry")

    expect(step_file("0.44.0") == "tools/migration/steps/v0_44_0.py", "the step file name")
    files = {step_file("0.42.0"): b"old", step_file("0.43.0"): b"new"}
    pushed = {step_file("0.42.0"): b"old"}
    expect(step_errors(["0.42.0", "0.43.0"], ["0.42.0"], files.get, pushed.get) == [],
           "pushed step unchanged, a new step exists")
    expect(step_errors(["0.42.0", "0.44.0"], ["0.42.0"], files.get, pushed.get) != [],
           "a declared step without its file")
    expect(step_errors(["0.42.0"], ["0.42.0"], {step_file("0.42.0"): b"fixed"}.get,
                       pushed.get) != [], "a pushed step file is never changed")
    expect(step_errors(["0.43.0"], ["0.43.0"], files.get, pushed.get) != [],
           "a pushed step whose file the pushed commit lacks")

    expect(game_conf_version("# version = 1.0.0\nversion = 0.41.0\n") == "0.41.0",
           "game.conf's version line")
    if failures:
        raise SystemExit("check_upgrade self-test: FAIL\n" + "\n".join(failures))
    print("check_upgrade self-test: PASS")


def main(argv):
    if argv == ["--self-test"]:
        self_test()
    elif not argv:
        self_test()
        check("origin/main")
    elif len(argv) == 2 and argv[0] == "--base":
        self_test()
        check(argv[1])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])

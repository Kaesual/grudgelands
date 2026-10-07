#!/usr/bin/env python3
"""Check the upgrade declaration (tools/web_data/upgrade.json).

The hosting platform reads this file to decide how a world moves to a newer
Grudgelands version (the upgrade contract, docs/technical/upgrade-contract.md):
compatible, map reset or new server. The rules checked here:

- the shape is exactly {"schema": 1, "version": "x.y.z", "map_reset": [...],
  "new_server": [...]}; versions are major.minor.patch, compared numerically
  per component;
- `version` equals game.conf's `version`;
- each list is strictly ascending and every entry is at most `version`;
- against the last pushed commit (default `origin/main`): the version never
  decreases, entries are never edited or removed, and a new entry comes only
  together with a version bump. A missing earlier declaration is accepted
  (the first declaration).

`outcome()` is the platform's reading: a move from `a` to `b` crosses every
entry v with a < v <= b; crossing a `new_server` entry needs a new server
(also when map_reset entries are crossed too), else crossing a `map_reset`
entry needs a map reset, else the move is compatible.

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
KEYS = ("schema", "version", "map_reset", "new_server")
LISTS = ("map_reset", "new_server")
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


def validate(decl, conf_version):
    """The declaration's own rules; returns a list of errors."""
    if not isinstance(decl, dict) or sorted(decl) != sorted(KEYS):
        return ["the declaration must hold exactly the keys " + ", ".join(KEYS)]
    errors = []
    if type(decl["schema"]) is not int or decl["schema"] != 1:
        errors.append("schema must be 1")
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
    """The rules against the last pushed declaration; returns a list of errors."""
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


def outcome(decl, from_version, to_version):
    """compatible, map_reset or new_server for a move between two versions."""
    a, b = parse_version(from_version), parse_version(to_version)
    if a is None or b is None or b < a:
        raise ValueError("upgrades only go forward: %s -> %s" % (from_version, to_version))

    def crossed(name):
        return any(a < parse_version(entry) <= b for entry in decl[name])

    if crossed("new_server"):
        return "new_server"
    if crossed("map_reset"):
        return "map_reset"
    return "compatible"


def pushed_declaration(ref):
    """The declaration at `ref`: (dict or None, note). Raises when `ref` is unknown."""
    probe = subprocess.run(["git", "rev-parse", "--verify", "--quiet", ref + "^{commit}"],
                           cwd=ROOT, capture_output=True, text=True)
    if probe.returncode != 0:
        raise SystemExit("check_upgrade: unknown base %s (fetch it or pass --base)" % ref)
    shown = subprocess.run(["git", "show", "%s:%s" % (ref, DECLARATION)],
                           cwd=ROOT, capture_output=True, text=True)
    if shown.returncode != 0:
        return None, "no declaration at %s: accepted once, as the first declaration" % ref
    return json.loads(shown.stdout), "compared with %s" % ref


def check(base):
    decl = json.loads((ROOT / DECLARATION).read_text())
    conf_version = game_conf_version((ROOT / "game.conf").read_text())
    errors = validate(decl, conf_version)
    note = ""
    if not errors:
        old, note = pushed_declaration(base)
        if old is not None:
            errors = compare(old, decl)
    if errors:
        raise SystemExit("Upgrade declaration: FAIL\n" + "\n".join(errors))
    print("Upgrade declaration %s: PASS (%s)" % (decl["version"], note))


def self_test():
    failures = []

    def expect(ok, label):
        if not ok:
            failures.append(label)

    first = {"schema": 1, "version": "0.41.0", "map_reset": ["0.40.1"], "new_server": []}
    expect(validate(first, "0.41.0") == [], "the first declaration is valid")
    expect(validate(first, "0.40.1") != [], "version must equal game.conf's")
    expect(validate(dict(first, extra=1), "0.41.0") != [], "no extra key")
    expect(validate({k: v for k, v in first.items() if k != "new_server"}, "0.41.0") != [],
           "no missing key")
    expect(validate(dict(first, schema=2), "0.41.0") != [], "schema 1 only")
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

    expect(outcome(first, "0.40.0", "0.41.0") == "map_reset", "0.40.0 -> 0.41.0 resets the map")
    expect(outcome(first, "0.40.1", "0.41.0") == "compatible", "0.40.1 crosses nothing")
    expect(outcome(first, "0.41.0", "0.41.0") == "compatible", "no move")
    both = {"schema": 1, "version": "0.44.0", "map_reset": ["0.40.1", "0.43.0"],
            "new_server": ["0.42.0"]}
    expect(outcome(both, "0.40.0", "0.44.0") == "new_server", "both lists crossed: new server")
    expect(outcome(both, "0.42.0", "0.44.0") == "map_reset", "only a map reset crossed")
    expect(outcome(both, "0.41.0", "0.42.0") == "new_server", "an entry at the target counts")
    expect(outcome(both, "0.43.0", "0.44.0") == "compatible", "an entry at the start does not")
    try:
        outcome(first, "0.41.0", "0.40.0")
        expect(False, "a downgrade is refused")
    except ValueError:
        pass

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

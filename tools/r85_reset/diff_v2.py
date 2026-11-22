#!/usr/bin/env python3
"""Round 85 lane RESET: the pre-reset pass on v2 claims against the tool
before Round 85. Exports tools/migration of BASE (default 0c5e547f, the
round's base) with `git archive`, runs that tool and this checkout's on
copies of tools/r50_ptool/world in four variants (as built; odd records: a
draft far off, a v1 record, a bad key, permissions; the map moved by -80
blocks with the claims; claims moved so the area's border falls elsewhere),
each with --check --map-reset and --map-reset, one clock, the world at the
checkout's version (no step due; the old tool gets this checkout's
game.conf, declaration and steps, which are not the pass). Every variant must give the same exit
code, the same mod-storage rows byte for byte and the same events; the new
tool's one added field, `skipped`, is printed and left out of the
comparison. Prints one line per run and DIFFERENTIAL PASS or FAIL.

Usage (repo root): python3 -I tools/r85_reset/diff_v2.py [BASE]
"""
import gzip
import importlib
import io
import json
import shutil
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BASE = sys.argv[1] if len(sys.argv) > 1 else "0c5e547f"
SOURCE = REPO / "tools/r50_ptool/world"
RECORD = json.loads(gzip.decompress((SOURCE / "r50_ptool_probe.json.gz").read_bytes()))
NOW = min(c["paid_until"] for c in RECORD["claims"]) - 5 * 26160 + 3600
sys.dont_write_bytecode = True


def load(root):
    """migration.cli from `root`/tools, freshly imported, with the clock fixed."""
    for name in [k for k in sys.modules if k == "migration" or k.startswith("migration.")]:
        del sys.modules[name]
    sys.path.insert(0, str(root / "tools"))
    try:
        cli = importlib.import_module("migration.cli")
    finally:
        sys.path.pop(0)
    cli.clock = lambda: NOW
    return cli


def set_rows(world, rows):
    conn = sqlite3.connect(world / "mod_storage.sqlite")
    with conn:
        for modname, key, value in rows:
            conn.execute("REPLACE INTO entries VALUES (?, ?, ?)",
                         (modname, key.encode(), value.encode()))
    conn.close()


def move_map(world, dx, dz):
    conn = sqlite3.connect(world / "map.sqlite")
    with conn:
        rows = conn.execute("SELECT x, y, z, data FROM blocks").fetchall()
        conn.execute("DELETE FROM blocks")
        conn.executemany("INSERT INTO blocks VALUES (?, ?, ?, ?)",
                         [(x + dx, y, z + dz, d) for x, y, z, d in rows])
    conn.close()


def dump(world):
    conn = sqlite3.connect(world / "mod_storage.sqlite")
    try:
        return sorted(conn.execute("SELECT modname, key, value FROM entries").fetchall())
    finally:
        conn.close()


def run(cli, world, args):
    out, err = io.StringIO(), io.StringIO()
    code = cli.main(["--world", str(world), *args], stdout=out, stderr=err)
    events = [json.loads(line) for line in out.getvalue().splitlines()]
    skipped = None
    for event in events:
        event.pop("seconds", None)
        event.pop("world", None)
        for report in (event, event.get("pack") or {}):
            report.pop("seconds", None)
            if "skipped" in report:
                skipped = report.pop("skipped")
    return code, events, skipped


def v2(owner, x, z, paid_until):
    return "v2|%s|%d|150|%d|1792174515|1792174515|%d|1792174515|" % (owner, x, z, paid_until)


VARIANTS = {
    "as_built": ((), None),
    "odd_records": ((
        ("grug_housing", "claim:3",
         "v2|drafter|5000|20|5000|%d|0|%d|%d|" % (NOW - 60, NOW - 60, NOW - 60)),
        ("grug_housing", "claim:4", "v1|old|1|2|3"),
        ("grug_housing", "claim:x", "v2|bad|1|2|3|4|5|6|7|"),
        ("grug_housing", "claim:9",
         "v2|perm|1300|150|1100|1|1|%d|1|a=interact,b=everything" % (NOW + 99999)),
    ), None),
    "negative": ((
        ("grug_housing", "claim:1", v2("builder", 1000 - 1280, 1000 - 1280, 1792736955)),
        ("grug_housing", "claim:2", v2("neighbor", 1300 - 1280, 1000 - 1280, 1792305315)),
    ), (-80, -80)),
    "border_moved": ((
        ("grug_housing", "claim:1", v2("builder", 1001, 1000, 1792736955)),
        ("grug_housing", "claim:2", v2("neighbor", 1059, 1050, 1792305315)),
    ), None),
}


def main():
    work = Path(tempfile.mkdtemp(prefix="r85-reset-diff."))
    try:
        old_root = work / "old"
        old_root.mkdir()
        archive = subprocess.run(["git", "-C", str(REPO), "archive", BASE, "tools/migration"],
                                 check=True, capture_output=True).stdout
        subprocess.run(["tar", "-x", "-C", str(old_root)], input=archive, check=True)
        # The old pass with this checkout's version, declaration and steps
        # (not the pass; with no step due they never run).
        shutil.copy(REPO / "game.conf", old_root / "game.conf")
        (old_root / "tools/web_data").mkdir(parents=True)
        shutil.copy(REPO / "tools/web_data/upgrade.json", old_root / "tools/web_data")
        shutil.rmtree(old_root / "tools/migration/steps")
        shutil.copytree(REPO / "tools/migration/steps", old_root / "tools/migration/steps")
        target = load(REPO).read_checkout(None)[0]
        old, new = load(old_root), load(REPO)
        ok = True
        for name, (rows, moved) in VARIANTS.items():
            for args in (("--check", "--map-reset"), ("--map-reset",)):
                results = []
                for side, cli in (("old", old), ("new", new)):
                    world = work / ("%s-%s-%d" % (name, side, len(args)))
                    shutil.copytree(SOURCE, world)
                    (world / "r50_ptool_probe.json.gz").unlink()
                    set_rows(world, [("grug_core", "world_version", target)])
                    if moved:
                        move_map(world, *moved)
                    set_rows(world, rows)
                    code, events, skipped = run(cli, world, args)
                    results.append((code, dump(world), events, skipped))
                (co, ro, eo, _), (cn, rn, en, skipped) = results
                same = co == cn and ro == rn and eo == en
                ok &= same and co == 0
                print("%-13s %-20s exit %d/%d  rows %s  events %s  skipped %s"
                      % (name, " ".join(args), co, cn, ro == rn, eo == en, skipped))
        print("DIFFERENTIAL", "PASS" if ok else "FAIL", "(base %s)" % BASE)
        return 0 if ok else 1
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())

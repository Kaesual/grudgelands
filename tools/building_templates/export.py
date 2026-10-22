#!/usr/bin/env python3
"""The freeze of the start towns' buildings (Round 56 lane FREEZE-TOWNS).

Builds the six start towns from the building generators of the pre-freeze
commit and cuts every building out of the finished towns into building
templates (docs/technical/building-template-format.md §8), through
export.lua. Writes mods/MAPGEN/grug_mapgen/building_templates/templates/ and
layouts/, the freeze report tools/building_templates/freeze_report.txt, and the
known-defects baseline (check.py --baseline=self --write-known-defects).

The templates are the source of truth from the freeze on (ruling 23): this
tool is the record of how they were made and the proof it is repeatable, not
a way to change them. Rerunning it overwrites every template with the
generators' version.

Usage (repository root):
  python3 tools/building_templates/export.py          # write (the freeze)
  python3 tools/building_templates/export.py --check  # the committed files
      are exactly what the pre-freeze source exports (nothing is written)
"""
import filecmp
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# The last commit whose start towns call the building generators.
PRE_FREEZE = "1ac0688bc5b8be597451a6aa79fadd76e911f445"
OUT = ROOT / "mods/MAPGEN/grug_mapgen/building_templates"
REPORT = ROOT / "tools/building_templates/freeze_report.txt"


def export(into):
    """Run the exporter into `into`; returns the report text."""
    with tempfile.TemporaryDirectory(prefix="grug_freeze_src_") as source:
        archive = Path(source) / "src.tar"
        with archive.open("wb") as handle:
            run = subprocess.run(["git", "archive", PRE_FREEZE, "mods/MAPGEN/grug_mapgen"],
                                 cwd=ROOT, stdout=handle)
        if run.returncode != 0:
            raise SystemExit("export: git archive %s failed (the history is needed)" %
                             PRE_FREEZE)
        with tarfile.open(archive) as tar:
            tar.extractall(source)
        (into / "templates").mkdir(parents=True, exist_ok=True)
        (into / "layouts").mkdir(parents=True, exist_ok=True)
        run = subprocess.run(["luajit", str(ROOT / "tools/building_templates/export.lua"),
                              str(ROOT), source + "/mods/MAPGEN/grug_mapgen/wp13", str(into)],
                             capture_output=True, text=True)
        if run.returncode != 0:
            raise SystemExit("export: export.lua failed:\n" + run.stdout + run.stderr)
        return run.stdout


def main(argv):
    if argv == ["--check"]:
        with tempfile.TemporaryDirectory(prefix="grug_freeze_out_") as out:
            report = export(Path(out))
            problems = []
            for kind in ("templates", "layouts"):
                fresh = sorted(p.name for p in (Path(out) / kind).iterdir())
                kept = sorted(p.name for p in (OUT / kind).iterdir())
                if fresh != kept:
                    problems.append("%s: the files differ: %s" %
                                    (kind, sorted(set(fresh) ^ set(kept))))
                for name in sorted(set(fresh) & set(kept)):
                    if not filecmp.cmp(Path(out) / kind / name, OUT / kind / name,
                                       shallow=False):
                        problems.append("%s/%s differs from the export" % (kind, name))
            if REPORT.read_text() != report:
                problems.append("freeze_report.txt differs from the export")
        if problems:
            raise SystemExit("export --check: FAIL\n" + "\n".join(problems))
        print("export --check: PASS (the templates are the export of %s)" % PRE_FREEZE[:8])
        return 0
    if argv:
        raise SystemExit(__doc__)
    with tempfile.TemporaryDirectory(prefix="grug_freeze_out_") as out:
        report = export(Path(out))
        for kind in ("templates", "layouts"):
            (OUT / kind).mkdir(parents=True, exist_ok=True)
            for stale in (OUT / kind).glob("*"):
                stale.unlink()
            for fresh in sorted((Path(out) / kind).iterdir()):
                (OUT / kind / fresh.name).write_bytes(fresh.read_bytes())
    REPORT.write_text(report)
    print(report.split("\n== templates:")[1].split("\n")[0].join(["templates:", ""]))
    run = subprocess.run([sys.executable, str(ROOT / "tools/building_templates/check.py"),
                          "--baseline=self", "--write-known-defects"])
    return run.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

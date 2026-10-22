#!/usr/bin/env python3
"""The freeze of the towns' buildings (Round 56 lanes FREEZE-TOWNS and
FREEZE-CAPITALS).

Builds the six start towns and the six capitals from the building generators
of their pre-freeze commits and cuts every building out of the finished towns
into building templates (docs/technical/building-template-format.md §8),
through export.lua (the start towns) and export_capitals.lua (the capitals).
Writes mods/MAPGEN/grug_mapgen/building_templates/templates/ and layouts/ (the
start towns' layouts and the capitals' rosters), the freeze reports
tools/building_templates/freeze_report.txt and freeze_report_capitals.txt, and
the known-defects baseline (check.py --baseline=self --write-known-defects).

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
import re
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# The last commit whose start towns call the building generators, and the
# last whose capitals do; each exporter runs on its own pre-freeze source.
PRE_FREEZE = "1ac0688bc5b8be597451a6aa79fadd76e911f445"
PRE_CAPITAL_FREEZE = "36698232416537fb87cd7b66ef3247db914a1cc4"
OUT = ROOT / "mods/MAPGEN/grug_mapgen/building_templates"
REPORT = ROOT / "tools/building_templates/freeze_report.txt"
REPORT_CAPITALS = ROOT / "tools/building_templates/freeze_report_capitals.txt"
EXPORTERS = (("export.lua", PRE_FREEZE, REPORT),
             ("export_capitals.lua", PRE_CAPITAL_FREEZE, REPORT_CAPITALS))


def export_one(into, exporter, commit):
    """Run one exporter on `commit`'s mapgen into `into`; returns its report."""
    with tempfile.TemporaryDirectory(prefix="grug_freeze_src_") as source:
        archive = Path(source) / "src.tar"
        with archive.open("wb") as handle:
            run = subprocess.run(["git", "archive", commit, "mods/MAPGEN/grug_mapgen"],
                                 cwd=ROOT, stdout=handle)
        if run.returncode != 0:
            raise SystemExit("export: git archive %s failed (the history is needed)" %
                             commit)
        with tarfile.open(archive) as tar:
            tar.extractall(source)
        (into / "templates").mkdir(parents=True, exist_ok=True)
        (into / "layouts").mkdir(parents=True, exist_ok=True)
        run = subprocess.run(["luajit", str(ROOT / "tools/building_templates" / exporter),
                              str(ROOT), source + "/mods/MAPGEN/grug_mapgen/wp13", str(into)],
                             capture_output=True, text=True)
        if run.returncode != 0:
            raise SystemExit("export: %s failed:\n%s%s" % (exporter, run.stdout, run.stderr))
        return run.stdout


def same_as_town(into, capital_names):
    """The capital templates whose part equals a start town's template (one
    template by format doc §8), compared without the measurements only the
    capital templates carry (`extent`, `top`)."""
    def body(path):
        lines = []
        for line in path.read_text().split("\n"):
            if not line.startswith(("#", "name ", "races ")):
                lines.append(re.sub(r" extent=\[[^\]]*\]| top=-?\d+", "", line))
        return "\n".join(lines)
    towns = {body(path): path.stem for path in sorted((into / "templates").glob("*.tpl"))
             if path.stem not in capital_names}
    return sorted((path.stem, towns[body(path)])
                  for path in (into / "templates").glob("*.tpl")
                  if path.stem in capital_names and body(path) in towns)


def export(into):
    """Run both exporters into `into`; returns {report path: text}."""
    reports = {}
    for exporter, commit, report in EXPORTERS:
        before = {path.stem for path in (into / "templates").glob("*.tpl")} \
            if (into / "templates").is_dir() else set()
        reports[report] = export_one(into, exporter, commit)
    capital_names = {path.stem for path in (into / "templates").glob("*.tpl")} - before
    same = same_as_town(into, capital_names)
    reports[REPORT_CAPITALS] += "\n".join(
        ["capital parts identical to a start town's template: %d" % len(same)] +
        ["  %s = %s" % pair for pair in same]) + "\n"
    return reports


def main(argv):
    if argv == ["--check"]:
        with tempfile.TemporaryDirectory(prefix="grug_freeze_out_") as out:
            reports = export(Path(out))
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
            for path, text in reports.items():
                if path.read_text() != text:
                    problems.append("%s differs from the export" % path.name)
        if problems:
            raise SystemExit("export --check: FAIL\n" + "\n".join(problems))
        print("export --check: PASS (the templates are the export of %s and %s)" %
              (PRE_FREEZE[:8], PRE_CAPITAL_FREEZE[:8]))
        return 0
    if argv:
        raise SystemExit(__doc__)
    with tempfile.TemporaryDirectory(prefix="grug_freeze_out_") as out:
        reports = export(Path(out))
        for kind in ("templates", "layouts"):
            (OUT / kind).mkdir(parents=True, exist_ok=True)
            for stale in (OUT / kind).glob("*"):
                stale.unlink()
            for fresh in sorted((Path(out) / kind).iterdir()):
                (OUT / kind / fresh.name).write_bytes(fresh.read_bytes())
    for path, text in reports.items():
        path.write_text(text)
        print(path.name + ": templates" + text.split("\n== templates:")[1].split("\n")[0])
    run = subprocess.run([sys.executable, str(ROOT / "tools/building_templates/check.py"),
                          "--baseline=self", "--write-known-defects"])
    return run.returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

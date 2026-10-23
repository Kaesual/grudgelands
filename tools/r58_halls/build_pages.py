#!/usr/bin/env python3
"""Build the two review pages of the Miner's Guild houses (Round 58 lane HALLS).

    python3 tools/r58_halls/build_pages.py OUT_DIR [--standalone]

Writes OUT_DIR/halls_gallery.html, the template gallery of the six houses
alone (building_templates/viewer/build_gallery.py over a copy of the six
templates and the capitals' rosters cut to their house lines, so "As placed"
resolves each house with its capital's palettes), and OUT_DIR/halls_cores.html,
the town viewer of the six civic cores with their houses
(building_templates/viewer/build_viewer.py over tools/r58_halls/view/).
Without --standalone the pages are written as the Artifact publisher takes
them (no <html> wrapper).
"""

import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
VIEWER = os.path.join(REPO, "tools", "building_templates", "viewer")
BASE = os.path.join("mods", "MAPGEN", "grug_mapgen", "building_templates")
CAPITALS = ["highcourt", "dur_brannoc", "lethariel", "nhal_veyr", "gor_drazhak",
            "kezamba"]


def run(command):
    proc = subprocess.run(command, cwd=REPO, capture_output=True, text=True)
    sys.stderr.write(proc.stderr)
    if proc.returncode != 0:
        raise SystemExit("build_pages: %s failed" % " ".join(command[:2]))


def main(argv):
    if not argv or argv[0].startswith("-"):
        raise SystemExit(__doc__)
    out = os.path.abspath(argv[0])
    flags = ["--standalone"] if "--standalone" in argv[1:] else []
    os.makedirs(out, exist_ok=True)
    gallery = os.path.join(out, "halls_gallery.html")
    with tempfile.TemporaryDirectory(prefix="grug_r58_halls_") as scratch:
        source = os.path.join(scratch, "building_templates")
        os.makedirs(os.path.join(source, "templates"))
        os.makedirs(os.path.join(source, "layouts"))
        for key in CAPITALS:
            name = key + "_miners_guild"
            shutil.copy(os.path.join(REPO, BASE, "templates", name + ".tpl"),
                        os.path.join(source, "templates"))
            with open(os.path.join(REPO, BASE, "layouts", key + ".roster")) as handle:
                lines = handle.read().split("\n")
            kept = [line for line in lines if not line.startswith("use ") or
                    line.split()[1] == name]
            with open(os.path.join(source, "layouts", key + ".roster"), "w") as handle:
                handle.write("\n".join(kept))
        run([sys.executable, os.path.join(VIEWER, "build_gallery.py"), "--source", source,
             "--title", "Miner's Guild Houses", "-o", gallery] + flags)
        # the page names each file by its path: show the repository's
        with open(gallery, encoding="utf-8") as handle:
            text = handle.read()
        prefix = os.path.relpath(source, REPO)
        text = text.replace(prefix, BASE).replace(source, BASE)
        if scratch in text:
            raise SystemExit("build_pages: the scratch path is still in the gallery")
        with open(gallery, "w", encoding="utf-8") as handle:
            handle.write(text)
    run([sys.executable, os.path.join(VIEWER, "build_viewer.py")] +
        [os.path.join("tools", "r58_halls", "view", key + "_core_blueprint.lua")
         for key in CAPITALS] +
        ["--title", "Miner's Guild Houses in the Capital Cores", "-o",
         os.path.join(out, "halls_cores.html")] + flags)
    print("wrote", gallery, "and", os.path.join(out, "halls_cores.html"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

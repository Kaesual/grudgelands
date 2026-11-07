#!/usr/bin/env python3
"""Install the picked Stonewright art (Round 70 lane GUILD).

    python3 tools/r70_guild/make_machines.py          # copy and write
    python3 tools/r70_guild/make_machines.py --check  # installed == sources

Lane ART's final folder (tools/r70_art/candidates/final, INSTALL.md) is the
source. The PNGs are copied unchanged into the owning mods' textures folders
(the Thread icon to grug_professions, the rest to grug_guild). The two JSON
construction records stay build inputs: this script writes their cells as
mods/PLAYER/grug_guild/machines_data.lua, pure Lua the game loads, and
tools/r58_halls/make_halls.py reads the same records for the cells' offsets.
"""
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
FINAL = os.path.join(REPO, "tools", "r70_art", "candidates", "final")
GUILD = os.path.join(REPO, "mods", "PLAYER", "grug_guild")
PROFESSIONS = os.path.join(REPO, "mods", "ITEMS", "grug_professions")
DATA = os.path.join(GUILD, "machines_data.lua")


def lua_number(value):
    return repr(value) if isinstance(value, float) else str(value)


def lua_tile(tile):
    fields = ['name = "%s"' % tile["name"], 'align_style = "%s"' % tile["align_style"]]
    animation = tile.get("animation")
    if animation:
        fields.append('animation = {type = "%s", aspect_w = %d, aspect_h = %d, length = %s}' % (
            animation["type"], animation["aspect_w"], animation["aspect_h"],
            lua_number(animation["length"])))
    return "{" + ", ".join(fields) + "}"


def data_text():
    lines = [
        "-- Written by tools/r70_guild/make_machines.py from lane ART's construction",
        "-- records (tools/r70_art/candidates/final/*.json): edit those, not this file.",
        "-- One row per occupied cell of the two machines; tiles in the engine's order",
        "-- (top, bottom, right, left, back, front), facing -z at facedir 0.",
        "return {",
    ]
    for machine in ("grinder", "furnace"):
        with open(os.path.join(FINAL, machine + ".json"), encoding="utf-8") as handle:
            record = json.load(handle)
        for cell in sorted(record["cells"], key=lambda row: row["name"]):
            lines.append('\t{name = "%s", machine = "%s",' % (cell["name"], machine))
            lines.append("\t\tlight_source = %d, node_box = {" % cell["light_source"])
            for box in cell["node_box"]:
                lines.append("\t\t\t{%s}," % ", ".join(lua_number(n) for n in box))
            lines.append("\t\t}, tiles = {")
            for tile in cell["tiles"]:
                lines.append("\t\t\t%s," % lua_tile(tile))
            lines.append("\t\t}},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def media():
    """(source, installed) of every picked PNG."""
    pairs = []
    for name in sorted(os.listdir(FINAL)):
        if name.endswith(".png"):
            owner = PROFESSIONS if name.startswith("grug_professions_") else GUILD
            pairs.append((os.path.join(FINAL, name), os.path.join(owner, "textures", name)))
    return pairs


def same_bytes(a, b):
    if not os.path.exists(b):
        return False
    with open(a, "rb") as first, open(b, "rb") as second:
        return first.read() == second.read()


def main(argv):
    check = argv == ["--check"]
    if argv and not check:
        raise SystemExit(__doc__)
    text = data_text()
    pairs = media()
    if check:
        stale = [os.path.relpath(path, REPO) for source, path in pairs
                 if not same_bytes(source, path)]
        if not os.path.exists(DATA) or open(DATA, encoding="utf-8").read() != text:
            stale.append(os.path.relpath(DATA, REPO))
        if stale:
            raise SystemExit("make_machines --check: FAIL, stale: " + ", ".join(stale))
        print("make_machines --check: PASS (%d PNGs, %s)" % (len(pairs), os.path.basename(DATA)))
        return 0
    for source, path in pairs:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        shutil.copyfile(source, path)
    with open(DATA, "w", encoding="utf-8") as handle:
        handle.write(text)
    print("installed %d PNGs and %s" % (len(pairs), os.path.relpath(DATA, REPO)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

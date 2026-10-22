#!/usr/bin/env python3
"""The building template validator (docs/technical/building-template-format.md §6).

The one validator for the gate and the editor (which imports `validate`). It
reads every template and town layout under
mods/MAPGEN/grug_mapgen/building_templates/, the palettes and the param2 rules
of the game's own Lua (through tools/building_templates/palette_dump.lua under
LuaJIT), the node registry tools/building_templates/nodes.json, the editor
palette tools/building_templates/editor_palette.txt and the known defects.

Rules (ruling 33): structure is always hard (§6.1); the editor palette,
reachability and the entrance on the footprint edge are hard only for templates
with cells edited against their BASELINE version (§6.2); warnings (§6.3). A hard
finding listed in known_defects.txt is reported as a warning (the frozen
state's known defects); an entry that no longer holds is reported too.

Usage (repository root):
  python3 tools/building_templates/check.py                 # the gate
  python3 tools/building_templates/check.py --baseline=self # the freeze itself
  python3 tools/building_templates/check.py --baseline=self --write-known-defects
      (the exporter: every hard finding of the frozen state becomes a known
      defect)
  python3 tools/building_templates/check.py --self-test
Exits non-zero on any error.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "mods/MAPGEN/grug_mapgen/building_templates"
TEMPLATE_MAGIC = "grudgelands-building-template 1"
LAYOUT_MAGIC = "grudgelands-town-layout 1"
RACES = ("dwarf", "human", "elf", "undead", "orc", "troll")
KINDS = {"facedir": "facedir", "wallmounted": "wallmounted"}
FACE_STEP = {0: (0, 1), 1: (1, 0), 2: (0, -1), 3: (-1, 0)}
STANDING_GROUPS = ("inside", "sockets")


class FormatError(Exception):
    def __init__(self, path, line, reason):
        super().__init__("%s:%s: %s" % (path, line if line else "?", reason))
        self.path, self.line, self.reason = path, line, reason


# --------------------------------------------------------------------------
# parsing (the format, §3 and §4)
# --------------------------------------------------------------------------

BARE = re.compile(r"^[A-Za-z0-9_:.{}-]+$")
INTEGER = re.compile(r"^-?\d+$")


def scalar(text):
    if INTEGER.match(text):
        return int(text)
    if text == "true":
        return True
    if text == "false":
        return False
    if len(text) >= 2 and text[0] == '"' and text[-1] == '"' and '"' not in text[1:-1]:
        return text[1:-1]
    if BARE.match(text) and not re.search(r"[{}]", text.replace("{id}", "")):
        return text
    raise ValueError(text)


def value_of(text):
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1]
        return [] if inner == "" else [scalar(item) for item in inner.split(",")]
    return scalar(text)


def tokens(line):
    out, current, quote = [], "", False
    for char in line:
        if char == '"':
            quote = not quote
            current += char
        elif char.isspace() and not quote:
            if current:
                out.append(current)
                current = ""
        else:
            current += char
    if quote:
        raise ValueError("an unterminated string")
    if current:
        out.append(current)
    return out


def comment_or_blank(line):
    stripped = line.strip()
    return stripped == "" or stripped.startswith("#")


def split_lines(text, path):
    if "\r" in text:
        raise FormatError(path, None, "carriage return in the file (only \\n line ends)")
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return lines


def parse_entry(text, cell, facts):
    words = text.split()
    if not words:
        raise ValueError("an empty legend entry")
    kind = words[0]
    if kind == "role":
        if len(words) < 2:
            raise ValueError("a role entry names its role")
        role = words[1]
        entry = {"kind": "role", "role": role, "variant": None, "channel": None,
                 "o": None, "fallback": None}
        for word in words[2:]:
            key, _, value = word.partition("=")
            if key == "variant" and value:
                entry["variant"] = value
            elif key == "channel" and re.match(r"^[A-Za-z_]\w*$", value):
                entry["channel"] = value
            elif key == "o" and value:
                entry["o"] = value
            elif key == "else" and value:
                entry["fallback"] = value
            else:
                raise ValueError("bad role option " + word)
        return entry
    if kind == "node":
        if len(words) < 2 or not re.match(r"^[\w]+:[\w]+$", words[1]):
            raise ValueError("bad node name %s" % (words[1] if len(words) > 1 else ""))
        entry = {"kind": "node", "name": words[1], "o": None}
        for word in words[2:]:
            if not word.startswith("o="):
                raise ValueError("bad node option " + word)
            entry["o"] = word[2:]
        return entry
    if kind == "race":
        entry = {"kind": "race", "map": {}, "order": []}
        for word in words[1:]:
            race, sep, key = word.partition("=")
            if not sep or len(key) != cell or (race != "*" and race not in RACES):
                raise ValueError("bad race switch " + word)
            if race in entry["map"]:
                raise ValueError("race %s switched twice" % race)
            entry["map"][race] = key
            entry["order"].append(race)
        if not entry["order"]:
            raise ValueError("an empty race switch")
        return entry
    raise ValueError("unknown legend entry " + kind)


def orientation(text):
    match = re.match(r"^(facedir|wallmounted):(\d+)$", text or "")
    if not match:
        return None
    value = int(match.group(2))
    if (match.group(1) == "facedir" and value > 23) or (
            match.group(1) == "wallmounted" and value > 5):
        return None
    return match.group(1), value


def parse_template(text, path, expected_name=None, facts=None):
    lines = split_lines(text, path)
    index = [1]

    def fail(number, reason):
        raise FormatError(path, number, reason)

    if not lines or lines[0] != TEMPLATE_MAGIC:
        fail(1, "the first line must be '%s'" % TEMPLATE_MAGIC)

    def next_line():
        while index[0] < len(lines) and comment_or_blank(lines[index[0]]):
            index[0] += 1
        if index[0] >= len(lines):
            return None, None
        number, line = index[0] + 1, lines[index[0]]
        index[0] += 1
        return number, line

    t = {"path": path, "meta": [], "legend": {}, "legend_order": [], "grid": {},
         "points": [], "races": None}
    while True:
        number, line = next_line()
        if line is None:
            fail(len(lines), "the file ends before its legend")
        words = line.split()
        head = words[0]
        ints = [INTEGER.match(w) is not None for w in words[1:]]
        if head == "legend" and len(words) == 1:
            break
        if head == "name" and len(words) == 2 and re.match(r"^[a-z0-9_]+$", words[1]):
            t["name"] = words[1]
        elif head == "pivot" and len(words) == 3 and all(ints):
            t["w"], t["d"] = int(words[1]), int(words[2])
            if t["w"] < 1 or t["d"] < 1:
                fail(number, "the pivot must be at least 1 x 1")
        elif head == "origin" and len(words) == 4 and all(ints):
            t["x0"], t["y0"], t["z0"] = (int(w) for w in words[1:])
        elif head == "size" and len(words) == 4 and all(ints):
            t["sx"], t["sy"], t["sz"] = (int(w) for w in words[1:])
            if min(t["sx"], t["sy"], t["sz"]) < 1:
                fail(number, "every size must be at least 1")
        elif head == "cell" and len(words) == 2 and words[1] in ("1", "2"):
            t["cell"] = int(words[1])
        elif head == "meta":
            try:
                for word in tokens(line)[1:]:
                    key, sep, raw = word.partition("=")
                    if not sep or not re.match(r"^[A-Za-z_]\w*$", key):
                        raise ValueError(word)
                    t["meta"].append((key, value_of(raw)))
            except ValueError as error:
                fail(number, "bad meta value %s" % error)
        elif head == "races" and len(words) >= 2:
            for race in words[1:]:
                if race not in RACES:
                    fail(number, "unknown race " + race)
            t["races"] = words[1:]
        else:
            fail(number, "unknown header line")
    for field in ("name", "w", "x0", "sx", "cell", "races"):
        if t.get(field) is None:
            fail(index[0], "the header lacks " + field)
    if expected_name and t["name"] != expected_name:
        fail(2, "name %s differs from the file name %s" % (t["name"], expected_name))
    cell = t["cell"]
    while True:
        number, line = next_line()
        if line is None:
            fail(len(lines), "the legend has no end")
        if line == "end":
            break
        key = line[:cell]
        if len(key) != cell or line[cell:cell + 1] != " " or re.search(r"[\s.|#]", key) or \
                any(ord(c) < 33 or ord(c) > 126 for c in key):
            fail(number, "bad legend key")
        if key in t["legend"]:
            fail(number, "legend key '%s' given twice" % key)
        try:
            entry = parse_entry(line[cell + 1:], cell, facts)
        except ValueError as error:
            fail(number, str(error))
        if entry.get("o") and not orientation(entry["o"]):
            fail(number, "bad orientation " + entry["o"])
        entry["key"], entry["line"] = key, number
        t["legend"][key] = entry
        t["legend_order"].append(key)
    air, keep = "." * cell, " " * cell
    width = t["sx"] * cell + 2
    for y in range(t["y0"], t["y0"] + t["sy"]):
        number, line = next_line()
        if line != "layer %d" % y:
            fail(number or len(lines), "expected 'layer %d'" % y)
        for z in range(t["z0"], t["z0"] + t["sz"]):
            if index[0] >= len(lines) or not lines[index[0]].startswith("|"):
                fail(index[0] + 1, "layer %d lacks its row for z %d" % (y, z))
            row, number = lines[index[0]], index[0] + 1
            index[0] += 1
            if len(row) != width or not row.endswith("|"):
                fail(number, "the row for z %d must be %d cells between two '|'" % (z, t["sx"]))
            for i in range(t["sx"]):
                token = row[1 + i * cell:1 + (i + 1) * cell]
                position = (t["x0"] + i, y, z)
                if token == keep:
                    continue
                if token == air:
                    t["grid"][position] = "."
                elif token in t["legend"]:
                    t["grid"][position] = token
                else:
                    fail(number, "the cell '%s' at x %d is not in the legend" %
                         (token, position[0]))
    number, line = next_line()
    if line != "points":
        fail(number or len(lines), "expected 'points'")
    while True:
        number, line = next_line()
        if line is None:
            fail(len(lines), "the points have no end")
        if line == "end":
            break
        try:
            words = tokens(line)
        except ValueError:
            fail(number, "an unterminated string")
        if len(words) < 4 or not re.match(r"^[A-Za-z_]\w*$", words[0]) or \
                not all(INTEGER.match(w) for w in words[1:4]):
            fail(number, "a point is '<group> <x> <y> <z> [face=n] [key=value ...]'")
        point = {"group": words[0], "x": int(words[1]), "y": int(words[2]),
                 "z": int(words[3]), "face": None, "attrs": [], "line": number}
        for word in words[4:]:
            key, sep, raw = word.partition("=")
            if not sep or not re.match(r"^[A-Za-z_]\w*$", key) or key in ("x", "y", "z"):
                fail(number, "bad point attribute " + word)
            try:
                value = value_of(raw)
            except ValueError:
                fail(number, "bad point attribute " + word)
            if key == "face":
                if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value <= 3:
                    fail(number, "face must be 0 to 3")
                point["face"] = value
            else:
                point["attrs"].append((key, value))
        if not (t["x0"] <= point["x"] < t["x0"] + t["sx"] and
                t["y0"] <= point["y"] < t["y0"] + t["sy"] and
                t["z0"] <= point["z"] < t["z0"] + t["sz"]):
            fail(number, "the point lies outside the box")
        t["points"].append(point)
    number, line = next_line()
    if line is not None:
        fail(number, "nothing may follow the points")
    return t


def parse_layout(text, path):
    lines = split_lines(text, path)
    if not lines or lines[0] != LAYOUT_MAGIC:
        raise FormatError(path, 1, "the first line must be '%s'" % LAYOUT_MAGIC)
    layout = {"path": path, "town": None, "race": None, "palettes": {}, "places": []}
    for number, line in enumerate(lines[1:], start=2):
        if comment_or_blank(line):
            continue
        words = line.split()
        head = words[0]
        if head == "town" and len(words) == 2 and re.match(r"^[a-z0-9_]+$", words[1]):
            layout["town"] = words[1]
        elif head == "race" and len(words) == 2 and words[1] in RACES:
            layout["race"] = words[1]
        elif head == "palette" and len(words) >= 3 and re.match(r"^[a-z0-9_]+$", words[1]):
            if words[1] in layout["palettes"]:
                raise FormatError(path, number, "palette %s given twice" % words[1])
            race = words[2][5:] if words[2].startswith("race=") else None
            if race not in RACES:
                raise FormatError(path, number, "bad palette race")
            overrides = {}
            for word in words[3:]:
                match = re.match(r"^([A-Za-z_]+)=(\w+:\w+)$", word)
                if not match:
                    raise FormatError(path, number, "bad override " + word)
                overrides[match.group(1)] = match.group(2)
            layout["palettes"][words[1]] = {"race": race, "overrides": overrides,
                                            "line": number}
        elif head == "place" and len(words) >= 7 and re.match(r"^[a-z0-9_]+$", words[1]):
            place = {"id": words[1], "channels": {}, "main": None, "lift": None,
                     "line": number}
            for word in words[2:]:
                key, sep, value = word.partition("=")
                if not sep:
                    raise FormatError(path, number, "bad placement field " + word)
                if key == "template":
                    place["template"] = value
                elif key in ("x", "y", "z", "turns", "lift"):
                    if not INTEGER.match(value):
                        raise FormatError(path, number, key + " must be an integer")
                    place[key] = int(value)
                elif key == "main":
                    place["main"] = value
                else:
                    if key in place["channels"]:
                        raise FormatError(path, number, "channel %s given twice" % key)
                    place["channels"][key] = value
            for field in ("template", "x", "y", "z", "turns"):
                if field not in place:
                    raise FormatError(path, number,
                                      "a placement needs template=, x=, y=, z= and turns=")
            if not 0 <= place["turns"] <= 3:
                raise FormatError(path, number, "turns must be 0 to 3")
            layout["places"].append(place)
        else:
            raise FormatError(path, number, "unknown layout line")
    if not layout["town"] or not layout["race"]:
        raise FormatError(path, 1, "a layout names its town and race")
    return layout


# --------------------------------------------------------------------------
# the game's facts
# --------------------------------------------------------------------------

def lua_facts(root, names):
    """Palettes and param2 rules from the game's Lua (palette_dump.lua)."""
    run = subprocess.run(["luajit", str(root / "tools/building_templates/palette_dump.lua"),
                          str(root)], input="\n".join(sorted(names)), capture_output=True,
                         text=True)
    if run.returncode != 0:
        raise SystemExit("check: palette_dump.lua failed: " + run.stderr.strip())
    facts = {"required": [], "optional": [], "families": {}, "binds": {}, "kinds": {}}
    for line in run.stdout.splitlines():
        words = line.split()
        if words[0] == "required":
            facts["required"].append(words[1])
        elif words[0] == "optional":
            facts["optional"].append(words[1])
        elif words[0] == "family":
            facts["families"][words[1]] = words[2:]
        elif words[0] == "bind":
            facts["binds"].setdefault(words[1], {})[words[2]] = words[3]
        elif words[0] == "kind":
            facts["kinds"][words[1]] = (words[2], int(words[3]), words[4] == "1",
                                       words[5] == "1")
    return facts


def registry(root):
    data = json.loads((root / "tools/building_templates/nodes.json").read_text())
    return data["nodes"]


def editor_palette(root):
    roles, nodes = set(), set()
    path = root / "tools/building_templates/editor_palette.txt"
    for line in path.read_text().splitlines():
        words = line.split()
        if not words or words[0].startswith("#") or words[0].startswith("["):
            continue
        if words[0] == "role" and len(words) == 2:
            roles.add(words[1])
        elif words[0] == "node" and len(words) == 2:
            nodes.add(words[1])
        else:
            raise SystemExit("check: %s: bad line %r" % (path, line))
    return roles, nodes


# --------------------------------------------------------------------------
# checking
# --------------------------------------------------------------------------

class Report:
    def __init__(self):
        self.errors, self.warnings = [], []

    def error(self, rule, where, position, message):
        self.errors.append((rule, where, position, message))

    def warn(self, rule, where, position, message):
        self.warnings.append((rule, where, position, message))


def entry_text(t, key, depth=0):
    """A legend entry as words, its fallback and switch targets resolved, so a
    renamed key is no edit."""
    if key == ".":
        return "air"
    entry = t["legend"].get(key)
    if entry is None or depth > 8:
        return "?"
    if entry["kind"] == "node":
        return "node %s o=%s" % (entry["name"], entry["o"])
    if entry["kind"] == "race":
        return "race " + " ".join("%s=<%s>" % (race, entry_text(t, entry["map"][race], depth + 1))
                                  for race in sorted(entry["map"]))
    fallback = entry["fallback"]
    if fallback not in (None, "air", "unchanged"):
        fallback = "<%s>" % entry_text(t, fallback, depth + 1)
    return "role %s variant=%s channel=%s o=%s else=%s" % (
        entry["role"], entry["variant"], entry["channel"], entry["o"], fallback or "unchanged")


class Context:
    """One way a template is placed: a race and its channel palettes."""

    def __init__(self, label, race, main, channels):
        self.label, self.race, self.main, self.channels = label, race, main, channels

    def palette(self, channel):
        if channel and channel in self.channels:
            return self.channels[channel]
        return self.main


def palette_of(facts, race, overrides):
    bound = dict(facts["binds"].get(race, {}))
    bound.update(overrides or {})
    return bound


def resolve(t, key, context, facts, depth=0):
    """(node or None for 'write nothing', template-frame param2, entry, problem)."""
    if key == ".":
        return "air", 0, None, None
    entry = t["legend"][key]
    if entry["kind"] == "race":
        target = entry["map"].get(context.race, entry["map"].get("*"))
        if target is None:
            return None, 0, entry, ("legend", "the race switch '%s' does not cover %s" %
                                    (key, context.race))
        return resolve(t, target, context, facts, depth + 1)
    if entry["kind"] == "node":
        name = entry["name"]
    else:
        base = context.palette(entry["channel"]).get(entry["role"])
        name = None
        if base is not None:
            name = base + entry["variant"] if entry["role"] in facts["families"] else base
        if name is None:
            optional = entry["role"] in facts["optional"]
            if not optional:
                return None, 0, entry, ("role_bound", "role %s is not bound for %s (%s)" %
                                        (entry["role"], context.race, context.label))
            fallback = entry["fallback"] or "unchanged"
            if fallback == "unchanged":
                return None, 0, entry, None
            if fallback == "air":
                return "air", 0, entry, None
            if depth > 8:
                return None, 0, entry, ("legend", "else= chain too long")
            return resolve(t, fallback, context, facts, depth + 1)
    kind, place, shaped, tree = facts["kinds"].get(name, ("none", 0, False, False))
    if kind == "none":
        if entry["kind"] == "node" and entry["o"]:
            return name, 0, entry, ("orientation", "%s has no orientation, o=%s" %
                                    (name, entry["o"]))
        return name, 0, entry, None
    if kind == "meshoptions" or not entry["o"]:
        return name, place, entry, None
    stored, value = orientation(entry["o"])
    if stored != kind:
        return name, value, entry, ("orientation", "o=%s does not fit %s (%s) for %s" %
                                    (entry["o"], name, kind, context.race))
    axis = value - value % 4
    if kind == "facedir" and axis != 0 and not (tree and value < 24):
        if axis != 20:
            return name, value, entry, ("orientation", "facedir axis %d on %s" % (axis, name))
        if not shaped:
            return name, value, entry, ("orientation", "only a stair or a slab may be "
                                        "upside down, not " + name)
    return name, value, entry, None


def is_door_leaf(name):
    return name is not None and re.match(r"^doors:door_\w+_[ab]$", name) is not None


def walk(cells, t, nodes):
    """Standing cells and the reachable ones from the entrances (§6.2)."""
    def passable(position):
        name = cells.get(position, "unchanged")
        if name == "unchanged":
            return True
        if is_door_leaf(name) or name == "doors:hidden":
            return True
        return not nodes.get(name, {}).get("walkable", True)

    def walkable(position):
        name = cells.get(position, "unchanged")
        if name == "unchanged":
            return position[1] <= 0
        return bool(nodes.get(name, {}).get("walkable", True))

    def standing(x, y, z):
        return passable((x, y, z)) and passable((x, y + 1, z)) and walkable((x, y - 1, z))

    x0, x1 = t["x0"], t["x0"] + t["sx"] - 1
    z0, z1 = t["z0"], t["z0"] + t["sz"] - 1
    y0, y1 = t["y0"], t["y0"] + t["sy"]
    starts = [(p["x"], p["y"], p["z"]) for p in t["points"] if p["group"] == "doors"]
    starts = [s for s in starts if standing(*s)]
    if not any(p["group"] == "doors" for p in t["points"]):
        for x in range(x0, x1 + 1):
            for z in range(z0, z1 + 1):
                if x in (x0, x1) or z in (z0, z1):
                    for y in range(y0, y1 + 1):
                        if standing(x, y, z):
                            starts.append((x, y, z))
    seen = set(starts)
    queue = list(starts)
    while queue:
        x, y, z = queue.pop()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = x + dx, z + dz
            if not (x0 <= nx <= x1 and z0 <= nz <= z1):
                continue
            for ny in (y - 1, y, y + 1):
                if y0 <= ny <= y1 and (nx, ny, nz) not in seen and standing(nx, ny, nz):
                    seen.add((nx, ny, nz))
                    queue.append((nx, ny, nz))
    return standing, seen, passable


def resolved_cells(t, context, facts):
    cells, problems = {}, []
    for position, key in t["grid"].items():
        name, param2, entry, problem = resolve(t, key, context, facts)
        if problem:
            problems.append((position, problem))
        if name is not None:
            cells[position] = (name, param2, entry)
    return cells, problems


def check_template(t, contexts, facts, nodes, report, baseline, palette_roles,
                   palette_nodes):
    name = t["name"]
    # legend
    for key in t["legend_order"]:
        entry = t["legend"][key]
        where = (name, None)
        if entry["kind"] == "role":
            role = entry["role"]
            declared = role in facts["required"] or role in facts["optional"] or \
                role in facts["families"]
            if not declared:
                report.error("legend", name, None, "line %d: role %s is not declared in "
                             "palette.lua" % (entry["line"], role))
                continue
            family = facts["families"].get(role)
            if family and entry["variant"] not in family:
                report.error("legend", name, None, "line %d: role %s needs a variant of %s"
                             % (entry["line"], role, ", ".join(family)))
            if not family and entry["variant"]:
                report.error("legend", name, None, "line %d: role %s has no variants" %
                             (entry["line"], role))
            optional = role in facts["optional"] or role in ("bed_fancy", "pillar")
            if entry["fallback"] and not optional:
                report.error("legend", name, None, "line %d: else= on the required role %s"
                             % (entry["line"], role))
            fallback = entry["fallback"]
            if fallback and fallback not in ("air", "unchanged"):
                target = t["legend"].get(fallback)
                if target is None or target["kind"] == "race":
                    report.error("legend", name, None, "line %d: else= names %s" %
                                 (entry["line"], "a race switch" if target else
                                  "the undefined key '%s'" % fallback))
        elif entry["kind"] == "race":
            for race in entry["order"]:
                target = t["legend"].get(entry["map"][race])
                if target is None or target["kind"] == "race":
                    report.error("legend", name, None, "line %d: the race switch names %s" %
                                 (entry["line"], "another switch" if target else
                                  "an undefined key"))
    if report.errors and any(e[1] == name and e[0] == "legend" for e in report.errors):
        return
    # races header
    placing = sorted({c.race for c in contexts}, key=RACES.index)
    if contexts and placing != sorted(set(t["races"]), key=RACES.index):
        report.error("layout", name, None, "the races header %s differs from the placing "
                     "races %s" % (" ".join(t["races"]), " ".join(placing)))
    if not contexts:
        report.warn("unused", name, None, "no layout places this template")
        contexts = [Context("races header", race, palette_of(facts, race, None), {})
                    for race in t["races"]]
    by_position = {}
    for context in contexts:
        cells, problems = resolved_cells(t, context, facts)
        for position, (rule, message) in problems:
            report.error(rule, name, position, message)
        for position, (node, param2, entry) in cells.items():
            if node != "air" and node not in nodes:
                report.error("known_node", name, position, "%s is not in the registry (%s)" %
                             (node, context.label))
        by_position[context.label] = cells
        # multi-cell objects (§5)
        for position, (node, param2, entry) in cells.items():
            x, y, z = position
            if is_door_leaf(node):
                above = cells.get((x, y + 1, z))
                want = param2 % 4 if node.endswith("_a") else (param2 + 3) % 4
                if not above or above[0] != "doors:hidden" or above[1] != want:
                    report.error("multi_cell", name, position, "the door leaf %s lacks its "
                                 "door_hidden (facedir %d) above it" % (node, want))
            elif node == "doors:hidden":
                below = cells.get((x, y - 1, z))
                if not below or not is_door_leaf(below[0]):
                    report.error("multi_cell", name, position, "door_hidden without its leaf")
            elif node.startswith("beds:") and node.endswith("_bottom"):
                dx, dz = FACE_STEP[param2 % 4]
                head = cells.get((x + dx, y, z + dz))
                if not head or head[0] != node[:-7] + "_top" or head[1] != param2:
                    report.error("multi_cell", name, position, "the bed %s lacks its _top "
                                 "one step along facedir %d" % (node, param2))
            elif node.startswith("beds:") and node.endswith("_top"):
                dx, dz = FACE_STEP[param2 % 4]
                foot = cells.get((x - dx, y, z - dz))
                if not foot or foot[0] != node[:-4] + "_bottom" or foot[1] != param2:
                    report.error("multi_cell", name, position, "the bed head %s lacks its "
                                 "_bottom" % node)
        # points (§3.4)
        names = {p: c[0] for p, c in cells.items()}
        standing, reach, passable = walk(names, t, nodes)
        corners = [p for p in t["points"] if p["group"] == "room_corner"]
        for point in t["points"]:
            position = (point["x"], point["y"], point["z"])
            if point["group"] == "doors":
                here = cells.get(position)
                above = (point["x"], point["y"] + 1, point["z"])
                leaf = here is not None and is_door_leaf(here[0]) and \
                    here[1] % 4 == point["face"]
                open_way = (here is None or not is_door_leaf(here[0])) and \
                    passable(position) and passable(above)
                if not (leaf or open_way):
                    report.error("point_place", name, position, "the door point is not in a "
                                 "doorway facing %s (%s)" % (point["face"], context.label))
            elif point["group"] in STANDING_GROUPS:
                if not standing(*position):
                    report.error("point_place", name, position, "the %s point is not a "
                                 "standing point (%s)" % (point["group"], context.label))
        if len(corners) % 2:
            report.error("point_pair", name, None, "room_corner points come in pairs")
        for a, b in zip(corners[0::2], corners[1::2]):
            if a["y"] != b["y"]:
                report.error("point_pair", name, (a["x"], a["y"], a["z"]),
                             "a room_corner pair differs in y")
        # warnings: a "leave unchanged" floor cell inside a room
        for a, b in zip(corners[0::2], corners[1::2]):
            for x in range(min(a["x"], b["x"]), max(a["x"], b["x"]) + 1):
                for z in range(min(a["z"], b["z"]), max(a["z"], b["z"]) + 1):
                    if (x, a["y"], z) not in t["grid"]:
                        report.warn("floor_gap", name, (x, a["y"], z),
                                    "a 'leave unchanged' cell in a room's floor")
        context.reach, context.standing = reach, standing
    # against the baseline version (§6.1 and §6.2)
    if baseline is None:
        edited = set(t["grid"]) | {(x, y, z) for x in range(t["x0"], t["x0"] + t["sx"])
                                   for y in range(t["y0"], t["y0"] + t["sy"])
                                   for z in range(t["z0"], t["z0"] + t["sz"])}
        edited = {p for p in edited}
    else:
        if (baseline["w"], baseline["d"]) != (t["w"], t["d"]) or \
                (baseline["x0"], baseline["y0"], baseline["z0"], baseline["sx"],
                 baseline["sy"], baseline["sz"]) != (t["x0"], t["y0"], t["z0"], t["sx"],
                                                     t["sy"], t["sz"]):
            report.error("box_baseline", name, None, "the box or the pivot differs from "
                         "the baseline version")
        old_points, new_points = baseline["points"], t["points"]
        same = len(old_points) == len(new_points) and all(
            a["group"] == b["group"] and a["face"] == b["face"] and a["attrs"] == b["attrs"]
            for a, b in zip(old_points, new_points))
        if not same:
            report.error("point_baseline", name, None, "the points' groups, order, faces "
                         "or attributes differ from the baseline version (only positions "
                         "may change)")
        edited = set()
        for position in set(t["grid"]) | set(baseline["grid"]):
            if entry_text(t, t["grid"].get(position, " ")) != \
                    entry_text(baseline, baseline["grid"].get(position, " ")):
                edited.add(position)
        for a, b in zip(old_points, new_points):
            if (a["x"], a["y"], a["z"]) != (b["x"], b["y"], b["z"]):
                edited.add(("point", b["line"]))
    if not edited:
        return
    shared = len(t["races"]) > 1
    for position in sorted(p for p in edited if p[0] != "point"):
        key = t["grid"].get(position)
        if key in (None, "."):
            continue
        keys = [key]
        entry = t["legend"][key]
        if entry["kind"] == "race":
            keys = [entry["map"][race] for race in entry["order"]]
        for k in keys:
            target = t["legend"][k]
            allowed = (target["kind"] == "role" and target["role"] in palette_roles) or \
                (target["kind"] == "node" and target["name"] in palette_nodes)
            if not allowed:
                report.error("edit_palette", name, position, "the edited cell holds %s, "
                             "which the editor palette does not offer" % entry_text(t, k))
            if target["kind"] == "node" and shared:
                report.warn("fixed_in_shared", name, position, "a fixed node painted into "
                            "a template %s place" % " and ".join(t["races"]))
    # reachability and the entrance, against the baseline version
    if baseline is None:
        return
    for context in contexts:
        old_cells, _ = resolved_cells(baseline, context, facts)
        old_standing, old_reach, _ = walk({p: c[0] for p, c in old_cells.items()}, baseline,
                                       nodes)
        for old, new in zip(baseline["points"], t["points"]):
            if old["group"] not in STANDING_GROUPS:
                continue
            was = (old["x"], old["y"], old["z"]) in old_reach
            now = (new["x"], new["y"], new["z"]) in context.reach
            if was and not now:
                report.error("reach", name, (new["x"], new["y"], new["z"]),
                             "the %s point %s is no longer reachable from an entrance (%s)"
                             % (new["group"], dict(new["attrs"]).get("id", ""),
                                context.label))

        def on_edge(point, template):
            x, z = point["x"], point["z"]
            return -1 <= x <= template["w"] and -1 <= z <= template["d"] and (
                x <= 0 or x >= template["w"] - 1 or z <= 0 or z >= template["d"] - 1)
        if any(p["group"] == "doors" and on_edge(p, baseline) for p in baseline["points"]) \
                and not any(p["group"] == "doors" and on_edge(p, t) for p in t["points"]):
            report.error("entrance", name, None, "the entrance left the footprint edge")


def baseline_unreachable(t, contexts, facts, nodes, report):
    for context in contexts:
        reach = getattr(context, "reach", None)
        if reach is None:
            continue
        for point in t["points"]:
            if point["group"] in STANDING_GROUPS and \
                    (point["x"], point["y"], point["z"]) not in reach:
                report.warn("unreachable", t["name"], (point["x"], point["y"], point["z"]),
                            "the %s point %s cannot be reached from an entrance inside the "
                            "template (%s)" % (point["group"],
                                               dict(point["attrs"]).get("id", ""),
                                               context.label))


# --------------------------------------------------------------------------
# the run
# --------------------------------------------------------------------------

def git(root, *args):
    return subprocess.run(["git", *args], cwd=root, capture_output=True)


def baseline_reader(root, mode):
    """A function relative path -> baseline text or None, and a description."""
    if mode == "self":
        return None, "the files themselves (--baseline=self)"
    path = root / BASE / "BASELINE"
    if not path.is_file():
        raise SystemExit("check: %s is missing; only --baseline=self runs without it" %
                         (BASE + "/BASELINE"))
    ref = path.read_text().strip()
    if git(root, "rev-parse", "--git-dir").returncode != 0:
        raise SystemExit("check: the baseline needs the repository's history (git)")
    if git(root, "rev-parse", "--verify", "--quiet", ref + "^{commit}").returncode != 0:
        raise SystemExit("check: BASELINE names %s, which this checkout does not have" % ref)
    if git(root, "merge-base", "--is-ancestor", ref, "HEAD").returncode != 0:
        raise SystemExit("check: BASELINE names %s, which is not in HEAD's history" % ref)

    def read(relative):
        shown = git(root, "show", "%s:%s" % (ref, relative))
        return shown.stdout.decode() if shown.returncode == 0 else None
    return read, "BASELINE %s" % ref


def validate(root=ROOT, baseline="file", replaced=None):
    """Run every rule. `replaced` maps a relative path to the text the editor
    is about to save. Returns the Report."""
    root = Path(root)
    replaced = replaced or {}
    report = Report()

    def read(relative):
        if relative in replaced:
            return replaced[relative]
        return (root / relative).read_text()

    template_dir, layout_dir = root / BASE / "templates", root / BASE / "layouts"
    names = sorted({p.stem for p in template_dir.glob("*.tpl")} |
                   {Path(r).stem for r in replaced if r.endswith(".tpl")})
    templates = {}
    for template_name in names:
        relative = "%s/templates/%s.tpl" % (BASE, template_name)
        try:
            templates[template_name] = parse_template(read(relative), relative, template_name)
        except FormatError as error:
            report.error("format", template_name, None, str(error))
    layouts = []
    for path in sorted(layout_dir.glob("*.layout")):
        relative = "%s/layouts/%s" % (BASE, path.name)
        try:
            layouts.append(parse_layout(read(relative), relative))
        except FormatError as error:
            report.error("format", path.stem, None, str(error))
    nodes = registry(root)
    wanted = set(nodes)
    for t in templates.values():
        for entry in t["legend"].values():
            if entry["kind"] == "node":
                wanted.add(entry["name"])
    facts = lua_facts(root, wanted)
    # layouts and the contexts they place each template in
    contexts = {name: [] for name in templates}
    for layout in layouts:
        town = layout["town"]
        ids = set()
        palettes = {name: palette_of(facts, spec["race"], spec["overrides"])
                    for name, spec in layout["palettes"].items()}
        races_of = {name: spec["race"] for name, spec in layout["palettes"].items()}
        for place in layout["places"]:
            where = "%s:%s" % (town, place["id"])
            if place["id"] in ids:
                report.error("layout", town, None, "placement %s given twice" % place["id"])
            ids.add(place["id"])
            if place["template"] not in templates:
                report.error("layout", town, None, "%s places the unknown template %s" %
                             (where, place["template"]))
                continue
            bad = [n for n in [place["main"], *place["channels"].values()]
                   if n is not None and n not in palettes]
            if bad:
                report.error("layout", town, None, "%s names the undefined palette %s" %
                             (where, ", ".join(bad)))
                continue
            race = races_of[place["main"]] if place["main"] else layout["race"]
            main = palettes[place["main"]] if place["main"] else \
                palette_of(facts, layout["race"], None)
            channels = {c: palettes[n] for c, n in place["channels"].items()}
            contexts[place["template"]].append(Context(where, race, main, channels))
            if race not in templates[place["template"]]["races"]:
                report.error("layout", place["template"], None, "the races header does not "
                             "cover %s (%s)" % (race, where))
    reader, described = baseline_reader(root, baseline)
    palette_roles, palette_nodes = editor_palette(root)
    for name, t in templates.items():
        if reader is None:
            base = t
        else:
            text = reader("%s/templates/%s.tpl" % (BASE, name))
            try:
                base = parse_template(text, "BASELINE:" + name, name) if text else None
            except FormatError:
                base = None
        check_template(t, contexts[name], facts, nodes, report, base, palette_roles,
                       palette_nodes)
        baseline_unreachable(t, contexts[name], facts, nodes, report)
    report.baseline = described
    report.counts = (len(templates), len(layouts))
    return report


def known_defects(root):
    path = root / BASE / "known_defects.txt"
    entries = []
    if not path.is_file():
        return entries
    for number, line in enumerate(path.read_text().splitlines(), start=1):
        if comment_or_blank(line):
            continue
        words = line.split(None, 5)
        if len(words) < 5 or not all(INTEGER.match(w) for w in words[2:5]):
            raise SystemExit("check: %s:%d: an entry is '<template> <rule> <x> <y> <z> "
                             "<note>'" % (path, number))
        entries.append((words[0], words[1], (int(words[2]), int(words[3]), int(words[4])),
                        words[5] if len(words) > 5 else ""))
    return entries


def describe(finding):
    rule, where, position, message = finding
    at = " at %d %d %d" % position if position and position[0] != "point" else ""
    return "%s [%s]%s: %s" % (where, rule, at, message)


def main(argv):
    if argv == ["--self-test"]:
        return self_test()
    baseline = "file"
    write_defects = False
    for arg in argv:
        if arg == "--baseline=self":
            baseline = "self"
        elif arg == "--write-known-defects":
            write_defects = True
        else:
            raise SystemExit(__doc__)
    report = validate(ROOT, baseline)
    if write_defects:
        if baseline != "self":
            raise SystemExit("check: --write-known-defects runs with --baseline=self")
        lines = ["# The frozen state's known defects (format doc §6.3): a hard finding",
                 "# listed here is reported as a warning until it is fixed.",
                 "# <template> <rule> <x> <y> <z> <note>"]
        seen = set()
        for rule, where, position, message in report.errors:
            if not position or position[0] == "point":
                raise SystemExit("check: a finding without a cell cannot be a known "
                                 "defect: " + describe((rule, where, position, message)))
            key = (where, rule, position)
            if key not in seen:
                seen.add(key)
                lines.append("%s %s %d %d %d %s" % (where, rule, *position, message))
        (ROOT / BASE / "known_defects.txt").write_text("\n".join(lines) + "\n")
        print("known_defects.txt: %d entries" % (len(lines) - 3))
        report = validate(ROOT, baseline)
    defects = known_defects(ROOT)
    errors, warnings = [], list(report.warnings)
    matched = set()
    for finding in report.errors:
        rule, where, position, _ = finding
        hit = [d for d in defects if d[0] == where and d[1] == rule and d[2] == position]
        if hit:
            matched.add(hit[0][:3])
            warnings.append(("known_defect", where, position, "known defect: " +
                             describe(finding)))
        else:
            errors.append(finding)
    for defect in defects:
        if defect[:3] not in matched:
            warnings.append(("defect_gone", defect[0], defect[2], "the known defect %s no "
                             "longer holds; remove it from known_defects.txt" % defect[1]))
    for finding in warnings:
        print("warning: " + describe(finding))
    for finding in errors:
        print("ERROR: " + describe(finding))
    templates, layouts = report.counts
    status = "FAIL" if errors else "PASS"
    print("building templates: %s (%d templates, %d layouts, %d errors, %d warnings; "
          "baseline: %s)" % (status, templates, layouts, len(errors), len(warnings),
                             report.baseline))
    return 1 if errors else 0


def self_test():
    """The parser and the rules on small made-up templates."""
    failures = []

    def expect(ok, label):
        if not ok:
            failures.append(label)

    good = "\n".join([TEMPLATE_MAGIC, "name t", "pivot 1 1", "origin 0 0 0", "size 1 3 1",
                      "cell 1", "races dwarf", "legend", "F role floor", "end",
                      "layer 0", "|F|", "layer 1", "|.|", "layer 2", "|.|", "points",
                      'inside 0 1 0 id={id} note="a b" tags=[door,work]', "end", ""])
    t = parse_template(good, "t.tpl", "t")
    expect(t["grid"][(0, 0, 0)] == "F" and t["grid"][(0, 1, 0)] == ".", "the grid parses")
    expect(t["points"][0]["attrs"] == [("id", "{id}"), ("note", "a b"),
                                       ("tags", ["door", "work"])], "point attributes parse")
    for bad, label in [(good.replace("|F|", "|F |"), "a row too wide"),
                       (good.replace("|F|", "|X|"), "an undefined key"),
                       (good.replace("layer 2", "layer 3"), "a layer out of order"),
                       (good.replace("inside 0 1 0", "inside 0 5 0"), "a point outside the box"),
                       (good.replace(TEMPLATE_MAGIC, "grudgelands-building-template 2"),
                        "another version"),
                       (good.replace("F role floor", "F role floor else=air"), None)]:
        try:
            parse_template(bad, "t.tpl", "t")
            expect(label is None, "refused: " + str(label))
        except FormatError:
            expect(label is not None, "accepted: else= parses (checked later)")
    expect(entry_text({"legend": {"A": {"kind": "node", "name": "a:b", "o": None}}}, "A") ==
           entry_text({"legend": {"B": {"kind": "node", "name": "a:b", "o": None}}}, "B"),
           "a renamed key is no edit")
    layout = parse_layout("\n".join([LAYOUT_MAGIC, "town x", "race dwarf",
                                     "palette slate race=dwarf roof_slab=stairs:slab_stone",
                                     "place a template=t x=1 y=0 z=-2 turns=3 roof=slate lift=2",
                                     ""]), "x.layout")
    expect(layout["places"][0]["channels"] == {"roof": "slate"} and
           layout["places"][0]["lift"] == 2, "a layout parses")
    try:
        parse_layout(LAYOUT_MAGIC + "\nplace a template=t x=1\n", "x.layout")
        failures.append("an incomplete placement is refused")
    except FormatError:
        pass
    if failures:
        print("check.py self-test: FAIL\n" + "\n".join(failures))
        return 1
    print("check.py self-test: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

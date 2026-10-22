#!/usr/bin/env python3
"""Read building templates, town layouts and rosters, and resolve a template
for a palette, as docs/technical/building-template-format.md describes.

The gallery's reader (build_gallery.py); the shared validator is
tools/building_templates/check.py. Everything here is plain data in, plain
data out, so the gallery and its test use the same code:

- ``parse_template(path)`` -> ``Template`` (header, legend, cells, points);
- ``parse_layout(path)`` -> ``Layout`` (a ``.layout`` or a ``.roster``);
- ``Palettes(data)``: the game's palettes (``palettes.lua palettes``);
- ``resolve(template, palettes, binding)`` -> per legend key the node and
  param2 the stamp writes for that palette binding (format doc §3.2);
- ``resolve_panes(cells, predicates)``: the port of ``parts.resolve_panes``.

Errors raise ``FormatError`` with the file, the line and the reason.
"""

import os
import re

TEMPLATE_MAGIC = "grudgelands-building-template 1"
LAYOUT_MAGIC = "grudgelands-town-layout 1"
# The format doc gives rosters "the same palette lines as a layout" but no
# magic line of their own; a roster may start with either line (or neither).
ROSTER_MAGICS = (LAYOUT_MAGIC, "grudgelands-town-roster 1")

FORCE_AIR = "air"        # '.': the part writes air
UNCHANGED = "unchanged"  # ' ': the part writes nothing


class FormatError(Exception):
    def __init__(self, path, line, reason):
        Exception.__init__(self, "%s:%s: %s" % (path, line, reason))
        self.path, self.line, self.reason = path, line, reason


# ------------------------------------------------------------- values ---

_TOKEN = re.compile(r'\s*(?:([A-Za-z0-9_*:.{}\-]+)=)?("[^"\n]*"|\[[^\]]*\]|[^\s]+)')
_BARE = re.compile(r"^[A-Za-z0-9_:.{}\-]+$")


def parse_value(text):
    """A point or meta attribute value (format doc §3.4)."""
    if text.startswith('"') and text.endswith('"') and len(text) >= 2:
        return text[1:-1]
    if text.startswith("[") and text.endswith("]"):
        inner = text[1:-1].strip()
        return [parse_value(v.strip()) for v in inner.split(",")] if inner else []
    if text in ("true", "false"):
        return text == "true"
    if re.match(r"^-?\d+$", text):
        return int(text)
    if _BARE.match(text):
        return text
    raise ValueError("not a value: %s" % text)


def split_attrs(text):
    """``k=v`` tokens and bare tokens of a line, quoted strings kept whole."""
    out, pos = [], 0
    text = text.rstrip()
    while pos < len(text):
        m = _TOKEN.match(text, pos)
        if not m or m.end() == pos:
            raise ValueError("cannot read: %s" % text[pos:])
        out.append((m.group(1), m.group(2)))
        pos = m.end()
    return out


# ---------------------------------------------------------- templates ---

class Template(object):
    def __init__(self, path):
        self.path = path
        self.name = None
        self.pivot = None
        self.origin = None
        self.size = None
        self.cell = 1
        self.meta = {}
        self.races = []
        self.legend = {}        # key -> entry dict
        self.legend_order = []  # keys in file order
        self.cells = {}         # (x, y, z) -> key, FORCE_AIR or UNCHANGED
        self.points = []        # dicts: group, x, y, z, face, attrs (ordered)


def _content_lines(path):
    with open(path, "r", encoding="utf-8") as fh:
        for number, raw in enumerate(fh, 1):
            yield number, raw.rstrip("\n")


def _is_skip(line):
    stripped = line.strip()
    return stripped == "" or stripped.startswith("#")


def parse_template(path):
    t = Template(path)
    lines = list(_content_lines(path))
    i = 0

    def fail(number, reason):
        raise FormatError(path, number, reason)

    # magic
    while i < len(lines) and _is_skip(lines[i][1]):
        i += 1
    if i >= len(lines) or lines[i][1].strip() != TEMPLATE_MAGIC:
        fail(lines[i][0] if i < len(lines) else 1, "expected '%s'" % TEMPLATE_MAGIC)
    i += 1
    layers_seen = set()
    while i < len(lines):
        number, line = lines[i]
        i += 1
        if _is_skip(line):
            continue
        word, _, rest = line.strip().partition(" ")
        rest = rest.strip()
        try:
            if word == "name":
                t.name = rest
            elif word == "pivot":
                t.pivot = tuple(int(v) for v in rest.split())
                if len(t.pivot) != 2:
                    raise ValueError("pivot takes w d")
            elif word == "origin":
                t.origin = tuple(int(v) for v in rest.split())
                if len(t.origin) != 3:
                    raise ValueError("origin takes x0 y0 z0")
            elif word == "size":
                t.size = tuple(int(v) for v in rest.split())
                if len(t.size) != 3 or min(t.size) < 1:
                    raise ValueError("size takes three counts >= 1")
            elif word == "cell":
                t.cell = int(rest)
                if t.cell not in (1, 2):
                    raise ValueError("cell is 1 or 2")
            elif word == "meta":
                for key, value in split_attrs(rest):
                    if key is None:
                        raise ValueError("meta takes key=value")
                    t.meta[key] = parse_value(value)
            elif word == "races":
                t.races = rest.split()
            elif word == "legend":
                i = _parse_legend(t, lines, i, fail)
            elif word == "layer":
                if t.size is None or t.origin is None:
                    fail(number, "layer before origin and size")
                y = int(rest)
                if y in layers_seen:
                    fail(number, "layer %d twice" % y)
                layers_seen.add(y)
                i = _parse_layer(t, y, lines, i, fail)
            elif word == "points":
                i = _parse_points(t, lines, i, fail)
            else:
                fail(number, "unknown line '%s'" % word)
        except ValueError as e:
            fail(number, str(e))
    for field in ("name", "pivot", "origin", "size"):
        if getattr(t, field) is None:
            fail(len(lines), "missing '%s'" % field)
    if t.name != os.path.basename(path)[:-4]:
        fail(1, "name %s does not match the file name" % t.name)
    x0, y0, z0 = t.origin
    want = set(range(y0, y0 + t.size[1]))
    if layers_seen != want:
        fail(len(lines), "layers %s missing" % sorted(want - layers_seen))
    for key in t.legend_order:
        entry = t.legend[key]
        refs = []
        if entry["kind"] == "race":
            refs = list(entry["choices"].values())
        elif entry.get("else") not in (None, FORCE_AIR, UNCHANGED):
            refs = [entry["else"]]
        for ref in refs:
            if ref not in t.legend:
                fail(entry["line"], "key '%s' names an undefined key '%s'" % (key, ref))
            if entry["kind"] == "race" and t.legend[ref]["kind"] == "race":
                fail(entry["line"], "race switch '%s' names another switch" % key)
    for pos, key in t.cells.items():
        if key not in (FORCE_AIR, UNCHANGED) and key not in t.legend:
            fail(len(lines), "cell %s uses an undefined key '%s'" % (pos, key))
    return t


def _parse_legend(t, lines, i, fail):
    while i < len(lines):
        number, line = lines[i]
        i += 1
        if _is_skip(line):
            continue
        stripped = line.strip()
        if stripped == "end":
            return i
        key, _, rest = stripped.partition(" ")
        if len(key) != t.cell:
            fail(number, "legend key '%s' is not %d character(s)" % (key, t.cell))
        if key in (".", "..") or any(c in key for c in " .|#"):
            fail(number, "legend key '%s' is reserved" % key)
        if key in t.legend:
            fail(number, "legend key '%s' twice" % key)
        words = rest.split()
        if not words:
            fail(number, "empty legend entry")
        kind = words[0]
        entry = {"kind": kind, "line": number, "text": rest.strip()}
        try:
            attrs = split_attrs(" ".join(words[1:]))
        except ValueError as e:
            fail(number, str(e))
        if kind in ("role", "node"):
            if not attrs or attrs[0][0] is not None:
                fail(number, "%s takes a name first" % kind)
            entry["name"] = attrs[0][1]
            allowed = ("variant", "channel", "o", "else") if kind == "role" else ("o",)
            for k, v in attrs[1:]:
                if k not in allowed:
                    fail(number, "unknown attribute '%s' on a %s" % (k, kind))
                entry[k] = v
            if "o" in entry:
                m = re.match(r"^(facedir|wallmounted):(\d+)$", entry["o"])
                if not m:
                    fail(number, "orientation '%s' is not facedir:<n> or wallmounted:<n>" % entry["o"])
                entry["o"] = (m.group(1), int(m.group(2)))
                if (m.group(1) == "facedir" and entry["o"][1] > 23) or \
                        (m.group(1) == "wallmounted" and entry["o"][1] > 5):
                    fail(number, "orientation '%s' is out of range" % rest)
        elif kind == "race":
            choices = {}
            for k, v in attrs:
                if k is None:
                    fail(number, "race switch takes <race>=<key>")
                choices[k] = v
            entry["choices"] = choices
        else:
            fail(number, "legend entry is not role, node or race")
        t.legend[key] = entry
        t.legend_order.append(key)
    fail(len(lines), "legend without end")


def _parse_layer(t, y, lines, i, fail):
    x0, _, z0 = t.origin
    sx, _, sz = t.size
    width = sx * t.cell
    for row in range(sz):
        if i >= len(lines):
            fail(len(lines), "layer %d has %d of %d rows" % (y, row, sz))
        number, line = lines[i]
        i += 1
        if len(line) != width + 2 or line[0] != "|" or line[-1] != "|":
            fail(number, "row is not |<%d cells>|" % sx)
        body = line[1:-1]
        for col in range(sx):
            key = body[col * t.cell:(col + 1) * t.cell]
            if key == "." * t.cell:
                value = FORCE_AIR
            elif key == " " * t.cell:
                value = UNCHANGED
            else:
                value = key
            t.cells[(x0 + col, y, z0 + row)] = value
    return i


def _parse_points(t, lines, i, fail):
    x0, y0, z0 = t.origin
    sx, sy, sz = t.size
    while i < len(lines):
        number, line = lines[i]
        i += 1
        if _is_skip(line):
            continue
        stripped = line.strip()
        if stripped == "end":
            return i
        try:
            words = stripped.split(None, 4)
            if len(words) < 4:
                raise ValueError("a point is <group> <x> <y> <z> [attributes]")
            x, y, z = int(words[1]), int(words[2]), int(words[3])
            attrs = []
            face = None
            for k, v in split_attrs(words[4] if len(words) > 4 else ""):
                if k is None:
                    raise ValueError("point attribute without a key: %s" % v)
                value = parse_value(v)
                if k == "face":
                    if value not in (0, 1, 2, 3):
                        raise ValueError("face is 0-3")
                    face = value
                else:
                    attrs.append((k, value))
        except ValueError as e:
            fail(number, str(e))
        if not (x0 <= x < x0 + sx and y0 <= y < y0 + sy and z0 <= z < z0 + sz):
            fail(number, "point outside the box")
        t.points.append({"group": words[0], "x": x, "y": y, "z": z,
                         "face": face, "attrs": attrs, "line": number,
                         "text": words[4] if len(words) > 4 else ""})
    fail(len(lines), "points without end")


# ------------------------------------------------------------ layouts ---

class Layout(object):
    def __init__(self, path):
        self.path = path
        self.kind = "roster" if path.endswith(".roster") else "layout"
        self.town = os.path.basename(path).rsplit(".", 1)[0]
        self.race = None
        self.palettes = {}   # name -> (race, {role: node})
        self.places = []     # dicts: id, template, x, y, z, turns, main, channels, lift
        self.uses = []       # dicts: template, count, main, channels (rosters)


def parse_layout(path):
    lay = Layout(path)
    lines = list(_content_lines(path))
    i = 0
    while i < len(lines) and _is_skip(lines[i][1]):
        i += 1
    if lay.kind == "layout":
        if i >= len(lines) or lines[i][1].strip() != LAYOUT_MAGIC:
            raise FormatError(path, lines[i][0] if i < len(lines) else 1,
                              "expected '%s'" % LAYOUT_MAGIC)
        i += 1
    elif i < len(lines) and lines[i][1].strip() in ROSTER_MAGICS:
        i += 1
    for number, line in lines[i:]:
        if _is_skip(line):
            continue
        word, _, rest = line.strip().partition(" ")
        try:
            attrs = split_attrs(rest)
            if word == "town":
                lay.town = rest.strip()
            elif word == "race":
                lay.race = rest.strip()
            elif word == "palette":
                name = attrs[0][1]
                fields = dict((k, v) for k, v in attrs[1:])
                if "race" not in fields:
                    raise ValueError("palette takes race=")
                race = fields.pop("race")
                lay.palettes[name] = (race, fields)
            elif word in ("place", "use"):
                rec = {"line": number, "channels": {}, "main": None}
                rest_attrs = attrs
                if word == "place":
                    if attrs[0][0] is not None:
                        raise ValueError("place takes an id first")
                    rec["id"] = attrs[0][1]
                    rest_attrs = attrs[1:]
                else:
                    if attrs[0][0] is not None:
                        raise ValueError("use takes a template first")
                    rec["template"] = attrs[0][1]
                    rest_attrs = attrs[1:]
                for k, v in rest_attrs:
                    if k is None:
                        raise ValueError("unexpected '%s'" % v)
                    if k in ("x", "y", "z", "turns", "lift", "count"):
                        rec[k] = int(v)
                    elif k == "template":
                        rec["template"] = v
                    elif k == "main":
                        rec["main"] = v
                    else:
                        rec["channels"][k] = v
                if "template" not in rec:
                    raise ValueError("%s without template" % word)
                (lay.places if word == "place" else lay.uses).append(rec)
            else:
                raise ValueError("unknown line '%s'" % word)
        except (ValueError, IndexError) as e:
            raise FormatError(path, number, str(e) or "malformed line")
    if lay.race is None and lay.kind == "layout":
        raise FormatError(path, len(lines), "layout without race")
    return lay


# ----------------------------------------------------------- palettes ---

class Palettes(object):
    """The game's palettes and node predicates (``palettes.lua palettes``)."""

    def __init__(self, data):
        self.required = set(data["required"])
        self.optional = set(data["optional"])
        self.families = data["families"]
        self.races = data["races"]
        self.extra = data.get("troll_overrides", {})
        self.nodes = data["nodes"]

    def bind(self, race, overrides=None):
        """A race palette with overrides, as palette.new builds it."""
        if race not in self.races:
            raise ValueError("unknown race %s" % race)
        out = dict(self.races[race])
        for role, name in (overrides or {}).items():
            if role not in self.required and role not in self.optional:
                raise ValueError("override role %s is not declared" % role)
            out[role] = name
        return {"race": race, "roles": out}

    def kind(self, name):
        return self.nodes.get(name, {}).get("kind", "none")

    def place_param2(self, name):
        return self.nodes.get(name, {}).get("place", 0)

    def is_pane(self, name):
        return bool(self.nodes.get(name, {}).get("pane"))

    def connects(self, name):
        return bool(self.nodes.get(name, {}).get("connects"))

    def canonical_param2(self, name, param2):
        """parts.canonical_param2."""
        if self.is_pane(name) and name.endswith("_flat"):
            if param2 == 1:
                return 3
            if param2 == 2:
                return 0
        return param2


def entry_node(entry, binding, palettes):
    """The node a role or node entry names under a binding, or None when an
    optional role is unbound. Raises ValueError for an unbound required
    role or a bad variant."""
    if entry["kind"] == "node":
        return entry["name"]
    role = entry["name"]
    channel = entry.get("channel")
    pal = binding.get(channel) or binding["main"]
    roles = pal["roles"]
    if role in palettes.families:
        suffix = entry.get("variant")
        if suffix not in palettes.families[role]:
            raise ValueError("%s has no variant %s" % (role, suffix))
        base = roles.get(role)
        return base + suffix if base else None
    if role not in palettes.required and role not in palettes.optional:
        raise ValueError("role %s is not declared" % role)
    name = roles.get(role)
    if name is None and role in palettes.required:
        raise ValueError("required role %s is unbound" % role)
    return name


def resolve(template, palettes, binding):
    """Per legend key: (node, param2), ``FORCE_AIR``, ``UNCHANGED`` or an
    error string, for a binding {"main": palette, <channel>: palette}.

    The stamp's rules (format doc §3.2) at turns = 0: the node first, then
    its param2 from the node's kind.
    """
    race = binding["main"]["race"]
    out = {}

    def one(key, depth):
        entry = template.legend[key]
        if entry["kind"] == "race":
            choice = entry["choices"].get(race, entry["choices"].get("*"))
            if choice is None:
                return "race switch '%s' covers no %s" % (key, race)
            return one(choice, depth + 1)
        try:
            name = entry_node(entry, binding, palettes)
        except ValueError as e:
            return str(e)
        if name is None:
            fallback = entry.get("else", UNCHANGED)
            if fallback in (FORCE_AIR, UNCHANGED):
                return fallback
            if depth > 2:
                return "else= chain too long at '%s'" % key
            return one(fallback, depth + 1)
        kind = palettes.kind(name)
        if kind == "none":
            return (name, 0)
        if kind == "meshoptions":
            return (name, palettes.place_param2(name))
        o = entry.get("o")
        if o is None:
            return (name, palettes.canonical_param2(name, palettes.place_param2(name)))
        if o[0] != kind:
            return "%s is %s, the legend stores %s" % (name, kind, o[0])
        return (name, palettes.canonical_param2(name, o[1]))

    for key in template.legend_order:
        out[key] = one(key, 0)
    return out


# -------------------------------------------------------------- panes ---

FACEDIR_STEP = {0: (0, 1), 1: (1, 0), 2: (0, -1), 3: (-1, 0)}


def resolve_panes(cells, palettes):
    """parts.resolve_panes over {(x, y, z): (name, param2)}, in place.

    A pane's shape follows its four horizontal neighbours (``update_pane``):
    no connection keeps the flat pane and its param2; one, or two opposite,
    give the flat pane at (last connecting direction + 1) % 4; two adjacent,
    three or four give the connected pane at 0. Rewriting a pane never
    changes whether it connects, so one pass in any order is exact.
    Returns the number of panes.
    """
    panes = []
    for pos, (name, param2) in cells.items():
        if palettes.is_pane(name):
            base = name[:-5] if name.endswith("_flat") else name
            panes.append((pos, base, param2))
    for (x, y, z), base, param2 in panes:
        any_dir, total, connected = param2, 0, {}
        for d in range(4):
            dx, dz = FACEDIR_STEP[d]
            neighbour = cells.get((x + dx, y, z + dz))
            hit = neighbour is not None and palettes.connects(neighbour[0])
            connected[d] = hit
            if hit:
                any_dir = d
                total += 1
        if total == 0:
            cells[(x, y, z)] = (base + "_flat", param2)
        elif total == 1 or (total == 2 and ((connected[0] and connected[2]) or
                                            (connected[1] and connected[3]))):
            cells[(x, y, z)] = (base + "_flat", (any_dir + 1) % 4)
        else:
            cells[(x, y, z)] = (base, 0)
    return len(panes)


def resolved_cells(template, resolution, palettes):
    """The cells a resolution writes, {(x, y, z): (name, param2)}, panes
    settled; force-air cells as ("air", 0); leave-unchanged cells absent.
    Second value: the cells whose key did not resolve, {(x, y, z): reason}."""
    cells, bad = {}, {}
    for pos, key in template.cells.items():
        if key == UNCHANGED:
            continue
        if key == FORCE_AIR:
            cells[pos] = ("air", 0)
            continue
        r = resolution[key]
        if r == UNCHANGED:
            continue
        if r == FORCE_AIR:
            cells[pos] = ("air", 0)
        elif isinstance(r, tuple):
            cells[pos] = r
        else:
            bad[pos] = r
    resolve_panes(cells, palettes)
    return cells, bad

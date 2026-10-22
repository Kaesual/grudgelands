"""The template editor's model of one building template file and its writer
(docs/technical/building-template-format.md §3).

The editor changes cells, legend entries and point positions; everything
else of a file stays as it was. ``load(text, path)`` reads a file into a
``Model`` through the viewer's reader (``viewer/templates.py``), keeping the
header lines (comments, name, pivot, origin, size, cell, meta, races) as they
are written; ``dump(model)`` writes the file in the canonical layout the
freeze exporter writes:

    grudgelands-building-template 1
    <the header lines, unchanged>
    <blank>
    legend
    <key> <entry>            one per legend entry, in legend order
    end
    <blank>
    layer <y>                every layer from y0 up, each with sz rows
    |<cells>|
    <blank>
    points
    <group> <x> <y> <z>[ <attributes, unchanged>]
    end

A file is *canonical* when ``dump(load(text)) == text``; then loading and
saving it unedited writes identical bytes. A file that is not canonical (a
comment inside the legend, extra blank lines, two spaces after a key) is
reported by the editor, never rewritten on load.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "viewer"))

import templates as T  # noqa: E402

MAGIC = T.TEMPLATE_MAGIC
# Legend keys, in the order the exporter hands them out (export.lua).
ALPHABET = ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            "!$%&'()*+,-/:;<=>?@[\\]^_`{}~\"")


class Model(object):
    """head: header lines; cell: 1 or 2; legend: [[key, entry text]];
    layers: one list of row strings (without the frame) per y from y0;
    points: [[group, x, y, z, rest]] with rest the attribute text."""

    def __init__(self):
        self.name = None
        self.head = []
        self.cell = 1
        self.origin = self.size = self.pivot = None
        self.races = []
        self.legend = []
        self.layers = []
        self.points = []


def load(text, path):
    """Read a template. Raises templates.FormatError."""
    t = T.parse_template(path, text=text)
    m = Model()
    m.name, m.cell, m.origin, m.size, m.pivot = t.name, t.cell, t.origin, t.size, t.pivot
    m.races = list(t.races)
    lines = text.split("\n")
    start = next(i for i, line in enumerate(lines) if line.strip() == MAGIC) + 1
    end = next(i for i, line in enumerate(lines) if line.strip() == "legend")
    head = lines[start:end]
    while head and head[-1].strip() == "":
        head.pop()
    m.head = head
    m.legend = [[key, t.legend[key]["text"]] for key in t.legend_order]
    x0, y0, z0 = t.origin
    sx, sy, sz = t.size
    for y in range(y0, y0 + sy):
        rows = []
        for z in range(z0, z0 + sz):
            row = []
            for x in range(x0, x0 + sx):
                value = t.cells[(x, y, z)]
                row.append("." * t.cell if value == T.FORCE_AIR else
                           " " * t.cell if value == T.UNCHANGED else value)
            rows.append("".join(row))
        m.layers.append(rows)
    m.points = [[p["group"], p["x"], p["y"], p["z"], p["text"]] for p in t.points]
    return m


def dump(m):
    """The file text of a model, canonical layout."""
    out = [MAGIC]
    for line in m.head:
        word = line.strip().split(" ", 1)[0]
        out.append("cell %d" % m.cell if word == "cell" else line)
    out += ["", "legend"]
    out += ["%s %s" % (key, text) for key, text in m.legend]
    out += ["end", ""]
    y0 = m.origin[1]
    for index, rows in enumerate(m.layers):
        out.append("layer %d" % (y0 + index))
        out += ["|%s|" % row for row in rows]
    out += ["", "points"]
    for group, x, y, z, rest in m.points:
        out.append("%s %d %d %d%s" % (group, x, y, z, " " + rest if rest else ""))
    out.append("end")
    return "\n".join(out) + "\n"


def canonical(text, path):
    """(True, None) when the file is canonical, else (False, the first line
    that differs, 1-based, with what the writer would put there)."""
    written = dump(load(text, path))
    if written == text:
        return True, None
    a, b = text.split("\n"), written.split("\n")
    for number, (old, new) in enumerate(zip(a, b), 1):
        if old != new:
            return False, "line %d: %r would be written as %r" % (number, old, new)
    return False, "the file has %d lines, the writer writes %d" % (len(a), len(b))


def used_keys(m):
    """Legend keys the grid uses, and those a used entry names (race switch
    targets and else= fallbacks), transitively."""
    keys = set()
    width = m.cell
    for rows in m.layers:
        for row in rows:
            for i in range(0, len(row), width):
                keys.add(row[i:i + width])
    keys.discard("." * width)
    keys.discard(" " * width)
    texts = dict((key, text) for key, text in m.legend)
    todo = [k for k in keys if k in texts]
    while todo:
        key = todo.pop()
        for word in texts[key].split()[1:]:
            name, _, value = word.partition("=")
            if not value:
                continue
            if name == "else" or texts[key].startswith("race "):
                if value in texts and value not in keys:
                    keys.add(value)
                    todo.append(value)
    return keys


def prune_legend(m):
    """Drop legend entries nothing uses (an editor-added entry whose cells
    were all painted over, an entry the edit emptied). Keys stay as they are,
    so no grid row changes."""
    keep = used_keys(m)
    m.legend = [[key, text] for key, text in m.legend if key in keep]

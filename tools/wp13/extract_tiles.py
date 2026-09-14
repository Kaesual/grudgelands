#!/usr/bin/env python3
"""Scan Lua mod sources for node registrations and emit tools/wp13/node_tiles.json.

This is a *pragmatic* static scanner, not a Lua interpreter. It tokenises Lua
well enough to find balanced call arguments and table literals, then pulls the
fields a renderer cares about (tiles, drawtype, paramtype2, use_texture_alpha).
Anything it cannot work out is simply absent from the JSON; render_blueprint.py
falls back to a flat colour and reports the name on stderr.

Handled registration forms
--------------------------
  core/minetest.register_node("name", {...})        also with a local table var
  *register_stair_and_slab(sub, base, groups, imgs, ...)   (also the _inner /
  *register_stair / *register_slab / *register_stair_outer  variants)
  default.register_fence / register_fence_rail(name, {texture = ...})
  doors.register(name, {tiles = ...})   -> name_a .. name_d
  doors.register_trapdoor(name, {tile_front, tile_side})
  doors.register_fencegate(name, {texture = ...})
  beds.register_bed(name, {tiles = {bottom = {...}, top = {...}}})
  xpanes.register_pane(name, {textures = {face, _, edge}})
  walls.register(name, desc, {textures}, ...)

Usage
-----
    python3 tools/wp13/extract_tiles.py                  # default roots
    python3 tools/wp13/extract_tiles.py --root mods \
        --root ../minetest_game/mods --out tools/wp13/node_tiles.json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))

# ---------------------------------------------------------------------------
# Lua-ish tokenisation helpers
# ---------------------------------------------------------------------------

_LONG_OPEN = re.compile(r"\[(=*)\[")


def _skip_string(src: str, i: int) -> int:
    """i points at a quote; return index just past the closing quote."""
    quote = src[i]
    i += 1
    n = len(src)
    while i < n:
        c = src[i]
        if c == "\\":
            i += 2
            continue
        if c == quote:
            return i + 1
        if c == "\n":  # unterminated short string
            return i
        i += 1
    return n


def _skip_long_bracket(src: str, i: int):
    """If src[i:] opens a long bracket, return index past its close, else None."""
    m = _LONG_OPEN.match(src, i)
    if not m:
        return None
    close = "]" + m.group(1) + "]"
    end = src.find(close, m.end())
    return len(src) if end < 0 else end + len(close)


def _skip_comment(src: str, i: int):
    """If a comment starts at i, return index past it, else None."""
    if not src.startswith("--", i):
        return None
    j = _skip_long_bracket(src, i + 2)
    if j is not None:
        return j
    j = src.find("\n", i)
    return len(src) if j < 0 else j


def find_balanced(src: str, start: int, open_ch: str, close_ch: str):
    """src[start] must be open_ch. Return index just past the matching close."""
    depth = 0
    i = start
    n = len(src)
    while i < n:
        c = src[i]
        if c in "\"'":
            i = _skip_string(src, i)
            continue
        j = _skip_comment(src, i)
        if j is not None:
            i = j
            continue
        if c == "[":
            j = _skip_long_bracket(src, i)
            if j is not None:
                i = j
                continue
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return -1


def split_args(body: str):
    """Split the inside of a call's parentheses on top-level commas."""
    out, depth, cur, i, n = [], 0, [], 0, len(body)
    while i < n:
        c = body[i]
        if c in "\"'":
            j = _skip_string(body, i)
            cur.append(body[i:j])
            i = j
            continue
        k = _skip_comment(body, i)
        if k is not None:
            i = k
            continue
        if c == "[":
            k = _skip_long_bracket(body, i)
            if k is not None:
                cur.append(body[i:k])
                i = k
                continue
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        if c == "," and depth == 0:
            out.append("".join(cur).strip())
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    tail = "".join(cur).strip()
    if tail:
        out.append(tail)
    return out


_STR_RE = re.compile(r"""^\s*(["'])(.*)\1\s*$""", re.S)


def as_string(arg: str):
    """Return the Lua string literal's value, or None. Simple concatenation of
    literals is joined; anything with a variable in it yields None."""
    arg = arg.strip()
    if arg[:1] in ('"', "'"):
        end = _skip_string(arg, 0)
        if end == len(arg):  # a single literal, not a concatenation
            return arg[1:end - 1].replace('\\"', '"').replace("\\'", "'")
    if ".." in arg:
        parts = split_concat(arg)
        # A `..` that sits inside brackets (e.g. a `{a .. b, c}` table literal)
        # leaves the whole argument as the single part, and recursing on it
        # would never terminate -- that is not a concatenation we can read.
        if len(parts) > 1:
            vals = [as_string(p) for p in parts]
            if all(v is not None for v in vals):
                return "".join(vals)
    return None


def split_concat(arg: str):
    out, depth, cur, i, n = [], 0, [], 0, len(arg)
    while i < n:
        c = arg[i]
        if c in "\"'":
            j = _skip_string(arg, i)
            cur.append(arg[i:j])
            i = j
            continue
        if c in "({[":
            depth += 1
        elif c in ")}]":
            depth -= 1
        if depth == 0 and arg.startswith("..", i):
            out.append("".join(cur))
            cur = []
            i += 2
            continue
        cur.append(c)
        i += 1
    out.append("".join(cur))
    return [p.strip() for p in out]


def table_fields(tbl: str):
    """Parse a `{...}` literal into (dict_of_named_fields, list_of_positional).

    Values are returned as raw source snippets.
    """
    tbl = tbl.strip()
    if not tbl.startswith("{"):
        return {}, []
    inner = tbl[1:-1] if tbl.endswith("}") else tbl[1:]
    named, positional = {}, []
    for item in split_args(inner):
        if not item:
            continue
        key, value = _split_field(item)
        if key is None:
            positional.append(value)
        else:
            named[key] = value
    return named, positional


_KEY_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=(?!=)")
_BRACKET_KEY_RE = re.compile(r"""^\s*\[\s*(["'])(.*?)\1\s*\]\s*=(?!=)""", re.S)


def _split_field(item: str):
    m = _KEY_RE.match(item)
    if m:
        return m.group(1), item[m.end():].strip()
    m = _BRACKET_KEY_RE.match(item)
    if m:
        return m.group(2), item[m.end():].strip()
    return None, item.strip()


def texture_list(value: str):
    """Turn a `tiles`-shaped value into a list of texture strings (or None)."""
    value = value.strip()
    s = as_string(value)
    if s is not None:
        return [s]
    if not value.startswith("{"):
        return None
    named, positional = table_fields(value)
    if not positional and "name" in named:
        # single {name = "...", animation = ...} table
        s = as_string(named["name"])
        return [s] if s else None
    out = []
    for item in positional:
        s = as_string(item)
        if s is None and item.strip().startswith("{"):
            sub, _ = table_fields(item)
            if "name" in sub:
                s = as_string(sub["name"])
        out.append(s)
    if not out:
        return None
    return out


# ---------------------------------------------------------------------------
# Scanning
# ---------------------------------------------------------------------------

CALL_RE = re.compile(
    # allow a dotted/colon receiver (`default.register_fence`) *and* a local
    # wrapper whose name merely ends in the API name (`my_register_stair...`).
    r"(?<![\w.])(?:[A-Za-z_][\w.]*[.:_])?"
    r"(register_node|register_stair_and_slab|register_stair_inner|"
    r"register_stair_outer|register_stair|register_slab|register_fence_rail|"
    r"register_fence|register_trapdoor|register_fencegate|register_bed|"
    r"register_pane|register)\s*\("
)

LOCAL_TABLE_RE = re.compile(r"(?:^|\n)\s*local\s+([A-Za-z_][\w]*)\s*=\s*\{")


class Scanner:
    def __init__(self):
        self.nodes = {}
        self.notes = []

    # -- low level ------------------------------------------------------
    def put(self, name, tiles, drawtype=None, paramtype2=None, alpha=None,
            shape=None, source=None):
        if not name:
            return
        name = name.strip()
        if name.startswith(":"):
            name = name[1:]
        if not name or ":" not in name:
            return
        if any(ch in name for ch in "\"' \t") or ".." in name:
            # a name the scanner could only half-resolve (built from a loop
            # variable inside an API function); not a real node.
            return
        tiles = [t for t in (tiles or []) if t]
        entry = {}
        if tiles:
            entry["tiles"] = tiles
        if drawtype:
            entry["drawtype"] = drawtype
        if paramtype2:
            entry["paramtype2"] = paramtype2
        if alpha:
            entry["alpha"] = alpha
        if shape:
            entry["shape"] = shape
        if source:
            entry["source"] = source
        old = self.nodes.get(name)
        if old and old.get("tiles"):
            # first definition wins: roots are scanned in priority order, so a
            # node the game itself ships shadows the reference-project copy.
            return
        self.nodes[name] = entry

    # -- file scan ------------------------------------------------------
    def scan_file(self, path, relpath):
        try:
            src = open(path, "r", encoding="utf-8", errors="replace").read()
        except OSError:
            return
        locals_ = self._local_tables(src)
        for m in CALL_RE.finditer(src):
            kind = m.group(1)
            open_paren = m.end() - 1
            end = find_balanced(src, open_paren, "(", ")")
            if end < 0:
                continue
            args = split_args(src[open_paren + 1:end - 1])
            if kind == "register":
                # only doors.register(name, def) is interesting
                if ".register" not in src[m.start():m.end()]:
                    continue
                if "doors" not in src[m.start():m.end()] and \
                        "walls" not in src[m.start():m.end()]:
                    continue
            try:
                self._dispatch(kind, src[m.start():m.end()], args, locals_,
                               relpath)
            except Exception as exc:  # pragma: no cover - defensive
                self.notes.append("%s: %s in %s" % (kind, exc, relpath))

    def _local_tables(self, src):
        out = {}
        for m in LOCAL_TABLE_RE.finditer(src):
            brace = src.index("{", m.start(1) + len(m.group(1)))
            end = find_balanced(src, brace, "{", "}")
            if end > 0:
                out[m.group(1)] = src[brace:end]
        return out

    def _resolve_table(self, arg, locals_):
        arg = arg.strip()
        if arg.startswith("{"):
            return arg
        if arg.startswith("table.copy("):
            inner = arg[len("table.copy("):]
            return self._resolve_table(inner.rstrip(")"), locals_)
        return locals_.get(arg)

    def _dispatch(self, kind, callsrc, args, locals_, relpath):
        if kind == "register_node":
            self._node(args, locals_, relpath)
        elif kind in ("register_stair_and_slab", "register_stair",
                      "register_slab", "register_stair_inner",
                      "register_stair_outer"):
            self._stairs(kind, args, relpath)
        elif kind in ("register_fence", "register_fence_rail"):
            self._fence(kind, args, locals_, relpath)
        elif kind == "register_trapdoor":
            self._trapdoor(args, locals_, relpath)
        elif kind == "register_fencegate":
            self._fencegate(args, locals_, relpath)
        elif kind == "register_bed":
            self._bed(args, locals_, relpath)
        elif kind == "register_pane":
            self._pane(args, locals_, relpath)
        elif kind == "register":
            if "doors" in callsrc:
                self._door(args, locals_, relpath)
            elif "walls" in callsrc:
                self._wall(args, relpath)

    # -- individual registration forms ----------------------------------
    def _node(self, args, locals_, relpath):
        if len(args) < 2:
            return
        name = as_string(args[0])
        if not name:
            return
        tbl = self._resolve_table(args[1], locals_)
        if tbl is None:
            self.put(name, None, source=relpath)
            return
        named, _ = table_fields(tbl)
        tiles = None
        for key in ("tiles", "tile_images"):
            if key in named:
                tiles = texture_list(named[key])
                if tiles:
                    break
        if not tiles and "inventory_image" in named:
            tiles = texture_list(named["inventory_image"])
        self.put(name, tiles,
                 drawtype=as_string(named.get("drawtype", "")) or None,
                 paramtype2=as_string(named.get("paramtype2", "")) or None,
                 alpha=as_string(named.get("use_texture_alpha", "")) or None,
                 source=relpath)

    def _stairs(self, kind, args, relpath):
        if len(args) < 2:
            return
        sub = as_string(args[0])
        base = as_string(args[1])
        if not sub:
            return
        images = texture_list(args[3]) if len(args) > 3 else None
        record = {"base": base, "images": images, "source": relpath}
        targets = []
        if kind in ("register_stair", "register_stair_and_slab"):
            targets.append("stairs:stair_" + sub)
        if kind in ("register_slab", "register_stair_and_slab"):
            targets.append("stairs:slab_" + sub)
        if kind in ("register_stair_inner", "register_stair_and_slab"):
            targets.append("stairs:stair_inner_" + sub)
        if kind in ("register_stair_outer", "register_stair_and_slab"):
            targets.append("stairs:stair_outer_" + sub)
        for t in targets:
            shape = "slab" if "slab_" in t else "stair"
            entry = {"shape": shape, "paramtype2": "facedir",
                     "source": relpath}
            if images:
                entry["tiles"] = images
            elif base:
                entry["inherit"] = base
            self.nodes.setdefault(t, entry)
            if images:
                self.nodes[t].setdefault("tiles", images)
            elif base:
                self.nodes[t].setdefault("inherit", base)
        _ = record

    def _fence(self, kind, args, locals_, relpath):
        if len(args) < 2:
            return
        name = as_string(args[0])
        tbl = self._resolve_table(args[1], locals_)
        if not name or tbl is None:
            return
        named, _ = table_fields(tbl)
        tex = as_string(named.get("texture", "")) or None
        shape = "fence" if kind == "register_fence" else "fence_rail"
        self.put(name, [tex] if tex else None, drawtype="fencelike",
                 shape=shape, source=relpath)

    def _trapdoor(self, args, locals_, relpath):
        if len(args) < 2:
            return
        name = as_string(args[0])
        tbl = self._resolve_table(args[1], locals_)
        if not name or tbl is None:
            return
        if ":" not in name:
            name = "doors:" + name
        named, _ = table_fields(tbl)
        front = as_string(named.get("tile_front", "")) or None
        side = as_string(named.get("tile_side", "")) or None
        tiles = [t for t in (side, side, side, side, front, front) if t]
        self.put(name, tiles, drawtype="nodebox", paramtype2="facedir",
                 shape="trapdoor", source=relpath)
        self.put(name + "_open", tiles, drawtype="nodebox",
                 paramtype2="facedir", shape="trapdoor_open", source=relpath)

    def _fencegate(self, args, locals_, relpath):
        if len(args) < 2:
            return
        name = as_string(args[0])
        tbl = self._resolve_table(args[1], locals_)
        if not name or tbl is None:
            return
        named, _ = table_fields(tbl)
        tex = as_string(named.get("texture", "")) or None
        for suffix in ("_closed", "_open"):
            self.put(name + suffix, [tex] if tex else None,
                     drawtype="nodebox", paramtype2="facedir", shape="fence",
                     source=relpath)

    def _door(self, args, locals_, relpath):
        if len(args) < 2:
            return
        name = as_string(args[0])
        tbl = self._resolve_table(args[1], locals_)
        if not name or tbl is None:
            return
        if ":" not in name:
            name = "doors:" + name
        named, _ = table_fields(tbl)
        tiles = texture_list(named["tiles"]) if "tiles" in named else None
        alpha = as_string(named.get("use_texture_alpha", "")) or None
        for suffix in ("_a", "_b", "_c", "_d"):
            self.put(name + suffix, tiles, drawtype="mesh",
                     paramtype2="facedir", alpha=alpha, shape="door",
                     source=relpath)

    def _bed(self, args, locals_, relpath):
        if len(args) < 2:
            return
        name = as_string(args[0])
        tbl = self._resolve_table(args[1], locals_)
        if not name or tbl is None:
            return
        named, _ = table_fields(tbl)
        tiles_tbl = named.get("tiles")
        bottom = top = None
        if tiles_tbl:
            sub, _pos = table_fields(tiles_tbl)
            if "bottom" in sub:
                bottom = texture_list(sub["bottom"])
            if "top" in sub:
                top = texture_list(sub["top"])
        self.put(name + "_bottom", bottom, drawtype="nodebox",
                 paramtype2="facedir", shape="bed", source=relpath)
        self.put(name + "_top", top, drawtype="nodebox",
                 paramtype2="facedir", shape="bed", source=relpath)

    def _pane(self, args, locals_, relpath):
        if len(args) < 2:
            return
        name = as_string(args[0])
        tbl = self._resolve_table(args[1], locals_)
        if not name or tbl is None:
            return
        named, _ = table_fields(tbl)
        textures = texture_list(named["textures"]) if "textures" in named \
            else None
        face = edge = None
        if textures:
            face = textures[0] if len(textures) > 0 else None
            edge = textures[2] if len(textures) > 2 else None
        tiles = [t for t in (edge, edge, edge, edge, face, face) if t]
        alpha = "blend" if "use_texture_alpha" in named else "clip"
        for target in ("xpanes:%s_flat" % name, "xpanes:%s" % name):
            self.put(target, tiles, drawtype="nodebox", paramtype2="facedir",
                     alpha=alpha, shape="pane", source=relpath)

    def _wall(self, args, relpath):
        if len(args) < 3:
            return
        name = as_string(args[0])
        tiles = texture_list(args[2])
        self.put(name, tiles, drawtype="nodebox", shape="wall",
                 source=relpath)

    # -- post processing ------------------------------------------------
    def resolve_inheritance(self):
        for name, entry in self.nodes.items():
            base = entry.pop("inherit", None)
            if not entry.get("tiles") and base:
                basedef = self.nodes.get(base)
                if basedef and basedef.get("tiles"):
                    entry["tiles"] = list(basedef["tiles"])
                    entry["inherited_from"] = base
            _ = name


# ---------------------------------------------------------------------------
# Manual overrides / shape hints
# ---------------------------------------------------------------------------

SHAPE_RULES = [
    # (match kind, pattern, shape)
    ("prefix", "stairs:stair_inner_", "stair"),
    ("prefix", "stairs:stair_outer_", "stair"),
    ("prefix", "stairs:stair_", "stair"),
    ("prefix", "stairs:slab_", "slab"),
    ("prefix", "xpanes:", "pane"),
    ("prefix", "walls:", "wall"),
    ("prefix", "doors:door_", "door"),
    ("contains", "fence_rail", "fence"),
    ("contains", "fence", "fence"),
    ("suffix", "_bottom", None),
]

# Names whose static definition the scanner cannot reach, or where the
# scanned answer is not what a reviewer wants to see. Keep this short.
MANUAL_OVERRIDES = {
    # torches are meshes; give the renderer the flat sprite plus a shape hint
    "default:torch": {"tiles": ["default_torch_on_floor.png"],
                      "shape": "torch", "paramtype2": "wallmounted",
                      "alpha": "clip"},
    "default:torch_wall": {"tiles": ["default_torch_on_floor.png"],
                           "shape": "torch_wall", "paramtype2": "wallmounted",
                           "alpha": "clip"},
    "default:torch_ceiling": {"tiles": ["default_torch_on_floor.png"],
                              "shape": "torch_ceiling",
                              "paramtype2": "wallmounted", "alpha": "clip"},
    # animated tile name -> the static art file actually on disk
    "default:furnace_active": {"tiles": ["default_furnace_front_active.png",
                                         "default_furnace_top.png"]},
    # registered through wrappers the scanner cannot follow
    "default:chest": {"tiles": ["default_chest_top.png",
                                "default_chest_top.png",
                                "default_chest_side.png",
                                "default_chest_side.png",
                                "default_chest_side.png",
                                "default_chest_front.png"],
                      "drawtype": "normal", "paramtype2": "facedir"},
    "default:chest_locked": {"tiles": ["default_chest_top.png",
                                       "default_chest_top.png",
                                       "default_chest_side.png",
                                       "default_chest_side.png",
                                       "default_chest_side.png",
                                       "default_chest_lock.png"],
                             "drawtype": "normal", "paramtype2": "facedir"},
    "grug_materials:iron_block": {"tiles": ["default_steel_block.png"],
                                  "drawtype": "normal"},
    "default:furnace": {"tiles": ["default_furnace_top.png",
                                  "default_furnace_bottom.png",
                                  "default_furnace_side.png",
                                  "default_furnace_side.png",
                                  "default_furnace_side.png",
                                  "default_furnace_front.png"],
                        "drawtype": "normal", "paramtype2": "facedir"},
    # grug_decor builds its tile names through a local `tex()` helper, which
    # the scanner cannot follow; these are the four static furnishing nodes a
    # WP13 palette binds.
    "grug_decor:xdecor_barrel": {
        "tiles": ["grug_decor_xdecor_xdecor_barrel_top.png",
                  "grug_decor_xdecor_xdecor_barrel_top.png",
                  "grug_decor_xdecor_xdecor_barrel_sides.png"],
        "drawtype": "normal", "paramtype2": "facedir"},
    "grug_decor:xdecor_cauldron": {
        "tiles": ["grug_decor_xdecor_xdecor_cauldron_top_empty.png",
                  "grug_decor_xdecor_xdecor_cauldron_bottom.png",
                  "grug_decor_xdecor_xdecor_cauldron_sides.png"],
        "drawtype": "normal", "paramtype2": "facedir"},
    "grug_decor:xdecor_empty_shelf": {
        "tiles": ["default_wood.png", "default_wood.png", "default_wood.png",
                  "default_wood.png",
                  "default_wood.png^grug_decor_xdecor_xdecor_empty_shelf.png",
                  "default_wood.png^grug_decor_xdecor_xdecor_empty_shelf.png"],
        "drawtype": "normal", "paramtype2": "facedir"},
    "grug_decor:cottages_shelf": {
        "tiles": ["default_wood.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    # ... and the farm vocabulary the human palette adds.
    "grug_decor:cottages_loam": {
        "tiles": ["grug_decor_cottages_cottages_loam.png"],
        "drawtype": "normal"},
    "grug_decor:cottages_straw": {
        "tiles": ["grug_decor_cottages_cottages_darkage_straw.png"],
        "drawtype": "normal"},
    "grug_decor:cottages_straw_bale": {
        "tiles": ["grug_decor_cottages_cottages_darkage_straw_bale.png"],
        "drawtype": "nodebox"},
    "grug_decor:cottages_straw_ground": {
        "tiles": ["grug_decor_cottages_cottages_darkage_straw.png",
                  "grug_decor_cottages_cottages_loam.png",
                  "grug_decor_cottages_cottages_loam.png"],
        "drawtype": "normal"},
    "grug_decor:cottages_straw_mat": {
        "tiles": ["grug_decor_cottages_cottages_darkage_straw.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:cottages_bench": {
        "tiles": ["grug_decor_cottages_cottages_minimal_wood.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:cottages_table": {
        "tiles": ["grug_decor_cottages_cottages_minimal_wood.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:cottages_anvil": {
        "tiles": ["grug_decor_cottages_cottages_stone.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:cottages_window_shutter_closed": {
        "tiles": ["grug_decor_cottages_cottages_minimal_wood.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:cottages_window_shutter_open": {
        "tiles": ["grug_decor_cottages_cottages_minimal_wood.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    # ... and the undead vocabulary the Stillgrave palette adds. The castle
    # pillars come out of a `register_pillar(material)` loop and the xdecor
    # pieces out of the same `tex()` helper as the four above, so neither is
    # reachable by static scanning.
    "grug_decor:castle_pillar_obsidianbrick_bottom": {
        "tiles": ["default_obsidian_brick.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:castle_pillar_obsidianbrick_middle": {
        "tiles": ["default_obsidian_brick.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:castle_pillar_obsidianbrick_top": {
        "tiles": ["default_obsidian_brick.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:darkage_iron_bars": {
        "tiles": ["grug_decor_darkage_darkage_iron_bars.png"],
        "drawtype": "glasslike", "alpha": "clip"},
    "grug_decor:xdecor_candle": {
        "tiles": ["grug_decor_xdecor_xdecor_candle_floor.png"],
        "drawtype": "torchlike", "paramtype2": "wallmounted",
        "alpha": "clip"},
    "grug_decor:xdecor_cobweb": {
        "tiles": ["grug_decor_xdecor_xdecor_cobweb.png"],
        "drawtype": "plantlike", "alpha": "clip"},
    "grug_decor:xdecor_ivy": {
        "tiles": ["grug_decor_xdecor_xdecor_ivy.png"],
        "drawtype": "signlike", "paramtype2": "wallmounted",
        "alpha": "clip"},
    "grug_decor:xdecor_table": {
        "tiles": ["grug_decor_xdecor_xdecor_wood.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:xdecor_workbench": {
        "tiles": ["grug_decor_xdecor_xdecor_workbench_top.png",
                  "grug_decor_xdecor_xdecor_workbench_bottom.png",
                  "grug_decor_xdecor_xdecor_workbench_sides.png",
                  "grug_decor_xdecor_xdecor_workbench_sides.png",
                  "grug_decor_xdecor_xdecor_workbench_sides.png",
                  "grug_decor_xdecor_xdecor_workbench_front.png"],
        "drawtype": "normal", "paramtype2": "facedir"},
    # `grug_nodes` builds its litter tops through a `register_litter()`
    # wrapper, in the same three-tile shape default's own litters use.
    "grug_nodes:dirt_with_bone_litter": {
        "tiles": ["grug_nodes_bone_litter.png", "default_dirt.png",
                  "default_dirt.png^grug_nodes_bone_litter_side.png"],
        "drawtype": "normal"},
    # ... the elf vocabulary the Silverleaf palette adds. `darkage.lua` builds
    # every one of these tile names through its own `tex()` helper, and
    # `shapes.lua` registers the stair and slab family through a loop, so the
    # scanner can follow neither. Each shape carries the tile of the cube it
    # is cut from, which is what `register_stair_and_slab` does.
    "grug_decor:darkage_marble": {
        "tiles": ["grug_decor_darkage_darkage_marble.png"],
        "drawtype": "normal"},
    "grug_decor:darkage_marble_tile": {
        "tiles": ["grug_decor_darkage_darkage_marble_tile.png"],
        "drawtype": "normal"},
    "grug_decor:darkage_slate_brick": {
        "tiles": ["grug_decor_darkage_darkage_slate_brick.png"],
        "drawtype": "normal"},
    "grug_decor:darkage_slate_tile": {
        "tiles": ["grug_decor_darkage_darkage_slate_tile.png"],
        "drawtype": "normal"},
    "grug_decor:darkage_slate_tile_stair": {
        "tiles": ["grug_decor_darkage_darkage_slate_tile.png"],
        "drawtype": "nodebox", "paramtype2": "facedir", "shape": "stair"},
    "grug_decor:darkage_slate_tile_stair_inner": {
        "tiles": ["grug_decor_darkage_darkage_slate_tile.png"],
        "drawtype": "nodebox", "paramtype2": "facedir",
        "shape": "stair_inner"},
    "grug_decor:darkage_slate_tile_stair_outer": {
        "tiles": ["grug_decor_darkage_darkage_slate_tile.png"],
        "drawtype": "nodebox", "paramtype2": "facedir",
        "shape": "stair_outer"},
    "grug_decor:darkage_slate_tile_slab": {
        "tiles": ["grug_decor_darkage_darkage_slate_tile.png"],
        "drawtype": "nodebox", "paramtype2": "facedir", "shape": "slab"},
    "grug_decor:darkage_slate_brick_slab": {
        "tiles": ["grug_decor_darkage_darkage_slate_brick.png"],
        "drawtype": "nodebox", "paramtype2": "facedir", "shape": "slab"},
    "grug_decor:darkage_serpentine_slab": {
        "tiles": ["grug_decor_darkage_darkage_serpentine.png"],
        "drawtype": "nodebox", "paramtype2": "facedir", "shape": "slab"},
    "grug_decor:xdecor_potted_viola": {
        "tiles": ["grug_decor_xdecor_xdecor_viola_pot.png"],
        "drawtype": "plantlike", "alpha": "clip"},
    "grug_decor:xdecor_potted_dandelion_white": {
        "tiles": ["grug_decor_xdecor_xdecor_dandelion_white_pot.png"],
        "drawtype": "plantlike", "alpha": "clip"},
    # The hanging lantern's tile is the same four-frame strip as the floor
    # lantern's; the renderer draws one frame.
    "grug_decor:xdecor_lantern_hanging": {
        "tiles": ["grug_decor_xdecor_xdecor_lantern.png^[verticalframe:4:0"],
        "drawtype": "plantlike", "alpha": "clip"},
    # `grug_nodes` builds the elf litter top through the same
    # `register_litter()` wrapper as the undead one.
    "grug_nodes:dirt_with_silver_litter": {
        "tiles": ["grug_nodes_silver_litter.png", "default_dirt.png",
                  "default_dirt.png^grug_nodes_silver_litter_side.png"],
        "drawtype": "normal"},
    # ... and the jungle vocabulary the troll palette adds. `darkage.lua`
    # builds its tile names through its own `tex()` helper and composes the
    # reinforced timber as an overlay over `default_wood.png`, neither of
    # which the scanner can follow.
    "grug_decor:darkage_basalt_brick": {
        "tiles": ["grug_decor_darkage_darkage_basalt_brick.png"],
        "drawtype": "normal"},
    "grug_decor:darkage_serpentine": {
        "tiles": ["grug_decor_darkage_darkage_serpentine.png"],
        "drawtype": "normal"},
    "grug_decor:darkage_reinforced_wood": {
        "tiles": ["default_wood.png^grug_decor_darkage_darkage_reinforce.png"],
        "drawtype": "normal"},
    "grug_decor:darkage_wood_bars": {
        "tiles": ["grug_decor_darkage_darkage_wood_bars.png"],
        "drawtype": "glasslike", "alpha": "clip"},
    # The lantern's tile is a four-frame vertical animation strip (16 x 64);
    # the renderer draws one frame.
    "grug_decor:xdecor_lantern": {
        "tiles": ["grug_decor_xdecor_xdecor_lantern.png^[verticalframe:4:0"],
        "drawtype": "plantlike", "alpha": "clip"},
    "grug_decor:xdecor_rope": {
        "tiles": ["grug_decor_xdecor_xdecor_rope.png"],
        "drawtype": "plantlike", "alpha": "clip"},
    "grug_decor:cottages_tub": {
        "tiles": ["grug_decor_cottages_cottages_barrel.png"],
        "drawtype": "nodebox"},
    "grug_decor:cottages_wagon_wheel": {
        "tiles": ["grug_decor_cottages_cottages_wagonwheel.png"],
        "drawtype": "mesh", "paramtype2": "wallmounted", "alpha": "clip"},
    "grug_decor:xdecor_stonepath": {
        "tiles": ["default_stone.png"],
        "drawtype": "nodebox", "paramtype2": "facedir"},
    "grug_decor:xdecor_potted_geranium": {
        "tiles": ["grug_decor_xdecor_xdecor_geranium_pot.png"],
        "drawtype": "plantlike", "alpha": "clip"},
    "grug_decor:xdecor_potted_dandelion_yellow": {
        "tiles": ["grug_decor_xdecor_xdecor_dandelion_yellow_pot.png"],
        "drawtype": "plantlike", "alpha": "clip"},
    # ... and the camp vocabulary the orc palette adds. `darkage.lua` builds
    # its tile names through the same local helper, so the mud brick and the
    # banded course had no texture at all and rendered as flat colour, which
    # is exactly the wall the whole settlement is made of.
    "grug_decor:darkage_adobe": {
        "tiles": ["grug_decor_darkage_darkage_adobe.png"],
        "drawtype": "normal"},
    "grug_decor:darkage_ors_block": {
        "tiles": ["grug_decor_darkage_darkage_ors_block.png"],
        "drawtype": "normal"},
}

# Last-resort flat colours for names that resolve to no texture at all.
FALLBACK_COLORS = {
    "air": None,
    "default:water_source": "#2b5fa8",
    "default:river_water_source": "#2f79b5",
    "default:lava_source": "#d05a17",
}


def classify_shape(name, entry):
    if entry.get("shape"):
        return entry["shape"]
    drawtype = (entry.get("drawtype") or "").lower()
    if drawtype in ("plantlike", "plantlike_rooted", "firelike"):
        return "plant"
    if drawtype == "torchlike":
        return "torch"
    if drawtype == "signlike":
        return "billboard"
    if drawtype == "fencelike":
        return "fence"
    if drawtype in ("liquid", "flowingliquid"):
        return "liquid"
    if drawtype == "airlike":
        return "air"
    if drawtype.startswith("glasslike"):
        return "glass"
    for kind, pat, shape in SHAPE_RULES:
        if shape is None:
            continue
        if kind == "prefix" and name.startswith(pat):
            return shape
        if kind == "contains" and pat in name:
            return shape
        if kind == "suffix" and name.endswith(pat):
            return shape
    if drawtype in ("nodebox", "mesh"):
        return "nodebox"
    return "cube"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", action="append", default=[],
                    help="directory tree to scan for *.lua (repeatable)")
    ap.add_argument("--texture-root", action="append", default=[],
                    help="directory tree to scan for textures (repeatable)")
    ap.add_argument("--out", default=os.path.join(HERE, "node_tiles.json"))
    ap.add_argument("--relative-to", default=REPO,
                    help="store texture/source paths relative to this "
                         "directory (default: the repository root). Point it "
                         "at the main checkout when scanning submodules that "
                         "are not populated in a worktree.")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    base = os.path.abspath(args.relative_to)

    roots = args.root or [os.path.join(REPO, "mods")]
    tex_roots = args.texture_root or roots

    scanner = Scanner()
    files = 0
    for root in roots:
        root = os.path.abspath(root)
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d != ".git"]
            for fn in sorted(filenames):
                if not fn.endswith(".lua"):
                    continue
                full = os.path.join(dirpath, fn)
                scanner.scan_file(full, os.path.relpath(full, base))
                files += 1
    scanner.resolve_inheritance()

    # texture index: basename -> path relative to REPO
    textures = {}
    for root in tex_roots:
        root = os.path.abspath(root)
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d != ".git"]
            if os.path.basename(dirpath) != "textures":
                continue
            for fn in filenames:
                if fn.lower().endswith((".png", ".jpg", ".jpeg", ".tga")):
                    textures.setdefault(fn, os.path.relpath(
                        os.path.join(dirpath, fn), base))

    for name, patch in MANUAL_OVERRIDES.items():
        entry = scanner.nodes.setdefault(name, {})
        entry.update(patch)
        entry["source"] = "MANUAL_OVERRIDES"

    for name, entry in scanner.nodes.items():
        entry["shape"] = classify_shape(name, entry)

    data = {
        "_comment": "generated by tools/wp13/extract_tiles.py -- do not hand edit",
        "roots": [os.path.relpath(os.path.abspath(r), base) for r in roots],
        "nodes": dict(sorted(scanner.nodes.items())),
        "textures": dict(sorted(textures.items())),
        "fallback_colors": FALLBACK_COLORS,
    }
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=1, sort_keys=False)
        fh.write("\n")

    if not args.quiet:
        untextured = [n for n, e in scanner.nodes.items() if not e.get("tiles")]
        sys.stderr.write(
            "scanned %d lua files, %d nodes (%d without tiles), %d textures\n"
            % (files, len(scanner.nodes), len(untextured), len(textures)))
        for note in scanner.notes[:20]:
            sys.stderr.write("  note: %s\n" % note)


if __name__ == "__main__":
    main()

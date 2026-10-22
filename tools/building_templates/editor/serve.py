#!/usr/bin/env python3
"""The building template editor: a small local server and its page.

    python3 tools/building_templates/editor/serve.py [--port N]

then open the address it prints (http://127.0.0.1:8756/ by default). It
serves one editor page and reads and writes the building templates of
mods/MAPGEN/grug_mapgen/building_templates/templates in this working tree
(docs/technical/building-template-format.md, Round 56 rulings 25-31).

- It listens on 127.0.0.1 only and answers only requests addressed to
  127.0.0.1 or localhost (so a web page cannot reach it by a rebound name).
- It writes nothing but existing template files in the templates directory,
  and only through Save: the edit is written canonically (``tplfile.py``),
  checked by the shared validator (``../check.py``, imported, against
  ``BASELINE``), refused on an error of the template, written only after the
  page confirmed the warnings, and replaced atomically (temp file + rename).
  The box, the pivot, the header and every point's group, order, face and
  attributes come from the file on disk; the page sends only cells, legend
  entries and point positions.
- Its one git use is reading a template at HEAD (``git show``, read-only)
  for the page's "changed since commit" highlight.
- Drafts live in the browser's local storage, never in the repository.

``--root DIR`` edits another checkout (the tests use a disposable clone).
Python 3 standard library plus the viewer's helpers (Pillow for textures).
"""

import argparse
import hashlib
import http.server
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile
import threading
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLS = os.path.dirname(HERE)
VIEWER = os.path.join(TOOLS, "viewer")
sys.path.insert(0, HERE)
sys.path.insert(0, VIEWER)
sys.path.insert(0, TOOLS)

import build_gallery  # noqa: E402
import build_viewer  # noqa: E402
import check  # noqa: E402
import templates as T  # noqa: E402
import tplfile  # noqa: E402

BASE = "mods/MAPGEN/grug_mapgen/building_templates"
NAME = re.compile(r"^[a-z0-9_]+$")
DEFAULT_PORT = 8756
MAX_BODY = 16 * 1024 * 1024
STATIC = {
    "/": (os.path.join(HERE, "editor.html"), "text/html; charset=utf-8"),
    "/editor.js": (os.path.join(HERE, "editor.js"), "text/javascript; charset=utf-8"),
    "/model.js": (os.path.join(HERE, "model.js"), "text/javascript; charset=utf-8"),
    "/renderer.js": (os.path.join(VIEWER, "renderer.js"), "text/javascript; charset=utf-8"),
}


class Refused(Exception):
    """A request the editor refuses: an HTTP status and a reason."""

    def __init__(self, status, reason, **extra):
        Exception.__init__(self, reason)
        self.status, self.reason, self.extra = status, reason, extra


def title(town):
    return town.replace("_", " ").title()


def sha(data):
    return hashlib.sha256(data).hexdigest()


# --------------------------------------------------------------- editor ---

class Editor(object):
    """What the server knows: the checkout, its palettes, nodes, layouts."""

    def __init__(self, root):
        self.root = os.path.realpath(root)
        self.template_dir = os.path.join(self.root, BASE, "templates")
        self.layout_dir = os.path.join(self.root, BASE, "layouts")
        if not os.path.isdir(self.template_dir):
            raise SystemExit("editor: no templates in %s" % self.template_dir)
        self.lock = threading.Lock()
        self._assets = None

    # -- the game's facts (once) -----------------------------------------
    def registry(self):
        path = os.path.join(self.root, "tools/building_templates/nodes.json")
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)

    def palettes(self):
        """palettes.lua over every registry name (the viewer's helper)."""
        if getattr(self, "_palettes", None) is None:
            reg = self.registry()
            names = set(reg["nodes"]) | set(reg.get("aliases", {}))
            with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as fh:
                fh.write("\n".join(sorted(names)) + "\n")
                listing = fh.name
            try:
                run = subprocess.run([build_viewer.find_lua(), os.path.join(VIEWER, "palettes.lua"),
                                      "palettes", listing], cwd=self.root,
                                     capture_output=True, text=True)
            finally:
                os.unlink(listing)
            if run.returncode != 0:
                raise SystemExit("editor: palettes.lua failed: " + run.stderr)
            self._palettes = json.loads(run.stdout)
        return self._palettes

    def editor_palette(self):
        """[[group, [[kind, name], ...]], ...] in file order, duplicates once."""
        groups, seen = [], set()
        path = os.path.join(self.root, "tools/building_templates/editor_palette.txt")
        with open(path, "r", encoding="utf-8") as fh:
            for line in fh:
                words = line.split()
                if not words or words[0].startswith("#"):
                    continue
                if words[0].startswith("["):
                    groups.append([line.strip()[1:-1], []])
                elif len(words) == 2 and words[0] in ("role", "node") and groups:
                    if (words[0], words[1]) not in seen:
                        seen.add((words[0], words[1]))
                        groups[-1][1].append([words[0], words[1]])
        return groups

    def assets(self):
        """Everything the page draws with: node types, textures, meshes, the
        palettes and node predicates, the editor palette."""
        if self._assets is None:
            reg = self.registry()
            names = sorted(reg["nodes"])
            textures, meshes = build_viewer.Textures(), {}
            types, _ = build_viewer.build_types(names, reg["nodes"], reg.get("aliases", {}),
                                                textures, meshes)
            data = self.palettes()
            self._assets = json.dumps({
                "types": types,
                "textures": textures.images,
                "meshes": {k: v for k, v in meshes.items() if v is not None},
                "palettes": data,
                "editor_palette": self.editor_palette(),
                "aliases": reg.get("aliases", {}),
                "overhang": overhanging(reg["nodes"]),
                "descriptions": {n: (d.get("description") or "").split("\n")[0]
                                 for n, d in reg["nodes"].items()},
            }, separators=(",", ":")).encode("utf-8")
        return self._assets

    # -- templates and their uses ----------------------------------------
    def layouts(self):
        out = []
        if os.path.isdir(self.layout_dir):
            files = sorted(os.listdir(self.layout_dir))
            for ext in (".layout", ".roster"):
                for name in files:
                    if name.endswith(ext):
                        out.append(T.parse_layout(os.path.join(self.layout_dir, name)))
        return out

    def names(self):
        return sorted(n[:-4] for n in os.listdir(self.template_dir)
                      if n.endswith(".tpl") and NAME.match(n[:-4]))

    def uses(self):
        """template -> [(layout, record, count)] in file order."""
        out = {}
        for lay in self.layouts():
            for rec in (lay.places if lay.kind == "layout" else lay.uses):
                out.setdefault(rec["template"], []).append((lay, rec, rec.get("count", 1)))
        return out

    @staticmethod
    def used_text(uses):
        if not uses:
            return "not used by any layout or roster"
        towns = {}
        for lay, _, n in uses:
            towns[lay.town] = towns.get(lay.town, 0) + n
        total = sum(towns.values())
        return "used %d× in %s" % (total, ", ".join(
            "%s (%d)" % (title(t), n) if n > 1 else title(t) for t, n in towns.items()))

    def listing(self):
        uses = self.uses()
        out = []
        for name in self.names():
            u = uses.get(name, [])
            out.append({"name": name, "town": u[0][0].town if u else None,
                        "used": sum(n for _, _, n in u), "used_text": self.used_text(u)})
        towns = []
        for lay in self.layouts():
            if lay.town not in [t[0] for t in towns]:
                towns.append([lay.town, title(lay.town), lay.race])
        return {"templates": out, "towns": towns}

    def path_of(self, name):
        """The template file of a name: inside the templates directory, an
        existing regular file, never a link. Anything else is refused."""
        if not isinstance(name, str) or not NAME.match(name):
            raise Refused(400, "not a template name: %r" % (name,))
        path = os.path.join(self.template_dir, name + ".tpl")
        real = os.path.realpath(path)
        if os.path.dirname(real) != os.path.realpath(self.template_dir):
            raise Refused(403, "outside the templates directory: %s" % name)
        if os.path.islink(path) or not os.path.isfile(real):
            raise Refused(404, "no template %s" % name)
        return real

    def relative(self, name):
        return "%s/templates/%s.tpl" % (BASE, name)

    def at_head(self, name):
        """The template's text at HEAD (git show, read-only), or None."""
        run = subprocess.run(["git", "show", "HEAD:./" + self.relative(name)], cwd=self.root,
                             capture_output=True)
        return run.stdout.decode("utf-8") if run.returncode == 0 else None

    def template(self, name):
        path = self.path_of(name)
        with open(path, "rb") as fh:
            data = fh.read()
        text = data.decode("utf-8")
        try:
            m = tplfile.load(text, path)
            is_canonical, why = tplfile.canonical(text, path)
        except T.FormatError as e:
            raise Refused(422, "the file does not parse: %s" % e)
        head = None
        head_text = self.at_head(name)
        if head_text is not None:
            try:
                hm = tplfile.load(head_text, path)
                head = {"cell": hm.cell, "legend": hm.legend, "layers": hm.layers,
                        "size": list(hm.size), "origin": list(hm.origin)}
            except T.FormatError:
                head = None
        uses = self.uses().get(name, [])
        pal = T.Palettes(self.palettes())
        bindings = []
        for lay, rec, n in uses:
            try:
                b = build_gallery.placement_binding(pal, lay, rec)
            except T.FormatError:
                continue
            label = title(lay.town) + (" " + rec["id"].replace("_", " ") if rec.get("id")
                                       else " (%d×)" % n)
            bindings.append({"key": "placed:%s:%s" % (lay.town, rec.get("id", rec["line"])),
                             "label": "As placed: " + label, "binding": b})
        return {
            "name": name, "path": self.relative(name), "hash": sha(data),
            "canonical": is_canonical, "canonical_note": why,
            "head": head, "head_lines": m.head, "cell": m.cell,
            "pivot": list(m.pivot), "origin": list(m.origin), "size": list(m.size),
            "races": m.races, "legend": m.legend, "layers": m.layers,
            "points": [[g, x, y, z, rest] for g, x, y, z, rest in m.points],
            "used_text": self.used_text(uses), "used": sum(n for _, _, n in uses),
            "bindings": bindings,
        }

    # -- an edit: the page's cells, legend and point positions ----------
    def edited_text(self, body):
        """The file text of the page's edit on top of the file on disk."""
        name = body.get("name")
        path = self.path_of(name)
        with open(path, "rb") as fh:
            data = fh.read()
        disk = tplfile.load(data.decode("utf-8"), path)
        m = tplfile.load(data.decode("utf-8"), path)
        cell = body.get("cell")
        if cell not in (1, 2):
            raise Refused(400, "cell is 1 or 2")
        legend, keys = [], set()
        for item in body.get("legend") or []:
            if not (isinstance(item, list) and len(item) == 2 and all(isinstance(v, str) for v in item)):
                raise Refused(400, "a legend entry is [key, text]")
            key, text = item
            if len(key) != cell or any(c in " .|#" or not ("!" <= c <= "~") for c in key):
                raise Refused(400, "legend key %r is not allowed" % key)
            if key in keys:
                raise Refused(400, "legend key %r twice" % key)
            if not text.strip() or any(c in text for c in "\n\r|") or text != text.strip():
                raise Refused(400, "legend entry %r is not one plain line" % text)
            keys.add(key)
            legend.append([key, text])
        sx, sy, sz = disk.size
        layers = body.get("layers")
        if not (isinstance(layers, list) and len(layers) == sy):
            raise Refused(400, "the edit has %s layers, the box %d" % (
                len(layers) if isinstance(layers, list) else "no", sy))
        for rows in layers:
            if not (isinstance(rows, list) and len(rows) == sz):
                raise Refused(400, "a layer of the edit is not %d rows" % sz)
            for row in rows:
                if not (isinstance(row, str) and len(row) == sx * cell and
                        all(" " <= c <= "~" and c != "|" for c in row)):
                    raise Refused(400, "a row of the edit is not %d cells" % sx)
        points = body.get("points")
        if not (isinstance(points, list) and len(points) == len(disk.points)):
            raise Refused(400, "points can only be moved: the edit has %s points, the file %d"
                          % (len(points) if isinstance(points, list) else "no", len(disk.points)))
        moved = []
        for old, new in zip(disk.points, points):
            if not (isinstance(new, list) and len(new) == 3 and
                    all(isinstance(v, int) and not isinstance(v, bool) for v in new)):
                raise Refused(400, "a point position is [x, y, z]")
            moved.append([old[0], new[0], new[1], new[2], old[4]])
        m.cell, m.legend, m.layers, m.points = cell, legend, layers, moved
        tplfile.prune_legend(m)
        text = tplfile.dump(m)
        try:
            tplfile.load(text, path)
        except T.FormatError as e:
            raise Refused(422, "the edit does not make a valid file: %s" % e.reason)
        return name, path, data, text

    def check(self, name, text):
        """The shared validator on the edited file: (blocking errors of this
        template, its warnings, errors elsewhere), as dicts."""
        try:
            report = check.validate(self.root, "file", {self.relative(name): text})
        except SystemExit as e:
            raise Refused(500, "the validator stopped: %s" % e)
        defects = check.known_defects(pathlib.Path(self.root))
        errors, warnings, elsewhere = [], [], []
        for finding in report.errors:
            rule, where, position, _ = finding
            known = any(d[0] == where and d[1] == rule and d[2] == position for d in defects)
            if known:
                if where == name:
                    warnings.append(as_dict(finding, "known defect"))
            elif where == name:
                errors.append(as_dict(finding))
            else:
                elsewhere.append(as_dict(finding))
        for finding in report.warnings:
            if finding[1] == name:
                warnings.append(as_dict(finding))
        return errors, warnings, elsewhere

    def review(self, body):
        name, _, data, text = self.edited_text(body)
        errors, warnings, elsewhere = self.check(name, text)
        return {"errors": errors, "warnings": warnings, "elsewhere": elsewhere,
                "unchanged": text.encode("utf-8") == data,
                "stale": sha(data) != body.get("hash")}

    def save(self, body):
        with self.lock:
            name, path, data, text = self.edited_text(body)
            if sha(data) != body.get("hash"):
                raise Refused(409, "the file changed on disk since the page loaded it; "
                              "reload it (your edit stays in the draft)", stale=True)
            errors, warnings, elsewhere = self.check(name, text)
            result = {"errors": errors, "warnings": warnings, "elsewhere": elsewhere}
            if errors:
                raise Refused(409, "the validator found %d error(s); nothing was written" %
                              len(errors), **result)
            if warnings and body.get("confirm") is not True:
                raise Refused(409, "confirm the %d warning(s) to save" % len(warnings),
                              need_confirm=True, **result)
            new = text.encode("utf-8")
            if new != data:
                write_atomic(path, new)
            result.update({"saved": True, "hash": sha(new), "unchanged": new == data})
            return result


def as_dict(finding, note=None):
    rule, where, position, message = finding
    pos = list(position) if position and position[0] != "point" else None
    return {"rule": rule, "where": where, "pos": pos,
            "message": ("%s: " % note if note else "") + message}


def write_atomic(path, data):
    """Write a temp file next to `path`, flush it to disk, rename it over."""
    directory = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(prefix="." + os.path.basename(path) + ".", suffix=".tmp",
                               dir=directory)
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp, os.stat(path).st_mode & 0o777)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def overhanging(nodes):
    """Nodes whose node box, collision box or selection box reaches into a
    neighbouring cell: {name: [axes]} (format doc §5 lists the multi-cell
    objects; these are reported to the coordinator)."""
    out = {}
    for name, d in sorted(nodes.items()):
        axes = set()
        for field in ("node_box", "collision_box", "selection_box"):
            box = d.get(field) or {}
            for key, value in box.items():
                if key == "type" or not isinstance(value, list) or not value:
                    continue
                for b in ([value] if isinstance(value[0], (int, float)) else value):
                    if isinstance(b, list) and len(b) == 6:
                        for axis in range(3):
                            if b[axis] < -0.5 - 1e-6 or b[axis + 3] > 0.5 + 1e-6:
                                axes.add("xyz"[axis])
        if axes:
            out[name] = sorted(axes)
    return out


# ---------------------------------------------------------------- HTTP ---

class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "GrudgeTemplateEditor/1"
    editor = None  # set by make_server

    def log_message(self, fmt, *args):
        if self.server.verbose:
            http.server.BaseHTTPRequestHandler.log_message(self, fmt, *args)

    def local(self):
        """Only requests addressed to this server by a loopback name."""
        host = (self.headers.get("Host") or "").lower()
        port = self.server.server_address[1]
        if host not in ("127.0.0.1:%d" % port, "localhost:%d" % port):
            raise Refused(403, "this editor answers only http://127.0.0.1:%d/" % port)
        origin = self.headers.get("Origin")
        if origin and origin.lower() not in ("http://127.0.0.1:%d" % port,
                                             "http://localhost:%d" % port):
            raise Refused(403, "cross-origin request refused")

    def send(self, status, body, ctype="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)

    def fail(self, e):
        self.send(e.status, dict({"error": e.reason}, **e.extra))

    def do_GET(self):
        try:
            self.local()
            url = urllib.parse.urlparse(self.path)
            query = urllib.parse.parse_qs(url.query)
            if url.path in STATIC:
                path, ctype = STATIC[url.path]
                with open(path, "rb") as fh:
                    self.send(200, fh.read(), ctype)
            elif url.path == "/api/assets":
                self.send(200, self.editor.assets())
            elif url.path == "/api/list":
                self.send(200, self.editor.listing())
            elif url.path == "/api/template":
                self.send(200, self.editor.template((query.get("name") or [None])[0]))
            else:
                raise Refused(404, "not found")
        except Refused as e:
            self.fail(e)
        except Exception as e:  # never drop the connection; nothing was written
            self.fail(Refused(500, "editor error: %s: %s" % (type(e).__name__, e)))

    def do_POST(self):
        try:
            self.local()
            if not (self.headers.get("Content-Type") or "").startswith("application/json"):
                raise Refused(415, "the editor takes JSON")
            length = int(self.headers.get("Content-Length") or 0)
            if length <= 0 or length > MAX_BODY:
                raise Refused(413, "no body or a body too large")
            try:
                body = json.loads(self.rfile.read(length).decode("utf-8"))
            except ValueError:
                raise Refused(400, "the body is not JSON")
            if not isinstance(body, dict):
                raise Refused(400, "the body is not an object")
            if self.path == "/api/check":
                self.send(200, self.editor.review(body))
            elif self.path == "/api/save":
                self.send(200, self.editor.save(body))
            else:
                raise Refused(404, "not found")
        except Refused as e:
            self.fail(e)
        except Exception as e:  # never drop the connection; nothing was written
            self.fail(Refused(500, "editor error: %s: %s" % (type(e).__name__, e)))


def make_server(root, port, verbose=False):
    """The server on 127.0.0.1 (never another address)."""
    editor = Editor(root)
    handler = type("BoundHandler", (Handler,), {"editor": editor})
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    server.verbose = verbose
    server.daemon_threads = True
    return server


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=DEFAULT_PORT, help="port (0: a free one)")
    ap.add_argument("--root", default=build_viewer.REPO,
                    help="the checkout to edit (default: this one)")
    ap.add_argument("--verbose", action="store_true", help="log every request")
    args = ap.parse_args(argv)
    server = make_server(args.root, args.port, args.verbose)
    server.RequestHandlerClass.editor.assets()  # build once, before the first page load
    print("template editor: http://127.0.0.1:%d/  (root %s; Ctrl+C stops it)" % (
        server.server_address[1], server.RequestHandlerClass.editor.root), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    sys.exit(main())

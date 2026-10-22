#!/usr/bin/env python3
"""Tests of the template editor's server and writer (tools/building_templates/editor).

    python3 tools/r56_editor/test_editor.py

On a disposable clone (common.scratch_root), never the working tree:
- the writer's byte round trip on every frozen template and fixture, and an
  unedited save through the server that writes nothing;
- localhost only (the bound address, the Host and Origin checks, JSON only);
- path confinement (names, `..`, a link, unknown paths; writes only into
  the templates directory) and the atomic write (a failed rename leaves the
  file and no temp file);
- the save gate: a walled-in door, a door without its upper cell and a bed
  without its head refused with their rules and the file untouched; a valid
  edit written; warnings only with a confirmation; a stale page refused;
- fixed size and move-only points (the page sends positions only; extra
  point data, a missing point and a resized box are refused; a moved point
  keeps its group, face and attributes in the file);
- the version at HEAD for the "changed since commit" highlight.
Exits 1 on the first failure. Python 3, git and LuaJIT (the validator).
"""

import glob
import http.client
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import common  # noqa: E402
from common import serve  # noqa: E402
import tplfile  # noqa: E402

TPL = "hearthpine_west_home"
SHARED = "dawnmere_tollhouse"
CHECKS = [0]


def check(cond, what):
    CHECKS[0] += 1
    if not cond:
        raise SystemExit("FAIL: %s" % what)


def request(port, method, path, body=None, headers=None):
    conn = http.client.HTTPConnection("127.0.0.1", port, timeout=60)
    h = {"Host": "127.0.0.1:%d" % port}
    data = None
    if body is not None:
        data = json.dumps(body).encode() if not isinstance(body, bytes) else body
        h["Content-Type"] = "application/json"
    h.update(headers or {})
    conn.request(method, path, body=data, headers=h)
    res = conn.getresponse()
    raw = res.read()
    conn.close()
    try:
        return res.status, json.loads(raw)
    except ValueError:
        return res.status, raw


class Edit(object):
    """The page's view of a template: cells by position, as the page sends them."""

    def __init__(self, tpl):
        self.tpl = tpl
        self.cell = tpl["cell"]
        self.legend = [list(e) for e in tpl["legend"]]
        self.layers = [list(rows) for rows in tpl["layers"]]
        self.points = [[p[1], p[2], p[3]] for p in tpl["points"]]
        self.x0, self.y0, self.z0 = tpl["origin"]

    def key(self, text):
        for k, t in self.legend:
            if t == text:
                return k
        used = {k for k, _ in self.legend}
        k = next(c for c in tplfile.ALPHABET if c not in used)
        self.legend.append([k, text])
        return k

    def get(self, x, y, z):
        row = self.layers[y - self.y0][z - self.z0]
        i = (x - self.x0) * self.cell
        return row[i:i + self.cell]

    def put(self, x, y, z, key):
        rows = self.layers[y - self.y0]
        row = rows[z - self.z0]
        i = (x - self.x0) * self.cell
        rows[z - self.z0] = row[:i] + key + row[i + self.cell:]

    def body(self, **extra):
        out = {"name": self.tpl["name"], "hash": self.tpl["hash"], "cell": self.cell,
               "legend": self.legend, "layers": self.layers, "points": self.points}
        out.update(extra)
        return out


def find(edit, test):
    for y in range(edit.y0, edit.y0 + edit.tpl["size"][1]):
        for z in range(edit.z0, edit.z0 + edit.tpl["size"][2]):
            for x in range(edit.x0, edit.x0 + edit.tpl["size"][0]):
                if test(x, y, z):
                    return x, y, z
    return None


def main():
    # -- the writer's round trip, every frozen template and fixture ----------
    paths = sorted(glob.glob(os.path.join(common.REPO, serve.BASE, "templates", "*.tpl")))
    paths += sorted(glob.glob(os.path.join(common.REPO, "tools/building_templates/viewer/fixtures/templates/*.tpl")))
    check(len(paths) >= 50, "the frozen templates are there")
    for path in paths:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
        ok, why = tplfile.canonical(text, path)
        check(ok, "%s is canonical: %s" % (os.path.basename(path), why))
        m = tplfile.load(text, path)
        tplfile.prune_legend(m)
        check(tplfile.dump(m) == text, "%s: an unedited write is byte-identical" % os.path.basename(path))
    bad = "grudgelands-building-template 1\nname x\n# a comment\npivot 1 1\norigin 0 0 0\nsize 1 1 1\ncell 1\nraces human\n\nlegend\n# inside\nA role wall\nend\n\nlayer 0\n|A|\n\npoints\nend\n"
    ok, why = tplfile.canonical(bad, "x.tpl")
    check(not ok and "line 11" in why, "a comment inside the legend is reported, not hidden: %s" % why)

    tmp, root = common.scratch_root()
    srv = common.Running(root)
    port = srv.port
    tdir = os.path.join(root, serve.BASE, "templates")
    path = os.path.join(tdir, TPL + ".tpl")
    try:
        with open(path, "rb") as fh:
            original = fh.read()

        # -- localhost only ----------------------------------------------------
        check(srv.server.server_address[0] == "127.0.0.1", "bound to 127.0.0.1")
        status, _ = request(port, "GET", "/api/list", headers={"Host": "evil.example:%d" % port})
        check(status == 403, "another Host is refused (%s)" % status)
        status, _ = request(port, "GET", "/api/list", headers={"Host": "localhost:%d" % port})
        check(status == 200, "localhost is answered")
        status, _ = request(port, "POST", "/api/check", {"name": TPL}, headers={"Origin": "http://evil.example"})
        check(status == 403, "a cross-origin POST is refused")
        status, _ = request(port, "POST", "/api/save", b"name=x", headers={"Content-Type": "application/x-www-form-urlencoded"})
        check(status == 415, "a form POST is refused (%s)" % status)

        # -- path confinement -------------------------------------------------
        for name, want in (("../BASELINE", 400), ("a/b", 400), ("..", 400), ("x.tpl", 400),
                           ("", 400), ("no_such_template", 404)):
            status, _ = request(port, "GET", "/api/template?name=" + name)
            check(status == want, "template name %r: %s (want %s)" % (name, status, want))
        outside = os.path.join(tmp, "outside.tpl")
        shutil.copyfile(path, outside)
        os.symlink(outside, os.path.join(tdir, "linked.tpl"))
        status, _ = request(port, "GET", "/api/template?name=linked")
        check(status in (403, 404), "a link in the templates directory is not followed (%s)" % status)
        os.unlink(os.path.join(tdir, "linked.tpl"))
        for p in ("/../serve.py", "/editor.py", "/api/../serve.py", "/tplfile.py"):
            status, _ = request(port, "GET", p)
            check(status == 404, "only the page's files are served: %s (%s)" % (p, status))
        status, page = request(port, "GET", "/")
        check(status == 200 and b"/editor.js" in page, "the page is served")
        for name in ("../" + TPL, "/tmp/x", ".."):
            status, _ = request(port, "POST", "/api/save", {"name": name, "hash": "x"})
            check(status == 400, "a save to %r is refused" % name)
        before = sorted(os.listdir(tdir))

        # -- an unedited save writes nothing ----------------------------------
        status, tpl = request(port, "GET", "/api/template?name=" + TPL)
        check(status == 200 and tpl["canonical"], "the template opens")
        check(tpl["head"] and tpl["head"]["layers"] == tpl["layers"], "the version at HEAD comes along")
        mtime = os.stat(path).st_mtime_ns
        status, r = request(port, "POST", "/api/save", Edit(tpl).body())
        check(status == 200 and r["saved"] and r["unchanged"], "an unedited save: %s" % r)
        check(os.stat(path).st_mtime_ns == mtime, "an unedited save does not touch the file")

        # -- fixed size, legend keys, move-only points ------------------------
        e = Edit(tpl)
        status, r = request(port, "POST", "/api/check", e.body(layers=e.layers[:-1]))
        check(status == 400, "a box with a layer less is refused")
        status, r = request(port, "POST", "/api/check", e.body(layers=[[row + "." for row in rows] for rows in e.layers]))
        check(status == 400, "a wider box is refused")
        for key in (".", " ", "|", "#", "AB"):
            status, r = request(port, "POST", "/api/check", e.body(legend=e.legend + [[key, "role wall"]]))
            check(status == 400, "legend key %r is refused" % key)
        status, r = request(port, "POST", "/api/check", e.body(legend=e.legend + [["~", "role wall\nnode x"]]))
        check(status == 400, "a legend entry with a line break is refused")
        status, r = request(port, "POST", "/api/check", e.body(points=e.points[:-1]))
        check(status == 400, "a point less is refused")
        status, r = request(port, "POST", "/api/check", e.body(points=[p + ["face=3"] for p in e.points]))
        check(status == 400, "point data beyond a position is refused")
        status, r = request(port, "POST", "/api/check", e.body(cell=3))
        check(status == 400, "cell 3 is refused")

        # -- the save gate ----------------------------------------------------
        door = next(p for p in tpl["points"] if p[0] == "doors")
        e = Edit(tpl)
        e.put(door[1], door[2], door[3], e.key("role wall"))
        status, r = request(port, "POST", "/api/save", e.body())
        rules = {f["rule"] for f in r.get("errors", [])}
        check(status == 409 and "point_place" in rules and "reach" in rules, "a walled-in door is refused: %s" % rules)
        check(open(path, "rb").read() == original, "a refused save writes nothing")
        e = Edit(tpl)
        e.put(door[1], door[2] + 1, door[3], ".")
        status, r = request(port, "POST", "/api/save", e.body())
        check(status == 409 and "multi_cell" in {f["rule"] for f in r["errors"]}, "a door without its upper cell is refused")
        bed = find(Edit(tpl), lambda x, y, z: Edit(tpl).get(x, y, z) in [k for k, t in tpl["legend"] if t.startswith("role bed variant=_top")])
        e = Edit(tpl)
        e.put(bed[0], bed[1], bed[2], ".")
        status, r = request(port, "POST", "/api/save", e.body())
        check(status == 409 and "multi_cell" in {f["rule"] for f in r["errors"]}, "a bed without its head is refused")
        check(any(f["pos"] for f in r["errors"]), "errors carry their cells")
        check(open(path, "rb").read() == original, "still nothing written")
        # a valid edit: a block on a free cell above the floor, a moved point
        e = Edit(tpl)
        wall = e.key("role wall_accent")
        spot = find(e, lambda x, y, z: y >= 3 and e.get(x, y, z) == "." and 2 <= x <= 6 and 2 <= z <= 6)
        e.put(*spot, wall)
        lights = [i for i, p in enumerate(tpl["points"]) if p[0] == "lights"]
        e.points[lights[0]] = [e.points[lights[0]][0], e.points[lights[0]][1] + 1, e.points[lights[0]][2]]
        status, r = request(port, "POST", "/api/check", e.body())
        check(status == 200 and not r["errors"] and not r["unchanged"], "a valid edit checks clean: %s" % r)
        status, r = request(port, "POST", "/api/save", e.body())
        check(status == 200 and r["saved"], "a valid edit is saved: %s" % r)
        written = open(path, "rb").read()
        check(written != original, "the file changed")
        check(sorted(os.listdir(tdir)) == before, "only the template file changed in its directory (no temp file left)")
        text = written.decode()
        old_lines, new_lines = original.decode().split("\n"), text.split("\n")
        changed = [(a, b) for a, b in zip(old_lines, new_lines) if a != b]
        check(len(old_lines) + 1 == len(new_lines) or len(old_lines) == len(new_lines), "the file keeps its layout")
        moved_old = original.decode().split("\npoints\n")[1].split("\n")[lights[0]]
        moved_new = text.split("\npoints\n")[1].split("\n")[lights[0]]
        check(moved_old.split()[0] == moved_new.split()[0] and moved_old.split()[4:] == moved_new.split()[4:] and
              int(moved_new.split()[2]) == int(moved_old.split()[2]) + 1, "a moved point keeps its group and attributes")
        check("role wall_accent" in text, "the new block is in the legend")
        status, again = request(port, "GET", "/api/template?name=" + TPL)
        check(again["hash"] != tpl["hash"] and again["head"]["layers"] == tpl["layers"], "HEAD stays the committed version")
        status, r = request(port, "POST", "/api/save", e.body())
        check(status == 409 and r.get("stale"), "a page with an old hash is refused")
        # a stale page check reports it
        status, r = request(port, "POST", "/api/check", e.body())
        check(status == 200 and r["stale"], "a check says the page is stale")

        # warnings need a confirmation: a fixed node in a template two races place
        status, shared = request(port, "GET", "/api/template?name=" + SHARED)
        check(shared["used"] == 2 and "used 2" in shared["used_text"], "the shared template's uses")
        e = Edit(shared)
        glass = e.key("node default:glass")
        spot = find(e, lambda x, y, z: y >= 2 and e.get(x, y, z) == "." and e.get(x, y - 1, z) not in (".", " "))
        e.put(*spot, glass)
        spath = os.path.join(tdir, SHARED + ".tpl")
        sorig = open(spath, "rb").read()
        status, r = request(port, "POST", "/api/save", e.body())
        check(status == 409 and r.get("need_confirm") and any(w["rule"] == "fixed_in_shared" for w in r["warnings"]),
              "a warning needs a confirmation: %s" % r.get("error"))
        check(open(spath, "rb").read() == sorig, "nothing written before the confirmation")
        status, r = request(port, "POST", "/api/save", e.body(confirm=True))
        check(status == 200 and r["saved"], "saved after the confirmation")

        # -- builds: every town and capital is built through the game's loader;
        # a build error of a town that places the edited template refuses the
        # save, one of a town that does not place it is a warning. No edit
        # within the editor's rules was found that breaks a build (every
        # leave-unchanged cell of every Highcourt and Lethariel template
        # filled with air or a wall builds), so the build finding is injected
        # into the real validator's report.
        status, r = request(port, "POST", "/api/check", Edit(tpl).body(hash=again["hash"]))
        check(status == 200 and not any(w["rule"] == "build" for w in r["warnings"]),
              "the clone builds every town and capital: %s" % r["warnings"][:2])
        real_validate = serve.check.validate
        broken_town = ["highcourt"]

        def validate(root, baseline, replaced, **kw):
            report = real_validate(root, baseline, replaced, **kw)
            report.error("build", broken_town[0], None, "does not build: wp13 %s: no door for kings_hall"
                         % broken_town[0])
            return report
        serve.check.validate = validate
        try:
            status, cap = request(port, "GET", "/api/template?name=highcourt_chapel_house")
            check("Highcourt" in cap["used_text"], "a capital template opens with its roster use")
            e = Edit(cap)
            spot = find(e, lambda x, y, z: y >= 2 and e.get(x, y, z) == "." and e.get(x, y - 1, z) not in (".", " "))
            e.put(*spot, e.key("role wall"))
            cpath = os.path.join(tdir, "highcourt_chapel_house.tpl")
            corig = open(cpath, "rb").read()
            status, r = request(port, "POST", "/api/save", e.body(confirm=True))
            check(status == 409 and any(f["rule"] == "build" and "Highcourt" in f["message"] for f in r["errors"]),
                  "a capital template edit that breaks its capital's build is refused: %s" % r.get("errors"))
            check(open(cpath, "rb").read() == corig, "nothing written")
            broken_town[0] = "kezamba"
            status, r = request(port, "POST", "/api/save", e.body())
            check(status == 409 and r.get("need_confirm") and not r["errors"] and
                  any(w["rule"] == "build" and "Kezamba" in w["message"] for w in r["warnings"]),
                  "a build error of a capital that does not place the template is a warning: %s" % r.get("error"))
            status, r = request(port, "POST", "/api/save", e.body(confirm=True))
            check(status == 200 and r["saved"], "and the unrelated edit saves after the confirmation")
        finally:
            serve.check.validate = real_validate

        # -- a file on disk that does not parse: a JSON error, nothing written
        broken = os.path.join(tdir, "broken_one.tpl")
        with open(broken, "w") as fh:
            fh.write("grudgelands-building-template 1\nname broken_one\nlegend\n")
        status, r = request(port, "GET", "/api/template?name=broken_one")
        check(status == 422 and "error" in r, "a broken file does not open: %s" % status)
        status, r = request(port, "POST", "/api/check", Edit(tpl).body(name="broken_one"))
        check(status == 500 and isinstance(r, dict) and "error" in r, "a server error answers JSON (%s)" % status)
        check(open(broken).read().endswith("legend\n"), "and writes nothing")
        os.unlink(broken)

        # -- the editor palette offers no rooted water plants -------------------
        status, assets = request(port, "GET", "/api/assets")
        offered = {n for _, items in assets["editor_palette"] for _, n in items}
        for name in ("default:coral_cyan", "default:coral_green", "default:coral_pink", "default:sand_with_kelp"):
            check(name not in offered, "%s is not in the editor palette" % name)
        check("default:coral_brown" in offered, "the plain coral blocks stay")

        # -- the atomic write -------------------------------------------------
        target = os.path.join(tmp, "atomic.tpl")
        with open(target, "wb") as fh:
            fh.write(b"old")
        real_replace = serve.os.replace
        serve.os.replace = lambda a, b: (_ for _ in ()).throw(OSError("disk full"))
        try:
            serve.write_atomic(target, b"new")
            check(False, "a failing rename raises")
        except OSError:
            pass
        finally:
            serve.os.replace = real_replace
        check(open(target, "rb").read() == b"old", "a failed write leaves the file")
        check(os.listdir(tmp).count("atomic.tpl") == 1 and not [n for n in os.listdir(tmp) if n.endswith(".tmp")],
              "a failed write leaves no temp file")
        serve.write_atomic(target, b"new")
        check(open(target, "rb").read() == b"new", "the atomic write replaces the file")
    finally:
        srv.stop()
        shutil.rmtree(tmp, ignore_errors=True)
    print("test_editor: %d checks passed" % CHECKS[0])
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Shared by the editor's tests: a disposable checkout to edit, and the
server on it.

``scratch_root()`` makes a sparse, shared clone of this repository at HEAD in
a new temp directory (the templates, the mapgen's palette Lua, the template
tools), so the tests write template files there and never in the working
tree. The validator needs the clone's history for BASELINE; a shared clone
reads the objects of this repository and writes nothing into it. The
template tools' data files are copied from the working tree, so an
uncommitted change to the editor palette is what the tests see.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import threading

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(REPO, "tools", "building_templates", "editor"))

import serve  # noqa: E402

# the mapgen whole: the validator builds every town and capital from it
SPARSE = ["/mods/MAPGEN/grug_mapgen/", "/tools/building_templates/"]
COPIED = ["tools/building_templates/nodes.json", "tools/building_templates/editor_palette.txt",
          "tools/building_templates/palette_dump.lua"]


def git(*args, cwd=REPO):
    run = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    if run.returncode != 0:
        raise SystemExit("git %s: %s" % (" ".join(args), run.stderr.strip()))
    return run.stdout.strip()


def scratch_root():
    """(temp dir, clone root). The caller removes the temp dir."""
    tmp = tempfile.mkdtemp(prefix="r56-editor-")
    root = os.path.join(tmp, "repo")
    common = os.path.abspath(os.path.join(REPO, git("rev-parse", "--git-common-dir")))
    head = git("rev-parse", "HEAD")
    git("clone", "-q", "--shared", "--no-checkout", common, root)
    git("sparse-checkout", "set", "--no-cone", *SPARSE, cwd=root)
    git("checkout", "-q", head, cwd=root)
    for rel in COPIED:
        shutil.copyfile(os.path.join(REPO, rel), os.path.join(root, rel))
    return tmp, root


class Running(object):
    """The editor server on a root, in a thread, on a free port."""

    def __init__(self, root):
        self.server = serve.make_server(root, 0)
        self.port = self.server.server_address[1]
        self.url = "http://127.0.0.1:%d" % self.port
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    @property
    def editor(self):
        return self.server.RequestHandlerClass.editor

    def stop(self):
        self.server.shutdown()
        self.server.server_close()

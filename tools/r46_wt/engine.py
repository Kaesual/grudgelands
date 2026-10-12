"""Round 46 lane WT engine run: the waiting point with real network clients.

One boot of a fresh world (seed 42) through the round's measuring queue
(`engine_run.sh`, which runs tools/luanti_headless.sh) with the disposable
probe grug_probe_r46_wt and a staged minetest.conf that raises
grug_reset_world to 1, so every character without a reset record has a
backlog. Players are real protocol clients (tools/r43_it/client.py, extended
here): they acknowledge map blocks (TOSERVER_GOTBLOCKS) and report their
position, look, view range and field of view like a standard client
(TOSERVER_PLAYERPOS every 0.1 s, viewing_range 190, fov 72 degrees), so the
engine generates and sends map around them as it would for a real player.

  setup    oldhero, leaver, arriver, steady join once as new players and
           leave; the probe saves their characters at their old positions;
  measure  while the preparation runs: newbie (new) and the four rejoin;
           right after the engine's first position each existing client
           reports that (stale) position once, the race every teleport has;
           leaver and arriver leave after 4 s;
  ready    newbie creates a Throng Troll Warrior through the inventory
           formspec; leaver and arriver join again; the probe waits for
           every teleport;
  end      every client leaves; the probe prints its summary and shuts the
           server down.

Usage (worktree root): python3 tools/r46_wt/engine.py OUT_DIR [LABEL]
Writes OUT_DIR/probe.txt (the probe's lines), OUT_DIR/clients.txt (what each
client saw: the positions the server sent, the blocks it received) and
OUT_DIR/run.txt; exits 0 only when the probe reports RESULT PASS.
"""

import os
import re
import difflib
import shutil
import socket
import subprocess
import struct
import sys
import tempfile
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.dont_write_bytecode = True  # no __pycache__ next to the shared client
sys.path.insert(0, str(REPO / "tools" / "r43_it"))
import client as base  # noqa: E402

QUEUE = Path.home() / "projects/grudgelands-orchestration/r45/engine_run.sh"
PROBE = HERE / "grug_probe_r46_wt"
TOCLIENT_BLOCKDATA, TOCLIENT_MOVE_PLAYER = 0x20, 0x34
TOSERVER_PLAYERPOS, TOSERVER_GOTBLOCKS, TOSERVER_INVENTORY_FIELDS = 0x23, 0x24, 0x3C
BS = 10.0
FOV = 72 * 3.14159265 / 180  # radians, as the client's camera fov
WANTED_RANGE = 190  # nodes, the client's default viewing_range
WAIT_Y = 31000


class Player(base.Client):
    """A client that stays in the game: acknowledges blocks, reports its
    position, records what the server sent."""

    def __init__(self, port, name, log):
        super().__init__(port, name, password="wt-" + name, log=log)
        self.pos = None  # in nodes
        self.moves = []  # every TOCLIENT_MOVE_PLAYER position, in nodes
        self.blocks = []  # every block position received
        self.stale_sent = False
        self.pending_fields = []  # sent by the client's own thread
        self.lock = threading.Lock()

    def _command(self, data):
        if len(data) >= 2:
            (command,) = struct.unpack_from(">H", data, 0)
            payload = data[2:]
            if command == TOCLIENT_MOVE_PLAYER and len(payload) >= 12:
                x, y, z = struct.unpack_from(">fff", payload, 0)
                pos = (x / BS, y / BS, z / BS)
                with self.lock:
                    self.moves.append(pos)
                    self.pos = pos
                if len(self.moves) == 1 and pos[1] < WAIT_Y - 1:
                    # The stale report: the engine's first position, sent back
                    # before the client has read the next move.
                    self.send_pos(pos)
                    self.stale_sent = True
                return
            if command == TOCLIENT_BLOCKDATA and len(payload) >= 6:
                bx, by, bz = struct.unpack_from(">hhh", payload, 0)
                self.blocks.append((bx, by, bz))
                self.send(TOSERVER_GOTBLOCKS, struct.pack(">Bhhh", 1, bx, by, bz), channel=2)
                return
        super()._command(data)

    def send_pos(self, pos=None):
        pos = pos or self.pos
        if pos is None:
            return
        p = [int(round(v * BS * 100)) for v in pos]
        payload = struct.pack(">iiiiiiiiIBBBff", p[0], p[1], p[2], 0, 0, 0, 0, 0, 0,
                              int(min(255, FOV * 80)), int(-(-WANTED_RANGE // 16)), 0,
                              0.0, 0.0)
        self.send(TOSERVER_PLAYERPOS, payload, channel=0, reliable=False)

    def send_fields(self, fields):
        payload = base._string("") + struct.pack(">H", len(fields))
        for key, value in fields.items():
            data = value.encode()
            payload += base._string(key) + struct.pack(">I", len(data)) + data
        self.send(TOSERVER_INVENTORY_FIELDS, payload, channel=0)

    def connect(self):
        """The join of tools/r43_it/client.py without its stay and leave."""
        self.send(0, b"", channel=0)
        end = time.monotonic() + 10
        while self.peer_id == 0:
            if time.monotonic() > end:
                raise base.JoinError("%s: the server gave no peer id" % self.name)
            self.pump(0.05)
        init = struct.pack(">BHHH", base.SER_FMT_VER_HIGHEST_READ, 0, base.PROTOCOL_MIN,
                           base.PROTOCOL_MAX) + base._string(self.name)
        hello = None
        for _ in range(10):
            self.send(base.TOSERVER_INIT, init, channel=1, reliable=False)
            try:
                hello = self.wait_for((base.TOCLIENT_HELLO,), 1)
                break
            except base.JoinError:
                if self.denied:
                    raise
        if hello is None:
            raise base.JoinError("%s: no TOCLIENT_HELLO" % self.name)
        _ser, _unused, _proto, mechs = struct.unpack_from(">BHHI", hello[1], 0)
        self._authenticate(mechs)
        self.wait_for((base.TOCLIENT_AUTH_ACCEPT,), 10)
        self.send(base.TOSERVER_INIT2, base._string(""))
        self.send(base.TOSERVER_CLIENT_READY, struct.pack(">BBBB", 5, 17, 0, 0) +
                  base._string("5.17.0-r46-wt") + struct.pack(">H", base.FORMSPEC_VERSION))

    def play(self, stop, seconds=None):
        """Stays until `stop` is set (or `seconds` passed), reporting the
        position every 0.1 s, then leaves."""
        end = time.monotonic() + seconds if seconds else None
        while not stop.is_set() and not self.closed and (end is None or time.monotonic() < end):
            self.pump(0.1)
            self.send_pos()
            self.inbox.clear()
            with self.lock:
                fields, self.pending_fields = self.pending_fields[:1], self.pending_fields[1:]
            for f in fields:
                self.send_fields(f)
        self.inbox.clear()
        self.leave()


class Run:
    def __init__(self, out):
        self.out = out
        self.lines = []
        self.players = []
        self.lock = threading.Lock()

    def note(self, text):
        line = "%s %s" % (time.strftime("%H:%M:%S"), text)
        with self.lock:
            self.lines.append(line)
        print(line, flush=True)


def free_port():
    for _ in range(50):
        port = 30000 + int.from_bytes(os.urandom(2), "big") % 10000
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            try:
                s.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    raise RuntimeError("no free port")


def reset_patch(work):
    old = (REPO / "minetest.conf").read_text().splitlines(keepends=True)
    new = old + ["\n", "# Round 46 WT only: the platform raises this for a map reset.\n",
                 "grug_reset_world = 1\n"]
    path = work / "reset.patch"
    path.write_text("".join(difflib.unified_diff(old, new, "a/minetest.conf",
                                                 "b/minetest.conf")))
    return path


def main():
    out = Path(sys.argv[1]).resolve()
    label = sys.argv[2] if len(sys.argv) > 2 else "r46-wt-waiting-point"
    out.mkdir(parents=True, exist_ok=True)
    run = Run(out)
    root = Path(tempfile.mkdtemp(prefix="grudgelands-headless.", dir="/tmp"))
    work = Path(tempfile.mkdtemp(prefix="r46_wt."))
    port = free_port()
    env = dict(os.environ, ROOT=str(root), PORT=str(port), SEED="42", PROBE=str(PROBE),
               GAME_PATCH=str(reset_patch(work)), LC_ALL="C")
    env.pop("KEEP", None)
    launcher_out = out / "launcher.txt"
    started = time.monotonic()
    status = 1
    try:
        with open(launcher_out, "w") as handle:
            proc = subprocess.Popen(
                [str(QUEUE), label, "290"], cwd=str(REPO), env=env,
                stdout=handle, stderr=subprocess.STDOUT)
            log = root / "server.log"

            def log_has(pattern):
                return log.exists() and re.search(pattern, log.read_text(errors="replace"))

            while proc.poll() is None and not log_has(r"listening on"):
                time.sleep(0.5)
            if proc.poll() is None:
                status = drive(run, port, log_has, proc)
            proc.wait()
        run.note("launcher exit %d after %.0f s" % (proc.returncode,
                                                     time.monotonic() - started))
        text = log.read_text(errors="replace") if log.exists() else ""
        probe_lines = [line for line in text.splitlines() if "[r46_wt_probe]" in line]
        (out / "probe.txt").write_text("\n".join(probe_lines) + "\n")
        interesting = re.compile(r"joins game|leaves game|map reset|moved too fast|ERROR|"
                                 r"listening on|world preparation")
        (out / "server_lines.txt").write_text("\n".join(
            line for line in text.splitlines() if interesting.search(line)) + "\n")
        passed = any("RESULT PASS" in line for line in probe_lines)
        status = 0 if passed and proc.returncode == 0 and status == 0 else 1
        run.note("r46 wt engine: %s" % ("PASS" if status == 0 else "FAIL"))
    finally:
        (out / "run.txt").write_text("\n".join(run.lines) + "\n")
        write_clients(run, out / "clients.txt")
        shutil.rmtree(work, ignore_errors=True)
        if root.name.startswith("grudgelands-headless.") and root.parent == Path("/tmp"):
            shutil.rmtree(root, ignore_errors=True)
    return status


def session(run, port, name, stop, seconds=None, after_connect=None):
    player = Player(port, name, log=run.note)
    player.session = len([p for p in run.players if p.name == name]) + 1
    run.players.append(player)
    try:
        player.connect()
        run.note("%s #%d connected" % (name, player.session))
        if after_connect:
            after_connect(player)
        player.play(stop, seconds)
        run.note("%s #%d left" % (name, player.session))
    except base.JoinError as err:
        run.note("%s #%d JOIN FAILED: %s" % (name, player.session, err))


def start(run, port, name, stop, seconds=None):
    thread = threading.Thread(target=session, args=(run, port, name, stop, seconds))
    thread.start()
    return thread


def wait_until(log_has, pattern, proc, timeout):
    end = time.monotonic() + timeout
    while time.monotonic() < end and proc.poll() is None:
        if log_has(pattern):
            return True
        time.sleep(0.3)
    return False


def drive(run, port, log_has, proc):
    never = threading.Event()
    # Setup: four new players join once and leave.
    threads = [start(run, port, name, never, seconds=2.0)
               for name in ("oldhero", "leaver", "arriver", "steady")]
    for t in threads:
        t.join()
    time.sleep(1)  # the engine saves a leaving player at its next step
    if log_has(r"\[r46_wt_probe\] READY"):
        run.note("the preparation was ready before the measured joins: invalid run")
    # Measure: joins during the preparation.
    stay = threading.Event()
    threads = [start(run, port, "newbie", stay), start(run, port, "oldhero", stay),
               start(run, port, "steady", stay),
               start(run, port, "leaver", never, seconds=4.0),
               start(run, port, "arriver", never, seconds=4.0)]
    if not wait_until(log_has, r"\[r46_wt_probe\] READY", proc, 200):
        run.note("no READY")
        stay.set()
        return 1
    run.note("preparation ready")
    newbie = next(p for p in run.players if p.name == "newbie")
    with newbie.lock:
        newbie.pending_fields += [{"faction_throng": "The Throng"}, {"race_troll": "Troll"},
                                  {"class_warrior": "Warrior"},
                                  {"create_character": "Create character"}]
    threads[3].join()
    threads[4].join()
    threads += [start(run, port, "leaver", stay), start(run, port, "arriver", stay)]
    settled = wait_until(log_has, r"\[r46_wt_probe\] ALL SETTLED", proc, 120)
    run.note("all settled" if settled else "not settled")
    # A few seconds at the starts and at the waiting point's neighbourhood.
    time.sleep(5)
    stay.set()
    for t in threads:
        t.join()
    return 0 if settled else 1


def write_clients(run, path):
    lines = []
    for p in run.players:
        moves = ", ".join("(%.0f,%.0f,%.0f)" % m for m in p.moves)
        high = sum(1 for b in p.blocks if b[1] * 16 > 29000)
        lines.append("%s #%d: positions sent by the server: %s" % (p.name, p.session,
                                                                     moves or "none"))
        lines.append("  stale first position reported back: %s; blocks received: %d "
                     "(above y 29000: %d)" % (p.stale_sent, len(p.blocks), high))
    path.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    sys.exit(main())

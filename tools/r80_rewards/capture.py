#!/usr/bin/env python3
"""Round 80 lane REWARDS: engine screenshots of the Account page holding every
reward, the Character page's cloak picker and the six donor cloaks worn. One
boot of a headless server with grug_bridge pointed at the fake bridge in
accounts mode (tools/r691_bridge/fake_bridge.py, in this process; the method
of tools/r79_page/capture.py), one real client at a time on a private Xvfb
display, once per GUI scale (default 1 and 2: the smallest and the largest
text against the form). The account a_test1 holds every reward of the
catalogue the game sent (seven cloaks on this branch); each client is a new
character bound to it directly. Per scale:

  A01_account        the Account page, every reward of the real catalogue
  A02_account_8      the same with Cheer added (a stub list in the probe:
                     the EMOTE lane's reward is not on this branch)
  A03_account_18     a stub list of 18 rewards, the most the card holds
  A04_character      the Character page, Frost Regent worn (the picker)

and at the first scale only (the art does not depend on the GUI scale):

  C0n_<cloak>        one donor cloak worn: back, three quarters from the
                     left and from the right (frozen copies of the
                     character's own look, after the real select_cloak)
  C07_all_back       the six side by side from behind
  C08_all_3q         the six side by side at three quarters

Called by capture.sh, which holds the temp directories and Xvfb. Writes
OUT/<shot>_s<scale>.png, OUT/capture.json (the state at each shot), the server
log and the headless launcher's verdict (the smoke boot)."""

import json
import math
import os
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(REPO / "tools" / "r691_bridge"))
from fake_bridge import Accounts, Bridge  # noqa: E402

OUT, ROOT, CAP = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
DISPLAY = sys.argv[4]
WORLD = ROOT / "world"
TOKEN = secrets.token_hex(32)
SETTLE = float(os.environ.get("SETTLE", "2.5"))
SCALES = os.environ.get("GUI_SCALES", "1 2").split()
NAMES = ["Rowan", "Isolde", "Brannoc"]
DONOR = ["emberwake", "veilstream", "pearlwing", "moonfall", "wintercourt", "frost_regent"]
SERVER_TIMEOUT = int(os.environ.get("SERVER_TIMEOUT", "330"))
ACCOUNT_PAGE, CHARACTER_PAGE = "grug_accounts:account", "grug_inventory:character"

record = []


def free_port(kind):
    with socket.socket(socket.AF_INET, kind) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def wait(what, test, limit=60.0, step=0.3):
    end = time.time() + limit
    while time.time() < end:
        value = test()
        if value:
            return value
        time.sleep(step)
    raise TimeoutError("waited for " + what)


class Server:
    def __init__(self, bridge_port):
        self.port = free_port(socket.SOCK_DGRAM)
        conf = (REPO / "minetest.conf").read_text()
        conf += f"\nport = {self.port}\nbind_address = 127.0.0.1\nserver_announce = false\n"
        conf += "fixed_map_seed = 42\nmobs_spawn = false\n"
        conf += "secure.http_mods = grug_bridge\n"
        conf += f"grug_bridge.url = http://127.0.0.1:{bridge_port}\ngrug_bridge.token = {TOKEN}\n"
        path = ROOT / "rewards.conf"
        path.write_text(conf)
        env = dict(os.environ, ROOT=str(ROOT), PORT=str(self.port),
                   PROBE=str(HERE / "grug_probe_r80_rewards"), LC_ALL="C")
        self.output = open(OUT / "headless.txt", "w")
        self.process = subprocess.Popen(
            [str(REPO / "tools/luanti_headless.sh"), str(SERVER_TIMEOUT), "--config", str(path)],
            env=env, stdout=self.output, stderr=subprocess.STDOUT)
        self.request_id = 0

    def log_text(self):
        try:
            return (ROOT / "server.log").read_text(errors="replace")
        except FileNotFoundError:
            return ""

    def probe(self, op, **fields):
        self.request_id += 1
        fields.update(id=self.request_id, op=op)
        temp = WORLD / "r80rewards_in.tmp"
        temp.write_text(json.dumps(fields))
        temp.replace(WORLD / "r80rewards_in")

        def answer():
            try:
                row = json.loads((WORLD / "r80rewards_out").read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                return None
            return row if row.get("id") == self.request_id else None
        # The engine writes an empty table as null.
        result = wait("the probe: " + op, answer, 30, 0.1)["result"] or {}
        if "error" in result:
            raise RuntimeError(f"probe {op}: {result['error']}")
        return result

    def stop(self):
        try:
            self.probe("shutdown")
        except (TimeoutError, RuntimeError):
            pass
        try:
            return self.process.wait(timeout=90)
        finally:
            self.output.close()
            if (ROOT / "server.log").exists():
                shutil.copy(ROOT / "server.log", OUT / "server.log")


class Client:
    def __init__(self, server, name, scale):
        self.log = CAP / f"client-{name}.log"
        conf = CAP / f"client-{scale}.conf"
        conf.write_text("screen_w = 1920\nscreen_h = 1080\nfullscreen = false\n"
                        "enable_sound = false\nviewing_range = 60\nfps_max = 20\n"
                        f"hud_scaling = {scale}\ngui_scaling = {scale}\n"
                        "enable_dynamic_shadows = false\nenable_bloom = false\n")
        env = {k: v for k, v in os.environ.items() if k != "WAYLAND_DISPLAY"}
        env["DISPLAY"] = DISPLAY
        self.process = subprocess.Popen(
            ["timeout", "--kill-after=5", "200", "flatpak", "run", "--command=luanti",
             "--socket=x11", "--nosocket=wayland", f"--filesystem={CAP}",
             f"--env=DISPLAY={DISPLAY}", "--env=SDL_VIDEODRIVER=x11",
             "--env=__GLX_VENDOR_LIBRARY_NAME=mesa", "--env=LIBGL_ALWAYS_SOFTWARE=1",
             f"--env=LUANTI_USER_PATH={CAP}/user", f"--env=XDG_CACHE_HOME={CAP}/xdg/cache",
             f"--env=XDG_DATA_HOME={CAP}/xdg/data", f"--env=XDG_CONFIG_HOME={CAP}/xdg/config",
             "--env=LC_ALL=C", "org.luanti.luanti", "--go", "--address", "127.0.0.1",
             "--port", str(server.port), "--name", name, "--config", str(conf),
             "--logfile", str(self.log)],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def stop(self):
        subprocess.run(["pkill", "-TERM", "-f", f"luanti.bin --go .*--logfile {self.log}"],
                       check=False)
        try:
            self.process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            subprocess.run(["pkill", "-KILL", "-f", f"luanti.bin --go .*--logfile {self.log}"],
                           check=False)
            self.process.wait(timeout=15)
        if self.log.exists():
            shutil.copy(self.log, OUT / self.log.name)



def session(server, bridge, name, scale, first):
    accounts = bridge.accounts
    suffix = f"_s{scale}"

    def status():
        return server.probe("status", name=name)

    def snap(label, view):
        time.sleep(SETTLE)
        path = OUT / f"{label}{suffix}.png"
        subprocess.run(["import", "-display", DISPLAY, "-window", "root", str(path)], check=True)
        row = dict(status(), shot=path.name, **view)
        row.pop("online", None)
        record.append(row)
        print(f"shot {path.name}: {row.get('rewards')} rewards, {row.get('selected')}", flush=True)

    def shot(label, page, stub=None):
        fields = {"name": name, "page": page}
        if stub:
            fields["stub"] = stub
        snap(label, server.probe("show", **fields))

    def figures(label, figs, **cam):
        snap(label, server.probe("figures", name=name, figures=figs, **cam))

    client = Client(server, name, scale)
    try:
        wait("the client", lambda: status().get("online"), 150, 1)
        server.probe("privs", name=name)
        wait("the list", lambda: status().get("enabled"), 30, 0.5)
        wait("the starting areas", lambda: status().get("prepared"), 180, 1)
        wait("the arrival", lambda: server.probe("ready", name=name).get("done"), 180, 1)
        wait("the catalogue", lambda: accounts.catalog, 30, 0.5)
        with bridge.lock:
            for entry in accounts.catalog:
                accounts.do_grant("a_test1", entry["id"])
        wait("the character id", lambda: bridge_bind(bridge, name), 30, 0.5)
        catalog = status().get("catalog")
        wait("the rewards", lambda: status().get("rewards") == catalog, 20)
        time.sleep(2)
        shot("A01_account", ACCOUNT_PAGE)
        shot("A02_account_8", ACCOUNT_PAGE, 8)
        shot("A03_account_18", ACCOUNT_PAGE, 18)
        if not server.probe("select_cloak", name=name, cloak="frost_regent").get("ok"):
            raise RuntimeError("Frost Regent could not be chosen")
        shot("A04_character", CHARACTER_PAGE)
        if not first:
            return
        pi = math.pi
        for index, cloak in enumerate(DONOR, 1):
            if not server.probe("select_cloak", name=name, cloak=cloak).get("ok"):
                raise RuntimeError(cloak + " could not be chosen")
            figures(f"C0{index}_{cloak}", [{"x": -1.5, "yaw": pi * 0.25}, {"x": 0, "yaw": 0},
                                            {"x": 1.5, "yaw": -pi * 0.25}])
        # The six side by side: each figure is the look at its spawn, so the
        # cloak changes between them (keep: earlier figures stay).
        for label, yaw in (("C07_all_back", 0), ("C08_all_3q", pi * 0.22)):
            for index, cloak in enumerate(DONOR):
                server.probe("select_cloak", name=name, cloak=cloak)
                server.probe("figures", name=name, keep=index > 0, distance=5.6,
                             figures=[{"x": (index - 2.5) * 1.25, "yaw": yaw}])
            snap(label, {"figures": len(DONOR)})
        server.probe("clear")
    finally:
        client.stop()


def bridge_bind(bridge, name):
    with bridge.lock:
        return bridge.accounts.do_bind(name, "a_test1") == "" or name.lower() in bridge.accounts.bindings


def main():
    lines = []
    bridge = Bridge(free_port(socket.SOCK_STREAM), TOKEN)
    bridge.accounts = Accounts(out=lines.append)
    bridge.start()
    failure, status = None, None
    try:
        server = Server(bridge.port)
        wait("the server", lambda: "listening on" in server.log_text(), 240, 0.5)
        for index, scale in enumerate(SCALES):
            session(server, bridge, NAMES[index], scale, index == 0)
    except Exception as error:  # reported below; cleanup stays with capture.sh
        failure = repr(error)
    finally:
        try:
            status = server.stop()
        except Exception as error:  # noqa: BLE001
            failure = failure or repr(error)
        bridge.stop()
    (OUT / "capture.json").write_text(json.dumps({"failure": failure, "server_status": status,
                                                  "shots": record}, indent=1))
    (OUT / "accounts.txt").write_text("\n".join(lines) + "\n")
    print(f"capture: {len(record)} shots, server status {status}, failure {failure}")
    return 1 if failure or status != 0 else 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(2))
    sys.exit(main())

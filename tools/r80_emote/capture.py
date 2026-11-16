#!/usr/bin/env python3
"""Round 80 lane EMOTE: engine screenshots of the quickbar's emote icons and
of Cheer. One boot of a headless server with grug_bridge pointed at the fake
bridge in accounts mode (tools/r691_bridge/fake_bridge.py, in this process),
one real client at a time on a private Xvfb display, once per GUI scale
(default 1 and 2: the smallest and the largest text against the form). Each
client is a new character:

  Q1 the quickbar, not linked: Wave and Dance only
  Q2 linked, the account given emote:cheer: Wave, Dance, Cheer
  Q3 riding: Wave and Cheer live, Dance greyed (the tooltip needs a mouse;
     the fixture checks it)
  A1 the Account page with the Cheer row and its icon (first scale only)
  C1-C3 Cheer standing, three moments (first scale only)
  S1-S2 Cheer seated on the mount, two moments (first scale only)

Called by capture.sh, which holds the temp directories and Xvfb. Writes
OUT/<shot>_s<scale>.png, OUT/capture.json (the state at each shot), the
server log and the headless launcher's verdict (the smoke boot)."""

import json
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
SERVER_TIMEOUT = int(os.environ.get("SERVER_TIMEOUT", "330"))

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
        path = ROOT / "emote.conf"
        path.write_text(conf)
        env = dict(os.environ, ROOT=str(ROOT), PORT=str(self.port),
                   PROBE=str(HERE / "grug_probe_r80_emote"), LC_ALL="C")
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
        temp = WORLD / "r80emote_in.tmp"
        temp.write_text(json.dumps(fields))
        temp.replace(WORLD / "r80emote_in")

        def answer():
            try:
                row = json.loads((WORLD / "r80emote_out").read_text())
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


def session(server, bridge, name, scale, frames):
    accounts = bridge.accounts
    suffix = f"_s{scale}"

    def status():
        return server.probe("status", name=name)

    def snap(label, settle=SETTLE):
        time.sleep(settle)
        path = OUT / f"{label}{suffix}.png"
        subprocess.run(["import", "-display", DISPLAY, "-window", "root", str(path)], check=True)
        row = dict(status(), shot=path.name)
        row.pop("online", None)
        record.append(row)
        print(f"shot {path.name}: emotes {row['emotes']} riding {row['riding']} "
              f"animation {row['animation']}", flush=True)

    def emote(label, which, after):
        # A fresh start for every moment: the clip is over and the gap passed.
        time.sleep(2.6)
        result = server.probe("emote", name=name, emote=which)
        if not result.get("ok"):
            raise RuntimeError(f"{which}: {result.get('why')}")
        snap(label, after)

    client = Client(server, name, scale)
    try:
        wait("the client", lambda: status().get("online"), 150, 1)
        wait("the list", lambda: status().get("enabled"), 30, 0.5)
        wait("the starting areas", lambda: status().get("prepared"), 180, 1)
        wait("the arrival", lambda: server.probe("ready", name=name).get("done"), 180, 1)
        time.sleep(2)
        server.probe("quickbar", name=name)
        snap("Q1_quickbar_not_linked")
        server.probe("close", name=name)
        with bridge.lock:
            message = accounts.do_bind(name, "a_test1")
            if message:
                raise RuntimeError(message)
            accounts.do_grant("a_test1", "emote:cheer")
        wait("the cheer", lambda: status().get("cheer"), 20)
        server.probe("quickbar", name=name)
        snap("Q2_quickbar_cheer")
        server.probe("close", name=name)
        mounted = server.probe("mount", name=name)
        if not mounted.get("ok"):
            raise RuntimeError(f"mount: {mounted.get('why')}")
        wait("the ride", lambda: status().get("riding"), 10)
        server.probe("quickbar", name=name)
        snap("Q3_quickbar_riding")
        server.probe("close", name=name)
        if frames:
            emote("S1_cheer_seated_early", "cheer", 0.45)
            emote("S2_cheer_seated_v", "cheer", 0.9)
            server.probe("dismount", name=name)
            wait("the dismount", lambda: not status().get("riding"), 10)
            emote("C1_cheer_early", "cheer", 0.25)
            emote("C2_cheer_v", "cheer", 0.6)
            emote("C3_cheer_pump", "cheer", 1.1)
            server.probe("camera", name=name, mode="first")
            server.probe("account", name=name)
            snap("A1_account_page_cheer")
            server.probe("close", name=name)
        else:
            server.probe("dismount", name=name)
        # The next character starts without the binding on screen.
        with bridge.lock:
            accounts.do_unlink(name)
    finally:
        client.stop()


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

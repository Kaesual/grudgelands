#!/usr/bin/env python3
"""Round 79 lane PAGE: engine screenshots of the Account page in every state
and of the Character page's cloak picker with the account cloak. One boot of
a headless server with grug_bridge pointed at the fake bridge in accounts mode
(tools/r691_bridge/fake_bridge.py, in this process), one real client at a
time on a private Xvfb display, once per GUI scale (default 1 and 2: the
smallest and the largest text against the form). Each client is a new
character, so every state is shot at every scale:

  P01 in character creation      P06 waiting after the confirmation
  P02 not linked                 P07 linked, no rewards (64-character name)
  P03 a website refusal          P08 linked with the Supporter Cloak
  P04 waiting after Link         P09 the Character page, the cloak worn
  P05 the offer (64-character name)

The buttons are pressed through the page's own handler (the probe), the
answers come from the fake bridge (a delay holds the waiting states). The
account a_test1 carries a 64-character name with formspec characters.

Called by capture.sh, which holds the temp directories and Xvfb. Writes
OUT/P0n_<state>_s<scale>.png, OUT/capture.json (the state at each shot), the
server log and the headless launcher's verdict (the smoke boot). A link code
reaches only the probe's request file inside the temp world; nothing here
prints or writes one."""

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
LONG_NAME = "Ser Aldric [the; Patient], keeper of the long road \\ home 123456"
ACCOUNT_PAGE, CHARACTER_PAGE = "grug_accounts:account", "grug_inventory:character"
assert len(LONG_NAME) == 64

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
        path = ROOT / "page.conf"
        path.write_text(conf)
        env = dict(os.environ, ROOT=str(ROOT), PORT=str(self.port),
                   PROBE=str(HERE / "grug_probe_r79_page"), LC_ALL="C")
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
        temp = WORLD / "r79page_in.tmp"
        temp.write_text(json.dumps(fields))
        temp.replace(WORLD / "r79page_in")

        def answer():
            try:
                row = json.loads((WORLD / "r79page_out").read_text())
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


def session(server, bridge, name, scale):
    accounts = bridge.accounts
    suffix = f"_s{scale}"

    def status():
        return server.probe("status", name=name)

    def shot(label, page):
        view = server.probe("show", name=name, page=page)
        time.sleep(SETTLE)
        path = OUT / f"{label}{suffix}.png"
        subprocess.run(["import", "-display", DISPLAY, "-window", "root", str(path)], check=True)
        row = dict(status(), shot=path.name, page=view["page"], picker=view["picker"],
                   account_tab=view["account_tab"], bytes=view["bytes"])
        row.pop("online", None)
        record.append(row)
        print(f"shot {path.name}: {row['state']} {row.get('account_name') is not None}", flush=True)

    def click(**fields):
        return server.probe("click", name=name, fields=fields)

    client = Client(server, name, scale)
    try:
        wait("the client", lambda: status().get("online"), 150, 1)
        server.probe("privs", name=name)
        wait("the list", lambda: status().get("enabled"), 30, 0.5)
        # The first join waits for the starting areas behind its own window.
        wait("the starting areas", lambda: status().get("prepared"), 180, 1)
        time.sleep(3)  # the client's first frames, the creation window
        shot("P01_creation", ACCOUNT_PAGE)
        wait("the arrival", lambda: server.probe("ready", name=name).get("done"), 180, 1)
        time.sleep(2)
        shot("P02_not_linked", ACCOUNT_PAGE)
        with bridge.lock:
            accounts.delay = 0
        click(grug_account_code="ABCDE-FGH23", grug_account_link="Link")
        wait("the refusal", lambda: status().get("state") == "refused", 20)
        shot("P03_refused", ACCOUNT_PAGE)
        with bridge.lock:
            code = accounts.new_code("a_test1")
            accounts.delay = 9
        click(grug_account_code=code[:5] + "-" + code[5:], grug_account_link="Link")
        shot("P04_waiting_link", ACCOUNT_PAGE)
        wait("the offer", lambda: status().get("state") == "offer", 25)
        shot("P05_offer", ACCOUNT_PAGE)
        click(grug_account_confirm="Link")
        shot("P06_waiting_confirm", ACCOUNT_PAGE)
        wait("the binding", lambda: status().get("account_name"), 25)
        shot("P07_linked_no_rewards", ACCOUNT_PAGE)
        with bridge.lock:
            accounts.do_grant("a_test1", "cloak:supporter")
        wait("the cloak", lambda: status().get("cloak"), 15)
        shot("P08_linked_cloak", ACCOUNT_PAGE)
        if not server.probe("select_cloak", name=name, cloak="supporter").get("ok"):
            raise RuntimeError("the account cloak could not be chosen")
        shot("P09_character_picker", CHARACTER_PAGE)
        # The next character starts without the reward on screen.
        with bridge.lock:
            accounts.do_revoke("a_test1", "cloak:supporter")
    finally:
        client.stop()


def main():
    lines = []
    bridge = Bridge(free_port(socket.SOCK_STREAM), TOKEN)
    bridge.accounts = Accounts(out=lines.append)
    bridge.accounts.accounts["a_test1"]["name"] = LONG_NAME
    bridge.start()
    failure, status = None, None
    try:
        server = Server(bridge.port)
        wait("the server", lambda: "listening on" in server.log_text(), 240, 0.5)
        for index, scale in enumerate(SCALES):
            session(server, bridge, NAMES[index], scale)
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

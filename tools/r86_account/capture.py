#!/usr/bin/env python3
"""Round 86 lane ACCOUNT: engine screenshots of the Account page "The Charter"
for the user's pick. One boot of a headless server with grug_bridge pointed at
the fake bridge in accounts mode (tools/r691_bridge/fake_bridge.py, in this
process, which sends default_rewards to a game reporting rewards.defaults) and
the probe of tools/r79_page (show a page, press its buttons, report the state).
One real client per screen size on its own Xvfb display, each a new
character, so every state is shot at both sizes:

  A1 unlinked, one default reward     A5 an expired code
  A2 unlinked, three default rewards  A6 the confirmation
  A3 unlinked, no default rewards     A7 linked, two rewards
  A4 a wrong code                     A8 linked, every reward of the catalogue

The account a_test1 is named "Fenlark" as in the mock-up. Called by
capture.sh, which holds the temp directories and the displays. Writes
OUT/A<n>_<state>_<w>x<h>.png, OUT/capture.json (the state at each shot), the
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
PROBE = REPO / "tools" / "r79_page" / "grug_probe_r79_page"
sys.path.insert(0, str(REPO / "tools" / "r691_bridge"))
from fake_bridge import Accounts, Bridge  # noqa: E402

OUT, ROOT, CAP = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
DISPLAYS = [entry.split("=") for entry in sys.argv[4:]]
WORLD = ROOT / "world"
TOKEN = secrets.token_hex(32)
SETTLE = float(os.environ.get("SETTLE", "2.5"))
SERVER_TIMEOUT = int(os.environ.get("SERVER_TIMEOUT", "420"))
NAMES = ["Tarnwick", "Rowan"]
ACCOUNT_PAGE = "grug_accounts:account"
ALL_REWARDS = ["emote:cheer", "cloak:supporter", "cloak:emberwake", "cloak:veilstream",
               "cloak:pearlwing", "cloak:moonfall", "cloak:wintercourt", "cloak:frost_regent"]

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
    """The headless server with the probe (as tools/r79_page/capture.py)."""

    def __init__(self, bridge_port):
        self.port = free_port(socket.SOCK_DGRAM)
        conf = (REPO / "minetest.conf").read_text()
        conf += f"\nport = {self.port}\nbind_address = 127.0.0.1\nserver_announce = false\n"
        conf += "fixed_map_seed = 42\nmobs_spawn = false\n"
        conf += "secure.http_mods = grug_bridge\n"
        conf += f"grug_bridge.url = http://127.0.0.1:{bridge_port}\ngrug_bridge.token = {TOKEN}\n"
        path = ROOT / "account.conf"
        path.write_text(conf)
        env = dict(os.environ, ROOT=str(ROOT), PORT=str(self.port), PROBE=str(PROBE), LC_ALL="C")
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
    """One real client on `display` at the screen size `size` (W x H)."""

    def __init__(self, server, name, display, size):
        w, h = size.split("x")
        self.log = CAP / f"client-{name}.log"
        conf = CAP / f"client-{size}.conf"
        conf.write_text(f"screen_w = {w}\nscreen_h = {h}\nfullscreen = false\n"
                        "enable_sound = false\nviewing_range = 60\nfps_max = 20\n"
                        "hud_scaling = 1\ngui_scaling = 1\n"
                        "enable_dynamic_shadows = false\nenable_bloom = false\n")
        env = {k: v for k, v in os.environ.items() if k != "WAYLAND_DISPLAY"}
        env["DISPLAY"] = display
        self.process = subprocess.Popen(
            ["timeout", "--kill-after=5", "240", "flatpak", "run", "--command=luanti",
             "--socket=x11", "--nosocket=wayland", f"--filesystem={CAP}",
             f"--env=DISPLAY={display}", "--env=SDL_VIDEODRIVER=x11",
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


def session(server, bridge, name, display, size):
    accounts = bridge.accounts

    def status():
        return server.probe("status", name=name)

    def applied():
        with bridge.lock:
            return bridge.requests and bridge.requests[-1].get("accounts_version") == accounts.version

    def shot(label):
        view = server.probe("show", name=name, page=ACCOUNT_PAGE)
        time.sleep(SETTLE)
        path = OUT / f"{label}_{size}.png"
        subprocess.run(["import", "-display", display, "-window", "root", str(path)], check=True)
        row = dict(status(), shot=path.name, page=view["page"], bytes=view["bytes"])
        row.pop("online", None)
        record.append(row)
        print(f"shot {path.name}: {row['state']}", flush=True)

    def click(**fields):
        return server.probe("click", name=name, fields=fields)

    def defaults(ids):
        with bridge.lock:
            accounts.defaults = list(ids)
            accounts.changed()
        wait("the defaults", applied, 20, 0.3)

    client = Client(server, name, display, size)
    try:
        wait("the client", lambda: status().get("online"), 150, 1)
        server.probe("privs", name=name)
        wait("the list", lambda: status().get("enabled"), 30, 0.5)
        wait("the starting areas", lambda: status().get("prepared"), 180, 1)
        wait("the arrival", lambda: server.probe("ready", name=name).get("done"), 180, 1)
        time.sleep(2)
        defaults(["emote:cheer"])
        shot("A1_unlinked_one")
        defaults(["cloak:emberwake", "cloak:pearlwing", "emote:cheer"])
        shot("A2_unlinked_three")
        defaults([])
        shot("A3_unlinked_none")
        defaults(["emote:cheer"])
        click(grug_account_code="ABCDE-FGH23", grug_account_link="Check code")
        wait("the wrong code", lambda: status().get("state") == "refused", 20)
        shot("A4_wrong_code")
        with bridge.lock:
            code = accounts.new_code("a_test1")
            accounts.codes[code]["created"] -= 3600
        click(grug_account_code=code[:5] + "-" + code[5:], grug_account_link="Check code")
        wait("the expired code", lambda: status().get("state") == "refused", 20)
        shot("A5_expired_code")
        with bridge.lock:
            code = accounts.new_code("a_test1")
        click(grug_account_code=code[:5] + "-" + code[5:], grug_account_link="Check code")
        wait("the offer", lambda: status().get("state") == "offer", 25)
        shot("A6_confirmation")
        click(grug_account_confirm="Confirm link")
        wait("the binding", lambda: status().get("account_name"), 25)
        with bridge.lock:
            accounts.accounts["a_test1"]["rewards"] = ["emote:cheer", "cloak:emberwake"]
            accounts.changed()
        wait("the rewards", applied, 20, 0.3)
        shot("A7_linked")
        with bridge.lock:
            accounts.accounts["a_test1"]["rewards"] = list(ALL_REWARDS)
            accounts.changed()
        wait("every reward", applied, 20, 0.3)
        shot("A8_linked_all")
        with bridge.lock:
            accounts.accounts["a_test1"]["rewards"] = []
            accounts.changed()
    finally:
        client.stop()


def main():
    lines = []
    bridge = Bridge(free_port(socket.SOCK_STREAM), TOKEN)
    bridge.accounts = Accounts(out=lines.append, defaults=["emote:cheer"])
    bridge.accounts.accounts["a_test1"]["name"] = "Fenlark"
    bridge.start()
    failure, status, server = None, None, None
    try:
        server = Server(bridge.port)
        wait("the server", lambda: "listening on" in server.log_text(), 240, 0.5)
        for index, (display, size) in enumerate(DISPLAYS):
            session(server, bridge, NAMES[index], display, size)
    except Exception as error:  # reported below; cleanup stays with capture.sh
        failure = repr(error)
    finally:
        try:
            if server:
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

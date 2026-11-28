#!/usr/bin/env python3
"""Round 89 lane BUBBLE: engine screenshots of the shield bubble for the
user's go. One boot of a headless server with the disposable probe
grug_probe_r89_bubble; TWO real clients at once, each on its own private Xvfb
display: Brann (The Accord, dwarf: the small race, stature 0.90) and Ukka
(The Throng, troll: the tall race, 1.12). The probe builds a stage in the air
above Brann's arrival (out of every guard's reach) and sets up each scene;
this script shoots the display of the scene's viewer.

Called by capture.sh, which holds the temp directories and both Xvfb
displays. Writes OUT/<shot>.png, OUT/capture.json (each scene and both
players' bubble state at the shot), the server and client logs and the
headless launcher's verdict (the smoke boot of the branch)."""

import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent

OUT, ROOT, CAP, PROBE = (Path(p) for p in sys.argv[1:5])
DISPLAYS = {"Brann": sys.argv[5], "Ukka": sys.argv[6]}
WORLD = ROOT / "world"
SETTLE = float(os.environ.get("SETTLE", "3"))
SERVER_TIMEOUT = int(os.environ.get("SERVER_TIMEOUT", "420"))
CHARACTERS = {"Brann": ("accord", "dwarf"), "Ukka": ("throng", "troll")}

OPEN, SNOW, GLASS, WATER = [0, 0, 0], [14, 0, 0], [-14, 0, 0], [-14, 0, 12]


def look_at(name, spot, z, pitch=8, camera="first", x=0.0, y=0.0):
    """A viewer at `spot` + (x, y, z) looking toward +z."""
    return {"name": name, "spot": spot, "offset": {"x": x, "y": y, "z": z},
            "yaw": 0, "pitch": pitch, "camera": camera}


def shielded(name, spot, shields, x=0.0, y=0.0, z=0.0, mount=False, camera="first",
             yaw=180, pitch=0):
    return {"name": name, "spot": spot, "offset": {"x": x, "y": y, "z": z},
            "yaw": yaw, "pitch": pitch, "camera": camera, "shields": shields,
            "mount": mount}


DAY, NIGHT = 0.5, 0.0
# (shot, viewer whose display is shot, time, players, variant, what it shows)
SCENES = [
    ("01_gold_troll_day", "Brann", DAY,
     [shielded("Ukka", OPEN, ["shield_spell"]), look_at("Brann", OPEN, -4)], None,
     "Priest's Shield (gold) on the tall troll, seen by another player at 4 nodes"),
    ("02_frost_troll_day", "Brann", DAY,
     [shielded("Ukka", OPEN, ["rime_mantle"]), look_at("Brann", OPEN, -4)], None,
     "Rime Mantle (frost) on the troll"),
    ("03_plain_troll_day", "Brann", DAY,
     [shielded("Ukka", OPEN, ["hold_ground"]), look_at("Brann", OPEN, -4)], None,
     "Hold Ground (plain, every other shield) on the troll"),
    ("04_gold_dwarf_day", "Ukka", DAY,
     [shielded("Brann", OPEN, ["shield_spell"]), look_at("Ukka", OPEN, -4)], None,
     "gold on the small dwarf, seen by the troll"),
    ("05_plain_dwarf_day", "Ukka", DAY,
     [shielded("Brann", OPEN, ["parry"]), look_at("Ukka", OPEN, -4)], None,
     "Parry (plain) on the dwarf"),
    ("06_far25_gold_day", "Brann", DAY,
     [shielded("Ukka", OPEN, ["shield_spell"]), look_at("Brann", OPEN, -25, pitch=2)], None,
     "gold at 25 nodes in daylight"),
    ("07_far25_plain_day", "Brann", DAY,
     [shielded("Ukka", OPEN, ["hold_ground"]), look_at("Brann", OPEN, -25, pitch=2)], None,
     "plain at 25 nodes in daylight"),
    ("08_snow_plain", "Brann", DAY,
     [shielded("Ukka", SNOW, ["unbroken"]), look_at("Brann", SNOW, -4)], None,
     "plain (Unbroken) against a snow wall"),
    ("09_snow_gold", "Brann", DAY,
     [shielded("Ukka", SNOW, ["shield_spell"]), look_at("Brann", SNOW, -4)], None,
     "gold against snow"),
    ("10_night_gold", "Brann", NIGHT,
     [shielded("Ukka", OPEN, ["shield_spell"]), look_at("Brann", OPEN, -4)], None,
     "gold at midnight"),
    ("11_night_frost", "Brann", NIGHT,
     [shielded("Ukka", OPEN, ["rime_mantle"]), look_at("Brann", OPEN, -4)], None,
     "frost at midnight"),
    ("12_night_plain", "Brann", NIGHT,
     [shielded("Ukka", OPEN, ["close_dance"]), look_at("Brann", OPEN, -4)], None,
     "plain (Close Dance) at midnight"),
    ("13_night_far20_plain", "Brann", NIGHT,
     [shielded("Ukka", OPEN, ["last_light"]), look_at("Brann", OPEN, -20, pitch=2)], None,
     "plain (Last Light) at 20 nodes at midnight"),
    ("14_mounted_dwarf_gold", "Ukka", DAY,
     [shielded("Brann", OPEN, ["shield_spell"], mount=True), look_at("Ukka", OPEN, -5, pitch=4)],
     None, "the dwarf mounted, gold, seen from the side-front"),
    ("15_overlap_two", "Ukka", DAY,
     [shielded("Brann", OPEN, ["shield_spell"], x=-0.45),
      shielded("Ukka", OPEN, ["hold_ground"], x=0.45, camera="third_front", yaw=180, pitch=10)],
     None, "two shielded players overlapping (gold and plain), the troll's front camera"),
    ("16_own_first_person", "Ukka", DAY,
     [shielded("Ukka", OPEN, ["shield_spell"], yaw=0, pitch=8), shielded("Brann", OPEN, [], z=4)],
     None, "the shielded troll's own first-person view: no bubble (shield icon on the row)"),
    ("17_own_third_person", "Ukka", DAY,
     [shielded("Ukka", OPEN, ["shield_spell"], camera="third", yaw=0, pitch=10),
      shielded("Brann", OPEN, [], z=4)],
     None, "the shielded troll's own third-person (back) camera"),
    ("18_glass_frost", "Brann", DAY,
     [shielded("Ukka", GLASS, ["rime_mantle"]), look_at("Brann", GLASS, -5)], None,
     "frost seen through a glass wall"),
    ("19_water_frost", "Brann", DAY,
     [shielded("Ukka", WATER, ["rime_mantle"], y=-0.6), look_at("Brann", WATER, -5, pitch=12)],
     None, "frost, feet in water"),
    ("20_gold_troll_day_op150", "Brann", DAY,
     [shielded("Ukka", OPEN, ["shield_spell"]), look_at("Brann", OPEN, -4)],
     {"opacity": 150}, "variant: the same textures at 150/255 opacity (thinner)"),
    ("21_plain_troll_day_op150", "Brann", DAY,
     [shielded("Ukka", OPEN, ["hold_ground"]), look_at("Brann", OPEN, -4)],
     {"opacity": 150}, "variant: plain at 150/255 opacity"),
    ("22_night_plain_op150", "Brann", NIGHT,
     [shielded("Ukka", OPEN, ["hold_ground"]), look_at("Brann", OPEN, -4)],
     {"opacity": 150}, "variant: plain at 150/255 opacity at midnight"),
]

# The look round: every look in the same six scenes (gold, frost and plain
# close by day, plain at 25 nodes by day, plain at night, the overlap).
LOOK_SCENES = [
    ("gold_day", "Brann", DAY,
     [shielded("Ukka", OPEN, ["shield_spell"]), look_at("Brann", OPEN, -4)], "gold, 4 nodes, day"),
    ("frost_day", "Brann", DAY,
     [shielded("Ukka", OPEN, ["rime_mantle"]), look_at("Brann", OPEN, -4)], "frost, 4 nodes, day"),
    ("plain_day", "Brann", DAY,
     [shielded("Ukka", OPEN, ["hold_ground"]), look_at("Brann", OPEN, -4)], "plain, 4 nodes, day"),
    ("plain_far25", "Brann", DAY,
     [shielded("Ukka", OPEN, ["hold_ground"]), look_at("Brann", OPEN, -25, pitch=2)],
     "plain, 25 nodes, day"),
    ("plain_night", "Brann", NIGHT,
     [shielded("Ukka", OPEN, ["hold_ground"]), look_at("Brann", OPEN, -4)], "plain, 4 nodes, midnight"),
    ("overlap", "Ukka", DAY,
     [shielded("Brann", OPEN, ["shield_spell"], x=-0.45),
      shielded("Ukka", OPEN, ["hold_ground"], x=0.45, camera="third_front", yaw=180, pitch=10)],
     "two shielded players overlapping (gold and plain)"),
]
# Look round 3 adds a large close shot per colour for each vein look.
CLOSE_SCENES = [
    (f"close_{colour}", "Brann", DAY,
     [shielded("Ukka", OPEN, [shield]), look_at("Brann", OPEN, -2.2, pitch=12)],
     f"{colour}, 2.2 nodes, day (large close shot)")
    for colour, shield in (("gold", "shield_spell"), ("frost", "rime_mantle"),
                           ("plain", "hold_ground"))]
SET = os.environ.get("SET")
if SET in ("round2", "round3"):
    default_looks = ("classic hex panels lattice" if SET == "round2"
                     else "hex marble lightning web")
    LOOKS = os.environ.get("LOOKS", default_looks).split()
    SCENES = []
    for look in LOOKS:
        scenes = LOOK_SCENES + (CLOSE_SCENES if SET == "round3" and look != "hex" else [])
        for index, (name, viewer, tod, players, what) in enumerate(scenes):
            SCENES.append((f"{look}_{index + 1}_{name}", viewer, tod, players,
                           {"look": look}, f"look {look}: {what}"))

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
    def __init__(self):
        self.port = free_port(socket.SOCK_DGRAM)
        conf = (REPO / "minetest.conf").read_text()
        conf += f"\nport = {self.port}\nbind_address = 127.0.0.1\nserver_announce = false\n"
        conf += "fixed_map_seed = 42\nmobs_spawn = false\ntime_speed = 0\n"
        path = ROOT / "bubble.conf"
        path.write_text(conf)
        env = dict(os.environ, ROOT=str(ROOT), PORT=str(self.port), PROBE=str(PROBE),
                   LC_ALL="C")
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
        temp = WORLD / "r89bubble_in.tmp"
        temp.write_text(json.dumps(fields))
        temp.replace(WORLD / "r89bubble_in")

        def answer():
            try:
                row = json.loads((WORLD / "r89bubble_out").read_text())
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
    def __init__(self, server, name):
        self.name = name
        self.display = DISPLAYS[name]
        self.log = CAP / f"client-{name}.log"
        home = CAP / name
        for sub in ("user", "xdg/cache", "xdg/data", "xdg/config"):
            (home / sub).mkdir(parents=True, exist_ok=True)
        conf = CAP / f"client-{name}.conf"
        conf.write_text("screen_w = 1920\nscreen_h = 1080\nfullscreen = false\n"
                        "enable_sound = false\nviewing_range = 80\nfps_max = 20\n"
                        "hud_scaling = 1\ngui_scaling = 1\n"
                        "enable_dynamic_shadows = false\nenable_bloom = false\n")
        env = {k: v for k, v in os.environ.items() if k != "WAYLAND_DISPLAY"}
        env["DISPLAY"] = self.display
        self.process = subprocess.Popen(
            ["timeout", "--kill-after=5", str(SERVER_TIMEOUT - 30), "flatpak", "run",
             "--command=luanti", "--socket=x11", "--nosocket=wayland", f"--filesystem={CAP}",
             f"--env=DISPLAY={self.display}", "--env=SDL_VIDEODRIVER=x11",
             "--env=__GLX_VENDOR_LIBRARY_NAME=mesa", "--env=LIBGL_ALWAYS_SOFTWARE=1",
             f"--env=LUANTI_USER_PATH={home}/user", f"--env=XDG_CACHE_HOME={home}/xdg/cache",
             f"--env=XDG_DATA_HOME={home}/xdg/data", f"--env=XDG_CONFIG_HOME={home}/xdg/config",
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


def run(server):
    clients = [Client(server, name) for name in CHARACTERS]
    try:
        for name, (faction, race) in CHARACTERS.items():
            wait(name + " online", lambda: server.probe("status", name=name).get("online"),
                 180, 1)
        wait("the starting areas", lambda: server.probe("status", name="Brann").get("prepared"),
             180, 1)
        for name, (faction, race) in CHARACTERS.items():
            wait(name + " arrival", lambda: server.probe(
                "ready", name=name, faction=faction, race=race).get("done"), 180, 1)
        server.probe("stage", name="Brann")
        for shot, viewer, tod, players, variant, what in SCENES:
            server.probe("scene", time=tod, players=players, variant=variant)
            time.sleep(SETTLE)
            path = OUT / f"{shot}.png"
            subprocess.run(["import", "-display", DISPLAYS[viewer], "-window", "root", str(path)],
                           check=True)
            state = {name: server.probe("status", name=name) for name in CHARACTERS}
            record.append({"shot": path.name, "viewer": viewer, "what": what,
                           "time": tod, "variant": variant, "players": players,
                           "state": state})
            print(f"shot {path.name}: " + ", ".join(
                f"{n} bubble={s.get('bubble')} {s.get('color')} riding={s.get('riding')}"
                for n, s in state.items()), flush=True)
    finally:
        for client in clients:
            client.stop()


def main():
    failure, status = None, None
    server = None
    try:
        server = Server()
        wait("the server", lambda: "listening on" in server.log_text(), 240, 0.5)
        run(server)
    except Exception as error:  # reported below; cleanup stays with capture.sh
        failure = repr(error)
    finally:
        if server:
            try:
                status = server.stop()
            except Exception as error:  # noqa: BLE001
                failure = failure or repr(error)
    (OUT / "capture.json").write_text(json.dumps({"failure": failure, "server_status": status,
                                                  "shots": record}, indent=1))
    print(f"capture: {len(record)} shots, server status {status}, failure {failure}")
    return 1 if failure or status != 0 else 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(2))
    sys.exit(main())

#!/usr/bin/env python3
"""Round 80 lane FIXES: water brakes a fast fall, measured in the engine.

Called by water_drop.sh (temp dirs, Xvfb). One headless server with the probe
grug_probe_r80_water, one real client (the fall is client physics). After the
character is made, the probe builds a 40-node-deep water tank high above the
start and drops the player into it from 30 nodes, once per override factor:
the game's minetest.conf sets movement_liquid_fluidity_smooth, the factor
multiplies it, so one client measures every value in DROPS (smooth, height).
A first drop from the highest platform is not recorded: it brings the
column's map blocks to the client (in the first run an unsent block held the
falling client mid-air for a second). The server step is 0.03 s, which the
client also uses as its position send interval (clientpackethandler.cpp:139,
client.cpp:606-611), so the trace is sampled about three times as finely as
at the default 0.09 s. Per drop: the entry speed, the depth below the surface
where the downward speed falls below 14 nodes/s (the engine's fall-damage
tolerance, clientenvironment.cpp:204: from there on landing hurts no more,
so this is the water depth that fully protects from the fall) and where it
falls to 3 nodes/s (the stop), both interpolated between samples, the
deepest point. Writes OUT/water_drop.json, the server and client logs."""

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
OUT, ROOT, CAP = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
DISPLAY = sys.argv[4]
WORLD = ROOT / "world"
NAME = "Diver"
SERVER_TIMEOUT = int(os.environ.get("SERVER_TIMEOUT", "300"))
SLOW = 3.0
SAFE = 14.0
STEP = 0.03
SHIPPED = None
for line in (REPO / "minetest.conf").read_text().splitlines():
    if line.startswith("movement_liquid_fluidity_smooth"):
        SHIPPED = float(line.split("=")[1])
# Run 3 (the user's ruling 2026-11-16: a full-speed fall stops within 6-10
# nodes): the candidates between 0.5 (10.6 nodes) and 2 (4.1 nodes) from 30
# nodes, then 60-node drops around the predicted pick (0.75).
DROPS = [(0.6, 30), (0.75, 30), (0.9, 30), (1.0, 30), (1.25, 30), (1.5, 30),
         (0.6, 60), (0.75, 60), (0.9, 60)]


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
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
        self.port = free_port()
        path = ROOT / "water.conf"
        path.write_text(f"port = {self.port}\nbind_address = 127.0.0.1\nserver_announce = false\n"
                        "fixed_map_seed = 42\nmobs_spawn = false\n"
                        f"dedicated_server_step = {STEP}\n")
        env = dict(os.environ, ROOT=str(ROOT), PORT=str(self.port),
                   PROBE=str(HERE / "grug_probe_r80_water"), LC_ALL="C")
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
        temp = WORLD / "r80water_in.tmp"
        temp.write_text(json.dumps(fields))
        temp.replace(WORLD / "r80water_in")

        def answer():
            try:
                row = json.loads((WORLD / "r80water_out").read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                return None
            return row if row.get("id") == self.request_id else None
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
    def __init__(self, server):
        self.log = CAP / "client.log"
        conf = CAP / "client.conf"
        conf.write_text("screen_w = 640\nscreen_h = 360\nfullscreen = false\n"
                        "enable_sound = false\nviewing_range = 60\nfps_max = 60\n"
                        "enable_dynamic_shadows = false\nenable_bloom = false\n")
        env = {k: v for k, v in os.environ.items() if k != "WAYLAND_DISPLAY"}
        env["DISPLAY"] = DISPLAY
        self.process = subprocess.Popen(
            ["timeout", "--kill-after=5", "240", "flatpak", "run", "--command=luanti",
             "--socket=x11", "--nosocket=wayland", f"--filesystem={CAP}",
             f"--env=DISPLAY={DISPLAY}", "--env=SDL_VIDEODRIVER=x11",
             "--env=__GLX_VENDOR_LIBRARY_NAME=mesa", "--env=LIBGL_ALWAYS_SOFTWARE=1",
             f"--env=LUANTI_USER_PATH={CAP}/user", f"--env=XDG_CACHE_HOME={CAP}/xdg/cache",
             f"--env=XDG_DATA_HOME={CAP}/xdg/data", f"--env=XDG_CONFIG_HOME={CAP}/xdg/config",
             "--env=LC_ALL=C", "org.luanti.luanti", "--go", "--address", "127.0.0.1",
             "--port", str(server.port), "--name", NAME, "--config", str(conf),
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


def crossing(samples, start, surface, speed):
    """The depth where the downward speed first falls below `speed` after
    `start`, interpolated linearly between the two samples around it."""
    for index in range(max(1, start), len(samples)):
        a, b = samples[index - 1], samples[index]
        if -b["vy"] < speed:
            va, vb = -a["vy"], -b["vy"]
            share = (va - speed) / (va - vb) if va > speed and va != vb else 0.0
            return surface - (a["y"] + share * (b["y"] - a["y"]))
    return None


def summary(row):
    surface, samples = row["surface"], row["samples"]
    entry, first = None, None
    for index, s in enumerate(samples):
        if surface - s["y"] > 0:
            # The last sample above the surface carries the entry speed.
            first = index
            entry = -samples[max(0, index - 1)]["vy"]
            break
    safe = crossing(samples, first, surface, SAFE) if first is not None else None
    slowed = crossing(samples, first, surface, SLOW) if first is not None else None
    after = [s for s in samples if s["t"] >= samples[-1]["t"] - 0.5]
    sink = -sum(s["vy"] for s in after) / len(after) if after else None
    steps = sorted(b["t"] - a["t"] for a, b in zip(samples, samples[1:]))
    return {"entry_speed": entry, "safe_depth": safe, "slowed_depth": slowed,
            "sink_speed_end": sink, "deepest": surface - min(s["y"] for s in samples),
            "samples": len(samples), "sample_step": steps[len(steps) // 2] if steps else None}


def main():
    results, failure, status = [], None, None
    server = None
    try:
        if not SHIPPED:
            raise RuntimeError("minetest.conf sets no movement_liquid_fluidity_smooth")
        server = Server()
        wait("the server", lambda: "listening on" in server.log_text(), 240, 0.5)
        client = Client(server)
        try:
            wait("the client", lambda: server.probe("status", name=NAME).get("online"), 150, 1)
            wait("the starting areas", lambda: server.probe("status", name=NAME).get("prepared"), 180, 1)
            wait("the arrival", lambda: server.probe("ready", name=NAME).get("done"), 120, 1)
            time.sleep(2)
            wait("the tank", lambda: server.probe("tank", name=NAME).get("state") == "ready", 90, 1)
            # A first, unrecorded drop: the column's map blocks reach the client
            # on the way down (an unsent block holds a falling client mid-air).
            for index, (target, height) in enumerate([(SHIPPED, 60)] + DROPS):
                factor = target / SHIPPED
                server.probe("drop", name=NAME, factor=factor, height=height)
                row = wait("the drop", lambda: (lambda r: r if r.get("done") else None)(
                    server.probe("result")), 30, 0.5)
                if index == 0:
                    print(f"warm-up drop: {summary(row)}", flush=True)
                    continue
                line = dict(summary(row), smooth=target, height=height, factor=factor)
                results.append(dict(line, trace=row["samples"]))
                f = {k: "-" if v is None else f"{v:.2f}" for k, v in line.items()
                     if not isinstance(v, int)}
                print(f"smooth {target:>4} from {height}: entry {f['entry_speed']} n/s, "
                      f"below {SAFE:g} n/s at {f['safe_depth']}, down to {SLOW:g} n/s at "
                      f"{f['slowed_depth']} nodes below the surface, deepest {f['deepest']}, "
                      f"sinking {f['sink_speed_end']} n/s at the end, sample step "
                      f"{line['sample_step']} s", flush=True)
        finally:
            client.stop()
    except Exception as error:  # reported below; cleanup stays with water_drop.sh
        failure = repr(error)
    finally:
        if server:
            try:
                status = server.stop()
            except Exception as error:  # noqa: BLE001
                failure = failure or repr(error)
    (OUT / "water_drop.json").write_text(json.dumps(
        {"failure": failure, "server_status": status, "shipped": SHIPPED, "drops": results},
        indent=1))
    print(f"water_drop: {len(results)} drops, server status {status}, failure {failure}")
    return 1 if failure or status != 0 else 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(2))
    sys.exit(main())

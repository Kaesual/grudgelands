"""Round 47 lane TD: the measuring side of tools/r47_td/measure.sh.

Follows the probe's lines in the server log ("[r47td] BUILT <scene> ...",
"BEGIN <scene> W|I", "END <scene> W|I"), and for every scene:
  * waits until the client has meshed it: at least 4 s after BUILT and two
    profiler prints in a row (one a second) without "Client: Mesh making";
    the mesh making summed over that time is the scene's mesh time; then
    writes "<scene>:go" into the world's ack file;
  * at BEGIN/END notes the time, the frame count of the Gallium HUD dump and
    the client log's length; after END W takes the screenshot and acks
    "<scene>:shot";
  * samples the client's VmRSS every 0.5 s.
At the end writes OUT/run.json: per scene the BUILT line, the settle time,
the mesh time, and per window the frame times, the profiler prints that lie
inside it and the RSS samples. Python 3 standard library only.
"""
import argparse
import json
import os
import re
import subprocess
import time

ENTRY = re.compile(r"\]:\s{2,}(.+?) _*\s+(\d+)x\s+(\S+)\s*$")
EMPTY = re.compile(r"\]:\s{2,}(\S.*?)\s*$")


def read_from(path, offset):
    try:
        with open(path, "rb") as handle:
            handle.seek(offset)
            data = handle.read()
    except FileNotFoundError:
        return b"", offset
    # whole lines only
    cut = data.rfind(b"\n")
    if cut < 0:
        return b"", offset
    return data[:cut + 1], offset + cut + 1


def profiler_blocks(text):
    """Split client log text into profiler prints: a list of {name: value}."""
    blocks, current = [], None
    for line in text.splitlines():
        if "Profiler:" in line and "INFO" in line:
            if current is not None:
                blocks.append(current)
            current = {}
            continue
        if current is None:
            continue
        match = ENTRY.search(line)
        if match:
            current[match.group(1).strip()] = float(match.group(3))
        elif EMPTY.search(line) and "INFO[Main]:   " in line:
            current[EMPTY.search(line).group(1).strip()] = 0.0
        else:
            blocks.append(current)
            current = None
    if current:
        blocks.append(current)
    return blocks


def mesh(block):
    """The block's "Client: Mesh making (sum) [ms]" (0 when absent)."""
    for name, value in block.items():
        if name.startswith("Client: Mesh making"):
            return value
    return 0


def line_count(path):
    try:
        with open(path, "rb") as handle:
            return handle.read().count(b"\n")
    except FileNotFoundError:
        return 0


def size(path):
    try:
        return os.path.getsize(path)
    except FileNotFoundError:
        return 0


def client_pid(tag):
    try:
        found = subprocess.run(["pgrep", "-f", "--", "--logfile " + tag],
                               capture_output=True, text=True).stdout.split()
    except OSError:
        return None
    for pid in found:
        try:
            with open("/proc/%s/comm" % pid) as handle:
                if handle.read().strip() in ("luanti", "luanti.bin"):
                    return int(pid)
        except OSError:
            pass
    return None


def rss_kib(pid):
    try:
        with open("/proc/%d/status" % pid) as handle:
            for line in handle:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1])
    except (OSError, TypeError):
        return None
    return None


def main():
    parser = argparse.ArgumentParser()
    for name in ("server-log", "client-log", "hud", "ack", "client-tag", "display", "out",
                 "label", "prefix"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--server-pid", type=int, required=True)
    args = parser.parse_args()

    started = time.monotonic()
    server_offset = 0
    scenes, order = {}, []
    rss, pid = [], None
    settling = None   # [scene, built_time, client_offset]
    last_rss = 0.0
    done = False
    while not done:
        now = time.monotonic()
        if now - last_rss >= 0.5:
            last_rss = now
            if pid is None:
                pid = client_pid(args.client_tag)
            value = rss_kib(pid) if pid else None
            if value:
                rss.append([now - started, value])
        text, server_offset = read_from(args.server_log, server_offset)
        for raw in text.decode("utf-8", "replace").splitlines():
            if "[r47td]" not in raw:
                continue
            line = raw.split("[r47td] ", 1)[1]
            words = line.split()
            stamp = time.monotonic() - started
            if words[0] == "BUILT":
                scene = words[1]
                order.append(scene)
                scenes[scene] = {"built": line, "built_at": stamp, "windows": {}}
                settling = [scene, stamp, size(args.client_log)]
            elif words[0] in ("BEGIN", "END"):
                scene, window = words[1], words[2]
                record = scenes[scene]["windows"].setdefault(window, {})
                record[words[0].lower()] = {"t": stamp, "frames": line_count(args.hud),
                                            "client": size(args.client_log)}
                if words[0] == "END" and window == "W":
                    shot = os.path.join(args.out, "%s_%s.png" % (args.prefix, scene))
                    subprocess.run(["import", "-display", args.display, "-window", "root",
                                    shot], capture_output=True)
                    with open(args.ack, "w") as handle:
                        handle.write(scene + ":shot\n")
            elif words[0] == "shutdown" or words[0].startswith("ERROR"):
                print("probe:", line)
                done = words[0] == "shutdown"
            elif words[0] in ("READY", "emerge", "mode", "character", "capital", "ack"):
                print("probe:", line)
        if settling:
            scene, built_at, offset = settling
            with open(args.client_log, "rb") as handle:
                handle.seek(offset)
                blocks = profiler_blocks(handle.read().decode("utf-8", "replace"))
            complete = blocks[:-1]   # the last one may still be written
            quiet = len(complete) >= 2 and all(
                mesh(b) == 0 for b in complete[-2:])
            waited = time.monotonic() - started - built_at
            if (waited >= 4 and quiet) or waited > 80:
                scenes[scene]["settle_s"] = waited
                scenes[scene]["mesh_ms"] = sum(mesh(b)
                                               for b in complete)
                scenes[scene]["settle_timeout"] = not quiet
                with open(args.ack, "w") as handle:
                    handle.write(scene + ":go\n")
                settling = None
        try:
            os.kill(args.server_pid, 0)
        except OSError:
            done = True
        time.sleep(0.2)

    # Collect the windows.
    with open(args.hud, "rb") as handle:
        frames = [float(x) for x in handle.read().split()]
    with open(args.client_log, "rb") as handle:
        client = handle.read()
    for scene in order:
        for window, record in scenes[scene]["windows"].items():
            if "begin" not in record or "end" not in record:
                continue
            a, b = record["begin"], record["end"]
            record["frametimes_ms"] = frames[a["frames"]:b["frames"]]
            record["profiler"] = profiler_blocks(
                client[a["client"]:b["client"]].decode("utf-8", "replace"))[1:-1]
            record["rss_kib"] = [v for t, v in rss if a["t"] <= t <= b["t"]]
    result = {"label": args.label, "order": order, "scenes": scenes, "rss": rss,
              "loadavg": open("/proc/loadavg").read().split()[:3]}
    with open(os.path.join(args.out, "run.json"), "w") as handle:
        json.dump(result, handle)
    print("drive: %d scenes, run.json written" % len(order))


if __name__ == "__main__":
    main()

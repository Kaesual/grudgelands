#!/usr/bin/env python3
"""0.49.1 DROP: compare where the client draws each drop with where the server
has it (tools/r491_drop/repro.sh writes probe.txt and client_scan.txt).

  python3 tools/r491_drop/analyze.py OUT_DIR

Each client object the scan saw is matched to the probe drop whose server
resting place is nearest to the object's first sighting (within the drop's
own life). A "slider" is a matched drop that the client still draws moving
over the ground after its server copy has come to rest: its client track
moves more than 0.3 nodes after the landing and its last client position is
more than 0.3 nodes from the server's. For each slider the client's speed is
printed next to the horizontal speed the server last sent before the landing
(the velocity the client keeps when the stop update is lost).
"""
import math
import re
import sys
from pathlib import Path

KV = re.compile(r"(\w+)=(\S+)")


def fields(line):
    return {k: v for k, v in KV.findall(line)}


def num(d, k):
    return float(d[k])


def main(out):
    out = Path(out)
    spawn, land, srv, objs, leads, drops_line = {}, {}, {}, [], [], ""
    for line in (out / "probe.txt").read_text(errors="replace").splitlines():
        f = fields(line)
        if " SPAWN " in line:
            spawn[int(f["n"])] = (num(f, "t"), f["kind"])
        elif " LAND " in line:
            land[int(f["n"])] = f
        elif " SRV " in line:
            srv.setdefault(int(f["n"]), []).append(
                (num(f, "t"), num(f, "x"), num(f, "y"), num(f, "z")))
        elif " OBJ " in line:
            objs.append((int(f["all"]), int(f["moving"])))
        elif " LEAD " in line or " LEADS " in line:
            leads.append(line.split("] ", 1)[-1])
        elif " DROPS total" in line:
            drops_line = line.split("] ", 1)[-1]
    tracks = {}
    scan = out / "client_scan.txt"
    for line in (scan.read_text(errors="replace").splitlines() if scan.exists() else []):
        f = fields(line)
        tracks.setdefault(int(f["id"]), []).append(
            (num(f, "t"), num(f, "x"), num(f, "y"), num(f, "z")))

    drops = sorted(n for n, (_, kind) in spawn.items() if kind == "drop")
    print(f"drops thrown: {len(drops)}, landed: {sum(1 for n in drops if n in land)}")
    if land:
        speeds = [math.hypot(num(land[n], "vx"), num(land[n], "vz")) for n in drops if n in land]
        single = sum(1 for n in drops if n in land and num(land[n], "d") <= 0.2)
        flights = [num(land[n], "flight") for n in drops if n in land]
        print(f"horizontal speed at the last step in the air: mean {sum(speeds)/len(speeds):.2f}, "
              f"max {max(speeds):.2f} nodes/s")
        print(f"flight time: mean {sum(flights)/len(flights):.2f} s")
        print(f"landing step travel <= 0.2 node (the engine sends the stop once): "
              f"{single} of {len(speeds)}; the others get it twice")
    if objs:
        print(f"objects within 128 nodes of the waystone: {min(o[0] for o in objs)}-"
              f"{max(o[0] for o in objs)}, moving {min(o[1] for o in objs)}-{max(o[1] for o in objs)}")
    # the server's resting place of each drop: its last SRV line
    rest = {n: srv[n][-1] for n in drops if n in srv}
    moved_on_server = []
    for n in drops:
        if n in land and n in srv:
            t_land = num(land[n], "t")
            later = [p for p in srv[n] if p[0] >= t_land + 1.0]
            if len(later) >= 2:
                dx = later[-1][1] - later[0][1]
                dz = later[-1][3] - later[0][3]
                if math.hypot(dx, dz) > 0.05:
                    moved_on_server.append((n, math.hypot(dx, dz)))
    print(f"drops that still move on the SERVER 1 s after landing: {len(moved_on_server)}"
          + (f" {moved_on_server}" if moved_on_server else ""))
    # match client objects to drops
    used, matches = set(), []
    for cid, tr in sorted(tracks.items(), key=lambda kv: kv[1][0][0]):
        t0, x0, _, z0 = tr[0]
        best, best_d = None, 1.5
        for n in drops:
            if n in used or n not in rest:
                continue
            born = spawn[n][0]
            if not (born - 1.0 <= t0 <= born + 6.0):
                continue
            d = math.hypot(x0 - rest[n][1], z0 - rest[n][3])
            if d < best_d:
                best, best_d = n, d
        if best is not None:
            used.add(best)
            matches.append((best, cid))
    print(f"client objects seen: {len(tracks)}, matched to drops: {len(matches)}")
    sliders = []
    for n, cid in matches:
        tr = tracks[cid]
        if n not in land:
            continue
        t_land = num(land[n], "t")
        after = [p for p in tr if p[0] >= t_land + 1.0]
        if len(after) < 2:
            continue
        moved = math.hypot(after[-1][1] - after[0][1], after[-1][3] - after[0][3])
        span = after[-1][0] - after[0][0]
        last_off = math.hypot(after[-1][1] - rest[n][1], after[-1][3] - rest[n][3])
        if moved > 0.3 and last_off > 0.3:
            sliders.append((n, cid, moved / span if span > 0 else 0.0, span, last_off,
                            math.hypot(num(land[n], "vx"), num(land[n], "vz")),
                            num(land[n], "d")))
    print(f"SLIDERS (client draws it moving, server has it at rest): {len(sliders)}")
    for n, cid, v, span, off, vs, d in sliders:
        print(f"  drop {n:3d} id {cid:5d}: client speed {v:.2f} n/s over {span:.0f} s, "
              f"{off:.2f} nodes from the server's copy at the end; server's last air "
              f"speed {vs:.2f} n/s, landing step {d:.2f}")
    if drops_line:
        print(drops_line)
    for line in leads:
        print(line)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")

#!/usr/bin/env python3
"""Round 52 PFX: the server and client cost of one card, and the fight
scenarios. Extends Round 40's model (tools/r40_v3/cost_model.py, imported,
not copied): its packet sizes after the engine's own serialization
(Luanti 5.17, reference_projects/luanti src/server.cpp:1656-1854,
src/particles.cpp:230-251), its wire framing and its measured Lua call costs.

What this file adds:
  * deterministic numbers only (the page is rebuilt byte for byte): the zstd
    sizes come from compressing the card's real particle records (a seeded
    RNG), the zstd time from a fit measured once (below), never a timer;
  * how many particles are alive after a cast, n(t), and its integrals: the
    mean particles alive in a fight is sum(rate x integral n dt), its variance
    sum(rate x integral n^2 dt) (a compound Poisson process: casts arrive at
    random, each adds its own curve);
  * the merging of single particles: every single particle the server queues
    in one server step reaches a player in ONE compressed batch
    (server.cpp:1656-1700), so in a busy fight the zstd frame and the packet
    headers are shared. A card alone pays them in full (the per-card number);
    the scenario pays them once per step and receiver.

Emitters come in the sim form effects.py builds (world coordinates, caster at
the origin facing +x): kind, n, steps, texture, attract, shape, vel, acc,
exp, size, glow, radial (outward speed) or reach (the "reach" radial: each
particle flies (reach - its distance) / its life).
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "r40_v3"))
import cost_model as cm  # noqa: E402  (Round 40's model)

STEP = 0.09                    # dedicated_server_step, engine default (builtin/settingtypes.txt)
STEPS_PER_S = 1 / STEP
SPAWNER_US = cm.EST_SPAWNER_SEND_US        # estimate, per receiver
PARTICLE_US = cm.EST_PARTICLE_SERIALIZE_US  # estimate, per particle per receiver
CHECK_US = cm.EST_DISTANCE_CHECK_US         # estimate, per queued particle per player
# zstd level 3 on one batch (libzstd through ctypes on this machine,
# 2026-10-19; 1 record 193 B: 4.0 us, 80 records 15440 B: 11.8 us), a fit
# instead of a timer so the page reproduces.
ZSTD_US_BASE, ZSTD_US_PER_BYTE = 3.9, 0.0005
DT = 0.01  # the alive curve's grid, seconds


def _z():
    if cm._Z is None:
        cm._Z = cm.Zstd()
    return cm._Z


def _r40(e):
    """A sim emitter in the shape Round 40's particle_record reads."""
    return {"spawn": e["shape"], "vel": e["vel"], "acc": e["acc"], "exp": e["exp"],
            "size": e["size"], "texture": e["texture"], "glow": e["glow"],
            "radial": e.get("radial")}


def _records(e, count, seed):
    rng = random.Random(seed)
    r = _r40(e)
    if e.get("reach") is not None:
        # The "reach" radial: (reach - start radius) / life, at the mean life.
        r0 = e["shape"][2] if e["shape"][0] in ("disc", "sphere") else 0.0
        speed = (e["reach"] - r0) / ((e["exp"][0] + e["exp"][1]) / 2)
        r = dict(r)
        r["radial"] = [speed, speed]
    out = []
    for i in range(count):
        rec = cm.particle_record(r, i, count, rng)
        out.append(rec)
    return b"".join(out)


def zframe():
    """Compressed bytes a batch pays once (frame header and the first
    record's extra): one record minus the marginal cost of a second."""
    e = {"shape": ["box", [0, 1, 0], [0.5, 1.5, 0.5]], "vel": [[-1, 0, -1], [1, 2, 1]],
         "acc": [0, -9, 0], "exp": [0.3, 0.5], "size": [2, 3],
         "texture": "default_item_smoke.png^[multiply:#ffe08a", "glow": 12}
    one = _z().compress(_records(e, 1, 1))
    two = _z().compress(_records(e, 2, 1))
    return one - (two - one)


ZFRAME = None


def emitter_cost(e, seed):
    """Per occurrence of one emitter: bytes and datagrams per receiver when
    it is alone in its step, server microseconds, the merged-batch share."""
    global ZFRAME
    if ZFRAME is None:
        ZFRAME = zframe()
    if e["kind"] == "spawner":
        data = cm.spawner_packet(e["texture"], "point" if e.get("attract") else None)
        wire, dg = cm.wire_bytes(data)
        lua = cm.LUA_SPAWNER_ATTRACT_US if e.get("attract") else cm.LUA_SPAWNER_US
        return {"kind": "spawner", "data": data, "wire": wire, "dg": dg, "lua_us": lua,
                "rx_us": SPAWNER_US, "check_us": 0.0, "marginal": 0, "zstd_us": 0.0,
                "steps": 0}
    steps = max(1, e.get("steps", 1))
    per = max(1, e["n"] // steps)
    raw = _records(e, per, seed)
    comp = _z().compress(raw)
    data = 2 + 4 + comp
    wire, dg = cm.wire_bytes(data)
    zus = ZSTD_US_BASE + ZSTD_US_PER_BYTE * len(raw)
    return {"kind": "single", "data": data * steps, "wire": wire * steps, "dg": dg * steps,
            "lua_us": cm.LUA_PARTICLE_US * e["n"], "rx_us": PARTICLE_US * e["n"] + zus * steps,
            "check_us": CHECK_US * e["n"], "marginal": max(0, comp - ZFRAME) * steps,
            "zstd_us": zus * steps, "steps": steps, "raw": len(raw) * steps}


def alive_curve(e, seed):
    """Expected particles alive t seconds after the card plays, n(t), on the
    DT grid (Monte Carlo over birth time and life with a seeded RNG, so it is
    the same on every run). A spawner bears its particles evenly over its
    time; single particles are born at once (a trail over its steps)."""
    rng = random.Random(seed)
    m = 400
    delay = e.get("delay", 0.0)
    span = delay + (e["time"] if e["kind"] == "spawner" else (e.get("steps", 1) - 1) * STEP) + e["exp"][1] + DT
    bins = [0.0] * (int(span / DT) + 2)
    pull = e.get("pull")
    for _ in range(m):
        if e["kind"] == "spawner":
            born = delay + rng.uniform(0, e["time"])
        else:
            born = delay + STEP * rng.randrange(max(1, e.get("steps", 1)))
        life = rng.uniform(*e["exp"])
        if pull and pull["kill"] and pull["smax"] > 0:
            st = rng.uniform(pull["smin"], pull["smax"])
            life = min(life, 1 / st)
        a, b = int(born / DT), int((born + life) / DT)
        for k in range(a, min(b, len(bins))):
            bins[k] += 1
    return [x * e["n"] / m for x in bins]


def card_cost(emitters, seed=0):
    """Totals for one occurrence of a card at grug_particle_scale 1."""
    tot = {"particles": 0, "spawners": 0, "singles": 0, "wire": 0, "dg": 0, "lua_us": 0.0,
           "spawner_wire": 0, "spawner_dg": 0,
           "rx_us": 0.0, "check_us": 0.0, "marginal": 0, "single_events": 0, "zstd_us": 0.0}
    curve = []
    for i, e in enumerate(emitters):
        c = emitter_cost(e, seed * 31 + i)
        tot["wire"] += c["wire"]
        tot["dg"] += c["dg"]
        tot["lua_us"] += c["lua_us"]
        tot["rx_us"] += c["rx_us"]
        tot["check_us"] += c["check_us"]
        tot["particles"] += e["n"]
        if e["kind"] == "spawner":
            tot["spawners"] += 1
            tot["spawner_wire"] += c["wire"]
            tot["spawner_dg"] += c["dg"]
        else:
            tot["singles"] += e["n"]
            tot["marginal"] += c["marginal"]
            tot["single_events"] = max(tot["single_events"], c["steps"])
            tot["zstd_us"] += c["zstd_us"]
        n = alive_curve(e, seed * 17 + i)
        if len(n) > len(curve):
            curve += [0.0] * (len(n) - len(curve))
        for k, x in enumerate(n):
            curve[k] += x
    tot["i1"] = sum(curve) * DT                # particle-seconds per occurrence
    tot["i2"] = sum(x * x for x in curve) * DT
    tot["peak"] = max(curve) if curve else 0.0
    tot["life"] = tot["i1"] / tot["particles"] if tot["particles"] else 0.0
    return tot


def server_us(c, receivers):
    """Main-thread microseconds of one occurrence with `receivers` players
    in range (all of them on the server, as in one busy area)."""
    return c["lua_us"] + receivers * (c["rx_us"] + c["check_us"])


def scenario(cards, players, pace=1.0, scale=1.0):
    """Per receiver in a fight of `players` in one area (everyone in range of
    everything). cards: list of (card cost, rate per player in the fight)
    with rate already including the share of players using it.

    Spawners: their packet per receiver whatever the scale. Single particles:
    merged per server step; marginal compressed bytes scale with the count,
    the frame and headers are paid once per step that carries any."""
    sp_bytes = sp_dg = sp_packets = sing_marg = sing_events = 0.0
    started = mean = var = us = 0.0
    for c, rate in cards:
        r = rate * players * pace
        if r <= 0:
            continue
        sp_bytes += r * c["spawner_wire"]
        sp_dg += r * c["spawner_dg"]
        sp_packets += r * c["spawners"]
        sing_marg += r * c["marginal"] * scale
        sing_events += r * c["single_events"]
        started += r * c["particles"] * scale
        mean += r * c["i1"] * scale
        var += r * c["i2"] * scale * scale
        us += r * server_us(c, players)
    packets = min(sing_events, STEPS_PER_S)
    sing_bytes = sing_dg = 0.0
    if packets > 0:
        per = 6 + ZFRAME + sing_marg / packets
        dg = math.ceil(per / (cm.CHUNK_MAX - cm.SPLIT_HDR)) if per + 1 > cm.CHUNK_MAX else 1
        hdr = (cm.BASE + cm.RELIABLE + cm.IP_UDP) + (cm.SPLIT_HDR if dg > 1 else cm.ORIGINAL_HDR)
        sing_bytes = packets * (per + dg * hdr)
        sing_dg = packets * dg
    return {"bytes": sp_bytes + sing_bytes, "spawner_bytes": sp_bytes, "single_bytes": sing_bytes,
            "datagrams": sp_dg + sing_dg, "packets": sp_packets + packets, "started": started, "mean": mean,
            "peak": mean + 3 * math.sqrt(var), "server_us": us,
            "out_bytes": (sp_bytes + sing_bytes) * players}

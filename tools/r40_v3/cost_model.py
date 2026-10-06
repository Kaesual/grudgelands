#!/usr/bin/env python3
"""Round 40 V3: the server cost model for particle effects (plan §2.12, §3.4).

Deterministic: packet bytes are built field by field after the engine's own
serialization (Luanti 5.17.0-dev, reference_projects/luanti):

  * a particle spawner: Server::SendAddParticleSpawner(peer, ...)
    (src/server.cpp:1762-1854) -- one packet PER RECEIVER, built in the Lua
    call; receivers are the players within max_block_send_distance for an
    unattached spawner with 0 < time <= 1 s, otherwise EVERY player
    (src/server.cpp:1739);
  * a single particle: ParticleParameters::serialize (src/particles.cpp:230-251)
    queued by add_particle and sent in the next server step: for EVERY player
    on the server each queued particle is distance-checked, the ones in range
    serialized (serializeString32-wrapped) and the batch zstd-compressed
    (src/server.cpp:1656-1700, compressZstd level 0 = zstd's default 3);
  * the transport: packets up to 512 bytes (src/network/connection.cpp:13);
    a reliable packet carries base header 7 + reliable header 3 and either an
    ORIGINAL byte or, above 502 bytes, is split into chunks with a 7-byte
    SPLIT header (src/network/mtp/impl.cpp:92-125, 1081-1083); plus 28 bytes
    IPv4+UDP per datagram.

Measured (headless, this machine, no client connected; probe in
particle_cost_probe): the Lua call of add_particlespawner incl. building
its table 1.88 us (2.26 us with an attractor), add_particle 0.60 us.
Measured here: zstd level 3 compression time of the actual particle batches
(libzstd through ctypes, context reused like the engine's).
Estimated (no client in a headless run): the per-receiver serialization and
queueing of a spawner packet (~3 us) and of one particle record (~0.3 us).
"""
import ctypes
import json
import struct
import sys
import time

MAX_PACKET = 512
BASE, RELIABLE, SPLIT_HDR, ORIGINAL_HDR, IP_UDP = 7, 3, 7, 1, 28
CHUNK_MAX = MAX_PACKET - BASE - RELIABLE  # 502

LUA_SPAWNER_US = 1.88
LUA_SPAWNER_ATTRACT_US = 2.26
LUA_PARTICLE_US = 0.60
EST_SPAWNER_SEND_US = 3.0      # estimate, per receiver
EST_PARTICLE_SERIALIZE_US = 0.3  # estimate, per particle per receiver
EST_DISTANCE_CHECK_US = 0.01     # estimate, per queued particle per player


def wire_bytes(data_len):
    """Datagram bytes on the wire for one reliable packet of `data_len` bytes."""
    if data_len + ORIGINAL_HDR <= CHUNK_MAX:
        return BASE + RELIABLE + ORIGINAL_HDR + data_len + IP_UDP, 1
    per = CHUNK_MAX - SPLIT_HDR
    chunks = -(-data_len // per)
    return data_len + chunks * (BASE + RELIABLE + SPLIT_HDR + IP_UDP), chunks


def tween_ranged_v3f():
    return 1 + 2 + 4 + 2 * (12 + 12 + 4)  # style, reps, beginning, start/end ranges


def tween_ranged_f32():
    return 1 + 2 + 4 + 2 * (4 + 4 + 4)


def tween_v3f():
    return 1 + 2 + 4 + 12 + 12


def tween_f32():
    return 1 + 2 + 4 + 4 + 4


def tween_v2f():
    return 1 + 2 + 4 + 8 + 8


def anim_bytes(animated):
    return 1 + (8 if animated else 0)  # type, (w, h, length) for vertical frames


def spawner_packet(texture, attract=None, animated=False):
    """Bytes of TOCLIENT_ADD_PARTICLESPAWNER incl. the 2-byte command id."""
    n = 2  # command
    n += 2 + 4  # amount, time
    n += 3 * tween_ranged_v3f() + 2 * tween_ranged_f32()  # pos vel acc, exptime size
    n += 1  # collisiondetection
    n += 4 + len(texture)  # long string
    n += 4 + 1 + 1 + 2  # id, vertical, collision_removal, attached_id
    n += anim_bytes(animated)
    n += 1 + 1  # glow, object_collision
    n += 2 + 1 + 1  # node param0, param2, node_tile
    n += 1 + tween_f32() + tween_v2f() + (anim_bytes(animated) if animated else 0)  # texture props
    n += tween_ranged_v3f()  # drag
    n += tween_ranged_v3f()  # jitter
    n += tween_ranged_f32()  # bounce
    n += 1  # attractor kind
    if attract:
        n += tween_ranged_f32() + tween_v3f() + 2 + 1
        if attract != "point":
            n += tween_v3f() + 2
    n += tween_ranged_v3f()  # radius
    n += 2  # texpool count (0)
    return n


def sample_single(e, i, n, rng):
    """Position, velocity and acceleration of the i-th of n single particles
    of emitter `e`, as the Lua loop that adds them would compute them."""
    import math
    sh = e["spawn"]
    if sh[0] == "box":
        pos = [rng.uniform(sh[1][k], sh[2][k]) for k in range(3)]
        c = [(sh[1][k] + sh[2][k]) / 2 for k in range(3)]
    elif sh[0] == "disc":
        a = (2 * math.pi * i / n) if sh[3] else rng.uniform(0, 2 * math.pi)
        r = sh[2] if sh[3] else sh[2] * math.sqrt(rng.random())
        pos = [sh[1][0] + math.cos(a) * r, sh[1][1], sh[1][2] + math.sin(a) * r]
        c = sh[1]
    elif sh[0] == "sphere":
        while True:
            v = [rng.uniform(-1, 1) for _ in range(3)]
            l = math.sqrt(sum(x * x for x in v))
            if 0.05 < l <= 1:
                break
        r = sh[2] if sh[3] else sh[2] * rng.random() ** (1 / 3)
        pos = [sh[1][k] + v[k] / l * r for k in range(3)]
        c = sh[1]
    else:
        f = i / (n - 1) if n > 1 else 0.5
        pos = [sh[1][k] + (sh[2][k] - sh[1][k]) * f for k in range(3)]
        c = pos
    vel = [rng.uniform(e["vel"][0][k], e["vel"][1][k]) if e["vel"][0][k] != e["vel"][1][k]
           else e["vel"][0][k] for k in range(3)]
    if e.get("radial"):
        sp = rng.uniform(*e["radial"])
        d = [pos[k] - c[k] for k in range(3)]
        l = math.sqrt(sum(x * x for x in d)) or 1
        vel = [vel[k] + d[k] / l * sp for k in range(3)]
    # World coordinates: the effect happens somewhere in the world, not at 0.
    pos = [pos[0] + 1234.5, pos[1] + 18.0, pos[2] - 876.25]
    return pos, vel, e["acc"]


def particle_record(e, i, n, rng):
    """One ParticleParameters record as the engine writes it
    (particles.cpp:230-251), wrapped in serializeString32 for the batch."""
    pos, vel, acc = sample_single(e, i, n, rng)
    tex = e["texture"]
    out = struct.pack("<9f", *pos, *vel, *acc)
    out += struct.pack("<ff", rng.uniform(*e["exp"]), rng.uniform(*e["size"]))
    out += b"\0"  # collisiondetection
    out += struct.pack("<I", len(tex)) + tex.encode()
    out += b"\0\0"  # vertical, collision_removal
    out += b"\0"  # animation none
    out += bytes([e.get("glow", 0)]) + b"\0"  # glow, object_collision
    out += b"\0\0\0\0"  # node param0 (u16), param2, node_tile
    out += b"\0" * 12  # drag
    out += b"\0" * 28 + b"\0" * 12  # jitter (v3f range: min, max, bias), bounce (f32 range)
    out += b"\x00" + b"\0" * 15 + b"\0" * 23  # texture flags, alpha tween, scale tween
    return struct.pack("<I", len(out)) + out


class Zstd:
    def __init__(self):
        lib = ctypes.CDLL("libzstd.so.1")
        lib.ZSTD_createCCtx.restype = ctypes.c_void_p
        lib.ZSTD_compressCCtx.restype = ctypes.c_size_t
        lib.ZSTD_compressCCtx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t,
                                         ctypes.c_char_p, ctypes.c_size_t, ctypes.c_int]
        lib.ZSTD_compressBound.restype = ctypes.c_size_t
        self.lib, self.ctx = lib, lib.ZSTD_createCCtx()

    def compress(self, data):
        cap = self.lib.ZSTD_compressBound(len(data))
        buf = ctypes.create_string_buffer(cap)
        n = self.lib.ZSTD_compressCCtx(self.ctx, buf, cap, data, len(data), 3)
        return n

    def time_us(self, data, reps=2000):
        t = time.perf_counter()
        for _ in range(reps):
            self.compress(data)
        return (time.perf_counter() - t) / reps * 1e6


_Z = None


def batch(e, count, seed=0):
    """(packet data bytes, zstd microseconds, raw bytes) for `count` single
    particles of emitter `e` sent in one server step."""
    global _Z
    import random
    _Z = _Z or Zstd()
    rng = random.Random(seed * 7919 + count)
    raw = b"".join(particle_record(e, i, count, rng) for i in range(count))
    comp = _Z.compress(raw)
    return 2 + 4 + comp, _Z.time_us(raw, 300), len(raw)


def emitter_cost(e):
    """Per occurrence: receivers rule, bytes per receiver (wire), Lua us, per-receiver us."""
    tex = e["texture"]
    if e["kind"] == "spawner":
        short = (not e.get("attached")) and 0 < e["time"] <= 1.0
        data = spawner_packet(tex, e.get("attract"), e.get("animated", False))
        wire, dgrams = wire_bytes(data)
        lua = LUA_SPAWNER_ATTRACT_US if e.get("attract") else LUA_SPAWNER_US
        return {"kind": "spawner", "receivers": "near" if short else "all",
                "data": data, "wire": wire, "datagrams": dgrams,
                "lua_us": lua, "per_rx_us": EST_SPAWNER_SEND_US}
    # Single particles sent over several server steps (a trail) form one
    # batch per step and player.
    count, steps = e["n"], max(1, e.get("steps", 1))
    per = max(1, count // steps)
    data, z_us, raw = batch(e, per)
    wire, dgrams = wire_bytes(data)
    return {"kind": "single", "receivers": "near", "data": data * steps, "raw": raw * steps,
            "wire": wire * steps, "datagrams": dgrams * steps, "lua_us": LUA_PARTICLE_US * count,
            "per_rx_us": EST_PARTICLE_SERIALIZE_US * count + z_us * steps,
            "per_player_check_us": EST_DISTANCE_CHECK_US * count, "zstd_us": z_us * steps}


def effect_cost(emitters, scale=1.0):
    """Totals for one occurrence of an effect at grug_particle_scale `scale`
    (spawner amounts scale but not their packet; single particles scale)."""
    tot = {"near_wire": 0, "all_wire": 0, "lua_us": 0.0, "near_us": 0.0, "all_us": 0.0,
           "player_check_us": 0.0, "particles": 0, "spawners": 0, "singles": 0}
    for e in emitters:
        e2 = dict(e)
        if e["kind"] == "single":
            e2["n"] = max(1, int(e["n"] * scale + 0.5))
        c = emitter_cost(e2)
        key = "near" if c["receivers"] == "near" else "all"
        tot[key + "_wire"] += c["wire"]
        tot[key + "_us"] += c["per_rx_us"]
        tot["lua_us"] += c["lua_us"]
        tot["player_check_us"] += c.get("per_player_check_us", 0)
        if e["kind"] == "spawner":
            tot["spawners"] += 1
            tot["particles"] += max(1, int(e["n"] * scale + 0.5))
        else:
            tot["singles"] += e2["n"]
            tot["particles"] += e2["n"]
    return tot


if __name__ == "__main__":
    for att in (None, "point"):
        d = spawner_packet("default_item_smoke.png^[multiply:#ffe9a0", att)
        print("spawner", att, "data", d, "wire", wire_bytes(d))

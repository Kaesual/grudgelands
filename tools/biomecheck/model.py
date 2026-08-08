"""Biome-distribution model for a Luanti/grudgelands world.

Re-implements, per column:
  * mgv7 base terrain height (mapgen_v7.cpp baseTerrainLevelAtPoint)
  * BiomeGenOriginal heat/humidity INCLUDING the blend noises
    (mg_biome.cpp calcHeatAtPoint/calcHumidityAtPoint)
  * BiomeGenOriginal::calcBiomeFromNoise (cuboid filter + voronoi)
  * grug_mapgen's ocean mask (geometry.lua column_cap)

The mask geometry used to live in structures.lua; WP36 moved it to
`mods/MAPGEN/grug_mapgen/geometry.lua`, which both the main and the mapgen
Lua environment dofile. The numbers below were re-verified against it
(2026-08-08) and are unchanged by the move.
"""
import sys, csv, math
import numpy as np
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from noiselib import NP, fractal2d

WORLD_SEED_U64 = 1181064378178512398
def s32(v):
    v &= 0xFFFFFFFF
    return v - (1 << 32) if v >= (1 << 31) else v
SEED = s32(WORLD_SEED_U64)

WATER_LEVEL = 1

# ---- noise params (map_meta.txt of the world) ----
np_heat      = NP(50, 35, 1000, 5349, 3, 0.5)
np_humidity  = NP(50, 35, 1000, 842,  3, 0.5)
np_heat_bl   = NP(0,  4,  32,   13,   2, 1.0)
np_hum_bl    = NP(0,  4,  32,   90003, 2, 1.0)
np_tbase     = NP(14, 70, 600, 82341, 5, 0.6)
np_talt      = NP(10, 25, 600, 5934,  5, 0.6)
np_tpersist  = NP(0.6, 0.1, 2000, 539, 3, 0.6)
np_hselect   = NP(-8, 16, 500, 4213, 6, 0.7)
np_coast     = NP(75, 75, 300, 91744, 3, 0.55)

# ---- geometry (grug_core / grug_mapgen/geometry.lua) ----
X_HALF, Z_MIN, Z_MAX = 1500, 100, 1700
TAPER, INSET_MAX, SHORE_DROP, TAPER_RISE = 150, 150, 5, 119
SHELF_DEPTH, SHELF_WIDTH = 10, 60
SEAT_Z, CORE_X_HALF = 900, 300
FIELD_X, FIELD_Z_FRONT, FIELD_Z_BACK = 1150, 1000, 775
WAR_COAST_Z, COAST_BAND = 300, 150


def terrain_height(X, Z):
    hsel = np.clip(fractal2d(np_hselect, X, Z, SEED), 0.0, 1.0)
    persist = fractal2d(np_tpersist, X, Z, SEED)
    hb = fractal2d(np_tbase, X, Z, SEED, persist_override=persist)
    ha = fractal2d(np_talt,  X, Z, SEED, persist_override=persist)
    h = np.where(ha > hb, ha, hb * hsel + ha * (1.0 - hsel))
    return np.trunc(h).astype(np.int32)          # C float->s16 truncation


def continent_distance(X, Z):
    ax, az = np.abs(X), np.abs(Z)
    return np.minimum(np.minimum(X_HALF - ax, az - Z_MIN), Z_MAX - az)


def surface_cap(s):
    """Vectorised geometry.lua surface_cap; returns (cap, has_cap)."""
    cap = np.zeros(s.shape, dtype=np.float64)
    sea = s <= 0
    away = np.minimum(-s, SHELF_WIDTH)
    cap_sea = np.floor(WATER_LEVEL - SHORE_DROP - 1 - away / SHELF_WIDTH * SHELF_DEPTH)
    t = s / TAPER
    cap_land = np.floor(WATER_LEVEL - SHORE_DROP + t * t * TAPER_RISE)
    cap = np.where(sea, cap_sea, cap_land)
    return cap, s < TAPER


def column_cap(X, Z):
    d = continent_distance(X, Z).astype(np.float64)
    inset = np.clip(fractal2d(np_coast, X, Z, SEED).astype(np.float64), 0, INSET_MAX)
    far_sea = d <= -SHELF_WIDTH
    s = d - inset
    cap, has = surface_cap(s)
    # far out at sea: flat shelf, no noise lookup (same value as surface_cap(-60))
    flat = math.floor(WATER_LEVEL - SHORE_DROP - 1 - SHELF_DEPTH)
    cap = np.where(far_sea, flat, cap)
    has = np.where(far_sea, True, has)
    has = np.where(d >= TAPER + INSET_MAX, False, has)
    return cap.astype(np.int32), has


def zone_at(X, Z, Y):
    az = np.abs(Z)
    inland = (np.abs(X) <= X_HALF) & (az >= Z_MIN) & (az <= Z_MAX)
    dx = np.maximum(np.abs(X) - CORE_X_HALF, 0)
    dz = np.abs(az - SEAT_Z)
    fz = np.where(az < SEAT_Z, FIELD_Z_FRONT, FIELD_Z_BACK)
    n = np.sqrt((dx / FIELD_X) ** 2 + (dz / fz) ** 2)
    out = np.full(X.shape, "outer", dtype=object)
    out = np.where(n <= 0.55, "inner", out)
    out = np.where(n <= 0.30, "core", out)
    out = np.where((X_HALF - np.abs(X) <= COAST_BAND) | (Z_MAX - az <= COAST_BAND),
                   "coast", out)
    out = np.where(az <= WAR_COAST_Z, "war_coast", out)
    out = np.where(az <= Z_MIN, "strait", out)
    out = np.where(~inland, "ocean", out)
    return out


def load_biomes(path):
    rows = []
    with open(path) as f:
        for r in csv.DictReader(f):
            rows.append({k: (v if k in ("name", "node_top") else int(v))
                         for k, v in r.items()})
    return rows


def calc_biome(biomes, heat, hum, X, Z, Y):
    """Vectorised BiomeGenOriginal::calcBiomeFromNoise (vertical_blend ignored:
    only grug_ocean has it, blend=1, and it only affects y == 4 where both
    candidates are sand)."""
    best = np.full(X.shape, -1, dtype=np.int32)
    bestd = np.full(X.shape, np.inf, dtype=np.float64)
    for bi, b in enumerate(biomes):
        elig = ((Y >= b["y_min"]) & (Y <= b["y_max"]) &
                (X >= b["x_min"]) & (X <= b["x_max"]) &
                (Z >= b["z_min"]) & (Z <= b["z_max"]))
        if not elig.any():
            continue
        dh = heat - b["heat"]
        dm = hum - b["humidity"]
        d = dh.astype(np.float64) ** 2 + dm.astype(np.float64) ** 2
        take = elig & (d < bestd)
        bestd = np.where(take, d, bestd)
        best = np.where(take, bi, best)
    return best


def build(step=10, zsign=+1, biomes=None):
    xs = np.arange(-X_HALF, X_HALF + 1, step, dtype=np.int32)
    zs = np.arange(Z_MIN, Z_MAX + 1, step, dtype=np.int32) * zsign
    X, Z = np.meshgrid(xs, zs, indexing="xy")
    Xf, Zf = X.astype(np.float32), Z.astype(np.float32)
    heat = fractal2d(np_heat, Xf, Zf, SEED) + fractal2d(np_heat_bl, Xf, Zf, SEED)
    hum = fractal2d(np_humidity, Xf, Zf, SEED) + fractal2d(np_hum_bl, Xf, Zf, SEED)
    h = terrain_height(Xf, Zf)
    cap, has_cap = column_cap(X, Z)
    eff = np.where(has_cap, np.minimum(h, cap), h)
    land = eff > WATER_LEVEL
    bid = calc_biome(biomes, heat, hum, X, Z, h)
    return dict(X=X, Z=Z, xs=xs, zs=zs, heat=heat, hum=hum, h=h,
                cap=cap, has_cap=has_cap, eff=eff, land=land, bid=bid)

"""Faithful re-implementation of Luanti noise.cpp NoiseFractal2D (value noise).

noise.cpp:174-181  noise2d
noise.cpp:240-254  noise2d_value
noise.cpp:314-338  NoiseFractal2D
"""
import numpy as np

NOISE_MAGIC_X = 1619
NOISE_MAGIC_Y = 31337
NOISE_MAGIC_SEED = 1013


def noise2d(x, y, seed):
    """x, y: int arrays (int64 ok, wrapped to int32 like C int math). seed: python int."""
    # C: unsigned int n = (1619*x + 31337*y + 1013*seed) & 0x7fffffff
    # The multiplications/additions are 32-bit int (wrap); the mask makes it positive.
    n = (np.int64(NOISE_MAGIC_X) * x.astype(np.int64)
         + np.int64(NOISE_MAGIC_Y) * y.astype(np.int64)
         + np.int64(NOISE_MAGIC_SEED) * np.int64(seed))
    n = (n & 0xFFFFFFFF).astype(np.uint32)          # 32-bit wrap
    n = n & np.uint32(0x7FFFFFFF)
    n = (n >> np.uint32(13)) ^ n
    n64 = n.astype(np.uint64)
    t = (n64 * n64 % (1 << 32)) * np.uint64(60493) % (1 << 32)
    t = (t + np.uint64(19990303)) % (1 << 32)
    n64 = (n64 * t) % (1 << 32)
    n64 = (n64 + np.uint64(1376312589)) % (1 << 32)
    n = (n64 & np.uint64(0x7FFFFFFF)).astype(np.int32)
    return np.float32(1.0) - n.astype(np.float32) / np.float32(0x40000000)


def ease(t):
    # noise.h: t*t*t*(t*(6*t-15)+10)
    six = np.float32(6.0)
    return t * t * t * (t * (six * t - np.float32(15.0)) + np.float32(10.0))


def noise2d_value(x, y, seed, eased=True):
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    xl = (x - x0.astype(np.float32)).astype(np.float32)
    yl = (y - y0.astype(np.float32)).astype(np.float32)
    v00 = noise2d(x0, y0, seed)
    v10 = noise2d(x0 + 1, y0, seed)
    v01 = noise2d(x0, y0 + 1, seed)
    v11 = noise2d(x0 + 1, y0 + 1, seed)
    if eased:
        xl = ease(xl)
        yl = ease(yl)
    u = v00 + (v10 - v00) * xl
    v = v01 + (v11 - v01) * xl
    return u + (v - u) * yl


class NP:
    def __init__(self, offset, scale, spread, seed, octaves, persist,
                 lacunarity=2.0, eased=True, absvalue=False):
        self.offset = np.float32(offset)
        self.scale = np.float32(scale)
        self.spread = np.float32(spread)
        self.seed = int(seed)
        self.octaves = int(octaves)
        self.persist = np.float32(persist)
        self.lacunarity = np.float32(lacunarity)
        self.eased = eased
        self.absvalue = absvalue


def fractal2d(np_, x, z, world_seed, persist_override=None):
    """NoiseFractal2D(np, x, z, seed). x,z: float32 arrays of node coords."""
    a = np.zeros(x.shape, dtype=np.float32)
    f = np.float32(1.0)
    g = np.ones(x.shape, dtype=np.float32)
    xs = (x.astype(np.float32) / np_.spread).astype(np.float32)
    zs = (z.astype(np.float32) / np_.spread).astype(np.float32)
    seed = world_seed + np_.seed
    persist = np_.persist if persist_override is None else persist_override
    for i in range(np_.octaves):
        nv = noise2d_value((xs * f).astype(np.float32), (zs * f).astype(np.float32),
                           seed + i, np_.eased)
        if np_.absvalue:
            nv = np.abs(nv)
        a = a + g * nv
        f = np.float32(f * np_.lacunarity)
        g = (g * persist).astype(np.float32)
    return (np_.offset + a * np_.scale).astype(np.float32)

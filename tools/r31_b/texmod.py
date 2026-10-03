"""A small offline renderer for Luanti texture strings (Round 31 lane B).

Covers the parts the gear images use: file parts, `^` overlays, `(...)`
groups, and the modifiers [verticalframe, [multiply, [opacity, [colorize,
[hsl and [cracko (drawn as a simple crack pattern, only for completeness).
Each follows reference_projects/luanti/src/client/imagesource.cpp
(blit_pixel<false>, apply_multiplication, apply_colorize,
apply_hue_saturation, the [opacity and [verticalframe branches), so the
preview shows what the engine builds from the same string.
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TEXTURE_DIRS = sorted(ROOT.glob("mods/*/*/textures"))
_files = {}


def load_file(name):
    if name not in _files:
        for directory in TEXTURE_DIRS:
            path = directory / name
            if path.exists():
                _files[name] = np.array(Image.open(path).convert("RGBA"), dtype=np.int64)
                break
        else:
            raise FileNotFoundError(name)
    return _files[name].copy()


def split_top(text):
    """Split at '^' outside parentheses."""
    parts, depth, start = [], 0, 0
    for i, ch in enumerate(text):
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == "^" and depth == 0:
            parts.append(text[start:i])
            start = i + 1
    parts.append(text[start:])
    return parts


def upscale(img, shape):
    if img.shape[:2] == shape:
        return img
    pil = Image.fromarray(img.astype(np.uint8), "RGBA").resize((shape[1], shape[0]), Image.NEAREST)
    return np.array(pil, dtype=np.int64)


def blit(src, dst):
    """blit_pixel<false> over the whole image (sizes matched first)."""
    if src.shape[0] * src.shape[1] > dst.shape[0] * dst.shape[1]:
        dst = upscale(dst, src.shape[:2])
    else:
        src = upscale(src, dst.shape[:2])
    out = dst.copy()
    sa, da = src[..., 3], dst[..., 3]
    replace = (sa == 255) | ((da == 0) & (sa > 0))
    out[replace] = src[replace]
    mix = (sa > 0) & (sa < 255) & (da > 0)
    for c in range(3):
        blended = (dst[..., c] * (255 - sa) + src[..., c] * sa) // 255
        out[..., c] = np.where(mix, blended, out[..., c])
    semi = mix & (da < 255)
    new_a = da + (255 - da) * sa * sa // (255 * 255)
    out[..., 3] = np.where(semi, new_a, np.where(mix, 255, out[..., 3]))
    return out


def parse_color(text):
    text = text.lstrip("#")
    r, g, b = (int(text[i:i + 2], 16) for i in (0, 2, 4))
    a = int(text[6:8], 16) if len(text) == 8 else 255
    return r, g, b, a


def hsl_from_rgb(r, g, b):
    mx, mn = max(r, g, b), min(r, g, b)
    lum = (mx + mn) * 50
    if abs(mx - mn) < 1e-6:
        return 0.0, 0.0, lum
    d = mx - mn
    sat = (d / (mx + mn) if lum <= 50 else d / (2 - mx - mn)) * 100
    if abs(mx - r) < 1e-6:
        hue = (g - b) / d
    elif abs(mx - g) < 1e-6:
        hue = 2 + (b - r) / d
    else:
        hue = 4 + (r - g) / d
    hue *= 60
    while hue < 0:
        hue += 360
    return hue, sat, lum


def hsl_to_rgb(hue, sat, lum):
    l = lum / 100
    if abs(sat) < 1e-6:
        return l, l, l
    rm2 = l + l * (sat / 100) if lum <= 50 else l + (1 - l) * (sat / 100)
    rm1 = 2 * l - rm2
    h = hue / 360

    def one(rh):
        if rh < 0:
            rh += 1
        if rh > 1:
            rh -= 1
        if rh < 1 / 6:
            return rm1 + (rm2 - rm1) * rh * 6
        if rh < 0.5:
            return rm2
        if rh < 2 / 3:
            return rm1 + (rm2 - rm1) * (2 / 3 - rh) * 6
        return rm1
    return one(h + 1 / 3), one(h), one(h - 1 / 3)


def apply_hsl(img, hue, sat, light):
    norm_s = max(-100, min(1000, sat)) / 100
    norm_l = max(-100, min(100, light)) / 100
    out = img.copy()
    for y in range(img.shape[0]):
        for x in range(img.shape[1]):
            r, g, b, a = (v / 255 for v in img[y, x])
            h, s, l = hsl_from_rgb(r, g, b)
            l = l * (norm_l + 1) if norm_l < 0 else l + norm_l * (100 - l)
            s = max(0.0, min(100.0, s * (norm_s + 1)))
            h = math.fmod(h + hue, 360)
            if h < 0:
                h += 360
            rr, gg, bb = hsl_to_rgb(h, s, l)
            out[y, x] = [int(math.floor(v * 255 + 0.5)) for v in (rr, gg, bb, a)]
    return out


def apply_modifier(img, mod):
    name, _, rest = mod.partition(":")
    if name == "[verticalframe":
        count, index = (int(v) for v in rest.split(":"))
        h = img.shape[0] // count
        return img[index * h:(index + 1) * h].copy()
    if name == "[multiply":
        r, g, b, _ = parse_color(rest)
        out = img.copy()
        out[..., 0] = img[..., 0] * r // 255
        out[..., 1] = img[..., 1] * g // 255
        out[..., 2] = img[..., 2] * b // 255
        return out
    if name == "[opacity":
        ratio = int(rest)
        out = img.copy()
        out[..., 3] = np.floor(img[..., 3] * ratio // 255 + 0.5).astype(np.int64)
        return out
    if name == "[colorize":
        color, _, ratio = rest.partition(":")
        r, g, b, a = parse_color(color)
        d = (a if ratio == "" else int(ratio)) / 255
        out = img.copy()
        visible = img[..., 3] > 0
        for c, v in enumerate((r, g, b, a)):
            out[..., c] = np.where(visible, np.round(img[..., c] * (1 - d) + v * d), img[..., c])
        return out.astype(np.int64)
    if name == "[hsl":
        values = [int(v) for v in rest.split(":")] + [0, 0]
        return apply_hsl(img, values[0], values[1], values[2])
    if name == "[cracko":
        out = img.copy()
        h, w = img.shape[:2]
        for i in range(min(h, w)):
            x, y = (i * 5) % w, (i * 3 + w // 2) % h
            if out[y, x, 3] == 255:
                out[y, x, :3] = out[y, x, :3] // 3
        return out
    raise ValueError("unsupported modifier " + mod)


def render(text):
    base = None
    for part in split_top(text):
        if part.startswith("(") and part.endswith(")"):
            img = render(part[1:-1])
            base = img if base is None else blit(img, base)
        elif part.startswith("["):
            base = apply_modifier(base, part)
        else:
            img = load_file(part)
            base = img if base is None else blit(img, base)
    return base


def to_pil(img):
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")

#!/usr/bin/env python3
"""Round 48 lane HUD: the minimap's side-element images (round plan §4.1,
sell plan §3.6, mail plan §3.13 as changed by the round plan's coordinator
choices).

Composes finished images from the parts in tools/r48_hud/parts/ and writes
them into mods/PLAYER/grug_map/textures/:

  grug_map_daytime_00.png .. _39.png  the daytime band, 160 x 40 px each, one
      per position (one per 30 real seconds; minimap_view.lua
      daytime_position). One 20-minute cycle is 160 px: the day phase 120 px
      with the sun at its centre, the night 40 px with the moon at its
      centre. The image shows exactly one cycle with the "now" marker in the
      middle; the band moves right to left, so the coming phase enters from
      the right.
  grug_map_mail_1.png .. _9.png, grug_map_mail_9p.png  the mail icon with its
      unread badge, 60 x 52 px each (0 unread shows no icon at all). The
      badge's digits are the cooldown digits of
      tools/r40_cd/gen_cooldown_textures.py (read from their generated files,
      at half size), the "+" included.

Parts (tools/r48_hud/parts/; the art lane replaces them with its picks and
reruns this script, any 8-bit PNG):
  mail_icon.png   the envelope, at most 48 x 40, drawn at the top left
  sun.png         drawn centred on the day phase's centre (at most 40 px)
  moon.png        drawn centred on the night's centre (at most 40 px)
  frame.png       160 x 40 overlay drawn over the band, sun and moon
  marker.png      160 x 40 overlay drawn last (the "now" marker at x 80)
  palette.json    {"day": "#rrggbb", "night": "#rrggbb", "blend": px of the
                  dawn and dusk blends, "badge": "#rrggbb" or null for no
                  pill behind the digits, "badge_rim": "#rrggbb"}

Python 3 standard library only; the output is byte-for-byte deterministic.

  python3 tools/r48_hud/gen_hud_textures.py                 write the images
  python3 tools/r48_hud/gen_hud_textures.py --check         exit 1 if any differs
  python3 tools/r48_hud/gen_hud_textures.py --placeholders  (re)write the
      placeholder parts first (overwrites the parts; not for picked art)
"""
import json
import math
import struct
import sys
import zlib
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PARTS = Path(__file__).resolve().parent / "parts"
OUT = REPO / "mods/PLAYER/grug_map/textures"
DIGITS = REPO / "mods/PLAYER/grug_abilities/textures"
DIGIT = "grug_abilities_cd_digit_%s.png"
# The cooldown glyphs: 7 x 9 cells of 4 px, ADVANCE cells apart
# (grug_abilities/cooldown_math.lua GLYPH_*); drawn here at half size.
GLYPH_CELL, GLYPH_W, GLYPH_H, ADVANCE = 4, 7, 9, 6
HALF = 2

BAND_W, BAND_H = 160, 40  # minimap_view.lua V.SIDE band_w, band_h
POSITIONS, DAY_POSITIONS = 40, 30  # minimap_view.lua V.DAYTIME
STEP = BAND_W // POSITIONS  # 4 px per position
DAY_W = DAY_POSITIONS * STEP  # 120 px of day, 40 of night
SUN_U, MOON_U = DAY_W // 2, DAY_W + (BAND_W - DAY_W) // 2
MAIL_W, MAIL_H = 60, 52  # minimap_view.lua V.SIDE mail_w, mail_h
CLEAR = (0, 0, 0, 0)


# ---------------------------------------------------------------------------
# PNG in and out
# ---------------------------------------------------------------------------
def png(width, height, pixels):
    """pixels: rows of RGBA tuples. Filter 0 per row, fixed zlib level."""
    raw = bytearray()
    for row in pixels:
        raw.append(0)
        for px in row:
            raw.extend(px)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def read_png(path):
    """An 8-bit, non-interlaced PNG (grey, grey+alpha, RGB, RGBA or palette)
    as rows of RGBA tuples."""
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("not a PNG: %s" % path)
    at, idat, palette, trns = 8, bytearray(), None, None
    width = height = depth = kind = None
    while at < len(data):
        (length,) = struct.unpack(">I", data[at:at + 4])
        tag, body = data[at + 4:at + 8], data[at + 8:at + 8 + length]
        at += 12 + length
        if tag == b"IHDR":
            width, height, depth, kind, _, _, interlace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or interlace != 0:
                raise SystemExit("%s: only 8-bit, non-interlaced PNGs" % path)
        elif tag == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif tag == b"tRNS":
            trns = body
        elif tag == b"IDAT":
            idat.extend(body)
        elif tag == b"IEND":
            break
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[kind]
    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    rows, prev, pos = [], bytearray(stride), 0
    for _ in range(height):
        filt, line = raw[pos], bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if filt == 1:
                line[i] = (line[i] + a) & 255
            elif filt == 2:
                line[i] = (line[i] + b) & 255
            elif filt == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 255
        prev = line
        row = []
        for x in range(width):
            v = line[x * channels:(x + 1) * channels]
            if kind == 6:
                row.append(tuple(v))
            elif kind == 2:
                row.append((v[0], v[1], v[2], 255))
            elif kind == 0:
                row.append((v[0], v[0], v[0], 255))
            elif kind == 4:
                row.append((v[0], v[0], v[0], v[1]))
            else:
                alpha = trns[v[0]] if trns is not None and v[0] < len(trns) else 255
                row.append(palette[v[0]] + (alpha,))
        rows.append(row)
    return rows


# ---------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------
def over(dst, src):
    """src over dst, both straight-alpha RGBA, in integers."""
    sa = src[3]
    if sa == 0:
        return dst
    if sa == 255:
        return src
    da = dst[3]
    oa = sa * 255 + da * (255 - sa)  # x 255
    if oa == 0:
        return CLEAR
    rgb = tuple((s * sa * 255 + d * da * (255 - sa) + oa // 2) // oa
                for s, d in zip(src[:3], dst[:3]))
    return rgb + ((oa + 127) // 255,)


def paste(canvas, image, left, top):
    height, width = len(canvas), len(canvas[0])
    for y, row in enumerate(image):
        cy = top + y
        if 0 <= cy < height:
            for x, px in enumerate(row):
                cx = left + x
                if 0 <= cx < width:
                    canvas[cy][cx] = over(canvas[cy][cx], px)


def color(text):
    text = text.lstrip("#")
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(round(x + (y - x) * t)) for x, y in zip(a, b))


# ---------------------------------------------------------------------------
# The daytime band
# ---------------------------------------------------------------------------
def band_color(u, palette):
    """The band's colour at cycle pixel u (0 .. BAND_W): day from 0 to DAY_W,
    night after it, blended over `blend` px around dawn (u 0) and dusk
    (u DAY_W)."""
    day, night = color(palette["day"]), color(palette["night"])
    blend = max(1, int(palette.get("blend", 8)))
    centre = u % BAND_W + 0.5
    for edge, before, after in ((DAY_W, day, night), (BAND_W, night, day), (0, night, day)):
        if abs(centre - edge) < blend / 2:
            return mix(before, after, (centre - edge + blend / 2) / blend)
    return day if centre < DAY_W else night


def band_image(position, parts, palette):
    now = position * STEP + STEP // 2  # the cycle pixel under the marker
    middle = BAND_W // 2
    canvas = [[band_color(now + x - middle, palette) for x in range(BAND_W)]
              for _ in range(BAND_H)]
    for name, centre in (("sun", SUN_U), ("moon", MOON_U)):
        sprite = parts[name]
        x = (centre - now + middle) % BAND_W
        # A sprite at the edge shows on both sides: the window is one cycle.
        for at in (x - BAND_W, x, x + BAND_W):
            paste(canvas, sprite, at - len(sprite[0]) // 2, (BAND_H - len(sprite)) // 2)
    paste(canvas, parts["frame"], 0, 0)
    paste(canvas, parts["marker"], 0, 0)
    return canvas


# ---------------------------------------------------------------------------
# The mail icon and its badge
# ---------------------------------------------------------------------------
def glyph(char):
    """A cooldown digit at half size (one cell HALF px)."""
    full = read_png(DIGITS / (DIGIT % char))
    step = GLYPH_CELL // HALF
    return [row[::step] for row in full[::step]]


def pill(width, height, fill, rim):
    """A rounded badge: ends of radius height / 2, a one-pixel rim."""
    r = height / 2
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            cx = min(max(x + 0.5, r), width - r)
            d = math.hypot(x + 0.5 - cx, y + 0.5 - r)
            if d > r:
                row.append(CLEAR)
            elif d > r - 1.5 and rim is not None:
                row.append(rim)
            else:
                row.append(fill)
        rows.append(row)
    return rows


def mail_image(text, parts, palette):
    canvas = [[CLEAR] * MAIL_W for _ in range(MAIL_H)]
    paste(canvas, parts["mail_icon"], 0, 0)
    cell = HALF
    glyphs = [glyph(ch) for ch in text]
    text_w = ((len(text) - 1) * ADVANCE + GLYPH_W) * cell
    text_h = GLYPH_H * cell
    pad = 2
    h = text_h + 2 * pad
    w = max(h, text_w + 2 * pad)
    left, top = MAIL_W - w, MAIL_H - h
    if palette.get("badge"):
        rim = color(palette["badge_rim"]) if palette.get("badge_rim") else None
        paste(canvas, pill(w, h, color(palette["badge"]), rim), left, top)
    x = left + (w - text_w) // 2
    for g in glyphs:
        paste(canvas, g, x, top + pad)
        x += ADVANCE * cell
    return canvas


# ---------------------------------------------------------------------------
# Placeholder parts (until the art lane's picks replace them)
# ---------------------------------------------------------------------------
def disc(size, fill, outline, radius, inner=None):
    c = size / 2
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c)
            if inner and math.hypot(x + 0.5 - c - inner[0], y + 0.5 - c - inner[1]) < inner[2]:
                row.append(CLEAR)
            elif d <= radius - 1.5:
                row.append(fill)
            elif d <= radius:
                row.append(outline)
            else:
                row.append(CLEAR)
        rows.append(row)
    return rows


def placeholder_parts():
    ink = (42, 34, 24, 255)
    sun = disc(22, (255, 210, 64, 255), (176, 104, 24, 255), 9.5)
    moon = disc(18, (232, 232, 214, 255), (96, 100, 120, 255), 7.5, inner=(4, -3, 6))
    frame = [[CLEAR] * BAND_W for _ in range(BAND_H)]
    for y in range(BAND_H):
        for x in range(BAND_W):
            edge = min(x, y, BAND_W - 1 - x, BAND_H - 1 - y)
            if edge < 2:
                frame[y][x] = ink
            elif edge == 2:
                frame[y][x] = (138, 111, 69, 255)
    middle = BAND_W // 2
    marker = [[CLEAR] * BAND_W for _ in range(BAND_H)]
    for y in range(3, BAND_H - 3):
        for x in (middle - 2, middle + 1):
            marker[y][x] = ink
        for x in (middle - 1, middle):
            marker[y][x] = (255, 244, 214, 255)
    for k in range(4):  # small triangles pointing at the band, top and bottom
        for x in range(middle - 4 + k, middle + 4 - k):
            marker[3 + k][x] = (255, 244, 214, 255)
            marker[BAND_H - 4 - k][x] = (255, 244, 214, 255)
    envelope = [[CLEAR] * 48 for _ in range(40)]
    paper, seal = (239, 230, 207, 255), (143, 59, 43, 255)
    for y in range(40):
        for x in range(48):
            if 2 <= x <= 45 and 4 <= y <= 35:
                edge = min(x - 2, y - 4, 45 - x, 35 - y)
                envelope[y][x] = ink if edge < 2 else paper
    for x in range(4, 44):  # the flap: a V from the top corners to the middle
        y = 6 + abs(x + 0.5 - 24) * -16 / 20 + 16
        for dy in (-1, 0):
            envelope[int(y) + dy][x] = ink
    paste(envelope, disc(10, seal, (90, 30, 20, 255), 4.5), 19, 17)
    palette = {"day": "#6fb3df", "night": "#1f2a55", "blend": 8, "badge": "#b8322a",
               "badge_rim": "#ffffff"}
    return {"mail_icon": envelope, "sun": sun, "moon": moon, "frame": frame,
            "marker": marker}, palette


# ---------------------------------------------------------------------------
def load_parts():
    parts = {name: read_png(PARTS / (name + ".png"))
             for name in ("mail_icon", "sun", "moon", "frame", "marker")}
    palette = json.loads((PARTS / "palette.json").read_text())
    for name in ("frame", "marker"):
        if len(parts[name]) != BAND_H or len(parts[name][0]) != BAND_W:
            raise SystemExit("%s.png must be %d x %d" % (name, BAND_W, BAND_H))
    icon = parts["mail_icon"]
    if len(icon) > MAIL_H or len(icon[0]) > MAIL_W:
        raise SystemExit("mail_icon.png must fit %d x %d" % (MAIL_W, MAIL_H))
    return parts, palette


def files(parts, palette):
    out = {}
    for position in range(POSITIONS):
        out["grug_map_daytime_%02d.png" % position] = png(
            BAND_W, BAND_H, band_image(position, parts, palette))
    for count in range(1, 10):
        out["grug_map_mail_%d.png" % count] = png(MAIL_W, MAIL_H,
                                                   mail_image(str(count), parts, palette))
    out["grug_map_mail_9p.png"] = png(MAIL_W, MAIL_H, mail_image("9p", parts, palette))
    return out


def main():
    args = sys.argv[1:]
    check = "--check" in args
    if "--placeholders" in args:
        parts, palette = placeholder_parts()
        PARTS.mkdir(exist_ok=True)
        for name, image in parts.items():
            (PARTS / (name + ".png")).write_bytes(png(len(image[0]), len(image), image))
        (PARTS / "palette.json").write_text(json.dumps(palette, indent=2) + "\n")
        print("wrote the placeholder parts to %s" % PARTS)
    parts, palette = load_parts()
    produced = files(parts, palette)
    bad = 0
    for name, data in sorted(produced.items()):
        path = OUT / name
        if check:
            if not path.exists() or path.read_bytes() != data:
                print("differs: %s" % path)
                bad += 1
        else:
            path.write_bytes(data)
    # No stale image of an older set.
    for pattern in ("grug_map_daytime_*.png", "grug_map_mail_*.png"):
        for path in sorted(OUT.glob(pattern)):
            if path.name not in produced:
                if check:
                    print("not generated: %s" % path)
                    bad += 1
                else:
                    path.unlink()
    if check:
        print("gen_hud_textures --check: %s" % ("FAIL" if bad else "PASS"))
        return 1 if bad else 0
    print("wrote %d files to %s" % (len(produced), OUT))
    return 0


if __name__ == "__main__":
    sys.exit(main())

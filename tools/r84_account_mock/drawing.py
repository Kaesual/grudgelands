"""Render inventory elements and collect their body-local builder coordinates."""
import colorsys
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
MODS = HERE.parents[1] / "mods"
UNIT, HEADER, WIDTH, HEIGHT = 64, 1.5, 20, 15
TEXT, MUTED, GOLD = "#eeeae1", "#b8bdb4", "#d4b77d"
RULE, ERROR, INK = "#d1c09a47", "#efafa2", "#243235"
URL = "https://grudgelands.com/play"
CHARACTER, ACCOUNT = "Tarnwick", "Fenlark"
EXAMPLE = "V7KMP-4TR9A"
CREST = "grug_creation_crest.png"
VILLAGE = "grug_creation_human.png"
FACTION = "grug_inventory_faction_accord.png"
TEXTURES = {p.name: p for folder in (
    "CORE/grug_core", "PLAYER/grug_classes", "PLAYER/grug_inventory",
    "PLAYER/grug_achievements", "PLAYER/grug_quickbar",
) for p in (MODS / folder / "textures").glob("*.png")}
REWARDS = {
    "cheer": ("Cheer", "Emote", "Play from the quickbar (E).", "grug_quickbar_emote_cheer.png"),
}
for reward in ("emberwake", "pearlwing", "moonfall"):
    REWARDS[reward] = (
        reward.title(), "Cloak", "Choose on the Character page.",
        "[combine:32x32:8,0=grug_achievements_cloak_" + reward + ".png\\^[sheet\\:2x1\\:0,0",
    )


@lru_cache(None)
def texture(name):
    if name == "grug_ui_danger.png^[hsl:105:0:0":
        plate = texture("grug_ui_danger.png").copy()
        def green(pixel):
            r, g, b, a = pixel
            h, l, s = colorsys.rgb_to_hls(r/255, g/255, b/255)
            rgb = colorsys.hls_to_rgb((h+105/360) % 1, l, s)
            return tuple(round(c*255) for c in rgb) + (a,)
        for y in range(plate.height):
            for x in range(plate.width):
                plate.putpixel((x, y), green(plate.getpixel((x, y))))
        return plate
    return Image.open(TEXTURES[name]).convert("RGBA")


@lru_cache(None)
def nine_slice(name, w, h):
    # The shared theme uses bgimg_middle=6 on 32 px square plates.
    src = texture(name)
    out = Image.new("RGBA", (w, h))
    for i, (x, right) in enumerate(zip((0, 6, w-6), (6, w-6, w))):
        for j, (y, bottom) in enumerate(zip((0, 6, h-6), (6, h-6, h))):
            tile = src.crop(((0, 6, 26)[i], (0, 6, 26)[j], (6, 26, 32)[i], (6, 26, 32)[j]))
            out.paste(tile.resize((right-x, bottom-y), Image.Resampling.NEAREST), (x, y))
    return out


class Drawing:
    def __init__(self, fonts):
        self.fonts = fonts
        self.image = Image.new("RGBA", (UNIT * WIDTH, UNIT * HEIGHT), "#222b2f")
        self.elements = []
        self.actions = []
        self.status = None
        self.offset = 0
        self.plate(0, 0, WIDTH, HEIGHT, "window")
        self.header()
        self.elements.clear()  # navigation is owned by the shared window
        self.offset = HEADER

    def record(self, kind, x, y, w, h, detail):
        if not (x >= -0.001 and y >= -0.001 and x+w <= WIDTH+0.001 and
                self.offset+y+h <= HEIGHT+0.001):
            raise ValueError(f"Outside form: {kind}, {detail}, {x,y,w,h}")
        self.elements.append([kind, *[round(v, 3) for v in (x, y, w, h)], detail])

    def rect(self, x, y, w, h):
        return (round(x*UNIT), round((y+self.offset)*UNIT),
                round((x+w)*UNIT), round((y+self.offset+h)*UNIT))

    def box(self, x, y, w, h, color):
        self.record("box", x, y, w, h, color)
        left, top, right, bottom = self.rect(x, y, w, h)
        tile = Image.new("RGBA", (max(1, right-left), max(1, bottom-top)),
                         ImageColor.getcolor(color, "RGBA"))
        self.image.alpha_composite(tile, (left, top))

    def plate(self, x, y, w, h, role):
        name = "grug_ui_" + role + ".png"
        self.record("background9", x, y, w, h, name + " · middle 6")
        left, top, right, bottom = self.rect(x, y, w, h)
        self.image.alpha_composite(nine_slice(name, right-left, bottom-top), (left, top))

    def art(self, x, y, w, h, name, pixels=None, smooth=False):
        self.record("image", x, y, w, h, name)
        src = pixels if pixels is not None else texture(name)
        left, top, right, bottom = self.rect(x, y, w, h)
        filt = Image.Resampling.LANCZOS if smooth else Image.Resampling.NEAREST
        self.image.alpha_composite(src.resize((right-left, bottom-top), filt), (left, top))

    def text(self, x, y, value, size=1, color=TEXT, bold=False, align="left", limit=None):
        # A real-coordinate label's y is its midline. x is left-aligned in game.
        font = self.fonts[bold, round(21 * size)]
        width = font.getlength(value) / UNIT
        if limit is not None and width > limit:
            raise ValueError(f"{value!r} needs {width:.2f} units, has {limit:.2f}")
        left = x-width/2 if align == "center" else x
        self.record("label", left, y, width, 0, f"{value} · ×{size:g} {color}" + (" bold" if bold else ""))
        ImageDraw.Draw(self.image).text((round(left*UNIT), round((self.offset+y)*UNIT)),
                                       value, fill=color, font=font, anchor="lm")

    def hit(self, role, label, x, y, w, h, value=""):
        self.actions.append(dict(role=role, label=label, x=x, y=y+self.offset, w=w, h=h, value=value))

    def button(self, x, y, w, h, label, action, role="button"):
        kind = "button_url" if action == "website" else "button"
        tone = {"selected": "#e6ca8d", "danger": "#e0aca0", "confirm": "#b4dca4"}.get(role, TEXT)
        name = "grug_ui_danger.png^[hsl:105:0:0" if role == "confirm" else "grug_ui_"+role+".png"
        left, top, right, bottom = self.rect(x, y, w, h)
        self.image.alpha_composite(nine_slice(name, right-left, bottom-top), (left, top))
        self.text(x+w/2, y+h/2, label, 1.04, tone, align="center", limit=w-0.18)
        self.elements.pop()  # the native button owns its caption
        self.record(kind, x, y, w, h, f"{label} · {role}" + (" · " + URL if kind == "button_url" else ""))
        self.hit(action, label, x, y, w, h)

    def field(self, x, y, w, h, value):
        self.box(x, y, w, h, "#829c9655")
        self.box(x+.015, y+.015, w-.03, h-.03, INK)
        if value:
            self.text(x+.17, y+h/2, value)
            self.elements.pop()  # field value
        self.record("field", x, y, w, h, "Link code · borderless · field_close_on_enter=false")
        self.hit("code", "Link code", x, y, w, h, value)

    def status_line(self, x, y, w, message):
        self.status = [x, y, w]
        words = message.split()
        line = ""
        for word in words:
            candidate = (line + " " + word).strip()
            if self.fonts[False, 21].getlength(candidate) > w*UNIT:
                self.text(x, y, line, color=ERROR, limit=w)
                y += .48
                line = word
            else:
                line = candidate
        if line:
            self.text(x, y, line, color=ERROR, limit=w)

    def header(self):
        self.art(.28, .17, .46, .55, FACTION)
        self.text(.95, .28, "GRUDGELANDS", 1.1)
        self.text(.95, .62, "THE ACCORD", .65, GOLD)
        self.text(15.9, .27, CHARACTER, .85)
        self.text(15.9, .61, "Level 18", .65, "#a9aea4")
        self.text(19.475, .39, "×", 1.1, align="center")
        self.box(.25, .8, 19.5, .015, "#d1c09a2b")
        tabs = ("Inventory", "Character", "Talents", "Crafting", "Social", "Map & Quests", "Help", "Account")
        weight = sum(len(label)+3.5 for label in tabs)
        x, available = .25, 19.5-.05*(len(tabs)-1)
        for label in tabs:
            w = available*(len(label)+3.5)/weight
            active = label == "Account"
            self.text(x+w/2, 1.12, label, 1.1, GOLD if active else "#a9aea4", align="center")
            if active:
                self.box(x, 1.36, w, .035, GOLD)
            x += w+.05


class Fonts:
    def __init__(self, directory):
        self.directory = directory

    @lru_cache(None)
    def __getitem__(self, key):
        bold, size = key
        return ImageFont.truetype(str(self.directory / ("Arimo-Bold.ttf" if bold else "Arimo-Regular.ttf")), size)


def reward(d, key, x, y, icon_size, width, owned=False):
    name, kind, hint, icon = REWARDS[key]
    d.box(x, y, icon_size, icon_size, "#a995674b")
    d.box(x+.025, y+.025, icon_size-.05, icon_size-.05, "#263034")
    pixels = None
    if kind == "Cloak":
        src = texture(f"grug_achievements_cloak_{key}.png")
        pixels = Image.new("RGBA", (32, 32))
        pixels.paste(src.crop((0, 0, src.width//2, src.height)), (8, 0))
    d.art(x+.08, y+.08, icon_size-.16, icon_size-.16, icon, pixels)
    start = x+icon_size+.25
    d.text(start, y+icon_size*.32, name, 1.15, bold=True, limit=width-icon_size-.25)
    d.text(start, y+icon_size*.72, kind, .95, MUTED)
    if owned:
        d.text(start, y+icon_size+.19, hint, .98, MUTED, limit=width-icon_size-.25)
    d.record("tooltip", x, y, width, icon_size, f"{name} · {kind}. {hint}")
    d.hit("tip", f"{name} · {kind}. {hint}", x, y, width, icon_size)

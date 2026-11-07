#!/usr/bin/env python3
"""Draw four rough Expedition proposals. Python 3 and Pillow; no game data writes.

Run from any directory. --check compares the committed images with the drawings
without writing. Shapes express a route, never measured template geometry.
"""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "docs/planning/round71-outline"
SIZE = (1100, 740)
PAPER = "#F8F4EA"
ROCK = "#E9E2D4"
ROOM = "#FFFCF5"
INK = "#303F43"
MUTED = "#6B746F"
ROUTE = "#367C70"
GOLD = "#B78A3F"
RED = "#B75843"
BLUE = "#577D9A"
PALE_BLUE = "#DDE9EF"
PALE_RED = "#F1DBD1"
FONTS = {size: ImageFont.load_default(size=size) for size in (15, 17, 19, 22, 32)}


class Sketch:
    def __init__(self, title, subtitle):
        self.image = Image.new("RGB", SIZE, PAPER)
        self.draw = ImageDraw.Draw(self.image)
        self.text((38, 22), title, 32)
        self.text((40, 68), subtitle, 17, MUTED)
        self.draw.line((40, 101, 1060, 101), fill=INK, width=2)
        self.draw.polygon(
            [(49, 128), (1037, 119), (1060, 151), (1053, 509),
             (1024, 536), (60, 529), (39, 492), (43, 159)],
            fill=ROCK,
        )
        self.draw.line(
            [(49, 128), (1037, 119), (1060, 151), (1053, 509),
             (1024, 536), (60, 529), (39, 492), (43, 159), (49, 128)],
            fill=MUTED, width=2,
        )

    def text(self, xy, value, size=19, colour=INK, anchor=None):
        self.draw.multiline_text(
            xy, value, font=FONTS[size], fill=colour, spacing=5, anchor=anchor,
            align="center" if anchor else "left",
        )

    def room(self, box, fill=ROOM):
        x0, y0, x1, y1 = box
        points = [(x0 + 12, y0), (x1 - 8, y0 + 3), (x1, y0 + 15),
                  (x1 - 3, y1 - 8), (x1 - 18, y1), (x0 + 4, y1 - 4),
                  (x0, y0 + 17)]
        self.draw.polygon(points, fill=fill)
        self.draw.line(points + [points[0]], fill=INK, width=3)

    def corridor(self, points, width=24):
        self.draw.line(points, fill=INK, width=width + 5, joint="curve")
        self.draw.line(points, fill=ROOM, width=width, joint="curve")

    def line(self, points, colour=ROUTE, width=3, dashed=False):
        if not dashed:
            self.draw.line(points, fill=colour, width=width, joint="curve")
            return
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            length = math.hypot(x1 - x0, y1 - y0)
            for distance in range(0, int(length), 15):
                a = distance / length
                b = min(distance + 8, length) / length
                self.draw.line(
                    (x0 + (x1 - x0) * a, y0 + (y1 - y0) * a,
                     x0 + (x1 - x0) * b, y0 + (y1 - y0) * b),
                    fill=colour, width=width,
                )

    def arrow(self, points, colour=ROUTE, dashed=False):
        self.line(points, colour, dashed=dashed)
        x, y = points[-1]
        px, py = points[-2]
        angle = math.atan2(y - py, x - px)
        head = [(x, y)] + [
            (x - 12 * math.cos(angle + turn), y - 12 * math.sin(angle + turn))
            for turn in (-0.5, 0.5)
        ]
        self.draw.polygon(head, fill=colour)

    def label(self, xy, number, title):
        x, y = xy
        self.draw.ellipse((x - 13, y - 13, x + 13, y + 13), fill=INK)
        self.text((x, y), str(number), 17, ROOM, "mm")
        self.text((x + 22, y - 10), title, 17)

    def ore(self, xy):
        x, y = xy
        self.draw.polygon([(x, y - 9), (x + 8, y), (x, y + 9), (x - 8, y)],
                          fill=GOLD, outline=INK)

    def crystal(self, xy, colour=BLUE, size=21):
        x, y = xy
        points = [(x, y - size), (x + size, y - 4), (x + size // 2, y + size),
                  (x - size // 2, y + size), (x - size, y - 4)]
        self.draw.polygon(points, fill=colour, outline=INK)
        self.line([(x, y - size), (x - 3, y + 3), (x + size // 2, y + size)],
                  ROOM, 2)

    def cart(self, xy):
        x, y = xy
        self.draw.rectangle((x - 15, y - 12, x + 15, y + 12), fill=GOLD, outline=INK, width=2)
        self.line([(x - 20, y - 23), (x - 20, y + 23)], INK, 6)
        for dx in (-9, 9):
            for dy in (-16, 16):
                self.draw.ellipse((x + dx - 3, y + dy - 3, x + dx + 3, y + dy + 3), fill=INK)

    def footer(self, headline, explanation, view="ROUGH TOP VIEW"):
        self.text((42, 555), headline, 22)
        self.text((42, 591), explanation, 17, MUTED)
        self.draw.line((42, 642, 1058, 642), fill=MUTED, width=1)
        self.arrow([(45, 665), (85, 665)])
        self.text((95, 654), "route 0 > 1 > 2 > 3 > 4 > 5", 15)
        self.ore((430, 665))
        self.text((447, 654), "mining area, not a node count", 15)
        self.text((1058, 665), view, 15, MUTED, "rm")
        self.text((42, 704), "Sealed 128 x 64 x 128 envelope. Shapes only: no scale, coordinates or spawn placements.", 15, MUTED)
        return self.image


def bulwark():
    s = Sketch("30 / The Borrowed Bulwark", "3 players  |  one floor  |  a shelter you move with the fight")
    for path in ([(146, 420), (146, 245)], [(236, 235), (425, 235)],
                 [(425, 409), (649, 409)], [(700, 412), (902, 412)],
                 [(914, 299), (914, 162)]):
        s.corridor(path)
    for box in ((70, 365, 263, 492), (70, 162, 282, 304), (345, 170, 511, 465),
                (559, 348, 749, 492), (794, 239, 1028, 496), (794, 136, 1028, 207)):
        s.room(box)
    s.arrow([(149, 403), (149, 283)])
    s.arrow([(240, 248), (417, 248)])
    s.arrow([(478, 278), (478, 420), (613, 420)])
    s.arrow([(691, 423), (908, 423), (908, 345)])
    s.arrow([(914, 290), (914, 208)])
    s.line([(230, 270), (430, 270), (430, 448), (968, 448), (968, 350)], GOLD, 4, True)
    s.cart((430, 352))
    s.draw.rectangle((351, 321, 365, 380), fill=RED)
    for y in (332, 352, 372):
        s.arrow([(371, y), (400, y)], RED)
    s.cart((967, 399))
    s.draw.rectangle((801, 380, 815, 427), fill=RED)
    s.label((92, 387), 0, "Arrival")
    s.text((94, 451), "start waystone", 15, MUTED)
    s.label((92, 187), 1, "Loading yard")
    s.label((365, 198), 2, "Duct\npassage")
    s.label((581, 373), 3, "Sorting bays")
    s.label((815, 265), 4, "Foreman's floor")
    s.text((818, 307), "Merrit Lockjaw", 19, RED)
    s.label((815, 161), 5, "Store / exit")
    s.ore((257, 284))
    s.ore((726, 470))
    s.ore((1002, 183))
    return s.footer("Read the duct. Move the screen. Shelter, then fight.",
                    "Cart shown twice. Gold dashes: rails. Screens block duct blasts; ordinary arrows keep their rules.")


def assay():
    s = Sketch("40 / The Hanging Assay", "4 players  |  height proposal  |  two bodies, one life")
    s.corridor([(145, 429), (430, 429), (596, 247), (795, 247), (956, 202)], 25)
    for box in ((66, 381, 192, 485), (216, 365, 356, 485), (378, 354, 513, 485),
                (549, 160, 714, 288), (744, 145, 923, 491), (948, 145, 1035, 267)):
        s.room(box, PALE_BLUE if box[0] == 744 else ROOM)
    s.arrow([(117, 445), (278, 445), (437, 445)])
    s.arrow([(457, 399), (587, 260)])
    s.arrow([(659, 246), (772, 246)])
    s.arrow([(885, 212), (968, 212)])
    # Two fixed landings and a ramp inside the final chamber, viewed from the side.
    s.line([(752, 270), (914, 270)], INK, 7)
    s.line([(752, 449), (914, 449)], INK, 7)
    s.line([(757, 443), (904, 278)], MUTED, 6)
    s.line([(840, 226), (854, 317), (837, 415)], BLUE, 12)
    s.crystal((840, 243), BLUE)
    s.crystal((837, 422), RED)
    s.label((82, 400), 0, "Arrival")
    s.label((234, 390), 1, "Samples")
    s.label((396, 381), 2, "Lower cut")
    s.label((568, 184), 3, "Gallery")
    s.label((767, 169), 4, "Assay well")
    s.label((969, 167), 5, "Store")
    s.text((965, 237), "exit", 15, MUTED)
    s.text((402, 300), "wide fixed\nramp", 17, MUTED)
    s.text((837, 516), "Glassvein: one shared life", 15, BLUE, "mm")
    s.ore((335, 465))
    s.ore((691, 269))
    s.ore((1014, 243))
    return s.footer("Stay together and move, or split between the two faces.",
                    "Blue and rust show the alternating armour. Both bodies stay within melee reach of their landing.",
                    "ROUGH SIDE VIEW")


def second_shift():
    s = Sketch("50 / The Second Shift", "4 players  |  one floor  |  the danger is where you were")
    for path in ([(159, 416), (159, 240)], [(250, 229), (427, 229)],
                 [(427, 229), (427, 419)], [(468, 419), (825, 419)],
                 [(930, 309), (986, 189)]):
        s.corridor(path)
    for box in ((73, 359, 287, 491), (73, 158, 287, 291), (333, 157, 536, 292),
                (333, 355, 555, 494), (607, 241, 1020, 503), (820, 135, 1024, 201)):
        s.room(box)
    s.arrow([(158, 402), (158, 284)])
    s.arrow([(249, 237), (395, 237)])
    s.arrow([(434, 267), (434, 411)])
    s.arrow([(501, 432), (683, 432)])
    s.arrow([(981, 312), (981, 202)])
    s.label((94, 383), 0, "Arrival")
    s.label((94, 182), 1, "Timekeeper")
    s.label((355, 183), 2, "Marking floor")
    s.label((355, 382), 3, "Wage room")
    s.label((632, 266), 4, "Audit court")
    s.label((842, 161), 5, "Store / exit")
    s.text((786, 303), "Auditor Nemm", 19, RED)
    for x, y in ((703, 346), (751, 383), (702, 422), (767, 456)):
        s.draw.ellipse((x - 18, y - 18, x + 18, y + 18), fill=PALE_RED, outline=RED, width=2)
        s.line([(x - 6, y - 6), (x + 6, y + 6)], RED, 2)
        s.line([(x + 6, y - 6), (x - 6, y + 6)], RED, 2)
    s.arrow([(793, 397), (875, 397)])
    s.draw.ellipse((878, 368, 956, 448), outline=ROUTE, width=2)
    s.text((917, 408), "clear", 17, ROUTE, "mm")
    s.text((644, 473), "old positions", 15, RED)
    s.ore((263, 273))
    s.ore((526, 471))
    s.ore((999, 181))
    return s.footer("Record once. Strike twice. Leave the old marks behind.",
                    "The four marks illustrate one party's choice, not fixed danger tiles. The next clear patch is yours to choose.")


def mint():
    s = Sketch("60 / The Last Mint", "4 players  |  height + short jumping proposal  |  turn the press against its guardian")
    for path in ([(155, 420), (155, 240)], [(243, 235), (410, 235)],
                 [(454, 239), (578, 239)], [(598, 321), (818, 421)],
                 [(918, 302), (975, 180)]):
        s.corridor(path)
    for box in ((70, 359, 284, 493), (70, 157, 284, 291), (325, 156, 487, 293),
                (527, 147, 720, 338), (739, 257, 1031, 508), (807, 135, 1035, 207)):
        s.room(box)
    s.arrow([(154, 398), (154, 283)])
    s.arrow([(247, 245), (398, 245)])
    s.arrow([(455, 245), (556, 245)])
    s.arrow([(648, 326), (767, 389)])
    s.arrow([(982, 312), (982, 207)])
    s.label((92, 383), 0, "Arrival")
    s.label((92, 182), 1, "Salvage bins")
    s.label((345, 182), 2, "Furnace walk")
    s.label((546, 174), 3, "Gantry")
    s.label((760, 281), 4, "Press floor")
    s.label((830, 161), 5, "Store / exit")
    # A side-view inset: broad jumps above a dry walking ledge, not lava.
    for x0, x1 in ((542, 587), (600, 647), (660, 707)):
        s.line([(x0, 239), (x1, 239)], INK, 7)
    for x in (586, 646):
        s.draw.arc((x - 5, 206, x + 22, 241), 185, 355, fill=ROUTE, width=3)
    s.line([(544, 254), (544, 282), (699, 282), (699, 254)], MUTED, 4)
    s.text((550, 303), "dry ledge / stairs", 15, MUTED)
    s.text((533, 358), "side view", 15, MUTED)
    s.text((784, 315), "Duewarden", 19, RED)
    s.draw.rectangle((861, 359, 907, 406), fill=INK)
    s.text((884, 382), "press", 15, ROOM, "mm")
    for x, y in ((769, 440), (880, 477), (1001, 438)):
        s.line([(884, 389), (x, y)], RED, 3, True)
        s.draw.rectangle((x - 9, y - 9, x + 9, y + 9), fill=GOLD, outline=INK, width=2)
    s.text((787, 451), "3 clamps", 15)
    s.ore((261, 273))
    s.ore((464, 272))
    s.ore((1007, 182))
    return s.footer("Bait the line. Wait for the aim to lock. Step out and break a clamp.",
                    "Only marked clamps break. The boss floor stays whole; the gantry's dry lower route also serves the walk back.")


DRAWINGS = (
    ("level30-borrowed-bulwark.png", bulwark),
    ("level40-hanging-assay.png", assay),
    ("level50-second-shift.png", second_shift),
    ("level60-last-mint.png", mint),
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed images without writing")
    args = parser.parse_args()
    if not args.check:
        OUTPUT.mkdir(parents=True, exist_ok=True)
    failures = []
    for filename, render in DRAWINGS:
        target = OUTPUT / filename
        expected = render()
        if args.check:
            if not target.is_file():
                failures.append(f"Missing: {target.relative_to(ROOT)}")
                continue
            with Image.open(target) as actual:
                if actual.size != expected.size or ImageChops.difference(
                    actual.convert("RGB"), expected
                ).getbbox():
                    failures.append(f"Stale: {target.relative_to(ROOT)}")
        else:
            expected.save(target, optimize=True)
            print(target.relative_to(ROOT))
    if failures:
        parser.exit(1, "\n".join(failures) + "\n")
    if args.check:
        print("All four committed sketches match the generator.")


if __name__ == "__main__":
    main()

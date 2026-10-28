#!/usr/bin/env python3
"""Round 66 lane MAIL: do the mailbox window's five tab captions fit?

   python3 tools/r66_mail/caption_widths.py [LUANTI_SOURCE]

For a few screen profiles this reproduces the engine's form fitting
(guiFormSpecMenu.cpp calculateImgsize / getImgsize, clientdynamicinfo.cpp
calculateMaxFSSize) with the game's Full-HD viewport cap
(grug_core/ui_window.lua window_padding, window_information) and text scale
(grug_core/ui.lua text_scale), then measures each tab caption in the
engine's default font (fonts/Arimo-Regular.ttf of LUANTI_SOURCE, default
reference_projects/luanti) at the tab's size (16 px x 1.1 x text scale x
GUI scaling x density, fontengine.cpp) against the tab button's width in
pixels. Before (0.65.0): four tabs of equal width; now: five tabs sharing
the bar by caption weight (window.lua TABS: length + 3.5, plus room for
" (99)" on a counted caption). Prints one line per profile: imgsize, text
scale, font pixels and, before and now, the caption with the largest share
of its own button. A share at or below 100 % fits; exits 1 otherwise.
"""
import math
import os
import sys

from PIL import ImageFont

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LUANTI = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "reference_projects", "luanti")
FONT = os.path.join(LUANTI, "fonts", "Arimo-Regular.ttf")

FORM_W, FORM_H = 20, 13.5 + 0.95      # the mailbox window (window.lua frame)
WINDOW_H = 13.5 + 1.5                 # grug_inventory UI.window_h (text_scale)
CAP_W, CAP_H = 1920, 1080             # ui_window.lua
# caption, base caption, counted (window.lua TABS)
TABS = [("Letters (99)", "Letters", True), ("Sent", "Sent", False),
        ("Announcements (99)", "Announcements", True), ("Write", "Write", False),
        ("To the admin", "To the admin", False)]


def tab_widths(tabs):
    """Button widths in form units: before, equal quarters; now, weighted."""
    bar = FORM_W - 0.8
    if tabs == 4:
        return {caption: bar / 4 - 0.1 for caption, _, _ in TABS if caption != "Sent"}
    weights = {caption: len(base) + 3.5 + (5 if counted else 0) for caption, base, counted in TABS}
    total = sum(weights.values())
    return {caption: bar * weight / total - 0.1 for caption, weight in weights.items()}

# label, width, height, display density, GUI scaling
PROFILES = [
    ("1920x1080 desktop", 1920, 1080, 1.0, 1.0),
    ("1280x720 window", 1280, 720, 1.0, 1.0),
    ("1024x600 window", 1024, 600, 1.0, 1.0),
    ("800x600 window", 800, 600, 1.0, 1.0),
    ("2560x1440 desktop", 2560, 1440, 1.0, 1.0),
    ("3840x2160 desktop", 3840, 2160, 1.0, 1.0),
    ("1920x1080 GUI 1.5", 1920, 1080, 1.0, 1.5),
    ("1920x1080 GUI 2", 1920, 1080, 1.0, 2.0),
    ("phone 2400x1080 d2.5", 2400, 1080, 2.5, 1.0),
    ("phone 1600x720 d2", 1600, 720, 2.0, 1.0),
]


def get_imgsize(avail_w, avail_h, density, gui):
    fixed = 0.5555 * 96 * density * gui
    prefer = int(min(avail_w, avail_h)) // 15 * gui   # s32 / 15: integer division
    return max(prefer, fixed)


def fit(width, height, density, gui):
    vw, vh = min(width, CAP_W), min(height, CAP_H)
    if (vw, vh) == (width, height):
        pad_x = pad_y = 0.05
    else:
        pad_x = (1 - vw / width * 0.9) / 2
        pad_y = (1 - vh / height * 0.9) / 2
    avail_w, avail_h = width * (1 - 2 * pad_x), height * (1 - 2 * pad_y)
    imgsize = min(get_imgsize(avail_w, avail_h, density, gui),
                  avail_w / FORM_W, avail_h / FORM_H)
    # max_formspec_size (padding 0), then the cap's virtual viewport.
    preferred = get_imgsize(width, height, density, gui)
    max_y = height / preferred
    rgs = density * gui
    if (vw, vh) != (width, height):
        virtual = max(0.5555 * 96 * rgs, preferred * min(vw, vh) / min(width, height))
        max_y = vh / virtual
    scale = max(1 / max(1, rgs), min(1, max_y / WINDOW_H))
    return imgsize, scale, rgs


def main():
    fonts = {}
    print("%-22s %7s %6s %5s  %-30s %-30s" % ("profile", "imgsize", "scale", "font",
                                               "largest share, 4 tabs (before)", "largest share, 5 tabs (now)"))
    worst = 0
    for label, width, height, density, gui in PROFILES:
        imgsize, scale, rgs = fit(width, height, density, gui)
        size = max(1, int(16 * 1.1 * scale * rgs))
        font = fonts.setdefault(size, ImageFont.truetype(FONT, size))
        cells = []
        for tabs in (4, 5):
            buttons = tab_widths(tabs)
            shares = {c: font.getlength(c) / (w * imgsize) * 100 for c, w in buttons.items()}
            widest = max(shares, key=shares.get)
            if tabs == 5:
                worst = max(worst, shares[widest])
            cells.append("%-5s %3.0f/%3.0f px %3.0f %%" % (widest.split(" ")[0][:5],
                         font.getlength(widest), buttons[widest] * imgsize, shares[widest]))
        print("%-22s %7.1f %6.3f %5d  %-30s %-30s" % (label, imgsize, scale, size, *cells))
    for caption, width in tab_widths(5).items():
        print("  now: %-18s %.3f units" % (caption, width))
    print("largest share with five tabs: %.0f %% (%s)" % (worst, "fits" if worst <= 100 else "CLIPS"))
    return 0 if worst <= 100 else 1


if __name__ == "__main__":
    sys.exit(main())

"""The two Account page proposals. All coordinates are local to the inventory body."""
from dataclasses import dataclass

from drawing import ACCOUNT, CHARACTER, CREST, GOLD, MUTED, REWARDS, RULE, VILLAGE, reward, texture

TODAY = ("cheer",)
SAMPLE = ("cheer", "emberwake", "pearlwing", "moonfall")
OWNED = ("cheer", "emberwake")


@dataclass(frozen=True)
class State:
    title: str
    note: str
    advertised: tuple | None = TODAY
    owned: tuple | None = None
    code: str = ""
    error: str = ""
    offer: bool = False


STATES = {
    "unlinked": State("Unlinked", "The website currently grants Cheer to every linked account."),
    "linked": State("Linked", "Fenlark owns Cheer and the donor cloak Emberwake.", owned=OWNED),
    "offer": State("Confirm account", "A valid code identifies an account. The player still has to confirm the match.", offer=True),
    "wrong": State("Wrong code", "The field keeps the entered code so the player can correct it.",
                   code="V7KMP-4TR9B", error="Unknown code. Check it and try again."),
    "expired": State("Expired code", "The player can open the website again from the same view.",
                     code="M6QWK-8HNP3", error="Code expired. Create a new one on the website."),
    "three": State("Three advertised rewards", "Sample website selection for sizing. The three shown are hypothetical.", SAMPLE[:3]),
    "four": State("Four advertised rewards", "Sample website selection for sizing. The four shown are hypothetical.", SAMPLE),
    "empty": State("No advertised rewards", "The website sent an empty list. Linking is still available.", ()),
    "missing": State("Website list missing", "The website has not supplied the new field. The preview makes no reward claim.", None),
    "linked_empty": State("Linked without rewards", "The binding exists and the account owns no rewards.", owned=()),
}

LAYOUTS = {
    "charter": ("The Charter", "Recommended. The crest frames what you gain. Your eye can follow the three steps straight down to the code field."),
    "village": ("Village Road", "The village introduces the website as part of the world. A shelf shows the rewards above a left-to-right path from browser to game."),
}


def step(d, x, y, number, title, width):
    d.text(x, y, str(number), .99, GOLD, bold=True)
    d.text(x+.52, y, title, 1.13, bold=True, limit=width-.52)


def help_block(d, x, y, w):
    d.box(x, y, w, .022, RULE)
    d.text(x, y+.55, "Missing a reward or want to unlink?", 1.04, bold=True)
    d.text(x, y+1.12, "Ask a website administrator.", 1.02, MUTED)
    d.text(x, y+1.99, "grudgelands.com/play", 1.02)
    d.button(x+4.2, y+1.61, 3.15, .76, "Open website", "website")


def identity(d, x, y, w, title, sub):
    d.text(x, y, "WEBSITE ACCOUNT", .9, GOLD, bold=True)
    d.text(x, y+.88, title, 2.06, limit=w)
    if sub:
        d.text(x, y+1.73, sub, 1.05, MUTED, limit=w)


def confirmation(d, x, y, w):
    d.text(x, y, "Confirm your account", 1.45, bold=True)
    d.text(x, y+1.03, f"Link {CHARACTER} to the website account", 1.12)
    d.text(x, y+1.85, ACCOUNT, 1.65, GOLD, bold=True)
    d.text(x, y+3.03, "Only link to your own account.", 1.02, limit=w)
    d.text(x, y+3.57, "Only a website administrator can undo a link.", 1.02, MUTED, limit=w)
    d.button(x, y+4.19, 3.7, .89, "Confirm link", "confirm", "confirm")
    d.button(x+3.94, y+4.19, 2.45, .89, "Cancel", "cancel", "danger")


def charter(d, s):
    # A framed, flat-colour heraldic panel. The only picture on it is the real crest.
    x, w = .43, 7.32
    d.box(x, .30, w, 12.82, "#97805c")
    d.box(x+.025, .325, w-.05, 12.77, "#203033")
    for edge in (x+.17, x+w-.19):
        d.box(edge, .32, .018, 12.79, "#b3996648")
    for top in (.49, 12.90):
        d.box(x+.17, top, w-.34, .018, "#b3996648")
    linked = s.owned is not None
    if linked:
        d.art(1.35, 1.70, 5.48, 5.48, CREST, smooth=True)
        d.text(4.09, 8.00, "LINKED WEBSITE ACCOUNT", .93, GOLD, True, "center")
        d.text(4.09, 9.04, ACCOUNT, 2.10, align="center", limit=6.6)
        d.text(4.09, 10.03, f"Linked to {CHARACTER}", 1.06, MUTED, align="center")
    elif s.advertised and not s.offer:
        many = len(s.advertised) > 1
        size, top = (4.75, .68) if many else (5.62, 1.12)
        d.art(4.09-size/2, top, size, size, CREST, smooth=True)
        y = 5.81 if many else 7.15
        d.box(1.12, y, 5.94, .018, RULE)
        d.text(1.12, y+.54, "Every linked account gets", 1.06, GOLD, bold=True)
        for i, key in enumerate(s.advertised):
            reward(d, key, 1.12, y+1.06+i*1.28, 1.04 if many else 1.65, 5.94)
        if not many:
            d.text(1.12, y+3.18, REWARDS[s.advertised[0]][2], 1.02, MUTED)
    else:
        d.art(1.15, 3.58, 5.88, 5.88, CREST, smooth=True)
        if s.advertised == ():
            d.text(4.09, 10.37, "No linking rewards right now.", 1.01, MUTED, align="center")

    x, w = 8.49, 10.76
    if linked:
        d.text(x, 1.40, "Your rewards", 2.06)
        if s.owned:
            d.text(x, 2.32, "Use these on every character linked to your account.", 1.05, MUTED, limit=w)
            for i, key in enumerate(s.owned):
                y = 3.35+i*2.38
                d.box(x, y-.20, w, .018, RULE)
                reward(d, key, x+.12, y+.20, 1.37, w-.24, owned=True)
        else:
            d.box(x, 3.3, w, .018, RULE)
            d.text(x, 4.15, "Your account has no rewards yet.", 1.15)
        help_block(d, x, 9.56, w)
    elif s.offer:
        identity(d, x, 1.29, w, "Link your character", "")
        confirmation(d, x, 4.42, w)
    else:
        identity(d, x, 1.29, w, "Link your character", f"Connect {CHARACTER} to your Grudgelands website account.")
        d.box(x, 3.83, w, .018, RULE)
        step(d, x, 4.67, 1, "Open the website", w)
        d.text(x+.52, 5.41, "grudgelands.com/play", 1.09)
        d.button(x+6.78, 4.68, 3.54, .82, "Open website", "website")
        step(d, x, 6.84, 2, "Sign in and create a code", w)
        d.text(x+.52, 7.51, "Your code is valid for 10 minutes.", 1.03, MUTED)
        # The gold edge makes the editable row the strongest control on the page.
        d.plate(x, 8.66, w, 3.82, "panel")
        d.box(x, 8.66, .065, 3.82, GOLD)
        step(d, x+.38, 9.42, 3, "Enter your 10-character code", w-.76)
        d.field(x+.44, 10.14, 6.11, 1.00, s.code)
        d.button(x+6.77, 10.14, 3.52, 1.00, "Check code", "submit", "selected")
        d.status_line(x+.44, 11.81, w-.88, s.error)


def village(d, s):
    linked = s.owned is not None
    # Native [combine crops the source at a fixed offset before image[] scales it.
    x, w = .43, 19.14
    top, crop_h = 108, 374
    crop = texture(VILLAGE).crop((0, top, 1540, top+crop_h))
    d.art(x, .30, w, w*crop_h/1540, f"[combine:1540x{crop_h}:0,-{top}={VILLAGE}", crop, smooth=True)
    d.box(x, 4.91, w, .035, GOLD)
    title = ACCOUNT if linked else "Link your character"
    d.box(x, 2.85, 8.44, 2.06, "#0d191bec")
    d.box(x, 2.85, .06, 2.06, GOLD)
    d.text(x+.39, 3.36, "LINKED WEBSITE ACCOUNT" if linked else "WEBSITE ACCOUNT", .9, GOLD, True)
    d.text(x+.39, 4.18, title, 1.92, limit=7.65)

    if linked:
        d.text(.88, 5.89, "Your rewards", 1.65)
        subtitle = (f"Available to {CHARACTER} and every character linked to {ACCOUNT}." if s.owned
                    else f"{CHARACTER} is linked to {ACCOUNT}.")
        d.text(.88, 6.65, subtitle, 1.05, MUTED)
        d.box(.88, 7.22, 18.24, .018, RULE)
        if s.owned:
            for i, key in enumerate(s.owned):
                reward(d, key, .95+i*9.26, 7.78, 1.45, 8.96, owned=True)
        else:
            d.text(.88, 8.39, "Your account has no rewards yet.", 1.15)
        d.box(.88, 10.55, 18.24, .018, RULE)
        d.text(.88, 11.28, "Missing a reward or want to unlink?", 1.12, bold=True)
        d.text(.88, 12.02, "Ask a website administrator.", 1.05, MUTED)
        d.text(11.08, 11.70, "grudgelands.com/play", 1.00)
        d.button(15.52, 11.25, 3.56, .9, "Open website", "website")
        return
    if s.offer:
        confirmation(d, .90, 6.14, 17.8)
        return

    if s.advertised:
        d.text(.88, 5.62, "Every linked account gets", 1.17, GOLD, True)
        for i, key in enumerate(s.advertised):
            reward(d, key, .92+i*4.6, 6.28, 1.23, 4.42)
    elif s.advertised == ():
        d.text(.88, 6.13, "No linking rewards right now.", 1.05, MUTED)
    # An absent website field removes the whole reward shelf and lifts the action panel.
    top = 8.19 if s.advertised else (6.96 if s.advertised == () else 5.58)
    d.box(.83, top, 18.34, .022, RULE)
    step(d, .88, top+.82, 1, "Visit the website", 5.48)
    d.text(1.40, top+1.75, "grudgelands.com/play", 1.01)
    d.button(1.40, top+2.44, 3.38, .84, "Open website", "website")
    d.box(6.38, top+.53, .017, 3.35, RULE)
    step(d, 6.75, top+.82, 2, "Create a code", 4.78)
    d.text(7.27, top+1.75, "Sign in on the website.", 1.01)
    d.text(7.27, top+2.37, "Codes last 10 minutes.", 1.01, MUTED)
    d.plate(11.67, top+.30, 7.49, 4.37, "panel")
    d.box(11.67, top+.30, 7.49, .044, GOLD)
    step(d, 12.01, top+.82, 3, "Enter your code here", 6.83)
    d.text(12.02, top+1.58, "10-character link code", .97, MUTED)
    d.field(12.02, top+1.99, 4.12, .91, s.code)
    d.button(16.33, top+1.99, 2.48, .91, "Check code", "submit", "selected")
    d.status_line(12.02, top+3.41, 6.80, s.error)

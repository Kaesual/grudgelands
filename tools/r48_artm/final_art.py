"""Picked Round 48 artwork, called by generate.py; original art, CC0-1.0.

Keep the proposal pixels intact. Adapt only the HUD parts to its compositor
and derive the two mail-window marks from the picked envelope and brass.
"""

import hashlib
import importlib.util


def mail_icon(a):
    """Pick B redrawn at 48x40, with the same folds, wax and double contour."""
    im = a.Image(48, 40)
    im.rect(3, 7, 44, 30, "ba9d68")
    im.rect(4, 8, 43, 29, "f0dfb1")
    im.line(4, 28, 16, 19, "ab905f")
    im.line(31, 19, 43, 28, "ab905f")
    im.poly([(4, 8), (23, 22), (43, 8)], "fff0c8")
    im.line(4, 9, 23, 23, "75654c")
    im.line(23, 23, 43, 9, "75654c")
    im.ellipse(20, 19, 27, 26, "9a482e")
    im.line(22, 20, 24, 20, "e69c63")
    return a.outline(a.outline(im, "262a28"), "d8caa6")


def frame(a):
    """The compositor fills 160x40: put the three-pixel brass rim inside it."""
    im = a.Image(160, 40, "222d2b")
    im.rect(1, 1, 158, 38, "c0a36d")
    im.rect(2, 2, 157, 37, "695942")
    im.rect(3, 3, 156, 36, a.CLEAR)
    for x in (1, 157):
        im.put(x, 1, "f2db9b")
        im.put(x, 38, "4f4232")
    return im


def admin_badge(a):
    im = a.Image(32, 32)
    im.poly([(5, 4), (26, 4), (26, 16), (24, 21), (20, 25),
             (15, 28), (10, 25), (6, 21), (5, 16)], "695942")
    im.poly([(6, 5), (25, 5), (25, 16), (23, 21), (19, 24),
             (15, 26), (11, 24), (7, 20), (6, 16)], "c0a36d")
    im.poly([(8, 7), (23, 7), (23, 16), (21, 20), (15, 24),
             (10, 20), (8, 16)], "75654c")
    im.poly([(9, 8), (22, 8), (22, 16), (20, 19), (15, 22),
             (11, 19), (9, 16)], "292b29")
    im.line(7, 5, 24, 5, "f2db9b")
    im.line(6, 6, 6, 15, "f2db9b")
    # A broad pale check is readable at list-row scale.
    im.poly([(10, 14), (12, 12), (15, 15), (20, 10),
             (22, 12), (15, 19)], "f0dfb1")
    im.line(12, 13, 15, 16, "fff0c8")
    return a.outline(a.outline(im, "262a28"), "d8caa6")


def npc_seal(a):
    im = a.Image(32, 32)
    im.poly([(11, 5), (17, 4), (20, 6), (24, 7), (25, 11),
             (27, 14), (26, 19), (23, 22), (21, 25), (16, 26),
             (12, 24), (8, 24), (6, 20), (5, 16), (6, 11), (9, 8)], "9a482e")
    im.ellipse(8, 7, 24, 23, "e69c63")
    im.ellipse(9, 8, 23, 22, "9a482e")
    im.line(10, 6, 16, 5, "e69c63")
    im.line(6, 12, 6, 16, "e69c63")
    # The picked envelope's folded V becomes the wax impression.
    a.envelope(im, 10, 11, 12, 8, "f0dfb1", "9a482e")
    im.put(15, 15, "c0a36d")
    im.put(16, 15, "c0a36d")
    return a.outline(a.outline(im, "262a28"), "d8caa6")


def final_sheet(a, mailbox, hud_images, badges):
    out = a.sheet("MAIL AND DAYTIME / THE USER PICKS", "R48 ARTM / MAILBOX A / ENVELOPE B / BRASS CHANNEL A", 1376)
    a.text(out, 24, 96, "WAYSIDE CHEST / FRONT AND SIDE 4X", scale=2)
    for x, mode in ((24, "front"), (200, "side")):
        out.blit(a.render_node("A", mailbox, mode).scale(4), x, 122)
        a.text(out, x, 286, mode + " 4X", scale=2)
    for x, face in ((400, "front"), (488, "side"), (576, "top"), (664, "back")):
        out.blit(mailbox[face].scale(4), x, 144)
        a.text(out, x, 224, face, scale=2)
    for x, name in ((848, "grug_mapgen_waystone.png"), (944, "grug_mapgen_waystone_top.png")):
        im = a.read_png((a.ROOT / "mods/MAPGEN/grug_mapgen/textures" / name).read_bytes())
        out.blit(im.scale(4), x, 144)
    a.text(out, 848, 224, "WAYSTONE 4X", scale=2)
    a.text(out, 400, 270, "NODEBOX STUDY / NODE-ALIGNED TILES", scale=2)
    a.text(out, 24, 328, "SEALED ENVELOPE / FINISHED HUD IMAGES / 1 - 3 - 9+", scale=2)
    for i, (label, ground) in enumerate((("LIGHT GROUND", "sand"), ("DARK GROUND", "forest"))):
        x = 24 + i * 584
        a.text(out, x, 354, label, scale=2)
        tile = a.ground(560, 210, ground)
        for j, suffix in enumerate(("1", "3", "9p")):
            im = hud_images["grug_map_mail_" + suffix + ".png"]
            xx = 20 + j * 184
            tile.blit(im, xx + 30, 12)
            tile.blit(im.scale(2), xx, 94)
            a.text(tile, xx + 104, 30, "1X", "292b29" if i == 0 else "f0dfb1", 1)
            a.text(tile, xx + 130, 137, "2X", "292b29" if i == 0 else "f0dfb1", 1)
        out.blit(tile, x, 378)
    a.text(out, 24, 618, "BRASS CHANNEL / FINISHED HUD IMAGES / 1X AND 3X", scale=2)
    for j, (label, pos) in enumerate((("NOON", 15), ("DUSK", 30), ("MIDNIGHT", 35))):
        y = 652 + j * 144
        im = hud_images[f"grug_map_daytime_{pos:02d}.png"]
        a.text(out, 24, y + 14, label, scale=2)
        a.text(out, 24, y + 40, f"IMAGE {pos:02d}", "9dab9f", 1)
        out.blit(im, 196, y + 40)
        a.text(out, 372, y + 53, "1X", scale=2)
        out.blit(im.scale(3), 444, y)
        a.text(out, 944, y + 53, "3X", scale=2)
    a.text(out, 24, 1108, "ADMIN SHIELD AND NPC WAX SEAL / WINDOW DARK GREY", scale=2)
    for j, (label, im) in enumerate(badges.items()):
        x = 24 + j * 584
        tile = a.Image(560, 172, "24272c")
        a.text(tile, 20, 16, label, scale=2)
        tile.blit(im, 24, 68)
        a.text(tile, 72, 80, "1X", scale=2)
        tile.blit(im.scale(2), 144, 52)
        a.text(tile, 224, 80, "2X", scale=2)
        # Also show the list and banner colours from grug_mail/window.lua.
        tile.rect(304, 44, 399, 137, "0d0e10")
        tile.rect(416, 44, 511, 137, "3a3018")
        tile.blit(im, 336, 72)
        tile.blit(im, 448, 72)
        a.text(tile, 320, 148, "LIST 1X", "9dab9f", 1)
        a.text(tile, 424, 148, "BANNER 1X", "9dab9f", 1)
        out.blit(tile, x, 1140)
    a.text(out, 24, 1338, "ALL ENLARGEMENTS: NEAREST PIXELS / ACTUAL DESKTOP AND WEB READABILITY: USER GUI CHECK", "9dab9f", 1)
    return out


def extend(a, outputs, images, manifest):
    """Add final files to the proposal generator's exact-byte output set."""
    sources, shipped = {}, []

    def add(path, data, draft, change, generator="tools/r48_artm/generate.py"):
        outputs[path] = data
        record = {"path": (a.HERE / path).resolve().relative_to(a.ROOT).as_posix(),
                  "draft": draft, "generator": generator, "adaptation": change,
                  "sha256": hashlib.sha256(data).hexdigest()}
        if path.endswith(".png"):
            im = a.read_png(data)
            images[path] = im
            record.update(size=[im.w, im.h], mode="RGBA")
        else:
            record["type"] = "application/json"
        shipped.append(record)
        sources[path] = f"Round 48; {draft}; {generator}; {change}"

    mailbox = {}
    for face in ("top", "side", "front", "back"):
        name = "grug_mapgen_mailbox_" + face + ".png"
        data = outputs["drafts/mailbox/A/" + name]
        add("../../mods/MAPGEN/grug_mapgen/textures/" + name, data,
            "mailbox A (Wayside chest)", "byte-identical copy of drafts/mailbox/A/" + name)
        mailbox[face] = a.read_png(data)

    original_band = a.band_parts("A")
    marker = a.Image(160, 40)
    marker.blit(original_band["marker"], 75, 0)
    parts = {"mail_icon": mail_icon(a), "sun": original_band["sun"],
             "moon": original_band["moon"], "frame": frame(a), "marker": marker}
    adaptations = {"mail_icon": "48x40 redraw of drafts/icon/B/grug_map_mail.png; same design and palette, sized to meet the HUD digits",
                   "sun": "byte-identical copy of drafts/band/A/sun.png",
                   "moon": "byte-identical copy of drafts/band/A/moon.png",
                   "frame": "drafts/band/A/frame.png adapted to 160x40; brass rim inside all four edges, transparent 154x34 interior",
                   "marker": "drafts/band/A/marker.png on a transparent 160x40 canvas at x=75; tip at x=80"}
    for name, im in parts.items():
        data = outputs[f"drafts/band/A/{name}.png"] if name in ("sun", "moon") else a.png(im)
        add(f"../r48_hud/parts/{name}.png", data,
            "icon B (Sealed envelope)" if name == "mail_icon" else "band A (Brass channel)", adaptations[name])
    palette = {"day": "#bda778", "night": "#273d50", "blend": 8,
               "badge": None, "badge_rim": "#d8caa6"}
    add("../r48_hud/parts/palette.json", a.json_bytes(palette), "band A and icon B",
        "picked day/night colours and 8px blend; HUD's direct day/night interpolation replaces the draft's third twilight colour; no badge pill")

    # Use HUD's single compositor, including the shipped cooldown digits.
    spec = importlib.util.spec_from_file_location("r48_hud", a.ROOT / "tools/r48_hud/gen_hud_textures.py")
    hud = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(hud)
    rows = {name: [im.p[y * im.w:(y + 1) * im.w] for y in range(im.h)] for name, im in parts.items()}
    composed = hud.files(rows, palette)
    hud_images = {}
    for name, data in sorted(composed.items()):
        add("../../mods/PLAYER/grug_map/textures/" + name, data,
            "band A (Brass channel)" if "daytime" in name else "icon B (Sealed envelope)",
            "composed from ARTM's picked parts; cooldown glyphs remain HUD-owned",
            "tools/r48_hud/gen_hud_textures.py")
        hud_images[name] = a.read_png(data)

    badges = {"ADMIN SHIELD": admin_badge(a), "NPC WAX SEAL": npc_seal(a)}
    for label, suffix in (("ADMIN SHIELD", "admin_badge"), ("NPC WAX SEAL", "npc_seal")):
        add(f"../../mods/PLAYER/grug_mail/textures/grug_mail_{suffix}.png", a.png(badges[label]),
            "derived from icon B and band A", "original 32x32 mark; envelope outline, parchment and wax palette, band's brass")
    final = final_sheet(a, mailbox, hud_images, badges)
    add("previews/final.png", a.png(final), "mailbox A, icon B, band A and derived marks",
        "final compositions at labelled integer scales; existing CC0 waystone textures and cooldown digits")
    refs = {}
    for char in "123456789p":
        a.ref(f"mods/PLAYER/grug_abilities/textures/grug_abilities_cd_digit_{char}.png", refs)
    manifest.update(stage="Round 48 ARTM step 2; user picks installed",
                    picks={"mailbox": "A", "icon": "B", "band": "A"},
                    pick_date=a.DATE, pick_changes_requested=False,
                    shipped_path_base="repository root", shipped=shipped,
                    final_palette=palette,
                    final_preview_references=[{"path": p, "sha256": h, "license": "CC0-1.0"}
                                              for p, h in sorted(refs.items())])
    return sources

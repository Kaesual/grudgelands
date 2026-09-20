#!/usr/bin/env python3
"""Build Round 12 project-authored 16x16 food and weapon sprites."""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
COOK = ROOT / "mods/ITEMS/grug_cooking/textures"
GEAR = ROOT / "mods/ITEMS/grug_gear/textures"

OUTLINE = "#24170f"
WOOD = ("#3a2415", "#65401f", "#986335", "#c18a4d")
METALS = {
    "bronze": ("#5b2d18", "#98502b", "#d47a43", "#ffad70"),
    "iron": ("#383b3e", "#686d70", "#a4a8a9", "#d7dad8"),
    "steel": ("#34383d", "#6f7780", "#b9c0c5", "#eef3f2"),
    "silversteel": ("#48535c", "#8294a1", "#c6d6df", "#f3fbff"),
    "embersteel": ("#4a1713", "#8e2c1e", "#dd5830", "#ffd06a"),
    "abyssal_steel": ("#302447", "#5b477c", "#9278bd", "#d5c2f1"),
}


def canvas():
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))


def save(img, path):
    img.save(path, optimize=False)


def bowl(liquid, garnish=()):
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(2, 6), (13, 6), (12, 12), (10, 14), (5, 14), (3, 12)], fill=OUTLINE)
    d.rectangle((3, 7, 12, 9), fill="#81502c"); d.rectangle((4, 8, 11, 10), fill=liquid)
    d.rectangle((4, 11, 11, 12), fill="#a76c3d"); d.rectangle((6, 13, 9, 13), fill="#6c4025")
    for x, y, color in garnish: d.rectangle((x, y, x+1, y+1), fill=color)
    return im


def pot(liquid, garnish=()):
    im = canvas(); d = ImageDraw.Draw(im)
    d.rectangle((1, 7, 14, 9), fill=OUTLINE); d.rectangle((0, 9, 2, 11), fill=OUTLINE); d.rectangle((13, 9, 15, 11), fill=OUTLINE)
    d.rectangle((2, 6, 13, 7), fill="#70757a"); d.rectangle((3, 7, 12, 9), fill=liquid)
    d.polygon([(2, 9), (13, 9), (12, 14), (4, 14)], fill="#34383d"); d.rectangle((4, 10, 11, 12), fill="#555c63")
    for x, y, color in garnish: d.rectangle((x, y, x+1, y+1), fill=color)
    return im


def platter(main, accent="#d89b45", garnish="#4d7b2c", large=False):
    im = canvas(); d = ImageDraw.Draw(im)
    d.ellipse((1, 10, 14, 14), fill=OUTLINE); d.ellipse((2, 11, 13, 13), fill="#b17a3c")
    box = (3, 5, 12, 12) if large else (4, 6, 11, 11)
    d.ellipse(box, fill=OUTLINE); d.ellipse((box[0]+1, box[1]+1, box[2]-1, box[3]-1), fill=main)
    d.line((5, 7, 10, 10), fill=accent, width=1)
    d.rectangle((2, 9, 3, 11), fill=garnish); d.rectangle((12, 9, 13, 11), fill=garnish)
    return im


def fish(crust="#e1a735", salt=False):
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(2, 8), (5, 5), (11, 5), (13, 7), (15, 5), (14, 9), (15, 11), (12, 10), (10, 12), (5, 11)], fill=OUTLINE)
    d.polygon([(3, 8), (6, 6), (11, 6), (13, 8), (10, 11), (5, 10)], fill=crust)
    d.rectangle((5, 7, 6, 8), fill="#fff2bc" if salt else "#f4cf65"); d.point((11, 7), fill="#17110d")
    d.rectangle((3, 11, 5, 12), fill="#4f7f31")
    return im


def jar():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rectangle((5, 2, 10, 3), fill=OUTLINE); d.rectangle((4, 4, 11, 13), fill=OUTLINE)
    d.rectangle((5, 5, 10, 12), fill="#8e1f53"); d.rectangle((6, 6, 9, 9), fill="#cf3f72")
    d.rectangle((5, 3, 10, 4), fill="#d7b779"); d.rectangle((6, 10, 7, 11), fill="#ef7193")
    return im


def skewer():
    im = canvas(); d = ImageDraw.Draw(im)
    d.line((2, 13, 13, 2), fill=OUTLINE, width=2); d.line((3, 12, 13, 2), fill="#a96c34")
    for x,y,c in [(5,10,"#9b5a31"),(8,7,"#ceb17a"),(11,4,"#794425")]:
        d.ellipse((x-2,y-2,x+2,y+2), fill=OUTLINE); d.rectangle((x-1,y-1,x+1,y+1), fill=c)
    return im


def mug():
    im = canvas(); d = ImageDraw.Draw(im)
    d.line((6, 1, 5, 3), fill="#d8d4c8"); d.line((9, 0, 8, 3), fill="#d8d4c8")
    d.rectangle((3, 4, 11, 13), fill=OUTLINE); d.rectangle((4, 5, 10, 12), fill="#8c512d")
    d.rectangle((4, 5, 10, 7), fill="#4a2417"); d.rectangle((5, 5, 8, 5), fill="#d5a276")
    d.rectangle((11, 6, 14, 11), fill=OUTLINE); d.rectangle((11, 7, 12, 10), fill="#a76838")
    return im


def bread():
    im = canvas(); d = ImageDraw.Draw(im)
    d.polygon([(2, 7),(4,4),(10,3),(13,6),(13,11),(11,13),(4,13),(2,11)], fill=OUTLINE)
    d.polygon([(3,7),(5,5),(10,4),(12,6),(12,11),(10,12),(4,12),(3,10)], fill="#c97c33")
    d.line((5,6,7,8), fill="#f0bc68"); d.line((8,5,10,7), fill="#f0bc68")
    return im


def raw_bundle(kind):
    im = canvas(); d = ImageDraw.Draw(im)
    colors = ["#b34f43", "#d17b36", "#8c6745", "#b67982", "#477f65", "#6b3d2b"]
    c = colors[kind]
    d.polygon([(2,5),(5,3),(10,4),(13,7),(12,12),(8,14),(3,11)], fill=OUTLINE)
    d.polygon([(3,6),(5,4),(10,5),(12,7),(11,11),(8,13),(4,10)], fill=c)
    d.line((2,5,12,12), fill="#d6b476", width=1); d.line((12,5,3,12), fill="#d6b476", width=1)
    d.rectangle((7,8,8,9), fill="#f1d49a")
    return im


def wand(pal):
    im = canvas(); d = ImageDraw.Draw(im)
    # Grip and shaft retain the shared bottom-left -> top-right convention.
    d.line((2,14,10,6), fill=OUTLINE, width=3); d.line((2,13,10,5), fill=WOOD[2], width=1)
    d.rectangle((2,11,4,14), fill=OUTLINE); d.line((3,12,5,10), fill=WOOD[3], width=1)
    d.polygon([(8,6),(10,2),(13,1),(15,3),(14,6),(11,8)], fill=OUTLINE)
    d.polygon([(10,5),(11,3),(13,2),(14,3),(13,5),(11,6)], fill=pal[2]); d.point((13,2), fill=pal[3])
    d.rectangle((8,6,10,8), fill=pal[1]); d.point((9,6), fill=pal[3])
    return im


def greataxe(pal):
    im = canvas(); d = ImageDraw.Draw(im)
    d.line((1,15,11,5), fill=OUTLINE, width=3); d.line((2,14,11,5), fill=WOOD[2], width=1)
    d.rectangle((1,12,3,15), fill=OUTLINE); d.point((2,13), fill=WOOD[3])
    # Equal broad blades reflected across the diagonal haft (x+y=16).
    # The eye is on the shaft at (10,6); neither side is just a rear spur.
    outer = [(10,5),(10,3),(8,1),(5,1),(3,3),(4,6),(6,8),(8,8)]
    inner = [(9,5),(9,3),(7,2),(5,2),(4,3),(5,6),(6,7),(8,7)]
    edge = [(5,2),(4,3),(5,6),(6,7)]
    reflect = lambda points: [(16-y,16-x) for x,y in points]
    for polygon in (outer, reflect(outer)): d.polygon(polygon, fill=OUTLINE)
    d.polygon(inner, fill=pal[2]); d.polygon(reflect(inner), fill=pal[2])
    for points in (edge, reflect(edge)): d.line(points, fill=pal[3], width=1)
    d.polygon([(9,5),(10,4),(12,6),(11,7)], fill=OUTLINE)
    d.line((10,5,11,6), fill=pal[0], width=1)
    return im


def main():
    foods = {
        "hearty_stew": bowl("#7a3d24", [(5,8,"#d17736"),(9,8,"#6d9137")]),
        "sweetroot_mash": bowl("#e0a449", [(7,7,"#f3d37a")]),
        "corn_crusted_fish": fish("#dba72f"),
        "pumpkin_stew": pot("#c35c25", [(6,7,"#ef9b39"),(9,8,"#608433")]),
        "berry_preserve": jar(),
        "fruit_glazed_roast": platter("#a84628", "#dc7041", "#8b3151"),
        "foragers_pot": pot("#63452f", [(5,7,"#b99b68"),(9,8,"#d2bd83")]),
        "mushroom_skewer": skewer(),
        "onion_seared_steak": platter("#744025", "#c17e45", "#e7d39a"),
        "marsh_roast": platter("#8f5132", "#d69258", "#b08aa8"),
        "marshbloom_chowder": bowl("#ded5b0", [(6,7,"#c99ad3"),(9,8,"#719557")]),
        "hunters_feast": platter("#a84b25", "#ed9648", "#486f2d", True),
        "kelp_wrapped_roast": platter("#42733e", "#77a44c", "#d78364"),
        "stormkelp_broth": bowl("#335d49", [(6,8,"#6c9b58"),(9,7,"#a8c17c")]),
        "salt_crusted_fish": fish("#d9d8c4", True),
        "grand_feast": platter("#b05a2a", "#efa34a", "#78508e", True),
        "jungle_cocoa": mug(),
        "cocoa_rubbed_game": platter("#63331f", "#9d5b34", "#7a322c", True),
    }
    for name, image in foods.items(): save(image, COOK / ("grug_cooking_dish_" + name + ".png"))
    raw_names = ["raw_stew_pot", "raw_pumpkin_pot", "raw_foragers_pot", "raw_marsh_roast", "raw_kelp_roast", "raw_grand_feast"]
    for i, name in enumerate(raw_names): save(raw_bundle(i), COOK / ("grug_cooking_" + name + ".png"))
    save(bread(), COOK / "grug_cooking_bread.png")
    for material, pal in METALS.items():
        save(wand(pal), GEAR / ("grug_gear_item_wand_" + material + ".png"))
        save(greataxe(pal), GEAR / ("grug_gear_item_greataxe_" + material + ".png"))


if __name__ == "__main__": main()

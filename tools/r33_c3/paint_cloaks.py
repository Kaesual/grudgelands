#!/usr/bin/env python3
"""Paint the 41 selected Round 33 cloaks at their native pixel resolution.

Run with Python + Pillow. No game files or external inputs are written.
Second pass: repaint only the twelve requested designs; preserve the other
29 PNGs byte for byte. Hunter trim uses the requested deeper woodland greens.
There is no dithering, antialiasing, noise, or interpolated texture colour.
The first-pass legend and validation.json are left untouched as requested;
the current checks run here and are reported on stdout.
"""

from pathlib import Path
import base64
import hashlib
import io

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "cloaks"
PALETTES = {
    "plain_grey": ("#797B7C", "#575A5C", "#8A8C8D"),
    "hunter": ("#203B29", "#14261B", "#34543B"),
    "kingslayer": ("#342A46", "#1D1929", "#C6A45C", "#EEE0AE"),
    "wyvernslayer": ("#216343", "#113828", "#44905A", "#A7C970"),
    "dragonslayer": ("#245D96", "#142E55", "#62AAD0", "#D5F1F3"),
    "honored": ("#9A303A", "#531E29", "#D1D4CD", "#BDA063"),
    "zombie_slayer": ("#51455F", "#2B2534", "#B8AD91", "#DBD4BA"),
    "boaring_work": ("#8B623D", "#463423", "#D8AB88", "#F1E2BF"),
    "rat_race": ("#827449", "#49432F", "#C8BEA1", "#CB9292"),
    "suppers_ready": ("#B07646", "#68442E", "#F0D7A2", "#7C8D58"),
    "bottle_service": ("#315B58", "#1D3433", "#A8D3BC", "#CEAC70"),
    "loose_bones": ("#3F5156", "#243136", "#D9D5B7", "#A7AD9D"),
    "stone_deaf": ("#6D716C", "#3B413D", "#C9C8B4", "#AA8257"),
    "final_notice": ("#D2C09A", "#806D51", "#913F3E", "#F0E4C7"),
    "rust_in_peace": ("#744B36", "#3D2B23", "#B9C3BE", "#D5A56D"),
    "no_more_orders": ("#414966", "#242A40", "#DED8BD", "#A8845D"),
    "last_word": ("#65465C", "#362635", "#D2B682", "#ECE0C5"),
    "grounded": ("#94724F", "#503C2D", "#D9C6A0", "#6E858C"),
}
FAMILIES = [
    ("plain_grey", 1, None),
    ("hunter", 3, "C-U1"),
    ("kingslayer", 3, "C-U2"),
    ("wyvernslayer", 3, "C-U3"),
    ("dragonslayer", 3, "C-U4"),
    ("honored", 3, "C-U5"),
    ("zombie_slayer", 3, "C1"),
    ("boaring_work", 3, "C2"),
    ("rat_race", 2, "C10"),
    ("suppers_ready", 3, "C7"),
    ("bottle_service", 3, "C8"),
    ("loose_bones", 3, "C12"),
    ("stone_deaf", 2, "C16"),
    ("final_notice", 1, "C17"),
    ("rust_in_peace", 2, "C19"),
    ("no_more_orders", 1, "C20"),
    ("last_word", 1, "C22"),
    ("grounded", 1, "C24"),
]


# Frozen first-pass evidence: hashes protect the other 29 textures; these twelve
# PNGs exist only to reproduce the old-left/new-right review sheet.
FIRST_PASS_SHA256 = {
    'boaring_work_1': '0bc308bfdcd529f5598d6991bf59ddf6788a43190836d68f3931be905a734f36',
    'boaring_work_2': 'f1bda6f1105b537d65ec129faa999e156540f285b485625f04d437fe1be65218',
    'boaring_work_3': '9a01e03d162b292cff5580badaffdd46444a903d27f0c8cb3074336d7d91bc90',
    'bottle_service_1': 'a0e7fb20be47ed66eb05180ab8796487441f73d8b20c6c89b86150c474007e9f',
    'bottle_service_2': 'ea0ef8e092710dd1e27dd4943dab9a42a95abba5556d0e966355572f95e548e8',
    'bottle_service_3': 'f417e7c23cfefbbf471f92b916f80c8af4f5b6973d2e6245cef259a92661ba4d',
    'dragonslayer_1': 'd0a87c5382a5b3d2601759da37c0ad2fc2299f789f1cd8818bfdc83401f7e054',
    'dragonslayer_2': '870e9cd9989dce8cdf31e347ef74cd2bee22a33bf228f9b9f17771b3452f149c',
    'dragonslayer_3': 'd4b9736f865954922bd58ffa32e2d6bb59f5717e1a39fd2cfee7e1cad2641ff6',
    'final_notice_1': 'aed561ce110007cdb8897073992df595346c4e8ddc6045306ba5b723b063b144',
    'grounded_1': '3eb70040ce15640d1d062f1e20ca3755fb7c3d0b28996379875a3d260edf55bb',
    'honored_1': 'c3f06c52a2837b92e4b203b9f71575a46b1e0d5f7a04b189d9b60ce054a2a550',
    'honored_2': '998906653af0cc47d66c5802b79a42de0e8b636105cc8dec53e5a62b1d93dba6',
    'honored_3': '7afa2025ab0a3002673edf842b0157843415667c01f1b3774a010a2fa04f1bd6',
    'hunter_1': 'e28ff4ba89bef0906b65c18bc56607b2879a25a3d7578eff8948835790edb281',
    'hunter_2': '4ab604edc3f3aec5dd702b4a47783bf795618c37e0a58a9cb985dd94df294359',
    'hunter_3': '4af056e1adfbe960f7da457d2115dae233c538dc978e6b728d5e5190f4373607',
    'kingslayer_1': 'cfc433f63366f82f63c9cce944bc227819389c5e81bc7a9c8eda4361308a7e76',
    'kingslayer_2': '5d63fecd5b017f64bfbe3048d26f6774feb094504e6c234c4a6403d9705c368f',
    'kingslayer_3': '7d2c5de10440970e2422cc93a2588e66538e0823f4f6ecf5e736eadeb37977f9',
    'last_word_1': 'b59761669a5a4aa27d8047c5221a7757e28e1fc51b9329ae3830a6f3328a3719',
    'loose_bones_1': 'b5d963e04faf15ae02bfd4e08fdcb542f75f387bc809d8ef977731cf37e6a41d',
    'loose_bones_2': 'dc14ed4fdf0d712c2cdd04c68bbf29f4ebd81a824ec3797748e24b759c41a615',
    'loose_bones_3': 'e22b84908ce5fc4f087079bd8fae8034df537ffa1bd38f5c806224b33cbce90c',
    'no_more_orders_1': 'ac381b16180d2a0ad2d03dbe96b3b92e4bad1d52959b391e792a9503b1644dec',
    'plain_grey': '9d8e689b697b83532da9634b80c9fd34f4e56b2a4ce05973d304385e77cba582',
    'rat_race_1': '6f82b40c8ed98e5e51ebe801b5587bbeeecc2ef390eef2c91ae5d43e0316135a',
    'rat_race_2': '98b3517fc70a4752b4c84d9bf4a163fdaca8e699aabdc5e93954484567210b77',
    'rust_in_peace_1': 'd315dab51dab6a972e9cd6aeed62fe15ed25c64741334ec750efdbe361bfbcd1',
    'rust_in_peace_2': 'f6a1f9a4f3a40888a9538fada2280cd544aa33dc206729cdb85d0896dfca142d',
    'stone_deaf_1': '81df6de969707377f9dc4650e99a48fea3c00d5b916956f36bf67803d338b1f0',
    'stone_deaf_2': 'd4760c465f30cf71b27b7c1431b08840e4e3e737aafa8fa9b7c4b52781b1e50d',
    'suppers_ready_1': '83796cce034f1e524a9eecb53c8c5be26dd6cf75f3095c88b85546bd49fb2522',
    'suppers_ready_2': '48c0756c26596c78a5053ea8bdd36164cc2f6651bf8bc03004451dbc7cd3be06',
    'suppers_ready_3': '7ef59bb43e748c852b6fd86562233b4e8397f88c6e5fed57abe050e4ecf254c7',
    'wyvernslayer_1': 'f796de9ffc39ce42def4ffe90969b5e4291715baf5a458ffbd43d10d51f48412',
    'wyvernslayer_2': '9c10b100478df52dacbb6267c02b9529759870a76467d9e96faff78f049c4b80',
    'wyvernslayer_3': '6d319313661e5eb82c9eb39f613b46c2a5cf3f085cea98ff43735d4e44d251af',
    'zombie_slayer_1': 'da8fe2989a53c4cad00b10acdf38e146ca2cc2538999690982ae30a088328ec1',
    'zombie_slayer_2': '8e51dd657060caa02f0592719be2675883a703352afa52dc149e8249a10781b7',
    'zombie_slayer_3': 'ccc3db98bc588b6b2b349e81a26af36ee0eafa9763de0be58484bef53eb03ac5',
}
FIRST_PASS_PNG = {
    'hunter_2': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAfElEQVR42mNMaQj6z0AB2LDsJCXaGVjQDeER5cOr'
        '4cvrT3B2QJQ5A6WAiWGAAYoDCPmeWDVDNwRGHTDqAGIBNXMCE62yF82jgFoOZhpI34/mglEHjDpg1AEUOQC5bTj0'
        'Q4BavhlNhCPHAdRMM0y0MHQ0DZDcO6ZGL5dcAAC63xfXvEICTgAAAABJRU5ErkJggg=='
    ),
    'hunter_3': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAApElEQVR42mMUUZP+zzCAgAVdgEeUD6+GL68/UdUB'
        'TAwDDJhI8T2xaoZuCIw6YNQBxAJq5gQmWmUvmkcBtRzMNJC+H80Fow4YdcCoAyhyALXahoMjBKjd0h1SIcDCwMDA'
        'EBBlzsDAwMBQ6GHJ0L/jOFySEH/DspPUD4FCD0uS+FRzAL0txhkCyEFMDJ9qDqC3xTDAKKIm/R+WCEkF1EiEjAPd'
        'PQcASMsu+qsw56UAAAAASUVORK5CYII='
    ),
    'kingslayer_3': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA0UlEQVR42mOUldT8zzCAgAVdQFxQFq+Gl+8fU9UB'
        'TAwDDJhI8T2xaoZuCIw6YEQ6gIWBgYFhZbcxAwMDA0Ne2yuiNMHUh5eepW0I7NqWwbBrWwZ9o2BSlRicfePIOoYb'
        'R9ZhlaNpGsBmES0sxxsFyBbSyvLBmQ3x5QRicwlF1TEDAwODhk0QDuUz6OMA5JQ/8opifCmebuXAgLYJaZHSh04I'
        '0LLEG22Q4AKMsJ4Rqc1tanVQyAoBavaOUJpkxAMx+jTJ6JoGSEkHVI8CWvV8iQEACLw4a7HX+SkAAAAASUVORK5C'
        'YII='
    ),
    'honored_3': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAABB0lEQVR42mMMltP8zzCAgAVdwF1IEK+Gne/eU9UB'
        'TAwDDJhI8T2xaoZuCAxYIuxb7AxJYPnniNIEU18Uu3eYhACpWcydVmmgbtsSghqIUUNRQQSzoMkrhqYWE0wDyBbS'
        'ynIMB2DzNbrl6GqoHgL4LKC25TijAJtFtLAcpwOwxTlMDFYI0cwB+CygtuUYDoBZIPB2PjzYYUEPE6OpA5DLdmQL'
        'kdnUKP8JhgCuSqcodi/t0wC6hchiNE8DuCynVfBjOGBn/jm8TS53IUGi2wwURQE2R1C7LUiwMkK2kFaWY62O6eHr'
        'QdUkY4R1zUjxLTV7RyzkNDjMqVhDDp4oICUaqB4FtOr5EgMAtSNjMaDAcUcAAAAASUVORK5CYII='
    ),
    'zombie_slayer_1': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAh0lEQVR42mPUVjX5zzCAgAVdQE1BG6+GWw+uUtUB'
        'TAwDDJhI8T2xaoZuCIw6YNQBxAJq5gQmWmUvmkcBtRzMNJC+H80Fow4YFA5AaZB09UcTpamscCltHHD35vWRFwWM'
        '2qom/8kpiKjVNhwcuYDaLd3RcmD4O4CaaYaJVl2u0TRAVl0wENEAABq4G7zxPE/aAAAAAElFTkSuQmCC'
    ),
    'zombie_slayer_2': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAApElEQVR42mPUVjX5zzCAgAVdQE1BG6+GWw+uUtUB'
        'TAwDDJhI8T2xaoZuCIw6YNQBxAJq5gQmWmUvmkcBtRzMNJC+H80FGA7o6o9m6OqPxqmYkDzF1fHdm9fxKiYkPySj'
        'ACUElNU1oUGtSUDbuYGJgmGZCxi1VU3+k1MQUattODjKAWq3dEeL4uHvAGqmGSZadblIKgk3rG8jS3NAYNUwKQkH'
        '0gEARMYoHoN6f/wAAAAASUVORK5CYII='
    ),
    'zombie_slayer_3': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAA10lEQVR42mPUVjX5zzCAgAVdQE1BG6+GWw+uUtUB'
        'TAwDDJhI8T2xaoZuCIw6YFBkQxjo6o9G4ZcVLqWJAxiRCyI1BW0Mi9EBzCHUKg/gDkC3HN3H6HLUcgATLgtw+Rym'
        'llrlARN64YIvrmmRDkazIROh7EesHMXlQFnhUob0DCO8iu/evM7AwMDAMHPGuWFaEiqra0KDWpOAtnO0cQAsiEdU'
        'LmDUVjX5T06pRvWieEDLAWq3dIdeNtywvo0szQGBVcMkF5Da3qdmmmGiVZdrNA2Q1SoeCAAAV85JZjiMn4gAAAAA'
        'SUVORK5CYII='
    ),
    'loose_bones_1': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAnklEQVR42mNUMTT7zzCAgAVdQFpBAa+Gpw8eUNUB'
        'TAwDDJhI8T2xaoZuCIw6YNQBxAJq5gQmWmUvmkcBtRzMgs2wWS2JeDWl1cynXQgQspymlRGy5dT0JclpgF6WD95y'
        'gJ7pgFHF0Ow/ci7AZzl61FCjccI0kPGPNQRIATQJAXpaPnhyAbVbuqMNkuHvAGqmGSZadblG0wBZDZKBiAYAHdgs'
        'P2N4usQAAAAASUVORK5CYII='
    ),
    'loose_bones_2': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAtElEQVR42mNUMTT7zzCAgAVdQFpBAa+Gpw8eUNUB'
        'TAwDDJhI8T2xaoZuCIw6YNQBxAJq5gQWZENntSQSpSmtZj71Q4BYy2FqqRUKLOhBSsh3pDiUGMCoYmj2n1zfUKNe'
        'GPBcwIIveGHRgUt8QBMhzdoD2HyHLDaaCGlWFM9qSSQqeIlVR3YaINZwarUNmcjJWtTMhoywZjmpCZHqITDaIBlS'
        'DqBm74iJVl2u0TRAVkk4ENEAAA5zQCNbTD8aAAAAAElFTkSuQmCC'
    ),
    'loose_bones_3': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAnElEQVR42mNUMTT7zzCAgAVdQFpBAa+Gpw8eUNUB'
        'TAwDDJhI8T2xaoZuCIw6YMCyYXNNOlmaa1tmUq8cqG2ZSVIKz4hxp24UUDt7kVUSzmpJJEpTWs38YZYIifUhsSFE'
        'tgMIBS01g35wRsFoIhxNhKOJcDQRDkQiZKF2/U4qYIT1jEhtD1Crg0JWIqRm74iJVl2u0WY5WdlwIKIBAJ5XNICI'
        'aV0mAAAAAElFTkSuQmCC'
    ),
    'bottle_service_2': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAApklEQVR42mOUNTH+zzCAgAVdQERdFa+GNzdvU9UB'
        'TAwDDJhI8T2xaoZeCHTP7yRZIzl6Bn8aGJEOYMElMTdQAoWfvP4FTXICE62yF8UhcEvdB01kzghKhOUVKUSJDc8Q'
        'wOdTWoTCaEGEMxt2dswZoYlw0EQBrYJ88IcAeuKjiwPUbm7BqH4JgptbRnMBVQAjrGtGSoOEmr0jJlp1uUbTAFnl'
        'wEBEAwB7myf2PALtqwAAAABJRU5ErkJggg=='
    ),
    'bottle_service_3': (
        'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAvElEQVR42mN8sK/kPwMFwLZsPyXaGVjQDRFRV8Wr'
        '4c3N23D24S5HBkoBC+mGyVDF5xgOYGBgYAic+4QoTeuTZRioBZgYBhiMOmDUASzEpnRic8jwCYGvWlFoIl0oPEIl'
        'JkkhQC3DqBICS3rLsCqEiccUdw3jbIjL96SqGS2IKM6GuBIatYN/NAoocgBy23DoJ0KIb2RomtiGRjYktpwfbRUP'
        '3zRAzbgl2QG2ZfuJbhlRqxCCO4D0Xi71QgoAUjEygzOjFMsAAAAASUVORK5CYII='
    ),
}


def palette_for(family, tier):
    palette = PALETTES[family]
    if family == "hunter" and tier > 1:
        palette = ("#203B29", "#14261B", "#34543B", "#55794C") if tier == 2 else (
            "#203B29", "#14261B", "#315C3D", "#5F8556")
    elif family == "wyvernslayer" and tier == 3:
        palette = palette[:3] + ("#D9D68D",)
    elif family == "honored" and tier == 3:
        palette = palette[:3] + ("#E1C16C",)
    elif family == "bottle_service" and tier == 3:
        palette = palette[:2] + ("#D5E8CE", "#E0BE74")
    return palette


class Cloth:
    def __init__(self, family, tier):
        self.palette = palette_for(family, tier)
        self.base, self.shadow = self.palette[:2]
        self.motif = self.palette[2]
        self.accent = self.palette[-1]
        self.edge = self.shadow
        self.image = Image.new("RGBA", (16, 32), self.base)
        self.d = ImageDraw.Draw(self.image)
        # Short tapered creases stay at the edges, away from the badge.
        self.poly([(1, 1), (3, 1), (2, 4), (2, 8), (1, 11)], self.shadow)
        self.poly([(12, 1), (14, 1), (14, 10), (13, 7), (13, 4)], self.shadow)
        self.rect((1, 23, 1, 30), self.shadow)
        self.rect((14, 21, 14, 30), self.shadow)
        self.rect((2, 28, 2, 30), self.shadow)
        self.rect((13, 27, 13, 30), self.shadow)

    def rect(self, box, color):
        self.d.rectangle(box, fill=color)

    def poly(self, points, color):
        self.d.polygon(points, fill=color)

    def line(self, points, color, width=1):
        self.d.line(points, fill=color, width=width)

    def frame(self, box, color, width=1):
        self.d.rectangle(box, outline=color, width=width)

    def stamp(self, rows, x, y, colors):
        for dy, row in enumerate(rows):
            for dx, key in enumerate(row):
                if key != ".":
                    self.d.point((x + dx, y + dy), fill=colors[key])

    def hem(self, color, y=28, width=2):
        self.rect((1, y, 14, y + width - 1), color)

    def finish(self):
        # All four edge strips share a single edge colour, including corners.
        self.frame((0, 0, 15, 31), self.edge)
        atlas = Image.new("RGBA", (32, 32), self.shadow)
        atlas.paste(self.image, (0, 0))
        return atlas


def plain(c, tier):
    # A few long, stepped ridges suggest cloth; never add an emblem.
    c.line([(5, 2), (5, 9), (4, 10), (4, 23)], c.motif)
    c.line([(10, 3), (10, 13), (11, 14), (11, 28)], c.motif)
    c.line([(7, 26), (7, 30)], c.shadow)


def hunter(c, tier):
    if tier == 1:
        plain(c, tier)
    elif tier == 2:
        plain(c, tier)
        # One woodland leaf on the shoulder; the edge stays a dark cloth seam.
        c.stamp([
            "....LL", "..LLLL", ".LLLLL", "LLLLL.", "LLLL..", ".LL...", ".L....",
        ], 5, 7, {"L": c.accent})
    else:
        c.hem(c.motif, 25, 6)
        for x in (3, 7, 11):
            c.stamp([".L.", ".LL", "LLL", "LL.", ".L."],
                    x - 1, 25, {"L": c.accent})


def kingslayer(c, tier):
    if tier == 3:
        # A full-width five-point crown; all rank trim runs across the cloak.
        c.hem(c.motif, 3, 2)
        c.rect((5, 5, 10, 5), c.motif)
        c.stamp([
            ".....HH.....", "G....GG....G", "GG.G.GG.G.GG",
            "GGGG.GG.GGGG", "GGGGGGGGGGGG", ".GGGGGGGGGG.",
            ".HHHHHHHHHH.", ".GGDGGGGDGG.", ".GGDGGGGDGG.",
            ".GGGGHHGGGG.", "GGGGGGGGGGGG", "HHHHHHHHHHHH",
        ], 2, 9, {"G": c.motif, "H": c.accent, "D": c.shadow})
        c.hem(c.motif, 27, 3)
        c.hem(c.accent, 28, 1)
    else:
        c.stamp([
            ".....HH.....", "G....GG....G", "GG...GG...GG",
            "GGG.GGGG.GGG", "GGGGGGGGGGGG", ".GGGGGGGGGG.",
            ".GGGGGGGGGG.", ".HHHHHHHHHH.", ".GGGGGGGGGG.",
        ], 2, 10, {"G": c.motif, "H": c.accent})
    if tier == 2:
        c.rect((3, 19, 12, 20), c.motif)
        c.hem(c.motif, 28, 2)


def scales(c, icy=False):
    # Interlocking, offset rows: six-pixel scales rather than stippled noise.
    for row, y in enumerate(range(5, 29, 5)):
        for x in range(-3 if row % 2 else 0, 16, 6):
            if icy:
                shape = ["SS..SS", ".SSSS.", "..SS.."]
            else:
                shape = ["S....S", "SS..SS", ".SSSS.", "..SS.."]
            c.stamp(shape, x, y, {"S": c.motif})


def shoulder_chevron(c, color):
    c.poly([(1, 3), (7, 7), (8, 7), (14, 3),
            (14, 6), (8, 11), (7, 11), (1, 6)], color)


def wyvernslayer(c, tier):
    scales(c)
    if tier >= 2:
        c.rect((6, 7, 9, 28), c.shadow)
        c.rect((7, 6, 8, 29), c.accent)
        for y in (10, 16, 22):
            c.rect((6, y, 9, y + 1), c.accent)
    if tier == 3:
        shoulder_chevron(c, c.accent)


def dragonslayer(c, tier):
    scales(c, icy=True)
    if tier >= 2:
        for y in range(2, 31):
            width = 2 if (y // 4) % 2 else 1
            c.rect((1, y, width, y), c.accent)
            c.rect((15 - width, y, 14, y), c.accent)
    if tier == 3:
        shoulder_chevron(c, c.accent)
        c.hem(c.accent, 27, 4)
        c.rect((4, 26, 5, 27), c.accent)
        c.rect((10, 26, 11, 27), c.accent)


def honored(c, tier):
    if tier >= 2:
        c.poly([(2, 8), (13, 8), (13, 17), (11, 21),
                (8, 24), (7, 24), (4, 21), (2, 17)], c.shadow)
        c.hem(c.motif)
    if tier == 3:
        # Gold shoulder mantle and hem leave the complete sword badge open.
        c.hem(c.accent, 3, 2)
        c.rect((4, 5, 11, 5), c.accent)
        c.rect((6, 6, 9, 6), c.accent)
        c.hem(c.accent, 27, 3)
        c.hem(c.motif, 28, 1)
    # Twelve-pixel crossed blades, clear gold guards, grips below the guards.
    c.poly([(3, 9), (5, 10), (11, 16), (10, 18), (3, 11)], c.motif)
    c.poly([(12, 9), (10, 10), (4, 16), (5, 18), (12, 11)], c.motif)
    c.line([(3, 16), (6, 19)], c.accent, 2)
    c.line([(12, 16), (9, 19)], c.accent, 2)
    c.line([(4, 19), (2, 21)], c.accent, 2)
    c.line([(11, 19), (13, 21)], c.accent, 2)
    if tier == 3:
        c.rect((7, 14, 8, 15), c.accent)


def zombie_slayer(c, tier):
    # A square, fleshy dead face with hair, one milky eye and a ragged mouth.
    # Steel sits behind the trophy, leaving its zombie features unobscured.
    if tier >= 2:
        c.line([(13, 6), (3, 25)], c.accent, 2)
        c.line([(10, 6), (14, 8)], c.motif, 2)
        c.rect((13, 4, 14, 5), c.motif)
    if tier == 3:
        c.line([(2, 6), (12, 25)], c.accent, 2)
        c.line([(2, 9), (5, 7)], c.motif, 2)
        c.line([(1, 5), (2, 6)], c.motif, 2)
    rows = [
        ".DDDDDDDDDD.", ".DMMMMMMMDM.", "MMMMMMMMMMMM",
        "MMDDMMMDDDMM", "MMDHMMMDDMMM", "MMMMMMDMMMMM",
        ".MMMMMMMMMM.", ".MMDDDDDDMM.", ".MMDMDMDMMM.",
        ".MMMMMMMMDM.", "..MMMMMMMM..", "...MMMMMM...",
    ]
    c.stamp(rows, 2, 10, {"D": c.shadow, "M": c.motif, "H": c.accent})
    if tier == 1:
        # A short execution blade below the severed head starts the progression.
        c.rect((2, 25, 4, 25), c.motif)
        c.rect((5, 23, 5, 27), c.motif)
        c.poly([(6, 24), (13, 24), (12, 25), (6, 25)], c.accent)
    if tier == 3:
        c.hem(c.motif, 28, 2)
        c.rect((6, 27, 9, 30), c.accent)


def boaring_work(c, tier):
    if tier == 3:
        c.poly([(2, 9), (6, 11), (9, 11), (13, 9), (13, 17),
                (11, 21), (4, 21), (2, 17)], c.shadow)
        c.poly([(3, 10), (5, 11), (4, 13)], c.motif)
        c.poly([(12, 10), (10, 11), (11, 13)], c.motif)
        c.rect((4, 13, 5, 13), c.accent)
        c.rect((10, 13, 11, 13), c.accent)
    c.stamp([
        "..PPPPPP..", ".PPPPPPPP.", "PPPPPPPPPP", "PPDDPPDDPP",
        "PPDDPPDDPP", ".PPPPPPPP.", "..PPPPPP..",
    ], 3, 15, {"P": c.motif, "D": c.shadow})
    if tier >= 2:
        c.poly([(1, 13), (2, 16), (3, 18), (4, 18), (4, 21),
                (2, 20), (1, 17)], c.accent)
        c.poly([(14, 13), (13, 16), (12, 18), (11, 18), (11, 21),
                (13, 20), (14, 17)], c.accent)


def rat_race(c, tier):
    if tier == 1:
        c.poly([(6, 14), (10, 14), (12, 16), (12, 18),
                (10, 20), (6, 20), (4, 18), (4, 16)], c.motif)
        c.poly([(6, 14), (3, 15), (2, 17), (3, 18), (7, 18)], c.motif)
        c.rect((3, 13, 4, 14), c.motif)
        c.rect((6, 13, 7, 14), c.motif)
        c.rect((4, 16, 4, 16), c.shadow)
        c.line([(12, 18), (13, 19), (13, 22), (10, 22)], c.accent)
    else:
        c.poly([(5, 13), (10, 13), (12, 15), (13, 17), (13, 19),
                (11, 22), (5, 22), (3, 19), (3, 16)], c.motif)
        c.poly([(5, 14), (2, 16), (1, 18), (3, 19), (7, 18)], c.motif)
        c.rect((3, 11, 5, 13), c.motif)
        c.rect((7, 11, 9, 13), c.motif)
        c.rect((4, 16, 4, 16), c.shadow)
        c.line([(13, 18), (14, 20), (14, 24), (10, 24)], c.accent)
        c.hem(c.accent, 27, 4)
        # Bite marks remove pink trim, not cloth or opacity.
        for x, y in ((3, 27), (9, 27), (6, 29), (12, 29)):
            c.rect((x, y, x + 1, y + 1), c.base)


def steam(c, x):
    c.stamp([".SS", ".SS", "SS.", "SS.", ".SS", ".SS"],
            x, 9, {"S": c.motif})


def suppers_ready(c, tier):
    if tier == 1:
        steam(c, 6)
    else:
        steam(c, 4)
        steam(c, 9)
        c.hem(c.accent, 29, 2)
    c.stamp([
        "BBBBBBBBBBBB", "BBBBBBBBBBBB", ".BBBBBBBBBB.",
        "..BBBBBBBB..", "...BBBBBB...", "....BBBB....",
    ], 2, 17, {"B": c.motif})
    if tier == 3:
        c.hem(c.motif, 24, 2)
        c.hem(c.accent, 27, 1)


def bottle_service(c, tier):
    if tier == 2:
        # Faceted round flask with a bubble and two distinct liquid layers.
        c.rect((6, 7, 9, 8), c.accent)
        c.rect((6, 9, 9, 12), c.motif)
        c.poly([(5, 12), (10, 12), (13, 16), (13, 21),
                (10, 24), (5, 24), (2, 21), (2, 16)], c.motif)
        c.poly([(5, 14), (10, 14), (11, 16), (11, 21),
                (9, 22), (6, 22), (4, 20), (4, 16)], c.shadow)
        c.rect((4, 18, 11, 20), c.base)
        c.rect((4, 20, 11, 21), c.accent)
        c.rect((6, 22, 9, 22), c.accent)
        c.rect((6, 15, 7, 16), c.motif)
        return
    if tier == 3:
        # Two chambers and a brass return coil, all part of the vessel itself.
        c.line([(9, 11), (12, 11), (12, 14), (14, 14),
                (14, 18), (12, 18), (12, 22), (10, 22)], c.accent, 1)
        c.rect((5, 5, 8, 6), c.accent)
        c.rect((6, 7, 7, 9), c.motif)
        c.poly([(5, 9), (8, 9), (9, 10), (9, 12),
                (8, 13), (5, 13), (4, 12), (4, 10)], c.motif)
        c.rect((6, 10, 7, 11), c.shadow)
        c.rect((6, 12, 7, 12), c.accent)
        c.rect((6, 14, 7, 16), c.motif)
        c.poly([(4, 16), (9, 16), (11, 18), (11, 23),
                (9, 25), (4, 25), (2, 23), (2, 18)], c.motif)
        c.poly([(4, 18), (9, 18), (10, 19), (10, 22),
                (8, 24), (5, 24), (4, 22)], c.shadow)
        c.rect((4, 21, 10, 22), c.accent)
        c.rect((5, 23, 9, 23), c.accent)
        c.rect((6, 24, 8, 24), c.accent)
        c.rect((6, 19, 7, 20), c.motif)
        return
    # Tier I stays byte-identical to the approved simple square flask.
    left, right = 4, 11
    c.rect((6, 9, 9, 10), c.accent)
    c.rect((6, 11, 9, 13), c.motif)
    c.rect((left + 1, 13, right - 1, 14), c.motif)
    c.rect((left, 15, right, 22), c.motif)
    # Broad liquid window, with a light glass edge retained on every side.
    c.rect((left + 2, 18, right - 2, 20), c.base)


def loose_bones(c, tier):
    # Round ivory cranium, black sockets and separated teeth: no fleshy face.
    # A jagged fracture and detached bones make the defeated skeleton explicit.
    if tier < 3:
        rows = [
            "..BBBBBB..", ".BBBBDBBB.", "BBBBBDBBBB", "BBBBDBBBBB",
            "BDDDBBDDDB", "BDDDBBDDDB", "BBBBBBBBBB", ".BBBDBBBB.",
            "..BBBBBB..", "..B.BB.B..",
        ]
        c.stamp(rows, 3, 11 if tier == 1 else 8,
                {"B": c.motif, "D": c.shadow})
    else:
        c.stamp([
            "...BBBBBB...", "..BBBBDBBB..", ".BBBBBDBBBB.", "BBBBBDBBBBBB",
            "BBBBBDBBBBBB", "BBDDDBBDDDBB", "BBDDDBBDDDBB", ".BBBBBBBBBB.",
            "..BBBDBBBB..", "..BBBBBBBB..", "...B.BB.B...",
        ], 2, 6, {"B": c.motif, "D": c.shadow})
    if tier == 2:
        c.stamp([
            "BB........BB", "BBBBB..BBBBB", "BBBB..BBBBBB", "BB........BB",
        ], 2, 22, {"B": c.motif})
    elif tier == 3:
        c.line([(3, 20), (12, 27)], c.motif, 2)
        c.line([(12, 20), (3, 27)], c.motif, 2)
        for x, y in ((2, 19), (11, 19), (2, 26), (11, 26)):
            c.rect((x, y, x + 2, y + 2), c.motif)
        # Both shafts are snapped apart at the crossing, not a pirate badge.
        c.poly([(7, 22), (9, 23), (7, 24), (8, 25), (6, 25), (6, 23)], c.base)


def stone_deaf(c, tier):
    if tier == 1:
        c.rect((3, 11, 12, 21), c.motif)
        c.line([(8, 11), (6, 15), (9, 17), (7, 21)], c.shadow, 2)
    else:
        c.poly([(2, 10), (7, 10), (5, 14), (7, 16),
                (5, 21), (2, 21)], c.motif)
        c.poly([(10, 11), (13, 11), (13, 22), (8, 22),
                (10, 17), (8, 15)], c.motif)
        c.hem(c.accent, 25, 2)
        c.hem(c.accent, 29, 2)


def final_notice(c, tier):
    c.rect((2, 9, 13, 24), c.shadow)
    c.rect((3, 9, 13, 23), c.accent)
    c.stamp([
        "RR.....RR", "RR.....RR", ".RR...RR.", "..RR.RR..",
        "...RRR...", "...RRR...", "...RRR...", "..RR.RR..",
        ".RR...RR.", "RR.....RR", "RR.....RR",
    ], 4, 11, {"R": c.motif})


def rust_in_peace(c, tier):
    if tier == 1:
        c.stamp([
            "..RRRRRRRR..", ".RRRRRRRRRR.", "RRR......RRR",
            "RR..SSSS..RR", "RR..SSSS..RR", "RR..SSSS..RR",
            "RR..SSSS..RR", "RRR......RRR", ".RRRRRRRRRR.",
            "..RRRRRRRR..",
        ], 2, 11, {"R": c.accent, "S": c.motif})
    else:
        # The right-hand tooth of a four-cardinal-tooth cog is absent.
        c.stamp([
            "....RRRR....", "....RRRR....", "..RRRRRRRR..",
            "..RRRRRRRR..", "RRRR....RR..", "RRRR.SS.RR..",
            "RRRR.SS.RR..", "RRRR....RR..", "..RRRRRRRR..",
            "..RRRRRRRR..", "....RRRR....", "....RRRR....",
        ], 2, 10, {"R": c.accent, "S": c.motif})
        c.hem(c.motif)


def no_more_orders(c, tier):
    c.stamp([
        "BB..........BB", "BB..........BB", "BB..........BB",
        "BB..........BB", "BB..........BB", "BB..........BB",
        "BB.BB.BB.BB.BB", "BB.BB.BB.BB.BB", "BBBBBBBBBBBBBB",
        ".BBBBBBBBBBBB.", "..BBBBBBBBBB..",
    ], 1, 11, {"B": c.motif})


def last_word(c, tier):
    c.stamp([
        "....GGGG....", "..GGGGGGGG..", ".GGGGGGGGGG.",
        ".GGGGGGGGGG.", "GGGGGGGGGGGG", "GGGGGGGGGGGG",
        "GGGGGGGGGGGG", "GGGGGGGGGGGG", ".GGGGGGGGGG.",
        ".GGGGGGGGGG.", "..GGGGGGGG..", "....GGGG....",
    ], 2, 10, {"G": c.motif})
    c.rect((1, 15, 14, 17), c.accent)


def grounded(c, tier):
    c.rect((2, 10, 13, 21), c.motif)
    c.stamp([
        "..SSSS....", ".SSSSSS.SS", "SSSSSSS.SS",
        "SSSSSSS.SS", ".SSSSSS.SS", "..SSSS....",
    ], 3, 13, {"S": c.shadow})


PAINTERS = {"plain_grey": plain}
for _family, _, _ in FAMILIES[1:]:
    PAINTERS[_family] = globals()[_family]


def rgb(color):
    return tuple(bytes.fromhex(color.removeprefix("#")))


def get_font(size):
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/dejavu-sans-mono-fonts/DejaVuSansMono.ttf",
    ):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


def contact_sheet(entries):
    columns, cw, ch = 7, 148, 180
    margin, top = 24, 88
    rows = (len(entries) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cw + margin * 2, top + rows * ch + 28),
                      "#181E22")
    d = ImageDraw.Draw(sheet)
    d.text((margin, 20), "GRUDGELANDS / CLOAKS", font=get_font(22), fill="#E9DDBF")
    d.text((margin, 53), "ROUND 33   /   41 APPEARANCES   /   OUTER FACE x4   /   NEAREST NEIGHBOUR",
           font=get_font(12), fill="#A3B1B6")
    for i, entry in enumerate(entries):
        x = margin + (i % columns) * cw
        y = top + (i // columns) * ch
        d.rectangle((x + 3, y + 2, x + cw - 5, y + ch - 8), fill="#242D32")
        d.text((x + 10, y + 7), f"{i + 1:02}", font=get_font(10), fill="#90A2AA")
        with Image.open(OUT / entry["file"]) as texture:
            face = texture.crop((0, 0, 16, 32))
            sheet.paste(face.resize((64, 128), Image.Resampling.NEAREST),
                        (x + (cw - 64) // 2, y + 12))
        label = entry["id"]
        font = get_font(11)
        text_width = d.textbbox((0, 0), label, font=font)[2]
        d.text((x + (cw - text_width) // 2, y + 149), label, font=font, fill="#E5E7DC")
    sheet.save(ROOT / "cloaks_sheet.png")


def comparison_sheet():
    # Grouping keeps each revised family together; first four are single edits.
    groups = [
        ["hunter_2", "hunter_3", "kingslayer_3", "honored_3"],
        ["zombie_slayer_1", "zombie_slayer_2", "zombie_slayer_3"],
        ["loose_bones_1", "loose_bones_2", "loose_bones_3"],
        ["bottle_service_2", "bottle_service_3"],
    ]
    margin, top, cw, ch = 24, 90, 196, 190
    sheet = Image.new("RGBA", (2 * margin + 4 * cw, top + 4 * ch + 20), "#181E22")
    d = ImageDraw.Draw(sheet)
    d.text((margin, 20), "GRUDGELANDS / CLOAKS / SECOND PASS",
           font=get_font(21), fill="#E9DDBF")
    d.text((margin, 54), "12 REDESIGNS   /   OLD LEFT, NEW RIGHT   /   OUTER FACE x4",
           font=get_font(12), fill="#A3B1B6")
    for row, ids in enumerate(groups):
        for col, id_ in enumerate(ids):
            x, y = margin + col * cw, top + row * ch
            d.rectangle((x + 2, y, x + cw - 6, y + ch - 8), fill="#242D32")
            old_bytes = base64.b64decode(FIRST_PASS_PNG[id_])
            assert hashlib.sha256(old_bytes).hexdigest() == FIRST_PASS_SHA256[id_]
            with Image.open(io.BytesIO(old_bytes)) as old, Image.open(
                    OUT / f"grug_achievements_cloak_{id_}.png") as new:
                for label, texture, dx in (("OLD", old, 22), ("NEW", new, 108)):
                    d.text((x + dx + 21, y + 7), label, font=get_font(10), fill="#90A2AA")
                    face = texture.crop((0, 0, 16, 32))
                    sheet.paste(face.resize((64, 128), Image.Resampling.NEAREST),
                                (x + dx, y + 24))
            font = get_font(12)
            width = d.textbbox((0, 0), id_, font=font)[2]
            d.text((x + (cw - width) // 2, y + 161), id_, font=font, fill="#E5E7DC")
    sheet.save(ROOT / "cloaks_sheet_v2.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    entries = []
    for family, tiers, proposal in FAMILIES:
        for tier in range(1, tiers + 1):
            id_ = family if family == "plain_grey" else f"{family}_{tier}"
            c = Cloth(family, tier)
            PAINTERS[family](c, tier)
            texture = c.finish()
            filename = f"grug_achievements_cloak_{id_}.png"
            path = OUT / filename
            encoded = io.BytesIO()
            texture.save(encoded, format="PNG", optimize=True)
            data = encoded.getvalue()
            if id_ not in FIRST_PASS_PNG:
                assert hashlib.sha256(data).hexdigest() == FIRST_PASS_SHA256[id_], id_
                if path.exists():
                    assert hashlib.sha256(path.read_bytes()).hexdigest() == FIRST_PASS_SHA256[id_], id_
            # No write at all for already-correct files, including all 29 originals.
            if not path.exists() or path.read_bytes() != data:
                path.write_bytes(data)
            entries.append({"id": id_, "file": filename,
                            "proposal": f"{proposal}.{tier}" if proposal else None,
                            "palette": c.palette, "edge": c.edge})

    assert len(entries) == 41
    assert {p.name for p in OUT.iterdir()} == {e["file"] for e in entries}
    pixel_hashes = set()
    for entry in entries:
        path = OUT / entry["file"]
        with Image.open(path) as texture:
            assert texture.format == "PNG" and texture.mode == "RGBA"
            assert texture.size == (32, 32)
            assert texture.getchannel("A").getextrema() == (255, 255)
            allowed = {rgb(color) + (255,) for color in entry["palette"]}
            assert {color for _, color in texture.getcolors(1024)} <= allowed
            edge = rgb(entry["edge"]) + (255,)
            for x in range(16):
                assert texture.getpixel((x, 0)) == edge
                assert texture.getpixel((x, 31)) == edge
            for y in range(32):
                assert texture.getpixel((0, y)) == edge
                assert texture.getpixel((15, y)) == edge
            lining = texture.crop((16, 0, 32, 32))
            assert lining.getcolors(512) == [(512, rgb(entry["palette"][1]) + (255,))]
            digest = hashlib.sha256(texture.tobytes()).hexdigest()
            assert digest not in pixel_hashes, entry["id"]
            pixel_hashes.add(digest)
            entry["pixel_sha256"] = digest
        entry["file_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    contact_sheet(entries)
    comparison_sheet()
    changed = {e["id"] for e in entries
               if e["file_sha256"] != FIRST_PASS_SHA256[e["id"]]}
    assert changed == set(FIRST_PASS_PNG), changed
    print("PASS: 41 unique 32x32 RGBA PNGs; approved palettes plus revised hunter greens;")
    print("      opaque faces, continuous one-pixel edges, solid dark linings.")
    print("PASS: exactly 12 repainted textures; all other 29 first-pass PNG hashes unchanged.")
    print("Written: cloaks_sheet.png (41) and cloaks_sheet_v2.png (12 old/new pairs at x4).")
    for entry in entries:
        if entry["id"] in changed:
            print(entry["file"], entry["file_sha256"])



if __name__ == "__main__":
    main()

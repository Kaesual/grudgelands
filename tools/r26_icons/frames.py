#!/usr/bin/env python3
"""Reproduce the three CC0 status frames; run from any working directory."""
from pathlib import Path
from PIL import Image, ImageColor, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
COLORS = {"buff": "#4caf50", "debuff": "#c41e3a", "neutral": "#ffd100"}


def make_frame(category):
    image = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ImageDraw.Draw(image).rectangle((0, 0, 63, 63),
                                   outline=ImageColor.getrgb(COLORS[category]) + (255,),
                                   width=3)
    return image


def main():
    directory = ROOT / "mods/CORE/grug_core/textures"
    directory.mkdir(parents=True, exist_ok=True)
    for category in COLORS:
        make_frame(category).save(directory / f"grug_status_frame_{category}.png",
                                  optimize=True)


if __name__ == "__main__":
    main()

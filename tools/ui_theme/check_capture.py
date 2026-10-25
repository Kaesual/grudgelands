#!/usr/bin/env python3
"""Reject incomplete/blank real-client captures before building review sheets."""
from pathlib import Path
from PIL import Image, ImageStat
import sys
root = Path(sys.argv[1])
for scene in ("dark", "bright"):
    for page in ("inventory", "achievements", "talents", "crafting", "chest", "quest", "map", "privileged"):
        path = root / (scene + "_" + page + ".png")
        image = Image.open(path).convert("RGB")
        assert max(ImageStat.Stat(image).stddev) > 1, f"Blank capture: {path}"
print("Capture integrity: 16 nonblank views")

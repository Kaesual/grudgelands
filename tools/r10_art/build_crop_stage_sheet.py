from pathlib import Path
from PIL import Image, ImageDraw
import sys

root = Path(sys.argv[1])
keys = ("wild_grain", "carrot", "cassava", "wild_onion", "fire_pepper",
        "pumpkin", "blightberry", "sunberry", "jungle_berry", "frost_melon",
        "sugar_cane", "bamboo_shoot", "cave_cap", "salt_crust", "ember_moss",
        "potato", "corn")
source = root / "mods/ITEMS/grug_farming/textures"
sheet = Image.new("RGBA", (384, len(keys) * 100), "white")
draw = ImageDraw.Draw(sheet)
for row, key in enumerate(keys):
    y = row * 100
    draw.text((4, y + 2), key, fill="black")
    for stage in range(1, 5):
        image = Image.open(source / f"grug_farming_{key}_{stage}.png").convert("RGBA")
        if key == "salt_crust": image = image.crop((0, 0, 16, 16))
        image = image.resize((64, 64), Image.Resampling.NEAREST)
        x = 8 + (stage - 1) * 94
        draw.text((x, y + 18), str(stage), fill="black")
        sheet.alpha_composite(image, (x + 14, y + 30))
sheet.convert("RGB").save(root / "docs/research/r10-visuals/crop-stages-sheet.png")

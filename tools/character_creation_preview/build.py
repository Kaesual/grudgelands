#!/usr/bin/env python3
"""Build a self-contained, offline layout study. Does not change the game.

Run from any directory: python3 tools/character_creation_preview/build.py
Uses the shipped look catalogue, texture layers, UI icons and preview geometry.
Landscape compositions and prose in the HTML are proposals, not game design.
"""
import base64
import hashlib
import io
import json
import re
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def uri(path):
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


# Execute only the pure look catalogue; serialize its actual option records.
lua = r'''
grug_visuals = {}
dofile("mods/PLAYER/grug_visuals/looks.lua")
local function encode(v)
    if type(v) == "string" then return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"' end
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    if #v > 0 then
        for _, x in ipairs(v) do parts[#parts + 1] = encode(x) end
        return '[' .. table.concat(parts, ',') .. ']'
    end
    local keys = {}
    for key in pairs(v) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts + 1] = encode(key) .. ':' .. encode(v[key]) end
    return '{' .. table.concat(parts, ',') .. '}'
end
print(encode(grug_visuals.LOOKS))
'''
looks = json.loads(subprocess.check_output(["luajit", "-e", lua], cwd=ROOT, text=True))
images = {}
scene_build = json.loads((HERE / "scene-build.json").read_text())
backgrounds = {}
portraits = {}
for race, scene in scene_build.items():
    png = (HERE / "renders" / (race + ".png")).read_bytes()
    receipt = json.loads((HERE / "renders" / (race + ".json")).read_text())
    assert receipt["input"] == scene["render_input"], "Re-render stale scene: " + race
    assert receipt["output"] == hashlib.sha256(png).hexdigest(), "Changed render: " + race
    with Image.open(io.BytesIO(png)) as original:
        image = original.convert("RGB")
    buf = io.BytesIO()
    image.save(buf, format="WEBP", lossless=True, method=6)
    (HERE / "renders" / (race + ".webp")).write_bytes(buf.getvalue())
    images["background_" + race] = "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()
    backgrounds[race] = image
    spec = json.loads((HERE / "scenes" / (race + ".json")).read_text())
    recipe = hashlib.sha256(json.dumps(spec, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    assert recipe == scene["recipe"], "Rebuild changed scene before embedding its camera: " + race
    if "portrait" in spec:
        portraits[race] = {"spec": spec, "width": image.width, "height": image.height}

# A compact still sheet for comparing the six authored scenes outside the UI.
sheet = Image.new("RGB", (1500, 1264), "#101b1c")
draw = ImageDraw.Draw(sheet)
font = ImageFont.load_default(size=22)
small = ImageFont.load_default(size=14)
draw.text((24, 18), "GRUDGELANDS / CHARACTER BACKDROPS", font=font, fill="#e1d1ae")
draw.text((24, 50), "Saved block scenes · shared building renderer · refined pixel-art study", font=small, fill="#a4b5a9")
for i, race in enumerate(("human", "dwarf", "elf", "orc", "troll", "undead")):
    x, y = (i % 3) * 500, 85 + (i // 3) * 590
    draw.text((x + 16, y), race.title(), font=font, fill="#e1d1ae")
    thumb = backgrounds[race].resize((468, 546), Image.Resampling.NEAREST)
    sheet.paste(thumb, (x + 16, y + 32))
sheet.save(HERE / "renders/contact-sheet.png")
# Keep earlier local review links useful; the PNG is the lossless review image.
sheet.save(HERE / "renders/contact-sheet.jpg", quality=100, subsampling=0)


def collect(value):
    if isinstance(value, dict):
        for entry in value.values():
            collect(entry)
    elif isinstance(value, list):
        for entry in value:
            collect(entry)
    elif isinstance(value, str) and value.endswith(".png"):
        images[value] = uri(ROOT / "mods/PLAYER/grug_visuals/textures" / value)


collect(looks)
images["grug_visuals_skin_mask.png"] = uri(ROOT / "mods/PLAYER/grug_visuals/textures/grug_visuals_skin_mask.png")
for race in looks:
    images["race_" + race] = uri(ROOT / "mods/PLAYER/grug_classes/textures" / ("grug_race_" + race + ".png"))
for faction in ("accord", "throng"):
    images["banner_" + faction] = uri(ROOT / "mods/MAPGEN/grug_mapgen/textures" / ("grug_mapgen_faction_banner_" + faction + ".png"))

skills = {}
for cls in ("warrior", "mage", "priest", "scout"):
    images["class_" + cls] = uri(ROOT / "mods/PLAYER/grug_classes/textures" / ("grug_class_" + cls + ".png"))
    source = ROOT / "mods/PLAYER/grug_abilities" / ("scout.lua" if cls == "scout" else "kits_" + cls + ".lua")
    rows = []
    seen = set()
    if cls in ("warrior", "scout"):
        rows.append({"id": "strike", "name": "Strike", "group": "Starting skills"})
        seen.add("strike")
    # Each shipped registration starts with its literal identity fields.
    for block in source.read_text().split("grug_abilities.register_ability({")[1:]:
        identity = block[:block.find("description") if "description" in block else 650]
        def field(key):
            match = re.search(r'\b' + key + r'\s*=\s*"([^"\n]+)"', identity)
            return match.group(1) if match else None
        sid, name, talent = field("id"), field("name"), field("talent")
        if not sid or not name or sid in seen:
            continue
        seen.add(sid)
        prefix = talent.split("_")[0] if talent else ""
        group = {"bulwark": "Bulwark", "ruin": "Ruin", "ember": "Ember", "rime": "Rime",
                 "mercy": "Mercy", "reckoning": "Reckoning", "quarry": "Quarry", "veil": "Veil"}.get(prefix, "Starting skills")
        rows.append({"id": sid, "name": name, "group": group})
    for row in rows:
        images["skill_" + row["id"]] = uri(ROOT / "mods/PLAYER/grug_abilities/textures" / ("grug_abilities_skill_" + row["id"] + ".png"))
    skills[cls] = rows

catalog = json.loads((ROOT / "tools/r54_armor/data/catalog.json").read_text())
data = {"looks": looks, "images": images, "skills": skills, "body": catalog["body"], "bones": catalog["bones"], "portraits": portraits}
page = (HERE / "layout.html.in").read_text()
page = page.replace("__PORTRAIT__", (HERE / "portrait.js").read_text())
page = page.replace("__DATA__", json.dumps(data, ensure_ascii=False, separators=(",", ":")))
# Reuse the existing vendored library; keep its licence notice in the artifact.
page = page.replace("__THREE__", (ROOT / "tools/r54_armor/vendor/three.min.js").read_text())
target = HERE / "preview.html"
target.write_text(page)
print(f"Built {target}: {target.stat().st_size:,} bytes; six races, four classes, {sum(map(len, skills.values()))} skill rows")

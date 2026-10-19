#!/usr/bin/env python3
"""Package ARTB pass 2, rebuild review sheets, and audit the node-list roster.

Run with python3 -I. Generation uses separate built-in image_gen calls; this
script prepares prompts and records their outputs, with no API/network calls.
"""

import argparse
import copy
import hashlib
import io
import json
import re
import shutil
import subprocess
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, __version__ as pillow_version


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
DROP = HERE / "drop-02"
MANIFEST = DROP / "manifest.json"
NODE_LIST = ROOT / "docs/planning/class-redesign/node-list.md"
TREES = ("ember", "rime", "bulwark", "ruin", "mercy", "reckoning", "quarry", "veil")
FAMILIES = {
    "ember": "fiery_spark fireball flame_lance meteor fire_rain",
    "rime": "ice_wave cold_spark ice_nova blink rime_mantle winter_field",
    "bulwark": "retort taunt bellow hold_ground unbroken",
    "ruin": "charge mighty_blow hamstring broadstroke ruination",
    "mercy": "heal shield_spell mend hearten haven",
    "reckoning": "smite rebuke word_of_ruin censure final_word",
    "quarry": "loose sidestep sprint true_draw snare_shot split_shot arrowfall",
    "veil": "bladecraft opening parry flourish close_dance",
    "neutral": "strike",
}
PALETTES = {
    "ember": "orange #F68B28, red #BC321E, warm ivory glint on charcoal #171619",
    "rime": "pale blue #A5D9F2, cold white #F1FBFF on deep navy #0A1930",
    "bulwark": "steel #99A3AE, bronze #B08A4D on slate #171D26; steel and bronze dominate",
    "ruin": "crimson #B52F3B, pale hot edges on near-black #140E15",
    "mercy": "warm gold #E8BC5C, soft ivory #FFF0CE on warm brown #251B17",
    "reckoning": "hard gold #D5AD52, white #FFF6DD, a crimson #A32A32 accent on umber-black #1E1615",
    "quarry": "green #91AA55, earth brown #94603A, ivory glints on dark forest #10251D",
    "veil": "indigo #343568, violet #8162B1, silver #DFE4ED on indigo-black #100F22",
    "neutral": "neutral silver steel #B8C2CC and ivory glints on matte charcoal #171D26",
}
BG_VARIANTS = {t: (3 if t in ("ember", "bulwark", "veil") else 1) for t in TREES}
REUSED_TALENTS = {"F1": "f1", "R10": "r10", "B2": "b2", "M7": "m7", "RK1": "rk1", "Q2": "q2"}
REUSED_SKILLS = {"fiery_spark", "cold_spark", "fireball", "smite", "bladecraft", "arrowfall"}
EDIT_BASES = {
    "skill.loose": "skill.bladecraft",
    "skill.ice_nova": "skill.ice_wave",
    "skill.retort": "skill.strike",
    "skill.bellow": "skill.taunt",
    "skill.broadstroke": "skill.mighty_blow",
}
EDIT_RULES = {
    "skill.loose": "Use the project's own picked Bladecraft image as the edit target. Preserve the curved bow's exact position, angle, scale and outer contour. Replace the diagonal silver blade with a single arrow leaving the bowstring in that same diagonal position, point upper-right, feathers lower-left. This is the base-skill counterpart of the picked transform. Change the violet palette to Quarry green and earth brown. Keep the bow and diagonal projectile as the same recognizable silhouette; no blade remains.",
    "skill.ice_nova": "Use the project's own Ice Wave as the edit target. Preserve its foreground fan of broad ice spikes exactly in position, angle, scale and silhouette. Extend that same fan backward into an elliptical ring of ice spikes bursting outward. Keep the foreground fan the dominant contour and the same pale-blue luminous core; add only a short rear arc to signal the radial transform.",
    "skill.retort": "Use the project's own Strike as the edit target. Preserve the sword's exact position, angle, scale, outer contour and sweeping stroke. Add a simple raised steel shield behind the lower half of that sword, with one bronze impact glint where the sword strikes back off it. Keep the sword unobscured and dominant. Apply the Bulwark steel/bronze palette, never crimson fury.",
    "skill.bellow": "Use the project's own Taunt as the edit target. Keep the beckoning gauntlet's exact position, scale, angle and outer contour in the foreground. Reveal a simple roaring helmeted head just behind the gauntlet and two broad bronze sound arcs. Preserve the gauntlet as the shared identifying silhouette while the helmet and spreading sound explain the area transform. No tiny teeth or detailed face.",
    "skill.broadstroke": "Use the project's own Mighty Blow as the edit target. Preserve the heavy two-handed sword and gripping gauntlets exactly in position, angle, scale and outer contour. Widen the impact stroke into a broad horizontal crimson sweep across the lower third, touching exactly three simple dark target silhouettes. The same sword remains the dominant silhouette; the wider arc signals the transform.",
}
DETAILS = {
    "skill.ice_wave": "One broad low fan of five large pale-blue ice shards surges from a luminous center at (50%,70%); tall central shard and two outward-slanted spikes each side. Fan fills 80% width, on a shallow elliptical frost sweep. Preserve this layout for the later Ice Nova transform.",
    "skill.strike": "A single plain broad steel sword, hilt lower-left at (24%,78%), tip upper-right at (78%,20%), with one broad pale curved swing behind it. Blade fills 70% of the square. No magic, shield or heraldry; this is the base silhouette for Retort.",
    "skill.taunt": "A large steel gauntlet in three-quarter view, wrist lower-center, beckoning curled fingers upper-center, bronze knuckles. One simple curved beckoning gesture accent; hand occupies 65% of square. This gauntlet remains the foreground silhouette in the later Bellow transform.",
    "skill.mighty_blow": "One heavy two-handed sword in an overhead downward smash: broad blade runs diagonally from gripping gauntlets at (65%,20%) to an impact at (28%,78%). A pale hot edge and one thick crimson descending stroke; no full warrior. Keep this sword contour for Broadstroke.",
    "skill.word_of_ruin": "A single abstract NON-ALPHABETIC angular gold seal, visibly split by a bold crack, with a broad light ribbon curving back toward the lower-left. Convey a spoken magical mark without any actual rune, glyph, letter or writing.",
    "talent.unfinished_sentence": "A single torn ivory scroll with two broad trailing ribbons of gold light, suggesting unfinished utterance. The scroll is completely blank: replace the motif's script with flowing light, no writing or letterlike marks.",
    "talent.quiet_care": "One muted gold bell with its clapper wrapped in a broad ivory cloth strip; still, gentle light, no sound lines. Single joined motif, no face or additional hand.",
    "talent.firm_aim": "One taut bowstring with a broad four-spoke aiming reticle and central ivory glint; no writing or numerals.",
    "talent.follow_the_line": "Exactly two broad parallel arrows aligned along one short dashed diagonal trajectory, distinct arrowheads with enough space to count them at 32 px.",
    "skill.hearten": "Exactly four small simplified ivory bust silhouettes in one compact cluster, enclosed by one warm gold light ring. Countable heads, no faces or extra crowd.",
    "skill.flourish": "Exactly three broad silver blade arcs forming a spinning fan, violet inner shadow and one shared luminous center; no extra blades.",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def snake(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def roster():
    """Read actual section 2 modifier/window rows and all section 3 skill rows."""
    rows, skill_nodes = [], {}
    section, tree, class_name = None, None, None
    for line in NODE_LIST.read_text().splitlines():
        if line.startswith("## "):
            section = line.split(".", 1)[0].removeprefix("## ")
        if section == "2" and line.startswith("### "):
            tree = line.split()[1].lower()
            class_name = line.split("(")[1].split(",")[0]
        if not line.startswith("| "):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if section == "2" and re.fullmatch(r"(?:F|R|B|U|M|RK|Q|V)\d+", cells[0]):
            code, name, _, _, _, kind, _, motif = cells
            skill_id = "shield_spell" if name == "Shield" else snake(name)
            if kind in ("modifier", "window"):
                rows.append(dict(key="talent." + snake(name), kind="talent", tree=tree,
                                 family=tree, node=code, node_type=kind, name=name,
                                 class_name=class_name, motif=motif))
            else:
                skill_nodes[skill_id] = code
        elif section == "3" and cells[0] in ("Mage", "Warrior", "Priest", "Scout"):
            cl, name, unlock, old_family, shipped, motif = cells
            ability_id = "shield_spell" if name == "Shield" else snake(name)
            family = next(t for t, ids in FAMILIES.items() if ability_id in ids.split())
            rows.append(dict(key="skill." + ability_id, kind="skill", tree=family,
                             family=family, skill=ability_id, node=skill_nodes.get(ability_id),
                             name=name, class_name=cl, motif=motif, origin=unlock))
    assert len(rows) == 118 and Counter(r["kind"] for r in rows) == {"talent": 74, "skill": 44}
    assert Counter(r["node_type"] for r in rows if r["kind"] == "talent") == {"modifier": 71, "window": 3}
    assert len({r["key"] for r in rows}) == 118
    assert {r["skill"] for r in rows if r["kind"] == "skill"} == set(" ".join(FAMILIES.values()).split())
    return rows


def make_prompt(entry, style):
    key, kind = entry["key"], entry["kind"]
    edit = key in EDIT_RULES
    prompt = (f"Use case: {'precise-object-edit' if edit else 'stylized-concept'}. Asset type: ONE square dark fantasy game "
              f"{kind.upper()} icon for Grudgelands, ultimately reduced to 64x64 and displayed at 32 px. ")
    prompt += "Subject: " + (EDIT_RULES[key] if edit else DETAILS.get(key, entry["motif"]).rstrip(".") + ".")
    prompt += " Style A, 'Painted embers': " + style["render"]
    prompt += " Palette: " + PALETTES[entry["family"]] + "."
    if kind == "talent":
        prompt += " Composition: " + style["frame"] + " The outer square corners remain opaque dark matte field."
    else:
        prompt += " Full-bleed dark painted background; skill subject occupies 75-85% of square. NO frame, rim, badge, medallion or border."
    prompt += (" One strong main silhouette with at most one semantic accent; broad painted facets and a luminous focal core, "
               "deep matte shadows, minimal texture. No decorative additions or fine scattered particles. "
               "Constraints: unmistakable motif at 32 px, one opaque square image, no text, letters, numerals, "
               "writing, logos, watermark, UI or panels. No third-party image supplied.")
    return prompt


def save(data):
    MANIFEST.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def initialize():
    if MANIFEST.exists():
        raise ValueError("Manifest already exists; use --pending or --record-source")
    old = json.loads((HERE / "drop-01/manifest.json").read_text())
    old_assets = {e["key"]: e for e in old["assets"] if e["style"] == "A"}
    data = dict(schema=2, date="2026-10-19", author="GPT-6 Astra", style="A / Painted embers",
                tool="built-in image_gen.imagegen; one individual prompt/call per new image",
                license="CC0-1.0 (project dedication, to the extent rights exist)",
                upgrade="compatible; staged media only", status="Generation in progress",
                node_list="docs/planning/class-redesign/node-list.md", node_list_sha256=digest(NODE_LIST),
                style_rules="../drop-01/STYLE.md", palette_ruling="2026-10-19: one family per tree; Strike neutral steel",
                redrawn_samples=[], assets=[], backgrounds=[], previews=[])
    for entry in roster():
        entry["path"] = f'{entry["kind"]}s/{entry["key"]}.png'
        entry["reused_from"] = None
        entry["prompt"] = make_prompt(entry, old["styles"]["A"])
        entry["source"] = None
        entry["sha256"] = None
        entry["processing"] = None
        key = None
        if entry["kind"] == "talent" and entry["node"] in REUSED_TALENTS:
            key = "talent." + REUSED_TALENTS[entry["node"]]
        elif entry.get("skill") in REUSED_SKILLS:
            key = entry["key"]
        target = DROP / entry["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        if key:
            old_entry = old_assets[key]
            source = HERE / "drop-01" / old_entry["path"]
            shutil.copyfile(source, target)
            for field in ("prompt", "source", "source_sha256", "processing", "reference_sources"):
                if field in old_entry:
                    entry[field] = copy.deepcopy(old_entry[field])
            entry["reused_from"] = "../drop-01/" + old_entry["path"]
            entry["reuse_processing"] = "Byte-for-byte copy of picked style A final; no resampling or recoloring"
            entry["sha256"] = digest(target)
            assert entry["sha256"] == old_entry["sha256"]
        if entry["key"] in EDIT_BASES:
            entry["edit_base"] = EDIT_BASES[entry["key"]]
        data["assets"].append(entry)
    save(data)
    print("Initialized 118 entries; copied 12 picked samples byte-for-byte; 106 pending")


def record_source(data, key, source, revision_prompt=None):
    entry = next(e for e in data["assets"] if e["key"] == key)
    target = DROP / entry["path"]
    if target.exists() and revision_prompt is None:
        raise ValueError(f"Refusing to overwrite final: {target}")
    if revision_prompt is not None:
        if entry["reused_from"]:
            raise ValueError("Picked samples must remain unchanged")
        previous = {k: copy.deepcopy(entry[k]) for k in
                    ("prompt", "source", "source_sha256", "processing", "sha256", "reference_sources")
                    if k in entry}
        entry.setdefault("previous_versions", []).append(previous)
        entry["prompt"] = Path(revision_prompt).read_text().strip()
    source = Path(source).resolve()
    with Image.open(source) as original:
        original.load()
        if original.width != original.height:
            raise ValueError(f"Expected square source: {source}")
        if "A" in original.getbands() and original.getchannel("A").getextrema() != (255, 255):
            raise ValueError(f"Unexpected transparency: {source}")
        entry["source"] = str(source)
        entry["source_sha256"] = digest(source)
        entry["processing"] = dict(tool="Pillow", version=pillow_version,
            source_size=list(original.size), source_mode=original.mode,
            operations=["convert RGB", "resize 64x64 with Image.Resampling.LANCZOS",
                        "save PNG, optimize=True, no source metadata"],
            crop=None, recolor=False, composite=False, output_size=[64, 64], output_mode="RGB")
        final = original.convert("RGB").resize((64, 64), Image.Resampling.LANCZOS)
        final.info.clear()
        final.save(target, format="PNG", optimize=True)
    if entry.get("edit_base"):
        base = next(e for e in data["assets"] if e["key"] == entry["edit_base"])
        entry["reference_sources"] = [base["source"]]
    entry["sha256"] = digest(target)
    save(data)
    print(f"Recorded {key}; {sum(bool(e['sha256']) for e in data['assets'])}/118 complete")


def pending(data):
    lookup = {e["key"]: e for e in data["assets"]}
    ready = []
    for entry in data["assets"]:
        if entry["sha256"]:
            continue
        row = {k: entry[k] for k in ("key", "prompt")}
        if entry.get("edit_base"):
            base = lookup[entry["edit_base"]]
            if not base["source"]:
                continue
            row["reference_sources"] = [base["source"]]
        ready.append(row)
    print(json.dumps(ready))


def read_backgrounds(data):
    if data["backgrounds"]:
        return
    commit = subprocess.check_output(["git", "rev-parse", "r52-arta"], cwd=ROOT, text=True).strip()
    for tree in TREES:
        path = f"tools/r52_art/arta/drop-01/bg/{tree}_v{BG_VARIANTS[tree]}.png"
        result = subprocess.run(["git", "show", f"{commit}:{path}"], cwd=ROOT, capture_output=True)
        if result.returncode:
            data["backgrounds"].append(dict(tree=tree, unavailable=True, path=path))
            continue
        with Image.open(io.BytesIO(result.stdout)) as original:
            # Exact source-size crop; no stretching or tint alteration.
            w, h = original.size
            box = [0, max(0, h // 2 - 160), w, min(h, h // 2 + 160)]
            crop = original.convert("RGB").crop(box)
        dest = DROP / "background-crops" / f"{tree}.png"
        dest.parent.mkdir(exist_ok=True)
        crop.save(dest, optimize=True)
        data["backgrounds"].append(dict(tree=tree, git_commit=commit, source_path=path,
            source_sha256=hashlib.sha256(result.stdout).hexdigest(), crop_box=box,
            path=dest.relative_to(DROP).as_posix(), sha256=digest(dest),
            license="CC0-1.0", author="GPT-6 Astra / ARTA", processing="RGB conversion; exact crop; optimized PNG"))
    save(data)


def font(size):
    return ImageFont.load_default(size=size)


def wrap(draw, text, width, size):
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if line and draw.textlength(trial, font=font(size)) > width:
            lines.append(line)
            line = word
        else:
            line = trial
    return lines + [line]


def build_sheets(data):
    read_backgrounds(data)
    data["previews"] = []
    for tree in TREES:
        entries = [e for e in data["assets"] if e["tree"] == tree]
        if tree == "bulwark":
            entries += [e for e in data["assets"] if e["key"] == "skill.strike"]
        width, cols, cellw, rowh = 1100, 5, 216, 230
        height = 110 + ((len(entries) + cols - 1) // cols) * rowh + 40
        sheet = Image.new("RGB", (width, height), "#11151c")
        d = ImageDraw.Draw(sheet)
        d.text((24, 18), f"{tree.upper()} / PAINTED EMBERS", font=font(26), fill="#f0e7d6")
        d.text((24, 56), "Each row: dark strip / picked tree crop. Icons at actual 64 px and 32 px. View at 100%.", font=font(15), fill="#b7bdc8")
        bg = next(b for b in data["backgrounds"] if b["tree"] == tree)
        crop = None if bg.get("unavailable") else Image.open(DROP / bg["path"]).convert("RGB")
        for i, entry in enumerate(entries):
            x, y = 10 + (i % cols) * cellw, 105 + (i // cols) * rowh
            prefix = entry.get("node") or "STARTER"
            if entry["key"] == "skill.strike":
                prefix = "UNIVERSAL / NEUTRAL"
            title = f"{prefix}  {entry['name']}"
            for j, line in enumerate(wrap(d, title, cellw - 14, 13)):
                d.text((x + 6, y + j * 16), line, font=font(13), fill="#efe6d4")
            d.text((x + 6, y + 35), entry["kind"].upper() + (" / PICKED SAMPLE" if entry["reused_from"] else ""), font=font(10), fill="#a4acb9")
            for strip in range(2 if crop else 1):
                sy = y + 52 + strip * 82
                d.rectangle((x + 4, sy, x + cellw - 5, sy + 76), fill="#202731")
                if strip:
                    # Tile the exact crop so every cell uses native background pixels.
                    for tx in range(x + 4, x + cellw - 5, crop.width):
                        tile = crop.crop((0, 0, min(crop.width, x + cellw - 5 - tx), 77))
                        sheet.paste(tile, (tx, sy))
                with Image.open(DROP / entry["path"]) as icon:
                    sheet.paste(icon, (x + 22, sy + 6))
                    sheet.paste(icon.resize((32, 32), Image.Resampling.LANCZOS), (x + 115, sy + 22))
                d.text((x + 164, sy + 27), "64 / 32", font=font(10), fill="#d8d6d1")
        d.text((24, height - 25), "Staged art / offline review only / CC0-1.0 / Round 52 ARTB pass 2", font=font(12), fill="#a4acb9")
        path = DROP / f"sheet-{tree}.png"
        sheet.save(path, optimize=True)
        data["previews"].append(dict(path=path.name, sha256=digest(path), size=list(sheet.size),
                                     kind="tree contact sheet", tree=tree))
    hotbars(data)
    save(data)


def hotbars(data):
    kits = {
        "Mage": "fiery_spark ice_wave fireball flame_lance meteor blink rime_mantle winter_field",
        "Warrior": "strike charge mighty_blow hamstring taunt hold_ground retort unbroken",
        "Priest": "smite heal shield_spell mend hearten rebuke censure final_word",
        "Scout": "loose sidestep sprint true_draw snare_shot opening parry close_dance",
    }
    lookup = {e.get("skill"): e for e in data["assets"] if e["kind"] == "skill"}
    sheet = Image.new("RGB", (1050, 690), "#11151c")
    d = ImageDraw.Draw(sheet)
    d.text((24, 18), "GRUDGELANDS / FOUR CLASS HOTBARS", font=font(26), fill="#f0e7d6")
    d.text((24, 58), "48 px icons / eight slots per class / visual mockups, not proposed builds or desktop/web screenshots", font=font(14), fill="#b7bdc8")
    for row, (cl, ids) in enumerate(kits.items()):
        y = 115 + row * 140
        d.text((24, y + 10), cl.upper(), font=font(19), fill="#dbc08f")
        for i, skill in enumerate(ids.split()):
            entry = lookup[skill]
            x = 155 + i * 109
            d.rectangle((x, y, x + 55, y + 55), fill="#080b10", outline="#887a60", width=2)
            with Image.open(DROP / entry["path"]) as im:
                sheet.paste(im.resize((48, 48), Image.Resampling.LANCZOS), (x + 4, y + 4))
            d.text((x + 25, y + 60), str(i + 1), font=font(11), fill="#a4acb9")
            for j, line in enumerate(wrap(d, entry["name"], 103, 12)):
                d.text((x, y + 80 + j * 15), line, font=font(12), fill="#ddd9cc")
    path = DROP / "hotbars.png"
    sheet.save(path, optimize=True)
    data["previews"].append(dict(path=path.name, sha256=digest(path), size=list(sheet.size),
                                 kind="four class hotbars", slots=kits))


def validate(data):
    expected = {e["key"]: e for e in roster()}
    assets = data["assets"]
    assert len(assets) == len(expected) == 118
    assert {e["key"] for e in assets} == set(expected)
    assert data["node_list_sha256"] == digest(NODE_LIST), "Node list changed; review roster and motifs"
    for e in assets:
        for field, value in expected[e["key"]].items():
            assert e[field] == value, (e["key"], field)
        assert e["path"] == f'{e["kind"]}s/{e["key"]}.png'
        path = DROP / e["path"]
        with Image.open(path) as im:
            im.load()
            assert im.format == "PNG" and im.mode == "RGB" and im.size == (64, 64), path
        assert digest(path) == e["sha256"], path
        assert e["prompt"] and e["source"] and e["source_sha256"] and e["processing"], path
        assert e["processing"]["output_mode"] == "RGB"
        assert e["processing"]["output_size"] == [64, 64]
        assert "resize 64x64 with Image.Resampling.LANCZOS" in e["processing"]["operations"]
        if e["reused_from"]:
            assert digest(DROP / e["reused_from"]) == e["sha256"], path
        if e.get("edit_base"):
            assert len(e["reference_sources"]) == 1
    assert sum(bool(e["reused_from"]) for e in assets) == 12
    files = {p.relative_to(DROP).as_posix() for kind in ("skills", "talents") for p in (DROP / kind).glob("*")}
    assert files == {e["path"] for e in assets}, "Unlisted or missing icons"
    assert len({e["sha256"] for e in assets}) == 118, "Duplicate final pixels"
    assert len(data["previews"]) == 9
    assert {p["path"] for p in data["previews"]} == {f"sheet-{t}.png" for t in TREES} | {"hotbars.png"}
    for entry in data["backgrounds"] + data["previews"]:
        if not entry.get("unavailable"):
            assert digest(DROP / entry["path"]) == entry["sha256"]
    assert len(data["backgrounds"]) == 8
    assert {b["tree"] for b in data["backgrounds"]} == set(TREES)
    for b in data["backgrounds"]:
        source_path = b.get("source_path", b.get("path"))
        assert source_path.endswith(f"/{b['tree']}_v{BG_VARIANTS[b['tree']]}.png")
    if data.get("status") == "Complete; awaiting the user's pick and integration":
        readme = (HERE / "README.md").read_text()
        for e in assets + data["backgrounds"] + data["previews"]:
            if not e.get("unavailable"):
                media_path = f"`drop-02/{e['path']}`"
                media_rows = [line for line in readme.splitlines() if line.startswith("| " + media_path + " |")]
                assert len(media_rows) == 1 and "CC0-1.0" in media_rows[0], media_path
    print("PASS: 118 unique icons = 74 talents (71 modifiers + 3 windows) + 44 skills; exact node-list coverage")
    print("PASS: opaque RGB PNG, 64x64, names, family mapping, prompts, processing, SHA-256, 12 exact sample copies, 9 previews")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    group = p.add_mutually_exclusive_group()
    group.add_argument("--init", action="store_true")
    group.add_argument("--pending", action="store_true")
    group.add_argument("--record-source", nargs=2, metavar=("KEY", "SOURCE"))
    group.add_argument("--revise-source", nargs=3, metavar=("KEY", "SOURCE", "PROMPT_FILE"))
    group.add_argument("--check", action="store_true")
    args = p.parse_args()
    if args.init:
        initialize()
        return
    data = json.loads(MANIFEST.read_text())
    if args.pending:
        pending(data)
    elif args.record_source:
        record_source(data, *args.record_source)
    elif args.revise_source:
        record_source(data, *args.revise_source)
    elif args.check:
        validate(data)
    else:
        build_sheets(data)
        validate(data)


if __name__ == "__main__":
    main()

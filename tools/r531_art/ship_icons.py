#!/usr/bin/env python3
"""Ship the 36 icons the user picked in Round 53 (0.53.1 lane ART).

The picks are recorded in the orchestration folder (`r53/astra-icons/decisions.md`,
pass-1 and pass-2 tables); PICKS below is that table. Each pick is copied byte for
byte over the shipped game file: a drop file of `tools/r53_art/icons/drop-01/` or
`drop-02/`, or for `old` the 0.51 file at `dea1d163` (Round 18 art, CC0).

    python3 -I tools/r531_art/ship_icons.py apply        copy the 36 picks into mods/
    python3 -I tools/r531_art/ship_icons.py check        byte identity, 64x64 PNG, licence rows
    python3 -I tools/r531_art/ship_icons.py rows         print the licence-table rows
    python3 -I tools/r531_art/ship_icons.py sheet OUT    32 px contact sheet (Pillow), before/after

Run from anywhere; paths resolve from the repository root. `check` and `rows` use
the standard library only; `sheet` needs Pillow and git.
"""
import hashlib
import io
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ICONS = "tools/r53_art/icons"
OLD_REV = "dea1d163"   # 0.51 icons (Round 18 art)
BEFORE_REV = "4e8a177d"  # main before this lane, for the contact sheet only
ABIL = "mods/PLAYER/grug_abilities"
CLASSES = "mods/PLAYER/grug_classes"

# key, choice, game file name part. choice: "old", "p1:vN" (drop-01) or "p2:vN" (drop-02).
PICKS = [
    ("skill:strike", "old", "strike"),
    ("skill:charge", "p2:v1", "charge"),
    ("skill:bellow", "p2:v3", "bellow"),
    ("skill:hold_ground", "old", "hold_ground"),
    ("skill:retort", "p1:v1", "retort"),
    ("skill:taunt", "p1:v1", "taunt"),
    ("talent:bulwark_enduring_stand", "p1:v3", "enduring_stand"),
    ("talent:bulwark_halt", "p2:v1", "halt"),
    ("skill:broadstroke", "p2:v1", "broadstroke"),
    ("skill:hamstring", "old", "hamstring"),
    ("skill:mighty_blow", "p1:v1", "mighty_blow"),
    ("skill:ruination", "p1:v1", "ruination"),
    ("talent:ruin_finisher", "p2:v2", "finisher"),
    ("talent:ruin_relentless", "p1:v3", "relentless"),
    ("talent:ruin_stoke", "p1:v3", "stoke"),
    ("skill:blink", "p2:v1", "blink"),
    ("skill:heal", "p1:v1", "heal"),
    ("skill:mend", "old", "mend"),
    ("skill:shield_spell", "old", "shield_spell"),
    ("talent:mercy_clear_conscience", "p1:v1", "clear_conscience"),
    ("talent:mercy_lasting_haven", "p1:v1", "lasting_haven"),
    ("skill:censure", "p1:v1", "censure"),
    ("skill:rebuke", "p1:v1", "rebuke"),
    ("skill:word_of_ruin", "old", "word_of_ruin"),
    ("talent:reckoning_long_reach", "p1:v3", "long_reach"),
    ("skill:loose", "p1:v1", "loose"),
    ("skill:sidestep", "p1:v3", "sidestep"),
    ("skill:sprint", "old", "sprint"),
    ("skill:split_shot", "p1:v1", "split_shot"),
    ("skill:true_draw", "p1:v2", "true_draw"),
    ("skill:close_dance", "p2:v2", "close_dance"),
    ("skill:flourish", "p1:v3", "flourish"),
    ("skill:opening", "old", "opening"),
    ("skill:parry", "p2:v1", "parry"),
    ("talent:veil_shake_loose", "p1:v1", "shake_loose"),
    ("talent:veil_travel_worn", "p1:v1", "travel_worn"),
]
RETIRED = ["cinderfall", "glacial_ward", "pinning_shot"]


def game_path(key, name):
    if key.startswith("skill:"):
        return f"{ABIL}/textures/grug_abilities_skill_{name}.png"
    return f"{CLASSES}/textures/grug_classes_talent_{name}.png"


def licence_path(key):
    return f"{ABIL if key.startswith('skill:') else CLASSES}/LICENSE-media.md"


def source(key, choice, name):
    """(label for the licence row, bytes)."""
    if choice == "old":
        path = game_path(key, name)
        data = subprocess.run(["git", "show", f"{OLD_REV}:{path}"], cwd=ROOT,
                              capture_output=True, check=True).stdout
        return f"`git show {OLD_REV}:{path}`", data
    drop = {"p1": "drop-01", "p2": "drop-02"}[choice[:2]]
    rel = f"{drop}/{key.replace(':', '__')}_{choice[3:]}.png"
    return rel, (ROOT / ICONS / rel).read_bytes()


def png_size(data):
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    return int.from_bytes(data[16:20], "big"), int.from_bytes(data[20:24], "big")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def apply():
    for key, choice, name in PICKS:
        _, data = source(key, choice, name)
        (ROOT / game_path(key, name)).write_bytes(data)
    print(f"copied {len(PICKS)} picks")


def rows():
    for key, choice, name in PICKS:
        label, data = source(key, choice, name)
        local = Path(game_path(key, name)).relative_to(
            ABIL if key.startswith("skill:") else CLASSES).as_posix()
        pick = f"{key} old" if choice == "old" else f"{key} pass {choice[1]} {choice[3:]}"
        src = label if choice == "old" else f"`{label}`"
        print(f"| `{local}` | {src} | {pick} | {len(data)} | `{sha(data)}` |")


def check():
    failures = []
    table = ["| Key | Choice | Shipped file | Size | Bytes | SHA-256 | Identical |", "|---|---|---|---|---:|---|---|"]
    licences = {}
    for key, choice, name in PICKS:
        _, want = source(key, choice, name)
        path = game_path(key, name)
        got = (ROOT / path).read_bytes()
        size = png_size(got)
        same = got == want
        if not same:
            failures.append(f"{path} differs from its pick {choice}")
        if size != (64, 64):
            failures.append(f"{path} is {size}, not 64x64")
        text = licences.setdefault(key.startswith("skill:"),
                                   (ROOT / licence_path(key)).read_text(encoding="utf-8"))
        local = path.split("/", 3)[3]
        row = f"| `{local}` |"
        hits = [line for line in text.splitlines() if line.startswith(row)]
        if len(hits) != 1:
            failures.append(f"{path}: {len(hits)} licence rows, want 1")
        elif not hits[0].endswith(f"| {len(got)} | `{sha(got)}` |"):
            failures.append(f"{path}: licence row bytes/sha256 stale")
        table.append(f"| {key} | {choice} | `{Path(path).name}` | {size[0]}x{size[1]} | {len(got)} | "
                     f"`{sha(got)[:16]}` | {'yes' if same else 'NO'} |")
    for name in RETIRED:
        path = f"{ABIL}/textures/grug_abilities_skill_{name}.png"
        if (ROOT / path).exists():
            failures.append(f"{path} is back")
    # Every row of a texture table names a shipped file (with its bytes and SHA-256 where the
    # row gives them); every shipped skill/talent icon has a row.
    for prefix, mod in (("grug_abilities_skill_", ABIL), ("grug_classes_talent_", CLASSES)):
        text = (ROOT / mod / "LICENSE-media.md").read_text(encoding="utf-8")
        named = set()
        for line in text.splitlines():
            if line.startswith("| `textures/"):
                file = line.split("`")[1]
                named.add(file)
                if not (ROOT / mod / file).exists():
                    failures.append(f"{mod}: licence row for missing {file}")
                    continue
                cells = [c.strip() for c in line.strip("|").split("|")]
                if len(cells) >= 2 and cells[-2].isdigit() and cells[-1].strip("`") != cells[-1]:
                    data = (ROOT / mod / file).read_bytes()
                    if int(cells[-2]) != len(data) or cells[-1].strip("`") != sha(data):
                        failures.append(f"{mod}: licence row of {file} has stale bytes/SHA-256")
        for file in sorted((ROOT / mod / "textures").glob(prefix + "*.png")):
            if f"textures/{file.name}" not in named:
                failures.append(f"{mod}: no licence row for {file.name}")
    print("\n".join(table))
    if failures:
        print("\nFAIL:\n  " + "\n  ".join(failures))
        return 1
    print(f"\nPASS: {len(PICKS)} picks byte-identical, 64x64 PNG, one licence row each with bytes and SHA-256; "
          "every shipped skill/talent icon has a row, no row names a missing file, every row's bytes/SHA-256 "
          "match its file; retired icons absent")
    return 0


def sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.load_default(size=11)
    cols, cell_w, cell_h = 4, 250, 46
    rows_n = (len(PICKS) + cols - 1) // cols
    img = Image.new("RGB", (cols * cell_w + 16, rows_n * cell_h + 44), "#15171c")
    draw = ImageDraw.Draw(img)
    draw.text((8, 8), "0.53.1 ART: the 36 shipped icons at 32 px (left: before at 4e8a177d, right: shipped). "
              "View at 100 %.", fill="#e8e6e0", font=font)
    for i, (key, choice, name) in enumerate(PICKS):
        x, y = 8 + (i % cols) * cell_w, 32 + (i // cols) * cell_h
        path = game_path(key, name)
        before = subprocess.run(["git", "show", f"{BEFORE_REV}:{path}"], cwd=ROOT,
                                capture_output=True, check=True).stdout
        for j, data in enumerate((before, (ROOT / path).read_bytes())):
            with Image.open(io.BytesIO(data)) as icon:
                icon = icon.convert("RGB").resize((32, 32), Image.Resampling.LANCZOS)
                img.paste(icon, (x + j * 38, y))
        draw.text((x + 80, y + 2), key.split(":")[1], fill="#e8e6e0", font=font)
        draw.text((x + 80, y + 17), "old (0.51)" if choice == "old" else f"pass {choice[1]} {choice[3:]}",
                  fill="#a9a59a", font=font)
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, format="PNG", optimize=True)
    print(f"wrote {out}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode == "apply":
        apply()
    elif mode == "rows":
        rows()
    elif mode == "check":
        sys.exit(check())
    elif mode == "sheet" and len(sys.argv) == 3:
        sheet(sys.argv[2])
    else:
        sys.exit(__doc__)

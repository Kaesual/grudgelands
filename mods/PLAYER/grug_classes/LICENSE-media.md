# Media Origin & Licenses (grug_classes)

## Round 26 class icons — CC0

All four class icons below were generated for Grudgelands on 2026-09-29
with OpenAI's built-in `image_gen.imagegen` tool, one separate prompt/call
per asset. No third-party image was supplied to the tool. The project
dedicates any rights it holds in these generated images to **CC0-1.0**,
to the extent such rights exist. They are not imported game art.

Final files are opaque 64×64 RGBA PNGs without a frame. Pillow reduces the
originals with Lanczos, normalizes border-connected near-background pixels
to the Round 18 sampled charcoal-blue `#151f2d`, and centers the result on a
matching plate with a 4 px margin. The class accents are brown (Warrior),
blue (Mage), white (Priest), and olive (Scout).

Exact prompts, local source output paths, source and final SHA-256 hashes:
`tools/r26_icons/manifest.json` at the repository root. Reproduce exports
and the 64/32 px contact sheet with `python3 tools/r26_icons/prepare.py`
when those originals are present. AI generation itself is not deterministic.
`python3 tools/r26_icons/prepare.py --check` validates committed files without
the originals. The manifest records the Pillow version.

| File | Origin / treatment | License |
|---|---|---|
| `textures/grug_class_warrior.png` | Own work; OpenAI-generated; export treatment above | CC0-1.0 |
| `textures/grug_class_mage.png` | Own work; OpenAI-generated; export treatment above | CC0-1.0 |
| `textures/grug_class_priest.png` | Own work; OpenAI-generated; export treatment above | CC0-1.0 |
| `textures/grug_class_scout.png` | Own work; OpenAI-generated; export treatment above | CC0-1.0 |

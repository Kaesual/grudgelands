# Round 52 ARTB — talent and skill icons, pass 1

Author: GPT-6 Astra. Date: 2026-10-19. Branch: `r52-artb`.

**Style sample complete; user selection pending.** The drop contains three
alternatives, A / Painted embers, B / Cut enamel and C / Forged sigils,
with the same six skills and six talents in each. Pass 2 will extend the
selected style to 44 skill and 74 talent icons.

Upgrade classification: **compatible**. This is staged media and its
packaging documentation; no game content, Lua, persistence or shipped
icons change.

## Files

- [Comparison sheet](drop-01/preview.png): all 36 samples at actual 32 px
  and 64 px on both dark and light strips, plus today's Fireball and Smite
  alongside each style; an eight-slot mock hotbar per style uses six
  48 px skill samples and two empty slots.
- [Manifest](drop-01/manifest.json): one asset entry per final icon, with
  key, style, final path and SHA-256, exact prompt, local tool output path
  and source SHA-256, source dimensions/mode and processing receipt.
  Comparison sources and the preview have their own hash records.
- [Style rules](drop-01/STYLE.md): framing, lighting, line weight and
  palette anchors for the eventual set.
- `drop-01/{A,B,C}/skill.<id>.png` and
  `drop-01/{A,B,C}/talent.<node id>.png`: 36 opaque 64 × 64 RGB PNGs.
- [Packaging script](build_drop.py): local image packaging, preview
  rebuilding and a read-only file audit.

The comparison sheet is an offline mockup, not a desktop or web-client
screenshot. Both transform variants are shown together to compare the
artwork; the hotbar is not a proposed character build. View the sheet at
100% to assess native pixel sizes.

## Method and provenance

The motif source is the class redesign's
[node list](../../../docs/planning/class-redesign/node-list.md), with
[Round 52 C6, C9, C11 and D7](../../../docs/planning/round52-class-plan.md).
Today's skill images, the
[Round 18 manifest](../../r18_art/manifest.json),
[art report](../../../docs/research/round18-art-report.md) and
[media notes](../../../mods/PLAYER/grug_abilities/LICENSE-media.md)
were inspected for the existing visual language and packaging method.

All 36 images were made with the built-in `image_gen.imagegen` tool, one
separate prompt and call per final image: 33 fresh generations and three
edits of this drop's own matching Fiery Spark originals to produce Cold
Spark. No third-party image was supplied. The tool's original files remain
at the local output paths recorded in the manifest; all final deliverables
are committed here and need none of those external paths to be viewed or
to rebuild the sheet.

Pillow converts each square original to RGB and downsamples the whole
image to 64 × 64 with `Image.Resampling.LANCZOS`, then saves an optimized
PNG without source metadata. There is no crop, post-generation recoloring,
compositing or sharpening of the final icon files. Cold Spark's elemental
change is a recorded image-generation edit, not a Pillow recolor.
Only the review sheet composites icons, labels, strips and mock slots.

## Rebuild and inspection

Requires Python 3 and Pillow 10.1 or later; the exact packaging version is
recorded per image. From the repository root:

```sh
python3 -I tools/r52_art/artb/build_drop.py
python3 -I tools/r52_art/artb/build_drop.py --check
```

The first command rebuilds the sheet from committed finals and the two
shipped comparison icons, and updates its manifest hash. The second reads
only: it verifies the exact 36-file roster, PNG format, opaque RGB mode,
64 × 64 dimensions, complete prompt/processing fields, and the final,
preview and comparison hashes. If a local final is missing and its
recorded original is still available, `--package` can restore that final;
it never overwrites an existing image.

Author inspection: all 36 final icons and their 32 px and 64 px comparison
rows were visually inspected. The three Spark pairs retain the diagonal
dart family silhouette; Fireball remains round; Arrowfall has four
converging arrows in all variants; each talent has a distinct frame from
the skill images. The file audit passes for 36/36 images. The sample is
ready for the user's style comparison; independent selection and later
desktop/web integration checks remain with the coordinator and user.

No fixtures, Lua checks, engine runs or seed fleet were run, as requested
for this media-only sample. No agents were launched.

## Media

All paths below are relative to this folder. **CC0** means **CC0-1.0**:
the project dedicates any rights it holds in the generated images and
review composition to CC0-1.0, to the extent such rights exist.

| File | Author | Date | Method | License |
|---|---|---|---|---|
| `drop-01/A/skill.fiery_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.cold_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation edit of own matching Fiery Spark; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.fireball.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.smite.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.bladecraft.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/skill.arrowfall.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.f1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.r10.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.b2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.m7.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.rk1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/A/talent.q2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.fiery_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.cold_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation edit of own matching Fiery Spark; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.fireball.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.smite.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.bladecraft.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/skill.arrowfall.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.f1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.r10.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.b2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.m7.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.rk1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/B/talent.q2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.fiery_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.cold_spark.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation edit of own matching Fiery Spark; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.fireball.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.smite.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.bladecraft.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/skill.arrowfall.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.f1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.r10.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.b2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.m7.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.rk1.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/C/talent.q2.png` | GPT-6 Astra | 2026-10-19 | Built-in image generation, individual prompt; Pillow RGB + Lanczos | **CC0-1.0** |
| `drop-01/preview.png` | GPT-6 Astra; Grudgelands Round 18 art lane (comparison images) | 2026-10-19 | Pillow composition of the listed samples and the project's CC0 Fireball/Smite; labeled strips and mock hotbars | **CC0-1.0** |

# Media Origin & Licenses (grug_core)

- `grug_core_hud_bar.png`: 1×1 opaque white pixel, generated for this project
  (own work), **CC0**. It is the single strip every HUD bar is stretched
  from; each bar tints it with `^[colorize:` and sets its drawn width through
  the `image` element's `scale` (`grug_core/hud_layout.lua`). Reproduce with:

  ```sh
  python3 -c 'from PIL import Image; Image.new("RGBA", (1, 1), (255, 255, 255, 255)).save("mods/CORE/grug_core/textures/grug_core_hud_bar.png", optimize=True)'
  ```

- `grug_core_mote.png`: 8×8 soft white mote (full white, alpha 255 in the
  middle falling to 50 at the rim), generated for this project (own work),
  **CC0**. The skill particle effects tint it with `^[multiply:`
  (`grug_core/particles.lua`, the emitter field `mote`), so a colour shows as
  written. Reproduce with:

  ```sh
  python3 -c 'from PIL import Image; im = Image.new("RGBA", (8, 8)); im.putdata([(255, 255, 255, (lambda d: 255 if d < 1.6 else 225 if d < 2.6 else 140 if d < 3.3 else 50 if d < 4 else 0)(((x + 0.5 - 4) ** 2 + (y + 0.5 - 4) ** 2) ** 0.5)) for y in range(8) for x in range(8)]); im.save("mods/CORE/grug_core/textures/grug_core_mote.png", optimize=True)'
  ```

- `grug_core_fx_hammer.png`: 64×64 RGBA hammer, the particle symbol of the
  priest's Smite and Final Word (`grug_core/particle_effects.lua`). Original
  art authored as polygon and line geometry by **GPT-6 Astra** for
  Grudgelands on 2026-10-28, no imported assets or reference images;
  **CC0-1.0**. Source: the Round 66 ART package `tools/r66_art/`
  (`candidates/smite_hammer_c.png`, the user's pick; generator
  `generate.py`, GPL-3.0-or-later; provenance in its `LICENSE-media.md`).
  Modifications: none (copied byte for byte, renamed).

- `grug_core_fx_book.png`: 64×64 RGBA book, the particle symbol of the
  priest's Censure (`grug_core/particle_effects.lua`). Original art authored
  as polygon and line geometry by **GPT-6 Astra** for Grudgelands on
  2026-10-28, no imported assets (a photo-illustration the user supplied
  served as orientation only; nothing of it is copied or shipped);
  **CC0-1.0**. Source: the Round 66 ART package `tools/r66_art/`
  (`candidates/censure_book_q.png`, the user's pick; generator
  `generate.py`, GPL-3.0-or-later; provenance in its `LICENSE-media.md`).
  Modifications: none (copied byte for byte, renamed).

## Round 26 status icons and frames — CC0

The 27 status emblems below were generated for Grudgelands on 2026-09-29
with OpenAI's built-in `image_gen.imagegen` tool, one separate prompt/call
per asset. No third-party image was supplied to the tool. Their style follows
the project's Round 18 skill icons. The project dedicates any rights it holds
in these generated images and its procedural frames to **CC0-1.0**, to the
extent such rights exist. They are not imported game art.

Final emblems are opaque 64×64 RGBA PNGs. Pillow downsamples each original
with Lanczos, normalizes border-connected near-background pixels to the
sampled charcoal-blue `#151f2d`, and centers it on a matching plate with a
4 px margin. The three separate overlays have an exact 3 px colored border
and a fully transparent center. No status frame is baked into an emblem.

Exact prompts, local source output paths, source and final SHA-256 hashes,
and the full filename roster: `tools/r26_icons/manifest.json`.
Reproduce the frames without image generation, from the repository root:

```sh
python3 tools/r26_icons/frames.py
```

With the original local generated files available, reproduce all exports and
the contact sheet using `python3 tools/r26_icons/prepare.py` (Pillow version
is recorded in the manifest). Use `python3 tools/r26_icons/prepare.py --check`
to validate the committed textures without the originals. AI generation itself
is not deterministic. The task enumerates 27 status IDs, although its heading
says 29; only the explicitly requested IDs are included.

| File | Origin / treatment | License |
|---|---|---|
| `textures/grug_status_food.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_elixir_vigor.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_elixir_focus.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_elixir_precision.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_elixir_stoneskin.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_elixir_deepwater.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_alchemy_swiftness.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_alchemy_cave.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_mount_land.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_mount_flight.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_mount_water.png` | GPT-6 Astra (Grudgelands), own work, Round 29; generated with OpenAI's built-in `image_gen.imagegen`, no third-party source images. Wooden rowboat, oar and blue waves; nearest-neighbour 64×64 RGBA export with the flat `#151f2d` plate normalized and the frame area left clear; no baked frame | CC0-1.0 |
| `textures/grug_status_shield.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_move_immune.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_poisoned.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_slowed.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_rooted.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_stunned.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_scorched.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_in_combat.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_pvp_tagged.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_pvp_contested.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_frame_buff.png` | Own work; procedural Pillow overlay; reproduce with frames.py | CC0-1.0 |
| `textures/grug_status_frame_debuff.png` | Own work; procedural Pillow overlay; reproduce with frames.py | CC0-1.0 |
| `textures/grug_status_frame_neutral.png` | Own work; procedural Pillow overlay; reproduce with frames.py | CC0-1.0 |

## Round 58 Miner's Guild status icons — CC0

Made for Grudgelands by GPT-6 Astra (guild art drop 01, proposal P2 "Reading
the rock", picked by the user on 2026-10-23): painted texel by texel by the
drop's own script (`paint.py`, no source images, no randomness, no
image-generation model). Copied unchanged; the frame is added at run time
like every status (`status_icons.lua`).

| File | Origin / treatment | License |
|---|---|---|
| `textures/grug_status_ore_sense.png` | Own work; drop 01 P2 `status_ore_sense.png` (assay vial with detection rays, 64×64, opaque plate), unchanged | CC0-1.0 |
| `textures/grug_status_treasure_hunt.png` | Own work; drop 01 P2 `status_treasure_hunt.png` (folded survey map with a destination bracket, 64×64, opaque plate), unchanged | CC0-1.0 |

## UI theme

`textures/grug_ui_*.png`: original geometric UI assets generated by
`tools/ui_theme/build.py` for Grudgelands (2026-10-24; fidelity revision
2026-10-25), CC0-1.0. The 18 files are `window`, `panel`, `button`, `hover`,
`pressed`, `selected`, `danger`, `clear`, and `icon_` followed by `emblem`,
`inventory`, `character`, `talents`, `crafting`, `party`, `map`, `help`,
`mail`, `creative` (each with the `grug_ui_` prefix and `.png` suffix).
No external
art, fonts or generated bitmap artwork. Regenerate with the script; verify
with `python3 tools/ui_theme/build.py --check`.

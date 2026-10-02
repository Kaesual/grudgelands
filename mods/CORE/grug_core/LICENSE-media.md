# Media Origin & Licenses (grug_core)

- `grug_core_hud_bar.png`: 1×1 opaque white pixel, generated for this project
  (own work), **CC0**. It is the single strip every HUD bar is stretched
  from; each bar tints it with `^[colorize:` and sets its drawn width through
  the `image` element's `scale` (`grug_core/hud_layout.lua`). Reproduce with:

  ```sh
  python3 -c 'from PIL import Image; Image.new("RGBA", (1, 1), (255, 255, 255, 255)).save("mods/CORE/grug_core/textures/grug_core_hud_bar.png", optimize=True)'
  ```

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
| `textures/grug_status_mount_water.png` | Round 29 first version (the art lane redraws it under this name): `sailboat_inventory.png` by deasanta from Lord of the Test `f164140154945f0b356521ae721a86e9c7a0e0cf`, `mods/boats/textures/` (licence per `mods/boats/license.txt`), scaled 2x nearest-neighbour onto the `#151f2d` plate | WTFPL |
| `textures/grug_status_shield.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_move_immune.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_talent_unbroken.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_talent_ruination.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_talent_whitehot.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_talent_turn_aside.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_talent_last_word.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_talent_untouchable.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_poisoned.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_slowed.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_rooted.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_stunned.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_scorched.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_in_combat.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_pvp_tagged.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_pvp_contested.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_warding_draught.png` | Own work; OpenAI-generated emblem; export treatment above | CC0-1.0 |
| `textures/grug_status_frame_buff.png` | Own work; procedural Pillow overlay; reproduce with frames.py | CC0-1.0 |
| `textures/grug_status_frame_debuff.png` | Own work; procedural Pillow overlay; reproduce with frames.py | CC0-1.0 |
| `textures/grug_status_frame_neutral.png` | Own work; procedural Pillow overlay; reproduce with frames.py | CC0-1.0 |

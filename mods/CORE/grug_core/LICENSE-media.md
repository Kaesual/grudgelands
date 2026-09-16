# Media Origin & Licenses (grug_core)

- `grug_core_hud_bar.png`: 1×1 opaque white pixel, generated for this project
  (own work), **CC0**. It is the single strip every HUD bar is stretched
  from; each bar tints it with `^[colorize:` and sets its drawn width through
  the `image` element's `scale` (`grug_core/hud_layout.lua`). Reproduce with:

  ```sh
  python3 -c 'from PIL import Image; Image.new("RGBA", (1, 1), (255, 255, 255, 255)).save("mods/CORE/grug_core/textures/grug_core_hud_bar.png", optimize=True)'
  ```

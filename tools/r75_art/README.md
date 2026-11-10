# Round 75 original paintings

Open [index.html](index.html) directly in a browser. It is local and offline;
the 16 thumbnails are the actual shipped 256×256 textures. Clicking opens the
original image. The complete Decoration Merchant and display design lives in
[decorations.md](../../docs/design/decorations.md).

`manifest.json` identifies each original, its prompt and any expedition-only
source. `source/*.png` are original outputs of OpenAI's built-in image generation
tool, created for Grudgelands on 2026-11-10. `prompts/*.txt` preserve the prompts.
No third-party image was supplied. Original art and authored frame meshes are
dedicated to CC0-1.0 to the extent rights exist. The frame's existing wood texture
keeps its upstream license; see the mod's media ledger.

`python3 tools/r75_art/build.py` mechanically resizes the originals, creates
the two frame meshes, the pure Lua painting catalog and this offline gallery.
It requires ImageMagick. It does not regenerate or paint artwork.

`luajit tools/r75_art/portable_test.lua .` checks full static decor registration,
city no-loot copies, all four painting mount directions, blocked/protected
corners, shop prices and reward exclusivity, exact 2% roll boundaries and the
two Basic recipes. Existing expedition fixtures cover cached personal chests.

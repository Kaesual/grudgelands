# Media licenses — grug_text

## The sign font (Round 68)

The glyphs and the character table come from VoxeLibre's sign font
(<https://git.minetest.land/VoxeLibre/VoxeLibre>, read at commit
`2373982f19f9b5d89cd2e3146ad7749876319e15`): `textures/_*.png` and
`mods/ITEMS/mcl_signs/characters.tsv`. The font is **CC0-1.0**, as
`mods/ITEMS/mcl_signs/README.md` there states ("Font: CC0 — Originally by
PilzAdam — Modified and massively extended by EmoryNB — Can be found in the
`/textures` sub-directory of game root, prefixed with `_`";
<https://creativecommons.org/publicdomain/zero/1.0/>). Credited anyway:
**PilzAdam** (the original glyphs) and **EmoryNB** (the extension to Latin-1
to Latin-4, Cyrillic and Greek).

`tools/r68_text/import_font.py` copies the files byte for byte, unchanged,
under the mod prefix, and rewrites the table (character, texture name; the
width column dropped; five rows whose glyph file upstream does not ship
left out). No code of `mcl_signs` (MIT) is copied: the wrapping, the
texture building and the entity handling in this mod are our own,
following the technique described there (one `[combine` texture per text,
one entity per sign).

| File | Source | License |
|---|---|---|
| `textures/grug_text_<name>.png` (431 files) | VoxeLibre `textures/_<name>.png`, unchanged | CC0-1.0 |
| `textures/grug_text_rc.png` (the placeholder glyph) | VoxeLibre `textures/_rc.png`, unchanged | CC0-1.0 |
| `characters.tsv` | VoxeLibre `mods/ITEMS/mcl_signs/characters.tsv`, columns 1-2 with the prefix | CC0-1.0 |

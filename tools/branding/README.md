# Branding — the Grudgelands crest

Everything needed to regenerate `menu/icon.png` and the other icon sizes from
the source render. Licence for all of it: CC0 1.0, see `menu/LICENSE-media.md`
(AI-generated with Z-Image, prompt and mask edit by Jan Hangebrauck).

| file | what |
|---|---|
| `grudgelands_icon.png` | 1024×1024 source render (Z-Image, local), black background |
| `mask_hand.png` | 1024×1024 cutout mask, hand-corrected in GIMP — the shipped reference |
| `make_icons.sh` | cutout + export pipeline (ImageMagick 7; the automatic-mask path also needs python3 with numpy and Pillow) |
| `hullmask.py` | helper for the automatic mask path only |

## Reproduce the shipped icon

```sh
cd tools/branding
MASK=mask_hand.png ./make_icons.sh grudgelands_icon.png /tmp/grudgelands-icons
magick compare -metric AE /tmp/grudgelands-icons/plain_96.png ../../menu/icon.png null:
```

The compare prints `0`: the pixels are identical. The files are not
byte-identical because ImageMagick writes the run's time into the PNG
(`tIME`, `date:*` text chunks). Verified on 2026-09-16 for `plain_96` and
`plain_512` (signature `cfa4e1b6…` and `fab9e7ca…`).

Without `MASK=` the script rebuilds an automatic mask that differs from the
hand-edited one by a few hundred pixels. Do not ship that path's output.

`out/punch_<N>.png` (96 and below) are the same icons with slightly boosted
contrast; `menu/icon.png` is the plain variant, the default choice.

## Package size

The source render is 1.6 MB and, like everything in the repository, would ship
in the ContentDB package. If it should stay out of the package, a
`.gitattributes` `export-ignore` line is the mechanism; whether ContentDB
honours it has not been verified, so nothing is set here.

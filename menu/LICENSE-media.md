# Media Origin & Licenses (menu)

The game's menu icon. Luanti reads `<game>/menu/icon.png` for the game bar of
the main menu; header, background and footer images are not part of this
directory yet.

## `icon.png` — CC0 1.0

The Grudgelands crest: a heater shield split by a glowing fissure, a gold half
with an oak and a sun (Elandor) and a rust-red half with three black peaks
(Kragmar), fire rising from the bottom of the crack. Approved by the user on
2026-09-16.

* Author / rights holder: Jan Hangebrauck (prompt, mask edit, approval).
* Generated with Z-Image (run locally); prompt by Jan Hangebrauck; the cutout
  mask that removes the render's black background was hand-edited by Jan
  Hangebrauck in GIMP.
* Licence: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
  (public-domain dedication) for the icon and for the source render.
* Source and reproduction: `tools/branding/` holds the 1024×1024 source render
  (`grudgelands_icon.png`, also CC0 1.0), the hand-edited mask and the export
  pipeline; `tools/branding/README.md` gives the exact command. `icon.png` is
  the pipeline's `plain_96.png`: the cutout scaled to 90 % of a transparent
  96×96 square.
* Modifications: background removed, padded to a transparent square, scaled.
  The PNG keeps the `zTXt parameters` chunk ImageMagick copied from the source
  render, i.e. the generation prompt travels inside the file.

## AI disclosure

This image is AI-generated. ContentDB's content policy (§4.3 as of 2026-09-16)
requires packages with AI-generated media to set the AI-generated flag on the
package page and to credit the tool in the licence file; this file is that
credit, and the flag is listed under the first-public-release gates in
`BACKLOG.md`.

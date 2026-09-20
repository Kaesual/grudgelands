# Round 12 art evidence

`build_assets.py` deterministically builds the 18 dishes, six raw assemblies,
Bread, six Wands and six double-bit Greataxes. Run it with Python 3 and Pillow;
paths resolve from the script location.

The project-authored sprites use explicit 16x16 geometry and fixed palettes.
`sources/imagegen-concept-sheet.png` is the unmodified concept sheet generated
with OpenAI's built-in image-generation tool. It suggested the object vocabulary
only; none of its raster pixels ship as game media. The prompt requested a
transparent, text-free grid of distinct fantasy food icons, a short focused
wand and a diagonal broad double-bit axe, with limited palettes and strong
16x16 silhouettes; Jungle Cocoa had to be a brown hot drink and the axe could
not resemble a halberd.

`evidence/before/` preserves the actual three generic food bases, Mese-fragment
wand base and six old Greataxes from the package baseline. The review plates
are nearest-neighbour scaled. Final evidence includes native and enlarged
before/after galleries plus a SHA-256 manifest.

POSE contract: both new weapon families use the existing diagonal tool axis,
grip near `(3.4, 12.6)`, business end upper-right. They need no special pose
metadata beyond the authored wand/axe family transforms.

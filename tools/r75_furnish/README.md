# Round 75 FURNISH lane report

This lane adds 56 ordered, purchasable static furnishings from families
N06–N32 and two non-shop static armoury silhouettes. Geometry uses bounded
nodeboxes plus 31 code-generated OBJ meshes with explicit per-component
material groups and full-face UVs. All textures are media already shipped by
the game. It adds no inventory, entity, timer, particle, workstation or
persistence behavior.

The generator precompensates Luanti's OBJ-loader X reflection in vertices,
normals and triangle order. Authored asymmetric component positions and the
hart/boar texture orientation therefore survive the engine import unchanged;
the preview script applies the same loader transform before rendering.

Orientation contract: facedir `0` presents the deliberate wall front toward
local `-Z`; `1`, `2`, and `3` rotate it toward `-X`, `+Z`, and `+X`. Table and
floor forms meet the bottom of their node at `y=-0.5`. Rugs are three
hundredths of a node thick and carry a restrained contrasting border. The two
heraldry meshes map their complete 1:2 hart/boar image to a 0.42 by 0.84 node
banner. Tabletop, wall, textile and ceiling forms are non-walkable. Sacks,
crates, the upright wicker basket, lectern, fire basket, hearth, planter, and
the two display silhouettes use their bounded nodebox as collision.

`grug_decor.place_furnishing(itemstack, placer, pointed_thing)` is the shared
mount-aware placer. Floor/table forms accept only a complete top support,
wall forms align local `+Z` to a complete wall face, and ceiling forms accept
only a complete underside. Every form stays upright with horizontal facedir.

Run the focused fixture from the repository root:

```sh
chrt --idle 0 ionice -c3 luajit tools/r75_furnish/portable_test.lua .
python3 tools/r75_furnish/generate_meshes.py --check
```

Generate a material-group contact sheet for visual review:

```sh
python3 tools/r75_furnish/render_preview.py /tmp/r75_furnish_preview.png
```

Integrated on `round75`: static loader and `grug_core` dependency, no-loot
city copies, merchant rows, and the shared media ledger. Media references need
no dependency on `grug_mapgen` (which already depends on the decor kit). Large
paintings use their own footprint-aware placer.

Independent review: MERGE, including material/UV, mounting, OBJ handedness and
the final ember/flame refinement. The focused fixture passes 14,632 checks.
The lane is additive and compatible; Round 75 requires a map reset for CITY.
Desktop/web visual acceptance remains open.

## Round 75.2 material correction

The geometry review in Round 75 did not catch transparent inventory sprites
used as full surface materials. Solid props now use opaque material textures;
only the two heraldic cloth silhouettes deliberately use alpha clipping.
Paper, book bindings, scroll ties, writing implements and colored alchemy
vessels have distinct full material groups. Ore and foliage overlays sit on
opaque stone/grass bases. The tool board separates light metal heads from
wooden handles. There are now 38 generated furnishing meshes.

The [material audit and textured inspection page](../r75_2_materials/README.md)
checks all new items and their city copies against the real engine node dump.
The older false-color preview above is only a geometry aid, not texture proof.

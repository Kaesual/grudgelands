# Tree concepts — growth model per species (Round 46, lane TREE, steps 2–4)

The viewer (`trees.html`, built by `build.py`) runs the generator in
`treegen.js`; the wood shapes are data in `shapes.js` (which also writes the
trunk meshes to `models/*.obj`). Every tree follows one readable logic:
**stem → limbs → twigs → leaf clusters at the twig ends**, thinning outwards
(trunk 16/16 → limb base 12/16 → branch 10/16 → twig 6/16). Individuals
differ only through the species' parameters below, drawn from the seed;
there is no per-node noise in the wood. The one place a position hash acts
is the outer band of a leaf cluster, where about a third of the cells are
left out so crowns are round but not geometric.

Common rules, all species:

- **Trunks** of 2 × 2 are four slanted quarter meshes from the ground up (no
  square foundation, no square collars). A 3 × 3 has quarter meshes on its
  corners and logs on its edges and centre. A 1 × 1 trunk is the existing
  log cube (see "1 × 1 trunks" below). Wide trunks never narrow to 1 × 1
  inside the column and never side-step: a log or limb on top of a slanted
  quarter would overhang its slant. A 3 × 3 steps in to a 2 × 2 diagonally:
  the 2 × 2's corner piece then stands on the 3 × 3's corner piece of the same
  turn, the rest on logs, so the outline above lies inside the one below.
- **Roots** (step 4): only at the foot of thick trunks, see "Roots" below.
- **Limbs** are staircases of face-connected cells that follow the straight
  line from their start to their target (the axis lagging furthest behind
  steps next). A limb leaving its parent sideways takes a level first step.
  A step that would touch other wood sideways takes another lagging axis
  when it can, so limbs do not fuse into ladders (connected boxes join every
  face neighbour).
- **Limb bases**: the first cell of a limb that leaves a trunk sideways is the
  base piece (a branch or lying log beside a stem log or quarter, or a twig
  beside a quarter). Its level arms reach half a node into the trunk cell and
  meet the slanted face without a gap.
- **Leaves** are the union of ellipsoid clusters; a leaf keeps a wood cell
  within 3 nodes (the engine's cube search for leaf decay) or is dropped,
  loose single leaves are dropped, everything stays inside 16 × 16 nodes.
  Twigs join a leaf directly above them (leaves get `connect_sides =
  {"bottom"}`), so every twig end reaches up into its foliage.
- **Grain**: logs, bases, branches and twigs carry facedir 0 / 4 / 12 so the
  bark runs along y / z / x — the direction the limb grew into that cell.

## Apple — the lollipop

A short stout bole (3–5 nodes; 2 × 2 in 40 % with 3–4) opens at its top into
3–4 scaffold limbs (four on a 2 × 2 bole, one leaving each quarter, turning
like a pinwheel), each through a limb base. Each limb stays in one upright
plane (a cardinal direction — a limb between two would zigzag in three axes)
and climbs at about 45° to 64–80 % of the crown radius, near the crown's
mid-height. There it forks: one twig curves up and in towards the top of the
ball, one runs sideways along the rim from two-thirds of the limb. The crown
is a round core (radius 3.75–4.6 nodes, half height 2.9–3.4) plus a cluster on
every limb end (radius 1.9–2.4) and twig end (1.5–2), so it is round and lumpy
where twigs end; 45 % lean their crown ¾ node to one side. 3–7 apples hang
on leaves with open air below. Height 8–12 (today 8), 8–13 wide (today 7).
Keeps: round ball on a short stout trunk, apples; gains height, a visible
branch structure and (step 3) a more generous crown.

## Jungle — tall stem, crown in clumps

A tree of 12–16 nodes (today 17). 70 % have a 1 × 1 stem that wanders: one
side-step low (a "knee", one layer standing on two logs) and in 60 % a
second one higher that turns back or aside, so it swings round its foot
instead of leaning off. 30 % have a straight 2 × 2 column up to the leader.
3–5 limbs leave the upper 45 % at 2–3 node intervals, each turned 5–7
sixteenths of a circle from the last, reaching 2.4–3.6 out and 1–2.3 up; each
ends in a rounded clump (radius 2.1–2.6, 40 % fork into two smaller clumps).
The leader ends in the highest clump; 0–2 tiny clumps sprout low on the stem.
Keeps: taller than apple, irregular, crown in clumps (the user likes it).

## Kapok — the emergent giant

21–26 high. A 3 × 3 column (60 %) or a 2 × 2 one. A 3 × 3 keeps its width up to
the crown base and steps in to the 2 × 2 leader one above it, towards its lean
(step 4: was at 6–9 high, where the ledge showed; now it sits among the big
limbs and under the dome). The 2 × 2 goes on as the leader to 4 below the top.
Always rooted (see "Roots"). At
60 % ± 1 of the height 4–6 big limbs leave through limb bases, reach 3.4–4.4
out and rise 1.5–3.5, fork into two twigs with a clump each; half carry a
clump under their middle. A second tier of 2–4 shorter limbs 3–4 higher sits
between them, the leader ends in the top clump, and a broad dome (radius
3.75–4.5, half height 2.75–3.25) joins the clumps. 12–16 wide. Keeps: a giant
with a 2 × 2 / 3 × 3 trunk and a broad high crown.

## Acacia — the umbrella (refined only)

A 1 × 1 trunk of 2–4 forks at its top into 2 (50 %, a wide V, 6–8 sixteenths
apart) or 3 thick limbs that climb out 2.9–4 and up 2–2.75. From every limb
end a twig climbs to one common level (one above the highest limb end) and,
in 55 %, splits sideways into two; every end there carries a pad (radius
2.6–3.25) that starts on the twigs' own layer and is widest one above (step
3: one node lower, so it sits on the twigs instead of floating). The pads
merge into one umbrella, 10–16 wide (today 9).

## Pine — the layered cone

A straight 1 × 1 stem of 12–17 that thins from log (lower 55 %) to branch to a
twig tip. From 2–4 up, a whorl every 2 nodes (3 in 15 %): four level twigs,
alternately along the axes and the diagonals, as long as the cone's radius
there allows; the cone narrows linearly from 3.1–3.9 at the lowest whorl to
the tip. Each whorl carries a needle skirt: wide at its own level, narrower
one above, so the cone is visibly layered; a small spire on top. Keeps:
straight trunk, layered cone; wider at the base than today (7 vs 5).

## Aspen — slender, pale, columnar

11–16 high on a slender 1 × 1 stem with a bare bole of 4–6 (log, then branch,
twig at the top; 40 % bend the top one node aside). The crown is a tall oval
(step 3: 5.25–6.5 wide, was 4.25–5.25) from the bole to the top, on short
twigs (1–2 out) that spiral up the leader, each turned 5/16 from the last,
every 1–2 nodes, each with a small cluster that roughens the oval. 5–8 wide.
Keeps: slender, columnar, pale.

## Silverwood — elegant flame

15–18 high, old trees (35 %) 19–22, on a slender 1 × 1 stem with a long clear
bole of 6–8. Above it 3–4 limbs (old: 4–5) step out 2–2.75 nodes and then
rise parallel to the leader to 3–5 below the top; each carries a leaf column
(radius 1.75–2.25) along its upright part that reaches down to where the limb
turns upright, the leader the tallest. Step 3: wider (6–11, median 8) and the
foliage reaches 2–3 nodes lower. Keeps: elegant, tall-columnar, pale silver
bark, distinct from the aspen's oval.

## Gravewood — dead and bent

A 1 × 1 stem of 6–10 (up to 12 with stub and hooks). It bends one way: a
knee at 2–3 towards its lean, in 55 % a second higher one, mostly the same
way. 3–5 bare limbs leave from 45 % of the height up, mostly on the side away
from the lean (they balance it), reach 2.75–4.4 out and between ¼ down and 1
up; 25 % end hooked up, 15 % drooping (step 3: was 40 %), the rest straight,
and every end is a two-pronged claw whose prongs go level or up (down only
on a drooping end). The top is a broken stub. 1–4 grey tufts (radius 1.1–1.6;
step 3: more foliage). Keeps: bent, mostly bare.

## Roots (step 4)

A few pieces at the foot of a thick trunk that lie on the ground and taper
into it, using the existing pieces (no new shape): a limb base beside the
trunk, a branch (only in 3-long roots) and a twig at the end; a 3-long root
may fork a twig sideways from its branch. Only the base and the twig join
the ground, and only through their bottom: they list the ground in
`connects_to` (`group:soil` — dirt, grass, the litters, blight dirt, mud —
plus `group:sand`, `default:gravel`; mesa clay if roots ever come there), and
the ground nodes declare `connect_sides = {"top"}`. So the base rests on the
ground at the trunk and the twig dives in at the end; a branch between them
keeps 3/16 above the ground like a root arching slightly. Tried and dropped:
roots leaving the trunk at knee height and stepping down (they read as legs
or a spider), and roots where every cell joins the ground (a comb of stubs).

| species | when | roots |
|---|---|---|
| apple | 2 × 2 trees, 25 % of them (≈ 10 % of all apples) | 1–2, opposite sides, 2 out |
| jungle | 2 × 2 trees, 45 % of them (≈ 15 % of all) | 1–3 on different sides, 2 out |
| kapok | always | per side 1–2 (2 from a 3 × 3 side leave its two ends), 2–3 out, 35 % of the 3-long ones fork |
| others | never | — |

**Ground test.** The generator takes `isGround(x, y, z)` (tree coordinates,
the foot on y = -1). Every root cell needs ground right under its column at
the foot level (`isGround(x, -1, z)`), none at the root's own level
(`isGround(x, 0, z)` false: the terrain does not rise there), a free cell and
no other wood touching it; else that root (or fork) is left out as a whole.
Roots draw their numbers from their own random stream before any test, so
the rest of the tree is the same on any terrain (checked). The Shapes view
shows a hillside: west of the trunk the ground falls away, east of it it
rises, so only the north and south roots grow.

**In the engine.** Schematic and decoration placement cannot test the ground
per cell, so the roots are not in the schematic. The cheapest place is the
Lua pass that already writes the tree: the WP40 template rows are
materialised by the R7 writer on a VoxelManip, so each template variant
carries its root runs as a list of optional cells, and the writer tests the
few column nodes from the data it already holds (two reads per root cell)
and writes a run only if all pass. Saplings do the same after placing the
schematic, with `core.get_node`. Cost: the ground nodes' `connect_sides`
override and the new `connects_to` change the frozen mapgen digest (map
reset, fine per the user).

## Shapes (per wood type: 4, the budget)

Boxes in sixteenths, `x1, y1, z1, x2, y2, z2`, centred on the node.

| shape | geometry | notes |
|---|---|---|
| quarter | **mesh** (`models/grug_tree_quarter_oct.obj`): outline from above, outwards from the axis corner, (16,0) → (16,7) → (7,16) → (0,16) | facedir 0..3, inner corner (trunk axis) at +x +z for 0. Three faces: a 7/16 half flat, a slant 12.7/16 long, a 7/16 half flat, so two pieces form one 14/16 face: a near-regular octagon column (the user's pick in step 3; a 16-gon quarter with five faces, (16,0) → (16,3.2) → (13.6,9.1) → (9.1,13.6) → (3.2,16) → (0,16), was tried and dropped). The two axis-side faces are left out (they always touch other trunk pieces). Two material groups: caps (tile 1, `*_tree_top`, planar) and bark (tile 2, u round the outline, v up the trunk: grain along the trunk). 6 side triangles plus 6 cap triangles. Collision and selection box: the full node (an approximation). |
| base | core `{-6,-6,-6,6,6,6}`; level arms to 8/16 past the border, e.g. right `{6,-6,-6,16,6,6}`; top/bottom arms to the border | connected; joins trunk pieces, other bases, branches, twigs, and the ground below it (roots). The arm toward the trunk ends where the slant lies at most 8/16 inside the border (7/16 at the arm's edge), so the join closes; towards the branch it ends half way into the branch cell as a sleeve (taper 12 → 10). 12/16 vs the branch's 10/16: no coplanar faces, no z-fighting. Extents ±1.0 node, inside the engine's soft limit ±1.45. Cost: the 4th shape slot, and up to ~5 hidden quads of overdraw per base (the part inside the trunk). |
| branch | core `{-5,-5,-5,5,5,5}`, arms to the border, e.g. right `{5,-5,-5,8,5,5}` | connected to trunk pieces, bases, branches, twigs. |
| twig | core `{-3,-3,-3,3,3,3}`, arm right `{3,-3,-3,8,3,3}` | as branch, plus leaves (only a leaf above: leaves' `connect_sides = {"bottom"}`) and the ground (only below: ground's `connect_sides = {"top"}`). Joining leaves on all sides made every twig inside a crown a six-armed star, busy through the see-through leaves; upward only reads as "the twig carries its foliage". |

**1 × 1 trunks** stay plain log cubes: the four shapes are spent (a chamfered
single log would be a fifth), a branch or base meets a cube's flat face
flush, and slender trees taper from the log to branch and twig anyway.

## Engine facts (reference_projects/luanti)

- Mesh nodes (`src/client/content_mapblock.cpp` `drawMeshNode`): the mesh is
  cloned and turned by facedir for every node (`rotateMeshBy6dFacedir`) and
  appended to the map block mesh; lighting is per vertex (smooth lighting:
  `blendLightColor(pos, normal)`, else face shading from the normal); no
  triangle of a mesh node is culled. Mesh nodes have solidness 0
  (`src/client/node_visuals.cpp`), so neighbours' faces toward them are not
  culled either — hence the open axis side. Static `.obj` meshes are scaled
  by BS (1 unit = 1 node, `NodeVisuals::updateMesh`); the OBJ loader negates
  x and flips v (`irr/src/COBJMeshFileLoader.cpp`, "change handedness"),
  which `shapes.js` writes for. Tile slot = material group order.
- Node boxes may reach beyond their cell; keep values within ±1.45 nodes
  for collision (`doc/lua_api.md`, "Node boxes").
- Connected boxes: two connected node boxes join only if each lists the
  other (`src/nodedef.cpp` `nodeboxConnects`, "ignores actually looking if
  back connection exists" means the target's list is checked, not its arm);
  any other target (log cube, mesh quarter, leaves) is joined if listed in
  `connects_to` and, when it declares `connect_sides`, only through those
  faces. Connected boxes never turn, but facedir turns their tiles
  (`drawNodeboxNode` → `getTile`), which the grain uses.
- Overriding the default leaves (for `connect_sides`) changes the WP40 frozen
  content digest (step-1 finding): integration is a map reset anyway.

## Porting to Lua

`treegen.js` is written for a 1:1 port to Lua 5.1: only integer arithmetic on
doubles below 2^53 (`idiv` = `math.floor(a / b)`), no trigonometry (the
16-direction table `DIR16`), Park–Miller random numbers (seed → salt ×
48271^(seed+1), then × 16807), cells in an explicit insertion list (never
`pairs` order) and the result sorted by a unique integer key. JS arrays
become 1-based tables (shift indices), `push` → `t[#t + 1]`, `splice` →
`table.insert` / `table.remove`, the cell map keeps the same integer key.
The same seed must then give the same node list in both; the check is to
dump the JSON of a few seeds from both and compare. The viewer's "Copy node
list (JSON)" gives the same lists for a schematic writer.

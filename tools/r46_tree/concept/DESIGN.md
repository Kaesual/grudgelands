# Tree concepts — growth model per species (Round 46, lane TREE, step 2)

The viewer (`trees.html`, built by `build.py`) runs the generator in
`treegen.js`. Every tree follows one readable logic: **stem → limbs →
twigs → leaf clusters at the twig ends**, thinning outwards (log 16/16 →
branch 10/16 → twig 6/16). Individuals differ only through the species'
parameters below, drawn from the seed; there is no per-node noise in the
wood. The one place a position hash acts is the outer band of a leaf
cluster, where about a third of the cells are left out so crowns are round
but not geometric. No root fins: wide trunks keep square log corners in
their ground layer instead (a subtle flare).

Common rules, all species:

- **Limbs** are staircases of face-connected cells that follow the straight
  line from their start to their target (the axis lagging furthest behind
  steps next). A limb leaving its parent sideways takes a level first step.
  A step that would touch other wood sideways takes another lagging axis
  when it can, so limbs do not fuse into ladders (connected boxes join every
  face neighbour).
- **Collars**: a quarter piece that a limb leaves from the side, or that
  carries non-quarter wood on top, becomes a plain log cube, so nothing
  overhangs its rounding; it reads as the swelling where a limb leaves.
- **Leaves** are the union of ellipsoid clusters; a leaf keeps a wood cell
  within 3 nodes (the engine's cube search for leaf decay) or is dropped,
  loose single leaves are dropped, everything stays inside 16 × 16 nodes.
- **Grain**: logs, branches and twigs carry facedir 0 / 4 / 12 so the bark
  runs along y / z / x — the direction the limb grew into that cell.

## Apple — the lollipop

A short stout bole (3–5 nodes; 2 × 2 in 40 % with 3–4) opens at its top
into 3–4 scaffold limbs (four on a 2 × 2 bole, one leaving each quarter,
turning like a pinwheel). Each limb stays in one upright plane (a cardinal
direction — a limb between two would zigzag in three axes) and climbs at
about 45° to 64–80 % of the crown radius, near the crown's mid-height. There
it forks once: one twig curves up and in towards the top of the ball, one
runs sideways along the rim from two-thirds of the limb. The crown is a round
core (radius 3.5–4.4 nodes, half height 2.75–3.25) plus a cluster on every
limb and twig end (radius 1.5–2.1), so it is round and lumpy where twigs end;
45 % lean their crown ¾ node to one side. 3–7 apples hang on leaves with open
air below. Height 8–11 (today 8), 8–11 wide (today 7). Keeps:
round ball on a short stout trunk, apples; gains height and a visible
branch structure.

## Jungle — tall stem, crown in clumps

A tree of 12–16 nodes (today 17), 2 × 2 in 30 % up to 70 % of its
height. It wanders: one side-step low (a "knee", one layer standing on two
logs) and in 60 % a second one higher that turns back or aside, so it swings
round its foot instead of leaning off. 3–5 limbs leave the upper 45 % at
2–3 node intervals, each turned 5–7 sixteenths of a circle from the last,
reaching 2.4–3.6 out and 1–2.3 up; each ends in a rounded clump (radius
2.1–2.6, 40 % fork into two smaller clumps). The leader ends in the highest
clump; 0–2 tiny clumps sprout low on the stem. Keeps: taller than apple,
irregular, crown in clumps; now lower than today and more irregular.

## Kapok — the emergent giant

21–26 high. A 3 × 3 column (60 %, square foot 2 layers, stepping in to 2 × 2
at 6–9 towards its lean) or a 2 × 2 one, clear up to 60 % ± 1 of the height.
There 4–6 big limbs leave sideways (first two cells are logs, then branch,
then twig), reach 3.4–4.4 out and rise 1.5–3.5, fork into two twigs with a
clump each; half carry a clump under their middle. A second tier of 2–4
shorter limbs 3–4 higher sits between them, the leader (log, then branch)
ends in the top clump, and a broad dome (radius 3.75–4.5, half height
2.75–3.25) joins the clumps. Keeps: a giant with a 2 × 2 / 3 × 3 trunk and a
broad high crown; up to 16 wide.

## Acacia — the umbrella (refined only)

A 1 × 1 trunk of 2–4 forks at its top into 2 (50 %, a wide V, 6–8 sixteenths
apart) or 3 thick limbs that climb out 2.9–4 and up 2–2.75. From every limb
end a twig climbs to one common level (one above the highest limb end) and,
in 55 %, splits sideways into two; every end there spreads a flat pad
(radius 2.6–3.25, flat bottom, a narrower second layer on top). The pads
merge into one wide umbrella, 11–16 wide (today 9). Keeps today's flat wide umbrella on
a forked trunk; refined by the common level and the forked pad twigs.

## Pine — the layered cone

A straight 1 × 1 stem of 12–17 that thins from log (lower 55 %) to branch to a
twig tip. From 2–4 up, a whorl every 2 nodes (3 in 15 %): four level twigs,
alternately along the axes and the diagonals, as long as the cone's radius
there allows; the cone narrows linearly from 3.1–3.9 at the lowest whorl to
the tip. Each whorl carries a needle skirt: wide at its own level, narrower
one above, so the cone is visibly layered; a small spire on top. Keeps:
straight trunk, layered cone; wider at the base than today (7 vs 5).

## Aspen — slender, pale, columnar

11–15 high on a slender 1 × 1 stem with a bare bole of 4–6 (log, then
branch, twig at the top; 40 % bend the top one node aside). The crown is a
narrow tall oval (4.25–5.25 wide, from the bole to the top) on short twigs
(1–2 out) that spiral up the leader, each turned 5/16 from the last, every
1–2 nodes, each with a small cluster that roughens the oval. Keeps: slender,
columnar, pale.

## Silverwood — elegant flame

15–18 high, old trees 19–22, on a slender 1 × 1 stem with a long clear bole
of 6–8. Above it 3–4 limbs (old: 4–5) step out two nodes and then rise
parallel to the leader to 3–5 below the top; each carries a slim leaf column
(radius 1.5–1.9) along its upright part, the leader the tallest. Together
they form a narrow flame (about 7 wide) with vertical grooves, distinct from
the aspen's oval. Keeps: elegant, tall-columnar, pale silver bark.

## Gravewood — dead and bent

A stem of 6–10 (up to 12 with stub and hooks), 1 × 1 (2 × 2 stump foot in 25 %). The stem bends one way: a knee
at 2–3 towards its lean, in 55 % a second higher one, mostly the same way.
3–5 bare limbs leave from 45 % of the height up, mostly on the side away from
the lean (they balance it), reaching 2.75–4.4 out and between ½ down and ¾
up; 20 % end hooked up, 40 % drooping, the rest straight, and every end is a
two-pronged claw. The top is a broken stub. 0–3 grey tufts of 1–3 leaves.
Keeps: bent, mostly bare, few or no leaves.

## Shapes (per wood type, 3 of the 4 allowed)

Boxes in sixteenths, `x1, y1, z1, x2, y2, z2`, centred on the node.

| shape | node box | notes |
|---|---|---|
| quarter | `{-8,-8,4, 8,8,8}` `{-6,-8,-1, 8,8,4}` `{-1,-8,-6, 8,8,-1}` `{4,-8,-8, 8,8,-6}` | fixed, facedir 0..3, inner corner (trunk axis) at +x +z for 0. Four facets stepping out; the outermost is 4/16 wide, the others 5/16, so two neighbours form one 8/16 face across their border. Four = round 2 × 2, corners of a 3 × 3 (edges and centre are log cubes). Tiles: top/bottom `*_tree_top`, sides bark. |
| branch | core `{-5,-5,-5,5,5,5}`, arms to the node border, e.g. right `{5,-5,-5,8,5,5}` | connected to every wood face neighbour (log, quarter, branch, twig); facedir only for the bark grain (connected boxes never turn, their tiles do: `drawNodeboxNode` → `getTile`). |
| twig | core `{-3,-3,-3,3,3,3}`, arm right `{3,-3,-3,8,3,3}` | as branch. |

The 4th slot stays free. Plain log cubes (existing node) fill trunk interiors,
collars and the first cells of the kapok's limbs.

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

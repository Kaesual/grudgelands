# WP13 playtest round 3, lane 2: the bushes that floated — 2026-09-15

The user's round-3 screenshot shows bushes hovering one node above the ground in
the terrain ring around Hearthpine Vale. This lane measured the defect in the
engine, found its cause, fixed it at the cause and re-measured.

**The cause is not round B and not the start terrain at all.** It is the
vertical anchor of every WP40 *template* decoration, and it has been wrong since
R6 first placed one. Round B only made it visible: before it, the blend ring
around a start carried no vegetation, so the nearest bush the user could stand
in front of was far away.

## 1. What was measured, and how

`tools/wp13/bush_probe` is a disposable engine probe, run through
`tools/wp13/run_bush_probe.sh` (a `PROBE=` of `tools/luanti_headless.sh`, so a
scratch `LUANTI_USER_PATH` under `/tmp` and nothing under the user's own Flatpak
folder). For every start of the roster it emerges a 381 × 381 square in 64-node
tiles, censuses each tile the moment it is generated, and counts, per node name
and per distance band, every decoration ROOT node whose node below is not solid
ground.

Three definitions carry the measurement, and each was forced by a wrong first
answer:

- A decoration's **root nodes** are the nodes of its lowest occupied schematic
  slice. The vocabulary is derived at run time from the production catalog
  (`wp40/r7_r6_manifest.lua`) by reading each template's own schematic through
  the engine — not hard-coded.
- A name is **gated** only if it can never be anything but a root: it occurs in
  some decoration's lowest occupied slice and in no higher slice of any
  decoration. The first calibration run gated every root name and reported 679
  floating `default:tree` at Dawnmere — an apple tree's *branches* are
  `default:tree` too, and branches hang over air by design. Trunks, branches and
  canopies are still counted, as `canopy_floating`, but never gated.
- An unsupported root is **floating** only when no node of the same name among
  its eight neighbours at its own height is supported. A blueberry bush is a
  single 3 × 3 layer of leaf nodes, so on a slope its outer cells hang over the
  next column's lower surface while its anchor cell rests on soil; Luanti's own
  decoration placement does exactly the same. Those are reported as
  `patch_overhang`.

The census also censuses each tile immediately rather than the whole start at
the end: a server with no player unloads mapblocks again while later tiles
generate, and the first version read `ignore` out of 9.8 % of its columns.

Bands are round B's own: pad 0–63, apron 64–73, blend ring 74–127, wild 128–190.

## 2. The baseline

Seed 531802985935182545, radius 190, floating roots / rooted nodes of that name:

| start | floating | biome bush | pad | apron | ring | wild |
| --- | --- | --- | --- | --- | --- | --- |
| Hearthpine | 1103 | `pine_bush_stem` 544/544, `blueberry…berries` 559/596 | 0 | 49 | 350 | 704 |
| Dawnmere | 357 | `bush_stem` 357/357 | 0 | 13 | 139 | 205 |
| Silverleaf | 0 | — (no bush in `grug_elf_forest`) | 0 | 0 | 0 | 0 |
| Stillgrave | 0 | — (`dry_shrub`, `bone_pile`: simple) | 0 | 0 | 0 | 0 |
| Sunscar | 351 | `acacia_bush_stem` 351/351 | 0 | 12 | 120 | 219 |
| Kapok | 0 | — (`junglegrass`: simple) | 0 | 0 | 0 | 0 |

The total is 1811. Seed 8675309 gives the same picture and 1636:
1046 / 271 / 0 / 0 / 319 / 0.

Three facts fall straight out of that table.

1. **Every bush floated, everywhere.** `pine_bush_stem`, `bush_stem` and
   `acacia_bush_stem` are 100 % floating outside the settlement pad — 544 of
   544, 357 of 357, 351 of 351.
2. **It is not round B's ring.** The wild band outside the 256-node blend
   envelope, which no WP13 lane has ever touched, carries the majority of them.
   Round B is only why the user can now see one from the gate.
3. **It is not the WP13 compositions.** The pad column is 0 on every start and
   every seed, including Dawnmere's own 216 authored `bush_stem` nodes. The
   blueprints plant correctly; the R6 decoration pass does not.

Every simple decoration — grass, ferns, dry grass, dry shrub, bone piles — was
already 0 of tens of thousands. The defect is specific to templates.

## 3. The cause

Luanti places a schematic decoration with its `y = 0` slice **on the surface
node**: `Decoration::placeDeco` hands `DecoSchematic::generate` the heightmap
value itself and the only adjustment is `place_offset_y`
(`reference_projects/luanti/src/mapgen/mg_decoration.cpp`).

WP40 anchors a template one node **higher**, on the first free node above the
surface, and deliberately so: `decoration_support_ref` asks for the host at
`candidate.y - 1`, and the writer refuses any decoration cell that would replace
a natural surface node. The two frames differ by exactly one node.

Two things the catalog inherited from Luanti encode that same one node of
clearance a second time, and each lifted its decoration into the air:

| what | where | affected |
| --- | --- | --- |
| an all-air bottom slice | `bush.mts`, `pine_bush.mts`, `acacia_bush.mts` — 3 × 3 × 3 with slice 0 entirely air | `meadows_bush`, `pine_hills_pine_bush`, `savanna_acacia_bush` |
| `offset_y_plus_1` | transcribed from MTG's `place_offset_y = 1`, which means "the node above the surface" — which is already the WP40 anchor | `pine_hills_blueberry_bush`, `deep_forest_apple_log` |

Of the 17 pinned schematics exactly three have an all-air bottom slice, and they
are exactly the three bushes the user saw hovering
(`tools/wp13/decoration_anchor_kat.lua`, `asset` rows). Every tree's slice 0
already carries its trunk, which is why trees never floated.

The alternatives the brief asked to rule out are ruled out by the same data:

- **The engine's own biome decorations.** There are none. `mods/BASE/default`
  registers Lua biomes and decorations only on `mg_name == "v6"`, and the game
  forces `v7`; the GRUG PATCH note at the end of `default/mapgen.lua` says so.
  A v7 mapgen with zero registered biomes places nothing.
- **Vegetation planted against a ground height a later pass lowers.** Both the
  planner and the writer read the one `planner_source.column_values_at`, the
  round-B pad-edge jitter included, and the placement is
  `candidate.y = terrain_y + 1` on both sides. The census confirms it: the
  simple decorations, which take the identical path minus the schematic, were
  already 0 floating.
- **The blend-ring planter placing at ground + 2.** There is no separate
  blend-ring planter; round B changed *who may host*, not *at what height*.
- **`buildable_to` / attached semantics.** Irrelevant — the nodes are written by
  the WP40 VoxelManip writer, not by an item placement.

## 4. The fix

One place, `mods/MAPGEN/grug_mapgen/wp40/r6_templates.lua`, in `rotate_record`,
which is the single point where an authored schematic plus an authored rule
becomes a WP40 world offset:

> A template is anchored by its lowest **occupied** slice, which rests on the
> first free node above the surface.

That consumes a leading all-air slice, and it is exactly the node
`offset_y_plus_1` names, so that rule now adds nothing. Combining the two is
refused (`template offsets its own air base`) rather than silently doubled.
`offset_y_minus_4` sinks the emergent jungle tree on purpose and is authored
against this anchor already, so it stands untouched.

No catalog row changed; the rule strings are still the authored input, and only
their interpretation moved into the frame WP40 actually places in.

Five of the twenty-one decoded template records move their `min_y`/`max_y` by
one node — the three bushes, the blueberry bush and the apple log. The vertical
SPAN of every record is unchanged, so `maximum_footprint` and the settlement
class of every row are unchanged.

## 5. After

Same probe, same seeds, same radius:

| start | user seed | boundary seed |
| --- | --- | --- |
| Hearthpine | 1103 → **0** | 1046 → **0** |
| Dawnmere | 357 → **0** | 271 → **0** |
| Silverleaf | 0 → 0 | 0 → 0 |
| Stillgrave | 0 → 0 | 0 → 0 |
| Sunscar | 351 → **0** | 319 → **0** |
| Kapok | 0 → 0 | 0 → 0 |
| **total** | **1811 → 0** | **1636 → 0** |

The only residue the census still reports at Hearthpine is 22 (user) / 37
(boundary) `patch_overhang`: outer cells of a blueberry bush hanging over the
step in a sloped column while the cell it is anchored on rests on soil. Luanti's
own placement does the same, the number barely moves between before and after
(23 → 22, 60 → 37), and it is reported beside the gate rather than inside it.

## 6. Frozen expectations this lane moves

| digest | before | after | why |
| --- | --- | --- | --- |
| `r7_manifest.frozen.decoded_templates` | `ab77c5efa9587823…` | `3734b3e2e3203c61…` | five of twenty-one decoded template records move `min_y`/`max_y` by one |
| `r7_manifest.SOURCE_PROJECTION_SHA256` | `de79b1fe983d8b5a…` | `8735e5f7af1c6331…` | the roll-up over the six limbs, of which only `decoded_templates` moved |

The other five limbs — `r6_catalog`, `accepted_r6_content`, `wp43_projection`,
`cultural`, `consumer_payload` — were read back from the engine and are
unchanged. Without the update the game does not boot at all
(`WP40 R7 manifest: frozen source projection differs`), which is how the
constants were found.

**Unchanged and verified so:** the six start blueprint identities
(`tools/wp13/evidence/20260914-capital-parts/start_identity.lua`, byte-identical
to the recorded `start-identity.txt`) and the WP13 final micro pair
(`0ed042f95db997bd…` under both interpreters, identical to the same run on the
pre-fix tree).

## 7. Not this lane's to fix

- **`tools/wp40/r6/micro_kat.lua` is red on `main`** with
  `r6 micro KAT: short-vein witness differs` — a resource shortfall witness
  (`micro_kat_fixture.lua:617`), unrelated to templates. Verified red on a
  pristine `19abee02` tree and red with exactly the same message afterwards.
- **`tools/wp40/r7/micro_kat.lua` is red on `main`** with
  `mods/ENTITIES/grug_mobs/start_npcs.lua:765: attempt to index field 'mob_class'`
  — the engine-free fixture cannot load `start_npcs.lua`. Same message before and
  after.
- **`tools/wp40/quality/final_micro.sh`** and the R7 integration KAT need the
  `reference_projects/luanti` submodule, which an agent worktree does not
  initialise.
- **`emergent_jungle_tree` is authored four nodes below the anchor**
  (`offset_y_minus_4`), which puts its bottom four slices inside the ground,
  where the writer's clearance test refuses them. It is very likely never placed
  at all. Out of this lane's scope, flagged rather than touched.
- **`swamp_papyrus`** carries two `default:dirt` slices before its papyrus and is
  therefore one node taller than Luanti's own placement would make it. It does
  not float and it is not this lane's defect.

## 8. What the review should look at

1. `rotate_record`'s new anchor loop reads the POST-replacement cell names
   (`replacement_for` runs in `base_record`), which is deliberate: a replacement
   that emptied a bottom slice should move the anchor with it. Check that is the
   intent.
2. `min_fy` is now `-1` for the three bushes, so the occupancy box and the
   owner-clipping test in `r6_settlement` reach one node lower. That reserves the
   ground node under a bush against another decoration and can clip a bush at an
   owner floor. Both are conservative; neither was measured separately.
3. The census's neighbour rule (`patch_overhang`) excuses an unsupported root
   next to a supported one of the same name. For one-column decorations there is
   no such neighbour, so the gate is unweakened there — but it is a judgement
   call, and the baseline numbers were taken with it in place too.
4. The probe's tile edges: the neighbour rule may read into a tile that is no
   longer loaded, in which case an overhang is counted as floating. That can only
   over-count, never under-count, and the after-runs are 0.

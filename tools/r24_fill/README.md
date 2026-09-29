# Round 24 Lane B — underground fill

Contract: [Round 24 plan](../../docs/planning/round24-mining-underground-mobs-plan.md),
rulings 9–15. Design text: `docs/design/world_zones.md` §7 ("Terrain fill",
"Decorative nests").

## Portable fixture (main correctness proof)

```sh
luajit tools/r24_fill/micro.lua "$PWD"
```

`fixture.lua` loads the production seams of `wp40/r6_settlement.lua` and
`wp40/r7_native.lua` (fake `core`, LuaJIT only; mapgen work runs no PUC) and
checks:

1. the fill predicate `r24_fill_stone` (R5 opcode-27 stone written into
   native void and untouched since; skin, filler, anchor-grade and
   foundation fills, native stone and ores are not fill);
2. the P8 resource-host base rule `r24_resource_host_base` (native hosts keep
   the former rule; fill stone hosts only the `default:stone` tier; claimed
   voxels keep their base; layer rock is no host);
3. the shallow strata in fill: a column whose first 40 nodes are fill gets
   exactly the bands it gets over native stone; steep and excluded columns
   stay bare; the former native-only rule leaves fill bare;
4. the mountain-interior layers: writes only to fill 41+ below the surface,
   only palette rock, gravel or dirt; interior stone share (measured
   88.7 %); smooth column offset (neighbour step ≤ 1, range ±5); identical
   result for 4 horizontal and 2 vertical owner splits; horizontal
   continuity; pockets inside their 16³ cell; seed and zone dependence; a
   known-answer digest of the layer writes of one synthetic mountain owner;
5. the native allowlist: nine ores in registration order (gravel blob, five
   tier strata, three decorative nests), nest hosts taken from the stratum
   rows, the first seven canonical rows byte-identical to the former digest
   `c29c9c6c…` (after the Lane A rename), and the new pinned digest.

`R24_PRINT_KAT=1` prints the layer digest without enforcing it (use after a
deliberate rule change, then update `LAYER_KAT`).

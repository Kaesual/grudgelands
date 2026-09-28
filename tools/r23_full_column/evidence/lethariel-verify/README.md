# Fast-path verify run over Lethariel's lake arcade (after Lanes B and C)

Tree: `wp48-full-column-preparation` with main f5a545bd merged (capital walls,
habitat renewal). One bounded engine run, 2026-09-28:

```sh
KEEP=1 SEED=10536739806879207652 \
  tools/r23_full_column/run_region.sh 1840,2079,-1540,-1221 200 --verify
```

Region: 4 x 5 tiles, x 1808..2127, z -1552..-1153: the north-east quarter of
Lethariel (anchor 1800,-1500) with the crown lake and the new stone_narrow
edge. The region was complete after 56 s; normal shutdown from a server step.

- `summary.txt`: 260 chunks; **180 fast-path chunks compared over the whole
  VoxelManip (content, param2, light of chunk and shell), 0 differ**, all
  `noop_equal_content` under the full writer.
- `run.log`: the per-chunk and per-tile lines; `game.patch`: the staged patch.
- Coverage of the capital walls: `tools/wp13/capital_walls_probe.lua` on this
  world's `grug_world_layouts.txt` (sha256 948d2d1b…d102db) dumped Lethariel's
  edge (84,622 cells, y 46..76, probe PASS). 17,793 edge cells lie in the
  region; of the 1,018 edge columns over the crown lake's authored capsules
  (arcade and piers), 790 lie in it.

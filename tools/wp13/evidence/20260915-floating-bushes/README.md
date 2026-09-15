# WP13 playtest round 3, lane 2: the bushes that floated

The user's round-3 screenshot shows bushes hovering one node above the ground in
the terrain ring around Hearthpine Vale. The research note is
`docs/research/wp13-floating-bushes.md`; this directory is its evidence.

**The cause is not round B and not the start terrain.** Every WP40 *template*
decoration is anchored one node too high whenever its schematic already encodes
its own ground contact, and it has been since R6 first placed one. Round B only
made it visible, by giving the blend ring around a start vegetation at all.

## The one-line picture

`renders/section-z5.txt`, one column of the dwarf ring, measured out of the
generated world on seed 531802985935182545:

```
 11 |    ###       |    11 |              |
 10 |    #T#  bbb  |    10 |    ###       |
  9 |              |     9 |    #T#  bbb  |
  8 |............. |     8 |............. |
      BEFORE (main)         AFTER (this lane)
```

`T` is a pine-bush stem, `#` its needles, `b` a blueberry bush, `.` soil. Before,
row 9 is air. The textured renders of the same box are `renders/bushes-before.png`
and `renders/bushes-after.png` (and `ring-before/after.png` for the whole box);
`renders/cells-{before,after}.tsv` are the world dumps they are drawn from, and
the only rows that differ between them are 78 bush cells, each exactly one node
lower.

## The measurement

`tools/wp13/bush_probe`, run through `tools/wp13/run_bush_probe.sh`, emerges a
381 x 381 square around each of the six starts in 64-node tiles, censuses each
tile as it is generated, and counts every decoration ROOT node whose node below
is not solid. Roots, the gated vocabulary and the overhang exemption are defined
in the probe's header and in section 1 of the research note; each definition was
forced by a wrong first answer, and both halves of the before/after comparison
use the identical probe.

Radius 190, both gate seeds, floating roots per start:

| start | user seed before | after | boundary seed before | after |
| --- | --- | --- | --- | --- |
| Hearthpine | 1103 | 0 | 1046 | 0 |
| Dawnmere | 357 | 0 | 271 | 0 |
| Silverleaf | 0 | 0 | 0 | 0 |
| Stillgrave | 0 | 0 | 0 | 0 |
| Sunscar | 351 | 0 | 319 | 0 |
| Kapok | 0 | 0 | 0 | 0 |
| **total** | **1811** | **0** | **1636** | **0** |

Three facts fall out of the per-name rows in `base-user.tsv`:

- **every bush floated, everywhere**: on the user seed `pine_bush_stem` 544 of
  544, `bush_stem` 357 of 357 and `acacia_bush_stem` 351 of 351 outside the
  settlement pad -- not a single planted one;
- **it is not round B's ring**: the wild band outside the 256-node blend
  envelope, which no WP13 lane has touched, carries most of them;
- **it is not the WP13 compositions**: the pad band is 0 on every start and both
  seeds, Dawnmere's own 216 authored `bush_stem` nodes included.

Every simple decoration — grass, ferns, dry grass, dry shrub, bone piles — was
already 0 of tens of thousands. The defect is specific to templates.

## The cause, in one sentence

Luanti places a schematic decoration with its `y = 0` slice ON the surface node
and measures `place_offset_y` from there; WP40 anchors a template one node
higher, on the first free node above the surface, because a decoration here
never cuts the natural surface. The all-air bottom slice of `bush.mts`,
`pine_bush.mts` and `acacia_bush.mts`, and the `offset_y_plus_1` transcribed
for `blueberry_bush.mts` and `apple_log.mts`, each encode that same node a
second time.

`r6_templates.lua` now anchors a template by its lowest OCCUPIED slice. No
catalog row changed.

## Checks

| Gate | Result |
| --- | --- |
| `luac51 -p` + SETGLOBAL, changed files | PASS, 4 files, 0 globals each |
| `luac51 -p`, tree-wide (`mods/*/grug_*`, `tools`) | PASS |
| five plain-5.1 sweeps, changed files | zero hits |
| five sweeps, `mods/*/grug_*` and `tools` | only the pre-existing hits `main` already carries |
| `tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `tools/wp13/decoration_anchor_kat.lua`, both interpreters | PASS, identical (`kat-luajit.txt`, `kat-puc51.txt`) |
| six start identities | byte-identical to `20260914-capital-parts/start-identity.txt` |
| `tools/wp13/final_micro.lua` pair | `0ed042f95db997bd…`, identical under both interpreters AND identical to the same run on the pre-fix tree |
| `tools/wp13/seam_kat.lua` | PASS, byte-identical under both interpreters |
| `tools/wp40/r7/run.sh unit` | PASS (`wp40-r7-unit.txt`) |
| headless boot on this tree | PASS, zero `ERROR`/`ModError` |
| engine census, six starts, both seeds | 0 floating roots |

Red on `main` before this lane, and red afterwards with exactly the same
message — verified against a pristine `19abee02` tree, not assumed:

- `tools/wp40/r6/micro_kat.lua`: `r6 micro KAT: short-vein witness differs`
  (`wp40-r6-micro-kat-pristine-main.txt` against `wp40-r6-micro-kat-this-lane.txt`);
- `tools/wp40/r7/micro_kat.lua`:
  `mods/ENTITIES/grug_mobs/start_npcs.lua:765: attempt to index field 'mob_class'`.

`tools/wp40/quality/final_micro.sh` and the R7 integration KAT need the
`reference_projects/luanti` submodule, which an agent worktree does not
initialise.

## Frozen digests this lane moves

| digest | before | after | why |
| --- | --- | --- | --- |
| `r7_manifest.frozen.decoded_templates` | `ab77c5efa95878232fd5138445b97394be44a700ea5c145c706505a64b427f94` | `3734b3e2e3203c61a2f08fdc7ee5abd7a8d3f7d00ae585c206aabc7c4ca7d42d` | five of twenty-one decoded template records move `min_y`/`max_y` by one |
| `r7_manifest.SOURCE_PROJECTION_SHA256` | `de79b1fe983d8b5aaadfd4180bc44e84704133248e20b117139267f232b803d4` | `8735e5f7af1c63316b13b71bfed3e2db02d83bd455e970c7ac5c0ed539536482` | the roll-up over the six limbs, of which only `decoded_templates` moved |

The other five limbs were read back out of the engine and are unchanged. Without
the update the game refuses to load at all
(`WP40 R7 manifest: frozen source projection differs`), which is how both values
were obtained.

## Reproducing

```sh
bash tools/wp13/evidence/20260915-floating-bushes/static.sh
bash tools/wp13/evidence/20260915-floating-bushes/kat.sh   <absent absolute dir>
bash tools/wp13/evidence/20260915-floating-bushes/engine.sh <absent absolute dir>
```

`engine.sh` builds the pristine-`main` half itself and runs all four censuses in
parallel on ports 31130/31140/31150/31160 (this lane's block); the recorded run
took about twelve minutes of wall time. The renders come from the probe's own
render mode:

```sh
DUMP="1,-40,-100,20" PORT=31103 tools/wp13/run_bush_probe.sh <dir> \
	531802985935182545 8 1 600
python3 tools/wp13/render_blueprint.py <dir>/cells.tsv -o bushes.png \
	--scale 22 --region 28 0 41 12 --ymin 5
python3 tools/wp13/evidence/20260915-floating-bushes/section.py \
	<before>/cells.tsv <after>/cells.tsv 5 28 41 5 13
```

## Files

| file | what |
| --- | --- |
| `files.sha256`, `files.sha256.sh` | the sources this lane changed or added |
| `static.sh`, `static.txt` | the static gates and their output |
| `kat.sh`, `kat-*.txt`, `start-identity.txt`, `final-micro-*.tsv`, `seam-luajit.txt` | the KAT set under both interpreters |
| `engine.sh`, `base-*.{log,tsv}`, `fix-*.{log,tsv}`, `probe-*.txt` | the engine census, before and after, both seeds |
| `renders/` | the world dumps, the textured renders and the ASCII section |
| `wp40-r7-unit.txt` | `tools/wp40/r7/run.sh unit` on this tree |
| `wp40-r6-micro-kat-*.txt` | the pre-existing red KAT, before and after |
| `sweeps.sh`, `sweeps-main.txt` | the tree-wide sweep hits of `main` itself, which this lane's are byte-identical to |

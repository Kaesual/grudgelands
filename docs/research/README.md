# Research and historical evidence

Research, decision records, completed round reports, reviews and test
evidence. **It is not the current specification or the work queue:** read
[the documentation guide](../README.md), [design](../design/README.md),
[status](../STATUS.md) and [BACKLOG](../../BACKLOG.md) first. A "must" in a
record here describes that record's scope and date; it does not authorize
restoring removed systems, migrations or old test campaigns.

## Still in use

- **Read by code or tools; do not move or edit:** the R6 documents that
  `grug_mapgen/wp40/r6_content.lua` and `r7_r6_manifest.lua` name as frozen
  digest keys (`wp40-simple-map-r6-contract.md`, `-decisions.md`, the five
  R6 content TSVs, `wp43_wp40_handoff.md`; `wp40-simple-map-r6-shore-bed.tsv`
  belongs to the same set); `r10-visuals/`, `round24-art/` and `assets/`
  (art tools and the `LICENSE-media.md` provenance); [licensing](licensing.md)
  (licence constraints, cited by CREDITS and README).
- **Cited as authority by live docs or code comments** (indexed in
  [docs/technical](../technical/README.md)): `wp40-simple-map-r6-contract.md`,
  `wp40-completion.md`, `wp6_spawn_budget.md`, `perf-review-2026-10.md`,
  `wp13-npc-sockets-contract.md`, `wp13-character-visuals-contract.md`,
  `hud-bars.md`, `mob-pressure.md`, `mapgen-chunk-profile-2026-10.md`.
- **Engine and reference research:** [engine API](luanti_engine_api.md),
  [mobs_redo](mobs_redo.md), [VoxeLibre/Minetest Game](voxelibre_minetest_game.md),
  [Lord of the Test](lord_of_the_test.md); verify against the pinned source
  before a new engine claim. Active Lua rules are in
  [luanti-lua.md](../technical/luanti-lua.md).
- **Recent studies** (proposals until the user decides; open items live in
  BACKLOG): [performance review R32](perf-review-2026-10-r32.md),
  [sound research](sound-research-2026-10.md),
  [items and professions analysis](items-professions-analysis-2026-10.md).

## History

Everything else (`round*`, `r9-*`, `r10-*`, `wp*`, `pregen-*`, `playtest*`,
completion, review and evidence folders) is the record of single deliveries.
Paths stay stable because plans, the archive and tools cite them. Before
acting on an old requirement, check its status in BACKLOG and the topic
design; older WP40 samplers and source rosters are not current.

## Archive

On 2026-11-16 (documentation cleanup, step 8) about 155 MB of evidence that
no code, tool or live document reads left the working tree for
`~/projects/grudgelands-orchestration/archive/docs-research/` (same relative
layout; git history keeps every file):

- 28 `wp40-*.tsv` artifacts, ledgers and receipts (all but the six small R6
  content files above), among them the 93 MB `wp40-simple-map-r6-artifact.tsv`;
- the twelve `wp40-*-evidence/` folders (855 files);
- `round23-tree-line/`, `round23-capital-walls/` and the renders of
  `round24-underground-fill/` (its receipt README stays here).

Links from the records here into that material name the archive path in
plain text.

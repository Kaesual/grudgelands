# Research and historical evidence

This directory preserves reference research, decision records, completed round
plans, implementation reports, independent reviews and immutable test evidence.
**It is not the current game specification or the current work queue.**

Use [the documentation guide](../README.md), [design](../design/README.md),
[status](../STATUS.md) and [BACKLOG](../../BACKLOG.md) first. Historical imperatives
such as “must implement” describe that record's scope and date; they do not
authorize restoring removed systems, migrations or old test campaigns.

## Useful technical references

- [Lua and engine constraints](luanti-lua.md): active technical requirements.
- [License compatibility research](licensing.md): retained provenance and constraints.
- [Engine API research](luanti_engine_api.md), [mobs_redo](mobs_redo.md),
  [VoxeLibre/Minetest Game](voxelibre_minetest_game.md),
  [Lord of the Test](lord_of_the_test.md): research tied to reference sources;
  verify against the pinned source when making a new engine claim.
- [Reference project registry](../reference_projects.md): pins, purposes and licenses.
- [Module implementation guide](../technical/module-guide.md): task-specific seams.

## Plans and evidence

`round*`, `r10-*`, completion/review files and evidence subdirectories retain the
history of individual deliveries. Old task cards and engineering briefs may
contain useful open requirements, but their current status and dependencies
must be checked in BACKLOG and the topic design before execution. In particular,
WP37 density tuning requires reconciliation; older WP40 samplers and source
rosters must not be restored or presented as current certification.

Paths remain stable where tools, license ledgers and external links cite them.
Archival status does not imply every recorded requirement is canceled. Open
requirements are tracked separately; uncertain ones belong in the consolidation
findings. The [baseline inventory](../maintenance/inventory-baseline.tsv) records
provisional roles and explicitly distinguishes structural from topic review.

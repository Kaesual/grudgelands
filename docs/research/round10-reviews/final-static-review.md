# Round 10 final static-artifact review

## Scope and verdict

- Frozen integration candidate: `2d3702d4627b215ea6782d10dc87e5d3b887c866`.
- Reviewed artifact directory: `/tmp/grudgelands-r10-final-static`.
- Review method: read-only inspection of the frozen input manifest, parser and static log, fresh-server audit, result summary, and every `diff --check` diagnostic. No interpreter, engine, or other runtime was started, and no candidate or evidence byte was changed.
- The 172-entry input manifest verifies with `sha256sum -c --quiet` (exit 0), and the worktree HEAD matches the recorded candidate.
- **Verdict: CLEAN STATIC.** The nonzero `diff_check=2` is fully accounted for by formatting in byte-preserved review/evidence artifacts. It does not identify production source or executable fixture damage. The final runtime pair and engine fleets remain separate pending gates.

## Parser and global-write review

- All 172 listed Lua files report `parser PASS`; the recorded parser/static gate result is 0.
- Production `SETGLOBAL` hits are the expected mod API tables: `grug_mobs`, vendored `mobs`, `grug_artisans`, `grug_cooking`, `grug_decor`, `grug_farming`, `grug_gathering`, `grug_gear`, `grug_nodes`, `grug_professions`, `grug_mapgen`, and `grug_abilities`.
- `mods/ITEMS/grug_quality/init.lua` deliberately publishes the existing `grug_items` API. Its file header documents that stable API ownership; the Round 10 diff extends the table and does not introduce a second quality global.
- Remaining `SETGLOBAL` hits occur in test/KAT fixtures that install and restore isolated engine or mod stubs (`core`, `ItemStack`, `vector`, and the relevant mod APIs). They are fixture environment construction, not undeclared production globals.

## Five semantic sweeps

- Sweeps 1, 2, and 3 have no hits.
- Sweep 4's hits are comments, quoted documentation fragments, or string construction/digest delimiters. In particular, the vertical bars in KAT canonical strings and `table.concat(..., "|")` are strings, while mathematical `|d|` and prose `&` occur only in comments. No Lua bitwise syntax is present.
- Sweep 5 has one hit at `mods/ENTITIES/mobs/api.lua:4658`: vendored, preexisting `minetest.is_protected(pos, "")`. The candidate changes elsewhere in that file concern the cliff predicate; the protection call is unchanged from the integration base. It is therefore an existing vendored alias, not a new `grug_*` namespace regression.

## Fresh-server and whitespace artifacts

- `fresh-server.log` reports `PASS: no stale migration or legacy-support code in changed runtime files` (exit 0).
- `diff-check.log` contains 16 formatting diagnostics in 14 non-production artifact files:
  - two preserved review Markdown files: one final blank line and one trailing space;
  - four CAP geometry logs with final blank lines;
  - three trailing tabs in the CAP development TSV;
  - one trailing-tab row in the combined development log;
  - six MAP-B evidence logs with final blank lines.
- These files are historical review output or immutable evidence whose bytes participate in recorded provenance. The whitespace has no Lua, registration, fixture, or runtime effect. Rewriting it would invalidate the preserved artifact hashes, so the correct disposition is to retain it and explicitly waive only these enumerated diagnostics.

## Calibration

- Findings: 0 High, 0 Medium, 0 Low.
- Review rounds: 1 static-artifact review round.
- Residual gates: the separately owned final PUC/LuaJIT digest pair, six-capital engine fleet, and six-start engine fleet; this review does not claim their results.

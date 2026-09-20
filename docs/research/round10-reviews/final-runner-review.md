# Independent final-runner composition review

## Verdict

**CLEAN — 0 Critical, 0 High, 0 Medium, 0 Low findings.**

- Runner candidate `9a5afb48c15dc99d8f98fac9b155a4177d42ea22`, parent `cdc79740`.
- Metadata archive `ff4671acd1d1354ea4ddea46cff4be7a864da92e`.
- Independent native GPT-5.6 Sol aggregation review. This is not a self-review of EQUIP production. No interpreter was run.
- MAP-B entries are intentionally absent until its source freeze; the runner must receive those entries and sentinels before the final pair.

## Runner composition

- The shell retains exactly one final portable LuaJIT invocation, one PUC 5.1 invocation and byte comparison. The only extra LuaJIT process is the existing broad WP13 development pre-step; no exhaustive or second PUC suite was added.
- All currently known fixture roots are included in the immutable input manifest: shipped `mods`, WP40/WP13 and retained packages, WORLD, FARM, EQUIP, CAP, ART, GAME and their transitive tool suites. Sentinels cover the key new real-code fixtures, including CAP purchase/services, EQUIP composition, FARM completion, ART mount icons, GAME cliff and the CAP-updated trainer oracle.
- The main runner preserves the established WP40/WORLD base. `r9_farm/farming_kat.lua` covers the earlier farming runtime while `r10_farm/final_micro.lua` covers the new 17-family completion/protection contract; these are distinct fixtures, not an accidental duplicate call.
- EQUIP is expanded to the exact 15-entry order from its frozen wrapper. It uses current CAP trainer/station fixtures and executes real recipe, quality, gear and vendor paths rather than the wrapper's `arg`-dependent body.
- CAP includes only its four portable returned functions. Planner/full-capital/B3D work remains outside PUC.
- ART correctly calls character visuals, mount-icon and media-binding fixtures directly. Its wrapper is not called, so ART does not repeat `r9_farm/farming_kat.lua`.
- GAME retains its exact order. The mounts KAT receives `{compact=true}`, excluding the full B3D/asset audit while preserving compact lifecycle/icon state. The standalone WP39 combat integration remains last, so its use of global `arg[1]`, direct output and non-restored globals cannot contaminate later fixtures.
- The generic `run` helper passes `(repo, options)` only to returned fixtures; Lua ignores the second argument where unused. It writes only non-nil canonical results and collects garbage after each isolated fixture. The top-level `arg` table is never replaced.

No duplicate ART farming call, unsafe wrapper invocation, missing known dependency root, argument mismatch or post-WP39 fixture was found.

## Metadata archive

- All nine rows in `docs/research/round10-reviews/reports.sha256` verify byte-for-byte against the archived reports.
- The README identifies implementation/reviewer model, candidate, disposition and fix-round count for EQUIP, GAME, WORLD, ART, ART integration and CLOSE. It does not convert earlier finding reports into current verdicts; later dispositions are explicitly authoritative.
- Its checkpoint statement correctly leaves CAP, MAP-B, FARM, the integrated pair, engine gates and dynamic documentation pending as of archive creation. Unknown elapsed time is recorded as unknown rather than reconstructed.
- The archive contains review reports only and makes no source-code approval claim.

## Required final additions

After MAP-B freezes, add its bounded returned fixtures, tool root and sentinel exactly as supplied by that lane. Then freeze the complete input manifest and run the single final interpreter pair. Any relevant runner, fixture or production-byte change after that point invalidates both outputs.

## Focused MAP-B composition rereview — 2026-09-20

**CLEAN — 0 Critical, 0 High, 0 Medium, 0 Low findings.**

- Runner candidate `70f04ceb` against `0c03af16`; review scope is the
  `final_micro.lua` / `final_micro.sh` delta. The other three commit files only
  archive the already completed independent shared-fixture review.
- No interpreter was run. The final PUC/LuaJIT pair remains pending on frozen
  integrated bytes.

The v3 composition removes the direct `r9_farm/farming_kat.lua` entry and runs
it exactly once through `registration_fixture.lua`. That wrapper uses the
fixture's observation callback after FARM's real `on_mods_loaded` callbacks and
before global restoration, then loads the real gathering harvest seam and real
`world_nodes.lua`. It verifies all 68 registered stage visuals, all 15 wild
source definitions, independent wild-node lifecycle/groups and non-aliased
visual tables. `r10_farm/final_micro.lua` remains a distinct 17-family
completion/protection fixture and does not invoke the R9 KAT, so no farming
lifecycle is duplicated.

`placement_fixture.lua` constructs the actual `world_content.lua` tail with the
real catalog and a real `r7_content.lua` resolver supplied by
`content_fixture.lua`. It covers all 15 plant routes, seven reef variants,
their real successor references and negative protection, housing, occupancy,
support, band, zone, shoreline, liquid and replay boundaries. The full writer,
runtime, template and pin derivation suites correctly remain LuaJIT-only and
are not pulled into the portable pair.

The shell adds `tools/r10_map_b` to the immutable input roster and explicitly
requires both portable fixtures plus the shared `crop_soil.lua` and
`crop_visual.lua` production seams. Existing roots already bind all shipped
`mods`, so the directly loaded world catalog, world tail, world node registrar,
gathering harvest and R7 content dependencies are hash-covered. Both returned
fixtures obey the existing `(repo)` aggregation contract, emit deterministic
text and run before the standalone WP39 fixture. No argument/global hazard,
duplicate ART/FARM wrapper, missing actual-API seam in the portable scope or
post-WP39 execution was found.

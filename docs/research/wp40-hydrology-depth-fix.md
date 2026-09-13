# Variable hydrology depth integration fix — 2026-09-13

The user could start `test_mapgen` after the manifest repair, but exploration
reached an ordinary water column whose varied depth differed from its profile's
nominal depth. R5's planner still required exact nominal equality for every
classified hydrology tuple, aborting R7's `on_generated` callback.

The existing decided contract in `world_zones.md` section 7 already requires
actual per-column depths for ordinary wet columns. The source publisher and
R6's neighbor/seal consumers had adopted it; R5 validation and the current
wet-column bed calculation had not. The portable geometry tests checked source
tuples without passing variable depths through the production R5 planner.

## Correction

Hydrology lookup checks the id and integer depth. Column validation owns the
context-sensitive contract: an ordinary wet column (no functional owner or
transition, water above terrain) must publish exactly water minus terrain and
stay within its profile range: 2→1..3, 4→2..6, 8→5..11, 12→8..15. Other profiles
and every dry, transition or functional tuple retain exact nominal depth.

The current wet-bed seal uses that validated depth, matching neighboring wet
columns and R6 consumers. It remains exactly three layers deep; wet-profile
seal and bank requirements remain validated. This also prevents silently
reinstating the old flat bed after merely fixing the crashing comparison.
No generation fallback, old-world reader or migration is introduced.

## Validation and review

[Real-engine reproduction](wp40-hydrology-depth-evidence/README.md) uses the
actual user seed and affected area: the previous production bytes reproduce
the reported error; the patched bytes generate it and adjacent mapchunks
successfully. Engine logs and exact planner patch are retained. No Rehearsal
VM or GUI was used.

The portable regression constructs the production R5 planner over four tiny
hydrology profiles, accepts each minimum/nominal/maximum depth and requires
opcode-18 bed seal runs at exactly actual bed minus two through actual bed.
It also checks positive nominal functional/rapid cases and rejects their
non-nominal variants, an out-of-range depth and a water/terrain/depth mismatch
with the expected error. The final micro-KAT now executes 75 production modules;
the combined R7 input rosters bind 115 paths. The normal quality
runner includes this planner fixture and the previous LuaJIT-only actual
manifest constructor regression.

Classification: non-trivial integration repair. Coordinator implements
production; configured GPT-5.6 Sol implements the bounded fixture. Independent
reviewer configured GPT-5.6 Sol: 0 Critical / High / Medium / Low, clean;
fix rounds 0; elapsed unknown. Plain-5.1 parsing, SETGLOBAL and five static sweeps
pass. The fresh-server source audit passes. The final quality gate runs the
real manifest constructor under LuaJIT, followed by exactly one compact PUC
process and the same fixture once under LuaJIT. Both 221-line outputs are
byte-identical, SHA-256 `247c0c1183c6f339e3c554d5c309591da71b2e94a331ebcbf0b51f81032aff65`.
The final gate input manifest verifies that all bound bytes stayed unchanged.
The previous startup smoke remains valid for startup, but did not exercise
this failing hydrology region.

## User runtime check

After syncing the fix, reopen `test_mapgen` and continue through the area that
previously crashed. Confirm new terrain loads and water beds retain variation.
No world deletion, seed change or stored-world cleanup is required.

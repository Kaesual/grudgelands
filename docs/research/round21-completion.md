# Round 21 integration receipt

Date: 2026-09-24. Coordinator GPT-6 Astra. Baseline `b5cf84d0`.
**Technical gates passed; final local merge/sync pending.**
[Execution ledger](../planning/round21-state.md),
[approved plan](../planning/round21-mapgen-and-playtest-fixes.md),
[playtest](round21-playtest.md).

## Scope

- Shared complete street junctions, corrected Kezamba core/gate landings,
  natural plot collars and bounded entrance approaches. Natural biome surfaces
  replace broad bare-stone ground at fitted POIs; authored foundations remain.
- Smoother broad terrain/detail blending, bounded natural-lake shoreline and
  bed variation, lateral coast transitions and low-altitude sand restriction.
- Varied coral patches, freshwater waterweed/lilies and one licensed animated
  passive fish with no rewards. P9G's live content window grows from 34 to 36;
  downstream anchor and settlement windows shift consistently.
- Approved fifteen-resource T1–T6 matrix, equal copper/tin, corrected Gold row,
  retained one-tier-ahead metal progression and existing deep multipliers.
- Both furnaces accept logs15s, coal80s and charcoal80s; normal ores10s and
  charcoal10s. Per-piece burning, seamless refueling and flame/arrow progress.
  Brewing and alloy durations retain their existing rules.
- Bronze-only 200-arrow craft, stoppable held-food feedback, independent boar
  selection box and authored POI names on the atlas.

## Independent review and calibration

All lanes are nontrivial. Native agents only; no provider CLI. Elapsed delivery
time was not reliably recorded and is **unknown**. Independent reviewers read
source and existing evidence rather than repeating heavy runtime checks.

| Lane | Implementer | Independent reviewer | Findings and correction passes |
|---|---|---|---|
| G1 settlement access | Astra worker | Astra nature worker | 0 Critical/High from independent review; author corrected street/verge interactions before review; one later root-integration correction adds the natural entrance fallback |
| G2 terrain/water/coast | Astra nature worker | Astra root | No Critical/High; clean source review; one scalar fixture assumption corrected |
| R1 resources | Astra root | Astra nature worker | No Critical/High; actual validator/quota and manifest pins reviewed |
| F1/F2/F3/F5 feedback | Sol worker | Astra root | No Critical/High; sound cancellation follow-up and targeted fixtures reviewed |
| F4 furnaces | Sol worker | Astra root and nature worker | No Critical/High; Medium brewing zero-elapsed refuel regression fixed; personal-light callback early return caught and fixed in one additional pass; shared refresh/timer and UI follow-ups reviewed |
| G3 aquatic | Sol worker | Astra root and nature worker | 0 Critical / 2 High (population/writer limits; successor offsets), 1 Medium cross-owner lily read; closed in two reviewed passes. Root's separate fish-offset and reef-hash findings corrected earlier |
| Combined pins and gate | Astra root | Astra nature worker | Actual constructor limbs match frozen pins; no substitute receipts or validators |

The gate's first exterior-terrain failure was a fixture overreach: it required
half-node steps beyond the authored lane. It now retains strict stairs through
the first exterior connection and permits ordinary one-node terrain afterward.
This is separate from the actual no-nearby-street entrance correction. Final
closure and test totals are recorded below.

## Evidence and limits

No full-world generation, seed fleet, exhaustive historical mapgen suite,
benchmark campaign or agent engine run. The real constructor and selected VM
owners use LuaJIT; the final portable pair uses one PUC process and one LuaJIT
process. The engine-shaped VM proxy does not certify native lighting/caves or
GUI behavior. Runtime acceptance remains [user-run](round21-playtest.md).

Fresh-world development remains in force; no migrations or rewriting existing
worlds. The Nether, Housing, wider quests/PvP and economy finalization remain
outside this round. No remote push/deployment is authorized or claimed.

Natural shoreline changes cover Frostbarrow/Moonfall lakes. Functional/civic
water connections retain their previous outlines. Personal furnace jobs keep
their progress UI private and publish only a
maximum cosmetic burn deadline for world light. The existing node timer expires
that light; it never scans or processes saved personal inventories. This is a
visual indication of observed burning, not a new background job scheduler.

## Final gates

- Actual `r7_manifest.new`, preparation source, `planner.plan_slice` and writer
  PASS. Three selected 80³ owners cover the reported Kezamba core/gate paths
  and one real plot approach, with zero remaining approach findings in touched
  plots. Final manifest:
  `3575ddcb09da9209be3f9dd57abac20b3f589ba1d7452f35fbb92752033e560a`.
- Final owner run: **19.46s wall / 19.39s CPU**. Earlier attempts exposed a
  missing R20 scenery registration in the older fixture, an overly strict
  exterior-terrain assertion, and the natural-entrance case. Three unique
  owners were reused (nine owner emissions total across three full attempts).
  Nature's two bounded scalar runs and the one rejected old fixture are also
  counted: **about 95 CPU seconds total for recorded larger mapgen checks**;
  small micros add less than a few seconds. No mapgen rerun for later furnace
  light changes. At most two interpreters ran concurrently.
- Final portable PUC-5.1/LuaJIT pair PASS, byte-identical SHA256
  `6b09edb0246c65d291770626ffed3dc3b287cb7775b8c4e0464e22480b8fc58e`.
  PUC0.53s CPU, LuaJIT0.23s CPU. One previous pair passed before the personal
  furnace-light scope closure; it is retained under `initial-*`, not used as
  final evidence. The replacement includes the actual registered timer/LBM
  fixture and both actual small planner regressions.
- All **60 changed/new source Lua files** pass the plain-5.1 parser. SETGLOBAL
  writes are expected mod declarations and isolated fixture doubles. Sweeps
  1/2/3/5 have no hits; sweep4 hits are reviewed comments or literal pipe-based
  data. The script's status1 reports these textual matches, not a parser failure.
- **990 source/media/fixture hashes** are recorded. Reference submodule pins
  are unchanged. No agent server was launched and no temporary test world
  needs cleanup.

Evidence: [real integration](../../tools/round21/evidence/integration.log),
[portable](../../tools/round21/evidence/portable/puc.log),
[static](../../tools/round21/evidence/static.log),
[hashes](../../tools/round21/evidence/inputs.sha256),
[reference pins](../../tools/round21/evidence/reference-pins.txt).
Final independent evidence review: native Astra `r21_nature_preflight` verified
all 990 hashes, final parity outputs, three-owner integration, static matches
and unchanged reference pins. **PASS, no open blocker.** No runtime repeated.
Local merge/sync receipt follows below.

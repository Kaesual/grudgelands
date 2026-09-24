# Round 21 integration receipt

Date: 2026-09-24. Coordinator GPT-6 Astra. Baseline `b5cf84d0`.
**Final integration and delivery pending.**
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
| F4 furnaces | Sol worker | Astra root and nature worker | No Critical/High; Medium brewing zero-elapsed refuel regression fixed; shared refresh/timer and UI follow-ups reviewed |
| G3 aquatic | Sol worker | Astra root and nature worker | 0 Critical / 2 High (population/writer limits; successor offsets), 1 Medium cross-owner lily read; closed in two reviewed passes. Root's separate fish-offset and reef-hash findings corrected earlier |
| Combined pins and gate | Astra root | Astra nature worker | Actual constructor limbs match frozen pins; no substitute receipts or validators |

The gate's first exterior-terrain failure was a fixture overreach: it required
half-node steps beyond the authored lane. It now retains strict stairs through
the first exterior connection and permits ordinary one-node terrain afterward.
This is separate from the actual no-nearby-street entrance correction. Final
closure and test totals are recorded below before delivery.

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
water connections retain their previous outlines. Personal furnace jobs update
their private UI, without a new scheduler to change the shared world node light.

Final gate output, CPU accounting, frozen hashes and local merge/sync receipt
will replace this pending statement before completion.

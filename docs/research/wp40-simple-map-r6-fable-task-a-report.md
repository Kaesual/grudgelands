All required sources are read and cross-checked. Here is the audit.

---

# WP40 R6 pre-R5 package — adversarial audit (Fable Task A)

## Verdict: CONDITIONAL GO — for pre-R5 contract preparation only

The approved D1–D6 set is substantially coherent, correctly separated from the R5 seam, and its numeric inputs check out against WP43 and the design authorities everywhere I could verify them. It is safe to keep preparing the R6 contract now. It is **not** yet safe to declare the content decisions "closed": I found two High gaps (decoration fill-ratio authority; cultural reservation footprint bound) and several Medium ambiguities that must be resolved by the user or explicitly frozen before the post-R5 contract-freeze pass, or implementers will be forced to invent design. Nothing here is an R6 implementation GO, and nothing here is an R5 acceptance finding.

## What was verified clean (selected)

- **Seed corpus (D5):** slots 1–27 in `source-r6/r6-seed-corpus.tsv` are byte-identical to the 27 fixed seeds in `source-r4/mods/MAPGEN/grug_mapgen/wp40/seed_corpus.lua:6-26`, including all seven existing SHA-label rows. The new slots 28–32 follow the corpus's own pre-existing continuation rule ("next unique broad label starting at grudgelands-wp40-seed-08", `seed_corpus.lua:41`). I hand-verified the hex→decimal projection of three rows (seed-01, seed-08, seed-12) — all exact. All 32 decimal strings are unique, and slot 18 (`2^53+1`) is a correct double-unsafe stress value justifying the strings-only rule.
- **Density numerics (D2):** the G2 12,000/6,000/3,000 rows, Abyssal 2,048 with T5 start, deep multipliers 5/4 at y=−1500..−1999 and 3/2 at y≤−2000, and G1's T2 harvest start all match `grug_materials/registry.lua:309-326`, `items_crafting.md:464-480` and `world_zones.md:818-826`. The "next-pick material available no deeper than" ladder (`items_crafting.md:397-404`) is satisfied by the table's first_tier column (iron in T1, silver in T3, emberglass in T4, abyssal in T5).
- **Cultural identities (D1):** all six cultural keys, race assignments and source-language strings match `grug_materials/registry.lua:262-276`; the allowed-biome sets are satisfiable in each race's zones per the §8 palettes (one dead entry — see Low findings).
- **Housing export numbers:** `R6-PREFLIGHT.md:216-219` (1,228,086 centres / 123,210 origins / 230 runs / 0 violations) matches the live V1e artifact `wp40-simple-map-r2-artifact.tsv:1444-1447`, not the superseded V1d numbers — the preflight quotes the correct live artifact.
- **Interpreter/concurrency plan:** preflight §9 and outline §17 correctly restate the LuaJIT/PUC split, the single post-freeze micro-KAT parity pair, and the seven-process cap from `AGENTS.md:131-158` and `luanti-lua.md:329-381`.
- **Boundary discipline:** D1–D6 correctly refuse rerolls, late repair, seed replacement, quota reinterpretation of palette shares, a second writer, and engine `register_ore`/`register_decoration` paths, consistent with the rebase plan's stop conditions and the engineering brief §3.4.
- **Canopy-litter correction:** the inventory's jungle-fringe row encodes the target (canopy litter) rather than the shipped legacy registration, which is the correct precedence per `biomes_mobs.md:704` and the preflight's authority item 2.

## Findings — genuine defects and gaps

### High

**H1 — The "decided fill ratio" of D4 does not exist for much of the decoration catalog, and conflicts where it does.**
`R6-DECISION-PACKET.md:183-186` (rule 1) instructs converting "the decided fill ratio" to an exact rational, but `biome-content-inventory.tsv` carries no fill column, and the target authority `biomes_mobs.md:692-706` gives numbers for only some trees: nothing for blight gravewood, badlands cactus/shrub, swamp papyrus, crags snowy pine, or any ground cover (grass, ferns, junglegrass, dry shrub, bone piles, bushes, blueberry, fallen log). Those values exist only in legacy `grug_mapgen/decorations.lua` (e.g. blight gravewood 0.0015 at :270-271, badlands cactus 0.001 at :261-262, swamp papyrus 0.02 at :322-323, meadow grass 0.06 at :171-174), which the preflight itself declares "migration inputs only… do not override the target design" (`R6-PREFLIGHT.md:82-85`). Worse, where both sources speak they conflict: `biomes_mobs.md:696` gives elf forest "silverwood + apple mix (fill 0.007)" while legacy sums to 0.009 (silverwood 0.007 at `decorations.lua:202-204` plus apple 0.002 at :205-206); pine hills' §2 "0.006" excludes the legacy pine_bush 0.006 and blueberry 0.001. **Failure scenario:** an implementer silently adopts the legacy table as "the decided ratios", violating the packet's own authority rule; or two independent artifacts disagree by biome; either way canonical evidence is generated from numbers no one decided. **Required:** a per-decoration numeric fill table must be produced and user-approved (or an explicit "adopt legacy values X, Y, Z as target" ruling) before contract freeze. The exact missing-decision list is in the Q4 answer below.

**H2 — D1's cultural reservation has no frozen footprint bound.**
`R6-DECISION-PACKET.md:52-54` says "An accepted slot reserves its bounded ground position even before WP33 provides a visible node," and the API invariants at :66-70 make "bounded footprint" a WP33 registration field — supplied *after* R6 has already generated slots and after ordinary decorations have avoided "that reservation". The size of the reservation R6 makes is never stated. **Failure scenario:** R6 reserves one column per slot; WP33 later registers a source feature with a 3×3 footprint; movement and fallback search are forbidden (:67-70), so registration fails closed with no permitted remedy, or the realized feature overlaps an already-settled tree footprint — exactly the collision D1 exists to prevent. **Required:** freeze a maximum per-slot reservation extent (e.g. exactly one column, or a fixed N×N×H volume) now, coordinated with WP33's expected feature sizes; WP33 registrations exceeding it fail closed by contract.

### Medium

**M1 — The exact-host budget is defined per resource/cell with a singular "applicable deep multiplier", but nearly every tier and multiplier boundary cuts through a 16³ cell.**
Cells are globally anchored (`R6-DECISION-PACKET.md:129`); tier boundaries at −100/−300/−500/−700/−1000 are not multiples of 16, and even −1500/−2000 boundaries land mid-cell (cell floor(−1500/16)=−94 spans −1504..−1489; cell −125 spans −2000..−1985). D2's budget step (:130-133) doesn't say whether the denominator/multiplier is chosen per cell, per node, or per sub-band. "A vein never crosses its … eligibility band" (:136) implies sub-band budgets but never defines them. **Failure scenario:** one implementation applies the cell-top's multiplier to the whole cell, another splits by y — different canonical bytes, or veins at −1999/−2000 receive the wrong budget by construction. **Fix (freezable now, non-design):** exact per-(resource, cell, band) formula proposed below.

**M2 — The "deterministic hash-based remainder trial" has no exact arithmetic definition.**
A 64-bit hash cannot pass through a Lua double, and a float threshold comparison invites platform/implementation divergence and unquantified bias. **Fix (freezable now):** exact integer modulus construction with a quantified bias bound, proposed below with KATs.

**M3 — D6's fixed-versus-varying sentence is literally wrong and could weaponize the "accidental variation" gate.**
`R6-DECISION-PACKET.md:239-240`: "Each seed must carry identical fixed-layout digests and may vary only R4 logical biome selection and R6 content candidates/settlement." But R3 height detail and the native v7 substrate are also legitimately seed-varying — `H(full_seed,x,z)` is seed-keyed (`wp40-simple-map-rebase-plan.md:118-121` explicitly says height/resource audits use representative seeds), and the outline's own per-seed ledgers require "host volume by region/depth" per seed (`R6-CONTRACT-OUTLINE.md:236-238`), which varies with v7 caves. **Failure scenario:** the per-seed manifest gate is built over derived surface/host data and every seed "fails", which under the no-late-repair rule (:349-352) stops the acceptance run; or the gate is quietly weakened mid-run. **Fix (freezable now):** define "fixed-layout digests" as exactly the input-artifact digests (R2/R3/R4 artifacts, corpus, manifest) plus the fixed anchor/socket manifest rows; define everything else as legitimately seed-varying.

**M4 — The ±5% parity ledger is not computable from the approved package.**
`world_zones.md:823-826` requires "total expected natural vein count plus the one ordinary camp budget … within ±5%, normalized by accessible host volume", but (a) the ordinary camp budget is an undecided range, "10–15 renewable resource nodes per camp" (`world.md:194-197`), owned by WP13; (b) the baseline of the ±5% comparison (mean of six vs pairwise extremes) is undefined; (c) veins vs nodes as the parity quantity needs confirmation (D2 :139-140 says density acceptance uses nodes but the §11 gate says vein count). **Failure scenario:** the ledger formula is invented during implementation; a failing region then triggers exactly the "repair with a local exception" path D2 forbids. Formula proposal below; the camp constant and baseline semantics are user/WP13-visible choices.

**M5 — D1's T4-concentration zone set is ambiguous and creates an undeclared faction asymmetry.**
"A non-civic contested level-31-40 zone of the owning race region" (`R6-DECISION-PACKET.md:39-41`) matches both Ashenward March (`world_zones.md:549`) *and* The Broken Causeway (`world_zones.md:590`, race_region Human, level 31–40, contested) for humans, while dwarf/elf/orc/troll/undead each match exactly one zone (their 41+ front zones are excluded by :43-44). Humans would get two concentrated T4 cultural zones; every other race one. This may be a deliberate reading of §11's "contested level-31+ land" or an accident. **Required:** an explicit zone list (or an explicit exclusion of Battlegrounds zones) in the frozen allowlist; either answer is fine, but it is a user-visible supply decision, not an implementation detail.

**M6 — "Eligible in every named land column" leaves ore eligibility under water columns undefined.**
`R6-DECISION-PACKET.md:90-92` excludes deep ocean and channels explicitly, but is silent on the substrate beneath planned water (rivers, lakes, the four bays) and the coastal shelf — all diggable columns with stratum hosts. **Failure scenario:** one reading places no ore beneath any river or bay (a player-visible barren-rock band and a parity denominator change); the other includes them. This changes accessible-host-volume normalization and is user-visible. **Required:** one sentence deciding the column classes eligible as ore hosts.

### Low

**L1 — Dead allowlist entry:** `r6-cultural-opportunities.tsv:5` allows `grug_badlands_east` for orc red_ochre, but `grug_badlands_east` occurs only in Troll-region palettes (Thunderroot Wilds `world_zones.md:576`, Stormscale Summit :593), where orc race-region eligibility never holds. Unsatisfiable row — either dead future-proofing or a mistaken key; harmless but should be resolved or annotated.

**L2 — Outline/packet wording conflict on shore/bed depths:** `R6-CONTRACT-OUTLINE.md:148-151` asks to freeze per-biome "shore/bed … depths", while D3 (`R6-DECISION-PACKET.md:155-158`) explicitly declines a biome-owned shore/bed depth (R3/R5 own the span). Clean up before freeze so nobody re-opens vertical authority.

**L3 — Undecided deterministic parameters for simple decorations:** the gravewood trunk height range 2–4 (`decorations.lua:270-271, 281-282`), dry-shrub `param2 = 4`, `place_offset_y` values (blueberry +1, apple_log +1, emergent jungle −4) and the legacy `y_min = 60` snowy-pine rule have no decided deterministic replacement in D4 (which fixes only column selection and rotation hash domains, :187-188). Mechanical to freeze (add a height hash domain and constant table), but currently missing.

**L4 — The ±10% paired ledger is probably empty in R6.** The paired families (`world_zones.md:858-861`: leather, cloth, silk, feathers, healing herbs, spices, reagents) are all mob-drop or WP33/WP10 surfaces; D4 keeps herbs/spices/cultural out of R6 (:176-181). "Where R6 owns the relevant opportunity surface" may bind zero rows. Declare the expected-empty result explicitly so a vacuous pass is not mistaken for evidence.

**L5 — WP33 rollout consequence unstated:** slots are invisible reservations; chunks generated before WP33 registers its sources can never receive the node (no healing writer is authorized by D1). Acceptable under fresh-world discipline, but the contract should say so, or a world created between R7 cutover and WP33 will permanently carry empty slots in explored terrain.

**L6 — apple_log replacement target:** legacy replaces `flowers:mushroom_brown` with `air` (`decorations.lua:224-229`); the target design gives mushrooms to WP33. Freeze the R6 replacement (air) explicitly so the template digest is stable.

### Seam observations (not findings; the R5 snapshot is unaccepted)

The snapshotted R5 contract reserves exactly `BIOME_TOP/FILLER/SHORE/BED` (P7), `RESOURCE_EXACT_HOST` (P8) and `DECORATION` (P9) (`source-r5/...r5-contract.md:1169-1171`), with aux frozen to `AUX_NONE` and a reviewed successor schema required for anything more (:1214-1219). D3's snow-dust role and D4's template-versus-simple record split and rotation/template-identity fields therefore all require the successor schema R6 must define — none of them fit the reserved vocabulary as-is. That is exactly the "mechanical projection" work the packet defers, but the R6 outline should not assume the reserved token set is sufficient. Also note water dressing is P6 (R5-owned opcodes `ORDINARY_WATER`/`RIVER_WATER`); D3's water materials will be realized through the R5 content-contract role mapping, not new P7 records — the outline's P7 phrase "top/filler/shore/bed/dust/water roles" (`R6-CONTRACT-OUTLINE.md:111`) should be tightened after R5 acceptance.

## The eight audit questions

**Q1 — Are D1–D6 jointly implementable without contradiction or hidden design invention?**
Mostly yes: the cross-decision orderings interlock correctly (cultural reservations resolve before templates in D4 rule 3; camps/sockets excluded from D2 multipliers; D3 declines vertical authority; D5/D6 fix the evidence frame). The G1 table is an acknowledged, user-approved interpretation, not hidden invention. But D4 cannot be implemented without inventing fill ratios (H1), D1 cannot be implemented without inventing a reservation extent (H2), and the parity ledger cannot be computed without inventing a camp constant and baseline (M4). With those closed, the set is jointly implementable.

**Q2 — Does the exact-host rational-budget algorithm admit a platform-independent, unbiased, bounded definition at negative coordinates and every boundary?**
Yes, with the sub-band and trial definitions currently missing (M1, M2). Division by 16 is a power-of-two operation, exact in doubles at all map coordinates, so `floor(c/16)` cell anchoring is platform-independent including negatives. The proposed formulas below are integer-only, bounded, and biased by at most `Dm/2^64 < 2^-47` per trial (exactly quantified, effectively unbiased against ±5%/±10% tolerances).

**Q3 — Can six-neighbor vein formation be deterministic and bounded without search/repair loops or leakage?**
Yes. Budget → fixed vein-count split → hash-ranked roots over a canonical host enumeration → hash-selected frontier growth, all confined to cell∩band, with shortfalls counted and never refilled, is bounded by ≤ cap growth steps per vein and needs no retry. The band definition must include the host-node identity (so a coal vein cannot cross −100/−101 from stone into slate). The split rule and enumeration order are unspecified today — mechanical, proposed below.

**Q4 — Are all decoration parameters actually authorized?** **No.** Target authority vs legacy migration values separate as follows. *Authorized by target design:* asset/template identities and host (place_on) nodes per biome (inventory TSV + `biomes_mobs.md` §2), the silverwood-via-aspen replacement concept, class priority order, the rotation set {0,90,180,270}, tree fills for meadows-apple 0.0015, savanna-acacia 0.002, jungle_edge 0.008, deep-jungle aggregate 0.025, deep-forest aggregate 0.02, bone-forest 0.015, pine aggregate 0.006, elf aggregate 0.007. *Legacy-only (unauthorized as target):* every ground-cover fill (grass 0.06, ferns 0.02, junglegrass 0.04/0.05, dry shrubs 0.004–0.015, bone piles 0.002/0.004, bushes 0.004/0.006, blueberry 0.001, apple_log 0.001), blight gravewood 0.0015, badlands cactus 0.001, swamp papyrus 0.02, crags snowy pine 0.002 with y≥60, all place_offset_y/param2/height-range values, and the per-decoration split of the aggregate fills (0.004+0.002 pine; 0.012+0.008 deep forest; 0.02+0.005 jungle). *Conflicted:* elf forest 0.007 (target) vs 0.009 (legacy sum). **Exact missing-decision list:** (1) elf-forest total and split; (2) pine-hills bush/blueberry/fern inclusion and numbers; (3) meadow bush + grass numbers; (4) blight three fills; (5) badlands two fills; (6) swamp two fills; (7) crags snowy-pine fill and the y≥60 rule's carry-over into the new height model; (8) all simple-decoration height ranges/offsets/param2; (9) apple_log replacement target; (10) per-species split of every aggregate fill.

**Q5 — Can invisible cultural reservations remain stable through WP33?**
Yes in architecture: slot identity is canonical (cell + seed hash), WP33 cannot move or reselect it, the registration API fails closed on unknown/duplicate/mismatched keys, and realization runs inside the one writer. Two conditions: freeze the reservation extent now (H2), and state the pre-WP33-chunk consequence (L5). With those, no second writer and no slot movement are needed at any point.

**Q6 — Are the tolerance/gate definitions mathematically complete and selection-bias-resistant?**
Not yet complete — the package correctly defers them ("define all denominators, rounding, tolerances, zero-host behavior… before generating canonical evidence", `R6-CONTRACT-OUTLINE.md:255-256`) but they are R5-independent and should be frozen now (M4 plus proposals below). Bias resistance is genuinely strong: the corpus is fixed before measurement and independent of the evidence (D5), densities cannot be tuned inside or after the acceptance population, failed regions cannot be repaired by seed replacement (D2 :122-124), aggregate parity cannot hide a per-seed missing access class (D6 :241-244). The one residual bias is disclosed and acceptable: the single permitted calibration revision is tuned on the same 32 seeds it is then judged on — mild overfitting-to-corpus, mitigated by the corpus not being outcome-selected.

**Q7 — Is the fixed-versus-varying split correct?**
Conceptually yes: R2 geometry, anchors, housing masks/packing and the 24 apex sockets are fixed by layout; R4 logical-biome selection and R6 content vary by seed. The once-only apex geometry/reachability proof is supported by R3's deliberately seed-independent anchor and route-endpoint pins (`wp40-simple-map-r3-contract.md:466-479`, "without making route endpoints depend on the seed"), and D6's per-seed manifest check of the 24 sockets is the right backstop. The defect is the D6 wording (M3): R3 ambient height detail and v7 substrate legitimately vary per seed, and the contract must say precisely which digests are "fixed-layout".

**Q8 — What freezes now, what waits, what needs the user?** See the table.

## D1–D6 individual assessment

- **D1 (cultural boundary):** sound ownership split, correct single-writer preservation, correct density-replacement (not additive) rule; blocked by H2 (footprint) and M5 (zone set); L1 dead entry.
- **D2 (resource density):** numerically consistent with WP43 and design; G1 interpretation legitimate and approved; blocked by M1/M2 (sub-band + trial arithmetic, freezable) and M6 (water-column eligibility, user); vein/ledger structure sound.
- **D3 (shore/bed):** complete and consistent (16 rows, families match biome soils, water-material rule matches `world_zones.md:408-415`, snow-dust confinement correct); only L2 wording cleanup and the post-R5 dust-opcode projection remain.
- **D4 (decorations):** the deterministic model (cells, hash domains, resolution order, footprint reservations, template digest/load-once rule — which correctly generalizes the legacy schematic-cache landmine documented at `decorations.lua:41-63`) is sound; blocked by H1 and L3/L6.
- **D5 (seed corpus):** verified correct and unbiased; freezable as-is.
- **D6 (fixed vs varying):** correct intent, correct aggregate+extrema parity design; needs the M3 wording repair before it becomes a gate.

## Disposition table

| Item | Disposition |
|---|---|
| 32-seed corpus rows + acceptance checks (D5) | safe to freeze now |
| Resource density table, vein caps, deep multipliers, G1 curve (D2 numbers) | safe to freeze now |
| Cell geometry, cell∩band budget rule, remainder-trial arithmetic, vein split/growth/settlement order (formulas below) | safe to freeze now |
| Canonical string-name manifest (16 biome IDs, node/schematic/WP43 identities) | safe to freeze now |
| Shore/bed/dust/water node mapping and precedence (D3, nodes only, no spans) | safe to freeze now |
| Cultural allowlist keys, densities, rejection accounting (D1, minus footprint and zone-set items) | safe to freeze now |
| Ledger arithmetic: parity/pair/access/zero-host/rounding formulas (once user inputs below are supplied) | safe to freeze now |
| Housing export projection rule bound to R2 file digest, with quoted metrics | safe to freeze now |
| Disabled-state, no-double-writer, interpreter split, seven-process cap, micro-KAT parity plan | safe to freeze now |
| Decoration class priority, rotation set, template digest/load-once, halo principle | safe to freeze now |
| D6 "fixed-layout digest" definition (input artifacts + fixed manifest rows only) | safe to freeze now |
| P7/P8/P9 record fields, tags, validators; successor plan-schema extensions (dust opcode, template/simple split, aux, stable-ref budget) | must wait for accepted R5 |
| Owner-slice emission/halo/clipping rule for footprints and veins | must wait for accepted R5 |
| Adapter/buffer/transaction semantics, VM and chunk-order fixtures, byte-level expected artifacts | must wait for accepted R5 |
| Allocation/performance bounds; module names bound to planner/adapter ownership | must wait for accepted R5 |
| Acceptance lineage digests (R5 commit/artifact/review) and the offline substrate/host-count seam | must wait for accepted R5 |
| Per-decoration fill table (incl. elf-forest conflict, blight/badlands/swamp/crags, ground cover, splits, heights/offsets) | requires user design |
| Cultural reservation footprint bound (with WP33) | requires user design |
| T4 cultural-concentration zone set (Broken Causeway in/out) | requires user design |
| Camp-budget constant and ±5% baseline semantics (with WP13); veins-vs-nodes parity quantity | requires user design |
| Ore-host eligibility of sub-water/shelf columns ("named land column" scope) | requires user design |
| Explicit declaration if the ±10% paired ledger is empty in R6 | requires user design |

## Proposed exact formulas and KAT vectors (non-design arithmetic)

**Cells (negative-safe).** `cx = floor(x/16)`, likewise cy, cz. Division by 16 is exact in IEEE doubles for all map coordinates, so this is platform-independent. KATs: x=0→0; 15→0; 16→1; −1→−1; −16→−1; −17→−2; y=−1500→cy=−94 (cell −1504..−1489); y=−2000→cy=−125 (cell −2000..−1985).

**Bands.** For resource r, a *band* is a maximal y-interval on which (stratum host node, table denominator D, deep multiplier m) are all constant. Boundaries: −100/−101, −300/−301, −500/−501, −700/−701, −1000/−1001 (host/tier changes), −1499/−1500 and −1999/−2000 (multiplier changes), plus r's first_tier top. Budgets, roots and veins are computed per (r, cell, cell∩band); a vein may not leave its cell∩band. KATs: cell −1504..−1489 splits into ordinary-T6 (−1499..−1489) and deep-1 (−1504..−1500); cell −2000..−1985 splits into deep-1 (−1999..−1985) and deep-2 (−2000); cell −112..−97 splits at −100/−101 (stone vs slate hosts).

**Budget.** With H = exact eligible hosts in cell∩band, m = mnum/mden (1/1, 5/4 or 3/2), D from the table: `N = H*mnum`, `Dm = D*mden`, `base = floor(N/Dm)`, `rem = N − base*Dm`. All values ≤ 48,000·… far below 2^53. KATs: coal (D=128, m=1), H=4096 → B=32 exactly, rem 0. Iron deep-1 (m=5/4): H=4096 → N=20480, Dm=512 → B=40 exactly. Iron deep-1, H=4000 → N=20000, base=39, rem=32 → extra-node probability 32/512 = 1/16. Diamond T4 (D=12000), H=100 → base 0, rem 100 → P=1/120. H=0 → B=0, no trial evaluated.

**Remainder trial (integer-only, quantified bias).** Take two 32-bit words hi, lo from the domain-separated canonical hash (T1 length-prefixed grammar, e.g. `(schema, "r6-ore-trial", layout_id, resource_key, [cx,cy,cz], band_ordinal)`, digest words 0 and 1 as unsigned big-endian, matching the housing-pack precedent in `wp40-simple-map-rebase-plan.md:757-759`). Compute `r64 = ((hi mod Dm) * (2^32 mod Dm) + (lo mod Dm)) mod Dm` — every intermediate < 48,000² ≈ 2.3·10⁹ < 2^53. Fire the extra node iff `r64 < rem`. Bias ≤ Dm/2^64 < 2^-47. KATs: Dm=512 → 2^32 mod 512 = 0, so r64 = lo mod 512; hi arbitrary, lo=1000 → r64=488. Dm=12000 → 2^32 mod 12000 = 11296; (hi=1, lo=0) → r64=11296; (hi=0, lo=2147483648) → r64=11648.

**Vein split and growth.** `v = ceil(B/cap)`; vein i has size `floor(B/v) + (i ≤ B mod v and 1 or 0)` (balanced; B=9, cap=8 → sizes 5,4; B=32, cap=8 → 8,8,8,8). Enumerate eligible hosts in canonical (z, x, y ascending) order; rank by per-host hash `(…,"r6-vein-root", key, cell, band, x,y,z)`; roots are the v lowest-ranked unclaimed hosts, in rank order. Growth: from the vein's claimed set, at each step choose the eligible unclaimed six-neighbor inside cell∩band with the lowest hash `(…,"r6-vein-grow", key, cell, band, i, x,y,z)`; stop at target size or empty frontier; shortfall is counted, never refilled. Bounded by ≤ cap steps × ≤ 6·cap frontier checks; no iteration-order dependence (`pairs` forbidden on the hot path).

**Decoration/cultural candidate counts.** Same floor+trial with N = E·fillnum, Dm = fillden over eligible surface columns E in a 16×16 cell. KATs: fill 3/2000, E=256 → rem 768/2000; fill 1/50, E=256 → base 5, rem 6 → P=3/25; cultural 1/4096, E=256 → P=1/16; T4 cultural 1/1024 → P=1/4. Candidates are the B lowest-hash eligible columns; that rank is the D4 rule-3 "candidate rank".

**±5% parity (proposal; baseline choice flagged).** Per region g over the 32-seed aggregate, with exact rationals: `M_g = (V_g + C) / Hvol_g` where V_g = accepted veins summed over seeds, Hvol_g = eligible hosts summed over seeds, C = the decided camp constant × 32. Mean-form pass: for all g, `20·|6·M_g − S| ≤ S` with `S = Σ M_g`, compared after cross-multiplication in integers. Alternative pairwise form: `20·(maxM − minM) ≤ minM + maxM`… the choice of mean-vs-pairwise, C, and veins-vs-nodes is the user decision in M4; the comparison mechanics above are freezable.

**±10% paired (proposal).** Per bracket, `20·|O_accord − O_throng| ≤ O_accord + O_throng` (that is |diff| ≤ 10% of the two-faction mean), integer cross-multiplied.

**Zero-host rules (proposal).** Cell∩band with H=0: budget 0, trial skipped. A (region × required band) aggregate with zero hosts over all 32 seeds: hard fail (structurally impossible layouts must not silently pass). A per-seed required access class with zero qualifying positions: that seed's row fails, per D6's aggregate-cannot-hide rule.

## Limitations

- **R5 is unaccepted.** All statements about the P7–P9 seam, reserved opcodes, aux/stable-ref limits and the content-contract mechanism describe the snapshotted draft only; they are seam-planning input, not acceptance findings, and may change before R5 acceptance. Everything in the "must wait" column depends on the accepted bytes.
- **No execution.** I could not recompute any SHA-256 (seed-label digests, archive digests, artifact digests). I verified the hex→decimal projections of three corpus rows by hand and the byte-level agreement of slots 1–27 with the in-repo corpus source; the digest column itself is taken on trust pending the runner's own `corpus.verify` path.
- The "relative abundance retained" claim for universal densities (D2) was not numerically compared against legacy `ores.lua` cluster parameters; the table is user-approved regardless, and the migration roster is explicitly non-authoritative.
- No files were created or modified; only Read/Grep/Glob were used within the three snapshot trees.

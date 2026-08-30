All authorities and seams are now read and cross-checked. Here is the review report.

---

# WP40 R6 Exact Contract — Hard-Lens Review (Fable Task D)

**Target:** `docs/research/wp40-simple-map-r6-contract.md` (uncommitted review candidate on `wp40-simple-map-r6`, base `0d0f44e`)

## Verdict: REVISE

**Counts: Critical 1 · High 3 · Medium 4 · Low 7**

---

## Critical

### R6HL-C1 — The 32-seed evidence has no defined census population, and the parity overflow proof is impossible without one
**Citations:** contract §10.2:762-767 ("Resource rows report exact H … for every sub-band"), §10.3:786-812, §11.1-11.2:816-847; `world_zones.md:1171-1173`; `wp40-simple-map-rebase-plan.md:942-944`; `wp40-simple-map-r6-preflight.md` §5.4.

The contract requires complete per-seed resource/cultural/decoration ledgers, per-sub-band resource rows, and the strict parity comparison with "all factors and products … statically and dynamically proven below `2^53`". But it never defines **which spatial volume each seed's ledger covers**, nor the substrate source for eligibility condition 4 (§6.1: "immutable old CID equals `wp43.stratum_node_for(y)` exactly"), which requires actual native v7 substrate the pure-Lua harness cannot produce for arbitrary volume. The two candidate readings both fail:

- *Full authored world:* a per-seed 3D census is on the order of 10¹¹–10¹² voxels and ~10⁸ sub-band groups per seed, with vein rows in the billions — an impossible LuaJIT population, and the artifact size is unbounded. Moreover, full-world `H_r` (~10¹⁴ over 32 seeds) and `V_r` (~10¹¹) make `21·N_lo·H_hi` exceed `2^53` by ~10 orders of magnitude, so §10.3's own rule ("if the proof fails, the ledger fails") makes the parity gate *unpassable by construction*.
- *Bounded sample:* the only reading consistent with the `2^53` claim — but then the sample (which slices/cells per seed, and the substrate injected for them) *defines* `H_r`, `V_r`, coverage and parity, and the contract leaves an implementer to invent it. Two conforming implementations would produce different gate results.

**Failure mode:** the mandatory §11.3 gates ("complete 32-seed … ledgers", "strict six-race parity") are unimplementable as written or unprovable; a ledger cannot prove its claimed product rule.
**Minimal correction:** define the exact deterministic per-seed census population (e.g. a fixed, layout-derived owner-slice/cell roster per seed), define the evidence substrate (synthetic fixture substrate or hash-pinned captured native buffers) for eligibility condition 4, and derive the static `2^53` bounds from that population. This closes implementation detail; it does not reopen decided design — the design fixes only "32 representative content seeds", never a full-world census.

---

## High

### R6HL-H1 — Mandatory arithmetic KAT value is mathematically wrong
**Citations:** contract §3.2:200-209.

`q=48000, hi=lo=4294967295 -> r=23615` is wrong. `(2^64 − 1) mod 48000 = 15615`, verified three independent ways: CRT over `48000 = 2^7·3·5^3`; repeated-squaring (`2^64 ≡ 15616 mod 48000`); and the contract's own reduction formula (`p = 23296`, `(23295·23296 + 23295) mod 48000 = 15615`). The claim "independently derived from `(2^64 − 1) mod 48000`" is therefore also false. The other three KATs (488, 11296, 11648) verify correct.
**Failure mode:** a correct implementation fails the frozen KAT and the final PUC/LuaJIT micro-KAT (§11.2 reuses denominator 48000); an implementer "fixing" code to match the KAT would corrupt every 48000-denominator budget.
**Minimal correction:** replace `23615` with `15615`. Pure arithmetic; nothing reopened.

### R6HL-H2 — "Zone tier" in resource eligibility/grouping contradicts the WP43 depth-tier density model
**Citations:** contract §6.1:437 ("the zone tier is at or above the row's first tier"), §6.2:453-456 (group key `…, exact_host_node, zone_tier, deep_band`); `registry.lua:309-326` (`DENSITY.g2.host_nodes_per_ore = {[4]=12000,[5]=6000,[6]=3000}`, shape `sparse_upper_rises_through_t4_flat_t5_t6`); `wp43_wp40_handoff.md:124-131`; `wp40-simple-map-r6-resource-density.tsv` row 16 ("T5 entry band must support an Abyssal Steel pick without T6 access"); `world_zones.md:832-838`.

Every frozen numeric authority uses **depth tiers** (the y-band of `tier_at(y)`, 1:1 with the exact stratum host): "sparse **upper**", "T5 entry **band** … without T6 access", registry tables keyed 4/5/6 with no zone concept, deep multipliers nested inside depth-T6. The contract instead gates eligibility and keys sub-bands on the horizontal **zone's** tier. The two readings produce radically different worlds (e.g. G1 at 1:3000 in shallow slate under a T6 zone versus 1:12000; zero gold/silver/G2 at any depth under T1 home zones), and §6.1's own fail-closed validation "against the live WP43 projection" is incoherent under the zone reading.
**Failure mode:** the implementer must resolve a direct contradiction between the contract and its frozen inputs — an unresolved semantically material choice at the core of P8.
**Minimal correction:** replace "zone tier" with the depth tier of y (equivalently the tier of the exact stratum host) in §6.1 condition 3, the §6.2 key, and §10.3's "tier/deep band" language. This aligns with approved D2 and the registry; it does not reopen design.

### R6HL-H3 — Parity denominator lacks the region restriction; universal-vein region attribution is undefined
**Citations:** contract §10.3:786-793; `world_zones.md:846-861`; `wp40-simple-map-r6-decisions.md` §3:77-84.

`H(r,s)` "counts each exact eligible WP43 host position once when it lies in an admitted horizontal class and in a tier/deep band where at least one of that region's counted resources is eligible" — with **no requirement that the position lie in a zone whose `race_region` is r**. Since universal resources are counted for every race and eligible everywhere admitted, the literal reading counts nearly the whole world into every `H_r`, collapsing the six denominators to near-equality and gutting the design's per-region density parity. Separately, `V_r` = "accepted natural veins … in r" is undefined for a universal vein whose 16-cube cell spans a region boundary (frontier growth is sub-band-restricted, not zone-restricted).
**Failure mode:** the strict parity gate — a mandatory acceptance gate — has an ambiguous numerator and a denominator whose literal definition contradicts design intent.
**Minimal correction:** add "and lies in a zone whose `race_region` is r" to `H(r,s)`, and attribute each vein to the race region of its root position. The H restriction restores decided design; the root-attribution rule is new but is the minimal closure of an implementation detail, not a reopening.

---

## Medium

### R6HL-M1 — Cross-slice P7 behavior at vertical owner boundaries is unspecified, and the dust condition invites a forbidden halo read
**Citations:** contract §5.1:396-399 ("the accepted top was written/equal"), §4.4:372-373, §9:703-711; R5 contract §11.2:2296-2298 (non-lighting reads restricted to `minp..maxp`), §9.2:1883-1895.

When `T` is a slice's top row (`T = 47+80k`), `BIOME_DUST` at `T+1` belongs to the slice above, whose transaction may not read the old CID at `T`. The condition "the accepted top was written/equal" is only decidable there analytically (under `SURFACE_EXACT` the matrix has no `N` row — the top is the target unless the neighboring transaction fails entirely), and the contract never states this analytic rule, nor the general rule that P7 spans (filler crossing the slice bottom) clip and continue analytically like R5 runs. The same applies to the §8.5 decoration root-support check when `surface_y = minp.y − 1`.
**Failure mode:** one implementer reads the halo (forbidden, halo-state-dependent), another requires `T` in-slice (missing dust/decorations along every `T = 47+80k` contour), a third derives analytically — three different worlds.
**Minimal correction:** state that all P7/P9 predecessor/support conditions on voxels outside the central owner are evaluated analytically from the column scalars (as R5 §9.2 continuation does), never from VM bytes, and that P7 spans clip per slice with analytic continuation. Closes detail; reopens nothing.

### R6HL-M2 — The public plan handle references a candidate array that is not in its closed schema
**Citations:** contract §4.2:283-294.

`candidate_cell_values` stride 4 is `cell_x, cell_z, first_candidate, after_candidate`, but the exact-field schema `grug_wp40_r6_refinement_plan_v1` contains no candidate-values array for those ordinals to index. The candidate representation (storage, per-candidate stride, ordering within a cell) must be invented by the implementer, and fixtures/validators cannot check the handle as specified.
**Minimal correction:** either add the candidate array (with stride and field list) to the schema, or redefine the two fields as a count/ordinal convention explicitly. Closes detail only.

### R6HL-M3 — Rotation and simple-height digest extraction are not byte-exact
**Citations:** contract §8.3:658-659 ("Rotation is 0, 90, 180 or 270 from the first two digest bits"), §8.4:666-667 ("2 + (digest byte mod 3)").

"First two digest bits" does not say which bits of which byte, nor the value→angle mapping; "digest byte" does not say which byte. Both feed directly into world bytes and into the canonical artifact, in a contract that elsewhere pins byte 1..4 semantics precisely (§3.2). The gravewood `mod 3` also carries an unacknowledged 86/86/84-in-256 bias, in tension with §8.3's blanket "no modulo bias" claim for 8-bit trials.
**Minimal correction:** e.g. "rotation index = `floor(first_digest_byte / 64)`, mapped 0→0°, 1→90°, 2→180°, 3→270°"; "height = 2 + (first digest byte mod 3)", with the finite-bias wording extended to the mod-3 trial. Closes detail only.

### R6HL-M4 — The practical opposing/deep/island-access ledgers assigned to R6 are silently absent
**Citations:** `wp40-simple-map-rebase-plan.md:942-944` ("Produce the 32-representative-seed G1/G2, cultural-resource, regional-parity, **practical opposing/deep/island-access** and 24-apex-slot ledgers"); `world_zones.md:1171-1175`; preflight §5.5; contract §10.2:752-761 (closed row families contain no access family), §11.3.

The contract freezes "the 32-seed evidence/ledger format" yet its closed row families and gates omit the access ledgers that the rebase plan and the §14.2 design gate assign to R6, without any deferral or ownership statement.
**Failure mode:** a design acceptance gate is lost between packages; the closed family list forbids adding it later without a contract revision.
**Minimal correction:** add the access row family/gate, or state explicitly that the access ledger is deferred and name its owning stage (R7/R8). The second option touches the rebase plan's R6 scope and should be confirmed as a deliberate scope move, not decided silently by this contract.

---

## Low

### R6HL-L1 — P7 target-class and policy wording internally inconsistent
§5.2:413-415 says P7 targets "classify as `NATURAL_SURFACE` or `WP43_STRATUM`", omitting `NATURAL_HOST` (dirt/gravel/mud fillers), which §4.3:359-360 correctly permits. §4.4:377 says P7 uses `SURFACE_EXACT` "exactly as R5 defines", then immediately (and correctly) overrides R5's `AIR→W` matrix cell with the cave no-op. Align the wording with §4.3 and call the cave rule an explicit successor extension of the B+ contextual row.

### R6HL-L2 — `surface_y` is used (§7.1, §8.2, §8.4) but the handle field is `terrain_y` (§4.2); the synonym is never defined.

### R6HL-L3 — `feature_ref` for P7 rows (`BIOME_*`, `BIOME_DUST`) is unspecified; §4.3:335-337 defines it only for resource/decoration/cultural rows. State that it is zero.

### R6HL-L4 — §6.1:441 excludes "dungeon/foreign … voxels", but R5 §7.6 forbids inferring dungeon provenance from content. Condition 4 already excludes all non-stratum content; reword the exclusion to the analytic dungeon y-range/fixed volumes so it is not read as a provenance query.

### R6HL-L5 — The decoration discovery halo is semantically inert as specified
Because 16-cells nest exactly in 80-cube owners (`80 = 5·16`, owner min `-32 ≡ 0 mod 16`) and §8.2/§7.2 require whole-footprint owner containment, no candidate rooted outside the central owner can ever place or reserve a voxel inside it. The required halo (§4.2 handle rows, §8.2 artifact row) cannot affect any outcome, and "cells whose largest rotated closed footprint could intersect its central owner" is misleading. Harmless either way (an implementation that consults accepted halo candidates gets the identical result), but the contract should say the halo is diagnostic-only so nobody builds neighbor-owner re-settlement.

### R6HL-L6 — Frozen-identity completeness: the silverwood replacement pairs live only in `grug_trees.silverwood_replacements` (cited by `decorations.lua:202-204`), and neither `grug_trees` nor the `.mts` source bytes are in the §2.1 manifest (template identity is carried only by the canonical post-replacement digests); the expanded variant ID strings (`meadows_grass_1..5` → presumably `meadows_grass_1`…) are hash-domain inputs and never spelled out. Pin all three explicitly.

### R6HL-L7 — The condition→primary-rejection-reason mapping (§7.2, §8.5) is not fully closed (e.g. a prospective P5 solid inside a crown: `insufficient_clearance` vs `forbidden_old_class`). World bytes are unaffected (rejection either way), but independent ledger reproduction is not guaranteed.

---

## Proved sound

The hardest invariants checked did survive the lens:

- **Opcode/role/policy numbering:** the ASCII-ordinal derivation of all 32 R5 opcodes reproduces exactly IDs 1/2/3/4 (`BIOME_*`), 12 (`DECORATION`), 24 (`RESOURCE_EXACT_HOST`), matching the live `planner.lua:252-308` constants (roles 1..16, policies 1..7); appendices 33/34, role 17, policies 8/9 collide with nothing, and the contract correctly forbids re-sorting.
- **Cell/owner nesting:** 16-cubes and 16×16 cells can never straddle an 80-cube owner (owner min `-32+80k ≡ 0 mod 16`), so sub-band-confined veins, owner-confined reservations and whole-footprint decorations are provably emerge-order-independent with no cross-owner partial world.
- **Modular reduction:** the two-word reduction's intermediates stay below `48000² + 48000 ≪ 2^53`; the bias bound `q/2^64 < 2^-48` is correct for `q ≤ 48000 < 2^16`; KATs 488/11296/11648 verify; §3.3's maxima (`4096·3·5 = 61440` numerator) are safely below `2^53`.
- **Vein split:** `v = ceil(B/c)`, `small = floor(B/v)` provably sums to `B`, differs by ≤1, and never exceeds `c` (including the exact-multiple edge case).
- **Deep bands:** `ordinary / −1999..−1500 / −31000..−2000` exactly partition and match the registry's decimal 1.25/1.5 bands, which `wp43_handoff.lua` converts to exact rationals as required.
- **Catalog closure:** the decoration TSV's 34 rows with five variant ranges expand to exactly 48 IDs; the surface TSV's 16 rows match the binding §2.1 design table including shore=bed single values; the resource TSV's 8+3+3+1 roster matches the registry's 15 keys and D2 tiers/caps; the cultural roster matches the corrected decisions/world_zones tables, and the "pending" status-cell trap is explicitly disarmed.
- **Parity algebra:** the cross-product form `20·N_hi·H_lo ≤ 21·N_lo·H_hi` is the exact rational equivalent of the decided `20·hi ≤ 21·lo`; `C_r = 384` matches decision #8.
- **Registration invariance:** zero-versus-six cultural registrations provably cannot change any non-cultural world byte (reservations, not visible sources, are the P8/P9 exclusion), so the disabled-R6 evidence remains valid for R7.
- **Transaction/light order:** §9 adopts the Task-C-coherent `get_light_data`-before-seed-derivation order and retains R5's one-setter limits; the interpreter schedule (LuaJIT fleets, contiguous 5/5/5/5/5/5/2 split, one final PUC/LuaJIT micro-KAT, seven-process cap) complies exactly with `luanti-lua.md` and AGENTS.md.

## Implementation GO

**NO-GO.** With 1 Critical and 3 High findings — including an undefined evidence census that the mandatory gates cannot be proven against, a wrong frozen KAT constant, and two unresolved semantically material choices in the resource/parity core — the contract must be corrected and re-reviewed before any R6 Lua implementation begins. None of the minimal corrections above requires reopening decided design; only R6HL-M4's deferral option would touch the rebase plan's R6 scope and needs an explicit scope ruling rather than silent omission.

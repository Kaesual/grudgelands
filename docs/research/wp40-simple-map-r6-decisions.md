# WP40 Simple Map R6 Decision Record

Status: decided design input; not an R6 implementation contract or
implementation GO
Decision date: 2026-08-29 (Europe/Berlin)
Branch: `wp40-simple-map-r6`
Preparatory commit: `bd74a8754f566abfa62188307bee545e2f9f94d4`

## 1. Decision

The user approved all ten recommendations from the five-section R6 decision
packet without amendment. This closes the design questions formerly stored in
`TODO-design-wp40-r6-contract.md`; that completed TODO is deleted under the
repository documentation-layer rule. The reviewed preparatory files remain
unchanged historical evidence and retain their recorded hashes.

The frozen preflight still contains a relative link to the now-deleted TODO;
changing that reviewed byte would invalidate its manifest. The reviewed TODO
remains addressable at preparatory commit
`bd74a8754f566abfa62188307bee545e2f9f94d4` with complete-file SHA-256
`6762bec749310fe92af58379f220a1261e8c5661e996a3e42c99fd15c834b1a0`.
This record is the current successor to that deliberately historical link.

| # | Decision | Accepted result |
|---:|---|---|
| 1 | Surface/decor catalog | Accept the complete proposed catalog and common surface projection. Target aggregate values win over conflicting migration values. |
| 2 | Cultural reservation envelope | Centred 5×5 columns from `surface_y - 1` through `surface_y + 7`. |
| 3 | Rollout ordering | Complete accepted WP33 registrations against the R6 slot API before R7 activates the writer. |
| 4 | Orc/Troll allowlists | Correct only the two invalid D1 rows; retain all other rows and both density denominators. |
| 5 | Concentrated T4 cultural zones | Use exactly the six race-frontier zones; exclude all Battlegrounds zones. |
| 6 | Resource-bearing water classes | Admit `land` and zone-owned `planned_water`; exclude shelf, deep ocean and dragon channels. |
| 7 | Natural parity scope | Count all universal resources plus the race region's assigned G1 and G2. |
| 8 | Ordinary camp quantity | Exactly 12 renewable regional-tier metal sockets per camp. |
| 9 | Parity unit | Compare deposit opportunities; report placed natural nodes separately. |
| 10 | Parity baseline | Strict pairwise extrema: `20 * hi <= 21 * lo`, using exact rational cross-products. |

## 2. Authoritative projection

- `docs/design/biomes_mobs.md` §2.1 owns the complete logical-biome surface
  projection, exact rational decoration fills, deterministic parameters,
  ordering and explicit deferrals.
- `docs/design/world_zones.md` §11 owns resource-bearing horizontal classes,
  the all-resource natural-vein ledger, strict six-race density parity, the
  cultural biome/zone roster, the 5×5×9 reservation and WP33-before-R7 order.
- `docs/design/world.md` §2 R4 owns exactly 12 renewable sockets in each
  ordinary mining camp.
- `BACKLOG.md` makes the accepted R6 slot API, rather than all of WP40, the
  WP33 placement dependency and makes the pre-R7 registration order explicit.
- `docs/research/wp40-simple-map-rebase-plan.md` carries the same R6/R7 order
  and the current LuaJIT/final-micro-KAT execution rule.

The preflight TSVs remain provenance for the proposal reviewed before the
decision. Their filenames and pre-decision status cells are historical and do
not override the design documents above.

## 3. Closed details

The exact corrected cultural roster is:

| Race | Ordinary eligible logical biomes | Concentrated zone |
|---|---|---|
| Human | `grug_meadows`, `grug_deep_forest` | `elandor_ashenward_march` |
| Dwarf | `grug_pine_hills`, `grug_crags`, `grug_crags_snowy` | `elandor_stormvault_heights` |
| Elf | `grug_elf_forest`, `grug_deep_forest`, `grug_jungle_fringe` | `elandor_glassroot_wilds` |
| Undead | `grug_blight`, `grug_bone_forest`, `grug_swamp`, `grug_beach` | `kragmar_blackwind_rise` |
| Orc | `grug_savanna`, `grug_badlands` | `kragmar_bannerbreak_mesa` |
| Troll | `grug_jungle_edge`, `grug_deep_jungle`, `grug_swamp`, `grug_badlands_east` | `kragmar_thunderroot_wilds` |

Ordinary cultural opportunity density remains exactly `1/4096` per eligible
logical-biome column; the listed concentrated zone uses exactly `1/1024`.
The reservation is invisible collision space and does not mutate the world,
promise a yield or protect a structure. A WP33 registration may use any subset
of it and fails closed if larger. Movement, retry, fallback search and a later
healing writer remain forbidden. WP33, not R6, decides whether the realized
feature may replace P7 top/filler output in the lower two levels.

The independent R6 contract review exposed that adding a full-world camp
constant to a bounded representative host census mixes populations. The
2026-08-30 correction supersedes that combined formula without changing either
approved quantity. For natural-resource parity over the fixed 32-seed corpus,
race `r` has accepted census veins `V_r` and census host denominator `H_r`.
The six exact sampled natural rates are `V_r / H_r`; if `hi` and `lo` are the
extrema, the contract compares their integer cross-products and requires
`20 * hi <= 21 * lo`. It may not use a mean-relative or floating-point
tolerance. Ordinary camps are gated separately at exactly 12 sockets per race
per seed, hence 384 per race across the corpus. Camp sockets are not added to
the sampled numerator; apex sockets are shared bonuses and are not regional
compensation.

## 4. Remaining contract gate

These decisions authorize exact R6 contract preparation, not Lua or world
generation. Before implementation the successor contract still closes:

- every P7-P9 record, role, aux field, footprint, conflict and replacement
  policy without reinterpreting an R5 opcode;
- bounded integer hash/remainder arithmetic and its finite modulo-bias bound;
- exact resource sub-band partition, root/split/growth order and shortfall
  accounting;
- cultural and decoration candidate settlement, immutable template identity
  and neighbor-halo bounds;
- closed content/resource/ledger/artifact schemas and canonical row ordering;
  and
- the 32-seed LuaJIT evidence fleet plus the one final PUC/LuaJIT micro-KAT
  pair required by current interpreter policy.

That contract receives a dedicated read-only hard-lens of its arithmetic and
representation and then a mandatory independent full review. R6 remains
disabled throughout implementation; R7 alone may activate the writer after
the accepted WP33 registrations exist.

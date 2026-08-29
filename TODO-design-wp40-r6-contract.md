# WP40 R6 contract decisions

Status: open; the decisions below block the final R6 contract and any R6
implementation. The R5 dependency is closed by merge commit
`e6fe00a4fdf52ad2c10e02128d8b367fda73f662`. This file contains only choices
that remain after reconciling the approved 2026-08-28 D1-D6 packet with the
accepted R5 schema and the supplementary Fable audits.

The accompanying preparatory record is
[`docs/research/wp40-simple-map-r6-preflight.md`](docs/research/wp40-simple-map-r6-preflight.md).
Recommendations are deliberately concrete so the five sections and ten
separately amendable choices can be approved as one set or amended
individually.

## A — Decoration catalog and deterministic parameters

### Context

`docs/design/biomes_mobs.md` §2 fixes the intended assets and some aggregate
tree densities. The legacy `decorations.lua` supplies the remaining fill
ratios and placement parameters, but it is migration evidence rather than
design authority. It also conflicts with the target Elf total: legacy
Silverwood `0.007` plus Apple `0.002` totals `0.009`, while the target mix is
`0.007`.

The complete proposed catalog is
[`docs/research/wp40-simple-map-r6-decoration-draft.tsv`](docs/research/wp40-simple-map-r6-decoration-draft.tsv).
It preserves every target aggregate, carries legacy-only ground cover forward,
and resolves the Elf mix as Silverwood `0.005` plus Apple `0.002`.

All three options below share one explicit surface projection: accept the
normalized table's WP18 migration-baseline top nodes plus retained legacy
filler nodes and top/filler depths as successor parameters. Their per-column
authority remains explicit in that table, and the two deep-jungle top nodes
also carry the later §2 target confirmation. A different surface projection
must be stated as an amendment to section A.

### Options

1. **Approve the proposed catalog and common surface projection
   (recommended).** Preserve the established visual roster and legacy-only
   parameters, but let the target aggregate values win wherever the two
   sources conflict.
2. Keep only entries whose numeric density is already explicit in the target
   design. This is the most conservative authority reading but removes much of
   the current ground cover and several biome-defining details; the common
   surface projection remains unchanged.
3. Author a new visual-density table. This permits a deliberate retune but
   requires another visual-design pass before the R6 contract can freeze; the
   common surface projection remains unchanged.

### Recommendation

Approve option 1, including these mechanical rules: exact rational fill
values; `surface_y >= 60` for the ordinary-crags snowy pine; hash-selected
Gravewood height `2..4`; dry-shrub `param2 = 4`; the recorded offsets and
altitude caps; and replacement of the unavailable Apple Log mushroom with
`air`. Every entry also requires `surface_y >= 1`; the legacy emergent-tree
`sidelen = 80` is replaced by the successor plan's exact rotated-footprint
halo, not retained as a second cell size. The proposed Savanna Dry Shrub is a
target-design asset with a new recommended fill of `0.004`, not a legacy
numeric carry-over. Approval also explicitly defers meadow flowers, Elf white
flowers, Pine Hills boulders, Blight grey-grass tufts and the optional Swamp
willow/gravewood retint: no registered target node or decided asset/shape
exists, so R6 emits no placeholder for them. R6 does not add herbs, spices,
crops, found-only food, battlefield dressing or new optional decorations.

Decision: **open**.

## B — Cultural-slot reservation envelope

### Context

R6 owns invisible deterministic opportunity slots which WP33 later realizes
inside the single WP40 writer. A one-column reservation is too small for a
later root, seam, cache or outcrop, while allowing WP33 to choose an arbitrary
footprint would let already-generated decorations collide with it. Movement,
retry and fallback search remain forbidden.

The approved D1 packet already fixes the ordinary and concentrated densities
at `1:4,096` and `1:1,024`, respectively, and supplies the initial biome
allowlists. Those rates are not being reopened here; the two R4-invalid
Orc/Troll rows are exposed below.

### Options

1. **Reserve a centred 5 by 5 horizontal square from `surface_y - 1` through
   `surface_y + 7` (recommended).** The later registered feature may occupy any
   subset of that fixed envelope; a larger registration fails closed. The
   R6 envelope emits no mutation and does not compete during R6 settlement; it
   reserves P9 collision space and bounds a later reviewed WP33 realization.
   Whether that realization may replace P7 top/filler output inside the lower
   two envelope levels is a WP33-contract question and is not decided here.
2. Reserve a centred 3 by 3 square over the same vertical span. This costs less
   decorative area but tightly constrains later visual sources.
3. Reserve one column. This supports nodes or a vertical seam only and is
   incompatible with a small multi-column cache/root/outcrop.

### Recommendation

Approve option 1. At one slot per 4,096 eligible columns it consumes at most
25 candidate columns per ordinary slot; the concentrated 1:1,024 cells remain
bounded. The envelope is a collision reservation, not a protected structure
and not a yield promise.

### Rollout ordering

The invisible-slot boundary creates one package-order choice:

1. **Complete the WP33 registrations against accepted R6 before R7 activates
   the writer (recommended).** WP33 consumes the frozen R6 slot API while the
   writer is still disabled, and the first production/fresh-world cutover
   contains the visible sources.
2. Activate R7 first. Any test world emerged before WP33 then permanently
   keeps empty slots and must be discarded for the later content test; no
   healing writer may backfill it.

Approving rollout option 1 also requires changing WP33's BACKLOG dependency
from all of WP40 to the accepted R6 slot API, while making R7 wait for the WP33
registrations. This preflight does not amend that dependency before the user
chooses the ordering.

### Orc/Troll biome-eligibility correction

The approved D1 packet fixed both density denominators and an exact six-race
biome allowlist. Four rows project cleanly into accepted R4. Its Orc row
includes Troll-only `grug_badlands_east`; its Troll row includes Elf-only
`grug_jungle_fringe` and omits the live Troll east badlands. Retaining the two
rows verbatim would therefore preserve two unreachable entries and omit one
live Troll eligibility.

1. **Correct only those two rows (recommended).** Orc becomes
   `grug_savanna;grug_badlands`; Troll becomes `grug_jungle_edge`,
   `grug_deep_jungle`, `grug_swamp`, and `grug_badlands_east`. Preserve the
   four other approved D1 rows and both approved density denominators
   unchanged.
2. Preserve both approved D1 rows verbatim. Orc keeps dead east-badlands
   eligibility; Troll keeps dead fringe eligibility and east badlands receives
   no Spirit Resin opportunity.
3. Author a new six-race biome allowlist, reopening all six rows.

Decision (envelope, ordering and Orc/Troll eligibility): **open**.

## C — Concentrated T4 cultural-source zones

### Context

The approved wording selects a non-civic contested level-31-40 zone of the
owning race region. Human matches both Ashenward March and the culturally Human
Broken Causeway, while every other race matches only its faction-front zone.
That creates an undeclared two-zone Human concentration.

### Options

1. **Use exactly the six race-frontier zones and exclude all Battlegrounds
   zones (recommended):**
   `elandor_stormvault_heights`, `elandor_ashenward_march`,
   `elandor_glassroot_wilds`, `kragmar_blackwind_rise`,
   `kragmar_bannerbreak_mesa`, and `kragmar_thunderroot_wilds`.
2. Include every matching level-31-40 contested zone. Human then receives both
   Ashenward March and The Broken Causeway at the concentrated rate.
3. Replace the rule with a separately authored six-zone roster.

### Recommendation

Approve option 1. It gives every race exactly one concentrated T4 source and
keeps Battlegrounds/endpoints as access routes and bonuses rather than hidden
regional compensation.

Decision: **open**.

## D — Resource-bearing horizontal water classes

### Context

The approved resource packet says “named land column” and excludes deep ocean
and dragon channels, but it does not decide whether exact stratum hosts below
rivers, lakes, bays or the nominal shelf count. This changes both placement and
the accessible-host denominator.

### Options

1. **Allow `land` and zone-owned `planned_water`; exclude `coastal_shelf`,
   `deep_ocean`, and `immutable_dragon_channel` (recommended).** Rivers, lakes
   and the landward bay masks retain underground geology; exterior seabed does
   not become a mining region.
2. Allow dry `land` only. Every planned-water column becomes barren at all
   depths.
3. Also allow the editable coastal shelf. This expands supply outside named
   land and complicates cultural-region projection.

### Recommendation

Approve option 1. Eligibility still requires the exact WP43 stratum host at y;
water, beds, route work, dungeons, foreign nodes and protected content are not
hosts.

Decision: **open**.

## E — Six-race ±5% resource parity and ordinary camp budget

### Context

`world_zones.md` §11 requires the expected natural vein count plus one ordinary
camp budget to be equal within ±5%, normalized by accessible host volume. The
current design gives ordinary camps a range of 10-15 renewable nodes in the
regional metal tier, and it does not define which natural resources enter the
numerator, the comparison baseline, or whether node or vein counts are the
parity unit.

For every option, an **accessible host volume** is the number of exact eligible
WP43 stratum-host positions in the approved horizontal column classes and in
the tier/deep bands where at least one resource counted by that ledger is
eligible. Each position is counted once regardless of how many counted
resources could use it. “Accessible” here means geometric and exact-host
eligibility after exclusions, not route reachability; route/access evidence is
reported separately. A split-ledger option computes this denominator
separately for each ledger.

### Natural-vein scope

1. **Count every natural resource eligible in a race-region column
   (recommended):** all universal resources plus that region's assigned G1 and
   G2. This is the literal “total natural vein count” reading and keeps the
   ordinary regional-metal camp in the same all-resource supply ledger.
2. Count assigned G1+G2 only. The ordinary metal camp must then be excluded
   from this gem-only metric and reported in a separate camp ledger.
3. Publish separate universal, G1, G2 and camp parity gates. This is most
   diagnostic but replaces the design's one combined ±5% gate with four.

### Camp quantity

1. **Freeze every ordinary camp at exactly 12 renewable regional-tier metal
   sockets (recommended).** This gives R6 one canonical expected camp ledger.
   The regional metal rule from `world.md` §2 does not change.
2. Keep the 10-15 range and let WP13 select each camp's quantity. R6 cannot
   freeze one canonical expected combined ledger under this option.
3. Choose another exact socket count now.

### Parity unit

1. **Compare deposit opportunities (recommended).** For race `r` over all 32
   seeds, divide the accepted natural veins selected by that scope plus the
   selected ordinary-camp sockets only when the chosen ledger includes camps,
   by that ledger's accessible host volume. Report placed nodes separately;
   density conformance remains node-based.
2. Compare placed natural nodes plus the selected camp nodes only when the
   chosen ledger includes camps. This has one unit throughout but makes
   vein-size tuning directly change the regional parity gate.

### Comparison baseline

1. **Use the strict pairwise-extrema reading (recommended).** Let `lo` and
   `hi` be the minimum and maximum of the six exact rational rates. Require
   `20 * hi <= 21 * lo`, so no race rate is more than 5% above the lowest.
2. Use inclusive ±5% around the arithmetic mean `M`: every rate must lie from
   `19/20 * M` through `21/20 * M`. This permits the highest and lowest rates
   to differ by as much as `21/19`, approximately 10.53%, and is therefore a
   looser reading of the current design.

### Recommendation

Approve option 1 in all four sub-sections. A natural vein and a renewable
socket are both one deposit opportunity across the all-resource supply ledger,
while the independent node ledger still proves material volume. The final
contract uses the stated exact cross-multiplication; no floating-point
tolerance is permitted.

Decision: **open**.

## Consequences already resolved without another design choice

- Resource budgets split each globally anchored 16-cube at every WP43 tier,
  exact-host identity and deep-multiplier boundary. The unit is
  `(resource, cell, band)`, never a whole cell spanning two rules.
- A hash remainder trial must use a fully specified integer construction and
  disclose its finite modulo bias; the contract must not call a simple
  `hash % denominator` trial exactly unbiased. The final arithmetic and KATs
  receive a dedicated hard-lens review before code starts.
- R2 topology, anchor positions, socket identities and housing packing are
  once-only fixed evidence. R3 height detail, R4 logical-biome choice, native
  v7 host volume, and R6 candidates/settlement legitimately vary by full seed.
- R6's ±10% paired leather/cloth/silk/feather/herb/spice/reagent ledger is
  expected to contain no owned opportunity rows. R6 exports its geometric
  denominators; WP6/WP33 and their consumers own the actual opportunity gate.

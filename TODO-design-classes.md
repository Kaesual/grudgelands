# Open questions for the class redesign

The [class redesign handoff](docs/planning/class-redesign-handoff.md) preserves
the discussion and the user's latest decisions. This TODO indexes its open
choices; it is not a round plan. Approved directions are in the handoff's
section 3, and the worked Mage remains a proposal.

**Parked (2026-10-12):** the rework is a future work package, not part of the
next round. Resume with the [continuation plan](docs/planning/class-redesign/continuation.md):
it records the user's decisions on the two reviews, the adopted
simplifications and the preparatory planning round (rulings, prepared skills,
balance corrections, document fixes, engineering ambiguities) that must
close before any implementation. Its section 5 extends the list below.
**2026-10-19:** the user's "maximally simple" rulings
([continuation §4a](docs/planning/class-redesign/continuation.md#4a-user-rulings-of-2026-10-19-a-maximally-simple-rework))
override the candidates where they conflict.

The [four-class review package](docs/planning/class-redesign/README.md) now
contains Warrior, Priest and Scout candidates, Mage corrections and the
cross-class balance review. The user supports the direction and approved the
[future targeting contract](docs/design/ability_targeting.md). Start planning
with the [implementation design](docs/planning/class-redesign/implementation-design.md).
Numerical tuning and graphs remain candidates; the design round is not closed.

The [Priest/Fire damage direction](docs/planning/class-redesign-handoff.md#31-class-development-and-the-mage)
is decided: even an offensive Priest stays slightly below Fire, with healing
as its separate advantage; Frost trades damage for slow/freeze. Exact tuning
and practical comparisons remain part of the candidate review. Refined
2026-10-12: a healing Priest stays somewhat below Frost without its slow, and
Priest healing returns close to the shipped level
([continuation, H1](docs/planning/class-redesign/continuation.md#3-user-decisions-on-the-review-findings-2026-10-12)).

- [Mage candidate](docs/planning/class-redesign-handoff.md#5-mage-design-proposal):
  confirm two starters, the node graph, point gates, the separate Fireball's
  cost/cadence and damage values, and pure/mixed builds. Cold Spark replacing
  Fiery Spark in the hotbar, both Sparks remaining single-target and Fireball
  remaining a separate skill are decided.
- [Reviewed class candidates](docs/planning/class-redesign/README.md):
  select starters, talent graphs, transforms, pure/hybrid allocations and
  ultimates; consider the Mage's revised fire cadence and Frost slow talent,
  Warrior protection/sustain, Priest support-crit and timing changes, and
  Scout click/RMB controls, Sprint removal and faster-arrow economy. Reviewed
  numbers are paper tuning, not gameplay acceptance.
- [Area geometry](docs/planning/class-redesign/implementation-design.md#6-feedback-and-area-geometry):
  freeze the vertical band and per-target cover of the one-shot area query
  (simplification 1). There is no preview while aiming
  ([continuation §4a](docs/planning/class-redesign/continuation.md#4a-user-rulings-of-2026-10-19-a-maximally-simple-rework));
  a delayed area shows a short particle warning at the impact point.
- Arrowfall and Split Shot: the per-release payment, facing cone and
  secondary-target questions fall away with §4a (one-shot effects, no
  projectiles at explicitly chosen secondaries); the
  [skill inventory](docs/planning/class-redesign/skill-inventory.md) holds
  their simplified versions.
- [PvP](docs/planning/class-redesign-handoff.md#57-pvp-and-leveling-checks-still-needed):
  settle strongest-only slows, repeated roots, crit eligibility, absorbed-hit
  triggers (cast commitment/cancellation fell away with §4a).
- [Ice Cage](docs/planning/class-redesign-handoff.md#58-ice-cage-and-discarded-mage-variants):
  keep Winter Field or choose the cage; if the cage, settle protection,
  displacement and destructible geometry before implementation.
- [Continuation](docs/planning/class-redesign-handoff.md#8-continuation-and-future-delivery):
  review the four-class overview and resolve the proposals, then choose round
  scope alongside existing carry-overs and settle migration/refund details.
  The user's 2026-10-12 parallel-draft request superseded sequential drafting.

**Not part of the class rework** (§4a item 11). Hotbar A/B shipped in 0.50.0
(Round 50), including combat switching, consumption order, starter placement
and the in-place transformation rule (Round 50 ruling 12). Two handoff
proposals remain separate, unscheduled ideas:

- [Food on the belt](docs/planning/class-redesign-handoff.md#72-consumables-belt-and-eating):
  eat from the E quick menu's belt with a timed action.
- [Tools](docs/planning/class-redesign-handoff.md#73-tools-and-everyday-layouts):
  remove shovels and combine axe and hoe; Hotbar A/B reduced the slot
  pressure that motivated it.

When these choices are resolved, consolidate approved rules into their topic
owners, preserve this handoff as provenance and delete this TODO under the
[documentation rules](docs/process/documentation.md).

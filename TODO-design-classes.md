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
  freeze eligible terrain and actor-footpoint conversion (including airborne
  actors), per-column surface/air selection, vertical allowance, damage volume
  and per-target cover. Crosshair enemy/terrain anchoring, preview, activation
  capture, fixed position and refusal on invalid placement are already decided.
  Set preview representation/update/particle limits with desktop/web evidence;
  the implementation design's numeric preview budget is provisional.
- [Arrowfall and Split Shot details](docs/planning/class-redesign/implementation-design.md#arrowfall-settlement-proposal-for-the-implementation-brief):
  approve the broad facing angle, per-shot integer mana apportionment, partial
  volley recovery and missed-scheduler-slot handling; for Split Shot settle
  ammo shortage behavior and deterministic nonplayer identity ties. One aimed
  initial target, forgiving follow-ups, per-release payment, nearest legal
  Split Shot secondaries and no payment for unfired arrows are decided.
- [PvP](docs/planning/class-redesign-handoff.md#57-pvp-and-leveling-checks-still-needed):
  settle strongest-only slows, repeated roots, crit eligibility, absorbed-hit
  triggers and cast commitment/cancellation across classes.
- [Ice Cage](docs/planning/class-redesign-handoff.md#58-ice-cage-and-discarded-mage-variants):
  keep Winter Field or choose the cage; if the cage, settle protection,
  displacement and destructible geometry before implementation.
- [Hotbars](docs/planning/class-redesign-handoff.md#71-hotbar-switching-details):
  settle combat switching, consumption priority, initial starter placement
  versus the no-auto-placement rule, and general transformation updates beyond
  the decided Cold Spark replacement. Do not reopen
  the user's explicit A/B insertion, cleanup, sorting and dropdown decisions.
- [Food](docs/planning/class-redesign-handoff.md#72-consumables-belt-and-eating):
  approve the English label and timed belt-click interaction; settle the
  remaining hotbar food gesture, placement and cancellation behavior.
- [Tools](docs/planning/class-redesign-handoff.md#73-tools-and-everyday-layouts):
  decide shovel removal and axe/hoe combination in light of the second hotbar.
- [Continuation](docs/planning/class-redesign-handoff.md#8-continuation-and-future-delivery):
  review the four-class overview and resolve the proposals, then choose round
  scope alongside existing carry-overs and settle migration/refund details.
  The user's 2026-10-12 parallel-draft request superseded sequential drafting.

When these choices are resolved, consolidate approved rules into their topic
owners, preserve this handoff as provenance and delete this TODO under the
[documentation rules](docs/process/documentation.md).

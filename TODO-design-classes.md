# Open questions for the class redesign

The [class redesign handoff](docs/planning/class-redesign-handoff.md) preserves
the discussion and the user's latest decisions. This TODO indexes its open
choices; it is not a round plan. Approved directions are in the handoff's
section 3, and the worked Mage remains a proposal.

- [Mage candidate](docs/planning/class-redesign-handoff.md#5-mage-design-proposal):
  confirm two starters, the node graph, point gates, the separate Fireball's
  cost/cadence and damage values, and pure/mixed builds. Cold Spark replacing
  Fiery Spark in the hotbar, both Sparks remaining single-target and Fireball
  remaining a separate skill are decided.
- [Area targeting and geometry](docs/planning/class-redesign-handoff.md#59-raycast-targeting-and-area-footprint-proposal):
  detail the user's range-limited raycast and per-column nearest-surface/air
  proposal: vertical allowance, eligibility, damage volume, cover, common
  spell scope, performance, particles and runtime behavior. Radius 5 and a
  ±2–3-block vertical allowance were examples, not fixed spell values.
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
  discuss the other classes sequentially, then choose round scope alongside
  existing carry-overs and settle migration/refund details.

When these choices are resolved, consolidate approved rules into their topic
owners, preserve this handoff as provenance and delete this TODO under the
[documentation rules](docs/process/documentation.md).

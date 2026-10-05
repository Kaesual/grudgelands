# Documentation reconciliation findings

> **Archived 2026-10-05** (Round 37 lane DA, after the
> [October 2026 audit](../../audit-2026-10/docs/02-agent-context.md), CTX-13).
> Every open item below was re-checked against the code: D2 is fixed (a
> profession book lists its locked recipes greyed, `grug_jobs/ui.lua`
> `recipe_listed`, Round 28 `01700592`); D4 is fixed (the Kraken has
> `view_range = 40` and the deep-ocean pursuit, `grug_mobs/kraken.lua`,
> Round 29 `38d9764a`); the WP44 buy-back is 5 %
> (`grug_traders/price_rules.lua` `buyback`, Round 29); the level 41–60
> story shipped in Round 36 (WP9), boats and waystones in Round 29 (WP17),
> geographic PvP in Round 31 (WP41); Round 33 removed the cultural finishes
> and put the crown in the masterwork's place. D3 is still a design
> question and moved to the
> [BACKLOG open questions](../../../BACKLOG.md#audit-2026-10-open-questions);
> the depth pulse (WP34) and the war-front battles (WP42) stay in the
> BACKLOG. The WP counts in the last section are from 2026-09-29. Kept as a
> historical record; it is no current list of open work.

2026-09-23. Documentation-only audit against baseline `d6937b31` and later
consolidation commits. No finding here authorizes a game-code change.
Updated 2026-09-29 after the [work-package audit](../../planning/wp-audit-2026-09-29.md)
and its [user decisions](../../planning/wp-audit-2026-09-29.md#user-decisions-2026-09-29).

## Decisions or follow-up work

| ID | Finding | Evidence and disposition |
|---|---|---|
| D1 | Old WP37 blanket surface-density reduction overlaps later R16 fightable-only +30% tuning; critter scope differs. | **Closed 2026-09-29.** Round 24 ruling 27 raised density (about 1.5× per-zone budget); the user canceled WP37 (audit C1) and kept ×0.75 only for the two surface critters Bone Weevil and Bog Fowl (C6, WP28 in Round 26). |
| D2 | Profession books should show higher-tier recipes greyed, but runtime omits them. | [Items audit](../../research/docs20-items-audit.md); `items_crafting.md` §2.2 versus `grug_jobs/ui.lua` recipe_unlocked filtering. Approved design retained; later code fix or explicit redesign required. |
| D3 | Four specialist mastery bands coexist with six profession tiers; not all specialist declarations were traced. | [Items audit](../../research/docs20-items-audit.md). This is a coverage/design-clarity concern, not proof of a new defect. Do not remove the future specialist rules without that audit. |
| D4 | Intended deadly-ocean travel is not established by Kraken speed alone. | The later approved speed is 5, not old WP17's 8.8; improved boat target is 8. [World audit](../../research/docs20-world-audit.md). Still open: `view_range` is 20 against a target of 40 and the position-dependent pursuit is not built. Owned by WP17, which is V1 since 2026-09-29; the boat/pursuit acceptance stays there. |

Existing approved-but-unimplemented systems remain in BACKLOG: WP44 economy
(current 25% versus target 5% buy-back), finishes and masterwork, the depth
pulse, boats and waypoints, geographic PvP, the level-41–60 story and the
war-front encounters. Claim Housing and the dragon encounters are delivered;
renewable ores, natural out-of-combat regeneration, rested XP, carried light,
the dragon hoard chest and `/unstuck` are removed from the design (2026-09-29). Their continued absence is not automatically a newly introduced bug.
GUI and first-public-release gates remain open where recorded.

## Corrections made without changing design

- Current named-zone world replaces present-tense descriptions of retired radial
  maps, cuboid biomes and capital experiments. Unique historical material moved
  to [world history](../design/world-historical.md).
- Preparation, settlement services, mount entitlement, pursuit and idle recovery
  follow later approved decisions rather than old startup/AI notes.
- Selected fixed-tier enchanting, removed refinement and current lifetime
  budgets are distinguished from found-item random rolls and older recipes.
- WP44 target prices are clearly separate from the running economy.
- Closed item research/decision essays moved to [item history](../design/items-history.md).
- BACKLOG delivery arithmetic corrected from 24 to 27 already-delivered WPs;
  WP8/WP12/WP20 were missing from the summary. No new implementation claimed.
- Backlog/roadmap completion diaries are archived; current queue and goals link
  to detailed pending scopes. Root README is unchanged.
- AGENTS retains working constraints; detailed module knowledge moved to a
  technical guide and stale migration, brewing, enchant and atlas claims corrected.
- Independent review also removed old WP13 construction instructions, made its
  24-versus-16 core discrepancy explicit, corrected WP22 old wear budgets and
  marked the depth-level curve as delivered rather than future WP34 work.
- Native-agent workflow replaces the obsolete synchronous-subagent workaround;
  documentation-only gates are explicit. Runtime gates remain unchanged.

## Coverage and limits

[Baseline inventory](../../maintenance/inventory-baseline.tsv) lists every tracked Markdown file
at baseline with provisional purpose, line count and SHA256. Its coverage column
records initial assignment, not a fabricated per-file certification. Final topic
coverage is documented by the [items](../../research/docs20-items-audit.md),
[world](../../research/docs20-world-audit.md), [play](../../research/docs20-play-audit.md)
and [process](../../research/docs20-process-audit.md) reports. All living topics have
an assigned review; some world sections were inspected selectively, as recorded.

The roughly 100,000 historical Markdown lines were not all re-read end to end.
Relevant decision records/code were selected by topic and citations. Raw logs,
measurement corpora, third-party Markdown and media/license evidence were not
re-certified. Stable evidence paths are intentionally preserved. Source-line
citations must still be verified when used for implementation.

## README owner handoff

Root README remained byte-identical during the consolidation. The follow-up
was applied on 2026-09-29: README links the [documentation guide](../../README.md)
and [project status](../../STATUS.md), routes `playtest_quality_revision.md` as
historical decision routing, and shows BACKLOG's counts (39 delivered, 3
canceled, 12 open of 54 after the work-package audit, WP28 and the new WP50).


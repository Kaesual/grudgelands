# Round 13 independent documentation/code drift audit

Date: 2026-09-21. Reviewer: native GPT-6 Astra `/root/r13_docs_drift`, independent
of implementation and of the coordinator's documentation corrections.

## Result

**Clean after one documentation correction round.** No unresolved Critical,
High or Medium finding remains in the reviewed Round 13 rules. The initial
audit found **0 Critical, 1 High, 7 Medium and 2 Low** grouped documentation
findings. The coordinator corrected the documents; this reviewer read the
resulting working-tree diff and relevant source again. No runtime was rerun.

Implementation reference: `ed0e4de2547f5b94f377c00cb29a1e92f8d5033f`, which
integrates `230d6cd4`, `f99393ce`, `e37524a9`, `93631dfd` and joint integration
changes. Final review includes the coordinator's subsequent documentation-only
working-tree corrections. Original finding locations below refer to the
candidate before those corrections, so later line numbers may have moved.

Delivery status remains a separate coordinator transaction: this audit does
not claim main merge, sync, push or user GUI acceptance. Completion records and
README should receive the concrete delivery receipt when that transaction
finishes.

## Scope and method

Read the current crafting/equipment contract, AGENTS, completion/execution
records and affected sections of `items_crafting`, `professions`,
`inventory_equipment`, `durability_repair`, `farming`, `combat_stats`,
`skill_trees`, README, BACKLOG and ROADMAP. Followed current cross-references
and searched related living Scout, economy, Housing, settlement, class,
character-visual and open crafting-TODO documentation.

Compared claims with the actual quality/enchant operation registration and
application, Goldsmith base recipes/trinket definitions, station/workspace
and automatic-production paths, profession permission/progression, gear
registration/curation and starter selection, tool/hoe budgets, repair wear
settlement, quiver handling, and armor multiplier/aggregate code. Existing
focused integration fixtures and receipts were inspected as evidence, not
executed. No GUI, PUC, CLI delegation, exhaustive suites or production writes.

The audit is bounded to Round 13 and directly affected current rules. It is
not a certification of unrelated gameplay or all historical source citations.

## Findings and verified corrections

### D1 — High: crafted rolls still described as random, item-scaled and mastery-gated

Original: `docs/design/items_crafting.md:249` and `:1918`–`:1935` taught a
Master's T1 random roll and an Apprentice's full T6 roll, with mastery deciding
the usable channel/value operation. This directly contradicted the latest
fixed-tier crafting decision, including the user's deterministic jewelry rule.

Evidence: `mods/ITEMS/grug_quality/init.lua:106` fixes values by enchant tier;
`:555` checks target tier; `:579` reads the recipe-tier value; `:593` writes the
selected channel. `mods/ITEMS/grug_professions/enchants.lua:10` registers both
channels at every tier without a mastery prerequisite.

Correction verified: §2.1 and §6.3 now distinguish found/vendor rolls from
fixed crafted values and explicitly reject item-tier scaling and mastery
suffix gates. **Resolved.**

### D2 — Medium: stations still declared uncraftable and city-only

Original: `docs/design/items_crafting.md:68` claimed profession stations were
uncraftable and restricted to capitals/villages.

Evidence: `mods/PLAYER/grug_jobs/station_nodes.lua:157` defines station grid
recipes; `:229` registers them as T3 professional crafts. Workspaces select
personal mode from authored station positions at
`mods/PLAYER/grug_jobs/workspaces.lua:262`; other placed stations share inputs.

Correction verified: the anchor now distinguishes authored personal workspaces
from crafted shared stations. No station-specific owner/access menu was added.
**Resolved.**

### D3 — Medium: starter and eligible weapon catalogs retained removed items

Original: `docs/design/scout.md:99`, `:103`, `:127` and `:318` described a
wooden starter bow, stone backup sword and bow refinement.
`docs/design/items_crafting.md:577` retained Wood/Stone swords;
`docs/design/combat_stats.md:904`–`:910` still treated vendored axes/swords as
eligible one-handed weapons and cited a removed `VENDORED_WEAPONS` list.

Evidence: `mods/ITEMS/grug_gear/init.lua:586`–`:588` points all starters to
Bronze; `mods/PLAYER/grug_inventory/equipment.lua:667` maps the classes;
`mods/ITEMS/grug_materials/content_curation.lua:17` removes both starter swords;
`mods/ITEMS/grug_materials/tool_lifetimes.lua:7` removes Weapon eligibility and
`:10` sets gathering-tool damage to zero.

Correction verified: living starter/weapon sections now describe Bronze and
exclude gathering tools. The explicitly labeled Round 11 delivered-scope table
is historical rather than a contradictory current starter rule. **Resolved.**

### D4 — Medium: trinket base channels and total operation count were stale

Original: `docs/design/professions.md:102` required every trinket already to
have one prefix and suffix; `docs/design/items_crafting.md:2002` counted only
420 operations without the 36 selected trinket operations.

Evidence: `mods/ITEMS/grug_gear/trinkets.lua:75` registers authored base items
with Common quality and identity-special fields, not affix metadata;
`mods/ITEMS/grug_artisans/goldsmith.lua:109` registers plain base outputs.
`mods/ITEMS/grug_artisans/enchants.lua:20` registers the trinket operation family;
the two three-stat pools at `mods/ITEMS/grug_quality/init.lua:67`–`:68` produce
36 operations over six tiers, in addition to 420 ordinary operations.

Correction verified: professions permits empty base channels and describes
selected fixed values; §6b.2 states 456 operations. **Resolved.**

### D5 — Medium: Protection acceptance values still used the previous calibration

Original: `docs/design/skill_trees.md:1038`–`:1040` retained damage-Warrior
60.9%, Protection 68.5% and emergency 69.6% against L70.

Evidence: `mods/CORE/grug_core/combat.lua:2` sets 1.65; `:187` defines K(L).
`mods/ITEMS/grug_quality/init.lua:846` applies the multiplier to the aggregate.
The concrete source/fixture at `tools/r13_integration/probe/scenarios.lua:167`
checks plate 71, shield 71 and final 298.65/313.65. With raw 181 and K=135,
the reductions are 57.28%, 68.87% and 69.91%.

Correction verified: the acceptance example now names the 181-rating sources
and all three current percentages. The talent row, code example and UI sketch
also use 1.65. **Resolved.**

### D6 — Medium: settled weapon wear was still presented as future work

Original: `docs/design/combat_stats.md:298`–`:300` said equipped weapons
remain wear-free until a later durability package installs the event hook.

Evidence: `mods/ITEMS/grug_repair/runtime.lua:69` implements outgoing wear;
`:132` registers its settled-action consumer, excluding pure absorb grants;
`:137` registers incoming selection among four armor slots and offhand.

Correction verified: current combat text describes once-per-settled-action
main-hand wear and effective in-combat healing. Dedicated durability/current
contract documents correctly retain nonlethal incoming HP-loss semantics,
Creative exclusion and broken-quiver retrieval. **Resolved.**

### D7 — Medium: the open-design TODO reopened the now-decided lifetime ladder

Original: `TODO-design-crafting-rework.md:38`, `:45` and `:72` said the six
pick `uses` values remained an open design decision.

Evidence: the authoritative current contract fixes the uses table;
`mods/ITEMS/grug_materials/tool_lifetimes.lua:3` and the mining profiles
implement 300/600/1000/1500/2000/3000, with Wood/Stone 30/60.

Correction verified: B22 now leaves only dig-speed `times` open and points to
the decided lifetime contract. Future runtime speed calibration remains open;
the correction does not claim completion of WP22. **Resolved.**

### D8 — Medium: an obsolete mandatory Woodcarver/grip supply dependency survived

Original: `docs/design/professions.md:176`–`:181` and
`docs/design/items_crafting.md:921`–`:930` presented Woodcarver purchases of
Leatherworker grips as a current required equipment supply loop.

Evidence: `mods/ITEMS/grug_artisans/enchants.lua:14`–`:16` supplies graded wood
and metal fittings; `mods/ITEMS/grug_professions/enchants.lua:15`–`:16` adds
the tier reagent. A production-wide search finds grip identities/groups only
at their registration in `mods/ITEMS/grug_professions/leatherworker.lua:40`–`:46`,
with no current recipe consumer.

Correction verified: living documentation now identifies retained grip
components without current enchant demand. No new ingredient requirement was
invented to preserve the old prose. **Resolved.**

### D9 — Low: obsolete names and refinement-era terminology

Original: `docs/design/items_crafting.md:549` used Greataxe as the display
noun, `:1029` called Hardened Staff the finished name and `:342` advertised
upgrade kits; `docs/design/economy.md:30`/`:47` used the removed refined-state
distinction; `docs/design/farming.md:51` ambiguously attributed lifetime to
quality rather than material tier.

Evidence: `mods/ITEMS/grug_gear/init.lua:204` defines Battle Axe;
the common gear ladder names finished caster weapons by metal tier.
Current operations replace channels directly, and tool/hoe budgets follow
material, not affix quality.

Correction verified: Battle Axe and Steel Staff/component wording, named
application/replacement, plain/unenchanted Common gear and higher material
tiers now match the implementation. **Resolved.**

### D10 — Low: the generic item-level gate clause omitted the T1 override

Original: `docs/design/items_crafting.md:321` said `_grug_ilvl` remained the
only consumption/equipment check, conflicting with its own newer Bronze rule.

Evidence: `mods/CORE/grug_core/combat.lua:67` prefers `_grug_req_level`;
`mods/ITEMS/grug_gear/init.lua:485` gives ordinary T1 weapons requirement 1
while preserving base-stat item level 3.

Correction verified: the general clause now states the explicit requirement
override and preserves elevated found-item gates. **Resolved.**

## Intentional boundaries, not findings

- Random found/vendor loot still has its own roll windows. Removing crafted RNG
  does not remove loot randomness or Rough-to-Cut gem processing.
- Four mastery bands still gate selected specialist recipes such as spellbooks
  and bag capacities. They no longer gate prefix/suffix enchanting.
- Automatic furnace, dual-furnace and brewing finishes are universal and award
  no progress; qualifying preparation/direct crafts and selected enchants own
  progress at exactly the effective current profession tier. Code matches this.
- Housing/Protector Stone integration, profession-based repair redesign,
  cultural/PvP finishes, masterworks and broader WP5/WP44 economy delivery remain
  future packages. This round does not implement their decided target specs.
- Marked historical research, Round 10/11 delivery accounts and the explicitly
  historical §10 decision log of `items_crafting.md` were not rewritten into
  current rules. Prior numerical/scope evidence remains historical evidence.
- Main/sync/push and GUI acceptance are not inferred from source review. Pending
  delivery language is appropriate before the coordinator completes delivery.

Calibration: one correction round; 1 initial High, 0 Critical; all listed
findings corrected by the author and independently rechecked. Wall time unknown.

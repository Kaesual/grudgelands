# WP40-Independent Design Rounds — Independent Review Evidence (2026-08)

Status: **Review record, not design.** This file documents the independent
review of the WP40-independent design-decision rounds on branch
`plan-post-wp40-readiness`. The decisions themselves live in
`docs/design/`, `BACKLOG.md` and `docs/research/wp26-task-card.md`; raw
reviewer JSONL logs are deliberately not committed.

Reviewer for every round: **Codex CLI (`codex exec`), model GPT-5.6 Sol,
`model_reasoning_effort = "xhigh"`, read-only sandbox, ephemeral session**,
collecting each diff itself from the named SHAs. Required lenses: design
consistency / no reopening of decided rules; completeness of the fold-in
across documentation layers; both-continents/balance rules; cross-references
and backlog truth; hidden decisions and invented measurements; task-card
gates and Lua/engine contracts. Findings format:
Critical/High/Medium/Low + exact `file:line` + defect + failure scenario +
correction direction; verdict CLEAN / NOT CLEAN.

## Phase 1 — PvP-death/XP decision + WP26 task card

Review scope: `git diff 80a9ea5...HEAD` (start = the CLEAN-reviewed
post-WP40 planning baseline, `post-wp40-planning-review.md`).

Content under review:

- **PvP-death/XP decision** (user-confirmed option (b), commit `72f65ce`):
  confirmed PvP deaths — final HP-lowering committed transaction attributed
  by `grug_pvp.classify_death` to an eligible hostile player — cost no XP;
  PvE, environment and unclassified deaths keep the 25% current-level loss.
  Folded into `progression.md` §3; WP9 unblocked in BACKLOG; README,
  `wp41-engineering-brief.md` §8 and `post-wp40-readiness.md` §1.1 synced;
  `TODO-design-pvp-death.md` deleted.
- **WP26 task card** (commit `3098efd`): dual-furnace port and the complete
  universal recipe surface, including the user-confirmed input-form rule
  (an alloy input is the material's bar where a bar exists; mined Coal,
  Emberglass and Abyssal Crystal enter as mined items).

### Round 1 — full review of `80a9ea5..3098efd`: NOT CLEAN (1 High, 3 Medium, 3 Low)

The PvP-death package was found consistent with no orphaned references; all
findings landed on the WP26 card. Every finding was independently verified
against the sources before fixing; all seven were confirmed. Resolution
commit: `4153ca7`.

1. **High — `dualfurn` recipes invisible to the §3.8 anti-loop audit.**
   `grug_traders`' recipe walk judges only `normal`/`cooking` engine
   recipes (`CONSUMING_METHODS`), so a private alloy registry could never
   be audited. Fix: the card now requires a public iterable
   `grug_smelting.RECIPES` surface, an extension of `grug_traders`' third
   audit over it (`optional_depends`, same `sell_price` resolution,
   error-level report) and an overpriced-synthetic-recipe negative test;
   WP44's repricing reuses the same path.
2. **Medium — dual-furnace craft recipe was implementer latitude.** A
   concrete recipe is a game rule. The user decided (2026-08-13): one
   `default:furnace` + 2 Copper Bars + 1 Tin Bar in LotT's T-arrangement;
   folded into `items_crafting.md` §3.0.2 and mirrored with the exact grid
   in the card (LotT's steel-tier original would deadlock the ladder).
3. **Medium — B22 owner mapping.** `TODO-design-crafting-rework.md` listed
   B22 (pick `times`/`uses`) as WP26/WP29 although WP26 ships no picks.
   Corrected to WP29 (catalog/recipes) / WP22 (runtime calibration) in the
   TODO body, its status table and the card; B22 itself stays open.
4. **Medium — "audits stay silent" unachievable.** Two informational
   `action` lines always print on a clean start. Card gates reworded to
   "no warning/error audit finding" with the expected lines named.
5. **Low —** "all 12 processed materials have bar craftitems" corrected to
   ten `kind = "bar"` rows plus two mined resources (no bar may be
   invented for Emberglass / Abyssal Crystal).
6. **Low —** "WP43 cleared every legacy furnace/pack/tool recipe" was
   overbroad; the card now enumerates the actual clears and the surviving
   wood/stone/bronze/steel tool recipes (until WP28/WP29).
7. **Low —** shifted LotT line citations corrected against the pinned
   v1.2.7 submodule.

### Round 2 — focused re-review of `3098efd..4153ca7`: NOT CLEAN (1 Medium, 1 Low)

Six of seven round-1 findings RESOLVED; finding 4 remained inconsistent one
level up: AGENTS.md and the `grug_traders` source comment still promised
"silent when clean", contradicting the corrected card, and the card's
"failures report at error level" was wrong (missing drop prices warn).
Resolution commit `5b341c4`: AGENTS.md and the comment now promise "no
warning/error finding when clean — the function-drop action line is
expected" (comment-only change, verified to alter no code line and to parse
under `luac51 -p`), and the card states the warning/error split precisely.

### Round 3 — focused re-review of `4153ca7..5b341c4`: NOT CLEAN (1 Low)

Both round-2 findings RESOLVED. The comment insertion had shifted three
`grug_traders/init.lua` anchors in the card by two lines. Resolution commit
`0623d4f` re-syncs them (`:167`, `:159`, `:223`); the `:81-91,100ff`
anchors sit before the insertion and were verified unchanged.

### Round 4 — focused re-review of `5b341c4..0623d4f`: **CLEAN**

All three anchors verified against HEAD, every other `file:line` anchor in
the card re-checked as valid, the commit confirmed to change nothing else.
Round-3 Low RESOLVED. Final verdict: **CLEAN**.

## Phase 2 — crafting-rework decision round

Review scope: `git diff 839d676...HEAD` (start = the CLEAN end of
Phase 1). Ten user-confirmed decisions (2026-08-13), folded one commit
each (`f580b54..3f1702c`), documentation-only:

1. **A2** — affix vocabulary: one prefix + one suffix word per §6.3
   stat (18 words, `items_crafting.md` §6b.4); the eight 2026-08-08
   example mappings preserved verbatim.
2. **A6** — refined marker: one grey "Refined" tooltip line; §6b.7
   special variants state their effect in the same block. WP5 fully
   design-unblocked.
3. **A5** — material grades: leather sleek/nightscale, bolts
   silk/stormweave, wood Seasoned→Heartwood; `biomes_mobs.md` §6
   source rows added.
4. **C10** — leather ships as the Warrior's rank-2 light avoidance set
   (option c); the false "nothing can wear leather" clause retired
   across four documents.
5. **A1** — signature table (profession × mastery, §2.1) with the
   uniform §7 kit rule and two documented deliberately-empty cells.
6. **A4** — keystone table §2.3 completed to T2–T6 × 6 professions;
   every T5/T6 drop is existing both-faction loot; trophy stays
   T4-only.
7. **E21** — six cooking groups (gates, recipes, 20–40% restore ramp,
   Well Fed I–III) plus the user-driven food-model revision (restore =
   movement-tolerant out-of-combat buff, canceled on combat entry;
   percent-only consumables reaffirmed) and the new buff/debuff icon
   framework (`inventory_equipment.md` §5, ships with WP10).
8. **B22 frame** — monotonic six-point speed/durability curves, WP29
   authors, WP22 calibrates; no `times`/`uses` literal frozen.
9. **A3** — bags are not refinable; Ornate reserved for cloth armor
   and spell tomes.
10. **Iron metal-pick gate** — starter picks shatter iron; iron needs a
    Bronze+ pick (`grug_metal_pick` flag, `metal_only` row; runtime
    with WP29).

### Round 1 — full review of `839d676..3f1702c`: NOT CLEAN (1 High, 5 Medium, 4 Low)

All findings verified against the sources and confirmed; resolution
commit `aa095c6`. High: the Alchemist section still described the
retired resting-channel food delivery (rewritten to the buff model; the
§10 D9 entry marked superseded). Medium: the HP span corrected to
30–325 (base attributes); the missing Alchemist imbuing-oil kits added
to the A1 table; the trophy sentence made Goldsmith-safe; wild cocoa —
whose biome palette reached level-21–30 zones — restricted to the
level-51–60 jungle zones (The Skyglass Canopy / Stormscale Summit) so
the T6 gate claim is literally true; the WP22 row reduced to
calibrating the WP29-authored B22 table. Low: Goldsmith keystone
itemstrings (`grug_mobs:sleek_pelt`/`bear_claw`), the grips cross-buy
added to `professions.md` §3, the icon-countdown wording made
churn-consistent, ROADMAP's A3 omission.

### Round 2 — focused re-review of `3f1702c..aa095c6`: NOT CLEAN (1 Medium, 1 Low)

Nine of ten findings RESOLVED; finding 5 left two residuals — the E21
intro still claimed per-continent existence of every gate ingredient,
and the found-only row labeled Stormscale Summit as part of the shared
front. Resolution commit `2e89bfb` (reachable-by-both-factions wording
with the explicit Skyglass/Stormscale exception; island-bonus label).

### Round 3 — focused re-review of `aa095c6..2e89bfb`: **CLEAN**

Both residuals RESOLVED against `world_zones.md`'s zone and travel-graph
definitions; a repository-wide sweep found no remaining per-continent
cocoa claim; the commit verified to change nothing else. Final verdict:
**CLEAN**.

## Phase 3 — playable-boat decision round (session phase A)

Review scope: `git diff b243aca...HEAD` (start = the CLEAN end of Phase 2).
Six user-confirmed decisions (2026-08-13) closing every open question in
`TODO-design-boats.md`, folded one commit per topic (`6bfc128..8f9f194`),
documentation-only; the TODO is deleted.

1. **Acquisition** — the base boat is a universal base recipe (five
   `group:wood`, level 1, no profession/trainer/vendor/quest). Only the
   improved boat is gated, and only through one shipwright per continent
   who teaches it from character level 30 in exchange for exactly one
   improved boat's ingredients, returning one finished boat. Rejected
   alternatives: a priced or level-60 travel unlock (it would put a paywall
   in front of a content pillar and in front of `world_zones.md` §11's
   resource-parity guarantee) and a craft-only profession route (it would
   gate both dragons behind the Woodcarver).
2. **Ownership/representation** — item ↔ world entity, no owner binding,
   exactly one player and never a mob or NPC (the VoxeLibre passenger
   pattern is explicitly rejected), free pickup/placement except that an
   occupied boat may only be picked up by its driver, no inventory, and an
   unused boat is deleted after 24 persistent wall-clock hours.
3. **Movement** — 4 nodes/s base and 8 improved, as entity velocity and
   never `physics_override.speed`. Both are decided anchors read onto
   water: the player's own walk speed and the fast land mount that unlocks
   at the same character level 30.
4. **Damage** — any incoming damage ejects the rider in PvE and PvP alike
   (the `mounts.md` §3.1 rule); boats have no hit points and are never
   destroyed. The decision records the engine fact it depends on: mobs_redo
   punches what the player is attached to (`api.lua:2525-2526`), so a mob
   swing lands on the boat and the eject needs both that entity's
   `on_punch` and the central `grug_core` HP-change hook.
5. **Return/respawn** — collapsed by decisions 1 and 2: a replacement is a
   craft, death/logout/shutdown detach, and the floating boat starts its
   24-hour timer.
6. **Ocean threat boundary** — `world.md` §2b's undefined "deep-ocean
   Kraken/boat-destruction rule" becomes a pursuit contract. The guard
   spawns only in deep ocean; while it stands in a deep-ocean column the
   drag leash, the 45 m chase give-up and the 25 m soft de-aggro are all
   suspended; everywhere else the complete `combat_stats.md` §4 model
   applies. Crossing a boundary is not a reset. Kraken `run_velocity`
   5 → 8.8 and `view_range` 20 → 40, `reach` 4 confirmed unchanged.

Two cross-cutting rules came out of the same round: `combat_stats.md` §4 now
requires the attack cadence to run during the chase (a mob that has closed
must be able to hit a target fleeing at full speed), and `mounts.md` §3.1
records the attachment fact for WP31.

### Round 1 — full review of `b243aca..8f9f194`: NOT CLEAN (3 High, 2 Medium, 3 Low)

Six findings confirmed against the sources and fixed; two rejected with
evidence. Resolution commit `f765144`.

1. **High — the pursuit contract had no implementing WP.** The WP17 row
   named only the attack-cadence patch and the numeric retune, while
   `kraken.lua` ships `_grug_no_leash = true` (`:37`) and its own 200-node
   coastal `LEASH_SLACK` (`:10`); without an owner the guard would keep
   both. Fixed in the WP17 row, its dependency note, ROADMAP and
   `biomes_mobs.md`, including that deep-ocean-only spawning needs no new
   mechanism because `_grug_spawn_check` is already `open_sea_at` (`:31`).
2. **High — "a pursuit that reaches the shelf ends at once" was an
   overgeneralization.** It holds only once the 40 m drag allowance is
   spent; a guard that acquired its target just before the boundary keeps
   most of it. `world.md` §2b and `boats.md` §7 now state the bounded
   residual, which is what keeps the shelf edge dangerous rather than
   farmable.
3. **High — `boats.md` §1 contradicted itself**, saying "only its recipe is
   gated" above a rule that also gates driving. **The reviewer's correction
   direction was rejected**: it proposed limiting the unlock to crafting,
   which would reverse the decision that the unlock covers crafting *and*
   driving. The contradictory clause was removed instead and the rationale
   recorded — a craftable, tradeable boat with only a recipe gate would hand
   the level-30 speed to a whole starting zone.
4. **Medium — rejected.** The Kraken values were called undecided; they were
   decided by the design owner in the session that produced this round.
   `biomes_mobs.md` now states that provenance explicitly and marks the
   quoted anchors as rationale rather than authority.
5. **Medium — rejected**, same reason, for the improved boat's T4 bill of
   materials.
6. **Low —** "carry no ledger price" contradicted the following
   `_grug_sell_price` sentence.
7. **Low —** the Lord-of-the-Test citation lacked its `reference_projects/`
   submodule path.
8. **Low —** the "cloth → bolt" claim cited §3.0.3 instead of §3 and §3.5.

The same commit fixed three defects found by self-verification before the
review returned: the shipwright anchor now cites `world.md` §2 R1 (the rule
that actually covers a peaceful service NPC) instead of `world_zones.md`
§11, the 0.09 s server step gained its source, and §3.0.5 gained the
anti-loop reference.

### Round 2 — focused re-review of `8f9f194..52b64c7` start: NOT CLEAN (1 High, 1 Medium, 2 Low)

Seven of eight round-1 findings RESOLVED. Resolution commit `52b64c7`.

1. **High — finding 1 was only two thirds fixed.** The Kraken ships a
   *third* blanket exception, `_grug_soft_deaggro = false` (`kraken.lua:38`),
   and it breaks the contract in both directions: left global the guard keeps
   8.8 on the shelf instead of dropping to walking speed at 25 m; removed
   global an 8 nodes/s boat outruns a walking guard on the open sea. All
   three fields are now named as blanket exceptions that become
   position-dependent.
2. **Medium — the anti-loop audit claim was false.** `grug_traders`' third
   audit skips any recipe with an unpriced input, and a group carries no
   price of its own (`init.lua:257-261`), so the base boat's `group:wood`
   recipe is never evaluated; its comparison is also `output > inputs`
   (`:269`) while §3.8 requires strictly below, so a break-even craft
   passes. §3.0.5 now states the real coverage and requires explicit tests.
   **Both are pre-existing coverage gaps in shipped code, not boat-specific**
   — every `group:`-input recipe is silently exempt today — and they are
   recorded in the WP44 row, which owns re-running these audits.
3. **Low —** 0.09 s was labeled a pin; it is the configurable
   dedicated-server default and singleplayer does not use it.
4. **Low —** "all three replace shipped values" contradicted "reach 4 is
   unchanged".

### Round 3 — focused re-review of `f765144..52b64c7`: **CLEAN**

All four round-2 findings RESOLVED; every code anchor re-verified against
`kraken.lua`, `grug_traders/init.lua` and `defaultsettings.cpp`; the
deep-ocean/ordinary split confirmed consistent across `world.md`,
`boats.md`, `biomes_mobs.md`, BACKLOG and ROADMAP with no double counting;
the commit confirmed to touch nothing else. Final verdict: **CLEAN**.

**Operational note:** the first attempt at the round-2 review hung for ten
minutes with zero events and zero CPU time. `codex exec` prints "Reading
additional input from stdin..." and can block there; re-running the identical
command with `< /dev/null` produced events within a minute. Every review in
this phase otherwise used the invocation documented at the top of this file.

## Phase 4 — WP5 task card (session phase B)

Review scope: `git diff 5c4bb2e..HEAD` (start = the CLEAN end of Phase 3).
`docs/research/wp5-task-card.md` authored after the `wp26-task-card.md`
pattern, plus the WP5 rows in BACKLOG/ROADMAP/README. Seven rounds; the card
required no new design of its own, but writing it exposed **eight** rules
that were open or only implicit, all of which were folded into
`items_crafting.md` rather than into the card — a task card may quote a game
rule, never own one. Two were user decisions (2026-08-13), six were
derivations recorded with their rationale:

1. **§6b.4 — affix side is positional.** Slots fill prefix, suffix, prefix,
   suffix, so the side follows from the slot number, an affix never changes
   side when a later slot is filled, and regeneration stays deterministic as
   §6.1 requires (user decision).
2. **§5 — gear-drop ilvl is `min(mob level, 60)`.** The six Kings are level
   65 while the top roll band and the character cap end at 60, so a literal
   drop would have no band and, through `grug_req_level = ilvl`, could never
   be worn. It is the only case: the level-100 Kraken drops nothing (user
   decision).
3. **§6.1 — attack speed converts as `fpi / (1 + p)`**, written as a
   complete tool-capability table, since a bare meta float of that name is
   not read by the engine.
4. **§6.1 — an equippable with no ilvl carries no requirement**, which is
   the eight vendored `default:` weapons and matches §3.0.1's starter line.
5. **§6.1 — the 60/40 and 70/30 affix counts apply only to sources without
   a crafter.** A crafted item's count is its crafter's mastery slots
   (§6b.5/§6b.6), so the roller needs an optional `count` argument for
   WP10 — scoped to ordinary equipment, since §6.2 fixes trinkets at one
   prefix plus one suffix regardless.
6. **§7 — the imbue kit uses the crafterless 60/40 roll**, because a kit is
   applied with no crafter present.
7. **§5 — the drop is one uniform draw over the tier's concrete registered
   base items**, no slot pre-selection and no per-family weighting.
8. **§5 — what the windows fix is the expected value per affix**, they
   overlap on purpose, and the whole-item promise of §0 covers the Master
   four-slot masterwork and the boss hoard only.

### Round 1 — full review of `5c4bb2e..53a7075`: NOT CLEAN (8 High, 7 Medium, 4 Low)

All nineteen findings verified and accepted; none rejected. Resolution
commits `c04f8a3` (design) and `b8a56b2` (card). The three that would have
broken an implementation outright:

- **The card told the implementer to preserve `grug_gear`'s baked base-stat
  numbers.** Drops land off-anchor — the design says so at
  `items_crafting.md:813`, "No shipped vendor bracket touches ilvl 27 or 42,
  but WP5's drop tables will" — so an ilvl-27 drop would have shown the
  ilvl-20 catalog value. Corrected to a per-stack ilvl with the base stat
  recomputed from the §3.1/§3.2 curves.
- **Affixes that display and do nothing.** The tasks built storage, display
  and caps but never consumed the nine stats; a "Heavy" item would have
  looked right and granted no Strength. Stat consumption and the +15%
  refinement bonus became their own task and gate.
- **The Fallen Crown conversion was missing**, although the BACKLOG row
  demands it; the whole masterwork path had been pushed to WP10. WP5 owns
  the transaction, WP10 the recipe.

Also: a clause labelled "implementer latitude" in fact froze a uniform draw
— the very thing the BACKLOG row's "retune against G2 and trophy demand"
exists to prevent — and the cultural-finish rule was inverted (§4.2 rejects
only the *same* culture and overwrites a *different* one at full cost).

### Round 2 — `53a7075..b8a56b2`: NOT CLEAN (5 still open, 4 new)

Resolution commits `09a2189`, `5c23cfa`. The King clamp had been stated once
and contradicted three times in the same authoritative document; the affix
counts collided with §6b.5's mastery slots; and a Common vendor item carries
its ilvl on the **definition**, never passing the drop roller, so without a
shared effective-ilvl resolver a level-1 character could wear a vendor
ilvl-30 Common while an identical drop was refused. Two gates demanded work
WP5 does not own (material consumption and cost, a character-sheet layout)
and were narrowed.

### Round 3 — `5c23cfa..6de9ad6`: NOT CLEAN (6)

Resolution commit `6de9ad6`. "Uniform draw over the eligible slot families"
never defined the drawn unit — uniform over five slots then four weapon
families yields a 20% weapon share, uniform over the concrete catalog 33%.
Gate 8 named `grug_classes.apply_stats` as the consumer for attributes and
Mana, but that function only pushes `hp_max`, so a `+Mana` implementation
would have passed the gate while doing nothing.

### Round 4 — `6de9ad6..b8cc30d`: NOT CLEAN (3)

Resolution commit `b8cc30d`. The new `count` argument collided with §6.2's
trinket exception; the boss window was mis-stated as 0.60–1.00 (it is
0.80–1.00, and §6.4's "two 0.60–1.00 windows" is shorthand for the two that
reach 1.00 from at least 0.60); and `apply_stats` also heals on level-up and
clamps current HP, which "sets nothing else" denied.

### Round 5 — `b8cc30d..4a834b3`: NOT CLEAN (2)

Resolution commit `4a834b3`. The reviewer's arithmetic refuted the round-4
correction itself: a named rare rolls 3.3 affixes on average in the
0.50–1.00 window, so its expected 3.3 × 0.75 = 2.475 edges out an **Expert**
masterwork's 3 × 0.80 = 2.400. "Found gear stays below crafted in
expectation" is therefore false; §5 now states only the per-affix
expectation, names the overlap as intended, and limits the whole-item claim
to the Master masterwork and the boss hoard. Three older loose restatements
of §6.3 were corrected with it.

### Round 6 — `4a834b3..5e7202b`: NOT CLEAN (1 Low)

Resolution commit `5e7202b`. The shorthand appeared in **four** places and
round 5 had caught three; the historical D16 note still called the rejected
depth layer "a third 0.60–1.00-window source".

### Round 7 — focused re-review of `4a834b3..5e7202b`: **CLEAN**

The reviewer re-derived the arithmetic independently and confirmed every
printed number — window means 0.30/0.55/0.60/0.75/0.80/0.90, Master
masterwork 3.20 against the strongest ordinary found item 2.475, and the
Expert overlap of exactly 0.075. A repository-wide sweep found no remaining
0.60–1.00 boss window and no strict per-item dominance claim. The WP5
readiness statements in BACKLOG, ROADMAP and README were confirmed true.
Final verdict: **CLEAN**.

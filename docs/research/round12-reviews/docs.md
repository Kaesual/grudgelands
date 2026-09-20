# Round 12 documentation consistency audit

Date: 2026-09-20  
Scope: read-only audit of active documentation on `wp12-round12`. This report does not assess the still-changing TALENTS or RECIPES implementation candidates and does not mark Round 12 complete.

## Findings

### High — all three Cooking refinements are still described as Basics recipes

The approved Round-12 contract says professional provenance is filtered before starter/discovery. The final RECIPES specification assigns all three furnace refinements — Cooked Meat, Cooked Fish and Bread — exclusively to Cooking. The living specification still says the opposite in its “Both furnace patterns” paragraph:

- `docs/design/items_crafting.md` around lines 1171–1173 correctly calls Cooked Meat, Cooked Fish and Bread T1 Hearty dishes.
- The “Both furnace patterns” paragraph around lines 1199–1203 incorrectly places all three among “universal refinements” in Basics.

Suggested exact correction:

Keep the existing T1 Hearty-dishes sentence and replace the opening of “Both furnace patterns” with the final candidate wording:

> **Both furnace patterns.** Raw meat → Cooked Meat, ordinary Raw Fish → Cooked Fish and Wild Grain → Bread are Cooking-owned furnace refinements; they stay in the Cooking book and never appear in Basics. Every tier also has one Cooking grid recipe for an inedible raw assembly; its profession-gated furnace route meets the direct grid route at the same edible Hearty dish:

This is a direct active-design contradiction across Cooking/Basics provenance.

### High — `classes.md` still defines the retired immutable auto-granted item lifecycle

`docs/design/classes.md` around line 33 says ability items are “indestructible, not droppable/tradeable, locked to the main inventory,” that class abilities are granted at class pick and that universal Strike is granted on every join. This directly contradicts the Round-12 Skills authority: representations are disposable, may live in owned bags, dropping deletes them, the base kit is inserted once at character creation, and later recovery is manual from Skills. Only trade/external-storage refusal remains true.

Replace the first “Abilities are hotbar items” bullet with:

> **Active abilities use owner-bound hotbar items.** The permanent entitlement is separate from its disposable representation. A character receives the base kit once at initial class selection; join never recreates a missing item, and talent unlocks add only a Skills-catalogue entry and notice. Dropping or returning an ability item to Skills deletes that representation without a world entity, entitlement loss, cooldown reset or combat-state reset. A missing unlocked representation is recovered manually from Inventory > Skills only when no copy exists in `main`, `craft` or owned bag contents. Representations may be carried in `main` or owned bags; crafting, equipment, external inventories and trade refuse them. Left click attacks or casts at the pointed target; the wear bar displays the skill's charge bar (§2b). Appearance is defined in §2c.

Also replace later “granted” phrasing for Renew/Hamstring with “unlocked/exposed in Skills”; granting now describes entitlement, not automatic stack insertion.

### High — `skill_trees.md` §3.4 mixes the new catalogue rule with the retired `sync_kit` grant design

The opening of §3.4 is current, but the following implementation prescription still says `kit_of(class, player)` keeps talent-gated definitions, `grant_at` assigns hotbar keys, `sync_kit` purges/re-grants them, and `register_on_talents_changed` calls `sync_kit`. That is internally inconsistent with the immediately following sentence that talent abilities are manually acquired from Skills. The later §3.10 table repeats that `sync_kit` becomes the respec purge path.

Delete the stale block from “**Three** existing sites test that flag” through the `register_on_talents_changed(... sync_kit ...)` example and its “re-granting” explanation. Replace it with:

> The shared entitlement predicate is authoritative at every use and catalogue boundary. A `talent_gated` ability is unlocked only while its required talent rank is positive; `grug_abilities.is_unlocked(player, id)` and `unlocked_ids(player)` expose that answer, and `stack_for(player, id)` creates a representation only for an unlocked id. Talent changes normalize the one-time base-kit record, refresh the Skills catalogue and remove carried representations whose entitlement was lost. They do not grant or position a newly unlocked stack. Re-ranking makes it manually recoverable from Skills. Cast and swing settlement revalidate entitlement so a forged or stale stack cannot activate.

In §3.10, replace the `sync_kit` row's result with:

> **Retired as the talent grant/purge authority.** Full respec removes now-locked representations through the shared Skills normalization/removal path; it never re-grants or hotbar-positions talent abilities.

Keep `sync_kit` references that concern current description/range metadata refresh only, but rename them if the final implementation has replaced that function. Update source-line citations after integration; the current line numbers describe pre-Round-12 code.

Bounded recheck of the coordinator's uncommitted corrections: the revised `classes.md` principle and the new §3.4 `is_unlocked`/`normalize_kit` account accurately describe the current Skills code. `is_unlocked` owns class/talent entitlement; catalogue listing, `stack_for`, cast/swing validation and normalization consume it; `normalize_kit` removes invalid/duplicate copies and refreshes retained metadata without restoring discarded items; `grant_initial_kit` runs only from the class-chosen callback. Two stale residues remain in `skill_trees.md` after that correction:

- In §3.10, the row immediately after the newly corrected `normalize_kit` row still describes a comment inside the old function as “Join, class pick and class SWITCH … before re-granting.” Replace that row with the current lifecycle statement or delete it; join only normalizes, class choice performs the one-time initial grant, and respec normalizes without re-granting.
- In §4's X3 lane table, the scope still says “the grant predicate at the three `talent_gated` sites and the append-after-base-kit rule of §3.4.” Replace that phrase with “the shared entitlement predicate at catalogue, recovery, normalization and cast/swing boundaries; later unlocks are manually recovered from Skills.”

The two Far Cast rows now naming `normalize_kit` are semantically correct, but their old `init.lua` line citations should be refreshed to the final integrated file (the current authority is `stack_for` plus `normalize_kit`, around lines 2162–2205 on this checkout).

The `round12-next-playtest.md` correction moving Turn Aside from Mage Rime to Priest Mercy is accurate: its talent is registered under Priest Mercy/Aegis and augments the target of Power Word: Shield while that absorb remains.

### Medium — active status prose still says Round 12 awaits Go

The following active status text contradicts `docs/research/round12-execution.md`, which records the explicit Go and active implementation:

- `BACKLOG.md` “Round 12 planning” says implementation awaits Go and no broader round has started.
- `BACKLOG.md` WP47 detail says “implementation awaits the user's round Go.”
- `ROADMAP.md` “Round 12 planning” repeats the same wording.
- `README.md` Current State says Round 12 “plans” the work and “implementation awaits the final round Go.”

Before final completion, replace those passages with a short active checkpoint link, for example:

> ## Round 12 execution
>
> The user gave the explicit round Go on 2026-09-20. Expanded farming, WP47 Skills, five-minute food, held-item presentation, Basics/onboarding/UI work, art and the remaining WP11 consumers are in integration and review. Exact package state and review gates are tracked in [Round 12 execution](docs/research/round12-execution.md); no package is claimed shipped until that record closes its final gates.

For the WP47 detail heading, use until final closure:

> **Round 12 implementation integrated; final review/integration gates pending.**

Delete `TODO-round12-planning.md` at final closure. It contains no open question, explicitly says Go was given, and therefore no longer belongs in the TODO layer. Replace links to it in active BACKLOG/ROADMAP prose with `docs/research/round12-execution.md` (and ultimately the Round-12 completion record).

### Medium — living recipe presentation rules omit two approved UI invariants

`docs/design/items_crafting.md` §2.2 records main-material visibility, but does not record the approved station-icon placement or the visible explanation of hidden counts. `docs/design/inventory_equipment.md` records Help onboarding but also omits station-icon placement. These are active UI rules, not implementation trivia.

Add to `docs/design/items_crafting.md` §2.2 after the Basics visibility bullet:

> Each non-starter Basics route declares exactly one main material against its complete route identity; starter routes declare `starter` instead. Missing, ambiguous, stale and multiply matched declarations are startup-audit failures. Undiscovered counts remain visible by tier and explain that acquiring the main material reveals more recipes; this is presentation only and never permission.

Add after the station-filter bullet:

> Recipe diagrams place the station icon below the input/output arrow. The icon names the execution station and is not an ingredient slot.

The exact declaration/audit language belongs in the living spec because it prevents a future return to “all inputs seen” or guessed-first-input discovery.

### Medium — AGENTS quick references do not expose the new Skills authority

`AGENTS.md` has current quick references for mounts and abilities but no compact rule for `grug_skills`; a future agent can still infer the old automatic-kit model from surrounding text. Add a new quick-reference bullet near Mount runtime:

> **Skills catalogue:** `grug_skills` lists every currently unlocked active class/talent ability and every purchased mount tier. Entitlement is authoritative; inventory stacks are disposable owner-bound representations. Drop/catalog return deletes only the stack. Manual recovery succeeds only when no copy exists in `main`, `craft` or owned bag contents; external inventories, equipment and trading refuse bound stacks. Base-kit insertion happens once at character creation; later talent unlocks and mount purchases announce catalogue availability and do not auto-insert. Respec/entitlement loss removes stale representations. Purchased mount tiers remain individually available at their original speeds.

Also extend the profession quick reference after “every recipe route appears in exactly one book” with:

> Basics presentation declares each route as either starter or with exactly one main material; discovery affects visibility only. Professional provenance is resolved first, so Cooking outputs such as Bread never leak into Basics. Recipe-book station icons sit below the input/output arrow.

The crop quick reference is not factually contradictory: `crop_visual(key, stage, sounds)` remains the current exported call. It is merely incomplete about multi-node ownership. If AGENTS is refreshed for Round 12, append:

> The rooted/base node owns state, timer and drops for tall crops; hidden helpers are non-owning. Every multi-position mutation is preflighted atomically for loaded, protected, replaceable and matching nodes. Mature regrowers use right-click; annuals are removed/replanted; cane/bamboo retain and reset the base.

### Low — design indexes and README tour describe the pre-Round-12 documents

Update `docs/design/README.md` when the final candidate closes:

- `items_crafting.md`: change the status date from food revision 2026-09-17 to include the 2026-09-20 five-minute/recipe-discovery amendment; mention starter/main-material Basics visibility.
- `inventory_equipment.md`: mention the shared enlarged layout, Skills catalogue/bound representations, onboarding Help and Creative Food category.
- `mounts.md`: replace “Round-10 mount candidate staged for integration” with the final WP47 state and mention retained individually recoverable tiers.
- `skill_trees.md`: once the separate X3 gate closes, remove “original classes' remaining X3 consumers are open.”

Update the human-facing README design tour:

- Farming: say all seventeen families now have family-appropriate annual, regrowing, retained-base or vertical behavior and silhouettes; keep wild renewal distinct.
- Basics paragraph: mention immediate starters and persistent main-material discovery; state Bread remains Cooking-owned.
- Inventory paragraph: mention Skills and disposable/recoverable bound ability/mount representations.
- Food paragraph/current-state delivery: state all food statuses last 300 seconds.

## Conditional final completion edits

Apply these only after every Round-12 implementation/review/integration gate closes.

### BACKLOG.md

1. Replace the top Round-11 checkpoint with a Round-12 completion pointer and add a concise Round-12 delivery paragraph covering: 17-family farming mechanics/art; WP47 Skills/delete/recovery and retained mount tiers; 300-second food; Basics main-material discovery with Cooking provenance; shared UI/Help/Food category; held fallback; reviewed art; X3 completion; UX report and its evidence limits.
2. Mark WP47 shipped and add its final commit/review/evidence record. Its detail section must no longer say “planned” or “awaits Go.”
3. If the separate X3 review closes cleanly, record X3 as delivered but keep WP11 **in progress**: WP44 still owes the measured six-bracket paid-respec prices that replace X4's coordinator placeholders. Replace “X3 remains open” with the exact remaining WP44 calibration dependency rather than closing WP11.
4. Keep WP32 **in progress** because active-claim integration still belongs to WP24. Amend its row and readiness note to say Round 12 delivered the reviewed family-specific silhouette/regrowth/vertical pass; do not call the whole WP shipped.
5. WP10 remains in progress because its cultural/WP44-priced remainder is outside Round 12. Record the Basics discovery/catalog refinement as delivered without closing WP10.
6. Recompute readiness after WP47 closes: shipped identities rise from **23 to 24**, and open/in-progress identities fall from **29 to 28**. WP11, WP32 and WP10 remain in progress and do not change identity counts.

### ROADMAP.md

1. Replace “Round 12 planning” with “Round 12 delivered” plus a completion-record link and the bounded GUI/UX caveats.
2. Keep WP11 `[ ]` after X3 independently passes and integrates. Rewrite its remaining scope to the WP44-calibrated six-bracket paid-respec prices; remove X3 from “Next prerequisite roots.”
3. Add/check WP47 as delivered (the roadmap currently mentions it only in planning prose and has no durable checkbox).
4. Preserve the Round-6 “three-minute food buffs” sentence as historical only: it explicitly describes the superseded Round-6 model. Add the current Round-12 300-second rule in the new delivery entry rather than rewriting historical evidence.

### README.md Current State

Replace the Round-12-awaits-Go sentence and Round-11 framing with the final Round-12 outcome. Update:

- heading date and completion-record/checklist links;
- shipped count/list (**24**, adding WP47 only);
- Delivered section with the five requested decisions plus art/pose;
- In progress section retaining WP11 for WP44 respec-price calibration, and retaining WP10, WP13 and WP32 for their real remaining scope;
- GUI caveat to point to `docs/research/round12-next-playtest.md` and state the UX review was source/heuristic unless a real GUI session was observed.

Suggested compact Current State delivery paragraph:

> **Delivered Round 12:** the independently reviewed build adds the Skills catalogue with disposable recoverable ability/mount representations and preserves every purchased mount tier at its original speed. All food statuses last 300 seconds; all seventeen crop families now use their decided family silhouette and annual, regrowing or retained-base lifecycle. Basics shows starters immediately and reveals later routes by their declared main material without gating crafting, while Cooked Meat, Cooked Fish, Bread and all other Cooking routes remain in Cooking. The shared inventory UI, onboarding Help, Creative Food category, generic held-item fallback, cooked-result/wand/Greataxe art and the original-class X3 consumers are integrated; WP11 remains open only for WP44's measured paid-respec prices. Use the Round-12 playtest checklist for GUI acceptance.

## Historical records intentionally left unchanged

- `docs/research/round12-plan/*` is a frozen planning record. Its pre-Go/resume language and references to the old 180-second value are historical inputs, while its binding amendments state 300 seconds; do not rewrite it.
- `docs/research/round12-execution.md` should become the durable completion record or link to one, preserving intermediate findings as history while changing the top status and completion checklist.
- ROADMAP/BACKLOG descriptions of Round 6 and Round 7 are labeled historical delivery records. The Round-6 three-minute value need not be rewritten; current authority is `docs/design/items_crafting.md` and `docs/design/combat_stats.md` at 300 seconds.
- Round-10 statements that a complete seventeen-family loop existed are historical and compatible: Round 12 changes family presentation and harvest profiles, not the fact that 17 families already existed.

## Audit result

The living farming, food-duration, mount-retention and shared-UI rules are otherwise aligned with the approved Round-12 plan. Material active contradictions remain in the three Cooking refinements' Basics ownership and the pre-Skills ability lifecycle in `classes.md`/`skill_trees.md`. The remaining issues are stale active status prose, missing living-spec UI invariants, and quick-reference/index updates needed at completion.

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

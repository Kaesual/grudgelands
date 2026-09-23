# Documentation cleanup round 20 — items and crafting audit

Date: 2026-09-23. Baseline: `d6937b31`. Scope: the living item, crafting,
profession, durability, farming, economy, inventory/equipment and character-
visual specifications plus `TODO-design-crafting-rework.md`. This is a bounded
documentation audit; it changes no game code, backlog state or delivery claim.

## Sources inspected

Living authority was read in full:

- `docs/design/items_crafting.md`
- `docs/design/crafting_equipment_revision.md`
- `docs/design/professions.md`
- `docs/design/durability_repair.md`
- `docs/design/farming.md`
- `docs/design/economy.md`
- `docs/design/inventory_equipment.md`
- `docs/design/character_visuals.md`
- `TODO-design-crafting-rework.md`

Later decision and delivery evidence was sampled from the directly relevant
Round 9–19 records: `round9-decisions.md`, `round9-design-drift.md`,
`round10-closeout.md`, `round11-initial-diagnosis.md`,
`round11-spec-audit.md`, `round11-completion.md`,
`round12-recipes-ui-audit.md`, `round12-completion.md`,
`round13-planning-history.md`, `round13-completion.md`,
`round13-reviews/docs-drift.md`, `round13-reviews/ui-catalog.md`,
`round16-docs-drift-review.md`, `round16-completion.md`,
`round17-completion.md`, `round18-plan.md`,
`round18-review-docs-art.md`, `round18-completion.md` and
`round19-completion.md`. Earlier reports were treated as historical evidence,
not as authority over later approved decisions.

Implementation was inspected only to classify delivery state and concrete
drift. The principal boundaries were `grug_jobs/state.lua`, `registry.lua`,
`stations.lua`, `workspaces.lua`, `ui.lua`, `discovery.lua`,
`basics_presentation.lua` and `basics_routes.lua`; `grug_quality/init.lua`;
`grug_gear/init.lua`, `trinkets.lua` and tool lifetime registrations;
`grug_farming/init.lua`, `hoes.lua`, `crop_profiles.lua` and `ecology.lua`;
the trader stock/transaction modules; inventory equipment/bag/page modules;
and `grug_visuals/apply.lua` plus wield geometry. No implementation behavior
was promoted into design merely because it exists.

## Corrected living-spec drift

1. **Target economy versus current runtime.** `economy.md` §2 and
   `items_crafting.md` §8 already contain the approved WP44 target: the
   25c→25s Common weapon axis and ceiling-rounded 5% buy-back. Current
   `grug_gear.BRACKETS` still uses 50/70/98/137/192/269 copper and its buy-back
   is 25% rounded down with a 1c minimum. Round-11 repair correctly uses that
   current purchase catalog until WP44. Both design owners now state this
   transition explicitly and require the trader, reference-price, anti-loop,
   buy-back and repair-source cutover to happen together.
2. **Retired refinement remained affirmative inside history.** The historical
   D5 paragraph claimed that +15% refinement and doubled lifetime survived the
   one-prefix/one-suffix change. It now records both the interim state and the
   Round-13 decision that removed refinement, its hidden bonuses and
   Imbue/Temper entirely. Current named enchants remain deterministic and
   separate from found-item random rolls.
3. **Stale lifetime summary.** `items_crafting.md` §8.3 still named the retired
   3,000/6,000 ordinary/refined combat budgets. It now delegates to the current
   tier-specific lifetime tables in `durability_repair.md` and the Round-13
   equipment contract (1,000 through 4,000 for T1–T6 combat equipment).
4. **Professional ownership wording.** `professions.md` still described
   Woodcarver weapon “quality” and loosely assigned base weapon families to
   professions. It now says exactly that plain weapons are Basics and that
   Weaponsmith/Woodcarver own the respective named enchant operations.
5. **Unapproved repair implication.** `durability_repair.md` called
   material/profession repair later WP22 design. No approved detailed design
   exists. It is now an optional future topic and grants no hidden V1 benefit.
6. **Cross-cutting contract routing.** `crafting_equipment_revision.md` now
   serves as a stable topic index for immutable README/tool/research links. It
   identifies the maintenance owner for each rule family while preserving the
   exact Round-13 tables and cross-topic rules those records cite.

## Verified alignment and preserved future work

- `farming.md` agrees with the delivered Round-11/Round-13 crop, hoe, bounded
  renewal and water-only bucket contract. Its 17 families, 200-second stages,
  exact renewal budgets and protection preflights match the inspected runtime.
- `inventory_equipment.md` agrees with Round 13 and Round 18 on Basics,
  transactional named enchants, weapon-slot authority, quiver storage/wear,
  hotbar guidance and bound Skills representations.
- `character_visuals.md` agrees with the current one-attachment system,
  equipped-weapon presentation for selected skills, forward generic fallback
  and deliberate absence of a rendered offhand. Round 18's semantic action
  icons do not change that third-person attachment rule.
- `TODO-design-crafting-rework.md` remains valid and was not collapsed. B22's
  six explicit pick-speed `times` are still open and explicitly excluded from
  Round 18 retuning. D18 remains a deferred unmounted-swimmer question.
- Future Housing station repair remains an approved requirement, not current
  delivery. Likewise the WP44 target prices remain approved future behavior.

## Unresolved findings

1. **Profession-book visibility contradicts runtime.** The approved living
   rule in `items_crafting.md` §2.2 says a learned profession exposes the full
   T1–T6 catalog and greys recipes above effective profession tier. Runtime
   `grug_jobs/ui.lua` filters the list through `recipe_unlocked`, so locked
   professional recipes are absent. Current discovery code applies
   starter/main-material discovery only to Basics; it does not explain the
   missing professional rows. This is code/UI drift and needs a later code
   correction or an explicit user redesign; this audit does not rewrite the
   approved design to match implementation.
2. **Mastery vocabulary remains structurally awkward.** The living item spec
   retains four named mastery bands for explicitly authored specialist recipes
   alongside six profession tiers for permission/progress. Round 13 removed
   mastery gates from enchant channels but did not abolish specialist mastery.
   No rewrite is justified without auditing each specialist declaration.
3. **Runtime acceptance remains pending.** The later completion records still
   assign GUI inspection to the user. This documentation pass makes no visual,
   multiplayer, persistence or real-engine acceptance claim.

## Archive extraction and cross-domain requests

- `items_crafting.md` §1 reference study and §10 non-authoritative decision log
  moved to `docs/archive/design/items-history.md`, with baseline provenance and
  a warning that the archive is not living authority. Short §1/§1.1/§1.2 and
  §10/§10.1/§10.2/§10.3 link stubs preserve existing numbered anchors. Every
  still-current outcome has a topical rule or pointer in §§0–§9.
- The active `items_crafting.md` shrank from 2,386 to 2,094 lines: **292 lines
  net active reduction**. The 334-line archive includes its provenance header
  and preserves historical evidence without burdening the active rule flow.
- `crafting_equipment_revision.md` remains at its stable path because the root
  README, immutable Round-13 evidence and tools cite it. Its introduction now
  makes it a durable topic index rather than a temporary superior override.
- Root should reconcile the profession-book visibility implementation finding
  above and stale cross-domain summaries that still cite 3,000/6,000 combat
  budgets. This lane intentionally did not edit `BACKLOG.md`, `AGENTS.md` or
  technical/process guides.

## Validation

`git diff --check` passes. No Lua, runtime, performance, GUI, reference-project,
vendor or media test was run because the owned changes are Markdown only.

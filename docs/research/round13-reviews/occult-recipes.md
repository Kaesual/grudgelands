# Independent occult weapon recipe review

2026-09-21. Reviewer: native GPT-5.6 Sol `/root/occult_recipes_review`,
independent of the native Sol implementation agent and the native GPT-6 Astra
coordinator additions. Authority: the approved **Plain caster weapons and
bows** section of `docs/design/crafting_equipment_revision.md`, the project
workflow checklist and the Lua 5.1 rules.

## Result

**Clean after one fixture correction round.** No unresolved Critical, High,
Medium or Low production finding remains. The review found one Medium defect in
the new integration fixture; the coordinator corrected it without changing a
production API, and the corrected frozen fixture passed the bounded native run.

The reviewed package implements all 18 plain outputs and 24 routes: one wand,
one staff and two mirrored bow routes at each of six tiers. T1 routes are
starter-visible; T2--T6 use their matching metal bar as the discovery material.
All remain universal Basics recipes and have no profession, character-level or
recipe-book discovery gate on engine crafting.

## Corrected finding

### R1 — Medium: the initial no-gate assertion called the profession API for a Basics recipe

Original `tools/r13_integration/probe/weapon_recipes.lua:49` called
`grug_jobs.can_craft_recipe` on engine catalog records whose profession is
`general`. That API deliberately enters profession qualification and therefore
rejects an unknown `general` profession; the UI separately treats general
records as universally unlocked. The first corrected native attempt would have
failed before testing the intended grid-veto boundary.

The coordinator replaced the assertion with the actual engine
`core.craft_predict` callback chain over each concrete book route. This follows
`reference_projects/luanti/builtin/game/register.lua:376-382` and exercises the
terminal grid permission callback that can veto a crafted preview. The final
fixture verifies general ownership and an unchanged preview for every one of
the 24 routes. **Resolved.**

An earlier author self-correction changed deferred module lookup from
`core.get_current_modname()` to the explicit probe mod name. It occurred before
the independent finding above and affected only the fixture.

## Reviewed behavior

- The production shapes exactly match the approved table. Wands consume one
  matching occult component, one matching-tier bar and one stick; staves consume
  two components, one bar and two sticks; both bow orientations consume one bar,
  two sticks and three Thread.
- The six component mappings are Boar Tusk, Rotting Flesh, Bone, Bear Claw,
  Sharp Feather and Venom Sac for T1--T6. The two newly useful former trash
  items retain their sell prices and only change to the existing material group.
  No drop definition, chance, weapon definition, stat or enchant operation was
  changed.
- `clear_craft` leaves exactly one current route for every wand and staff and
  two for every bow. The old graded-wood staff, wand and bow routes and the
  former metal-rod wand alternative are absent. The three-cell wand cannot
  collide with the unchanged two-cell dagger.
- The Basics declaration mirrors every engine route exactly: 24 records for the
  18 outputs, T1 `starter=true`, and matching metal `main_material` for T2--T6.
  The complete strict catalog contains 650 routes. Graded wood remains in the
  unchanged Woodcarver enchant recipes and production chain.
- The living design documents now state the approved shapes, component ladder,
  discovery rule and retained enchant-material role. The resolved discussion
  TODO is removed. A stale processed-wood wand/staff paragraph found during the
  final pass was corrected before approval.
- Changed Lua parses under plain Lua 5.1 and introduces no global assignment or
  prohibited syntax. The change adds no callback, hot loop, persistence path,
  protection boundary or migration behavior. Reference submodule pins are clean.

## Evidence and limits

The coordinator's final bounded native log is
`tools/r13_integration/evidence/occult-native.log`, SHA-256
`155ce760488473ab0e7aa2dd0023dacd47dbd17246130581538c87268b0e8dbd`.
It reports `OCCULT WEAPON RECIPES PASS tiers=6 outputs=18 routes=24` and the
combined integration result with 2,341 assertions, catalog 650, 456 book
operations and five existing selected-operation Apply transactions. The input
manifest matches the three production and two fixture Lua files reviewed here.

The final static log is `tools/r13_integration/evidence/occult-static.log`,
SHA-256
`5ec71b794222ba97fcfc4c7a5326c871df92dafee184923af1ed54a2028cdacc`.
It records plain-5.1 parser success for all five changed Lua files plus the
SETGLOBAL and five required sweeps; reported tree matches are known prose or
string-literal matches rather than prohibited changed code. I independently
reran the parser, SETGLOBAL check and diff checks while reviewing, but did not
duplicate the native server run.

No PUC runtime, GUI, mapgen, broad suite, sync, merge or push was performed by
this reviewer. Native matching covers registered routes, consumption, retired
forms, mirrored bows, discovery and craft-predict authorization; final recipe
appearance and hands-on crafting remain user GUI checks.

Calibration: production recipe implementer native GPT-5.6 Sol; coordinator
additions native GPT-6 Astra; reviewer native GPT-5.6 Sol in an independent
context. Findings: 0 Critical, 0 High, 1 Medium fixture finding, 0 Low; correction
rounds: 1; production findings: 0.

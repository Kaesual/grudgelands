# Round 75.2 — Solid decoration surfaces and fuller rooms

Status: complete, independently reviewed, merged into main as one squash
commit and synced to the local Luanti installation, 2026-11-10. Not pushed;
desktop/web GUI acceptance remains open. Work started from main 0.75.1
(`b44507d1`) in its own round worktree; `round-75.2` preserves that history.

## Scope and user rulings

- Audit every decoration introduced in Round 75, including the purchasable
  versions and city copies. Fix the broken flask, writing, scroll and wall-tool
  surfaces and any shared cause; validate actual alpha/material/UV behavior,
  not only texture-file existence or a false-color geometry preview.
- Add a moderate amount of purposeful decoration to larger houses and
  profession-trainer buildings. Keep doors, services and circulation usable.
- Add wall art and other non-colliding accents to the six royal halls. No
  added decoration may provide a standing surface or obstruct combat.
- Keep camps excluded. No price, crafting or reward changes. Stable item IDs.

Classification: **map reset**, because city placement changes; it joins the
already planned production reset. Texture fixes alone are compatible. No
migration, live retrofit, production reset or push.

## Work and review

The coordinator owns material fixes, full material validation, engine-exported
preview evidence and release integration. The CITY implementer owns the
explicit placement authoring/catalog and its audit. A separate agent audits
all new decoration materials and independently reviews the coordinator's fix;
a different reviewer checks CITY. Shared-worktree files have disjoint owners.
The Lua process budget remains eight across all work; CITY uses at most three.

## Gates and GUI checklist

- Real texture alpha and complete material coverage for all new decoration
  definitions; full opaque surfaces on closed props, explicit intentional
  transparency only; exact city/player material parity.
- Real node definitions, mesh slots, UVs, handedness and actual-texture preview.
  A browser preview alone does not establish Luanti runtime acceptance.
- Strict audit of all 24 city builders, route/service support and non-colliding
  royal additions, real lazy rotated placement, changed settlement identities.
- Focused fixtures, changed Lua 5.1 checks, generated artifacts, upgrade and
  template/source gates; independent review before integration.
- User desktop/web: inspect every prop in the local contact sheet and in game,
  particularly flasks, paper goods, wall tools, food/ore baskets and plants;
  visit large houses and profession trainers; fight/move through all royal
  halls and confirm there is no new standing surface or obstacle.

## Completion

Implementation and final integration gates complete. Independent reviews:
**MERGE** for MATERIALS, CITY, TOOLS, the final support-geometry delta and
release integration. No GUI acceptance claimed.

The material audit found 21 definitely affected furnishing types and their city
copies, plus an unsuitable clipped herb-bundle surface. Transparent inventory
sprites (paper, books, brick, food), mineral overlays without a base and the
nearly empty glass-block texture had been applied to closed 3D forms. Existing
checks verified files and geometry but not resulting opacity. The shared
browser renderer also forced clipping on meshes and non-cube nodeboxes, so it
could conceal the black opaque-background defect.

The fix uses complete material surfaces, with separate paper/cover/ink/tie/flask
parts and opaque stone/grass under mineral/foliage overlays. The two heraldic
silhouettes keep intentional clipping. The tool board did not reproduce the
same alpha defect: its original wood/steel textures were opaque. It now uses
separate wood handles and brighter metal heads, and remains an explicit GUI
recheck rather than a claim that the reported runtime cause was reproduced.

CITY changes are explicit authoring data: **649 → 770 placements**, with 338
of the 515 surveyed entries decorated and 177 intentionally quiet. Twenty-nine
large residences receive one additional spaced accent; all 42 buildings with
profession-trainer sockets receive one to three (+86 in total). Each of the
six royal halls replaces its two prior floor displays with wall accents, for
four non-walkable wall objects per hall. The complete before/after ledger lives
in `tools/r75_city/report.json`; it counts blueprint alternatives, not a world.

All 24 strict city audits, actual lazy/rotated placement, access (8,985 checks)
and PvP/camp exclusions (5,694 checks) passed. The six capital identity pins
change; their raw point/build digests and all town pins remain unchanged.
The focused furnishing fixture passes 14,632 checks and all 38 generated meshes
are current. The final isolated 0.75.2 headless boot passed. The earlier
45-second node-export run produced the complete dump but ended before listening;
it is not counted as a successful smoke boot.


Final verification:

- **344 portable fixtures passed, zero failures**, one complete integration run.
- Material audit: **194 definitions**, 92 resolved texture expressions, 114 mesh
  nodes, zero errors/warnings. Every city clone retains the source's materials.
- The immutable 0.75.1 dump reproduces 56 missing-explicit-mode and 24 actual
  alpha-policy failures; the corrected dump has none. These are policy failure
  counts, not distinct broken-item counts. All four reported cases are pinned.
- Renderer regression covers cube, nodebox and mesh alpha handling. All five
  labelled preview scenes rebuild byte-identically. Actual-texture contact
  views cover the 82 source definitions, with a close view of the four reported
  props; this remains authoring evidence rather than Luanti GUI acceptance.
- Final node dump: 1,309 nodes / 49 aliases. Final 120-second isolated boot passed
  after the support correction. Chandelier and hanging-plant supports now connect
  continuously without changing their overall bounds or collision behavior.
- Changed Lua and generated Lua scenes passed the Lua 5.1 parser and six sweeps.
  Template audit: 284 templates, six layouts, six rosters, zero errors and 59
  existing warnings. Editor: 656 checks; reader: 56 checks.
- Fresh-server source audit, upgrade self-test/declaration, generated design
  tables and game design audit passed (18 existing design warnings). Generated
  meshes and gallery are current; diff whitespace check passed.

Main did not move beyond the included 0.75.1 baseline during implementation.
The merged tree matches the reviewed round tip. No push, production deploy or
world reset was performed. The user's desktop/web checklist above stays open.

# Town architecture transfer

User-authorized study scope, 2026-11-11. Original branch: `study-dwarf-architecture`.
The user accepted the framing revision at `48d69ef0` and authorized game
integration on `round75.5` in the same worktree. The historical study phases
below remain tools-only; current implementation and gates are owned by the
[Round 75.5 plan](round75.5-plan.md).
The reviewed twelve-building study is secured in commit `28231c5e`.

## Scope and delivery

The user chose a lean transfer to ordinary residential and profession/service
buildings, using the existing shared templates and culture palettes. This is
an offline browser pass first. Shipped game templates, palettes, versions and
installed worlds remain untouched. **Compatible, tools only.** Adopting the
results in world generation later requires the normal map-reset declaration;
that reset can join the already planned production reset.

- Keep silhouettes, occupied cells, orientations, doors, windows, furniture,
  circulation, points and placement bindings. Do not add obstacles or decor.
- Preserve all twelve refined reference scenes exactly. The material choices
  and individual refinements are recorded in the
  [reference study](../../tools/dwarf_architecture_study/README.md), its source
  and six audit snapshots. Those examples determine the transfer's direction.
- Transfer facade roles to ordinary enclosed buildings across all six start
  towns and six capitals. Resolve each actual placement palette independently;
  shared templates can have different results in different towns.
- Exclude royal halls, gates, watch/toll towers, other special military or
  religious compositions, ruins, open structures and grounds. Camps are not
  included. The full list and reasons are in the generated audit and browser.
- Keep the four reed stair shapes browser-only for now, using the existing
  reed texture. A later game implementation must register the required shapes.

## Transfer choices

These are coordinator defaults for review, not a new worldwide architecture
system. The offline transformer does not replace the runtime template loader.

The base and lowest wall course use each culture's selected base material.
The framing revision replaces material-role heuristics with continuous facade
runs. Solid columns at corners and selected intermediate bays become one-cell
piers; doors, windows and chimneys keep their existing nodes. Local roof heights
define ties. Human/troll frames share a low-eave belt across the building; elf
facades retain one continuous green belt. Higher asymmetric side walls remain
walls, and dwarf timber starts only in the actual gable above the higher roof
endpoint. Remaining cells form calm, single-material infill fields.

Troll infill trials existing umber clay (`grug_nodes:clay_band_umber`) instead of
red jungle bark. This is a browser proposal awaiting the user's visual response;
the twelve original references, including the two bark-filled troll buildings,
remain exact benchmarks. Original platforms and under-floor stilts are preserved.

Human and elf buildings retain their existing roof family, carrying forward
the user's preference for their original roofs. Dwarves use dark slate;
undead use obsidian brick; trolls use the brown reed preview. Flat orc roofs
get the red edge and earthy inner surface. **Pitched orc roofs retain their
existing red brick family**, a visual correction after the first transfer
pass; the earthy surface is scoped to flat roofs. Existing parapets and
signature details remain unchanged.

The small set of buildings with raised floors, multiple roof/floor levels or
tall walls is highlighted for visual inspection. It does not imply that each
of the other buildings needs a separate user approval conversation.

## Artifacts and verification

The [transfer tool](../../tools/city_architecture_rollout/README.md) owns its
build commands, audit, overview, browser receipt and contact sheets. The
browser is a Three.js approximation; it is not a native Luanti acceptance run.
Its current audit is a complete per-placement cell delta, suitable as input
for a subsequent implementation, without applying it to shipped templates.

Independent review is required before the transfer is committed. The user
reviews visual exceptions in the overview. Game integration, its map-reset
release, engine checks and desktop/web walkthrough remain a later step.

## First transfer — 2026-11-11 (`a4579cf1`)

The browser transfer is complete: 145 distinct comparisons, twelve unchanged
references and seven highlighted structural cases. All 299 placement rows are
accounted for, including 154 explicitly deferred rows. Open the local
[overview](http://127.0.0.1:8875/) to filter by culture and inspect paired scenes.

Independent implementation review: **PASS**; the sole finding, the STATUS date,
was corrected. Source/reference hashes, all material deltas, unchanged geometry
and the full scope accounting were verified. Browser checks passed (521 scene
assertions and 15 overview assertions, no exceptions). Both the coordinator and
reviewer visually inspected all fifteen final contact sheets. The tool README
links the reproducible evidence. The independent overview follow-up also passed
with no findings. No game integration, merge or push was made.

## Framing revision — 2026-11-11

The user found unstructured mixtures of frame and infill in the first transfer,
and approved a shared structural grammar instead of reviewing each building.
The revised overview opens on four contrasting forms: Harvest Inn (long facade),
Smithy (joined wings), Lane House (high dwarf side wall) and Elder Stilt (raised
troll house). Each shows its previous-transfer capture next to the revised one;
clicking opens the full 3D original/proposal comparison. Culture filters expose
all 145 scenes. All twelve original references remain unchanged.

Independent topology review **PASS**: complete exposed-wall coverage, continuous
piers, asymmetric roof transitions, protected chimneys and exact reference
bypasses verified. The revised package passed 521 comparison assertions with
172 captures, 18 overview assertions and 14 grouped structural checks decoded
from the delivered scenes. The coordinator inspected all fifteen final contact
sheets. Final independent evidence review **PASS**: current page/capture hashes,
all fifteen contact sheets, four previous-image hashes, overview and documentation
verified; no findings remain. Tools only; no game files,
version, world or main branch changed. The user subsequently accepted this framing revision and authorized the
[game integration](round75.5-plan.md). Native desktop/web acceptance remains open.

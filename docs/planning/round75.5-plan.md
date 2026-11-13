# Round 75.5 — Town facade integration

## 1. Scope and execution

One implementation lane on `round75.5`, using the existing architecture worktree.
Base: current main `64d585f4`, merged into the reviewed study as `c97cf2a5`.
The separate Round 76 worktrees are not touched. The user authorized integration
on 2026-11-11 after approving the framing revision (`48d69ef0`).

## 2. User rulings

- Adopt all 145 reviewed template/palette scenes (136 template files) from the
  [framing study](../../tools/city_architecture_rollout/README.md).
- Preserve the twelve original reference designs exactly, including the two
  original troll examples. Other troll infill uses the approved umber-clay trial.
- Preserve shapes, openings, orientation, furniture, decor, points, access and
  placement. Camps stay as-is; subsequent authorizations extend the scope to
  the shrine, guild/services and all remaining approved special proposals below.
- Use existing templates and culture palettes; register the four missing reed
  stair/slab shapes with the existing shape helper and texture.
- **Map reset**, no migration; joins the already planned production reset.

## 3. Implementation conventions

Bake the approved material assignments into template legend roles and existing
race switches. Dedicated `facade_*` palette roles leave the older building and
camp vocabulary unchanged. No runtime facade inference, format extension or
new world-generation pass. Integration compares real resolved template cells
against the frozen approved deltas, with only preview reed ids renamed to the
registered family. Keep decoration positions/items intact while refreshing
expected support materials where the facade changed.

## 4. Validation

- Exact before/after comparison for every included placement; excluded uses
  and protected content unchanged; real loader/rotation coverage.
- Lua 5.1 checks, template validator/self-test, viewer/editor tests.
- Node-registry refresh through an isolated engine boot; shape parity.
- Relevant city/decor/settlement fixtures and updated material identity pins;
  full portable suite once, fresh-server and upgrade checks.
- No seed fleet: only node substitutions, no terrain/placement/footprint or
  writer change (round-workflow seed-fleet rule).
- Independent review; no push. Main integration/sync is a later delivery step.

## 5. Desktop and web GUI checklist

- Visit all six start towns and a residential/profession district per capital.
- Check long human facades and joined workshops: thin continuous frames.
- Check a high dwarf side wall: masonry up to its roof, timber only in gables.
- Check troll stilt houses and ground houses: umber infill and reed roof corners.
- Check the continuous elf accent, red orc piers and dark undead frames.
- Verify windows, doors, trainer access, wall-mounted decorations and lighting.
- Verify camps and the 16 retained grounds/monuments keep their appearance.
- Inspect monumental gates and royal halls: clear combat floors and unchanged
  access, throne and wall art; coherent masonry and culture-specific cornices.
- Inspect open tower stages, colonnades, treehouse stairs and ruined silhouettes.
- Visit Silverleaf's moon shrine: pale roof, marble lantern/piers, silverwood
  fields and green course; door access and furnishings unchanged.

## 6. Completion

Implementation is complete on `round75.5`; **not merged, synced or pushed**.
The separate Round 76 worktrees and main remain untouched. The independent
implementation review and final proof/documentation follow-up both returned
**PASS**, with no open findings. Classification confirmed: **map reset**, no
migration or new server. No seed fleet is owed for this node-only change.

- 136 templates implement all 145 accepted scene bindings; all 299 placement
  contexts are checked, including 154 unchanged deferred contexts. Original
  templates **and palette/rotation predicates** come from `48d69ef0`.
- The actual Lua loader passes all 580 rotated scene checks (1,409,256 cells).
  Flat-pane rotations are canonicalized only for their identical 180-degree
  geometry. Authored point content, metadata, shapes and openings stay intact.
- Four real reed shapes match the preview geometry and existing reed texture.
  The isolated engine registry refresh passed: 1,313 nodes and 49 aliases.
- All 770 city decoration placements remain; only 71 support names changed,
  including two existing props on the Sunscar armoury's flat roof. All 24
  strict city builder audits and both lazy/rotated decoration checks pass.
- Template validator: PASS, 284 templates / 6 layouts / 6 rosters, zero errors
  and 59 existing warnings; its original BASELINE is retained. Self-tests PASS.
- Viewer tests: 56 checks PASS. Editor tests: 656 checks PASS.
- Lua 5.1 syntax and six sweeps PASS for every changed Lua file. Fresh-server
  audit and the 0.75.5 upgrade declaration/self-test PASS. Local documentation
  link targets: 620 checked, none missing. Git whitespace check PASS.
- Full portable fixture suite: **345 passed, zero failed** (`JOBS=2`),
  including the new architectural regressions, both town/capital identity
  fixtures, decoration/access checks and the excluded royal/PvP checks.
- Final isolated server boot after support-pin integration: PASS (240-second
  smoke run, seed `12771324364340880323`, clean startup/listening).

The map-reset identities in the freeze fixtures were deliberately refreshed.
Their point digests include node palettes, which change even though raw authored
points do not; the exact integration proof verifies those independently.

The archived study pages/captures remain unchanged. Rebuilding them requires
checkout `48d69ef0`; current code uses the separate
[integration proof](../../tools/r75_5_architecture/README.md). Native desktop/web
acceptance remains open on the checklist above. Browser approval and a headless
server start are not a native GUI acceptance run.

## 7. Moon shrine and deferred-structure proposals (2026-11-11)

The user explicitly extended the implementation to `silverleaf_moon_shrine`
and requested a proposal for every previously excluded city structure.
The shrine changes 266 material cells using existing facade roles; pale roof,
roof shape, openings, furnishing, decor, points and collision remain exact.
This joins the same **map reset** release; no new version or migration step.
The original 145-scene audit remains immutable; `shrine.json` is its explicit
supplement. Totals are now **146 implemented contexts / 137 templates**, with
153 deferred city contexts still unchanged. All 299 contexts are checked;
actual Lua proof: **584 rotations / 1,420,760 cells**. Silverleaf's cell identity
is refreshed; its point digest and the other five town identities stay exact.
No additional decor support changes are necessary.

The [deferred-structure overview](../../tools/city_architecture_specials/README.md)
contains all original 154 contexts across 130 templates, including the now
implemented shrine. Every remaining context has a written proposal with its
actual current appearance; all runtime planting is included. Proposals do not
authorize implementing the other structures. Remaining character backdrops and
the opening-logo proposal stay unchanged; only the prepared elf image is
re-rendered. Shipped character art and UI are untouched.

The targeted validation and browser evidence are recorded with that overview.
The previous full-suite/engine results above refer to the original integration;
the follow-up uses targeted tests for the single material-only template change.
Native desktop/web acceptance remains open. No merge, sync or push.

Independent follow-up review (`special_scope_review`): **PASS**, no findings
remaining. All fifteen contact sheets inspected; special-building text proposals
were corrected against their actual geometry. Final evidence: 624 viewer checks,
17 overview checks, 28 character-comparison checks, zero browser exceptions.
Targeted template, town-identity, decoration, architecture, Lua and upgrade
checks pass; source/hash receipts are stored with the overview.

## 8. Guild and ordinary-service follow-up (2026-11-11)

User authorization: align guilds and ordinary service buildings next, and
separate the browser list into completed (for acceptance), pending and a
leave-as-is recommendation group. Implementation follows `services.json`:
50 additional contexts / 45 templates / 19,685 changed material cells.
The first 145 scenes and the shrine remain exact. The 103 other excluded
contexts are unchanged; camps are still outside scope. Totals: 196 contexts /
182 templates; same map-reset release, no migration or runtime facade pass.

Guild halls use explicit bounded wall axes and preserve the ore yards,
headframes, machines, tier stones and service points. Open sheds avoid doubled
interior/exterior posts and retain free-standing supports. Lower frames and
upper galleries are handled separately without altering floors or openings.
Public human roofs use existing red-tile shapes through five added palette
roles, also available in the editor. The original guild generator applies the
same authoring step and reproduces all six templates. Thirteen support names
follow changed materials; the previous 71-change receipt stays separate.

Validation: all 299 contexts checked; real Lua proof 784 rotations / 2,075,264
cells. Structural regression checks 98, architecture 65, guild halls 2255,
Stonewright/services 3991, town freeze 109, capital freeze 302; all 24 strict
city-decoration builders and lazy/rotated checks pass. Template validator:
284 templates, zero errors, unchanged 59 warnings. Lua 5.1 and six sweeps,
upgrade contract/self-test pass. No additional full-suite or engine boot;
those historical results belong to the original integration above.

The browser overview shows 51 completed contexts (including the shrine), 87
pending and 16 leave-as-is recommendations, with linked original study.
Completed views have paired thumbnails and coupled 3D cameras. The reviewer
and coordinator inspected actual rendered buildings. Final browser receipts:
675 viewer checks / 261 captures and 21 overview checks / 3 captures, zero
exceptions. The final independent verdict is recorded below.

GUI acceptance: review the completed group, including guild yard/hall contrast,
open workshop fronts and two-level galleries in all cultures; on native desktop
and web after a separately authorized sync, verify services, decor mounts and
access. No merge, game sync, world reset or push during this follow-up.

Independent final review: **PASS**, no open findings (`service_scope_review`,
2026-11-11). Read-only audit covered all 154 historical contexts, exact scope
and material changes, protected guild yards/machines/displays and gallery
floors, support-name-only decoration changes, generator reproducibility,
structural regressions, all 15 contact sheets and detailed comparisons, final
browser page/capture hashes, status grouping and documentation. User acceptance
remains open; all work is saved locally on `round75.5`.

## 9. Remaining approved special buildings (2026-11-11)

The user's “Die Vorschläge sehen gut aus, setz das bitte so um” approves all
87 pending contexts frozen in the overview at `cbc67f1f`. They cover 72 templates:
royal/sacred buildings, towers and gates, open markets/colonnades/wells, yards,
shelters, ruins and two bough huts. The 16 leave-as-is contexts remain unchanged.
Earlier completion sections record their then-current scope; this is the final
combined state: **283 implemented contexts / 254 templates**, all 299 city
contexts checked. No runtime inference, shape or placement change; same
unreleased **map reset** 0.75.5, no migration, merge, sync or push.

`specials.py` / `specials.json` retain explicit per-typology rules and frozen
source deltas. Twelve hidden city pillar material variants preserve original
fixed boxes and orientations and reuse existing textures. Pillar param2 contracts
are registered in the parts library. The isolated real engine registry refresh
passes (1,325 nodes / 49 aliases). Treehouse `late` flags survive legend baking;
actual planted-before scenes are exported with the real loader for both proof
and browser comparison. All previous 51 special implementations and the 16
retained contexts remain exact. Thirty-three further support-name pins change,
with every decoration position, node and orientation unchanged.

Combined proof: **1,132 rotations / 4,030,468 cells**. Targeted special regressions
cover physical node properties, twelve pillars, open tower floors, royal combat
surfaces, ceremonial troll roofs, ruined timber, treehouse ordering/access and
pale shrine roofs with one green course (135 checks). Guild/service regressions
remain at 98 checks. Full validation and independent final review are recorded below.

The overview now has **138 completed / 0 pending / 16 retained** views, with
paired actual before/after renders. The prepared undead character backdrop is
also refreshed from these templates; all six proposed backdrops now differ from
shipped art. Camera, scene recipes, opening-logo proposal and shipped UI/art stay
unchanged. Native acceptance: inspect all newly completed categories in the
browser; after a separately authorized game sync, check access, wall art and
combat floors on desktop and web. Browser evidence does not replace that test.

Final validation and independent review: **PASS**, no open findings
(`remaining_architecture_review`, 2026-11-11). The reviewer inspected all 15
contact sheets, focused royal/gate/shrine/carver comparisons, exact scope,
geometry, 499 late cells, original implementations and retained contexts,
pillar registration/rotation, support-only decoration changes and final hashes.

- Full portable suite: 343 initially passed; two failures corrected and rerun
  successfully. `r47_nz` found a carved workpiece misclassified as a support:
  its raw trunk is now preserved (43 checks). `r75_art` needed the existing
  default junglewood dependency in its fake registry; it now also checks all
  twelve hidden pillars (1,033 checks). All 345 fixtures therefore pass after
  these targeted corrections; the full sweep was not repeated.
- Special regressions 135 and guild/service regressions 98 pass. Updated capital
  identity fixture passes 302 checks after the carving correction. The real
  loader proof remains 1,132 rotations / 4,030,468 cells. Reproducible special
  authoring records 55,653 material changes in the 87-context supplement.
- All 24 strict city-decoration builders and lazy/rotated checks pass. Template
  validation passes: 284 templates, zero errors, 59 unchanged baseline warnings.
  Lua 5.1 and sweeps pass for all ten changed Lua files; upgrade declaration
  and self-test pass. Local documentation links: 594 checked, none missing.
- Isolated engine boot/registry refresh passes: 1,325 nodes / 49 aliases,
  including the twelve new pillar material variants. No installed world used.
- Final browser evidence: 762 viewer checks / 435 captures; 21 overview checks /
  3 captures; 28 character-comparison checks / 15 captures; zero exceptions.
  The coordinator also inspected all 15 final sheets and the updated undead
  backdrop. Page/capture hashes are stored with each browser receipt.

No main merge, installed-game sync, world reset or push. Native desktop/web
acceptance remains open. The checks and their source receipts are indexed in
[`special_validation.json`](../../tools/r75_5_architecture/special_validation.json).

## 10. User acceptance and delivery (2026-11-11)

The user accepted the browser result and explicitly requested that everything
be adopted into the game and merged back to main. All architecture and special
building previews are visually accepted; this is not a native desktop/web run.
The six approved 1540 × 1400 images are copied byte-identically from
`architecture-refresh/native/renders` into `grug_classes`. Their existing
cameras, compositions and character standing points remain unchanged. The small
recommended crest uses the approved transparent 512px branding export, rendered
as a separate 2 × 2 formspec-unit image centered above the opening text. The
opening image/text stay intact; the crest disappears on race selection.
Source hashes and approval are recorded in `architecture-refresh/installation.json`;
media provenance/hash tables follow the adopted files. The old `native` tool
folder remains the before-comparison baseline.

At delivery start, main `64d585f4` is already an ancestor of the reviewed branch;
there are no intervening commits to reconcile. All new delivery code/assets
receive independent review before the required one-commit squash. The round tip
will be retained as `round-75.5`. Sync is from main into the local Flatpak game;
no saved world is reset, no production update and no push is authorized here.
Final delivery checks and status are recorded below after completion.

Native GUI follow-up: restart Luanti, verify the small crest is centered and
separate from the title at desktop/web window sizes, select each race and check
its matching backdrop/character grounding, then inspect newly generated towns,
royal combat spaces, doors, services and wall decor. Existing generated maps keep
their buildings until a map reset; the release already declares that reset.

Delivery implementation/assets/documentation review: **PASS**
(`remaining_architecture_review`). Six backdrop PNGs and the 512px crest match
approved sources and media hashes; cameras and archived baselines stay exact.
The native crest fits the scene and clears the unchanged opening text, and
leaves with race selection. Character creation: 272 fixture checks; changed
Lua parser/sweeps pass; adopted-state browser check: 28 checks / 15 captures,
zero exceptions. Two stale proposal captions were corrected before delivery.

Final main integration gates: **PASS**. Full sweep: **345 passed / 0 failed**;
isolated 240-second server boot (port 36262, seed `4339807192009219981`) passes.
Fresh-server audit, upgrade/self-test, design data (zero errors, 18 warnings),
income check, building validator (284 templates, zero errors, 59 baseline
warnings), 686 local Markdown link targets and Git whitespace checks pass.
The main content equals the reviewed round tip before delivery-status updates;
there were no merge conflicts. Detailed history is tagged `round-75.5` at
`f9fbb5a9`; main receives one squash commit. Local sync follows this commit.
No production update, saved-world reset or push. Native desktop/web acceptance
remains open despite the user's completed browser acceptance.

Delivery complete: one squash on main; local Flatpak game synced from main.
A full checksum manifest verifies all **4,958 installed game files** against
the checkout (version 0.75.5). The reviewed round history remains in tag
`round-75.5`; the clean worktree and local round branch are removed after
checking that tagged and main game content agree. Port 8876 now serves the
same acceptance pages from main. No production deployment, push or saved-world
reset was performed. New architecture appears in newly generated worlds after
the planned map reset. Final gate/sync evidence: `tools/r75_5_architecture/delivery.json`.

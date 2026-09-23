# Round 18 independent implementation review — A/B/E/F/H2/J

Date: 2026-09-23

Reviewed snapshot: `85c162ab1e971333d90c41d440dc9a1b7f42467a`

Baseline: `7460c49d227a3f66673ad1bf4b7ed429e4b62321`

Review model: GPT-5.6 Sol

Independence: PASS. This reviewer authored none of the reviewed implementation,
fixtures, contracts, or reports.

## Verdict

**CHANGES REQUIRED.** Package J removes every shovel's `crumbly` capability,
but does not project the replacement `grug_loose` group onto two existing
shovel-authored cultural source nodes. This is a progression/resource-access
regression and requires a fix plus focused re-review.

This is a source and evidence review, not the final delivery gate. The frozen
snapshot does not yet contain the required final compact PUC 5.1/LuaJIT
byte-identical micro-KAT pair. Native GUI acceptance also remains pending for
formspec layout, Escape-to-menu behavior, atlas presentation and marker
placement, minimap arrow/toggle/dot policy, particles, tool feel, semantic icon
readability, bow draw/wield appearance, and stable-tag visibility. Those pending
gates are explicit limits, not inferred passes.

## Severity-ranked findings

- Critical: 0
- High: 1
- Medium: 0
- Low: 0

### High

1. `mods/ITEMS/grug_gathering/nodes.lua:46` — cultural source registration
   copies only the catalog's old `crumbly` group and never adds `grug_loose`,
   while J removes `crumbly` from every shovel
   (`mods/ITEMS/grug_materials/tools.lua:104` and
   `mods/ITEMS/grug_materials/overrides.lua:96`); consequently ordinary Red
   Ochre and Gravesalt sources no longer have a shovel digging route, and Red
   Ochre's concentrated shovel route is likewise not diggable with the required
   tool. Concrete scenario: wield any registered shovel at
   `grug_gathering:red_ochre_source` (ordinary or concentrated zone) or an
   ordinary-zone `grug_gathering:gravesalt_source`; `can_dig` may authorize the
   family/zone policy, but engine dig parameters find no shared groupcap, so the
   intended source cannot be harvested by shovel. This contradicts the exact
   ordinary/concentrated family table in `docs/design/items_crafting.md:1407`
   and `docs/design/items_crafting.md:1409`. Add `grug_loose` to cultural nodes
   whose ordinary or concentrated family is shovel, while retaining `crumbly`
   only if another intended family still needs it; extend the final-registration
   fixture with both sources and both zone policies so this cross-mod boundary
   cannot regress again.

## Verified implementation boundaries

- Trainer operations remain player-local and proximity-bound. A successful
  Learn reports success and book guidance; rejected Learn does not. Cooking is
  protected at the formspec, forged Unlearn/Confirm, and public `unlearn` API
  boundaries. A primary Confirm is accepted only after that session entered its
  explicit confirmation state, and only the selected primary's slots, level and
  current-tier craft count are cleared (`mods/PLAYER/grug_jobs/trainers.lua:73`,
  `mods/PLAYER/grug_jobs/trainers.lua:90`,
  `mods/PLAYER/grug_jobs/trainers.lua:103`,
  `mods/PLAYER/grug_jobs/trainers.lua:115`,
  `mods/PLAYER/grug_jobs/state.lua:86`).
- The regional atlas is a complete overlapping 3 by 2 cover of the authoritative
  world rectangle. Renderer and runtime projection both consume
  `grug_map/atlas.lua`; formspec width derives from the world aspect and marker
  projection uses the same centered rectangle. Existing marker providers remain
  in the atlas path. Native minimap modes are surface/off with zero-based surface
  selection. Player and entity dots are disabled with `show_on_minimap=false`,
  while the engine draws the local direction arrow separately
  (`mods/PLAYER/grug_map/atlas.lua:6`, `mods/PLAYER/grug_map/page.lua:65`,
  `mods/PLAYER/grug_map/minimap.lua:2`; engine contract
  `reference_projects/luanti/doc/lua_api.md:9366`, implementation
  `reference_projects/luanti/src/script/lua_api/l_object.cpp:2801`,
  `reference_projects/luanti/src/client/content_cao.cpp:917`).
- The shared XP setter rejects non-finite input and clamps before metadata
  persistence. Upward callbacks execute after the new XP is stored; stats fill
  HP only while HP is positive, mana does the same, and no path mutates rage.
  Downward changes and join-style callbacks clamp rather than fill. Death XP
  mutation is removed, and capped grants report the actual zero or partial
  amount (`mods/PLAYER/grug_xp/init.lua:55`,
  `mods/PLAYER/grug_classes/stats.lua:153`,
  `mods/PLAYER/grug_classes/stats.lua:194`,
  `mods/PLAYER/grug_abilities/init.lua:2755`).
- Preparation gates faction, race and class both when displaying forms and when
  processing submitted fields. Dismissal suppresses progress-driven reopening;
  a failure transition reopens once. Retry preserves scheduler progress and
  starts a new arrival load where applicable. Complete characters are released
  in place, partial characters resume at their first missing step, and arrival
  callbacks re-fetch the player and validate both session identity and load
  generation before committing class or teleport (`mods/PLAYER/grug_factions/init.lua:305`,
  `mods/PLAYER/grug_factions/init.lua:314`,
  `mods/PLAYER/grug_classes/selection.lua:239`,
  `mods/PLAYER/grug_classes/selection.lua:316`,
  `mods/PLAYER/grug_classes/selection.lua:475`,
  `mods/PLAYER/grug_classes/selection.lua:537`).
- Every active ability registers a semantic inventory icon. Stack synchronization
  explicitly clears any old `inventory_image` override and changes only the
  `wield_image` according to equipped weapon/offhand state. Empty equipment
  restores the registered neutral colored-orb wield fallback, while inventory,
  hotbar and catalogue stay semantic. The bow draw path remains separate from
  equipment refresh, and wear/range metadata is untouched
  (`mods/PLAYER/grug_abilities/init.lua:797`,
  `mods/PLAYER/grug_abilities/init.lua:1733`,
  `mods/PLAYER/grug_abilities/init.lua:1832`,
  `mods/PLAYER/grug_abilities/init.lua:1962`).
- Capital mount displays clear the parent nametag and use the existing managed
  carrier. The carrier owner deduplicates by parent, applies NPC colors and the
  existing 25/30-node hysteresis, and excludes NPC-category displays from the
  injured hostile/neutral/guard HP-bar set. Display-type changes and deactivation
  remove the carrier (`mods/ENTITIES/grug_mobs/capital_displays.lua:76`,
  `mods/ENTITIES/grug_mobs/capital_displays.lua:88`,
  `mods/CORE/grug_core/tag_carrier.lua:64`,
  `mods/CORE/grug_core/tag_carrier.lua:252`,
  `mods/CORE/grug_core/tag_carrier.lua:303`).
- For the nodes currently included in J's fixture, loose-material membership is explicit rather than inherited from all
  `crumbly` nodes. Shovels expose only `grug_loose`; picks retain rock/resource
  capabilities and add the corresponding shovel times multiplied by two.
  Starter and six metal tool tiers preserve their depth/harvest metadata and
  lifetime owner. Sandstone, clay, snow, stone and ores receive no shovel route
  (`mods/ITEMS/grug_materials/mining.lua:92`,
  `mods/ITEMS/grug_materials/overrides.lua:55`,
  `mods/ITEMS/grug_materials/overrides.lua:96`,
  `mods/ITEMS/grug_materials/tools.lua:71`,
  `mods/ITEMS/grug_materials/tools.lua:104`).

## Evidence assessment

The review inspected the changed production code and the real-module fixtures
behind `round18-map-report.md`, `round18-xp-report.md`,
`round18-waiting-report.md`, `round18-tools-report.md`,
`round18-icons-tags-report.md`, and `tools/r18_ux/REPORT.md`. The supplied
LuaJIT results cover the requested bounded matrices and state transitions. No
additional LuaJIT reproduction was necessary: the missing group is directly
established by final registration composition and the engine's shared-groupcap
dig contract. The reports correctly avoid claiming native GUI coverage or final
fallback-interpreter parity. The J fixture's material matrix omits both cultural
sources and therefore did not exercise this existing cross-mod consumer.

`git diff --check` is not clean because the H2 report has two trailing-space
Markdown line breaks and the round plan has a final blank line. These are
documentation whitespace only and do not change the implementation verdict.
The snapshot's reference submodules are represented by symlinks, so this
worktree cannot perform the repository-level submodule-status check; no
submodule was edited during review.

## Calibration record

- Task classification: non-trivial, cross-package implementation review
- Implementing model(s): native GPT-5.6 Sol for the reviewed lanes, with root
  GPT-6 Astra integration/corrections as recorded by the lane reports
- Reviewing model: GPT-5.6 Sol
- Initial review findings: 0 Critical / 1 High / 0 Medium / 0 Low
- Fix rounds requested by this review: 1, focused on the cultural-source shovel
  route and final-registration fixture coverage
- Final review state: CHANGES REQUIRED; after the High fix, focused independent
  re-review and the separately owned final PUC/LuaJIT micro-KAT remain required

## Focused High-finding re-review

Re-review date: 2026-09-23

Re-reviewed snapshot: `4d7adb555494e130feffdde2f83da3d6be4dd05a`

Author fix: `8a1a8fca9f128cc4e719d154a26ba3e4acacef52`, integrated by
`44a1a9a0`

**CLOSED — PASS.** `grug_gathering` now projects `grug_loose = 3` onto an
actual cultural source definition whenever its ordinary or concentrated family
is shovel (`mods/ITEMS/grug_gathering/nodes.lua:55`). Red Ochre therefore keeps
its authored ordinary and concentrated shovel routes. Gravesalt receives the
ordinary shovel route while retaining `cracky = 3` for its concentrated T4-pick
route. The change is data-driven from the existing family fields and does not
broaden unrelated hand/axe/pick sources.

The focused fixture now loads the real gathering catalog, harvest policy and
node registrar after the final tool registrations. It checks the actual Red
Ochre and Gravesalt node definitions, ordinary shovel authorization,
concentrated Red Ochre shovel authorization plus pick rejection, and
concentrated Gravesalt wrong-family/T3 rejection plus T4-pick acceptance
(`tools/r18_tools/fixture.lua:168`). The bounded LuaJIT run passed with:

```text
r18-tools: wood=30,stone=60,bronze=300,iron=600,steel=1000,silversteel=1500,embersteel=2000,abyssal_steel=3000 loose=shovel/pick2x solids=denied depth=denied harvest=shatter stack=override cultural=ordinary+concentrated family+tier
```

Final finding state after one fix round: 0 open Critical / 0 open High / 0 open
Medium / 0 open Low. The independent implementation verdict is now **PASS**.
After the focused source review, the root-owned isolated native gate also
completed successfully on the same production bytes. Its archived log records
`[r18_tools_native] PASS materials=8 loose=6 ratio=2 solids=denied cultural=diggable`
and `[r18_integration] PASS` in
`tools/r18_final/evidence/native.log`. Root verified all 2,083 production
snapshot hashes against `4d7adb55`; this reviewer inspected the archived PASS
lines. The required final frozen PUC 5.1/LuaJIT pair and native GUI/user
acceptance remain separate gates.

# City-structure follow-ups and acceptance overview

Prepared on 2026-11-11 in the existing `round75.5` worktree. The user requested
an actual Silverleaf moon-shrine update and a browser overview with a proposal
for every structure excluded from the previous city architecture pass.

## Open

Serve the **repository root** on the existing preview server:

```sh
python3 -m http.server 8876 --bind 127.0.0.1
# http://127.0.0.1:8876/tools/city_architecture_specials/
```

[index.html](index.html) has 154 filterable cards, a written proposal for each
placement/palette context, priorities and links to the interactive viewer.
The page separates **138 completed** contexts for acceptance, **0 pending**
proposals and **16 leave-as-is** recommendations. Completed views have paired before/after thumbnails and a
coupled interactive comparison. Pending and leave-as-is views show the actual
unchanged building. Status, culture, type, priority and text filters combine;
the initial view is the completed group. The earlier 145-scene study is linked
separately. The [character backdrop comparison](../character_creation_preview/architecture-refresh/index.html)
now includes the revised shrine.

## Exact scope

The immutable [previous audit](../city_architecture_rollout/audit.json) lists
154 excluded contexts across 130 templates in the twelve start/capital layouts.
This overview includes every row, including repeated/shared templates with
locally different palettes. Its counts by culture are human 30, dwarf 22,
elf 24, orc 21, troll 20 and undead 37. Together with the previous 136 templates,
these cover all 266 templates used by those layouts. The remaining 18 camp
files remain outside the user-requested city scope. This is not a claim about
all procedural structures in the entire game.

The exclusions include buildings **and grounds**: markets, wells, statues,
colonnades, gardens and ruins. Keep a coherent cultural material vocabulary,
but preserve monumental masonry, open structures and intentional decay. Start
with the six miners' guilds and ordinary inhabited military/service buildings,
then individually composed royal/religious/defensive structures. Grounds often
need only restraint and aligned existing edges, not new walls or decoration.
No extra collision, geometry or obstacles are proposed in royal combat halls.
The user subsequently approved all 87 pending proposals. The 16 leave-as-is
contexts remain unchanged; the final implementation is recorded below.

Names do not reliably describe physical forms. The editorial rules explicitly
distinguish enclosed drill buildings from yards, inhabited watch houses from
towers, ordinary chapel/gate houses from monuments, the candle memorial from
a market, the enclosed Totem Shrine from open shrines, and the stump-supported
bough huts from living trees. Kezamba's royal hall has basalt walls but an
actual junglewood roof; its proposal preserves that existing dark roof.

## Actual scene sources

`build.py` reads the audited placements and current game palettes.
`export.lua` calls the **real template loader**, including planted trees,
undergrowth, late cells and pane resolution, rather than approximating them.
All 13 contexts with planting therefore include that vegetation. The viewer
uses the existing shared Three.js renderer and original game textures, with
source provenance retained in the existing mod media licences. No new artwork
or external service is involved.

Scenes are isolated building parts: surrounding city geometry, NPCs and the
later city-decoration overlay are not displayed. The page states this limit.
Roof tops and raised bases use full exported bounds for camera framing.
`catalog.json` records placements, bindings, source hashes, proposals, actual
materials and planting; `build-report.json` pins the input audit, templates,
layouts and viewer. `captures/` and `contact_sheets/` provide visual evidence.

## Moon shrine implementation

The explicit extension is authored by
[`shrine.py`](../r75_5_architecture/shrine.py), with immutable-source deltas in
[`shrine.json`](../r75_5_architecture/shrine.json). It changes 266 material cells:
pale base, marble piers, silverwood fields, one continuous serpentine course
at y=7, and marble supports on the open roof lantern. All roofs, cell positions,
orientations, collision shapes, openings, points, furnishings and decor remain.
The existing `facade_*` roles are sufficient; no new material or runtime
inference is added. The existing map-reset release 0.75.5 covers this change.

The shrine-only integration proof covered 146 contexts / 137 templates and
153 unchanged exclusions (584 rotations / 1,420,760 cells). Silverleaf's cell identity changes; its point digest and all
other town identities remain exact. No decoration support pin needs changing.
The refreshed elf PNG differs; the other five prepared PNGs are byte-identical
to the preceding proposal. Shipped character art/UI and the installed game are
unchanged. The subsequent service integration is recorded below.

## Rebuild and checks

```sh
python3 tools/r75_5_architecture/shrine.py
python3 tools/r75_5_architecture/integrate.py --runtime
python3 tools/city_architecture_specials/build.py
node tools/city_architecture_specials/check.mjs
python3 tools/city_architecture_specials/overview.py
node tools/city_architecture_specials/check-overview.mjs
```

Chromium uses `CHROME_BIN` when set, otherwise the existing local cached build.
It gets a separate temporary profile. The browser check covers every context,
texture loading, honest existing/proposal labels, shrine camera coupling,
direct links and narrow layouts. The overview check covers all cards, images,
filters, unique links and narrow layouts. Receipts bind current page hashes
and capture hashes. The coordinator visually inspected all fifteen contact
sheets and the shrine's front/back/inside comparisons. Independent review
checks implementation, scope, editorial shape descriptions and evidence.

Targeted game checks: template validator (284 templates, zero errors, unchanged
59-warning baseline), start-town identity fixture (109 checks), strict Silverleaf
decoration audit, architecture regression fixture (65 checks), exact runtime
proof, Lua 5.1 syntax/sweeps and upgrade contract. The 345-fixture full suite
and isolated engine boot were already completed for the original integration;
this follow-up adds no engine-facing node/code changes and uses these targeted
checks. Native desktop/web acceptance remains with the user: visit the shrine,
check the exterior, roof lantern, doors and original furniture/decor, then
inspect the character backdrop after a separately approved art integration.

Classification: shrine **map reset**, joining 0.75.5; overview and prepared
character art **tools only**. No merge, game sync, map reset or push is performed.

## Final review and evidence

Independent implementation, scope, visual and editorial review: **PASS**
(`special_scope_review`, 2026-11-11). The review inspected all fifteen contact
sheets, the revised shrine, corrected exceptional typologies and complete
framing of both bough huts and both Sunscar towers. No open findings remain.
Final browser evidence: **624 viewer checks / 159 captures**, **17 overview
checks / 3 captures**, and **28 character-comparison checks / 15 captures**,
all with zero browser exceptions. Game validation passed as listed above.
The user's native GUI acceptance and the remaining proposals' design approval
are separate and still open.

## Guild and ordinary-service implementation (2026-11-11)

The user's next authorization covers all six miners' guilds and ordinary
service buildings. `services.py` freezes the proposed next-step scope at
`33b27633`, plus the two tollhouse contexts and the enclosed Nhal Veyr stable:
50 contexts, 45 templates, 19,685 material changes. No building geometry,
opening, furniture or point changes. Special rules preserve guild yards and
machinery, open shed sides and gallery floors. `make_halls.py --check` reproduces
all six current guild templates, preventing a generator rollback.

Current combined proof: **196 implemented contexts / 182 templates**, all
299 contexts checked, **784 real-loader rotations / 2,075,264 cells**. All 103
remaining historical exclusions are exact. Thirteen support-name changes keep
existing decoration mounts valid; no props move. The original 145 scenes and
shrine remain exact. This joins the unreleased 0.75.5 **map reset**; no migration,
new runtime node, deployment, installed-game sync, merge or push.

Checks: 98 focused structural regressions; 65 architecture regressions;
2255 guild-hall and 3991 Stonewright/service checks; town/capital identity
fixtures (109 / 302 checks); all 24 city-decoration builders and rotated/lazy
checks; template validator (284 templates, zero errors, original 59 warnings);
Lua 5.1 parser and six sweeps; upgrade contract/self-test. This is a targeted
follow-up; the previously recorded full suite and engine boot were not rerun.
Final browser receipts: 675 viewer checks / 261 captures, 21 overview checks /
3 captures, zero exceptions. The independent final verdict is recorded below.

The camera fit uses the renderer's negative-z convention and fits in both
directions; each complete building must occupy 65–90% of the viewport's
limiting dimension. This makes the before/after images useful for acceptance.
Native desktop/web acceptance remains with the user: inspect guild fronts and
yards, shed openings, tall/galleried service buildings, services and decor.

Independent final review: **PASS**, no open findings (`service_scope_review`,
2026-11-11). Read-only audit covered all 154 historical contexts, exact scope
and material changes, protected guild yards/machines/displays and gallery
floors, support-name-only decoration changes, generator reproducibility,
structural regressions, all 15 contact sheets and detailed comparisons, final
browser page/capture hashes, status grouping and documentation. User acceptance
remains open; all work is saved locally on `round75.5`.

## Remaining special structures implemented (2026-11-11)

All 87 proposals pending at `cbc67f1f` are implemented across 72 templates.
Current combined totals: 283 contexts / 254 templates. All original 299 city
contexts are covered by exact proof; 16 retained grounds/monuments stay exact.
The earlier sections above are historical stage receipts. The current overview
has 138 completed / 0 pending / 16 retained contexts. Every completed row has
actual before/after thumbnails and a coupled interactive comparison.

Dedicated rules retain monumental royal masonry and unobstructed combat floors,
open tower galleries, market awnings and colonnades, ruined gaps and timber,
and treehouse platforms/access/late planting. Twelve hidden material variants
reuse the original fixed pillar shapes and existing textures. Pale elf shrine
roofs sit above one green beam course. Thirty-three decoration support names
follow new surfaces; props do not move. The prepared undead backdrop is refreshed;
all six proposed character images now differ from shipped art, which stays untouched.

Reproduce with `python3 tools/r75_5_architecture/specials.py`, test with
`specials_test.py`, then run the existing integration/build/browser commands.
The same 0.75.5 map reset covers this extension. No merge, installed-game sync,
world reset or push. Final evidence is recorded in the round plan; native
acceptance remains open for the user.

Final independent review **PASS**, no open findings (`remaining_architecture_review`).
All 15 final contact sheets and focused comparisons reviewed; 762 viewer checks /
435 captures and 21 overview checks / 3 captures pass with verified hashes.
The full portable sweep had 343 passes and two corrected failures; both targeted
reruns now pass. The carver workpiece keeps its original raw timber, and the
art fixture models the existing junglewood dependency. Full evidence belongs to
the [round plan](../../docs/planning/round75.5-plan.md#9-remaining-approved-special-buildings-2026-11-11).

## User acceptance and game adoption

On 2026-11-11 the user accepted the complete browser result and requested game
adoption and main merge. The previous pending-acceptance statements are stage
history. Final merge/sync and native test status belong to
[STATUS](../../docs/STATUS.md); native desktop/web testing remains separate.

# Round 64 — shared map icons and stable placement

Planned with the user on 2026-10-27. **Implementation authorized on
2026-10-27; M0–M4 implementation and technical gates complete. Separate markers in both views.** The user accepted the initial artwork and requested this
small round after discussing integration, minimap traffic and overlap.
Delivery state: [STATUS](../STATUS.md). Version: **0.64.0**. Classification: **compatible**; only
presentation and derived map caches change. No terrain reset or migration
is introduced, and earlier pending deployment requirements remain intact.

## 1. Lanes and order

Keep the implementation in one lane because sizes, placement and projection share the same coordinate contract. Work packages run in order;
they are not separate parallel implementations.

| Order | Lane / package | Reviewable result | Depends on |
|---|---|---|---|
| 1 | M0 — baseline and minimap feasibility | Before/after probe, chosen composition and cache strategy | Current runtime and approved art |
| 2 | M1 — shared assets and size | Reproducible shipped art, alpha masks, common size conversion | M0 |
| 3 | M2 — placement and world map | Bounded deterministic layout, stable tooltips, all zooms | M1 |
| 4 | M3 — minimap integration | Separate fixed/personal markers, overlay ordering | M0–M2 |
| 5 | M4 — integrated verification | Independent review and technical receipts | M3 |
| 6 | D — delivery documentation | Version/upgrade declaration, design reconciliation, GUI checklist | Reviewed M |

Lane M uses `r64-map` in `.claude/worktrees/r64-map`; the coordinator
handles D after integration. Follow the [round workflow](../process/round-workflow.md)
and the session's model routing. Every non-trivial implementation receives
independent read-only review; only the user pushes.

## 2. User decisions and scope

The approved behavior is owned by
[World atlas — approved icon integration](../design/world_map.md#approved-icon-integration-round-64).
This plan implements it; it does not introduce travel, discovery or NPC rules.

Approved art is the current [review page](map-icon-rework.html), backed by
the [catalogue](../../tools/map_icon_rework/drop01/catalog.json),
[manifest](../../tools/map_icon_rework/drop01/review-manifest.json) and
[generation provenance](../../tools/map_icon_rework/drop01/generated.json).
There are 44 reviewed motifs and 89 PNGs including directional frames.
The final mining-camp choice is revision 5: brown tent and bright pickaxe.
The earlier [inventory](map-icon-inventory.html) records what each replaces.

Out of scope: new artwork, terrain/road generation, new map zooms or layer
controls, automatic clustering, remote marker actions, displacement of
actual world anchors, and any new client/engine requirement.

## 3. Shared implementation contract

The following are **implementation defaults**, not additional user rulings.
M0 validates them against the pinned engine and records any necessary change.

- Ordinary icons use one display-size function: 32 pixels at scale 1,
  multiplied by the client's reported effective HUD scale in both views.
  Convert this screen extent to formspec units for the world map; do not
  independently apply GUI scale to those icons. Round consistently and
  test unequal GUI/HUD settings. The displacement limit uses the same
  logical pixel scale. Area rings and minimap rim indicators keep their
  spatial purpose; exact positional markers do not move to avoid collisions.
- Export occupancy from nonzero alpha in the final PNG, retaining the
  deliberately smaller motif inside an icon canvas. Do not substitute
  bounding-box collisions. No extra clearance padding in the first pass.
- Layout returns `{id, anchor, offset, texture}` records; it never mutates
  source positions. Both renderers consume these records separately.
- Cache identity includes the existing world key, builder/icon digests,
  simultaneous marker set, relevant faction, projection/display scale and
  size policy. Panning is translation, not a new layout. Bound resident
  caches; eviction must reproduce the same result.
- Use spatial neighbor groups, a fixed ordered candidate set inside the
  displacement limit, stable IDs and bounded local improvement. Minimize
  occupied-pixel overlap first, then displacement, within the hard radius.
  Do not claim a global optimum or use elapsed time to choose the result.
- For fixed quest-giver slots, reserve the union of possible status-icon
  masks. This avoids rearrangement on `!`/`?`/story-state changes, at the cost
  of some reserved space when a giver is not visible. Keep these slots
  faction-correct. Reserve known home/innkeeper variants similarly where
  needed. Shared fixed offsets do not change when a viewer's personal state
  changes. Place new personal markers, including Claim Stones, against that
  fixed layout with the same bounded search and accepted residual overlap;
  invalidate only the affected personal placement cache.
- Define canonical neighbor groups in world-anchored coordinates for each
  projection scale, accounting for icon extent and possible displacement.
  Solve those groups independently of viewport/cell selection, then crop
  the result. A viewport margin alone is insufficient: chains of neighboring
  markers could otherwise change a greedy result at the edge. Do not clamp
  every marker to the moving minimap rim.

## 4. Work packages

### M0 — establish the cost and composition strategy

Inspect the current `grug_map` base, atlas, window, providers, layers,
minimap and minimap geometry against the pinned engine. Current world-map
zooms reuse one base; world markers are independent. The minimap currently
mixes baked location icons with individual HUD markers.

The completed feasibility checkpoint below rejected enlarged composed cells.
The user chose separate 32px HUD icons on the minimap, leaving terrain
resolution unchanged. The world map retains its existing separate markers;
zoom changes terrain and anchor spacing, never ordinary icon size. No
per-zoom or per-layer baked map images are introduced. Compare dense and
sparse movement traffic against the baseline and report the added cost.

### M1 — consume the approved assets

Make a reproducible source-to-runtime mapping and checks for dimensions,
alpha, directional orientation and source hashes. Approved 32px PNGs are
the tracked illustrative masters; preserve large originals and previous
drafts in the optional ignored local archive, as requested by the user. Route all riding trainers to the common horse; give the
map its own claim icon without changing the actual Claim Stone texture.
Audit shared uses before replacing files. Keep post, music, daytime and
bezel art unchanged. Update the owning media licence records.

Inspect existing art exporters, especially `tools/r44_mb/gen_baked_art.py`
and `tools/r58_lift/art/ship.py`, so an old generator cannot restore stale
map icons or fail a required check. Remove obsolete runtime use of the
6px variants; do not delete unrelated historical art or fixtures blindly.

### M2 — place icons and integrate the world map

Implement the pure layout and size functions, consuming exported alpha
masks. Lay out only markers that can appear together: the selected world
layer/quest mode and the minimap's own combined set are distinct cases.
Keep zoom/resize-specific results reusable. Ensure state changes that alter
membership or collision masks have explicit invalidation.

Replace the world map's inconsistent sizes, including smaller trainers at
1x/2x. Resolve tooltip hit areas: transparent rectangle corners must not
steal the visible neighbor's tooltip. Verify the feasible hit-area policy
with the engine and keep its formspec byte cost in the measurements.
Preserve exact quest target positions, area extents and player/party arrows.

### M3 — separate minimap markers

Draw both-faction landmarks and the appropriate faction's fixed services
using M2 positions. Paint terrain and all ground overlays first, fixed
symbols above them, and personal/dynamic markers above those. Include the
green Claim Stone preview square in this ordering audit, not just the red
overlay tiles. Do not duplicate icons into each overlay asset.

Quest states, chosen-home/innkeeper substitutions, discovered waystones and
Claim Stone markers remain viewer-dependent. A house must replace the
innkeeper symbol, not leave a second tankard marker underneath. Player and party arrows retain exact positions and rim behavior.

Keep the present visibility rules and minimap modes. Audit remaining HUD
slot capacity and z ordering together; do not silently drop additional
markers or let raised slots draw over the bezel. Invalidate derived map
caches through builder/art keys, including previously prepared worlds.

### M4 and D — verify and deliver

Independent review checks the shared coordinate contract, stale caches,
visibility and personal-state isolation, mask collision behavior, bounded
work, tooltip ownership, texture lifetime and compatibility classification.
Fix confirmed findings before integration. D reconciles the current-behavior
paragraphs in the design owner, records receipts, updates delivery pointers
and declares 0.64.0 compatible when the implementation is actually delivered.
Planning does not change `game.conf`, CHANGELOG or upgrade declarations.

## 5. Verification and acceptance

- [x] Reproducible icon/alpha-mask export and final source-to-runtime hashes.
- [x] Pure layout fixtures: transparent corners, opaque collision, 16px
  bound, coincident anchors, dense residual overlap, shuffled input,
  repeated output, state-mask union, chained overlaps across viewport/cell
  edges, and personal changes that leave shared fixed offsets unchanged.
- [x] Size fixtures at 1x/2x/4x/8x, normal/high terrain, small/full-HD/high-DPI
  windows, and independently varied GUI/HUD scaling.
- [x] Minimap fixtures: both factions, neutral viewer, home replacement,
  waystone discovery, claim relocation, quest-state changes, party/rim
  arrows, overlay toggles, resize, cache invalidation and no hidden slot loss.
- [x] Tooltip cases with overlapping transparent corners on the world map.
- [x] Before/after cost receipts on identical seed, route, speed, window
  and marker population: a dense capital, a camp/POI area and sparse travel;
  walking and mounted travel, cold cells and revisits, long traversal and
  mode/size changes. Report actual remaining overlaps and displacement.
  No unmeasured savings claims or invented hard time limits.
- [x] Changed Lua passes `tools/check_lua.sh`; targeted map, minimap,
  claim/flight and affected art fixtures pass. Use the round workflow's
  full-suite/release gates once at the appropriate integration point.
- [x] One isolated final smoke boot; independent review; local sync from
  reviewed main only. No seed fleet is owed unless scope reaches worldgen.

GUI acceptance belongs to the user on **desktop and web**:

- Compare the same services/places on the world map at every zoom and on
  the minimap: equal ordinary icon extent, readable art, no old badges.
- Inspect a crowded capital and neighboring camps; check displacement is
  modest, tooltips identify the visible icon, and exact targets stay exact.
- Walk across minimap cells and its circular edge; icons glide without
  jumping/repacking or leaking beyond the bezel.
- Change quest status, home, known waystone and Claim Stone state; check
  replacements and visibility without stale or double icons.
- Check normal, claim and flying modes: icons above colored overlays;
  map-off/claim-preview behavior, party arrows, post/music/daytime retained.
- Resize and change GUI/HUD scales; compare readability and size again.

## 6. Start state and execution notes

Execution baseline: main `0cb190ff`, game 0.63.0. The concurrent mount
camera changes are already committed there and are outside this round.
The depth/nether TODOs do not block this round. Capture the approved art
and reviewed plan before creating the implementation worktree.
Do not regenerate accepted illustrations during integration.

The user authorized implementation and pre-commit cleanup on 2026-10-27.
Large generated originals and previous drafts are retained locally under
`tools/map_icon_rework/local-originals/`, excluded from Git. The 89 approved
32px PNGs remain byte-identical and are canonical tracked masters; their
complete hashes are in `drop01/approved-icons.json`. Default builds need
no large original or external generation path. The review page retains the
pre-integration comparison from `0cb190ff` even after runtime replacement.

During execution keep an M0–M4 receipt here, with completed checks and
measured limits, followed by a Completion section when work is delivered.

Planning review completed independently on 2026-10-27 with no remaining
findings. It clarified viewport-independent neighbor groups and immutable
shared offsets across personal changes. New documentation links and anchors
resolve. This is a review of the plan, not implementation or GUI acceptance.


### M0 feasibility checkpoint — 2026-10-27

The reviewed source cleanup is committed on main as `6bfec5b9`; the
implementation worktree is `.claude/worktrees/r64-map`. The committed art
package and both HTML pages total about 2.1 MiB. All 89
accepted icon hashes are unchanged. The optional originals/revisions remain
on the workstation, ignored by Git; a clean-copy build without them passes.

The first composition candidate hits the planned memory checkpoint before
runtime integration. In the pinned engine, each new texture name is cached
in `src/client/texturesource.cpp:383–429`; `getTextureId` reuses identical
names, and the textures are removed at `TextureSource` destruction
(`:205–227`), not when a HUD element stops using them. A server-side cache
limit cannot release these client textures. Ordinary HUD images draw their
whole source image with no minimap clipping rectangle
(`src/client/hud.cpp:488–510`); a reusable large icon atlas cannot simply be
slid beneath the small round bezel without leaking outside it.

The existing runtime probe's baseline is recorded in
[baseline.txt](../../tools/r64_map/evidence/baseline.txt): approximately
350 bytes/s walking and 791 bytes/s riding on its sparse synthetic route.
This is a LuaJIT stand-in, not live-client traffic or a dense-capital result.

[texture_probe.lua](../../tools/r64_map/texture_probe.lua) uses the actual
minimap geometry and cell recipe builder with artificial tile names. It
compares existing 72px cells with a minimal native-resolution composition
candidate (upscale terrain, then add a 32px icon). It counts unique recipes
and calculates final-image RGBA storage, **not measured GPU/process memory**.
Marker layout, the final circular mask after composition, real-world marker
rosters and traffic savings are not implemented by this probe; none can
remove the final texture's width/height cost. The artificial recipe lengths
are diagnostic, not production payload estimates. Receipt:
[texture-probe.txt](../../tools/r64_map/evidence/texture-probe.txt).

A 9,750-node diagonal traversal at 12 nodes/s with 0.09s steps visits 1,025
cells. At 1920x1080, final textures grow from 72x72 to 216x216:
**20.3 MiB becomes 182.4 MiB** of cumulative decoded RGBA storage. Revisiting
identical cells adds zero textures. Traversing again with the flight overlay
brings the totals to **40.5 / 364.9 MiB**. Additional passes after resizing
to 720p and 2160p add no old cell variants but bring the candidate to
**1,302.3 MiB**. At 2160p each candidate cell is 468x468 (the actual geometry's
scale step), while an ordinary icon still occupies 32px at HUD scale 1.
This accounting excludes mipmaps, driver overhead, GUI scaling caches and
intermediate images; it is not a claim about a particular graphics driver's
allocation. Marker count and PNG compression do not reduce these dimensions.

The simple candidate therefore trades fewer moving HUD elements for much
larger session-long client texture storage, particularly on the web target.
The options presented at the plan's explicit M0 checkpoint were:

- Recommended simplification: retain low-resolution terrain cells and draw
  the new 32px icons as individual HUD elements, including fixed places.
  This preserves native-size icon quality and avoids the enlarged-cell cost;
  movement traffic rises with visible icons. Measure dense-capital traffic
  before delivery; no savings claim is made here.
- Retain full-resolution composed cells with the measured memory tradeoff.
  This keeps the requested composition path; a larger implementation to
  bound client texture lifetime is not silently added.

No runtime asset, game version or saved-world behavior has changed.
M0 is partial: this is a decision checkpoint, not completed M0–M4 validation.
The existing baseline and new probe run on LuaJIT; the probe passes the
plain-5.1 parser and repository Lua sweeps. No full fixture suite, GUI test,
smoke boot or local game sync is owed for this measurement-only change.


Independent read-only review of the M0 probe, engine evidence and accounting
passed on 2026-10-27. The user has been asked to choose the simpler HUD-icon
path or retain composed cells with the stated memory cost. Integration is
pending that decision; neither alternative has been selected implicitly.


### M0 decision — separate markers

The user chose separate minimap markers after the memory explanation.
All icons retain their shared 32px size at standard HUD scale; terrain
resolution remains unchanged. World-map icons also remain separate, so
zoom and layer changes need no new baked maps. The earlier fixed-icon
composition preference is superseded. M1–M4 may proceed; no further
composition approval is pending.


### M1–M4 implementation receipt — 2026-10-27

The approved 89 PNGs are copied byte-for-byte into runtime textures by
`tools/r64_map/ship.py`; its generated masks cover nonzero alpha. The shared
`markers.lua` facade handles size conversion, bounded cached placement and
silhouette tooltip regions. Historical exporters no longer overwrite this
set. Large originals remain optional and ignored. Post, music, daytime and
bezel assets are unchanged. The old 6px silhouettes have no runtime bake path.

Both views now draw separate markers. World zoom changes terrain and anchors,
not the icons' HUD-scaled extent. Minimap terrain and overlay resolutions stay
unchanged. Both-faction landmarks join the own faction's services and givers;
the clash site remains the minimap's sole rift landmark. Stable HUD slots grow
with visibility and stay below the bezel; the old 24-slot loss is removed.
Shared offsets reserve quest/home silhouettes; personal markers never move
shared ones. Panning and cell changes reuse a world-anchored layout. At very
high density the bounded local search leaves overlap, rather than moving
icons far away or concealing them.

The pinned engine's integer formspec `imgsize`, truncating image extent and
inclusive tooltip endpoints required explicit rounding. Icon images use the
same rounded HUD extent in both renderers. Tooltip regions cover filled 2×2
interiors; isolated one-pixel slivers cannot own a nonzero-area engine tooltip
without touching a transparent neighbor. World resizing and independent
GUI/HUD scale changes are checked in the existing bounded 2 s window pass,
including solo windows. Player/party anchors and target extents stay exact.

#### Cost comparison and limits

The isolated seed-42 smoke exported its actual authored settlements, sockets,
givers and layer rows through [probe/init.lua](../../tools/r64_map/probe/init.lua).
The captured [roster](../../tools/r64_map/evidence/seed42-roster.lua) is immutable
benchmark data, not a new game input. [bench.lua](../../tools/r64_map/bench.lua)
loads each revision's real atlas/providers/minimap against engine stand-ins.
Before is main `1607e03f` (0.63.0 runtime); after is this lane. Every comparison
uses the same route, roster, 1920×1080 window, HUD/GUI scale 1, 0.09 s steps,
two moving party members and 60 s traversal, followed by an identical revisit.
All own-faction givers are marked available as a visibility upper bound, not
a claim about a particular character's quest log. The flight run includes
the flight-overlay recipes. The fixed routes start at (centre.x − 100, centre.z − 75) and move in
direction (0.8, 0.6).

HUD protocol payload includes **both HUDADD and HUDCHANGE**, including new
pool allocations on the route. It excludes transport framing, retransmission,
compression and media transfer. HUDADD's 82 fixed bytes plus strings follow
`Server::SendHUDAdd` in the pinned engine; updates include id, field and value.
These are stand-in measurements, not network or GPU captures. Complete receipts:
[before](../../tools/r64_map/evidence/hud-before.txt),
[after](../../tools/r64_map/evidence/hud-after.txt).

| Route | Walking 4 n/s, before → after B/s | Riding 8 n/s | Flying 12 n/s |
|---|---:|---:|---:|
| Highcourt, centre (0, −1500) | 596 → 622 | 927 → 908 | 1075 → 1068 |
| Mining camp, centre (240, −1056) | 166 → 199 | 328 → 412 | 541 → 686 |
| Sparse, centre (0, −3000) | 140 → 140 | 271 → 271 | 457 → 457 |

The result is not a general traffic reduction: more visible landmarks cost
updates, while stable HUD IDs avoid some old reassignment traffic. On the
capital walking run the maximum ordinary-marker count grows 16 → 19; cold
bootstrap allocates 31 HUD elements instead of 44 and later grows by 7 (574
payload bytes). Revisits allocate none. A fixture with 32 nearby service/giver
markers confirms all are retained. Layout/bootstrap in these isolated fresh
processes costs about 17–19 ms rather than 0.7–0.9 ms; it includes the complete
world roster and is cached. Revisited update CPU time is about 2–7 µs/step in
the new probe, versus 2–9 µs before; timing is diagnostic, with no hard budget
or output decision based on elapsed time.

For the actual capital roster within 200 nodes of its centre (18 slots),
pairwise nonzero-alpha overlap of the new artwork's reservation masks falls
**4742 → 436 pixel intersections** without/with displacement, maximum
displacement 16 px. At the camp (2 slots), **247 → 0**, maximum 14.42 px. These
counts use the reserved state unions and the canonical layout, not a claim
that every client-rendered pixel is separated under filtering. The synthetic
36-marker stress case deliberately retains 10,906 pairwise overlap pixels.

Cell recipes and 72×72 final dimensions are identical before/after. Capital
routes visit 25/51/76 new cells (walk/ride/fly), then zero on revisit; the other
routes likewise match. The earlier long traversal/resize accounting remains
valid for the unchanged terrain geometry: no native-resolution composed-cell
variants were added. Ordinary icon media are shared PNGs, not per-cell images.

World-map silhouette tooltips increase raw formspec size substantially. The
[window probe](../../tools/r64_map/bench_window.lua) reuses the existing window
fixture's engine stand-ins with the same seed roster and real renderer. It
retains the fixture's known waystone, rift location and entity texts in both
revisions: a controlled comparison, not a byte-identical live-player form.
[Before](../../tools/r64_map/evidence/window-before.txt) and
[after](../../tools/r64_map/evidence/window-after.txt) at 1×: Quests 10.0 → 29.6 KB,
Trainers 7.6 → 64.5 KB, Towns 8.8 → 78.0 KB, POIs 10.2 → 132.3 KB; the largest
8× case is 135.7 KB, with 1675 tooltips including controls. These are uncompressed
form strings. A solo map does not resend on movement; **an open party map can
resend the whole form on the existing 2 s arrow check**, so these larger payloads
can recur (about 68 KB/s for that largest example before transport/compression).
This is the cost of silhouette-specific hover ownership in the first version;
client responsiveness and the chosen tradeoff remain part of GUI acceptance.

#### Validation

- Independent runtime review: **MERGE**, compatible. Confirmed findings about
  image rounding, tooltip endpoints, solo resizing and HUD slot retention were
  corrected and checked independently. Final evidence/doc review: **MERGE**, with no open findings; its clarifications
  about party resends, reserved-mask counts, fixture markers and draw order
  are reflected in this receipt and the design owner.
- `tools/r64_map/portable_test.lua`: 206,509 checks; deterministic placement,
  input immutability, transparent/filled intersections, 16px bound, residual
  density, chained neighbors, state unions, personal isolation and eviction.
- Updated map window fixture: 19,967 checks, including 16 size/zoom combinations,
  actual serialized image extents, every emitted inclusive hover pixel and
  solo resizing. Minimap fixture: 122 checks, including both factions/neutral
  landmarks, faction service filtering, rift duplication exclusion and 32 slots.
  Claim, flight, home, art and travel fixtures retain their existing coverage.
- Full portable suite: 280 passed initially; four obsolete art-size/claim-icon/
  priority expectations and a missing provider stand-in were corrected in those
  fixtures. All four then pass. **All 284 fixtures pass** across that full run
  and its targeted rechecks; no unrelated game fix was needed.
  [Full receipt and rechecks](../../tools/r64_map/evidence/fixtures.txt).
- Changed Lua passes the plain-5.1 parser and repository sweeps; changed Python
  parses. Approved source/export hashes, retained guild art and historical
  baked-font export checks pass. `check_fresh_server.py`, `check_upgrade.py`,
  `r28_design/validate.py --game` (0 errors, 17 existing content warnings),
  `building_templates/check.py` (278 templates, 0 errors, 23 existing warnings)
  and `r37_dc` (766 checks) pass. No seed fleet is owed.
- One isolated final runtime smoke boot passes on seed 42, with no errors or
  undeclared-global warning; [receipt](../../tools/r64_map/evidence/smoke.txt).
  GUI acceptance is still pending on desktop and web. No production state was
  changed and nothing was pushed.


## Completion (2026-10-27)

Independent runtime and final evidence/documentation review: **MERGE**, no
open findings; classification **compatible**. Implementation `3bed24b1` was
merged as `4b17b639` into unchanged main. The reviewed runtime, assets and
upgrade declaration are byte-identical after integration, so the lane's full
suite and final isolated smoke are reused under the workflow's no-duplicate-run
rule. New Markdown links/anchors and `git diff --check` pass.

Local Luanti was synced from reviewed main and its map files/game version
were verified byte-identical. **Nothing was pushed.** Desktop/web acceptance
remains the user's [GUI checklist](#5-verification-and-acceptance); in particular,
check dense marker groups and the larger silhouette-tooltip forms in a party.
The production version and earlier pending reset/migrations are unchanged.

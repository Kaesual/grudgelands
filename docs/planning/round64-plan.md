# Round 64 — shared map icons and stable placement

Planned with the user on 2026-10-27. **Implementation authorized on
2026-10-27; source cleanup is complete and M0 awaits the composition decision.** The user accepted the initial artwork and requested this
small round after discussing integration, minimap traffic and overlap.
Delivery state: [STATUS](../STATUS.md). Target version: **0.64.0** at
integration, not during planning. Classification: **compatible**; only
presentation and derived map caches change. No terrain reset or migration
is introduced, and earlier pending deployment requirements remain intact.

## 1. Lanes and order

Keep the implementation in one lane because sizes, placement and raster
composition share the same coordinate contract. Work packages run in order;
they are not separate parallel implementations.

| Order | Lane / package | Reviewable result | Depends on |
|---|---|---|---|
| 1 | M0 — baseline and minimap feasibility | Before/after probe, chosen composition and cache strategy | Current runtime and approved art |
| 2 | M1 — shared assets and size | Reproducible shipped art, alpha masks, common size conversion | M0 |
| 3 | M2 — placement and world map | Bounded deterministic layout, stable tooltips, all zooms | M1 |
| 4 | M3 — minimap integration | Composed fixed icons, personal markers, overlay ordering | M0–M2 |
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
  source positions. Raster composition consumes these records separately.
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

Measure the current path before changing it. Prototype the smallest path
that composes fixed markers above the map's colored overlays, at sufficient
resolution for the approved icons. First scale the terrain, then insert
icons at their intended display extent; stamping 32 source pixels into the
normal-resolution terrain would enlarge the icons with that terrain.

Preferred candidate: reuse existing media and client texture composition
for cached minimap cells, moving fixed icons together. This is a candidate,
not a performance result. Compare movement packets/bytes, cell recipe
length, generated texture count, decoded texture bytes and server layout
work. Include long traversal and resize/overlay toggles: a server-side LRU
does not prove that the client's texture cache is bounded.

**Checkpoint:** choose and document the composition/cache strategy before
M3. If the candidate causes unacceptable memory growth or needs complex
engine workarounds, report the measured tradeoff and a simpler alternative
to the user before building it out. Do not silently abandon fixed-icon
composition or reduce icon quality. No new PNG upload per movement step.

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

### M3 — compose fixed minimap icons

Compose both-faction landmarks and the appropriate faction's fixed services
using M2 positions. Paint terrain and all ground overlays first, fixed
symbols above them, and personal/dynamic markers above those. Include the
green Claim Stone preview square in this ordering audit, not just the red
overlay tiles. Do not duplicate icons into each overlay asset.

Quest states, chosen-home/innkeeper substitutions, discovered waystones and
Claim Stone markers remain viewer-dependent. A house must replace the
innkeeper symbol, not merely cover an already baked tankard with transparent
corners. Player and party arrows retain exact positions and rim behavior.

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

- [ ] Reproducible icon/alpha-mask export and final source-to-runtime hashes.
- [ ] Pure layout fixtures: transparent corners, opaque collision, 16px
  bound, coincident anchors, dense residual overlap, shuffled input,
  repeated output, state-mask union, chained overlaps across viewport/cell
  edges, and personal changes that leave shared fixed offsets unchanged.
- [ ] Size fixtures at 1x/2x/4x/8x, normal/high terrain, small/full-HD/high-DPI
  windows, and independently varied GUI/HUD scaling.
- [ ] Minimap fixtures: both factions, neutral viewer, home replacement,
  waystone discovery, claim relocation, quest-state changes, party/rim
  arrows, overlay toggles, resize, cache invalidation and no hidden slot loss.
- [ ] Tooltip cases with overlapping transparent corners on the world map.
- [ ] Before/after cost receipts on identical seed, route, speed, window
  and marker population: a dense capital, a camp/POI area and sparse travel;
  walking and mounted travel, cold cells and revisits, long traversal and
  mode/size changes. Report actual remaining overlaps and displacement.
  No unmeasured savings claims or invented hard time limits.
- [ ] Changed Lua passes `tools/check_lua.sh`; targeted map, minimap,
  claim/flight and affected art fixtures pass. Use the round workflow's
  full-suite/release gates once at the appropriate integration point.
- [ ] One isolated final smoke boot; independent review; local sync from
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
Before building M1–M3, ask the user at the plan's explicit M0 checkpoint:

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

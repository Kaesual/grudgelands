# Fix round 0.50.2 — Claim Stone placement preview on the minimap

Coordinator: Claude (Opus 5.5), planned with the user on 2026-10-17.
Status: **go given by the user on 2026-10-17**. Process:
[round workflow](../process/round-workflow.md).

To ship as **0.50.2**, a compatible patch on 0.50.1 (main `bdabec4d`, not
pushed yet). Existing worlds play on: no migration step, no map reset, no
new world. The world map base re-renders once at the first start after the
upgrade (its cache key includes `base.lua`; measured 8.9–10.0 s so far).

**Why:** player feedback. Placing a Claim Stone fails again and again on a
rule the player cannot see (the square reaches into forbidden ground or
another claim); the refusal names the rule but not where it is.

## 1. Lanes

| Lane | Goal | Wave | Implementer / reviewer (default) |
|------|------|------|----------------------------------|
| **CMAP** | While a Claim Stone is held, the minimap shows forbidden ground in red and the player's 101 × 101 square in green | 1 | Opus / Opus |

The reviewer works in a fresh context that wrote none of the change.

## 2. Rulings

User, 2026-10-17:

1. **The minimap only.** No markers in the world, no map window layer, no
   placement through the map.
2. **While a Claim Stone is held** (the wielded item is
   `grug_housing:claim_stone`) the minimap is in claim mode; otherwise it
   is unchanged.
3. **Forbidden ground is semi-transparent red**: every column a claim may
   not cover by `housing.md` §2, that is the other faction's land, level
   1–10 and 31+ zones, capital zones, land that is not the faction's home,
   the coastal shelf and the sea, and the settlement cores and hard
   footprints widened by the 16-node margin. This part never changes in a
   world: it is computed once per world and faction and baked into the
   minimap's cell texture as an overlay, not as markers.
4. **Claims are red too**: every claim in the registry, so drafts, active
   and expired claims alike (a draft reserves its square, `housing.md`
   §2a). They are drawn as rectangles in the cell texture from the
   registry's current state, never baked into an image; a claim that goes
   (picked up, crumbled, destroyed, removed) disappears with the next
   texture.
5. **The player's square**: a semi-transparent green 101 × 101 square with a
   frame, centred on the player's arrow. It is one fixed HUD element; the map
   glides under it, so walking sends nothing for it. The overlap colour comes
   from the blending; no hatching.
6. **Minimap switched off**: it appears while the stone is held and goes
   again afterwards.
7. **Rules unchanged.** `registry.lua` `validate` stays the only authority
   and its messages stay; the preview is a guide.

### Coordinator defaults

The user may overrule these.

- **Conservative red.** The zone part is classified per base pixel (about
  6.67 nodes) and then widened by one pixel; settlement boxes and claims
  are rounded outward. A square that does not touch red passes the zone,
  settlement and claim checks; a square that just touches red may still
  pass. The other way round ("green, yet refused") must not happen except
  for forbidden pieces narrower than a pixel that hold no pixel centre.
  Exact per-column refinement of border pixels is not part of this round.
- **Not shown:** the depth limit (y −100) and the 3 × 3 × 3 arrival cube.
  Both are local and their refusal messages suffice.
- **Placement centre:** the square is centred on the player, the stone lands
  on the pointed node (usually 1–5 nodes away, under one base pixel).
  Accepted.
- **Side row jump:** with the minimap switched off, the mail icon and the
  daytime band move from the corner to beside the bezel while the stone is
  held, and back afterwards (`minimap_view.lua` `side_layout`). Accepted.
- **No faction:** no claim mode.
- **Touching claims:** two claims may share an edge; rounded outward, their
  shared pixel line can get red twice and look darker. Cosmetic, accepted;
  the lane may round shared edges consistently if it is simple.
- **Own claim:** a player who holds a stone while a claim of theirs stands
  sees it red like any other; placing is refused anyway ("already placed").
- **Look:** starting values red about 45 % opacity, green fill about 30 %
  with a more opaque frame. The user tunes them after the GUI test.
- **Version 0.50.2** (not 0.51.0): compatible, one lane, player feedback.

## 3. Shared conventions

- **One source for the rules.** The column rule (`registry.lua`
  `zone_problem`) and the margin and level constants are used from
  `grug_housing`, never copied into `grug_map`. `grug_map` adds
  `grug_housing` to its `depends` (no cycle today: `grug_housing` depends on
  `grug_core`, `grug_mapgen`, `grug_mobs`, `grug_sounds`; the lane checks
  it again).
- **Recipe, not state.** The claim-mode cell texture is a texture string
  built from the minimap tiles, the faction's red overlay tiles and one
  `[fill` per claim. It is rebuilt from the registry, never patched.
- **Pure geometry** goes into `minimap_view.lua` (it calls nothing from
  `core`), so a portable fixture tests it.

## 4. Lane goal

### CMAP — the claim preview on the minimap

**Red overlay (once per world).** `base.lua` `render` already classifies one
water class and zone id per pixel centre (pass 1). From those arrays, and
without asking the zone authority again for those, it renders one overlay per
faction at the **minimap base's size** (1080 × 960): red where the column
rule refuses the pixel centre (territory lookups only for pixels whose zone
is otherwise eligible), plus the settlement cores and hard footprints widened
by the margin, then widened by one pixel.

On a high-quality server pass 1 runs at the Map tab's size (3600 × 3200) and
the minimap gets a downscaled copy (`M.spec`, `M.downscale`). The overlay is
then reduced conservatively: a minimap pixel is red when any high pixel it
covers is red, never by averaging.

Tiles, cache and media:
- encoded as tiles like the base (`M.tiles`; a name such as
  `grug_map_claim_<faction>_<col>_<row>.png`);
- cached in the world folder and covered by the stale-tile removal;
- served to every client with `add_media`, both factions (they are small); a
  client only decodes the tiles its claim-mode textures use.

The cache key (`base.lua` `cache_key`) covers `base.lua`'s own source, the
seed, the world-generation identity and samples of the zone layout. It does
**not** cover the housing rules, so the key gains `registry.lua`'s rule
inputs (the column rule, the level range, the margin). The lane checks that
the settlement boxes are covered by the existing parts of the key, or adds
them.

The settlement boxes and footprints need an enumeration; today only "is
there one in this rectangle" exists (`grug_core.world_feature_boxes_in`,
`grug_zones.hard_footprint_in`). The lane finds the cheapest correct source
and reports it.

If the base or the overlays fail to render, or the minimap is unavailable,
there is no claim mode; placing works as today.

**Claims (live).** The registry gets a claim-set version that changes
whenever a claim is created or removed (also on load and map reset), and a
query for the claims in a rectangle (its spatial grid, `CELL` 128). The API
passes both through.

**Minimap.** A per-player claim mode in `minimap.lua`:
- on when the wielded item is the Claim Stone and the player has a faction;
- the cell texture recipe then adds the faction's overlay tiles to the
  `[combine` after the map tiles (`[combine` blits with alpha), and one
  `[fill` in the same red per claim overlapping the cell texture, before
  the `^[mask`;
- the texture is rebuilt on a cell change, a mode change or a claim-set
  version change, and sent only when the string differs;
- the green square is one HUD image above the map and below the markers,
  placed at the arrow, scaled to 101 nodes at the frame's scale (changes only
  with the window);
- a hidden minimap is created for claim mode and removed after it.

**Hard edge (must be exact).** The engine refuses a `[fill` whose x or y
lies outside the base image or whose width or height is 0, and then drops
the **whole** texture (`imagesource.cpp` `[fill`, `CHECK_DIM`). Every
rectangle is clipped to the cell texture in Lua; empty and fully outside
ones are left out. A part that runs past the right or bottom edge is
clipped by the engine, but the lane clips it too.

**Art.** The green square's texture (fill plus frame), made by a small
script like `tools/r48_hud/gen_hud_textures.py`.

**Docs and version.** `housing.md` §2 (the preview), `world_map.md`
"Minimap" (claim mode, its costs), CHANGELOG, `game.conf` version and
`tools/web_data/upgrade.json` (0.50.2, compatible). STATUS and this plan's
completion are the coordinator's at the round end.

**Measurements** (comparisons, not targets; report them):
- the render's extra time and the overlay tiles' bytes;
- with the stone held on the `texture_growth.lua` walk, the client textures
  and their MB next to the normal walk;
- `bench_glide.lua`-style HUD packets per second while walking with the
  stone held;
- the minimap's µs per player and step with and without claim mode.

**Fixtures.** A new portable fixture for the pure parts:
- rectangle clipping (partly outside at each edge, fully outside, on the
  edge, zero size);
- outward rounding;
- recipe identity (the same claims give the same string, a claim elsewhere
  changes nothing);
- the version counter.

Of the existing fixtures, only the ones that test the changed behaviour:
`tools/r27_minimap/portable_test.lua` (minimap geometry),
`tools/r37_po/portable_test.lua` (minimap updates and texture growth),
`tools/r48_hud/portable_test.lua` (side layout with the minimap shown and
hidden) and `tools/r25_claim_core/fixture.lua` (`validate` must be
unchanged after exposing the column rule).

## 5. Rules

- Repository docs in English, code names in English.
- `core.*` only; no client mods.
- No change to placement rules or messages (ruling 7).
- Lanes never push or merge; only the user pushes.
- Fixtures: run only your own fixture plus the fixtures that actually test
  the behaviour you change (not every fixture that loads a changed file);
  the full run once before your report; name what you ran and why.

## 6. Verification

**Lane gates:**
- `bash tools/check_lua.sh` on every changed `.lua`;
- `python3 tools/check_fresh_server.py`;
- `python3 tools/check_upgrade.py` (compatible);
- the full fixture run once;
- a smoke boot that renders the base and overlays from an empty cache.

**GUI checklist** (desktop and web build, both factions):
1. Hold the stone deep in an own L11–30 zone, far from anything: the
   green square shows, no red inside; placing succeeds.
2. Walk to a border (enemy land, a level 1–10 or 31+ zone, the coast): the
   red shows; with red inside the square, placing is refused with the
   matching message.
3. Near a village or POI: a red box including the margin.
4. A second player's draft nearby shows red at once. After its pickup, or
   after 5 minutes when it crumbles, it goes without re-selecting the
   stone.
5. Another hotbar slot: the normal minimap returns.
6. Minimap switched off: it appears while the stone is held and goes
   afterwards; the mail icon and daytime band move and come back.
7. Window resize and GUI scale 1.5: the square keeps its size relative to
   the map.

## 7. Orchestration

- Start state: main `bdabec4d` (0.50.1, not pushed).
- Worktree `.claude/worktrees/r502-cmap`, branch `r502-cmap`.
- Briefs in `~/projects/grudgelands-orchestration/r50.2/`, written at the
  go.
- One lane, then the independent review, the merge, the round-end gates and
  the sync. Then the user's GUI test (may go together with 0.50.1's) and
  the push.
- Shared files: none with other lanes.

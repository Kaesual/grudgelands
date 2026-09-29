# Round 27 — Own minimap and map quality (WP50)

Drafted 2026-09-29 after the Round 26 playtest; approved by the user the same
day. Work package: [WP50](work-package-scopes.md#wp50).
**Status: approved, not started.**

Running alongside, outside this round: the Round 26 playtest fix for gaps
between capital walls and gatehouses and the wall kink into a river
(branch `r26-w2-gate-fixes`). It touches only capital mapgen; this round
touches no capital files.

## Goals

1. Replace Luanti's native minimap with our own, built on the pre-generated
   world map, so it can show NPCs, quest givers and party members.
2. A server setting chooses the map quality; high quality also feeds the Map
   tab.
3. The relief (height profile) becomes clearly readable on both qualities.

## Rulings

### Map quality and relief

1. **One base image serves the Map tab and the minimap.** Its quality is a
   server setting in `minetest.conf` (for example `grug_map_quality =
   normal|high`), the same for every player on that server.
2. **Normal (default)** keeps today's resolution (1080×960, about 6.7 nodes
   per pixel), so the first world start costs no extra time.
3. **High** is about 2 nodes per pixel (about 3600×3200). No edge above 4096
   pixels, because some GPUs cannot hold larger textures. First render and
   the client download size are measured and reported; the image stays
   cached in the world directory as today, and the quality enters the cache
   key.
4. **Readable relief on both qualities:** stronger hillshading, subtle
   contour lines (about every 16 nodes) and a light elevation tint (high
   ground lighter and stonier). Strength is tuned on images first.

### Minimap

5. **Native minimap off** for every player (`hud_set_flags` minimap and
   radar false, `set_minimap_modes` off as a backstop).
6. **Look and place:** round, top right, the same size and position as the
   native minimap today (the quest list's clearance in `hud_layout.lua`
   stays valid). North up; the player arrow rotates with the view. No
   rotating map.
7. **One zoom level,** a window of about 900 nodes.
8. **Markers:** party members (live), quest givers with their state, the
   Housing Steward, trainers, innkeepers and the player's own home. Party
   members outside the window show as a small arrow on the rim.
9. **Client memory:** the map window snaps to a coarse grid (about 16 base
   pixels) and the arrow moves off-centre inside it, so the client's
   never-freed texture cache grows only when the player enters a new grid
   cell. Markers are separate HUD elements, never drawn into the map image.
   Updates are sent only on change.
10. **Toggle:** a per-player "Show minimap" switch on the Map tab (Luanti has
    no custom keybinds), stored in player meta, on by default.
11. Underground the minimap keeps showing the surface map.
12. Also check the small dark box next to the region names on the Map tab
    (probably a hypertext scrollbar from overflowing label text) and fix it
    if it is ours.

## Lanes

| Lane | Scope | Depends on |
|---|---|---|
| **M — Map quality and minimap** | Rulings 1–12 in `grug_map` (base renderer, page, minimap, atlas markers) and the HUD layout where needed | — |
| **D — Docs** | `world_map.md` (quality setting, relief, minimap), `inventory_equipment.md` / HUD docs where the minimap is described, BACKLOG/ROADMAP/STATUS, WP50 closure | M |

**Order.**
- **Images first:** M shows the normal and high base images with the new
  relief and a mockup of the minimap (with markers, a party rim arrow and the
  ring) before building the HUD part. The user approves them, as with the
  Round 26 capitals.
- Then implementation, fixtures, one short engine check with a screenshot of
  the minimap in play, an independent review, merge, then D.

**Coordination rules** (as in Rounds 24–26):
- Opus lanes in their own worktrees and branches; independent review per
  lane; review findings are hypotheses to verify.
- Checks with judgement: portable fixtures first; engine runs only through
  `tools/luanti_headless.sh`, short (≤ 5 min), `pgrep` clean afterwards; no
  PUC.
- Render time, download size and per-player update cost are reported as
  comparisons; clearly slower preparation or much more complexity goes to the
  user first.
- Afterwards: short playtest.

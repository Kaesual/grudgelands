# Round 11 Scout bow presentation follow-up

## Cause and reference evidence

- The shipped Scout arrow used `visual = "sprite"` with the 16x16 inventory
  icon, so Luanti billboarded a broad square toward the camera instead of
  rendering a projectile along its trajectory.
- Pinned VoxeLibre uses a rigid crossed-plane arrow mesh, the negative-X
  reflection and a dedicated texture
  (`reference_projects/VoxeLibre/mods/ITEMS/mcl_bows/arrow.lua:33-43`). Its
  projectile foundation recomputes yaw and vertical pitch from velocity
  (`mods/ITEMS/vl_projectile/init.lua:50-59`). Luanti's pinned yaw helper is
  `-atan2(x,z)` (`reference_projects/luanti/builtin/common/item_s.lua:153-155`).
- VoxeLibre avoids bow punching by charging on RMB/zoom and uses `on_use` only
  to disable ordinary digging (`mcl_bows/bow.lua:140-160,215-250`). That input
  change is outside the approved Grudgelands contract, which keeps LMB.
- Luanti calls usable `on_use` on the first LMB edge, but then unconditionally
  calls `camera->setDigging(0)` whenever DIG was freshly pressed
  (`reference_projects/luanti/src/client/game.cpp:2786-2810`). Server Lua can
  prevent the attack and continuous air-punch path, but cannot suppress that
  first-person camera gesture while retaining LMB. The remaining initial local
  gesture is therefore an engine/client boundary, not a claimed complete fix.

## Implemented solution

- `scout_arrow` now renders the imported VoxeLibre mesh/texture with its proven
  `visual_size = {x=-1,y=1}` reflection. The public projectile definition has
  an optional boolean `orient_to_velocity`. Spawn establishes rotation before
  return, and each active projectile step recomputes it from current velocity,
  so gravity changes the visible pitch. Collision, active tokens, damage,
  ammo, receipts, and settlement are untouched.
- Loose shows VoxeLibre's three draw sprites through the existing quantized
  0.05-second draw updater. Existing bow-family color grades and tier texture
  suffixes are carried onto the stages. Release and every cancellation path
  restore the concrete equipped bow image. Ten visible charge states plus the
  lifecycle reset retain the previous maximum of eleven stack writes per draw;
  there is no new player scan or globalstep.
- Vendored `player_api` exposes one callback registry inside its existing
  connected-player animation scan. Active Loose selects `stand`/`walk`, so
  third-person observers no longer see the generic melee `mine`/`walk_mine`
  pose. The original selector remains unchanged for every other action.
- Sprint now applies `speed = 0.50` for 10 seconds and publishes “50% faster”;
  cooldown and cost remain unchanged. The Scout starter KAT now requires 200
  arrows, matching the separately owned inventory/gear correction.
- Media ledgers distinguish the arrow OBJ's default CC BY-SA 3.0 license from
  the Pixel Perfection arrow texture and draw sprites under CC BY-SA 4.0. The
  OBJ is rigid projectile geometry, not an animated creature: it has no
  skeleton or locomotion clips and its whole-object orientation follows
  velocity at runtime.

## Tests and limits

- `luajit tools/r11_followup/arrow_visual_kat.lua .`:
  `r11_arrow_visual PASS mesh=arrow orientation=launch+gravity actor=stand+walk`.
  Uses the pinned Luanti `dir_to_yaw` formula and checks the Scout reflection.
- `luajit tools/wp39/projectile_test.lua .`: `projectile_test: ok`.
- Actual consumer/dispatcher invocation:
  `luajit -e 'local f=dofile("tools/wp11/talent_tree_kat.lua"); local ok,out=f("."); if ok == false then io.stderr:write(out); os.exit(1) end; io.write(ok)'`
  ended `wp11_talents_result PASS 0`. It covers all 16 Scout talent consumers,
  draw start/full stage/release restoration, animation override lifecycle,
  projectile/ammo transactions, Sprint +50%, and the 200-arrow starter.
- `tools/bin/luac51 -p` passed for every changed Lua source and fixture. This
  is parser/static use only; no PUC runtime was run.
- SETGLOBAL inspection: one declared mod global in `player_api/api.lua`, one
  in `grug_projectiles/init.lua`, none in `scout.lua` or the talent KAT; the
  focused standalone visual fixture intentionally installs its six engine/mod
  stub globals.
- All five repository Lua sweeps ran. Reported matches were existing comments,
  strings and the frozen WP40 manifest; no prohibited changed-code construct.
- `git diff --check` passed. No GUI/client render was run. The user playtest
  must confirm pixel scale, point direction and the three in-hand stage colors.
  The first local LMB camera gesture remains for the engine reason above.

## Owned files and SHA-256

See `../../tools/r11_followup/evidence/bow-inputs.sha256` for the complete frozen list. It covers:

- `VENDOR.md`
- `mods/BASE/player_api/api.lua`
- `mods/ENTITIES/grug_projectiles/{init.lua,LICENSE-media.md,models/grug_projectiles_arrow.obj,textures/grug_projectiles_arrow.png}`
- `mods/PLAYER/grug_abilities/{mod.conf,scout.lua,LICENSE-media.md,textures/grug_abilities_bow_draw_{0,1,2}.png}`
- `tools/r11_followup/arrow_visual_kat.lua`
- `tools/wp11/talent_tree_kat.lua`

No commit, sync, push or main merge was performed.

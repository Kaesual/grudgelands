# Round 20 F1/F2 implementation receipt

Status: implemented on `wp20-ux`; independent review and final runtime evidence pending.
Implementer: GPT-6 Astra (native thread reused by coordinator due slot availability).
Reviewer: pending. Critical/High findings, fix rounds and elapsed time: pending/unknown.

## Changes

- Player suffocation requires ordinary opaque full-cube drawing plus regular
  collision/node boxes. Missing fields follow Luanti defaults. Doors, panes,
  shutters, stairs, transparent cubes, liquids, stasis and noclip are excluded;
  full stone and the existing damage rate remain effective. The explicit
  `disable_suffocation=1` node group opts out.
- Native minimap player markers are enabled for both factions. Entity initial
  properties remain suppressed; native client minimap enable/toggle stays intact.
- Party views expose live levels, and each persistent party stores only its own
  members' last known levels. Acceptance, level changes, join and leave maintain
  that snapshot; removal deletes the member's snapshot. UI/HUD, invitations and
  online candidates show `[Lv X]`. Level changes refresh open Group pages.
  `grug_xp` is an explicit dependency. No historical-format reader is added.
- The profession book initially focuses its existing Search button instead of
  the search edit field. Group initially focuses Invite. Both are nonforced,
  preserving user focus across updates and normal typing after a click.

## Source findings and limits

The local reference `reference_projects/VoxeLibre/mods/PLAYER/mcl_playerplus/init.lua:566`
checks regular boxes, opaque classification and an opt-out. Grudgelands does
not share its opaque group, so normal drawing and non-propagated sunlight
classify the cube instead. Engine defaults are in
`reference_projects/luanti/builtin/game/item.lua:672`.
The existing vendored NPC path already checks regular geometry and the opt-out
(`mods/ENTITIES/mobs/api.lua:1179`); no NPC health change is justified here.
The NPC-before-door interaction change belongs to F5.

Luanti initially prefers editboxes, then tables, then buttons
(`reference_projects/luanti/src/gui/guiFormSpecMenu.cpp:165`). Its inventory
close action respects `keymap_inventory` (`:4481`), but a focused editing/native
widget may consume the key first. Server Lua cannot universally override this
without losing typing. Escape remains the reliable close action while typing.
No literal `i`, server key hook, engine modification or forced recurring focus
is introduced. Tabheaders are not supported focus targets (`doc/lua_api.md:3733`),
so shared navigation focus was rejected during inspection; inventory files are
unchanged. Unnamed read-only textareas need no speculative replacement.

## Verification

Executed: plain-5.1 parsing for six changed production Lua files and the new
fixture; SETGLOBAL inspection (only the existing `grug_parties` assignment);
five source sweeps including the new tools fixture; `git diff --check`. Clean.
No runtime interpreter, engine, synchronization or historical suite was run.

Prepared `tools/r20_ux/micro.lua`: a final-only callable fixture returning a
canonical receipt, exercising cube/door/pane/liquid/privilege classification,
player/entity minimap policy, live invitation/member levels and same-version
party restart with offline levels. Root consolidates this with existing UI/HUD
fixtures and the single final PUC/LuaJIT pair. Existing fixtures mocking parties
must now supply `grug_xp.get_level` and `register_on_level_change`; saved party
fixtures must use current `levels` maps. Those are current-format fixtures,
not an old-world migration requirement.

GUI acceptance: stand in full stone versus doors/panes/shutters; inspect native
minimap with friendly/enemy players and ordinary mobs; invite/join/level up and
reconnect party members; inspect all level labels; open the profession book,
close with the configured inventory key, then click search and verify normal
typing and Escape. Check narrow-window/long-name HUD layout visually.

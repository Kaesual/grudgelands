# Round 15 atlas work

Status: provider/rendering implementation in progress; live lifecycle paused for
user ruling, no delivery claim. Implementer: root Astra, independent reviewer
pending. Base `6908d1d5`.

## Implemented independent portion

- Sixteen directional arrow sprites per colour, original polygon art. Gold viewer
  drawn last, cyan online party members; names remain in tooltips/details to
  avoid unreadable overlapping text at world scale.
- Marker keys encode full provider identity into a stable field name; index
  changes cannot make a queued click refer to another NPC/player.
- Quest positions come from authored socket registry, with no emerge requests
  or live-entity scans. Nearby givers in the same settlement share one marker
  showing the highest-priority state; tooltip lists every relevant giver.
- The world and region views use the same projection and clipping.

## Engine boundary requiring a ruling

`reference_projects/luanti/src/client/game_formspec.cpp:314` opens the inventory
on the client. Its on_inventory_open hook at line 339 is client-script-only,
not a server callback. The server receives tab actions and quit fields but
receives no later reopen event. `doc/lua_api.md:9234` confirms that changing
the inventory formspec updates it live if open and otherwise changes the next
open's form. Thus page selection is not proof that the inventory is open.

Asked user: reset from Map to Character when closing (recommended), or retain
Map with throttled selected-page polling even while closed. Do not silently
implement an event approximation or introduce client mods.

## Bounded evidence so far

`luajit tools/r15_map/kat.lua <repo>` passes provider identity, heading,
online/offline, per-view quest-priority and region clipping cases. No PUC
runtime yet. `tools/r15_final/static.py` passed six changed/new Lua files;
only global write is the owning `grug_map` table; all five sweeps had no hits.
Final evidence must replace this intermediate checkpoint after lifecycle and
integration are complete.

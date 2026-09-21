# Round 15 atlas work

Status: delivered in Round 15. Implementer: root Astra; independent Astra
provider review and Sol final lifecycle review clean. Base `6908d1d5`.

## Provider/rendering implementation

- Sixteen directional arrow sprites per colour, original polygon art. Gold viewer
  drawn last, cyan online party members; names remain in tooltips/details to
  avoid unreadable overlapping text at world scale.
- Marker keys encode full provider identity into a stable field name; index
  changes cannot make a queued click refer to another NPC/player.
- Quest positions come from authored socket registry, with no emerge requests
  or live-entity scans. Nearby givers in the same settlement share one marker
  showing the highest-priority state; tooltip lists every relevant giver.
- The world and region views use the same projection and clipping.

## Engine boundary and accepted ruling

`reference_projects/luanti/src/client/game_formspec.cpp:314` opens the inventory
on the client. Its on_inventory_open hook at line 339 is client-script-only,
not a server callback. The server receives tab actions and quit fields but
receives no later reopen event. `doc/lua_api.md:9234` confirms that changing
the inventory formspec updates it live if open and otherwise changes the next
open's form. Thus page selection is not proof that the inventory is open.

The user chose reset to Character on closing Map. Only explicit Map entry
starts a live session; no closed-map polling. Half-second refreshes compare the
whole form before writing, preserve stable identity and clear selected detail
when its marker leaves the view. Tab leave, disconnect and death clean up.

## Initial bounded checkpoint (historical)

`luajit tools/r15_map/kat.lua <repo>` passes provider identity, heading,
online/offline, per-view quest-priority and region clipping cases. No PUC
runtime yet. `tools/r15_final/static.py` passed six changed/new Lua files;
only global write is the owning `grug_map` table; all five sweeps had no hits.
The final evidence supersedes this intermediate checkpoint: all 17 round Lua
files pass statics, the four-fixture final PUC/LuaJIT digest matches, and actual
native initialization validates all quest sockets. See round15-completion.md
and round15-map-review.md. GUI pointer/refresh behavior remains a user gate.

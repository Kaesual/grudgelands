# Round 17 HOME implementation

Status: implemented on `wp17-home`; independent review and integrated final
interpreter parity are coordinator gates. Author: native Astra; no delegated
workers or CLI agents. Elapsed author time: unknown. Author self-check is not
independent approval. No GUI or personal-world test was run.

## Authority and placement

`mods/PLAYER/grug_home/locations.lua` is the single twelve-ID catalog. It selects
existing inhabited door sockets. The core registry reserves each selected
socket as `innkeeper` before mods-loaded placement; the existing resident is
replaced, not duplicated. Existing villager entities remain peaceful,
noncombatant and stationary, reuse persistent socket claims, and dispatch only
the authenticated HOME dialog. They carry `_grug_socket_role = "innkeeper"`.

| ID | Existing building |
| --- | --- |
| hearthpine | West home |
| dawnmere | Harvest Inn |
| silverleaf | West glade house |
| stillgrave | Warden house |
| sunscar | Tusk lodge |
| kapok | Spirit lodge |
| dur_brannoc | Terrace alehouse |
| highcourt | Homes tavern |
| lethariel | Homes longhouse |
| nhal_veyr | Homes lane house |
| gor_drazhak | Warren clan house |
| kezamba | Vine longhouse |

Dawnmere's cottage-door resident moves to the existing Harvest Inn doorstep;
Silverleaf's shrine-door resident moves to the existing west glade house.
Only their socket metadata changes. A direct original/current comparison
confirmed all 66,361 Dawnmere cells and 71,495 Silverleaf cells unchanged.
No manifest content projection, planner column tuple, terrain rule or building
changes. The other ten home sockets keep their authored positions.

The registry exposes copies of the fitted NPC position and the fixed arrival
position: one node east of that socket, with feet 0.51 above its ground course.
Capital plot IDs retain the actual `plot/socket` identity and use the existing
reference-column height projector, not the capital core height. Arrival checks
require a loaded, non-damaging full ground block and two non-liquid,
non-damaging passable cells. Blocked arrivals fail rather than inventing a new
position. The source audit proves the canonical position is clear for all
12 actual authored compositions/selected plots.

## Persistence and lifecycle

- `grug_home:id` stores the bound stable ID. An unset choice resolves to the
  racial start; enemy or unknown IDs cannot become a destination.
- `grug_home:ready_at` stores an absolute `os.time()` deadline as a string.
  The 1,800-second return cooldown elapses offline, survives module/server
  reload, is charged only after `set_pos` is observed at the destination,
  and is never reset by binding or death.
- Each request owns an in-memory session token and one pending slot. Emerge
  completion defers into the normal step and rechecks session, pending identity,
  current home, faction/race, life, combat and cooldown. Death, leave, new join
  or binding invalidates the token. Duplicate and delayed callbacks are inert.
  A 30-second timeout releases an abandoned request without charging it.
- Teleport dismounts, invalidates the shared combat identity immediately before
  `set_pos`, then clears velocity. Existing faction spawn teleports also
  invalidate combat identity. Character-creation's direct selection teleport is
  owned by COMBAT, not this lane.
- Respawn first loads the small already-generated racial-start pocket from
  disk, validates its fixed safe position and moves the revived player there.
  It then prepares the bound home, independently of combat and return cooldown.
  An emerge failure leaves the player at that safe start instead of the death
  location. If the racial fallback cannot be validated, the existing faction
  fallback owns the respawn; no HOME request is left pending. Incomplete
  character creation retains its existing stasis/faction path.

`reference_projects/luanti/src/server/player_sao.cpp:553` restores HP before
calling respawn callbacks; `src/script/cpp_api/s_player.cpp:104` combines their
results with OR. `doc/lua_api.md:7159` documents `load_area` as disk loading
without generation. `src/script/lua_api/l_object.cpp:154` returns no success
value for `set_pos`; the runtime therefore verifies the resulting position.
`src/server/player_sao.cpp:357` ignores position changes while attached, which
is why dismount precedes teleport and a failed move cannot charge cooldown.

## UI and files

The Map page adds a destination/cooldown button and labeled `I` innkeeper / `H`
current-home markers from the same registry. Its existing active-page refresh
updates the countdown; no additional globalstep or mapblock scan is added.
The innkeeper form binds a unique server-side dialog to the actual live entity,
its authenticated socket, faction, and current player/NPC distances. Submission
reauthenticates all of them.

Production changes: new `grug_home` mod; core `settlement_sockets.lua` reservation
seam; mob `start_npcs.lua` and `start_villagers.lua`; two start blueprint socket
rows; faction respawn/spawn hooks; map dependency, page, marker layering and provider.
No setting is added. Root owns living specs and project status documents.

## Verification and remaining acceptance

LuaJIT development checks PASS:

- `tools/round17/home_sources.lua`: all 12 real source sockets, fixed canonical
  floor/headroom, faction/race identity, selected descriptor and production
  terrain-relative socket projection. Six starts and six selected capital
  plots only; no capital/world-generation suite.
- `tools/round17/home_micro.lua`: production registry/HOME/factions/atlas/page;
  default home, authenticated binding/enemy/stale/proximity refusal, combat,
  cooldown persistence, failed/blocked emergence, duplicate and stale callbacks,
  death/reconnect/binding changes, timeout, failed respawn safety and map output.
- Extended `tools/wp13/start_npcs_kat.lua`: real placement/claim/title/static
  behavior and right-click dispatch for the innkeeper role, alongside existing
  bounded NPC regressions.
- Plain `luac51 -p`, SETGLOBAL inspection and all five documented sweeps;
  only the expected `grug_home` and existing `grug_factions` mod globals in
  this lane. Existing whole-repo comment/string matches remain non-executable.
- `tools/check_fresh_server.py`: PASS.

`tools/round17/home_final.lua` returns the combined portable report and is ready
for exactly one inclusion in root's frozen integrated PUC/LuaJIT parity pair.
No PUC runtime was run in this lane. Native GUI validation remains user-run:
visit friendly/enemy innkeepers, bind a capital, return via Map, reconnect and
check the countdown, then die and confirm bound-home respawn without cooldown
change. Inspect all twelve innkeepers and the Map's labels/layout in-game.

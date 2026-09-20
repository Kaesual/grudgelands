# Round 11 playtest follow-up: capital trainers and Leatherworker sign

Implementer: native Sol
Baseline: `28b118c4` on root branch `wp11-playtest-followups`
State: source freeze, uncommitted by instruction

## Cause

All eight profession trainer sockets were already authored in every capital, and the Cooking and Woodcarver resolvers/entities were registered. The missing NPCs were caused by the shared capital placement retry gate.

The first visit to a capital authenticates it by loading its core anchor. Outer service houses load later as the player walks toward them. `serve()` nevertheless re-ran `settlement_ready()` on every heartbeat, which required the core anchor mapblock to remain loaded at the same time as each outer shop mapblock. Once the player moved far enough for the core to unload, pending Cooking/Woodcarver trainer sockets could remain empty even while their own houses were loaded.

`start_npcs.lua` now latches a capital as ready after either its anchor or one of its authored socket blocks is loaded. Existing persisted socket markers also restore that latch after restart. This covers walking outward from the core, resuming an already-served world beside an outer shop, and a direct first arrival in an outer district. `nil`/`ignore` blocks remain ineligible and the per-socket loaded-node gate remains unchanged, so no NPC is placed until its own mapblock is loaded.

The correction is in the one shared placement path used by Highcourt, Dur Brannoc, Lethariel, Nhal Veyr, Gor Drazhak and Kezamba.

## Leatherworker presentation

Every capital's Leatherworker exterior frame now uses a protected fixed plaque that combines the existing leather chest icon with the existing raw light-leather icon. The interior armor plaque remains unchanged. The new plaque inherits the existing no-dig, no-drop, no-inventory, no-punch/right-click and blast-safe display contract.

## Focused verification

- Actual `start_npcs.lua` placement fixture passes. New cases prove an unloaded outer Cooking trainer remains pending, then spawns after its shop loads while the authenticated core is unloaded; a restart with an existing capital socket marker restores readiness; and a direct first arrival at the outer district authenticates from the loaded authored socket block without the core.
- Actual six-capital service-plot fixture passes: 48 real service plots and all 48 profession trainer sockets, including Cooking and Woodcarver in every capital. Each Leatherworker plot has exactly one ordinary interior armor plaque and one exterior combined material/armor plaque. All nine plaque definitions satisfy the protected-display contract.
- All six changed Lua files pass `tools/bin/luac51 -p`; production bytecode contains no `SETGLOBAL`. The targeted prohibited-syntax/API scan found only the pre-existing tool-host `io.open` in `start_npcs_kat.lua`. `git diff --check` passes.
- No PUC runtime, broad mapgen/performance suite, seed fleet, headless server or user-world mutation was run.

Focused LuaJIT receipts:

```text
capital_pending anchor_latched outer_trainer_placed
capital_restart marker_restored_readiness outer_trainer_placed
capital_direct_outer socket_block_authenticated outer_trainer_placed
R11 CAP PASS: 48 real service plots, 48 profession trainer sockets, 6 open shelters, 24 mounts, 24 authored ground endpoints, 48 exterior product frames; 9 protected product definitions
```

Logs: `../../tools/r11_followup/evidence/trainers.log`,
`../../tools/r11_followup/evidence/capital-services.log`.

## Frozen files and hashes

```text
525e28200f4379c1c544d23cf6f40526b4017d8090f6ebc41a68b7f62be05bcd  mods/ENTITIES/grug_mobs/start_npcs.lua
fe969a9a08ed1312ddce825440a193cd46d75a780e4a367c5e8f5f2ae3aa8af4  mods/MAPGEN/grug_mapgen/wp13/capital_services.lua
8f35e005381ae0a7df5f2cbb0efe85b8403017a0282b14657f9d0131b58d5f84  mods/ITEMS/grug_decor/capital.lua
e76ad454dd7c18b47ec29436c5da79681c77f9243de431e40aa62e1d1c7c47c7  mods/MAPGEN/grug_mapgen/wp13/parts.lua
62e12dbcb8e3d46a217405bf034a342fb56aed35c33099b531358a89cbb1b7e8  tools/r11_world/capital_fixture.lua
7b4383da5e1af8b3e2c198892a5f365a09e2b9fbea12289260c797500e67cfd7  tools/wp13/start_npcs_kat.lua
```

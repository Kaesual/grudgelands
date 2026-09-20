# Round 10 gameplay implementation record

Date: 2026-09-20. Candidate branch: `wp23-r10-gameplay`. This record covers
only the GAME lane; capital trainer placement, profession/equipment work,
terrain work and final mount icons belong to their separate Round-10 packages.

## Implemented behavior

- Apprentice Riding moves at 6.4 nodes/s (+60%). Mounting installs a
  modifier-free runtime status line such as `T1 Mount, +60% Speed`; the shared
  dismount path clears it.
- A neutral-scale transparent physical controller owns movement, collision and
  punch forwarding. The visible mesh is a non-physical child of the rider with
  `force_visible = false`, using Luanti's local first-person child hiding while
  preserving third-person and remote views. Land controllers use step height
  1.01; flight movement is unchanged.
- Mounted native tool/fist PvP packets return before swing claims, clocks,
  accumulation, target refresh, rage or damage.
- Native fall damage `r` becomes `ceil(max_hp * r / 20)`. Dwarf reduction
  applies next with ceiling rounding, then absorb. Armor and dodge remain out
  of the fall path.
- mobs_redo's existing quarter-second forward cliff probe uses a two-node ray
  for ambient stand/walk state, permitting at most a one-node descent without
  adding a scan. Combat, flee, flight and scripted movement retain their own
  contracts.
- Idle dragons walk between authored rest positions. Horizontal obstruction or
  a cliff stops the route and restarts the selection cadence; idle relocation
  never teleports. Wind-ups and target-only effects validate a living hostile
  target, including the `peaceful_player` privilege, and target loss cancels an
  active action. Scorch damage refreshes combat state.
- The weak vendor healing potion applies the equipped Apothecary Loop instant-
  potion modifier exactly once, then preserves the existing nearest-integer
  rounding and shared cooldown.

The first-person mechanism follows the engine attachment visibility path in
`reference_projects/luanti/src/client/content_cao.cpp` and uses the fifth
`ObjectRef:set_attach` `force_visible` argument documented in
`reference_projects/luanti/doc/lua_api.md`. Visual placement still requires the
GUI test below because Lua fixtures cannot render a client camera.

## Verification

The frozen candidate must retain these checks:

- plain Lua 5.1 parse of every `mods/*/grug_*` Lua file and all changed tools;
- changed-mod `SETGLOBAL` inspection (the existing `grug_abilities` module-table
  declaration is the only changed-file write) and all five repository Lua
  conformance sweeps; hits are existing comments or frozen manifest text;
- LuaJIT real-code fixtures: `tools/r9_mounts/mounts_kat.lua`,
  `tools/r8_mob1/bosses_kat.lua`, `tools/r6_food_buffs/kat.lua`,
  `tools/wp39/combat_integration_test.lua`, and
  `tools/r10_gameplay/potion_kat.lua`;
- one final compact PUC-5.1/LuaJIT digest pair after review freezes the bytes.

The final compact pair produced byte-identical output with SHA-256
`55469b34055a8eb2e65c169edff61e42bfe956eb5977a62ae43ff0dd61133900`.
The complete mount fixture remains a LuaJIT development check because its B3D
asset audit is deliberately outside the compact fallback-runtime boundary.

GUI acceptance on a fresh world: ride T1 and T2 land mounts over slabs and one
full block without jump, confirm a two-block wall and low ceiling block them,
and switch first/third person while another player observes. Confirm the status
line and every dismount cleanup. Check ordinary mounted PvP does nothing. Fall
at the same native severities on low/high-level and Dwarf/non-Dwarf characters,
including absorb. Observe ordinary idle mobs at ravines. Watch a peaceful
player near both dragons through several rest cycles, then fight and break a
rest route with terrain. Drink the weak vendor potion with and without an
Apothecary Loop and verify the shared cooldown.

## Calibration and review state

- Implementing model: GPT-5.6 Sol, native agent.
- Independent reviewing model: pending coordinator assignment; must be native
  and independent under the active Round-10 provider rule.
- Critical/High findings: pending review.
- Review-fix rounds: pending review.
- Implementation elapsed time: not measured.

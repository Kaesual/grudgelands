# Round 20 F5 input implementation

Status: active, partial implementation only; final review/runtime evidence pending.
Implementer: GPT-6 Astra. Independent reviewer: pending. Calibration: unknown.

## First independent corrections

Friendly support now resolves the current server combat ray: a visible eligible
ally within range, otherwise the caster. No client reference or remembered ally
is aim authority. Renew still captures the selected recipient on activation.
The skill RMB fallback now raycasts actors and nodes together by physical
intersection distance. A hidden-from-client actor in front of a door receives
its actual entity right-click callback; nodes behind it are not activated.
Ordinary object clicks remain engine-dispatched, avoiding duplicate callbacks.

Source authority: `docs/planning/round20-input-contract-proposal.md`;
`mods/CORE/grug_core/combat_ray.lua`; local engine `src/client/game.cpp:2786`
(native usable-item branch), `:3269` (hand digging fallback), builtin
`game/item.lua:489` (actual node-dig protection/drop/wear path).

## Native digging feasibility

Native digging requires removing cast-item `on_use` and no-dig pointabilities.
A bounded server input scheduler must replace the swing-only dispatcher.
Native dig presentation can start before the approximately 200 ms arbitration;
root accepted this presentation limitation, provided no node is removed early.
Any native-dig guard must delegate exactly once to the actual registered
`on_dig`, preserve materials/profession/farming behavior, enforce hand reach
and actor/RMB eligibility, and never consume skill cooldown wear. No fake
PlayerRef, wield-slot swap or second digging engine is authorized.
This part remains under source investigation; it is not yet delivered.

## Checks and acceptance

First corrections: plain-5.1 parser, SETGLOBAL and five source sweeps; runtime
execution deferred to the round's single final pair. Prepared
`tools/r20_input/friendly_micro.lua` loads the real kit definitions and checks
current-ally, stale-client, memory, obstructed/out-of-range and invalid-ally
outcomes. Final input/interaction fixtures remain to be consolidated.

GUI acceptance later: heal one ally, aim away and heal self; aim at another
ally and verify new support stays on that recipient; right-click an NPC before
a door and confirm only the NPC interaction opens. Full click/hold and native
digging acceptance remains pending implementation.

# Round 14 QUEST/PARTY core independent review

Reviewed 2026-09-21 by native GPT-6 Astra, independently of the native GPT-6
Astra authors. Read-only production review; only this report was written.

## Verdict

PASS for the bounded core candidate: no confirmed Critical, High or Medium
defect. This is not Round 14 delivery approval. Final integrated static gates,
native boot/content validation, final-byte PUC/LuaJIT parity and user GUI/runtime
checks remain pending coordinator gates. The intentionally empty production
quest catalog and UI files being integrated concurrently are not defects in
this core review.

Scope: `grug_quests/{registry,state,npc}.lua`, both original marker meshes,
`grug_parties/init.lua` through its core globalstep, and the changes from
`20f21795` in `grug_core/tag_carrier.lua`, `grug_mobs/init.lua` and
`grug_mobs/start_villagers.lua`. Party UI/HUD loader appends and dependency edits
are excluded. Governing documents: AGENTS, workflow review checklist, model
policy, Lua 5.1 strategy, quests/parties design, and both lane work records.

## Checks and evidence

- Quest settlement checks current requirements, eligibility, coin capacity and
  reward space together. Repeated item objectives share the preflight copies;
  removal can free reward space. Only main and installed owned-bag contents are
  touched. Writes compare snapshots, refused writes restore earlier slots, and
  the completed claim is saved before reward notifications. Reentrant turn-in
  is guarded. Both money and XP calls are attempted if one notification raises.
- The engine actually returns boolean success from `InvRef:set_stack`:
  `reference_projects/luanti/src/script/lua_api/l_inventory.cpp:175-192`.
  Inventory-change reporting at lines 31-35 marks the inventory modified; it
  does not execute a player inventory action callback between slot writes.
  Existing reward owners persist before notification
  (`grug_money/init.lua:98`, `grug_xp/init.lua:62`). No crash-spanning transaction
  or protection against arbitrary broken third-party callbacks is claimed.
- Shared kill notifications use exactly the already-built online/40-node XP
  eligible set before participant cleanup, including gray kills. The original
  XP denominator/rounding stays unchanged. Quest filtering independently rejects
  friendly faction targets and enforces objective/zone and prerequisite rules.
- NPC forms retain server-side entity/selection state, repeat validity/socket
  identity and six-node reach checks, and dispatch only the stored quest whose
  giver/turn-in socket matches. A client cannot supply an arbitrary quest id.
  Registry startup checks item/entity/NPC references and prerequisite cycles.
- Markers activate with empty observers and consume the existing tag loop's
  25/30-node membership every one-second tick, even when membership is unchanged.
  They do not add player scans. Observer partitions implement the specified
  precedence; carrier removal/invalid parent cleanup removes children. Attachment
  observer intersection agrees with the actual engine contract at
  `reference_projects/luanti/doc/lua_api.md:9002-9024`. Meshes are original
  extruded symbols, not imported unanimated creature models.
- Parties persist one canonical group record and derive membership lookup.
  Disconnect changes presence and invitations, never membership/leadership.
  Removal elects the earliest remaining member even when offline; one survivor
  dissolves. Acceptance repeats online/faction/authority/preference/capacity
  checks without yielding. A/B/C invitations survive group dissolution as
  specified. Mutation observers run after state persistence, and invitation
  recipients receive changed inviter-context notifications. Pending queues are
  capped at ten; only the required one-second sender rate applies. The sweep
  is throttled and does not scan persistent offline parties.

Inspected the three QUEST fixtures and PARTY's 90-check development fixture,
static log and SHA256 manifest. Did not rerun PUC, native boot or long suites.
The party fixture/static/log files match their accepted hashes. Current party
`init.lua` differs only by the concurrent UI loader suffix: removing the suffix
beginning `local path = core.get_modpath` reproduces the recorded core SHA256
`559ceac630761205cc97a441c3531f47c8119859f4d974768ec801f4727fcd73`.
The changed `mod.conf` is expected UI integration drift, not certified by the
earlier manifest. Regenerate final evidence after integration.

The staged STORY catalog was spot-checked only: six culture chains with nine
main quests and two optional crafting hand-ins each, ordinary raw meat and
Wood/Stone tools, race/faction restrictions and no Nether objectives. Full
local spawn/material availability and final socket validation belong to the
separate STORY/POI integration review, not this verdict.

## Reviewed core hashes

SHA256, paths relative to the repository root:

```text
f4ae75c7c52491a49ae48c723ec9ef0c162c2b6777d970f52f66be4a2b531ad5  mods/PLAYER/grug_quests/registry.lua
f52a51dafd9969c52355a47f252abb1e71465782d923a347559b7e76925c384f  mods/PLAYER/grug_quests/state.lua
ffa9eb772fbd582892f010538c02b3e411f4bdecd1ef6acba3d5c482012e6455  mods/PLAYER/grug_quests/npc.lua
15975e5e105fdaf225606f6cf8736007c92f11a17fd858c81cba857b7e76615f  mods/CORE/grug_core/tag_carrier.lua
577265c1dae133a3b07b4b1c23efe63019e47eeefe9921a2fd04b152318586ff  mods/ENTITIES/grug_mobs/init.lua
fc25e9d4325f4ade15d0a307df486768583ea466e848484d9cfa33aeaa5a51f2  mods/ENTITIES/grug_mobs/start_villagers.lua
55c52015341b0ec45a1b3343d5cd00a33ff7f14e8cb2e0d5263129b3e6cf8322  mods/PLAYER/grug_quests/models/grug_quests_exclamation.obj
e2cdd58eb20ce6d43f26f0afeeb0c061e396a0f878519fb4bd8ade39753939d6  mods/PLAYER/grug_quests/models/grug_quests_question.obj
```

## Calibration and runtime plan

Classification: non-trivial state/transaction/lifecycle change. Implementers:
GPT-6 Astra; independent reviewer: GPT-6 Astra. Findings: 0 Critical / 0 High /
0 Medium. Fix rounds: 0. Observed elapsed wall time: unknown.

User runtime: accept/abandon and reconnect with quests; turn in from bags with
full reward space and with insufficient space; verify repeated completion,
damage/heal/gray shared kills, and two viewers seeing different marker states
across 25/30 nodes. Move away from or unload an open NPC. With three same-faction
players, run A invites B/C, B joins/leaves, then C accepts; check offline HP,
restart with an offline leader, transfer leadership, and disable invitations.

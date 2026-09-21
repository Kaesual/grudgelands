# Round 14 QUEST-CORE working record

2026-09-21. Implementation candidate; independent review and integrated final
conformance are pending. No user worlds or installation paths were touched.

## Implemented boundary

- `grug_quests` registers socket-bound NPCs and one-time item/kill quests.
  Startup validates prerequisite cycles, references, registered items/mobs and
  exact quest sockets. STORY owns the final catalog and local-availability audit.
- Player metadata holds active counters, completed claims, up to three tracked
  quests and the saved HUD preference. The log limit is exactly 20.
- Item turn-ins preflight main plus installed owned bag contents, aggregate
  repeated requirements, and simulate rewards after removal. They compare exact
  snapshots, roll back earlier writes on refusal, persist the claim before
  publishing money/XP callbacks, and refuse duplicate completion. Equipment and
  foreign inventories are excluded. Currency capacity is preflighted.
- Existing money and XP owners remain authoritative. Each persists its ledger
  before notification; both reward calls are attempted before rethrowing any
  notification error. There is no mail, escrow or cross-crash transaction system.
- Shared kill credit uses the XP authority's exact online/40-node participant
  result (damage and effective healing), before cleanup, including gray kills.
  Friendly-faction kills do not advance objectives; party membership is unused.
- Journal snapshots and NPC status evaluation scan holdings once per evaluation;
  NPC lookup and quest candidates are indexed. No global inventory cache exists.
- Socket-bound dialogue revalidates entity identity and six-node reach before
  each action. UI strings use item descriptions and reward counts.
- Original extruded OBJ glyphs use yellow/silver flat textures and separate
  observer partitions. Activation starts with empty observers. Existing tag
  visibility supplies its one-second 25/30-node hysteresis membership, including
  unchanged membership ticks. Parent/carrier teardown removes marker children.
  No second player scan or HUD implementation was added.

## Public UI contract

`journal(player)` returns `{quests, tracked, hud_enabled}`. Each quest row has
`id`, `title`, `description`, `objectives`, `ready`, `npc` (turn-in NPC id), and
`rewards`. Objective rows have `type`, `item` or `mobs`, `count`, `required`, and
optional `description`. `tracked` is an ordered array of at most three ids.

Mutators: `accept(player,id)`, `abandon(player,id)`, `turn_in(player,id)`,
`set_tracked(player,id,boolean)`, `set_hud_enabled(player,boolean)`.
`register_on_change(callback)` receives the player after quest state changes.
UI consumers must additionally refresh live item readiness on inventory changes
or their bounded HUD refresh pass. `status(player,id)` returns a status and
optional explanation. `npc_quests(player,npc_id)` returns sorted relevant rows.

Registry schema: `register_npc(id,{settlement,socket,title})` and
`register_quest(id,{title,description,npc,turnin_npc?,faction?,race?,min_level?,
prerequisites?,objectives,rewards?})`. Objectives use `type='item',item,count`
or `type='kill',mob`/`mobs,count,zone?`; zone is a stable named-zone id, resolved
through `grug_zones.id_at`. Rewards contain `xp`, `copper`, `items` itemstrings.

## Evidence so far

LuaJIT development fixtures, all passing:

- `tools/r14_quests/core_kat.lua`: owned bag turn-in, live readiness, one-time
  rewards, full inventory refusal, abandoned counters, exact 20 slots, tracking,
  HUD persistence, player isolation, refused-write rollback, reentrant claim,
  prerequisite/level rejection and reconnect metadata.
- `tools/r14_quests/participation_kat.lua`: real `grug_mobs/init.lua` main chunk;
  exact 40-node inclusion, effective-heal exclusion at zero, gray-level credit,
  unchanged XP split, one event per eligible player before cleanup. Roster
  submodules are omitted in this bounded fixture.
- `tools/r14_quests/visibility_kat.lua`: real tag carrier and quest NPC module;
  empty initial observers, shared hysteresis, state refresh with unchanged
  observer membership, original mesh selection and child cleanup.
- Plain Lua 5.1 parser: 11 lane Lua files passed. Production SETGLOBAL: only
  `grug_quests` and existing `grug_mobs` module globals. All five sweeps passed;
  sweep 4's sole match was pre-existing tier-list prose in `grug_mobs/init.lua`.

Historical `tools/r5_progression/progression_kat.lua` was tried once and fails
before reaching mobs at `combat.lua:1165`: its ability target stub lacks `get_hp`.
It was not modified; new participation coverage above passes independently.

No PUC runtime was run here. Root owns one integrated final PUC/LuaJIT digest
pair after final catalog/UI/POI bytes freeze and independent review.

## Remaining integration gates

The empty `content.lua` is explicitly intermediate and must be replaced by
STORY's approved catalog once the new quest sockets exist. Run the native boot,
content locality audit and independent review. User runtime: accept/abandon,
reload/reconnect, shared damage/heal/gray kills, full-bag refusal, NPC range
rejection, marker color/shape/occlusion at 25/30 nodes and multi-viewer states.

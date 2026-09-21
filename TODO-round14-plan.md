# Round 14 plan — quests, parties and a world worth exploring

Planning checkpoint: 2026-09-21. **Implementation is not authorized yet.**
The user requested this detailed plan and one final discussion before a round Go.
The separate optional-fog documentation change is already delivered on main
(`791b9923`). No other Round 14 implementation has started.

This document preserves the user's decisions and distinguishes them from the
remaining recommendations. At approval, fold the decided rules into
`docs/design/`, update the affected WP contracts, move the execution plan into
`docs/research/round14-execution.md`, and delete this TODO once its questions close.
Do not leave competing permanent design authorities.

## 1. Outcome and scope

The next playtest should offer meaningful local tasks, recognizable quest hubs,
player coordination and geographical orientation. Existing combat, professions,
equipment, farming and resources remain the foundation.

Proposed delivery scope, awaiting final round approval:

- WP8: a persistent quest framework, NPC offers, a Quest tab and optional HUD.
- Early WP9 content: six culturally distinct starter chains, approximately 8–12
  quests each, plus a short transition into each level-11–20 home region.
- A bounded WP13 increment: six level-11–20 villages and one existing outpost
  and bandit-camp anchor per corresponding home region, with quest-relevant
  inhabitants and dressing. This is not the complete 100-anchor POI roster.
- WP20 revised: persistent same-faction parties, management UI and health HUD;
  no party-based XP, quest-credit, loot, combat-scaling or tap-ownership rules.
- A first WP12 Map tab, with the rendering choice still pending in section 8.
  It does not require implementing WP17 travel or Housing first.
- Optional full-world startup generation and a unified resumable preparation
  path for full-world and starts-only modes.
- The reported profession-isolation defect, corrected flight policy and an
  interactive fishing pass.
- Independent reviews, documentation reconciliation and a short user playtest
  checklist. The coordinator owns integration throughout.

Full level-1–60 main stories, war-front encounters, Housing, boats, fast travel,
economy rebasing, raid systems and a general engine/mapgen rewrite stay outside
this round. Whole-WP completion is recorded only where the complete revised
contract is delivered; content slices do not silently close larger WPs.

## 2. Authority and evidence to read before delegation

- `AGENTS.md`, `docs/process/agent-model-policy.md`,
  `docs/process/wp-workflow.md`, `docs/research/luanti-lua.md`.
- `BACKLOG.md`: WP8, WP9, WP12, WP13, WP20 and their dependencies.
- `docs/design/story.md`, `progression.md`, `world_zones.md`, `settlements.md`,
  `world.md`, `mounts.md`, `economy.md`, `classes.md`, `combat_stats.md`.
- `docs/research/wp13-capitals-pois-contract.md` and
  `docs/research/wp13-npc-sockets-contract.md`: reuse authored anchors/sockets;
  consult current living design where historical briefs differ.
- `mods/CORE/grug_core/tag_carrier.lua`: one-second shared player snapshot,
  show below 25 nodes / retain through 30 nodes, managed observer sets.
- `mods/ENTITIES/grug_mobs/init.lua`: `mark_xp_participant`, effective-heal
  propagation and `award_kill_xp`. Damage/healing participation already exists;
  online participants within 40 nodes at death share XP under current rules.
- `mods/PLAYER/grug_jobs/state.lua` and `trainers.lua`: profession records and
  trainer sessions are already keyed to the player. The reported failure is
  real user evidence, but its cause has not yet been reproduced.
- `mods/PLAYER/grug_mounts/entity.lua:119`: current `flight_state` accepts own
  home and `holy_grounds`, incorrectly excluding ordinary contested land under
  the user's revised explicit policy.
- `mods/CORE/grug_core/starts_preload.lua`: current coarse start requests,
  completion marker and deferred enqueue seam; replace scheduling coherently.
- `reference_projects/luanti/src/server.cpp:363`: emerge threads stop before
  Lua shutdown hooks, then the map and mod storage are saved during teardown.
  `src/emerge.cpp:256` stops/joins workers; the worker checks stop requests
  between work units. `on_shutdown` alone is not an early cancellation hook.
- `reference_projects/luanti/doc/lua_api.md:7163`: `emerge_area` callbacks are
  per mapblock, not per mapchunk; CANCELLED is not proof of successful work.
- `reference_projects/luanti/src/client/client.cpp:690` and
  `src/client/minimap.cpp:22,75,107`: native minimap data comes from client-side
  block/mesh data and a memory cache; this is not a saved world-map image API.
- `reference_projects/VoxeLibre/mods/ITEMS/mcl_maps/init.lua`: an example of
  server-side PNG generation, world-directory storage and dynamic media delivery.
- `reference_projects/VoxeLibre/mods/ITEMS/mcl_fishing/init.lua`: reference for
  visible bobber/bite/reel behavior, subject to media/code license checks.

Pinned references remain read-only. All agents must read their owning design
sections before proposing code; no replacement game systems invented locally.

## 3. Quests — confirmed rules and proposed bounded semantics

### Confirmed by the user

- Exactly 20 active quests maximum; accepting beyond that is refused with a
  clear explanation. Completion or abandonment frees a slot.
- A dedicated Quest inventory tab supports viewing and abandoning quests.
- A quest HUD toggle lives in this tab, defaults on and is saved per player.
  No active quests means no quest HUD, without changing the saved preference.
- Objective families are **item turn-in** and **kill**. A crafting lesson can
  request the resulting item. No separate crafting, mining, visit or escort
  objective engine is required for V1.
- Kill credit uses the same per-mob damage/effective-healing participation and
  eligibility mechanism as shared XP, never a killing-blow test and never
  party membership. Players from different parties are not a special case.
- Quest-giver markers are attached visible symbols with `set_observers()`.
  Use the existing tag visibility/hysteresis loop and distances, not a second
  independent all-players scan.
- Marker precedence: ready to turn in (yellow question mark), available
  (yellow exclamation mark), active but incomplete (silver question mark),
  relevant prerequisite-locked quest (silver exclamation mark), otherwise none.
- Quest chains use existing faction story and zone identities. No cross-faction
  cooperative questline is introduced.

### Recommended defaults for approval

- Track up to three selected quests on the HUD. Keep the tab authoritative;
  do not place the entire journal permanently on screen.
- Item turn-ins accept already-owned and traded/crafted-by-others items.
  Descriptions say “Bring ...” instead of claiming to verify personal crafting.
  V1 requirements match registered item id and count only, with no wear,
  enchantment, quality or provenance predicates. Author hand-ins around ordinary
  resources and basic Wood/Stone tools; do not request valuable enchanted gear.
- Count and consume from main inventory and the player's owned bag contents
  through existing inventory APIs; do not reach into equipment, stations,
  chests or another player's inventory. Recheck at turn-in, not only in the UI.
- Kill counters start at acceptance; item readiness reflects current holdings.
  Sharing credit does not divide quest counters: one eligible kill is one
  count for each relevant active quest. XP splitting itself stays unchanged.
- Do not use `xp > 0` as the sole participation test: gray-level XP suppression
  must not accidentally hide the shared eligible participant event from quests.
  Quest min-level/prerequisite/faction and target rules remain independent.
- Abandoning a quest removes its counters, not ordinary player items. It may be
  accepted again if prerequisites still hold. Completed one-time quests remain
  completed and do not consume active-log slots.
- One-time XP/coin/item rewards, with all prerequisites, consumed items and
  reward space preflighted together; insufficient space refuses the turn-in
  without consumption or a dropped reward. Avoid adding mail/escrow systems.
- Repeated packets and repeated dialogue clicks must not duplicate rewards.
  Persist active/completed state and HUD preference across reconnect/restart.
- Locked markers only expose the next relevant chain step, not all distant
  future quests. NPCs with multiple quests offer a simple list.
- Explain optional crafting through a side branch; do not force every player
  to craft as a prerequisite for the local combat story.
- Opening kill lessons use common mobs and small counts (e.g. five boars).
  Avoid five low-drop-rate tusks as the first mandatory task. Quest materials
  must actually exist locally under the current zone/time spawn policies.

## 4. Parties — confirmed rules and invitation edge cases

### Confirmed by the user

- Maximum ten members, **always the same faction**. This is not a temporary
  V1 limitation; enemy factions cannot form a party.
- A party is created only when an invitation is accepted and there are two
  members. There are no persistent one-person parties.
- When membership falls to one, dissolve the party automatically. Offline
  players are still members and count toward both minimum and maximum size.
- Offline membership is indefinite, including across server restarts. Offline
  leaders keep leadership indefinitely; disconnects never elect a new leader.
- Only the leader invites and kicks while a party exists. Ungrouped players
  can invite to form one. Everyone may leave voluntarily.
- A Group tab manages invitations, accept/decline, leave and leader actions.
- Each player can disable incoming invitations. Rate limit is one invitation
  per second **per sender**. No ten-per-minute limiter or additional rate tiers.
- A saved per-player HUD switch defaults on. Ungrouped means hidden. Display
  names and HP bars; offline rows display offline status, not fake live HP.
  No mana/rage bars in this round.
- No XP multiplier, passive nearby-party credit, loot mode, automatic quest
  sharing or party-owned mob tag is introduced. Existing participation governs
  XP and quest credit independently of party identity.

### Recommended invitation model — explicit answer to the user's scenario

An invitation refers to its **inviter**, not to a provisional group id. On
acceptance, validate both current factions, recipient eligibility/preferences,
current membership, inviter authority and available capacity again:

1. If the inviter is ungrouped, create a new two-person party.
2. If the inviter currently leads a party, join that party if space remains.
3. If the inviter is now an ordinary party member, refuse the stale invitation.

Therefore: A invites B and C; B accepts (A+B exists); B leaves (dissolve);
C accepts the still-valid invitation (new A+C party). No special orphan-party
state or generation history is necessary. The UI identifies the inviter and
shows current group context before acceptance; invites do not reserve slots.

Recommended remaining defaults, not user decisions yet:

- One pending invitation per inviter/recipient pair; duplicate sends are a
  no-op and cannot create duplicate notifications.
- Invitations are short-lived (120 seconds), session-only, and require an
  online inviter/recipient to send/accept. No offline mailbox; leaving the
  server expires that player's invitations but **never** their membership.
- Limit pending incoming invitations to ten so many different senders cannot
  grow the queue indefinitely. This is a storage cap, not another rate timer.
- Turning invites off removes pending incoming invitations as well.
- Store canonical membership/leader in mod storage and treat lookup indexes
  as derived. No two authoritative copies of party state.
- Explicit leadership transfer is allowed. If a leader voluntarily leaves while
  at least two members remain, the earliest-joined remaining member becomes
  leader, regardless of online status. This is one deterministic leave rule,
  without a mandatory successor-selection dialog. Logout never triggers it.
  Leaving a two-member party dissolves it instead.
- No automatic party cleanup for inactivity, region change, death or logout.
- Party HUD rows need not support click-to-target for V1. Do not broaden the
  current spell ally/targeting rules merely because parties now exist.

## 5. Flight — the user's corrected authority

| Horizontal area | Own faction | Enemy faction |
|---|---|---|
| Safe faction home region, including capital | Flight allowed | Ground riding only |
| Ordinary contested region | Flight allowed | Flight allowed |
| Mainland Battlegrounds | Flight allowed | Flight allowed |
| Either dragon island | Ground riding only | Ground riding only |
| Authored ocean/channel | Existing no-flight rule | Existing no-flight rule |

Villages and other POIs inherit the surrounding region. They do not establish
local faction ownership or independent flight bans. Dragon islands are the
explicit geographic exception even though contested. Planned inland water
inherits its host region. Existing ceiling, underground takeoff, damage dismount
and warning-band behavior are retained.

Implement one shared legality predicate consumed by summon, movement and
warning probes. Do not infer ownership from race-region provenance. Update
living mounts/world-zone documentation and remove the obsolete implication that
all `contested_land` is enemy airspace. Test both factions over ordinary contested
land, Battlegrounds, both capitals/home regions, dragon islands and ocean.

## 6. Reported profession isolation bug

Two independent friends reportedly saw **“You already know Cooking” / “Unlearn”**
on a fresh multiplayer world after another player learned Cooking. This is not
merely universal furnace access and must not be dismissed as expected behavior.

After Go, reproduce with two distinct player identities using the trainer's
actual interaction/receive-fields path, inspect authoritative player metadata,
and trace session/callback ownership. Include Cooking and one primary profession,
reverse the learn/open order, simultaneous open dialogs and reconnects. Correct
the demonstrated cause without adding guessed resets or global relearn logic.
No player should acquire another player's profession or progress. Existing
universal Basics and automatic finishing remain universal.

## 7. Startup generation — confirmed behavior and simple execution design

### Confirmed by the user

- Option B only: preparation before players enter normal gameplay. No background
  idle-generation mode and no separately implemented LuaJIT world writer.
- Exactly one Grudgelands boolean in `minetest.conf` selects full-world versus
  starts-only preparation at the **first startup of a fresh world**.
- Persist the selected mode immediately, before queueing preparation. It is
  immutable for that world. Later configuration edits cannot switch the mode.
- Full-world mode replaces starts-only mode; do not queue both schedulers.
- One waiting UI handles both modes, shows actual progress and an estimated
  remaining time when enough timing evidence exists. Players cannot enter the
  unprepared world while the selected preparation plan is incomplete.
- Both modes must stop on a normal server-shutdown request and resume their
  deterministic chunk traversal after restart. Do not complete all remaining
  starts or the full world before shutting down.
- Bounds are named code constants, not additional configuration settings:
  x_min/x_max/z_min/z_max/y_min/y_max. Cover both continents, the mainland
  frontier, both islands and a generous ocean margin.
- The user's approximately -100/+300 vertical bounds and approximately twenty
  mapchunks of ocean are **coverage targets, not adopted exact numbers**.
  Choose values from actual relief/structures and ordinary surface loading needs.

### Recommended implementation constraints

- One scheduler and one immutable ordered work list definition for both modes.
  Starts-only uses the deduplicated union of all six necessary start envelopes;
  full-world uses a simple bounding cuboid. Avoid coast-following masks.
- Store mode, resolved bounds/order/chunk geometry and the contiguous completed
  cursor together so resume cannot reinterpret the same index differently.
  This is current-world persistence, not compatibility with earlier versions.
- First version: one mapchunk-sized request in flight. Persist the completed
  prefix only after all relevant block callbacks succeed, then defer the next
  dispatch through the main loop. This avoids out-of-order completion journals
  and an enormous emerge queue; do not add a custom worker fleet.
- Derive the aligned mapgen-chunk grid from the engine's actual chunk origin
  and size, including negative coordinates. Each work index identifies exactly
  one aligned 3D mapchunk and its expected mapblock set. Count distinct successful
  block positions, accepting generated/memory/disk outcomes; duplicate callbacks
  or one successful corner must not mark the whole chunk complete.
- CANCELLED/ERRORED requests never advance the cursor. Bound retries and show
  an actionable stopped/error state rather than incorrectly reaching 100%.
- A completed emerge callback means generated/loaded, not necessarily already
  durable on disk. Verify the normal shutdown save ordering against the shipped
  engine. A partially completed final request may be re-requested on restart;
  existing blocks load instead of being overwritten. Do not promise zero replay.
- Graceful shutdown may finish the current native work unit and necessary
  saves. Do not promise cancellation halfway through a chunk. Lua shutdown hooks
  run after emerge workers stop; do not enqueue work from emerge callbacks or
  rely exclusively on a shutdown hook to break a pre-existing giant queue.
- Before implementing the scheduler, verify the actual stop path: server-step
  termination must prevent deferred dispatch from submitting another unit during
  teardown, while pending emerge callbacks settle without enqueueing directly.
  Prove this with the targeted native stop/resume test; a comment or shutdown
  boolean set only in the late Lua hook is insufficient. If the supported engine
  path cannot provide bounded stopping, report that blocker instead of silently
  adding an engine patch or claiming the contract is met.
- Diagnose the reported starts-only shutdown delay with a small native case;
  do not assert its root cause before measuring the actual engine path.
- Do not guarantee power-loss transactionality between separate map and mod
  storage databases. Any crash-hardening beyond safe bounded replay must be
  justified explicitly; clean stop/restart is the required acceptance case.
- An immutable world mode overrides later config edits visibly in the server
  log. Completed worlds skip preparation on later starts.
- Progress counts distinct completed work units, not callbacks or attempts.
  ETA is approximate; show “estimating” initially, not a made-up duration.
- Retain the existing safe creation/stasis gate; full-world completion satisfies
  the start-readiness interface without running a second generation pass.
- No promise of zero subsequent loading: disk reads, network transfer, client
  mesh construction and travel outside the prepared volume still cost time.
- Twenty default mapchunks can mean roughly 1,600 nodes of ocean per side
  (16-node blocks × default chunksize 5 × 20). Account for that volume before
  choosing final bounds; do not confuse blocks and chunks.

Before freezing bounds, report the resulting chunk count and an estimate from
a tiny representative native sample. Surface walking is the coverage objective;
preparing every possible high-altitude flight view or deep mine is not required.
No hours-long full-world generation is an agent acceptance test.

## 8. World map — one remaining product choice

The previous explanation needs precision: **a map does not inherently require
full-world pregeneration**. An exact image of actual terrain needs source data
for the portions drawn; a schematic atlas can use the authored world model.

### Native minimap facts

- The V minimap is client-side and works from block-derived surface data the
  client has received. It builds a memory cache and renders textures locally.
  It is not a persistent per-character atlas saved by our game.
- Server mods cannot simply retrieve that minimap bitmap or embed its current
  view in a formspec through a supported server API. We do not add client mods.
- Fog of war can limit our own terrain-map work to explored tiles. It does not
  create missing terrain data or grant access to the native minimap image.

### Choice A — recommended simplest first delivery

An authored-world atlas in a separate Map tab: coasts/regions, roads, named zones,
settlements and the player's position; zoom/pan or bounded region views. Derive
the shared base from existing map authority, without forcing world generation.
Label its cartographic nature; it is not a live rendering of every player build.
Quest navigation can link to an authored target region/NPC location without a
new visit-objective type. Waypoint display does not unlock travel.

### Choice B — if actual surface appearance is the priority

A tiled terrain atlas rendered server-side from already-generated surface data;
unknown areas remain blank/fogged. Shared tile images live in a dedicated world
data directory, sent through dynamic media. Per-character discovery is a small
set of revealed tile ids in player metadata, not separate PNGs per player.
Reconnect restores discovery. Only relevant tiles are sent/displayed; never
assemble or transmit a full-resolution world image on every UI refresh.

Tile availability and personal discovery are separate: full pregeneration does
not automatically mean a player has explored every tile. V1 tiles are a surface
snapshot rather than a promise to track every placed/removed block. Do not add
live edit invalidation, a mapping profession, map items or client minimap capture.

Fog of war remains optional under the already-adopted ruling unless the user
chooses B. **Do not silently pick B or make pregeneration mandatory for maps.**
Once selected, close this choice before handing MAP to an implementation agent.

## 9. Fishing — bounded gameplay pass

Confirmed: a visible bobber moves/dips on a bite; the player must reel during a
short window or miss that fish. Successful catches use a temporary HUD message
`Caught: <Fish Name>`, not chat. Consult VoxeLibre's actual implementation/media.

Recommended defaults: right-click casts/reels; a 1.5-second bite window; a missed
bite returns to waiting with the line out. Early reeling retrieves an empty line.
One line per player, clean removal on leaving/dying/unequipping/moving too far.
Keep current catch tables, ordinary item rewards and catch-only rod wear. No
new fishing profession, lure system or rarity rebalance. Reuse the existing
transient notification area with sane replacement/expiry, avoiding HUD overlap.

## 10. Work packages, routing and ownership

All names below are proposed Round 14 lanes, not new whole-WP numbers.
Root Astra coordinates; native tools only. No Claude/other-provider CLI tasks
are authorized in this session. Sol owns ordinary bounded content and UI work;
Astra owns transaction/lifecycle-heavy tasks.

| Lane | Model | Deliverable / ownership boundary | Prerequisites |
|---|---|---|---|
| SPEC | Root Astra | Fold approved decisions into living specs; update WP8/9/12/13/20 contracts, frozen interfaces and plan state | Final discussion and Go |
| QUEST-CORE | Astra | Quest storage/transactions, shared eligible-kill seam, registry and NPC dialogue/marker state | SPEC |
| PARTY | Astra | Canonical persistent groups, invite validation, membership/leadership edge cases and UI actions | SPEC; shared UI interfaces frozen |
| PREGEN | Astra | Unified starts/full scheduler, world-bound mode, cursor, waiting-state API and shutdown/resume | SPEC; no final POI generation evidence before content freeze |
| UI | Sol | Quest and Group tabs/HUD layout/toggles; adapts core APIs rather than reimplementing authority | Frozen QUEST/PARTY APIs; integrates after core lanes |
| STORY | Sol | Six starter catalogs and home-region transitions, localized NPC identities and quest/POI content table | SPEC; parallel with core |
| POI-ART | Sol | Reusable village/outpost/camp designs, cultural variants, protected displays and NPC sockets; preview gallery | STORY handshake; existing terrain/anchor contracts |
| POI-INTEGRATION | Astra if geometry changes; otherwise Sol | Connect reviewed structures to existing anchors/roads, protection and NPC lifecycle | POI-ART; minimal real consumer checks |
| MAP | Sol for A; Astra data design + Sol UI for B | Selected world-map rendering and UI, no new travel authority | Section 8 decision and frozen POI identifiers |
| FIX | Sol | Reproduce/fix profession isolation and apply the explicit flight matrix; escalate only a demonstrated hard cause | SPEC; separate file ownership from core lanes |
| FISH | Sol | Bobber/bite/reel flow and transient catch notification | Shared HUD slot/API agreed |
| REVIEW | Fresh Sol/Astra | Independent code/visual/integration reviews, final docs drift audit | Frozen lane candidate and evidence |

Do not hand one agent all stateful systems simply because its model is Astra.
Separate contracts and independent review matter more than model count.

### Parallel waves under the current tool limit

The current native collaboration environment exposes **four active slots total,
including root**: at most three active child agents. This is a session/tool
limit, not a repository policy, user restriction or chosen cost cap. More named
lanes can exist and run in waves. If the environment later offers more slots,
independent lanes may run concurrently; do not use CLI workarounds to evade it.

Suggested scheduling after SPEC:

1. QUEST-CORE + STORY/POI concept pass + FIX. Root freezes UI integration and
   verifies the PREGEN bounds/evidence plan without starting full generation.
2. PARTY + PREGEN + POI-ART/build. STORY content consumes the frozen quest API
   when a slot opens; completed lane reviews also take a slot.
3. UI + MAP + FISH / POI integration, sequenced by available slots and shared
   HUD/mapgen ownership. Actual three-way selection follows readiness.
4. Final quest/POI integration, focused cross-player checks and fresh reviews;
   documentation drift review after all production changes settle.

Root owns shared BACKLOG/ROADMAP/README/design edits, API agreements and merges.
Agents use isolated worktrees or non-overlapping explicitly assigned files;
no concurrent writers to combat, tag-carrier, HUD or mapgen integration seams.
Package counts are not a reason to run duplicate tests or leave reviews out.

## 11. Interface and integration contracts to freeze before code

- **Participation:** one per-death eligible participant result reused by XP and
  quests. Preserve current damage/effective-heal rules, range 40, XP formula and
  no-party semantics; publish before participant cleanup. No new tap ownership.
- **Quest catalog:** stable quest/NPC/zone/anchor ids, target families, item
  counts, prerequisites, min levels, text and rewards. Data validation catches
  cycles, unknown items/mobs/sockets and locally unavailable mandatory resources.
- **Visibility:** tag owner supplies nearby observer membership once; marker
  owner partitions those observers by quest state. Do not change base nametag
  visibility when quest state changes. Parent/child activation cleanup is shared.
- **HUD:** named layout allocations for party, quests and transient messages;
  no hardcoded overlapping coordinates in three independent mods.
- **Party:** server revalidates every action; UI caches never authorize invites,
  leadership, faction membership or the tenth slot.
- **Preparation:** one persisted mode/plan/cursor, one readiness/progress API,
  one waiting screen; creation and reconnect must both respect the active gate.
- **Map/POI:** stable authored anchors feed map labels and quests. Never encode
  today's resolved x/z in quest definitions as a substitute for the anchor API.

## 12. Minimal meaningful verification

Read the interpreter strategy before scheduling tests (done for this plan).
Every Lua change gets plain-5.1 parser, SETGLOBAL and all five source sweeps,
including changed tools outside the default mod glob. Development/runtime
fixtures use LuaJIT; no intermediate PUC suite, seed fleet or exhaustive PUC run.
For this new feature round, follow the repository default of one bounded final
PUC micro-KAT and the same fixture under LuaJIT with a canonical equal digest;
prior fix-round PUC waivers are not silently extended to new scope. Native
engine behavior remains a separate targeted check. No hour-long test loops.

At most seven interpreter processes workstation-wide; parallel independent runs
use idle CPU/I/O scheduling and immutable inputs. Agent slots and interpreter
process limits are different limits. Reviewers inspect accepted evidence instead
of repeating native runs or final parity checks.

Required focused cases:

- Quests: accept/20-slot limit/abandon/reaccept, same-world reload, inventory+
  bags turn-in, insufficient reward space, duplicate submit and exactly-once
  rewards; local item and mob availability checked from actual catalogs.
- Participation: two attackers, effective healer, two different groups and
  ungrouped helpers, out-of-range/offline and no-effect heal; credit matches
  current XP eligibility without requiring the killing blow.
- Party: A/B/C dissolution example; simultaneous final-slot acceptance; faction
  rejection; offline members and leader across restart; invite opt-out/rate limit;
  stale inviter authority and voluntary leadership transfer/leave.
- Visuals: two players at the same NPC with different quest states, 25/30
  hysteresis, lifecycle cleanup; ten party rows and three quests without overlap.
- Flight: both factions across the full table in section 5, same predicate for
  warning/summon/movement, explicit island and ocean precedence.
- Professions: actual two-player trainer callback paths and metadata; no guessed
  fixture that bypasses the reported interaction.
- PREGEN: tiny native world/test-only bounds; starts and full modes; normal
  shutdown mid-work and two restarts; changed config ignored; failed/cancelled
  request does not skip; no duplicated starts work; readiness never premature.
  Record shutdown latency and the bounded unit that finished. Full production
  world generation is a user-operated workflow, not an integration test fleet.
- POIs: targeted placement/roads/NPC sockets and the real affected mapgen
  consumers. No broad inherited WP40 oracle reruns without a specific reason.
- Fishing: successful/missed/early reel, two simultaneous anglers, no reward
  duplication, cleanup and a readable expiring HUD notification.
- MAP: chosen rendering path works without full pregeneration; reconnect and
  absent tiles/unknown areas handled under the selected design.

Every non-trivial lane gets a fresh non-author review, findings resolved before
merge. Keep final immutable logs/hashes and calibration fields. Final docs audit
uses a fresh Astra agent after all implementation lanes settle. That audit
must remove obsolete party-credit, contested-flight and mandatory-fog rules from
living authorities while preserving historical completion evidence.

## 13. Remaining decisions for the final discussion

1. **Map rendering:** A (schematic authored-world atlas, recommended simple V1)
   or B (actual terrain tiles plus personal exploration). The native V minimap
   itself cannot simply become the inventory atlas.
2. **Invitation/leader defaults:** approve inviter-bound invitations, 120-second
   online/session lifetime, ten pending incoming maximum, and succession to the
   earliest-joined remaining member on voluntary leader departure. The user's
   offline-leader rule and A/B/C scenario remain intact in either implementation.
3. **Content boundary and modest defaults:** approve six starter chains, six
   home-region villages plus six outposts/six bandit camps, optional crafting
   branch, three tracked quests, simple full-inventory turn-in refusal and the
   1.5-second fishing window. These are proposals, not previously confirmed
   numbers. Creative agents may author within the approved bounds autonomously.

PREGEN coordinate values are evidence-driven implementation choices within the
user's coverage objective, not another menu of settings or arbitrary new design
question. Freeze and record them before running preparation, with cost estimate.

## 14. Delivery and next playtest

After approval and implementation: clean reviewed merges to main, current design
and progress docs, installed-game sync, push to the authorized repository, no
modification of the user's personal worlds, and a concise playtest handoff.

The next GUI test should start with two same-faction characters: verify isolated
Cooking learning, accept different quests at one NPC, complete a shared kill
with healing participation, form/leave/re-form a party, reconnect an offline
leader, visit an authored village, inspect the chosen map, fish through a bite
and cross the revised flight boundaries. PREGEN gets a separate optional admin
check on a disposable world; do not make the user regenerate the entire world
merely to verify the quest/UI round.

## Planning review checkpoint

Independent planning review: GPT-5.6 Sol; author/coordinator: GPT-6 Astra.
Two PREGEN contract clarifications (aligned chunk accounting and early shutdown
proof) were incorporated in one correction round. Final verdict: zero blocking,
High or Medium findings; ready for final user discussion, not implementation.
Elapsed review time: unknown. Documentation-only validation; no Lua or native
runtime tests were executed for this planning change.

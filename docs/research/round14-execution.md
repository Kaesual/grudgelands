# Round 14 execution

Approved and started 2026-09-21. Root: GPT-6 Astra. User authorized autonomous
implementation through the next playtest, local reviewed merges, installation
sync and push. No Claude tasks or same-provider CLI delegation.

## Authority and durable decisions

Living contracts: [quests](../design/quests.md), [parties](../design/parties.md),
[world atlas](../design/world_map.md), [world preparation](../design/world_preparation.md).
The reviewed plan was approved in full, with atlas A and no fog, accepted invite/
leader defaults, and an ocean margin of **20 mapblocks = 320 nodes**.
If unexpected complexity materially expands a lane, pause that lane and escalate
the concrete tradeoff to the user; continue independent lanes. Do not silently
invent a bigger system.

## Scope

Six starter chains (8–12 quests each), six level-11–20 villages, six corresponding
outposts and six bandit camps on existing anchors; optional crafting lessons.
Quest core/UI/markers, persistent party management/HUD, cartographic Map tab,
resumable startup preparation, profession isolation and flight fixes, fishing.
The Nether is reserved for the first expansion, not V1: no Nether-dependent
quests, rewards or POIs in this round.
No full 1–60 story, Housing, fast travel, boats, economy rebase or broad engine
rewrite. All suggested simplifications in the approved plan apply.

## Lane state

| Lane | State | Owner / next step |
|---|---|---|
| SPEC | running | Root: authoritative documents and shared API/ownership agreements |
| QUEST-CORE | candidate; review queued | native r14_quest_core, Astra; owns grug_quests core/tag_carrier/mobs kill seam/start_villagers |
| STORY | candidate; review queued | native r14_story, Sol; 66 quests staged tools/r14_story/content.lua until POI sockets exist |
| FIX | candidate; review queued, Cooking diagnosis unresolved | native r14_fixes, Sol; jobs and mount flight |
| PARTY | core candidate; independent review running | native r14_party, Astra; UI integration running separately |
| PREGEN | candidate; independent review queued | native r14_pregen, Astra + root waiting UI; bounded native stop/resume passes |
| UI | running | native r14_ui, Sol; Quest/Group pages and HUD |
| POI-ART / INTEGRATION | running | native r14_poi, Sol; 18 anchors through existing r7 settlement writer |
| MAP | queued | Sol, atlas only |
| FISH | queued | Sol |
| Reviews / final drift | state review running | native r14_state_review, Astra; remaining lanes/final drift queued |

## Accepted operational plan

## 10. Work packages, routing and ownership

All names below are approved Round 14 lanes, not new whole-WP numbers.
Root Astra coordinates; native tools only. No Claude/other-provider CLI tasks
are authorized in this session. Sol owns ordinary bounded content and UI work;
Astra owns transaction/lifecycle-heavy tasks.

| Lane | Model | Deliverable / ownership boundary | Prerequisites |
|---|---|---|---|
| SPEC | Root Astra | Fold approved decisions into living specs; update WP8/9/12/13/20 contracts, frozen interfaces and plan state | Approved |
| QUEST-CORE | Astra | Quest storage/transactions, shared eligible-kill seam, registry and NPC dialogue/marker state | SPEC |
| PARTY | Astra | Canonical persistent groups, invite validation, membership/leadership edge cases and UI actions | SPEC; shared UI interfaces frozen |
| PREGEN | Astra | Unified starts/full scheduler, world-bound mode, cursor, waiting-state API and shutdown/resume | SPEC; no final POI generation evidence before content freeze |
| UI | Sol | Quest and Group tabs/HUD layout/toggles; adapts core APIs rather than reimplementing authority | Frozen QUEST/PARTY APIs; integrates after core lanes |
| STORY | Sol | Six starter catalogs and home-region transitions, localized NPC identities and quest/POI content table | SPEC; parallel with core |
| POI-ART | Sol | Reusable village/outpost/camp designs, cultural variants, protected displays and NPC sockets; preview gallery | STORY handshake; existing terrain/anchor contracts |
| POI-INTEGRATION | Astra if geometry changes; otherwise Sol | Connect reviewed structures to existing anchors/roads, protection and NPC lifecycle | POI-ART; minimal real consumer checks |
| MAP | Sol | Selected world-map rendering and UI, no new travel authority | world_map.md and frozen POI identifiers |
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

Scheduling after SPEC:

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


## Final delivery

Review all nontrivial changes independently, minimal relevant static/native
gates, one bounded final interpreter parity pair, final fresh Astra docs-drift
audit, clean main merge/sync/push and a next-playtest checklist. No personal
world writes. Current worktree is shared with explicit non-overlapping lane
ownership; root alone changes git branch/history and shared docs.

## Planning review

Author Astra, independent reviewer Sol, two PREGEN contract clarifications
closed in one correction round; final 0 blocking/High/Medium findings. User
approved final defaults and Go. Review elapsed time unknown.

## Frozen implementation seams (2026-09-21)

QUEST schema: `register_npc(id,{settlement,socket,title})`,
`register_quest(id,{title,description,npc,turnin_npc,faction,race,min_level,
prerequisites,objectives,rewards})`. Kill objectives use mob/count/optional zone;
item objectives use item/count. Rewards are xp/copper/items. Runtime APIs:
accept, abandon, turn_in, status, journal, set_tracked, set_hud_enabled,
register_on_change. QUEST owns `start_villagers.lua` elder hook. FIX may request
`start_npcs.lua`; coordinate before touching. STORY owns quest `content.lua` only.

Existing shared HUD layout is `mods/CORE/grug_core/hud_layout.lua` (not a separate
mod). UI lane will own its added party/quest anchors and notification helper,
plus a new quest journal/HUD adapter; preserve bottom-centre bars and top-right
status list. Core quest lane should not implement competing HUD coordinates.

FIX additionally owns the affected flight assertions in
`tools/r9_mounts/mounts_kat.lua`. No shared-file author overlap is authorized.

## Root checkpoint: first-wave findings

- QUEST core API/schema frozen; marker models must be original extruded 3D glyphs
  rather than nametag characters, initialized with empty observers.
- STORY POI handoff is in `round14-story.md`. New NPC sockets: village
  `quest_steward`, outpost `quest_scout`, bandit `quest_captive`, all role quest.
  Catalog is staged under `tools/r14_story/content.lua` until these sockets exist;
  never weaken startup validation to hide missing content.
- FIX flight matrix implemented; profession isolation remains **unreproduced**,
  not fixed. Actual NPC/trainer/state call chain and two-player callback fixtures
  isolate correctly. Root authorized narrow trainer action diagnostics (one log
  per open/learn/unlearn) to obtain real two-client evidence, no new setting.
- STORY instructed to avoid mandatory consecutive night-only waits and premature
  travel into higher-level zones; validate level gates against real XP curve.

### Waiting UI candidate

Root owns `mods/PLAYER/grug_classes/selection.lua`: selected preparation mode,
whole-percent progress, minute-rounded ETA and unchanged-form suppression.
Complete characters reconnecting during preparation enter stasis, then resume
at their previous position; only new characters perform the arrival teleport.
`tools/r14_selection/kat.lua` loads the real module and passes under LuaJIT;
parser/SETGLOBAL/five sweeps pass (two existing display-string pipe hits).
Independent review is pending with PREGEN.

### Party API handoff

`grug_parties.view(player_or_name)` returns nil or a copied
`{id, leader, faction, members={{name, online, hp, hp_max}, ...}}` in join order.
`pending(player_or_name)` returns sorted `{inviter, expires_in, party}` entries.
Authenticated online-player mutations: `invite`, `accept`, `decline`, `leave`,
`kick`, `transfer_leader`; results are boolean/message. Preferences use
`invitations_enabled` / `set_invitations_enabled` and `hud_enabled` /
`set_hud_enabled`; subscriptions use `register_on_change(fn(name, reason))`.
Core emits presence/membership/preferences/invitation changes; UI samples HP
at a bounded interval and compares displayed values before sending changes.

### Story review focus before integration

The authored catalog is a candidate, not approved final content. Verify the
actual spawn policy for every mandatory target (especially step 06 at level 8),
level-gate pacing, and objective text: `Defeat the named threat` is too vague
for a tracker unless target names are included by the UI. Ensure the optional
tool lessons actually explain a useful mechanic rather than only promising
a lesson. The Nether exclusion is now explicit in both story and quest specs.

### Preparation candidate evidence

Real isolated native starts/full stop/resume passes (three boots each), including
immutable settings and zero dispatch after completion. Full bounds contain
70,488 default engine mapchunks; ocean margin remains 320 nodes, not 1,600.
Two warm surface-unit timings only suggest 16–23 hours if extrapolated; this is
explicitly nonrepresentative and no full world was generated. Cold initialization
can take 15–16 seconds; shutdown waits at most the active unit, not the full plan.
Evidence and scratch-only execution details: `round14-pregen-work.md`.

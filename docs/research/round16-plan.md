# Round 16 — Playtest fixes, combat feedback and surface preparation

Status: approved and executing; explicit user Go on 2026-09-22.
Date: 2026-09-22. Coordinator: native GPT-6 Astra.
Both proposed simplifications are approved: tile-based preparation progress and
lightweight ice-crystal particles. Execution ledger: `round16-execution.md`.

## Authority and scope

The user's latest playtest decisions govern this increment. Earlier Round 15
delivery records describe shipped behavior, not acceptance of newly reported
defects. This plan records the accepted changes and implementation boundaries;
before implementing each lane, fold its decisions into the relevant living
`docs/design/` sections. Do not leave contradictory active rules in those files.

Read `AGENTS.md`, `docs/process/wp-workflow.md`,
`docs/process/agent-model-policy.md`, and the interpreter strategy in
`docs/research/luanti-lua.md`. The user's session routing overrides historical
Claude routing: native Astra and native Sol only, no Claude and no Codex CLI.
Fresh-server development remains in force: no migrations or legacy readers.
Normal persistence and restart of the same current-version world are required.

Unexpected major complexity pauses only the affected decision path and is
reported to the user. Do not silently build a general subsystem to solve one
reported defect. Nether, waypoints, new POI rosters, broad loot/economy expansion,
and a new Charge movement implementation are outside this round.

## Confirmed decisions

1. Fix invisible self/party directional atlas markers. Add individual static
   quest-giver, profession/Riding-trainer, king and dragon markers. Player/party
   markers remain live and directional in overview and regional maps. NPC
   positions use authored anchors, not remote entity lookup. Tooltip text is
   names only, with no level/HP/status prose. Quest symbols/colors retain the
   viewer's quest state and existing priority. **No clustering, displacement,
   collision avoidance, proximity grouping or other close-icon special case**
   in this first pass; user feedback will decide whether any is needed later.
2. Armor tooltips identify Cloth, Leather or Metal. Repair the furnace recipe
   book/input-slot overlap, including related furnace layouts.
3. Target a 20-real-minute day/night cycle: 15 minutes day and 5 minutes night,
   including smooth dawn/dusk transitions within those phases. Moderately raise
   nighttime exterior visibility without making enclosed caves daylight-bright.
4. Quest rewards are fixed by intended quest level/work, not scaled to the
   receiver's current level: ordinary quests approximately 15–25% of the
   intended level interval; substantial chain finales approximately 30–40%.
   Account for accompanying kill XP. These ranges authorize a concrete reviewed
   reward table, not a new runtime reward framework. Show minimum level and
   prerequisite quests in descriptions. Send the final starter quest to the
   next regional giver for hand-in and update all six racial chains.
5. Increase **mob-kill XP by 50%** at its shared source, once only. Preserve
   current participation sharing, gray-mob rules and racial modifiers. This is
   separate from quest rewards and does not multiply admin XP grants.
6. Add a small HUD combat indicator using the existing combat state. Extend
   the XP bar label to `Lv X (520/1000)` using XP within the current level;
   max level gets an explicit stable label. Add privileged
   `/xp give <player> <amount>` without changing the XP curve.
7. Correct only the Ibex targeting box against its real mesh/scale; do not
   build automatic animated mesh-to-hitbox inference or audit every creature.
8. Investigate threat/target switching with an Astra agent. The report may be
   mistaken: no speculative aggro rewrite if no defect is established. Retain
   accumulating threat, current target-switch hysteresis and reset behavior;
   no new time-based in-combat decay. Apply the latest audit-first instruction
   conservatively: do not preemptively retune Taunt. A clean audit leaves its
   current three-second/top×1.1 behavior unchanged until the targeted user test.
   The earlier five-second/top+1 proposal is deferred, not silently implemented
   as an audit fix. A demonstrated bug warrants a targeted correction, not
   automatic adoption of new tuning values.
9. Charge retains its current teleport movement and gains a 1.5-second true
   stun on eligible targets. Normal mobs and hostile players can be stunned;
   kings and dragons are immune. Stun prevents voluntary movement and new or
   pending attacks/skill execution, rather than only reducing speed. Already
   launched projectiles need not be removed. Existing PvP/target validity and
   combat-result rules apply; do not apply hostile control to rejected targets.
10. Frost Nova roots players through the existing hard-root facility instead
    of the present 10%-speed modifier. Preserve subsequent slow and legitimate
    movement immunity. Persistent lightweight ice visuals follow the actual
    root state on mobs and hostile players. Add small baseline damage around
    one quarter of comparable Fireball baseline damage with consistent scaling;
    reconcile existing control-damage talents without double counting.
11. Reject eating during combat before item consumption or food-status
    mutation, with concise feedback. Double every food's periodic HP/mana
    regeneration only; preserve instant restoration, stat bonuses, five-second
    tick interval, five-minute duration and out-of-combat regeneration rule.
12. Reuse licensed reference-game eating/drinking audio, checking exact source
    attribution. Start eating audio at 50% source playback gain. Use runtime
    gain rather than destructive audio edits; ffmpeg is available but not
    required. Sound plays only on successful consumption. Other sound additions
    are a small curated set of conspicuously silent actions, not a full audio
    overhaul.
13. Increase ambient **fightable open-world mob density by about 30%**, replacing
    the earlier +50% proposal. Leave critters, NPCs, bosses, authored guards,
    king guards and summoned/encounter adds unchanged. Preserve species/zone
    distribution. No extensive AI-budget measurements or PERF work is requested.
14. Fix the mounted logout crash in both vendored mobs cleanup and our mount
    lifecycle; land and flight mounts, normal logout and server shutdown must
    all clean up safely.
15. Replace full-mode fixed vertical-volume preparation with conservative
    **surface-following chunk selection**. Keep the boolean setting, exclusive
    starts/full choice, waiting UI, immutable per-world mode and resumable
    successful-prefix cursor. Full preparation covers both continents, frontier,
    dragon islands and the existing 20-mapblock (320-node) ocean margin.

## Source findings and limits of this planning pass

- `grug_map/providers.lua` and `page.lua` already implement self/party markers
  and quest markers. Their missing in-client rendering is confirmed by the user,
  but its cause has not been reproduced. Existing quest grouping is explicitly
  removed by the individual-marker decision; no replacement grouping system.
- `grug_core/combat.lua` currently accumulates damage/healing threat and uses
  120% switching hysteresis. Its Taunt defaults are three seconds and top×1.1.
  The investigation must distinguish tuning from an actual bypass/ledger bug;
  the latest audit-first instruction leaves numerical retuning deferred.
- `grug_abilities/kits.lua` explicitly applies a 0.1 speed stage to Nova-hit
  players; `grug_core/movement.lua` already has a zero-speed/zero-jump hard root.
- `grug_quests/content.lua` grants 3,000 XP for starter-chain quest six.
  Registry/state already support a distinct `turnin_npc`; no new quest type is
  needed for starter handoff.
- Ibex in `grug_mobs/start_zone_families.lua` has a collision box ending at
  y=0.5. Validate the actual aiming/selection path before choosing final bounds.
- `player_api` drops player animation records in its leave callback;
  `mobs/mount.lua` and `grug_mounts/entity.lua` later call animation restoration.
  This matches both supplied assertion stacks. Fix lifecycle ownership/order,
  not broad exception swallowing.
- No local `time_speed` override was found in the user's standard Flatpak
  config or production game. Reference engine default is 72: a 20-minute cycle.
  `src/daynightratio.h` gives about 9m47.5s full daylight, 7m42.5s full darkness,
  and 2m30s combined transitions. This is a local reference, not a claim about
  every separately configured multiplayer server.
- `grug_alchemy/effects.lua` already uses `override_day_night_ratio` for night
  vision. New exterior lighting must compose with that effect, including expiry,
  rather than overwriting its benefit or clearing the new baseline.
- `SimpleSoundSpec.gain` supports half-volume playback directly; reference
  audio file-specific licensing still needs verification before copying.
- Surface research found an existing readonly authority seam:
  `grug_mapgen.wp40.planner_source` (`wp40/r7_loader.lua:138`) exposes
  `column_values_at` (`wp40/zones.lua:1570,1668`). It includes terrain, water,
  functional and transition heights. Structure/vegetation coverage also needs
  real `r7_manifest`/settlement/content extents; that adapter remains an explicit
  implementation task. The horizontal footprint has roughly 55 million node
  columns, so a synchronous full scan at mod load is not acceptable.

## Package contracts

### A — Mount teardown (Astra, highest priority)

Own `grug_mounts` lifecycle and the minimum necessary vendored mount hook patch.
Read player_api callback ordering and engine leave/shutdown contracts. Use the
shared cleanup path, idempotent controller/visual removal, and no animation
restoration after player data teardown. Preserve ordinary in-session dismount
visuals, mount ownership, speed and first-person behavior. Mark vendored changes
and update VENDOR.md. Acceptance: land/flight logout, shutdown with mounted
players, repeated cleanup, and ordinary dismount do not assert or retain state.

### B — Combat correctness and control (Astra)

Own shared combat/movement status seams, ability execution, mob attack-control
hooks and Ibex definition. First report threat findings with concrete evidence;
an unconfirmed report does not authorize a rewrite. Audit accepted damage,
healing, threat modifiers, native retaliation/forced target changes, expiry and
leash reset. Report current values and concrete defects separately; preserve
current Taunt tuning if no defect is found and await the user's targeted test.

Implement Charge stun and Nova changes through common state/authority paths.
Ensure melee held swings, casts and bow release cannot bypass stun; stop pending
actions without banking a catch-up burst. Mobs must not continue special attacks
while stunned. Preserve gravity and movement after expiry; do not use continuous
teleports or invisible cages. Reconcile overlap with roots/slows and immunity.
Ice feedback uses a few lightweight crystal particle sprites near feet/body,
with simple size scaling and emission tied to actual root state. No fitted ice
mesh, per-model bones or separate persistent decorative entities. Brief fade-out
after expiry is allowed; stop emission on expiry/death/removal.
Acceptance uses bounded real-code scenarios, including two distinct player
records attacking one mob. It is not advertised as a two-client GUI test.

### C — Atlas repair and navigation markers (Astra)

Own `grug_map`, provider/texture wiring and required readonly authored-position
seams. Trace why rendered triangles fail, including packaged media, coordinates,
layering and formspec lifecycle. Use authored NPC anchors without emerge calls.
Retain current close-to-Character behavior and live refresh only while Map is
open. Include self, online party, individual quest givers, trainers, kings and
dragons on overview and appropriate regional views. No special handling of
nearby markers. Names-only tooltips; static boss markers indicate locations,
not live presence, health or respawn knowledge. No remote quest interactions.

### D — Progression and quest guidance (Sol)

Own quest catalog/descriptions and shared kill-XP award source. Read
`quests.md`, XP curve, participation rules and current `turnin_npc` behavior.
Provide a compact old/new reward table by intended level with expected kill XP;
keep the implementation a catalog correction. Apply +50% kill XP exactly once
before the existing downstream sharing/racial semantics as appropriate to their
actual authority. No group XP redesign, no extra quest types or expansion quests.
Starter finales lead to the next giver, with log/NPC/atlas states agreeing.
Coordinate marker-state API changes with C; D owns quest-state writes.

### E — UI clarity and food recovery (Sol)

Own furnace forms, armor-tooltip composition, food values/use path, combat HUD,
XP label and admin command. Preserve equipment/enchantment descriptions and
station inventory authorization. Coordinate XP-module writes with D in sequence
or assign the module to one agent; never simultaneous edits/cherry-picks that
overwrite one another. Use one existing combat-state authority for food/HUD.
No food loss or buff replacement on rejection; periodic regeneration alone
doubles. Admin grants require privileges and validated amount/recipient.
Retain layout clearance at normal GUI scales, including wider XP text.

### F — Atmosphere, audio and ambient density (Sol)

Own day/night clock, atmosphere integration, reference audio imports/ledger and
central ambient spawn tuning. No new mod-specific configuration menu. Resolve
time phase boundaries consistently with current lighting and mob-clock behavior;
the 15/5 target includes transitions, not 20 minutes plus extra dawn/dusk.
Use a single coherent lighting owner with night-vision composition. Keep darkness
in enclosed underground areas and verify ordinary client lighting support.

Audio should be wired through agreed consumption/status hooks, with E owning
the food source file. Choose a few useful sounds; no music package. For density,
classify existing ambient fightable rows and adjust chance/caps coherently;
neutral huntable wildlife counts, cosmetic critters do not. A 30% target is
approximate because caps are integer and populations depend on player activity.
Bosses, rares with their dedicated timers, service NPCs, guards and adds retain
their encounter counts. Use source/registration checks, not a benchmark fleet.

### G — Surface-only full-world preparation (Astra)

Own `grug_core/preparation_plan.lua`, `starts_preload.lua`, necessary selection
UI messages and a narrow readonly mapgen-authority adapter. Read
`docs/design/world_preparation.md`, Round 14 pregen evidence and current
mapgen height/content authority before changing traversal.

Before finalizing/persisting a selected work plan, validate the supported mapgen,
actual chunk geometry and deterministic current terrain/content authority. If
that authority is missing or mismatched, stop with an actionable error/escalation;
never silently substitute coarse heights or invented global padding.

**Coverage contract:** choose aligned generation chunks that contain the visible
land/water surface, exposed slopes/cliffs, above-ground structures/vegetation and
required local support at their boundaries. Avoid globally generating every
height layer from a deep floor to the highest peak. Retain the existing horizontal
coverage/margin and actual engine chunk origin/geometry, including negative coords.
Normal surface travel is the objective; deep mining, diving and arbitrary flight
volumes are not pre-generated. Chunk granularity inevitably includes some air,
soil and water beyond the strictly visible skin.

**Conservative selection:** use the actual current terrain/writer authority,
including settlement grading, shore changes, water, functional heights and
content extents. Do not infer extrema from one center/corner sample or select
only one top chunk per horizontal tile. Adjacent lower terrain can expose a tall
cliff; boundary-neighbor heights and all intervening exposed Y layers must be
included. Account for towers/tree crowns and shallow visible seabed without
turning all ocean columns into a full-depth ocean pregen. A conservative local
vertical envelope is acceptable; a full-world cuboid disguised as fallback is not.

**Tile-by-tile selection:** resolve a conservative local surface envelope for
one horizontal generation tile, generate all selected Y chunks, then advance
in a deterministic horizontal order. Progress counts fully completed horizontal
tiles, not a precomputed global count of 3D chunks. Persist the tile and its
inner-chunk cursor/selection so restart neither changes index meaning nor loses
partial-tile progress. No full-world height prepass, global selected-list build
or separate persistent world-planning phase. Bound local selection work if needed.
A tile counts complete only after every required chunk succeeds. Preserve one
emerge request in flight, deferred dispatch, distinct-successful-mapblock
accounting, retries and cancellation behavior. Mountain tiles may take longer;
ETA remains approximate and needs no terrain-weighted prediction. Mode remains
locked at first fresh-world startup; no old-plan migration. Starts-only behavior
remains bounded and resumable. Full mode includes every start's required readiness
envelope without a second scheduler.

**Limits and escalation:** no promise of zero later generation/loading. Clients
can request neighboring air or underground chunks; disk/network/meshing costs
remain. If a safe selector needs a new terrain authority, massive synchronous
sampling, writer/manifest redesign or generalized visibility tracing, pause and
report options before doing that work. Report selected-vs-old chunk count only
if available incidentally from the implemented selector. Exact savings are not
a deliverable; do not perform a comparison run or optimize for a minimal chunk
set. Conservative extra soil/air is explicitly acceptable.

**ETA instruction (user follow-up):** the initial estimate may be much too high
and naturally decrease after the first few percent. This is accepted behavior;
do not tune/fix the estimator or treat its early value as a reliable forecast.
A final order-of-magnitude estimate is optional, not an acceptance gate. If one
is reported, run generation exactly once for 60–120 seconds after implementation
is ready, then request normal shutdown and report the estimate observed after
that warm-up with its uncertainty. Allow the current bounded native unit and
normal saves to settle; do not kill it just to hit a wall-clock deadline.
No repeated timing samples during development, seed comparisons or full runs.
Use a disposable fresh world; the one final sample may also supply the normal
stop-path observation, without replacing required bounded correctness checks.

## Dependencies, file ownership and scheduling

The environment presently has four active-agent slots including root: schedule
up to three workers, not seven simultaneous agents. This is a tool limit, not a
project policy against wider parallelism. Root keeps the integration ledger.

1. After Go: A, B and G start independently; root freezes doc updates and seams.
2. As a lane frees a slot, start C, then D/E/F as dependencies allow. Never hold
   all implementation slots for reviewers while unfinished prerequisites wait.
3. B owns movement/combat hooks; E consumes combat state. D owns quest state;
   C consumes marker state. D/E share XP through explicit serial handoff. E/F
   share food audio through explicit handoff. A/B both touching vendored mobs
   requires isolated patches and root integration review.
4. Use isolated lane branches/worktrees. Root integrates reviewed changes onto
   one round branch, resolves overlap, and owns final validation and delivery.
5. Independent reviewers did not author their scope. Astra reviews surface
   coverage/resume and combat authority; separate Sol/Astra reviews the remaining
   work. Root never self-approves root-authored changes. Finish with a bounded
   docs/code drift review, then merge, sync from main and push under the user's
   standing authorization. Record model calibration and evidence limits.

## Validation budget

This planning task executes no runtime suites. For implementation:

- Every changed Lua file: plain-5.1 parser, SETGLOBAL inspection and all five
  source sweeps, including changed tools outside mod sweep defaults.
- Development fixtures use LuaJIT. No intermediate PUC execution, seed fleet,
  full world generation, historical WP40 population suites or general PERF work.
- Use focused lifecycle, combat target/control, inventory/XP/food and map-form
  fixtures that exercise actual changed consumers. GUI claims remain user-tested.
- Surface selector cases: flat land, one narrow peak, a cliff exactly across
  chunk boundary, coast/water, structure/tree crossing a Y boundary, negative
  coordinates, start coverage, resume/cancel/duplicate/error and changed config.
  Test actual authority integration, not only a hand-built height mock. A small
  representative native surface/stop-resume gate is allowed; no whole-world run.
  Optional final ETA sampling is the single 60–120-second run specified in G,
  never a repeated development benchmark. Initial ETA overestimation is accepted.
  If planner tuples or R7 projection change, required real manifest/planner gates
  apply; do not change those interfaces merely to avoid reading existing sources.
- One combined compact final PUC-5.1 process and the same fixture once under
  LuaJIT on frozen bytes; identical canonical digest. Reviewers inspect artifacts
  rather than duplicating the pair. Changed relevant bytes replace that pair.
- At most seven independent interpreter processes workstation-wide, immutable
  inputs/separate outputs, idle priority for fleets. This is a ceiling, not a
  request to create a fleet. No expensive AI-density/PERF measurements.

## Documentation and delivery checklist

Update the affected living specs before lane implementation: world_map,
world_preparation, quests, combat_stats/classes/skill_trees, food/economy/XP,
biomes_mobs, atmosphere/visuals and inventory descriptions as applicable. Keep
one authority per rule; no unrelated broad historical-doc cleanup. New assets
carry exact source/version/license attribution, with vendor patches recorded.

Maintain BACKLOG/ROADMAP/README status without claiming new whole-WP completions.
At delivery record implemented scope, independent findings/fixes, final hashes,
test limitations, merge/sync/push receipt, and a concise next-playtest checklist.

User GUI focus: mounted logout/shutdown; two-player threat/Taunt; Charge stun and
Nova root/ice in PvE/PvP; atlas markers on all views; early quest leveling and
handoff; food rejection/regeneration/sound; furnace/armor/XP/HUD readability;
day/night feel and ordinary mob density. Surface preparation uses a fresh test
world and a stop/restart, with representative cliffs/coasts/settlements visited.

## Planning ledger

- Latest user follow-up accepts extra generated soil/air, does not request an
  exact savings report, and explicitly leaves initial ETA overestimation alone.
  Optional final ETA sample is capped to one 60–120-second generation run.
- Both simplifications approved with explicit implementation Go. Decisions are
  folded into this plan and living design; the resolved TODO is deleted.

- Root inspected current code, local time settings and engine lighting/audio
  contracts. No game files changed or tests executed.
- Native Astra `r16_surface_planning`: bounded readonly feasibility research.
- Surface research complete: existing height authority is usable; actual
  structure/vegetation extents and bounded selection scheduling require care.
- Native Sol `r16_plan_review`: found one scope ambiguity (earlier Taunt tuning
  versus latest audit-first instruction). Root chose the conservative audit-only
  scope and added the suggested surface-authority precondition. Focused re-review
  is clean; no implementation began. Planning review calibration: author Astra,
  reviewer Sol, initial 0 Critical / 1 High, one correction round, elapsed time
  not recorded. This reviews the plan, not future code or runtime behavior.
- Implementation authorized. See `round16-execution.md` for current assignments.

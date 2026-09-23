# Round 18 — Playtest clarity, world consistency and preparation

Date: 2026-09-23. **Approved; implementation authorized by explicit user Go on 2026-09-23.**
Baseline inspected: `7460c49d227a3f66673ad1bf4b7ed429e4b62321` on main.
The original user feedback is preserved verbatim in
[round18-playtest-input.txt](round18-playtest-input.txt), items 1–19 in order.
All planning decisions are closed; living authority: [Round 18 revision](../design/playtest_quality_revision.md).
Resume/status: [round18-execution.md](round18-execution.md).

This is the approved implementation contract, not a claim that these features
are already shipped. Root remains the Astra orchestrator. The user approved all
listed simplifications and requires a VoxeLibre complexity preflight BEFORE
starting any held-light implementation. Pause and discuss if that preflight
already shows disproportionate complexity.

## 1. Authority and boundaries

Read AGENTS.md, BACKLOG.md, docs/process/wp-workflow.md,
docs/process/agent-model-policy.md and docs/research/luanti-lua.md before work.
Relevant living specs: classes.md, combat_stats.md, progression.md,
inventory_equipment.md, professions.md, crafting_equipment_revision.md,
biomes_mobs.md, world_zones.md, world_map.md, quests.md and character_visuals.md.
Update their decided rules during implementation; never leave new mechanics
only in a completion report. Historical research remains historical.

- Standard unmodified Luanti client; no client fork, required client mod or
  upstream-PR dependency. Native subagents only; no Codex CLI or Claude tasks.
- Fresh-world development, no migrations or compatibility aliases. Same-version
  reconnect, restart, entity reload and preparation resume must work.
- No Nether, extra questline expansion, new world geometry, combat balance
  campaign, broad AI rewrite, economy retuning or new death penalty.
- Preserve R17 homing, damage scale 1.5, fixed dispositions, tag colors,
  home travel and group rules unless this plan explicitly changes them.
- Large unexpected complexity pauses only the affected lane for discussion.
  Do not solve engine limitations through an unapproved replacement system.
- Existing open tool-speed calibration (TODO-design-crafting-rework.md B22)
  does not authorize retuning every tool in this fix round. Depth and Nether
  TODOs do not block these packages.

## 2. Decisions and simplifications

User already confirmed during planning:

1. Ordinary world mobs may be pulled indefinitely while receiving damage.
   After **15 seconds without incoming damage**, they evade and return home.
   Remove the extra distance-from-last-hit test for these mobs. Bosses and
   location-bound guards retain their existing encounter/post bounds.
2. Strong ambient species appear only where the local difficulty supports their
   minimum level. Do not clamp them upward into easier bands. Update affected
   starter quests. Wildlife lookalike variants are selected per named zone;
   humanoid NPCs/guards may still share models.
3. Native minimap: terrain and own direction arrow only; other object/player
   dots hidden. Party/quest/trainer markers remain in the full atlas.

Explicit user requests needing no further product decision:

- Equip-slot-only weapons stay that way; improve explanations and skill icons.
- Six regional atlas views collectively cover the whole current world atlas,
  including capitals, frontiers and islands; small overlap is allowed.
- Trainer success/help copy; Cooking no longer offers Unlearn; other primary
  professions retain explicit destructive-action confirmation.
- Stable display tags use the existing 25/30-node hysteresis and NPC color.
- Actual level increase fills HP and mana; Warrior rage unchanged; gold burst.
- No death XP loss; excessive `/xp give` reaches 60 and discards excess.
- Pickaxes can dig loose soil slowly; shovels do it faster but cannot mine rock.
- Inventory guidance, clear hotbar row and visually selected buttons.
- Waiting can be dismissed to reach the game menu; preparation precedes creation.
- Faster reliable surface preparation; moving light from a held torch.

Scope reductions confirmed with the round Go:

- Guard healing is deferred: player-only healing, Renew, shields and threat
  cannot coherently be extended by changing one target predicate.
- Keep camp/rare encounter-owned actors on their existing home/slot lifecycle;
  only free-roaming world populations get unlimited damage-sustained pursuit.
  This exemption is explicitly approved.
- One level-up burst for a multi-level grant; no resurrection through XP, no
  refills on join, equipment changes or downward admin level changes.
- Clamp the shared XP setter to level-60 cumulative XP as well as `/xp give`,
  so normal rewards cannot build an invisible surplus at maximum level.
- Pickaxe loose-material time = twice the matching shovel time; leave current
  shovel timings, tool lifetime budgets and mining depth restrictions intact.
- Moving light covers the actually wielded torch only; no offhand lights or
  general luminous-item framework in this round. Aim for a staggered 1 Hz update.
- Preparation target is useful throughput without avoidable idle gaps, not an
  unconditional 100% CPU assertion. Disk/engine waits and shutdown responsiveness
  are legitimate. Do not change ETA smoothing or enable additional emerge threads.

## 3. Read-only findings informing the plan

| Feedback | Evidence and implication |
|---|---|
| Trainer confusion | `grug_jobs/trainers.lua:21,79` renders the same already-known status immediately after Learn. Confirmation already exists at lines 33–36. This is a UX correction, not evidence of shared player profession state. |
| Atlas clipping | `grug_map/atlas.lua:5–20` uses small outer-region crops; central world/fronts are not covered. `tools/r14_map/render_atlas.lua:9–14` duplicates the bounds. Both must use one geometry authority. |
| Stable tags | `grug_mobs/capital_displays.lua:86` sets a direct parent nametag, bypassing `grug_core/tag_carrier.lua`. Reuse managed carriers, no second distance loop. |
| Troll difficulty | `jungle_lynx.lua:29` declares minimum 10; `levels.lua:349–355` clamps local level upward. `spawn_policy.lua` accepts this habitat in Kapok without a minimum-level gate. This does not demonstrate reversed Throng bands. |
| Town safety | Existing `spawn_policy.lua:240` excludes the 148×148 start footprint from spawning; wandering/chasing into town is a separate path. Verify before changing settlement exclusion rules. |
| Two boars | Base and jungle variants accept different ground types within the same zone. The old per-biome policy is weaker than the requested per-zone policy. |
| Native minimap | Engine `doc/lua_api.md:9337–9385` supports permission/mode selection. Marker API is a global `show_on_minimap` boolean, not per-viewer icon data. `src/client/minimap.cpp:629–670` draws a local arrow and fixed remote dots. Client settings may suppress the map. |
| Evade | `grug_mobs/aggro.lua` combines chase-anchor distance and contact timeout; some contact writes are threat/taunt events, not actual damage. Guard/NPC combat needs explicit handling. |
| Skill images | `grug_abilities/init.lua:1859–1899` combines the weapon into the inventory icon AND uses its wield image. Separate those visual outputs while retaining skill authority and bow draw presentation. |
| Quest tool text | `grug_quests/ui.lua:14–16` uses the full item description, including durability lines. Use the concise item name for objectives, not a literal removal of two strings. |
| Preparation stalls | `grug_core/starts_preload.lua:129–159` scans 512 columns per 0.2-second dispatch and waits for tile selection before emerge; one request is pending at a time. This is a plausible idle-gap source, not yet a measured diagnosis of the user's server. |
| Pick/shovel report | Current pick capabilities are cracky/resource-only; pure dirt is crumbly. Verify final registered capabilities and stack overrides; do not infer the failure from the visible held icon. |

All paths above are relative to their owning mod unless fully qualified. Local
engine source is `reference_projects/luanti`. Do not move reference pins.

## 4. Packages, models and acceptance contracts

### A — Equipment explanations, trainers and inventory UX (Sol)

Feedback 1, 3, 12, 17. Independent reviewer: fresh Sol.

Ownership: `grug_inventory/ui.lua`, `pages.lua`, `grug_jobs/trainers.lua`,
`state.lua`, `ui.lua`, `grug_skills/page.lua`, `grug_classes/talents_ui.lua`,
`grug_quests/ui.lua` and, if needed, its HUD label formatting. Gear description
changes in `grug_gear` coordinated with TOOLS; no damage/equipment behavior change.

- Weapon tooltip and Character Weapon slot explicitly say: equip here, then use
  a combat skill from the hotbar. Give a brief throttled contextual hint on
  attempting to use a raw weapon. Do not auto-equip, block inventory storage,
  introduce modal tutorials or make raw hotbar weapons deal damage.
- After successful Learn, show an actual success message with Crafting/book
  guidance; later visits show known profession/progress/help without pretending
  another learning event occurred. Never show success after a rejected learn.
- Cooking has no Unlearn action, including forged UI submissions. Primary
  unlearning retains a clearly worded confirmation and cancel path; only that
  profession's progression is reset. Preserve player-local state and repair access.
- Crafting starts with a concise recipe-book prompt. Skills explains deletion,
  recovery, and one owned copy across inventory/crafting/bags, without implying
  that dropping deletes the entitlement or places an item on the ground.
- Highlight and label the top inventory row as Hotbar. Cover shared station/
  inventory layouts where practical without changing slot indices or geometry.
- Shared selected-button style uses colored border/tint, with a non-color cue
  such as a stronger border; remove selection `>` prefixes from Bags, Talents,
  atlas and other actual selection controls. Do not remove legitimate text arrows.
  B owns atlas page edits and consumes the shared visual convention.
- Quest objectives show concise tool names, not durability/stat lines. Worn
  qualifying tools remain accepted; do not change turn-in matching.

Checks: actual successful/rejected learn and confirmation callbacks, Cooking
forged unlearn refusal, two-player state isolation; concise quest labels with
worn-item acceptance unchanged. GUI pass covers all four classes and layouts.

### B — Atlas coverage and bounded native minimap (Sol)

Feedback 2, 7. Independent reviewer: fresh Sol.
Ownership: `grug_map/atlas.lua`, `page.lua`, related media, renderer and a small
native minimap initialization module. Shared styles come from A.

- Derive six views from a 3-column × 2-row coverage of the current world bounds,
  extending view edges for small overlap and keeping capitals wholly visible.
  Include world middle/fronts and outer islands. Use one shared bounds table for
  renderer and runtime markers. Keep map aspect correct; no stretched terrain.
- Re-render the existing authored atlas, not a new terrain map or fog of war.
  Keep live position/party/quest/trainer/home marker semantics, hover/click and
  closing-to-Character behavior. Keep each view reasonably useful as a zoom;
  larger coverage necessarily reduces its previous magnification.
- Default to a surface minimap mode on join; retain player V toggle and client
  permission to disable the feature. No forced radar/x-ray mode.
- **Approved minimap policy: terrain + own direction arrow only.** Disable
  other player/object minimap dots through their global visibility properties;
  preserve actual world/entity visibility and nametags. Full atlas retains party,
  trainer and quest markers. No proxy entities or custom HUD map workaround.

Checks: rectangle-union coverage and border cases; settlement/trainer positions
inside intended views; shared renderer/projection bounds and click identity.
Native GUI validates default-on, own direction, local toggle and chosen dots policy.

### C — Difficulty bands, wildlife variants and quest consistency (Sol)

Feedback 5, 6. Independent reviewer: Astra for spawn/quest integration.
Ownership: `grug_mobs/spawn_policy.lua`, species definitions/variant registration,
`levels.lua` only if needed; `grug_quests/content.lua`; relevant roster documents.
No mapgen writer or terrain/source geometry changes.

- Audit all six starts and three bands per zone, both factions, using the actual
  authoritative zone query and final spawn eligibility. Confirm the axial
  projection before touching it; currently species minimum clamping explains Lynx.
- Gate ordinary surface species by their declared natural minimum and local band.
  Keep depth, fixed-level bosses, guards and deliberately authored encounters out
  of this generic change. Do not leave starter areas without suitable enemies.
- One lookalike wildlife variant per named zone. Retain local Jungle/Plague Boar
  identity where suitable, with appropriate ground habitats covering that zone.
  Do not remove all boars from an accepted host surface or duplicate the density
  budget by replacing independent per-name caps mechanically.
- Produce a before/after zone→species/min-level table, including day/night rows.
  Keep total intended combat-mob density and R17 dispositions; no extra models.
- Audit all related kill/drop quests against the selected zone roster. The Troll
  starter Lynx objective must be achievable at the intended stage, using a fitting
  replacement target if necessary. Rewards/counts stay unless a concrete mismatch
  requires adjustment. All required drops retain a reasonable local source.
- Distinguish forbidden town spawning from later walking/chasing into town. Any
  additional safe-town AI behavior requires escalation, not an implicit rewrite.

Checks: small real-policy point set in all six starts/band boundaries, low-level
predator exclusion, correct-family distribution and quest reachability. No world
population sweep or density/PERF campaign.

### D — Damage-sustained ordinary-mob pursuit (Astra)

Feedback 8. Independent reviewer: fresh Astra.
Ownership: `grug_mobs/aggro.lua`, narrow hooks in mob/core combat and lifecycle.

- Free-roaming ordinary combat mobs remain engaged while taking effective HP
  damage from players or guards. On first aggro start the grace clock; every
  qualifying incoming hit refreshes it. A DoT tick that deals damage counts.
  Taunt/threat-only changes, misses and outgoing damage do not refresh it.
- After 15 seconds without incoming damage, reset/evade, clear encounter threat
  and existing tap state as today, heal as today, and return to original home.
  Preserve untouchable return and the 40-second teleport fallback. Do not move
  the permanent home to the latest hit position.
- Remove ordinary chase-anchor distance cancellation; inspect underlying engine/
  mobs_redo target validity and the existing 25/40/45 m checks so they do not
  silently preserve the reported reset. Keep only checks required for a valid
  available target; do not load/unload distant terrain to sustain combat.
- Before implementation, freeze an actor-policy table: ambient free-roam,
  camp-owned, rare-owned, bosses/retinue, fixed guards and explicit bespoke
  entities. Do not infer lifecycle from appearance or a generic monster flag.
- Boss encounter bounds/retinue reset and fixed guard post rules remain. The camp/rare exception is approved. No changes to boss
  projectile hit rules, rewards, scale or participant credit.
- Do not award player XP/loot merely because an NPC kept a fight active.

Checks: received player/guard damage sustains a long pull, outgoing attacks and
Taunt alone do not; timeout/home fallback; death/unload; boss and post invariants;
no duplicate camp/rare population caused by changing counting assumptions.

### E — Level-up feedback and forgiving XP (Sol)

Feedback 9, 14, 16. Independent reviewer: fresh Sol.
Ownership: `grug_xp/init.lua`, `grug_classes/stats.lua`, narrow resource callback
in `grug_abilities/init.lua`; sequence this last file before H's icon edits.

- Real upward transition recomputes final stats, fills living player's HP and
  mana to those new maxima, leaves rage unchanged and refreshes HUD once.
- One short gold/yellow particle burst per transition, including multilevel
  admin grants. No effect/refill on login, recalculation or level decrease.
- Remove all XP-on-death deductions/messages. Retain inventory/home/death flow
  and damage-event durability. No replacement penalty or extra death wear.
- `/xp give` saturates at level 60, discards overflow and reports actual granted
  amount; already-capped player succeeds with zero gain. Reject malformed and
  non-finite input cleanly. Approved shared setter clamp prevents hidden surplus.
- Remove obsolete PvP-only XP-loss exception requirements from living specs and
  BACKLOG WP9. Do not remove unrelated PvP attribution infrastructure.

Checks: HP/mana/rage after single/multiple level increases; no join refill or
XP resurrection; all death causes preserve XP; huge grant and level-60 no-op.

### F — Preparation waiting and character-creation order (Sol)

Feedback 15. Independent reviewer: fresh Sol.
Ownership: `grug_classes/selection.lua`, `grug_factions/init.lua` entry/display
and receive-fields gates. G owns scheduler and status producers.

- Waiting precedes faction→race→class selection. Guard both displayed pages and
  incoming submitted actions against incomplete preparation.
- Escape dismisses the waiting form; another Escape can open native game menu.
  Keep waiting movement/safety restrictions active. Progress updates must not
  immediately steal focus or reopen the dismissed form.
- On readiness, begin/continue selection. Existing complete characters resume
  without re-creation, inventory grant duplication or forced home teleport.
- Reopen the waiting/error form once when preparation enters failure, even if
  previously dismissed, so Retry is reachable. Do not reopen every progress tick
  while failed. Reconnect/partial selection/stale callbacks must not bypass the
  gate or permanently strand a player.
- Prefer native dismissal/menu behavior over a version-dependent disconnect API.

Checks: pending→ready with new/partial/complete characters, forged submissions,
disconnect/rejoin, dismissed UI and failure/retry. Native user test verifies Esc.

### G — Surface-preparation throughput (Astra)

Feedback 18. Independent reviewer: fresh Astra.
Ownership: `grug_core/starts_preload.lua`, preparation plan/source seams only as
necessary and a bounded diagnostic fixture. No unrelated writer optimization.

- First distinguish selection work, artificial scheduler sleeps, emerge work,
  callback wait, storage and failure/retry. Use short phase counters, not a broad
  profiler framework. CPU fluctuations alone do not prove deadlock.
- Prefer a bounded CPU-time scanning budget and decoupled UI notification cadence
  over a large queue/prefetch rewrite. If necessary, add only bounded lookahead
  after evidence shows it is useful. No recursive emerge from callbacks.
- Preserve conservative surface coverage (slopes/cliffs/content/visible water),
  fixed world-mode snapshot, ordered successful-prefix persistence, deterministic
  resume, retry/failure and prompt stop. Progress remains accepted tile-based %.
- Keep `num_emerge_threads=1`; no engine fork or multithreaded v7 assumption.
  Report useful work rate and unavoidable waiting rather than promise full use
  of every core. Do not optimize the intentionally accepted early ETA correction.
- No full-world generation run. Use tiny deterministic functional fixtures and a
  bounded native stop/resume run. Optional final throughput/ETA observation:
  **exactly once for 60–120 seconds**, then stop and report its limited meaning.
  Never repeat long observations during development or touch the user's worlds.

Checks: exact same selected coverage for representative flat/steep/coastal and
settlement columns, queue/callback sequencing, partial stop/resume, failures.
If source/planner output changes, exercise actual `r7_manifest.new` and
`planner.plan_slice` boundaries; do not claim a hand-built receipt proves them.

### H — Skill icon design and stable nametags (Astra art, Sol integration)

Feedback 4, 13. Independent reviewer: fresh Sol for code, fresh visual reviewer
(Astra or Sol) who did not choose/create the assets.

Split bounded ownership: H1 Astra selects/designs licensed icons and writes a
skill→icon manifest/contact sheet; H2 Sol integrates `grug_abilities` image
composition and `grug_mobs/capital_displays.lua` tag lifecycle. H2 waits for E's
resource callback commit, or root integrates their non-overlapping hunks once.

- Inventory/hotbar/Skills catalogue show a meaningful distinct action icon for
  each active class/talent ability across all four classes. Do not merely put the
  same weapon on differently colored backgrounds. Reuse suitable reference media
  first; generate missing raster assets only through the authorized image skill.
- Equipped weapon still supplies the in-hand/third-person appearance; bow draw
  stages, wear/cooldown display, tier appearance and offhand behavior remain.
  Empty weapon slot keeps honest empty/baseline presentation.
- No redesign of already accepted swords/axes/armor, mount icons or crop media.
  Passive talent art is outside this active-skill scope.
- Deliver before/after contact sheet at actual hotbar size, asset provenance and
  license records. Include normal and cooldown/charge states in visual review.
- Stable display parent nametag becomes empty; one managed carrier uses NPC
  lilac and existing 25/30 hysteresis/1-second observer pass. Reload/unload must
  not duplicate carriers; peaceful displays get no damaged-mob HP bar.

Checks: catalogue vs hotbar vs wield separation, actual bow charge, equipped
weapon replacement, unchanged stack-authority/wear; stable close/far observers.

### I — Held-torch moving light (Astra, complexity-gated)

Feedback 19. Independent reviewer: fresh Astra or Sol with lighting lens.
Ownership: isolated light owner plus minimal registration/dependency wiring.

- Torch held in main hand provides its ordinary light strength around a moving
  player. Scope excludes offhand, all other luminous items and dynamic shadows.
- Use stock-client server lighting. First verify a bounded approach against engine
  and an attributable upstream reference; do not assume the fake-torch guess is
  the upstream algorithm. Newer VoxeLibre source uses direct light manipulation;
  it is not in our pinned worktree, so record any separately inspected upstream
  revision explicitly and do not silently move the reference pin.
- Target roughly one update per player per second, staggered and change-driven,
  loaded local terrain only. Define overlapping-player lights, static-light
  preservation, switching item, teleport, leave, shutdown and same-world reload.
  No permanently glowing trails, node drops, griefing/protection bypass, map-wide
  scans or accidental removal of real torches/player blocks.
- **Stop condition:** if preserving/rebuilding overlapping ordinary light needs
  an extensive new lighting engine or expensive repeated VM scans, report the
  issue and defer this lane rather than expanding the whole round. Do not ship
  a visually plausible single-player proof as multiplayer-ready behavior.

Checks: two moving torch users, fixed torch nearby, darkness/water/solid boundaries,
leave/rejoin/reload and teleport. Small functional evidence only; no PERF fleet.

### J — Pickaxe/shovel material semantics (Sol)

Feedback 11. Independent reviewer: fresh Sol.
Ownership: `grug_materials/mining.lua`, `tools.lua`, `overrides.lua`, necessary
node groups and final-capability audit; no broad recipe/durability changes.

- Reproduce using final registered tools and representative exact dirt/gravel/
  sand/ash/stone/ore nodes; inspect per-stack overrides and mining-policy hooks.
- Shovel digs loose materials and never stone/ore/coal. Pick retains rock/resource
  tier/depth behavior and gains slower loose-material digging.
- Approved simple timing rule: pick loose-material duration is 2× same-material
  shovel, with current shovel times unchanged. Include Wood/Stone and six metals.
- Resolve multi-group nodes intentionally (engine chooses fastest matching cap),
  protect solid sandstone/ores from an accidental shovel route. Consistent shovel
  tier metadata is preferable to item-name special cases.
- Keep decided uses 30/60/300/600/1000/1500/2000/3000 and tool-only damage rules.

Checks: representative material×tool-class×tier matrix using final registrations,
depth/harvest denial, lifetime consumption and same-tier relative timing.

### Deferred — Healing friendly guards

Feedback 10. Approved explicit deferral; no implementation agent this round.
Record future Astra design task: entity HP authority, same-faction eligibility,
ray/ally fallback, Renew/other heal effects, shields, threat and unload identity.
Do not silently make only one Priest ability behave differently toward guards.

## 5. Parallel scheduling and ownership

Current runtime exposes four total slots (root plus three children). This is a
runtime limit, not a project policy limiting future rounds to three workers.
Queue lanes as slots free; no CLI workaround. If more native slots become
available, independent lanes may run concurrently within actual capacity.

Suggested launch sequence after Go:

1. G Astra preparation, D Astra evade, C Sol population/quests. Root freezes
   shared UI/icon interfaces, integrates decisions and keeps the ledger current.
2. As slots free: A Sol UX, E Sol XP, B Sol maps; H1 Astra art can run alongside
   code once its input manifest is frozen. Do not hold free slots unnecessarily.
3. F Sol waits only for G's status interface to be frozen, not full G completion.
   J Sol tools and I Astra light are independent. H2 Sol waits for E's shared
   ability file edit and H1 media. B adopts A's selected-control convention.
4. Schedule fresh independent reviewers per scope, reuse completed agents only
   for scopes they never authored. Final Astra documentation-drift review.

Each lane gets an isolated worktree/branch off the approved integration base and
an explicit file roster, interface contract, non-goals, test budget and stop
conditions. Root owns shared-file integration, living docs, BACKLOG/README
status consistency and final delivery. Do not claim this round completes larger
open WPs such as WP48 or the full tool-speed calibration.

## 6. Verification and delivery budget

Planning used read-only source inspection only: no code edits, game runs,
benchmarks, sync or installation. Planning notes are not runtime evidence.

After Go, every changed Lua file gets plain `tools/bin/luac51 -p`, SETGLOBAL
inspection and all five luanti-lua.md sweeps (also changed tools Lua explicitly).
Development checks use LuaJIT; no intermediate PUC execution. Keep tests focused
on changed contracts and multiplayer/lifecycle risks, not implementation mirrors.
At most seven independent Lua interpreter processes across all lanes, immutable
inputs and separate outputs, idle scheduling for worker fleets. No full-map or
historical population suite unless an actual new finding justifies escalation.

Frozen final integration gets one compact PUC-5.1 process and the identical
LuaJIT fixture with byte-identical canonical digest; one replacement pair only
if relevant final bytes change. Reviewers inspect logs/hashes, not duplicate
that PUC run. Native registration and targeted interaction/persistence checks
supplement mocks. User performs GUI acceptance; no claim of GUI testing by agents.

Independent review reports carry model, author/reviewer independence, findings,
fix rounds and elapsed time/unknown. Fix and re-review material findings before
merge. At delivery update living docs, BACKLOG/ROADMAP/README where affected,
completion/execution record and a short ordered playtest checklist; merge, sync
from main and push under standing authorization. Do not overwrite personal worlds.

## 7. Planning review

Independent native Astra planning review (`r18_world_planning`) found no missing
feedback item or blocking inconsistency. Two refinements were incorporated:
explicit actor categories before freezing evade scope, and one-time failure UI
reopening after dismissal. This is a plan review, not implementation acceptance.

## 8. Next user playtest, proposed order

1. Fresh join during preparation: Escape/menu and waiting before creation.
2. Warrior/Scout/Caster starter kit: weapon explanation, skill icons, correct held
   weapon; Cooking success and no Unlearn; primary confirmation/cancel.
3. Troll and other starts: suitable levels, one boar variant, achievable quests.
4. Ordinary long pull with repeated damage, then 15-second disengagement; boss
   and post guards remain bound. XP death unchanged and level-up refill/burst.
5. Six atlas regions, capitals and islands; native minimap policy; stable tags.
6. Dirt/gravel/rock with shovel vs pick; two players carrying torches, changing
   item and leaving, with no persistent light trails.


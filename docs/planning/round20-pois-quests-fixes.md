# Round 20 proposal: authored places, quest journeys and playtest fixes

Date: 2026-09-24. Coordinator: GPT-6 Astra.
Status: **approved and active; user round Go received 2026-09-24**.
Execution ledger: [Round 20 state](round20-state.md).
This proposal records the current request and distinguishes recommendations
from approved design. It does not supersede living design until accepted.

## Authority and execution

- User request: the playtest list supplied on 2026-09-24, plus answers recorded
  below. Keep this document self-contained; the attachment is not a runtime
  dependency.
- Current design: `../design/settlements.md`, `../design/world_zones.md`,
  `../design/quests.md`, `../design/inventory_equipment.md`,
  `../design/items_crafting.md`, `../design/combat_stats.md`.
- Work inventory: `../../BACKLOG.md`, `work-package-scopes.md` (WP8/9/13).
- Process: `../process/wp-workflow.md`, `../process/agent-model-policy.md`,
  `../research/luanti-lua.md`, `../technical/module-guide.md`.
- Root coordinates native agents. GPT-5.6 Sol handles bounded implementation;
  GPT-6 Astra handles creative direction, geometry/integration and combat state.
  No same-provider CLI, Claude delegation, engine fork or required client mod.
- Available session concurrency is four agents including root, i.e. three
  simultaneous workers. This is a tool limit, not a desired project-wide cap.
  Queue independent lanes and reuse slots as tasks finish.
- Fresh-server development remains in force. Same-version save/reload matters;
  no legacy readers, migrations, aliases or conversion jobs.

## Scope boundaries

The round combines the twelve reported fixes with authored POI coverage and
quest pacing/content. Housing, geographic PvP flags, moving warfront armies,
new king/dragon encounter mechanics, renewable mining resources and Nether
content are excluded. Enemy-guard quests use existing faction combat and
contribution credit, not player-kill objectives or a new PvP rules engine.

Large terrain shaping and replacement of flat stone reservations are deferred.
POIs should visually belong to their surrounding zone now; authoring must not
depend on today's blank stone platform being the intended final environment.
No world-preparation throughput or engine scheduling changes.

## Confirmed scope decisions (user follow-up, 2026-09-24)

1. Keep existing armor ranks: Warrior cloth/leather/metal, Scout cloth/leather,
   Mage/Priest cloth. Adopt the requested weapon permissions below. Use
   a common dagger family with Str/Dex/Int enchant choices, no automatic
   class-dependent conversion of an item's enchantments.
2. Cover all 70 remaining POI art acceptance slots, with natural
   exceptions to the building minimum for battlefields, arenas and rare pads.
   Target approximately 240 total quests as an authoring budget, not a quota
   to fill with repeated errands. Separate cook questgivers; king finale later.
3. Use universal `Usable by: ...` tooltip text plus specific equip refusal,
   instead of viewer-dependent item metadata colors in shared inventories.

Additional minor recommendations to accept with the plan: Shore Crab uses the
ordinary immediate death/removal presentation; generic offhands keep current
permissions for this round (no silent new shield/book/quiver class gate).

These decisions and the complete round are approved for implementation.
The user additionally requests consistent click behavior and broken-equipment
appearance. The final input contract below resolves harvesting and controls.

## F1 — Suffocation and NPC interaction (Sol)

Observed implementation: `grug_core/suffocation.lua` considers any walkable
non-liquid head node suffocating. Thin doors/windows/shutters therefore qualify.
Use the local VoxeLibre `mcl_playerplus/init.lua` reference: full regular
collision/node geometry, an explicit suffocation opt-out, and opaque-solid
classification. Translate to Grudgelands definitions; do not blindly require
a foreign group that our stone nodes might lack. Keep normal terrain damage,
liquid exclusions, creation stasis and noclip behavior.

Avoid detailed intersection math and per-door name lists. Inspect node defaults
and explicit geometry once; test full stone vs door/pane/shutter, including
open state. The mobs_redo path already filters geometry; the reported NPC
damage is unconfirmed and must be traced before changing all NPC health logic.

Ability right-click fallback currently raycasts nodes without objects when the
native pointed target is empty. Make interaction stop at the first valid object
instead of reaching a door behind it. Preserve intended NPC interaction, node
interaction when unobstructed, range and protection; merely suppressing the
door while leaving the NPC unusable does not satisfy acceptance.

Ownership: core suffocation. F5 owns shared ability right-click routing and
implements the NPC-before-door correction; no parallel writers to that seam.

## F2 — Inventory, party and native minimap UX (Sol)

- Restore native minimap visibility of **all players**, including enemies;
  retain suppression of ordinary entity points. This does not add quest/NPC
  symbols. Luanti's native minimap is client/engine functionality, not our atlas.
- Add `[Lv X]` in party HUD, member list, invitation list and online invitation
  candidates. Include offline members using their last known level where
  needed; avoid a new world-wide offline player database solely for invitations.
- Investigate inventory-key focus handling, using actual affected pages.
  Text entry must retain normal typing. A client-consumed key is unavailable
  to server Lua: do not promise a universal override. Correct unnecessary
  focusable text widgets/default focus where feasible. If a native widget
  still swallows the binding, report the specific limitation and retain Escape
  rather than adding a client modification. Do not force users to bind literal
  `i`; respect their configured inventory key.

Ownership: `grug_map/minimap.lua`, owning party/page modules and formspec focus.
No atlas overhaul, new map markers or party rules.

## F3 — Equipment permissions, enchant pools and wear display (Astra)

Existing armor permission already allows lower armor ranks. Existing weapons
explicitly have no class gate; replace that rule only after plan acceptance.

| Class | Armor recommendation | Requested weapon families |
|---|---|---|
| Warrior | Metal, leather, cloth | Sword, dagger, Battle Axe |
| Scout | Leather, cloth | Bow, sword, dagger |
| Mage | Cloth | Staff, wand, dagger |
| Priest | Cloth | Staff, wand, dagger |

These are all six current main-hand weapon families. Woodcutting axes remain
tools. Shields, spellbooks and quivers are separate offhand families, not
forgotten main-hand weapons. Existing hand-count and item-level rules remain.
Apply one permission authority across drag/equip and relevant server grant
paths, preserving starter loadouts and explicit refusal reasons.

Proposed weapon pools, fixed on the item family, never its current wearer:

| Family | Legal ordinary stats |
|---|---|
| Battle Axe | Str, attack speed, Crit, HP |
| Sword | Str, Dex, attack speed, Crit, HP, Mana |
| Dagger | Str, Dex, Int, attack speed, Crit, HP, Mana |
| Bow | Dex, attack/draw speed, Crit, HP, Mana |
| Staff, wand | Int, Crit, HP, Mana |

Preserve existing armor/offhand/trinket pools, deterministic enchant values,
one prefix/one suffix, tier applicability and no duplicate stat. A shared sword
or dagger can carry a stat irrelevant to one permitted wearer; permissions do
not dynamically strip effects or rewrite the item. Dex remains the Scout
attribute path, including shared melee families. Crit is not class-exclusive;
this request does not automatically add Crit to every armor pool.

Check caster dagger skill/stat behavior explicitly: allowing equip must not
quietly reclassify all daggers as caster weapons or boost melee users. If
caster-dagger use requires a new scaling design, escalate before implementing
that extension. Preserve profession ownership (Weaponsmith melee, Woodcarver
caster/bow), unless user chooses a different dagger design.

Use stable permission text on every item and a clear rejected-equip message.
Shared stack metadata is not a per-viewer tooltip store; avoid racing red/white
descriptions when two different classes inspect one shared station inventory.

Show `Durability: remaining / maximum` for pickaxes, shovels, woodcutting axes,
hoes, weapons and armor. Derive normalized durability units from the actual wear
authority, lifetime and fractional remainder. Display whole remaining units
(round a positive fractional unit up); at broken show zero. Fixed-cost events
retain their exact integer budget. This is not a promise of the exact number
of future blocks: digging cost can depend on the node/tool combination.
Refresh after wear, repair and normal inventory/description rebuilds without
per-frame scans or losing enchants/quality/tooltips. Keep durability values and
Creative behavior unchanged. Include wear-bearing offhands for consistency.

Armor is currently registered as craftitems while native wear bars are drawn
only for tools (`luanti/src/gui/drawItemStack.cpp`). Prefer native tool-type
registration for nonstackable wearable items if capability inspection confirms
it is safe; do not grant digging or weapon-slot eligibility. Retain repairable
broken gear. A custom image-overlay system is not the default solution.

### Broken equipment stays visually equipped (additional request)

At zero durability retain the weapon/tool/armor appearance and mark it broken
with dark jagged cracks, plus explicit `Broken` tooltip text. Remove the broken
appearance after repair. Do not introduce progressive cosmetic damage tiers.

The engine already provides `^[cracko:...]`, restricted to opaque texture pixels
(`reference_projects/luanti/doc/lua_api.md`, Texture modifiers); the game ships
`mods/BASE/default/textures/crack_anylength.png`. Prefer this existing effect
over generating new media or a variant registry for every weapon/tier.

The visual bug comes from `grug_inventory.get_equipped_weapon/offhand` returning
nil for broken items while skill skins and third-person wielding use those
combat accessors. Add/read a cosmetic slot source that includes broken items;
do not weaken combat getters or re-enable broken stats/capabilities.

Apply the same broken-state predicate to inventory art, first-person wield art,
skill weapon skin, third-person held art, and the affected armor slot's texture
layer. Armor cracks belong on the armor layer before composition, never on the
whole player skin. Third-person currently often resolves item names only; carry
the bounded cosmetic broken flag/image through the visual cache key rather
than expecting stack metadata alone to change every observer's model.

Preserve original images, alpha silhouettes, quality/enchantment names and
modifiers. Repeated refreshes must not stack cracks; repair restores the current
base/enchant appearance. Updates occur on break/repair/equip, not every frame.
Skill wear bars remain cooldown/charge displays, not weapon durability bars.
Broken tools/weapons remain unusable as before; this is a presentation change,
not a redesign of which spells can function without a usable weapon.

## F4 — Combat presentation and health-state fixes (Astra)

- Shore Crab death frames 200..300 at speed 50 explain its two-second corpse.
  Proposed presentation: ordinary immediate removal, without changing loot,
  XP or kill-credit timing.
- Add visible particles on successful Warrior stun for players, guards and
  susceptible mobs at shared stun application seams. Respect immunity and
  avoid duplicating Charge's existing burst; no new stun balance/duration.
- Bandit has no healing skill in its current definition. Trace leash-reset
  healing and idle recovery before deciding the cause. No healing during a
  live fight merely because one callback temporarily lacks a target. Preserve
  genuine evade/reset and out-of-combat recovery without immortal enemies.
  Cover ordinary pursuit and place-bound camp mob reset separately.
- Investigate reported actor stacking. mobs_redo already disables object
  collisions to prevent physical stacking. Identify whether this is true
  support, jump behavior, spawn placement or visual overlap; do not blindly
  turn collisions back on. Prefer a local correction. General crowd steering,
  pairwise separation searches or pathfinding redesign require escalation.

Ownership: mobs wrappers/aggro/idle health and shared stun application. Delegate
small cosmetic edits only with non-overlapping ownership.

## F5 — Consistent click intent (Astra, design agreed; implementation pending)

The authoritative current proposal for this lane is the separate
[agreed input contract](round20-input-contract-proposal.md).
It replaces the withdrawn RMB-dig suggestion and the earlier prohibition on
held combat retargeting into digging. User intent: held LMB performs contextual
combat or empty-hand digging, immediate abilities where unambiguous, and
click/hold arbitration only where a usable skill competes with block digging.

Repeat policy, one pickup per press and initial timing are now agreed.
Healing/shields use current eligible crosshair ally, otherwise self; remove
the old remembered-ally fallback. Loose explicitly documents LMB Strike and
RMB draw/release. The user authorized round implementation on 2026-09-24.
Native RMB interaction, food hold and bow draw remain separate contextual
paths. Broken-equipment presentation is owned by F3 above.

Ownership: shared abilities input routing, scout draw and food hold lifecycle;
coordinate with F3 skin changes and F4 stun effects in shared ability files.
No required client mod or engine fork. This is a substantive input lane, not a
one-line pointability fix; escalate any need for a parallel digging engine.

## Q1 — Quest visibility and journey mechanics (Sol)

Current `grug_quests/state.lua:npc_quests` makes a successor visible when its
prerequisite is active. Require completed prerequisites for visibility; merely
accepting or finishing objectives must not reveal dependent follow-ups before
turn-in. Keep accepted quests visible in their own log/turn-in context.

After prerequisites and race/faction eligibility are satisfied, an insufficient
level leaves the quest visible with the actual required level. Quest text and
UI explain all applicable requirements; do not expose unrelated faction/race
quests just to list their locks. NPC symbols and atlas markers use the same
visibility authority as the dialog.

Use existing kill/item-turn-in semantics for ordinary work. Add/reuse explicit
talk-to-NPC completion for travel handoffs: no hidden item, secondary kills or
arrival-radius objective. Arrival and conversation complete the handoff, with
ordinary reward/turn-in flow. This is the sole proposed objective extension.
The named destination NPC completes and accepts the handoff; no return trip
to the originating NPC is required.
Current 20-active cap, abandonment, persistence and contribution-based kill
credit remain; no party-specific XP or quest-sharing rules.

## P1/Q2 — Creative content design (Astra), then implementation lanes

Current authored roster: 12 civic compositions (six starts/six capitals) and
18 regional compositions. The 100-anchor roster is not 100 empty towns.

| Remaining art acceptance | Count | Proposed treatment |
|---|---:|---|
| Villages | 6 | 4–6 varied buildings, shared social space, zone details |
| Outposts | 18 | 2–4 buildings, visible purpose and local defenses |
| Frontier bandit camps | 6 | 2–4 buildings/shelters and occupation traces |
| Mining camps | 6 | 2–4 structures, mine entrance/workplace; no renewable system |
| Mirefolk camps | 4 | 2–4 culturally distinct structures |
| Apex camps | 2 | At least two structures, reserve future resource sockets |
| Clash sites | 16 | Static battlefield ruins/positions; no battle simulation |
| Dragon arenas | 2 | Open arena/environmental storytelling; existing bosses |
| Rare-route pads | 10 | Natural encounter scenes, tracks/remains/ruin details |

Total: 70 acceptance slots. These may already have actors/anchors and must not
receive duplicate bosses/guards. Building minimum applies to inhabited camps
and settlements, not natural arenas. Existing 18 regional POIs get a targeted
coherence pass, not blanket replacement; retain user-approved improvements.

Each site needs an authored card before building: anchor ID/name, zone/faction,
level, purpose, silhouette/palette, asymmetrical layout, building count,
1–2 secondary features, approach/sightlines, NPC/quest sockets, bounds and
protection. Do not substitute rotated copies of one four-house square.
Reuse architectural components, not identical whole settlements. Consider
zone vegetation, soil, materials and future terrain blending. No bespoke
runtime AI or random building placement to achieve cosmetic variety.

Freeze NPC IDs, positions and quest roles jointly before parallel authoring.
Preserve shipwright plots/display boats at Whitebridge Shire and Whispering
Reedlands; implementing their travel/teaching service is outside this round.
Respect decided reservation bounds and the recorded `bandit_frontier` 24-vs-16
core discrepancy. Inspect the placement pipeline before promising that a
building cannot affect surrounding terrain. If the correction requires broad
terrain changes, escalate rather than silently resizing the world planner.

Quest content budget proposal: approximately 240 total, including revision of
all 102 current quests. A possible allocation of the 138 additions is twelve
cook quests, twelve capital introductions, 96 regional quests and eighteen
travel handoffs. Treat allocation as an editorial budget, not a numeric gate.
Review actual level/faction routes, reachable sources and NPC availability;
cut filler rather than adding copies solely to meet a count.

Starter flow: an initial bundle of roughly three independent local quests,
split between an existing hunt/adventure giver and a nearby cook with an oven.
Examples are kills, an item/tool delivery and local provisions. Individual
turn-ins can open follow-ups, while several compatible tasks share an outing.
Avoid repeatedly sending players back to the same mob solely for larger counts.
Cooking-related quests should not require having learned Cooking unless the
quest explicitly teaches that profession. Item delivery does not falsely claim
to prove that the player crafted or gathered the item personally.

Capitals and many regional POIs add appropriate bundles and travel leads.
Include the already-decided level-10 capital/service introduction; do not
replace it with a trip to another small village or defer all capital content
to level 20. Later capital provision quests may have higher target levels.
Travel handoffs lead to named NPCs in named locations and do nothing else.
Enemy-guard tasks use existing guards at reachable frontier targets; no
ordinary civilian kills, king finale or player-kill requirements in this
proposal. No quest depends on future warfront troop simulation, expansion
Nether content, unshipped deep resources or unfinished boss mechanics.
Keep current reward formulas unless a concrete progression defect is found;
more quest opportunities already change leveling pace.

## Parallel sequencing and ownership

1. After decisions and Go, root folds accepted rules into their design owners
   and creates the package/branch ledger. No competing overrides in old docs.
2. First wave: Astra P1/Q2 creative atlas; Sol F1/F2 bounded fixes; Astra F3
   equipment contract/implementation. Root freezes shared interfaces and NPC IDs.
3. Next free slot: Astra F4 health/stacking investigation. Sol Q1 implements
   quest mechanics independently of content text.
   Astra F5 owns input changes after the shared ability-file interfaces with
   F3/F4 are frozen. Food changes may be delegated to Sol under that contract.
4. After authored cards: Sol implements civic/settlement POI content; another
   Sol lane implements regional quests; Astra handles encounter-site art and
   geometry integration. Split POI files/modules by family or geographic batch,
   with one designated owner for shared registration/manifests and core builders.
5. Each non-trivial lane receives fresh independent review. Prefer Sol review
   of Astra work and Astra review of Sol work; critical combat/geometry gets
   Astra review where needed. Reviewers did not author the reviewed changes.
6. Root integrates, runs bounded final acceptance, updates living design,
   WP8/9/13 remainders, README/ROADMAP/STATUS and a playtest receipt. Remaining
   encounters/PvP/economy work does not become delivered through static art.
   Merge only reviewed work, sync from main; remote push is a separate action.

## Deliberately small validation budget

No tests or engine runs are part of this planning task. During implementation,
cheap mandatory Lua-5.1 parsing/SETGLOBAL/five sweeps run on changed Lua.
Consolidate runtime KATs at the round's frozen final candidate, as requested;
do not repeatedly launch old mapgen suites for each building/content batch.
Only a concrete defect justifies a narrow intermediate reproduction under JIT.

Final scope:
- Fast whole-catalog validation: references, IDs, quest cycles/unreachable
  prerequisites, levels/targets/items, counts, legal equipment/pool matrices.
- Compact behavior fixtures for suffocation, NPC-before-door interaction,
  actual equip rejection/wear/repair and combat recovery, plus quest visibility
  and travel completion. Test meaningful boundaries, not copied implementation.
  Include one press/one action for NPC-vs-food/bow, held/released/repeated input,
  slot-switch cancellation, harvest protection, and broken/repair cosmetic
  transitions with combat still disabled. No new broad input test fleet.
- POI validation: all authored bounds/NPC sockets; representative actual
  `r7_manifest.new` and `planner.plan_slice` consumers for each changed
  construction family, including boundary/cross-slice placement. No fake
  hand-built receipt offered as proof of real integration.
- One compact final PUC-5.1 micro-KAT process and the identical LuaJIT fixture,
  matching canonical digest. Large composition/projection samples use JIT
  only. Reviewers reuse evidence instead of repeating runs.
- At most one bounded isolated headless smoke if needed for engine integration;
  no complete-world generation, seed fleet, population census, broad PERF suite
  or personal-world mutation. Propose a five-minute smoke ceiling; stop and
  diagnose rather than extend a hanging run. No invented timing guarantee for
  gates; report unexpectedly expensive checks before widening them.
- Visual acceptance: representative per-family/per-biome views and selected
  player-route walkthrough; user GUI playtest remains final visual authority.

Escalate material complexity immediately: engine-only focus limitations,
dynamic per-viewer item tooltips, caster-dagger scaling, general crowd AI,
reservation/terrain redesign, unshipped quest targets, or tests that expand
into a mapgen certification round. Continue independent lanes while that
specific decision is pending.

## Planning receipt

Read-only preflights: native Astra POI/quest audit; native Sol defect audit.
No game implementation, synchronization, runtime testing or push performed.
Approval answers and implementation status will be added here before execution.

Follow-up: user confirmed all three scope/equipment/tooltip decisions and
explicitly requires ordinary hand digging with selected skills. Added F5
input contract and F3 broken-item visuals; full round Go received 2026-09-24.
Implementation authorization comes from the subsequent explicit round Go.

Independent proposal review: GPT-5.6 Sol PASS, no High/Medium findings. Two
non-blocking clarifications incorporated: travel handoff turn-in occurs at the
destination, and durability display uses defined units. Follow-up review caught
one Medium wording defect in the earlier remaining-event promise for tools;
corrected to normalized durability units, not a future block-count prediction.
Implementing model: GPT-6 Astra (plan only); reviewing model: GPT-5.6 Sol;
Critical/High findings: 0/0; corrective rounds: 0; elapsed time: unknown.

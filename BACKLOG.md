# Backlog — Work Packages

High-level goals: [ROADMAP.md](ROADMAP.md). This document breaks them down
into **work packages (WPs)**, each doable in a fresh session/context
window. Rules:

- One WP = one coherent, testable increment with commit(s).
- Before starting: read AGENTS.md; check for blocking `TODO-*.md` design
  files; skim the relevant briefings in [docs/research/](docs/research/).
- Design questions are settled in `TODO-<topic>.md` files first and then
  folded into [docs/design/](docs/design/) — WPs implement the design,
  they don't invent it (see AGENTS.md "Documentation layers").
- After finishing: update the status here (✅ + one-liner of what was
  built), keep the ROADMAP checkboxes in sync, run
  `tools/sync_to_luanti.sh`, commit.
- Insights that future sessions need belong in AGENTS.md (conventions) or
  docs/ (details) — not just in the chat.

## Phase 1 (MVP)

| WP | Title | Status | Depends on |
|----|-------|--------|------------|
| WP0 | Foundation: skeleton, BASE, mobs_redo, wob_core, wob_factions, wob_xp | ✅ | — |
| WP1 | Starter-zone mobs: boar + zombie, XP on kill, loot drops | ✅ (runtime test by user pending) | WP0 |
| WP2 | Territory mapgen: north/south, race regions per faction, difficulty gradient, capitals | ✅ engine biomes (v7 + min_pos/max_pos) in `wob_mapgen`; zone/difficulty API + is_protected in `wob_core` (runtime test by user pending) | WP0 |
| WP3 | Classes: Warrior/Mage/Priest, selection dialog, stats via level pipeline | ✅ `wob_classes`: class+race registry, creation flow faction→race→class, attribute/HP formulas via level pipeline, /char /class /race commands (runtime test pending) | WP0 |
| WP4 | Abilities: 2–4 per class, cooldowns, mana/resource HUD (text line per classes.md §1) | ✅ `wob_abilities`: 3 abilities/class as hotbar items (wear = cooldown), mana/rage + HUD, damage pipeline (crit/dodge) in `wob_core` (runtime test pending; spec: `docs/design/classes.md`; kit tuning → WP19) | WP3 |
| WP5 | Loot & enchantments: class items with roll ranges, elite variants | open | WP1, WP3 |
| WP6 | Faction mobs & mob feel: guards, outposts, mob tiers by distance + DEPTH, elite mobs (scale/tint + 2 s telegraph), one behavior verb per family, named rares with faction broadcast, boar/zombie retune incl. speed-to-spec + soft de-aggro (25 m), taunt force duration, R4 ore respawn, nametags (level+HP), con-color target frame, gray = no XP; **player-tag drop rule** (loot only with player involvement, 60 s expiry, NPC drops only in PvP; carries the Leatherworker loot hook); nature-mob on-sight aggro vs players AND NPCs; **pathfinding quality pass is a blocker of this WP, not polish** (also carries the high-density target, world.md §8) | open (spec: `docs/design/combat_stats.md` §3/§6, world.md §1/§8; mob roster: `docs/design/biomes_mobs.md`) | WP1, WP2 |
| WP7 | Money & traders: copper/silver/gold currency (`docs/design/economy.md`), buy-all-drops, selling UI | open | WP1 |
| WP8 | Quest framework: quest log, kill/gather goals, quest-giver NPCs, min_level per quest | open (story frame: `docs/design/story.md`) | WP1, WP7 |
| WP9 | Mandatory questlines: PvP quests (border guards), elite quests, level gates | open | WP6, WP8 |
| WP10 | Professions: 2 free mains (Herbalism, Alchemist, Blacksmith, Leatherworker, Tailor, Gem Hunter) + universal Cooking/First Aid; recipe-unlock system (craft_predict veto + workbench proximity), recipe book UI, gathering split, Leatherworker ×5-leather loot hook | open (spec: `docs/design/professions.md`, `inventory_equipment.md` §4) | WP7 |
| WP11 | Skill trees: 2 trees × 5 talents × 3 ranks per class, 1 point per 3 levels (20/30 fillable), 9 numeric talents + 1 capstone per tree = NEW active main skill (e.g. Priest: Renew), respec for gold at the class trainer | open (spec: `docs/design/progression.md` §2) | WP3, WP4 |
| WP12 | Global map with fog of war (adapt the mcl_maps approach), shows discovered waypoints | open | WP2, WP17 |
| WP13 | Starter/world content: 3 race capitals per continent (center = faction seat; schematics, per-race build sets, elven treehouses), patch villages/settlements, flavor camps, spawn immunity | open (spec: world.md §3/§9, `docs/design/biomes_mobs.md`) | WP2, WP18 |
| WP14 | Offhand & carried light: wob_offhand (mcl_offhand pattern), shields, 2H rule, torch light radius (profiled) | open (spec: `docs/design/combat_stats.md` §7) | WP3 |
| WP15 | Character screen & bags: sfinv pages (Character/Bags), equipment slots + stat recompute, bag system | ✅ `wob_inventory`: Character homepage (stats, model, 7 slots incl. reserved trinkets), 4-slot bag system (runtime test pending) | WP3 |
| WP16 | Guilds: registry, manager NPC, roles, guild bank, /g chat | open (spec: `docs/design/guilds.md`) | WP7 |
| WP17 | Travel: waypoint nodes, visit-unlock, travel formspec (map UI docks on with WP12), Home Stone + /unstuck | open (spec: `docs/design/world.md` §6) | WP2 |
| WP18 | Continent mapgen rework: two ocean-separated continents (soft coasts, 3000×1600 default via wob_core constants), remove mountain wall, per-race spawn points at the 3 race capitals (safe-core belt), radial mob-level field with war-coast cap (+ `guard_level_at` inverse field for WP6), civilization-gradient biome layer (settled race biomes core/inner, shared nature biomes outward), coastal-ocean guarantee, R3 ocean build lock, deep-sea guard mobs | open (spec: `docs/design/world.md` §1/§2/§2b/§8; biome catalog: `docs/design/biomes_mobs.md`; replaces WP2's wall + z-rings) | WP2 |
| WP19 | Combat feel & kit tuning: global cooldown (1 s), soft target lock (~8 s), Mighty Blow as rage dump, Hamstring, Fireball mana-limited, Frost Nova pivot (12 s + slow), Power Word: Shield (absorb via hp modifier), visible race passives | ✅ GCD 1 s (silent gate, no wear churn) + soft target lock (8 s, separate enemy/ally slots, range+LOS re-checks) in `wob_abilities`; kits per classes.md tables (Mighty Blow 25 rage dump, NEW Hamstring w/ mob slow via `wob_mobs.slow` halving speeds, Fireball 8 mana GCD-only, Frost Nova 12 s root→slow, PW:S absorb via `wob_core.set_absorb` in the central hp modifier; Renew `talent_gated` for WP11); race passives via `wob_classes` perk registry (dwarf fall −20%, troll OOC regen — mana today, WP21 reuses perk; undead zombie night truce via `_wob_ignore_player` veto patch in mobs api.lua; orc +1 rage/hit taken, elf +5 m item-meta range, human quest-XP hook latent until WP8). Runtime test pending | WP4 |
| WP20 | Party system: /party (content sized for 2–3), tap rules (first damager's party tags), shared XP/kill/quest credit within 60 m, member HP frames HUD, group loot basics | open (spec: classes.md balance constraints) | WP4 |
| WP21 | Recovery & rest: out-of-combat HP regen (0.5%/s), food recovery, innkeeper NPC (rested XP + Home Stone rebind), NPC anchor/respawn insurance | open (spec: `docs/design/combat_stats.md` §5, progression.md §1) | WP1 |
| WP22 | Durability & repair: effect-loss at 0 durability (items never destroyed), NPC repair for gold, tier-scaled costs | open (spec: `docs/design/economy.md` §4) | WP5, WP7 |
| WP23 | Apex world bosses: one dragon POI per continent (stationary arena fight, telegraphs, hoard + respawn timer); enemy-dragon raid trophy and per-region apex kits follow (Phase 2) | open (spec: `docs/design/world.md` §4b) | WP6 |

### Readiness (2026-08-06)

**Ready now** (no design blockers, deps done): WP11 (talents — spec
progression.md §2), WP14 (offhand), WP17 (travel), WP20 (party),
WP21 (recovery/innkeeper).

**Blocked, by what**:
- WP18 is design-unblocked (biomes_mobs.md decided) — ready once picked up; WP6 waits on WP18
- WP5, WP7, WP10 are design-unblocked (`docs/design/items_crafting.md`
  decided); WP22 additionally needs WP5 gear to exist
- WP8, WP9 ← `progression.md` §4 (quest structure/level gates)
- WP12 ← WP17; WP13 ← WP18 + biomes; WP16 ← WP7; WP23 ← WP6
- Housing WP (unscheduled) ← `TODO-design-housing.md`

Notes from the decided world design (`docs/design/world.md`):
- Race choice at character creation: ✅ shipped with WP3 (race dialog
  between faction and class; race perks follow with WP7/WP10).
- Build/dig restrictions (destructibility rules §2) land in `wob_core`
  alongside WP2.
- Housing implementation is not yet scheduled as a WP — the layout is
  still open in `TODO-design-housing.md` (ocean/island model, world.md
  §5). The Home Stone is covered by WP17.

### WP details (acceptance criteria)

**WP1 — Starter-zone mobs**: Boar (day, meadow) and zombie (night) spawn
and attack; kills grant XP depending on the mob; drops (meat/leather and
zombie trash loot as future vendor goods). Models/textures from VoxeLibre
`mobs_mc` (GPL, attribution). Helper `wob_mobs.register_mob` extends
mobs_redo with `_wob_faction`, `_wob_xp_reward` and XP awarding via
`on_death` (basis for faction targeting via `do_custom`).

**WP2 — Territory mapgen** (✅ 2026-08-06): Engine biomes on mapgen v7,
each confined to its territory/race region via the biome definition's
`min_pos`/`max_pos` cuboids (decision: C++-fast, ores/decorations/dungeons
keep working; a custom `on_generated` pass would have had to reimplement
all of that). `wob_mapgen` registers 3 race biomes per faction (+ ocean
variants, borderland, underground), its own ores/decorations, and a small
`register_on_generated` pass for the spawn camp platforms (cobble, at
z=±200) and the mountain wall at x=±2000. `wob_core` gained
`territory_at/zone_at/difficulty_at/mob_level_at` (ring anchors per
combat_stats.md §3) and the central `core.is_protected` override (R1–R3;
faction resolved via `wob_core.get_player_faction`, overridden by
wob_factions). Deferred: R4 ore respawn → with outposts/mining zones
(WP6/WP13); housing frontier is fully locked until housing plots ship.

**WP3 — Classes** (✅ 2026-08-06): `wob_classes` with class AND race
registry (races per world.md §7, race perks hook for WP7/WP10). Creation
flow: faction → race → class, chained via
`wob_factions.register_on_faction_chosen`, every step mandatory/final,
stored in player meta. Stats per combat_stats.md §1/§2:
`get_attributes/get_max_hp/get_max_mana/get_melee_bonus/
get_spell_power_bonus/get_crit_chance/get_dodge_chance` as the single
source of truth for WP4's damage pipeline; hp_max applied via the level
pipeline (heal-on-levelup only for real level-ups — join deltas must not
heal, properties reset every session). Commands: `/char`, `/class`,
`/race`.

**WP15 — Character screen & bags** (✅ 2026-08-06): `wob_inventory`.
Equipment and bags are player-inventory lists (auto-persisted).
Character sfinv page = homepage (nav reordered Character/Bags/Crafting):
stat sheet, 3D model preview, slots Head/Chest/Legs/Feet/Offhand +
2 reserved trinket slots — items declare their slot via group
(`wob_equip_head` etc., accepted once WP5/WP14 items exist). Bags:
4 slots, `bagslots` group (8/16/24) sizes the content list; a bag only
leaves its slot when empty (a shrinking list would destroy items); no
bags inside bags; no recipes yet (Tailor WP10 / vendor WP7, test via
`/give`). **Engine gotcha documented in code**: multiple
`register_allow_player_inventory_action` callbacks combine as
OR-with-short-circuit — return nil when unconcerned, a number swallows
all later callbacks.

**WP4 — Abilities** (✅ 2026-08-06): Design decided in
`docs/design/classes.md` (kits, costs, cooldowns — numbers live THERE).
`wob_abilities`: abilities are indestructible hotbar tools (item `range` =
targeting range, wear bar = running cooldown, tinted-orb icons via
`^[multiply` on one CC0 texture); kit auto-granted/purged on join and via
the new `wob_classes.register_on_class_chosen`. Resources are runtime-only
(mana full on join/respawn, rage 0); regen/decay + cooldown display run in
one 0.5 s globalstep. `wob_core/combat.lua` = damage pipeline:
`deal_ability_damage` (crit ×1.5, applies via `object:punch` so armor/
knockback/XP-on-death keep working), `heal_player`, central dodge roll as
hp-change modifier, `mark_in_combat/in_combat` (5 s window, reused by
WP6 leash + recovery), threat **stubs** (`add_threat`/`add_heal_threat` —
WP6 fills them; Taunt already forces targets via mobs_redo
`do_attack(player, force)`). Crit/dodge stubs in wob_core are overridden
by wob_classes (get_player_faction pattern). **mobs_redo gotcha
(documented in wob_mobs)**: a truthy return from a mob's `do_punch`
CANCELS the punch (the "return false to cancel" comment in api.lua is
wrong — precedence); wrappers must return nil. Deferred: melee bonus/crit
on auto-attacks ride on WP5's stack-meta tool-caps override; ability
sounds/icons → Phase 3.

**Playtest fixes (2026-08-06,** after the first WP1/WP2/WP15 runtime
tests): **(a)** Mob spawn coverage — the WP1 whitelists only knew
`dirt_with_grass`, so the whole Horde side (savanna/blight/jungle tops)
and the dwarf hills had NO spawns; now all race-region surfaces spawn
boar/zombie, rates raised (boar chance 6000→2000/aoc 4, zombie 3000/aoc 3)
and ring-gated (borderland/starter/midlands) via the new
`_wob_spawn_zones` + `mobs:spawn_abm_check` override in wob_mobs (WP6
extends this to level tiers). **(b)** Camp platforms are terrain-adaptive:
first generated mapchunk near a camp takes the max mapgen heightmap within
40 nodes, persists the platform y in wob_core mod storage (fixed y=8 had
buried camps inside hills → players spawned in an inescapable pit); spawn/
respawn go through `wob_core.get_spawn_pos()` and re-read after emerge.
**(c)** v7 terrain offsets raised (`mgv7_np_terrain_base` 4→14,
`terrain_alt` 4→10, override_meta=true) → contiguous landmasses with lakes
instead of starter archipelagos; **existing worlds get chunk seams — test
on a fresh world**. **(d)** WP15 character preview fed `""` to `model[]`
when rendered before player_api set the model (client "Mesh not found"
spam) — empty properties now fall back to character.b3d/png. **(e)**
Vendoring policy decided → VENDOR.md (upstream commits + patch inventory,
`-- WOB PATCH` markers), AGENTS.md section.

(Further WP details are added once the respective WP comes up.)

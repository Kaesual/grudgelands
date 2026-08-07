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
  built), keep the ROADMAP checkboxes and the README's "Current State"
  section in sync, run `tools/sync_to_luanti.sh`, commit.
- Insights that future sessions need belong in AGENTS.md (conventions) or
  docs/ (details) — not just in the chat.

## Phase 1 (MVP)

| WP | Title | Status | Depends on |
|----|-------|--------|------------|
| WP0 | Foundation: skeleton, BASE, mobs_redo, grug_core, grug_factions, grug_xp | ✅ | — |
| WP1 | Starter-zone mobs: boar + zombie, XP on kill, loot drops | ✅ (runtime test by user pending) | WP0 |
| WP2 | Territory mapgen: north/south, race regions per faction, difficulty gradient, capitals | ✅ engine biomes (v7 + min_pos/max_pos) in `grug_mapgen`; zone/difficulty API + is_protected in `grug_core` (runtime test by user pending) | WP0 |
| WP3 | Classes: Warrior/Mage/Priest, selection dialog, stats via level pipeline | ✅ `grug_classes`: class+race registry, creation flow faction→race→class, attribute/HP formulas via level pipeline, /char /class /race commands (runtime test pending) | WP0 |
| WP4 | Abilities: 2–4 per class, cooldowns, mana/resource HUD (text line per classes.md §1) | ✅ `grug_abilities`: 3 abilities/class as hotbar items (wear = cooldown), mana/rage + HUD, damage pipeline (crit/dodge) in `grug_core` (runtime test pending; spec: `docs/design/classes.md`; kit tuning → WP19) | WP3 |
| WP5 | Loot & enchantments: class items with roll ranges, elite variants | open | WP1, WP3 |
| WP6 | Faction mobs & mob feel: guards, outposts, mob tiers by distance + DEPTH, elite mobs (scale/tint + 2 s telegraph), one behavior verb per family, named rares with faction broadcast, boar/zombie retune incl. speed-to-spec + soft de-aggro (25 m), taunt force duration, R4 ore respawn, nametags (level+HP), con-color target frame, gray = no XP; **player-tag drop rule** (loot only with player involvement, 60 s expiry, NPC drops only in PvP; carries the Leatherworker loot hook); nature-mob on-sight aggro vs players AND NPCs; **pathfinding quality pass is a blocker of this WP, not polish** (also carries the high-density target, world.md §8) | ✅ the full `docs/design/biomes_mobs.md` roster in `grug_mobs` — **38 registered mobs in 40 spawn rows**, 10 named rares (§3.3's 9 rows, Bonerattle ×2), guards, camps. Architecture: **level/tier engine** (`levels.lua` — HP/dmg/XP/armor derived from `mob_level_at`/`guard_level_at` + tier multipliers, defs never hand-set them; elite ×1.6 gold, rare ×2 violet, global nametags, con-color target frame at 20 m, gray = no XP); **threat table** in `grug_core/combat.lua` (damage-as-threat, 120 % hysteresis, 40 m validity, heal threat, real taunt) + **leash/evade** (40 m drag from the chase anchor, 15 s contact, snap-home, 45 m give-up, 25 m soft de-aggro); **verb library** (`verbs.lua`: pack, stalker/rush, ambush, webs, poison, damage aura, camp swarm, arrows); **elite/rare telegraph** (4 s first engagement, 10 s cadence, 90° cone at reach + 1.5 m, LOS required); **named-rare spawner** (2–4 h respawn, patrol routes, faction broadcast); **faction guards + 24 deterministic outposts + hourly patrol legs**, POI protection registry (`grug_core.add_poi`), guard banners on the capital platforms; **12 deterministic bandit camps** + mirefolk camps on node timers; **player-tag drop rule** via an api.lua patch; **R4 ore respawn** (depleted-vein placeholder, 15–30 min); **pathfinding/density/perf pass** (four api.lua fixes + the budget audit in `docs/research/wp6_spawn_budget.md`) and a 4-reviewer gate. Runtime test pending | WP1, WP2 |
| WP7 | Money & traders: copper/silver/gold currency (`docs/design/economy.md`), buy-all-drops, selling UI | open | WP1 |
| WP8 | Quest framework: quest log, kill/gather goals, quest-giver NPCs, min_level per quest | open (story frame: `docs/design/story.md`) | WP1, WP7 |
| WP9 | Mandatory questlines: PvP quests (border guards), elite quests, level gates | open | WP6, WP8 |
| WP10 | Professions: 2 free mains (Herbalism, Alchemist, Blacksmith, Leatherworker, Tailor, Gem Hunter) + universal Cooking/First Aid; recipe-unlock system (craft_predict veto + workbench proximity), recipe book UI, gathering split, Leatherworker ×5-leather loot hook | open (spec: `docs/design/professions.md`, `inventory_equipment.md` §4) | WP7 |
| WP11 | Skill trees: 2 trees × 5 talents × 3 ranks per class, 1 point per 3 levels (20/30 fillable), 9 numeric talents + 1 capstone per tree = NEW active main skill (e.g. Priest: Renew), respec for gold at the class trainer | open (spec: `docs/design/progression.md` §2) | WP3, WP4 |
| WP12 | Global map with fog of war (adapt the mcl_maps approach), shows discovered waypoints | open | WP2, WP17 |
| WP13 | Starter/world content: 3 race capitals per continent (center = faction seat; schematics, per-race build sets, elven treehouses), patch villages/settlements, flavor camps, spawn immunity | open (spec: world.md §2 protection zones, §3/§9, `docs/design/biomes_mobs.md`) | WP2, WP18 |
| WP14 | Offhand & carried light: grug_offhand (mcl_offhand pattern), shields, 2H rule, torch light radius (profiled) | open (spec: `docs/design/combat_stats.md` §7) | WP3 |
| WP15 | Character screen & bags: sfinv pages (Character/Bags), equipment slots + stat recompute, bag system | ✅ `grug_inventory`: Character homepage (stats, model, 7 slots incl. reserved trinkets), 4-slot bag system (runtime test pending) | WP3 |
| WP16 | Guilds: registry, manager NPC, roles, guild bank, /g chat | open (spec: `docs/design/guilds.md`) | WP7 |
| WP17 | Travel: waypoint nodes, visit-unlock, travel formspec (map UI docks on with WP12), Home Stone + /unstuck | open (spec: `docs/design/world.md` §6) | WP2 |
| WP18 | Continent mapgen rework: two ocean-separated continents (soft coasts, 3000×1600 default via grug_core constants), remove mountain wall, per-race spawn points at the 3 race capitals (safe-core belt), radial mob-level field with war-coast cap (+ `guard_level_at` inverse field for WP6), civilization-gradient biome layer (settled race biomes core/inner, shared nature biomes outward), coastal-ocean guarantee, R3 ocean build lock, deep-sea guard mobs | ✅ two-continent geometry + radial level/guard fields in `grug_core` (wall and z-rings gone), continent ocean mask + 6 race-capital platforms in `grug_mapgen/structures.lua`, 17 mirrored biomes per biomes_mobs.md §1.3 with new `grug_nodes`/`grug_trees` content, Kraken Guard in the open sea (**needs a fresh world**; runtime test pending) | WP2 |
| WP19 | Combat feel & kit tuning: global cooldown (1 s), soft target lock (~8 s), Mighty Blow as rage dump, Hamstring, Fireball mana-limited, Frost Nova pivot (12 s + slow), Power Word: Shield (absorb via hp modifier), visible race passives | ✅ GCD 1 s (silent gate, no wear churn) + soft target lock (8 s, separate enemy/ally slots, range+LOS re-checks) in `grug_abilities`; kits per classes.md tables (Mighty Blow 25 rage dump, NEW Hamstring w/ mob slow via `grug_mobs.slow` halving speeds, Fireball 8 mana GCD-only, Frost Nova 12 s root→slow, PW:S absorb via `grug_core.set_absorb` in the central hp modifier; Renew `talent_gated` for WP11); race passives via `grug_classes` perk registry (dwarf fall −20%, troll OOC regen — mana today, WP21 reuses perk; undead zombie night truce via `_grug_ignore_player` veto patch in mobs api.lua; orc +1 rage/hit taken, elf +5 m item-meta range, human quest-XP hook latent until WP8). Runtime test pending | WP4 |
| WP20 | Party system: /party (content sized for 2–3), tap rules (first damager's party tags), shared XP/kill/quest credit within 60 m, member HP frames HUD, group loot basics | open (spec: classes.md balance constraints) | WP4 |
| WP21 | Recovery & rest: out-of-combat HP regen (0.5%/s), food recovery, innkeeper NPC (rested XP + Home Stone rebind), NPC anchor/respawn insurance | open (spec: `docs/design/combat_stats.md` §5, progression.md §1) | WP1 |
| WP22 | Durability & repair: effect-loss at 0 durability (items never destroyed), NPC repair for gold, tier-scaled costs | open (spec: `docs/design/economy.md` §4) | WP5, WP7 |
| WP23 | Apex world bosses: one dragon POI per continent (stationary arena fight, telegraphs, hoard + respawn timer); enemy-dragon raid trophy and per-region apex kits follow (Phase 2) | open (spec: `docs/design/world.md` §4b) | WP6 |

### Readiness (2026-08-07)

**Ready now** (no design blockers, deps done): WP11 (talents — spec
progression.md §2), WP13 (structures — mapgen/biomes ship, and WP6's
outpost/camp anchors + POI registry are waiting for real structures),
WP14 (offhand), WP17 (travel), WP20 (party), WP21 (recovery/innkeeper),
**WP23** (apex bosses — WP6 ✅ shipped the elite/rare tier, the
telegraph mechanic the boss scales up, and the POI protection registry
a lair needs).

**Blocked, by what**:
- WP5, WP7, WP10 are design-unblocked (`docs/design/items_crafting.md`
  decided); WP22 additionally needs WP5 gear to exist
- WP8 ← `progression.md` §4 (quest structure/level gates); **WP9** is
  free of its WP6 dependency (guards, outposts and the war-coast roster
  ship) and now waits only on WP8 + that same §4
- WP12 ← WP17; WP16 ← WP7
- Housing WP (unscheduled) ← `TODO-design-housing.md`

Notes from the decided world design (`docs/design/world.md`):
- Race choice at character creation: ✅ shipped with WP3 (race dialog
  between faction and class; race perks follow with WP7/WP10).
- Build/dig restrictions (destructibility rules §2) land in `grug_core`
  alongside WP2.
- Housing implementation is not yet scheduled as a WP — the layout is
  still open in `TODO-design-housing.md` (ocean/island model, world.md
  §5). The Home Stone is covered by WP17.

### WP details (acceptance criteria)

**WP1 — Starter-zone mobs**: Boar (day, meadow) and zombie (night) spawn
and attack; kills grant XP depending on the mob; drops (meat/leather and
zombie trash loot as future vendor goods). Models/textures from VoxeLibre
`mobs_mc` (GPL, attribution). Helper `grug_mobs.register_mob` extends
mobs_redo with `_grug_faction`, `_grug_xp_reward` and XP awarding via
`on_death` (basis for faction targeting via `do_custom`).

**WP2 — Territory mapgen** (✅ 2026-08-06): Engine biomes on mapgen v7,
each confined to its territory/race region via the biome definition's
`min_pos`/`max_pos` cuboids (decision: C++-fast, ores/decorations/dungeons
keep working; a custom `on_generated` pass would have had to reimplement
all of that). `grug_mapgen` registers 3 race biomes per faction (+ ocean
variants, borderland, underground), its own ores/decorations, and a small
`register_on_generated` pass for the spawn camp platforms (cobble, at
z=±200) and the mountain wall at x=±2000. `grug_core` gained
`territory_at/zone_at/difficulty_at/mob_level_at` (ring anchors per
combat_stats.md §3) and the central `core.is_protected` override (R1–R3;
faction resolved via `grug_core.get_player_faction`, overridden by
grug_factions). Deferred: R4 ore respawn → with outposts/mining zones
(WP6/WP13); housing frontier is fully locked until housing plots ship.

**WP18 — Continent mapgen rework** (✅ 2026-08-06): the world is now two
mirrored continent rectangles (`grug_core.CONTINENT_X_HALF` 1500,
`CONTINENT_Z_MIN` 100, `CONTINENT_Z_MAX` 1700 — 3000×1600 each, strait
along z=0). **Continent mask decision**: keep engine biomes on v7 and cut
the coastline afterwards — a post-generation VoxelManip pass in
`grug_mapgen/structures.lua` caps and floods every column outside the
rectangle ("the terrain generates, but it MUST be water", world.md §2b),
so all of v7's biomes/ores/decorations/dungeons keep working (a custom
terrain generator would have had to reimplement them, the WP2 argument
again). The coast noise insets the rectangle by 0..150 nodes INWARD only,
which guarantees the 200-node strait by construction; 60-node quadratic
taper, seaward shelf W−6..W−16, carved tops re-sanded near water level,
and a chunk-box fast path so inland and deep chunks cost nothing. The
mountain wall (`|x| = 2000`) and the z-ring model are deleted.
`grug_core` fields: `territory_at` → accord/throng/ocean; `zone_at` →
underground/ocean/strait/war_coast/coast/core/inner/outer (the
`_grug_spawn_zones` vocabulary); `mob_level_at` = radial elliptical field
around the faction seat (anchors n 0/0.30/0.55/0.90/1.0 → level
1/10/25/45/60) with the war-coast cap 20–30, strait cap 5, depth axis
(combat_stats.md §3) and nil on the open/coastal sea surface; NEW
`guard_level_at` (inverse field, 20..70, ≥ local mob level +5 — WP6
consumes it) and `open_sea_at` (beyond `OCEAN_COASTAL_WIDTH` 1500). Six
race capitals (`grug_core.capitals`, x = −550/0/550 at z = ±900, the
central one is the faction seat) get the terrain-adaptive camp platform
(median height, persisted per race) and are the per-race spawn/respawn
points via `get_spawn_pos(faction, race)`; the race dialog now teleports,
because faction join happens before the race is known. Protection: **R3
is the whole ocean** (replaces WP2's borderland and housing-frontier
rules), camp zones are the six capitals. Biome layer per biomes_mobs.md
§1.3: 17 registrations — the 13 band biomes are authored once in Throng
coordinates and registered mirrored at z=0, swamp/beach/ocean/underground
are shared (a biome name exists only once) — wide cuboid overlaps as the
patch mosaic, climate noise (`mg_biome_np_heat`/`np_humidity` offset 50,
scale 35) so the extreme points are reachable; decorations are trees + ground cover only (herbs/food →
WP10). New **ITEMS modpack**: `grug_nodes` (signature tops blight_dirt /
bone-, forest-, silver-litter, mesa_clay, mud, bone_pile — they exist for
the spawn-whitelist trick) and `grug_trees` (silverwood, gravewood).
Deep sea got its deterrent: **Kraken Guard** L100 (no drops, no XP),
gated by the new generic `_grug_spawn_check` hook in grug_mobs, assets
vendored from VoxeLibre. Deferred: mud walk slow-down (marker group
`mud = 1` only), the §4 spawn-parameter retune and the full mob roster →
WP6; real capital structures and the §2 war-coast battlefield overlay
(broken carts, bone piles, burnt patches) → WP13. **Existing worlds are
incompatible — the mask, the biomes and the platform anchors all changed:
test on a FRESH world.** The user's runtime test produced two follow-up
fix commits: floating tree canopies over the ocean (decoration overflow in
the emerged shell, `a7ef34c`) and the spawn platforms — the platform height
now comes from `core.get_spawn_level` at the anchor (−2 for the engine's
dust allowance), resolved lazily in `grug_core.get_camp_platform_y` and
persisted, with a footprint heightmap median in `grug_mapgen` only as the
fallback for the many positions mgv7 calls "unsuitable"; a heightmap-only
decision is chunk-order-dependent and could deadlock. The POI protection
was reshaped to "footprint only, from 30 nodes below the platform upward"
per world.md §2 (`grug_core.POI_PROTECT_DEPTH` replaces
`CAMP_PROTECT_RADIUS`). The remaining spawn-safety questions (liquid
sabotage next to the platform, enclosed-pit detection, own-faction
griefing) moved to `TODO-design-spawn-safety.md`.

**WP6 — Faction mobs & mob feel** (✅ 2026-08-07): the whole
`docs/design/biomes_mobs.md` roster plus the combat-feel layer, in
`grug_mobs` (38 registered mobs, 40 spawn rows, 10 named rares) with the
threat half in `grug_core/combat.lua`, R4 in `grug_nodes/ore_respawn.lua`
and the outpost/camp anchors in `grug_core` + `grug_mapgen/structures.lua`.

*Architecture worth remembering* (the pattern-level rules moved to
AGENTS.md "Mobs"): a **level/tier engine** owns HP/damage/XP/armor — a
def that hand-sets them is overridden, `_grug_fixed_level` is the one
exception; **runtime field installation** because mobs_redo copies only
an explicit def-field whitelist onto the entity; **countdowns tick in
`do_custom`**, never `core.after`; the **chase model** (45 m give-up /
25 m soft de-aggro / 40 m drag from the chase anchor / 15 s contact /
evade snap-home); `aoc` is **per entity NAME** in a 128-node sphere.
Vendored `mobs_redo` carries **16 `GRUG PATCH` sites in `api.lua`**
(inventory in VENDOR.md). Spawn calibration audit:
`docs/research/wp6_spawn_budget.md` — measured peaks Σaoc **16 day /
12 night** against the ~14 the rows were sized for, the target density
is met at the hotspots and not in the median cell.

*Deviations from the catalog* (all folded back into the design docs):
- **Jungle Lynx instead of Raptor** — the §8.2 fallback was executed
  (paleotest media unverifiable per file); same verb, same drops,
  `raptor_claw` item id kept.
- **Shore Crab + Reef Lurker still deferred** (§8.3, no licensed model);
  the beach cells run on the Gull alone.
- **Crocodile: one speed 4.4**, no 5.0-in-water bonus (mobs_redo rewrites
  velocities from `standing_in` and would fight our speed-restore
  bookkeeping) and **mud-only spawns** — "water at mud" is not
  expressible, the ABM `neighbors` list is an OR set; `floats` delivers
  the lurking instead.
- **Ram substitutes heavy leather 1/4** for the critter light-leather
  slot; the **Dust Hare** rides the settled hare row, so no badlands
  critter shipped.
- **Bog Ooze aura is a flat 2** — the one hand-written damage number in
  the roster (its melee is level-scaled as usual).
- **`visual_size` corrections** per the T5 mesh-scale rule (rendered mesh
  must match its own collisionbox) touched most vendored models —
  **flagged for the runtime test: this is the thing most likely to look
  wrong in-world.**
- **Sounds deferred WP-wide**: no audio was imported in T4, so no mob has
  a `sounds` table and the telegraph growl is a TODO — one future pass
  for the whole roster.

*Carry-overs*:
- **WP13**: the settlement pass owns the patch-driven camps/villages, the
  real outpost STRUCTURES (WP6 ships anchors, a banner node and the
  guards standing on them) and the war-coast battlefield decorations.
- **WP10**: the Leatherworker ×5 hook is wired (`register_drop_hook`,
  `grug_leather` group) but needs a special case for **`mobs:leather`** —
  the vendored item cannot carry our group.
- **WP20**: tap rules must fix XP attribution (today the LETHAL hit gets
  the kill XP, not the first damager's party) and replace the MVP heal
  threat group (healer + heal target) with real party membership.
- **WP7**: bandit **copper-coin drops** (no coin ITEM exists yet) and
  guard PvP loot (`drops = {}` today).
- **WP16**: the ore-respawn **guild-claim exception** is a reserved slot
  in the dig hook.
- **PvP work package** (with the war-coast PvP quests, WP9-adjacent):
  port the 2026-08-07 melee auto-attack pipeline (cadence gate, Str,
  crit — combat_stats §2) to **player-vs-player punches**. PvP melee
  still runs the engine's raw tflp scaling, i.e. a held button deals a
  permanent 0 with weapons below bronze — the exact defect the mob
  pipeline fixed.

*Accepted caveats* (known, deliberately not fixed in WP6):
- **Dual `physics_override` ownership**: `grug_mobs/verbs.lua` (webs) and
  `grug_abilities/kits.lua` (Hamstring/Frost Nova in PvP) each keep their
  own player-speed record and each restore to 1 — overlapping effects can
  end early. Both windows ≤ 7 s; the fix is one shared owner in
  `grug_core`, out of scope here.
- **The telegraph only fires in melee** — a ranged elite kept at distance
  never winds up (deliberate: it must not slam empty air).
- **Camp head-count blind spots**: a camp counts members within
  `radius + 16`, so a member dragged further out reads as dead and the
  camp refills behind it. The evade snap-home closes the common case;
  a determined puller can still inflate a camp temporarily.

**WP3 — Classes** (✅ 2026-08-06): `grug_classes` with class AND race
registry (races per world.md §7, race perks hook for WP7/WP10). Creation
flow: faction → race → class, chained via
`grug_factions.register_on_faction_chosen`, every step mandatory/final,
stored in player meta. Stats per combat_stats.md §1/§2:
`get_attributes/get_max_hp/get_max_mana/get_melee_bonus/
get_spell_power_bonus/get_crit_chance/get_dodge_chance` as the single
source of truth for WP4's damage pipeline; hp_max applied via the level
pipeline (heal-on-levelup only for real level-ups — join deltas must not
heal, properties reset every session). Commands: `/char`, `/class`,
`/race`.

**WP15 — Character screen & bags** (✅ 2026-08-06): `grug_inventory`.
Equipment and bags are player-inventory lists (auto-persisted).
Character sfinv page = homepage (nav reordered Character/Bags/Crafting):
stat sheet, 3D model preview, slots Head/Chest/Legs/Feet/Offhand +
2 reserved trinket slots — items declare their slot via group
(`grug_equip_head` etc., accepted once WP5/WP14 items exist). Bags:
4 slots, `bagslots` group (8/16/24) sizes the content list; a bag only
leaves its slot when empty (a shrinking list would destroy items); no
bags inside bags; no recipes yet (Tailor WP10 / vendor WP7, test via
`/give`). **Engine gotcha documented in code**: multiple
`register_allow_player_inventory_action` callbacks combine as
OR-with-short-circuit — return nil when unconcerned, a number swallows
all later callbacks.

**WP4 — Abilities** (✅ 2026-08-06): Design decided in
`docs/design/classes.md` (kits, costs, cooldowns — numbers live THERE).
`grug_abilities`: abilities are indestructible hotbar tools (item `range` =
targeting range, wear bar = running cooldown, tinted-orb icons via
`^[multiply` on one CC0 texture); kit auto-granted/purged on join and via
the new `grug_classes.register_on_class_chosen`. Resources are runtime-only
(mana full on join/respawn, rage 0); regen/decay + cooldown display run in
one 0.5 s globalstep. `grug_core/combat.lua` = damage pipeline:
`deal_ability_damage` (crit ×1.5, applies via `object:punch` so armor/
knockback/XP-on-death keep working), `heal_player`, central dodge roll as
hp-change modifier, `mark_in_combat/in_combat` (5 s window, reused by
WP6 leash + recovery), threat **stubs** (`add_threat`/`add_heal_threat` —
WP6 fills them; Taunt already forces targets via mobs_redo
`do_attack(player, force)`). Crit/dodge stubs in grug_core are overridden
by grug_classes (get_player_faction pattern). **mobs_redo gotcha
(documented in grug_mobs)**: a truthy return from a mob's `do_punch`
CANCELS the punch (the "return false to cancel" comment in api.lua is
wrong — precedence); wrappers must return nil. Deferred: melee bonus/crit
on auto-attacks ride on WP5's stack-meta tool-caps override; ability
sounds/icons → Phase 3.

**Playtest fixes (2026-08-06,** after the first WP1/WP2/WP15 runtime
tests): **(a)** Mob spawn coverage — the WP1 whitelists only knew
`dirt_with_grass`, so the whole Throng side (savanna/blight/jungle tops)
and the dwarf hills had NO spawns; now all race-region surfaces spawn
boar/zombie, rates raised (boar chance 6000→2000/aoc 4, zombie 3000/aoc 3)
and ring-gated (borderland/starter/midlands) via the new
`_grug_spawn_zones` + `mobs:spawn_abm_check` override in grug_mobs (WP6
extends this to level tiers). **(b)** Camp platforms are terrain-adaptive:
first generated mapchunk near a camp takes the max mapgen heightmap within
40 nodes, persists the platform y in grug_core mod storage (fixed y=8 had
buried camps inside hills → players spawned in an inescapable pit); spawn/
respawn go through `grug_core.get_spawn_pos()` and re-read after emerge.
**(c)** v7 terrain offsets raised (`mgv7_np_terrain_base` 4→14,
`terrain_alt` 4→10, override_meta=true) → contiguous landmasses with lakes
instead of starter archipelagos; **existing worlds get chunk seams — test
on a fresh world**. **(d)** WP15 character preview fed `""` to `model[]`
when rendered before player_api set the model (client "Mesh not found"
spam) — empty properties now fall back to character.b3d/png. **(e)**
Vendoring policy decided → VENDOR.md (upstream commits + patch inventory,
`-- GRUG PATCH` markers), AGENTS.md section.

(Further WP details are added once the respective WP comes up.)

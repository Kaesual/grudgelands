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
| WP4 | Abilities: 2–4 per class, cooldowns, mana/resource as HUD bar | open | WP3 |
| WP5 | Loot & enchantments: class items with roll ranges, elite variants | open | WP1, WP3 |
| WP6 | Faction mobs: guards, outposts, mob tiers by distance, elite mobs; nametags (level+HP), con-color target frame, gray = no XP | open (spec: `docs/design/combat_stats.md` §3/§6) | WP1, WP2 |
| WP7 | Gold & traders: currency, buy-all-drops, selling UI | open | WP1 |
| WP8 | Quest framework: quest log, kill/gather goals, quest-giver NPCs | open | WP1, WP7 |
| WP9 | Mandatory questlines: PvP quests (border guards), elite quests, level gates | open | WP6, WP8 |
| WP10 | Jobs: Herbalism, Alchemist, Blacksmith, Gem Hunter; max 2 per player | open | WP7 |
| WP11 | Skill trees: 2 trees/class of ~5 talents, talent points, formspec UI | open | WP3, WP4 |
| WP12 | Global map with fog of war (adapt the mcl_maps approach) | open | WP2 |
| WP13 | Starter/world content: capital & camp structures (schematics), race villages, spawn immunity | open | WP2 |
| WP14 | Offhand & carried light: wob_offhand (mcl_offhand pattern), shields, 2H rule, torch light radius (profiled) | open (spec: `docs/design/combat_stats.md` §7) | WP3 |

Notes from the decided world design (`docs/design/world.md`):
- Race choice at character creation: ✅ shipped with WP3 (race dialog
  between faction and class; race perks follow with WP7/WP10).
- Build/dig restrictions (destructibility rules §2) land in `wob_core`
  alongside WP2.
- Housing (frontier plots, §5) and the Home Stone (§6) are not yet
  scheduled as WPs — add them once WP2 stands (housing zone needs the
  territory layout).

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

(Further WP details are added once the respective WP comes up.)

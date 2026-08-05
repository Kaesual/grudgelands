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
| WP0 | Foundation: skeleton, BASE, mobs_redo, wow_core, wow_factions, wow_xp | ✅ | — |
| WP1 | Starter-zone mobs: boar + zombie, XP on kill, loot drops | ✅ (runtime test by user pending) | WP0 |
| WP2 | Territory mapgen: north/south, race regions per faction, difficulty gradient, capitals | open (spec: `docs/design/world.md`) | WP0 |
| WP3 | Classes: Warrior/Mage/Priest, selection dialog, stats via level pipeline | open | WP0 |
| WP4 | Abilities: 2–4 per class, cooldowns, mana/resource as HUD bar | open | WP3 |
| WP5 | Loot & enchantments: class items with roll ranges, elite variants | open | WP1, WP3 |
| WP6 | Faction mobs: guards, outposts, mob tiers by distance, elite mobs | open | WP1, WP2 |
| WP7 | Gold & traders: currency, buy-all-drops, selling UI | open | WP1 |
| WP8 | Quest framework: quest log, kill/gather goals, quest-giver NPCs | open | WP1, WP7 |
| WP9 | Mandatory questlines: PvP quests (border guards), elite quests, level gates | open | WP6, WP8 |
| WP10 | Jobs: Herbalism, Alchemist, Blacksmith, Gem Hunter; max 2 per player | open | WP7 |
| WP11 | Skill trees: 2 trees/class of ~5 talents, talent points, formspec UI | open | WP3, WP4 |
| WP12 | Global map with fog of war (adapt the mcl_maps approach) | open | WP2 |
| WP13 | Starter/world content: capital & camp structures (schematics), race villages, spawn immunity | open | WP2 |

Notes from the decided world design (`docs/design/world.md`):
- Race choice at character creation adds a selection step (implement with
  WP3's dialog flow or as a small WP of its own).
- Build/dig restrictions (destructibility rules §2) land in `wow_core`
  alongside WP2.
- Housing (frontier plots, §5) and the Home Stone (§6) are not yet
  scheduled as WPs — add them once WP2 stands (housing zone needs the
  territory layout).

### WP details (acceptance criteria)

**WP1 — Starter-zone mobs**: Boar (day, meadow) and zombie (night) spawn
and attack; kills grant XP depending on the mob; drops (meat/leather and
zombie trash loot as future vendor goods). Models/textures from VoxeLibre
`mobs_mc` (GPL, attribution). Helper `wow_mobs.register_mob` extends
mobs_redo with `_wow_faction`, `_wow_xp_reward` and XP awarding via
`on_death` (basis for faction targeting via `do_custom`).

**WP2 — Territory mapgen**: New world: only Horde biomes north of z=+64,
only Alliance biomes south of z=−64, neutral borderland in between; each
territory has ≥2 distinguishable (race-flavored) biomes; distance function
`wow_core.difficulty_at(pos)` (0=border … 1=heartland) for mob tiers;
walkable camp platform at both spawns. Zone/ring layout, soft east–west
border and race regions per `docs/design/world.md` §1/§7; destructibility
rules §2 (central `core.is_protected` override in wow_core) belong in
this WP. Decision needed: engine biomes (v7 + biome registration) vs. a
custom `on_generated` pass (LotT style) — the recommendation will be
worked out in WP2, criteria in docs/research/ (mind the mapgen env).

**WP3 — Classes**: After the faction choice comes the class choice (same
dialog flow, mandatory); class in player meta; HP/base damage scale per
level via `wow_xp.register_on_level_change`; class registry in
`wow_classes` with room for abilities (WP4) and skill trees (WP11).

(Further WP details are added once the respective WP comes up.)

# Research: Weapons, Armor & Class Equipment

Date: 2026-08-06 · Target: GPLv3+ code, per-file attributed media (no NC/ND).

## Summary

For **visible armor** the established pattern is texture layering on the player model:
the model has extra UV-mapped texture slots (skin / armor / wielditem), and equipping
armor swaps the armor texture in. Three implementations were reviewed:

1. **3d_armor** (stu / minetest-mods) — the reference implementation, entity-free since
   it composites textures directly onto `player_api`'s model slots. Code **LGPL-2.1**,
   media **CC BY-SA 3.0**. LGPLv2.1 §3 explicitly permits converting the code to
   "GPL version 2 **or later**", so **forking just the visual-layering part into our
   GPLv3+ game is permitted** (keep copyright headers; texture derivatives must stay
   CC BY-SA + attribution). Its damage/`armor groups` logic is separable — the layering
   lives in `armor:set_player_armor()` / texture compositing and can be lifted alone.
2. **VoxeLibre `mcl_armor`** (local: `reference_projects/VoxeLibre/mods/ITEMS/mcl_armor/`)
   — code **GPLv3+** (whole game), cleanest modern API (`api.lua`, documented in
   `API.md`). Registers a player model with three texture layers (`character.png` +
   2 × `blank.png`) and swaps layers on equip. Directly license-compatible with us;
   best **architectural** template, but tied to `mcl_player` (port needed to `player_api`).
3. **LOTT `lottarmor` + `multiskin`** (local: `reference_projects/Lord-of-the-Test/mods/lottarmor/`)
   — a 3d_armor derivative (code **LGPL-2.1**, plus BSD-3 parts from cornernote's bags).
   `multiskin.lua` composites 4 layers: skin + armor + **clothing** + wielditem — exactly
   our use case (robes = clothing layer over skin, plate = armor layer).

**Robes exist under free licenses:** `lottclothes` (LOTT) ships complete wizard sets —
`lottclothes_robe_wizard_grey/white.png`, hoods, cloaks (8 colors), trousers — media
**CC BY-SA 3.0** (Amaz/Flipsels), code LGPL-2.1. Ideal Mage/Priest starting point; recolor
for class variants (attribution + share-alike required). For inventory icons, the
**Dungeon Crawl Stone Soup 32×32 tileset** (OpenGameArt, **CC0**) has robes, swords,
daggers, staves, wands, shields — and **DungeonSoup** repackages DCSS as a CC0 Minetest
texture pack. OGA also hosts assorted CC0 "Minecraft-style" texture collections, but no
verified ready-made robe *player-skin overlay* was found there — deriving from the LOTT
robe templates is the fastest path.

## Top recommendations

1. **Fork the layering**: take VoxeLibre `mcl_armor` API structure (GPLv3+, no relicense
   needed) as the code skeleton, port to `player_api` model slots; borrow LOTT's
   4-layer idea (separate clothing layer for robes). Skip 3d_armor's armor-group damage
   math — we plug equip events into our own stats pipeline instead.
2. **Textures**: LOTT wizard robes + LOTT/3d_armor metal armor overlays (CC BY-SA 3.0)
   as bases; VoxeLibre armor textures (CC BY-SA 4.0, Pixel Perfection) as alternative.
   Quality tiers via engine texture modifiers (e.g. `^[multiply:` color tint) — no extra art.
3. **Item icons** (swords, wands, staves, daggers): DCSS tiles / DungeonSoup, CC0 —
   zero license friction, huge coverage, WoW-like icon feel.
4. **Bows (later)**: x_bows (LGPL-2.1-or-later) — modern raycast arrows + charge API.

## Candidate table

| Name | Author | URL | Code | Media | Harvestable | Effort | Status | Prio |
|---|---|---|---|---|---|---|---|---|
| 3d_armor | stu / minetest-mods | content.luanti.org/packages/stu/3d_armor/ | LGPL-2.1 (→GPLv3 via §3) | CC BY-SA 3.0 | Layering code, armor overlay textures (10 sets), shields, wieldview | Medium (strip armor groups, keep player_api glue) | Maintained (2026-07) | **High** |
| VoxeLibre mcl_armor | VoxeLibre team | local + git.minetest.land/VoxeLibre | GPLv3+ | CC BY-SA 4.0 (+CC0 sounds; per-file README) | API design, equip/unequip events, enchant hooks, armor textures | Medium (mcl_player → player_api port) | Active | **High** |
| LOTT lottarmor/multiskin | fishyWET, Amaz, Flipsels | local; github.com/minetest-LOTR/Lord-of-the-Test | LGPL-2.1 (+BSD-3) | CC BY-SA 3.0 (armor tex: Ryan Jones) | 4-layer multiskin concept, armor+shield textures, b3d model | Low-Medium | Semi-active | **High** |
| LOTT lottclothes | Flipsels, Amaz | local, same repo | LGPL-2.1 | CC BY-SA 3.0 | **Wizard robes/hoods/cloaks** = Mage/Priest sets; hobbit/ranger cloaks | Low (retexture slots) | Semi-active | **High** |
| DCSS tiles / DungeonSoup | crawl devs / sirrobzeroone | opengameart.org/content/dungeon-crawl-32x32-tiles · github.com/sirrobzeroone/DungeonSoup | — | **CC0** | Item icons: swords, daggers, staves, wands, robes, shields | Low | Static (fine for art) | **High** |
| x_bows | SaKeL | content.luanti.org/packages/SaKeL/x_bows/ | LGPL-2.1-or-later | CC BY-SA 4.0 | Bow charge mechanic, raycast arrows, quiver, API | Medium (rewire damage to our pipeline) | Maintenance-only (2025-04) | Medium (later class) |
| Throwing Redo | Palige | content.luanti.org/packages/Palige/throwing/ | MPL-2.0 (GPLv3-compatible) | ⚠ not stated — verify per-file before reuse | Extensible projectile API | Medium | Stale (2023-10) | Low |
| Mystical Tools | liteninglazer | content.luanti.org/packages/liteninglazer/mystical_tools/ | ⚠ CC BY-SA 4.0 as *code* license (one-way GPLv3-compatible, but unusual) | CC BY-SA 4.0 | Staff/wand textures (5 tiers each) | Low (textures only) | Stale (2022-02) | Low-Medium (icons) |
| minetest_game default/player_api | MT devs | local BASE modpack | LGPL-2.1 | CC BY-SA 3.0 | Sword textures (steel etc.), player model with texture slots | Already embedded | Frozen upstream | Given |
| Spears | Echoes91 | content.luanti.org/packages/Echoes91/spears/ | not verified ⚠ | not verified ⚠ | Thrown-spear mechanic | — | — | Low |

## Notes

- **3d_armor fork question — answered yes.** LGPL-2.1 §3 allows re-distribution of the
  code under GPL v2 *or any later version*, so even a strict "LGPL-2.1-only" reading is
  GPLv3-compatible. Alternatively keep the forked files LGPL-2.1 inside our GPLv3+ game
  (LGPL and GPLv3 coexist fine). Media stays CC BY-SA 3.0 with attribution to
  Stuart Jones (model: Jordach/MirceaKitsune character heritage — credit them too).
- **No GPLv2-only code found** among the candidates; nothing NC/ND.
- **Damage pipeline**: all three armor systems compute protection via `armor` groups —
  we only reuse the *equip → texture layer* path and emit our own events into the
  stats/enchantment-roll system (item meta survives fine; mcl_armor's enchant overlay
  hook `_mcl_armor_texture` shows how to render enchanted glint per item).
- **Quality tiers**: use icon border/tint compositing (`^[multiply`) + name color in
  description meta — no per-tier textures needed.
- **Skins DB** (content.luanti.org skinsdb ecosystem): user-submitted skins with per-skin
  licenses (many CC0/CC BY) — usable for NPC class trainers, check license per skin ⚠.
- Wieldview (visible wielded weapon) ships inside 3d_armor modpack, same licenses —
  worth taking along with the layering fork for "sword on player" visuals.

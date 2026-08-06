# Research: Humanoid & Race Models/Skins

Status: 2026-08-06 · Topic: NPC meshes (guards, traders, quest givers) + player race visuals
for 6 races — Alliance: Humans, Dwarves, Elves · Horde: Orcs, Trolls, Undead.

## Summary

The single most important finding: **Lord-of-the-Test renders ALL of its humanoid races
(dwarves, elves, hobbits, humans, orcs, trolls, traders, guards) with ONE mesh** —
`lottarmor_character.b3d` (Stuart Jones' 3d_armor character, LGPL 2.1) — differentiated only by
64x32 player-style skin textures and `visual_size` scaling. That is exactly our strategy: one
rigged character mesh (we already ship `mods/BASE/player_api/models/character.b3d`) covers all 6
races as mobs_redo NPCs *and* as player_api race models; per-race skins do the differentiation.
Undead get real monster meshes from mobs_mc/22i (GPLv3 — we already use the 22i zombie in
`mods/ENTITIES/wob_mobs`). Gaps: no ready-made WoW-style green orc, lanky troll, or night-elf
skins exist — those are recolors/edits of CC BY-SA LOTT skins or new paint jobs on the standard
skin template (cheap, 2D pixel work only).

Standard character rig animation ranges (identical for character.b3d and lottarmor_character.b3d):
`stand 0–79, sit 81–160, lay 162–166, walk 168–187, mine/punch 189–198, walk+mine 200–219` —
directly usable in mobs_redo (`stand_start/walk_start/punch_start`, see lottmobs `dwarves.lua`).

## Race coverage matrix

| Race / role | Best source | Mesh | Skin source | License (media) |
|---|---|---|---|---|
| Human | own player_api + lottmobs skins | character.b3d | `lottmobs_human_trader.png`, `lottmobs_gondor_guard*.png` | CC BY-SA 3.0 (fishyWET/Amaz) |
| Dwarf | lottmobs | character.b3d, `visual_size {x=1.1, y=0.85}` | `lottmobs_dwarf*.png` (+ guard/trader variants) | CC BY-SA 3.0 |
| Elf | lottmobs | character.b3d | `lottmobs_elf.png`, `lottmobs_lorien_elf_*.png`, `lottmobs_elf_trader.png` | CC BY-SA 3.0 |
| Orc | lottmobs (recolor green) | character.b3d, slight upscale | `lottmobs_orc*.png`, `lottmobs_uruk_hai*.png` | CC BY-SA 3.0 |
| Troll | lottmobs skins or own paint | character.b3d upscaled; alt: `troll_model.x` (WTFPL, chunky cave troll) | `lottmobs_half_troll.png`, `lottmobs_troll*.png` | CC BY-SA 3.0 / WTFPL |
| Undead | mobs_mc (22i) — already in wob_mobs | `mobs_mc_zombie.b3d`, `mobs_mc_skeleton.b3d`, `mobs_mc_villager_zombie.b3d` | Pixel-Perfection-based textures | Models GPLv3, textures CC BY-SA 4.0 |
| Guard NPC | lottmobs pattern | character.b3d + weapon wielding | `lottmobs_*_guard*.png` per race | CC BY-SA 3.0 |
| Trader NPC | lottmobs skins + mobs_npc code | character.b3d | `lottmobs_*_trader.png` per race | CC BY-SA 3.0 |

## Candidate table

| Source | Author | Where | Code lic. | Media lic. | Covers | Format/anims | Priority |
|---|---|---|---|---|---|---|---|
| lottmobs | Amaz, lumidify, fishyWET | `reference_projects/Lord-of-the-Test/mods/lottmobs` | WTFPL/MIT/LGPL 2.1 mix (see `license.txt`) | Race skins CC BY-SA 3.0; troll_model.x WTFPL | all 6 races, guards, traders | b3d/x, standard character ranges | **High** — primary skin source |
| lottarmor (multiskin) | fishyWET, Amaz; base Stuart Jones | `.../mods/lottarmor` | LGPL 2.1 + BSD-3 | `lottarmor_character.b3d` LGPL 2.1 (+ .blend source) | shared humanoid mesh; layered skin+clothes+armor compositing for players | b3d, standard ranges | **High** — pattern for player race visuals |
| mobs_mc | maikerumine, Wuzzy et al. | `reference_projects/VoxeLibre/mods/ENTITIES/mobs_mc` | GPLv3 | Models GPLv3 (22i); textures CC BY-SA 4.0/CC0/CC BY 3.0 (`LICENSE-media.md`) | Undead (zombie, skeleton, wither skeleton, zombie villager), witch/villager as quest-giver base | b3d + .blend, own anim tables in each lua | **High** — undead already integrated |
| 22i voxel blender models | 22i | github.com/22i/minecraft-voxel-blender-models | GPLv3 | GPLv3 | .blend sources for all mobs_mc humanoids — base for custom race meshes (e.g. lanky troll) | .blend → b3d via bundled exporter scripts | **Medium** — for custom variants |
| mobs_npc | TenPlus1 | content.luanti.org/packages/TenPlus1/mobs_npc | MIT | CC BY 4.0 | NPC/trader behavior code (trading API) on character model; updated 2026 | b3d (character), standard ranges | **Medium** — code patterns, few skins |
| goblins | FreeLikeGNU | content.luanti.org/packages/FreeLikeGNU/goblins | MIT ⚠ (GitLab repo shows "no license" — verify before reuse) | CC BY-SA 3.0 | flavor mobs (mines/caves), not core races | custom b3d, animated; active (2025) | Low |
| mobs_monster | TenPlus1 | content.luanti.org/packages/TenPlus1/mobs_monster | MIT | CC BY 3.0 | Oerkki/Dungeon Master as dungeon humanoids | b3d | Low |
| skinsdb | bell07 | content.luanti.org/packages/bell07/skinsdb | GPL-3.0 | Bundled 8 skins CC0 | player skin manager (v1.0/v1.8 formats) | textures only | Medium — code OK |
| Addi's open MT-Skin DB | community uploads | skinsdb online source | — | ⚠ **mixed per-skin licenses, some CC NC** — must verify each skin individually; do NOT bulk-import | 64x32/64x64 textures | Low — cherry-pick only |
| nativevillages / people / working_villages | Liil / theFox et al. | ContentDB | varies | ⚠ media provenance not clearly documented per file — audit before any reuse | villager behavior ideas | Low — ideas only |

## Notes

- **License compatibility**: LGPL 2.1 (character meshes) and CC BY-SA 3.0/4.0 (skins) are fine
  for a GPLv3+ game with per-file media attribution. lottmobs code layer contains LGPL v2.1
  contributions declared without "or later"; LGPL 2.1 §3 permits conversion to GPL ≥2, so it is
  GPLv3-compatible — but prefer rewriting the (thin) registration code ourselves anyway.
- ⚠ **Skin databases**: only skinsdb's bundled CC0 skins are safe wholesale; the online
  database mixes licenses including NC — per-skin verification mandatory.
- **Player race visuals**: keep one `character.b3d` in player_api; register per-race skins;
  dwarves via `visual_size`/`set_properties` scaling (lottmobs precedent: y=0.85). lottarmor's
  multiskin shows how to composite skin + clothes + armor into one texture at runtime.
- **WoW-style gaps** (own 2D work, cheap): green orc recolor of `lottmobs_orc*.png`, blue/purple
  troll and night-elf recolors of elf skins, Forsaken player skin (zombie-tinted human).
  Derivatives of CC BY-SA skins stay CC BY-SA — document in per-file attribution.
- lottmobs guard/trader implementation (`trader.lua`, `functions.lua`: `lottmobs.guard`,
  `do_custom_guard`, trader formspec) is a proven mobs_redo pattern matching our embedded fork.

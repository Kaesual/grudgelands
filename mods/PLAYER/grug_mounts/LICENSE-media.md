# Media licences — `grug_mounts`

No sounds are shipped by this mod. Every mount mesh below contains `ANIM`,
`BONE` and `KEYS` chunks; the mount animation ranges were checked against the
keyed frame ranges and are listed in the final table. The two boat hulls are
rigid (`NODE`/`MESH`/`BRUS`/`VRTS`/`TRIS` only): a hull does not move its parts,
so it needs no animation (travel plan, lane B).

## Imported media

| File | Author | Pinned source | Licence | Modifications |
|---|---|---|---|---|
| `grug_mounts_horse.b3d` | 22i | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `mods/ENTITIES/mobs_mc/models/mobs_mc_horse.b3d` | GPL-3.0-or-later (`mods/ENTITIES/mobs_mc/LICENSE-media.md`, Models) | Renamed only; byte-identical |
| `grug_mounts_horse_white.png` | XSSheep | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `textures/mobs_mc_horse_white.png` | CC BY-SA 4.0 (`mods/ENTITIES/mobs_mc/LICENSE-media.md`, Pixel Perfection mob textures) | Renamed only; runtime colour modifier supplies faction/tier colour |
| `grug_mounts_horse_brown.png` | XSSheep | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `textures/mobs_mc_horse_brown.png` | CC BY-SA 4.0 (`mods/ENTITIES/mobs_mc/LICENSE-media.md`, Pixel Perfection mob textures) | Renamed only; runtime colour modifier supplies faction colour |
| `grug_mounts_tiger.b3d` | Liil/Wilhelmine | animalworld `ac835da96681774679ace90656812aab67e25b5c`, `models/Tiger.b3d` | MIT (`LICENSE`: explicit textures/models/animation clause) | Renamed only; byte-identical |
| `grug_mounts_rowboat.b3d` | deasanta | Lord of the Test `f164140154945f0b356521ae721a86e9c7a0e0cf` (https://github.com/minetest-LOTR/Lord-of-the-Test), `mods/boats/models/rowboat.b3d` | WTFPL (`mods/boats/license.txt`, "Authors of media files"; the repository's top-level `LICENSE.txt` LGPL 2.1 covers its code) | Renamed only; byte-identical. Base boat hull; rendered with `default_wood.png` as upstream |
| `grug_mounts_sailboat.b3d` | deasanta | same commit, `mods/boats/models/sailboat.b3d` | WTFPL (same file) | Renamed only; byte-identical. Improved boat hull |
| `grug_mounts_sailboat.png` | deasanta | same commit, `mods/boats/textures/sailboat.png` | WTFPL (same file) | Renamed only; byte-identical |
| `grug_mounts_icon_boat.png` | deasanta | same commit, `mods/boats/textures/rowboat_inventory.png` | WTFPL (same file) | Renamed only; first version, the art lane redraws it under this name |
| `grug_mounts_icon_improved_boat.png` | deasanta | same commit, `mods/boats/textures/sailboat_inventory.png` | WTFPL (same file) | Renamed only; first version, the art lane redraws it under this name |
| `grug_mounts_tiger.png` | Liil/Wilhelmine | animalworld `ac835da96681774679ace90656812aab67e25b5c`, `textures/texturetiger.png` | MIT (`LICENSE`: explicit textures/models/animation clause) | Renamed only; runtime warm-gold modifier |

## Reused shipped media

These files remain physically owned and licensed by `grug_mobs`; Luanti media
names are game-global, so duplicating them would waste transfer bytes. Source
and licence details are repeated here so every mount-model row is independently
auditable.

| Files used by mounts | Pinned source | Licence | Mount use / modification |
|---|---|---|---|
| `grug_mobs_ibex.b3d`, `grug_mobs_ibex.png` | animalworld `ac835da96681774679ace90656812aab67e25b5c`, `models/Ibex.b3d`, `textures/textureibex.png` | MIT, Liil/Wilhelmine | Dwarf T2; runtime pale-bronze modifier |
| `grug_mobs_stag.b3d`, `grug_mobs_stag.png` | animalia `5895f403fd43a9464e06b3675af3495f50565a3f`, `models/animalia_reindeer.b3d`, `textures/reindeer/animalia_reindeer.png` | MIT, ElCeejo | Elf T2; unchanged texture |
| `grug_mobs_boar.b3d`, `grug_mobs_boar.png`, `grug_mobs_blank.png` | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `mobs_mc_pig.b3d`, `mobs_mc_pig.png`, `blank.png` | model GPL-3.0-or-later by 22i; textures CC BY-SA 4.0 by XSSheep | Orc T2; runtime red-brown modifier |
| `grug_mobs_wolf.b3d`, `grug_mobs_wolf_blightfang.png` | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `mobs_mc_wolf.b3d`, derived `mobs_mc_wolf.png` | model GPL-3.0-or-later by 22i; texture CC BY-SA 4.0 by XSSheep | Undead T2; existing Grudgelands blight retint plus runtime violet modifier |
| `grug_mobs_eagle.b3d`, `grug_mobs_eagle.png` | animalworld `ac835da96681774679ace90656812aab67e25b5c`, `models/Stellerseagle.b3d`, `textures/texturestellerseagle.png` | MIT, Liil/Wilhelmine | Accord T3/T4; scaled, with steel-blue then noble ivory runtime colour |
| `grug_mobs_cave_bat.b3d`, `grug_mobs_cave_bat.png` | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `mobs_mc_bat.b3d`, `mobs_mc_bat.png` | model GPL-3.0-or-later by 22i; texture CC BY-SA 4.0 by XSSheep | Throng T3/T4; scaled, with violet then noble blood-red runtime colour |
| `default_wood.png` (owned by the vendored `mods/BASE/default`) | minetest_game `b5243f3`, `mods/default/textures/default_wood.png` | CC BY-SA 3.0, BlockMen (`mods/BASE/default/README.txt`) | Base boat hull texture, unchanged, as the Lord of the Test rowboat uses it |

## Mount animation audit

| Mount family | Mesh keyed range | Frames used while mounted | Result |
|---|---:|---|---|
| Horse (both T1, Human T2) | 1–41 | stand 1, movement 1–40 | animated; frame-zero source range clamped to first real key |
| Ibex (Dwarf T2) | 1–400 | stand 1–100, movement 200–300 | animated; upstream stand and walk ranges |
| Stag (Elf T2) | 1–150 | stand 1–59, movement 100–119 | animated; inside keyed range |
| Boar (Orc T2) | 1–82 | stand 1, movement 1–40 | animated; frame-zero source range clamped to first real key |
| Wolf (Undead T2) | 1–92 | stand 1, movement 1–40 | animated; frame-zero source range clamped to first real key |
| Tiger (Troll T2) | 1–300 | stand 1–100, movement 100–200 | animated; upstream stand and walk ranges |
| Eagle / Steller's sea eagle (Accord T3/T4) | 1–350 | stand 1–100, flight 150–250 | animated; inside keyed range |
| Cave bat / giant bat (Throng T3/T4) | 1–81 | stand/flight 1–40 | animated; inside keyed range |

## R10 inventory renders

The twelve mount `grug_mounts_icon_*.png` files (not the two boat icons) are offline Eevee renders of the
shipped model/texture/tint combinations listed above. They inherit each row's
model and texture licenses. `tools/r10_art/render_mount_icons.sh` converts the
B3D mechanically for Blender, preserves the horse blank/body/blank buffers and
the boar Skin/blank-Saddle slots, renders with nearest-neighbour textures, and
writes static 64×64 PNGs. No generated geometry is shipped.

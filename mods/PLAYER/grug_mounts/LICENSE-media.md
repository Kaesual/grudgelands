# Media licences — `grug_mounts`

No sounds are shipped by this mod. Every mesh below contains `ANIM`, `BONE`
and `KEYS` chunks; the mount animation ranges were checked against the keyed
frame ranges and are listed in the final table.

## Imported media

| File | Author | Pinned source | Licence | Modifications |
|---|---|---|---|---|
| `grug_mounts_horse.b3d` | 22i | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `mods/ENTITIES/mobs_mc/models/mobs_mc_horse.b3d` | GPL-3.0-or-later (`mods/ENTITIES/mobs_mc/LICENSE-media.md`, Models) | Renamed only; byte-identical |
| `grug_mounts_horse_white.png` | XSSheep | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `textures/mobs_mc_horse_white.png` | CC BY-SA 4.0 (`mods/ENTITIES/mobs_mc/LICENSE-media.md`, Pixel Perfection mob textures) | Renamed only; runtime colour modifier supplies faction/tier colour |
| `grug_mounts_horse_brown.png` | XSSheep | VoxeLibre `c2dbc520ff4e1637072d33b06c3a2404e0f08df7`, `textures/mobs_mc_horse_brown.png` | CC BY-SA 4.0 (`mods/ENTITIES/mobs_mc/LICENSE-media.md`, Pixel Perfection mob textures) | Renamed only; runtime colour modifier supplies faction colour |
| `grug_mounts_tiger.b3d` | Liil/Wilhelmine | animalworld `ac835da96681774679ace90656812aab67e25b5c`, `models/Tiger.b3d` | MIT (`LICENSE`: explicit textures/models/animation clause) | Renamed only; byte-identical |
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

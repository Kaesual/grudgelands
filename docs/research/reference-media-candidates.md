# Reference-media candidates: `wildlife` and `forgotten_monsters_reworked`

Research date: 2026-09-17. This is a decision basis only. No media from either
rejected project has been imported. The source snapshots inspected were
`wildlife` commit `6b8b4910d9991652279a1acbf1eea6f4f591350a` and
`forgotten_monsters_reworked` commit
`62e9202ce4ceca5bd117262bb0623f64ef1ca310`, both in the read-only
`/tmp/d5-rejected-reference-projects/` clones supplied for this audit.

The acceptance rule is the per-file rule in [Licensing Research](licensing.md)
§3.2: no NC or ND media, and every imported file needs an author, source,
exact licence and modification record. The replacement pool is limited to the
pinned projects in [Reference projects](../reference_projects.md). The value
column uses the closed palettes and gaps in the
[round-5 spawn-variance audit](spawn-variance-audit.md); it does not amend the
decided [mob roster](../design/biomes_mobs.md) §3.

## Evidence and method

Media lists below cover every mesh, texture and sound directly referenced by
each mob definition, including blood, projectile, particle and spawn-egg
media. A drop is followed through its item registration to its directly
referenced media; the three registered boss trophies and companion
registrations kept in a candidate's Lua file are included too. Commented-out
references are marked inactive. An OGG generated from a WAV is listed
separately because both are separate copyrighted files in the source tree.

### Rejected-source licence evidence

- **W-MIT:** `wildlife/LICENSE` says “this software and associated
  documentation files” are under MIT, but does not say that meshes, textures
  or sounds are included. This is generic code-style wording, not per-file
  media evidence.
- **W-DOG:** `wildlife/sounds/readme.txt` says “dog sounds by Mike Koenig” and
  names `http://soundbible.com`, without a licence or individual source page.
  The Vorbis comments in `angrydog.ogg` and `dogbite.ogg` repeat
  `TITLE=SoundBible.com` and `ARTIST=Mike Koenig`, again without a licence.
  Thus the repository-wide MIT text appears broad while the sound files are
  credited to a third party; it cannot establish that TheTermos had authority
  to place those files under MIT.
- **W-NONE:** no file, header, README line, metadata tag or reachable commit
  message in the shallow clone states an author or licence for the named
  media. The sole visible media commit message is “add animation”; it contains
  no licence statement.
- **F-TEXTURE:** `forgotten_monsters_reworked/LICENSE` says “Textures :
  forgotten_monsters © 2024 da DuckGo está licenciado sob CC BY-SA 4.0”; the
  README separately says “TEXTURE : CC BY-SA 4.0”. This is project-wide
  texture evidence, not an attribution row per file.
- **F-MIT:** the same `LICENSE` contains the MIT text for “software and
  associated documentation files”, and the README says “LICENSE : MIT”.
  Neither file explicitly assigns a media licence to meshes or sounds.
- **F-GROWLER:** `fg_Wiki/Mobs.md` says “Growler ( Texture by :
  j0j0n4th4n )”. That third-party credit makes the blanket DuckGo texture
  statement insufficient for `growler.png` unless the upstream can document
  j0j0n4th4n's grant of CC BY-SA 4.0.
- **F-SOURCE-LINK:** some Lua headers give provenance URLs but no licence and
  sometimes no unambiguous file mapping: `Skull_lancer.lua`,
  `skull_berserker.lua`, `skullarchers.lua` and `skullsword.lua` cite
  spookymodem sound `202091` and, where relevant, Wdfourtee sound `192055`;
  `golem.lua` cites Debsound `250148`; `growler.lua` cites usamah `464993`;
  `meselord.lua` cites BrainClaim `267638`; `skullking.lua` cites
  TomRonaldmusic `607201`; and `spectrum.lua` cites Legnalegna55 `547558`.
  `fg_part.lua:20` maps `summon_boss.ogg` to Julianmateo Freesound `522699`,
  <https://freesound.org/people/julianmateo_/sounds/522699/>. A source URL
  without its exact licence is not import clearance.
- **F-SKELETON-RANDOM:** `sounds/skeleton_random.2.ogg` is byte-identical to
  `reference_projects/VoxeLibre/mods/ENTITIES/mobs_mc/sounds/
  mobs_mc_skeleton_random.2.ogg`; both have SHA-256
  `44e662cc09329f6bf4dd735c41beb89a57753d674c49b02ac92b57062de70c3a`.
  `mobs_mc/LICENSE-media.md:194-197` credits remixer Baŝto and original author
  kantouth, licenses `mobs_mc_skeleton_random.*.ogg` under CC BY 3.0, names
  <https://opengameart.org/content/walking-skeleton>, and identifies
  <https://freesound.org/people/kantouth/sounds/115113/> as the basis. A
  SHA-256 comparison of every file in both rejected projects' sound folders
  against the complete pinned `mobs_mc/sounds/` directory found this one
  identity and no others.
- **F-NONE:** none found for the named file. The snapshot has one grafted
  commit (`0.62`), whose message contains no licence evidence.

### Licensed replacement evidence

- **R-VL:** `reference_projects/VoxeLibre/mods/ENTITIES/mobs_mc/
  LICENSE-media.md` says “All models were done by 22i and are licensed under
  GPLv3”. Its default mob-texture rule is CC BY-SA 4.0. It itemizes Skeleton
  random sounds as CC BY 3.0, Skeleton death/hurt and Wolf sounds as CC0, and
  Vex hurt/death as CC0. These are stronger per-family rows than the overview
  in `docs/reference_projects.md`.
- **R-ANIMALIA:** the `animalia` row in `docs/reference_projects.md` records
  MIT media, and `reference_projects/animalia/LICENSE` contains the MIT grant
  by ElCeejo. The reindeer body, texture and four sounds all live in that
  same pinned project.
- **R-ANIMALWORLD:** `reference_projects/animalworld/LICENSE` explicitly says
  “Textures, Models and Animation by Liil/Wilhelmine/Liil under (MIT)
  License”. Its other-sounds paragraph only says “Creative Commons License”
  and does not identify an exact variant per file, so this report uses its
  meshes/textures but does not clear its Dragonfly or Shark sounds.
- **R-MONSTER:** `reference_projects/mobs_monster/license.txt` assigns the
  Mese Monster mesh/textures to SirrobZeroone under CC0; the Stone Monster
  and Tree Monster meshes and the base Tree Monster textures to Pavel_S and
  PilzAdam under WTFPL; `mobs_stone_monster.png` to wwar under CC0; and the
  Mese, Stone and Tree Monster sounds to Cyberpangolin under WTFPL.
- **R-DRACONIS:** the `draconis` row in `docs/reference_projects.md` records
  MIT code and media, and `reference_projects/draconis/LICENSE` contains
  ElCeejo's MIT grant. The selected Jungle Wyvern mesh, texture and sounds are
  all within that pinned project.

### Animation check

The body-mesh check was run with `strings FILE | grep -Eo
'ANIM|BONE|KEYS' | sort -u`. Both `wildlife` body meshes and all thirteen
`forgotten_monsters_reworked` mob rows' body meshes (twelve distinct files;
Skull Berserker and Skull Sword share one) contain all three B3D chunks. The
same check found all three chunks in every proposed replacement
body mesh: VoxeLibre Wolf, Skeleton and Vex; animalia Reindeer;
mobs_monster Mese, Stone and Tree Monster; draconis Jungle Wyvern; and
animalworld Dragonfly and Shark. Animation is therefore not the rejection
reason for any body-mesh candidate in the two tables. Unused
`models/spectrum_eye.b3d` has no animation chunks, but no loaded mob refers to
it and it is not proposed for import.

## `wildlife`

The source's custom spawner has no clock or light test, so both mobs are
eligible day and night. The Wolf is a hostile predator: it hunts Deer and
warns then attacks a nearby player. The Deer is passive and flees both Wolf
and player.

| Mob and source role | Source media and licence evidence | Animation | Best licensed replacement already pinned | User-supplied piece | Round-6 zone/day-night value |
| --- | --- | --- | --- | --- | --- |
| Wolf — hostile predator, day and night | Mesh `models/wolf.b3d`: W-MIT only, media scope unclear. Texture `textures/kit_wolf.png` and editable source `textures/kit_wolf.xcf`: W-MIT only. Sounds `sounds/angrydog.ogg`, `sounds/dogbite.ogg` plus source-like `sounds/Large Angry Dog 2-SoundBible.com-410353863.wav` and `sounds/Dog Bite-SoundBible.com-107030898.wav`: W-DOG; no licence. There are no egg, drop, projectile or trophy registrations. | Source `wolf.b3d`: `ANIM`, `BONE`, `KEYS`. | R-VL: `reference_projects/VoxeLibre/mods/ENTITIES/mobs_mc/models/mobs_mc_wolf.b3d`, `reference_projects/VoxeLibre/textures/mobs_mc_wolf.png`, and its `mobs_mc_wolf_*` sound family. Same quadruped/canine silhouette and exactly the same pack-predator palette role; already used by Grudgelands' Wolf family. | No media is missing for the replacement. A new texture would be needed only to make this visibly different from the shipped Wolf. | The audit names `wildlife` for the settled belts and the empty capitals, but this replacement duplicates the existing Wolf already present in Whitebridge, Moonfall, Ashenward and other forest palettes. It closes no distinct day/night silhouette gap without a new identity. |
| Deer — passive herbivore/fleeing prey, day and night | Mesh `models/herbivore.b3d`: W-MIT only, media scope unclear. Texture `textures/herbivore.png`: W-MIT only. Sounds `sounds/deer_hurt.ogg`, `sounds/deer_scared.ogg` plus `sounds/deer_hurt.wav` and `sounds/deer_scared.wav`: W-NONE. There are no egg, drop, projectile or trophy registrations. | Source `herbivore.b3d`: `ANIM`, `BONE`, `KEYS`. | R-ANIMALIA: `reference_projects/animalia/models/animalia_reindeer.b3d`, `textures/reindeer/animalia_reindeer.png`, and `sounds/reindeer/animalia_reindeer*.ogg`. Same antlered-deer silhouette and passive-prey role; already used by Grudgelands' Stag family. | No media is missing for the replacement. A distinct non-antlered texture/model treatment would be needed to avoid another Stag presentation. | A day-only adaptation could add a third settled-day silhouette in Hearthpine, Copperfell, Dawnmere, Goldmead, Silverleaf and Starbough, whose current day set is Boar plus Rabbit. As-is, the replacement repeats the existing Stag silhouette and does not address their Zombie-only nights. |

## `forgotten_monsters_reworked`

The project loads twelve mob definitions. `fg_monsters/skulls.lua` contains a
complete thirteenth definition, Normal Skull, but `init.lua` never loads that
file; it is included below as a dormant candidate rather than silently
omitted. “Both” in the skull rows means the default
`forgotten_monsters.daytime = true`, which raises their maximum spawn light to
14. Turning that setting off limits them to darkness. Bosses have no natural
spawn and the project wiki says they are summoned. Skeleton Swordfish also has
no effective natural row: its file mistakenly registers a spawn for
`rb_animals:shark`, not for `rb_animals:skeleton_swordfish`.

| Mob and source role | Source media and licence evidence | Animation | Best licensed replacement already pinned | User-supplied piece | Round-6 zone/day-night value |
| --- | --- | --- | --- | --- | --- |
| Skull Archer (`sarchers`) — hostile ranged skeleton; both by default | Mesh `models/skull_archers.b3d`: F-NONE. Body/blood/projectile textures `textures/monsters_textures/skull_arch.png`, `textures/buried_bone.png`, `textures/arrow_stone.png`: F-TEXTURE. `textures/particules_arrow.png` is an inactive commented projectile tail. Egg `textures/eggsarc.png` and Buried Bone drop icon `textures/buried_bone.png`: F-TEXTURE. Sounds `sounds/falling_bones.ogg` and `sounds/arrow_hit_1.ogg`: F-SOURCE-LINK is incomplete; no exact licence. `sounds/skeleton_random.2.ogg`: F-SKELETON-RANDOM, CC BY 3.0. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-VL Skeleton: `models/mobs_mc_skeleton.b3d`, root `textures/mobs_mc_skeleton.png`, and `sounds/mobs_mc_skeleton_*`. Same humanoid skeleton and ranged role. | Nothing for a generic archer; a visibly distinct bow/skin would need user-made art. Recreate or omit the source egg, arrow/tail and drop icon; do not reuse their blanket-attributed files. Licensed base sounds, including the byte-identical random sound, exist. | No new gap: Skeleton Archer already occupies bone forest and war nights, including Ossuary Reach, Blackwind Rise and Gravesalt Escarpment. |
| Skull Berserker — hostile melee skeleton; both by default | Mesh `models/skull_sword_anim.b3d`: F-NONE. Textures `textures/monsters_textures/skull_berserker.png`, `textures/buried_bone.png`, egg `textures/skull_berserker_egg.png`, Buried Bone drop icon `textures/buried_bone.png`, and Bones Axe drop icon `textures/bones_axe.png`: F-TEXTURE. The dropped axe calls `sounds/swoosh1.ogg`: F-NONE. `sounds/sword_skull.ogg` and `sounds/falling_bones.ogg`: F-SOURCE-LINK without exact mapping/licence. `sounds/skeleton_random.2.ogg`: F-SKELETON-RANDOM, CC BY 3.0. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-VL Skeleton set above. Same skeletal humanoid; the base does not preserve the large axe/berserker silhouette. | A new axe/berserker texture or wielded model is the main differentiator. Recreate or omit egg/drop art and the axe swoosh; the licensed Skeleton voice sounds suffice. | Could add a melee night variant to Stillgrave Hollow's Zombie-only night and the narrow bone-forest nights, but it repeats the existing skeleton species and requires a palette decision. |
| Skull Sword (`ssword`) — hostile melee skeleton; both by default | Mesh `models/skull_sword_anim.b3d`: F-NONE. Textures `textures/monsters_textures/skull_sword.png`, `textures/buried_bone.png`, egg `textures/eggsskullsword.png`, Buried Bone drop icon `textures/buried_bone.png`, and Bones Sword drop icon `textures/bones_sword.png`: F-TEXTURE. The dropped sword calls `sounds/swoosh1.ogg`: F-NONE. `sounds/sword_skull.ogg` and `sounds/falling_bones.ogg`: F-SOURCE-LINK without exact mapping/licence. `sounds/skeleton_random.2.ogg`: F-SKELETON-RANDOM, CC BY 3.0. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-VL Skeleton set. Same silhouette and melee-capable rig, but not a distinct sword-bearing body. | A user-made sword treatment is needed for a separate family. Recreate or omit egg/drop art and the swoosh; licensed skeleton voice audio exists. | Same possible night placement as Berserker: Stillgrave, Ossuary, Blackwind or Gravesalt. It does not help Lorindor or jungle-edge identity without changing the established palette theme. |
| Skull Lancer — hostile melee skeleton; both by default | Mesh `models/Skull_lancer.b3d`: F-NONE. Textures `textures/monsters_textures/Skull_lancer.png`, `textures/buried_bone.png`, shared egg `textures/skull_berserker_egg.png`, and Buried Bone drop icon `textures/buried_bone.png`: F-TEXTURE. Inactive commented attack sound `sounds/sword_skull.ogg` and active `sounds/falling_bones.ogg`: F-SOURCE-LINK, no exact licence. `sounds/skeleton_random.2.ogg`: F-SKELETON-RANDOM, CC BY 3.0. The inactive commented Axe drop would add `textures/bones_axe.png` and `sounds/swoosh1.ogg` (F-TEXTURE/F-NONE). | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-VL Skeleton set. Same skeletal humanoid; spear/lance silhouette is absent. | A lance plus matching texture/animation treatment is missing. Recreate or omit the egg/drop art; existing licensed skeleton sounds cover the voice. | A melee/range-varied skeleton could diversify bone-forest and Gravesalt nights, but does not fill the requested forest or jungle silhouette with the replacement alone. |
| Normal Skull (`skull`) — hostile melee skeleton, dormant: file not loaded and no spawn row | Mesh `models/skull_normal.b3d`: F-NONE. Textures `textures/monsters_textures/skull.png`, `textures/buried_bone.png`, egg `textures/eggsskull.png`, and Buried Bone drop icon `textures/buried_bone.png`: F-TEXTURE. Sound `sounds/falling_bones.ogg`: F-SOURCE-LINK, no exact licence. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-VL Skeleton set. Same species and generic role. | Nothing is missing for a generic skeleton, but there is no distinct identity to supply. Recreate or omit its egg/drop art. | No current source spawn and no new palette value; Grudgelands already has two skeleton families. |
| Growler — hostile flying predator near leaves, day and night | Mesh `models/glowler.b3d`: F-NONE. Body texture `textures/monsters_textures/growler.png`: F-TEXTURE conflicts with F-GROWLER's third-party credit. Blood `textures/growler_blood.png`, egg `textures/egggrowler.png`, and Growler Leather drop icon `textures/Growler_Leather.png`: F-TEXTURE. Sound `sounds/growl_growler.ogg`: F-SOURCE-LINK, no licence. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-DRACONIS: `models/draconis_jungle_wyvern.b3d`, `textures/jungle_wyvern/draconis_jungle_wyvern_jade.png`, and `sounds/draconis_jungle_wyvern*.ogg`. Both are flying predators; the replacement is a winged reptile rather than the Growler's compact floating silhouette, but it fits the high-jungle threat palette better. | No body media is missing for the replacement. Recreate or omit the source egg and leather icon; a non-dragon texture/model would be needed to preserve the Growler identity. | A night-only adaptation could supply the distinct high-jungle family missing from The Skyglass Canopy and broaden Thunderroot/Glassroot night silhouettes. The source's 24-hour schedule would not specifically close those night gaps. |
| Hungry — stationary hostile plant/ambush creature, bright day | Mesh `models/hungry.b3d`: F-NONE. Textures `textures/monsters_textures/hungry.png`, `textures/folha.png`, and egg `textures/hungryegg.png`: F-TEXTURE. The Hungry Sheet drop also uses `textures/folha.png`. Sounds `sounds/hungry_attack.ogg`, `sounds/hungry_sheet.ogg`: F-NONE. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-MONSTER Tree Monster: `models/mobs_tree_monster.b3d`, `textures/mobs_tree_monster.png`, `sounds/mobs_treemonster.ogg`. Same plant-monster/forest role; different walking tree silhouette rather than a rooted maw. | No body media is missing for the replacement. Recreate or omit the source egg and drop icon. | It could add day forest/jungle variety, but the audit's `forgotten_monsters_reworked` targets are principally night holes in Lorindor, Moonfall, Kapok and jungle edge. A bright-day mob closes none of them. |
| Spectrum — hostile flying ranged spirit, dark/night | Mesh `models/spectrum.b3d`: F-NONE. Body/blood/projectile/drop textures `textures/monsters_textures/spectrum.png`, `textures/blood_spectrum.png`, `textures/spectrum_orb.png`, and egg `textures/spectrum_egg.png`: F-TEXTURE. Companion registrations in the same file add `textures/anim_orb_block.png`, `textures/translocation_rod.png`, `textures/blink_part.png` and `sounds/trod.ogg`: F-TEXTURE/F-NONE. Sounds `sounds/spectrum.ogg`, `sounds/orb_spectrum.ogg`: F-SOURCE-LINK applies only as an unmapped header citation; no licence. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-VL Vex: `models/mobs_mc_vex.b3d`, root `textures/mobs_mc_vex.png` and `mobs_mc_vex_charging.png`, plus `sounds/mobs_mc_vex_hurt.ogg` and `mobs_mc_vex_death.ogg`. Same small flying supernatural silhouette and hostile role. | An idle/attack sound is the only missing body-media category if the two licensed Vex reaction sounds are insufficient. Recreate or omit all source egg, orb/block, rod and particle art plus the rod sound; those files are not cleared by the Vex replacement. | Strong fit for Lorindor's empty night, Moonfall's repeated Wolf/Spider night, Stillgrave's Zombie-only night, jungle-edge's missing night family in Kapok/Whispering/Totemwater, and the high-jungle night roster. Exact zones still require a palette decision. |
| Bug — hostile flying insect, underground darkness at y ≤ -40 | Mesh `models/bug.b3d`: F-NONE. Body/egg texture `textures/monsters_textures/bug.png` and Bug Meat drop icon `textures/Bug_Meat.png`: F-TEXTURE. Its `mobs_bee` random/attack sound is external and no corresponding sound file exists in this clone. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-ANIMALWORLD Dragonfly: `models/Dragonfly.b3d` and `textures/texturedragonfly.png`. Same flying-insect role, but a slender dragonfly rather than a beetle/bug. The upstream `animalworld_dragonfly.ogg` is not cleared here because animalworld names no exact CC variant for it. | Sound remains missing; the user's own insect recording would avoid the ambiguous animalworld sound row. Recreate or omit the meat icon; the replacement body texture could serve as an egg only if its licence attribution is retained. | None in this audit: the spawn-variance table explicitly excludes underground rows. It could diversify caves in a separate decision. |
| Skeleton Swordfish — hostile aquatic melee fish; no effective natural source spawn | Mesh `models/Skeleton_Swordfish.b3d`: F-NONE. Body texture `textures/monsters_textures/Skeleton_Swordfish.png`, egg `textures/buried_bone_block.png`, and Spine Sword drop icon `textures/Spine_sword.png`: F-TEXTURE. No sounds in the mob definition. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-ANIMALWORLD Shark: `models/Shark.b3d` and `textures/textureshark.png`. Same aquatic predator role, but neither the long swordfish silhouette nor the skeletal look. `animalworld_shark.ogg` is not cleared because its exact CC variant is unstated. | Sound is missing, and preserving either “skeleton” or “swordfish” requires a new texture/model. Recreate or omit the source egg and sword icon; audio alone cannot recover the candidate. | None in the surface audit, which excludes open-sea and underwater rows. It does not address a listed round-6 gap. |
| Mese Lord — summoned hostile ranged crystalline boss; no day/night schedule | Mesh `models/mese_guardian.b3d`: F-NONE. Body/blood/projectile/particle textures `textures/monsters_textures/mese_guardian.png`, `textures/default_mese_crystal_fragment.png`, `textures/energy_mese.png`, `textures/smoke_fg.png`, and summon egg `textures/summon_boock_meselord.png`: F-TEXTURE. Drop media: `textures/heart_of_mese.png`, `textures/forgotten_staff.png`, and shared staff projectile `textures/energy_mese.png`: F-TEXTURE. Inactive trophy media `models/trofeus_fm.obj` (F-NONE) and `textures/trufeus_meselord.png` (F-TEXTURE). Sounds `sounds/mese_lord.ogg`, `sounds/lord_mese_shot.ogg`: F-SOURCE-LINK does not identify which derives from BrainClaim `267638` and gives no licence. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-MONSTER Mese Monster: `models/mobs_mese_monster.b3d`, for example `textures/mobs_mese_monster_blue.png`, and `sounds/mobs_mesemonster.ogg`. Same crystalline magic construct role and a close blocky golem silhouette. | No body media is missing for the replacement. Recreate or omit the source summon egg, two drop icons/staff projectile, particle and trophy mesh/texture. | None in the ambient spawn audit because it is a summoned boss. It could be considered separately as authored boss content. |
| Golem — summoned hostile ranged stone boss; no day/night schedule | Mesh `models/golem.b3d`: F-NONE. Body/blood/projectile/particle textures `textures/monsters_textures/golem.png`, `textures/faisca.png`, `textures/monsters_textures/dark_stone_arrow.png`, `textures/smoke_fg.png`, and summon egg `textures/summon_boock_golem.png`: F-TEXTURE. Drop icons `textures/Eye_of_the_golem.png` and `textures/forgotten_sword.png`: F-TEXTURE. Inactive trophy media `models/trofeus_fm.obj` (F-NONE) and `textures/trufeus_golem.png` (F-TEXTURE). Sounds `sounds/damage_golem.ogg`, `sounds/punch_golem.ogg`: F-SOURCE-LINK gives one Debsound URL but no per-file mapping or licence; inactive `sounds/monster.ogg` is F-NONE. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-MONSTER Stone Monster: `models/mobs_stone_monster.b3d`, `textures/mobs_stone_monster.png`, and `sounds/mobs_stonemonster.ogg`. Same stone-construct silhouette and combat role; already used for Grudgelands' Stone/Mesa Golem family. | No body media is missing for the replacement. Recreate or omit the summon egg, drop icons, particle and trophy mesh/texture. | None as a summoned boss, and the replacement would duplicate the shipped Golem silhouette. Mountain nights are already Golem-only rather than lacking a golem. |
| Skull King (`sking`) — summoned hostile ranged/melee skeleton boss; no day/night schedule | Mesh `models/skull_king.b3d`: F-NONE. Body/blood/projectile/particle textures `textures/monsters_textures/Skull_King_hammer.png`, `textures/buried_bone.png`, `textures/monsters_textures/arrow_skull_skullking/skull_arrow_top.png`, `textures/monsters_textures/arrow_skull_skullking/skullking_arrosw.png`, `textures/monsters_textures/arrow_skull_skullking/skull_arrow_side.png`, `textures/monsters_textures/arrow_skull_skullking/skull_arrow.png`, `textures/smoke_fg.png`, and summon egg `textures/summon_boock_skullking.png`: F-TEXTURE. Hammer drop: `models/hummer.obj` (F-NONE), `textures/monsters_textures/sk_hammer.png`, `textures/skullking_hammer_inv.png` (F-TEXTURE), and `sounds/swoosh1.ogg` (F-NONE). Crown drop: `textures/armors/forgotten_monsters_helmet_skullking.png`, `textures/armors/forgotten_monsters_helmet_skullking_preview.png`, and `textures/armors/forgotten_monsters_inv_helmet_skullking.png`: F-TEXTURE. Inactive trophy: `models/trofeus_fm.obj` (F-NONE), `textures/trufeus_skull_king.png` (F-TEXTURE). Sounds `sounds/skullking.ogg`, `sounds/falling_bones.ogg`, `sounds/air_impact.ogg`: incomplete F-SOURCE-LINK; `sounds/summon_boss.ogg` maps to <https://freesound.org/people/julianmateo_/sounds/522699/> but has no recorded licence/version or modification note. | Source mesh: `ANIM`, `BONE`, `KEYS`. | R-VL Skeleton set. Same skeletal humanoid base, but it does not replace the crown/large hammer/boss silhouette. | A king texture, crown, hammer and projectile treatment are missing. Recreate or omit the source summon egg, drops, particle and trophy set. Licensed Skeleton sounds can cover bones; boss voice, impact, summon and hammer audio need licensed replacements or user recordings. | None in the ambient audit because it is a summoned boss. Captain Bonerattle already supplies the named skeleton-rare slot. |

## Recommendation per candidate

- **Wildlife Wolf — no.** The source media is unclear and the fully licensed
  replacement is the Wolf family already shipped, so it adds no new
  silhouette.
- **Wildlife Deer — no.** A complete licensed replacement exists, but it is
  the same animalia Reindeer already used for Stag; it does not close the
  settled night gaps.
- **Skull Archer — no.** The licensed replacement and the gameplay family are
  already present as Skeleton Archer.
- **Skull Berserker — yes-with-replacement.** Keep only the melee-variant
  concept; use the licensed Skeleton base and require new axe/berserker art
  before it can be visually distinct.
- **Skull Sword — no.** It is a generic melee Skeleton without enough role or
  silhouette separation from the existing skeleton roster.
- **Skull Lancer — yes-with-replacement.** A spear-bearing melee variant can
  diversify bone/war nights, but needs user-made lance art on the licensed
  Skeleton base.
- **Normal Skull — no.** It is dormant upstream and duplicates existing
  skeleton families.
- **Growler — yes-with-replacement.** The licensed Jungle Wyvern is not the
  same silhouette, but it can carry the high-jungle flying-predator role that
  has clear audit value.
- **Hungry — no for round 6.** The Tree Monster replacement is licensed and
  role-compatible, but this bright-day candidate closes none of the cited
  night gaps.
- **Spectrum — yes-with-replacement.** The licensed Vex is animated, close in
  silhouette and role, and directly fits several forest/jungle night gaps;
  only optional new attack/idle audio is missing.
- **Bug — no for round 6.** Licensed animated insect media exists and only
  audio is missing, but the candidate is cave-only and the audit excludes
  underground rows.
- **Skeleton Swordfish — no.** The Shark replacement preserves only the
  aquatic predator role, not the silhouette or undead identity, and the audit
  has no aquatic gap for it.
- **Mese Lord — yes-with-replacement outside the ambient roster.** The
  licensed Mese Monster is a close animated crystalline replacement with
  cleared sound, but this is boss content rather than a spawn-variance fix.
- **Golem — no.** The licensed Stone Monster replacement is already the
  shipped Stone/Mesa Golem family.
- **Skull King — no.** A generic Skeleton base does not replace the king and
  hammer presentation, and the ambient audit assigns no value to a summoned
  boss.

## Questions for upstream

### `wildlife`

1. Are `models/wolf.b3d`, `models/herbivore.b3d`,
   `textures/kit_wolf.png`, `textures/kit_wolf.xcf` and
   `textures/herbivore.png` original works by TheTermos, and are they
   intentionally licensed under the repository's MIT licence? Please add an
   explicit per-file media table or statement.
2. What are the exact source pages and exact licences for
   `Dog Bite-SoundBible.com-107030898.wav`,
   `Large Angry Dog 2-SoundBible.com-410353863.wav`, `dogbite.ogg` and
   `angrydog.ogg`, and what transformations produced the OGG files? The clone
   currently gives only Mike Koenig and the SoundBible home page.
3. Who created `deer_hurt.wav`, `deer_scared.wav`, `deer_hurt.ogg` and
   `deer_scared.ogg`; what is each file's source URL and exact licence; and
   are the OGG files derivatives of the corresponding WAV files?

### `forgotten_monsters_reworked`

1. Who created each B3D file used by a mob (`Skeleton_Swordfish.b3d`,
   `Skull_lancer.b3d`, `bug.b3d`, `glowler.b3d`, `golem.b3d`, `hungry.b3d`,
   `mese_guardian.b3d`, `skull_archers.b3d`, `skull_king.b3d`,
   `skull_normal.b3d`, `skull_sword_anim.b3d`, `spectrum.b3d`), where is its
   original source, and under which exact licence is it distributed? The MIT
   text never explicitly names models/media.
2. Does the CC BY-SA 4.0 texture statement cover every PNG in the repository?
   If so, please provide author and source per file. In particular, what
   permission from j0j0n4th4n allows `textures/monsters_textures/growler.png`
   to be distributed under CC BY-SA 4.0?
3. For every OGG in `sounds/`, please add a row giving the exact file,
   creator, original URL, exact licence/version and modifications. The current
   Lua header URLs do not map cleanly to all runtime filenames and do not state
   licences.
4. Specifically, which runtime files derive from BrainClaim `267638`,
   Debsound `250148`, TomRonaldmusic `607201`, Legnalegna55 `547558`, usamah
   `464993`, spookymodem `202091` and Wdfourtee `192055`? Were any mixed or
   edited into more than one OGG?
5. `fg_part.lua:20` maps `sounds/summon_boss.ogg` to Julianmateo Freesound
   `522699`. Which exact licence and licence version applied when it was
   downloaded, and what modifications produced the repository file?

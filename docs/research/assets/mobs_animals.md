# Research: Mob/Animal Mods — Reusable Assets

Status: 2026-08-06 · Licenses verified on ContentDB package pages / repos (noted per candidate).
Our constraints: code GPLv3+-compatible, media GPL-family/LGPL/MIT/Apache/CC0/CC BY/CC BY-SA. No NC/ND. Engine: embedded mobs_redo (MIT).

## Summary

There is more than enough freely licensed creature content to cover all our tiers.
The single best find is **Wilhelmine's Animal World** (mt-mods): 80+ animals, MIT code *and* media,
and it is **already written against the mobs_redo API** — bears, crocodiles, big cats, hyenas,
zebras, giraffes, elephants, i.e. nearly our whole mid-tier and biome-wildlife wishlist in one repo.
**Animalia** (ElCeejo, all-MIT) has the highest visual/animation quality (wolves, foxes, horses, owls…)
but needs porting from the creatura API. TenPlus1's **mobs_animal/mobs_monster** are drop-in
mobs_redo mods with clean licensing. **water_life is unusable (CC-BY-NC-SA media ⚠)**.

### Top 5 recommendations
1. **animalworld** — HIGH: MIT code+media, mobs_redo-native, 80+ animals = bears/crocs/big cats/savanna/jungle solved.
2. **animalia** — HIGH: all-MIT, best-in-class b3d models & animations (wolf, fox, horse, owl, bat…); port creatura→mobs_redo or harvest assets only.
3. **mobs_animal + mobs_monster** — HIGH: drop-in mobs_redo (MIT code, CC-BY-SA-4.0 / CC-BY-3.0 media); spider, farm animals, dungeon monsters.
4. **VoxeLibre/Mineclonia mobs (mobs_mc)** — MED-HIGH: GPLv3 + CC-BY-SA-4.0; we already use boar+zombie from it; consistent 16px style; mcl_mobs→mobs_redo port per mob.
5. **NSSM** — MEDIUM: LGPL-3.0 + CC-BY-4.0, mobs_redo-based; large monster roster (giant spiders, ants, snakes) for undead/monster tiers.

## Candidate table

| Mod | Author | Code | Media | API | Format/Style | Maint. | Prio |
|---|---|---|---|---|---|---|---|
| [animalworld](https://content.luanti.org/packages/Liil/animalworld/) | Liil/Wilhelmine (mt-mods) | MIT | MIT (sounds: freesound CC, verify per file) | mobs_redo | b3d, blocky w/ detailed textures | 2024-03 | **High** |
| [animalia](https://content.luanti.org/packages/ElCeejo/animalia/) | ElCeejo | MIT | MIT (single license on CDB) | creatura | b3d (Blockbench), polished blocky | 2025-12, beta | **High** |
| [mobs_animal](https://content.luanti.org/packages/TenPlus1/mobs_animal/) | TenPlus1 | MIT | CC-BY-SA-4.0 | mobs_redo | b3d, simple blocky 16px | 2026-07, active | **High** |
| [mobs_monster](https://content.luanti.org/packages/TenPlus1/mobs_monster/) | TenPlus1 | MIT | CC-BY-3.0 | mobs_redo | b3d, simple blocky 16px | 2026-06, active | **High** |
| [VoxeLibre](https://content.luanti.org/packages/Wuzzy/mineclone2/) / [Mineclonia](https://content.luanti.org/packages/ryvnf/mineclonia/) mobs_mc | teams | GPL-3.0-or-later | CC-BY-SA-4.0 | mcl_mobs | b3d (22i), 16px Minecraft-like | active (2026-08 / 2026-07) | **Med-High** |
| [nssm](https://content.luanti.org/packages/TenPlus1/nssm/) | npx / TenPlus1 | LGPL-3.0-only | CC-BY-4.0 | mobs_redo | b3d, quirky high-detail | maintained | **Medium** |
| [mobs_water](https://content.luanti.org/packages/TenPlus1/mobs_water/) | TenPlus1 | MIT | CC-BY-SA-3.0 (crocs part GPL-3.0) | mobs_redo | b3d, simple blocky | 2026-08, active | **Medium** |
| [paleotest](https://content.luanti.org/packages/ElCeejo/paleotest/) | ElCeejo | GPL-3.0-only | not separately listed → treat as GPL-3.0 ⚠ verify | mob_core+mobkit | b3d, detailed | 2021, maintenance-only | **Medium** |
| [draconis](https://content.luanti.org/packages/ElCeejo/draconis/) | ElCeejo | MIT | MIT (single license) | creatura | b3d, high-detail dragons | 2025-12 | **Low-Med** |
| [dmobs](https://content.luanti.org/packages/TenPlus1/dmobs/) | D00Med / TenPlus1 | LGPL-2.1-only ⚠ (GPLv3-compatible, but note) | CC-BY-SA-3.0 | mobs_redo | b3d, mixed quality | 2026-08 | **Low** |
| [wildlife](https://content.luanti.org/packages/Termos/wildlife/) | Termos | MIT | CC-BY-SA-3.0 | mobkit | wolf + gazelle only | 2021, stale | **Low** |
| [water_life](https://github.com/berengma/water_life) | berengma | — | **⚠ CC-BY-NC-SA — UNUSABLE** | mobkit | — | — | **Reject** |
| petz | runs | GPL-3.0 | textures CC-BY-SA-4.0; sounds mixed ⚠ per-file | own API | b3d, cute style | **deprecated**, CDB page gone | **Low** |

## Notes per candidate

- **animalworld (Wilhelmine's Animal World)** — github.com/mt-mods/animalworld. 80+ creatures: ants, anteater, **bear, polar bear, boar, crocodile, hippo, hyena, leopard, tiger, elephant, giraffe, kangaroo, zebra, camel, cobra, eagle, monkey, shark, wolf**… Covers savanna, jungle/swamp, mountains, plains wildlife almost completely. Code forked from mobs_redo/mobs_animal (MIT), models/textures/animation MIT by Skandarella/Liil. ⚠ Sounds are freesound.org imports "under Creative Commons" — check each sound's exact license before shipping; replace any NC ones. Style: Blockbench-blocky bodies with higher-res, semi-realistic textures — will need texture rework to match a 16px look. Sister mods by same author (marinara, living_jungle etc., also on CDB under mt-mods/Liil) are worth the same check if we need ocean/jungle fill.
- **animalia** — Best animation quality in the ecosystem (skeletal b3d, smooth movement). Roster: cow, sheep, chicken, pig, horse, **wolf**, cat, fox, bat, owl, song birds, frog, rat, turkey, reindeer… No bears/big cats. Single MIT license on ContentDB covers media. Two reuse paths: (a) embed creatura too (MIT) and run animalia beside mobs_redo, or (b) harvest models/textures/sounds and re-register on mobs_redo (animation frame ranges must be re-mapped by hand). Style is blockier-but-smoother than 16px MC mobs — mild clash with our VoxeLibre-derived boar/zombie.
- **mobs_animal / mobs_monster** — Zero-effort drop-ins for our engine. Animal: cow, sheep, chicken, bunny, penguin, panda, bee, kitten... Monster: **spider** (climbing), dungeon master, mese monster, stone/tree monster, golem, land guard. Media attribution required (CC-BY-SA-4.0 / CC-BY-3.0); keep per-file credits from their READMEs.
- **VoxeLibre / Mineclonia (mobs_mc)** — Both GPL-3.0-or-later + CC-BY-SA-4.0 (verified on CDB 2026-08). Huge roster: **wolf, spider, cave spider, skeleton, zombie variants, witch, slime, polar bear, ocelot, llama, parrot** — strongest source for the undead/monster tier in a consistent 16px style matching our existing boar+zombie. Port cost: mcl_mobs definitions → mobs_redo per mob (we have already done this twice, pattern known). Mineclonia and VoxeLibre share the mob asset lineage (22i's GPLv3/CC models); credit both chains in our media table.
- **nssm** — LGPL-3.0-only code (GPLv3-compatible), CC-BY-4.0 media, runs on mobs_redo. Good monster fillers: giant ants, spiders, snakes, mordain/morde undead-likes, phoenix. Style is idiosyncratic — cherry-pick.
- **mobs_water** — crocodile (3 variants!), shark, turtle, fish, jellyfish on mobs_redo. Note on CDB: croc part is GPL-3.0 — fine for us, but track it separately in attribution.
- **paleotest** — **Velociraptor, Sarcosuchus (croc), Smilodon (big cat), mammoth** etc. — exactly our "raptors" niche. GPL-3.0-only code ⚠ (GPL-3.0-*only*, still fine for a GPLv3+ project's media reuse, but code merges lock us to v3-compat review); media license not separately declared on CDB — verify in-repo per file before harvesting. API (mob_core+mobkit) is dead; treat as an asset quarry, re-register on mobs_redo.
- **draconis** — MIT dragons/wyverns; only relevant for a much later raid/boss tier; creatura dependency.
- **dmobs** — ⚠ code LGPL-2.1-only (FSF: compatible with GPLv3 via its upgrade clause, but document it); media CC-BY-SA-3.0. Elephant, fox, owl, panda, orc, skeleton, golem. Mixed quality; use only if a gap remains.
- **petz** — deprecated, ContentDB page 404s; textures CC-BY-SA-4.0 usable (leopard, snow leopard, many pets) but ⚠ sounds have mixed per-file licenses; own bespoke API. Only mine it for the big-cat textures if animalworld's don't suffice.
- **water_life** — ⚠ **contains CC-BY-NC-SA media → excluded entirely.** Do not copy anything from it.

## Cross-cutting license notes

- ⚠ NC/ND: water_life (reject); freesound-sourced sounds in animalworld/petz need per-file verification.
- ⚠ GPL-only variants: paleotest is GPL-3.0-only, mobs_water croc part GPL-3.0, dmobs LGPL-2.1-only — all GPLv3-compatible, no GPLv2-only code found among candidates, but record exact license per copied file.
- CC-BY-SA media (mobs_mc, mobs_animal, dmobs, wildlife) forces share-alike on *derived textures* — fine for us, but keep them out of any future non-SA asset pack.
- All candidate models are .b3d (Blender/Blockbench export) — directly loadable by Luanti and animatable via mobs_redo `animation` tables.

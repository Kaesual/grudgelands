# Lord of the Test Briefing

## Struktur
- game.conf + mods/: Basis-Mods (default, mobs, farming, stamina, bones, ...) + lott*-Mods.
- Wichtig: lottclasses (FRAKTIONEN), lottmapgen (custom Mapgen, 13 LotR-Biome), lottmobs (fraktions-alignierte Mobs/NPCs/Trader), lottarmor (3d_armor-Fork, Player-Model + Multiskin-Layering), lottachievements (awards-Fork), lottinventory, lottweapons.

## Fraktionen (lottclasses) — Kernsystem
- Rasse == Fraktion, komplett über PRIVILEGES (GAMEdwarf, GAMEorc, ... + GAMEmale/female), kein Metadata-Table.
- Bei Join ohne Priv: race_selector Formspec (Bild+Button pro Rasse, Gender-Dropdown); re-prompt wenn ohne Wahl geschlossen (init.lua:35-48,134-221). set_race + update_skin + rassen-spezifisches Starterkit (give_initial_stuff, init.lua:60-108). /race Chatcommand für Admin-Wechsel.
- Ally-Matrix: lottclasses.allies[race][race]=bool (allies.lua:1-32), in-game editierbar (/allies-Formspec), persistiert nach worldpath via serialize.
- Friend/Foe-Prädikate: player_same_race_or_ally, lua_ent_same_race_or_ally, npc_same_race_or_ally, obj_same_race_or_ally (allies.lua:58-119) — vereinheitlicht Spieler & Mobs. "ents" = neutral.
- PvP: KEIN Fraktions-Gating zwischen Spielern (nur Waffen-Wear-Hook) — Feindschaft nur in Mob-AI.
- Spawn-Immunität: immunity.lua — 300s Mob-Immunität für neue Spieler, in player meta "lott:immunity", überlebt Rejoin.
- KEINE per-Fraktion-Spawnpunkte (alle spawnen am Default-Spawn) — Lücke, die wir füllen müssen.

## Rassen = nur kosmetisch + Starterkit + Fraktion — keine Stats/Skills/Klassen-Achse.

## Mobs (lottmobs + gepatchte mobs-Engine)
- mobs_redo-artige API, GEPATCHT für Fraktionen: Target-Auswahl filtert via lottclasses.lua_ent_same_race_or_ally (mobs/api.lua:1900), Group-Attack nur same race/ally (api.lua:3012).
- Jeder Mob-Def hat `race`-Feld ("GAMEman", "GAMEorc", "ents"...). NPC-Rightclick: gleiche Rasse → Anheuern als Wache (payment-Item → Formspec) oder Dialog; falsche Rasse → ggf. Angriff (functions.lua:430,467).
- Trader (trader.lua:227-241 + trader_goods.lua): Detached-Inventory-Shop-Formspec (goods/selection/price/payment/takeaway), unterschiedliches Sortiment für eigene vs. fremde Rasse.

## Mapgen (lottmapgen)
- Custom on_generated Voxel-Mapgen (~595 Zeilen), 2D-Perlin Temp+Humidity+Random → 13 Biome via Schwellwerte (Angmar, Shire, Mordor, Rohan, ...).
- Territorien NICHT zusammenhängend (noise-verstreut)! Aber: jedes Biom legt Signatur-Grass-Node (shire_grass, ironhill_grass, ...), und Fraktions-Mobs spawnen per Node (mobs:register_spawn auf Biom-Node) → Biome = de-facto Fraktionszonen über Spawn-Nodes.
- deco.lua, schematics.lua+schems/, chests.lua (biomspezifische Loot-Chests).

## XP/Level/Skills: KEINE. Nur lottachievements (awards-Fork, register_trigger dig/place/eat mit target-Count) — als Zähl-/Trigger-Framework für Quest-Objectives wiederverwendbar.

## Übernehmenswert
- Fraktionen als Privileges + Ally-Matrix + Prädikat-Familie; Fraktionswahl-Formspec bei Join; Starterkit-Dispatch; b3d-Player-Model mit 4 Textur-Layern (skin/armor/wielditem/clothing, lottarmor/multiskin.lua); race-Feld + Target-Filter-Patch im Mob-Engine; Trader-Formspec; Spawn-Immunität.

## Lücken für uns
- Per-Fraktion-Spawns/Startzonen, zusammenhängende Territorien-Mapgen, Spieler-PvP-Fraktions-Gating, XP/Level/Skilltrees.

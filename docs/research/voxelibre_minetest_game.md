# VoxeLibre + minetest_game Briefing

## VoxeLibre-Architektur
- Mods unter mods/ in Kategorie-Modpacks (CORE, ITEMS, PLAYER, ENTITIES, HUD, ENVIRONMENT, MISC, HELP, MAPGEN), je modpack.conf — rein organisatorisch, gutes Modell.
- Namespace: mcl_/vl_ Präfixe; globale Tabelle pro Mod (`mcl_experience = {}`), Subfiles via dofile. Custom-Item-Felder mit `_mcl_`-Präfix. Groups werden intensiv für Behavior-Dispatch genutzt. Konventionen: VL/API.md, GROUPS.md.
- Load-Order über mod.conf depends/optional_depends. HUD-Kompat: mcl_vars.hud_type_field ("type" ab 5.9 vs "hud_elem_type").

## XP: mods/HUD/mcl_experience/init.lua (~260 Zeilen, perfekte Vorlage)
- XP als int in player meta (get_meta():get_int("xp")). API: get/set/add_xp, get/set_level, throw_xp (Orb-Entities), register_on_add_xp(func, priority) Callback-Pipeline (gut für Buffs/Rested-XP).
- Level-Kurve: stückweise quadratisch (level_to_xp/xp_to_level). HUD-Bar via hud_add + [lowpart Texture-Modifier. Tod: register_on_dieplayer → XP drop/zero.

## Händler: mods/ENTITIES/mobs_mc/villager.lua (2318 Zeilen, Gold-System-Vorlage)
- Emerald=Währung; Trades {wanted{item,min,max}, offered{...}}. Professions-Tabelle mit name/texture/jobsite (Node in der Nähe = Beruf). 5 Trade-Tiers (Novice→Master), _trades serialisiert im Entity.
- Trade-UI: Formspec + detached inventory `mobs_mc:trade_<player>` (wanted/input/offered/output), update_offer prüft Input. Trade gibt XP, Tier-Ups, Trades locken nach ~12 Nutzungen (Ökonomie).
- Dorf-Strukturen: mods/MAPGEN/mcl_villages/ (Schematics .mts + buildings.lua/paths.lua) — Vorlage für Fraktionslager.

## Mob-Engine: mods/ENTITIES/mcl_mobs/ = Fork von mobs_redo 1.41
- API-kompatibel zu mobs_redo; aufgeteilt in api/combat/breeding/movement/pathfinding/spawning/physics/mount/effects.lua. Mobs selbst in mobs_mc/.

## Rüstung/Tools
- mcl_armor.register_set(def) (head/torso/legs/feet in einem Call, points/toughness/durability, Entity-Overlay-Texturen) — Vorlage für Klassen-Gear. mcl_tools + _mcl_autogroup (dig-Groupcaps aus Hardness generiert).

## Tod/Respawn/Damage
- mcl_spawn (Spawnpunkte), mcl_death_drop, mcl_beds (Respawn), mcl_damage (CORE) = einheitliches Damage/Reason-System — übernehmenswert für Fähigkeiten.

## HUD
- vl_hudbars (Statbar-API), mcl_bossbars (Raid-Bosse!), mcl_title (Zonen-/Quest-Announcements), mcl_formspec_prepend (Styling), mcl_player.get_player_formspec_model (3D-Modell im Formspec — Charakterbildschirm).

## Skins/Modelle
- mcl_player.player_register_model/set_model/animation; mcl_skins Auswahl-Formspec. Keine Klassen — auf Meta-Feld + Modell-API aufbauen.

## minetest_game
- Bewusst minimal ("no NPCs, monsters"); Kern = mods/default (nodes/tools/crafting/furnace/chests/mapgen), 25 Mods hängen an default. game_api.txt.
- Empfehlung: STANDALONE bauen, VL-Modpack-Struktur übernehmen, gezielt VL-Subsysteme adaptieren; MG default als schnelle Node-Palette vendorbar. VL ist GPL/Mixed — LICENSE.txt/LEGAL.md prüfen vor Code-Kopie!

## Karte/Fog of War
- MG mods/map: Minimap-Gating per Item (hud_set_flags{minimap=}). 
- VL mods/ITEMS/mcl_maps/init.lua (528 Zeilen): rendert Top-Down-PNG explorierter Chunks (colors.json, Height-Shading), pusht via core.dynamic_add_media, Zoom-Levels, globalstep-gedrosselt (map_update_rate). = Fog-of-War-nächste Lösung. Kein Waypoint-Mod — Engine-HUD "waypoint"/"image_waypoint" nutzen.

## Berufe/Crafting-Patterns
- mcl_potions: datengetriebener Rezept-Graph (register_water_brew/awkward/mundane/ingredient_potion/table_modifier/inversion) — Modell für Kräuterkunde→Alchemie.
- mcl_brewing: Workstation-Node mit Formspec + node timer (Fuel + Slots, timed process) — Muster für Schmiede etc.
- mcl_enchanting: Lapis+XP-Level → Item-Meta-Enchantments — als Gear-Upgrade/Talent-Mechanik wiederverwendbar.
- mcl_events (CORE): register_event mit cond_start/on_step/cond_progress/cond_complete — Quest-/Event-Gerüst!
- mcl_craftguide (HELP, API.md) — Rezeptbuch-UI-Vorlage.

## Performance
- ABM (39 Mods): nur ambient random events, chance/interval drosseln, catch_up=false. LBM (34): einmalige Load-Fixes/Migrationen. globalstep (51): IMMER dtime-Akkumulator-gating. Node-Timer (24): bevorzugt für Maschinen (Furnace/Brewing). mcl_playerinfo cached Nearby-Node-Queries. get_node_raw in Hot Loops.

# AGENTS.md — Projekt-Leitfaden

WoW-inspiriertes Luanti-Game (Arbeitstitel „Voxel of Warcraft"). Ziele und
Scope: **[ROADMAP.md](ROADMAP.md)**. Arbeitspakete und Status:
**[BACKLOG.md](BACKLOG.md)**. Ausführliche Recherche-Notizen zu den
Referenzprojekten: **[docs/research/](docs/research/)**.

## Arbeitsweise (Sessions & Context)

Aller Projektzustand lebt im Repo, nicht im Chat-Verlauf:

1. **Session-Start**: BACKLOG.md lesen, das nächste offene WP nehmen (oder
   das vom User genannte). Zugehörige docs/research/-Briefings überfliegen.
2. **Ein WP pro Session** ist der Normalfall — kohärent, testbar, committet.
   Große Explorationen in Subagents auslagern, Haupt-Context schlank halten.
3. **WP-Abschluss**: Lua-Syntax-Check (`luajit -e "assert(loadfile(...))"`),
   `tools/sync_to_luanti.sh`, committen, BACKLOG-Status + ROADMAP-Häkchen
   aktualisieren. Was künftige Sessions wissen müssen → AGENTS.md/docs, nicht
   nur Chat.
4. **Runtime-Tests macht der User** (Flatpak-Luanti, GUI); Fehlerdiagnose
   über `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.

## Projektstruktur

- Wir bauen ein **eigenständiges Game** (kein Mod-Pack, kein Fork von
  minetest_game/VoxeLibre). Das Game lebt später in einem Layout wie
  `games/<gameid>/` mit `game.conf`, `menu/`, `mods/`, `settingtypes.txt`.
- `reference_projects/` enthält **nur Referenzen — dort nie etwas ändern**:
  - `luanti/` — die Engine selbst (C++ + builtin-Lua). API-Referenz:
    `reference_projects/luanti/doc/lua_api.md` (~12.700 Zeilen, DIE Quelle).
  - `Lord-of-the-Test/` — beste Fraktions-Referenz (Privileges + Ally-Matrix,
    fraktionsbewusste Mob-AI, Trader).
  - `VoxeLibre/` — beste Architektur-Referenz (XP-System, Villager-Trading,
    Karten-Rendering, Modpack-Struktur).
  - `minetest_game/` — minimales Basis-Game (Node-/Tool-Palette in `mods/default`).
  - `mobs_redo/` — Mob-Engine (MIT-Lizenz → dürfen wir forken/einbetten).

## Lua & Luanti-Umgebung (WICHTIG)

- **Lua 5.1** (Engine bündelt Lua 5.1.x, bevorzugt aber **LuaJIT**;
  `USE_LUAJIT` in `reference_projects/luanti/CMakeLists.txt`). Konsequenzen:
  - **Kein `goto`**, keine Integer-Division `//`, keine Bit-Operatoren-Syntax
    (`&`, `|`) — stattdessen `bit.*` (LuaJIT BitOp, immer verfügbar).
  - Zahlen sind C-Doubles, kein Integer-Typ; sicherer Ganzzahlbereich ±(2^53−1).
  - `unpack` (nicht `table.unpack`), `setfenv`/`getfenv` existieren.
  - Rückportiert aus 5.4: `string.pack`/`unpack`/`packsize`.
- Engine-Version der Referenz: **Luanti 5.17.0-dev** (git-Checkout nach 5.16).
- **Namespace: `core.*` verwenden** — `minetest.*` ist nur ein deprecated Alias.
- **Alle Game-Logik läuft serverseitig.** Mods laufen nur auf dem Server;
  Definitionen/Medien werden automatisch an Clients übertragen. SSCSM
  (server-sent client-side mods) ist in der Engine noch ein Stub — nicht nutzen.
- **Sandbox** (bei `secure.enable_security`): verfügbar sind `coroutine`,
  `string`, `table`, `math`, `bit` vollständig; `io`/`os`/`debug` stark
  beschnitten (kein `os.execute`/`os.exit`); `dofile`/`require` pfadbeschränkt
  auf den eigenen Mod. `core.request_insecure_environment()` nur über
  `secure.trusted_mods` — brauchen wir nicht.
- **Global injizierte Helfer** (builtin): `dump()`, `string.split`,
  `string:trim()`, `table.copy/indexof/insert_all/shuffle`,
  `math.round/sign/hypot`, `vector.*` (Metatable-basiert, Operatoren
  überladen: `vector.new/add/distance/direction/normalize/...`),
  `core.after(sec, fn)`, `core.serialize/deserialize`,
  `core.parse_json/write_json`.
- `strict.lua` der Engine warnt bei undeklarierten Globals — Mod-Globals
  explizit deklarieren (eine globale Tabelle pro Mod, s. Konventionen).

## Game-/Mod-Anatomie

- `game.conf`: `title` (Pflicht), `description`, `first_mod`/`last_mod`,
  `allowed_mapgens`/`default_mapgen`, `disabled_settings` (z. B.
  `!enable_damage` erzwingt PvE-Schaden), `author`, `textdomain`.
- Jeder Mod: `mod.conf` (`name`, `depends`, `optional_depends`) + `init.lua`.
  Medien in `textures/ sounds/ models/ locale/` (Namen: `a-zA-Z0-9_.-`;
  Modelle `.b3d/.obj/.gltf/.glb`, Sounds `.ogg`).
- Registrierte Namen immer `modname:name`; `:foo:bar` überschreibt fremde
  Registrierung (Dependency nötig).
- Modpacks (Ordner mit `modpack.conf`) nutzen wir zur Gruppierung wie
  VoxeLibre: `CORE/`, `PLAYER/`, `ENTITIES/`, `ITEMS/`, `MAPGEN/`, `HUD/`.

## Projekt-Konventionen

- **Namespace-Präfix: `wow_`** für alle unsere Mods (z. B. `wow_xp`,
  `wow_factions`, `wow_quests`, `wow_jobs`, `wow_mobs`, `wow_map`).
- Pro Mod genau eine globale Tabelle (`wow_xp = {}`), Sub-Dateien via
  `dofile(core.get_modpath(core.get_current_modname()).."/foo.lua")`.
- Custom-Felder in Item-/Node-/Entity-Definitionen mit `_wow_`-Präfix
  (Muster von VoxeLibre `_mcl_*`).
- Verhalten über **Groups** dispatchen statt Namenslisten (VoxeLibre-Muster).
- Persistenz:
  - Spieler-Daten (Klasse, Fraktion, XP, Level, Talente, Jobs, Gold,
    Quest-Status, Map-Exploration) → `player:get_meta()` (PlayerMetaRef,
    auto-persistiert). Komplexe Strukturen via `core.serialize` als String.
  - Mod-weite Daten → `core.get_mod_storage()` (beim Laden holen).
  - Node-Daten (Workstations) → `core.get_meta(pos)`.
- Performance-Regeln (aus VoxeLibre destilliert):
  - `register_globalstep` **immer** mit dtime-Akkumulator drosseln.
  - Node-Timer für Maschinen/Workstations (Schmiede, Alchemie).
  - LBM für einmalige Load-Fixes/Migrationen.
  - ABM nur für ambiente Zufalls-Events, mit `chance`/`interval` gedrosselt,
    `catch_up = false` wo möglich.
  - In Hot Loops `core.get_node_raw`/Content-IDs + VoxelManip statt `get_node`.

## Schlüssel-APIs für unsere Features (Kurzreferenz)

Details + Zeilennummern in [docs/research/](docs/research/).

- **Fraktionen**: Muster aus Lord of the Test `lottclasses` — Fraktion als
  **Privilege** + Ally-Matrix + Prädikate (`*_same_race_or_ally`), Auswahl-
  Formspec bei Join (re-prompt bei Abbruch), Starterkit-Dispatch. LotT hat
  KEINE per-Fraktion-Spawns und kein Spieler-PvP-Gating — bauen wir selbst
  (`core.register_on_punchplayer` / `register_on_player_hpchange`).
- **XP/Level**: Vorlage VoxeLibre `mods/HUD/mcl_experience/init.lua` — XP als
  int in Player-Meta, `level_to_xp`-Kurve, `register_on_add_xp`-Pipeline,
  HUD-Bar. XP-Loss on Death via `core.register_on_dieplayer`.
- **Kampf/Klassen**: Schaden = damage_groups × armor_groups (÷100) ×
  Punch-Interval-Faktor. Fähigkeiten über `core.register_on_punchplayer`,
  `ObjectRef:punch()`, `set_physics_override` (Buffs), `hud_add`-statbar für
  Mana/Ressourcen. Einheitliches Damage-Reason-System wie VoxeLibre
  `mcl_damage` übernehmen.
- **Mobs**: mobs_redo (MIT) einbetten und patchen. Fraktions-Targeting:
  Bedingung in `general_attack()` (api.lua:1699ff) nach LotT-Muster
  (`race`-Feld im Mob-Def + Ally-Check); Territorium-/Tier-Gating über
  `mobs:spawn_abm_check()`. Tiers über `hp_max`/`armor` (niedriger = zäher)/
  `damage`/`view_range`/`group_attack`. Dynamischer Loot: `drops` kann
  Funktion sein. Quest-Kill-Credit: `on_death(self, killer)`.
  Quest-/Händler-NPCs: `type="npc"`, `passive`, `on_rightclick` → Formspec;
  Platzierung via `mobs:add_mob(pos, def)`.
  **Pathfinding ist Qualitätskriterium** (User-Vorgabe: gefährliche Mobs
  dürfen nicht an Terrain scheitern, sonst sind sie nicht gefährlich):
  mobs_redo hat `pathfinding = 1|2` (nutzt `core.find_path`, 2 = kann Nodes
  brechen/bauen) plus `stepheight`/`jump_height`/`fear_height` — beim
  Mob-Tuning immer aktivieren und testen. VoxeLibre `mcl_mobs` hat ein
  eigenes, ausgebautes `pathfinding.lua` (+ `gopath` der Villager) — falls
  mobs_redo-Pathfinding nicht reicht, von dort adaptieren (GPL ok, s. u.).
  Fallback-Design: Kernland-Mobs zusätzlich schnell machen (`run_velocity`)
  und mit Ranged-Attacken (`attack_type = "dogshoot"`) ausstatten, damit
  Terrain-Exploits nicht trivial sind.
- **Loot/Verzauberungen**: Klassen-Items (Zauberstab, Magier-/Hexerrobe,
  Eisenrüstung/-schwert, Dolch, …) droppen mit **zufälligen Roll-Ranges**
  (z. B. Stärke +1..+3, Angriffsgeschwindigkeit +5..+20 %). Umsetzung wie
  VoxeLibre `mcl_enchanting`: Rolls in **Item-Meta** speichern
  (`stack:get_meta()`), Beschreibung via Meta-Key `description` mit den
  gerollten Werten generieren (Muster `_mcl_generate_description`).
  Wirkung: Attack-Speed über `tool_capabilities.full_punch_interval` im
  Stack-Meta-Override, Stats beim Anlegen/Wechseln auf Player-Stats
  anwenden. Drop-Quelle: `drops`-Funktion im Mob-Def rollt bei Kill
  (Basis-Variante überall, verbesserte Variante mit besseren Ranges nur
  bei Elite-/Kernland-Mobs).
- **Händler/Gold**: Vorlagen VoxeLibre `mobs_mc/villager.lua` (Trade-Tiers,
  detached inventory `wanted/input/offered/output`) und LotT
  `lottmobs/trader.lua` (fraktionsabhängiges Sortiment). Gold als Item +
  Zähler in Player-Meta; Händler kauft JEDEN Mob-Drop an (Ankaufspreis-Feld
  `_wow_sell_price` in Item-Defs).
- **Quests**: Kein fertiges Framework in den Referenzen. Bausteine:
  Trigger-/Zähl-Muster aus `lottachievements` (awards-Fork), Event-Stufen aus
  VoxeLibre `mcl_events` (`cond_start/on_step/cond_complete`), Questlog als
  Formspec, Status in Player-Meta, Questgeber via NPC-`on_rightclick`,
  HUD-`waypoint`-Elemente für Questziele.
- **Mapgen/Biome**: `core.register_biome/register_ore/register_decoration`
  (Mapgen v7) ODER custom `register_on_generated` (LotT-Stil, Perlin-basiert).
  Für zusammenhängende Fraktionsterritorien (Nord/Süd) brauchen wir eine
  eigene Lösung: Territorium als Funktion der Z-Koordinate + Schwierigkeit
  als Funktion der Distanz zur Grenze/zum Spawn — Biome-Noise nur innerhalb
  des Territoriums. Mapgen-Env (`core.register_mapgen_script`) läuft in
  eigenen Threads: kein Metadata-Zugriff, dafür schnell.
  LotT-Trick: Biom-Signatur-Nodes (z. B. Grass-Varianten) steuern
  Mob-Spawns per Node-Whitelist.
- **Karte/Fog of War**: VoxeLibre `mcl_maps` rendert explorierte Chunks als
  PNG (`colors.json`, Height-Shading) und pusht via
  `core.dynamic_add_media` — beste Basis für unsere globale Karte.
  Minimap-Gating: `hud_set_flags{minimap=...}` (Muster minetest_game `map`).
- **UI**: Formspecs (`core.show_formspec` +
  `register_on_player_receive_fields`), `formspec_version` +
  `real_coordinates[true]` setzen. 3D-Charaktervorschau: `model[]`-Element.
  Skill Tree = Formspec mit `image_button`-Grid.
- **Spielermodell/Skins**: `player:set_properties{visual="mesh", mesh=...,
  textures={...}}`; Textur-Layering (skin/armor/wielditem) nach
  LotT `lottarmor/multiskin.lua`.

## Lizenzen

- **Unser Projekt ist GPL** (nicht-kommerziell, Entscheidung vom 2026-07-03).
  Damit dürfen wir Code aus ALLEN Referenzprojekten übernehmen und anpassen —
  auch aus VoxeLibre (GPLv3). Bei Übernahmen Copyright-/Lizenz-Hinweise der
  Quelle im jeweiligen Mod behalten (mobs_redo: MIT-Notice; Assets:
  CC-Attribution, wenn übernommen).
- **Keine WoW-Assets/-Namen 1:1 kopieren** — Blizzard-IP. Eigene Assets,
  eigene Namen mit erkennbarem Charakter („inspiriert von", nicht „kopiert").

## Test & Entwicklung

- Lokal testen: Luanti ist als **Flatpak** installiert (`org.luanti.luanti`,
  Sandbox ohne Zugriff auf `~/projects`!). Deshalb `tools/sync_to_luanti.sh`
  ausführen — kopiert das Game nach
  `~/.var/app/org.luanti.luanti/.minetest/games/voxel_of_warcraft`.
  Nach jeder Code-Änderung erneut syncen. Engine-Logs:
  `~/.var/app/org.luanti.luanti/.minetest/debug.txt`.
- `strict.lua`-Warnungen (undeclared global) ernst nehmen — meist Tippfehler.
- Server-Log via `core.log("action"|"warning"|"error", msg)`.

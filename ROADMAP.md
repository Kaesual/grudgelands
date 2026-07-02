# Roadmap — „Voxel of Warcraft" (Arbeitstitel)

Ein Luanti-Game, das Spielmechaniken, Story und Charakter von World of Warcraft
so gut wie möglich in einer Voxel-Welt einfängt — als eigenständiges Game
(kein Mod-Pack), in Lua geschrieben.

## Vision

- Zwei Fraktionen (**Horde** / **Allianz**) mit eigenen, großen zusammenhängenden
  Territorien (Multi-Biom-Regionen, z. B. Nord/Süd-Teilung).
- Klassen mit XP, Leveln und vereinfachten Skill Trees.
- Quests, die Progression treiben und gezielt PvP und Exploration erzwingen.
- Berufe („Jobs"), Gold-Ökonomie und Händler-NPCs.
- Schwierigkeit skaliert räumlich: sichere Startzonen an den Fraktionsgrenzen,
  tödliche Elite-/Raid-Gebiete im Inneren bzw. weit weg vom Spawn.
- Globale Karte pro Spieler mit Fog of War (jeder deckt sie selbst auf).
- Kein Gildensystem (bewusste Entscheidung — Luanti ist dafür nicht MMORPG genug).
- **Lizenz: GPL** (nicht-kommerzielles Projekt) — damit können wir Code aus allen
  Referenzprojekten (inkl. VoxeLibre) übernehmen und anpassen.

---

## Phase 1 — MVP

### 1.1 Fundament
- [x] Game-Skelett: `game.conf`, Mod-Struktur, Namespace-Konventionen (siehe AGENTS.md)
- [x] Basis-Welt: Blöcke/Werkzeuge/Crafting (BASE-Modpack aus minetest_game)
- [x] Mob-Engine integrieren (mobs_redo eingebettet; Fraktions-Patch folgt mit 1.4)

### 1.2 Fraktionen & Welt
- [x] Fraktionswahl bei Charaktererstellung (Horde/Allianz), persistent
- [ ] Mapgen: zwei große zusammenhängende Fraktionsterritorien (Nord/Süd),
      jeweils aus mehreren Biomen zusammengesetzt
- [ ] Schwierigkeits-Gradient: leichte Biome nahe Grenze/Spawn, schwere Biome
      im Landesinneren (Mob-Stärke skaliert mit Distanz)
- [ ] Fraktions-Spawnpunkte (Hauptstadt-Lager je Fraktion nahe der Grenze)
      — Platzhalter-Spawns bei z = ±200 existieren, Lager fehlen
- [x] PvP-Grundlage: Friendly-Fire-Schutz innerhalb der Fraktion;
      Quest-getriebenes PvP folgt mit 1.5

### 1.3 Klassen & Progression (MVP: 3 Klassen)
- [ ] **Krieger** (Melee, simpel — Referenzklasse), **Magier** (Ranged/Caster),
      **Priester** (Heiler/Support)
- [x] XP-System: Level-Kurve 1–60, XP-Verlust beim Tod (25 % des
      Level-Fortschritts), HUD; XP-Quellen (Mob-Kills, Quests) folgen mit 1.4/1.5
- [ ] Level-System mit Stat-Steigerung (HP, Schaden) —
      `register_on_level_change`-Pipeline existiert bereits
- [ ] Vereinfachte Skill Trees: pro Klasse 2 Bäume à ~5 Talente,
      Talentpunkte pro Level, Formspec-UI
- [ ] 2–4 aktive Fähigkeiten pro Klasse (Hotbar-/Item-basiert), Cooldowns

### 1.4 Mobs & Kampf
- [ ] Fraktions-Wachen (greifen gegnerische Fraktion an)
- [ ] WoW-artige Startzonen-Mobs: z. B. kämpferische Wildschweine, Zombies,
      Wölfe — wiedererkennbarer WoW-Charakter in den leichten Biomen
- [ ] Neutrale/feindliche Mobs in Stufen: Grenze = schwach, Kernland = stark,
      Elite-Mobs die Gruppen erfordern
- [ ] **Gute Wegfindung** — gefährliche Mobs müssen ihre Ziele zuverlässig
      erreichen (nicht in Schluchten hängenbleiben o. ä.); Pathfinding-Qualität
      der Mob-Engine evaluieren und ggf. verbessern (Qualitätskriterium, kein
      Nice-to-have)
- [ ] Loot-Drops (Trash-Loot zum Verkaufen, Crafting-Materialien)

### 1.4b Loot & Verzauberungen
- [ ] Klassen-Items als Drops: Zauberstab, Magierrobe, Hexerrobe, Eisenrüstung,
      Eisenschwert, Dolch, … (pro Klasse ein paar Items)
- [ ] Einfaches Verzauberungs-System mit **Roll Ranges**: Items droppen mit
      zufällig ausgewürfelten Boni, z. B. Stärke +1 bis +3,
      Angriffsgeschwindigkeit +5 % bis +20 % (Werte in Item-Meta, sichtbar in
      der Beschreibung)
- [ ] Je Klassen-Item eine verbesserte Variante, die nur bei schweren Mobs
      (Elite/Kernland) droppt — mit besseren Roll Ranges

### 1.5 Quests (MVP: erzwungene Progression)
- [ ] Quest-Framework (Questlog-UI, Quest-Status in Player-Meta)
- [ ] Questgeber-NPCs in den Fraktionslagern
- [ ] Pflicht-Questlines für Level-Progression (Level-Gates), darunter:
  - [ ] „Töte 5 Wachen an der Grenze der gegnerischen Fraktion" (PvP-Trigger)
  - [ ] „Dringe ins gegnerische Gebiet ein und töte einen Elite-Mob" (Exploration + Risiko)
  - [ ] Sammel-/Kill-Quests in verschiedenen Biomen (Explorations-Zwang)

### 1.6 Berufe & Ökonomie
- [ ] Job-System: max. 2 Jobs pro Spieler, wählbar bei Job-Lehrern
- [ ] MVP-Jobs: **Kräuterkunde** (Pflanzen sammeln), **Alchemist** (Tränke),
      **Schmied** (Waffen/Rüstung), **Juwelensammler** (zufällige Gem-Drops beim
      Mining — Bergbau selbst kann jeder)
- [ ] Gold-System (Währung, persistent)
- [ ] Händler-NPCs: kaufen JEDEN Mob-Drop gegen Gold an, verkaufen Basiswaren

### 1.7 Karte
- [ ] Globale Karte mit Fog of War, pro Spieler freispielbar
      (vorhandene Map-Mods evaluieren, z. B. mapserver/„map" Mods; sonst eigene
      Lösung über HUD/Formspec)

---

## Phase 2 — Ausbau (nach MVP)

- [ ] Weitere Klassen: **Paladin**, **Schurke**, **Hexenmeister**, **Schamane**
- [ ] Weitere Jobs: **Schneider**, ggf. Verzauberer
- [ ] Mehr Questlines, Story-Bögen je Fraktion (WoW-inspirierte Lore-Adaption)
- [ ] Dungeons/Instanzen-artige Strukturen (feste Elite-Areale mit Boss + Loot)
- [ ] Raid-Bosse im tiefsten Kernland
- [ ] Reittiere (Mounts)
- [ ] Ruf-/Reputationssystem (vereinfacht)
- [ ] Auktionshaus-artiger Handel zwischen Spielern

## Phase 3 — Polish

- [ ] Eigene Texturen/Sounds/Modelle (WoW-Charakter, aber eigenständige Assets!)
- [ ] Balancing-Pass (Klassen, Mob-Tiers, Ökonomie)
- [ ] Server-Performance-Pass (Active Object Limits, ABM-Budget)
- [ ] Onboarding/Tutorial-Quests

## Bewusst NICHT geplant

- Gildensystem
- Battlegrounds/Arenen (evtl. viel später)
- Flugreittiere

# Backlog — Arbeitspakete

Grobe Ziele: [ROADMAP.md](ROADMAP.md). Dieses Dokument zerlegt sie in
**Arbeitspakete (WP)**, die jeweils in einer frischen Session/einem frischen
Context-Window umsetzbar sind. Regeln:

- Ein WP = ein kohärentes, testbares Inkrement mit Commit(s).
- Vor Arbeitsbeginn: AGENTS.md lesen; relevante Briefings in
  [docs/research/](docs/research/) überfliegen.
- Nach Abschluss: Status hier aktualisieren (✅ + Einzeiler was entstand),
  ROADMAP-Häkchen pflegen, `tools/sync_to_luanti.sh`, committen.
- Erkenntnisse, die künftige Sessions brauchen, gehören in AGENTS.md
  (Konventionen) oder docs/ (Details) — nicht nur in den Chat.

## Phase 1 (MVP)

| WP | Titel | Status | Hängt ab von |
|----|-------|--------|--------------|
| WP0 | Fundament: Skelett, BASE, mobs_redo, wow_core, wow_factions, wow_xp | ✅ | — |
| WP1 | Startzonen-Mobs: Wildschwein + Zombie, XP bei Kill, Loot-Drops | ✅ (Runtime-Test durch User ausstehend) | WP0 |
| WP2 | Territorien-Mapgen: Nord/Süd, Biome je Fraktion, Schwierigkeits-Gradient, Fraktionslager | offen | WP0 |
| WP3 | Klassen: Krieger/Magier/Priester, Wahl-Dialog, Stats über Level-Pipeline | offen | WP0 |
| WP4 | Fähigkeiten: 2–4 pro Klasse, Cooldowns, Mana/Ressource als HUD-Bar | offen | WP3 |
| WP5 | Loot & Verzauberungen: Klassen-Items mit Roll-Ranges, Elite-Varianten | offen | WP1, WP3 |
| WP6 | Fraktions-Mobs: Wachen, Mob-Tiers nach Distanz, Elite-Mobs | offen | WP1, WP2 |
| WP7 | Gold & Händler: Währung, Ankauf aller Drops, Verkaufs-UI | offen | WP1 |
| WP8 | Quest-Framework: Questlog, Kill-/Sammel-Ziele, Questgeber-NPCs | offen | WP1, WP7 |
| WP9 | Pflicht-Questlines: PvP-Quests (Grenzwachen), Elite-Quests, Level-Gates | offen | WP6, WP8 |
| WP10 | Jobs: Kräuterkunde, Alchemist, Schmied, Juwelensammler; max 2 pro Spieler | offen | WP7 |
| WP11 | Skill Trees: 2 Bäume/Klasse à ~5 Talente, Talentpunkte, Formspec-UI | offen | WP3, WP4 |
| WP12 | Globale Karte mit Fog of War (mcl_maps-Ansatz adaptieren) | offen | WP2 |
| WP13 | Startzonen-Content: Lager-Strukturen (Schematics), Spawn-Immunität | offen | WP2 |

### WP-Details (Akzeptanzkriterien)

**WP1 — Startzonen-Mobs**: Wildschwein (Tag, Wiese) und Zombie (Nacht) spawnen
und greifen an; Kill gibt XP abhängig vom Mob; Drops (Fleisch/Leder bzw.
Zombie-Trash-Loot als spätere Verkaufsware). Modelle/Texturen aus VoxeLibre
`mobs_mc` (GPL, Attribution). Helper `wow_mobs.register_mob`, der mobs_redo
um `_wow_faction`, `_wow_xp_reward` und XP-Vergabe via `on_death` erweitert
(Fraktions-Targeting-Grundlage über `do_custom`).

**WP2 — Territorien-Mapgen**: Neue Welt: nördlich von z=+64 nur
Horde-Biome, südlich von z=−64 nur Allianz-Biome, dazwischen neutrales
Grenzland; je Territorium ≥2 unterscheidbare Biome; Distanz-Funktion
`wow_core.difficulty_at(pos)` (0=Grenze … 1=Kernland) für Mob-Tiers;
begehbare Lager-Plattform an beiden Spawns. Entscheidung nötig:
Engine-Biomes (v7 + Biom-Registrierung) vs. eigener `on_generated`-Pass
(LotT-Stil) — Empfehlung wird in WP2 erarbeitet, Kriterien in
docs/research/ (Mapgen-Env beachten).

**WP3 — Klassen**: Nach Fraktionswahl folgt Klassenwahl (gleicher
Dialog-Flow, Pflicht); Klasse in Player-Meta; HP/Basis-Schaden skalieren
pro Level über `wow_xp.register_on_level_change`; Klassen-Registry in
`wow_classes` mit Platz für Fähigkeiten (WP4) und Skill Trees (WP11).

(Weitere WP-Details werden ergänzt, sobald das jeweilige WP ansteht.)

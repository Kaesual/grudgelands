# Round 51 follow-up — after the user's first GUI look

Coordinator: Claude, 2026-10-19, from the user's GUI feedback on the built Round 51 (main `473d658c`, not pushed).
Status: **built** 2026-10-19 (merges `c6fa76ff`, `107124cd`, `ef02ae36`, `898f64e1`); the user chose **B** (animated
textures) for §3. What shipped: the round plan's completion, "Follow-up lanes".

0.51.0 is not pushed yet, so these fixes ship **inside 0.51.0** (still the one map reset; no version bump). The
round plan's completion gets a "follow-up lanes" block (round workflow §4, post-merge status step).

## 1. The user's feedback (2026-10-19, quoted)

1. "Die 'Zufallsverteilung' von seagrass_1, 2 und 3 sieht komisch aus. Damit meine ich nicht die Zufälligkeit der
   Varianten, sondern dass Seagrass immer als zusammenhängende Fläche auftritt und recht 'scharf umrissene Flächen'
   bildet, die nach außen hin nicht auslaufen."
2. "Wasserpflanzen sind nicht animiert. Dadurch wirkt das Meer sehr statisch. Wäre es möglich, Seagrass und Kelp zu
   animieren?"
3. "Schildkröten und Frösche (und evtl. noch andere Wassermobs), die an der Oberfläche schwimmen, tauchen immer
   wieder auf und unter. […] Können wir die schwimmen lassen? Und haben Frösche eine Schwimm-Animation? Die
   'Spring-Animation', die sie gerade im Wasser machen, wäre aber auch okay. Vor allem sollten die Mobs auf gleicher
   Höhe direkt unter der Oberfläche schwimmen, statt immer zu springen."
4. "Die Baum-Dichte in allen Start-Städten ist ein bisschen zu hoch […]. Halbieren sollte passen. (Betrifft nur die
   Start-Städte, nicht die Hauptstädte.)"
5. "In der Untoten-Start-Stadt liegen zu viele Knochen herum. Auf dem Friedhof passt das super, aber außerhalb des
   Friedhofs sind es zu viele."
6. "Im Stadtkern der Untoten-Hauptstadt sind es noch mehr Knochen, VIEL zu viele. Die Troll-Hauptstadt hat im
   Stadtkern auch zu viel Bodendekoration. Ich glaube, die Dichte ist im Stadtkern einfach zu hoch, und im Rest der
   Stadt fehlt die Dekoration völlig. Außerdem wirkt der Bodenbewuchs in den Stadtkernen irgendwie zu gleichmäßig."
7. "In allen Hauptstädten außerhalb der Stadtkerne fehlt die Boden-Dekoration, zumindest die 'kleinen'
   Dekorations-Elemente sollten dort vorhanden sein (z. B. ein paar Knochen hier und dort bei den Untoten, Gräser bzw.
   gebietstypische Dekorationen bei den anderen Hauptstädten)."
8. "Die Seen in der Troll-Hauptstadt und der Elfen-Hauptstadt haben keine Fische. Sie sollten keine Kampf-Mobs
   haben, aber dekorative Fische, Pflanzen und ein paar Seerosenblätter wären schön. Generell sollten die
   'Land-Seen' ein paar Pflanzen und Fische haben."

## 2. Lanes

Three Opus lanes in parallel, each with an independent review; merge order FW → FT → FM (FW and FT share mapgen
files; FM touches mobs only).

| Lane | Items | Main files (leads, re-check) |
|---|---|---|
| **FW** water plants | 1, 2, 8 (wild lakes' plants) | `wp40/seabed.lua`, `world_content.lua`, `world_content_catalog.lua` (T3's meadow rule); the seagrass nodes and `default:sand_with_kelp`; wild-lake rows (waterlily, underwater weed) |
| **FT** towns | 4, 5, 6, 7, 8 (capital lakes' plants and lily pads) | the town tree placement (`wp40/r7_settlement.lua`, the start towns' files in `wp13/`), `wp13/dressing.lua` (`undergrowth`, `blight_flora`, `undergrowth_at`), `wp13/stillgrave.lua`, `wp13/nhal_veyr*.lua`, `wp13/kezamba.lua`, `wp13/lethariel.lua`, the other capitals, `wp40/r7_capital_blueprint.lua` |
| **FM** water mobs | 3, 8 (fish in land lakes, none hostile in capital lakes) | `grug_mobs/tortoise.lua`, `frog.lua` (the model's swim clip 250–350 is unused today), `crocodile.lua`, the `floats` path in the vendored `mobs` API and `grug_mobs` wrappers, the lake band of `spawn_regions_core.lua`, the Reed Angelfish and the goby rows |

### FW — water plants

- **Meadows that fade out (item 1):** seagrass meadows keep their cores but thin out toward the edge (density falls
  over a few nodes, a few single tufts beyond the edge), so no meadow has a sharp outline; the three variants stay
  mixed. Kelp meadows the same if they show the same hard edge. The renewal rule follows the generator (shared
  rule, as T3 built it).
- **Animation (item 2):** the user's choice **B** (§3): Astra (lane FA) draws a few sway frames for the three
  seagrass variants and a kelp texture of our own; the user picks on a page; FW wires them as tile animations
  (`waving` stays 0).
- **Wild land lakes (item 8):** a few plants in and on lakes — waterlily pads at the surface near the shore and an
  underwater weed on the bed (use the existing freshwater nodes; find what exists: the swamp's waterlily, the
  freshwater waterweed LG mentions) — at rough densities, regrowing like the other water plants. Swamp pools keep
  their Round 47 look.

### FT — towns

- **Start towns (item 4):** halve the tree density in the six start towns (not the capitals). Find where the town
  trees come from (Round 47's town greening) and halve there; report before/after counts on one seed.
- **Undead start town (item 5):** Stillgrave keeps its graveyard as it is; outside the graveyard the bones drop to a
  sparse scatter (rough target: about a quarter of today's outside count; report the numbers).
- **Capital cores (item 6):** the ground decoration in capital cores is too dense and too even — cut the density
  clearly (Nhal Veyr's bones most of all; Kezamba's undergrowth) and break the evenness (patches and gaps, not a
  uniform field).
- **Capital outskirts (item 7):** the parts of each capital outside its core get small zone-typical ground decoration
  (grass and the zone's small plants; a few bones here and there at Nhal Veyr), sparse.
- **Capital lakes (item 8):** Kezamba's and Lethariel's lakes get a few water plants and lily pads (the town writer
  owns those lakes); fish come from FM.
- The terrain guard and the plan rules as in Round 51; seed fleet `quick` before the merge.

### FM — water mobs

- **Swimming at the surface (item 3):** amphibians and any other water mob that bobs (tortoise, frog; check the
  crocodile, the crab in water, the Reed Angelfish) swim at a steady height just under the surface instead of the
  float-jump cycle; on land they walk as before; they still follow a player ashore (the M1 navigation test again).
  The frog uses its swim clip (250–350) in water if it reads well; otherwise its jump clip is fine (the user).
- **Fish in land lakes (item 8):** decorative critter fish in wild lakes and in the capitals' lakes (Kezamba,
  Lethariel and any other capital with a lake); no hostile or combat mob in a capital's lake (frogs and crocodiles
  stay out); critters never kill targets.

## 3. Decision for the user: how seagrass and kelp move

The engine can wave rooted water plants (`waving = 1` on `plantlike_rooted`, `node_visuals.cpp`), but only for
players who switch on **"Waving plants"** in the client settings (default **off**, `enable_waving_plants`, shaders
needed). The server cannot switch it on.

- **A — waving only:** free, no art; most players see no movement unless they enable the setting.
- **B — animated textures (recommended):** a gentle sway drawn in a few texture frames (tile animation), which every
  client shows, the web client included; a small art job (the three seagrass variants and a kelp texture of our own,
  by Astra on a pick page) plus FW's wiring. Waving stays off so the two do not add up.
- **C — both:** animated frames for everyone, and waving on top for players who enabled it.

## 4. Rules

As in the round plan §5 and the common brief: fixtures by the usual sentence, independent review per lane (fix
deltas with logic changes too), no sounds, no references to existing games, the seed fleet `quick` for FT (and FW if
placement changes), a closing engine run with screenshots per lane, `tools/sync_to_luanti.sh` after merges, push only
on the user's word. Lane D's files: the coordinator (or a small docs step) adds the follow-up block to the completion,
the CHANGELOG 0.51.0 entry and the BACKLOG.

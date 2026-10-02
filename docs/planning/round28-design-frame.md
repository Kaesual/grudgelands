# Round 28 design frame (C0)

The frame for the Round 28 design round: what the designers (GPT-6 Astra)
deliver, in which data formats, inside which budgets and limits. Written by
the coordinator from the
[Round 28 plan](round28-questing-leveling-plan.md); the plan's rulings and
reasons are binding and are not repeated in full. Revised after Astra's
sparring pass and an independent Opus review. **Status: approved by the
user on 2026-10-01**, together with the zone atlas, the mob catalogue and
the design tools (all under [round28/](round28/)); the user's answers on
routes, difficulty, front shares, islands, metal fittings and new givers
are written in.

Track B implements exactly these formats; content lanes (E) port the designs
into the mods.

## 1. What the design must achieve

- Questing and leveling feel good, varied, exciting and replayable in every
  zone. A first character learns a lot; a second character profits from
  that knowledge (where to farm what, what a name means, which route suits
  which level).
- Every zone is a closed unit with its own progression: several spawn areas
  with fixed level ranges, quest hubs "in front of the door", lines that
  resolve something established earlier.
- Mob variety comes from **sub-types** of existing families (size, name,
  disposition, tint) and from the **behaviours** the families already have
  (packs, archers, ambushers, witches, constructs; see the mob catalogue).
- Professions are self-contained; their inputs combine **loot and mining**
  (and gathering) of the tier.
- Fewer, clearer quests that fit their areas; questing covers about 90 % of
  a start zone's XP and about 80 % elsewhere (Ruling 33).

### 1.1 Design method (from Astra's sparring pass)

- **Teach, practise, combine.** An early quest introduces one readable rule
  (neutral vs aggressive names, night spawns, sun burns zombies — not the
  Sun-Dried Husk, which does not burn); later quests combine it with another
  (a pack near a ranged enemy, a night hunt near an elite).
- **Reward preparation and route knowledge.** Ordinary materials can be
  collected before the quest asks for them; compatible quests share one
  outing; day and night create scheduling choices, so a daytime task is
  always available while a night hunt waits.
- **Each zone has a distinctive problem** (an identity brief: the local
  problem, a signature encounter, a useful discovery, the resolution). The
  race tracks share systems but differ in motive and ending (for example
  Human provisioning, Dwarven dangerous extraction, Elven stewardship,
  Undead preservation, Orc resource rivalry, Troll bargains with the wild).
- **Climaxes resolve something seeded in the line's first quest** (stolen
  feed → bandit requisitions → the chief's ledger as a guaranteed quest
  drop). Completion texts acknowledge the result without promising scripted
  world changes.

## 2. The player's journey and budgets

### 2.1 Routes (user, 2026-10-01)

Budgets are planned per **route**: the sum over all zones a player of that
race can use in that band. All percentages in §2.2 are route sums, never
per zone.

- **1–20, own race only:** start zone (1–10) → home zone (11–20). Each covers
  its band alone (§2.2).
- **20–30, the faction's seven zones:** the three capital outskirts (20–30)
  and the four heartland zones (21–30) of the faction. No single zone covers
  the band: each offers roughly 35–50 % of it, so a player quests in two to
  three of them and **visits at least one other race's zone of the own
  faction**. The own capital and the own race's heartland zone are the
  natural first stops; travel quests lead on to the sister races' zones.
  Mounts (from level 15) make the longer routes reasonable.
- **31–40, four zones:** the faction's three contested zones and The Broken
  Causeway (shared by both factions). Each offers roughly 30–40 % of the
  band; a player uses about three of them.
- **41–60, shared front:** The Shattered Line (41–50), Gravesalt Escarpment
  and The Skyglass Canopy (51–59), for both factions. Quest givers sit in
  the 31–40 outposts and the capitals (Ruling 43); each 31–40 outpost giver
  and one quest giver per capital reserve one of their two lines, named
  `front`, for the front lane; the front lane writes those quests into
  `zones/<host_zone>.front.quests.json` (§4.7). Contested zones with a
  single quest NPC (Glassroot Wilds, Thunderroot Wilds) are exempt.
- **Islands (60):** not part of leveling; reachable with flying mounts (from
  level 45, no boats yet, WP17); endgame content with coin and material
  incentives.
- **Quests may point into any zone of the own faction from 20 on, and into
  shared zones; never into another race's 11–20 zone** (Ruling 44).

### 2.2 XP units (Rulings 30–33)

- Kill XP of a normal mob: `M(L) = 25 + 5·L` (L1 30, L10 75, L30 175,
  L60 325). Elite ×4, rare ×6. A kill below the player's level is worth
  less than one same-level kill; above, it caps at player level + 5.
- XP for one level: `round(M(L) × k(L), tens)` with
  `k(L) = 8 + 0.29·(L − 1)`.
- **Kill equivalent (KE):** the XP of one same-level normal kill. Designers
  write quest rewards as **weights in KE** at the quest's reward level; the
  ledger tool converts everything into real XP (KE at different levels are
  not additive).

| Band | KE to cross (levels) | Questing target | Reward share | Quest-demanded kills and gathering | Free play |
|---|---|---|---|---|---|
| 1 → 10 | 82 (L1–9) | ≈ 90 % | ≈ 40 % | ≈ 50 % | ≈ 10 % |
| 10 → 20 | 119 (L10–19) | ≈ 80 % | ≈ 40 % | ≈ 40 % | ≈ 20 % |
| 20 → 30 | 148 | ≈ 80 % | ≈ 40 % | ≈ 40 % | ≈ 20 % |
| 30 → 40 | 177 | ≈ 80 % | ≈ 40 % | ≈ 40 % | ≈ 20 % |
| 40 → 50 | 206 | ≈ 70 % incl. repeatables | ≈ 35 % | ≈ 35 % | ≈ 30 % |
| 50 → 60 | 235 | ≈ 70 % incl. repeatables | ≈ 35 % | ≈ 35 % | ≈ 30 % |

Kill counts follow from the "quest-demanded" column. Players should leave
a start zone at level 10, not 15. The targets apply to a **solo** player
(Human routes measured with the +10 % quest bonus, `--human`);
the ledger also reports a two-player journey for information (kill XP is
split, quest credit is not, each member needs their own requested items, so
a duo questing share is naturally lower).

### 2.3 Gathering

Ore 0.10, gem 0.20, fish 0.33 KE (reference level capped at player level
+ 5). Reward weights for gathering requests account for travel and time,
not only XP. The ledger records time for travel, combat, collection,
respawn and waiting for the right clock separately.

### 2.4 Difficulty promise (user, 2026-10-01)

- The **main route** of every band is completable **solo** by every class at
  the band's level with quest-reward and vendor-level equipment.
- **Line climaxes in 1–30** are **named normal-tier leaders** (fixed spot,
  level at the top of the area, about 5 min respawn), not elites. From 31
  on a climax may be an elite; elite climaxes in the main route are marked
  "Group" when a solo player is not expected to win, and the route still
  reaches its target without them.
- Optional content (group quests, repeatables, rares) is labelled as such.

### 2.5 Counts and limits (binding)

- ≤ 2 quest givers per hub; each giver has **at most two lines in total**
  (a line is a named chain of quests given one after another; ≤ 4 active
  quests per hub). Repeatables belong to one of those two lines (often its
  tail, or a giver's dedicated `bounties` line).
- Free quest sockets without an NPC (Highcourt, Dur
  Brannoc, Lethariel, Gor Drazhak; atlas) may each get one new giver,
  written as `{"npc": "<new id>", "new": {"name", "race", "socket"},
  "lines": [...]}` in the hub (Track E creates the NPC); it counts toward
  the two-giver limit. Everywhere else givers are existing NPCs. Only NPCs with a quest socket can give quests; many
  villages and outposts have one, so their hub has one giver.
- **Start towns:** the elder gives a **hunt line** (kill quests) and a
  **tools line** (tools, ores, bars); the cook gives a **pantry line** (drop
  requests: crab legs, fox tails, rat fur … — mob contact without a second
  kill line) and a **kitchen line** (coal, meat, staples). That is the
  user's "2× kill, 2× gather" within two lines per giver.
- Start zones: about five kill quests in total, at the low end of 8–10
  targets (5 for scarce targets such as crabs); a geographic area may host a
  day and a night quest (Small Boars and Large Rats share the home fields).
- Each mob family has at most **two signature items per band**, and only
  for family/band combinations that actually occur; enchant inputs are
  chosen from those; at most about two new universal reagents per tier.
  These are ceilings. C1 reports the world-wide count of new items (C4's
  icon count).
- Every stat loot input of a tier is obtainable in **every** race track's
  zones of that band (both factions).
- Sub-type size factor 0.75–1.3 (elite tier 1.4 is separate).
- Aggressive areas: idle aggressive mobs drift about their view range
  (6–16 nodes) away from roads, towns and villages (Ruling 2); no area may
  lie mostly inside that drift band.
- In a zone with areas, shore mobs (crabs) spawn only through areas (use
  `shore: true`); gulls stay ambient critters (`critters`). Underground and
  water spawns are unchanged.
- No mapgen, no new POIs, roads, mob models or skins. Underground spawns,
  water and swimmers, rares, vendors and guards keep today's rules; rares
  are never quest targets (Ruling 38).
- A zone's existing quests (including the tool lessons and envoy travel
  quests) are fully replaced by its new quest file; the new design keeps
  the travel handoffs the route needs (start → home zone, home zone →
  capital, capital → 21–30, 21–30 → 31–40).
- Objective types: kill (optionally limited to an area), item (single item
  or group), talk (travel; the only objective of its quest), several
  objectives per quest, quest-only drops. No node interaction, no arrival
  objective.

## 3. Deliverables per design lane

All design files live under `docs/planning/round28/design/`, JSON (UTF-8,
two-space indent) with a short Markdown narrative. Ids are lowercase
`snake_case`. Every file passes `tools/r28_design/validate.py`; every
track runs through `tools/r28_design/ledger.py` with no unexplained flag
(the targets are rough guides; a flag is fine when the narrative explains
it).

| Lane | Files |
|---|---|
| C1a world catalogue | `catalog/subtypes.json`, `catalog/items.json`, `catalog/drops.json`, `catalog/tints.json` |
| C1b economy catalogue | `catalog/enchants.json`, `catalog/reagents.json`, `catalog/bounties.md`, `catalog/calibration.md` |
| C1 editor | `catalog/README.md` (supply vs demand reconciled) |
| C2 Human track | `zones/<zone_id>.spawns.json`, `zones/<zone_id>.quests.json`, `zones/<zone_id>.md` (identity brief + narrative) for Dawnmere Fields, Goldmead Vale, Highcourt (outskirts), Whitebridge Shire; `ledger/human.md` |
| C3a–e race tracks | the same for the Dwarf, Elf, Undead, Orc and Troll tracks |
| C3f contested | the six 31–40 zones; `ledger/contested.md` |
| C3g front | Broken Causeway, Shattered Line, Gravesalt, Skyglass, both islands (their spawns and md files); the front quests in `zones/<host_zone>.front.quests.json` for each 31–40 outpost and capital host; `ledger/front.md` |
| C4 art | `art/` originals, 16×16 PNGs, `art/manifest.json` |

Together C2 and C3 cover all 38 zones exactly once (ownership manifest in
`design/README.md`, written by the coordinator).

## 4. Data formats

### 4.1 Sub-types (`catalog/subtypes.json`)

```json
{
  "role": "small_boar",
  "family": "boar",
  "base": "grug_mobs:boar",
  "display": "Small Boar",
  "display_by_zone": {"kragmar_kapok_cradle": "Small Jungle Boar"},
  "tint_by_zone": {"kragmar_stillgrave_hollow": "plague"},
  "size": 0.85,
  "disposition": "neutral",
  "tier": "normal",
  "levels": [1, 3],
  "drops": "boar",
  "notes": "First kill target in boar start zones."
}
```

- `role` becomes the entity name `grug_mobs:<role>`; it must not collide
  with an existing entity name. Existing mobs may be used unchanged: their
  role is their current name without the mod prefix (`giant_rat`).
- `base`: the existing registration whose model, animations and behaviour
  the sub-type reuses (mob catalogue).
- `disposition`: `neutral` (yellow, retaliates), `aggressive` (red),
  `critter` (white; never a kill target).
- `tier`: `normal` (default) or `elite`. Named leaders are sub-types with
  `"leader": true` (normal tier in 1–30, §2.4).
- `levels`: the widest range the role may appear at; areas narrow it.
- `tint_by_zone`: a tint id from `catalog/tints.json`, whose entries are
  `{"id", "texture"}` (an existing baked texture) or `{"id", "modifier"}`
  (a texture modifier such as `^[multiply:#a0b070`).
- Day or night is decided only by the area's `clock`.

### 4.2 Items (`catalog/items.json`)

```json
{
  "id": "grug_mobs:rat_tail",
  "name": "Rat Tail",
  "tier": 1,
  "family": "rat",
  "kind": "signature",
  "description": "Long, bald and surprisingly tough.",
  "uses": ["enchant:dex:t1", "quest"],
  "icon": "A pale pink rat tail curled into an S on a dark plate."
}
```

`kind`: `signature`, `generic` (reuse existing meat, leather, cloth, bone…),
`reagent`, `quest` (quest-only drop). Existing items keep their ids
([round28/items/existing.md](round28/items/existing.md); never items curated
out by `grug_materials/content_curation.lua`). Item groups for quest
objectives are listed there too (e.g. `group:tree`).

### 4.3 Drops (`catalog/drops.json`)

```json
{
  "family": "rat",
  "bands": {
    "1": [
      {"item": "mobs:meat_raw", "chance": 1, "min": 1, "max": 1},
      {"item": "grug_mobs:rat_tail", "chance": 3},
      {"item": "grug_mobs:rat_fur_patch", "chance": 4}
    ]
  },
  "leader_bonus": [{"item": "grug_mobs:rat_tail", "chance": 1, "min": 2, "max": 3}]
}
```

`chance` = 1 in N. The band is the mob's level band (1–10 → "1" …). Metal
drops are rare and tier-matched (bronze in band 1, never iron). Leaders add
`leader_bonus`.

### 4.4 Enchants (`catalog/enchants.json`)

```json
{
  "tier": 1,
  "stat_loot": {"str": "grug_mobs:boar_tusk", "dex": "grug_mobs:fox_tail",
                "int": "grug_mobs:crab_eye", "max_mana_percent": "grug_mobs:crab_eye"},
  "family_input": {"sword": "grug_materials:tin_bar", "bow": "grug_materials:quartz",
                   "leather_armor": "grug_materials:copper_bar"}
}
```

- An enchant at tier T for equipment family F and stat S costs: the
  family's **own material** of tier T + `stat_loot[S]` + `family_input[F]`.
  Own materials: Armorsmith the metal bar, Leatherworker the leather grade,
  Tailor the cloth bolt, Woodcarver the seasoned wood, Goldsmith the
  setting; Weaponsmith the metal bar (user, 2026-10-01: metal fittings are removed
  entirely).
- `family_input` keys: sword, dagger, greataxe (Weaponsmith); metal_armor,
  shield (Armorsmith); leather_armor (Leatherworker); cloth_armor (Tailor);
  bow, caster_weapon (Woodcarver); spellbook, trinket (Goldsmith).
- An existing item used as stat loot (e.g. `grug_mobs:boar_tusk`) also gets
  an `items.json` entry of kind `signature` with its existing id.
- Prefix and suffix share these inputs; trinket prefix and suffix pools
  differ (`grug_quality/init.lua` POOLS) but use the same `stat_loot`.
- `family_input` may be from an earlier tier, a gem, an alloy ingredient,
  a gathered material or a universal reagent; it varies per family for
  variety. Stats: str, dex, int, attack_speed_percent, crit_percent,
  max_hp_percent, max_mana_percent, dodge_percent, armor_rating.
- No profession needs another profession's product.

### 4.5 Reagents (`catalog/reagents.json`)

```json
{"id": "grug_materials:glittering_tin", "name": "Glittering Tin", "tier": 1,
 "method": "grid", "inputs": ["grug_materials:tin_bar", "grug_materials:quartz"],
 "output_count": 2, "uses": ["enchant family_input"]}
```

`method`: `grid` or `furnace` (anyone can make them).

### 4.6 Spawn areas (`zones/<zone_id>.spawns.json`)

```json
{
  "zone": "elandor_dawnmere_fields",
  "critters": ["rabbit", "wild_turkey"],
  "areas": [
    {
      "id": "home_fields_day",
      "anchor": "start",
      "offset": [0, 0],
      "shape": {"kind": "band", "forward": [-400, 0], "side": [-250, 250]},
      "hosts": {"biomes": ["any"], "shore": false},
      "clock": "day",
      "levels": [1, 3],
      "species": [{"role": "small_boar", "weight": 3}],
      "notes": "Behind the town toward the ocean."
    },
    {
      "id": "border_bandits",
      "anchor": "start",
      "offset": [-160, 200],
      "shape": {"kind": "circle", "r": 38},
      "hosts": {"biomes": ["any"]},
      "clock": "both",
      "levels": [9, 10],
      "species": [{"role": "confused_bandit", "weight": 1}],
      "camp": {"slots": 6, "respawn": [30, 60], "min_player_distance": 16}
    },
    {
      "id": "fallback",
      "anchor": "zone",
      "shape": {"kind": "zone"},
      "hosts": {"biomes": ["any"]},
      "clock": "both",
      "levels": [3, 6],
      "species": [{"role": "small_boar", "weight": 1}],
      "fallback": true
    }
  ],
  "leaders": [
    {"role": "confused_bandit_chief", "anchor": "start", "offset": [-160, 200],
     "level": 10, "respawn": 300}
  ]
}
```

- **Trigger (Ruling 34):** a zone whose `areas` list is empty keeps today's
  palette and level field. Track B writes every zone's file with empty
  areas first; a design fills them.
- `anchor`: an anchor id from the zone atlas (`anchor_015`), a settlement
  key (`goldmead_village`), a slot (`village_1`, `outpost_1`, `clash_1`,
  `rare_<name>`), `start`, `capital`, or `zone` (the zone hub). `offset` is
  `[x, z]` in **world axes** (nodes), applied to the anchor; the result must
  lie inside the zone (the validator checks it). A band is measured from the
  offset point.
- `shape`: `circle` (`r`), `ring` (`r`: [min, max]), `zone` (the whole
  zone) or `band`. A band is measured from the anchor + offset point along the **front
  axis** (`forward`, positive toward the Battlegrounds: +z on the Elandor
  continent, −z on the Kragmar continent) and the side axis (`side`, +x).
  Front zones and islands (around z = 0) may not use `band`.
- Areas are **clipped to their zone**. Overlapping areas combine their
  species (weights add). A `fallback` area applies at a point and time only
  where no other area of the zone matches that point, clock and host; every
  zone has one, so no land is empty at any hour.
- `hosts.biomes`: biome ids from the atlas (badlands, badlands_east, beach,
  blight, bone_forest, crags, crags_snowy, deep_forest, deep_jungle,
  elf_forest, jungle_edge, jungle_fringe, meadows, pine_hills, savanna,
  swamp) or `any`; `shore: true` restricts to land near water (beaches),
  absent or false means no restriction.
- `clock`: `day`, `night` or `both`. `levels`: fixed range inside the zone's
  band and inside each role's `levels`. Every level of a kill or drop
  target's area (or a leader's fixed level) must lie within the quest's
  reward level ±3 (`LEVEL_SLACK`, containment; the same in the validator and
  in Track B's load-time check). `cap` (optional): at most this many
  of the area's mobs alive near a player.
- `camp` (optional) turns the area into slot spawns (bandits, poachers,
  mirefolk): `slots`, `respawn` [min, max] seconds, `min_player_distance`;
  radius about 35–40 so two players do not block it.
- `critters`: ambient critters that keep spawning in a zone with areas.
- `leaders`: named leaders (§2.4), snapped to the surface at anchor +
  offset; elite leaders only from 31.
- Every mob remembers the id of the area it spawned from; area-limited kill
  objectives credit by that tag, not by death position.

### 4.7 Quests (`zones/<zone_id>.quests.json`)

```json
{
  "zone": "elandor_dawnmere_fields",
  "identity": "Dawnmere feeds Highcourt; this year something is eating the harvest first.",
  "hubs": [
    {
      "id": "dawnmere",
      "anchor": "start",
      "givers": [
        {"npc": "r14_human_elder", "lines": ["hunt", "tools"]},
        {"npc": "r20_human_start_cook", "lines": ["pantry", "kitchen"]}
      ]
    }
  ],
  "quests": [
    {
      "id": "dawnmere_hunt_01",
      "line": "hunt",
      "giver": "r14_human_elder",
      "turnin": "r14_human_elder",
      "min_level": 1,
      "level": 2,
      "requires": [],
      "title": "Crop Thieves",
      "text": "During the day, Small Boars have been stealing our crops south of Dawnmere. Drive them off before the harvest is gone.",
      "objectives": [
        {"type": "kill", "roles": ["small_boar"], "count": 8,
         "area": "elandor_dawnmere_fields/home_fields_day"}
      ],
      "rewards": {"weight": 4, "copper": 10, "items": []},
      "lesson": "Yellow names are neutral: they only fight back.",
      "duration_min": 8
    }
  ]
}
```

- `npc`: registered quest NPC ids from the atlas (only NPCs with a quest
  socket).
- `min_level`: when the quest can be accepted; `level`: the reward level.
- `requires`: quest ids, also across zones (Track B registers in dependency
  order).
- Objectives: `kill` (`roles` list, `count`, optional `area` as
  `zone_id/area_id`; a kill of a leader carries no area, the leader's fixed
  spot and level apply, also from another zone); `item` (`item` or `group`, `count`); `talk` (`npc`;
  the only objective of its quest; credited on accept, Ruling 39).
- `quest_drops` (optional list): `{"item", "roles", "area"?, "chance"}`;
  each pairs with an `item` objective of the same quest and an
  `items.json` entry of kind `quest`; rolled per eligible participant who
  has the quest, straight into the inventory (dropped at the feet when it
  is full).
- `repeatable` (optional): `{"cooldown": seconds}`; the cooldown starts at
  turn-in; shown as "Repeatable"; prerequisites of other quests count the
  first completion.
- `rewards`: `weight` (KE at `level`), `copper`, `items` as
  `[{"item": id, "count": n}]` (existing or catalogue items). C1 proposes
  the copper rule.
- **Front file** `zones/<host_zone>.front.quests.json`: same format, only
  `quests` (no hubs); every quest uses its giver's line `front`, which the
  host zone's own quest file declares; the host's own quests never use line
  `front`. Validation and the ledger merge it into the host zone.
- Design-only fields: `lesson`, `duration_min`, `optional`, `climax`,
  `group`.
- Legacy-only (B4's mechanical split of today's quests, not for new
  designs): fixed `xp`, `mobs`, `zone` on kill objectives, `faction` and
  `race` gates.
- Texts: English, two to four sentences, say where and when (day/night) the
  targets live, teach a mechanic where natural, light humour welcome, the
  voice of the giver's race.

### 4.8 Bounties (`catalog/bounties.md`)

Bounties are `repeatable` quests in the zone quest files, given by existing
givers (zone hubs in 1–40; 31–40 outposts and capitals for the front). C1
defines how many per giver, the cooldown range, reward weights (below
one-time quests) and how they are grouped into small compatible bundles
(hunting, material recovery, optional elite work).

### 4.9 Ledger (`ledger/<track>.md`)

Output of `tools/r28_design/ledger.py` for the route, solo and duo, plus per
kill quest: area, count, species mix and level, expected time, and a note on
reachability (E lanes measure it in the game).

### 4.10 Notes for Track B (from the mob catalogue)

- Name-keyed mechanics (quest kill matching, density weights, group alert,
  pack calls, swarms) match the exact entity name today. Sub-types of one
  family must share group alert, pack calls and swarms by **family** (B2);
  density weights and quest matching stay per role (quests list several
  roles when they mean a whole family).
- Neutral disposition switches the group alert off: neutral sub-types are
  single pulls. The Fox is aggressive today, so a neutral "Young Fox" is its
  own role.
- Only the Zombie burns in the sun (not the Sun-Dried Husk, not skeletons;
  zombies spawned on blight dirt never burn). Rift Spawn bursts give no
  credit and cannot be kill targets.
- Several palette entries have no host surface in their zone today (mob
  catalogue §3); areas replace those palettes.

## 5. Naming

User rule, 2026-10-02 (Round 28 Lane N1); it replaces the earlier
"size or temper first" rule. The applied names and the reason for each
change are in [names-proposal.json](round28/mobs/names-proposal.json);
`tools/r28_names/build_review.py` checks the rules below and renders the
review page [catalogue-review.html](round28/mobs/catalogue-review.html).

- **Signal words only in start zones.** Words that announce size, age,
  strength, temperament or wits (Small, Young, Large, Aggressive,
  Monstrous, Braindead, Sluggish, Confused …) appear only on roles of the
  six start zones (levels 1–10). There they form one ladder, the same in
  all six starts; the rung is the role's first level:

  | Column | L1–3 | L3–5 | L5–7 | L7–9 | L9–10 |
  |---|---|---|---|---|---|
  | Neutral animals (yellow) | Small | Small | Young | — | — |
  | Hostile animals (red) | Large | — | Aggressive | Monstrous | — |
  | Zombies and husks | — | Braindead | Sluggish | Monstrous | — |
  | Bandits, poachers, chiefs | — | — | — | Confused | Confused |

  Examples: Small Boar, Large Rat, Aggressive Rat, Small Crab, Monstrous
  Crab, Braindead Zombie, Monstrous Drowned Zombie, Young Fox, Confused
  Bandit. Retired words: Giant, Rabid, Irritable, Prowling, Furtive,
  Befuddled, Muddled, Misguided, Quiet. Item names carry a signal word only
  at tier 1.
- **Everywhere else every sub-type has its own name.** No display name
  (default or `display_by_zone` variant) is used by two roles, by a base
  mob or by a rare; at most three words; it describes the creature in its
  place (ecology, look, local flavour), in English, fitting the zone's
  culture. Roles of one family that share a zone differ in more than their
  first word (Tidepool Crab and Reefclaw Snapper, Debtbound Zombie and
  Tithe Revenant); across zones a place word plus the family noun may
  repeat (Bank Crab, Breakwater Crab). A role in several zones may keep one
  name. Disposition is shown by the yellow or red name tag, not by the
  name.
- **Kill quests always name the exact sub-type and place**, so every name
  must be unmistakable on its own.
- **Named leaders keep "Title Name".** The six start chiefs carry the ladder
  word: Confused Bandit Chief Crumb, Confused Ore Chief Bracket. Leaders
  elsewhere follow the no-signal-word rule; the three-word limit does not
  apply to them.
- Race-specific families (Plague Boar, Jungle Boar, Sun-Dried Husk,
  Scorpion, Viper …) keep their identity through `display_by_zone` and
  tints. Role and item ids never change with a display name.

## 6. Process

1. The user approves this frame together with the atlas, mob catalogue and
   tools.
2. **C1a and C1b** (Astra, parallel), then one editor pass reconciling
   supply and demand; Opus reviews; the user sees the catalogues with C2.
3. **C2** (Astra, one owner) designs the complete Human route with ledger
   (solo and duo). The user approves geography, pacing, teaching, the
   climaxes and the ledger — not only the prose.
4. **C3a–g** (Astra, seven lanes in parallel) with the frozen catalogues,
   atlas, approved C2 and reserved front slots. Opus reviews each; a final
   consistency pass checks references, giver capacity, prerequisite
   reachability, clock and habitat availability, faction access, ingredient
   supply, route XP and repeated narrative beats.
5. After the content is in the game: a solo route, the same as a duo, and
   an informed second character on the Human route; record level gaps,
   waiting, travel and climax difficulty.
6. Designers never change rulings; an open point goes into
   `## Blockers / questions` with a recommendation.

# Round 28 design tools

Tools for the Round 28 design round (plan:
`docs/planning/round28-questing-leveling-plan.md`, data formats:
`docs/planning/round28-design-frame.md` §4). Python 3 standard library only;
no network, no engine needed except to refresh the item catalogue.

Design files live under `docs/planning/round28/design/` (`catalog/`,
`zones/<zone_id>.spawns.json`, `zones/<zone_id>.quests.json`, and
`zones/<host_zone>.front.quests.json` for the front lane's quests given in a
31–40 or capital zone, and `zones/<zone_id>.catalog.json` for a zone's own
leader roles and quest-only items). Both tools
read that directory by default; `--design DIR` points them elsewhere (for
example your own worktree's copy).

## 1. Existing items: `docs/planning/round28/items/existing.md`

The reference of every registered item, item group, mob entity and quest NPC
a design may use, generated from the real registry. Read `existing.md`; the
tools read `existing.json`. Never use anything under "Curated out".
The catalogue's own registrations (its sub-types and the new loot items
grug_mobs registers from the shipped copy of `catalog/items.json`) are left
out: the tools take those from the catalogue.

Refresh it after mod changes (one short headless boot, about 40 s):

```sh
LC_ALL=C tools/r28_design/dump_items.sh            # rewrites existing.{json,md}
LC_ALL=C tools/r28_design/dump_items.sh /tmp/x     # also keeps the raw dump and server log in /tmp/x
pgrep -f '^luanti.bin'                              # must not list a server of yours
```

`dump_items.sh` stages the disposable probe mod
`items_probe/grug_probe_r28_items` through `tools/luanti_headless.sh` and runs
`items_catalog.py` on the dump.

## 2. Spawns files: the spawn recipe

`zones/<zone_id>.spawns.json` is `{"zone": id, "recipe": {...}, "notes"?}`
(a shipped game file without a recipe carries only `palette`, today's
spawn rule). The recipe holds rules, never coordinates; the game turns it
into a region map for each world seed. Format and rules:
`docs/design/spawn_regions.md`; the game's parser,
`mods/ENTITIES/grug_mobs/spawn_regions_core.lua` (`parse_recipe`), is the
reference, and `r28common.parse_recipe` mirrors it. In short:

- `from: {"anchor": <slot or anchor id, or a list>}` or `{"border": <zone
  id or list>}` (the entry), `to: {"border": <zone id or list>}` (other zones
  only) or `{"core": true}` (the cells farthest from every source are the
  top belt): progress runs from the entry to the exit. A one-belt recipe
  may omit `to`, and then `from`.
- `belts`: `{id, share, levels: [lo, hi], max_from?, kinds}`; shares add up
  to 100; `kinds` keyed by terrain type (`shore`, `bank`, `swamp`,
  `forest`, `highland`, `open`), `open` required (the parent of the others).
- A kind: `{id, name, day, night, density}`; `day`/`night` is a roster (one
  main role and at most one minor role of at most 25 % of the weight, as
  `{role, weight}`) or `"open"` (the belt's open kind's roster; not in the
  open kind itself); density `sparse`, `normal` or `dense`.
- `camps`: `{id, name, belt, roster, slots, respawn: [a, b],
  min_player_distance, apart, site?}`. Kind and camp ids are unique in the
  zone. `site`: `"generate"` (default) or `{"poi": "bandit" | "mirefolk",
  "name"?: <POI name>}`: on a camp POI of the zone (the atlas `camps`);
  `belt` stays required (exact quest levels; the renderer's stats name the
  belt the POI lies in per seed and warn when it is more than one belt
  away) and `apart` is not allowed.
- `leaders`: `{role, at: {"camp": id} | {"kind": id, "pick":
  "farthest_from_roads"}, respawn}`; the role is marked `"leader": true`
  in the catalogue, placed once, and stands at the top of its belt's levels
  within its own.
- `critters`: a list of critter roles.
- Levels: a role in a kind or camp is met at the belt's levels within the
  role's catalogue levels (they must meet; an existing mob without a
  catalogue row is unrestricted); a kind's or camp's levels are the union
  over its roles.

To see the regions a recipe gives on real worlds, render it:
`tools/r28_regions/run.sh <zone_id> [out_dir] [seed ...]` (the game's own
code over the analytic world, several seeds).

## 3. Validate a design: `validate.py`

```sh
python3 tools/r28_design/validate.py                         # whole design dir
python3 tools/r28_design/validate.py --atlas docs/planning/round28/zones/
python3 tools/r28_design/validate.py --zone elandor_dawnmere_fields --quiet
python3 tools/r28_design/validate.py --game --atlas docs/planning/round28/zones/ --zone <your zones>   # a content lane's shipped files
python3 tools/r28_design/validate.py --game --legacy --atlas docs/planning/round28/zones/   # the whole shipped set incl. legacy quests
```

- `--game` reads the zone files from the game
  (`mods/ENTITIES/grug_mobs/data/zones` and
  `mods/PLAYER/grug_quests/data/zones`) instead of the design's `zones/`;
  the catalogue stays the design's. A content lane checks its own zones
  **without** `--legacy` (that option lets a quest through with a fixed `xp`
  or without `weight`); `--legacy` is only for the whole shipped set while
  legacy quests ship.
- Quest texts (Round 29 Q1, [quests.md](../../docs/design/quests.md#for-content-lanes)):
  `E-placeholder` (a brace outside a well-formed placeholder, an unknown
  placeholder, a wrong argument count, a direction placeholder in a title),
  `E-placeholder-target` (not a kind or camp of the zone's recipe or a
  leader), `E-placeholder-place` (not a settlement key or anchor id; with
  `--atlas`), `W-placeholder-spread` (`{dir_from_giver:...}` on an open kind),
  `E-compass` (a fixed compass word in a title or text). The game checks the
  same at load (`grug_quests/validate.lua`).

- Checks every catalogue and zone file against the frame's formats
  (required fields, id formats, enums, level ranges) and the
  references between them: roles exist (catalogue sub-type or existing mob),
  items exist (catalogue or `existing.json`, never curated out, never skill
  items), NPCs are quest NPCs (today's registry, plus the atlas), areas used by
  quests (a kind or camp of the zone's recipe) exist and host the target, `quest_drops` pair with an item objective
  and a catalogue item of kind `quest`, prerequisites exist and have no cycle.
- Zone catalogues: `zones/<zone_id>.catalog.json` = `{"subtypes": [...],
  "items": [...]}` in the formats of `catalog/subtypes.json` and
  `catalog/items.json`. Both tools merge them into the catalogue: role and
  item ids are unique across the global catalogue and every zone addition
  (`E-duplicate`), and a zone-added role or item may be used from any zone's
  files. A zone catalogue adds only leader roles (`"leader": true`) and
  quest-only items (kind `quest`) (`E-zone-catalog`); a zone-added leader is
  a leader of that zone only (`E-zone-leader` in another zone's recipe `leaders`,
  `W-zone-leader` when its own zone does not place it). Its drops come from
  its family's `leader_bonus` in `catalog/drops.json`.
- Sub-type bases: a sub-type of a critter base stays a critter
  (`E-critter-base`), and an aggressive role needs a base with an
  `attack_type` (`E-attack-type`; from the mob catalogue
  `docs/planning/round28/mobs/catalogue.json`, `--mobs` to point elsewhere).
  B2 enforces both in the game.
- Limits: at most 2 givers per hub and 2 line names per giver (front
  included), a giver in one hub only, critters never kill targets, sub-type
  size 0.75–1.3, at most two signature items per family and band,
  tier-matched metal drops, enchant stat loot is a signature drop, enchant
  `family_input` keys are sword, dagger, greataxe, metal_armor, shield,
  leather_armor, cloth_armor, bow, caster_weapon, spellbook, trinket; elite
  leaders only from 31 (`E-leader-tier`).
- Spawn recipes: every rule of section 2, as the game parses it. Codes:
  `E-recipe` (structure), `E-recipe-key` (unknown field anywhere in the
  file, e.g. an old `areas` list), `E-recipe-shares`, `E-recipe-open`
  (missing `kinds.open`, `"open"` in the open kind), `E-recipe-roster`
  (roster shape, minor role above 25 %, missing day/night),
  `E-recipe-levels` (belt levels, a role that never meets its belt, belt
  outside the zone band with `--atlas`), `E-recipe-cover` (a kind's roster
  leaves part of its belt uncovered at a clock, a camp's roster has a gap or
  stops below its belt's top, the last belt ends below the zone band's top
  with `--atlas`: every zone runs to its round level), `E-recipe-ref` (unknown belt, camp
  or kind, wrong `pick`, `to` naming the zone itself), `E-id`,
  `E-duplicate` (ids, a leader placed twice or in two zones), `E-enum`
  (density), `E-unknown-role`, `E-not-a-mob`, `E-leader-flag` (leader role
  not `"leader": true`), `E-critter` (non-critter in `critters`),
  `W-critter-area` (a critter in a roster), `E-required` (no recipe and no
  palette), `E-recipe-poi` (a camp site's POI: not bandit or mirefolk, a
  type or name the zone lacks with `--atlas`, two of the type unnamed, two
  camps on one POI); `E-unknown-anchor` /
  `E-unknown-zone` / `W-border-neighbour` check every `from` anchor and
  every `from`/`to` border zone with `--atlas`.
- Level fit is **containment** (`E-level-fit`): every level a kill target or
  quest-drop source is met at lies within the quest's reward `level` ±3.
  "Met at" is the named leader's level, else the referenced kind's or camp's
  levels (the union over its roles, as the game's quest validator), else the
  union over the zone's kinds and camps hosting the role, else the role's
  levels.
- Leaders: a kill objective or quest drop on a leader role finds the leader
  in the zone's recipe `leaders`, else in any zone's (leader roles are
  unique), and uses its computed level; it names no area (`E-leader-area`),
  because leaders do not spawn from a kind or camp.
- Front files: `zones/<host>.front.quests.json` (`{"zone": host, "quests":
  [...]}`) are validated with the host zone. Their quests use the line
  `front`, which the host's `quests.json` must declare for that giver
  (`E-front-line`); the host's own quests never use `front`. In a contested
  zone every outpost quest NPC the atlas lists is declared as a giver with
  the line `front` (`E-front-reserve`), except in zones with a single quest
  NPC (Glassroot, Thunderroot); in a capital at least one giver declares it.
  Prerequisite cycles are checked across all quest and front files.
- New givers at free quest sockets: a hub giver may be
  `{"npc": "<new id>", "new": {"name": "…", "race": "…", "socket":
  "<socket key>"}, "lines": [...]}` when the atlas lists that socket in the
  hub's settlement as a free quest socket (no NPC yet; today Dur Brannoc,
  Highcourt, Lethariel and Gor Drazhak have one each). The new id must not be
  a registered NPC, each socket takes one NPC (`E-new-giver`,
  `E-duplicate`), and the id is then a valid giver, travel target and
  turn-in everywhere in the design.
- Reward items are `[{"item": id, "count": n}]`. A front file whose
  host `quests.json` does not exist yet is checked against the atlas only
  (`W-front-host-missing`).
- Area references are `zone_id/area_id`, the id of a kind or camp of that
  zone's recipe; a bare id is accepted with a warning only when it exists in
  the quest's own zone.
- `--atlas DIR` (the zone atlas `docs/planning/round28/zones/`, or one
  `<zone_id>.json`) adds:
  - zone ids exist; hub anchors resolve (anchor id such as `anchor_015`,
    settlement key such as `goldmead_village`, or slot such as `start`,
    `capital`, `village_1`, `outpost_1`, `clash_1`, `rare_*`; `zone` = the
    zone hub);
  - recipes: belt levels inside the zone's level range (`E-recipe-levels`);
    `from.anchor` is an anchor id or slot of the zone (the game takes no
    settlement key; `E-unknown-anchor`); each `to.border` zone exists
    (`E-unknown-zone`) and is an atlas neighbour (`W-border-neighbour`; the
    game needs a land border reachable from the anchor);
  - quest NPCs are the atlas's quest-socket NPCs; a hub's givers stand in
    that zone (`E-giver-zone`) at the hub's anchor (`E-giver-hub`);
  - **Ruling 44** (`E-race-track`): no kill area, quest-drop area, travel
    target or turn-in in another race's 11–20 zone; `W-faction` when a quest
    points into the other faction's zones;
  - **stat loot per race track** (`W-loot-track`): every tier's stat loot
    drops in at least one designed zone of each race track's band (T1 start,
    T2 home, T3 capital and 21–30, T4 the race's contested zone, T5/T6 the
    front). Zones without a spawn recipe are not checked (`W-loot-unchecked`
    names those tracks).
  Without `--atlas` these checks are skipped with one `W-no-atlas` warning.
- `--legacy` allows the legacy-only fields of B4's mechanical split (`xp`,
  `faction`, `race`; kill objectives with `mobs` entity names and `zone`
  instead of `roles`). Such a legacy kill objective may also name the enemy
  faction guards (`grug_mobs:guard_accord`, `grug_mobs:guard_throng`) that
  today's contested-zone quests ask for; a designed `roles` objective may
  not (`E-not-a-mob`). The split itself is
  `mods/PLAYER/grug_quests/data/zones/`; the game checks the same rules at
  load (`grug_quests/validate.lua`).
- Output: one line per finding, `error [E-code] file: json.path: message` or
  `warning [W-code] …`. Exit 0 = no errors, 1 = errors (or warnings with
  `--strict`), 2 = unreadable files.

## 4. Leveling ledger: `ledger.py`

```sh
python3 tools/r28_design/ledger.py \
  --route elandor_dawnmere_fields,elandor_goldmead_vale,elandor_highcourt,elandor_whitebridge_shire \
  --atlas docs/planning/round28/zones/ --human --out docs/planning/round28/design/ledger/human.md
```

- `--track RACE [--sister ZONE]` (Round 29 Q1): the race's whole route as
  frame §2.1 and the [quests plan](../../docs/planning/round29-quests-plan.md)
  §3.1 define it: start zone, home zone, own capital and heartland zone(s)
  plus the optional sister zone (another race's 20–30 zone of the faction),
  the faction's three contested zones (own race's first), then The Broken
  Causeway and The Shattered Line with the faction's front quests of reward
  level 41–50 (line `front` of its contested zones and capitals), then
  Gravesalt Escarpment and The Skyglass Canopy with those of 51–60. Every
  band is reported, also one without quests yet, and 20 → 30 adds the share
  of its questing XP from the own capital and heartland (target about
  60–70 %, the rest from the sister zone). `--track human` implies
  `--human`. Zones and bands come from `r28common.zone_records()`: the
  mapgen's zone rows with today's gameplay bands of
  `grug_core/zone_bands.lua` (one line there switches when the bands move
  into the mapgen data).
- `--game` reads the shipped zone files, as in `validate.py`.
- `--route`: the zones in play order. Quests of the line `front` (front
  files) are skipped unless `--lines` names `front`, so race and contested
  ledgers are not distorted by front quests. Every quest counts in the band of its **reward level** (so front
  quests in contested or capital files count in the front bands). The zone
  table labels each zone with its gameplay band (`zone_records()`), else its
  atlas band (`--atlas`), else its quests' median band, or `zone:lo-hi`. For
  alternative zones (two sister zones) run one ledger per alternative.
- `--lines front` (comma list) counts only those quest lines, e.g.
  `--route <the 31-40 and capital zones> --lines front --start-level 40
  --repeat 3` for `ledger/front.md`.
- Kill objectives and quest drops on a leader (of any zone) use its fixed
  level; legacy
  kill objectives (`mobs`) are read too.
- Walks the route quest by quest (prerequisites first, then by `min_level`)
  with a simulated player and counts real XP: quest rewards
  (`weight × M(level)`, rounded half up; `--human` +10 %), kill objectives
  (`count × M(min(mob level, player level + 5))`, averaged over the levels
  the target role is met at in the kind or camp, gray rule, elite ×4), kills behind item requests for mob drops
  (quest-only drops: `count × chance`; family drops from `catalog/drops.json`
  by band for the drop family — a sub-type's `drops`, else an existing mob's
  own role — else today's entity drops; drops from earlier quest kills are used
  first), and gathering behind item requests (ores/gems/fish; bars and alloys
  resolve to their ores; ore 0.10, gem 0.20, fish 0.33 KE at `10 × tier`).
  Crafted items, logs and talk objectives give no XP. When the player is below
  a quest's `min_level`, the missing XP is added as free play and noted.
- Reports per band: XP needed (and KE), rewards, quest kills, drop kills,
  gathering, questing total and share, reward share, free play and flags
  against the frame's targets (1→10: ≈90 % questing / ≈40 % rewards; 10→40:
  ≈80 % / ≈40 %; 40→60: ≈70 % / ≈35 %), ±10 points (`--tolerance`). Then per
  zone (level in/out, the `duration_min` sum) and per kill quest (area,
  count, species mix per clock as `day: role weight; night: role weight`,
  mob levels, player level, XP).
- Solo and a two-player party (`--party solo|duo|both`, default both): the
  party shares kill credit and splits kill XP; quest XP is not split; every
  member needs their own requested items (ordinary drops go to one player,
  quest-only drops roll per member). Group quests (`"group": true`) count for
  the party only (`--solo-group` to include them solo).
- `--repeat N` counts every repeatable quest N times (front bands target
  "incl. repeatables"); `--skip-optional` drops `"optional": true` quests;
  `--start-level N` for contested and front routes (the first band's need
  then starts at N).
- Exit 0: the targets are rough guides for the solo route, the duo table is
  informational. `--strict` exits 1 when a band is flagged.

## 5. Design overlay maps: `overlay.py`

Draws a design's quest hubs and givers on the zone atlas maps
(`docs/planning/round28/zones/maps/<zone>.png`). Needs numpy and Pillow
(the atlas builder's dependencies), unlike the other tools.

```sh
python3 tools/r28_design/overlay.py --design DIR --out /tmp/maps [--zone ZONE ...]
```

For every zone with a spawns or quests file it writes
`<out>/<zone>.design.png`: the quest givers (`!`) with their lines on the
map, and a side panel with the recipe (belts, kinds with levels and
species, camps, leaders with their computed level, critters, parse errors)
and the hubs (givers missing from the atlas are flagged). Spawn regions
are not drawn here: they exist only per seed, see
`tools/r28_regions/run.sh`.

## Self-tests

```sh
python3 tools/r28_design/validate.py --self-test
python3 tools/r28_design/ledger.py --self-test
```

They use `samples/valid/` (a small Dawnmere Fields design with catalogues,
real zone and NPC ids; the bandit chief and the crop ledger come from its
zone catalogue; its spawns file is a three-belt recipe with a bandit camp
and the chief as its leader), `samples/existing_min.json`, `samples/mobs_min.json` and
`samples/atlas/`
(nine zone files of the seed-42 atlas, trimmed to the fields the tools
read). The validator test checks that the valid sample gives only
`W-loot-unchecked` (only Dawnmere is designed) and that 102 variants each give
their expected finding (broken designs and recipes, plus allowed forms: a
`from` anchor by anchor id, a leader deep in a kind, a palette-only spawns
file, a leader kill without area, a leader of another zone, a declared
front file, a capital front giver, both outpost givers declared, the
single-NPC contested exemption, a new giver at a free socket, a zone-added
leader used from another zone, a critter sub-type of a critter base, legacy kill
objectives, a legacy enemy-guard kill). The ledger test checks the
formulas against the plan's numbers (4.2k XP / 82 KE to level 10, about
194k / 968 KE to 60), the solo/duo rules, atlas bands, leader levels,
per-quest bands, per-role levels in kinds, species mix, `--lines` and
`--start-level`. Both print one summary line
on PASS.

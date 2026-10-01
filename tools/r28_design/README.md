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

Refresh it after mod changes (one short headless boot, about 40 s):

```sh
LC_ALL=C tools/r28_design/dump_items.sh            # rewrites existing.{json,md}
LC_ALL=C tools/r28_design/dump_items.sh /tmp/x     # also keeps the raw dump and server log in /tmp/x
pgrep -f '^luanti.bin'                              # must not list a server of yours
```

`dump_items.sh` stages the disposable probe mod
`items_probe/grug_probe_r28_items` through `tools/luanti_headless.sh` and runs
`items_catalog.py` on the dump.

## 2. Validate a design: `validate.py`

```sh
python3 tools/r28_design/validate.py                         # whole design dir
python3 tools/r28_design/validate.py --atlas docs/planning/round28/zones/
python3 tools/r28_design/validate.py --zone elandor_dawnmere_fields --quiet
```

- Checks every catalogue and zone file against the frame's formats
  (required fields, id formats, enums, level ranges, shapes) and the
  references between them: roles exist (catalogue sub-type or existing mob),
  items exist (catalogue or `existing.json`, never curated out, never skill
  items), NPCs are quest NPCs (today's registry, plus the atlas), areas used by
  quests exist and host the target, `quest_drops` pair with an item objective
  and a catalogue item of kind `quest`, prerequisites exist and have no cycle.
- Zone catalogues: `zones/<zone_id>.catalog.json` = `{"subtypes": [...],
  "items": [...]}` in the formats of `catalog/subtypes.json` and
  `catalog/items.json`. Both tools merge them into the catalogue: role and
  item ids are unique across the global catalogue and every zone addition
  (`E-duplicate`), and a zone-added role or item may be used from any zone's
  files. A zone catalogue adds only leader roles (`"leader": true`) and
  quest-only items (kind `quest`) (`E-zone-catalog`); a zone-added leader is
  a leader of that zone only (`E-zone-leader` in another zone's `leaders`,
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
  leather_armor, cloth_armor, bow, caster_weapon, spellbook, trinket; one
  fallback area per zone with areas, elite leaders only from 31, no `band`
  shape in front zones.
- Level fit is **containment** (`E-level-fit`): every level a kill target or
  quest-drop source is met at lies within the quest's reward `level` ±3.
  "Met at" is the named leader's fixed level, else the referenced area's
  levels, else the levels of all the zone's areas hosting the role, else the
  role's levels.
- Leaders: a kill objective or quest drop on a leader role finds the leader
  in the zone's `leaders`, else in any zone's (leader roles are unique fixed
  spots), and uses its fixed level; it names no area (`E-leader-area`),
  because leaders do not spawn from an area.
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
- Area references are `zone_id/area_id`; a bare id is accepted with a warning
  only when it exists in the quest's own zone.
- `--atlas DIR` (the zone atlas `docs/planning/round28/zones/`, or one
  `<zone_id>.json`) adds:
  - zone ids exist; anchors resolve (anchor id such as `anchor_015`,
    settlement key such as `goldmead_village`, or slot such as `start`,
    `capital`, `village_1`, `outpost_1`, `clash_1`, `rare_*`; `zone` = the
    zone hub); biomes are the zone's (with or without the `grug_` prefix;
    `shore: true` = only near water, false or absent = no restriction); area
    levels inside the zone's level range; no `band` shape in front zones and
    islands;
  - **in zone**: the centre (anchor + offset) of every circle, ring, band
    origin and leader. `E-outside-zone` only when it lies more than 96 nodes
    beyond the zone's land extent box (a sign or axis mistake). Outside the
    approximate border outline (the extent box plus each border as the line
    through its midpoint perpendicular to the two zones' hubs; it misjudges
    5–17 % of real land in front zones) is `W-area-outside`, as is a circle,
    ring or band mostly outside it. Points at an atlas anchor never warn. The
    game clips areas to the real zone;
  - quest NPCs are the atlas's quest-socket NPCs; a hub's givers stand in
    that zone (`E-giver-zone`) at the hub's anchor (`E-giver-hub`);
  - **Ruling 44** (`E-race-track`): no kill area, quest-drop area, travel
    target or turn-in in another race's 11–20 zone; `W-faction` when a quest
    points into the other faction's zones;
  - **stat loot per race track** (`W-loot-track`): every tier's stat loot
    drops in at least one designed zone of each race track's band (T1 start,
    T2 home, T3 capital and 21–30, T4 the race's contested zone, T5/T6 the
    front). Zones without spawn areas are not checked (`W-loot-unchecked`
    names those tracks).
  Without `--atlas` these checks are skipped with one `W-no-atlas` warning.
- `--legacy` allows the legacy-only fields of B4's mechanical split (`xp`,
  `faction`, `race`; kill objectives with `mobs` entity names and `zone`
  instead of `roles`).
- Output: one line per finding, `error [E-code] file: json.path: message` or
  `warning [W-code] …`. Exit 0 = no errors, 1 = errors (or warnings with
  `--strict`), 2 = unreadable files.

## 3. Leveling ledger: `ledger.py`

```sh
python3 tools/r28_design/ledger.py \
  --route elandor_dawnmere_fields,elandor_goldmead_vale,elandor_highcourt,elandor_whitebridge_shire \
  --atlas docs/planning/round28/zones/ --human --out docs/planning/round28/design/ledger/human.md
```

- `--route`: the zones in play order. Quests of the line `front` (front
  files) are skipped unless `--lines` names `front`, so race and contested
  ledgers are not distorted by front quests. Every quest counts in the band of its **reward level** (so front
  quests in contested or capital files count in the front bands). The zone
  table labels each zone with its atlas band (`--atlas`), else its quests'
  median band, or `zone:lo-hi`. For alternative zones (two 21–30 zones) run
  one ledger per alternative.
- `--lines front` (comma list) counts only those quest lines, e.g.
  `--route <the 31-40 and capital zones> --lines front --start-level 40
  --repeat 3` for `ledger/front.md`.
- Kill objectives and quest drops on a leader (of any zone) use its fixed
  level; legacy
  kill objectives (`mobs`) are read too.
- Walks the route quest by quest (prerequisites first, then by `min_level`)
  with a simulated player and counts real XP: quest rewards
  (`weight × M(level)`, rounded half up; `--human` +10 %), kill objectives
  (`count × M(min(mob level, player level + 5))`, averaged over the area's
  levels, gray rule, elite ×4), kills behind item requests for mob drops
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
  count, species mix, mob levels, player level, XP).
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

## Self-tests

```sh
python3 tools/r28_design/validate.py --self-test
python3 tools/r28_design/ledger.py --self-test
```

They use `samples/valid/` (a small Dawnmere Fields design with catalogues,
real zone and NPC ids; the bandit chief and the crop ledger come from its
zone catalogue), `samples/existing_min.json`, `samples/mobs_min.json` and
`samples/atlas/`
(nine zone files of the seed-42 atlas, trimmed to the fields the tools
read). The validator test checks that the valid sample gives only
`W-loot-unchecked` (only Dawnmere is designed) and that 71 variants each give
their expected finding (broken designs, plus allowed forms: a settlement-key
anchor, a leader kill without area, a leader of another zone, a declared
front file, a capital front giver, both outpost givers declared, the
single-NPC contested exemption, a new giver at a free socket, a zone-added
leader used from another zone, a critter sub-type of a critter base, legacy kill
objectives). The ledger test checks the
formulas against the plan's numbers (4.2k XP / 82 KE to level 10, about
194k / 968 KE to 60), the solo/duo rules, atlas bands, leader levels,
per-quest bands, `--lines` and `--start-level`. Both print one summary line
on PASS.

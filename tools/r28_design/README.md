# Round 28 design tools

Tools for the Round 28 design round (plan:
`docs/planning/round28-questing-leveling-plan.md`, data formats:
`docs/planning/round28-design-frame.md` §4). Python 3 standard library only;
no network, no engine needed except to refresh the item catalogue.

Design files live under `docs/planning/round28/design/` (`catalog/`,
`zones/<zone_id>.spawns.json`, `zones/<zone_id>.quests.json`). Both tools
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
- Limits: at most 2 givers per hub and 2 lines per giver, a giver in one hub
  only, critters never kill targets, sub-type size 0.75–1.3, at most two
  signature items per family and band, tier-matched metal drops, enchant stat
  loot is a signature drop, one fallback area per zone with areas, elite
  leaders only from 31, no `band` shape in front zones.
- Level fit: a kill target's level range `[lo, hi]` (the area's, else the
  role's) must contain the quest `level` within ±3.
- Area references are `zone_id/area_id`; a bare id is accepted with a warning
  only when it exists in the quest's own zone.
- `--atlas DIR` (the zone atlas `docs/planning/round28/zones/`, or one
  `<zone_id>.json`) adds:
  - zone ids exist; anchors resolve (anchor id such as `anchor_015`,
    settlement key such as `goldmead_village`, or slot such as `start`,
    `capital`, `village_1`; `zone` = the zone hub); biomes are the zone's
    (with or without the `grug_` prefix); area levels inside the zone's level
    range; no `band` shape in front zones and islands;
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
  `mobs`, `zone` on kill objectives, `faction`, `race`).
- Output: one line per finding, `error [E-code] file: json.path: message` or
  `warning [W-code] …`. Exit 0 = no errors, 1 = errors (or warnings with
  `--strict`), 2 = unreadable files.

## 3. Leveling ledger: `ledger.py`

```sh
python3 tools/r28_design/ledger.py \
  --route elandor_dawnmere_fields,elandor_goldmead_vale,elandor_highcourt,elandor_whitebridge_shire \
  --atlas docs/planning/round28/zones/ --human --out docs/planning/round28/design/ledger/human.md
```

- `--route`: the zones in play order. Each zone's band comes from the
  atlas level range (`--atlas`; capital 20–30 and 21–30 zones share the
  20 → 30 band), else from its quests' median reward level; pin it with
  `zone:lo-hi`. For alternative zones (two 21–30 zones) run one ledger per
  alternative.
- Walks the route quest by quest (prerequisites first, then by `min_level`)
  with a simulated player and counts real XP: quest rewards
  (`weight × M(level)`, rounded half up; `--human` +10 %), kill objectives
  (`count × M(min(mob level, player level + 5))`, averaged over the area's
  levels, gray rule, elite ×4), kills behind item requests for mob drops
  (quest-only drops: `count × chance`; family drops from `catalog/drops.json`
  by band, else today's entity drops; drops from earlier quest kills are used
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
  `--start-level` for contested and front routes.
- Exit 0: the targets are rough guides for the solo route, the duo table is
  informational. `--strict` exits 1 when a band is flagged.

## Self-tests

```sh
python3 tools/r28_design/validate.py --self-test
python3 tools/r28_design/ledger.py --self-test
```

They use `samples/valid/` (a small Dawnmere Fields design with catalogues,
real zone and NPC ids), `samples/existing_min.json` and `samples/atlas/`
(seven zone files of the seed-42 atlas, trimmed to the fields the tools
read). The validator test checks that the valid sample gives only
`W-loot-unchecked` (only Dawnmere is designed) and that 36 variants each give
their finding (35 broken, one allowed anchor form); the ledger test checks
the formulas against the plan's numbers (4.2k XP / 82 KE to level 10, about
194k / 968 KE to 60), the solo/duo rules and the atlas bands.

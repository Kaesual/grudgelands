# Docs alignment, round 4: what wave 3 shipped after the first sweep

WP13 round 4, lane D4. The first sweep of 2026-09-16
([docs-alignment-2026-09-16.md](docs-alignment-2026-09-16.md), lane A) compared
the docs against the **wave-2** code and merged at `b4fa6042`. Seven more lanes
merged after it on the same day. This pass covers exactly that gap, in the same
method and the same format, and it also carries the doc-only half of
`skill_trees.md` §7 (§4 below).

Baseline: `main` at `dfb32cd5` ("Read one Highcourt avenue expectation, the one
every capital runner reads"). **Every line number below is the number on that
baseline**, before this lane's own commits moved them. No code, tool or engine
file was touched and no engine was run; every claim is a `grep`, a file read or
a script over the repository, quoted in §5.

What shipped after lane A, and was therefore never compared against the docs:
the WP11 skill-tree design revision 2 and `scout.md` (`3d284bc9`, `51655ecf`),
WP26 smelting (`mods/ITEMS/grug_smelting`), WP13 fishing
(`mods/ITEMS/grug_fishing`), lane S's one street rule for all six capitals
(`1f5a2c32`), lane P's polish and Highcourt lot repair, and lane K's Kezamba
terrain and crops (`6c7fd398`).

Read: `ROADMAP.md`, `BACKLOG.md`, `README.md`, `AGENTS.md`, all 18
`docs/design/*.md` and their index, `VENDOR.md`, the thirteen
`LICENSE-media.md` files, and the wave-3 research notes (`wp13-fishing.md`,
`wp13-kezamba.md`, `wp13-polish-wave3.md`, `wp13-street-geometry.md`,
`wp26-implementation.md`); compared against `mods/` and against
`git log b4fa6042..dfb32cd5`.

## 0. Counts

| Category | Fixed | For the user | No change needed |
|---|---|---|---|
| (a) doc says planned, code has it | 3 | 0 | 0 |
| (b) doc says shipped, code lacks it | 0 | 0 | 0 |
| (c) two docs contradict | 5 | 0 | 0 |
| (d) stale numbers, paths, names, status boxes | 6 | 0 | 0 |
| (e) code behaviour nobody documented | 0 | 2 | 0 |
| (f) links that do not resolve | 0 | 1 | 0 |
| verified correct (checked, left alone) | — | — | 11 |
| **total** | **14** | **3** | **11** |

The `skill_trees.md` §7 tasks are counted separately in §4: six of the nine are
doc-only and this lane's, and each is recorded there with its verification.

Three findings carry a measurement rather than a citation; they are marked
MEASURED. The FOR-THE-USER rows are in §3 and say what is unmeasured.

## 1. FIXED

### (a) Three places where the docs describe the world before wave 3

1. **`AGENTS.md:635` still handed the furnace recipes to a future WP.**
   *"WP26 owns all furnace/alloy/storage recipes"* — WP26 shipped on
   2026-09-16. The bullet now names `mods/ITEMS/grug_smelting`, the
   `grug_smelting:dual_furnace` node pair, and `grug_smelting.RECIPES`, which
   exists because a `dualfurn` recipe is invisible to the engine's own craft
   walk and `grug_traders/audit_alloys.lua` has to iterate it instead.
   Checked, not assumed: five single-input smelts and five alloys in
   `grug_smelting/recipes.lua:28-67`, and MEASURED twelve storage pack/unpack
   pairs, because `grug_materials.PROCESSED_MATERIALS`
   (`grug_materials/registry.lua:208-250`) has twelve rows. This matters beyond
   tidiness for the same reason lane A's mapgen finding did: AGENTS.md is the
   first file every session reads.

2. **`settlements.md:147-151`: streets "crossing water as a causeway".** Since
   `1f5a2c32` every street of every capital that stands over water is a railed
   bridge on piers, a crossing is a levelled junction plateau, and a street
   raised three nodes or more stands on pillars over open air. The five
   playtest-5 rulings and their nine-seed numbers are in
   [wp13-street-geometry.md](wp13-street-geometry.md) §1-§2 (worst cross-profile
   spread 5..8 → 0; worst spread over a junction square 4..22 → 0; lamps
   footing off the street 1089..1244 → 0). **Corrected**: the causeway word is
   replaced and the rule is added as its own paragraph, because it holds for
   avenues, ring streets, district lanes, fill lanes and gate approaches alike
   — which is the point of it.

3. **`settlements.md:212-221`: fill ground that grows nothing.** The "Between
   the plots" paragraph carried the round-3 half of the fill rule but not the
   playtest-5 half — the user's *"Fields in Kezamba grow 'Mossy Stone'? That
   cannot be right"* ([wp13-kezamba.md](wp13-kezamba.md) §8). A race that binds
   no crop fell back to its plain ground node, so a field was a rectangle of
   bare mud and a vineyard was seven rows of kerb with no soil in it.
   **Corrected** with one sentence and the two mechanisms: a crop handle in the
   palette, and a planter bed cut deep enough to have an interior.

### (b) Nothing found

No doc claimed a wave-3 feature the code does not have. What was checked by
reading the code rather than by grep: `items_crafting.md` §2.3's three fishing
rows against `grug_fishing/init.lua:62-140` and `catch.lua` (rod = 3 sticks +
2 Spider Silk, `ROD_USES = 64`, cooked fish a `cooking` recipe from
`grug_mobs:raw_fish` at cooktime 5, catch table 78/12/10 summing to 100);
§3.0.2's alloy table against `grug_smelting/recipes.lua`'s `SMELTS` and
`ALLOYS` row for row, including the T-arrangement station recipe; and
`character_visuals.md` §4's three poses against
`grug_visuals/wield_geometry.lua:248-296`.

### (c) Five contradictions

1. **`settlements.md:322` still called Nhal Veyr "one of the three walled
   ones"**, two hundred lines after the same file's `:186-190` says the split
   is **four walled and two open**. It is a residue of lane A's own correction
   (`f2ce9cd0`, "Correct settlements.md where it still describes three walled
   capitals"). The code agrees with four:

   ```sh
   grep -ln 'M\.wall' mods/MAPGEN/grug_mapgen/wp13/*.lua
   # highcourt.lua  dur_brannoc.lua  gor_drazhak.lua  nhal_veyr.lua  (plus library files)
   ```

   **Corrected.** Gor Drazhak is one of the four and its wall is a stake
   palisade on an earth rampart (`gor_drazhak_quadrants.lua:152-180`), which
   `settlements.md:257-269` already explains correctly.
2. **`README.md:239` said "Shipped (19 of 46 work packages)"** and left WP26
   out of the list, while `README.md:306` in the same section said *"WP26 is
   shipped"*. MEASURED against `BACKLOG.md`: **49** WP rows, **20** of them with
   a status cell starting with the shipped mark (script in §5). **Corrected to
   20 of 49**, with the three lettered rows of 2026-09-16 named as open.
3. **`ROADMAP.md:143-145` did not know the three work packages the rulings
   created.** `BACKLOG.md:35-37` carries WP-Scout, WP-HUD and WP-Speed; the
   roadmap's "independently ready" bullet listed only WP11/WP14/WP20/WP21/WP8,
   so the two status sources disagreed on the roster. **Corrected**, with
   WP11's design revision and its PROPOSAL banner named.
4. **`professions.md:207-209`: *"no current or committed class uses a bow
   baseline"*.** Since 2026-09-16 one does: the Scout's base kit opens with
   **Loose** (`scout.md` §2), rulings 7 and 12 are the user's, and `BACKLOG.md`
   carries WP-Scout with a bow+arrows lane. The substrate is still unbuilt, so
   only the reasoning changed. **Corrected**, and `items_crafting.md` §9 —
   whose heading calls the family an inactive substrate — gained the same
   dated paragraph, including the ballistic-arrow / straight-Fireball split
   (`combat_stats.md:249-252`, `classes.md:280-292`).
5. **`classes.md:475-495` kept two sentences of the text it retired.** The
   bullet that superseded the Phase-2 Rogue lists *"stealth"* among the
   existing stats the Scout's melee tree is built from — ruling 12 took stealth
   out of version 1 entirely (`skill_trees.md` §2.8's capstone is Untouchable,
   a timed dodge effect, and the whole stealth design is parked in `scout.md`
   §8) — and it closes with *"the Rogue work is what turns it into one"*, four
   lines after stating there is no planned owner for a player poison stat at
   all. **Corrected**; nothing about what exists today changes.

### (d) Stale status boxes, numbers and pointers

| # | Where (baseline) | What | Correction |
|---|---|---|---|
| 1 | `ROADMAP.md:159-220` | The WP13 entry ends at wave 2 and the round-4 route-gate ruling | Wave 3 named: the one street rule, Kezamba's terraced pad edge and crops, the thirteen relocated Highcourt lots, and fishing |
| 2 | `BACKLOG.md:39` | The WP13 status cell ends at the same place | Same, with the street package's own nine-seed numbers |
| 3 | `ROADMAP.md`, `BACKLOG.md`, `README.md` | **Fishing appears in none of them.** MEASURED: at `dfb32cd5` the only `fish` match in BACKLOG.md is the string `mobs_mc_silverfish.b3d`; ROADMAP's is a future coastal-shelf line and README's is the `fisher` NPC activity | `mods/ITEMS/grug_fishing` is now in all three, with the rod, the cooked fish, the one world-wide catch table and the `table_for(pos)` seam |
| 4 | `README.md:239`, `:243-283` | The shipped count, and a capitals paragraph that predates wave 3 | See (c)2; plus the street rule and Kezamba's crops |
| 5 | `docs/design/README.md` | The index lists 16 of the 18 design documents: `skill_trees.md` and `scout.md`, both added on 2026-09-16, have no row. AGENTS.md's rule ("when a `docs/design/` file is added … check the README's design tour for the same edit") is the one lane A applied to `settlements.md` | Two rows added, each carrying the PROPOSAL status the file itself carries |
| 6 | `BACKLOG.md:549` | The WP11 note says `items_crafting.md` §8.3's trainer sentence *"needs the trainer struck from it"* | It was struck on this branch (§4, task 3); the note now records that, with the two other files |

`progression.md:54-56` needed the same closing edit — it said `economy.md` §4,
`items_crafting.md` §8.3 and `world.md` §1 *"still name a class trainer and are
corrected separately"* — and is recorded in §4 with the task that caused it.

## 2. Verified correct — checked, nothing changed

Recorded so the next pass does not spend the time again. This project has
repeatedly found "X is missing" claims to be false, so each of these was read
in the code rather than inferred from an empty grep.

| Claim | Where | Check |
|---|---|---|
| The three fishing rows: rod recipe, 64 catches, cooked fish, prices | `items_crafting.md:1267-1269` | `grug_fishing/init.lua:62-140`: 3 sticks + 2 `grug_mobs:spider_silk` in two mirrored shapes, `ROD_USES = 64`, `cooking` from `grug_mobs:raw_fish` cooktime 5, no `_grug_sell_price` on either item |
| One catch table, 78 % fish / 12 % stick / 10 % papyrus | `items_crafting.md:1271-1276` | `grug_fishing/catch.lua:29-33`; the weights sum to 100 and `table_for(pos)` is the only accessor |
| The five alloys, the node pair and the T-arrangement station recipe | `items_crafting.md` §3.0.2 | `grug_smelting/recipes.lua:28-110`, row for row, `grug_smelting:dual_furnace`/`_active` |
| Twelve storage pack/unpack pairs | §3.0.2, `wp26-implementation.md` | MEASURED: `PROCESSED_MATERIALS` has twelve rows (`registry.lua:208-250`) |
| *"Three startup audits in `grug_traders/init.lua`"* | `AGENTS.md:702-712` | still three: `audit_alloys.lua` **extends audit 3**, it does not add a fourth (`grug_traders/init.lua:322-325`) |
| *"40 `GRUG PATCH` sites in `mods/ENTITIES/mobs/api.lua`"* | `AGENTS.md:521` | `grep -c 'GRUG PATCH' …` → 40, unchanged by wave 3 |
| Three wield poses and the families that pick them | `character_visuals.md:108-138` | `wield_geometry.lua:275-296`: `EDGE_DOWN_GROUP = {"axe"}` is checked first and `DIAGONAL_GROUP` carries `fishing_rod`; its seventh entry, `grug_equip_weapon`, is the weapon slot's group and not an art family |
| Every stored texture has a licence row | all thirteen `LICENSE-media.md` | MEASURED by script over `mods/*/grug_*/textures`: nothing unaccounted for once the wildcard rows (`…_dagger_<material>.png (6)`, `…_ironaxe.png`) are resolved. `grug_fishing` (1 file, CC BY-SA 4.0, carrying licensing.md §3.2's five fields) and `grug_smelting` (2 files, CC BY-SA 3.0 derivatives of the vendored furnace fronts, no `lottblocks` art) are complete |
| The dual-furnace port's provenance | `VENDOR.md:158-172` | Present, with the ported line ranges, the four dropped pieces and the patch list; a curated code port, not a vendored tree |
| Kezamba's decided terrain form | `world_zones.md:789` | *"a broad stepped central cenote is surrounded by flood-safe stilt-and-stone capital terraces"* — wave 3's `cenote_terrace` apron brought the code **to** this sentence (pad face 17-28 → 3 on nine seeds), so no doc edit is owed |
| The twelve profession shop kinds | `professions.md:196-202`, `settlements.md:406-412` | `grug_traders/vendors.lua:445-458`, twelve rows, `GEAR_KINDS = {smith, armourer}` |

## 3. FOR THE USER — a decision, not a doc fix

### 3.1 A fishing rod lengthens every interaction, not just the cast

MEASURED in the code, UNMEASURED in play. `grug_fishing:rod` sets `range = 8`
(`init.lua:68`) so that an angler can fish from the bank rather than from
inside the pond. An item definition's `range` sets the wielder's **whole**
interaction distance while that item is held, so with the rod in hand a player
opens a door, a chest or a vendor formspec from 8 nodes instead of the usual 4.
[wp13-fishing.md](wp13-fishing.md) records it as a known side effect of a
number chosen for water. It is not a defect and it is in no design document.
Either it is fine — the rod is a niche item and 8 nodes is not an exploit — or
the cast should carry its own range and the item should not, which is code and
nobody's this round. The comparison that makes it small: every ability orb
already sets `range`, and `grug_abilities`' kits run 4, 8, 12 and 20.

### 3.2 The rod lands 65 catches and every document says 64

MEASURED arithmetic, not play: `ROD_WEAR = floor(65535 / 64) = 1023`, so after
64 catches wear is 65 472, and `ItemStack::addWear` clears the stack only when
the next step would exceed 65 535 — the 65th. `wp13-fishing.md` records the
off-by-one and keeps `ROD_USES = 64` deliberately, because `uses = N` is the
engine's own convention and every other tool in the game counts that way;
`items_crafting.md:1267` says "64 catches" for the same reason. Nothing is
wrong. It is listed because it is exactly the kind of number a later balance
pass reads off a design doc and then disbelieves in the engine.

### 3.3 Six relative links that do not resolve, none of them fixable here

MEASURED by walking every `](*.md)` link in every Markdown file outside
`reference_projects/` (the script is in §5): all but six resolve, and all six
predate wave 3.

| File | Link | Why |
|---|---|---|
| `tools/wp13/evidence/20260914-{kapok,sunscar,stillgrave,silverleaf,dawnmere}/README.md` | `../../../docs/research/wp13-*.md` | one `../` short — the README sits four levels down, so the path resolves to `tools/docs/research/` |
| `docs/research/wp40-simple-map-r6-preflight.md` | `../../TODO-design-wp40-r6-contract.md` | the TODO was folded in and deleted, which is the documented lifecycle for a `TODO-*.md` |

The five evidence READMEs are inside **frozen evidence packages** whose
`files.sha256` covers them, so correcting a link there moves a frozen digest
for a typo — the coordinator's call, not a lane's. The preflight note is a
dated record and its dead link points at a file that was *supposed* to be
deleted. Both are listed rather than fixed.

### 3.4 Still open from the first sweep

Nothing in wave 3 answered lane A's three FOR-THE-USER items, and this pass
found no new evidence on any of them: the five *"WP40 must …"* obligations
(§3.1 there), the socket-count example in `wp13-npc-sockets-contract.md` §8.3
(Highcourt is 256 sockets, the example says 144), and the workplace-versus-
walker wording in `wp13-npc-work.md` (§3.4 there). The four-walled/two-open
split, which two corrections on this branch now depend on, is still a
coordinator plan the user approved rather than a user ruling
(`wp13-capitals-pois-contract.md` §4), and the user may still reverse it.

## 4. The `skill_trees.md` §7 tasks that are doc-only

§7 lists nine tasks its own lane could not write. Six are doc-only and this
lane's; every line number was verified before editing, because §7 was written
at `70dda602`.

| Task | What | Verified | Done |
|---|---|---|---|
| 1 | The 4.4 > 4.0 pillar holds **except** for named long-cooldown skills; Sprint is the first at +25 % / 10 s / 300 s; the Swiftness Draught's +8 % stays | Rulings 10 and 29 quoted from `skill_trees.md` §5.1 | One added paragraph in `mounts.md` §3.1 and one added bullet in `combat_stats.md` §3, each in its own commit and touching nothing else in those paragraphs, so the mob-pressure lane's edits to the same text merge |
| 3 | Retire the class trainer | `grep -rn -i trainer mods/ --include=*.lua` is **empty**: neither a class nor a job trainer exists in code, so this is design-only | `economy.md:92`, `items_crafting.md:2380` and `world.md:408` rewritten on rulings 4 and 22; `post-wp40-readiness.md` got a **dated pointer at the top** (its trainer row is in §2.1, not the §4 that §7's line number lands in); `progression.md:54-56`'s "corrected separately" pointer closed |
| 5 (doc half) | "Holy tree" → Mercy | `grep -n Holy docs/design/classes.md` → one hit, `:464`, the Renew row | `classes.md`; `kits.lua:650` is code and the WP11 lane's |
| 6 | The `mcl_bows` media line | Read in the source repo as AGENTS.md requires. `reference_projects/` is empty in a worktree, so `mcl_bows/README.txt` was read in the main checkout at the pinned VoxeLibre commit: `mcl_bows_bow_shoot.ogg` CC0, `mcl_bows_hit_other.ogg` CC0, `mcl_bows_hit_player.ogg` **CC BY 3.0** | `items_crafting.md:2425-2426`: **one** attribution-requiring sound and not two, CC BY-SA 4.0 is the *texture* licence, and the code is dual-licensed LGPL 3.0 **or** GPL 3.0 |
| 7 (doc half) | `mounts.md:165`'s api.lua citation | `grep -n "get_attach() or self.attack" mods/ENTITIES/mobs/api.lua` → **2531** (its comment is 2530), not 2525-2526 | `mounts.md`; the two `grug_mobs` code comments are the mob-pressure lane's |

Tasks 2, 4, 8 and 9 belong to other lanes by §7's own column, and task 5's code
half does too. None of them was touched here.

**Consequence for `skill_trees.md` itself, which is not this lane's file.** Its
header (`:30-35`) says *"`economy.md:92` and `items_crafting.md` §8.3 (`:2380`)
… still carry the retired seam"*, and §7's table lists tasks 1, 3, 5, 6 and 7
as outstanding. After this branch they are done, and the file should get a
status line saying so — the WP11 lane owns it this round. The same header cites
the Renew row as `classes.md` §5 (`:459`); on `dfb32cd5` line 459 is that
table's header row and Renew is `:464`, which is the number §7's own task 5
uses.

## 5. Evidence a reader can rerun

```sh
# (c)2 / (d)4 -- the shipped count, from BACKLOG's own table
python3 - <<'PY'
import io, re
rows = [l for l in io.open('BACKLOG.md', encoding='utf-8') if re.match(r'^\| WP', l)]
real = [l for l in rows if not re.match(r'^\| WP \|', l)]
ship = [l for l in real if [x.strip() for x in l.split('|')][3].startswith('✅')]
print(len(real), "WP rows,", len(ship), "shipped")
PY

# (d)3 -- fishing in the planning documents, before this branch
git show dfb32cd5:BACKLOG.md | grep -o -i "fish[a-z]*" | sort | uniq -c

# (c)1 -- which capitals have a wall
grep -ln 'M\.wall' mods/MAPGEN/grug_mapgen/wp13/*.lua

# (a)1 -- the twelve processed materials the storage pairs are derived from
sed -n 208,250p mods/ITEMS/grug_materials/registry.lua | grep -c 'key ='

# section 2 -- every stored texture has a licence row
for d in mods/*/grug_*/textures; do
  m=$(dirname "$d")/LICENSE-media.md
  for f in "$d"/*.png; do
    grep -q "$(basename "$f")" "$m" || echo "unlisted: $f"
  done
done   # the remainder are the wildcard rows named in section 2

# section 4, task 3 -- no trainer exists in code
grep -rn -i trainer mods/ --include=*.lua

# section 4, task 7 -- the attach-aware punch
grep -n "get_attach() or self.attack" mods/ENTITIES/mobs/api.lua
```

Section 3.3's link walk, kept separate because it is the one check that reads
every Markdown file in the repository:

```python
import io, os, re
for root, dirs, files in os.walk('.'):
    if '.git' in root or 'reference_projects' in root:
        continue
    for name in files:
        if not name.endswith('.md'):
            continue
        path = os.path.join(root, name)
        text = io.open(path, encoding='utf-8').read()
        for m in re.finditer(r'\]\(([^)#\s]+\.md)(#[^)]*)?\)', text):
            if m.group(1).startswith('http'):
                continue
            target = os.path.normpath(os.path.join(root, m.group(1)))
            if not os.path.exists(target):
                print('broken:', path, '->', m.group(1))
```

## 6. Deliberately not touched

Other round-4 lanes own these in parallel and this lane reported rather than
edited: `skill_trees.md` (the WP11 lane adds its status line — see §4);
`classes.md` §3's rage rows, and `combat_stats.md` §3's speed numbers and §4's
line numbers (the WP11 and mob-pressure lanes); `biomes_mobs.md`, `boats.md`
and `mounts.md`'s ownership sentence (mob pressure); `classes.md`'s HUD
sentences and the two task cards' status pointers (the HUD and mob-pressure
lanes); `wp13-street-geometry.md` (the streets lane). The edits this lane did
make to `mounts.md` §3.1, `combat_stats.md` §3 and `classes.md` §6 are each an
**addition in its own commit** that changes no number and no sentence those
lanes own.

Research notes were not rewritten — they are dated records. One got a dated
pointer (`post-wp40-readiness.md`, §4 task 3) because a user ruling retired a
row in it, and the first sweep's note gets a pointer to this one.

## 7. What a review should look at

- The three `settlements.md` edits are the ones with real content risk. The
  street paragraph is a summary of another lane's shipped rule: read it against
  [wp13-street-geometry.md](wp13-street-geometry.md) §1, not against this note.
- The `professions.md` and `items_crafting.md` §9 bow paragraphs assert that a
  **proposal** creates a consumer. Both files still say the substrate is
  unbuilt; the question is whether "committed" is the right word for a class
  whose design doc carries a PROPOSAL banner and whose rulings are the user's.
- `ROADMAP.md`, `BACKLOG.md` and `README.md` are three descriptions of one
  state and should agree with each other and with `settlements.md`.
- §4 task 1 was written twice, once per file, deliberately. If the mob-pressure
  lane also edits those paragraphs, check that both survived the merge.

## 8. Open

- The three §3 items, and the three carried over in §3.4, need the user's or
  the coordinator's decision.
- `skill_trees.md` §7's table and header describe work this branch finished
  (§4); its owner has to fold that in.

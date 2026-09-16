# Docs and WP-planning alignment sweep, 2026-09-16

WP13 wave 3, lane A. The user's request: *"One lane could check the work-package
planning so far and compare the current state of the code with the docs, so docs
and WP planning do not go stale and stay in sync."*

Baseline: `main` at `f37a0c5b` ("Freeze the Dur Brannoc corner digest on the gate
seed"), the wave-2 merge with six starts and six capitals. **Every line number
below is the number on that baseline**, before this lane's own commits moved
them. No code, tool or engine file was touched; no engine was run. The two Lua
commands quoted in the note (`decor_registry_kat.lua`, `highcourt_kat.lua`) are
engine-free KATs run under LuaJIT with `LC_ALL=C`.

Read: `ROADMAP.md`, `BACKLOG.md`, `README.md`, `AGENTS.md`, `CLAUDE.md`,
`VENDOR.md`, all 17 `docs/design/*.md`, all three `docs/process/*.md`, the three
WP13 contracts, and the WP13 research notes of 2026-09-14/15/16; compared
against `mods/` and `tools/` and against `git log --since=2026-09-01`.

## 0. Counts

| Category | Fixed | For the user | No change needed |
|---|---|---|---|
| (a) doc says planned, code has it | 4 | 0 | 0 |
| (b) doc says shipped, code lacks it | 3 | 0 | 0 |
| (c) two docs contradict | 2 | 0 | 0 |
| (d) stale numbers, paths, names, status boxes | 11 | 2 | 0 |
| (e) code behaviour nobody documented | 1 | 1 | 0 |
| verified correct (checked, left alone) | — | — | 9 |
| **total** | **21** | **3** | **9** |

Five findings carry a measurement rather than a citation; they are marked
MEASURED. Three FOR-THE-USER rows are marked UNMEASURED and say so.

## 1. FIXED

### (b) The largest one: AGENTS.md describes a mapgen that no longer exists

`AGENTS.md:717-844` — the whole "Mapgen/biomes" bullet, 128 lines — documents
`grug_mapgen/biomes.lua`, `ores.lua`, `geometry.lua`, `ocean_mask.lua`,
`ocean_mask_mapgen.lua` and `structures.lua` in the present tense. On the
baseline `mods/MAPGEN/grug_mapgen/` holds `init.lua`, `wp43_handoff.lua`,
`wp13/` and `wp40/` — nothing else — and `init.lua` is nine lines whose header
reads *"Legacy biome/ore/decoration/ocean/structure loaders are deliberately
absent: r7_loader owns the one reviewed native allowlist, mapgen script,
generated callback and VM transaction."*

Evidence a reader can rerun:

```sh
find mods -name biomes.lua -o -name ores.lua -o -name structures.lua \
  -o -name ocean_mask.lua -o -name ocean_mask_mapgen.lua      # empty
grep -rn "register_mirrored\|column_cap\|clean_shell\|_grug_spawn_zones" mods/  # empty
grep -rn "get_camp_platform_y\|set_camp_platform_y\|request_camp_platform\|\
ensure_camp_platform_built\|CAMP_SAMPLE_RADIUS\|CAMP_PLATFORM_Y\|\
probe_platform_y" mods/                                        # empty
grep -rn "difficulty_at" mods/CORE/                            # empty
```

The claim *"**20 biome registrations**"* is now zero — R7 registers no Lua biome
and no Lua decoration at all — and the six-capital camp-platform decider ladder
(`AGENTS.md:799-831`, WP36's "exactly ONE decider") describes a WP18 deadlock
that has no code left to deadlock in.

Why it matters beyond tidiness: an agent that writes a mapgen brief against
`grug_mapgen/biomes.lua` writes a brief nobody can implement, and this file is
the first thing every session reads.

**Corrected** (commit "Point AGENTS.md at the mapgen that exists"). The rewrite
keeps everything still true and still load-bearing — the mgv7 stage order
(caves → ores → dungeons) and the registration-order trick, now discharged by
five native `ore_type = "stratum"` records in `wp40/r7_native.lua`; the
`default:stone`-below-−100 landmine; the unresolved-biome-name landmine; the
two-Lua-environment split; the fresh-world warning — and replaces the removed
API list with the current one, each name checked against
`grug_core/zone_authority.lua` and its callers.

### (b) world.md still says the placeholder platforms are the running map

`docs/design/world.md:416-421`: *"The running map still places the six
placeholder platforms at x = 0/±550, z = ±900 and uses them as spawn points."*
It does not. The builder (`grug_mapgen/structures.lua`) is gone, and the spawn
comes from `grug_core.start_position` (`grug_core/zone_authority.lua:487`, read
by `grug_classes/selection.lua:259`). **Corrected**: the block is relabelled
historical and kept, because its 2026-08-08 biome-guarantee argument is worth
re-reading before anyone proposes climate tuning again.

Also `docs/design/world.md:471-474`: *"the shipped platform watch … until the
real cities land"*. They landed on 2026-09-16. Corrected, and the sentence now
says what is actually missing — the king entity.

### (b) biomes_mobs.md says the running game uses the retired radial field

`docs/design/biomes_mobs.md:22-25`: *"**Migration note:** until WP40, the running
game still uses the retired radial field and the old ring vocabulary printed in
§1/§4."* WP40 shipped 2026-09-13; `_grug_spawn_zones` appears nowhere in
`mods/`, and `grug_mobs/spawn_policy.lua` reads `grug_zones.id_at`,
`pvp_rule_at`, `race_region_at` and `biome_at`. **Corrected** to say §1/§4 are a
historical record — and to say plainly that re-cutting them onto the 38 named
zones is still outstanding, rather than hide that in a status word (see §3).
`biomes_mobs.md:309`'s pointer at `grug_mapgen/biomes.lua` is marked retired.

### (a) Four obligations the code already discharged

1. `AGENTS.md:845` *"**WP40 target contract (decided 2026-08-11)**"* — shipped
   2026-09-13; `grug_zones` is published by `grug_core/zone_authority.lua:387`,
   which refuses to install if anything else published it first. Relabelled.
2. `docs/design/items_crafting.md:1260-1271` (§3.8) called the material-naming
   *"planned work, not a defect"* and the adjective catalog shipped. The reverse
   is true since 2026-09-15: §3.0.3 of the same file already carries
   "**Shipped 2026-09-15**", and `grug_gear/init.lua:64` says the adjective
   ladder "is retired here (WP13 playtest round 2)". Corrected.
3. `docs/design/world.md:990-992` — the 24 outpost anchors described as
   ring-derived *"until WP40 proves and installs the replacement"*.
   `grug_mobs/camps.lua:302`: "R7 authenticates all 24 outpost anchors."
   Corrected.
4. `docs/design/biomes_mobs.md:709` and `:1611` — the Accord jungle fringe
   *"still uses rainforest litter … until WP40 replaces the legacy biome
   registrations"*. `grep -n jungle_fringe
   mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua` gives
   `grug_jungle_fringe|grug_nodes:dirt_with_canopy_litter`, and the fringe's
   jungle trees, emergent trees and junglegrass all place on that node.
   Corrected; `default:dirt_with_rainforest_litter` correctly survives as
   `grug_jungle_edge`'s top.

### (c) Two contradictions

1. **How many capitals are walled.** `docs/design/settlements.md:182-184` says
   *"Three of the six are walled (Dur Brannoc, Nhal Veyr, Gor Drazhak) and three
   are open"*; `settlements.md:274-286` in the same file says *"Two of the six
   have no wall at all — Lethariel and Kezamba"* and records that the round-3
   plan moved Highcourt across. The code agrees with the second:

   ```sh
   grep -ln 'M\.wall\s*=' mods/MAPGEN/grug_mapgen/wp13/*.lua
   # highcourt.lua  dur_brannoc.lua  gor_drazhak.lua  nhal_veyr.lua
   ```

   and `highcourt.lua:15-25` writes the provenance out in full — an approved
   coordinator plan, **not** a user ruling, which
   `wp13-capitals-pois-contract.md` §4 records the same way and says the user may
   reverse. **Corrected** to four walled / two open, pointing at that record.
   No ruling was invented and none was paraphrased.
2. **A robe that is not on the ladder.** `docs/design/items_crafting.md:1267`
   gives *"Linen Robe"* as the cloth example. The six bolt grades in §3.0.3 and
   in `grug_gear.MATERIALS` (`grug_gear/init.lua:81-100`) are Patch / Woven /
   Heavy / Silkweave / Silk / Stormweave. Linen survives as a mob drop
   (`grug_mobs:linen_scrap`, `linen_cloth`) and as a First Aid bandage grade,
   never as armour. **Corrected** to Patch Robe, the T1 row.

### (d) Stale status boxes, numbers, paths and names

| # | Where (baseline) | What | Correction |
|---|---|---|---|
| 1 | `ROADMAP.md:185-186` | WP13 ends at the 2026-09-15 seam generalisation: *"the other three districts, the remaining five capitals and the king content are still open"* | Rewritten through the five wave-2 capitals; the open half named exactly (playtest, 12 villages + 2 shipwright plots, outposts/camps, 2 apex camps, 6 kings) |
| 2 | `BACKLOG.md:36` | WP13 status cell ends at increment 11 | Same, plus the round-3 lanes and the wave-2 NPC vocabulary |
| 3 | `BACKLOG.md:36` | *"Highcourt registers 95 NPC sockets … 71 of them carry an NPC"* — MEASURED: **256** sockets today | Number replaced with the measured one and the command that prints it |
| 4 | `README.md:221` | *Last updated: 2026-09-15* | 2026-09-16 |
| 5 | `README.md:243-283` | Current State ends at *"the remaining capitals … remain later work"*; AGENTS.md's own rule is that this section moves with every BACKLOG status change | WP13 paragraph rewritten for all six cities, the work/walker split, the twelve shops and the weapon ladder; the "not yet walked" caveat kept |
| 6 | `docs/design/settlements.md:29` | *"The other five starts, all capitals and the rest of WP13 remain separate increments"* — true on 2026-09-13, not since | Rewritten; villages/outposts/camps/kings named as the remainder |
| 7 | `docs/design/settlements.md:179-180` | *"the capitals whose cores have not been built yet keep their fixed vendor offsets"* — an empty set: all six cores export two `vendor` sockets | Kept as the fallback it is, with that stated |
| 8 | `docs/design/README.md` | `settlements.md` is the only design document missing from the index table | Row added |
| 9 | `docs/design/README.md:33` | `biomes_mobs.md` status *"target surface pending WP40"* | WP40 shipped; the outstanding §1/§4 re-cut named instead |
| 10 | `AGENTS.md:268` | modpack list names `HUD/`, which does not exist, and omits `BASE/`, which does (`ls mods/`) | Corrected to the six that exist |
| 11 | `AGENTS.md:684-687` | WP7's vendor rule: *"Placement is a throttled globalstep against fixed capital offsets — **no mapgen change**, so existing worlds get vendors too"* | Two problems: WP13 moved vendors onto blueprint `vendor` sockets and all six cores now export them, so the offsets serve nobody; and "existing worlds" is the reasoning fresh-server mode retired. Described as the fallback it now is, with the twelve shop kinds named |

### (e) Code behaviour the docs did not carry

**A bowyer is two different things.** `professions.md:192-195` says *"The Bowyer
split is dropped entirely … there is nothing left for a Bowyer to own."* Since
2026-09-15, `grug_traders/vendors.lua:446-458` registers twelve profession
**shop** vendors and one of them is `bowyer`. `settlements.md` already draws the
line — *"a shop with its own shelf, not the crafting-profession system of
professions.md"* — but `professions.md` did not, so a reader arriving from the
design side found a profession the design says does not exist. **Corrected**:
the distinction is now stated under §5's own bullet, with the twelve kinds
listed. The six-profession roster is unchanged.

## 2. Verified correct — checked, nothing changed

Recorded so the next review does not spend the time again. This project has
repeatedly found "X is missing" claims to be false, so each of these was read in
the code rather than inferred from a grep coming back empty.

| Claim | Where | Check |
|---|---|---|
| *"**40 `GRUG PATCH` sites** in `mods/ENTITIES/mobs/api.lua`"* | `AGENTS.md:518` | `grep -c 'GRUG PATCH' mods/ENTITIES/mobs/api.lua` → 40 |
| §3.0.3 weapon ladder *"Shipped 2026-09-15"* and its three-line material table | `items_crafting.md:570-629` | matches `grug_gear.MATERIALS` row for row; `grug_gear:staff_wood` exists; the four new pick tiers are in `grug_materials/tools.lua` with no recipe |
| *"Shipped (19 of 46 work packages)"* | `README.md:224` | 46 `\| WPnn \|` rows in BACKLOG.md, 19 with a ✅ status, WP16 canceled |
| Race stature table 0.85–1.12 | `character_visuals.md:40-47` | identical to `grug_visuals/compose.lua:45-50`, and the window is asserted there and in the KAT |
| Activity vocabulary, 15 names | `wp13-npc-sockets-contract.md` §8.2 | identical set to `ACTIVITIES` in `grug_core/settlement_sockets.lua:44-47` |
| Twelve shop kinds; *"only the smith and the armourer also sell the equipment ladder"* | `settlements.md:406-412` | `vendors.lua:442` `GEAR_KINDS = {smith, armourer}`; the twelve rows at `:446-458` |
| *"the still-unimplemented king L65"* | `AGENTS.md:474-476` | still true: `grep -rn '"king"' mods/ --include=*.lua` is one line, the socket in `wp13/capitals.lua:602`. No king entity |
| *"curated **333**-node `grug_decor` kit"* and *"seven vendored minetest_game building mods"* | `README.md`, `BACKLOG.md` | MEASURED: the decor KAT prints 148 + 52 + 102 + 31 = **333**; VENDOR.md carries exactly seven minetest_game rows (doors, xpanes, beds, wool, dye, vessels, walls) |
| Relative markdown links in the top-level docs | all | 0 broken across `AGENTS.md`, `README.md`, `ROADMAP.md`, `BACKLOG.md`, `CLAUDE.md`, `VENDOR.md`, `docs/design/*`, `docs/process/*`. The three backticked TODO files that do not exist (`TODO-design-boats.md`, `TODO-design-weapon-slot.md`, `TODO-design-spawn-safety.md`) are each cited as deleted or folded in, which is correct |

## 3. FOR THE USER — a decision is needed, or the code may be what is wrong

### 3.1 Five "WP40 must …" obligations that WP40's completion record does not mention

UNMEASURED by this lane. WP40 was accepted as development-complete on
2026-09-13, and these five sentences in the design docs are obligations it was
handed. `docs/research/wp40-completion.md` (159 lines) mentions none of them:

| Where | The obligation |
|---|---|
| `world.md:171-173` | *"WP40 must grade every fixed reserved anchor position inside its owning envelope or fail that seed's generation audit"* |
| `world.md:979-980` | *"WP40 must re-derive every `biome × named zone` spawn cell before replacing the old ring vocabulary"* |
| `biomes_mobs.md:9-10` | *"WP40 must reassign this catalog to fixed named-zone palettes before WP13/WP33 author new surface content"* |
| `items_crafting.md:16-17` | *"WP40 must translate placement to the named-zone catalog without changing the item, tier, depth or economy rules"* |
| `mounts.md:272-275` | *"WP40 must validate the Master tier's 100-node maximum grace travel against every authored border approach"* |

Each is one of three things and only the user can say which: already done and
merely unrecorded; deliberately deferred, in which case it belongs in
BACKLOG.md as an open item under its consumer WP; or genuinely missed. The
second one is the load-bearing one — `biomes_mobs.md` §1/§4 still hold the
retired ring spawn cells, and WP34/WP37 are the WPs that will read them.

### 3.2 The socket-count example in the NPC contract is out of date

`wp13-npc-sockets-contract.md` §8.3 derives its 10–30 % walker band from
*"Highcourt with 108 idle spawn and 36 work sockets gives 22 of 144, 15.3 %"*.
MEASURED today (`luajit -e 'io.write(dofile("tools/wp13/highcourt_kat.lua")
("."))'`):

```
highcourt_sockets  256  guard_patrol=56, guard_post=19, idle=134, king=1,
                        quest=2, spare=26, vendor=7, waypoint=1, work=36
```

The districts and the fill moved it. The band itself may still hold — 134 idle
against 36 work is comfortably inside the `I >= W` rule the section states — but
the worked example no longer matches the city it names, and the §8.3 arithmetic
is what a capital lane checks its composition against. Not corrected here: the
brief forbids rewriting research notes, and a contract's numbers are the
coordinator's to move.

### 3.3 Highcourt's socket total is not in any design document

MEASURED: 256 sockets, the table above. `settlements.md` deliberately carries
rules and not per-capital counts, which is probably right; but nothing in
`docs/design/` records how large a capital's roster actually is, and the
"lived-in without paying for it in server load" ruling of playtest round 3 is a
load statement. Whether a per-capital roster size belongs in the design docs, in
BACKLOG, or nowhere is the user's call.

## 4. Deliberately not touched

Other wave-3 lanes own these in parallel and this lane reported rather than
edited: `ROADMAP.md`'s WP26 and WP11 lines and `items_crafting.md` §3.0.2
(lane C); `items_crafting.md`'s fish and rod rows (lane F); `classes.md` and
`progression.md` skill-tree content (lane X). Nothing in the findings above
falls inside them.

Research notes were not rewritten — they are dated records — and none needed a
status pointer at its top: every WP13 note read was accurate for the date it
carries.

## 5. What a review should look at

- The AGENTS.md mapgen rewrite is the one change with real risk of losing
  knowledge. It deletes 128 lines. The question to ask is not "is the new text
  true" but "did anything true and load-bearing go with the old text": the five
  things deliberately kept are listed in that commit message, and a reviewer
  should read the deleted block against them.
- The four-walled/two-open correction: confirm the reading of
  `wp13-capitals-pois-contract.md` §4 — a coordinator plan the user approved,
  which the user may reverse — has not been upgraded to a ruling anywhere.
- The ROADMAP, BACKLOG and README WP13 rewrites are three descriptions of one
  state; they should agree with each other and with `settlements.md`.

## 6. Open

- The five §3.1 obligations, and §3.2's contract number, need the user's or the
  coordinator's decision.
- `biomes_mobs.md` §1/§4 remain the retired WP18/WP36 ring tables, now labelled
  as such. Re-cutting them onto the 38 named zones is real work with no owner.

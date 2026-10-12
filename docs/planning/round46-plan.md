# Round 46 — World generation and player feedback

Coordinator: Claude (Opus 5.5), drafted 2026-10-12 from the user's decisions
of the same day. Status: **complete** (2026-10-13, version 0.46.0, **map
reset**; [completion](#completion-2026-10-13)).

The main focus is world generation. **Seed-dependent placement** replaces
the fixed coordinates of villages, outposts, camps, mines and the PvP sites
with rules per kind. It is built so that later rounds add POI kinds, and the
quests that come with them, as data. The **ore, gem and coal distribution**
is revised in the same pass. Around that core, small packages answer the
players' feedback from 2026-10-12:

- kill and gathering XP;
- underground spawns and torches;
- a designed depth pulse;
- rage and caster weapons;
- cloth, loot and coins;
- cooking for every start zone;
- no repeatable quests;
- repair only in towns.

Release **0.46.0** with a **map reset**. The production world is not
migrated now: the user plans several rounds first and one larger update
afterwards. Each lane still classifies its change, so that update knows
what touches saved character state.

Routing (the user, 2026-10-12): Claude coordinates; Opus implements and
reviews; Astra makes art only (the repair icon). The class, skill and talent
rework is **parked** as a future work package
([continuation plan](class-redesign/continuation.md)). Only its rage fix
(lane CB) is pulled into this round.

## 1. Lanes and waves

| Lane | What | Wave | Kind | Waits for |
|---|---|---|---|---|
| OR | Ore, gem and coal distribution; the `TIERS[].ilvl` clean-up | 1 | data + mapgen pins | — |
| PL | Seed-dependent placement of villages, outposts, camps, mines, clash sites and PvP sites; extensible kind rules; a design note first | 1 (note), 2 (build) | mapgen | note: —; build: OR merged, the coordinator's review of the note |
| WT | The waiting point for players in creation stasis | 1 | code | — |
| XP | Kill XP by level difference, gathering XP, repeatable quests removed | 1 | code + data | — |
| CB | Rage per hit by weapon speed; caster spells partly from the weapon | 1 | code | — |
| LT | Loot: sell-only drops off, coin-bag compensation, cloth drops, spiders at 41–50 | 1 | data | — |
| CK | Cooking: the plain dish role, staples in every start zone, six plain dishes | 1 | code + data + icons | — |
| ART | Repair icon variants for the user's pick (Astra) | 1 | art | — |
| DP | Depth pulse: a design note for the user's decision, then the build | 1 (note), 2 (build) | design, then code | build: the user's decision, UW merged |
| UW | Underground spawns from −1, light, sight, elites; torches | 2 | code + data | XP merged (both touch `grug_mobs`) |
| RP | Repair only in towns; the Grudge-Free Repairs map and minimap icon | 2 | code + art | ART pick |
| ID | A dropdown per group ingredient in the crafting box; one torch recipe for coal or charcoal (added by the user, 2026-10-12) | 2 | code + UI | CK's count fix and UW merged |
| D | Documentation, version 0.46.0, the declaration's map-reset entry, gate list | 3 | docs | last merge |

The user's GUI test follows the round; findings go into a fix round as
in 0.45.1.

Estimates (unmeasured, for planning only), each lane plus its review:

| Lane | Hours |
|---|---|
| OR | 3–5 |
| PL | 3 note + 16–24 build |
| WT | 3–4 |
| XP | 6–8 |
| CB | 4–6 |
| LT | 4–6 |
| CK | 6–8 |
| ART | 2 |
| DP | 3 note + 8–10 build |
| UW | 4–6 |
| RP | 3–4 |
| ID | 4–6 |
| D | 3 |

PL is the largest and riskiest lane.

## 2. Rulings (the user, 2026-10-12)

1. **Map reset** for 0.46.0. There is no production migration now; it comes
   with a later combined update.
2. **Seed-dependent placement:**
   - **Randomized per seed:** villages, outposts, bandit camps, Mirefolk
     camps, mines, clash sites, the PvP war camps and the two fortresses.
   - **Fixed:** start towns, capitals, dragon arenas and rift sites. The
     rift sites are the four clash anchors that the rift reads
     (`r20_anchor_076`, `077`, `084`, `085`); every other clash site is
     randomized.
   - **Built for extension:** a later POI kind is added as data and placed
     randomly in its target zone. Quest-bearing POIs with an underground
     part (e.g. a mine with a lift) are a later round's content. This round
     provides the hooks only.
3. **Gems** also occur one tier deeper at half and two tiers deeper at a
   quarter of their own density, in addition to their own tier.
4. **T3 and coal:** the coordinator's T3 correction (§3) is the user's
   request.
   - The **coal supply** problem is solved by torches, not by more coal:
     **10 torches per coal or charcoal** instead of 4. The torch light stays
     12.
5. **Kill XP:**
   - XP per kill is the own-level kill XP of the **player's** level times a
     factor for the level difference d = mob level − player level:
     - d ≤ −7: 0 (gray);
     - −6…−1: 1 − 0.15·|d|;
     - 0: 1;
     - +1…+5: 1 + 0.10·d;
     - above +5: capped at 1.5.
   - The tier multipliers stay: **elite ×4, rare ×6**.
   - The party split stays: **every member counts in the head count**,
     whether their share is above 0 % or not (a higher-level member is an
     advantage anyway).
   - The level table stays: Curve A (level 60 needs three times the
     own-level kills of level 2) already matches the current curve.
6. **Ruling 33 is retired:** no fixed questing share. The XP mix follows the
   game's decisions; players mine a lot, and the depth pulse gives XP while
   mining.
7. **Gathering XP:** ore 0.05, gem 0.10 (the 1:2 ratio kept), fish
   unchanged, and **no +5-level bonus** for gathering.
8. **Repeatable quests are removed.**
9. **Rage per hit scales with the weapon's base swing interval:** a slower
   weapon gives more rage per hit, the same rage per second.
10. **Caster weapons, option B:** half of the spell base comes from the
    equipped weapon. Own-level gear keeps today's numbers; old gear weakens
    only moderately.
11. **Cloth:** drop chance 1/1 instead of 1/2, stack 1–2 instead of 1. The
    spellbook cost stays. Spiders spawn at levels 41–50 again.
12. **Loot:**
    - The 23 sell-only mob drops stop dropping.
    - The income is compensated through **coin bags**.
    - The income check is applied **with judgment**, not pedantically.
13. **Cooking:**
    - Every start zone and every 11–20 follow-up zone can cook locally.
    - **Plain dishes are always weaker**: a new food role.
    - One plain dish per tier from few local ingredients.
14. **Depth pulse:** wanted, with a preference for **flying** servants to
    raise the difficulty. It is its own lane; the user decides on its design
    note before the build.
15. **Underground spawns:** spawns start below y −1, are allowed up to light
    7 (a torch at 12 still protects about 5 nodes), sight is wider and there
    is an elite chance.
16. **Repair only in towns** (decided): no claim-stone repair, no furnace
    repair, no crafting-table repair station.
17. **Tests in the mapgen lanes:** as few CPU-heavy runs as possible during
    development; the full runs once at the end.
18. **Emberglass stays unchanged.** Its T5 peak follows the pattern that an
    ingredient peaks where its consumers mine.

## 3. The resource table (lane OR)

One ore node per N host nodes of the band's tier rock. "–" means none.
Changes are in bold.

| Resource | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Coal | 64 | 128 | **96** | 128 | 128 | 128 |
| Copper | 96 | 192 | 384 | 384 | 384 | 384 |
| Tin | 96 | 192 | 384 | 384 | 384 | 384 |
| Iron | 128 | 96 | **128** | 384 | 384 | 384 |
| Quartz | 128 | 256 | 512 | 512 | 512 | 512 |
| Gold | – | 512 | 256 | 128 | 256 | 256 |
| Silver | – | – | 256 | 128 | 256 | 512 |
| Emberglass | – | – | – | 256 | 128 | 256 |
| Abyssal Crystal | – | – | – | – | 512 | 256 |
| Citrine | 512 | **1024** | **2048** | – | – | – |
| Jade | – | 512 | **1024** | **2048** | – | – |
| Garnet | – | – | 512 | **1024** | **2048** | – |
| Sapphire | – | – | – | 512 | **1024** | **2048** |
| Ruby | – | – | – | – | 512 | **1024** |
| Diamond | – | – | – | – | – | 512 |
| **Share of all resources** | 5.4 % | 3.6→3.7 % | 3.0→3.7 % | 3.9→4.1 % | 3.7→3.9 % | 3.3→3.5 % |

- **The T3 correction:** T3 is the Steel band, and Steel is Iron + mined
  Coal. Iron and Coal there are raised to the T2 level of supply.
- **Unchanged:**
  - The pattern that a next-tier ingredient peaks in the band where its
    consumers mine (Iron in T2, Silver in T4, Emberglass in T5, Abyssal
    Crystal in T6).
  - Vein sizes, harvest tiers and the deep-band multipliers (×1.25 below
    −1500, ×1.5 below −2000).
  - The "exclusion ⊆ dig-forbidden" rule of Round 40.
- **Gem harvest tier stays the gem's own tier.** Deeper rock needs the
  deeper pick anyway, so no new gate appears; Coal at depth already works
  this way.
- **Owners to change together:**
  - `grug_mapgen/wp40/r6_content.lua` `RESOURCE_EXPECTED` and the gem-band
    check that enforces "own tier only" (lines 385–394);
  - the r7/r6 manifest rows;
  - `grug_materials.DENSITY` and the WP43 projection digest pinned in
    `r7_manifest.lua`;
  - `items_crafting.md` §3.0.1 (the "only in the tier rock of that tier"
    rule) and §3.0.4;
  - the gathering-XP tables (lane XP owns the ratios, not the bands).
- In the same pass, OR folds in the `TIERS[].ilvl` clean-up and the
  `r7_loader.lua:46-47` comment ([Round 45
  carry-overs](../../BACKLOG.md#round-45-carry-overs)), because both
  re-pin the same projection.

## 4. Lanes (goals; the briefs add file facts)

Every lane classifies its change (compatible, map reset, or would need a
step on a kept world) and updates the design documents whose rules it
changes.

### 4.1 OR — ore, gem and coal distribution
**Goal:**
- The table of §3 is live in the mapgen.
- Every pin and check that encodes the old table follows it.
- The design text describes the new gem rule.

**Proof:**
- The resource census of a few chunks per band (the existing per-cell
  metrics) matches the new denominators within the budget rounding.
- The `quick` seed fleet before the merge.

**Report:** the measured per-band shares.

### 4.2 PL — seed-dependent placement
**First deliverable: a short design note** (in the lane's report folder)
for the coordinator's review, before the build. It covers:
1. **Placement rules per kind:**
   - target zone or zones, the level-band fit with the zone's level field
     (a POI's band must fit where it lands);
   - spacing to every other anchor, to start towns and capitals, to zone
     borders and coasts;
   - terrain: dry, slope and flatness over the footprint, distance to
     rivers, lakes and sea;
   - kind-specific rules: fortresses dry, flat, near the Battlegrounds and
     the middle road; war camps; mines in hill or mountain terrain where
     available.
2. **Position in the world plan:** placement on the natural terrain, then
   core flattening, road routing, protection, the region-map cache and the
   quest targets. It must run identically in the main and emerge
   environments, deterministically per seed, computed once per world and
   stored in the world-layout cache.
3. **Fallbacks:**
   - If a kind finds no candidate, its rules relax stepwise in a documented
     order.
   - A world never fails to load because of placement.
   - The known failing seed 8507030740356938342 loads.
   - The rule that rivers never cover a POI core (Round 34 F3) stays.
4. **Extension:**
   - A POI kind is one rules entry; a POI is one catalog row (with its
     blueprint).
   - Nothing outside the placement owner holds anchor coordinates.
   - All consumers read positions by anchor key: quests and their targets,
     NPC sockets, map and minimap icons, protection, spawn exclusions,
     roads, the region map and tools.
   - A catalog row may declare an **underground reservation** (a volume
     under the footprint kept for a later shaft, lift or chamber). That
     covers the reservation and its protection only, no content this round.
5. The consumer list with every place that reads fixed anchor coordinates
   today (`source/simple_map.lua` `layout_fixed`, the r20 and r31 catalogs,
   tools), and how each changes.

The coordinator reviews the note. Renders of the placement for three seeds
(`tools/r31_m/render.py`) go to the user as a page. Then the build.

**Goal of the build:**
- Every randomized kind is placed per seed under its rules.
- The fixed kinds are unchanged.
- Quest targets resolve on six seeds.
- Adding a kind or a POI needs no change outside the catalog and rules.

**Tests (ruling 17), during development:**
- the offline pick tools and portable fixtures;
- single-seed engine probes over small chosen regions, each at most about
  5 minutes, never the full world (the mapgen test budget).

**Tests at the end, once:**
- the full fixture run;
- `tools/seed_fleet/run.sh quick` before the merge;
- the quest-target check on six seeds.

The full fleet is the round-end gate (§6).

### 4.3 WT — the waiting point
**Goal:** every player whose wait ends in a teleport waits at
(0, 31000, 0) from the moment they join. Map generation around waiting
players disappears. The rule and its invariants are the user's spec
(`grudgelands-orchestration/r46/waiting-point-spec.md`, kept verbatim
there): new or incomplete characters, and characters with a map-reset
backlog. A complete character without a backlog is not moved.

**Proof:**
- an engine probe that a waiting player generates no terrain below
  y 30927 apart from the shared one-time air chunks;
- that arrival and the reset relocation still teleport correctly;
- that a disconnect at the waiting point is safe.

### 4.4 XP — kill XP, gathering XP, repeatables
**Goal:**
- **Kill XP** follows ruling 5:
  - the target frame's colours and the help text match the gray line
    at −7;
  - bosses, kings and guards follow the same rule with their tier
    multipliers;
  - PvP stays without XP.
- **Gathering XP** follows ruling 7.
- **The 55 repeatable quests** are removed, together with what only
  served them: bounty boards or givers left without quests, help lines and
  achievement references. Unknown quest ids are dropped from saved state;
  verify this.
- `progression.md` replaces Ruling 33's shares with ruling 6.

**Report** (comparisons, not targets):
- the ledger (`tools/r28_design/ledger.py`) per race route before and
  after;
- quest share by level band;
- the free-play kill equivalents.

**Fixtures pinning today's numbers** are updated, not bypassed.

### 4.5 CB — rage and caster weapons
**Goal:**
- **Rage per landed swing** = (base rage + Stoke) × the weapon's **base**
  swing interval / 1 s. Every weapon gives the same rage per second; rage
  per hit taken is unchanged.
- **Caster spells** take half their base from the level baseline and half
  from the equipped caster weapon's own-level value, per ruling 10.
  - Own-level staffs and wands reproduce today's numbers.
  - Healing keeps its support-factor formula.
  - A check point, not a decision: the staff is strictly worse than wand
    plus spellbook today, and new casters start with the Bronze Staff. The
    lane reports whether option B changes that and proposes the smallest
    fix if not (for example the starting weapon).
- Tooltips, the balance model (`tools/r33_ds/models.py`) and its tables
  follow.

**Report:** before/after damage of a level-1, -30 and -60 caster with T1
and with own-level weapons, and rage per second per weapon.

### 4.6 LT — loot, coins and cloth
**Goal:**
- The 23 sell-only drops no longer drop; they stay registered.
- Coin bags compensate the lost income.
- A checkbox next to the Bag of Coins deposit slot, **on by default**,
  credits picked-up bags straight to the player's money (the user,
  2026-10-12), so nobody drags every bag into the slot by hand.
- Cloth drops at 1/1 with stack 1–2.
- Spiders spawn in the level-41–50 zones, so T5 silk has a source and
  `items_crafting.md` is right again.
- `tools/r29_e4/income.py` and the price checks stay green. Their
  corridors may be widened with a recorded reason (ruling 12).

**Report:**
- income per hour by band, before and after;
- cloth per hour per tier, against the Tailor's needs;
- the T5 silk sources.

### 4.7 CK — cooking
**Goal:**
- **A new food role "plain"**: tier HP and the out-of-combat regeneration,
  no secondary, always weaker than the existing roles.
- **Carrot and cassava** join the staple group, so all six start zones cook
  two T1 recipes.
- **One plain dish per tier** from few local ingredients, using the band
  fish where possible, local in every zone of its band. The 11–20 zones are
  covered by T1 and T2 plain dishes.
- **Two adjacent findings, fixed here:**
  - The T4/T5 fish dishes need Raw Fish, which comes only from fishing at
    levels 1–10. Accept the band fish, for example through a group.
  - The Dwarf has no local T3 recipe.
- Icons come from the existing CC0 generator script; the web data export
  is rebuilt.
- **The user's direction for higher tiers:** recipes there may need more
  ingredients from more zones, for example a T3 dish with two T3
  ingredients and one T2 ingredient. The lane checks whether the existing
  T3–T6 dishes already work this way and proposes small ingredient changes
  where they do not. Proposals only; no further recipes beyond the six
  plain dishes.

**Report:** for each race, which recipes each start and follow-up zone can
cook locally, before and after.

### 4.8 ART — repair icon (Astra)
**Goal:** several variants of a repair symbol for the map and the minimap
(the mender's Grudge-Free Repairs), readable at minimap size, on a pick
page. The user picks; RP integrates it.

### 4.9 DP — depth pulse
**First deliverable: a design note for the user**, based on the decided
WP34 (`biomes_mobs.md` "depth pulse", `TODO-design-depth.md` A2 and
A2/D10). It covers:
- start depth;
- cadence, cap per player and the 2 s warning;
- placement geometry, including sealed rooms;
- interaction with claims, POIs and towns;
- **the flyer roster:** today no hostile physical flyer lives underground.
  The cave bat is a fleeing critter, and the wisps are non-physical and
  pass through rock. The proposal should therefore be hostile physical
  flyers per depth band, preferably retinted variants of the cave bat
  without new assets, as few new names as possible (the players' "too many
  mobs" feedback);
- XP and loot;
- the particle budget (web: hundreds, never thousands).

**The user decides; then the build**, after UW's merge, because both touch
the spawn path.

**Report:** population and entity counts around one player at three depths,
measured with `tools/r24_density_xp`.

### 4.10 UW — underground spawns and torches
**Goal:**
- **Spawns:**
  - underground spawning begins below y −1, so the dead band −1…−40 goes;
  - spawns are allowed up to light 7;
  - an underground mob can see a newly spawned position (either its view
    range reaches the minimum spawn distance, or the underground minimum
    distance shrinks; the lane chooses and reports);
  - a 3–5 % elite roll underground with the existing warning telegraph.
- **Torches:** 1 coal or charcoal + 1 stick → 10 torches; the vendor torch
  price is checked against that.

**Report:** population before and after at three depths
(`tools/r24_density_xp`), and the protected radius around a torch.

### 4.11 RP — repair only in towns
**Goal:**
- Claim-stone repair and furnace repair are removed; no crafting-table
  repair station exists.
- Help texts, the design documents (`durability_repair.md`, `housing.md`
  as touched) and tooltips follow.
- The mender's Grudge-Free Repairs carries the picked icon on the map and
  the minimap, without a tooltip.

### 4.12 D — documentation
- Version 0.46.0.
- The declaration's `map_reset` entry (`tools/web_data/upgrade.json`).
- CHANGELOG, STATUS, README's current state.
- The plan's completion with the GUI checklist.
- BACKLOG carry-overs.
- The round-end gate list gains
  `python3 tools/r451_mc/gen_bat_ride_mesh.py --check`
  ([0.45.1 carry-overs](../../BACKLOG.md#0451-carry-overs)).

## 5. Rules

- Stock clients only; plain Lua 5.1; the web build is a target. Particle
  totals stay in the hundreds.
- Numbers are comparisons, never targets. A lane that gets noticeably
  slower or more complex reports to the coordinator, who asks the user.
- **Release mode:** 0.46.0 is a map reset.
  - Character-state changes (quests removed, XP rules, items no longer
    dropped) should stay readable by the new code without a step; a lane
    that finds otherwise records it for the later combined update.
  - No compatibility code for the old map.
- The terrain damage guard applies to anything the depth pulse or the
  spawns might touch; towns and POIs are never damaged.
- Sounds: none planned. Any sound needs the user's pick on a listening
  page.
- Review scope with judgment: theoretical concerns become backlog notes, not
  fix rounds.

## 6. Verification

Per lane the gates of the [round workflow](../process/round-workflow.md#3-gates).

- **Fixtures (every brief):** own fixture plus the fixtures that test the
  changed behaviour during development; the full run once before the
  report.
- **Seed fleet:** `quick` before merging OR and PL; `full` once at the round
  end on main.
- **Quest targets on six seeds** after PL.
- **The PvE micro run** (`tools/r31_pvp/run.sh`) before and after CB, as a
  comparison.
- **Economy:** `income.py --check` after LT, CK and XP.

**GUI checklist** (desktop and web, a new world):
- **Placement:** two different seeds show villages, camps, mines and
  fortresses at different, plausible places in their zones; start towns and
  capitals unchanged; roads reach the moved places; quest markers point to
  them.
- **Waiting point:** a new character waits without terrain loading around
  it, then arrives at the race start.
- **Mining:** gems one and two tiers deeper; T3 feels richer in Iron and
  Coal; 10 torches per coal or charcoal.
- **XP:** XP from a mob 3 levels below and 3 above, and gray at −7.
- **Underground:** spawns at shallow cave depth and near, but not right at,
  torches; an underground elite; the depth pulse with flyers at the decided
  depth.
- **Combat:** a dagger and an axe Warrior gain the same rage per second; a
  caster with a T1 staff at a higher level hits a little weaker than with
  own-level gear.
- **Professions and cooking:** cloth drops; a Troll and an Undead cook in
  their start zone; a plain dish is weaker than a hearty one.
- **No repeatables;** a mob drops no sell-only item but sometimes a coin
  bag, which goes straight to the purse with the auto-deposit box on and
  into the inventory with it off.
- **Repair:** only at a town mender; the repair icon on map and minimap; no
  repair at the claim stone or furnace.

## 7. Orchestration notes

**Start state:** main after the class-package commit (`acd6b70e`) and this
plan's commit.

**Before every lane start:**
- the lane-start checklist (`grudgelands-orchestration/LANE-START-CHECKLIST.md`);
- the fixture sentence in every launch prompt;
- at most 8 Lua processes through the shared queue;
- engine runs only through `tools/luanti_headless.sh` with `LC_ALL=C`;
- never the user's Luanti folder.

**File ownership (the briefs list exact files):**

| Lane | Files |
|---|---|
| OR | `grug_mapgen/wp40` resource rows and pins, `grug_materials/registry.lua`, `items_crafting.md` |
| PL | `grug_mapgen/wp40` layout and placement (`source/simple_map.lua`, catalogs, world assembly, road layout, protection, region-map cache), quest-target resolution, map icons that read anchors, `tools/r31_m` |
| XP | `grug_xp`, `grug_mobs` levels, kill XP and gray rule, the target frame, help, quest data (repeatables), the ledger tools |
| UW | `grug_mobs` spawn policy and ABMs, the mobs API patch if needed, the torch recipe |
| DP | a new depth-pulse module in `grug_mobs`, flyer variants, names |
| CB | `grug_abilities` rage, `kits.lua` spell bases, `grug_core` combat helpers, tooltips |
| LT | `drops.json`, coin bags, spider spawn data, the income tools |
| CK | `grug_cooking`, `grug_farming` staples, food roles, icons |
| RP | repair paths (claim stone, furnaces, mender), map and minimap icons |

**Merge order:**
- Wave 1 in any order, except that OR merges before PL's build starts.
- XP before UW (both touch `grug_mobs`); UW before DP's build.
- RP after ART's pick.
- D last.
- **Shared files:** LT and CK may both touch item and drop data. CK owns
  the food rows and LT the drop rows; the second to merge rebases.

**The user's touchpoints:**
- PL's placement renders (a page);
- DP's design note (a decision);
- ART's icon pick;
- the GUI test.

After merges: `tools/sync_to_luanti.sh`.

## 8. Open questions for the user

1. **The depth pulse design:** after DP's note.
2. **CK's ingredient proposals** for higher-tier dishes, if any.

## Completion (2026-10-13)

Every lane is merged on main; this lane D (this section and the status
owners) follows PL on main `54190e98`. **0.46.0 is a map reset:** world
generation changed (placement, the resource table), and no lane needs a
migration step. The production world (0.45.1) is not moved now; a later
combined update takes it across several releases (§5). **Push:** 0.46.0
is not pushed yet (pushed only on the user's word); origin/main is
`0e6b3061` (0.45.1), which production runs.

### Lanes

Main's first-parent merges from `31f16c11`, in order (the plan's own
updates `b47fdc7c`, the coin-bag Auto box, and `4d3a0685`, lane ID, lie
between them):

| Lane | Merge (follow-ups) | What | Review |
|---|---|---|---|
| OR | `a8c85077` (`82ac44d8`) | the §3 table: Coal 96 and Iron 128 in T3, gems one and two tiers deeper at 1/1024 and 1/2048; `TIERS[].ilvl` dropped; the `r7_loader` comment; WP43 projection re-pinned | MERGE AFTER FIXES (Medium: the Help gem line), fixed |
| XP | `fb524129` | kill XP by level difference (gray at −7), gathering XP 0.05/0.10/0.33 without +5, the 55 repeatables and 11 hub lines removed, Ruling 33 retired; three prices over a rounding edge | MERGE |
| WT | `82567b16` | the waiting point (0, 31000, 0) for players whose wait ends in a teleport | MERGE (doc nits fixed) |
| XPC | `29a26134` | the con colour as a green–yellow–red gradient per level | coordinator-checked delta |
| ART | `af7435b1`, `9783e969` | GPT-6 Astra's repair marker proposals (CC0, generator committed), four rounds to the user's pick A1c | the user's picks |
| CB | `de7da34c` | rage per hit by the base swing interval; the caster spell base half from the staff or wand; caster talent terms on the spell base | MERGE AFTER FIXES (two doc lines), fixed; delta MERGE |
| XPC2 | `0daa32bb` | every mob that pays the viewer no kill XP shows gray, one predicate for payout and frame | coordinator-checked delta |
| CK | `f0fd0844` | the plain food role, carrot and cassava as staples, six plain dishes, band fish in fish dishes, furnace foods plain, four ingredient swaps; ×N respects overlapping groups | MERGE AFTER FIXES (×N overcount), fixed; delta MERGE |
| RP | `b7d05a5a` | claim-stone and furnace repair removed; the mender's icon A1c on map and minimap | MERGE |
| LT | `0f5d9f36` | the 23 sell-only drops off, coin bags (1 in 8) with the Auto box, tier cloth 1/1 ×1–2, scrap rows off in bands 2–6, spiders at 41–50 | MERGE (Lows fixed) |
| CKF | `2389231f` | the ×N overlap count by halving with the output ceiling | coordinator-checked delta |
| UW | `a0ad8834` | underground spawns from y −1, light 7, sight 26, 4 % elites from level 5; 10 torches per coal or charcoal | MERGE |
| ID | `38c49eb0` (`ac874261`) | a dropdown per group ingredient in the crafting box; one torch recipe of `group:coal` | MERGE (stale-event fix) |
| LTF | `4c665966` | the no-coin-bag flag reaches the live mob (the Kraken) | coordinator-checked delta |
| DP | `0225b4ae` | the depth pulse below −300 with the user's curve, the Riftwing below −1000 | MERGE AFTER FIXES, fixed at the merge |
| PL | `54190e98` | seed-dependent placement of villages, outposts, camps, mines, clash sites, rare dens and the PvP sites; quest-named region kinds always form a region | MERGE AFTER FIXES (Medium: 13 quest targets missing), fixed; delta MERGE AFTER FIXES (the fallback restricted to quest-named kinds, plus a guard), fixed |
| D | this section | CHANGELOG, version and declaration, status owners, the Help cave line, the gate list | — |

Main has 171 portable fixtures (10 new: `r46_wt`, `xp`, `cb`, `lt`, `ck`,
`rp`, `uw`, `id`, `dp`, `pl`); `mods/` +3,499 −3,184 lines in 181 files,
three new Lua files (`grug_mobs/depth_pulse.lua`, `wp40/placement.lua`,
`wp40/placement_rules.lua`).

### Decisions during the round

The user's decisions of 2026-10-12 and 2026-10-13, one line each (the
coordinator log is outside the repository):

1. **ART:** icon A, then a hammer that reads as one (A1–A3), a heavier
   anvil (A1a/A1b), the hammer one pixel closer: **A1c**.
2. **DP-1:** no pulse above −300; 0.5 arrivals a minute at −300, rising
   linearly to 1 at −1000 and 2 at −2000, flat below; the level is the
   cave level at the arrival spot.
3. **DP-2 … DP-8** as recommended: caps 2/4/6 (to −500 / to −1000 /
   below) shared within 24 nodes; a silent 2 s warning with 32 particles;
   6–14 nodes in line of sight, sealed rooms down to 3, no room → skip, no
   node changed; claims, start footprints and hard protection refuse;
   never elite; roster R2 with the new Riftwing, Rift Spawn and Bedrock
   Sentinel; fade after 10 s without a target; full XP, family drops, no
   coin bag.
4. **CB-1:** without a usable staff or wand the weapon half is 0.
5. **CB-2:** (B) caster talent damage terms scale with the spell base.
6. **CB-3:** no staff fix; new casters keep the Bronze Staff.
7. **CB-4:** the staff, wand and spell tooltip texts are fine.
8. **XP-1:** a green–yellow–red con gradient per level (gray at −7);
   then gray for every mob that gives the viewer no XP.
9. **XP-2:** the price commit stays; **XP-3:** the repeatable mechanism
   stays for later content.
10. **CK-1:** plain dishes stand outside the Round 34 cost rule;
    **CK-2:** Cooked Meat, the Meat Block, Cooked Fish and Bread are plain;
    **CK-3:** the four ingredient swaps.
11. **×N count:** the 12 ms worst case is not acceptable → CKF (halving
    and the output ceiling).
12. **LT:** the Auto box beside the coin slot, on by default; Q1 the
    linen scrap rows of bands 2–6 removed; Q2 the label "Auto", Q3
    spiders as a minor role, Q4 coin bags for every looted kill.
13. **PL-1** rare dens placed per seed; **PL-2** apex mines fixed;
    **PL-3** the island clash sites 075 and 086 bound to their islands;
    **PL-4** fortress sides fixed (Accord east, Throng west); **PL-5** 128
    nodes to capitals and start towns; **PL-6** the build after the
    prototype renders; the build renders (seeded order) shown again.
14. **UW-1** 4 % elites from level 5; **UW-2** the level-5 floor also for
    the def-elite golems; **UW-3** the Help line about caves and torches
    (this lane).
15. **Lane ID** added: a dropdown per group ingredient and one torch
    recipe for coal or charcoal; charcoal in the coal group, so black dye
    takes it too.
16. **Hotbar A/B** prepared by a read-only survey; its timing is open.

The coordinator decided the PL note's other questions as recommended, the
×N fix (a) in `jobs.lua`, the region notes at action level and the PL
fallback restricted to quest-named kinds with its guard. DP's two build
questions (the rate linear in depth; the 3-node minimum, which leaves a
3×3 bunker safe) are built as the lane recommended.

### Deviations from the plan

- **Lane ID** joined in wave 2 (the user, 2026-10-12); four small
  follow-up deltas (XPC, XPC2, CKF, LTF) came from the user's answers and
  one DP side finding.
- **Torch radius:** a mob may stand from the fifth step of a torch
  (light 12 − 5 = 7), so 4 nodes stay clear, not 5.
- **The depth pulse** took over the Land Guard's and the Rift Spawn's deep
  rows; both left `UNDERGROUND_MOBS`.
- **The golems' elite floor** removed the L2–4 golems at −41 … −74 under
  low-level zones (the user's UW-2 covers it in intent).
- **Placement:** candidates are walked in a seeded order (mines and
  fortresses by score) instead of flattest-first, and a placed POI keeps
  clear of every authored lake's bounds; both found in the build.
- **Quest targets:** three region kinds vanished on single seeds (one
  already on main); a fallback block now forms each of the 137
  quest-named kinds, never cutting another kind's largest region.
- **The WT refutation:** the view cone requests no air chunks below the
  waiting point (0 measured); the docs say so.

### Numbers worth keeping

Comparisons, not targets.

- **Resource share per band** (OR census, seed 12345, one 80 × 80 column
  to −1312): T1 5.40 %, T2 3.75 %, T3 3.66 %, T4 4.05 %, T5 3.86 %, T6
  3.47 % (table: 5.40 / 3.74 / 3.66 / 4.05 / 3.86 / 3.47; before 5.4 /
  3.65 / 3.0 / 3.9 / 3.7 / 3.3); every resource within about 2 % of its
  denominator.
- **Kill XP per kill, solo** (normal / elite):

  | Player | d −7 | −3 | 0 | +3 | +6 |
  |---|---:|---:|---:|---:|---:|
  | L10 | 0 / 0 | 41 / 165 | 75 / 300 | 97 / 390 | 112 / 450 |
  | L30 | 0 / 0 | 96 / 385 | 175 / 700 | 227 / 910 | 262 / 1050 |
  | L60 | 0 / 0 | 178 / 715 | 325 / 1300 | 422 / 1690 | 487 / 1950 |

  The ledger's free play over the whole journey rises by 77–128 kill
  equivalents (of 968) per race route; quest shares per band now 59–99 %.
- **Rage per second:** 8 with every weapon (before: dagger 11.4, sword 8,
  battle axe 5.7, hand 8.9); per hit 5.6 / 8 / 11.2 / 7.2; Mighty Blow
  every 3.1 s from swings alone.
- **Fireball at L60** (no gear Int, no crit): own-level staff or wand 337,
  T1 staff 256, no caster weapon 240; with Tinder 5/5: 404 / 295 / 274.
- **Income per hour** (`income.py`, by band 1–10 … 51–60): 172 / 428 /
  911 / 2440 / 6448 / 14764c before → 196 / 439 / 1038 / 2575 / 6978 /
  16723c after; tier cloth per hour T1 6.0 → 17.9, T5 silk 3.1 → 7.1.
- **Cooking locality** (zones that cook a recipe of their own band): T1
  2/6 → 6/6, T3 7/14 → 14/14, T4 2/6 → 6/6, T5 1/2 → 2/2, T6 1/4 → 4/4
  (T2 6/6).
- **Underground population** (`r24_density_xp`, hostiles within 56 nodes
  / entities, seed 4242424242 under Hearthpine): −30 7.0 / 17 → 8.7–9.0 /
  23; −300 10.7 / 25 → 14.7–18.0 / 32–41; −900 11.7 / 27 → 14.0–16.3 /
  29–37. With the pulse (`POINTS=pulse`): −400 9 / 18–22 → 7–8 ambient, 0–1
  pulse / 18–22; −1000 6 / 14–18 → 7–8 / 16–20; −1500 12–14 / 30–34 →
  12–13 / 26–32. Pulse step 12.5 µs mean, 368 µs max.
- **The waiting point:** 0 chunks generated around moved and waiting
  players (the control that stayed: 14).
- **First start** (seed 42): offline 18.1–19.3 s → 19.2–20.1 s
  (placement 0.4–0.6 s); engine 19.6–21.0 s, a cache hit 4.7–4.8 s.
- **Quest targets on six seeds:** 1047 ok and 13 missing → 1060 ok, 0
  missing, with 3 fallback blocks on 3 of 228 maps.
- **×N count** (`r46_ck/bench_count.lua`, Sweetroot Mash, worst case):
  3.32 ms (LuaJIT) / 11.29 ms (`-joff`) → 0.002 / 0.004 ms; a whole
  Cooking page 3.40 / 11.40 → 0.047 / 0.055 ms.
- **Crafting page** with two dropdowns: 3552 → 3652 B.

### Classification

- **Map reset:** OR and PL (world generation). The layout and region-map
  caches rebuild once (their keys digest the mapgen tree and the
  recipes).
- **Compatible:** every other lane. Saved state the new code reads
  differently, for the later combined update:
  - quest state: the removed repeatables drop from the active and tracked
    lists at load; their `completed` and `cooldowns` entries stay dead;
  - running crafting jobs of a changed recipe (the torch, Mushroom
    Skewer, Raw Forager's Pot, Salt-Crusted Fish, Stormkelp Broth,
    Cocoa-Rubbed Game) return their ingredients;
  - new player meta `grug_money:auto_deposit` ("off" only; absent = on);
  - underground mobs save a `view_range` field; pulse arrivals are never
    saved;
  - a player who leaves at the waiting point is saved at (0, 31000, 0)
    and returns to the same flow.
- **The declaration:**
  `{"schema": 2, "version": "0.46.0", "map_reset": ["0.40.1", "0.46.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0"]}`.

### Open notes

The reviews' and reports' backlog notes are in the
[BACKLOG](../../BACKLOG.md#round-46-carry-overs).

### GUI checklist (Round 46)

Desktop (GUI scale 1 and 2) and the web build (about 1280 × 720), on new
worlds.

**Placement:**

1. Two worlds with different seeds (for example 42 and 2026): villages,
   bandit and Mirefolk camps, mines, outposts, clash sites and rare dens
   stand at different, plausible places in their zones, on dry, fairly
   flat ground, never in a river; start towns, capitals, dragon arenas,
   apex mines and the four rift sites are unchanged.
2. Roads and trails reach the moved places; the fortresses' gates face
   the middle road, the Accord's on the east side, the Throng's on the
   west; the war camps sit in their zones.
3. The map and minimap icons and the quest markers (a camp, a mine, a
   leader, a quest area) point to the moved places on both seeds.
4. Seed 8507030740356938342 loads.

**Joining:**

5. A new character joins and waits without terrain loading around it,
   creates, and arrives at its race start; leaving mid-creation or before
   arriving and rejoining continues normally.
6. After a map reset an existing character waits, then lands at its race
   start; an ordinary rejoin keeps its position.

**Mining and torches:**

7. T2 rock has an occasional Citrine, T3 Jade and rarer Citrine, T6 Ruby
   and Sapphire next to Diamond; a deeper gem still reads "Requires a
   T<own> pick" and pays its own tier's XP; T3 feels richer in Iron and
   Coal.
8. Coal at level 1 gives +2 XP, T1 ore at level 10+ +4.
9. One recipe "Charcoal or Coal Lump" + a Stick → 10 torches; black dye
   from Charcoal.

**XP and quests:**

10. A mob 3 levels below gives about 55 %, 3 above 130 %; the name line
    shades green (6 below) → yellow (own level) → red (5 above); 7 below,
    critters, own-faction guards and the Kraken show gray with (no XP).
11. No Bounty quests anywhere (the Copperfell steward, Raincall); the
    quest dialog's legend has no "(R)"; Help → Levels shows the new text.
12. Apprentice Riding and the Boat cost 1s 10c, the bracket-5 respec
    5s 50c.

**Underground:**

13. At y −5 … −30 outside a start town cave mobs appear; none inside the
    town footprint; none within 4 nodes of a torch, some from about the
    fifth; Help → Levels has the cave line.
14. A cave mob about 25 nodes away comes at you; underground ranged mobs
    (Goblin Pelter, Fire Hurler) shoot from about 26 nodes.
15. An occasional gold elite with the wind-up from level 5 on; none, and
    no golem, in level 1–4 caves.

**The depth pulse:**

16. At −300 … −350 an arrival about every 2 min: the violet wind-up for
    2 s, then a Blood Bat or Glowwing 6–14 nodes away in view, attacking;
    at −1000 about one a minute; at −2000 about every 30 s.
17. Below −1000: Riftwings (violet, glowing), Ember Wisps, Rift Spawn,
    sometimes a Bedrock Sentinel; nothing arrives above −300; a walled
    3×3 cell gets nothing, a 7×7 room does; nothing in a claim.
18. An arrival that loses you fades after 10 s; kills give XP and family
    drops, never a coin bag, never a gold elite tint (the Sentinel stays
    its own elite); the web build stays smooth with several deep players.

**Combat:**

19. A Warrior's Strike tooltip shows 5.6 with a dagger, 8 with a sword,
    11.2 with a battle axe; dagger and axe fill the bar equally fast per
    second.
20. A level-30+ caster with a T1 staff hits visibly weaker than with an
    own-level staff or wand, and with none at half the base; Fireball and
    Smite tooltips change on equip; staff and wand tooltips show the
    "spell base" line.
21. A caster talent tooltip with an empty weapon slot: the number is
    halved, the wording still says "with your staff or wand" (judge it).

**Loot and money:**

22. No sell-only drop; about one kill in eight a Bag of Coins; with Auto
    ticked it goes to your money on pickup ("Deposited Xc.", no "+1 Bag of
    Coins" line), unticked into your bags; the Auto box between the coin
    slot and Sort, its tooltip readable, not clipped on the web; reopening
    keeps the tick.
23. Zombies and outlaws drop tier cloth (1–2) on every looted kill;
    spiders by night in both level 41–50 fronts (Ford Weaver, Trench
    Widow); the Kraken drops no coin bag.

**Crafting and cooking:**

24. Sweetroot Mash with carrot and cassava: two dropdowns; Cassava for
    the root lowers Max and ×N and Craft now takes cassava; the torch with
    coal and charcoal: Automatic = the sum, Coal Lump takes only coal;
    a used-up kind falls back to Automatic or the dropdown goes; another
    recipe starts on Automatic; the dropdown fits the box on the web and
    its list opens over the rows below.
25. A Troll in Kapok and an Undead in Stillgrave cook Sweetroot Mash, Raw
    Hearty Stew and Spiced Skewer from local food; a level 11–20 zone
    cooks Pan-Fried Trout (Silver Trout from its water).
26. Spiced Skewer, Cooked Meat and Bread show 3 % (plain) against Hearty
    Stew's 4 % (tooltip and Effects); the labels "Any vegetable", "Any raw
    fish", "Cave Cap or Mushroom"; the six new icons readable (Spiced
    Skewer next to Mushroom Skewer, Pan-Fried Trout next to Corn-Crusted
    Fish).

**Repair:**

27. The hammer-and-anvil icon at Grudge-Free Repairs on the map window and
    the minimap in a capital and a start town, no tooltip, not the other
    faction's; a town trainer and the mender repair; a furnace in a claim
    has no "Repair equipment"; Help → Bags, food and repair says "only in
    towns"; Help → About shows 0.46.0.

### Round-end gates

**Round-end gates on the final branch** (coordinator): *to be filled in:
full fixtures, full seed fleet, `check_upgrade.py`,
`check_fresh_server.py`, `gen_bat_ride_mesh.py --check`, smoke boot,
lane D's review.*

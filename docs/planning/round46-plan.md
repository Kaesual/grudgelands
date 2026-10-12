# Round 46 — World generation and player feedback

Coordinator: Claude (Opus 5.5), drafted 2026-10-12 from the user's decisions
of the same day. Status: **planned**; starts after a context compaction and
the user's go.

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

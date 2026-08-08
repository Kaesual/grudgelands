# TODO — Depth: danger, spawn pressure and where resources come from

Opened 2026-08-08, out of the WP25 runtime test. WP25 shipped the six rock
strata, so depth is now a real gate for the first time — and testing it
surfaced a set of coupled questions the existing docs answer either not at
all or in a way the owner has since overturned.

**Everything in this file is open unless its *Decision* line says
otherwise.** No decided *rule* lives here — a decided question keeps only a
short stub naming the design file it landed in, so the reasoning behind it
stays findable; the rule itself lives in `docs/design/` (AGENTS.md
"Documentation layers").

Groups: **A** the depth curve and spawn pressure · **B** renewable
resources · **C** the housing isles · **D** the T6 band as endgame
content.

---

## ⚠ Design-doc statements this file overturns

Three passages in `docs/design/` are **no longer true** and are waiting on
the open questions below before they can be rewritten. Until then, do not
implement against them:

1. **`world.md` §2 R4** — "Ores/resources respawn (node timers) in the open
   world" with the isles as the exception. Reversed by **B5**: nothing
   respawns anywhere except inside indestructible structures.
2. **`items_crafting.md` §3.0.2 / §3.0.1** — "Abyssal Crystal … so
   Grudgesteel needs the level-30 isle grant and its deepest depth step",
   and the T6 row's "no continental deposit at all" (written 2026-08-08,
   §10.3 D11). Reversed by **C7**: the crystal is a base resource and gets
   a continental deposit below −1000.
3. **`world.md` §5.4** — "Housing mining is a treasure hunt, not a second
   ore economy". Partially reversed by **C8**, which is still open: isles
   are to become worth mining, but the *distribution* is the open question
   and it must not be the continental one.

`combat_stats.md` §3's depth axis (+1 per 20 nodes) is superseded by **A1**
but not contradicted — it is a recalibration of the same formula.

---

## A. The depth curve and spawn pressure

### A1 — The depth level curve

**Decision:** decided 2026-08-08 → lands in `combat_stats.md` §3.

The model is unchanged and was already correct: `mob_level_at =
max(surface_level(x,z), depth_level(y))`, cap 60. Only the *rate* is
recalibrated, from "+1 per 20 nodes" to **3 levels per 50 nodes**, so that
the two anchors the owner set fall exactly on stratum boundaries.

Why `max()` and not an additive term, since the question came up: the
material ladder is absolute in y — silver sits at −301…−500 everywhere. An
additive depth term would make the same vein a different game depending on
where the player stands horizontally, would make the newbie zone the safest
place to mine T4, and would blow the level cap. `max()` binds the danger to
the resource, which is what makes depth the "alternative progression path"
that `combat_stats.md` §3 already claims it is.

The reasoning stays here; the formula, the anchors and the crossover table
live in `combat_stats.md` §3.

### A2 — Spawn pressure by depth: the phase-in

The load-bearing open question of this file.

**The constraint that rules out the obvious answer.** `mobs:spawn`
registers a static ABM: `chance` and `active_object_count` are fixed at
registration time, and **`aoc` is counted per entity NAME in a 128-node
sphere, shared by every row of that name** (AGENTS.md; measured in
`docs/research/wp6_spawn_budget.md`). A second, deeper spawn row for
`grug_mobs:zombie` therefore cannot carry a larger budget than the shallow
one — the two share it. A depth-continuous spawn rate is not expressible in
the ABM model at all.

Options:

- **(a) A player-centric phase-in pulse.** A throttled globalstep walks the
  players, and for each one below the threshold rolls an arrival at a
  frequency `f(depth)`, spawning in the dark rock near them. Independent of
  light, independent of cavern volume, and hard-capped per player.
- **(b) One "deep" entity name per mob** (`grug_mobs:zombie_deep`, …) so
  each band gets its own `aoc` budget. Works within the shipped model, but
  it doubles the roster, and `aoc` still cannot vary *within* a band.
- **(c) Raise `chance`/`aoc` globally on the existing cave rows.** One
  number, no new machinery, but it raises the pressure at −120 as much as
  at −1800 and it spends the budget the WP6 audit measured.

Recommendation: **(a)**. It is the only option that yields a continuous
curve; it is what the fiction already says (`story.md` §1: "something
demonic and ancient stretches its dark hands **from below** into the
overworld" — the servants leak through before the portals do); it scales
with player presence rather than with how much air the mapgen happened to
carve, which is the right cost model at the 100-player target; and it is
the only one that can ignore light on purpose. The existing ABM cave rows
stay as they are and remain the ambient cave life.

**Open numbers**, to be set as starting values and then calibrated in a
runtime test the way `wp6_spawn_budget.md` did:

- The arrival curve. Proposed shape, single formula, safe by construction:
  `arrivals_per_minute = min(R_MAX, max(0, (−y − Y0) · R_MAX / SPAN))`
  with a suggested `Y0 = 300` (nothing above it), `R_MAX = 6/min` and
  `SPAN = 1700`, giving ~2.5/min at −1000, ~4.2/min at −1500 and the
  ceiling of 6/min at −2000 and below. The `min()` is what makes it hold
  past −2000 rather than growing without bound.
- **The concurrent cap per player** — proposed 6. This is the real safety
  valve and the number the 100-player target actually cares about.
- Spawn placement: distance band from the player, line-of-sight rule,
  whether it must be a solid-adjacent air node, and what happens if there
  is no legal position (skip, or widen the search).
- **Whether a phase-in may appear inside a sealed room.** This is the whole
  point of the mechanic and should be answered explicitly: removing the
  light gate alone does *not* deny safe areas, because a walled 3×3 room
  offers no spawn position at all. If "no safe areas below X" is to be
  literally true, the pulse has to be allowed to place a mob in a room the
  player dug out. Recommendation: yes, below the same threshold, and that
  is exactly the story beat.
- Which mobs phase in. Recommendation: a small dedicated set rather than
  the whole cave roster, so the fiction reads (these are *servants*, not
  local wildlife) and so the `aoc` accounting stays separate.

**Decision:** _open_ — the mechanic is decided (a), the numbers are not.

### A3 — Surface spawn rate, slightly up

The owner wants the overworld a little denser as well. This is the ABM
rows' `chance`, and it has one binding constraint: `aoc` is the cap that
`docs/research/wp6_spawn_budget.md` calibrated against the 100-player
target, and it is shared per entity name.

Options: **(a)** lower `chance` on the surface rows (more attempts, same
ceiling) — the safe knob, because `aoc` still bounds the outcome;
**(b)** raise `aoc` — moves the ceiling itself and re-opens the budget
audit.

Recommendation: **(a)**, in one pass across the surface rows, with the
budget audit re-run afterwards. A ~25 % reduction in `chance` is a sensible
first step.

**Decision:** _open_ (the amount).

### A4 — Does anything scale past level 60?

**Decision:** decided 2026-08-08 → no design-doc change needed; the
existing rule stands.

**60 stays the cap for regular mobs.** Depth beyond −1000 buys *frequency*,
not stats. The existing exceptions are untouched: elite guards via
`guard_level_at`, and fixed-level bosses via `_grug_fixed_level` (the
Kraken at 100).

This is what keeps `grug_core.difficulty_at`'s 0..1 contract intact — it is
normalised as `(level−1)/59` and read by several consumers, so a level 80
mob would have broken it. It also keeps the XP curve out of the balance
question: a level 60 player farming the deep band is paid in materials, not
experience, which is the intended shape.

One consequence worth stating when this lands: because strength is capped,
"too dangerous even for a perfectly equipped level 60" has to come from the
**rate of arrival**, not from the concurrent count — a trickle that never
lets the player finish clearing the room, so the mining happens under
permanent pressure. That is also the cheap answer for the server: a modest
concurrent cap (A2) with a high arrival rate costs far less than a swarm.

---

## B. Renewable resources

### B5 — Ore respawn is removed

**Decision:** decided 2026-08-08 → lands in `world.md` §2 R4 (rewrite) and
`items_crafting.md` where R4 is referenced.

R4 existed so "a persistent world doesn't run dry". The depth economy of
group A solves that better: an effectively unbounded supply priced in
**danger and travel** instead of in waiting. Renewable ore actively worked
against the design — it caps the value of every mined material at the
respawn timer and turns mining into a rotation rather than an expedition.

It also removes a special case instead of adding one: `world.md` §5.4
already exempted the housing isles from R4, so "nothing respawns" becomes
the universal rule.

Implementation note, so nobody deletes the wrong thing: the machinery in
`mods/ITEMS/grug_nodes/ore_respawn.lua` is **re-scoped, not removed** — the
depleted-vein node and the `register_on_dignode` hook are what B6 needs.
The hook already carries a marker for exactly this kind of zone check.

### B6 — Renewable nodes live only where the world is not editable

**Decision:** the rule is decided 2026-08-08; the content is open.

The rule, as the owner put it and sharpened: **nachwachsende Ressourcen
existieren ausschließlich dort, wo die Welt nicht editierbar ist.** That is
the line the design already draws with the POI protection registry
(`grug_core.add_poi`, `world.md` §2 R1), and it is self-enforcing — a
player who cannot dig the walls cannot build a farm around the node.

Decided: mining camps carry **10–15** renewable resource nodes, and a
camp's ore is **its own region's tier**, so a camp is a place to get T3
without a −400 expedition. That makes it the "resource site + conflict
point in one" that `world.md` §4 already asks for. Non-camp POIs get the
same treatment later, one renewable node type per POI kind (the owner's
example: a gem block on a jungle-temple altar).

Open:

- **Mining camps do not exist as a structure yet.** `world.md` §4 mentions
  them only as a *role* an outpost can have ("e.g. a dwarven mining camp").
  Someone has to build them — most likely WP13 (world structures), which
  would then also own their protection footprint.
- Which POI kinds qualify, and the node count per kind.
- Whether the depleted-vein placeholder stays visible inside camps (it is
  good ambience — a worked-out vein that refills) or whether the node
  simply reappears.
- The respawn interval inside camps. The shipped 15–30 min was tuned for a
  world-wide mechanic; for a handful of nodes at a destination it can be
  much longer.
- `world.md` §4 currently states the opposite in writing — "ore respawns
  there like everywhere else, R4" — and inverts to "only there".

**Decision:** rule decided; content **open**. Blocks nothing today, but
WP13 cannot author camps without it.

---

## C. The housing isles

### C7 — Abyssal Crystal gets a continental deposit below −1000

**Decision:** decided 2026-08-08 → lands in `items_crafting.md` §3.0.1
(placement table), §3.0.2 (the Grudgesteel sentence) and §10.3 (D11 is
partly reversed).

The crystal is a **base resource**, not a privilege, and the deep band is
where it belongs thematically. This reverses the decision taken earlier the
same day (no continental deposit), which had been made to keep §3.0.2's
claim that Grudgesteel depends on the isle depth ladder literally true.
That claim is what changes: the isle keeps its own reason to exist through
C9's exclusive materials instead of by holding the T6 alloy hostage.

Open only as numbers: the band and the `register_ore` scarcity, to be
authored in the §3.0.1 table alongside the WP25 values. It should be
genuinely scarce — the deep band's appeal is meant to be volume under
pressure, not a T6 giveaway at −1010.

### C8 — What is actually in an isle's rock?

**This is the open question of group C, and the recommendation contradicts
the owner's first instinct — deliberately, so it gets decided rather than
assumed.**

The owner's goal: an isle should be worth mining ("Mining lohnt sich"), by
carrying the same base resource distribution as the continent, plus C9's
exclusives.

The problem is magnitude. An isle is a 100×100 build box running from the
seabed at −30 down to bedrock — call it 970 nodes deep, so **~9.7 million
nodes**. At the continental quartz density decided in WP25 (`clust_scarcity
= 8³`, 6 ores per cluster) that is roughly **113,000 quartz nodes** in one
player's private box. Protected ground (R5), no mobs, no PvP, no depth
danger, no travel. An owner would never mine the continent again, and the
entire group-A danger economy would be bypassed by anyone who bought the
depth ladder.

The finiteness argument does not rescue it: 1.9 g buys a supply that
outlasts the character.

Options:

- **(a) Keep §5.4's shape, raise its generosity.** The isle keeps
  *deterministic treasure clusters per purchased step* rather than an ore
  field, but the clusters are made rich enough that clearing a step is a
  real payday. Preserves the "treasure hunt, not a second ore economy"
  decision while satisfying "mining is worth it".
- **(b) Continental distribution at a fraction of the density** — e.g. a
  tenth — so the isle is a slow, safe trickle and the continent stays the
  place to actually supply a profession.
- **(c) Continental distribution at full density** — the owner's first
  formulation. Simple and generous, and it makes the isle the primary mine
  for everyone who owns one.
- **(d) No base ores at all, only C9's exclusives.** The purest reading of
  §5.4, and the strongest push back onto the continent — but then the
  depth ladder's first four steps buy almost nothing.

Recommendation: **(a)**, with the cluster contents scaled to the step's
tier. It is the smallest change to a decision that was made deliberately
six weeks of design ago, it keeps the safe/dangerous split that group A
exists to create, and "a bought step yields a defined, generous haul" is a
better fit for a **gold sink** than "a bought step yields an ore field",
because a sink should pay out a known amount.

**Decision:** _open_ — **blocks WP24**.

### C9 — One isle-exclusive rare material per depth tier

**Decision:** the direction is decided 2026-08-08; names, numbers and
effects are open.

Decided: each of the six depth steps additionally holds **one rare material
that exists nowhere else in the world**. Non-renewable (B5/B6 — an isle is
editable ground, so nothing regrows there), and reserved for special
recipes: unique endgame items and the highest-tier upgrades. This is what
gives the 1.9 g depth ladder its own reason to exist once C7 takes the T6
alloy off its back.

The owner's first concrete idea, as the shape to aim for: **a stone that
amplifies an item's magical properties — applicable once per item, raising
all prefix and suffix values by 10 %.**

Open:

- Six names, six textures, six drop items, and which step holds which.
- Scarcity per step. These are meant to be a find, not a yield.
- **The amplifier's interaction with the affix system.** It multiplies
  §6.3's rolled values, so §6.3's cap arithmetic has to be re-run — the
  same check A3 in `TODO-design-crafting-rework.md` already ran for eight
  slots. The caps are consumer-side (crit clamps at 30 %, armor at 60 %),
  so it probably absorbs cleanly, but it must be verified rather than
  assumed. It also needs a once-per-item marker in item meta, which is
  WP5's description/roller territory.
- Whether the remaining five materials get effects now or stay reserved.
  The owner's framing — "später, wenn wir das Grund-Spiel fertig haben,
  können wir dort auch weitere Materialien für mehr Rezepte verstecken" —
  argues for naming all six but only wiring the amplifier in the MVP.

**Decision:** direction decided; content **open**. Blocks WP24's treasure
clusters and, for the amplifier, WP5.

---

## D. The T6 band as endgame content

### D10 — What is down there below −1000: the roster and the environments

**Decision:** the band's **role** is decided 2026-08-08 → landed in
`world.md` §4c, cross-referenced from `items_crafting.md` §3.0.1's T6
row. Decided there: below −1000 is the T6 stratum, reachable only with a
T6 tool, and it is intended to **carry endgame content** — dangerous
underground environments, the owner's own example being **lava lakes
with dangerous creatures around them**, plus a level-appropriate roster.
**The content is open, and it is this group's only question.**

Two decisions in this file already fence it in: **A4** caps regular mobs
at 60, so the band's danger has to come from the environment and from
the **rate of arrival**, not from bigger stats; **A2**'s player-centric
phase-in is the mechanism that delivers that rate, and it already needs
a roster of its own.

Open:

- **The creature roster.** Which families live down there, and whether
  they are the A2 phase-in set extended (one roster, one `aoc`
  accounting) or a second, place-bound set that spawns from the rock the
  way the cave rows do. Recommendation: **extend A2's set** — the
  fiction is the same one (`story.md` §1: the servants leak through from
  below), and a second mechanism would have to re-solve the per-name
  `aoc` problem A2 exists to route around.
- **Lava lakes: biome, decoration, ore blob or structure pass?** The
  four are not equivalent here:
  - **(a) A deep biome.** Biomes take y bounds and the underground
    biome is already registered once (`grug_mapgen/biomes.lua`), but the
    six strata are **stratum ores registered last** and convert
    `default:stone` wholesale (`items_crafting.md` §3.0.4), so a
    biome's own stone would be overwritten and only its cave/deco layer
    would survive. A biome buys less here than it looks like it does.
  - **(b) An `ore_type = "blob"` pass** of lava inside
    `group:grug_stratum` rock. Cheapest by far, rides the existing ore
    stage, and needs no new machinery — but a blob has no shape
    control, so it makes pockets, not lakes with a surface and a shore.
  - **(c) A `register_on_generated` VoxelManip pass**, in the same file
    as the continent mask and the camp platforms
    (`grug_mapgen/structures.lua`). The only option that can express a
    *flat* connected lava surface with an air dome over it — i.e. an
    actual lake you stand at the edge of. Costs a pass on the hot path
    and a chunk-box fast path to keep it cheap.
  - **(d) A schematic/structure set** placed by WP13's structure pass,
    which would also give the band ruins, bridges and lairs rather than
    only terrain.

  Recommendation: **(c) for the lakes plus (b) for cheap ambience
  pockets**, and (d) later for anything with walls.
- **How the band relates to `world.md` §4b's apex bosses.** §4b's stage
  1 is a *visible* outdoor carrot (the Mountain Wyrm at the outer ring,
  "you can see it at level 8 and fight it at 50"), which is the exact
  opposite of a boss nobody can reach without a T6 pick. Open: does the
  deep band get an apex of its own — the lair/hoard/arena tech already
  exists and is generic — or does it stay roster-plus-environment, with
  the bosses left on the surface? Recommendation: **roster-plus-
  environment for the MVP**, a deep apex as a §4b stage of its own once
  the band has content at all, so the two are not authored at once.
- **Whether the band gets its own drop layer.** `items_crafting.md` §5's
  loot table has a "Depth axis" row that today lists only materials
  ("cave mobs as per surface tier"). A level-60 roster in a place only a
  T6 player reaches is the natural home for T6 gear drops, and that is a
  §5 edit, not a §4c one.

*Lands in*: `world.md` §4c (the environments and the band's content
role), `biomes_mobs.md` §3/§4 (the mob rows and their spawn parameters),
`items_crafting.md` §5 (the drop layer, if it gets one).
**Decision:** role decided 2026-08-08; content **open**. Blocks the
depth WP's content half, and WP13 if the lakes turn out to be structures.

---

## Status summary

| # | Question | Blocks |
|---|---|---|
| A1 | ~~Depth level curve~~ — decided 2026-08-08 (3 levels per 50 nodes, `max()` model unchanged) | — |
| A2 | Phase-in spawn pressure: the numbers, the placement rules, the roster | **the depth WP** |
| A3 | How much to raise the surface spawn rate | the depth WP |
| A4 | ~~Anything past level 60?~~ — decided 2026-08-08 (no; depth buys frequency, not stats) | — |
| B5 | ~~Ore respawn removed~~ — decided 2026-08-08 | — |
| B6 | Renewable nodes: which POI kinds, counts, intervals — and mining camps do not exist yet | WP13 |
| C7 | ~~Abyssal Crystal continental below −1000~~ — decided 2026-08-08; scarcity numbers open | WP26 (reads §3.0.2) |
| C8 | What is in an isle's rock — the recommendation contradicts the first instinct on purpose | **WP24** |
| C9 | Six isle-exclusive materials; the affix amplifier's cap re-check | **WP24**, WP5 |
| D10 | The T6 band's content — roster, lava lakes, relation to the apex bosses (the band's **role** is decided 2026-08-08 → `world.md` §4c) | the depth WP, WP13 |

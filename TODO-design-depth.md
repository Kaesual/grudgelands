# TODO — Depth: danger, spawn pressure and where resources come from

Opened 2026-08-08, out of the WP25 runtime test. WP25 shipped the six rock
strata, so depth is now a real gate for the first time — and testing it
surfaced a set of coupled questions the existing docs answered either not
at all or in a way the owner has since overturned.

**The settled depth rules were folded into `docs/design/`.** What remains here
is their reasoning plus the two unresolved spawn/content details below
(AGENTS.md "Documentation layers").

**Two small remainders are still open**, both content rather than mechanics:
the pulse's placement geometry (A2) and the servant roster below −1000
(A2/D10).

Groups: **A** the depth curve and spawn pressure · **B** renewable
resources · **D** the T6 band as endgame content.

---

## A. The depth curve and spawn pressure

### A1 — The depth level curve

**Decision:** decided 2026-08-08 → **landed in `combat_stats.md` §3**
(with the anchors and the crossover points; `world.md` §1 and §4c and
`biomes_mobs.md` §1.5 cite it).

The model is unchanged and was already correct: `mob_level_at =
max(surface_level(x,z), depth_level(y))`, cap 60. Only the *rate* is
recalibrated, so that the two anchors the owner set fall exactly on
stratum boundaries.

Why `max()` and not an additive term, since the question came up: the
material ladder is absolute in y — silver sits at −301…−500 everywhere. An
additive depth term would make the same vein a different game depending on
where the player stands horizontally, would make the newbie zone the safest
place to mine T4, and would blow the level cap. `max()` binds the danger to
the resource, which is what makes depth the "alternative progression path"
that `combat_stats.md` §3 already claims it is.

### A2 — Spawn pressure by depth: the phase-in

**Decision:** decided 2026-08-08 → **landed in `biomes_mobs.md` §4.1**
(mechanism, curve, concurrent cap, the sealed-room rule with its
telegraph, and the staged roster); `combat_stats.md` §3 and `world.md`
§4c link to it with a sentence each.

The load-bearing decision of this file, and the constraint that decided
it belongs here as well as in the design doc: `mobs:spawn` registers a
**static** ABM whose `chance` and `active_object_count` are fixed at
registration time, and **`aoc` counts per entity NAME in a 128-node
sphere, shared by every row of that name** (AGENTS.md; measured in
`docs/research/wp6_spawn_budget.md`). A depth-continuous spawn rate is
not expressible in the ABM model at all. A **player-centric pulse in a
throttled globalstep** was chosen because it is the only option that
yields a continuous curve, it scales with player presence rather than
with how much air the mapgen happened to carve, and it is the only one
that can ignore light on purpose.

Rejected:

- **One "deep" entity name per mob** (`grug_mobs:zombie_deep`, …) to buy
  each band its own `aoc` budget. Works inside the shipped model, but it
  doubles the roster and `aoc` still cannot vary *within* a band.
- **Raising `chance`/`aoc` globally on the existing cave rows.** One
  number and no new machinery, but it raises the pressure at −120 as much
  as at −1800 and it spends the budget the WP6 audit measured.

Also settled while deciding: the pulse's shallow half reuses the existing
cave families, so **the depth work package ships without a single new
mob**, and the ABM cave rows stay untouched as ambient cave life.

**Still open** (content, blocks nothing that has started):

- **Placement geometry** — the distance band from the player, the
  line-of-sight rule, whether the target must be a solid-adjacent air
  node, and what happens when no legal position exists (skip, or widen
  the search).
- **The servant roster below −1000** — see D10, which is the same list.

### A3 — Surface spawn rate, slightly up

**Decision:** decided 2026-08-08 → **landed in `biomes_mobs.md` §4**
(the factor, the two mechanism-driven exclusions, and the multiplied
`chance` column).

`chance` is the safe knob because `aoc` — the ceiling
`docs/research/wp6_spawn_budget.md` calibrated against the 100-player
target — still bounds the outcome: more attempts fill the same budget
faster, they do not raise it. Rejected: **raising `aoc`**, which moves
the ceiling itself and re-opens the budget audit rather than merely
re-running it.

### A4 — Does anything scale past level 60?

**Decision:** decided 2026-08-08 → no design-doc change needed; the
existing rule stands.

**60 stays the cap for regular mobs.** Depth beyond −1000 buys
*frequency*, not stats. The existing exceptions are untouched: elite
guards via `guard_level_at`, and fixed-level bosses via
`_grug_fixed_level` (the Kraken at 100).

This is what keeps `grug_core.difficulty_at`'s 0..1 contract intact — it is
normalised as `(level−1)/59` and read by several consumers, so a level 80
mob would have broken it. It also keeps the XP curve out of the balance
question: a level 60 player farming the deep band is paid in materials, not
experience, which is the intended shape. The consequence — that "too
dangerous even for a perfectly equipped level 60" has to come from the
**rate of arrival** — is what A2 then delivered.

---

## B. Renewable resources

### B5 — Ore respawn is removed

**Decision:** decided 2026-08-08 → **landed in `world.md` §2 R4**
(rewritten), with §4 and the README pulled along.

R4 existed so "a persistent world doesn't run dry". The depth economy of
group A solves that better: an effectively unbounded supply priced in
**danger and travel** instead of in waiting. Renewable ore actively worked
against the design — it caps the value of every mined material at the
respawn timer and turns mining into a rotation rather than an expedition.

The sole renewable exception is the bounded protected mining-camp socket
mechanism in B6.

Implementation note, so nobody deletes the wrong thing: the machinery in
`mods/ITEMS/grug_nodes/ore_respawn.lua` is **re-scoped, not removed** — the
depleted-vein node and the `register_on_dignode` hook are what B6 needs.
The hook already carries a marker for exactly this kind of zone check.

**Known deviation until then**: the shipped code still runs the old
world-wide respawn, so it now contradicts the design docs (which are the
spec); re-hanging it onto mining camps belongs to **WP34**, and the same
note sits in `BACKLOG.md`'s readiness section.

### B6 — Renewable nodes live only where the world is not editable

**Decision:** decided 2026-08-08 → **landed in `world.md` §2 R4** (the
exception, with the counts, the tier rule and the interval) **and §4**
(the camp's role and the fact that the structure does not exist yet).

The rule, as the owner put it: **renewable resources exist only where the
world is not editable.** That is the line the design already draws with
the POI protection registry (`grug_core.add_poi`, `world.md` §2 R1), and
it is self-enforcing — a player who cannot dig the walls cannot build a
farm around the node.

Scoped to **mining camps only** in the MVP. Rejected: opening the
exception to every POI kind at once — the owner's own later idea (a gem
block on a jungle-temple altar) is exactly the sort of thing that should
wait until one structure has proven the shape. The long respawn window
was chosen against the shipped 15–30 min because a handful of nodes at a
guarded destination is a different object from a vein under every hill: a
camp should be worth a trip every few sessions, never a rotation.

Mining camps still have to be **built** — `world.md` §4 had named them
only as a *role* an outpost can carry. That is WP13's job (structure,
garrison, protection footprint), and WP34 owns the respawn mechanic that
runs inside them.

---

## D. The T6 band as endgame content

### D10 — What is down there below −1000: the roster and the environments

**Decision:** decided 2026-08-08 → **landed in `world.md` §4c** (the
band's role, the lava-lake mechanism, and no apex boss in the MVP) and
**`items_crafting.md` §5** (no drop layer of its own), recorded in §10.3
D16.

**Lava lakes** are a `register_on_generated` VoxelManip pass in
`grug_mapgen/structures.lua` plus cheap `ore_type = "blob"` lava pockets
for ambience. Rejected: a **deep biome** — the six strata are stratum
ores registered last and convert `default:stone` wholesale, so a biome's
own `node_stone` would be overwritten and only its cave/deco layer would
survive; **blobs alone** — no shape control, so pockets rather than lakes
with a surface and a shore; **schematics** — the right tool for anything
with walls, and still the right tool later, but not for terrain.

**No apex boss of its own in the MVP.** §4b's apex bosses are
deliberately *visible* outdoor carrots — the Mountain Wyrm is seen at
level 8 and fought at 50 — and a boss behind a T6 pickaxe is the exact
opposite of that, so it is not the same design object under a different
sky. Authoring the zone and its boss at once would mean inventing both
against nothing; the lair/hoard/arena tech is generic and waits.

**No gear drops.** The depth pays in raw materials only, which keeps §0's
promise that the best items come from crafting and hard bosses intact.

**Still open**: the **servant roster** below −1000 — which families live
down there, their models and their drop tables. A2 already decided that
they are the pulse's own set (one mechanism, one accounting) rather than
a second place-bound spawn source, and that the shallow half of the pulse
reuses existing mobs, so this is content on top of a shipped mechanic
rather than a blocker underneath it.

---

## Status summary

| # | Question | State |
|---|---|---|
| A1 | Depth level curve | ~~open~~ decided 2026-08-08 → `combat_stats.md` §3 |
| A2 | Phase-in spawn pressure | ~~open~~ decided 2026-08-08 → `biomes_mobs.md` §4.1; **placement geometry + servant roster still open** |
| A3 | Surface spawn rate | ~~open~~ decided 2026-08-08 → `biomes_mobs.md` §4 |
| A4 | Anything past level 60? | ~~open~~ decided 2026-08-08 (no; depth buys frequency, not stats) |
| B5 | Ore respawn removed | ~~open~~ decided 2026-08-08 → `world.md` §2 R4 |
| B6 | Renewable nodes: scope, counts, interval | ~~open~~ decided 2026-08-08 → `world.md` §2 R4 / §4 (camps only; the structure is WP13's) |
| D10 | The T6 band's content | ~~open~~ decided 2026-08-08 → `world.md` §4c, `items_crafting.md` §5; **the servant roster still open** |

**Implementation**: `BACKLOG.md` **WP34 — Depth economy** carries the
mechanics half of A2/A3/B5/B6/D10; WP13 owns the mining camps as a
structure.

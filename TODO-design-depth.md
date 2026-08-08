# TODO — Depth: danger, spawn pressure and where resources come from

Opened 2026-08-08, out of the WP25 runtime test. WP25 shipped the six rock
strata, so depth is now a real gate for the first time — and testing it
surfaced a set of coupled questions the existing docs answered either not
at all or in a way the owner has since overturned.

**All ten questions were decided on 2026-08-08 and folded into
`docs/design/`.** What is left in this file is the reasoning and the
rejected options behind each decision — no rule and no number lives here
(AGENTS.md "Documentation layers"). Three passages this file had flagged
as overturned (`world.md` §2 R4, `items_crafting.md` §3.0.2/§3.0.1 and
`world.md` §5.4) were rewritten in the same pass and are current again,
so the warning block that used to stand here is gone.

**Three small remainders are still open**, all of them content rather
than mechanics, listed under the stubs they belong to: the pulse's
placement geometry (A2), the servant roster below −1000 (A2/D10) and the
names of the six isle-exclusive materials (C9).

Groups: **A** the depth curve and spawn pressure · **B** renewable
resources · **C** the housing isles · **D** the T6 band as endgame
content.

---

## A. The depth curve and spawn pressure

### A1 — The depth level curve

**Decision:** decided 2026-08-08 → **landed in `combat_stats.md` §3**
(with the anchors and the crossover points; `world.md` §1 and §5.4 and
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

It also removes a special case instead of adding one: `world.md` §5.4
already exempted the housing isles from R4, so "nothing respawns" becomes
the universal rule.

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

## C. The housing isles

### C7 — Abyssal Crystal gets a continental deposit

**Decision:** decided 2026-08-08 → **landed in `items_crafting.md`
§3.0.1** (the reversal and the placement row), with §5, §5.5 and §10 P5
pulled along and §10.3 D15 recording it.

The crystal is a **base resource**, not a privilege. This reverses the
decision taken earlier
the same day (no continental deposit), which had been made only to keep
§3.0.2's claim that Grudgesteel depends on the isle depth ladder
literally true. That claim is what changed: the isle keeps its own reason
to exist through C9's exclusive materials instead of by holding the T6
alloy hostage. It is deliberately the scarcest entry in the placement
table — what the band sells is volume under pressure, not a giveaway.

**Caught while folding, and the reason the band is the T5 one rather than
the deep one**: an earlier draft put it below −1000, which closed the
ladder into a circle — T6 rock only opens to a Grudgesteel pick, and
Grudgesteel is made of this crystal, so the 10 % apex-hoard drop would
have become the tier's only door instead of a bridge. §3.0.1's binding
rule already answers it: a lead metal lies one band *above* its own
tier. Abyssal Crystal is no exception to that rule, and the ore node
carries the `level` of the Emberrock it sits in.

### C8 — What is actually in an isle's rock?

**Decision:** decided 2026-08-08 → **landed in `world.md` §5.4** — §5.4's
shape stands (deterministic treasure clusters per purchased step, no ore
field), the clusters become markedly more generous, and each step's
clusters are filled in that step's own rock tier.

The recommendation contradicted the owner's first instinct on purpose and
was accepted. The magnitude is what carries it: an isle is 100×100 from
the seabed at −30 to bedrock, i.e. **~9.7 million nodes**, so continental
ore density would have put tens of thousands of ore nodes on protected,
mob-free, PvP-free, travel-free ground — an owner would never mine the
continent again and the whole group-A danger economy would apply only to
other people. The finiteness argument does not rescue it: 1.9 g buys a
supply that outlasts the character. The second argument is the sink's:
**a gold sink should pay out a known amount**, and an ore field pays out
whatever the seed felt like.

Rejected: **continental distribution at full density** (the first
formulation — makes the isle the primary mine for everyone who owns one);
**continental distribution at a fraction of the density** (a slow safe
trickle still bypasses the danger axis, just more slowly); **no base
materials at all** (the purest reading of §5.4, but then the ladder's
first four steps buy almost nothing).

### C9 — One isle-exclusive rare material per depth tier

**Decision:** decided 2026-08-08 → **landed in `world.md` §5.4** (six
materials, one per step, non-renewable, all six placed and only one live)
and **`items_crafting.md` §6b.8** (the Amplifier's effect and its rules),
recorded in §10.3 D17.

Each of the six depth steps additionally holds one rare material that
exists nowhere else in the world. That is what gives the 1.9 g ladder its
own reason to exist once C7 takes the T6 alloy off its back. Only the
**Amplifier** does anything in the MVP — once per item, +10 % on all
prefix and suffix values. The other five are named, textured and placed
but inert, which is the whole point of placing them now: a later recipe
package can hang new recipes on stock that is already in the ground,
without a mapgen change and without regenerating anybody's isle.

Two follow-ups were written into the design as **tasks, not open
questions**: §6.3's cap arithmetic is re-run against the multiplier (the
same check §6.3 already ran for eight slots — the caps are consumer-side,
so it should absorb cleanly, but verified rather than assumed), and WP5
owns the once-per-item marker in item meta.

**Still open**: the **six names, textures and scarcities**, and which
step holds which. These are meant to be a find, not a yield. Blocks
WP24's treasure clusters, nothing else.

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
| C7 | Abyssal Crystal continental below −1000 | ~~open~~ decided 2026-08-08 → `items_crafting.md` §3.0.1 |
| C8 | What is in an isle's rock | ~~open~~ decided 2026-08-08 → `world.md` §5.4 (generous clusters, no ore field) |
| C9 | Six isle-exclusive materials + the Amplifier | ~~open~~ decided 2026-08-08 → `world.md` §5.4, `items_crafting.md` §6b.8; **the six names/textures/scarcities still open** |
| D10 | The T6 band's content | ~~open~~ decided 2026-08-08 → `world.md` §4c, `items_crafting.md` §5; **the servant roster still open** |

**Implementation**: `BACKLOG.md` **WP34 — Depth economy** carries the
mechanics half of A2/A3/B5/B6/C7/D10; WP13 owns the mining camps as a
structure and WP24 the isle side of C8/C9.

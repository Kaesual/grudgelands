# TODO — Crafting rework: what the 2026-08-07 session left open

The crafting/professions/materials rework was decided on 2026-08-07 and
folded into `docs/design/` (commit `d5baf03`): the two ladders
(`items_crafting.md` §2.1), the six-tier material ladder (§3.0), one item
per concept (§3.0.3), exact natural pick depths plus separate harvest tiers
(§3.0.4), the six
material-cut professions (`professions.md` §2), the one recipe book per
profession (§2.2) with the surviving keystones (§2.3), refinement and the
prefix/suffix affixes (§6b), the herb/spice split
(`biomes_mobs.md` §2) and the new `mounts.md`. The later material, map,
open-world housing and mount-geography decisions live in their design docs;
this file retains only the crafting/content questions they did not answer.

**Everything in this file is open.** No decided rule or resolved-question
stub lives here; those rules and their rationale belong to `docs/design/` and
the repository history. Several design sections point here by name for exactly
these remaining lists.

Once a question is decided: fold it into the design doc named in its
*Lands in* line, update ROADMAP/BACKLOG where affected, and remove the resolved
question from this file. When nothing open is left, delete the file
(AGENTS.md "Documentation layers").

Groups: **A** crafting & items · **B** material calibration · **C** profession
identity · **D** mounts.

## A. Crafting & items

### A3 — Do bags participate in refinement and enchanting?

`items_crafting.md` §6b.1 still names bags as an Ornate refinable family, but
§6b.2's bonus modifies base damage or armor and ordinary durability. A bag has
none of those values, so "Ornate Bag" currently has no defined effect. The
separate trinket exception in §6.2 is complete and does not belong to this
question.

Options: **(a)** define a bag-specific refinement benefit without colliding
with the fixed 8/16/24/32-slot ladder; **(b)** remove bags from the refinable
families entirely and reserve the Ornate word for cloth armor and spell tomes.

Recommendation: **(b)**. The four mastery sizes already supply the bag line's
progression, and removing one unsupported family is clearer than adding a
second bag axis.

*Lands in*: `items_crafting.md` §§6b.1/6b.2.
**Decision:** _open_ — affects WP10's Tailor book.

---

## B. Material calibration

### B22 — The six picks' dig-speed progression: the actual `times`

The material review keeps the **rule** — every higher-tier pick is faster on
ordinary rock, including its own current band — but retires engine level
difference as the progression mechanism. Natural-depth access and resource
harvesting are separate checks in `world.md` §2 R6 and do not set the speed
curve.

The six effective `times` and `uses` sets are still unauthored. They must form
an explicit six-pick progression, preserve sensible durability and be measured
against representative ordinary rock in a runtime calibration. Wood and Stone
starter picks share the T1 depth cap but still need a deliberate relative
speed below Bronze.

Options:

- **(a) Author one `times`/`uses` set per tier from a curve**, then verify the
  effective seconds and blocks-per-tool values in a six-pick table.
- **(b) Reuse one vendored profile for every tier.** Cheapest, but it makes
  access the only reward and contradicts the decided speed progression.

Recommendation: **(a)**, calibrated in a runtime test rather than derived on
paper (pattern: `docs/research/wp6_spawn_budget.md`). Author it together with
the missing Iron, Silversteel, Embersteel and Abyssal Steel picks.

*Lands in*: `items_crafting.md` §3.0.4.
**Decision:** _open_ (the `times` and `uses` numbers). Owner:
**WP29/WP22** — WP29 authors the pick catalog and recipes, WP22
runtime-calibrates dig times and durability (BACKLOG WP22 row). WP26
ships bars and furnaces only, no picks.

---

## C. Profession identity

This is not a gap in a list. It is a consequence the rework produced
deliberately, and it leaves one profession standing on very little in the MVP.
It wants a decision, not an author.

### C12 — Does the bow foundation receive a playable ranged class?

The item foundation is already decided: bows follow the material weapon curve,
arrows are stackable ammunition, the Woodcarver owns bows and the Leatherworker
owns quivers. The current MVP classes and the named Phase-2 additions contain
no Hunter-like bow user, so those registrations would have no designed combat
consumer.

Options:

- **(a) Add a Hunter-like ranged class** and author its resource, baseline
  attack, abilities, armor rank and talent identity around the bow foundation.
- **(b) Keep the foundation inactive** until a later class package explicitly
  adopts it; no player-facing bow, arrow or quiver recipe ships in advance.
- **(c) Assign bows to one already planned Phase-2 class**, then revise that
  class's kit around a ranged baseline rather than adding another class.

Recommendation: **(b)** until a class package can evaluate (a) and (c) against
the complete seven-class role roster. It preserves the license-checked item
work without shipping a dead equipment line or silently redesigning a class.

*Lands in*: `docs/design/classes.md`, `docs/design/items_crafting.md` §9 and
`docs/design/professions.md` §5.
**Decision:** _open_ — blocks any playable bow consumer, not the existing item
foundation or its profession ownership.

---

## D. Mounts

`docs/design/mounts.md` decides the four level-15/30/45/60 tiers and their
6/8/7/10-node speeds (§1.1), income-time price targets (§2), the persistent
inventory item plus ephemeral attached entity (§3), ocean warning/hard-flight
boundaries, flyable Holy Grounds and the enemy-territory flight ban (§4), plus
the licence-checked references (§5). The unresolved parts below must close
before the work package can ship.

### D12 — Which assets represent the four mount tiers?

Open: which models represent the four tiers, and from where.

`mounts.md` §5 clears the *code* licences (mobs_redo MIT, LotT
LGPL 2.1, VoxeLibre GPL-3.0-or-later) but names **no model** for a
flying mount. mobs_redo ships none; VoxeLibre's `mobs_mc/horse.lua`
covers the land tiers. Assets have to go through the AGENTS.md licence
rule (re-verify in the source repo before import) and the shopping-list
pattern of `docs/research/assets/`.

**Decision:** _open_.

### D14 — Can mounts be attacked, damaged or killed, and do they drop anything?

`mounts.md` §3 already says a mount carries no level, no XP, no threat
and no aggro, and is **not** registered through `grug_mobs.register_mob`
(that wrapper is the level engine). It does not say what a punch does to
it.

Options: **(a)** invulnerable, no drops — a permanent purchase must not
be destructible, and PvP counterplay is D15's dismount instead;
**(b)** killable with the mount returning to the owner (a cooldown, not
a loss); **(c)** killable and lost — rejected: 60s of gold deleted by
one gank.

Recommendation: **(a)**, and it got stronger on 2026-08-08: D15's damage
dismount is now **decided** (`mounts.md` §3.1), so the counterplay
option (a) leans on exists in the design rather than being promised by a
sibling question. A hit already takes the rider off the mount; making
the mount itself destructible on top would only add the gank loss (c)
was rejected for.

**Decision:** _open_.

### D15 — May a player mount while in combat?

Incoming damage already dismounts immediately under `mounts.md` §3.1. Open:
whether the mount action is also **refused**
while `grug_core.mark_in_combat` / `in_combat` is true (the 5 s window
shipped with WP4 and reused by WP6's leash and by recovery). Under the
damage rule alone a player can remount between two hits and ride away
from a fight already started. The hook exists and costs nothing; this needs a
decision, not an author.

Options: **(a)** refuse mounting for the complete 5 s combat window;
**(b)** allow mounting between hits and rely on the next damage event to
dismount again; **(c)** add a separate cast-like remount delay.

*Landed in*: `mounts.md` §3.1.
**Decision:** _open_ and wanted before the mount WP, not during it.

### D16 — May flying tiers operate underground?

Enemy territory, Holy Grounds, PvP-tag and ocean behavior are decided in
`mounts.md` §4 and no longer belong to this TODO.

**Still open:** whether either flying tier may operate underground. The earlier
recommendation remains unrestricted underground because the pick's natural
depth limit, rather than physical arrival, owns material access.

### D17 — Flight ceiling and post-dismount drift

The authored ocean/channel warning and hard-flight boundaries are decided in
`mounts.md` §4.1.

**Still open:** the general flight ceiling. The eventual ceiling and forced-
dismount implementation must bound post-dismount air drift so a high-altitude
rider cannot cross a dragon-channel hard strip after losing the mount. The
design deliberately does not choose a ceiling value yet.

### D18 — What does "Exhausted" do to an un-mounted player?

The revised `mounts.md` §4.1 no longer uses `Exhausted` for flight: flyers have
a spatial warning band and a hard no-flight column. Whether an unmounted
swimmer in deep ocean receives an `Exhausted` effect is therefore purely an
ocean-survival question. The present deterrents are the Kraken Guard, immutable
deep-ocean terrain and the boat-threat rules.

Options: **(a)** cosmetic for swimmers — the Kraken does the killing;
**(b)** escalating damage over time after the same 10 s window;
**(c)** a stamina model — swim speed decays to zero and the player
sinks.

Recommendation: **(b)**. It does not depend on one mob's spawn roll and makes
the deterrent legible ("the sea is killing me") instead of arbitrary.

*Lands in*: the revised ocean section of `world.md`, not the mount movement
system.
**Decision:** _open_.

### D19 — Are skins/variants separate purchases, and are the four tiers four creatures?

Open: (i) is a mount tier one creature or a choice of several; (ii) are
they per faction, per race, or global; (iii) do cosmetic variants cost
extra.

The art bill decides this. Six races × 4 tiers × 2 factions is 48
skins — a Phase 3 quantity (ROADMAP: own assets are Phase 3), and WP7
already accepted that even the race vendors ship **without** race-specific
skins.

Recommendation: **four creatures total** (two land, two flying),
re-skinned per **faction** for flavour and not per race. Defer cosmetic
variants as separate purchases entirely — the economy has no cosmetic
sink today, and inventing one is a bigger decision than mounts.

**Decision:** _open_.

---

## Status summary

| # | Question | Blocks |
|---|---|---|
| A3 | Whether bags participate in refinement and enchanting | WP10 |
| B22 | The six picks' explicit dig-speed `times` and durability `uses` | WP29/WP22 |
| C12 | Whether the bow foundation receives a Hunter-like or existing ranged class | future class/bow package |
| D12, D14–D19 | Mount assets, entity damage, mounting in combat, underground flight, ceiling/post-dismount drift, swimmer exhaustion, skins | **mounts WP** (D20 decided 2026-08-13 → `mounts.md` §1) |

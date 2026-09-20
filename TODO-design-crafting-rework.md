# TODO — Crafting rework: what the 2026-08-07 session left open

The crafting/professions/materials rework was decided on 2026-08-07 and
folded into `docs/design/` (commit `d5baf03`): the two ladders
(`items_crafting.md` §2.1), the six-tier material ladder (§3.0), one item
per concept (§3.0.3), exact natural pick depths plus separate harvest tiers
(§3.0.4), the seven
material-cut professions (`professions.md` §2), the exclusive Basics and one
UI recipe book per learned profession (§2.2), refinement and the
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

Groups: **B** material calibration · **C** profession identity · **D** mounts.

## B. Material calibration

### B22 — The six picks' dig-speed progression: the actual `times`

The curve **shape** is decided (2026-08-13, `items_crafting.md` §3.0.4):
one monotonic six-point curve each for speed and durability, Wood/Stone
deliberately below Bronze at the shared T1 depth cap, authored as a WP29
table and runtime-calibrated by WP22 against representative ordinary rock
(pattern: `docs/research/wp6_spawn_budget.md`) — never vendored-profile
reuse, never the retired engine `leveldiff` coupling.

Open here: **only the six effective `times` and `uses` sets themselves.**

*Lands in*: `items_crafting.md` §3.0.4.
**Decision:** _open_ (the `times` and `uses` numbers). Owner:
**WP22** — the six-tier pick catalog and familiar universal recipes now exist;
WP22 runtime-calibrates only dig times and durability (BACKLOG WP22 row).

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

## D. Ocean survival (deferred)

The former mount questions D12 and D14–D17/D19 are decided in
`docs/design/mounts.md`: shipped appearances, invulnerable/no-drop entities,
five-second combat refusal, no underground takeoff, y=600 ceiling with cleared
drift, and the fixed faction/race tier families. They are no longer open design.

### D18 — What does "Exhausted" do to an un-mounted player?

This remains a separate, deferred ocean-survival question. It does not block
mount behavior: flyers use their warning band and hard no-flight columns. The
current ocean deterrents are the Kraken Guard, immutable deep-ocean terrain and
boat-threat rules. No new swimmer exhaustion mechanic is authorized by the
Round-10 mount decisions.

---

## Status summary

| # | Question | Blocks |
|---|---|---|
| B22 | The six picks' explicit dig-speed `times` and durability `uses` | WP29/WP22 |
| C12 | Whether the bow foundation receives a Hunter-like or existing ranged class | future class/bow package |
| D18 | Optional unmounted swimmer exhaustion behavior | deferred ocean-survival package |

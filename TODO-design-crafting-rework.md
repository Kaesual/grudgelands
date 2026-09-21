# TODO — Crafting rework: what the 2026-08-07 session left open

The crafting/professions/materials rework was decided on 2026-08-07 and
folded into `docs/design/` (commit `d5baf03`): the two ladders
(`items_crafting.md` §2.1), the six-tier material ladder (§3.0), one item
per concept (§3.0.3), exact natural pick depths plus separate harvest tiers
(§3.0.4), the seven
material-cut professions (`professions.md` §2), the exclusive Basics and one
UI recipe book per learned profession (§2.2), and the
prefix/suffix system (now superseded by the Round13 fixed-enchant rules), the herb/spice split
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

Groups: **B** material calibration · **D** ocean survival.

## B. Material calibration

### B22 — The six picks' dig-speed progression: the actual `times`

The curve **shape** is decided (2026-08-13, `items_crafting.md` §3.0.4):
one monotonic six-point curve each for speed and durability, Wood/Stone
deliberately below Bronze at the shared T1 depth cap, authored as a WP29
table and runtime-calibrated by WP22 against representative ordinary rock
(pattern: `docs/research/wp6_spawn_budget.md`) — never vendored-profile
reuse, never the retired engine `leveldiff` coupling.

Open here: **only the six effective dig-speed `times` sets.** The lifetime
`uses` values are decided in `docs/design/crafting_equipment_revision.md`
(2026-09-21), so they are not an open design question. WP29 authors the speed
table; WP22 owns runtime speed calibration. This separates
design authorship from runtime calibration without moving either package's
existing responsibility.

*Lands in*: `items_crafting.md` §3.0.4.
**Decision:** _open_ (the `times` numbers only). Owners: **WP29** authors
the table; **WP22** runtime-calibrates dig times (BACKLOG WP22
and WP29 rows).

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
| B22 | The six picks' explicit dig-speed `times` | WP29/WP22 |
| D18 | Optional unmounted swimmer exhaustion behavior | deferred ocean-survival package |

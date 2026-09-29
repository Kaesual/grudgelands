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

Group: **D** ocean survival.

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
| D18 | Optional unmounted swimmer exhaustion behavior | deferred ocean-survival package |

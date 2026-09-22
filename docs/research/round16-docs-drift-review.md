# Round 16 bounded documentation/code drift review

Reviewed integrated commit `a449549a06355a1f3dbd183b2f72347f06363590`
on `wp16-playtest-polish`, plus the supplied lane F handoff/review drafts.
Reviewer: native GPT-6 Astra; authored none of this review scope.

## Verdict

Two documentation corrections: **0 Critical / 0 High / 1 Medium / 1 Low**.
No additional gameplay implementation defect was established in this bounded
drift audit. This is not a replacement for the completed independent lane
reviews or the coordinator's pending final gates.

### D-1 — Medium: current XP pacing still describes the pre-increase award

Locations: `docs/design/progression.md:12`,
`docs/design/combat_stats.md:499`; related unqualified XP representations at
`docs/design/combat_stats.md:420`, `:547` and `:571`.

The living rules still say approximately 20 same-level kills per level and
justify that with XP = 10L, although Round 16 now settles normal eligible solo
kills at 15L before racial modifiers. A future balancing task following these
paragraphs will use the old reward and an incorrect kill count, contradicting
the explicit +50% decision and progression.md's own Round 16 section.

Evidence: `mods/PLAYER/grug_xp/init.lua:15-17` retains cumulative XP
`100*(L-1)^2`, making the next interval `100*(2L-1)`.
`mods/ENTITIES/grug_mobs/levels.lua:117` still constructs the internal normal
base as `10L`; `mods/ENTITIES/grug_mobs/init.lua:228` applies 1.5 exactly once
before sharing. Thus the kill-only ratio is `(200L-100)/(15L)` (about 12.7 at
level 10, approaching 13.3), before quests/race bonuses/sharing. This is
arithmetic, not a proposed pacing target or evidence for the 10–20-hour goal.

Minimal correction: replace both ~20-kill statements with the qualified current
formula/approximation, without changing the curve or tuning the approved design.
Explicitly label the 10L formula and 10/100/300/600 table as **base XP before
the Round 16 settlement multiplier**, or provide the corresponding current
normal solo award column (15/150/450/900). Qualify the boar/zombie XP example
similarly; the internal base value itself is still correct.

### D-2 — Low: the promised fixed quest reward table is absent from its living authority

Locations: `docs/design/quests.md:83-84` and
`docs/design/progression.md:99-104`.

quests.md says the starter/local values are given by a fixed target-level table
in progression.md, but that file contains only percentage ranges and a short
starter summary. A reader following the current design reference cannot recover
the accepted concrete catalog values; the complete table exists only in
`docs/research/round16-progression.md:7-34` and executable catalog constants.

Evidence: `mods/PLAYER/grug_quests/content.lua:7-9` fixes the nine main-chain
values and target levels, `:272-277` fixes six local rewards, and `:332-346`
fixes the two lessons. These agree with the research handoff's table.

Minimal correction: promote the current intended-level/effort/new-XP columns
into progression.md section 4, including lessons and optional local quests;
retain the old/new comparison as historical research evidence. Clarify the
outpost step's 25% exception and lesson/local 15/20/25% shares there. No runtime
reward framework or new reward tuning is needed.

## Scope that agrees

- Food: raw 2%, dishes 4/5/6/7/8/10% per five-second tick, 300-second duration,
  unchanged instant restoration/secondary modifiers; combat refusal precedes
  consumption/status replacement and later combat pauses ticks. Successful
  food uses gain 0.5; drinking retains normal source gain and rejected use is
  silent. Checked the living tier/recovery/status rules against food and alchemy
  consumption sources; lane F's independent report covers exact asset hashes.
- Atmosphere: 04:30–19:30 phase at speed 60 gives 15 minutes, complement at 108
  gives five; ordinary night floor 0.30 and night-vision floor 0.45 compose with
  brighter natural sunlight. Source semantics match world.md; exact client
  perception and phase-edge polling precision remain the documented limits.
- Ambient population: eligible surface chance/caps scale by 1.3 with integer
  rounding; underground/critter/NPC/dedicated encounter exclusions match the
  binding Round 16 paragraph and spawn policy. This does not certify measured
  realized density or revive historical spawn-budget claims.
- Combat: three-second/top-times-1.1 Taunt, 120% valid-target switching,
  accepted-hit 1.5-second Charge stun, king/dragon immunity, Nova hard root and
  quarter-baseline damage, once-only Rimebite contribution, and lightweight
  root-bound particles agree with current living amendments and lane B's
  corrected independent evidence.
- Atlas: individual authored quest/service/boss records, name-only tooltips,
  live directional self/online-party records, and no grouping/displacement agree
  with world_map.md and AGENTS.md. No remote interaction or new anchor scope.
- Quests and XP apart from D-1/D-2: catalog constants, prerequisites, six
  quest-six village handoffs, single kill-XP multiplier, exact interval HUD and
  privileged administrative grant match the approved decision and code.
- Preparation: local tile selection, persisted Y selection/inner cursor,
  success-only tile progress, immutable mode, 320-node margin and bounded live
  terrain/selector digest agree with world_preparation.md and AGENTS.md. No
  global height prepass, fallback cuboid or old-plan migration was introduced.
- Mount teardown and armor/station/HUD amendments agree with their living
  summaries and independently reviewed lane records. Current-world persistence
  is retained; the audited increment does not add expansion/waypoint scope.

## Evidence limits and calibration

Read-only source/document comparison against the approved Round 16 plan,
affected living specs, AGENTS.md summaries, completion/execution drafts and
lane handoffs/review reports. Applied the workflow's design-adherence review
requirement. Historical unrelated design cleanup and known pending delivery
fields were intentionally outside scope. No production edits, tests, PUC or
LuaJIT execution, native server, world generation, benchmark, GUI, external
service, Claude task or CLI delegation were performed. The only output written
is this review report. Final integrated gates and user runtime acceptance remain
with the coordinator/user; report inspection does not certify future runs.

Implementation models: native Astra/Sol as recorded by the lane ledger.
Independent reviewer: native Astra, no authorship in reviewed scope.
Classification: non-trivial final documentation/design-consistency audit.
Initial C/H/M/L: **0/0/1/1**. Fix rounds at this report: **0**; coordinator
corrections pending. Elapsed wall time: **unknown**.

User runtime plan: follow `docs/research/round16-playtest.md`, including actual
solo kill/quest XP, food refusal/recovery/audio, day/night/cave/night-vision
appearance, moving-target stun/root and two-player threat, atlas readability,
mounted logout/shutdown, and fresh-world partial preparation stop/restart.

## Focused correction closure — 2026-09-22

**CLEAN: D-1 and D-2 resolved; no remaining findings.** Reviewed the coordinator's
working-tree corrections to progression.md and combat_stats.md above integrated
commit `a449549a06355a1f3dbd183b2f72347f06363590`.

- D-1: both pacing passages now use normal solo `15L` awards and the unchanged
  `(200L-100)` interval, with the level-one rounded count and high-level ratio
  appropriately described as approximate. combat_stats.md now explicitly
  distinguishes internal base XP from the final 1.5-times settlement value;
  its table gives correct base/award pairs 10/15, 100/150, 300/450 and 600/900.
  The retained historical WP1/WP6 examples sit under that explicit base-XP
  interpretation and do not prescribe a different current award.
- D-2: progression.md now contains the concrete fixed values for all nine
  main-chain positions, both optional lessons and all six local quests.
  Compared every value and intended level directly with the current catalog
  constants/registrations; all agree. The hard level-11 row is 525 (25% of
  2,100), the camp finale 805 (35% of 2,300), and optional/local rows agree
  with the stated 15/20/25% shares. quests.md's existing reference now resolves
  to an actual living table. No reward or XP-curve tuning was introduced.

Focused source comparison only; no runtime, interpreter, test, native server
or production edit by the reviewer. Pending delivery-overview updates remain
outside this correction verdict. Calibration update: **one fix round**,
initial **0/0/1/1**, remaining **0/0/0/0**; reviewer remains independent;
elapsed wall time unknown. The preceding user runtime plan and evidence limits
are unchanged.

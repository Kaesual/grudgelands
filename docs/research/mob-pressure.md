# Mob pressure — what shipped (2026-09-16)

Implementation note for the round-4 mob-pressure lane. The task card that
planned this work is
[`mob-pressure-task-card.md`](mob-pressure-task-card.md); it was written at
`70dda602` and every line number it cites was re-verified against this lane's
base `dfb32cd5` before any code moved — **all of them still held**.

Four things landed, in this order: the movement aggregator, the attack-cadence
patch, the ranged family, and the speed raise. The speed raise is one separate
commit on purpose, so it can be dropped without touching anything else.

Every number below is followed by the command that produces it. Anything not
measured says so.

---

## 1. The movement aggregator (task card §4b, `skill_trees.md` §3.9)

**Ruling 11 (user, 2026-09-16), verbatim:** "effects overlap freely with
independent durations; the design is **one central aggregator in
`grug_core`** where each system registers a **named modifier with its own
duration**; a **root is a hard flag** (speed 0 regardless of modifiers), never
a '−1000 %'; **mounts stay outside** the aggregator."

**Ruling 26, verbatim:** "The movement aggregator combines additively, per
axis, with one clamp. `clamp(1 + Σ, 0.1, 1.5)` for speed and for jump; a root
or an exclusive hold takes precedence over the sum."

`mods/CORE/grug_core/movement.lua` is that aggregator, and it is now the only
writer of `physics_override` in the game.

```sh
grep -rn "set_physics_override" mods/
```

| | call sites | writers |
|---|---|---|
| before | 7 (plus one comment) | 3 — `grug_mobs/verbs.lua`, `grug_abilities/kits.lua`, `grug_classes/selection.lua` |
| after | **1** | **1** — `grug_core/movement.lua:194` |

The third writer is the one both `verbs.lua:100-118` and `mounts.md`/
`boats.md` missed when they said "two owners", and it was the worst of the
three: `release_player` restored a **snapshot** taken when character creation
began, so a slow running at that moment was written back permanently, long
after the effect had expired. That snapshot is gone; releasing the exclusive
hold hands the player back to whatever the aggregator says at that moment.

### The API, for the consumers that arrive later

WP11's Sprint, Hold Ground, Shake Loose, Tendon Cut and Pinning Shot are
specified against this seam (`skill_trees.md` §3.9) and none of them exists
yet. The surface is deliberately small and is **stable**:

```lua
grug_core.set_move_modifier(player, name, {speed = d, jump = d}, duration)
grug_core.clear_move_modifier(player, name)
grug_core.get_move_modifier(player, name)   -- {speed, jump, remaining} or nil
grug_core.set_root(player, duration)        -- hard flag; false while immune
grug_core.clear_root(player)
grug_core.set_move_immunity(player, duration)
grug_core.clear_move_immunity(player)
grug_core.hold_movement(player, name)       -- exclusive, counted, untimed
grug_core.release_movement(player, name)
grug_core.is_movement_held(player [, name])
grug_core.get_move_state(player)            -- {speed, jump, rooted, immune, held, modifiers}
grug_core.clear_movement(player)
grug_core.reassert_movement(player)         -- re-write against the live override
```

Things a consumer needs to know and cannot guess:

- **Deltas, not multipliers.** `{speed = -0.40}` is "40 % slower",
  `{speed = 0.25}` is Sprint's "+25 %". A missing axis is 0. Callers whose
  design numbers are absolute (`kits.lua`'s stages are `speed = 0.1`) convert
  with `value - 1`, as the applier there does.
- **The name is the identity.** Re-registering a name replaces that entry
  (a refresh); two different names overlap and add. A family that wants
  "stronger and longer wins" implements that policy in its own file, not in
  the aggregator — `grug_mobs.slow_player` is the worked example, and
  `get_move_modifier` exists for exactly that.
- **A second `set_root` keeps the LATER expiry** (coordinator decision,
  2026-09-16, after the round-4 review). `rec.root = math.max(rec.root or 0,
  now + duration)`: a 1 s root cast onto a running 5 s root leaves 5 s, and a
  4 s root onto a running 1 s root extends it to 4. The root carries **no
  name** on purpose — it is one flag, not a set — so "the longest wins" is the
  only rule that can give the guarantee the staged `kits.lua` chain used to
  give by hand, "a Hamstring must not lift an ally's Frost Nova root".
  `clear_root` still lifts it outright, and immunity still discards it. This
  is the rule WP11's Tendon Cut and Pinning Shot land on.
- **Durations are seconds from the call**, expiry is evaluated on
  `grug_core.mono_time()` at use time. There is no `core.after` chain to
  orphan and no generation counter; a relog drops the whole record.
- **Immunity discards roots and negatives, keeps positives.** A root is
  refused (`set_root` returns `false`) and a running one is dropped; negative
  modifier deltas are skipped in the sum while it lasts but still expire on
  their own clock, so a 3 s immunity cannot swallow a 7 s web.
- **A hold outranks a root, and holds are counted.** An unbalanced release
  can never free a player another holder is still freezing.
- **Gravity is not an axis.** Only the exclusive hold touches it (0 while
  held, exactly 1 when released), because the only gravity writer the game
  ever had was the creation freeze.
- **Mounts and boats stay outside**, exactly as ruling 11 says: their speed is
  the mount/boat entity's velocity (`mounts.md` §3, `boats.md` §5).
- **Mobs are not players.** Mob roots and slows keep their own reload-safe
  countdowns in `grug_mobs` (`grug_mobs.root`/`slow`), ticked inside
  `do_custom` because a mob can unload mid-timer.
- **A read is free and a steady state is silent.** `get_move_state`,
  `is_movement_held` and `get_move_modifier` never create a record, so a
  per-step HUD consumer asking about a player with no effects costs nothing
  and leaves nothing behind; the engine write is skipped whenever the resolved
  speed, jump *and* gravity equal what was last written, so an exclusive hold
  writes once when it starts and once when it releases rather than once per
  throttled step. Both are asserted in the KAT's write-economy section, and
  both were review findings (6 and 7).

### What the migrations preserved, exactly

| effect | before | after |
|---|---|---|
| spider web | `{speed = 0.6}`, restored to 1 by a `core.after` chain | modifier `mob_web`, `{speed = -0.4}`, same stronger-and-longer merge |
| Frost Nova stage 1 | `{speed = 0.1, jump = 0.3}` for 4 s | modifier `frost_nova`, `{speed = -0.9, jump = -0.7}`, 4 s |
| Frost Nova stage 2 | `{speed = 0.5, jump = 1}` for the next 3 s | modifier `frost_nova_2`, `{speed = -0.5}`, **7 s** (overlapping) |
| Hamstring | `{speed = 0.5}` for 5 s | modifier `hamstring`, `{speed = -0.5}`, 5 s |
| creation freeze | `{speed = 0, jump = 0, gravity = 0}` + snapshot restore | `hold_movement(player, "class_creation")`, no snapshot |

The overlap is what keeps Frost Nova's shipped numbers: during the first 4 s
the sum is `1 − 0.9 − 0.5 = −0.4`, clamped to the floor **0.1**, and jump is
`1 − 0.7 = 0.3`; from 4 s to 7 s only stage 2 remains, so speed is **0.5** and
jump **1**. Both are what the old chain wrote.

The "a stronger snare stage is running, keep it" guard is gone with the chain,
and nothing is lost: a Hamstring cast into a running Frost Nova now *adds*
−0.5 to a sum already clamped at the floor, so it still cannot lift an ally's
root.

### KAT

```sh
luajit          -e 'io.write(dofile("tools/wp11/move_aggregator_kat.lua")("."))'
tools/bin/lua51 -e 'io.write(dofile("tools/wp11/move_aggregator_kat.lua")("."))'
```

Both interpreters, byte-identical:

```
baseline	1	1	writes	0
additive	0.85	1
clamp	low	0.1	high	1.5
expiry	independent	ok
root	hard_flag	ok
immunity	discards_root_and_negatives	ok
hold	exclusive_counted_no_snapshot	ok
lifecycle	join_leave_reset	ok
callers	web_frost_nova_hamstring	ok
writes	one_per_change	2
wp11_move_aggregator	PASS	mutation	0
```

It loads the real `movement.lua` and the real `verbs.lua` against a stub
engine with a controllable clock, and it asserts the `kits.lua` applier's
arithmetic against that file's own text, so an edit to either breaks it.
Three mutations, each of which must go red:

| `MUTATION=` | what it breaks | the assertion that catches it |
|---|---|---|
| 1 | multiplicative combination | `web -40% + sprint +25% is additive: expected 0.85, got 0.35` |
| 2 | root written as a −1000 % modifier | `a root is speed 0 regardless of modifiers: expected 0, got 0.1` |
| 3 | snapshot restore left in the hold | `one holder released, the other still holds: expected 0, got 0.6` |
| 4 | a second `set_root` replacing instead of keeping the later expiry | `a 1 s root cut a running 5 s root short; a second root must keep the later expiry: expected 0, got 1.5` |

The write-economy section bites on its own too: reverting only the
gravity-aware skip makes it report `a running hold wrote 10 unchanged
override(s) over ten steps`, and reverting only the read-only `peek` makes it
report `reading a clean player's state caused 5 engine write(s)`.

**No runtime test is owed for the aggregator itself** — it is pure Lua with no
engine dependency, and the KAT carries it. The *migrations* do owe one,
because they change how every slow in the game feels; that is in the playtest
list below, and a headless server cannot answer it because it has no player.

---

## 2. The attack cadence (task card §2, `combat_stats.md` §4)

**Ruling 1 (user, 2026-09-16):** melee mobs must deal damage **immediately**
when their attack is ready and the target is in reach; walking backwards must
no longer avoid all damage.

This was already decided design. `combat_stats.md` §4 "Catching up must be
enough to hit" settled it on **2026-08-13** and even diagnosed the defect; the
patch was never written.

Three GRUG PATCH markers in `mods/ENTITIES/mobs/api.lua`, 40 → 43
(`grep -c "GRUG PATCH" mods/ENTITIES/mobs/api.lua`):

1. **`:2368-2403`** — `punch_timer` accumulates at the top of the dogfight
   branch, above the `dist > reach` test, on every tick with a live target.
   The backlog is capped at one `punch_interval`, the rule the player's own
   swing clock already follows (`combat_stats.md:153`).
2. **`:2535-2564`** — the in-reach branch no longer zeroes the velocity
   unconditionally. The mob runs down to a contact distance of
   `reach × 0.6` and stops there.
3. **`:2567-2618`** — the punch sits outside both branches and carries the
   in-reach and line-of-sight tests at the site of the punch. A cadence that
   comes due out of reach is **not** reset, so the hit lands on the first tick
   reach is regained. Everything from the timer reset down is upstream's own
   body, moved verbatim.

`reach` is untouched, for the three reasons the decided text gives: it cannot
repair the defect, it widens the elite/rare telegraph cone (`reach + 1.5`) and
it makes `dogshoot` mobs switch to melee earlier.

**One consequence worth naming.** `punch_timer` is never cleared outside the
punch, so the banked swing survives not only a chase but a wall, a lost target
and a target switch: **every re-engagement opens with an immediate hit.** The
cap keeps that at exactly one hit however long the interruption lasted, and it
is the literal reading of ruling 1 — "damage IMMEDIATELY when the attack is
ready and the target is in reach" — but it means a mob you break away from and
then meet again does not give you a free second.

**Why a fixed contact distance and not "keep running while the distance is
increasing".** The card offers both. A per-tick distance derivative oscillates
once per server step against a target only marginally slower than the mob —
the mob would stop on every closing tick and run on every receding one,
halving its effective speed to below the player's. A fixed contact distance
settles instead: the mob ends up hovering just inside it, which is well inside
`reach`.

### The runtime test the decided text demands

> "because it changes every mob's feel, the WP that ships it owes a runtime
> test" — `combat_stats.md` §4

```sh
git show <base>:mods/ENTITIES/mobs/api.lua > /tmp/api.before.lua
PORT=31201 TIMEOUT=420 nice -n 19 \
  bash tools/wp11/run_cadence_probe.sh /tmp/out /tmp/api.before.lua 15912857179583385436
```

One boar (level 1, `reach` 2, `punch_interval` 1, `damage` 2.4), one target
entity, on a built stone platform in forceloaded blocks; 10 s per scenario at
the dedicated-server step of 0.09 s (111 steps, `dtime_max` 0.091 in every
window). **Punches per 10 s:**

| scenario | before | after |
|---|---|---|
| target receding at walk speed 4.0 | **1** | **10** |
| target standing still (the control) | **10** | **10** |

and the mob-to-target gap:

| scenario | before | after |
|---|---|---|
| receding | 2.34 – 2.70 m — **outside its reach of 2** | 1.50 – 1.85 m |
| standing | 1.68 m | 0.95 m |

That "1 per 10 s" is the figure `combat_stats.md` §4 worked out from the
server step and explicitly labelled *"the shape of the defect rather than a
measurement"*. It is now a measurement, and the gap column is why: before the
patch the mob sat just **outside** its own reach for the whole chase.

The control is the important half — the standing rate did not move.

**The runner takes both columns without touching the repository.** It builds
two throwaway mirrors of the game under `/tmp` and swaps only `api.lua` in the
"before" one; the repo is read and never written. Timing: ~110 s per boot, of
which ~55 s is `grug_core`'s six-start preload (the probe waits for it, because
a measurement taken while the emerge queue is saturated measures the emerge
thread).

**Recorded twice**, once with the aggressive band at 4.4 and once on the
shipped tree with it at 4.6, so the speed commit's contribution is visible on
its own (`tools/wp11/evidence/20260916-mob-pressure/engine/`). The answer is
that it has none, and this is the single most useful number this lane
produced:

| `run_velocity` | before, receding | after, receding | before, standing | after, standing |
|---|---|---|---|---|
| 4.4 | 1 | 10 | 10 | 10 |
| **4.6** | **1** | **10** | 10 | 10 |

**A faster mob does not repair ruling 1 and a patched mob does not need the
extra speed to satisfy it.** The defect is structural, exactly as
`combat_stats.md` §4 argued: a mob that stops the instant its target is inside
reach leaves its own radius whatever its speed, so at 4.6 it still landed one
hit in ten seconds. That is the measured case for treating the speed raise as
a separate, droppable question about how dangerous the game should feel — not
as part of the fix.

**What a headless server cannot show, and the playtest must:** the target is
an entity, not a player, so the player-specific half of `do_states`
(`is_invisible`, the mounted-rider `get_attach`) never runs, and the target is
moved by the probe rather than by real player input with jumping and
collision. **Whether the fight now feels right is the user's playtest, not
this number.**

### Pure-function KAT

```sh
luajit          -e 'io.write(dofile("tools/wp11/mob_cadence_kat.lua")("."))'
tools/bin/lua51 -e 'io.write(dofile("tools/wp11/mob_cadence_kat.lua")("."))'
```

```
api_fragments	accumulator_above_reach_test	cap	reach_gate	contact_distance
standing_10s	before	9	after	9	step	0.09	interval	1	effective	1.08
receding_10s	before	0	after	9	worst_gap	2.000	reach	2
backlog	chase_10s_then_arrive	1
no_reset_out_of_reach	ok
wp11_mob_cadence	PASS	mutation	0
```

It reads the real `api.lua` and asserts the three fragments are where they
must be (the accumulator **above** the in-reach test, exactly one accumulator
in the file, the cap, the reach gate on the punch, exactly one
`set_velocity(0)` in the in-reach branch), then replays the arithmetic for
both the upstream and the patched rules. The simulated 9-per-10-s rather than
10 is honest: a landed punch resets the timer to 0 and discards the overshoot
(upstream's arithmetic, kept), so at a 0.09 s step the effective interval is
`ceil(1 / 0.09) × 0.09 = 1.08 s`. Mutations: `=1` reverts both halves of the
patch, `=2` removes the backlog cap, `=3` resets the timer when the cadence
comes due out of reach — each goes red.

### Line-number repairs that travelled with it

The coordinates in the following historical correction note refer to commit
`77261837` (2026-09-15), the pre-patch vendored input.

- `combat_stats.md` §4's own `api.lua:2493` / `:2495-2497` / `:3768` had
  drifted by five lines even before this patch; the paragraph now states the
  pre-patch numbers correctly **and** where the fix lives in the patched tree.
- The stale `api.lua:2249` citation the card found in `golem.lua:67` and
  `skeleton_archer.lua:65` was corrected to the then-current line. The current
  melee switch is at `api.lua:2492`. **The card missed a
  third**, `skeleton_raider.lua:37`, which carried the same number; it is
  corrected too.

---

## 3. Speed (task card §3, user ruling 2) — the droppable commit

**This whole section documents one commit, "Raise the aggressive band to 4.6",
which is the last on this branch. If the playtest says the cadence fix alone
is enough, drop that commit and strike this section with it — nothing else in
this note, in the code or in the evidence depends on it, and the two share no
file.**

The roster was **already at spec**: `combat_stats.md` §3 specified 4.4 and all
13 definition sites carried it (`grep -rn "run_velocity" mods/ENTITIES/grug_mobs/`).
"A bit faster" is therefore a change to the spec.

`run_velocity` by value, after:

| value | sites | who |
|---|---|---|
| 5.0 | 1 | kraken |
| **4.6** | **15** | the 13 former-4.4 families plus panther and crag eagle/vulture |
| 4.2 | 1 | zombie |
| 4.0 | 3 | skeleton archer, skeleton raider, **bandit archer** |
| 3.4 | 11 | the critters |
| 3.0 | 1 | golem |
| 2.6 | 1 | bog ooze |
| 1.1 / 0 | 2 | start villagers |

Nothing new was introduced: 4.6 is the value two heartland hunters already
used, so the aggressive band and the hunters collapse into one number.

**The measured argument for dropping this commit.** The card recommends
measuring before moving the speed. §2's table has both halves of the answer:
the cadence patch alone takes landed hits on a fleeing target from 1 to 10 per
10 s, and the speed raise on its own changes that number by **nothing** — an
unpatched mob at 4.6 still lands 1 per 10 s. Ruling 1 may therefore be the
whole of "mobs should be more dangerous", and unlike ruling 2 it costs no
pillar.

**The Mage, with numbers.** `classes.md`: "Frost Nova became the rotation
pivot — kiting IS the Mage fantasy here". One Frost Nova is a 4 s root then a
3 s 50 % slow (`kits.lua`, ability `frost_nova`):

| | 4.4 | 4.6 |
|---|---|---|
| lead gained during the 4 s root | 16.0 m | 16.0 m |
| lead gained during the 3 s slow | 3 × (4.0 − 2.2) = 5.4 m | 3 × (4.0 − 2.3) = 5.1 m |
| **total lead per cast** | **21.4 m** | **21.1 m** |
| the mob closes it again at | 0.4 m/s | 0.6 m/s |
| **time to lose the lead** | **~53 s** | **~35 s** |

So the lead is unchanged and the time to keep it falls by a third. The 25 m
soft de-aggro was never reachable on one cast and still is not; two casts
inside one cooldown window are still what reaches it. **This is arithmetic
from the shipped durations, not a playtest result** — it is the first thing
the user should feel for.

Everything that states the inequality moved in the same commit:
`combat_stats.md` §3, `mounts.md` §1.1 and §3.1, `items_crafting.md` §10 P4
(4.0 × 1.08 = 4.32, now 0.28 below a mob instead of 0.08 — the Swiftness
Draught got *safer*), `biomes_mobs.md` §0 and all eleven Speed cells of §3.1,
and seven code comments.

---

## 4. Ranged mobs (task card §4, user ruling 3)

**Measured before:** four registered ranged mobs of 43, from three definition
sites, and every one in the outer ring or on the war coast — a player met no
ranged enemy at all below roughly level 25.

**The rule, now written down** in `biomes_mobs.md` §3.1 and
`combat_stats.md` §3: a `dogshoot` family sees **16 m**, a melee family
**10–14 m by habitat**, and **16 is the ceiling for a land mob** because §4's
45 m chase give-up and 40 m leash both need a mob to keep a target it can no
longer see. The stone/mesa golem was the one ranged family that did not follow
its own rule and moved **14 → 16**. The aquatic Kraken's 20 keeps its
documented exemption.

**The new family: the Bandit Archer.** `grug_mobs:bandit_archer`, built from
`grug_mobs.bandit_def()` so it can never drift from the brawler on leash
range, loot or level source. It differs in exactly four things — `dogshoot`
with the skeleton archer's arrow entity, `view_range` 16, 4.0 walk-and-run
("an archer keeps its distance"), and the bandit's drop table plus arrows 1/3.
No new art: the same `character.b3d` people, the same skins, the same arrow.

**It costs no spawn budget.** It has no `mobs:spawn` row — the bandit camp
already has none — and instead joins the camp's slot roll at **1 in 3**
(`camps.lua`, new `variant`/`variant_chance`). Both families count against the
one head count, which is what stops a camp growing.

**After, measured on a headless boot** (`tools/wp11/ranged_probe`, staged with
`PROBE=` into a throwaway game copy):

```
roster registered=55 dogfight=42 dogshoot=5 none=8
roster rule_ok dogshoot=16 melee<=16 exempt=grug_mobs:kraken (aquatic, own open-sea leash)
camp mob=grug_mobs:bandit variant=grug_mobs:bandit_archer variant_chance=3 count=3-5 radius=12
ranged archer=grug_mobs:bandit_archer level=1 damage=2.4 attack_type=dogshoot
      view_range=16 shoot_interval=2.5 window_s=15.07 arrows=3 hits=3 final_dist=0.81
```

Five registered ranged mobs of 44 (`grep -rn 'grug_mobs.register_mob("'
mods/ENTITIES/grug_mobs/*.lua | wc -l` = 44; the 55 above counts every
registered `grug_mobs` entity including the twelve villagers and elders, whose
`attack_type` is `none`). Three arrows for three hits in a 15 s window at
12 m is what `shoot_interval` 2.5 and mobs_redo's own 60 % shot roll predict;
`final_dist=0.81` is `dogswitch` doing its job — 10 s of shooting, then the
melee phase closes.

**The camp's own refill was not exercised**, and that is the engine rather
than a gap: `camp_tick` returns early unless a player is within
`PLAYER_RANGE`, and a headless server has no player. What the slot roll does
with the config is arithmetic; the config is what the probe checks.

**Not taken:** the mirefolk spitter and the harpy/crow the card lists as
optional second and third candidates, and the `dogshoot_switch` /
`dogshoot_count_max` tuning the card calls "a second knob, already present".

---

## 5. What the review should look at

1. **The aggregator's precedence order** (`combine` in `movement.lua`):
   hold > root > clamped sum, and immunity acting *inside* the sum rather than
   above it. That is the reading of rulings 11 and 26 this lane committed to;
   a different reading would put immunity above the root, which is the same
   thing only because `set_move_immunity` also clears the root.
2. **The contact distance `reach × 0.6`.** It is a tuning constant this lane
   chose, not a decided number. It is the only free parameter the cadence
   patch introduces, and it is what keeps a standing mob's rate unchanged.
   `reach` is 2 for 20 of 22 families, so it is 1.2 m almost everywhere.
3. **`grug_mobs.slow_player`'s merge now reads through the aggregator**
   (`get_move_modifier`) instead of a private table. That is one engine-free
   read per web application, and it is the only place a caller's stacking
   policy sits outside the aggregator.
4. **The removed snapshot in `selection.lua`.** The WP45 regression asserted
   the old behaviour and was re-taken in its own commit
   (`tools/wp45/character_creation_test.lua`); that file belongs to no lane.
5. **The in-reach run branch has no `at_cliff` guard** (review finding 8),
   while the chase branch it mirrors does. `on_step`'s own cliff stop runs
   every 0.25 s and *before* `do_states` in the same step, so `do_states`
   overwrites it: a mob 1.2–2.8 m from a target on a ledge can now run off it
   where upstream stood still. `fear_height` and fall damage absorb it, so it
   is cosmetic-to-annoying rather than a break, and it was left alone
   deliberately — adding the guard would re-introduce exactly the standstill
   the patch removes whenever `at_cliff` fires on flat ground near a target.
   Worth a playtest look and a decision of its own.
6. **`bandit.lua` became a builder.** The registration is
   `grug_mobs.register_mob("grug_mobs:bandit", grug_mobs.bandit_def("Bandit"))`
   and every caller gets a fresh table.

## 6. What is open

- **The `api.lua` citation corpus is stale, tree-wide, and not this lane's to
  repair.** `mods/ENTITIES/grug_mobs/` carries well over a hundred
  `api.lua:NNNN` citations and a spot check against the **pre-patch** file
  shows many were already wrong (`:2913` and `:3444` were both `end`, `:2431`
  was `yaw_to_pos`, `:2779` was blank). This lane corrected only the three the
  card named. The cadence patch shifts everything after `:2367` by up to 68
  lines, so the drift is now larger; repairing it is a mechanical job of its
  own.
- **The Kraken Guard's speed is a recorded gap, not a new one.**
  `combat_stats.md` §3 says 8.8 and `kraken.lua:54` ships 5, and
  `biomes_mobs.md` §1109 already says so outright ("`run_velocity` 8.8
  (shipped: 5)"). The brief for this lane pinned the kraken at 5.0, so it was
  left alone.
- **The aggregator has no consumer for `set_move_immunity` yet.** It exists
  because WP11's Hold Ground and Shake Loose are specified against it; nothing
  calls it, so only the KAT exercises it. The same is true of `set_root`,
  which is why its "longest wins" rule above was decided before a caller
  exists rather than after.
- **An expiry reaches the ENGINE up to one `STEP_INTERVAL` plus one server
  step late** (measured by the review at 0.54 s for a 0.5 s modifier at a
  0.09 s step). The logic is never late — every read prunes at use time — but
  a future effect shorter than ~0.2 s would want a smaller `STEP_INTERVAL`.
- **The speed raise is unmeasured as a change in feel.** §3's table is
  arithmetic from shipped durations.
- The card's optional ranged candidates and the `dogshoot` ratio knob.
- **Three suites are red on main `ba831caf` itself and this lane did not
  break them** — `wp45/character_creation_test.lua` (Lane W1's `/class`
  removal against a test that still calls the command),
  `wp39/combat_integration_test.lua` (Lane H's HUD reads
  `grug_core.hud_layout`, which that test's stub lacks) and
  `wp39/projectile_test.lua` (Lane W1's rage tuning against `kits.lua`'s
  description string reading `RAGE_PER_SWING`). Swapping this branch's four
  files for main's own reproduces all three; the A/B is in the evidence
  README. They belong to the lanes that made those changes.
- **Review finding 8, left as shipped:** the in-reach run branch has no
  `at_cliff` guard, so a mob 1.2–2.8 m from a target on a ledge can run off
  it. See §5 item 5 for why adding the guard is not obviously right.

## 7. What the user should playtest, in a FRESH world

1. **Walk backwards away from a boar, a wolf or a bandit while it chases
   you.** Before this round that was free; it should now cost roughly one hit
   per second, the same rate as standing still and trading. This is the whole
   of ruling 1 and the one thing the headless number cannot confirm.
2. **Stand still and let a mob hit you.** The rate must feel exactly as it did
   before. If standing now takes *more* hits than it used to, the contact
   distance is wrong.
3. **Is it too much?** Ten hits per ten seconds from a fleeing chase is a
   tenfold rise. If a low-level fight now feels unwinnable, the speed commit
   (`Raise the aggressive band to 4.6`) is the one to drop, and it can be
   dropped on its own.
4. **Play the Mage.** Frost Nova, run, and see whether you still break contact
   before the nova is back up. §3's arithmetic says the window shrank from
   ~53 s to ~35 s. If kiting stops working, that is the speed commit again.
5. **Get hit by a giant spider's web while a Hamstring or a Frost Nova is on
   you**, and check that the first one to end does not lift the other. That is
   the bug the aggregator exists to end, and only a second player or a PvP
   duel can produce the overlap.
6. **Make a new character.** After the last creation dialog you must be able
   to move normally and jump normally — the freeze now releases to the
   aggregator's baseline rather than to a snapshot.
7. **Find a bandit camp in the inner ring.** Roughly one member in three
   should be an archer that shoots you from about 16 m before the brawlers
   reach you, and closes to melee when you get near. It carries a dagger, not
   a bow: there is no bow weapon family yet (`items_crafting.md` §9 has it as
   Phase-2 work), and that is cosmetic.
8. **Fight a stone or mesa golem.** It should open fire two nodes earlier than
   it used to.

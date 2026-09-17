# Mob pressure — task card (2026-09-16)

> **STATUS 2026-09-17 — ROUND-5 FOLLOW-UP.** The current melee floor is
> **4.6** for every attacker except the explicitly slow-tank Bog Ooze
> (**2.6**); archers remain **4.0**, harmless critters **3.4**, and the Kraken
> **5.0**. Player and ordinary mob melee reach are now both **3 m**. A blocked
> close target starts bounded A* after about **1 s**, retains its path while
> LOS is blocked, and gets an alternating **0.5 s** sidestep when no path is
> found; cover no longer spends the banked swing. Ordinary hits have zero
> implicit knockback, and players/mobs/NPCs no longer collide with objects.
> Current implementation references: `grug_abilities/kits.lua:284,344,381`;
> `grug_mobs/stag.lua:21`, `ram.lua:26`, `zebra.lua:20`,
> `carrion_crow.lua:54`, `zombie.lua:29`, `golem.lua:87`,
> `bog_ooze.lua:38`, `kraken.lua:54`; and
> `mobs/api.lua:103-104,2321-2330,2512,2644-2646,2695-2699,3352-3356,3840`.

**Historical snapshot qualifier:** every `mobs/api.lua:<line>` and shorthand
`api.lua:<line>` coordinate in this task card refers to commit `77261837`
(2026-09-15), the frozen vendored input the card audited.
> The older status and card below remain the historical round-4 record.
>
> **STATUS 2026-09-16 — SHIPPED.** This card was executed by the round-4
> mob-pressure lane. What landed, and where to read it:
> [`docs/research/mob-pressure.md`](mob-pressure.md) is the implementation
> note with every measurement and its command. §4b's aggregator is
> `mods/CORE/grug_core/movement.lua` and `grep -rn set_physics_override mods/`
> now finds one call site. §2's cadence patch is three GRUG PATCH markers in
> `mods/ENTITIES/mobs/api.lua` (40 → 43), and the runtime test it owes was
> taken: punches per 10 s against a target receding at walk speed go from
> **1 to 10**, against a standing target stay at **10**. §3's speed raise
> 4.4 → 4.6 landed at all 13 sites as **one separate commit**, so it can be
> dropped if the user's playtest says the cadence fix alone is enough. §4's
> view-range rule is written into `biomes_mobs.md` §3.1 and
> `combat_stats.md` §3, the golem moved 14 → 16, and the **Bandit Archer**
> is the new ranged family — 5 registered ranged mobs of 44, and the first
> one a player meets in the inner ring. The mirefolk spitter and the
> harpy/crow of §4.2 were not taken.
>
> Everything below is the card as written before the work, kept as the
> record of what was measured at `70dda602`; every line number it cites was
> re-verified against `dfb32cd5` and all of them still held.

**A task card, not an implementation.** No code was written, no engine was
run. Written by the WP11 skill-tree lane because the Scout's kiting and
stealth read on top of it ([`docs/design/scout.md`](../design/scout.md) §6.3),
but it is **not part of WP11** and belongs to a later lane of its own.

Every number below is either measured in this tree at `70dda602` or quoted
from a decided design file, and says which.

---

## 1. The user's rulings (2026-09-16)

1. **Melee mobs must deal damage IMMEDIATELY** when (a) their attack is ready
   **and** (b) they are within reach. Today a player avoids all melee damage
   by walking backwards.
2. **Mobs should be a bit faster.**
3. **More ranged mobs**, with a **larger view range than melee mobs**, so
   ranged players and the Mage take damage sooner.

---

## 2. Ruling 1 is already decided design that was never implemented

This is the important finding of the card: ruling 1 does not need a design
decision. `combat_stats.md` §4 (`:467-490` on this branch, which is `:461-484`
on `main` — this lane's own `combat_stats.md` commit adds six lines above it)
already decided it on **2026-08-13**, in detail, and even diagnosed the
defect:

> **Catching up must be enough to hit** (decided 2026-08-13): a mob that has
> closed to within its `reach` lands its attacks on a target fleeing at full
> speed. The **attack cadence therefore runs during the chase**, not only
> while the target is inside reach; the only condition an attack still carries
> is being in reach at the moment the cadence is due. Fleeing costs HP — it is
> not a free escape from a fight already lost.
>
> *Rationale, because the defect is invisible on paper*: vendored mobs_redo
> zeroes the mob's velocity as soon as the target is inside `reach`
> (`mods/ENTITIES/mobs/api.lua:2493`) while `punch_timer` accumulates **only
> in that same branch** (`:2495-2497`; default interval 1 s at `:3768`). A
> receding target leaves reach after one server step, so the timer gains one
> step while the mob loses the ground the target covered in it. Worked at the
> **dedicated-server default** `dedicated_server_step = 0.09`
> (`reference_projects/luanti/src/defaultsettings.cpp:498`; the setting is
> configurable and a singleplayer session does not use it, **so this is the
> shape of the defect rather than a measurement**): the timer gains 0.09 s
> while the mob loses ~0.36 m that it needs ~0.9 s to re-close at its
> 0.4 nodes/s margin — roughly
> **one landed hit per ten seconds** instead of one per second. Raising
> `reach` cannot repair this (a stopped mob always leaves its own radius,
> whatever the radius) and would silently widen the elite/rare telegraph cone,
> which is `reach + 1.5` (§3), and make `dogshoot` mobs switch to melee
> earlier. **The fix is one vendored api.lua patch; because it changes every
> mob's feel, the WP that ships it owes a runtime test.**

**The line numbers in that quote had drifted** and the card originally
corrected them against `70dda602`. The right-hand coordinates below were
refreshed against the current patched tree on 2026-09-17:

| Historical coordinate | Current patched tree | What is there |
|---|---|---|
| `api.lua:2493` | **`api.lua:2679-2725`** | the in-reach branch and its bounded contact movement |
| `api.lua:2495-2497` | **`api.lua:2524-2527`** | `self.punch_timer = (self.punch_timer or 0) + dtime` and its one-hit cap |
| `api.lua:3768` | **`api.lua:4087`** | `punch_interval = def.punch_interval or 1` |

The structure, verified line by line:

- `api.lua:2620` — `if dist > (self.reach + (self.reach_ext or 0)) then` opens
  the **chase** branch (path-finding, `set_velocity(self.run_velocity)` at
  `:2668`, walk speed instead beyond 25 m at `:2650-2666`).
- `api.lua:2679` — `else -- rnd: if inside reach range` opens the **attack**
  branch.
- `api.lua:2524` — `self.punch_timer = (self.punch_timer or 0) + dtime`. The
  cadence now advances before both distance branches.
- `api.lua:2526-2527` caps the cadence at one ready hit.
- `api.lua:2690-2725` keeps closing to contact instead of freezing throughout
  the in-reach branch, while retaining the cliff guard.
- `api.lua:2788-2819` tests readiness, range and canonical target visibility,
  then consumes the cadence only after an accepted attempt.
- `api.lua:2810-2813` — `target:punch(self.object, 1.0, {…
  damage_groups = {[dgroup] = self.damage}}, nil)` — the hit lands. Note
  `local target = self.attack:get_attach() or self.attack` at `:2808`: a
  mounted player's **mount** eats the swing, which `mounts.md:162-171`
  already relies on.

The shipped fix separates the cadence at `api.lua:2524-2527` from contact
movement and settlement at `:2690-2819`. Reach is uniform in the roster:
measured, **20 of 22 `reach` values are 2**, the Kraken is 4 with a comment
explaining why, and one is 0. `punch_interval` is the mobs_redo default of 1 s
for every grug mob — no definition sets it.

### The fix, described

1. **Move the cadence out of the branch.** `punch_timer` accumulates on every
   dogfight tick with a live target, chase branch included. That is
   `combat_stats.md`'s "the attack cadence therefore runs during the chase"
   read literally.
2. **Keep the in-reach test where the punch lands, not where the clock runs.**
   When the timer is due, test `dist <= reach + reach_ext` and LOS at that
   moment: in reach → punch and reset; out of reach → do **not** reset (or the
   defect returns in a new shape), and do not bank more than one attack.
3. **Do not zero the velocity for the whole in-reach branch.** A mob standing
   still inside reach of a receding target is what loses the ground. Either
   keep running while the target's distance is increasing, or zero the
   velocity only for the frames the punch animation needs.
4. **Cap the backlog at one.** The same rule the player's own swing clock
   already uses (`combat_stats.md:153`: "lag never replays a backlog").
5. **Do not raise `reach`.** The decided text explains why: it cannot repair
   the defect, it widens the elite/rare telegraph cone (`reach + 1.5`,
   `combat_stats.md:338`) and it makes `dogshoot` mobs switch to melee
   earlier — that last one is **`api.lua:2492`**
   (`and (ds_var == 2 or dist <= self.reach)`), not the `api.lua:2249` that
   `golem.lua:67`'s comment cites. That stale citation has drifted too, and
   the **same** one also sits in `skeleton_archer.lua:65` — the patch should
   correct both.

### What it costs

One GRUG PATCH in the vendored `mods/ENTITIES/mobs/api.lua`, next to the 40
that already live there (`grep -c "GRUG PATCH" mods/ENTITIES/mobs/api.lua`
= **40**). It changes **every mob's feel**, so the lane that ships it owes a
runtime test on a headless server, exactly as the decided text says, and a KAT
is not enough.

---

## 3. Ruling 2 — mob speed

### Measured, by definition site

`grep run_velocity mods/ENTITIES/grug_mobs/`, counting definition sites (some
files define one shared table for two registered mobs):

| `run_velocity` | Sites | Who |
|---|---|---|
| 5.0 | 1 | kraken ("must outswim a player") |
| 4.6 | 2 | panther, crag eagle/vulture ("heartland hunters") |
| **4.4** | **13** | boar, boar variants, hyena, jungle lynx, bandit, serpent, wolf, bear, mirefolk, jungle ape, spider, crocodile, guard |
| 4.2 | 1 | zombie |
| 4.0 | 2 | skeleton archer, skeleton raider |
| **3.4** | **11** | ram, parrot, cave crawler, bog fowl, stag, rabbit, bone weevil, gull, cave bat, carrion crow, zebra |
| 3.0 | 1 | golem |
| 2.6 | 1 | bog ooze |
| 1.1 / 0 | 2 | start villagers (not combat mobs) |

**43** mobs are registered through `grug_mobs.register_mob` (counted as
`grug_mobs.register_mob("` call sites; a looser grep also catches the wrapper's
own internal `mobs:register_mob` at `grug_mobs/init.lua:559` and
`start_villagers.lua`'s
two direct loops, which is why §6's command over-counts to 47). The player
walks at
**4.0** (`mounts.md:50-51`, engine default `movement_speed_walk = 4`).

This matches the design: `combat_stats.md:310-315` specifies "aggressive mobs
`run_velocity` **4.4** (player: 4.0) — evading must never be trivially easy;
harmless critters 3.4; heartland hunters 4.6". **The roster is already at
spec.** "A bit faster" is therefore a request to change the spec, not to fix a
deviation.

### The constraint the change runs into

The 4.4-against-4.0 inequality is not a mob tuning value; it is the number
three other systems are built on. `mounts.md:173-190` states it outright:

> `combat_stats.md` §3 gives aggressive mobs `run_velocity` **4.4** against a
> player's **4.0** — "evading must never be trivially easy" — and the whole mob
> game is built on top of that one inequality: the **25 m soft de-aggro**
> […] and the **45 m chase give-up** and **40 m leash** […] all assume the mob
> can close the distance.

The same paragraph is why the **Swiftness Draught** is +8 % for 15 s
(`items_crafting.md` §10 P4: `4.0 × 1.08 = 4.32 < 4.4`) and why **any**
incoming damage dismounts a rider.

So raising mob speed has three named consequences the lane must decide with
it, not after:

1. **The Mage.** `classes.md:439-441` — "Frost Nova became the rotation pivot
   — **kiting IS the Mage fantasy here**". Kiting distance per Frost Nova is
   `root_duration × (mob_speed − player_speed)` of ground *not* lost, plus the
   4 s standstill. At 4.4 the Mage loses 0.4 m/s while running; at 4.8 it is
   0.8 m/s — the Mage's escape budget halves. Either the root duration or the
   soft-de-aggro distance moves with the speed, or the Mage's pivot stops
   working.
2. **The soft de-aggro.** `combat_stats.md:328-330`: beyond ~25 m a chasing
   mob drops to walk speed (`api.lua:2650-2666` implements it, and
   `_grug_soft_deaggro ~= false` is the per-mob opt-out). Reaching 25 m is
   *only* possible because of the standstill-and-root windows; faster mobs
   make it harder in exactly the same proportion.
3. **Ruling 1 multiplies ruling 2.** Once the cadence runs during the chase
   (§2), a 4.4 mob already lands roughly one hit per second on a fleeing
   player where it lands far less often today. The decided text's own figure
   for "today" is *one hit per ten seconds*, and that figure is **estimated,
   not measured** — it is worked from the dedicated-server step and the file
   says so in the clause quoted in §2. The direction is certain and the
   multiplier is not, which is exactly why the lane owes the runtime test of
   §5. **Ruling 1 alone may still be the whole of "mobs should be more
   dangerous"**, and it costs no pillar.

**Recommendation for the lane: ship §2 first, measure, and only then decide
whether the speed still needs to move.** If it does, the smallest change that
respects the pillar is to raise the *aggressive* band from 4.4 to **4.6** (the
value two heartland hunters already use, so nothing new is introduced) and to
leave critters at 3.4 — and to write the new inequality into
`combat_stats.md` §3, `mounts.md` §3.1 and the Swiftness Draught's arithmetic
in the same commit.

---

## 4. Ruling 3 — more ranged mobs, seeing further

### Measured

`attack_type` across the whole `mods/` tree:

| `attack_type` | Registered mobs |
|---|---|
| `dogfight` (melee) | 20 definition sites |
| **`dogshoot`** (ranged, alternating) | **3 definition sites → 4 registered mobs**: skeleton archer (`skeleton_archer.lua:56`), skeleton raider (`skeleton_raider.lua:28`), stone golem and mesa golem (one shared def, `golem.lua:57`) |
| `shoot` (pure ranged) | **none** |

`verbs.lua:676` defaults anything unset to `dogfight`. **The brief's figure of
"6 today" is not what this tree contains: it is four registered ranged mobs
out of 47**, from three definition sites.

View ranges, measured:

| Mob | `view_range` |
|---|---|
| skeleton archer | **16** — "it shoots; it needs to see further than a brawler" (`:86`) |
| skeleton raider | **16** — same comment (`:57`) |
| stone/mesa golem | 14 (`golem.lua:113`) |
| crag eagle / vulture | 16 — "a bird of prey spots you from far off" |
| bandit, hyena, guard, zombie, wolf, jungle lynx, zebra | 14 |
| bear, panther, mirefolk, stag, spider, jungle ape | 12 |
| boar, boar variants, bog ooze, ram, serpent | 10 |
| the eight critters | 8 |
| crocodile | 6 (deliberate, its own comment explains it) |

So **the rule ruling 3 asks for already exists in two of the four ranged mobs
and is written down in their comments** — the archer and the raider see 16
against a brawler's 12-14. The golem does not (14) and is the exception to
fix.

### The task

1. **Make the rule explicit** in `biomes_mobs.md` §3.1 and `combat_stats.md`
   §3: a `dogshoot` family's `view_range` is **16** and a melee family's is
   10-14 by habitat. Raise the golem from 14 to 16 to match.
2. **Add ranged families.** Four of 43 is 9.3 %; the ruling asks for more.
   Candidates that need no new art beyond a projectile:
   - a **bandit archer** variant beside `grug_mobs:bandit` (the bandit camp
     already exists, and `boar_variants.lua` is the pattern for a variant
     def);
   - a **mirefolk spitter** in the bogs;
   - a **harpy/crow** ranged flyer on the existing bird rigs.
   Each needs a `register_simple_arrow` entity
   (`skeleton_archer.lua:18` is the template) and a `mobs:spawn` row; the
   roster and the spawn budget belong to `biomes_mobs.md` §4 and are that
   lane's to decide, not this card's.
3. **Do not raise `view_range` above 16 without checking the chase rules.**
   `combat_stats.md:462-466` warns that a mob gives up a chase at **45 m**,
   "not at its `view_range` (mobs_redo's default, ≤ 16 m for ground mobs —
   with it, neither the 25 m soft de-aggro nor the 40 m leash could ever
   fire)". 16 is the working ceiling for **land** mobs; the only higher value
   in the roster is the Kraken's 20 (`kraken.lua:55`), which is aquatic and
   outside this comparison.
4. **The dogshoot ratio is a second knob, already present.** `dogshoot_switch`
   / `dogshoot_count_max` / `dogshoot_count2_max` decide how long a mob shoots
   before closing to melee — `golem.lua:63-68` documents it ("10 vs 3 is
   'mostly ranged', and a target inside `reach` forces melee regardless"); the
   switch itself is `dogswitch` (`api.lua:2122-2134`, defaults 5/5 at `:165`)
   and the melee branch condition is `api.lua:2492`. Making existing ranged
   mobs *stay* at range is cheaper than adding new ones, and it is one number
   per def.

---

## 4b. Prerequisite this lane owns: the speed aggregator (user ruling, 2026-09-16)

Not one of the three rulings above, but the same session decided it and **this
lane is its owner**, because this lane is the one that has to stop zeroing a
mob's velocity while its attack clock runs (§2) and because the WP11 talent
work needs it too (`docs/design/skill_trees.md` §3.9).

> **Ruling (user, 2026-09-16):** effects overlap freely with independent
> durations; the design is **one central aggregator in `grug_core`** where
> each system registers a **named modifier with its own duration**; a **root
> is a hard flag** (speed 0 regardless of modifiers), never a "−1000 %";
> **mounts stay outside** the aggregator.

Why it cannot wait, and **measured rather than inherited**.
`mods/ENTITIES/grug_mobs/verbs.lua:100-118` says there are two owners of
`physics_override.speed`, and `mounts.md:128-133` and `boats.md:113-117` both
repeat that count. `grep -rn set_physics_override mods/` finds **three**:

| Writer | Lines | What it writes |
|---|---|---|
| mob webs / snares | `grug_mobs/verbs.lua:153`, `:167`, `:178` | `{speed = factor}`, `{speed = 1}` to restore, and a join reset |
| the ability root/slow chain | `grug_abilities/kits.lua:161`, `:167` | `{speed = 1, jump = 1}` and `{speed = stage.speed, jump = stage.jump or 1}` |
| **character creation** | `grug_classes/selection.lua:52`, `:91` | `{speed = 0, jump = 0, gravity = 0}`, restored from a **snapshot** at `:91` |

The third is the one both comments miss and the worst for an aggregator:
`reassert_player_lock` (`selection.lua:49-53`) re-asserts the freeze whenever
it sees the override drift, so it fights any other writer; and
`release_player` (`:91`) restores `session.physics`, a snapshot taken when
creation began — so a slow running at that moment is captured and written back
permanently after the aggregator believes it expired. That is precisely the
bug class the ruling exists to end, and it does not go away unless this writer
migrates too.

**Speed and jump, not speed alone.** The shipped roots are speed+jump pairs
(`kits.lua:495` is `{speed = 0.1, jump = 0.3, time = 4}`, applied at `:167`),
while `verbs.lua:114-116` deliberately never touches `jump` so that "a mob web
can never lift a PvP jump root". An aggregator that owns only `speed` cannot
absorb the roots it is meant to replace. **Gravity stays outside**: its only
writer is `selection.lua:52`'s spawn freeze, which migrates as one named
exclusive hold rather than as a modifier.

The shape:

```lua
grug_core.set_move_modifier(player, "mob_web", {speed = -0.40}, 7)
grug_core.set_move_modifier(player, "sprint",  {speed =  0.25}, 10)
grug_core.clear_move_modifier(player, "sprint")
grug_core.set_root(player, 3)             -- hard flag: speed 0, jump 0
grug_core.set_move_immunity(player, 8)    -- discards negatives and roots
grug_core.hold_movement(player, "class_creation")  -- exclusive, releases exactly
```

**Recommended combination rule: additive percentages per axis, then one
clamp** — `clamp(1 + Σ, 0.1, 1.5)` for speed and for jump, with a root or an
exclusive hold taking precedence. Additive rather than multiplicative because
the shipped numbers already read as absolute speeds (`kits.lua:372` sets
`speed = 0.5`), because two slows multiplying to 0.25 is a stacking rule
nobody has decided, and because a sum is the only form in which a KAT can
state one invariant instead of enumerating application orders.

**Size, honestly split.** The **core** is roughly **100 lines** — a per-player
table of named entries with expiries, one accumulator per axis, the root flag,
the immunity, the exclusive hold, and the join/leave reset `verbs.lua:176-179`
already performs. **The migrations are extra**, and this is where the previous
estimate was short:

| Piece | Work |
|---|---|
| aggregator core (speed + jump, root, immunity, hold) | ~100 lines, new |
| migrate `grug_mobs/verbs.lua`'s slow chain (~95 lines today) | rewrite down to calls |
| migrate `grug_abilities/kits.lua`'s staged root/slow (~59 lines today) | rewrite; the staged `root → slow` becomes two named modifiers with different durations, which is what it always wanted to be |
| migrate `grug_classes/selection.lua`'s freeze and snapshot | becomes `hold_movement`; the snapshot restore disappears |
| KAT | overlap, expiry, root precedence, immunity, hold, and a no-effect baseline per axis |

It is pure Lua with no engine dependency, so the KAT carries it and no runtime
test is owed for the aggregator itself — unlike the api.lua patch of §2. The
**migrations** do owe one, because they change how every slow in the game
feels.

**Order within the lane: the aggregator first, the api.lua patch second.**
They are independent in code, but §3's speed question cannot be answered
honestly until slows and sprints stop cancelling each other, and the WP11
talents that depend on it (`skill_trees.md` §3.9) are blocked until it lands.

## 5. What this lane owes

- The **speed aggregator** of §4b, ~100 lines in `grug_core`, with its own
  KAT — and it lands first, because WP11's talent work is blocked on it.
- One GRUG PATCH in `mods/ENTITIES/mobs/api.lua` (§2), with the patch comment
  in the house style and the line-number drift in `combat_stats.md` §4
  corrected in the same commit.
- A **runtime test on a headless server**, required by the decided text
  itself: a player walking backwards at full speed away from a level-appropriate
  melee mob must take roughly one hit per `punch_interval`, and a player
  standing still must take exactly the same rate as today.
- A KAT is possible for the *arithmetic* (timer accumulation and the
  at-most-one-backlog rule as a pure function of `dtime`), but not for the
  feel; the KAT does not replace the runtime test.
- If mob speed moves (§3): the same commit updates `combat_stats.md` §3,
  `mounts.md` §3.1's pillar paragraph and `items_crafting.md` §10 P4's
  arithmetic, or the repo states three different versions of one inequality.
- If ranged mobs are added (§4): `biomes_mobs.md` §3.1 and §4 own the roster
  and the spawn budget.

## 6. Commands that reproduce every measurement in this card

```sh
grep -rn "run_velocity" mods/ENTITIES/grug_mobs/
grep -rn 'attack_type *= *"\(shoot\|dogshoot\)"' mods/
grep -rn 'attack_type *= *"dogfight"' mods/ | wc -l
grep -rn "view_range *=" mods/ENTITIES/grug_mobs/*.lua
grep -rn "mobs.register_mob(" mods/ENTITIES/grug_mobs/*.lua | wc -l
grep -c "GRUG PATCH" mods/ENTITIES/mobs/api.lua
sed -n '2430,2545p' mods/ENTITIES/mobs/api.lua
sed -n '3765,3775p' mods/ENTITIES/mobs/api.lua
```

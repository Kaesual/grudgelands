# Mob pressure — task card (2026-09-16)

**A task card, not an implementation.** No code was written, no engine was
run. Written by the WP11 skill-tree lane because the Scout's kiting and
stealth read on top of it ([`docs/design/scout.md`](../design/scout.md) §6.9),
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
decision. `combat_stats.md` §4 (`:461-484`) already decided it on
**2026-08-13**, in detail, and even diagnosed the defect:

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
> step while the mob loses the ground the target covered in it. […] roughly
> **one landed hit per ten seconds** instead of one per second. Raising
> `reach` cannot repair this (a stopped mob always leaves its own radius,
> whatever the radius) and would silently widen the elite/rare telegraph cone,
> which is `reach + 1.5` (§3), and make `dogshoot` mobs switch to melee
> earlier. **The fix is one vendored api.lua patch; because it changes every
> mob's feel, the WP that ships it owes a runtime test.**

**The line numbers in that quote have drifted** and the card corrects them
against `70dda602`:

| `combat_stats.md` says | Actually at `70dda602` | What is there |
|---|---|---|
| `api.lua:2493` | **`api.lua:2498`** | `self:set_velocity(0)` |
| `api.lua:2495-2497` | **`api.lua:2500-2502`** | `self.punch_timer = (self.punch_timer or 0) + dtime` and the `>= self.punch_interval` test |
| `api.lua:3768` | **`api.lua:3771`** | `punch_interval = def.punch_interval or 1` |

The structure, verified line by line:

- `api.lua:2434` — `if dist > (self.reach + (self.reach_ext or 0)) then` opens
  the **chase** branch (path-finding, `set_velocity(self.run_velocity)` at
  `:2481`, walk speed instead beyond 25 m at `:2477-2479`).
- `api.lua:2492` — `else -- rnd: if inside reach range` opens the **attack**
  branch.
- `api.lua:2498` — `self:set_velocity(0)`. The mob stops the instant the
  target is inside reach.
- `api.lua:2500` — `self.punch_timer = (self.punch_timer or 0) + dtime`. The
  cadence advances **only here**.
- `api.lua:2502-2504` — `if self.punch_timer >= self.punch_interval then
  self.punch_timer = 0`.
- `api.lua:2522` — `if self:line_of_sight(p2, s2) then` — the punch is
  additionally LOS-gated.
- `api.lua:2535-2538` — `target:punch(self.object, 1.0, {…
  damage_groups = {[dgroup] = self.damage}}, nil)` — the hit lands. Note
  `local target = self.attack:get_attach() or self.attack` at `:2531`: a
  mounted player's **mount** eats the swing, which `mounts.md:162-171`
  already relies on.

So the two defects are one line apart: **the mob stops (`:2498`) and the clock
only ticks while it is stopped (`:2500`)**. Reach is uniform in the roster:
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
   already uses (`combat_stats.md:147`: "lag never replays a backlog").
5. **Do not raise `reach`.** The decided text explains why: it cannot repair
   the defect, it widens the elite/rare telegraph cone (`reach + 1.5`,
   `combat_stats.md:332`) and it makes `dogshoot` mobs switch to melee
   earlier — that last one is **`api.lua:2366`**
   (`and (ds_var == 2 or dist <= self.reach)`), not the `api.lua:2249` that
   `golem.lua:68`'s comment cites; that citation has drifted too and is worth
   correcting in the same patch.

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

47 mobs are registered through `grug_mobs.register_mob`. The player walks at
**4.0** (`mounts.md:50-51`, engine default `movement_speed_walk = 4`).

This matches the design: `combat_stats.md:304-309` specifies "aggressive mobs
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

1. **The Mage.** `classes.md:430-432` — "Frost Nova became the rotation pivot
   — **kiting IS the Mage fantasy here**". Kiting distance per Frost Nova is
   `root_duration × (mob_speed − player_speed)` of ground *not* lost, plus the
   4 s standstill. At 4.4 the Mage loses 0.4 m/s while running; at 4.8 it is
   0.8 m/s — the Mage's escape budget halves. Either the root duration or the
   soft-de-aggro distance moves with the speed, or the Mage's pivot stops
   working.
2. **The soft de-aggro.** `combat_stats.md:322-324`: beyond ~25 m a chasing
   mob drops to walk speed (`api.lua:2477-2479` implements it, and
   `_grug_soft_deaggro ~= false` is the per-mob opt-out). Reaching 25 m is
   *only* possible because of the standstill-and-root windows; faster mobs
   make it harder in exactly the same proportion.
3. **Ruling 1 multiplies ruling 2.** Once the cadence runs during the chase
   (§2), a 4.4 mob already lands roughly one hit per second on a fleeing
   player where it now lands one per ten seconds. **Ruling 1 alone may be the
   whole of "mobs should be more dangerous"**, and it costs no pillar.

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
2. **Add ranged families.** Four of 47 is 8.5 %; the ruling asks for more.
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
   `combat_stats.md:456-460` warns that a mob gives up a chase at **45 m**,
   "not at its `view_range` (mobs_redo's default, ≤ 16 m for ground mobs —
   with it, neither the 25 m soft de-aggro nor the 40 m leash could ever
   fire)". 16 is the working ceiling of the current tuning.
4. **The dogshoot ratio is a second knob, already present.** `dogshoot_switch`
   / `dogshoot_count_max` / `dogshoot_count2_max` decide how long a mob shoots
   before closing to melee — `golem.lua:63-68` documents it ("10 vs 3 is
   'mostly ranged', and a target inside `reach` forces melee regardless"); the
   switch itself is `dogswitch` (`api.lua:2032-2044`, defaults 5/5 at `:165`)
   and the melee branch condition is `api.lua:2366`. Making existing ranged
   mobs *stay* at range is cheaper than adding new ones, and it is one number
   per def.

---

## 5. What this lane owes

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

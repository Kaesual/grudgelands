# Mounts — Riding, Speed Tiers & No-Mount Zones

Decided 2026-08-07 (crafting/mounts design session). **Nothing here is
built yet**: this file is the spec a later work package implements, not
a description of shipped behaviour. It exists so that the WP can be cut
without re-opening the design.

Neighbouring rules: travel and waypoints `world.md` §6, ocean zones
`world.md` §2b, housing isles `world.md` §5, the four mastery tiers
`items_crafting.md` §2.1, universal skills `professions.md` §1, sinks
`economy.md` §4 and `items_crafting.md` §8.4.

## 1. Riding is a universal skill

- **Riding does not cost a main profession slot.** Like **Cooking** and
  **First Aid** (`professions.md` §1) it is universal — every character
  can learn it, and the two main profession slots stay free for the six
  crafting professions.
- Riding is learned **from a trainer in a race capital**, in four steps.
  A learned step is **player state, permanent and per character** (like
  a profession tier), and it hands over the mount of that step.
- **Mounts are not a reward and not a drop** — they are bought (§2), and
  buying them is the point (§2 is a gold sink).

### 1.1 The four tiers

Riding uses the **same four mastery tiers as the crafting professions**
(`items_crafting.md` §2.1), with the same names and the same character
level anchors — a player learns one vocabulary, not two:

| Mastery | Learn at ~char level | Mount | Speed | Mount speed |
|---|---|---|---|---|
| Apprentice | 1 | slow land mount | +50 % | 6 nodes/s |
| Journeyman | ~16 | fast land mount | +100 % | 8 nodes/s |
| Expert | ~31 | slow flying mount | +50 % | 6 nodes/s |
| Master | ~46 | fast flying mount | +100 % | 8 nodes/s |

- Percentages are relative to a player's **default walking speed of 4
  nodes/s** (engine default `movement_speed_walk = 4`,
  `reference_projects/luanti/src/defaultsettings.cpp:520`; the game
  does not override it).
- The two flying tiers are the milestones — a flying mount is **the**
  travel upgrade of the second half of the game, and Expert is
  deliberately no faster than Journeyman: the first flight buys
  *terrain*, not speed. Master buys speed on top.
- The level anchor is the **visibility** gate; the price (§2) is the
  real gate at the low end — an Apprentice mount is nominally available
  at level 1 and costs about the first hour of income.

*Rationale for reusing the ladder*: the four names already carry a
meaning for every player (their profession book, their enchant slots,
their tome chain). A fifth, separate ladder for riding would be pure
vocabulary tax; sharing it makes "I am Expert" a statement about where
a character stands, not about which system is being talked about.

## 2. Prices — the riding gold sink

All values copper (`economy.md` §1). Bought once, permanent.

| Tier | Price |
|---|---|
| Apprentice — slow land mount | **1s** |
| Journeyman — fast land mount | **8s** |
| Expert — slow flying mount | **30s** |
| Master — fast flying mount | **60s** |

**≈ 99s ≈ 1g for the complete ladder.**

*Rationale*: against a lifetime gross income to level 60 of ≈ 1g and
endgame farming of 6–12s/hour (`items_crafting.md` §8/§8.1), the whole
riding ladder costs about one full playthrough's income while the
housing depth ladder costs ≈ 1.9g (`world.md` §5.3) — housing stays
**the** anchor sink (`economy.md` §4.1) and riding is the second-largest
long-term goal, not a rival. **No single riding purchase reaches a full
gold**, so `economy.md` §2's "a full gold is a fortune" stays reserved
for the deepest housing step, the guild founding fee and nothing else;
the biggest riding purchase (Master, 60s) matches housing step 5 and
sits clearly under its 1g flagship step.

## 3. What a mount is, mechanically

- **Mounts are bought, never tamed.** Taming was considered and
  **rejected**: there is no taming design, and the vendored mobs_redo's
  taming items — `mobs:saddle`, `mobs:lasso`, `mobs:net`
  (`mods/ENTITIES/mobs/crafts.lua:119`, `:138`, `:231`) — are removed with the
  vendored-recipe cleanup. A mount is a purchase, exactly like a tome or
  a depth step.
- **A mount is an entity the player is attached to.** The player calls
  `player:set_attach(mount_entity, ...)`
  (`reference_projects/luanti/doc/lua_api.md:8948`); while attached the
  player's `get_pos`/`get_rotation` return the parent entity's values
  and their own setters are ignored (`lua_api.md:8864-8870`).
- **Mount speed is the entity's velocity, never
  `physics_override.speed`.** That follows from the attachment above and
  it matters: `physics_override.speed` already has two declared owners
  (mob webs in `mods/ENTITIES/grug_mobs/verbs.lua:100-118` and the PvP
  snare chain in `mods/PLAYER/grug_abilities/kits.lua`). Riding adds no
  third owner and can never collide with a slow.
- **A mount carries no level, no XP, no threat and no aggro.** It is not
  registered through `grug_mobs.register_mob` — that wrapper *is* the
  level/XP engine (AGENTS.md, WP6 patterns) and would give a horse a
  level, a health bar and a con colour.
- **Dismounting** detaches the player and places them on a free
  neighbouring node — the `mobs.detach` / `find_free_pos` pattern of the
  vendored `mods/ENTITIES/mobs/mount.lua:183-198` and `:107-120`.
- **Death, logout and server shutdown dismount automatically.** The
  vendored mount API already registers `on_dieplayer`, `on_leaveplayer`
  and `on_shutdown` force-detach handlers
  (`mods/ENTITIES/mobs/mount.lua:47-97`), so no separate rule is needed:
  you always come back on foot.
- **Entering a no-mount zone dismounts you** (§4) — via the same detach
  path, so the player lands on a valid node rather than inside the
  mount's model.

## 4. Where riding is forbidden

Two independent rules. The housing rule (§4.2) is **not** an exception
to the open-sea rule (§4.1); each stands on its own.

### 4.1 Open sea: the "Exhausted" debuff

- **Outside the continents a player gets an "Exhausted" debuff** —
  mounted, swimming or flying alike. Movement mode makes no difference
  to whether the debuff applies.
- **A mounted player who carries "Exhausted" for more than 10 seconds is
  dismounted and falls into the ocean.** The window is what keeps a
  clipped corner of open water from throwing a rider off; crossing the
  band on purpose does not work.
- This is the same system as the deep sea of `world.md` §2b, seen from
  the player's side: the open sea is where the Kraken Guard lives, where
  deep-sea creatures destroy boats, and where players are simply not
  meant to be. A flying mount must not turn that deterrent into a ferry
  any more than a boat may.

**The boundary is `grug_core.open_sea_at(pos)`, never a hand-picked
coordinate** (`mods/CORE/grug_core/init.lua:741-745`). The function is a
Chebyshev distance from the nearer of the two continent rectangles
(`rect_distance`, `init.lua:733-737`) compared against
`OCEAN_COASTAL_WIDTH`. Every number in it is derived:

| Constant | Value | Source |
|---|---|---|
| `grug_core.CONTINENT_X_HALF` | 1500 | `grug_core/init.lua:13` |
| `grug_core.CONTINENT_Z_MIN` | 100 | `grug_core/init.lua:14` |
| `grug_core.CONTINENT_Z_MAX` | 1700 | `grug_core/init.lua:15` |
| `grug_core.OCEAN_COASTAL_WIDTH` | 1500 | `grug_core/init.lua:19` |

So the real geometry a mount rule has to respect is |x| ≤ 1500 and
100 ≤ |z| ≤ 1700 for the land rectangle, plus a 1500-node coastal band
around it. Any literal copied out of that — "z > 2300", "x > ±2200",
"|z| > 3200" — is wrong the moment the world size changes, because the
whole derived geometry of `grug_core` hangs off those four constants by
construction (`grug_core/init.lua:21-25`). The mount rule therefore
calls the function and nothing else.

**Known issue, inherited.** `open_sea_at` today is a pure
distance-from-the-continent test, so open sea starts at |z| = 3200 —
`BACKLOG.md` already flags this as too far in its WP24 readiness note
(it would spawn Kraken Guards on housing beaches, `world.md` §2b: the
function must answer false inside each isle's 150-node safe ring). The
mount rule inherits the bug one-for-one: until `open_sea_at` learns
about the isles, "Exhausted" fires on somebody's own beach. Fixing
`open_sea_at` is a precondition for shipping the mount rule, not a
separate concern of it.

### 4.2 Housing isles: no riding and no flying at all

- **On a housing isle there is no riding and no flying, at any mastery
  tier.** Not a speed penalty, not a timer — mounting is refused and an
  arriving rider is dismounted on the spot.
- **Being dismounted on an isle is intended, not an accident.** The
  build box is 100 × 100 nodes (`world.md` §5.1); a mount saves no time
  there, a flying mount trivialises the one thing the isle is about
  (digging down, `world.md` §5.3), and the isles must not become a
  substitute capital (`world.md` §5.6).
- The no-mount zone is **the isle and its 150-node safe ring**
  (`world.md` §2b/§5.6) — the same ring `open_sea_at` has to learn
  about. The two rules then meet exactly at the ring boundary with no
  gap in between: inside the ring riding is refused outright, outside it
  the water is open sea and "Exhausted" takes over.
- Isles are reached by **waypoint** (`world.md` §6) — the teleport pad
  is the only intended way in or out, and that is unchanged by mounts.

## 5. Reference implementations & licences

Three vendored reference projects carry a ride/attach pattern worth
adapting. Licence verdicts per AGENTS.md "Licenses" (project code is
GPL-3.0-or-later):

| Source | What to take | Code licence | Verdict |
|---|---|---|---|
| **mobs_redo** (already vendored as `mods/ENTITIES/mobs`) | the complete ride API | MIT (`reference_projects/mobs_redo/license.txt:1`) | ✓ compatible |
| **Lord-of-the-Test** `lottmobs/horse.lua` | mount-as-purchasable-item pattern | LGPL 2.1 (`Lord-of-the-Test/LICENSE.txt:1`; per-file heritage in `mods/lottmobs/license.txt`: PilzAdam WTFPL, TenPlus1 MIT, LGPL 2.1 contributions) | ✓ compatible |
| **VoxeLibre** `mcl_mobs/mount.lua`, `mobs_mc/horse.lua` | a maintained fork of the same API | GPL-3.0-or-later (`VoxeLibre/LEGAL.md`); `mobs_mc/README.md` names GPLv3 for that mod, and LEGAL.md's dual-licence clause lets us take the game's GPL-3.0-or-later terms instead | ✓ compatible |

- **mobs_redo is the base**: `mount.lua` is already vendored and loaded
  (`mods/ENTITIES/mobs/init.lua:26`). Its four public helpers are
  `mobs.attach(entity, player)` (`mount.lua:133-179`),
  `mobs.detach(player)` (`:183-198`),
  `mobs.drive(entity, moving_anim, stand_anim, can_fly, dtime)`
  (`:202-334`) and `mobs.fly(entity, dtime, speed, shoots, arrow, ...)`
  (`:338-410`); `force_detach` plus the leave/shutdown/die handlers sit
  at `:47-97`. `drive`'s `can_fly` flag and `fly` are exactly the land /
  flying split of §1.1, and the speed cap is the entity's own
  `max_speed_forward` (`mount.lua:313-316`). It **requires the
  `player_api` mod** (`mount.lua:8-16` stubs the whole API out
  otherwise) — we vendor it as `mods/BASE/player_api`, so the
  precondition holds.
- **Lord of the Test** shows the acquisition half we need and mobs_redo
  does not have: `lottmobs:register_horse(name, craftitem, horse)`
  (`Lord-of-the-Test/mods/lottmobs/horse.lua:26`) registers a
  **craftitem whose `on_place` spawns the mount entity** (`:31-41`) next
  to a plain `core.register_entity` mount (`:305`) with attach/detach on
  right-click (`:200-222`). That is the shape a bought mount wants: an
  item you own, placed to summon, with no taming step anywhere.
- **VoxeLibre**'s `mcl_mobs/mount.lua` (`mcl_mobs.attach` at `:52`,
  `detach` `:82`, `drive` `:89`, `fly` `:222`) is the same lib_mount
  ancestry, better maintained; `mobs_mc/horse.lua:226` is the reference
  call site. Use it to cross-check fixes, not as a second base — mixing
  GPL-3.0 code into the MIT-licensed vendored copy would relicense it
  for no gain.

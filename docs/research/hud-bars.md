# HUD bars — what shipped (round 4, lane H, 2026-09-16)

The implementation of [hud-bars-task-card.md](hud-bars-task-card.md). That
card is now historical; this file is the current document.

Branch `ui-r4-hud-bars`, based on `dfb32cd5`. Engine reference read in the
main checkout (`reference_projects/` submodules are not populated in a
worktree), pinned at `df04879066de6eb94ca43996822a6dfacc74feca`, Luanti
5.17.0-dev.

## 1. The user's ruling (2026-09-16), verbatim from the card

> The current heart statbars are rejected — "**half hearts are an ugly
> approximation**". Instead: a **thin, point-accurate LIFE bar**, and a
> **MANA-or-RAGE bar directly above the hotbar slots**. Every class has
> exactly **one** secondary bar — rage **or** mana, never both.

## 2. What the four open questions were answered with

**These four answers are the round-4 COORDINATOR's decisions, not the
user's.** They were handed to this lane in its brief and are recorded here
so the playtest can overturn any of them.

1. **The text line goes away; the exact numbers go INSIDE the bars** as
   centred text ("84 / 148"). The separate `Mana 84 / 148` element is gone.
2. **`grug_core` owns the offset stack.** One small table
   (`mods/CORE/grug_core/hud_layout.lua`) publishes the bottom-centre column
   plus the two free anchors (error flash, weapon-ready reticle); the three
   consumer mods read it and keep no constant of their own.
3. **Two bars, and the secondary row stays reserved** for a character who
   has not picked a class yet, so nothing jumps when the class arrives.
4. **Breath gets a third thin bar in the same style**, shown only while the
   player is short of air. The builtin bubbles go off with the hearts.

Three further choices were this lane's and are equally open to the playtest:
the bar geometry (180 × 16 px, 2 px above the hotbar), the life colour
(`0x4caf50`) and the breath colour (`0x8fd9f2`), and the empty track colour
(`0x141414`). Mana `0x4a9bd8` and rage `0xc41e3a` are `classes.md` §1's own
numbers and were not touched.

## 3. What shipped

### 3.1 `mods/CORE/grug_core/hud_layout.lua` (new)

The column, measured upwards from the top edge of the builtin hotbar, plus
the bar geometry and the arithmetic. It calls nothing from `core`, which is
why the fixture can load the real file rather than a copy.

Rows, bottom first (`top..bottom` in `hud_add` offset pixels; y grows
downwards, so both are negative and `bottom` is the lower edge):

| Row | Kind | top..bottom | Written by |
|---|---|---|---|
| `secondary` (mana **or** rage) | bar | −80..−64 | `grug_abilities` |
| `life` | bar | −100..−84 | `grug_abilities` |
| `breath` | bar | −120..−104 | `grug_abilities` |
| `skill` (selected skill name) | text | −142..−122 | `grug_abilities` |
| `money` | text | −164..−144 | `grug_money` |
| `xp` | text | −186..−166 | `grug_xp` |

Anchors outside the column: `flash` at `position.y = 0.35`, `reticle` at
`position.y = 0.5`, and the round-6 status text list at top right with
`position = {x = 1, y = 0}`, `offset = {x = -20, y = 20}` and
`alignment = {x = -1, y = 1}`. The status registry owns the text and reads
only this shared geometry.

The baseline is −62: the builtin hotbar is drawn at `{x = 0.5, y = 1}` with
`alignment.y = −1` and `offset.y = −4` (`builtin/game/hud.lua:270-277`), one
row is `m_hotbar_imagesize + 2 × m_padding` = 48 + 8 px
(`src/client/hud.cpp:239`, `HOTBAR_IMAGE_SIZE` = 48 in
`src/hud_element.h:45`), and its background box adds `m_padding/2`
(`src/client/hud.cpp:268-269`).

### 3.2 The bars

Three elements per bar: a dark track image, a coloured foreground image, and
a centred `text` label with the exact numbers. All three are registered on
join and dropped on leave, the shape every HUD writer in this game already
had.

Why `image` and not `statbar` — the card's §2 argument, re-verified here:
`Hud::drawStatbar` draws `count / 2` whole icons plus at most one half icon
(`src/client/hud.cpp:660-765`), and builtin rescales any pool onto the same
ten hearts (`scale_to_hud_max`, `builtin/game/hud.lua:143-154`). At the
level-60 Warrior's 325 HP (`combat_stats.md` §2) that is **16.25 HP per half
heart**.

Why a 1 × 1 strip: for an `image` element a positive `scale` multiplies the
source texture **and** `m_scale_factor`, which is the same factor that
multiplies `offset` (`src/client/hud.cpp:496-506`). A one-pixel-wide source
therefore makes `scale.x` the drawn width *in the same pixels the offsets
are written in*, at any `hud_scaling` or display density. `alignment.x = 1`
puts the image's left edge on the anchor
(`offset.X = (align.X − 1) × width / 2`, same lines), so the foreground
drains to the right instead of collapsing towards its own centre.

The tint is `^[colorize:#rrggbb:255` on one shared white strip, the way the
ability icons are tinted (`classes.md` §2c). A row that is reserved but not
drawn sets the empty texture name, which the engine skips
(`src/client/hud.cpp:489-491`) — the same mechanism WP39's reticle already
used.

### 3.3 Update path — no new globalstep

`AGENTS.md`'s throttling rule forbids a new one, and none was added. The
bars ride the **existing shared 0.5 s pass** that already serves mana/rage
regen, cooldown wear and the charge bars — one added call at the end of its
per-player loop body. That pass is also the only way breath can be shown at
all: the Lua API has `get_breath`/`set_breath` and the builtin's internal
`breath_changed` player event, but **no breath-change callback for mods**.

Between passes, a non-modifier `register_on_player_hpchange` callback
carries the hit. It has to carry a **prediction**, and this is the one real
trap in the whole lane: `PlayerSAO::setHP` runs every logger and only *then*
assigns `m_hp` (`src/server/player_sao.cpp:519-535`, loop in
`builtin/game/register.lua:546-563`), so `get_hp()` returns the **old** hit
points inside all of them. Worse, it returns the old value inside anything a
*later* logger calls — and `grug_abilities`' rage logger is registered after
the HUD one and calls `hud_update`, which would have painted the bar back to
full on every hit taken. The predicted value is therefore stored per player
and survives until the next 0.5 s pass, which drops it and reads what the
engine really stored. The fixture drives every non-modifier logger in
registration order with `get_hp()` deliberately stale, which is exactly that
ordering.

### 3.4 Packet discipline

`player:hud_change` sends a packet **whether or not the value changed** —
`src/script/lua_api/l_object.cpp:2026` still carries the comment
`// FIXME: only send when actually changed`. Every write in the new code is
therefore gated on the drawn value, and the drawn value is quantized to
whole pixels by `bar_fill` so that the gate is exact rather than optimistic.

## 4. Measurements

### 4.1 Elements and offsets, before and after

Before, at `dfb32cd5` (six Lua elements plus two builtin statbars):

| Element | Type | Offset | Owner |
|---|---|---|---|
| health | statbar (builtin) | `y = −88`, 24 px, 10 hearts | engine |
| breath | statbar (builtin) | `y = −88`, 24 px | engine |
| resource line "Mana 84 / 148" | text | **−135** | `grug_abilities` |
| XP line | text | **−110** | `grug_xp` |
| money | text | **−85** | `grug_money` |
| selected skill name | text | **−70** | `grug_abilities` |
| error flash | text | `position.y = 0.35` | `grug_abilities` |
| weapon-ready reticle | image | `position.y = 0.5` | `grug_abilities` |

After (fourteen Lua elements, no builtin statbars) — the definitions the
shipped join callbacks built while running inside the real engine, read back
through the probe's own **fake player** (a headless server has no real one,
so the engine's `read_hud_element` never sees them):
`tools/ui/evidence/20260916-hud-bars/engine-probe.log`.

| Element | Type | Offset | z |
|---|---|---|---|
| life track / fill | image | −90, −100 | 0 / 1 |
| life label | text | 0, −92 | 2 |
| secondary track / fill | image | −90, −80 | 0 / 1 |
| secondary label | text | 0, −72 | 2 |
| breath track / fill | image | −90, −120 | 0 / 1 |
| breath label | text | 0, −112 | 2 |
| selected skill name | text | 0, −132 | – |
| money | text | 0, −154 | – |
| XP line | text | 0, −176 | – |
| error flash | text | `position.y = 0.35` | – |
| weapon-ready reticle | image | `position.y = 0.5` | 1 |

Eight more Lua elements and two fewer builtin ones. That is a **one-time
join cost** — fourteen `hud_add` packets instead of six — and nothing per
second. No consumer mod carries a pixel offset any more; the fixture reads
the three files as text and fails if one comes back.

### 4.2 Packets per second, at the worst update cadence

Reasoned from the hooks, not estimated, and the two end points measured by
the fixture.

The worst cadence is the **shared 0.5 s regen pass**, so at most **two
opportunities per second per player** exist at all, before and after.

| Situation | Before | After |
|---|---|---|
| Idle, full pools, no damage | 0/s | **0/s** (measured: 0 writes over 4 passes) |
| Level-60 Mage regenerating out of combat (384 mana, 2 %/s = 7.68 mana/s) | 4/s — `hud_update` wrote `text` **and** `number` unconditionally on every tick that moved `floor(mana)` | **≤ 4/s** — label 2/s, fill 2/s (7.68 mana/s = 3.6 px/s over a 180 px bar, so the pixel moves on most ticks) |
| The same Mage in combat (0.5 %/s = 1.92 mana/s) | 4/s (the same two writes) | **≤ 3/s** — label 2/s, fill on about every second tick (0.9 px/s) |
| Warrior rage decaying out of combat (2 rage/s) | 4/s | **≤ 4/s** — label 2/s, fill 2/s (3.6 px/s) |
| One hit point lost | 1 packet (builtin `hud_change(id, "number", …)` per health event, `builtin/game/hud.lua:177-179`) | **2 packets** (measured: `scale` + `text`) |
| A landed swing (+12 rage) | 2 packets | **≤ 2 packets** |
| Submerged, breath **not** moving | 0/s | **0/s** (measured: 0 writes over 4 passes) |
| One breath point lost | 1 packet (builtin bubbles, `builtin/game/hud.lua:199, 216-217`) | **2 packets** |
| Going under / surfacing (the row appears / disappears) | 1 packet | **4 / 3 packets, once** |

So for **the row the old element was** — the resource row — the
steady-state worst case is unchanged at 4 packets/s per player, and the
colour write that used to go out twice a second without ever changing is
gone. Damage costs one packet more per hit than the builtin statbar did, and
a drowning player about twice what the bubbles cost; both buy the exact
number. Adding the rows up honestly: a Mage regenerating, drowning **and**
being hit peaks near 6-8 packets/s. All of it is event-driven and bounded,
none of it is per-tick, and an idle player still costs 0.

### 4.3 The resolution claim, stated honestly

`bar_fill(value, maximum)` returns whole pixels, clamps at both ends, and
guards both ends of a *partial* value:

```
hud_bars_resolution   hp_max 325   at_324 178   at_1 2   full 180
```

and the same four numbers from inside the real engine
(`HUDPROBE fill 325of325=180 324of325=178 1of325=2 0of325=0`).

**What that does and does not claim.** A 180 px bar at `hp_max = 325` is
1.81 HP per pixel, so the *bar* is not literally accurate to the point —
nothing 180 px wide can be. What is guaranteed is that it is monotone, never
negative, never wider than the bar, **never reads full while a point is
missing** and **never reads empty while a point is left**; the exact number
is the label inside it. That is the whole distance from the rejected
statbar, whose step at the same `hp_max` is 16.25 HP. The fixture sweeps
every value of 0..325, 0..384, 0..100 and 0..10 and reports zero order or
bound faults.

`MIN_FILL = 2` is the lower guard. At 180 px it only actually bites above
`maximum ≈ 360` — which is why the mutation that removes it is caught by the
384-point mana pool and not by the 325-point life bar. Its second job is
`hud_scaling` below 1, where the engine's `int` truncation of
`scale.x × m_scale_factor` would otherwise erase a one-pixel fill.

### 4.4 Gates

| Gate | Result |
|---|---|
| `tools/bin/luac51 -p` + SETGLOBAL, 5 changed files + whole tree | PASS; SETGLOBAL 0 for `hud_layout.lua` and the fixture, 1 (the mod table) elsewhere |
| Five plain-5.1 sweeps, scoped and tree-wide | no new hits (the four scoped hits are pre-existing `\|` inside concatenations and comments) |
| `python3 tools/check_fresh_server.py` | `Fresh-server source audit: PASS` |
| `bash tools/wp40/r7/run.sh unit` | PASS |
| `tools/wp13/final_micro.lua` pair (this lane touches no mapgen) | `4d41e72a8980389f6dad96341bb20443f9ddc903eb1450930149c63ac9952484` under both interpreters, **identical to the same pair taken on the base before any edit** |
| `tools/ui/hud_bars_kat.lua` under LuaJIT and PUC 5.1 | `PASS 0`, byte-identical output (`d1457e6b59f57f13181b635e3b868307f3075a2980110c6e7acd04aa9c00510c`) |
| Four mutations | all four go red — see §5 |
| Headless boot with the probe, port 31307 | `listening on 127.0.0.1:31307`, no ERROR/ModError |
| `LICENSE-media.md` row per texture; strip regenerated | `media rows missing: 0`; byte-identical regeneration |

## 5. What turns red if the ruling is broken

`tools/ui/hud_bars_kat.lua` has four sections — the arithmetic, the layout,
the three consumer mods read as text, and the real `grug_abilities` loaded
under a stub engine and driven through its real join callback with a fake
player. `tools/ui/evidence/20260916-hud-bars/mutations.sh` breaks the rule
on purpose four times and shows the fixture failing each time:

| Mutation | Result |
|---|---|
| a bar is drawn as a `statbar` again | FAIL 21 |
| `grug_xp` writes its own pixel offset again | FAIL 2 (the literal **and** the un-shared `hud_add`) |
| a full bar draws wider than the bar | FAIL 8 |
| the guard that keeps the last point visible is removed | FAIL 2 |

Adding 1 to the *rounded* value is deliberately **not** one of the
mutations: the upper guard absorbs it, which is the guard doing its job.

## 6. The engine probe

A headless server has **no client**, so a HUD cannot be seen there and
nothing below is a claim about how it looks. What the probe
(`tools/ui/probe/grug_hud_probe/`, staged into a throwaway copy of the game
by `engine.sh` and never shipped) proves is the whole server side: the game
loads with the new `grug_core` module in it, `grug_core.hud_layout` inside
the real engine is the same table the fixture asserts, and the **shipped**
join callbacks of `grug_abilities`, `grug_xp` and `grug_money` — picked out
by `core.callback_origins` (`builtin/common/register.lua:6`), so the faction
and class dialogues of the other mods do not run — build the fourteen
element definitions of §4.1, with `healthbar = false` and
`breathbar = false`. Those definitions are read back from the probe's own
fake player table; with no client there is no real player, so the engine's
own `read_hud_element` never validates them. **The element definitions
themselves are gated by the playtest, not by this probe.**

One detail worth keeping: the probe's fake player joins at 325 HP and the
life bar comes out `30 / 30`, because `grug_classes.apply_stats` runs
through the XP level pipeline during that join and resets `hp_max` to the
level-1 value. The bar followed the properties rather than the stale number,
which is the behaviour wanted.

## 7. Verifying the card's citations

Every `file:line` the task card gives for `mods/` was re-resolved against
this lane's base `dfb32cd5` and is exact there (the card was written at
`70dda602`; the HUD regions did not move between the two). Two notes:

- the card's `grug_abilities/init.lua:45-52` covers `resource_of` at 45-48
  plus the section comment that follows, and `:229-247` starts three lines
  above `show_skill_name`; both land on the right code.
- `classes.md:294-306` (the charge bar, cited in the card's §6) is now
  **`classes.md:305-317`**: this lane rewrote the one-line HUD bullet in §1
  into twelve lines. Everything the card cites in `mods/` is gone by
  construction — those are the four offsets it was written to remove.

## 8. What the review should look at

- The prediction in §3.3 and its lifetime. It is correct for every path that
  goes through `setHP`, but it is a *prediction*: if the engine clamps the
  change differently (an `immortal` armor group — this game sets one during
  class selection — or an `hp_max` that moved without an HP change, which
  `apply_stats` does) the bar is wrong until the next shared pass. That bound
  is **0.5 s plus one server step**, not 0.5 s: the pass fires on the first
  step with `acc >= 0.5`, and a step is often 0.09 s, so ~0.6 s. Whether that
  window is acceptable, or whether the HUD logger should instead be
  registered last, is a judgement call — but registering last does not remove
  the need to predict (`get_hp()` is stale in *every* logger) and it would
  break again the day someone registers a logger after `grug_abilities`.
- The one line added at the end of `grug_abilities`' shared 0.5 s pass. It
  is inside a loop lane W1 also edits (rage tuning); it was put at the end
  of the body, as far from the rage branch as possible, and it is the only
  hunk of this lane inside that function.
- `player:get_properties()` is called once per player per pass (twice on a
  pass where the resource also moved, because the existing regen branches
  call `hud_update` themselves). That is a fresh table per call from the
  engine. It was chosen over caching `hp_max` because a cached maximum that
  misses an `apply_stats` draws a wrong bar, and `get_max_hp` is not the
  same thing as the `hp_max` the engine actually holds.
- Whether `secondary` really belongs below `life`. The ruling puts the
  mana/rage bar "directly above the hotbar slots" and says nothing about
  where the life bar goes, so it went above it.

## 9. What is open

- **The look.** Bar width, height, colours and the gaps are this lane's
  first pass, not a decision. So is the font size inside the bars: the label
  uses the player's own font size, because `size = {x = <float>}` is only
  supported from client 5.16 and an older client rounds a fractional value
  down to **zero**.
- **The hotbar's second row.** If the hotbar ever wraps (the engine draws a
  second row when its width exceeds `hud_hotbar_max_width` of the screen,
  `src/client/hud.cpp:807-822`), it grows upwards into the `secondary` row.
  With eight slots at the default setting it does not wrap at any ordinary
  resolution, and Lua cannot query the condition; it is recorded, not
  handled.
- **The −62 baseline assumes the hotbar images this game sets.** It is the
  top of the hotbar *background box*, which exists only because
  `mods/BASE/default/init.lua:42-43` calls `hud_set_hotbar_image` and
  `hud_set_hotbar_selected_image`. The selected-slot image bleeds
  `2 × m_padding` = 8 px above the item rect and so reaches **−64** — exactly
  where the secondary bar's bottom edge is. They **abut with 0 px**; they do
  not overlap. Whether touching looks right is a playtest question, and the
  number would be 2 px too generous for a game that sets no hotbar image.
- **A fifth HUD writer is still outside the table.** `grug_mobs`' target
  frame (`mods/ENTITIES/grug_mobs/target_frame.lua:155-162`) is a text
  element at `position.y = 0` with a literal `offset {x = 0, y = 40}`. It is
  top-centre and cannot collide with the bottom column, but it means
  `classes.md` §1's "no mod carries its own offset" is about **this column**,
  and §4.1's "six Lua elements before" counts the column plus the two
  anchors, not every HUD element in the game. That file belongs to another
  lane; extending `layout.anchors` to it is later work.
- **The reserved breath row** leaves a 20 px gap between the life bar and
  the skill-name line whenever the player is not short of air. That is the
  price of "nothing jumps"; the alternative is a row that appears and pushes
  everything up.
- **The Character page** still shows nothing about these bars, and nothing
  in this lane touched how HP, mana or rage are *computed*.

## 10. What the user should look at in a FRESH world

1. **Right after joining, before picking a class.** There should be one
   green life bar with `30 / 30` in it, an empty gap directly above the
   hotbar where the secondary bar will be, and **no hearts and no bubbles**.
2. **After picking a class.** Warrior: a red rage bar appears in that gap at
   `0 / 100` and the life bar does **not** move. Mage or Priest: a blue mana
   bar at its full value. Never both.
3. **Take a hit** (a mob, or a fall). The life bar should move immediately,
   not on the next half second, and the number inside it should match what
   `/combatdebug` and the damage feel say. Hit something as a Warrior and
   watch rage climb in +12 steps.
4. **Swim under water.** A pale blue breath bar should appear in the row
   above the life bar, count down `10 / 10 … 1 / 10`, and disappear a few
   seconds after surfacing. It is the first thing to check because the
   builtin bubbles are gone: if drowning no longer shows anything, that is
   the bug.
5. **At low health.** With one hit point left the bar must still show a
   visible sliver, not nothing.
6. **The look.** Width, height, the two-pixel gap above the hotbar, the
   colours, and whether the numbers inside the bars are legible at your
   resolution — all of that is this lane's first guess and is meant to be
   argued with.

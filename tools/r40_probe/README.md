# Round 40 GUI probe: Charge as a dash, the cooldown overlay

A throwaway mod (`grug_r40_probe`) for the user's look at two Round 40
topics before wave 2 builds them ([round plan](../../docs/planning/round40-plan.md)
§4.1 "V4 Probe", research §3.1 and §3.3). It is **never shipped**: nothing
in `mods/` changes, and the game runs exactly as before without it. What you
see decides lane CH (carrier A or push B, the terrain mode, the `Body` lead,
the FOV kick) and lane CD (the overlay layout and the number variant).

## Install

1. Create (or reuse) a test world of the Grudgelands game. Do not use a
   world you care about: the courses replace nodes for a while.
2. Copy this folder into the world as `worldmods/grug_r40_probe`
   (Flatpak: `~/.var/app/org.luanti.luanti/.minetest/worlds/<world>/worldmods/grug_r40_probe`).
   The folder name should match the mod name.
3. Start the world. The log shows
   `[grug_r40_probe] loaded, commands registered: /psetup /pdummy /pcharge /plead /pcd /pbench`.
4. For the web build: the server the web client joins needs the same
   `worldmods` copy; the second client (to watch the `Body` lead from
   outside) joins the same server.

`/psetup`, `/pdummy`, `/pcharge`, `/plead` and `/pbench` need the `server`
privilege (singleplayer has it; on a server `/grant <name> server`). `/pcd`
needs none. Remove the folder afterwards; `/psetup clear` first if a course
is still standing.

## Commands

### Test courses: `/psetup`

`/psetup <course> [mob <entity>]` builds a lane three nodes wide along the
axis you face, from temporary probe nodes, puts you at its start facing the
green **probe target**, and says how many nodes it replaced. It refuses
(and changes nothing) where any node is a town, start, capital, POI or other
guarded ground (`grug_core.world_alterable`), part of a road, village or
camp, unloaded, liquid, holds metadata, or carries sand or gravel on top:
walk into open countryside and try again.

| Course | What it is |
|---|---|
| `short` | flat, target 5.3 m away (a dash of about 4 m) |
| `long` | flat, target 12 m away (a dash of about 10.7 m; 12 m is Charge's cast range) |
| `wall` | a 1.25 m wall 4 m out that the eyes see over, target 9 m away |
| `wall_high` | a 2 m wall: no line of sight, so every variant refuses at the cast |
| `step` | a one-node step up 4.5 m out, target on top 8 m away |
| `uphill` | stairs up one node every two (about 27°), target 10 m away and 4 m higher |
| `ledge` | you start on a 3 m ledge, target 9 m away below |
| `hit` | flat, target 10 m away, a red **striker** beside the lane at 5 m |

- `mob <entity>`: a real mob instead of a probe block — on `hit` as the
  striker, on every other course as the target (for example
  `/psetup long mob grug_mobs:wolf`; any registered entity name works).
- `/psetup back` puts you back at the start (after a dash).
- `/psetup clear` removes the course and restores every replaced node (the
  list survives a restart; a node that cannot be restored stays on the list
  and the command says so: walk back to the course and clear again).
- `/psetup` alone lists the courses.

`/pdummy [<m>] [mob <entity>]` puts a target `<m>` metres ahead (default 8)
on the real terrain, without a course; `/pdummy clear` removes targets.

### One Charge: `/pcharge <variant> [key=value ...]`

Every variant asks the game for the same destination as today's Charge
(`grug_abilities.charge_destination`: 1.3–3 m in front of the target, line
of sight from eye to eye) and then moves you differently:

| Variant | What moves you |
|---|---|
| `teleport` | today's Charge: `set_pos` to the destination (the baseline) |
| `ghost` | carrier A, non-physical: a straight line from your feet to the destination, through anything in between |
| `physical` | carrier A, physical: collides with nodes, falls with gravity, climbs `step` metres |
| `path` | carrier A on the planned path: the ground is sampled once at the cast; level stretches are runs, every step, slope, low obstacle or drop is a ballistic hop; where nothing fits the path is cut short or refused |
| `push` | B: a push (`add_velocity`) with a temporary braking override, restored afterwards — **do not hold a movement key**, it changes the distance |

Options (defaults in brackets):

| Option | Meaning |
|---|---|
| `speed=` [16] | m/s; for `push` the start speed. Try 12, 16 and 24. |
| `lead=` [0] | the `Body` lead in metres: the drawn model runs this far ahead of the camera (third person and other players only). Try 0.4–0.8. |
| `leadin=` [0.1] | seconds the lead takes to build up (and 1.5x that to go back) |
| `fov=` [0] | the first-person FOV kick as a multiplier, for example 1.15; 0 = off |
| `hold=` [0.1] | seconds the carrier waits at the stop before letting you go |
| `snap=` [0] | 1 = after letting you go, also set your position to the stop |
| `anim=` [walk] | the pose during the dash (`walk`, `walk_mine` or `none`) |
| `step=` [0.6] | `physical` only: the carrier's step height (1.1 climbs one node) |
| `hopspeed=` [1] | `path`: horizontal speed in a hop as a share of `speed` (0.6 reads more like a jump) |
| `gmax=` [50] | `path`: a hop steeper than this gravity (m/s²) is lengthened while it can be |
| `maxhop=` [6] | `path`: the longest hop, metres |
| `rise=` [1.6], `drop=` [4] | `path`: the highest step up and the deepest drop between two samples |
| `clear=` [0.35] | `path`: how far a hop clears the highest ground under it |

Examples: `/pcharge path speed=16 lead=0.6 fov=1.15`,
`/pcharge physical step=1.1`, `/pcharge push speed=20`.

Every dash prints (and logs) its result:

```
path (16 m/s, lead 0.6 m): planned 6.77 m (cast to destination, 6.70 m flat), target 8.1 m away; destination in 31 us
path: hop +1.00 m over 5.75 m in 0.36 s (apex 1.35, g 48) | run 0.95 m in 0.06 s; planning 144 us (27 samples, 4216 node reads, 74 nodes)
ARRIVED within CHARGE_REACH (1.30 m from target) | stop: clamped at the destination after 451 ms server time, 5 steps (361 ms wall) | reach entered at 361 ms, step 4
carrier cost: 7 steps, avg 13.0 us, max 21 us per step, 1 segment switches
```

- **ARRIVED within CHARGE_REACH / MISS**: whether the server saw you within
  3 m of the target when the dash stopped (§2.10). In the game, damage,
  stun and rage would land then (arrival) or nothing would (miss, §2.3).
- **server time** is the sum of the server steps the dash ran (its motion
  time), **wall** the real time since the cast; **steps** counts server
  steps (0.09 s each by default). "reach entered" is the first step within
  3 m.
- On `hit`, one more line says whether the striker's punch — resolved like
  a mob's melee hit, `attack:get_attach() or attack` — reached you through
  the carrier (§2.11), with your HP before and after.

### `Body` lead check: `/plead <m>`

Holds the relative `Body` override (`/plead 0.5`; `/plead 0` clears) so you
can check in third person (F7, front view) that the model moves **forward**.
If it moves backward, tell the coordinator: the sign is the probe's guess
from `tools/r33_c3/gen_cloak_model.py` ("+z is forward").

### The cooldown overlay: `/pcd`

Fake cooldowns on the real hotbar slots: a pie at 50 % black that clears
clockwise (72 frames, one per 5°) and the number in the middle (`5m` … `2m`,
then `60` … `1`, §2.1). Nothing else of the game changes.

| Command | What it does |
|---|---|
| `/pcd <slot> <seconds>` | a cooldown on hotbar slot 1..n (several at once; 2–300 s) |
| `/pcd demo` | every slot at once: 2, 5, 10, 30, 60, 65, 120, 300 s |
| `/pcd clear` | removes them |
| `/pcd number text\|shadow\|image\|none` | the number as HUD text, HUD text with a shadow element, image digits that scale with the icon, or none |
| `/pcd textsize <x>` | text size as a multiple of the font size [1]; text follows the font, not `hud_scaling` |
| `/pcd digitsize <share>` | image digit height as a share of the slot [0.45] |
| `/pcd layout exact\|plain` | `exact` [default] places every element on the engine's own slot pixels from the window size and scaling your client reports (and follows the two-row split); `plain` uses fixed HUD units and knows nothing about the window |
| `/pcd itemcount <n>` | the hotbar item count (default 8; set 8 again when done) |
| `/pcd gui <g>` | tell the probe your `gui_scaling` if it is not 1 (it derives the display density from it) |
| `/pcd maxwidth <w>` | tell the probe your `hud_hotbar_max_width` if it is not 1.0 |
| `/pcd info` | what the probe knows: window, scaling, slot size, rows, pass cost, HUD writes |

The overlay updates at most ten times a second and only when the frame or
the number changes; it re-places itself within a moment after you resize
the window or change `hud_scaling` (while a cooldown runs).

### `/pbench`

Prints the server-side Lua cost of the path planner on every course and of
one overlay pass with 8 and 32 running cooldowns. Numbers are comparisons,
never targets.

## What to look at first

1. `/psetup long`, then `/pcharge teleport`, `/pcharge ghost`,
   `/pcharge path` (`/psetup back` between them), in third person and in
   first person. Does a dash read as a dash? Which speed: 12, 16 or 24?
2. `/psetup step` and `/psetup uphill` with `/pcharge path` (the leap) and
   `/pcharge physical` (stops at the step) — in first person too.
3. `/pcd demo`, then `/pcd number shadow` and `/pcd number image`, at
   `hud_scaling` 1 and 1.5.

## Report form

Copy this list into a reply and fill in each line: **ok**, **bad** (what is
wrong) or **n/a**. "D" = desktop client, "W" = web build; "3rd"/"1st" =
third/first person; "2nd" = watched from a second client.

### Charge

| # | Check | What to look at | D 3rd | D 1st | W 3rd | W 1st | 2nd |
|---|---|---|---|---|---|---|---|
| C1 | `long`: teleport vs ghost vs path | does the dash read as movement, not a jump cut; smooth or stuttering; the stop exact or a jerk back | | | | | |
| C2 | speed | `speed=12`, `16`, `24` on `long`: which reads best (fast constant speed, §2.3)? | | | | | |
| C3 | `short` | a 4 m dash: too quick to see, or fine? | | | | | |
| C4 | detach | at the end, any snap or slide when the carrier lets go (`hold=0`, `hold=0.2`, `snap=1`)? | | | | | |
| C5 | `wall`, `ghost` | passing through the wall: acceptable or broken-looking? | | | | | |
| C6 | `wall`, `path` | the hop over the wall | | | | | |
| C7 | `wall`, `physical` | stops at the wall: printed MISS | | | | | |
| C8 | `wall_high` | every variant refuses at the cast (no cooldown would be spent) | | | | | |
| C9 | `step`, `path` | the leap onto the step; try `hopspeed=0.6` and `gmax=150` | | | | | |
| C10 | `step`, `physical` | stops at the step (`step=0.6`); with `step=1.1` it climbs | | | | | |
| C11 | `uphill`, `path` / `ghost` / `physical` | the leaps vs the straight line through the stairs vs stopping | | | | | |
| C12 | `ledge`, `path` / `ghost` / `physical` | the drop off the ledge; `ghost` cuts through the ledge corner | | | | | |
| C13 | `push` on `short` and `long` | starts fast, slows down; stops near the target or overshoots/undershoots? (no keys held) | | | | | |
| C14 | `push` on `step` / `uphill` | where it stops | | | | | |
| C15 | `hit` with `ghost` / `path` | the strike line says "resolved to the carrier and was forwarded to the rider"; your HP drops | | | | | |
| C16 | `hit` with `mob <entity>` | a real mob as the striker: same | | | | | |
| C17 | `lead=0.6` (and 0.4, 0.8) | `/plead 0.5` first: moves forward? Then the lead during a dash: model ahead, camera following — only visible in 3rd and from the 2nd client (§3.3) | | — | | — | |
| C18 | `fov=1.15` (and 1.1, 1.25) | the first-person accent: a kick or a distraction? | — | | — | | — |
| C19 | the pose | legs run during the dash (`anim=walk`), or `anim=none` | | — | | — | |
| C20 | a real mob as the target | `/psetup long mob <entity>`: the mob fights back on arrival; any surprise? | | | | | |

### Cooldown overlay

| # | Check | What to look at | D | W |
|---|---|---|---|---|
| O1 | `/pcd demo` at `hud_scaling` 1 | the pie sits exactly on each slot's icon; clears clockwise from twelve o'clock; 50 % black reads well | | |
| O2 | the same at `hud_scaling` 1.5 (and one odd value, e.g. 1.3) | still exactly on the icons? `/pcd layout plain` for comparison: does it drift? | | |
| O3 | numbers | `text`, `shadow` and `image` side by side (`/pcd number ...`): readable on bright and dark icons; which one? | | |
| O4 | number size | text at `textsize` 1 and 2 vs image digits at 1 and 1.5 `hud_scaling` (text does not grow with the icon) | | |
| O5 | minutes | the 120 s and 300 s slots: `5m` … `2m`, then `60` … `1` | | |
| O6 | short cooldown | the 2 s slot: smooth enough at ten updates a second? | | |
| O7 | narrow window | make the window narrower than the hotbar: the hotbar splits into two rows — does the overlay follow (`exact`)? | | |
| O8 | item count | `/pcd itemcount 10`, then `6` (then `8` again): the overlay follows | | |
| O9 | `/pcd info` | paste the output (window, scaling, slot size, rows) | | |

Free comments: what looked best, what looked wrong, which numbers you want
for speed, lead, FOV kick and the overlay.

## Files

- `init.lua` — the commands; `course.lua` — courses, target, striker;
  `charge.lua` — the variants, the carrier, the report; `overlay.lua` — the
  hotbar overlay; `bench.lua` — the timings.
- `planner.lua`, `hudmath.lua`, `shapes.lua` — pure Lua (no engine calls):
  the path planner, the overlay arithmetic (the engine's slot rectangles
  from `src/client/hud.cpp`), the courses.
- `gen_textures.py` — writes `textures/` (72 pie frames, image digits);
  `python3 tools/r40_probe/gen_textures.py --check` verifies them.
- `portable_test.lua` — `luajit tools/r40_probe/portable_test.lua .`
  (the planner on every course with the game's own destination search, the
  number format, the frames, the slot arithmetic); `run_fixtures.sh` picks
  it up like every `tools/*/portable_test.lua`.
- Headless timings: stage a copy of this folder named `grug_r40_probe` with
  an empty file `BENCH` in it and boot it with `PROBE=<that copy>
  tools/luanti_headless.sh 300`; the log's `[r40 bench]` lines hold the
  results and the server shuts down by itself. It builds every course next
  to a land spot of the throwaway world (same guards as `/psetup`).

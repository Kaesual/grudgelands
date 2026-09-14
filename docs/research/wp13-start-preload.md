# Start-area preload and start-footprint spawn refusal

Round A playtest decisions of the user, **2026-09-14**. Both replace shipped
behaviour; the design rules themselves live in
[settlements.md](../design/settlements.md) and [world.md](../design/world.md)
§2 R1.

## Decision 1 — the server prepares all six starts at startup

WP45 emerged only the chosen race's start, behind character creation, and made
that player wait for it. Because the starts generate through the WP40 mapgen,
the first player of every race paid the same mapchunk cost again, and the
person who chose an unvisited race waited the longest.

Decided instead:

- After every mod has loaded, the server emerges the **128 × 128 build
  envelope of all six starts**, at the vertical extent character creation used
  before (spawn − 24 … spawn + 80). The 256-node blend ring is deliberately
  **not** included: it is terrain, not arrival area.
- At most **two** emerges run at a time. A start counts as ready only when
  every block of its volume reported a terminal action; `EMERGE_CANCELLED`
  (server shutdown) and `EMERGE_ERRORED` never mark one ready. Nothing is
  persisted, so a restart simply re-requests and already generated blocks
  return from disk.
- Character creation keeps its existing flow, but its final step — the single
  teleport plus class commit — waits until **all six** starts are ready, not
  only the player's own. While waiting, the player sees the existing stasis
  loading form with the progress line "Preparing the starting areas (N of
  6)...". The form is sent only when that text actually changes, never per
  emerged block and never per server step.
- A start that fails three attempts turns the wait into the existing
  retryable failure state (the "Try again" button re-requests exactly the
  missing starts) instead of an endless wait.
- Progress is driven purely by emerge callbacks. The only accumulator in the
  creation flow remains WP45's throttled stasis re-assertion.
- `grug_core.starts_ready()` (ready, total), `grug_core.start_ready(race)`,
  `grug_core.starts_preload_failed()` and
  `grug_core.register_on_starts_progress(func)` are the public seam.

WP45's own per-race emerge is gone from character creation. Its
`grug_factions.prepare_spawn` survives for **respawn only**: a start may be
unloaded again long after the startup preload, and the respawn teleport still
has to guarantee its destination is present at that moment. That is the one
thing the startup preload does not cover.

Measured on a fresh world, headless, 2026-09-14: 13.6 s to the first start and
**42.6 s to 6/6**, logged at ACTION level as one line per start plus one
summary line. No per-block logging.

## Decision 2 — no hostile spawns inside the six start footprints

The start footprint is the 128-node build envelope plus its 10-node protection
apron (world.md §2 R1), i.e. the **148 × 148 hard-protected square** centred on
the start anchor. It is half-open: anchor − 74 … anchor + 73 are inside,
anchor − 75 and anchor + 74 are outside.

- Every mob that can attack players is refused inside those six squares,
  including the zombie's 24-hour blight row inside Stillgrave Hollow. The
  refusal is horizontal and therefore height-independent — the cave rows stop
  under a start too.
- Passive critters (rabbits, gulls, parrots, bats, weevils, bog fowl) and the
  four non-aggressive prey animals keep spawning there.
- The undead race passive (the zombie night truce) is untouched.

Where and how: `grug_mobs.spawn_policy_allows` in
`mods/ENTITIES/grug_mobs/spawn_policy.lua`, the single gate
`mobs:spawn_abm_check` calls for every ABM spawn candidate. The hostile role is
**derived** at registration from exactly the fields mobs_redo's
`general_attack` tests for a player candidate (`passive` and `attack_players`,
the latter defaulting to true), so it cannot drift the way a hand-kept list
would.

`grug_zones.territory_rule_at(pos) == "hard_protected"` is the same predicate
and was rejected on cost: it normalizes a position, walks a sparse footprint
index and allocates a candidate list per call. The six rectangles are compiled
once from `grug_core.start_identities()` and tested as at most 24 plain number
comparisons with no allocation. Capitals are hard-protected too and are
deliberately not covered here — their mob palettes are empty, so no ordinary
row reaches them anyway.

## Verification

- `tools/bin/luac51 -p`, `SETGLOBAL` inspection and all five plain-5.1 sweeps
  on the changed mods; `tools/check_fresh_server.py` green.
- `tools/wp45/run.sh` — the updated character-creation regression plus
  `starts_preload_kat.lua` (cold start, concurrency cap, cancellation, bounded
  retry, permanent failure, restart from disk) and `start_footprint_kat.lua`
  (all six footprints at their half-open edges, acceptance one column out,
  critter acceptance inside). Byte-identical output under LuaJIT and
  `tools/bin/lua51`.
- One real headless boot through `tools/luanti_headless.sh` (240 s, fresh
  world): preload start, six completions, 6/6 after 42.6 s, no ERROR.

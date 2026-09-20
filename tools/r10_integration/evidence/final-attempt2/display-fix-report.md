# Capital display placement crash: correction evidence

## Frozen candidate

- Branch: `wp13-r10-engine-gates`
- Base/integration input: `2d3702d4`
- Candidate: `561a9c2b23954947c7dabf09ec409739786610af`
- Candidate worktree was clean after the commit.

## Root cause and correction

`start_npcs.place` sent every socket entity through three mobs_redo-only
post-install helpers. The new `grug_mobs:capital_display` is intentionally a
plain Luanti entity and therefore has `ObjectRef:set_yaw`, but no
`luaentity:set_yaw`. `grug_mobs.face_yaw` consequently failed at
`patrol.lua:66` after the display had already configured its own authored yaw.

The placement path now leaves capital displays with their existing
`configure_capital_display` call, which owns model, floor pose, animation and
`ObjectRef:set_yaw`, and skips the mob-only face/retag/restyle block. Socket
claiming, staticdata, duplicate lease handling and deactivation remain on the
shared path. Ordinary mobs retain `face_yaw`, including its `target_yaw`
overwrite that cancels mobs_redo's pending activation turn.

## Failure witness

- Candidate: `2d3702d4`
- File: `/tmp/grudgelands-r10-final-engines/capitals/highcourt/console.log`
- SHA-256: `1d48c6655851721905039768830c4567ba183d6acb9b7ded6149e6edb31d782f`
- Failure: `patrol.lua:66: attempt to call method 'set_yaw' (a nil value)`
  through `start_npcs.place` and `serve`.

## Focused LuaJIT regression

- File: `/tmp/grudgelands-r10/display-fix-start-npcs.tsv`
- SHA-256: `c9cf28fd726e1396ebaf9d46ece06dba30736c236de53900942325301195b47b`
- Result row: `capital_display plain_entity objectref_yaw configured_once
  mob_pending_yaw_preserved`.
- PUC runtime was deliberately not run; the final integrated pair remains the
  root-owned final-byte gate. Both changed Lua files passed the PUC 5.1 parser.

## Real engine replacement witness

- Output: `/tmp/r10-displayfix`
- Port: `31946`; capital: Highcourt; seed: `531802985935182545`
- Luanti process: `exit=0`, `errors=0`, `complete=1`, 105/105 requests.
- Seven `capital_display` entities were placed: four mount and three gear.
- Services: PASS with 7 stations, 8 profession trainers, 1 riding trainer,
  4 mount displays and 3 gear displays.
- Precinct: PASS.
- SHA-256:
  - `server.log`: `97e9648d4b00efb7db3f9f2b8f0bb9a411399e82b766bf9adfeb70b4be9e6bf1`
  - `highcourt-services.tsv`: `2a0110f297809003aeab697fe4d322797fca164bde3e4cba370f9caa2d4787f0`
  - `highcourt-precinct.tsv`: `a92413801686d6df7dbb7b1dff4d2d52c3dd893ab366661554e61f2d8a97c301`
  - `probe.txt`: `3b9895586121d5cd0c8b7b6594d875e9588d516a84f7461498c8313157d68ce1`

The shell runner returns nonzero after the successful engine/process and probe
completion because the avenue, rampart and gate geometry digests differ from
their committed expectations. Corner matches. This is a separate, unresolved
geometry-attribution gate: the avenue has an accepted inner-layout change,
while the outer rampart and gate differences still require attribution and may
be regressions. It is not a display runtime failure and is not hidden or waived
here.

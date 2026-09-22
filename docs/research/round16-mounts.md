# Round 16 — Mount teardown

Lane A, implemented on `wp16-mounts`; independent review and final combined
interpreter gate pending. Classification: non-trivial lifecycle fix.

## Cause and implementation

The real player API deletes its private player record and attached flag in
`mods/BASE/player_api/api.lua:172`; its animation access asserts that record
exists (`:60`). Both the vendored force-detach callback and the Grudgelands
restore path previously called animation afterward. The latter could also
recreate a visual cache and call player_api through `grug_visuals.apply`.

Both leave/shutdown handlers now explicitly select teardown. They detach and
clear attachment bookkeeping without restoring appearance. Grudgelands keeps
its shared status/warning/controller/child cleanup and hard position/velocity
settlement, but schedules no deferred motion on teardown. Active state is
removed before object removal; the removing flag prevents recursive cleanup.
Normal dismount, damage, death and geographic exits retain appearance restoration.
No ownership metadata, movement speed, asset or first-person behavior changed.

Engine evidence (read-only pinned reference):

- `reference_projects/luanti/src/server.cpp:3153` calls leave hooks before
  `PlayerSAO::disconnected`; the PlayerRef can still settle position/attachment.
- `reference_projects/luanti/src/server.cpp:392` executes shutdown hooks before
  player saves, kicks and environment object deactivation. Shutdown cleanup
  must therefore also tolerate subsequent leave/deactivation callbacks.
- `reference_projects/luanti/src/script/cpp_api/s_server.cpp:152` dispatches
  registered shutdown callbacks; callback success does not grant continued
  ownership of another mod's discarded records.

## Validation

`tools/r16_mounts/lifecycle.lua` returns a function accepting an absolute repo
root. It creates an isolated Lua environment and loads the actual player API,
vendored mount hooks and Grudgelands entity code. Its canonical result is
`mount-lifecycle:12:ok`. Root can add that returned string to the final combined
micro-KAT digest without global pollution.

LuaJIT development result: all 12 cases passed: land/flight times ordinary
logout, reversed vendor/own logout ordering, shutdown, reversed shutdown
ordering, manual dismount and death. Each verifies one controller/child removal,
cleared driver/rider/status/warning/attachment, repeat cleanup and subsequent
leave/shutdown. Ordinary exits verify standing animation and restored racial
scale; teardown verifies no appearance calls and no new deferred callback.
Player data removal comes from the real player_api leave callback, rather than
a test copy of that behavior. Object removal invokes real on_deactivate.

Plain Lua 5.1 parser passed for both changed runtime files and the fixture;
SETGLOBAL inspection found zero writes. All five sweeps passed on those files.
Repository own-mod sweeps also ran: hit counts 1/2/0/244/3, consisting of existing
comments, command/UI strings, and serialized manifest/delimiter strings. The
compiler used was `/home/jan/projects/grudgelands/tools/bin/luac51` because build
artifacts are absent from the isolated worktree. No PUC runtime was executed.

The historical `tools/r9_mounts/mounts_kat.lua` was also attempted but stops at
line 364: its obsolete purchase-immediately-inserts-item assertion conflicts
with the current Skills catalog policy. That unrelated historical fixture was
not changed or counted as passing.

## Limits and review calibration

No GUI, engine session, full world generation, sync or push was performed.
Player ObjectRefs are bounded doubles; real network/save/render behavior remains
in the user playtest. Required final PUC/LuaJIT digest pair belongs to root's
combined frozen-byte runner.

Implementer: native Astra. Independent reviewer: pending. Critical/High findings:
pending. Fix rounds: pending. Observed elapsed wall time: unknown.

User runtime plan: mount each land/flight type, log out and reconnect on foot;
repeat with server shutdown while mounted. Verify normal dismount restores race
size/camera and that no controller, mount child or status icon remains.

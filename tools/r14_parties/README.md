# Round 14 party core fixture

Run `luajit tools/r14_parties/core_kat.lua .` from the repository root.
Run `bash tools/r14_parties/static.sh` for the Lua 5.1 parser, global-write
inspection and all five source sweeps, explicitly including the fixture.

The bounded fixture loads the actual production core with engine/storage/player
stubs. Its 90 checks cover the A/B/C dissolution example, duplicate and expired
invites, incoming cap, per-sender rate including reconnect, opt-out, online-only
invitation sessions, same-world reload with offline leadership, deterministic
succession, explicit transfer, copied views, faction changes, authority changes,
final-slot competition, kick/dissolve and saved HUD preference. Two acceptance
calls execute consecutively because the server serializes Lua callbacks; the
second must observe the first committed membership.

Output is canonical and suitable for the final bounded interpreter parity
fixture. The evidence directory currently contains **development LuaJIT and
static evidence only**. No intermediate PUC runtime was run. Root owns final
review, integrated byte freeze and the one final PUC/LuaJIT pair.

The fixture does not certify native GUI/HUD behavior. After UI integration, use
two clients to invite/accept, inspect both views, disable/re-enable incoming
invites, leave/dissolve, reconnect, and restart with an offline leader.

# Round 14 waiting UI fixture

Run `luajit tools/r14_selection/kat.lua .` from the repository root.
The fixture loads the production character-selection module and checks both
preparation modes, percentage/ETA rendering, unchanged-message suppression,
closing/reopening the waiting form, reconnecting a complete character without
teleporting or re-granting a class, and exactly-once new-character completion.
It uses a fresh player object on reconnect, matching runtime-only armor state.
Native preparation/shutdown evidence belongs to `tools/r14_pregen/`.

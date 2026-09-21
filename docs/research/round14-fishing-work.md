# Round 14 fishing candidate

Author: Root GPT-6 Astra. Independent review and final integration pending.

The existing rod and six catch tables remain authoritative. Right-click casts a
small red/white 3D float, which bobs gently and dips during a 1.5-second bite
window. A right-click during that window settles the catch once and returns the
worn rod stack through the native item callback. Early reeling returns nothing;
a missed bite leaves the line out and schedules another wait. Catches alone
wear the rod; inventory overflow retains the existing dropped-catch behavior.

One 0.2-second throttled pass validates anglers and moves floats. Leaving range,
switching away from a rod, losing the water/entity, death, disconnect and shutdown
remove the ephemeral cast and float. There is no persisted cast, client mod,
fishing profession, lure or new reward table.

`grug_abilities.notify` exposes the existing skill-name HUD row and expiry token.
`Caught: <item description>` appears there, never in chat. New messages replace
old ones; old timers cannot erase a newer notification. Fishing now explicitly
depends on abilities; its dependency closure is acyclic. No competing HUD
coordinates or timers were added for notifications.

## Evidence

`luajit tools/r14_fishing/kat.lua .` drives the actual registered rod callbacks
and server pass: no automatic catch, early and missed bites, successful repeat
bite, two anglers, reward deduplication, returned-stack wear, full inventory,
range/wield/water/death/disconnect/shutdown cleanup and the production HUD
function's latest-message expiry. Lua-5.1 parsing, GETGLOBAL inspection and all
five sweeps pass, including the fixture. Existing ability comment/pipe literals
are false positives. No PUC runtime has been run.

The former `tools/wp13/fishing_kat.lua` models the intentionally replaced
automatic-catch flow and remains historical evidence; Round 14's current
behavioral gate is the fixture above. Native integrated boot and visual float
inspection remain pending. Original float uses engine cube geometry and authored
color-fill textures, with no imported assets.

Runtime test: cast into water, see the float dip, right-click promptly and verify
one catch/HUD text/wear; miss a bite and wait again; reel early; walk away or
change items; repeat with two anglers. Inspect float visibility above water.

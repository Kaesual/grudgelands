# Round 13 STATIONS candidate

2026-09-21. Implementation: native GPT-6 Astra. Independent review: pending
coordinator assignment. Critical/High findings and review fix rounds: pending.
Elapsed wall time: unknown. No merge, sync, push, PUC runtime or mapgen suite.

## Architecture and integration

`grug_jobs/workspaces.lua` owns all station callbacks. Authored public positions
select owner-limited detached inventories backed by per-player serialized node
metadata. A persistent physical-node identity invalidates stale views after
replacement. Every mutation saves concrete itemstrings; node deletion and blast
are denied for authored stations. Player-placed nodes retain shared node inputs,
fuel and automatic outputs. Their qualified craft previews are private detached
views. First successful output transfer consumes one recipe and credits its
qualified collector once; a partial transfer persists its already-produced
remainder per player and physical station. A remainder prevents ordinary digging;
shared station blasts drop it once along with the shared contents.

All detached actions recheck player identity, life, distance, station identity
and area access. Preview eligibility is recomputed from current shared inputs.
Cross-inventory output dragging and shift transfer use normal engine capacity
checks. Output reinsertion and same-inventory output moves are denied. Enchant
operations use a qualified selector and the ENCHANTS package's pure
`grug_items.operation_plan(recipe, inputs, player)` result: exact output ItemStack
and consumed slot counts, committed after main-inventory capacity validation.

`automatic.lua` is the common evaluator for furnace, dual furnace and brewing.
Fuel and cooking progress use elapsed server game time. Shared machines retain
node timers and active-node appearance; personal machines catch up on open and
only tick while viewed. Finite inventory contents bound catch-up, with a 512-event
safety cap. Fuel replacements must fit in output, never spill private items.
Blocked output preserves inputs and unlit fuel; already-lit fuel continues to
expire. Recipe identity includes output, duration and material names. No automatic
process grants profession progress or gates collection by profession.

Alchemy now registers `grug_alchemy:mixture_<potion id>` as the qualified inventory
grid preparation. Each mixture already contains both reagents and its vial;
brewing consumes one mixture plus fuel. Cooking raw dishes/direct dishes retain
their grid gate; automatic finishing has no credit. Simple meat/fish/bread
profession registrations are removed for the coordinator's Basics integration.
Registry recipes expose `automatic_finish`; `can_craft_recipe` treats those
routes as universal while preserving book provenance.

Dependencies at integration:

- Root updates Basics declarations and recipe-book presentation. The isolated
  engine run applies `evidence/catalog-only.patch`, adding the real mixture
  routes and changing only the three simple roasting ownership declarations.
  No startup audit is disabled.
- ENCHANTS supplies the agreed operation catalog and plan API and removes old
  refinement recipes. Actual enchant Apply integration needs the combined branch.
- Root owns authoritative design/BACKLOG/README updates and independent review.

## Evidence

Native Flatpak LuaJIT `2.1.1784272936`: **45 behavioral assertions passed**, then
**5 same-world restart assertions passed**. Each engine invocation had a 45-second
cap, disabled startup preload through the existing probe seam, and requested its
own shutdown. `native-final.log` and `native-restart.log` carry explicit markers.
The first exploratory run had 43 passing assertions; the retained final fixture
adds denied-destination checks and input-specific process identity. The only
production-byte difference between the 45-assertion run and restart was removing
one trailing blank line from Brewing's node definition. All production files in
`final-files.sha256` match the restart's staged game byte for byte.

The fixture uses production jobs registration/progression and workspace/process
code, real engine ItemStack, detached InvRef, node metadata, craft resolution,
fuel replacement, node callbacks and actual database-backed restart. Player
objects, player lookup, protection results and UI display are controlled test
adapters. Inventory callback order is driven explicitly following pinned engine
`src/inventorymanager.cpp`; it is **not a network/client packet test**.

Covered: concurrent eligible/ineligible viewers; callback owner check; denied
output moves/reinsertion; zero and partial destination capacity; one material
debit and one progress credit; remainder close/reopen and profession loss; stale
inputs, range and protection; private player/station isolation; authored dig and
blast refusal; replacement-node invalidation; automatic furnace/dual/brewing
completion; replacement fuel and blocked output; partial thermal progress;
qualified real engine mixture preparation; elapsed personal catch-up; node
identity, finished item, replacement, consumed inputs and process state after
server restart. Mapblock metadata round-trip and actual restart cover persistence;
GUI unload/reactivation and real two-client interaction remain runtime checks.

`static.sh` runs the plain-5.1 parser, SETGLOBAL inspection and five sweeps over
changed Lua plus the production tree. Changed files have no forbidden-syntax
hits; the sole global declaration is the existing `grug_cooking` mod table.
Tree sweep hits are existing comments, literal strings, patterns and embedded
historical manifests. No PUC runtime was executed under the session override.

Reproduce in an isolated game with `PROBE=tools/r13_stations/probe`,
`GAME_PATCH=tools/r13_stations/evidence/catalog-only.patch`, `KEEP=1` and
`tools/luanti_headless.sh 45`; reuse the printed disposable `ROOT` for restart.
The second run must print `R13 STATIONS RESTART PASS`, not only a boot marker.

## User runtime plan

With two clients, open the same player-placed Forge: compare eligible/ineligible
results, change shared inputs while both view, use drag and shift-click, fill the
destination, lose the profession, walk away, close/reconnect and collect a partial
remainder. At two authored stations, verify player isolation and distinct saved
contents; restart/unload while a furnace and Brewing Stand process work. Try
protected access, digging and blast removal. Prepare a mixture as an Alchemist,
finish it as a non-Alchemist, and compare progression before/after both stages.
Repeat with a qualified raw Cooking dish and universal bread/meat/fish. On the
integrated branch apply an enchant to a metadata-bearing/worn item and verify
exact preview, preserved metadata, exact material debit and one progress credit.

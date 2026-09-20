# Round 12 Basics recipe discovery

`grug_jobs/basics_routes.lua` is the frozen exact ownership and presentation
catalog for the current engine registry. Its 830 complete route identities were
captured from a real LuaJIT engine boot with `catalog_probe`; 596 are universal
Basics routes and 234 are profession-owned. Every general route declares either
starter visibility or one concrete/group main material. The production startup
audit rejects missing, stale and duplicate identities before a player opens the
book.

The 73 starter routes include all existing wooden, stone and Bronze universal
tool/weapon routes, including both mirrored Bronze-hoe recipes. The separate
wooden staff and bow starter items have no registered crafting routes, so they
do not appear in this exact route catalog.

Focused LuaJIT fixtures cover the complete declaration set, the five alloy main
materials, all four T1 Bronze armor starters, professional exclusions, mutation
failures, persistent discovery across bags/crafting/trade and station-icon
formspec placement. `catalog_probe` independently enumerates the live engine
registry and asserts the complete 830-route catalog, 596 Basics routes, 73
starters, five alloys, four Bronze armor outputs and real `recipe_for_craft`
Cooking provenance for Bread, Cooked Meat and Cooked Fish.
`furnace_authority_kat.lua` passes those three outputs through the real
extraction wrapper: an unlearned player is denied, while a learned cook can
take them and receives three craft credits.

Run the isolated engine audit with:

```sh
PORT=32348 PROBE="$PWD/tools/r12_recipes/catalog_probe" KEEP=1 \
  nice -n 19 bash tools/luanti_headless.sh 120
```

The final run used Luanti's Flatpak server and reported LuaJIT
`2.1.1784272936`; its catalog is in `evidence/engine-catalog.log`. The first two
sandboxed launcher attempts could not allocate a Flatpak instance id. Running
the same isolated launcher outside the command sandbox succeeded; no game or
user world was used. No PUC runtime or broad suite ran.

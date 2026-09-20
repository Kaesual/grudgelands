# Round 11 equipment implementation evidence

This record binds the approved AFF-GEAR implementation. It is an implementation and evidence record, not a source of new design authority.

## Frozen catalog interfaces

The complete repairable item-price input is `round11-gear-price-catalog.tsv`. Its prices are Common-quality reference purchase prices in copper; Uncommon and Rare multiply the row by 3 and 6. Repair consumes 20% of that quality-adjusted reference price, rounded up. The catalog deliberately excludes bags, quivers, arrows and other items without durability. `docs/design/durability_repair.md` owns the rule and the later repair package consumes this table.

Generated tier items use the six material keys `bronze`, `iron`, `steel`, `silversteel`, `embersteel`, `abyssal_steel`. The active weapon families are `sword`, `dagger`, `greataxe`, `staff`, `wand`, `bow`; shield and spellbook use the same six keys. Armor uses the four slots `head`, `chest`, `legs`, `feet` across the metal, cloth and leather grade ladders already defined in `grug_gear.MATERIALS`. Base shield armor rating is the sum of the same-tier unrefined metal set. Spellbooks provide base Mana 1/1/2/2/3/3. Bags are `bag_small` (8), `bag_medium` (16), `bag_large` (24), `bag_great` (32), plus `bag_leather_pouch` (8), `bag_leather_satchel` (16), `bag_leather_pack` (24), `bag_leather_rucksack` (32). The one quiver is `grug_inventory:quiver`, with four arrow-only stacks. The arrow is `grug_gear:arrow`.

Plain tier bows use both mirrored VoxeLibre bow layouts, translated to same-tier processed wood and thread. Plain tier shields use the VoxeLibre shield layout, translated to same-tier metal and universal wood. The universal arrow route yields 20 from one iron bar, four sticks and four sharp feathers. References: `reference_projects/VoxeLibre/mods/ITEMS/mcl_bows/bow.lua:389`, `reference_projects/VoxeLibre/mods/ITEMS/mcl_bows/arrow.lua:219`, and `reference_projects/VoxeLibre/mods/ITEMS/mcl_shields/init.lua:453`.

## Runtime and review state

Implementation and focused evidence are still in progress. Final commands, immutable input hashes, media gaps, and independent-review status are appended only after the candidate freezes.

Current catalog SHA-256: `417c64d198ab301bce2714564c570c7a6b7ccb3a8a6fcd3879d7435a70fd9273` (155 data rows).

Development validation used LuaJIT only, as required for this package:

```text
luajit tools/r11_gear/final_micro.lua .
find mods/*/grug_* -name '*.lua' -print0 | xargs -0 /home/jan/projects/grudgelands/tools/bin/luac51 -p
find tools/r9_ench tools/r9_prof tools/r10_equip tools/r11_gear tools/wp13 -name '*.lua' -print0 | xargs -0 /home/jan/projects/grudgelands/tools/bin/luac51 -p
```

The current LuaJIT receipt is `tools/r11_gear/evidence/luajit.log`, SHA-256 `56484ba34a7e36138c82e607862fd028725adefc1cb690669f1ac56d69243a3f`. The mod parser gate and the five required Lua 5.1 sweeps passed; sweep hits were existing comments/strings. The only changed-mod `SETGLOBAL` writes are the established `grug_artisans`, `grug_gear`, and `grug_items` module globals.

Final media is pending the Round 11 ART lane. Provisional registrations reuse shipped staff, chest, book, stick and bag images for bows, shields, spellbooks, arrows, quivers and the new bag identities. Independent source review is also pending; this author evidence does not claim it.

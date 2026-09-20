# Round 11 Scout evidence

Date: 2026-09-20  
Branch: `wp11-r11-scout`  
Frozen implementation head: `3d61d55b`

## Delivered contract

- Scout is a mana class with leather rank 2 and per-level growth of +2
  Dexterity, +1 Strength and +1 Intelligence. Its starter set equips the
  below-ladder wooden bow and safely grants one stone sword plus 20 player
  arrows in `main`.
- Loose is a server-authoritative held draw. Release uses the current server
  look direction, a maximum 0.5 second draw modified by Fletching and the
  equipped attack-speed affix, linear impulse/damage, 40 nodes/s maximum
  impulse, gravity and 25 m maximum range. The charge display is quantized to
  ten steps and scans only active draws; compare-first state limits a complete
  draw or cancellation to at most 11 inventory writes.
- Twin Shot reserves two bounded projectile slots before consuming two arrows.
  A spawn or commit failure removes every sibling without hit callbacks and
  releases every opaque active token. Both siblings reuse one REPAIR receipt.
  Refund happens only after successful spawn and returns the whole action cost
  to equipped quiver first, then `main`, with safe world overflow.
- Longshot changes Loose to 33 m and adds four damage beyond 25 m. Snare Shot
  and Pinning Shot apply control only from the shared accepted outgoing-action
  settlement. Dodge, full absorb, PvP refusal, mobs `do_punch` refusal and CMI
  refusal therefore apply no control.
- Sidestep, Sprint, Opening and all 16 Quarry/Veil talents have runtime
  consumers. Shake Loose removes existing roots and negative named movement
  modifiers, preserves positive modifiers, then starts four seconds of the
  existing root/slow immunity. Untouchable persists its 180-second readiness
  timestamp and runs its six-second 25-point dodge / 55% cap window.
- Opening is a main-hand authoritative swing. It resolves its 15% base-mana
  cost once at attempt time, falls back to the ordinary swing when
  unaffordable or in front, and pays/resets only after accepted landed damage.
  Cancelled results do not pay or consume charge.
- Draw state clears on death, disconnect, wield change, true weapon change and
  broken transitions. A REPAIR `durability_metadata` notification refreshes
  the same usable bow snapshot without cancelling the draw. Mounting after
  draw start refuses release before ammunition payment and clears the charge
  display.

## Focused executable evidence

All commands ran from the repository root under LuaJIT. The session's explicit
test override prohibited a PUC runtime process; PUC 5.1.5 was used only as the
required parser and bytecode-listing static tool.

| Command | Result | Boundary exercised |
| --- | --- | --- |
| `luajit -e 'local a,b=dofile("tools/wp11/talent_tree_kat.lua")("."); if a==false then io.write(b); os.exit(1) else io.write(a) end'` | `wp11_talents_result PASS 0` | Real class/talent registries, all 16 Scout consumers, actual cast dispatcher and mana/cooldown path, full/partial held draw, current release aim, Twin/Longshot/refund/failure, Snare/Pinning settlement, lifecycle/mount refusal, Opening direction, Untouchable and actual starter callback |
| `luajit tools/wp39/swing_aim_test.lua .` | `swing_aim_test: ok` | Actual held-swing authority, percentage-mana affordability snapshot, accepted payment, cancelled non-payment, main-hand clock and REPAIR metadata reason |
| `luajit -e 'io.write(dofile("tools/wp11/move_aggregator_kat.lua")("."))'` | `wp11_move_aggregator PASS mutation 0`; `dispel old_negative_removed positive_preserved ok` | Actual movement aggregator: old slow/root dispel, positive Sprint preservation and new slow immunity behavior |
| `luajit tools/wp39/projectile_test.lua .` | `projectile_test: ok` | Active limit/session tokens, partial batch rollback, no rollback callbacks, commit refusal and successful siblings |
| `luajit -e 'io.write(dofile("tools/r11_gear/ammo_kat.lua")("."))'` | pass | Quiver-first consume/refund, main fallback, filled-quiver transfer, atomic refusal and safe refund overflow |
| `luajit -e 'io.write(dofile("tools/r11_gear/quality_kat.lua")("."))'` | pass | Real quality wrapper including forwarding `durability_metadata` through the equipment notification wrapper |

The complete changed Lua set and all `mods/*/grug_*` Lua files passed
`tools/bin/luac51 -p`. `SETGLOBAL` inspection found only the declared mod-table
writes in top-level `grug_abilities` and `grug_projectiles`; loaded subfiles
write no globals. All five `docs/research/luanti-lua.md` grep sweeps were run
against the full first-party mod scope and the changed tools. Hits were
comments, ordinary string separators and the frozen WP40 data manifest; no
prohibited syntax, library call, sandbox call or `minetest.*` use was present.
`git diff --check` passed.

Raw outputs for the focused reruns and final static checks are stored under
`tools/r11_scout/evidence/`. The independently reviewed movement output used
the exact runner shown in the table above and was not redundantly rerun for the
final wear-only correction.

## Frozen hashes

```text
909d9c466bee7cddc77ebe210483dfdb06d0390db9368ad4f8da9942556b0a59  mods/PLAYER/grug_abilities/scout.lua
73ec5773c782c9ef5033cbf89ed57fe4bad7eaae020ecd6b8333922a54eacf94  mods/PLAYER/grug_abilities/init.lua
52cb43d5fff3ac6249ccc20aa000671f4f7673d59c73e3af943c8b820c352c8d  mods/PLAYER/grug_classes/scout.lua
1e2260b152510ffbd2eb826b85cef7ff41486908f5e6e0d17e6dd542d4dcbacd  mods/PLAYER/grug_classes/scout_talents.lua
105175837379288bb8d456abc1909a870b91f24f1f8477c96ffd39a5bd216235  mods/CORE/grug_core/movement.lua
3ac3a04d55f36140da09d2979c08731d78b17c3caaa1596fd72647611f086538  mods/ENTITIES/grug_projectiles/init.lua
0ef7f0e42b09cfb2f24acaf4e55fc56e405e5be27393f9d34a61a310ea953916  mods/PLAYER/grug_inventory/bags.lua
98ab29285c30035298774dc6a3a0fc491c81b4a7756c4db293f2ba19f9c175e9  mods/PLAYER/grug_inventory/equipment.lua
efe4338d94ad4ddaa6f84fdf00848f41d0b7df1017291b692680a1b7f12a3ef8  mods/ITEMS/grug_quality/init.lua
d8f4309c496413a3b5bb5c5d3e835d09934b6aae03cab092d1c332591ad39c0d  tools/wp11/talent_tree_kat.lua
e9b5fa8dfb0d78ddf28a733ebdce139a6d58d03a577b533ff0c74eb87e665776  tools/wp39/swing_aim_test.lua
41803752dc0738bc15b3cb69918334cf9e8c7670ddaad9b28be91b9ea5e605f9  tools/wp11/move_aggregator_kat.lua
4f7f09685876c4a3b8dc57033899117e49b658ef6cf03abdfbd4b3a53eea1af9  tools/wp39/projectile_test.lua
beec9315a13720484ae6d1d85e99a58a1634392f30f5a62c5e3f7cf0892cae90  tools/r11_gear/ammo_kat.lua
9508ee55545e004fdbb32c61b9f3adefd8593d060969c7b578427d283c9e2506  tools/r11_gear/quality_kat.lua
```

## Runtime playtest gate

On a fresh Flatpak Luanti world, create a Scout and verify the equipped wooden
bow, stone sword and 20 arrows. Fire partial and full Loose shots while changing
aim during the hold; verify Twin consumes/refunds two arrows as one action and
Longshot reaches past 25 m. Exercise Snare/Pinning against an ordinary mob and
an immune/fully absorbed target, mount during a draw, swap/break the equipped
bow during a draw, use Shake Loose while rooted/slowed with Sprint active, and
use Opening from the front and rear at both sufficient and insufficient mana.

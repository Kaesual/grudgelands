# Mounts: reference implementations and licences (archived)

Moved out of [mounts.md](../../design/mounts.md) §5 in Round 81 (audit
DD4-04): the ride and attach references studied before `grug_mounts` was
built, with their licence verdicts. `grug_mounts` uses none of these ride
APIs: its controller is its own entity (`grug_mounts/entity.lua`, the player
attached with `set_attach`), and since Round 44 no mount item exists. Kept as
provenance, not as current design.

## Reference implementations & licences (as written before the build)

Three vendored reference projects carry a ride/attach pattern worth
adapting. Licence verdicts per AGENTS.md "Licenses" (project code is
GPL-3.0-or-later):

| Source | What to take | Code licence | Verdict |
|---|---|---|---|
| **mobs_redo** (already vendored as `mods/ENTITIES/mobs`) | the complete ride API | MIT (`reference_projects/mobs_redo/license.txt:1`) | ✓ compatible |
| **Lord-of-the-Test** `lottmobs/horse.lua` | mount-as-purchasable-item pattern | LGPL 2.1 (`Lord-of-the-Test/LICENSE.txt:1`; per-file heritage in `mods/lottmobs/license.txt`: PilzAdam WTFPL, TenPlus1 MIT, LGPL 2.1 contributions) | ✓ compatible |
| **VoxeLibre** `mcl_mobs/mount.lua`, `mobs_mc/horse.lua` | a maintained fork of the same API | GPL-3.0-or-later (`VoxeLibre/LEGAL.md`); `mobs_mc/README.md` names GPLv3 for that mod, and LEGAL.md's dual-licence clause lets us take the game's GPL-3.0-or-later terms instead | ✓ compatible |

- **mobs_redo is the base**: `mount.lua` is already vendored and loaded
  (`mods/ENTITIES/mobs/init.lua`). Its four public helpers are
  `mobs.attach(entity, player)`, `mobs.detach(player)`,
  `mobs.drive(entity, moving_anim, stand_anim, can_fly, dtime)` and
  `mobs.fly(entity, dtime, speed, moving_anim, stand_anim)`; the local
  `force_detach` and the leave/shutdown/die handlers sit at the top of
  `mount.lua`. `drive`'s `can_fly` flag and `fly` are exactly the land /
  flying split of §1.1, and the speed cap is the entity's own
  `max_speed_forward` (read in `mobs.drive`). It **requires the
  `player_api` mod** (the head of `mount.lua` stubs the whole API out
  otherwise) — we vendor it as `mods/BASE/player_api`, so the
  precondition holds.
- **Lord of the Test** shows the acquisition half we need and mobs_redo
  does not have: `lottmobs:register_horse(name, craftitem, horse)`
  (`Lord-of-the-Test/mods/lottmobs/horse.lua:26`) registers a
  **craftitem whose `on_place` spawns the mount entity** (`:31-41`) next
  to a plain `core.register_entity` mount (`:305`) with attach/detach on
  right-click (`:200-222`). Reuse only the item-to-entity registration shape:
  Grudgelands uses the persistent, non-consuming toggle lifecycle of §3 and
  removes the ephemeral entity on every dismount. It must not copy a placed,
  parked or consumed-horse lifecycle.
- **VoxeLibre**'s `mcl_mobs/mount.lua` (`mcl_mobs.attach` at `:52`,
  `detach` `:82`, `drive` `:89`, `fly` `:222`) is the same lib_mount
  ancestry, better maintained; `mobs_mc/horse.lua:226` is the reference
  call site. Use it to cross-check fixes, not as a second base — mixing
  GPL-3.0 code into the MIT-licensed vendored copy would relicense it
  for no gain.

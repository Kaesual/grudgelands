# Round 18 D — Damage-sustained pursuit

Implementation: native Astra, `wp18-evade`. Independent review and the single
final PUC/LuaJIT parity pair belong to the coordinator's integration gate.
No live-world changes, sync, push, or intermediate PUC execution occurred.

## Actor policy frozen before implementation

| Actor authority | Pursuit policy |
|---|---|
| Registered, non-passive normal/elite combat family without an encounter owner | Incoming effective player/guard damage; initial 15-second grace; no distance cancellation |
| Ordinary Zombie, Sun-Dried Husk, Goblin Raider/Slinger/Hound | Same ambient policy; old never-leash flags removed under the coordinator's explicit correction |
| Camp member (`_grug_camp_pos`) | Existing camp leash, home and population counting unchanged |
| Named rare (`_grug_rare_id`) or rare-tier registration | Existing rare leash/route unchanged |
| Boss, royal summon, boss summon; boss-tier registration | Existing encounter bounds and retinue reset unchanged |
| NPC guard, including fixed posts and designated patrols | Existing guard/post/patrol rules unchanged |
| Kraken or explicit royal no-leash actor | Existing bespoke encounter policy unchanged |
| Passive scenery and critter-tier registrations | No combat pursuit opt-in |

The registration wrapper records eligibility and publishes it on the registered
entity prototype before first activation. Group alert can therefore start the
clock before the first custom tick. Runtime encounter owner fields override that
eligibility every time it is read. No camp/rare identity or census was redesigned.
Population-lane ownership was checked before removing the three families' old
flags; C edits neither those family files nor the combat wrapper.

## Implementation and engine boundaries

- `grug_damage_at` lives only in `self.temp`. First `do_attack` seeds it once;
  target changes, Taunt and outgoing attacks do not refresh it. Legacy contact
  timestamps remain available exclusively to the unchanged bounded policy.
- The vendored `on_punch` reports the **actual health subtraction**, after
  `do_punch`, CMI, rounding, immunity and friendly-fire decisions. Only a player
  or a registered monster-attacking NPC guard can refresh the clock. Damage
  ticks through the ordinary ability punch settlement qualify; environmental
  damage and zero-rounded hits do not. This seam adds no tag, threat, XP or loot.
- The same ambient predicate removes the 40m threat validity radius, 45m target
  drop, 25m chase-speed penalty and LOS patience cancellation. Connected/alive
  player validity, available object positions, target HP and invisibility remain
  native checks. There is no new terrain loading or distant-object scan.
- The existing one-second leash pass handles timeout at >=15 seconds, resets
  threat/tap/HP, and enters the existing untouchable return beyond the existing
  four-node arrival radius. Permanent `_grug_home` is never moved. Existing
  straight-line return, 1.5x speed and >40-second fallback remain intact.
- PUC-compatible `math.huge` is only a local comparison sentinel; no infinite
  entity field enters serialization.

Read engine evidence: `reference_projects/luanti/src/script/lua_api/l_object.cpp`
`ObjectRef::l_punch` (199–223) invokes the active object's punch synchronously.
The vendored `on_punch` owns actual mob HP subtraction; `check_for_death` may
remove the object immediately, so the new notification precedes it. Vendored
`mob_activate` resets `self.temp`, and `clean_staticdata` omits it, preserving
normal current-version unload behavior without a saved combat clock.

Three new in-place patch markers are recorded in `VENDOR.md`. The existing
source-reference symlinks in this isolated worktree were read only and are not
part of the commit.

## Verification

`tools/r18_evade/micro.lua` returns a function accepting the repository root.
It loads real Core combat, the complete mob adapter (unrelated content imports
suppressed), aggro, the complete vendored API and all three changed family files.
Engine APIs and unrelated registration dependencies use bounded doubles.

Invocation for root's combined final fixture:

```lua
print(dofile(repo .. "/tools/r18_evade/micro.lua")(repo))
```

LuaJIT development result: PASS. Covered registration tiers and initial prototype
policy, each runtime owner exclusion, 60-second/6000-node sustained pull, distant
threat switch, Taunt-only expiry at 15 seconds, return inside the previous 40m
radius, home arrival, >40-second fallback, guard-only combat without player tap,
dead target, dead mob, temporary pack flight without instant healing or paused
expiry, bounded camp pull, native distance/LOS target handling,
accepted player/guard damage, canceled hits, immunity, fractional zero rounding,
friendly-fire refusal and fresh runtime-clock initialization.

`python tools/r18_evade/static.py`: PASS parser for eight files; expected global
writes only (`grug_mobs`, vendored `mobs`, fixture globals). All five sweeps include
all owned mods plus the portable fixture and changed vendor file. Matches are
comments, strings/manifest data, and one pre-existing permitted vendored
`minetest.is_protected` alias; no new prohibited Lua construct. Full logs are in
`tools/r18_evade/evidence/`. No PUC runtime was run in this lane.

Standalone doubles do not prove in-engine terrain return or real unload/reload.
User runtime plan: pull a normal wolf/Zombie/Husk with periodic damage well past
40m; cease damage and observe return after about 15 seconds, immunity while
returning and the fallback when blocked. Repeat near a guard, verify no player
loot from an untagged guard-only kill, and spot-check that a camp/rare/fixed guard
still obeys its prior bound. Re-enter after a normal unload to confirm the mob
is attackable and a new fight receives its initial grace.

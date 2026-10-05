# C7 — Combat and progression

**Scope.** `mods/PLAYER/grug_abilities/` (5,701 lines: `init.lua` 2,706,
`kits.lua` 1,123, `input.lua` 769, `scout.lua` 610, `blink.lua` 253,
`crosshair.lua` 229, `strike_delay.lua` 11), `grug_classes/` (3,385 lines),
`grug_xp/` (302), `grug_skills/` (239), `grug_pvp/` (858), `grug_parties/`
(725), `grug_factions/` (389), `grug_trinkets/` (174). About 11,800 lines in
total.

**Baseline.** `0f169898` (main). The working tree had no changes under `mods/`
against the baseline when I checked (`git diff --stat 0f169898 -- mods/` was
empty).

**Method.** I read these files in full: `grug_abilities/init.lua`, `kits.lua`,
`input.lua`, `scout.lua`, `crosshair.lua`, `strike_delay.lua`;
`grug_classes/init.lua`, `stats.lua`, `perks.lua`, `scout.lua` and
`selection.lua`; the runtime half of `talents.lua` (lines 1–400 and 780–1369);
`grug_xp`, `grug_pvp` (all files), `grug_parties` (all files), `grug_factions`,
`grug_trinkets` and `grug_skills`. I skimmed `blink.lua` (geometry only), the
talent data rows in `talents.lua` and `scout_talents.lua`, and the top of
`talents_ui.lua`.

To trace the damage pipeline end to end I also read the seams these mods
depend on:
- `grug_core/combat.lua`: level scalars, armor, the accumulators, the
  authoritative-swing token, `deal_ability_damage`, `heal_player`, absorbs,
  the central hp-change modifier;
- `grug_core/combat_ray.lua` (`aim_raycast`, `combat_ray`);
- the `on_punch` player-melee patch in `mods/ENTITIES/mobs/api.lua`
  (lines 3215–3600);
- `grug_repair/runtime.lua`, `grug_quality/init.lua` lines 960–1100,
  `grug_inventory/equipment.lua` lines 190–230 and 655–700, and
  `grug_visuals/apply.lua` lines 380–500;
- the engine: `PlayerSAO::punch`/`setHP`, builtin `knockback.lua` and the
  `hp_max` clamp in `c_content.cpp`.

One LuaJIT micro-benchmark, in my scratch directory: `grug_xp.level_from_xp`
costs about 50 ns per call at level 60 under LuaJIT. That is negligible; the
meta read around it dominates.

**Out of scope** (other lanes): `grug_core` beyond the seams above, the
`mobs_redo` AI, `grug_mobs` threat/aggro, `grug_projectiles` internals,
`grug_visuals`, `grug_inventory` and `grug_repair` beyond the call chains
quoted here. Findings that cross into those lanes say so.

## Summary

- **The damage pipeline has one owner per step, and I found no double
  application.**
  - Level scaling: `scale_player_damage`, once per transaction.
  - Crit: once. `deal_ability_damage`, `roll_melee_crit` in the PvP handler,
    or the `mobs/api.lua` patch.
  - Dodge: once. Abilities pre-roll it and the central modifier skips while
    `in_ability_punch` is set.
  - Armor: once. The PvP swing applies it itself and tags
    `ARMOR_APPLIED_CUSTOM_TYPE`.
  - Absorb, then the PvP contact report, both in the single hp-change
    modifier (`grug_core/combat.lua:1783`).
  - Every other `register_on_player_hpchange` in the tree is a non-modifier.
    It must predict HP as `get_hp() + hp_change`, because the engine has not
    stored the value yet.
- **Swings are a two-phase, single-token transaction.**
  - `attempt_swing` (`grug_abilities/init.lua:1257`) builds the whole scaled
    amount and opens a global token (`grug_core.begin_authoritative_swing`),
    then punches.
  - The mob patch or the PvP handler claims the token. `finish_*` pays the
    proc cost, resets the charge and grants rage only after the hit was
    accepted.
  - Native client punch packets are input only. Tools and fists never deal
    native damage, either to mobs (`mobs/api.lua:3246`) or to players
    (`init.lua:2259-2267`).
- **Since that change, most of the WP38 "proportional tool/fist" machinery is
  unreachable.** The remainder accumulator, the wear accumulator and the
  ordinary-input clock coupling remain, along with the comments describing
  them as live (CMB-03).
  - The one path that still reaches the accumulator is a misroute: the
    Strike fallback in PvP (CMB-01).
- **Every landed or received hit triggers a full `on_equipment_change`
  fan-out**, through the durability writer. That is the costliest per-hit
  path in this area (CMB-02).
- **All per-player runtime state is cleared on leave**; I checked every table
  in these eight mods. Nothing in scope leaks.
  - Ability cooldowns, mana, rage, charges and absorbs are session-only.
    Talent, trinket and PvP timers persist in player meta via `os.time()`
    (CMB-10).
- **Stats are derived on demand, not cached.** `get_attributes` reads level
  and class from meta on every call. Talents are parsed once and cached per
  player.
  - `grug_quality` monkey-patches four `grug_classes` accessors, and
    `grug_core` stubs are overridden in two or three layers (CMB-05).
- **PvP follows the design.** One flag per player, both sides flagged, the
  button plus geography, logout death, and kill credit within 15 s
  (`grug_pvp/rules.lua`).
  - Kill XP is split by participation, not by party.
    `docs/design/progression.md:171` says "Party membership confers no
    automatic credit", so `grug_parties` has no XP role at all.
- **No ability in scope changes the world** (no `set_node`, fire or
  explosion), so the terrain damage guard does not apply.
- **Faction naming is clean.** No "Alliance" or "Horde" anywhere in `mods/`.
  One admin-command wording leftover remains (CMB-15).

## Findings table

| ID | Sev | Category | Title | Location |
|---|---|---|---|---|
| CMB-02 | High | Perf | Every landed or received hit runs the full equipment-change fan-out (durability write) | `grug_repair/runtime.lua:33-55,142-161` → `grug_abilities/init.lua:1923-1965` |
| CMB-01 | Medium | Bug | PvP Strike fallback (Loose or a cast skill wielded) takes the legacy proportional path: loses `melee_damage_add`, durability, trinket proc | `grug_abilities/init.lua:2259,2312-2411` |
| CMB-03 | Medium | Legacy | WP38 tool/fist accumulator, wear accumulator and ordinary-input clock are unreachable (≈300 lines plus misleading comments) | `grug_core/combat.lua:1098-1209,1257-1269,1353-1413`; `grug_abilities/init.lua:1456-1483,2292-2297,2372-2411` |
| CMB-04 | Medium | Bug | Builtin engine knockback still fires on refused or suppressed player punches, and at full strength on every PvP cast | `grug_abilities/init.lua:2216-2221`; builtin `knockback.lua` |
| CMB-05 | Low | Agent-trap / Duplication | Combat accessors are monkey-patched across mods; the armor-rating formula exists twice | `grug_quality/init.lua:1028-1095`; `grug_inventory/equipment.lua:673-681` |
| CMB-06 | Low | Bug | Lowering `hp_max` with an active shield eats shield points (`set_hp` reason is absorbed) | `grug_classes/stats.lua:173-188`; `grug_core/combat.lua:1881-1908` |
| CMB-07 | Low | Bug | Player nametag shows a stale max HP after gear, talent or buff changes | `grug_factions/init.lua:105-137` |
| CMB-08 | Low | Perf | Party HUD calls `get_properties()` per member per member every 0.5 s | `grug_parties/init.lua:120-135`, `hud.lua:136-149` |
| CMB-09 | Low | Perf | The 20 Hz input pass reads the wielded stack three times and runs a combat ray every pass while LMB is held | `grug_abilities/init.lua:2447-2462`; `input.lua:443-568` |
| CMB-10 | Low | Bug / Design | Relog resets every ability cooldown and refills mana; talent and trinket ICDs persist | `grug_abilities/init.lua:2598-2600,2638-2641` |
| CMB-11 | Low | Duplication | Persisted-ICD and "below X % after a punch" triggers are hand-written four and three times | `talents.lua:1036-1043,1108-1126`; `classes/scout.lua:58-76`; `grug_trinkets/init.lua:75-89,113-125` |
| CMB-12 | Low | Agent-trap | Stale consumer map in `EFFECT_KEYS`; `post(context)` handed to a parameter named `action_id` | `talents.lua:50-115`; `kits.lua:392`; `init.lua:1227-1229` |
| CMB-13 | Low | Bug | Mend ticks on a global 3 s phase, not from the cast | `kits.lua:980-1009` |
| CMB-14 | Low | Bug | Loose tooltip promises a target requirement and a fixed 2.5 s draw that the code does not have | `scout.lua:496-498` |
| CMB-15 | Low | Naming | `/faction` prints the raw id ("the accord faction") | `grug_factions/init.lua:351,358` |
| CMB-16 | Low | Perf | `guard_destinations()` walks every registered node on each Skills page render and each join | `grug_skills/bound_items.lua:74-81`, `page.lua:111` |

Counts: High 1, Medium 4, Low 11, plus Noted items below.

## Findings

### CMB-02 Every landed or received hit runs the full equipment-change fan-out
- **Severity:** High. **Category:** Perf. **Confidence:** Verified (call
  chain traced); cost magnitude Plausible (not measured in the engine).
- **Location:** `mods/ITEMS/grug_repair/runtime.lua:33-55` (`wear_stack`) and
  `:142-161` (the settled-action hooks), feeding
  `grug_inventory.equipment_changed(player, list, "durability_metadata")`.
- **What:** Two hooks wear an item and call `equipment_changed` on every
  combat event:
  - `register_on_settled_outgoing_action` runs for every landed swing
    (`finish_authoritative_swing`, `init.lua:1197`), every accepted cast
    (`combat.lua:1523`/`997`) and every in-combat heal.
  - `register_on_settled_incoming_hit` runs for every non-lethal punch a
    player takes, mob hits included.

  Both call `wear_stack`, which always does `inv:set_stack` and then
  `equipment_changed(player, list, "durability_metadata")`. That reaches all
  eight `register_on_equipment_change` consumers:
  - `grug_classes.apply_stats`: `get_pool_breakdown` plus `get_properties()`.
  - `grug_abilities` (`init.lua:1923-1965`):
    - `clamp_mana` and `hud_update`, which does another `get_properties()`.
    - `sync_descriptions`: walks `main` plus all four bag lists, up to about
      128 `get_stack` ItemStack allocations. It also re-runs every ability's
      `description_for`, with talent and attribute reads and
      `string.format`. It runs before the irrelevant-list early return, so
      armor wear pays it too.
    - for weapon lists, a second full walk in `sync_skins`, with
      `apply_swing_caps` (`swing_stats` plus `%.17g` formatting) per ability
      stack.
  - `grug_visuals.apply` (`apply.lua:490-495` → `:412`): an **unconditional**
    `player:set_properties({visual_size = ...})`. That marks the properties
    unsent, so the engine re-broadcasts the whole object-property packet to
    every client that sees the player.
  - `grug_inventory.refresh`: no-op unless a page is open. The
    `grug_quality` aggregate cache and the `grug_inventory` slot/armor caches
    are dropped, so the next crit or dodge read re-parses every equipment
    affix.

  The comment at `init.lua:1891-1893` says "No globalstep or cast path calls
  this". Indirectly, every hit does.
- **Impact:** The cost scales players × hits per second. Each fighting player
  produces one event per landed action plus one per hit taken, typically
  2–5 per second. Each event costs two inventory walks, about six tooltip
  rebuilds, two to three `get_properties()` calls, a property packet times
  the number of observers, and an inventory-list packet. Players see nothing;
  the server and the network pay it in exactly the situations where load is
  highest (group fights, PvP, boss arenas).
- **Better (effort S–M):** Stop notifying a full equipment change for a
  same-stack wear write.
  - Option 1: `grug_repair` notifies only when the broken state flips. The
    `set_stack` already refreshes the item's own tooltip, wear bar and
    client view.
  - Option 2, if a notification must stay: use a distinct reason
    `durability_broken`. Have `grug_abilities`, `grug_classes`,
    `grug_quality`'s cache drop and `grug_visuals` return early on plain
    `durability_metadata`.
  - Separately (visuals lane), guard the `visual_size` write by value.
    Mount detach can be handled by its own re-apply.
  - The contract already exists in `equipment.lua:201-202` ("consumers must
    still treat a broken-state transition as a concrete change"), so this is
    plumbing, not design.
  - Measure before and after with a stand-in fight probe (R30/R32 style).
  - Risk: a broken weapon must still update skins, the swing clock and
    stats. Test the break transition explicitly.
- **Verification (phase 2):** Partly confirmed — the CPU chain is real (`grug_repair/runtime.lua:49-52` → grug_quality wrapper `init.lua:1019-1024` → `equipment.lua:207-214` → seven consumers; only grug_gear `init.lua:809`, the abilities swing-clock branch `init.lua:1944` and Scout `scout.lua:475` read the reason, trinkets and visuals filter by list only), but the network amplification is wrong: the engine's `set_properties` only marks properties unsent when the struct actually changed (`reference_projects/luanti/src/script/lua_api/l_object.cpp:1027-1032`, since c524c52ba), so the unchanged `visual_size` write sends nothing, and the Character formspec is deduplicated (`l_object.cpp:1748`); the only per-event packet is the inventory resend any wear write needs. Estimate (engine calls counted, ~0.5 µs per `get_stack`, 1.6 µs per `get_properties` from upstream-workarounds.md, ~6–12 µs LuaJIT `-joff` for the ~3 KB Character string): about 0.25–0.5 ms per weapon-wear event (two 96–128-slot walks dominate) and 0.15–0.3 ms per armour-wear event, i.e. O(players × hits) CPU only, still High at the 100-player target. Correction: `grug_inventory.refresh` is not a no-op when closed; it rebuilds whenever the *selected* sfinv page is Character, the homepage (`pages.lua:549,574-580`). Same verdict as PLY-01, CORE-01, ITM-01.

### CMB-01 PvP Strike fallback takes the legacy proportional path
- **Severity:** Medium. **Category:** Bug. **Confidence:** Verified (traced).
- **Location:** `mods/PLAYER/grug_abilities/init.lua:2259` (`local selected =
  selected_swing_def(hitter)`) and `:2312`
  (`authoritative = authoritative_token ~= nil and selected ~= nil`), then
  the "ordinary" branch at `:2372-2411`.
- **What:** `input.lua` falls back to Strike in two places:
  - `:379`: a refused swing skill.
  - `:382-384`: a cast skill whose cast is refused, which includes **every**
    LMB press with Loose wielded (`castable` excludes `loose`, `:168-171`)
    and held LMB with Fireball/Smite between cast intervals.

  The fallback calls `attempt_swing(player, Q.registered.strike, ...)`,
  which opens a valid token. But the PvP handler re-derives "selected" from
  the **wielded item**. For Loose or a cast skill that is `nil`, so a claimed
  authoritative token is treated as an ordinary tool/fist packet:
  - Damage is recomputed as `fleshy + get_melee_bonus` and scaled. The
    transaction's `scaled_damage`, which includes `melee_damage_add` (Scout
    "Fine Edge", up to +20 % of a base hit), is ignored.
  - The damage then goes through the remainder accumulator, carrying a
    fraction across swings.
  - `finish_native_melee` is never called, so no
    `run_settled_outgoing_action` (no weapon durability), no
    `trinket_weapon_hit` (Battlebeat rage) and no proc settlement. The
    prepared context is simply dropped.

  The PvE path (`mobs/api.lua:3353`, `3386-3395`) uses the token's context
  and is correct.
- **Impact:** A Scout fighting another player in melee with Loose in hand,
  which is the designed "LMB = Strike" setup, deals less than the tooltip
  says and wears no weapon. A Warrior or Mage hitting with Strike while a
  cast skill is selected gets no Battlebeat procs. PvP only; PvE is
  unaffected.
- **Better (effort S):** In the PvP handler, decide "authoritative" from the
  claimed token alone. `prepare_authoritative_swing` already ignores
  `selected`. Use the token's context for damage and finish, as the mob
  patch does. Then delete the ordinary branch (see CMB-03). Re-run the
  `tools/r31_pvp` PvE micro run as AGENTS.md requires for combat-path
  changes.
- **Verification (phase 2):** Confirmed — `input.lua:382-384` falls back to `api.swing(strike)` for Loose (`castable` excludes it, `:168-171`) and for refused casts; the PvP handler re-derives `selected` from the wielded item (`init.lua:2259`, `selected_swing_def` `:1131-1135` returns nil for `kind = "cast"`), so `authoritative` is false (`:2312`) and the claimed token goes through the accumulator branch (`:2372-2411`) without `finish_native_melee`, i.e. no settled outgoing action (no durability), no Battlebeat and no proc settlement. Damage loss is just `melee_damage_add` (attempt_swing passes `tflp = fpi` and `fleshy = weapon_damage`, `:1421`, so fraction = 1 and the same scalar applies); rage is still granted via `committed_fraction`.

### CMB-03 The WP38 tool/fist accumulator machinery is unreachable
- **Severity:** Medium. **Category:** Legacy. **Confidence:** Verified (greps
  over `mods/` plus traced guards).
- **Location:**
  - `grug_core/combat.lua`:
    - `1098-1209`: remainder accumulator (`prepare_/commit_/apply_accumulated_melee`).
    - `1257-1269`: ordinary-input seam.
    - `1353-1413`: per-stack wear accumulator with `SecureRandom` ids.
  - `grug_abilities/init.lua`:
    - `1456-1483`: ordinary input handler.
    - `2292-2297`: `if not authoritative_token`, after an earlier `return`
      for exactly that case.
    - `2268-2278`: same-faction ally targeting, only reachable with a token
      that `valid_target` never issues.
    - `2372-2411`: proportional PvP branch.
    - The `entry.ordinary` bookkeeping and the `applied ~= nil` branch at
      `2183-2184`.
  - `mobs/api.lua`: `3332-3335`, `3456-3461`, `3584-3592`.
- **What:** Two vetoes make the code above dead:
  - `mobs/api.lua:3246-3250` returns for every non-authoritative,
    non-ability player punch on a grug mob.
  - The PvP handler returns `true` for every unclaimed packet
    (`init.lua:2260-2267`).

  `grug_melee and not grug_authoritative` therefore never reaches the
  accumulator or wear block. Authoritative caps carry
  `punch_attack_uses = 0`, so wear is 0 for them too. The only live entry is
  the CMB-01 misroute.
- **Impact:** None at runtime, but about 300 lines of subtle code describe
  themselves as live ("Ordinary hostile tool/fist PvP is unchanged…",
  `init.lua:2372`). Every combat change has to reason about states that
  cannot occur. Two prior incidents were in exactly this code: the
  input-recursion bug noted at `mobs/api.lua:3218-3224` and the wear bug
  noted at `combat.lua:1493-1505`.
- **Better (effort M):** After fixing CMB-01, delete the accumulator, the
  wear accumulator, the ordinary-input seam and handler, the `ordinary`
  field, and the dead PvP branches. Keep `reset_accumulated_melee` callers
  only if something else needs them; nothing does today. Coordinate with the
  ENTITIES lane for the `mobs/api.lua` GRUG PATCH blocks and VENDOR.md
  markers. Run the r32/r35 fixtures afterwards.
- **Verification (phase 2):** Confirmed — the native-swing-input handler returns true unconditionally (`init.lua:1444-1450`), so every unclaimed player punch on any mob returns at `mobs/api.lua:3233-3236` (the `:3246-3250` veto is a second, redundant gate) and the PvP handler returns at `init.lua:2260-2267`; `apply_accumulated_melee` has no caller, `handle_ordinary_melee_input` is reached only from dead branches (`mobs/api.lua:3334`, `init.lua:2296`), and the wear accumulator needs `wear > 0` while authoritative caps carry `punch_attack_uses = 0`. The CMB-01 misroute is the only live entry into `prepare_accumulated_melee`.

### CMB-04 Builtin knockback fires on refused punches and on every PvP cast
- **Severity:** Medium. **Category:** Bug. **Confidence:** Verified (engine
  source).
- **Location:** `grug_abilities/init.lua:2216-2221` (the "deferred" note);
  the engine's `builtin/game/knockback.lua`; `PlayerSAO::punch`
  (`src/server/player_sao.cpp:473-481`).
- **What:** Builtin registers its own `on_punchplayer`. MODE_OR runs every
  callback, and the knockback uses the engine's pre-callback
  `hitparams.hp`. Returning `true` suppresses the damage but **not** the
  push. Consequences:
  1. Any player can push any other player with a refused punch: allies,
     unflagged enemies, players in town. This needs a wielded item with
     `fleshy > 0`: the bare hand (1, about 1.4 m/s) or a weapon carried in
     the hotbar (4–6, about 4–6 m/s). Gathering tools are 0 and ability
     items are 0, so they don't push.
  2. `deal_ability_damage` punches players with `fleshy = amount` (already
     scaled), so every PvP Fireball, Smite, Nova or arrow pushes at the
     curve's maximum (about 8–8.8 m/s).
  3. Mob melee on players (`mobs/api.lua:3047`) pushes with the mob's raw
     `self.damage`.

  `docs/design/combat_stats.md:522-547` says knockback is "player melee
  swings only" and "Casts, Charge, arrows, mob hits and every other punch
  carry no implicit knockback". That passage is written about mobs; for
  players nothing is decided.
- **Impact:** Point 1 is player-visible griefing: shoving allies or enemies
  off ledges in peaceful towns. Point 2 makes PvP casters displace targets
  far more than melee does.
- **Better (effort S):** Override `core.calculate_knockback` once (it is the
  documented mod hook; `player_api` and `boss_dragons` already wrap it). Pass
  only what the design wants. The minimum is 0 when the punch was refused or
  suppressed (no claimed token and no `in_ability_punch`). Probably also 0
  for casts, pending Jan's answer (open question 1).
- **Verification (phase 2):** Confirmed — builtin registers its `on_punchplayer` before any mod and MODE_OR runs every callback (`s_player.cpp:63`), feeding `calculate_knockback` the pre-callback `hitparams.hp` (`player_sao.cpp:473-481`); the hand keeps `fleshy = 1` (`default/tools.lua:8-18`, only `groupcaps` overridden at `input.lua:690-694`) and `deal_ability_damage` punches with `fleshy = amount` (`combat.lua:1507-1511`), so refused punches push ~1.4 m/s and casts ~7–8.8 m/s. Only wrappers: `player_api/api.lua:199-205` (zero for attached riders) and the dragon slam flag.

### CMB-05 Monkey-patched combat accessors; the armor formula exists twice
- **Severity:** Medium. **Category:** Agent-trap / Duplication.
  **Confidence:** Verified.
- **Location:**
  - `grug_quality/init.lua:1028` (`get_equipment_pool_percent`), `1053`
    (`get_attributes`), `1063`/`1069` (crit and dodge raw), `1094-1095`
    (`grug_core.get_armor_rating`).
  - `grug_inventory/equipment.lua:673-681`: a second
    `grug_core.get_armor_rating` with the same Unbroken multiplier and
    talent terms, shadowed by grug_quality.
  - `grug_classes/stats.lua:196-201`: `grug_core` aliases captured as
    function values.
- **What:** The player stat surface is assembled by load-order overrides
  across three modpacks:
  - `grug_core` stub → `grug_classes` / `grug_inventory` → `grug_quality`
    wrapper.
  - The aliases work only because the wrapped functions are the *raw*
    accessors, which `get_crit_chance`/`get_dodge_chance` look up
    dynamically. An agent who wraps `grug_classes.get_crit_chance` instead
    would be silently bypassed by `grug_core.get_crit_chance`, which still
    holds the old function value.
  - The armor formula is written twice; editing the `grug_inventory` copy
    has no effect.
  - The `grug_core/combat.lua:185-186` comment names only grug_inventory as
    the overrider; grug_quality's later override is the one that wins.
- **Impact:** Edits land in the wrong place with no error. Typical traps:
  adding an armor term to `grug_inventory`, or wrapping the capped accessor.
- **Better (effort S–M):**
  - Delete the `grug_inventory` armor fallback; grug_quality always ships.
  - Turn the stat surface into explicit contributor registries:
    `grug_classes.register_attribute_source(fn)`, an armor-term list in
    `grug_core`, and so on, instead of wrappers.
  - Until then, add a one-line "overridden by grug_quality" comment at each
    patched definition.
- **Verification (phase 2):** Confirmed, severity changed to Low — the overrides are as described (`grug_quality/init.lua:1019-1095`, `grug_inventory/equipment.lua:673-681`, aliases `grug_classes/stats.lua:196-201`), and grug_quality's `depends` on grug_inventory makes the shadowing deterministic; but the grug_inventory copy is labelled "Base fallback until grug_quality adds shield and affix rating" (`equipment.lua:672`), and the alias trap needs an agent to wrap the capped accessor, so it is a maintainability note rather than a live risk.

### CMB-06 Lowering `hp_max` with an active shield eats shield points
- **Severity:** Low. **Category:** Bug. **Confidence:** Verified (engine
  `c_content.cpp:344-347`, `player_sao.cpp:511-526`).
- **Location:** `grug_classes/stats.lua:173-188` (`apply_stats`);
  `grug_core/combat.lua:1881-1908` (absorb block).
- **What:** When `hp_max` drops below the current HP, the engine itself calls
  `setHP(hp_max, SET_HP_MAX)` (type `"set_hp"`). This happens on unequipping
  +HP % gear, a respec, or a pool buff expiring. The central modifier absorbs
  any negative non-bypass change, so the shield soaks the excess. The engine
  clamps to `hp_max` anyway, so the HP result is identical and only the
  shield is lost. The explicit `set_hp(max_hp)` in `apply_stats` is
  redundant.
- **Impact:** A Priest shield or Glacial Ward silently shrinks during a gear
  swap or a buff expiry, and shield particles play.
- **Better (S):** Make `bypasses_absorb` (or the modifier) skip `reason.type
  == "set_hp"` without a `custom_type`, or skip only reasons from SET_HP_MAX
  if they can be told apart. Drop the redundant clamp in `apply_stats`.

### CMB-07 Player nametag shows a stale max HP
- **Severity:** Low. **Category:** Bug. **Confidence:** Verified.
- **Location:** `grug_factions/init.lua:105-137`.
- **What:** `refresh_player_tag` runs on hp change and level change only.
  `apply_stats` raises `hp_max` on equipment, talent and status changes
  without an hp change, so "Name [Lv] hp/hp_max" keeps the old maximum until
  the next hit or heal.
- **Better (S):** Call `grug_factions.refresh_player_tag` from
  `apply_stats` when `hp_max` changed. It is the single writer.

### CMB-08 Party HUD: `get_properties()` per member per member every 0.5 s
- **Severity:** Low. **Category:** Perf. **Confidence:** Plausible (cost not
  measured).
- **Location:** `grug_parties/init.lua:120-135` (`view`: `row.hp_max =
  member:get_properties().hp_max`), polled by `hud.lua:136-149` for every
  party member every 0.5 s.
- **What:** A full party of 10 builds 10 views of 10 rows each, so 100
  `get_properties()` calls per 0.5 s. Each one converts the whole
  ObjectProperties struct (textures, boxes, colors) into a Lua table. The
  view also does a meta read for level and class per row.
- **Better (S):** Cache `hp_max` in `grug_classes.apply_stats` (the only
  writer) and expose `grug_classes.get_hp_max_cached(player)`. The same
  cache serves `grug_abilities` `hud_update` (`init.lua:413`), the nametag,
  and the "below X %" triggers (CMB-11).

### CMB-09 The 20 Hz input pass repeats reads and casts a ray per held pass
- **Severity:** Low. **Category:** Perf. **Confidence:** Plausible.
- **Location:** `grug_abilities/init.lua:2447-2462`; `input.lua:443-568`.
- **What:** Every player costs the following each 0.05 s, idle or not:
  - `input.step`: `get_player_control`, plus the wielded item twice (`item`
    and `api.selected`) and an `is_unlocked` meta read.
  - `selected_swing_def`: a third wielded-item read and a second
    `is_unlocked`.

  With LMB held on a foe, the pass also runs `combat_hit` (a full
  `combat_ray`: engine raycast plus `get_objects_in_area` over the ray box,
  then Lua box tests) 20 times a second. On a due swing, `attempt_swing`
  casts its own second ray in the same pass. Also, `hand_diggable`
  (`input.lua:157`) rebuilds `ItemStack(""):get_tool_capabilities()` on
  every held-gather pass.
- **Impact:** Small per player. About 60 ItemStack allocations per second per
  player plus 20–40 rays per second per fighter. It scales with players.
- **Better (S):**
  - Read the wielded stack once per pass and hand it to `input.step` and the
    reticle check.
  - Let `attempt_swing` reuse the pass's `combat_hit` ray when called from
    the same step.
  - Cache the hand capabilities after `on_mods_loaded`.
  - Measure with the R30 crosshair probe.

### CMB-10 Relog resets every ability cooldown and refills mana
- **Severity:** Low. **Category:** Bug / Design. **Confidence:** Verified.
- **Location:** `grug_abilities/init.lua:2598-2600` (join: `rage = 0`,
  `refill_mana`) and `2638-2641` (leave clears `cooldowns`, `charges`,
  `cast_intervals`).
- **What:** By the file header's rule, ability cooldowns and resources are
  runtime state. Logging out and back in therefore resets Sprint (300 s),
  Hold Ground (60 s), Shield and the others, and refills mana. Talent ICDs
  (`talents.lua:1036-1043`, `1119-1122`), trinket cooldowns
  (`grug_trinkets/init.lua:75-89`) and PvP timers persist in meta via
  `os.time()`. Logout in PvP combat is death, so PvP can't use this; PvE
  boss attempts can.
- **Better (S):** Decide (open question 2). If cooldowns should survive,
  store the expiries of cooldowns ≥ 30 s as `os.time()` deadlines in meta,
  following the trinket pattern.

### CMB-11 Persisted-ICD and "below X % after a punch" triggers written several times
- **Severity:** Low. **Category:** Duplication. **Confidence:** Verified.
- **Location:**
  - The same `os.time()` meta-ICD pattern, four copies:
    `grug_classes/talents.lua:1036-1043` (`talent_trigger_ready`),
    `talents.lua:1119-1122` (Unbroken), `grug_classes/scout.lua:69-75`
    (Untouchable), `grug_trinkets/init.lua:75-89` (`cooldown_ready`).
  - Three near-identical non-modifier hp hooks: `talents.lua:1108-1126`,
    `scout.lua:58-76`, `grug_trinkets/init.lua:113-125`. Each calls
    `get_properties()` on every punch.
- **Better (S):** One `grug_core.persisted_cooldown(player, key, seconds)`
  helper, and one "survived punch crossing a threshold" dispatcher fed by
  the central settled-incoming seam (`combat.lua:1928-1936`).

### CMB-12 Stale consumer map in `EFFECT_KEYS`; `post(context)` handed to a parameter named `action_id`
- **Severity:** Low. **Category:** Agent-trap. **Confidence:** Verified.
- **Location:** `grug_classes/talents.lua:50-115`; `grug_abilities/kits.lua:392`
  vs `init.lua:1227-1229`.
- **What:**
  - About 20 keys are still labelled `"X3"`, and `armor_rating_add_low_hp`
    names `grug_inventory/equipment.lua`, although the live consumer is
    `grug_quality` raw armor. Yet `skill_trees.md` §3.7 presents this table
    as the consumer map.
  - Mighty Blow's `post` is declared `function(action_id)` but is called with
    the whole swing `context`. It works because `grug_repair` deduplicates by
    table identity and the main swing used the same table, but nobody reading
    `kits.lua` would know.
- **Better (S):** Update the consumer strings. Rename the parameter
  `context`, and pass `context` explicitly as `action_id` in the cleave call
  with a one-line comment.

### CMB-13 Mend ticks on a global 3 s phase
- **Severity:** Low. **Category:** Bug. **Confidence:** Verified.
- **Location:** `grug_abilities/kits.lua:980-1009`.
- **What:** One shared `mend_acc` drives every Mend. The first tick lands
  0–3 s after the cast, and all four ticks fall within roughly 9–12 s instead
  of at 3/6/9/12 s. The status icon says 12 s.
- **Better (S):** Store `next_tick = now + 3` per mend and tick each record
  on its own deadline. Same globalstep, no extra cost.

### CMB-14 Loose tooltip does not match behaviour
- **Severity:** Low. **Category:** Bug (text). **Confidence:** Verified.
- **Location:** `grug_abilities/scout.lua:496-498`.
- **What:** The tooltip says "Requires a visible hostile target within 25 m"
  and "A full draw takes 2.5 s". `launch` fires along the aim without any
  target check, the range grows with Longshot and the race perk, and the draw
  time comes from the bow (`_grug_bow_draw_time`) minus Fletching and the
  speed affix (`effective_draw_time`).
- **Better (S):** Add a `description_for` that formats
  `grug_abilities.loose_draw_time(player)` and the effective range, and drop
  the target claim.

### CMB-15 `/faction` prints the raw id
- **Severity:** Low. **Category:** Naming. **Confidence:** Verified.
- **Location:** `grug_factions/init.lua:351` ("now belongs to the accord
  faction") and `:358` ("belongs to the Accord faction").
- **Better (S):** Use `grug_factions.display_name(id)`, giving "… now
  belongs to The Accord." "Welcome to the Accord!"
  (`grug_classes/selection.lua:722`) is prose and fine under world.md §0.

### CMB-16 `guard_destinations()` walks every node on each Skills render and join
- **Severity:** Low. **Category:** Perf. **Confidence:** Verified (cost
  small).
- **Location:** `grug_skills/bound_items.lua:74-81`; `page.lua:111`.
- **What:** `pairs(core.registered_nodes)` (thousands of entries) runs on
  every join and every render of the Skills page. Nodes cannot be registered
  after load, so only the detached-inventory half can find anything new.
- **Better (S):** Wrap nodes once in `on_mods_loaded`. Re-scan only
  `core.detached_inventories`, or wrap `core.create_detached_inventory`
  once.

## Hot-path inventory

| Path | Frequency | Cost class | Notes |
|---|---|---|---|
| `grug_abilities` input/swing pass (`init.lua:2447`) | every 0.05 s × players | Low per player; Medium while LMB is held (1–2 combat rays per pass) | CMB-09. Idle: 3 wielded reads, 1 control read, 2 meta reads. |
| Crosshair overlay (`crosshair.lua` `C.update`) | every 0.15 s × players | Medium: one 4 m `aim_raycast` plus up to one skill-range `combat_ray` | Already tuned in R30 (walled skip, 0.25 s unchanged-ray reuse). HUD packets only on change. Fine. |
| `combat_ray` / `aim_raycast` (`grug_core/combat_ray.lua:226,292,511`) | per crosshair refresh, held pass, swing, cast | Medium: engine raycast to range plus `get_objects_in_area` over the ray's AABB, `get_luaentity` per object | A 20 m diagonal ray box collects many objects in towns (NPCs, tag carriers). Core lane. |
| Regen/decay/wear ticker (`init.lua:2475`) | every 0.5 s × players | Low | `get_max_mana` computed 2–3× per player; `hud_update` with one `get_properties()`; wear writes only on a quantized step change. Fine. |
| Wield watcher (`watch_wield`) | every 0.5 s × players | Low | One read per changed slot. Fine. |
| Scout draw loop (`scout.lua:438`) | every 0.05 s × drawing players | Low | Wear and image write at most 10 times per draw. Fine. |
| Mend ticker (`kits.lua:982`) | every 3 s × active mends | Low | CMB-13 is about timing, not cost. |
| Authoritative swing (`attempt_swing` → `target:punch` → claim → finish) | per due swing (about 1/s per fighter) | Medium in itself; **High with the durability fan-out** | CMB-02. |
| `deal_ability_damage` (`combat.lua:1439`) | per cast hit; per target for AoE | Medium | One `punch`, one crit roll, threat; then the durability fan-out once per action (deduplicated per action id). |
| Central hp modifier (`combat.lua:1783`) plus about 9 non-modifier hp hooks | per HP change on any player | Low–Medium | Each of `grug_abilities` (2), `grug_factions`, `talents` (Unbroken), `classes/scout` (Untouchable), `grug_trinkets` and the dragon hook adds a small cost; three call `get_properties()`. |
| `on_equipment_change` fan-out (8 consumers) | **per landed and per received hit** (durability), plus real equips | **High** (CMB-02) | Two inventory walks, tooltip rebuilds, `get_properties()` ×2–3, an unconditional `set_properties` broadcast. |
| `get_talent_bonus` | many per hit/cast/tooltip | Very low | Parsed cache per player; windowed keys loop only over windowed talents. Fine. |
| `get_attributes` / `get_level` | several per hit | Low | Two meta reads plus a table allocation; `level_from_xp` about 50 ns (measured). Fine. |
| `grug_pvp` location tick (`init.lua:297`) | 1 s × players | Low | Zone lookup per player; callbacks only on change. Fine. |
| `grug_pvp` page refresh (`page.lua:81`) | 1 s × players | Low | Builds the key only for players whose sfinv page is PvP. While a countdown runs it re-sends the inventory formspec every second even with the inventory closed. Noted. |
| Party HUD poll (`grug_parties/hud.lua:136`) | 0.1 s slot, each player every 0.5 s | Low–Medium for big parties | CMB-08. |
| Party level emit (`grug_parties/init.lua:316-321`) | per level change of anyone (and every join) | Low | Notifies every connected player; Group-page viewers rebuild the roster, O(N) each. |
| Character-creation stasis watchdog (`selection.lua:655`) | 0.1 s × creation sessions | Very low | Fine. |

## Bug-prone areas

- **`input.lua` hold state machine** (`step`/`activate`). Fourteen state
  fields (`mode`, `foe`, `ally`, `pending`, `dig`, `right`, `food`, `settle`,
  `cancelled`, `rmb`, `down`, `used`, `failed`, `notices`), a grace window,
  settle and retry timers, and a re-entrancy guard. Most regressions in R28,
  R32 and R36 came from here. Any change needs the `tools/r32_f2` fixture.
- **The PvP `on_punchplayer` handler** (`init.lua:2226-2412`). It mixes live
  and dead branches (CMB-01, CMB-03) and relies on MODE_OR semantics with
  `grug_factions`' handler and builtin knockback (CMB-04).
- **The equipment-change contract.** Consumer order is load-bearing
  (`grug_classes` first; `grug_visuals` before `grug_inventory`'s refresh),
  nested notifications are capped at two passes, and the reason flag is
  propagated through `notify_reason`.
- **Stat accessors assembled by load-order monkey patches** (CMB-05).
- **The single global swing token** (`combat.lua:1276-1323`). Correct only
  because every punch is synchronous. Nested punches (Mighty Blow cleave,
  Hamstring post, threat callbacks) depend on the `in_ability_punch`
  short-circuits in both the mob patch and the PvP handler.
- **Non-modifier hp hooks must predict HP** (`get_hp() + hp_change`). Writing
  `get_hp()` alone silently reads the pre-hit value
  (`init.lua:388-398` documents it).
- **Ability item wear doubles as the cooldown display.** Any wear writer that
  touches ability stacks (the mobs_redo wear block, tool after_use) would
  corrupt it. The `punch_attack_uses = 0` contract in `deal_ability_damage`
  and the swing caps is what keeps this safe.
- **Character creation** (`selection.lua`). Asynchronous emerge generations,
  admin identity changes mid-load and the sfinv suspension; well commented
  but stateful.

## Noted (no action)

- `try_cast` ignores a `false` from `spend()` (`init.lua:1557`). Reachable
  only if a cast changes its own resource; none does.
- `grug_skills/page.lua:20` asserts at most 8 abilities per class at page
  render time. The current maximum is 7 (Scout). A future eighth talent skill
  would crash the server on opening Skills.
- PvP, talent and trinket timers use `os.time()`; a wall-clock jump shifts
  them.
- Blink and Charge do not consult protection or housing claims
  (`blink.lua`). Movement into claims is presumably allowed; see open
  question 4.
- `grug_parties` asserts on corrupted mod storage at load, so the server
  fails closed.
- In `grug_factions`' respawn callback, `set_pos(spawn)` is followed by an
  asynchronous `teleport_to_spawn` that sets the position again. Harmless.
- The scout draw loop's "player gone" branch calls `clear_draw(rec.player)`
  on a possibly invalid ref. Unreachable in practice because leave clears
  draws first.
- Kill XP is split among eligible participants within 40 m
  (`grug_mobs/init.lua:228-280`), healers included via heal participation.
  No party XP by design.
- XP persistence is `get_int`/`set_int` player meta. The maximum, 194,220 at
  level 60, fits easily. `set_xp` rejects NaN and ±inf and clamps.
- No ability places or removes nodes, so the terrain/POI damage guard is not
  applicable.

## Open questions for Jan

1. **Knockback on players.** Should the engine's builtin knockback apply to
   players at all? Today PvP casts push at the maximum, mob hits push, and a
   refused click from an ally or an unflagged enemy still pushes (CMB-04).
   The proposal: 0 for refused punches in any case. And casts, and mob hits?
2. **Cooldowns across relog.** Should long ability cooldowns (Sprint 300 s,
   Hold Ground 60 s, Shield and the others) and mana survive a relog, the
   way talent and trinket ICDs already do (CMB-10)?
3. **Dead tool/fist code.** May the dead WP38 tool/fist proportional path be
   removed entirely (CMB-03)? That includes `mobs/api.lua` GRUG PATCH blocks
   in the vendored mod.
4. **Blink and claims.** Should Blink or Charge be refused into another
   player's housing claim or protected POI interiors? Today only walls stop
   them.

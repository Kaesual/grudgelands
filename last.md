# R7-FOOD completion report

Completed on 2026-09-18 on branch `r7-food`.

## Commits

- `92bdf635` — Retarget moved mobs_redo API citations.
- `0a7ec4e2` — Implement tiered Food v2 recovery.
- `1ac18085` — Document Round 7 food and preload rules.

## Delivered behavior

- `grug_food.TIERS[1..6]` now owns the proposed instant-HP values, minimum
  levels and role-specific dish data. Raw foods use the invariant 1% pool
  rule; current cooked meat and fish are T1 dishes. Registration uses
  `(tier, kind, role)`, retains `grug_food.converted`, assigns `_grug_ilvl`,
  and installs effect-bearing labels and complete tooltips.
- Food lasts 180 seconds and ticks every five seconds. Out-of-combat servings
  heal instantly; a serving eaten in combat defers that heal exactly once to
  the first eligible tick. Regeneration pauses in combat, secondary modifiers
  remain active, and the latest `food` status replaces the previous one.
- The status registry accepts only `hp_pool_percent`, `mana_pool_percent`,
  `crit_percent`, `armor` and `spell_damage_percent`. Active statuses sum by
  key; unknown or non-finite modifier values reject the status. Modifier
  changes use the normal HP/mana clamp and HUD/page refresh paths.
- The concrete stat consumers are max HP/mana in
  `mods/PLAYER/grug_classes/stats.lua:67-110`, spell damage at `:120-123`,
  Crit at `:129-145`, and armor in
  `mods/PLAYER/grug_inventory/equipment.lua:498-502`. HP refresh is registered
  at `stats.lua:170-175`; mana clamp/HUD refresh is registered in
  `mods/PLAYER/grug_abilities/init.lua:2282-2287`.
- `grug_core.can_use_item_level` is the shared `_grug_ilvl` decision seam for
  equipment and consumables. Food refuses below-level use with `Requires level
  N.` and consumes nothing.
- Mana regeneration is absolute: `1 + 0.15 * level` per second, multiplied by
  the Troll perk; combat uses one quarter and Cold Focus multiplies that rate
  by `1 + 2 * bonus`.
- Start preload writes `starts_preloaded_v1` only after all six areas succeed.
  A later server start skips every emerge and logs exactly
  `[grug_core] start areas already generated` once.
- All moved `mobs/api.lua` references reported by the citation checker were
  retargeted. The final scan resolves 240 references with zero mismatches.

## Verification evidence

- `bash tools/wp11/static.sh` — PASS. The entire mod and tool Lua tree parsed
  with `tools/bin/luac51`; fresh-server audit, WP40 unit suite and WP11 talent
  KATs passed. WP11 LuaJIT/PUC output was byte-identical at
  `e83d2878c17c266ac21aaebea7446fbc72a894f5ef309268c71fe18c87aa3a68`.
- Explicit parser pass over all 30 changed Lua files — PASS. The five scoped
  Lua-5.1 sweeps found no forbidden syntax/API use; sweep-four matches were
  existing `|` characters in strings and comments.
- `R7_FOOD_LUA_BIN=luajit tools/r7_food/run.sh` and the same command with
  `tools/bin/lua51` — PASS and byte-identical at
  `1c021ec8b64296f517543f7f661cb1bdee26efb61a4915930696416a90b3bf50`.
  Covered tier shape, every raw tier, dish data, combat deferral, status
  stacking/rejection, max HP/mana/Crit/spell/armor consumers, clamp behavior,
  the shared level gate, labels, tooltips, L1/L10/L30/L60 mana rates and both
  preload paths.
- `MUTATION_LUA_BIN=luajit tools/r7_food/mutations.sh all` — baseline PASS;
  all ten mutations failed on their intended row: `tier`, `raw`, `dish`,
  `deferral`, `modifiers`, `level_gate`, `label`, `tooltip`, `regen`, and
  `preload`.
- All seven `tools/wp39/*_test.lua` files — PASS.
- All 24 `tools/wp13/*_kat.lua` files — PASS in four parallel groups.
- `WP45_LUA_BIN=luajit tools/wp45/run.sh` — PASS:
  `cold_requests=6`, `restart_marker_skip=6`, `callback_reentry=0`.
- Round-6 balance/hotfix and HUD-bar regressions — PASS, including
  `R6_BALANCE_OK rows=15 pools=45 costs=8 support=4 tooltips=7` and
  `hud_bars_result PASS 0`.
- `luajit tools/docs/check_api_citations.lua $(git ls-files 'mods/*.lua'
  'docs/*.md')` — `TOTAL 240`, zero old/resolved line mismatches.
- `git submodule status` — all eleven reference projects exactly pinned; no
  `+`, `-` or `U` marker.
- `PORT=31200 nice -n 19 bash tools/luanti_headless.sh 60` — PASS; server
  listened on `127.0.0.1:31200`, then exited, and `pgrep -f '^luanti.bin'`
  found no remaining process.

## Documentation updated

- `docs/design/items_crafting.md` — Food v2 tier, raw/dish, combat, tooltip and
  level rules; the Round 6 history remains recorded.
- `docs/design/combat_stats.md` — status stat source, shared consumable gate,
  recovery rules and mana curve.
- `docs/design/skill_trees.md` — relative Cold Focus wording.
- `docs/design/inventory_equipment.md` — effect-bearing buff labels.
- `docs/research/wp13-start-preload.md` — marker lifecycle and restart log.
- `AGENTS.md`, `BACKLOG.md`, `ROADMAP.md` and `README.md` — implementation
  seams and derived current-state summaries.

## Open items

- Round 8 still owns the real dish, potion and elixir tables and recipes.
- Independent review remains the coordinator's integration gate; this worker
  made no merge, push or sync operation.

## Runtime test plan

1. In a fresh GUI world, damage a character and eat an apple out of combat:
   verify +5 HP immediately, `Food +1% HP/5s`, then one-percent ticks.
2. Eat while the combat flag is active: verify no immediate heal or tick,
   leave combat, and verify one +5 HP deferral plus the normal first tick.
3. On a mana class, consume Wild Cocoa and compare recovery at low and high
   levels; repeat in combat, with Cold Focus and with the Troll perk.
4. Restart the same world after all six starts are ready and verify exactly
   one `[grug_core] start areas already generated` line and no new start-area
   emerge progress lines.

## Blockers / questions

None for the implementation lane.

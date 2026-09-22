# Round 16 UI and food implementation

Author: root Astra. Independent review pending. XP label/admin command belongs
to the progression lane and is recorded there.

- Eating in combat refuses before stack consumption or status replacement and
  uses the existing short ability-feedback HUD. Successful food keeps its
  original instant heal; the obsolete deferred-heal queue is removed.
- Periodic regeneration is doubled: raw food 2%; tier dishes 4/5/6/7/8/10%
  every five seconds. Five-minute duration and secondary modifiers are retained.
  Existing buffs pause regeneration during later combat.
- Armor descriptions include Cloth, Leather or Metal at initial registration
  and after metadata/enchantment description regeneration.
- The station recipe-book button moves to a free right-hand position in the
  shared 12-unit workspace form. Default helper coordinates remain available
  for other callers. Inventory authorization and geometry are unchanged.
- A small Combat label to the right of the health bar reads the existing
  combat flag at 0.2-second intervals and sends HUD writes only on transitions.

Validation: `tools/r16_ui/food_hud.lua` loads actual food/status/HUD consumers in
an isolated fixture. LuaJIT passes 24 tier/role routes, rejection without loss or
buff replacement, unchanged instant healing, doubled ticks, combat pause,
expiry without deferred healing, and HUD enter/idle/exit/death/reconnect.
Parser, SETGLOBAL inventory and five source sweeps pass; no PUC runtime yet.
Final portable runner can call `dofile(path)(repo)` and collect its result.
Armor/station visual readability remains a user GUI check; no GUI pass claimed.

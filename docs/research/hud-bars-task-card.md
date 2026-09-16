# HUD bars — task card (2026-09-16)

**A task card, not an implementation.** No code was written and no engine was
run. Written by the WP11 skill-tree lane because the user's ruling arrived in
the same session; it belongs to **no work package yet** and is not part of
WP11.

Every `file:line` below was resolved against this tree at `70dda602`.

---

## 1. The user's ruling (2026-09-16)

> The current heart statbars are rejected — "**half hearts are an ugly
> approximation**". Instead: a **thin, point-accurate LIFE bar**, and a
> **MANA-or-RAGE bar directly above the hotbar slots**. Every class has
> exactly **one** secondary bar — rage **or** mana, never both.

The second half is already true in the data (`grug_abilities`' `resource_of`
returns exactly one of `"mana"`, `"rage"` or nothing,
`mods/PLAYER/grug_abilities/init.lua:45-52`); what is missing is the bar.

## 2. What the engine offers

Two ways to draw a bar, and one call to get the builtin one out of the way.

- **`hud_add{type = "statbar"}`** — the engine's own repeated-icon bar, which
  is what the default hearts are. It draws `number / 2` **whole** icons plus
  optionally a half icon, which is exactly the approximation the ruling
  rejects: a 325-HP level-60 Warrior (`combat_stats.md:87-92`) cannot be shown
  point-accurately by an icon that represents two HP. A statbar can be made
  finer only by shrinking what one icon means, and the icon count is then
  absurd. **Not the right tool for the LIFE bar.**
- **`hud_add{type = "image"}` with a scaled texture** — the approach this card
  recommends. One background image and one foreground image whose horizontal
  `scale` is set from the exact ratio, so the bar is accurate to the point
  rather than to the icon. The game already draws four image/text HUD elements
  this way (§3), so nothing new is learned; the only new asset is a 1×N pixel
  strip per bar, tinted with `^[colorize:` the way the ability icons already
  are (`classes.md` §2c).
- **`player:hud_set_flags{healthbar = false, breathbar = false}`** removes the
  builtin hearts and bubbles. It is the one call that makes the ruling
  visible, and it must be paired with the replacement in the same commit or
  the player has no health display at all.

**Both claims above are verified against the engine source, not assumed.**
`reference_projects/luanti/src/client/hud.cpp:660-765` (`Hud::drawStatbar`)
draws `for (s32 i = 0; i < count / 2; i++)` full icons and then
`if (count % 2 == 1)` one half icon — so one unit of `number` is **half an
icon**, the default hearts are 2 HP each, and a 325-HP Warrior would need 163
icons. `reference_projects/luanti/doc/lua_api.md:9337-9344` lists `healthbar`
and `breathbar` among the `hud_set_flags` fields. (The nine
`reference_projects/` trees are registered submodules; a worktree does not
populate them, so these were read from the main checkout — the independent
review of 2026-09-16 did so at the pinned commit
`df04879066de6eb94ca43996822a6dfacc74feca`.)

## 3. Where this game already draws HUD elements

Four writers, all with the same shape — `hud_add` on join, `hud_change` on
update, drop the id on leave — and all stacked above the hotbar by a negative
`y` offset from `position = {x = 0.5, y = 1}`:

| Element | Offset | Registration | Update |
|---|---|---|---|
| Ability resource text ("Mana 84 / 148") | **−135** | `grug_abilities/init.lua:2290-2297` | `:195-203`, formatted at `:184-193` |
| XP line ("Level 12 — 340 / 900 XP") | **−110** | `grug_xp/init.lua:122-130` | `:115-120`, formatted at `:104-113` |
| Money | **−85** | `grug_money/init.lua:153-162` | `:146-151` |
| Selected skill name | **−70** | `grug_abilities/init.lua:2306-2313` | `:229-247` |
| Error flash (top centre) | `y = 0.35` | `grug_abilities/init.lua:2298-2305` | `:205-219` |
| Weapon-ready reticle (centre) | `y = 0.5` | `grug_abilities/init.lua:2314-2322` | `:249-263` |

**The offsets are a stack with no owner.** −70, −85, −110, −135 are four
constants in three different mods, and inserting two bars "directly above the
hotbar slots" means every one of them moves. That is the real work in this
card: a single place that says what the HUD column is, rather than four mods
each guessing. The cheapest version is a small table of offsets published by
`grug_core` (it is below all three in the dependency graph) that the three
consumers read.

## 4. The seam for the values

Both numbers already exist behind accessors, so the bars need no new state:

- **Life**: `player:get_hp()` against `player:get_properties().hp_max`, which
  `grug_classes.apply_stats` keeps current (`grug_classes/stats.lua:56-69`,
  from `get_max_hp` at `:19-22`).
- **The secondary bar**: `resource_of(player)` (`grug_abilities/init.lua:45-52`)
  returns `"mana"`, `"rage"` or nothing, and then
  `grug_abilities.get_mana(player)` (`:54`) against
  `grug_classes.get_max_mana(player)` (`grug_classes/stats.lua:25-31`), or
  `grug_abilities.get_rage(player)` (`:58`) against the flat 100 of
  `classes.md` §1. `hud_state` (`grug_abilities/init.lua:184-193`) already
  picks exactly this pair and even carries the two colours — mana `0x4a9bd8`,
  rage `0xc41e3a`. **The bar is a second consumer of a function that already
  exists**; if the text line stays, both read the same source.
- **Update cadence**: the resource HUD is already refreshed by
  `hud_update(player)` at every spend and regen tick, and HP changes arrive
  through `core.register_on_player_hpchange`, which `grug_abilities` already
  registers for rage (`init.lua:2107-2112`). No new globalstep is needed, and
  `AGENTS.md`'s throttling rule says one should not be added.

## 5. Open questions for whoever takes this

1. **Does the text line stay?** A point-accurate bar plus "Mana 84 / 148" is
   redundant; a bar alone loses the exact number. Options: keep both, put the
   number *inside* the bar as a centred text element, or show the number only
   while it changes.
2. **Who owns the offset stack?** (§3.) This is the decision that stops the
   next HUD element from guessing again.
3. **Two bars or three?** The ruling says LIFE plus one secondary. A class
   with no class yet (`resource_of` returns nothing) then has one bar, and the
   layout must not jump when a class is chosen.
4. **Breath.** `hud_set_flags` turns the bubbles off with the hearts. Drowning
   is a real mechanic (`combat_stats.md:65-68` excludes it from armor), so the
   bubbles either stay on or get their own thin bar.

## 6. Reference mods

The coordinator asked for ContentDB mods that do point-accurate bars. **I do
not have verified knowledge of a specific ContentDB mod that does this, and
naming one I am not sure of would be worse than naming none** — the brief's
own instruction. What *is* verifiable inside this repo and is the closest
working reference: the **charge bar** of `classes.md:289-301`, which already
renders a continuous 0-1 value accurately by driving the item **wear bar**
(`wear = (1 − charge) × 65534`) with a red→yellow→green ramp through
`set_wear_bar_params`. It is not an HUD element, but it is this game's own
precedent for "a continuous value shown exactly rather than in steps", and the
same 2/s packet-cost reasoning in `classes.md:302-304` applies to any bar that
updates per tick.

What **is** in reach: `reference_projects/` registers **nine** trees —
`animalia`, `animalworld`, `Lord-of-the-Test`, `luanti`, `minetest_game`,
`mobs_monster`, `mobs_redo`, `protector`, `VoxeLibre`. **VoxeLibre** is the
strongest reference for exactly this problem (it replaces the default HUD
wholesale and draws its own bars) and `minetest_game` is the simplest; both
should be grepped for `hud_add` before anyone writes new bar code. They are
submodules, so they are populated in the main checkout rather than in a
worktree.

## 7. Commands that reproduce every citation here

```sh
grep -rn "hud_add\|hud_change\|hud_set_flags" mods/PLAYER/ mods/CORE/
sed -n '45,60p;180,205p;2288,2325p' mods/PLAYER/grug_abilities/init.lua
sed -n '112,132p' mods/PLAYER/grug_xp/init.lua
sed -n '145,162p' mods/PLAYER/grug_money/init.lua
sed -n '19,31p;56,69p' mods/PLAYER/grug_classes/stats.lua
```

# WP5 Task Card — Loot, Refinement Metadata and the Affix System

Status: **Executable task card, authored 2026-08-13 (WP40-independent
design round). WP5 is buildable today: every dependency is shipped —
WP1 ✅, WP3 ✅, WP43 ✅ — and the last design blocker fell on 2026-08-13
(A2 affix vocabulary `items_crafting.md` §6b.4, A6 refined marker §6b.7,
C10 leather line §3.8).** Nothing here reopens a decided rule; every
number is quoted from `items_crafting.md` §§5–7/6b and
`inventory_equipment.md`, resolved to shipped item fields and code seams.

## 1. Scope and non-goals

WP5 is the **per-stack item-data layer**: it owns what an item stack
carries, who may wear it, how it is described, and how a dropped item is
rolled. It owns no recipe, no profession, no catalog and no price.

- Deliver the meta model of §6.1 (`grug_quality`, `grug_ench`,
  `grug_upgrades`, `grug_req_level`, refinement boolean, plus the separate
  masterwork, cultural-finish and PvP-special channels), one idempotent
  description regeneration path, the §6.3 roll engine with its six source
  windows, the §5/§5.1 drop layer, and the §6b.4 prefix/suffix naming.
- **The mod is `grug_items`, and its entry point's signature is already
  fixed by a shipped call site.** WP7 probes exactly that global and
  exactly one function (`mods/ENTITIES/grug_traders/stock.lua:183-189`)
  and calls it as **`roll(stack, entry.ilvl, "world")`**
  (`stock.lua:200-203`). So the contract is
  `grug_items.roll_enchants(stack, ilvl, window)`, mutating the stack in
  place, with the window passed as the §6.3 window name as a string.
  Registering the mod under another name, or choosing another signature,
  silently keeps every vendor Uncommon switched off — the probe fails
  closed by design.

Non-goals, all binding:

- **No recipes and no professions.** Refinement, fine/masterwork recipes,
  imbue/temper kits, cultural-finish operations, Warding Draughts and the
  weapon counter finish are **WP10's** (and WP29's for the gear catalog).
  WP5 ships the *channels those recipes write into*, their caps, their
  overwrite rules and their display — not a single `register_craft`.
- **No prices.** Reference values and buy-back are WP44's. WP5 adds no
  `_grug_sell_price` and no trader override. The x3 Uncommon premium
  already exists in `grug_traders` and needs no edit.
- **No new gear items.** The catalog is `grug_gear`'s generated one today
  and WP29's merged ladder later; WP5 rolls what exists.
- **No trinket items.** The six core identities and their seven specials
  (§6.2) are the Goldsmith's family and ship with **WP10**. WP5 implements
  only the trinket *exception* in the shared roll/description path — one
  prefix, one suffix, no base-stat line, no refinement, no durability — so
  that WP10 registers items rather than a second data model.
- **No durability.** Refinement doubles a budget WP22 owns; WP5 stores the
  refined boolean and shows the doubled number, it does not implement wear.
- **Nothing to remove.** The BACKLOG row's "remove the retired Amplifier
  path" is stale: `Amplifier` occurs in no design document and in no Lua
  file in `mods/`. There is no code, item, recipe or alias to retire, and
  this card treats that clause as already satisfied.

## 2. Shipped baseline this card builds on

- **`grug_gear` publishes the WP5 interface and implements none of it**
  (`mods/ITEMS/grug_gear/init.lua:11-23`): every generated item carries
  `_grug_ilvl`, `_grug_bracket` and `_grug_quality = 1` (`:247-249`,
  `:285-287`). WP5 derives the per-stack `grug_req_level` and the rolls
  from those fields; the catalog needs no second list of levels
  (§6.1 hand-off).
- **The description helper already emits the two lines WP5 must
  preserve** (`grug_gear/init.lua:66-87`): name plus `Item level N` plus
  one grey base-stat line. The base stat does **not** live in meta and
  cannot be reconstructed from a roll, so regeneration appends affix lines
  below these and never rebuilds them. The name is deliberately
  un-colorized: WP5 owns the quality colors.
- **The equip filter exists and has no level branch.** The group-filtered
  `allow_put` in `mods/PLAYER/grug_inventory/equipment.lua` already
  enforces the armor rank (`:311`) and the two-handed rule, with one
  shared throttled refusal channel (`:111` names WP5 as a future third
  rule). WP5 adds one branch there (`:304` marks the spot), not a new
  callback.
- **The vendor Uncommon path is complete and dormant**
  (`grug_traders/stock.lua:166-189`, `:251-253`): the x3 price, the
  `grug_quality = 2` meta, the blue description and the roll call all
  exist. The moment `grug_items.roll_enchants` exists, Uncommons light up
  **with no edit in that file**. `core.global_exists` is used to probe
  without tripping `strict.lua`.
- **Attack speed already flows through per-stack meta.** The equipped
  weapon's `full_punch_interval` override is read by the swing clock
  (`grug_abilities/kits.lua:243`, `grug_abilities/init.lua:1233`), so a
  rolled `+attack speed%` affix needs no new plumbing — it writes the
  same key. `grug_abilities/init.lua:1115` requires that a changed
  override must not read as unchanged.
- **Equipment writes have one legal path.** Any per-stack mutation must go
  through `grug_inventory.equipment_changed`
  (`mods/CORE/grug_core/combat.lua:66`, `:110` name WP5's affix work
  explicitly); `get_equipped_weapon` hands out the caller's **own copy**,
  so a modified stack is not equipped until written back.
- **WP7 ships 72 equippable items that carry an ilvl and enforce nothing**
  (§6.1) — that is the gap WP5 closes in one place.

## 3. The complete WP5 surface

### 3.1 Per-stack meta (§6.1)

| Key | Contents | Written by |
|---|---|---|
| `grug_quality` | 1 Common / 2 Uncommon / 3 Rare / 4 Unique-reserved | drop roller, WP10 recipes |
| `grug_ench` | one serialized ordinary-affix table (stat → rolled value) | roll engine |
| `grug_upgrades` | 0–2, temper applications (§7) | WP10 kits |
| `grug_req_level` | equals the item's ilvl, on **every** equippable item | WP5 on first touch |
| refined | plain boolean, alongside `grug_quality` | WP10 refinement |
| masterwork / cultural finish / PvP special | separate structured channels | WP10 |

These channels never overwrite one another. Exact key names are
implementation-owned; **one idempotent regeneration path reads them all**
and rebuilds name, color and description.

### 3.2 Roll engine (§6.3)

`roll = min + frac × (max − min)`, `frac` uniform inside the source
window. The band is chosen by the **item's** ilvl — never by a crafter's
mastery or character level — which is also the only reading a drop can
have, since a drop has no crafter.

| Enchant | 1–15 | 16–30 | 31–45 | 46–60 |
|---|---|---|---|---|
| +Str / +Int / +Dex | 1–3 | 2–5 | 4–8 | 6–12 |
| +HP | 4–8 | 8–15 | 14–24 | 20–35 |
| +Mana | 6–12 | 12–24 | 20–36 | 30–50 |
| +Crit% / +Dodge% | 0.5–1.0 | 0.5–1.5 | 1.0–2.0 | 1.5–3.0 |
| +Attack speed% | 3–6 | 4–8 | 6–12 | 8–16 |
| +Armor% (armor only) | 1–2 | 1–3 | 2–4 | 3–6 |

| Window | frac | Used by |
|---|---|---|
| world | 0.00–0.60 | normal-mob drops, vendor Uncommons |
| crafted-fine | 0.30–0.80 | WP10 fine recipes |
| elite | 0.30–0.90 | elite drops |
| rare | 0.50–1.00 | named-rare drops |
| crafted-masterwork | 0.60–1.00 | WP10 masterworks |
| boss | 0.80–1.00 | apex hoards, race Kings |

Legality is **§6.2 and only §6.2**: an affix is legal on a family iff its
stat is in that family's pool, and no item may carry the same stat twice
across its four ordinary slots.

### 3.3 Drop layer (§5, §5.1)

Drops obey the shipped player-tag rule. `ilvl = mob level`, and **a
dropped item's material tier must match the mob's tier** — a T3 item drops
from level-21–30 mobs and nowhere else, which is what stops the drop table
from becoming a side door around the depth gate of §3.0.4. The depth axis
adds **no** gear layer at any depth.

| Source | Uncommon | Rare | Window |
|---|---|---|---|
| Normal mob | 3% | — | world |
| Elite (armor 80) | 20% | 3% | elite |
| Named rare (armor 70) | 100% | 25% | rare |
| Apex boss / race King | — | 100% | boss |

A dropped item carrying affixes is by definition refined (§6b.3), which is
why no refinement word appears in a drop's name (§6b.4).

**Implementer latitude, deliberately not frozen:** which concrete item a
qualifying drop selects. The tier is fixed by the mob's level band, so the
selection is a uniform draw from that bracket's existing catalog
(`grug_gear.catalog[b].all`); a weighted table is a tuning question for
the runtime pass, not a design rule. Everything else on this page is
binding.

### 3.4 Names, colors and the tooltip block (§6b.4, §6b.6, §6b.7)

Maximum **2 prefixes + 2 suffixes = 4 slots**, the hard ceiling for any
item. One prefix word and one suffix word per stat, no synonyms:

| Stat | Prefix | Suffix |
|---|---|---|
| +Str | Heavy | of the Bear |
| +Dex | Quick | of the Fox |
| +Int | Clever | of the Owl |
| +HP | Stout | of the Ox |
| +Mana | Attuned | of the Raven |
| +crit% | Lucky | of the Eagle |
| +attack speed% | Swift | of the Hornet |
| +dodge% | Elusive | of the Cat |
| +armor% | Stalwart | of the Tortoise |

Two suffixes combine into one phrase and drop the article — *of Bear and
Ox*; a single suffix keeps it. The refinement word disappears as soon as
any affix is present, and an enchanted item instead states **one grey
"Refined" line above the affix lines**; a special variant states its
authored effect in that same block. Quality follows the slot count
(0 Common white, 1–2 Uncommon blue, 3–4 Rare yellow) with the §6.1 colors
`#FFFFFF` / `#4A90FF` / `#FFD700` / `#FF8000`.

### 3.5 The two separate channels (§4.2, §4.3)

WP5 stores, caps and displays them; WP10 writes them.

- **Cultural finish** — at most **one per stack**, on weapon, offhand,
  head, chest, legs and feet only (never trinkets). One fixed deterministic
  effect per culture × family (§4.2's table); it preserves base item,
  tier, refinement, quality, durability, ordinary affixes, masterwork state
  and PvP-special data.
- **PvP special** — at most **one per item**, stored independently.
  Identical target-race specials never stack (highest value wins); a new
  target **overwrites** the old at full cost with no refund; the identical
  target is rejected as a no-op.
- **Combined caps are unchanged and shared**: Crit 30%, Dodge 30%, armor
  60%. Ordinary affixes, trinket affixes, cultural finishes, attributes and
  base equipment all add **before** the cap. Overcap stays on its stack and
  grants nothing; the Character page shows effective and raw values
  (`Armor 60% (67% raw)`). No reroll, overflow conversion, diminishing
  return or cap increase may hide the waste.

## 4. Tasks

1. **`grug_items` skeleton and the meta model** — one global table, the
   §3.1 keys, `core.serialize` for `grug_ench`, and the single idempotent
   regeneration entry point. No behavior yet.
2. **Roll engine** — §3.2's tables as data, the six windows, §6.2 pool
   legality plus the no-duplicate-stat rule, and the public
   `grug_items.roll_enchants(stack, ilvl, window)` exactly as WP7 already
   calls it (`stock.lua:200-203`). Vendor Uncommons must light up without
   touching `grug_traders`.
3. **Description regeneration** — name (prefixes + noun + combined
   suffixes), quality color, preserved `Item level` and grey base-stat
   lines, the "Refined" line, one line per affix, then the separate
   cultural-finish and PvP-special lines naming culture/target and value.
   Idempotent: regenerating twice must produce a byte-identical string.
4. **`grug_req_level` enforcement** — one branch in the existing
   group-filtered `allow_put` (`equipment.lua:304`), refusal with a chat
   message through the **existing throttled channel** (`:111`), never a
   silent "equips but grants nothing".
5. **Drop layer** — §3.3's table wired into the shipped `drops` functions,
   respecting the player-tag rule and the tier match; elite and named-rare
   sources use their own windows.
6. **The two channels** — storage, the overwrite/no-op rules, the shared
   cap evaluation and the Character page's effective/raw display.
7. **Trinket exception path** — one prefix, one suffix, no base-stat line,
   no refinement, no durability, in the shared code so WP10 only registers
   items.

## 5. Acceptance gates

1. `tools/bin/luac51 -p` clean on every changed file; the five
   `luanti-lua.md` grep sweeps clean; no new global (verify with
   `luac51 -l -p … | grep SETGLOBAL` when in doubt).
2. **Vendor Uncommons appear with no edit to `grug_traders`** — the proof
   that the seam name is right.
3. A level-1 character cannot equip a level-30 drop; the refusal prints
   once per drag, not per callback.
4. Regeneration is idempotent and preserves the base-stat line for all 72
   shipped `grug_gear` items.
5. No item carries a duplicate stat across its four ordinary slots, and no
   affix appears outside its §6.2 family pool — assert over a large
   generated sample, not by inspection.
6. A T3 item never drops from a mob outside level 21–30, and no drop
   appears at any depth that would not appear on the surface.
7. Cap audit: a deliberately overcapped set shows `raw > effective` and
   grants no combat power above the cap.
8. Applying a second cultural finish or an identical PvP special is
   rejected; a different PvP target overwrites at full cost.
9. **Runtime test plan for the user** (agents cannot run the Flatpak GUI):
   kill boars until an Uncommon drops and read its name/lines; try to
   equip an over-level item; buy an Uncommon from a vendor; confirm a
   rolled attack-speed affix changes the swing interval.

## 6. Composition

One implementation agent per task group (1–3 data/display, 4–5 rules/drops,
6–7 channels), then the mandatory Opus review per
`docs/process/wp-workflow.md` with a second reviewer on the roll/cap
arithmetic. WP5 changes no mapgen and needs no fresh world.

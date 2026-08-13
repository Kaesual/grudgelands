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
- **The global name and the entry point's signature are already fixed by a
  shipped call site.** WP7 probes the global table `grug_items` and one
  function on it (`mods/ENTITIES/grug_traders/stock.lua:183-189`) and calls
  it as **`roll(stack, entry.ilvl, "world")`** (`stock.lua:200-203`). The
  binding contract is therefore
  **`grug_items.roll_enchants(stack, ilvl, window[, count])`**, mutating the
  stack in place, with the window passed as the §6.3 window name as a
  string. The shipped three-argument call must keep working unchanged — it
  omits `count` and gets the crafterless roll — while WP10 passes an
  explicit `count` for a crafted item, whose affix number is its crafter's
  mastery slots rather than a roll (§6.1/§6b.5). The
  probe tests the *global*, not the registered mod name — naming the mod
  `grug_items` is the ordinary project convention (AGENTS.md: one global
  per mod), but choosing a different global or signature silently keeps
  every vendor Uncommon switched off, because the probe fails closed by
  design.

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
  path" is already satisfied. The only mention anywhere in `docs/design/`
  is the tombstone in `items_crafting.md:25`, which lists the Amplifier
  among the things "absent from the target", and no Lua file under `mods/`
  contains the word. There is no code, item, recipe or alias to retire.

## 2. Shipped baseline this card builds on

- **`grug_gear` publishes the WP5 interface and implements none of it**
  (`mods/ITEMS/grug_gear/init.lua:11-23`): every generated item carries
  `_grug_ilvl`, `_grug_bracket` and `_grug_quality = 1` (`:247-249`,
  `:285-287`). WP5 derives the per-stack `grug_req_level` and the rolls
  from those fields; the catalog needs no second list of levels
  (§6.1 hand-off).
- **The description helper shows the shape WP5 must reproduce — not
  numbers it may reuse** (`grug_gear/init.lua:66-87`): name, `Item level N`,
  one grey base-stat line. Those numbers are baked per registered item at
  the six bracket anchors (ilvl 3/10/20/30/40/50), while a drop carries
  `ilvl = min(mob level, 60)` and therefore lands off-anchor — the design
  says so outright: "No shipped vendor bracket touches ilvl 27 or 42, but
  **WP5's drop tables will**" (`items_crafting.md:813`). **So WP5 stores the
  per-stack ilvl and recomputes the base stat from the §3.1/§3.2 curves**,
  preserving the line *format* and its position above the affix lines, not
  the definition's literal values. The base stat is still not stored in
  meta and still cannot be reconstructed from a roll. The name is
  deliberately un-colorized: WP5 owns the quality colors.
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
- **Attack speed already flows through per-stack tool capabilities.** The
  equipped weapon's `full_punch_interval` override is resolved by
  `grug_abilities.swing_stats` through `stack:get_tool_capabilities()`
  (`grug_abilities/kits.lua:240-256`, whose comment names this WP) and read
  by the swing clock and the swing-caps mirror
  (`grug_abilities/init.lua:849`, `:1347`), so
  a rolled `+attack speed%` affix needs no new plumbing — it writes the
  same per-stack override, as `fpi / (1 + p)` and as a **complete**
  capability table (`items_crafting.md` §6.1; a bare meta float of that
  name is not read by the engine, and every other capability of the base
  item must survive). The swing-caps mirror compares first on a token built
  from the interval (`init.lua:1347`), so a changed override must not read
  as unchanged.
- **Writes to an equipped stack have one legal path.** Mutating a stack
  that already sits in an equipment list means writing it back and then
  calling `grug_inventory.equipment_changed`
  (`mods/CORE/grug_core/combat.lua:66`, `:110` name WP5's affix work
  explicitly); `get_equipped_weapon` hands out the caller's **own copy**,
  so a modified copy is not equipped until it is written back. Stacks with
  no owner — a fresh drop, a vendor stack, an item in `main` — are ordinary
  ItemStacks and need no notification.
- **WP7 ships 72 equippable items that carry an ilvl and enforce nothing**
  (§6.1) — that is the gap WP5 closes in one place. Note that those stacks
  carry the ilvl **on the item definition**, not in stack meta, and a
  Common vendor purchase never passes through the drop roller. The equip
  check must therefore read one **effective-ilvl resolver** — per-stack
  value if present, otherwise the definition's `_grug_ilvl` — or a level-1
  character could equip an ilvl-30 Common bought from a vendor while an
  ilvl-30 drop is correctly refused.

## 3. The complete WP5 surface

### 3.1 Per-stack meta (§6.1)

| Key | Contents | Written by |
|---|---|---|
| `grug_quality` | 1 Common / 2 Uncommon / 3 Rare / 4 Unique-reserved | drop roller, WP10 recipes |
| `grug_ench` | the **ordered** affix slots 1–4, each carrying stat and rolled value; the slot number is also its side (§6b.4) | roll engine |
| `grug_upgrades` | 0–2, temper applications (§7) | WP10 kits |
| ilvl | per-stack item level; equals the def's `_grug_ilvl` for a shop item and `min(mob level, 60)` for a drop | drop roller |
| `grug_req_level` | equals the stack's ilvl; **absent on an item that has no ilvl at all** (§6.1) | WP5 on first touch |
| refined | plain boolean, alongside `grug_quality` | WP10 refinement |
| masterwork / cultural finish / PvP special | separate structured channels | WP10 |

`grug_ench` must be an **ordered** record, not a `stat → value` map: §6b.4
fills the four slots as prefix, suffix, prefix, suffix, so the slot index is
what decides whether a rolled `+Str` appears as *Heavy* or *of the Bear*,
and a map cannot represent that.

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
| world | 0.00–0.60 | normal-mob drops (and the shipped vendor Uncommon call) |
| crafted-fine | 0.30–0.80 | crafted Uncommon ("fine" recipes) — WP10 |
| elite | 0.30–0.90 | elite drops, dungeon/crate loot |
| rare | 0.50–1.00 | named-rare drops |
| crafted-masterwork | 0.60–1.00 | crafted Rare incl. Grudgeforged items — WP10 |
| boss | 0.80–1.00 | apex hoards, race Kings |

Legality is **§6.2 and only §6.2**: an affix is legal on a family iff its
stat is in that family's pool, and no item may carry the same stat twice
across its four ordinary slots.

**Affix counts are decided, not free** (§6.1): for a source **without a
crafter** — mob drops and vendor stock — Uncommon rolls **1 or 2 affixes at
60/40** and Rare **3 or 4 at 70/30**. A vendor Uncommon that always produced
two affixes would silently be the best-value item on the shelf. For a
**crafted** item the count is not rolled at all: it is the crafter's mastery
slot count (§6b.5/§6b.6). The shipped three-argument call therefore keeps
rolling the count, and WP10's path needs an **optional fourth argument that
fixes it** — `roll_enchants(stack, ilvl, window, count)` — so a Master's
four-slot masterwork cannot come back with three.

**Temper re-roll windows** (§7), needed as a WP5 data seam because WP10's
kits write through it: first application **0.50–0.95**, second
**0.60–1.00**, `grug_upgrades` caps at **2**, and a temper never changes
the affix count or the quality tier. §6b.7's ordinary special variant is a
further structured per-stack field which keeps its full 2+2 slots on top of
its one authored effect; WP5 stores and displays it, WP10 writes it.

### 3.3 Drop layer (§5, §5.1)

Drops obey the shipped player-tag rule. `ilvl = min(mob level, 60)` (§5;
the clamp exists for the level-65 Kings), and **a dropped item's material
tier must match the mob's tier** — a T3 item drops from level-21–30 mobs
and nowhere else, which is what stops the drop table from becoming a side
door around the depth gate of §3.0.4. The depth axis adds **no** gear layer
at any depth.

| Source | Uncommon | Rare | Window |
|---|---|---|---|
| Normal mob | 3% | — | world |
| Elite (armor 80) | 20% | 3% | elite |
| Named rare (armor 70) | 100% | 25% | rare |
| Apex boss / race King | — | 100% | boss |

The named-rare row is **additive, not a ladder** (§5.2): every kill yields
the guaranteed Uncommon *and* rolls the 25% Rare independently *and* keeps
the shipped 100% signature trophy. The Rare never replaces or upgrades the
guaranteed Uncommon, and the trophy must survive this WP's changes to the
drop function.

A dropped item carrying affixes is by definition refined (§6b.3), which is
why no refinement word appears in a drop's name (§6b.4).

**The distribution is decided in the design, not here** (§5, 2026-08-13):
**one uniform draw over the concrete registered base items of the mob's own
tier** — the bracket catalog's whole list, no slot pre-selection, no
per-family weighting. Ordinary found gear stays below crafted gear by
construction (`world` 0.00-0.60, `elite` 0.30-0.90 and `rare` 0.50-1.00
against crafted-masterwork's 0.60-1.00, with different affix counts on
top), so no rate tuning carries that guarantee. **Boss and King loot is the
deliberate peer**, not a lesser source: §6.4 names crafting and bosses as
the two 0.60-1.00 windows. What the BACKLOG row
means by "retune elite/high-tier gear drops against G2 and trophy demand" is
therefore an **audit** (task 8): if it shows the §5.1 rates erasing demand
for crafted G2 gear or named-rare trophies, the fix is a change to §5.1 in
`items_crafting.md`, never a private weighting in the drop code.

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
  and PvP-special data. **A different culture overwrites** the old finish
  and appearance at full material/service cost with no refund; only
  **reapplying the same culture** is rejected, and it is rejected before any
  consumption (§4.2).
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

### 3.6 The stats must actually apply

An affix that displays correctly and changes nothing is the failure mode
this WP exists to avoid, so WP5 owns the **consumption** of all nine
stats — Str, Int, Dex, HP, Mana, Crit%, Dodge%, attack speed%, armor% —
not only their storage. They aggregate per player, cached, refreshed from
the equipment-change notifier and applied **before** `grug_classes.apply_stats`,
which is the deliberately first consumer of that notifier (AGENTS.md).
Crit, dodge and armor feed the existing `grug_core` accessors; attack speed
writes the per-stack capability override of §3.2.

WP5 also applies the **refinement bonus** itself: `+15%` base damage or the
armor equivalent, rounded half-up like every other value on the curve, plus
the doubled durability *number* in the grey line (§6b.2). WP22 keeps wear
and the durability calibration; the bonus is item data and belongs here.

### 3.7 Fallen Crown conversion (§5.4)

The BACKLOG row names this explicitly, and it is per-stack data rather than
a recipe, so WP5 owns the transaction and WP10 owns the recipe that
triggers it: a Fallen Crown substitutes **one-for-one** for a qualifying
named-rare trophy in the trophy slot of an ordinary Master-tier masterwork,
including a T6 Grudgeforged item, and grants the **same** stat/affix budget
and quality window — the crown adds royal provenance and visual identity,
never a bigger roll. The Crown is one registered item carrying per-stack
defeated-race provenance, not six currencies.

## 4. Tasks

1. **`grug_items` skeleton and the meta model** — one global table, the
   §3.1 keys, `core.serialize` for `grug_ench`, and the single idempotent
   regeneration entry point. No behavior yet.
2. **Roll engine** — §3.2's tables as data, the six windows, §6.2 pool
   legality plus the no-duplicate-stat rule, and the public
   `grug_items.roll_enchants(stack, ilvl, window[, count])` — the
   three-argument form exactly as WP7 already calls it
   (`stock.lua:200-203`), plus the optional fourth argument that fixes the
   count for WP10's crafted path. Vendor Uncommons must light up without
   touching `grug_traders`.
3. **Description regeneration** — name (prefixes + noun + combined
   suffixes), quality color, preserved `Item level` and grey base-stat
   lines, the "Refined" line, one line per affix, then the separate
   cultural-finish and PvP-special lines naming culture/target and value.
   Idempotent: regenerating twice must produce a byte-identical string.
4. **`grug_req_level` enforcement** — the effective-ilvl resolver (§2) plus
   one branch in the existing group-filtered `allow_put`
   (`equipment.lua:304`), refusal with a chat message through the
   **existing throttled channel** (`:111`), never a silent "equips but
   grants nothing". It must refuse a Common vendor item exactly as it
   refuses a rolled drop.
5. **Drop layer** — §3.3's table wired into the shipped `drops` functions,
   respecting the player-tag rule, the tier match and the ilvl clamp; the
   named-rare row stays additive and keeps its trophy.
6. **Stat aggregation and the refinement bonus** — §3.6: the cached
   per-player aggregate ahead of `apply_stats`, all nine stats live, and
   the +15%/×2 durability application.
7. **The two channels** — storage, the different-culture overwrite and
   same-culture/same-target rejections, the shared cap evaluation and the
   Character page's effective/raw display; plus the Fallen Crown
   substitution of §3.7.
8. **Drop-distribution audit** — a reproducible script that reports, per
   level band, the expected value of found gear against crafted G2 gear and
   named-rare trophy demand, run against §5's decided uniform draw and
   §5.1's decided rates (§3.3). Record it like `wp6_spawn_budget.md` records
   spawn calibration. If it finds a problem, the fix is a change to §5.1 in
   `items_crafting.md`, proposed to the design owner — never a private
   weighting inside the drop code.
9. **Trinket exception path** — one prefix, one suffix, no base-stat line,
   no refinement, no durability, in the shared code so WP10 only registers
   items. Temper windows and the special-variant field ship as seams here.

## 5. Acceptance gates

1. `tools/bin/luac51 -p` clean on every changed file; the five
   `luanti-lua.md` grep sweeps clean; **exactly one intentional
   `SETGLOBAL grug_items` and no other** (verify with
   `luac51 -l -p … | grep SETGLOBAL`).
2. **Vendor Uncommons appear with no edit to `grug_traders`** — the proof
   that the global and the signature are right.
3. A level-1 character cannot equip a level-30 drop **nor a level-30 Common
   bought from a vendor** — both paths go through the effective-ilvl
   resolver — and an equippable with no ilvl at all (a `default:` sword)
   stays freely equippable. The refusal uses
   the existing throttled channel: **at most one burst per 2 s per player**,
   distinct reasons allowed inside a burst
   (`grug_inventory/equipment.lua:118-124`) — not "once per drag", which
   that channel does not promise.
4. Regeneration is idempotent (twice → byte-identical) and produces the
   correct base-stat line for **off-anchor** ilvls: an ilvl-27 drop shows
   the §3.1/§3.2 curve value for 27, not the catalog's ilvl-20 number.
5. Affix legality and counts are proven by an **exhaustive matrix** over
   family × band × window × quality with an injected fixed-seed RNG — no
   duplicate stat across the four slots, no affix outside its §6.2 pool,
   observed 1/2 and 3/4 frequencies matching 60/40 and 70/30, and slot
   order prefix/suffix/prefix/suffix in the generated name. The same matrix
   covers the **fixed-count** path: `count = 1..4` must produce exactly that
   many affixes every time, so a Master's four-slot masterwork can never
   come back with three.
6. A T3 item never drops from a mob outside level 21–30; no drop appears
   at any depth that would not appear on the surface; a King drops at
   ilvl 60, never 65; a named rare yields Uncommon + independent 25% Rare +
   trophy in the same kill.
7. Cap audit: a deliberately overcapped set shows `raw > effective` and
   grants no combat power above the cap.
8. Every one of the nine stats is measurably consumed by its **existing
   authoritative consumer**, and those are not one function: attributes
   through `grug_classes.get_attributes`, HP through `get_max_hp` (which
   `apply_stats` pushes into `hp_max` — that function sets nothing else),
   Mana through `get_max_mana` and the resource clamp/ticker, crit and dodge
   through `get_crit_chance`/`get_dodge_chance`, armor through
   `grug_core.get_armor_percent`, attack speed through
   `grug_abilities.swing_stats`. A refined weapon deals the +15% (half-up)
   damage. The display-only failure mode is what
   this gate exists for; it prescribes no new character-sheet layout, which
   `inventory_equipment.md` would have to own.
9. The channel transitions behave as specified at the **data layer** WP5
   owns: applying the same culture is a rejected no-op, a different culture
   replaces the stored finish, an identical PvP target is a no-op and a
   different target replaces the stored special. Material consumption, the
   full-cost charge and the no-refund rule belong to WP10's recipes and are
   gated there.
10. The Fallen Crown substitutes one-for-one for a qualifying named-rare
    trophy in an ordinary Master-tier masterwork **and** in a T6
    Grudgeforged item, yields the same affix budget and roll window as the
    trophy path, consumes exactly one Crown, and preserves its per-stack
    defeated-race provenance through description regeneration.
11. The drop-distribution audit of task 8 is reproducible and its report is
    committed.
12. **Runtime test plan for the user** (agents cannot run the Flatpak GUI):
    kill boars until an Uncommon drops and read its name/lines; try to
    equip an over-level item; buy an Uncommon from a vendor; confirm a
    rolled attack-speed affix visibly changes the swing rate and that a
    +Str affix moves the Character page number.

## 6. Composition

One implementation agent per task group (1–3 data/display, 4–6
rules/drops/stats, 7–9 channels/audit/trinket seam), then the mandatory
Opus review per `docs/process/wp-workflow.md` with a second reviewer on the
roll/cap arithmetic and the stat aggregation. WP5 changes no mapgen and
needs no fresh world.

**Known stale comment (not fixed here, no code changes in a design round):**
`mods/ITEMS/grug_gear/init.lua:335` still reads "ALL TWELVE ARE ONE-HANDED"
directly above a `VENDORED_WEAPONS` list of eight. The rule is unchanged —
every entry is one-handed — only the count is stale since the mese and
diamond tool tiers were deleted. Whoever next touches that file corrects it.

**Design provenance:** eight rules this card depends on were open or implicit
when it was first drafted and were settled on 2026-08-13 in
`items_crafting.md`, not here — the positional prefix/suffix side (§6b.4),
the `min(mob level, 60)` drop clamp (§5), the `fpi / (1 + p)` attack-speed
conversion and the no-ilvl-no-requirement exemption (both §6.1), the scope
of the 60/40 and 70/30 affix counts to sources without a crafter (§6.1), and
the uniform draw over the tier's concrete base items for drops (§5), the
imbue kit's crafterless 60/40 count (§7) and the boss window's peer status
(§5). The card quotes them; the design document owns them.

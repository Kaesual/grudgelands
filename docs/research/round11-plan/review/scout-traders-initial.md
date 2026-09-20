# R11 SCOUT-TRADERS independent review — findings

Candidate: `52a6111a3783b465910ba289eefaff6275eb781f`  
Base: `6bd8a6b8`  
Review: fresh native GPT-5.6 Sol, read-only  
Result: **not clean**

## Medium

1. **`mods/ENTITIES/grug_traders/stock.lua:126-127,235-249` — the implementation resolves an active living-spec contradiction without an authoritative ruling.** `docs/design/items_crafting.md:1333-1341` still says exactly **one** extra family is withheld each rotation, then names five active extra families and only says the slot count is below the pool size. This change retains three slots while expanding the pool from four to five, so two families are withheld and a Bowyer bracket is empty whenever bow is omitted (before also considering an Uncommon replacement). The production comment was changed from one withheld family to two, but the authoritative design was not. The code may be the desired interpretation, but the package cannot establish whether four rotating slots or the current three-slot/two-withheld behavior is binding; the living spec must be reconciled or an existing ruling cited before acceptance.

2. **`tools/r11_scout_traders/stock_kat.lua:42-47,105-116` and `tools/r11_scout_traders/README.md:8-13` — the focused evidence never enables the shipped quality roller and therefore makes a false “exactly four Tanner items” claim.** The fixture saves `grug_items` but never installs `grug_items.roll_enchants`, so `enchant_roller()` is always nil and the 1-in-5 Uncommon branch cannot execute. With a temporary copy of the same fixture changed only to provide a roller, the targeted LuaJIT run fails at `Tanner must expose four leather slots`: an Uncommon leather item from `cat.all` correctly survives the filter beside the four fixed Common pieces. Thus the production quality-chain path is not tested, and the README's exact-four statement is false for the actual game. The fixture should cover Common and Uncommon filtered views, including price ×3, quality metadata/roll handoff, permitted duplicate identity at different quality, and the render/buy recomputation path.

## Low

3. **`mods/ENTITIES/grug_traders/stock.lua:106-107,248` — nearby rotation comments still describe retired cardinalities.** “three caster forms” refers to the removed scepter/orb model, and the degenerate-case note says “3 extras, 2 slots” although the active pool/slot counts are five and three. These comments sit inside the authority explanation for the changed algorithm and make future maintenance error-prone.

## Verified behavior

The real UI path consumes `vendor.brackets` and `vendor.bracket_filter`: it renders only entitled tabs, calls `vendor_bracket_stock` for display, recomputes the same filtered offer on purchase, and cross-checks item, price and quality against the shown snapshot. Bowyer General supplies `grug_gear:arrow` and no obsolete mob-arrow bundle; Tanner filters by armor class 2; Smith, Armourer, general and race vendors retain their declared full-catalog behavior. No duplicate profession class or second gear catalog was introduced.

Targeted verification: the committed LuaJIT stock KAT passes; a temporary quality-enabled variant produces the concrete failure described above; `git diff --check` passes. No PUC runtime, broad matrix, production edit, commit, sync, push or user-world mutation was performed.

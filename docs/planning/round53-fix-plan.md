# Round 53 fix round — 0.53.1

Coordinator: Claude, 2026-10-20, from the user's feedback on the built Round 53 (main `3c45c726`, 0.53.0, not
pushed). Status: **planned**.

0.53.0 is not pushed. 0.53.1 (**compatible**, no step of its own) is built on top, the user runs **one** GUI test on
0.53.1 (the 0.53.0 migration first, [Round 53 GUI checklist](round53-plan.md#gui-checklist-round-53) plus §5 here),
and both are pushed together.

## 1. The user's rulings (2026-10-20, quoted where short)

1. **Areas, cones and group heals: one rule, no line of sight.** "Ich würde für alle Skills Variante A nutzen. Es
   ist einfach, billig, und vermeidet unerwartetes Verhalten. Das gleiche Verhalten bitte für Kegel, und auch für
   Heilungen." Every area hits everything accepted by its filter within the skill's horizontal radius and ±3 in
   height around its anchor (cones: their angle and radius around the caster; groups: their radius around the
   caster); no line of sight. The ground anchor and "No ground found." stay.
2. **Flight ban: warning band and minimap.** The band becomes **40** nodes (today 48), the HUD warning stays shown
   while inside it; the minimap shows the no-fly areas of the rider's faction as a red overlay **only while the
   player sits on a flying mount** (like the Claim Stone overlay). The dismount check itself stays per step
   (coordinator default: a 1 s check would let a fast flyer travel a second deep into enemy land before falling).
3. **Shield and spellbook tooltips** name the classes that can really equip them (shield: Warrior; spellbook: Mage,
   Priest), from the same rule that decides equipping.
4. **The same trinket in both slots is allowed** ("aus meiner Sicht darf man das gleiche Schmuckstück in beiden Slots
   tragen"), different tiers too; each special's two-slot rule (additive with a cap, or highest only) applies to the
   pair.
5. **Undead:** zombies — the whole zombie family including the sun-dried husks and all sub-types — never attack an
   Undead player on their own, day and night; a zombie the player attacked fights back as today. Skeletons and other
   undead are unchanged. The racial text says so.
6. **Elves:** ability range **+3 m** (today +5), still not for melee skills.
7. **Dwarves:** "Thick Skin" **+5 % armor rating** replaces −20 % fall damage.
8. **Effective range in tooltips:** every skill with a pointing range shows "Range: N m" with talents and the elf
   bonus included; skills whose `range` is really a radius around the caster show none; hardcoded "N m" literals in
   the texts go.
9. **Skeleton archers hold a bow:** the bow-shooting skeletons (Skeleton Archer, Skeleton Raider, Frost Stray) show
   a bow in the hand (the mesh's wield slot, today blank) — a shipped bow texture, no new art.
10. **Pick fruit with right-click:** blueberry bushes and apples are picked with right-click (the bush/tree stays,
    the same regrowth as today); left-click digging keeps working; herbs, spices and wood stay left-click.
11. **Icons:** the 28 icons the user picked on the pick page ship; the 8 sent back (Bellow, Blink, Broadstroke,
    Charge, Close Dance, Parry, Halt, Finisher) go through an Astra pass 2 and a second small pick page; whatever is
    picked before the GUI test ships in 0.53.1, the rest keeps today's icon.

## 2. Lanes

All Opus, each independently reviewed (logic deltas of fix rounds too); merge order as they finish, main merged into
a later lane before its review.

| Lane | Items | Main files (leads, re-check) |
|---|---|---|
| **SKILLS** | 1, 6, 8 | `grug_core/area.lua` (`query`, `cone`, `group`), `grug_classes/init.lua` (elf perk), `grug_abilities/init.lua` (`description_prefix`, `get_range`), the kit `description_for` texts (`kits_priest.lua`, `scout.lua`, `kits_warrior.lua`, `kits_mage.lua`) |
| **FLIGHT** | 2 | `grug_mounts/entity.lua` (`WARNING_DISTANCES`, `column_flight_state`, the island ids), `grug_map/base.lua` (a sibling of `claim_overlay`), `grug_map/minimap.lua` / `minimap_view.lua` (a flight layer next to `claim_mode`) |
| **GEAR** | 3, 4 | `grug_gear/permissions.lua` (`usable_by` from `grug_inventory.HAND_RULES`), `grug_inventory/equipment.lua` (`allow_unique_trinket`), `grug_trinkets/init.lua` (two-slot rules), `grug_quality` refresh of stored descriptions |
| **RACE** | 5, 7, 9, 10 | `grug_mobs/init.lua` (`truce_active`, `_grug_ignore_player`), `zombie.lua`, `zero_asset_variants.lua` (husks), `grug_classes/init.lua` + `perks.lua` (dwarf, undead texts), `grug_quality/init.lua` (`raw_armor`), `combat.lua` (fall perk removed); `skeleton_archer.lua`, `skeleton_raider.lua`, frost stray (slot 3); `default` blueberry bush and apple nodes (via `core.override_item` from a grug mod, VENDOR rules) |
| **ART** | 11 | `grug_abilities/textures/`, `grug_classes/textures/`, their `LICENSE-media.md`; inputs `tools/r53_art/icons/` (drop-01, drop-02) and `r53/astra-icons/decisions.md` |
| **D** | all | CHANGELOG 0.53.1, STATUS, BACKLOG, design docs (`ability_targeting.md`, `classes.md`, `mounts.md`, `inventory_equipment.md`, `items_crafting.md`, `world.md` racials), this plan's completion |

Version: 0.53.1 in `game.conf` and `tools/web_data/upgrade.json` by lane D (compatible, no new step; the 0.53.0 step
stays declared). ART merges last before D so the docs see the final icon set.

## 3. Lane goals (briefs add file facts)

- **SKILLS:** remove the line-of-sight test from `area.query`, `area.cone` and `area.group` (keep `clear_line` if
  anything else uses it; otherwise delete it); fixtures that pinned LOS behaviour updated with a reason; the elf perk
  3; a "Range: N m" line in `description_prefix` (per-def opt-out for radius-type ranges), the literals removed;
  tooltips refresh as today. Report the per-cast cost before/after (comparison only).
- **FLIGHT:** band 40; the overlay rendered once per world per faction from the same zone data as the dismount rule
  (one shared function, so overlay and rule cannot disagree), cached like the claim overlay; a flight layer shown
  only while mounted on a flyer, folded into the existing minimap rebuild; report startup render time and media size.
- **GEAR:** `usable_by` derived from `HAND_RULES`; stored descriptions refreshed; the unique-trinket block removed,
  each special's two-slot rule checked with the same identity twice (fixture per special); a refusal that remains
  gets a feed message.
- **RACE:** the truce as ruling 5 (no clock, the whole zombie family by one flag on the family's base defs and the
  husk family); the racial text; dwarf +5 % armor rating in `raw_armor` (combat and Character page); the fall perk
  removed; skeleton bows (headless capture to check orientation; if the shipped bow looks wrong on the mesh's plane,
  stop and report before any new art); right-click picking for blueberry bushes and apples (the bush/apple node
  changes exactly as when dug today; protection: picking is allowed where digging the node would be — report what
  that means in towns).
- **ART:** copy the 28 (and later the pass-2) picks over the shipped files (byte-identical to the drop files; for
  "old" the 0.51 file from `dea1d163`), licence rows updated, the three retired icons stay deleted.
- **D:** as the table.

## 4. Rules

The Round 53 common brief and review brief apply (`~/projects/grudgelands-orchestration/r53/common-brief.md`,
`review-common.md`), with the classification **compatible** for every lane. Fixtures: run only your own fixture plus
the fixtures that actually test the behaviour you change (not every fixture that loads a changed file); the full run
once before your report; name what you ran and why.

## 5. GUI checklist (0.53.1, after the Round 53 checklist)

1. A Meteor/Fire Rain/Censure on stairs, in a cave and next to a wall: everything within the radius and ±3 is hit,
   also behind the step edge and through a thin wall; Ice Wave and Flourish the same; Hearten and Haven reach allies
   behind a corner.
2. Fly towards enemy land: the warning appears 40 nodes before the border and stays; on a flyer the minimap shows the
   red no-fly areas; dismounted or on a ground mount it does not.
3. Shield and spellbook tooltips name the right classes; two identical trinkets can be worn, their effect follows the
   special's rule.
4. As an Undead: zombies and husks ignore you by day and by night until you attack them; skeletons still attack.
5. As an Elf: ranges +3; tooltips show "Range: N m" including talents (e.g. a range talent changes the number).
6. As a Dwarf: the Character page shows the higher armor rating; fall damage is normal.
7. Skeleton archers hold a bow while drawing.
8. Right-click a blueberry bush and an apple: picked, the bush stays; left-click still works; in a town.
9. The new icons on the hotbar, the skill row and the Talents page (32 px).

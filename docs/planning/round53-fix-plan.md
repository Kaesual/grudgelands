# Round 53 fix round — 0.53.1

Coordinator: Claude, 2026-10-20, from the user's feedback on the built Round 53 (main `3c45c726`, 0.53.0, not
pushed). Status: **built** (2026-10-20, all five lanes merged and reviewed, [completion](#completion-2026-10-20)), awaiting
the user's GUI test; 0.53.0 and 0.53.1 are pushed together on the user's word.

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
   tragen"), different tiers too. Simple bonuses add as today (Manawell, Battlebeat, Mercy Seal, Apothecary: their
   caps are twice the T6 value, so two equal ones double fully). The two effect specials (Last Light, Reclaimer's
   Mark: "highest only, shared cooldown") fire once: the stronger copy gives the effect and **the other copy
   strengthens it by 5/10/15/20/25/30 % by its tier (T1–T6)**; one shared cooldown as today. This applies to any two
   trinkets with the same special. Their tooltip says "Worn twice: the second one strengthens the effect by N %."
   (the user, 2026-10-20: "Ja, Schmuckstücke mit Verstärkung").
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
11. **Icons:** all 36 redrawn icons the user picked ship (pick page 1: 28; pick page 2 after an Astra pass 2: the
    other 8, all decided — "diesmal sind keine mehr offen, ich bin zufrieden"). The sources per key are in
    `~/projects/grudgelands-orchestration/r53/astra-icons/decisions.md` (pass 1 and pass 2 tables).

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
- **GEAR:** `usable_by` derived from `HAND_RULES`; stored descriptions refreshed; the unique-trinket block removed;
  simple specials add (fixture: two equal T6 double, the cap holds); Last Light and Reclaimer's Mark: the stronger
  copy's effect × (1 + the other copy's tier share 5–30 %), one shared cooldown, the tooltip line (fixture per
  tier pairing); a refusal that remains gets a feed message.
- **RACE:** the truce as ruling 5 (no clock, the whole zombie family by one flag on the family's base defs and the
  husk family); the racial text; dwarf +5 % armor rating in `raw_armor` (combat and Character page); the fall perk
  removed; skeleton bows (headless capture to check orientation; if the shipped bow looks wrong on the mesh's plane,
  stop and report before any new art); right-click picking for blueberry bushes and apples (the bush/apple node
  changes exactly as when dug today; protection: picking is allowed where digging the node would be — report what
  that means in towns).
- **ART:** copy all 36 picks (decisions.md, pass 1 and pass 2) over the shipped files (byte-identical to the drop files; for
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

## Completion (2026-10-20)

All five lanes are merged on main and independently reviewed (Opus, all MERGE); this lane D (this section, the design
docs and the status owners) follows on main `2c5ecbc2`. **0.53.1 is compatible:** no step of its own, the 0.53.0 step
stays declared. Nothing in world generation changes and nothing writes world nodes beyond what a dig does. **Push:**
not pushed; origin/main stays at `e4d5c9d5` (0.52.1); 0.53.0 and 0.53.1 go out together on the user's word.

### Lanes

Worktrees and branches were named `r531-<lane>` (the name `r53-d` was taken), from main `4e8a177d`. Main's first-parent
merges, in order:

| Lane | Merge (lane tip) | What | Review |
|---|---|---|---|
| ART | `272cf9e6` (`fe2d53eb`) | the 36 picked icons (26 skills, 10 talents: 20 from drop-01, 8 from drop-02, 8 `old` 0.51 files from `dea1d163`) byte-identical over the shipped files; licence rows in both `LICENSE-media.md`; `tools/r531_art/ship_icons.py` (`apply`, `check`, `rows`, `sheet`) | MERGE (no findings) |
| FLIGHT | `ad1157eb` (`010da19b`) | band 40 (`grug_mounts.WARNING_WIDTH`, now the single source), the shared rule `grug_mounts.flight_rule` in the new `grug_mounts/flight.lua`, the minimap's no-fly overlay on a flyer (`flight_overlay` in `grug_map/base.lua`, `flight_mode` in the minimap) | MERGE (a doc line for D, backlog notes) |
| SKILLS | `144a7cc9` (`b60e52be`) | no line of sight in `area.query`, `area.cone` and `area.group` (`clear_line` deleted); the group is the same ±3 cylinder; the "Range: N m" tooltip line from `get_range`; the pointing-range literals out of the skill texts, then (review Low 1, delta `b60e52be`) out of the talent texts too ("in your crosshair") | MERGE; the text delta checked by the coordinator |
| GEAR | `8e146dfe` (`597c8d21`) | `usable_by` for hand pieces from `grug_inventory.hand_accepts` (the equip rule); the unique-trinket block and `grug_trinkets`' second uniqueness guard (`effects.seen`) removed; the pair share 5–30 % and its tooltip line | MERGE (backlog notes) |
| RACE | `2c5ecbc2` (`8779f0c8`) | the zombie truce without the clock on the zombie and husk families (`_grug_truce_perk`); Elf +3 m; Dwarf Thick Skin +5 % armor rating in `raw_armor` (the fall perk gone); the bow in slot 3 of Skeleton Archer, Skeleton Raider and Frost Stray (`grug_gear_bow_wood.png`); right-click picking (`grug_gathering/pick.lua`) | MERGE (GUI and backlog notes) |
| D | this section | the design docs, this completion, STATUS, CHANGELOG, BACKLOG, ROADMAP, README, the AGENTS pointer, the version | independent docs review |

Main has 229 portable fixtures (4 new: `r531_skills`, `r531_flight`, `r531_gear`, `r531_race`; ART's verifier is
`ship_icons.py check`). `mods/` against 0.53.0: +645 −334 lines in 35 text files, 2 new Lua files (`flight.lua`,
`pick.lua`), 36 PNGs replaced.

### Decisions during the round

**The coordinator** (HANDOVER, answers to lane questions; each built as stated):

- The elf value (5 → 3) and every racial text were built by RACE, which owns the race definitions (the plan's §2 said
  SKILLS); SKILLS reads the perk.
- **SKILLS:** a group is the ±3 cylinder around the caster's feet like every other area (was a sphere: an ally 4 m or
  more above or below is no longer healed, one up to 3 m up at the full radius now is). Fireball's splash keeps its
  ±2 band (radius 2). The range line is shown by default for the hostile and friendly target kinds; the self kinds show
  none unless `range_shown = true` (Meteor, Fire Rain, Winter Field, Censure), and `range_shown = false` opts any skill
  out (a default plus four opt-ins instead of the plan's opt-out, since every radius-type skill is a self kind). The
  talent texts' pointing-range literals became "in your crosshair" (review finding); radii, Blink's 10 m teleport and
  the talent increments stay.
- **FLIGHT:** the ocean is red too, so the overlay equals the dismount rule exactly; bays and lakes of a mainland zone
  stay clear. A minimap the player switched off stays off (claim mode forces it on; flight mode does not).
- **GEAR:** Reclaimer's Mark's Rage restore is strengthened too (6 × 1.3 = 7.8 Rage at T6 + T6); the tooltip writes
  "…by 30%." (the repo's "+5%" spelling).
- **RACE:** husks had no truce flag before 0.53.1 (the old night truce never covered them); now all 28 zombie-family
  sub-types (13 zombie-, 15 husk-based) carry it through `copy_base_def`. Picking is one `core.node_dig`, so it is
  protected exactly like a dig: in towns, villages, capitals, camps, POI cores, on roads and in the other faction's
  home land it is refused with the usual hint, and in a claim only the owner and "everything" players pick. The
  Dawnmere orchards and the human capital green are therefore not pickable — **open question to the user** (below).

### Deviations from the plan

- Ruling 6 moved from SKILLS to RACE (above).
- **GEAR** removed a second uniqueness guard the brief did not name (`effects.seen` in `grug_trinkets`), without which
  a second copy counted for nothing; and stubbed `grug_inventory.hand_accepts` in `r33_c5` and `r45_eu`.
- **FLIGHT** made the unused `catalog.lua` `WARNING_WIDTH` the band's single source; `r30_p4`, `r451_mc` and `r45_pt6`
  now load `flight.lua` (r30_p4's pinned band 48 → 40).
- **SKILLS** updated the fixtures that pinned line of sight, each with a reason (`r52_core`, `r53_priest`, `r53_hooks`,
  `r53_mage`), and named Bladecraft's shot range in its text (its own line shows the 3 m blade).
- **RACE** changed `grug_core/combat.lua` outside its list (only the Dwarf fall multiplier deleted).

### Numbers worth keeping

- **Area cost per call** (SKILLS, measured, `tools/r531_skills/probe.sh`, same seed and scene, 2000 calls): query
  25.38 → 8.34 µs, cone 10.84 → 3.80 µs, group 20.10 → 11.36 µs. `r31_pvp` medians before/after within noise
  (combat_ray 13.76/12.90 µs, mob punch chain 18.55/16.99, enemy-player chain 19.23/21.79, tick of 100 players
  82.0/88.7; the combat path is untouched).
- **No-fly overlay** (FLIGHT, measured, 2 boots, seed 42, normal quality): render 0.05 s (210 rule calls), 29,223 bytes
  for both factions; the Claim Stone overlay beside it 0.51–0.53 s and 26,465 bytes; the base map 12.3–12.6 s
  (re-rendered once at the first start, because the cache key now holds `flight.lua`'s source). At high quality about
  0.4 s (estimated).
- **Warning band** (FLIGHT fixture, 16 headings): the warning shows at every position within 39 nodes and never beyond
  40; between 39.2 and 40 it can drop (the 16-direction sampling, as before).
- **Trinkets** (GEAR fixture): all 36 tier pairings of Last Light and Reclaimer's Mark in both slot orders; T6 + T1 Last
  Light = 10 % × 1.05 (21 of 200 HP), T3 + T3 = 5 % × 1.15; Reclaimer T6 + T1 = 42 of 1000 Mana; two T6 Manawell 1.00,
  Mercy +12 %, Apothecary +30 %, Battlebeat 4 (the caps).
- **Icons** (ART, measured): 36 files of 5,763–9,208 bytes, 64×64; licence coverage 44/44 skill and 74/74 talent icons.

### Classification

**Compatible**, no step of its own:
`{"schema": 3, "version": "0.53.1", "map_reset": ["0.40.1", "0.46.0", "0.47.0", "0.48.0", "0.49.0", "0.51.0"], "new_server": [], "migrate": ["0.44.0", "0.45.0", "0.47.0", "0.48.0", "0.53.0"], "map_reset_pass": "0.50.0"}`.
A world on 0.53.0 moves on without a step; a world on 0.52.1 runs the 0.53.0 step first. Saved state read or written
differently: none. Skill and trinket stacks' stored `description` meta is rewritten on the existing refresh paths (the
join, a talent or level change, an equipment change); the perk keys (`zombie_truce`, `armor_rating_mult`) live in
code; provocation memory stays runtime-only; the `grug_map_flight_*` tiles live in the world folder like the claim
tiles and are rebuilt from the cache key.

### Open notes

- **For the user:** fruit picking in towns. Today a pick is protected like a dig, so town and village orchards
  (Dawnmere, the human capital green) cannot be picked, by either click. Recommended: keep. The alternative is a
  fruit-only exception to world-feature protection inside `pick.lua`.
- The reviews' and reports' notes are in the [0.53.1 carry-overs](../../BACKLOG.md#0531-carry-overs).

### GUI checklist (0.53.1)

Desktop and the web build, on the synced game, in **one** test of 0.53.1: first the 0.53.0 migration and the
[Round 53 GUI checklist](round53-plan.md#gui-checklist-round-53) (world
`~/projects/grudgelands-orchestration/r53/worlds/r53_ms_0.52.1`, logins `warrior`, `mage`, `priest`, `scout`, `sleeper`,
`walker`, password `it-<name>`; a copy of the production world; a fresh world), then this list. Round 53 item 4's stair
case changes with 0.53.1: a target one step up behind the riser **is** hit now (item 1 below).

1. **Areas without line of sight:** Meteor, Fire Rain and Censure on stairs, in a cave and next to a wall: everything
   within the radius and ±3 m is hit, also behind the step edge and through a thin wall; a target on a floor 4 m or
   more above or below is not. Ice Wave and Flourish the same through a wall; Hearten and Haven reach allies behind a
   corner, and an ally 4 m or more above or below is not healed (the ±3 cylinder).
2. **Flight:** fly towards enemy land: the warning appears about 40 nodes before the border and stays; on a flyer the
   minimap shows the red no-fly areas; dismount or switch to a ground mount: the red is gone at once. At a coast: is
   the red ocean with clear bays acceptable, and is red on the orange mesa readable? Hold a Claim Stone on a flyer:
   both overlays show.
3. **Gear:** a shield reads "Usable by: Warrior", a spellbook "Usable by: Mage, Priest" (an old stack too, after a
   relog). Two identical trinkets (two Last Light, different tiers too) equip without a refusal; the tooltip says
   "Worn twice: the second one strengthens the effect by N%."; below 25 % HP one absorb, then the 120 s cooldown.
4. **Undead:** zombies and husks ignore you by day and by night until you hit one; skeletons still attack.
5. **Elf and the range line:** ranges +3; tooltips show "Range: N m" with talents (Fiery Spark 20 m, 23 with Far Cast
   3/3, +3 for an Elf); Strike stays 3 m for an Elf; Hold Ground, Ice Nova and Hearten show no range line; Meteor,
   Fire Rain, Winter Field and Censure show theirs.
6. **Dwarf:** the Character page shows a 5 % higher armor rating (one decimal); fall damage is normal.
7. **Skeleton bows:** Skeleton Archer, Skeleton Raider and Frost Stray hold a bow while drawing (upright in front of
   the body), at the hip while standing.
8. **Picking:** right-click a ripe blueberry bush and a wild apple outside a town: picked, the bush stays and regrows;
   left-click still works; in a town it is refused with the protection hint. Known effects: no pick sound for the
   picker; a Scout's Loose aimed at ripe fruit within 4 m picks instead of shooting; a block held + right-click on
   ripe fruit picks (Shift + right-click places).
9. **Icons:** the 36 new icons on the hotbar, the skill row and the Talents page at 32 px; Strike (old) beside Retort
   (new) with different swords by design; Word of Ruin, Mend and the old Scout icons in their 0.51 colours.

### Round-end gates

Lane D on its branch from `2c5ecbc2`: `r37_dc` PASS, `check_upgrade.py` (0.53.1 against origin/main) and
`check_fresh_server.py` PASS, the docs link check (the lane report); no full fixture run (a docs lane). Each code lane
ran the full `run_fixtures.sh` once (226/0 for SKILLS, GEAR's reviewer and RACE; ART 225/0; FLIGHT 224/2, both fixed and
rerun). The round end on main (full fixtures, `check_upgrade.py`, `check_fresh_server.py`, one boot, the sync) is the
coordinator's.

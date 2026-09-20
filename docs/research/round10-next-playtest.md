# Round 10 fresh-world playtest checklist

This checklist applies only after the staged EQUIP, GAME, WORLD, CAP, ART and
MAP-B candidates are integrated and synchronized. Offline fixtures and renders
do not replace these GUI observations.

## Short smoke route

1. Create a fresh world and character. In the crafting UI open **Basics** and
   confirm ordinary recipes appear there without learning a profession. Learn
   Cooking and verify **Sweetroot Mash** (`grug_cooking:sweetroot_mash`) appears
   only in Cooking, with concrete alternatives such as `Carrot or Cassava`
   instead of an internal `group:` token.
2. Craft a Bronze Sword (`grug_gear:sword_bronze`) with two Bronze Bars above
   one wooden stick, then repeat with the same-tier metal rod. Confirm shifted,
   reversed or extra-gem layouts fail. Check one pick, both axe orientations,
   both Farmer's Hoe orientations and one 5/8/7/4 armor layout.
3. In one capital, learn Weaponsmith and use the shared **Forge**. The preview
   must name and describe the +15% refined result before Apply. Apply once,
   then Add Affix once; the same concrete stack must retain wear and unrelated
   metadata, consume inputs once and gain exactly its next legal positional
   affix. A denied/out-of-range/full-output attempt must consume and roll
   nothing.
4. Visit the capital's dedicated Riding Trainer. Buy/summon T1
   (`grug_mounts:apprentice_mount`): status reads `T1 Mount, +60% Speed` with no
   countdown. Toggle first/third person; the owner sees no mount mesh in first
   person, sees it in third, and a second client always sees it. Ride over a
   slab and one full block, then confirm a two-block rise and low ceiling stop
   it. Dismount, take damage and reconnect to confirm status/visual cleanup.
5. With known maximum HP, compare the same fall at low and high level. Damage
   should be the same percentage after ceiling rounding; armor/dodge must not
   reduce it. Repeat as Dwarf and with an absorb shield to confirm scaling →
   Dwarf reduction → absorb.
6. Observe ambient ground mobs near a one-block step and a two-block ravine:
   they may descend one block but must refuse two. Visit a dragon as
   `peaceful_player`: it may walk visibly between rest spots but must not cast,
   teleport as idle travel or acquire the peaceful observer.

## World, farming and art

1. Visit all six capitals. Each must have seven primary trainers plus Cooking,
   public owning stations and a separate Riding stable in outer premises; no
   Riding Trainer belongs in a start settlement. Each stable displays exactly
   four race-appropriate static mounts, and displayed mounts/gear release no
   item through dig, punch, take, blast, death or reload.
2. At the Dawnmere witness near seed `4151598227737528026`, position
   approximately `(-71,19,-2458)`, confirm natural caves can break the surface
   outside the functional settlement footprint without damaging buildings,
   foundations, aprons, required routes or POIs.
3. Check mountain-island and high freshwater shores for stone/gravel rather
   than sand. Confirm all three Rock Salt source zones still yield it on their
   approved supports.
4. For a representative crop, obtain the wild ingredient, recover its seed,
   till approved soil with the Farmer's Hoe, compare wet and dry growth, then
   harvest and replant. Dry growth pauses and resumes after watering; protection
   blocks unauthorized planting/harvest. Optionally repeat all 17 families,
   including cave plants, potato and corn, and inspect sea-only coral/kelp.
5. Inspect replacement armor, loot, material, food and crop icons at ordinary
   inventory size and as world drops. Equip representative metal, cloth and
   leather pieces on several races and inspect worn UV alignment. Weapon art
   must be unchanged. Inspect all twelve mount icons for recognizable model,
   tier, transparent padding and consistent camera framing.

## Optional breadth

- Repeat the base/refinement flow at T1, a middle tier and T6, and with both
  smith professions plus Tailor, Leatherworker, Woodcarver and Goldsmith.
- Inspect each capital race palette, service access and stable approach; cover
  T2 land plus T3/T4 flight, the legal-side 48-node warning, exterior ocean,
  enemy territory, underground takeoff refusal and y=600 ceiling.
- Fight a dragon without `peaceful_player`: skills require a live hostile
  target, lost targets cancel queued actions, scorch refreshes combat, blocked
  idle travel stops/retries, and no-target flight lands and resumes rest.

Use `/giveme <item-id>` only for focused setup after the ordinary acquisition
path has been checked. `/money`, `/xp`, `/char`, `/faction`, `/talents` and the
admin-only `/combatdebug` are the registered diagnostic commands relevant to
this pass; exact privileges and arguments are shown by in-game command help.

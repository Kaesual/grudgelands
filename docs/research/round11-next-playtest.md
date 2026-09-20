# Round 11 fresh-world playtest checklist

**Round 11 playtest build — 2026-09-20.** Implementation, independent reviews,
focused LuaJIT/static gates and the isolated native engine witness pass. Delivery
is tracked in [Round 11 completion](round11-completion.md). GUI acceptance
remains this checklist; no PUC runtime was run in this round.

Use a fresh world. For the supplied beach witnesses use seed
`15140735923413111218`. Keep Creative disabled when checking durability;
Creative intentionally suppresses wear. Diagnostic setup can use `/giveme`,
`/xp`, `/money`, `/talents` and `/combatdebug`; use in-game help for arguments.

## First pass: reported defects

1. Visit the beach around `(-414,20,-2724)` and `(-511,20,-2562)`. The accepted
   broad beach shape should remain, with no isolated thin tall columns or
   unlowered edge plates. Ordinary caves and percentage fall damage were
   already accepted in the previous playtest.
2. Visit a capital's outer profession premises. The forge is an anvil,
   Goldsmith's anvil has a muted gold head, Tailor has a loom, Woodcarver's
   bench stands upright. Product frames outside identify the professions;
   displayed products cannot be taken. Open stations and check the complete
   player inventory fits in the window. Learning a profession immediately
   updates the book buttons; recipes appear only at their real mastery band.
3. Inspect the open stable: earth floor, low fences, six posts, roof and four
   racial mounts. Ground mounts take short walks with pauses; flying mounts
   remain grounded but animate. Their feet stay on the floor during motion.
4. Mount and stand still in third person, then turn the mouse: rider and mount
   turn together. Repeat while moving. First-person owner hiding, normal
   third-person visibility and one-block step-up should still work.
5. Visit each dragon, teleport far away, then return without restarting.
   Exactly one dragon remains at each encounter, now displayed at level 70.
   With `peaceful_player`, idle movement must not cast combat skills.

## Equipment, professions and repair

1. Inspect bows, shields, books, bags and the quiver at inventory size and as
   drops. Compare Silversteel icons and worn armor: silver rather than bright
   blue; weapon shapes and wooden handles stay intact. Check bow grip in third
   person. Cloth/leather bags should be recognizable material variants.
2. Make a universal plain bow/shield through Basics. Improve them through
   Woodcarver/Armorsmith respectively. Try representative melee, bow, caster,
   cloth, leather, metal and shield affixes: at most one prefix and one suffix,
   no repeated stat, and family-appropriate choices. Refinement preview must
   explain the actual output and preserve the concrete item's metadata.
3. Equip a two-handed staff: Offhand is unavailable. Equip a one-handed wand
   with a Goldsmith spellbook. Equip a bow with the optional Leatherworker
   quiver: four arrow stacks, no combat bonus. Other two-handed weapons still
   require empty Offhand. Removing a filled quiver transfers arrows to main;
   if they do not all fit, removal is refused with a message and nothing moves.
4. Outside Creative, fight briefly and inspect slow equipment wear. A miss,
   fall or out-of-combat heal must not charge combat durability. Check a
   deliberately damaged/broken item using diagnostic setup instead of waiting
   through thousands of actions. Broken equipment remains in the inventory
   with its identity/affixes, supplies no effects, and works again after repair.
5. At a city profession trainer, compare repair-one and repair-all quotes.
   Any learned profession combination is allowed; Cooking trainers also repair.
   Intact items cost zero; fully damaged items cost 20% of their reference
   purchase price, rounded up per item. Test insufficient funds and moving an
   item after opening the quote: refused actions change neither money nor gear.
   Walk away or switch to another trainer and try the old window.
6. Check the Character/Talents armor breakdown with shield versus no shield.
   The percentage preview is always against the character's own level. A
   Protection build gains its deep Unbroken multiplier; a damage build wearing
   the same gear does not. Stronger enemies penetrate more of the same rating.

## Farming

1. Compare Carrot/Corn seeds with their harvest icons. Inspect representative
   remaining seed families, including potato, berries and grain.
2. Craft an empty iron bucket from three Iron Bars in a V. Collect an actual
   ordinary or river water source and place it by a legal farm. Flowing water,
   lava and protected civic sources must be refused. Try placing water just
   outside protected scenery: subsequent flow must not destroy that scenery.
3. Till legal soil with wooden and metal hoes. They perform the same operation
   with different lifetimes. Only a real new conversion spends durability;
   repeated use on existing soil and Creative use do not. Verify watering,
   growth, harvest and replanting still work.
4. Wild harvestable plants should be approximately half as dense, in their
   previous habitats. Renewal is intentionally slow: an observed depleted
   natural population first becomes eligible after 4–8 real hours, only in
   loaded suitable terrain. This is a longer optional multiplayer observation,
   not a demand to wait during the short playtest. Player crops and minerals
   must not create natural renewal debt.

## Scout

1. Create a Scout: leather eligibility, mana, wooden bow equipped, 20 arrows
   and a stone sword in main, no required starter quiver. Verify class selection
   and both talent trees are available.
2. Try partial and full draws with Loose, then Snare Shot, Sidestep and Sprint.
   Arrows follow current release aim and gravity, collide with terrain and
   expire at their range. Aim away from an old target: target memory must not
   steer an arrow. Shooting works with main-inventory ammunition alone.
3. In Quarry, check Twin Shot's full-draw second arrow and two-arrow cost,
   Pinning Shot's root and Longshot's extended reach. Repeat with ammunition
   split between quiver and main and with too few arrows: failed shots consume
   nothing. Check refund and draw-speed talents.
4. In Veil, use a one-handed weapon/shield and the existing two-handed greataxe.
   Strike and Opening use only the main hand. Compare Opening from behind
   versus in front; check its charge and Follow Through. Shake Loose clears
   and briefly prevents movement debuffs. Untouchable is a short emergency
   dodge window, with its cooldown preserved through reconnect.

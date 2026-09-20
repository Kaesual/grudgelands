# Round 12 playtest checklist

Reviewed Round12 checklist; see [completion](round12-completion.md) for evidence
and limits. Restart Luanti after the coordinator reports synchronization.
Use a fresh world/character for onboarding and recipe discovery. Creative is
useful for art inspection, but intentionally disables ordinary durability wear.
Use `/help` for existing `/giveme`, `/xp`, `/money` and `/talents` diagnostics;
class choice remains permanent, so use separate characters for class checks.

## First pass

1. Open Character, Bags, Talents, Skills, Crafting, Help and Creative Food at
   normal UI scale. All inventory rows and controls should fit. Check long
   talent descriptions/tooltips, the character model and stats, and the Bags
   page with a quiver equipped. Help should provide a usable starting route.
2. On a new character, Basics already shows starter equipment and bootstrap
   recipes. Acquire an Abyssal Steel Bar, including through a bag: its sword
   recipe appears without needing the handle first or reaching a level gate.
   Bread, Cooked Meat and Cooked Fish belong to Cooking. Furnace recipes show
   the furnace below the input/output arrow, not among the ingredients.
3. Drop an unused skill: it disappears without leaving an item on the ground.
   Recover it by dragging from Skills into inventory. Put it in a bag: another
   copy cannot be recovered. Recover a cooling-down ability: cooldown remains.
   Buying/unlocking a new skill announces Skills instead of filling inventory.
4. With upgraded riding, Skills still offers every purchased earlier mount.
   T1/T2/T3/T4 retain +60%/+100%/+100%/+200% respectively; ground and flight
   models retain their respective movement modes. Dropping the icon never
   removes purchased riding. A chest must refuse skill and mount items.
5. In Creative Food, find Jungle Cocoa, a stew, roast, fish dish, Bread and raw
   ingredients. Compare the [art gallery](round12-gallery.md). Wands should
   read as held magical implements and Greataxes as broad double-bit axes.
   Check six tiers and third-person grips. Ordinary unprofiled held icons now
   point forward; authored weapons keep their poses. Engine first-person
   wieldmesh rotation is separate and was not changed by this fallback.
6. Eat a dish and continue the other checks: its buff remains after three
   minutes and expires at five. Combat pauses food healing/regeneration;
   eating another food replaces the existing food buff.

## Farming

Plant representative roots/grain, berries/pepper, pumpkin/melon, mushrooms/moss,
Sugar Cane, Bamboo and Corn on wet soil. All seventeen families have four
logical stages; stage growth remains 200 wet seconds. Compare young and mature
shapes: Corn reaches three blocks, Cane four, Bamboo three. Harvest annual
roots/grain/Corn and resow; fruit/berry families can be picked and regrow;
Cane/Bamboo regrow from the retained base. Immature destructive harvest gives
only seeds, not mature food. Harvesting a mature vertical crop must not pay
once per segment. Blocked space should pause vertical growth without replacing
building blocks. Wild repopulation remains separate from cultivated regrowth.

## Original-class talent consumers

Use the Talents page to purchase a legal build, then retrieve newly unlocked
active abilities through Skills. Inspect the live description at each rank.
Check one new skill per tree before deeper balance testing:

- Warrior Bulwark: Hold Ground absorb and eight-second root/slow immunity;
  Bellow area taunt and the retained Protection armor multiplier.
- Warrior Ruin: gated Hamstring, Tendon Cut root/ICD, Broadstroke cleave,
  Ruination's bounded Crit-cap window.
- Mage Ember: Cinderfall at the crosshair's first contact, Brand splash,
  Whitehot's temporary damage and mana-cost changes.
- Mage Rime: Glacial Ward, Frostbind with its Slow description/control change,
  Rimebite's Shatter replacement.
- Priest Mercy: gated Renew, Hearten's group-heal extension, and Turn Aside
  granting dodge to the target only while its Power Word: Shield holds.
- Priest Reckoning: Word of Ruin damage/drain, Recompense absorb/cost and the
  low-health Last Word window.

Respec removes unavailable active entries without recreating discarded skills.
Check death, reconnect and expiry do not leave temporary control/cap bonuses.
Missed/refused/immune hits must not grant damage-dependent benefits. Normal
Scout skills and talents should continue behaving as in the accepted playtest.

Report the class/build, equipped item, target, coordinates and exact observed
behavior for any regression. UI screenshots help distinguish clipping from a
long tooltip or an oversized default UI scale.

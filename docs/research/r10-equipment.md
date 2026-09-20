# Round 10 equipment delivery evidence

Final integrated status and exact gate identities: [Round 10 final completion](round10-final-completion.md).
Final technical gates PASS. The reviewed changes are delivered on main, synchronized
and pushed; GUI acceptance remains pending.

This record covers the universal equipment recipe, profession split,
refinement/affix and vendor-catalog package. It does not claim the CAP trainer
projection or ART texture package; those are atomic integration dependencies.

## Delivered behavior

- The player-facing universal recipe category is **Basics**. Profession recipes
  remain in exactly their owning book, and group ingredients render concrete
  item descriptions joined by `or`.
- Weaponsmith and Armorsmith are distinct primaries sharing one Forge. Together
  with Alchemist, Tailor, Leatherworker, Woodcarver and Goldsmith this is the
  seven-primary roster; players retain two primary slots.
- Plain six-tier weapons, picks, axes, shovels and metal/cloth/leather armor are
  universal. The one existing Farmer's Hoe is universal. Ordinary cloth,
  leather and processed-wood preparation is universal; professional fittings,
  grips and kits remain trade products.
- Refinement and Add Affix are explicit station transactions. Preview does not
  roll. Apply verifies profession, tier, station access, distance and inventory
  room before it rolls or consumes, preserves the concrete source stack, and
  grants profession progress exactly once after successful settlement.
- Refinement applies the decided +15% damage or armor marker once. Add Affix
  appends one legal positional affix up to the 1/2/3/4 mastery limit. Imbue and
  temper kits now apply to their owned families; Goldsmith kits preserve the
  trinket's fixed two-channel, unrefined exception.
- Equipment vendors retain 13 fixed items and expose three of four conceptual
  rotating families. The caster family deterministically selects one of wand,
  scepter or orb. The one-in-five expensive Uncommon replacement remains.

## Familiar-grid source and oracle

The pinned VoxeLibre source is the independent shape authority:

- `reference_projects/VoxeLibre/mods/ITEMS/mcl_core/crafting.lua:142-148`
  defines four sticks from two vertically placed planks. The old Minetest Game
  one-plank shortcut is cleared; the negative oracle rejects any one-row route.
- `reference_projects/VoxeLibre/mods/ITEMS/mcl_tools/crafting.lua:1-173`
  supplies pick, shovel and both mirrored axe shapes. Shaped recipes are
  registered independently because the engine does not mirror them.
- `reference_projects/VoxeLibre/mods/ITEMS/mcl_farming/hoes.lua:145-161`
  explicitly registers both mirrored hoe shapes.
- `reference_projects/VoxeLibre/mods/ITEMS/mcl_armor/init.lua:7-57` supplies
  the 5/8/7/4 head/chest/legs/feet layouts.

`tools/r10_equip/base_recipes_kat.lua` encodes these expectations separately
from the production recipe tables. It compares exact two-dimensional recipes
and output amounts for all six tiers of swords, picks, axes, shovels and every
metal, cloth and leather armor slot, plus both existing hoe orientations, the
four-stick and four-rod yields, and the delegated non-Minecraft weapon shapes.
It also rejects the old one-plank stick route and a gemstone in the four-wood
orb.

## Integration dependencies

- Integrated, independently reviewed CAP projects separate `weaponsmith` and
  `armorsmith` trainers, replaces the retired Blacksmith socket vocabulary, and
  projects one shared public
  `grug_jobs:forge`. There is deliberately no old-name alias or migration.
- Integrated, independently reviewed ART supplies the four leather armor inventory textures referenced
  by the active logical line: `grug_gear_item_{head,chest,legs,feet}_leather.png`.
- The package and CAP are integrated together; there is no retired Blacksmith
  vocabulary in the current trainer projection. Final interpreter parity passes; the central completion record owns exact gate results.

## Validation

The final candidate is checked with Lua 5.1 parsing, the SETGLOBAL inspection,
all five portability/security sweeps, the fresh-server source audit, focused
LuaJIT fixtures and one compact byte-identical LuaJIT/PUC 5.1 digest pair. The
real-code fixtures also prove source-stack metadata preservation and terminal
craft-callback composition. The reproducible runner, provenance and immutable
logs are recorded under `tools/r10_equip/evidence/`. Independent source review of `b8dc0db3` is CLEAN; see
[the review index](round10-reviews/README.md). The package-specific historical
pair remains scoped to its recorded inputs; the final integrated replacement
pair passes with byte-identical output, as recorded centrally.

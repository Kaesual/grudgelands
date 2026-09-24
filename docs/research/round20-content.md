# Round 20 Q3: quest catalog

Implementation receipt; independent review and final runtime acceptance pending.

## Delivered scope

The catalog retains all 102 established IDs and their 30 NPC bindings, adds
90 regional quests at 30 authored hosts, and adds 48 civic/travel quests with
18 civic NPCs. Total: 240 quests and 78 NPCs. Runtime content is ordinary Lua;
the planning JSON is not loaded by the game. Capital envoys reuse the existing
hall quest socket, while cooks use the separate authored kitchen sockets.

The established six race routes now offer the first hunt, raw-meat provision
and axe lesson independently. The cook accepts meat without a profession gate;
the independent coal job is an additional optional source of work. Wood repairs
replace the old second pest hunt. The night patrol is separate from the repair
branch. The level-10 village handoff is a pure conversation; the independent
capital introduction also opens at level 10. Later regional and camp tasks
retain their authored locations. Dependencies use Q1's hidden-until-turn-in rule.

All six main routes change hunt counts, work objectives, dependency structure,
travel handoff and camp turn-in. Local jobs retain unique work where it already
fits, while overlapping combat becomes fox/hyena fangs, goblin scraps, poacher
linen, crocodile teeth, lynx leather or purse recovery. The six camp purse
requests have separate cultural stories and share one outing with the combat
report and linen request. Fixed carried/traded items count intentionally.

## Source findings and authored corrections

- `grug_mobs/spawn_policy.lua` supplies the actual named-zone palettes;
  `start_zone_families.lua`, `night_families.lua`, `zero_asset_variants.lua`
  and individual mob definitions supply clocks, minimum levels and habitat.
  Fox/ibex/scorpion/viper start checks require level-4 ground. Poachers need
  night (Silverleaf additionally level 7); goblins, frost strays, wisps, snow
  leopards and treants are night jobs. Stillgrave zombies are the explicit
  blight-any-clock exception. The text describes those restrictions.
- The four new undead plank deliveries at anchors 020, 038, 040 and 064 use
  `grug_trees:gravewood_wood`, correcting the draft's ordinary oak planks.
  Stillgrave's early repair does likewise. `grug_gathering/catalog.lua` and
  `grug_trees/init.lua` establish the tree-to-plank source. Other regional
  deliveries use their local pine, oak, acacia or jungle wood.
- `hyena.lua` and the fox definition drop fangs; goblins drop linen scraps;
  crocodiles drop teeth; jungle lynx drop leather. `bandit.lua` supplies
  stolen purses and guaranteed ordinary linen below/equal to level 30;
  regional camps are level 11–20. Poachers inherit that linen definition.
- Coal is an ordinary tier-1 harvest material (`grug_materials/registry.lua`),
  so its optional starter job explicitly permits trade and describes a bronze
  or better pick when mining. It does not imply that a wooden pick mines coal.
- Six guard jobs target opposing faction guards in actual frontier zones,
  require level 40 and describe hostile border posts. `camps.lua`, `guard.lua`
  and `grug_mapgen/wp40/zones.lua` provide guard spawning and the surface-level
  rule; capital guards are not the target. No player kills or king targets.
- New fixed XP amounts use the authored target-level interval
  `100 * (2 * level - 1)`: 15% for conversations, 20% ordinary, 25% hard,
  35% finale. Main meat is 20 XP/10 copper; village conversation is
  285 XP/40 copper. No runtime XP scaling was added.

## Validation and final invocation

Parser, SETGLOBAL inspection and all five Lua sweeps passed for the six changed
Lua files, including the server fixture. Only `init.lua` writes the intended
`grug_quests` global. No Lua runtime, engine process or old suite was run here.

`tools/r20/content_server.lua` returns a callable assertion function. In the
single final isolated headless smoke, after all mods and their mods-loaded
callbacks have completed, run:

```lua
local validate = dofile(game_root .. "/tools/r20/content_server.lua")
core.log("action", validate())
```

The smoke harness owns scheduling, a maximum five-minute timeout and shutdown;
this function neither generates terrain nor writes player/world data. It calls
real `grug_quests.validate_registry()` against the actual core item/entity
registries and the actual settlement socket provider. It additionally checks
all 240 IDs, 78 NPCs, 90 regional quests, 36 conversation jobs, six opposing
level-40 guard jobs, faction-consistent and nondecreasing prerequisite gates,
initial parallel tasks, capital access, talk XP and regional spawn palettes.
It returns a stable SHA-1 receipt over sorted IDs/levels/XP. Habitat and special
spawn filters above remain source-reviewed constraints; a zone palette alone
is not claimed to prove every spawn position.

The existing Q1 portable fixture covers quest progression mechanics. This
catalog fixture belongs in the real server smoke rather than reconstructing
engine registries with permissive doubles in the portable interpreter pair.

## User runtime plan

On a fresh character, accept the three initial tasks independently, hand in
meat at the start cook, and verify that successors appear only after turn-in.
At level 10, use the capital introduction without finishing the combat chain.
Visit a new regional host, complete one night task and its consequence, and
check that the capital envoy is a single actor in the existing hall socket.

## Final-smoke fixture correction: ambient versus camp authority

The first real-server catalog assertion incorrectly required ambient membership
for bandit archers. This was a fixture defect, not an unobtainable quest target.
The all-90 regional source audit contains 32 item jobs and 58 kill jobs: 46
ambient targets, four camp-archer targets, two camp-bandit targets and six
opposing guard targets. No production quest change is necessary.

The corrected server fixture joins actual `simple_map.lua` anchor templates
and zone identities with `grug_mobs.registered_camp_types` primary/variant mobs.
It requires a matching camp in the objective zone, including the race-bound
outpost faction, instead of exempting bandit/guard names. The six frontier
bandit anchors are 050/052/054/056/058/060 in Stormvault/Ashenward/Glassroot/
Blackwind/Bannerbreak/Thunderroot. `camps.lua` registers bandit archers as the
one-in-three variant and selects that variant when filling a real camp slot.
All six frontier regions also contain the opposing quests' authenticated
race-bound outposts. These are level-31–40 regions; guard jobs require 40.

All 46 ambient objective pairs intersect the actual zone and mob palettes.
Their selected lookalikes agree with the zone filter (notably skeleton raiders
in Ashenward/Bannerbreak and frost strays in Stormvault). Habitat review matches
rock/gravel/snow in the mountain zones, forest/bone litter for wolves/treants,
savanna/clay for tigers/scorpions, jungle for tapir/lynx, and mud for crocodile/
ooze/wisp jobs. Every involved zone includes the required biome. Minimum gates
are compatible: tiger explicitly 21–50; wolves/hyena/lynx minimum 10; the
start-family level-4 restriction does not restrict these level-21+ jobs.
Night-only targets retain the explicit night descriptions. The fixture now also
checks objective-zone level bands and registered entity minimum levels.

No engine or Lua runtime was run in the correction lane. Parser, SETGLOBAL and
all five static sweeps passed; root owns the replacement smoke and independent
reviewer verification.

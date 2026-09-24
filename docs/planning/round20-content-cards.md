# Round 20 authored content cards

Date: 2026-09-24. Author: GPT-6 Astra. Implementation input for the approved
[round](round20-pois-quests-fixes.md); this file does not report shipped art.
The [JSON companion](round20-content-cards.json) holds the same 70 identities,
30 regional NPCs, 90 regional quest sketches, 18 civic identities and 48 other
quest sketches. Names introduced here are place/NPC names, not replacements
for zone names or anchor IDs. No runtime or engine tests were run for this
creative specification.

## Frozen interface and ownership

- P2/P3 owns construction, actor sockets and their publication. Q3 owns NPC
  registration, all text and quest catalog data. Q1 owns objective/state/UI
  behavior. All consumers resolve standing positions through
  `grug_core.settlement_sockets_at`; none adds its own world-coordinate offsets.
- New regional settlement key: `r20_anchor_NNN`. Host NPC:
  `r20_anchor_NNN_host`; socket `quest_host`, role `quest`, local `(2,1,0)`,
  facing `(-1,0)`. Reserve feet and head air, full ground below and a two-node
  approach from the open central court. Do not attach a `door` tag, which would
  reverse facing in the current NPC consumer. Hosts are peaceful; no vendor,
  trainer, guard or other service is implied. Regional quests are faction-only,
  so same-faction races can use the places; existing race-specific stories and
  civic additions retain their race gate. Host faction comes from the card,
  never from a contested zone's `faction=false` field.
- Existing 30 bound NPC IDs/socket keys stay unchanged. Each capital's existing
  **unbound core quest shell** becomes its named envoy. Resolve the one core
  role=quest socket and bind its exact existing ID; do not spawn a duplicate or
  rename that socket. The envoy's frozen position is the existing socket.
- New start cook `r20_<race>_start_cook` uses `quest_cook` at `(2,1,13)` in
  Accord starts and `(2,1,-13)` in Throng starts, facing west; own oven at
  `(4,1,13)` or `(4,1,-13)`. This is beside, not on, the existing trainer.
  Keep street access open. Cooking training is optional and is never checked
  for these provision quests. Art implementation must inspect these columns
  for existing scenery and make a bounded local furniture adjustment if needed.
- Capital cook `r20_<race>_capital_cook` uses the existing Cooking plot,
  local `(2,1,-1)`, facing south (`dir={x=0,z=-1}`). The trainer remains
  `(-2,1,-1)` and furnace `(0,1,1)`. Socket name after normal plot projection is
  `<plot>/<plot>_quest_cook`. Preserve the plot's reference height; never project
  these on the capital core's flat y. The 18 civic identities are in JSON.
- Root accepted talk schema: `{type="talk",npc=destination,count=1}` with
  `turnin_npc=destination`. Conversation with that named NPC completes it;
  no visit radius, courier item, kill add-on or return to origin. Q1 owns when
  an opened conversation records progress and shows ordinary turn-in.
- Quest IDs for new regional triples are `r20_anchor_NNN_01..03`; first two
  independent, third requires completed `_02`. No NPC rotation, random quest
  generation or runtime assembly from this planning JSON. Q3 authors normal
  static Lua catalog data. Descriptions explain the actual level and completed
  prerequisite. No future quest appears on mere acceptance/objective readiness.

## Geometry, protection and actor contract

Coordinates in every card are anchor-local: x east, z north, y=0 the existing
fitted ground. Approaches describe the composition's open edge; connect its
perimeter path to the existing road pin within the core, without moving roads.
No authored roof, sign, prop, support or foundation escapes the listed box.
Normal inhabited boxes use y=0..8; island camp/arena boxes use y=0..12. No
excavation below the pad. Mine mouths are shallow, braced walk-in workplaces,
not newly generated underground mines. Natural mining remains finite.

The actual `simple_map.lua` profiles set village width24, outpost16, frontier
bandit16, mine20, Mirefolk16, clash16, dragon32, apex32 and rare12. Fitting and
blend widths are **not** building envelopes. `world_zones.md` states24 for both
bandit profiles, but current `bandit_frontier` is16. These cards fit16 with two
real compact buildings; correcting that design/source discrepancy remains a
separate geometry decision. This art completion does not close that remainder.
Do not widen terrain fitting, reservations or protection to make a card fit.

Preserve existing functional anchor/root cells, guard banners, camp spawn
positions, rare route nodes, boss roots and apex resource sockets. Buildings
stand off the centre; reserve the central 5×5 horizontal square for actor
circulation/root integration, except the peaceful quest standing socket.
Inspect the current camp actor offsets before freezing each building footprint;
an existing spawn point inside a wall is a defect, not grounds for another
spawner. Keep apex resource columns, their approach and digging access free.
No new apex ore, harvestable prop or renewable mining mechanic.

Protection derives from existing reservation/projection rules, not faction
colors. Retain the current envelope and indirect-mutation behavior; do not
claim all surrounding ground is protected. Explicit prop fixtures must use
existing noncollectible scenery definitions or normal protected nodes. Do not
introduce new media just to draw a feather, coil, bone, crate or insignia.
A requested motif may be built from existing small parts and palette blocks.

Each of the 42 inhabited scenes has at least two **real buildings/shelters**:
roof with bearings, usable entry and walkable interior/work area. Adits count
only if their braced roofed workplace is actually built; a flat dark wall does
not count. Villages have four or five buildings, unequal in footprint, height,
roofline and orientation. Components can repeat; whole village plans cannot.
No identical four-house square with rotated roofs. Keep doors, two-node lanes,
NPC clearance, readable exits and weather shelter ahead of decorative clutter.
The 28 encounter scenes explicitly have no building minimum. Battlefield
trenches are shallow above-grade scenery here, not earthwork or war simulation.

## Existing compositions: retain and touch only where required

Anchors001..012 retain the six starts and six capitals. Add cooks/ovens and bind
existing capital shells. Preserve innkeepers, public stations, district terrain,
capital boundaries, stable displays and all current actors. Anchors013/015/017/
019/021/023, 025/029/033/037/041/045 and049/051/053/055/057/059 are the18
already-authored regional compositions. Keep their layouts, names and quest
sockets. Coherence work is limited to blocked interaction approaches, a clearly
missing task prop or conflicting socket; it is not a blanket rebuild. Preserve
Whitebridge and Whisperreed shipwright plots/display boats; they gain no travel
or teaching service in this round.

## Quest revision: all 102 existing entries

The current catalog has six cultures × (nine main steps + two tool lessons +
six local tasks). Q3 must audit/rewrite all17 entries for each culture; keeping
an ID does not mean keeping its old sequential pacing or misleading prose.
Keep reward formulas and existing IDs; no legacy readers are needed.

| Existing slots, each of six races | Required revision |
|---|---|
| Main01,02 and lesson10 | Initial parallel bundle at level1: short local hunt, raw-meat delivery owned by the new start cook, optional wood-axe delivery at elder. No prerequisites among the three. |
| Main03 and04 | Unlock together after01 is turned in; replace repeated boar fallbacks with complementary local provision/work or time-explicit tasks. Do not send the player for the same larger boar count. |
| Main05 and lesson11 | Independent next options after03 and10 respectively; preserve locally available target minimum levels and optional crafting. |
| Main06 | Pure level10 talk handoff to existing regional village steward, replacing kill-plus-travel. Its prose names destination and its danger band. Capital introduction also becomes available at level10, independently of this village trip. |
| Main07 | Regional first job at steward, after06 turn-in. Keep actual home-zone target and explain visible workplace. |
| Main08 | Outpost task after07 turn-in; no claim that a second identical pack is new story. |
| Main09 | Keep existing camp fight and captive turn-in, explaining that the captive hears the report. This is a combat job, not one of the pure travel handoffs. |
| Local01/02,03/04,05/06 | Three independent pairs at existing village/outpost/camp givers. Keep paired availability, locality and workplace relevance. Review overlap against main07/08/09; change objective/text where an outing would merely repeat the same mob. |

Q3 may retain a sound target or line, but must record the review of each entry.
For main03 use race-specific ordinary building wood (pine/oak/wood/grave-region
ordinary wood/acacia/junglewood) and an honest store-repair purpose, count6;
these are item hand-ins, not proof of harvesting. For main04 use the current
night enemy only with explicit night wording, small count3, and the existing
minimum-level constraint; remove daytime duplicate-boar fallback. The initial
hunt, provisions, tool delivery and later optional daytime work prevent waiting
for night from becoming the only progress route. Main05 retains its distinct
animal only where it differs from the initial hunt; Stillgrave's repeated
plague-boar task becomes a cobble delivery for retaining stones (8). All exact
registered item IDs and target minimum levels are checked by Q3 against code.

The 138 additions are 90 regional tasks +6 capital supply tasks +12 cook tasks
+12 capital introductions +18 travel handoffs. Total editorial target240.
No filler quest is required to hit an exact count. Two initial tasks per new
host share an outing; the third is a consequence, not simply a larger repeat.
Six third tasks are explicit level40 enemy **guard** missions to an opposite
frontier zone. They use the existing faction-guard entity/zone filters and
contribution credit, no civilians, kings or players; physical outposts already
supply these guards. They remain optional and do not gate service access.
Existing reward effort authority must be used, not the low-level arrays indexed
past their end. Root froze pure-talk rewards at the existing light/lesson share: 15% of the
authored target-level XP interval, no kill XP added, fixed one-time values.
Use comparable existing light-quest copper; no new economy formula. A former
combined errand converted to talk uses this15% share rather than retaining
its combat reward. Other existing quests retain rewards where effort is equal.

The JSON quest sketches are code-ready IDs/objectives/levels/prerequisites,
not final prose. Their direct mob targets were selected from the current named
spawn palette, with bandits and guards from existing fixed camp/outpost actors.
Q3 still checks mob minimum levels, actual habitats/day-night rules, item
registration and final dependency reachability. No custom drops, profession
requirements, Nether materials, housing, king finales or new encounter logic.
Regional item hand-ins deliberately accept existing/traded supplies; descriptions
must not pretend the player mined or crafted them. Night targets say so.

## Individual scene cards

All70 cards below are independently named and laid out. The JSON supplies the
numeric anchor location, exact stable zone, full box, host and objective data.
The x/z positions there identify current source anchors, not a second runtime
authority; implementations resolve the anchor through the normal zone session.


### anchor_014 — Tarnwatch Fold

`elandor_frostbarrow_shelf` / `village_1`; Frostbarrow Shelf, levels 21–30; accord. Purpose: shelter shelf caravans.

**Form:** 5 buildings. granite lower walls, pine, soot-grey slate. long low communal hall west; two unequal homes north; smith east; store southeast. Details: cairn niche; split sled runners.

**Approach:** south lane bends round cairn to hall. **Bounds:** x/z -12..11, y 0..8; retain existing protection.

**Host:** Edda Tarnmantle (`r20_anchor_014_host`), `r20_anchor_014/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_014_01` — **The Cairn Mortar**, L21: item `default:cobble` ×10. Initially independent.

- `r20_anchor_014_02` — **Hooves Above the Sleds**, L21: kill `grug_mobs:ibex` ×4 in `elandor_frostbarrow_shelf`. Initially independent.

- `r20_anchor_014_03` — **The Bell After Dark**, L23: kill `grug_mobs:goblin_raider` ×4 in `elandor_frostbarrow_shelf`. After `_02` turn-in.


### anchor_016 — Whitebridge Market Close

`elandor_whitebridge_shire` / `village_1`; Whitebridge Shire, levels 21–30; accord. Purpose: bridge provisioning and boat craft.

**Form:** 5 buildings. chalk plaster, oak beams, dull red tile. market hall northeast; baker northwest; two homes along a bent west lane; shipwright shed southeast. Details: half-built display hull; apple press.

**Approach:** southwest opens onto narrow market elbow. **Bounds:** x/z -12..11, y 0..8; retain existing protection.

**Host:** Merren Oakstamp (`r20_anchor_016_host`), `r20_anchor_016/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_016_01` — **The Press Frame**, L21: item `default:wood` ×8. Initially independent.

- `r20_anchor_016_02` — **The Poacher's Market**, L21: kill `grug_mobs:poacher` ×4 in `elandor_whitebridge_shire`. Initially independent.

- `r20_anchor_016_03` — **A Light Beyond the Bridge**, L23: kill `grug_mobs:wisp` ×3 in `elandor_whitebridge_shire`. After `_02` turn-in.


### anchor_018 — Lorindor Berrycourt

`elandor_lorindor` / `village_1`; Lorindor, levels 21–30; accord. Purpose: marsh-fed orchard work.

**Form:** 4 buildings. pale stone, silverwood boards, moss-green roofs. tall orchard house northwest; low drying house east; two cottages staggered south. Details: berry trellis; white-flower trough.

**Approach:** east lane skirts trellis into off-centre green. **Bounds:** x/z -12..11, y 0..8; retain existing protection.

**Host:** Ilwen Petalmeasure (`r20_anchor_018_host`), `r20_anchor_018/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_018_01` — **Stones Around the Roots**, L21: item `default:cobble` ×8. Initially independent.

- `r20_anchor_018_02` — **No Snares in Berrycourt**, L21: kill `grug_mobs:poacher` ×4 in `elandor_lorindor`. Initially independent.

- `r20_anchor_018_03` — **The Uninvited Lanterns**, L23: kill `grug_mobs:wisp` ×3 in `elandor_lorindor`. After `_02` turn-in.


### anchor_020 — Ossuary Ledgerstead

`kragmar_ossuary_reach` / `village_1`; Ossuary Reach, levels 21–30; throng. Purpose: care for remembered dead and living supply routes.

**Form:** 4 buildings. gravewood, pale fossil stone, charcoal roofs. archive hall north; stonecutter west; two narrow houses southeast at unequal depths. Details: labelled stone shelves; candle recess.

**Approach:** south approach sees archive gable beyond low yard. **Bounds:** x/z -12..11, y 0..8; retain existing protection.

**Host:** Sovel Namekeeper (`r20_anchor_020_host`), `r20_anchor_020/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_020_01` — **Shelves for the Remembered**, L21: item `default:wood` ×8. Initially independent.

- `r20_anchor_020_02` — **Teeth Beside the Archive**, L21: kill `grug_mobs:blightfang_wolf` ×4 in `kragmar_ossuary_reach`. Initially independent.

- `r20_anchor_020_03` — **The Trees That Refuse Rest**, L23: kill `grug_mobs:gravewood_treant` ×3 in `kragmar_ossuary_reach`. After `_02` turn-in.


### anchor_022 — Speargrass Wellhold

`kragmar_speargrass_reach` / `village_1`; Speargrass Reach, levels 21–30; throng. Purpose: protect water and travelling herds.

**Form:** 5 buildings. ochre earth, acacia beams, basalt feet. wide shade hall west; tanner north; store northeast; two small homes south of uneven court. Details: water jars under awning; worn hunting stone.

**Approach:** east opens beside water shade with clear western exit. **Bounds:** x/z -12..11, y 0..8; retain existing protection.

**Host:** Brakka Jarward (`r20_anchor_022_host`), `r20_anchor_022/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_022_01` — **Shade Before Strength**, L21: item `default:acacia_wood` ×8. Initially independent.

- `r20_anchor_022_02` — **Stripes in the Cutting Grass**, L21: kill `grug_mobs:speargrass_tiger` ×3 in `kragmar_speargrass_reach`. Initially independent.

- `r20_anchor_022_03` — **Night at the Water Jars**, L23: kill `grug_mobs:scorpion` ×4 in `kragmar_speargrass_reach`. After `_02` turn-in.


### anchor_024 — Whisperreed Landing

`kragmar_whispering_reedlands` / `village_1`; Whispering Reedlands, levels 21–30; throng. Purpose: reed-path provisions and boat craft.

**Form:** 5 buildings. junglewood, dark stone piers, reed-toned roofs. raised common house northwest; net loft east; two homes staggered west; shipwright shelter southeast. Details: display skiff; hanging drying poles.

**Approach:** south dry path opens to common-house stair. **Bounds:** x/z -12..11, y 0..8; retain existing protection.

**Host:** Taleko Drycord (`r20_anchor_024_host`), `r20_anchor_024/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_024_01` — **A Landing That Holds**, L21: item `default:junglewood` ×8. Initially independent.

- `r20_anchor_024_02` — **Tapirs on the Dry Path**, L21: kill `grug_mobs:tapir` ×4 in `kragmar_whispering_reedlands`. Initially independent.

- `r20_anchor_024_03` — **Cold Lights in the Reeds**, L23: kill `grug_mobs:wisp` ×3 in `kragmar_whispering_reedlands`. After `_02` turn-in.


### anchor_026 — Rimebell Watch

`elandor_frostbarrow_shelf` / `outpost_1`; Frostbarrow Shelf, levels 21–30; accord. Purpose: watch the shelf road.

**Form:** 2 buildings. granite, pine, slate. squat bell-house northwest; long bunkhouse east leaving bent yard. Details: stacked signal wood; low windbreak.

**Approach:** south entrance shows bell above bunk roof. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Hedra Rimebell (`r20_anchor_026_host`), `r20_anchor_026/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_026_01` — **Fuel Under Cover**, L21: item `default:coal_lump` ×6. Initially independent.

- `r20_anchor_026_02` — **The Sled Track Pack**, L21: kill `grug_mobs:snow_leopard` ×3 in `elandor_frostbarrow_shelf`. Initially independent.

- `r20_anchor_026_03` — **Notches on the Signal Pole**, L23: kill `grug_mobs:goblin_slinger` ×4 in `elandor_frostbarrow_shelf`. After `_02` turn-in.


### anchor_027 — Splitbolt Station

`elandor_stormvault_heights` / `outpost_1`; Stormvault Heights, levels 31–40; accord. Purpose: monitor Stormvault ascent.

**Form:** 2 buildings. dark granite, pine, weathered iron accents. tall narrow watchhouse west; low provision lodge northeast. Details: lightning-split post; weighted shutters.

**Approach:** southeast path faces watchhouse then turns west. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Borin Splitbolt (`r20_anchor_027_host`), `r20_anchor_027/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_027_01` — **Shutters Against the Storm**, L31: item `default:pine_wood` ×8. Initially independent.

- `r20_anchor_027_02` — **The Frost That Walks**, L31: kill `grug_mobs:frost_stray` ×4 in `elandor_stormvault_heights`. Initially independent.

- `r20_anchor_027_03` — **Slatehook's Cargo**, L33: kill `grug_mobs:bandit_archer` ×4 in `elandor_stormvault_heights`. After `_02` turn-in.


### anchor_028 — Archshadow Post

`elandor_stormvault_heights` / `outpost_2`; Stormvault Heights, levels 31–40; accord. Purpose: hold the high ridge crossing.

**Form:** 2 buildings. slate stone, pine, faded blue cloth. low guard hall north; compact chart hut southwest. Details: ridge sighting stones; repaired shield rack.

**Approach:** east sightline across open southern yard. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Alna Archsight (`r20_anchor_028_host`), `r20_anchor_028/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_028_01` — **Stones for the Sighting Line**, L31: item `default:cobble` ×8. Initially independent.

- `r20_anchor_028_02` — **Wings Over the Crossing**, L31: kill `grug_mobs:crag_eagle` ×3 in `elandor_stormvault_heights`. Initially independent.

- `r20_anchor_028_03` — **The Watch Beyond the Ash Wind**, L40: kill `grug_mobs:guard_throng` ×3 in `kragmar_blackwind_rise`. After `_02` turn-in.


### anchor_030 — Oakspan Tollhouse

`elandor_whitebridge_shire` / `outpost_1`; Whitebridge Shire, levels 21–30; accord. Purpose: keep market wagons moving.

**Form:** 3 buildings. white stone, oak, brick-red tile. tollhouse northwest; narrow guard hut east; roofed store southwest. Details: broken cart axle; stamped crate stack.

**Approach:** south arrival pinches between store and open yard. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Jessa Axlewright (`r20_anchor_030_host`), `r20_anchor_030/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_030_01` — **An Axle for the Empty Cart**, L21: item `default:wood` ×8. Initially independent.

- `r20_anchor_030_02` — **The Tollhouse Snares**, L21: kill `grug_mobs:poacher` ×4 in `elandor_whitebridge_shire`. Initially independent.

- `r20_anchor_030_03` — **Night Lights at Oakspan**, L23: kill `grug_mobs:wisp` ×3 in `elandor_whitebridge_shire`. After `_02` turn-in.


### anchor_031 — Cinderline Watch

`elandor_ashenward_march` / `outpost_1`; Ashenward March, levels 31–40; accord. Purpose: watch fire-scarred approaches.

**Form:** 2 buildings. smoke-dark oak, pale masonry, dull red cloth. bunkhouse west; taller lookout hut northeast. Details: burned beam retained in fence; water barrels.

**Approach:** south path reveals intact pale doorway against char. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Toren Waterbarrel (`r20_anchor_031_host`), `r20_anchor_031/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_031_01` — **A Wall Against Embers**, L31: item `default:cobble` ×10. Initially independent.

- `r20_anchor_031_02` — **The Ashen Wood Stirs**, L31: kill `grug_mobs:ashen_treant` ×3 in `elandor_ashenward_march`. Initially independent.

- `r20_anchor_031_03` — **Coalbrand's Watchers**, L33: kill `grug_mobs:bandit_archer` ×4 in `elandor_ashenward_march`. After `_02` turn-in.


### anchor_032 — Last Hedge Redoubt

`elandor_ashenward_march` / `outpost_2`; Ashenward March, levels 31–40; accord. Purpose: maintain a frontier supply stop.

**Form:** 2 buildings. rough stone, oak, faded linen. guardhouse southeast; low dispatch shed northwest. Details: clipped surviving hedge; scorched message board.

**Approach:** west approach crosses open centre without funnel trap. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Nella Hedgeward (`r20_anchor_032_host`), `r20_anchor_032/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_032_01` — **Posts for the Last Hedge**, L31: item `default:wood` ×8. Initially independent.

- `r20_anchor_032_02` — **Dead on the Dispatch Road**, L31: kill `grug_mobs:skeleton_raider` ×4 in `elandor_ashenward_march`. Initially independent.

- `r20_anchor_032_03` — **Standards Across the Mesa**, L40: kill `grug_mobs:guard_throng` ×3 in `kragmar_bannerbreak_mesa`. After `_02` turn-in.


### anchor_034 — Petalbank Wardenry

`elandor_lorindor` / `outpost_1`; Lorindor, levels 21–30; accord. Purpose: protect berry gatherers.

**Form:** 2 buildings. silverwood, pale stone, green shingles. long warden hall northeast; small herb shelter southwest. Details: flower troughs; stacked pruning poles.

**Approach:** west path follows low planted edge to hall. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Orya Petalward (`r20_anchor_034_host`), `r20_anchor_034/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_034_01` — **The Trough's New Kerb**, L21: item `default:cobble` ×8. Initially independent.

- `r20_anchor_034_02` — **Wardens Without Arrows**, L21: kill `grug_mobs:poacher` ×4 in `elandor_lorindor`. Initially independent.

- `r20_anchor_034_03` — **Lanterns We Did Not Hang**, L23: kill `grug_mobs:wisp` ×3 in `elandor_lorindor`. After `_02` turn-in.


### anchor_035 — Moonfall Observatory

`elandor_moonfall_wood` / `outpost_1`; Moonfall Wood, levels 21–30; accord. Purpose: observe lake paths without new telescope mechanics.

**Form:** 2 buildings. silverwood, dark oak, pale stone. tall narrow lookout west; long chart room south. Details: crescent paving fragment; fallen bough bench.

**Approach:** northeast approach sees offset roof pair. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Lethen Moonledger (`r20_anchor_035_host`), `r20_anchor_035/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_035_01` — **A Chart Table Repaired**, L21: item `default:wood` ×8. Initially independent.

- `r20_anchor_035_02` — **Fangs Beneath the Fallen Bough**, L21: kill `grug_mobs:wolf` ×4 in `elandor_moonfall_wood`. Initially independent.

- `r20_anchor_035_03` — **The Moonlit Snare Line**, L23: kill `grug_mobs:poacher` ×4 in `elandor_moonfall_wood`. After `_02` turn-in.


### anchor_036 — Glassroot Gate

`elandor_glassroot_wilds` / `outpost_1`; Glassroot Wilds, levels 31–40; accord. Purpose: keep cliff passages usable.

**Form:** 2 buildings. pale stone, dark timber, green-grey roofs. guard lodge north; short rootworkers hut southeast. Details: glass-coloured inset stones; bundled rope.

**Approach:** west arrival looks between lodge and hut. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Faeris Rootbinder (`r20_anchor_036_host`), `r20_anchor_036/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_036_01` — **Stone Under the Passage**, L31: item `default:cobble` ×10. Initially independent.

- `r20_anchor_036_02` — **Rootsnare's Stolen Cloth**, L31: kill `grug_mobs:bandit` ×4 in `elandor_glassroot_wilds`. Initially independent.

- `r20_anchor_036_03` — **The Other Rootwatch**, L40: kill `grug_mobs:guard_throng` ×3 in `kragmar_thunderroot_wilds`. After `_02` turn-in.


### anchor_038 — Boneledger Post

`kragmar_ossuary_reach` / `outpost_1`; Ossuary Reach, levels 21–30; throng. Purpose: guard the ossuary road.

**Form:** 2 buildings. fossil stone, gravewood, grey slate. low barracks southwest; square records house northeast. Details: stone rubbing table; covered lantern alcove.

**Approach:** northwest lane reaches sheltered records porch. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Mereth Rubbinghand (`r20_anchor_038_host`), `r20_anchor_038/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_038_01` — **A Shelf for Stone Names**, L21: item `default:wood` ×8. Initially independent.

- `r20_anchor_038_02` — **The Hungry Gravewood**, L21: kill `grug_mobs:gravewood_treant` ×3 in `kragmar_ossuary_reach`. Initially independent.

- `r20_anchor_038_03` — **A Pack on the Ledger Road**, L23: kill `grug_mobs:blightfang_wolf` ×4 in `kragmar_ossuary_reach`. After `_02` turn-in.


### anchor_039 — Ashveil Watch

`kragmar_blackwind_rise` / `outpost_1`; Blackwind Rise, levels 31–40; throng. Purpose: read wind and patrol signals.

**Form:** 2 buildings. black stone, gravewood, pale cloth. tall watchhouse northwest; shallow resting hall east. Details: ash-catching trough; tied wind chimes.

**Approach:** south arrival sees pale pennant beside black gable. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Vaska Ashlistener (`r20_anchor_039_host`), `r20_anchor_039/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_039_01` — **Keep the Lamps Burning**, L31: item `default:coal_lump` ×6. Initially independent.

- `r20_anchor_039_02` — **Ash Among Living Branches**, L31: kill `grug_mobs:gravewood_treant` ×3 in `kragmar_blackwind_rise`. Initially independent.

- `r20_anchor_039_03` — **The Pallcloth Thieves**, L33: kill `grug_mobs:bandit_archer` ×4 in `kragmar_blackwind_rise`. After `_02` turn-in.


### anchor_040 — Hollowarch Station

`kragmar_blackwind_rise` / `outpost_2`; Blackwind Rise, levels 31–40; throng. Purpose: secure the approach to the old arches.

**Form:** 2 buildings. pale fossil masonry, dark boards. long guardroom north; small messenger house southwest. Details: bone-shaped stone arch fragment; covered dispatch shelf.

**Approach:** east-to-west open yard preserves retreat. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Orrel Hollowstep (`r20_anchor_040_host`), `r20_anchor_040/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_040_01` — **The Dispatch Shelf**, L31: item `default:wood` ×8. Initially independent.

- `r20_anchor_040_02` — **Claws Beneath the Arch**, L31: kill `grug_mobs:plaguehide_bear` ×3 in `kragmar_blackwind_rise`. Initially independent.

- `r20_anchor_040_03` — **The Watch Under the Storm**, L40: kill `grug_mobs:guard_accord` ×3 in `elandor_stormvault_heights`. After `_02` turn-in.


### anchor_042 — Cutgrass Watch

`kragmar_speargrass_reach` / `outpost_1`; Speargrass Reach, levels 21–30; throng. Purpose: protect cutters and hunters.

**Form:** 2 buildings. acacia, ochre plaster, basalt. broad shade barracks northwest; narrow lookout southeast. Details: grass bundles; marked water jars.

**Approach:** east entry turns round shade porch. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Morga Cutgrass (`r20_anchor_042_host`), `r20_anchor_042/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_042_01` — **Posts for the Shade**, L21: item `default:acacia_wood` ×8. Initially independent.

- `r20_anchor_042_02` — **The Cutters' Long Walk**, L21: kill `grug_mobs:speargrass_tiger` ×3 in `kragmar_speargrass_reach`. Initially independent.

- `r20_anchor_042_03` — **Raiders at the Signal Fire**, L23: kill `grug_mobs:goblin_raider` ×4 in `kragmar_speargrass_reach`. After `_02` turn-in.


### anchor_043 — Red Ramp Post

`kragmar_bannerbreak_mesa` / `outpost_1`; Bannerbreak Mesa, levels 31–40; throng. Purpose: hold the mesa ascent.

**Form:** 2 buildings. red stone, black beams, ochre cloth. high signal hut northeast; low guard hall west. Details: stacked ramp planks; battered practice shield.

**Approach:** southwest entry frames narrow signal roof. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Drek Rampbinder (`r20_anchor_043_host`), `r20_anchor_043/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_043_01` — **Planks for the Ascent**, L31: item `default:acacia_wood` ×10. Initially independent.

- `r20_anchor_043_02` — **Shells Among the Planks**, L31: kill `grug_mobs:scorpion` ×4 in `kragmar_bannerbreak_mesa`. Initially independent.

- `r20_anchor_043_03` — **Sunderstrap's Sentinels**, L33: kill `grug_mobs:bandit_archer` ×4 in `kragmar_bannerbreak_mesa`. After `_02` turn-in.


### anchor_044 — Tornstandard Hold

`kragmar_bannerbreak_mesa` / `outpost_2`; Bannerbreak Mesa, levels 31–40; throng. Purpose: keep the border line supplied.

**Form:** 2 buildings. basalt, acacia, faded red cloth. guard hall south; compact chart house northwest. Details: tattered standard on short pole; shaded map slab.

**Approach:** northeast approach crosses unequal open court. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Yarra Standardmender (`r20_anchor_044_host`), `r20_anchor_044/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_044_01` — **A Standard Needs a Footing**, L31: item `default:cobble` ×8. Initially independent.

- `r20_anchor_044_02` — **The Empty Mesa Patrol**, L31: kill `grug_mobs:skeleton_raider` ×4 in `kragmar_bannerbreak_mesa`. Initially independent.

- `r20_anchor_044_03` — **The Last Hedge Abroad**, L40: kill `grug_mobs:guard_accord` ×3 in `elandor_ashenward_march`. After `_02` turn-in.


### anchor_046 — Reedvoice Station

`kragmar_whispering_reedlands` / `outpost_1`; Whispering Reedlands, levels 21–30; throng. Purpose: mark safe paths through reeds.

**Form:** 2 buildings. junglewood, stone feet, reed roofs. raised watchroom east; low provisions house northwest. Details: split reed signal pipes; drying rope coils.

**Approach:** south approach sees open under-eaves passage. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Enashi Reedvoice (`r20_anchor_046_host`), `r20_anchor_046/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_046_01` — **A Dry Signal Shelf**, L21: item `default:junglewood` ×8. Initially independent.

- `r20_anchor_046_02` — **Cats by the Reed Pipes**, L21: kill `grug_mobs:jungle_lynx` ×4 in `kragmar_whispering_reedlands`. Initially independent.

- `r20_anchor_046_03` — **The False Answering Lights**, L23: kill `grug_mobs:wisp` ×3 in `kragmar_whispering_reedlands`. After `_02` turn-in.


### anchor_047 — Totemwater Post

`kragmar_totemwater_reach` / `outpost_1`; Totemwater Reach, levels 21–30; throng. Purpose: watch inland river crossings.

**Form:** 2 buildings. dark stone, junglewood, teal cloth. carved-post guard hall west; short boat-rope store northeast. Details: small carved marker; empty mooring bollard.

**Approach:** southeast entry faces carved porch. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Tokai Knotreader (`r20_anchor_047_host`), `r20_anchor_047/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_047_01` — **Rope Rack Timbers**, L21: item `default:junglewood` ×8. Initially independent.

- `r20_anchor_047_02` — **Jaws at the River Path**, L21: kill `grug_mobs:crocodile` ×3 in `kragmar_totemwater_reach`. Initially independent.

- `r20_anchor_047_03` — **Mud Around the Marker**, L23: kill `grug_mobs:bog_ooze` ×4 in `kragmar_totemwater_reach`. After `_02` turn-in.


### anchor_048 — Thunderstep Watch

`kragmar_thunderroot_wilds` / `outpost_1`; Thunderroot Wilds, levels 31–40; throng. Purpose: maintain the storm-forest ascent.

**Form:** 2 buildings. ochre stone, junglewood, dark green roof. tall narrow guard house north; broad rain shelter southwest. Details: storm-split stump; hanging runoff trough.

**Approach:** east entry stays clear of stump and shelter. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Host:** Rumela Stormstep (`r20_anchor_048_host`), `r20_anchor_048/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_048_01` — **A Gutter Before the Rain**, L31: item `default:cobble` ×8. Initially independent.

- `r20_anchor_048_02` — **Rainchar's Burning Cargo**, L31: kill `grug_mobs:bandit` ×4 in `kragmar_thunderroot_wilds`. Initially independent.

- `r20_anchor_048_03` — **Across the Glass Passage**, L40: kill `grug_mobs:guard_accord` ×3 in `elandor_glassroot_wilds`. After `_02` turn-in.


### anchor_050 — Slatehook Hideout

`elandor_stormvault_heights` / `bandit_1`; Stormvault Heights, levels 31–40; hostile bandits. Purpose: bandits divert ridge cargo.

**Form:** 2 buildings. stolen pine boards, slate, patched dark cloth. heavy-cloth store northwest; small bunk cabin southeast. Details: ore tally boards; snagged blue pennant.

**Approach:** southwest broken fence opens onto central fight space. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_052 — Coalbrand Yard

`elandor_ashenward_march` / `bandit_1`; Ashenward March, levels 31–40; hostile bandits. Purpose: bandits disguise stolen supply fires.

**Form:** 2 buildings. charred oak, salvaged pale brick, soot cloth. long loot lodge east; short lookout shack northwest. Details: burned crate ends; hooked-sun charcoal mark.

**Approach:** south entry keeps both doorways visible. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_054 — Rootsnare Camp

`elandor_glassroot_wilds` / `bandit_1`; Glassroot Wilds, levels 31–40; hostile bandits. Purpose: bandits strip the forest trade.

**Form:** 2 buildings. dark timber, pale stone feet, ragged green roof. sleep hut northeast; long textile shed west. Details: cut vine coils; confiscated pruning tools.

**Approach:** southeast gap leads to open central yard. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_056 — Pallcloth Den

`kragmar_blackwind_rise` / `bandit_1`; Blackwind Rise, levels 31–40; hostile bandits. Purpose: bandits raid funeral caravans.

**Form:** 2 buildings. gravewood, fossil rubble, dull grey cloth. loot cabin southwest; narrow watch hut northeast. Details: stolen mourning cloth; cold ash bowls.

**Approach:** northwest approach sees watch hut across yard. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_058 — Sunderstrap Camp

`kragmar_bannerbreak_mesa` / `bandit_1`; Bannerbreak Mesa, levels 31–40; hostile bandits. Purpose: bandits raid frontier pack trains.

**Form:** 2 buildings. acacia salvage, red rubble, brown cloth. long hide store north; low bunkhouse southeast. Details: cut harnesses; shattered water jars.

**Approach:** west gap opens away from stored hides. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_060 — Rainchar Camp

`kragmar_thunderroot_wilds` / `bandit_1`; Thunderroot Wilds, levels 31–40; hostile bandits. Purpose: bandits hide smouldering contraband.

**Form:** 2 buildings. wet junglewood, ochre rubble, patched reed roof. raised loot hut west; compact sleeper lodge northeast. Details: blackened wet cargo; broken rain gutter.

**Approach:** south path keeps loot door and escape gap visible. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_061 — Tarncut Mine

`elandor_frostbarrow_shelf` / `mine`; Frostbarrow Shelf, levels 21–30; accord. Purpose: peaceful shelf extraction.

**Form:** 3 buildings. granite, pine, slate roofs. assay hut northwest; braced adit facade northeast; low tool shed south. Details: sorted scree trays; sled rail ends.

**Approach:** west arrival reaches tool shed before mouth. **Bounds:** x/z -10..9, y 0..8; retain existing protection.

**Host:** Kelda Screesort (`r20_anchor_061_host`), `r20_anchor_061/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_061_01` — **A Handle for the Cutting**, L21: item `default:pick_stone` ×1. Initially independent.

- `r20_anchor_061_02` — **Rams on the Haul Lane**, L21: kill `grug_mobs:mountain_ram` ×4 in `elandor_frostbarrow_shelf`. Initially independent.

- `r20_anchor_061_03` — **The Cold Shift**, L23: kill `grug_mobs:snow_leopard` ×3 in `elandor_frostbarrow_shelf`. After `_02` turn-in.


### anchor_062 — Bridgechalk Dig

`elandor_whitebridge_shire` / `mine`; Whitebridge Shire, levels 21–30; accord. Purpose: provide bridge repair stone.

**Form:** 3 buildings. chalk stone, oak, brown roofs. long sorting house west; low braced adit facade northeast; tool cabin southeast. Details: chalk-marked tally wall; stone wheel fragment.

**Approach:** south path sees pale working face behind open sorting court. **Bounds:** x/z -10..9, y 0..8; retain existing protection.

**Host:** Halen Chalkthumb (`r20_anchor_062_host`), `r20_anchor_062/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_062_01` — **Braces for the Pale Face**, L21: item `default:wood` ×10. Initially independent.

- `r20_anchor_062_02` — **The Surveyor's Snare**, L21: kill `grug_mobs:poacher` ×4 in `elandor_whitebridge_shire`. Initially independent.

- `r20_anchor_062_03` — **A Quarry Hand's Pick**, L23: item `default:pick_stone` ×1. After `_02` turn-in.


### anchor_063 — Paleroot Cutting

`elandor_lorindor` / `mine`; Lorindor, levels 21–30; accord. Purpose: extract stone without burying orchard roots.

**Form:** 2 buildings. pale stone, silverwood, green roof. survey hut southwest; broad braced quarry shelter north. Details: root-safe cutting marks; sorted rubble baskets.

**Approach:** east entrance passes empty haul lane. **Bounds:** x/z -10..9, y 0..8; retain existing protection.

**Host:** Saevin Rootscribe (`r20_anchor_063_host`), `r20_anchor_063/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_063_01` — **A Gentle Edge**, L21: item `default:pick_stone` ×1. Initially independent.

- `r20_anchor_063_02` — **The Survey Stakes Vanish**, L21: kill `grug_mobs:poacher` ×4 in `elandor_lorindor`. Initially independent.

- `r20_anchor_063_03` — **Light on the Cutting Marks**, L23: kill `grug_mobs:wisp` ×3 in `elandor_lorindor`. After `_02` turn-in.


### anchor_064 — Memoryvein Dig

`kragmar_ossuary_reach` / `mine`; Ossuary Reach, levels 21–30; throng. Purpose: separate useful rock from memorial stone.

**Form:** 3 buildings. fossil stone, gravewood, black roof. stonecutters lodge east; braced adit facade northwest; record shed southwest. Details: labelled fossil shelves; candle niche.

**Approach:** south lane reaches records before working face. **Bounds:** x/z -10..9, y 0..8; retain existing protection.

**Host:** Neris Fossilhand (`r20_anchor_064_host`), `r20_anchor_064/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_064_01` — **The Record Shed Frame**, L21: item `default:wood` ×8. Initially independent.

- `r20_anchor_064_02` — **The Cutters' Uneasy Night**, L21: kill `grug_mobs:gravewood_treant` ×3 in `kragmar_ossuary_reach`. Initially independent.

- `r20_anchor_064_03` — **A Tool for Unnamed Stone**, L23: item `default:pick_stone` ×1. After `_02` turn-in.


### anchor_065 — Redpick Yard

`kragmar_speargrass_reach` / `mine`; Speargrass Reach, levels 21–30; throng. Purpose: supply metalwork from dry gullies.

**Form:** 2 buildings. red rock, acacia, ochre canvas accents. long ore shelter west; squat miners lodge northeast with braced cutting beside it. Details: water jars; stacked drill poles.

**Approach:** southeast entry opens to shaded sorting space. **Bounds:** x/z -10..9, y 0..8; retain existing protection.

**Host:** Gorren Redpick (`r20_anchor_065_host`), `r20_anchor_065/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_065_01` — **Roof Over the Sorting Trays**, L21: item `default:acacia_wood` ×10. Initially independent.

- `r20_anchor_065_02` — **Hunters at the Water Shade**, L21: kill `grug_mobs:hyena` ×4 in `kragmar_speargrass_reach`. Initially independent.

- `r20_anchor_065_03` — **Stings in the Drill Stack**, L23: kill `grug_mobs:scorpion` ×4 in `kragmar_speargrass_reach`. After `_02` turn-in.


### anchor_066 — Reedstone Cut

`kragmar_whispering_reedlands` / `mine`; Whispering Reedlands, levels 21–30; throng. Purpose: keep a wet-region quarry workable.

**Form:** 3 buildings. dark stone, junglewood, reed roof. raised tally hut northwest; low tool store east; braced adit facade southwest. Details: rope drying frame; runoff channels drawn in paving.

**Approach:** south entry bends clear of mine mouth. **Bounds:** x/z -10..9, y 0..8; retain existing protection.

**Host:** Zali Runoff (`r20_anchor_066_host`), `r20_anchor_066/quest_host`, local(2,1,0), west-facing. Bundled tasks:

- `r20_anchor_066_01` — **Timbers Kept Above Water**, L21: item `default:junglewood` ×8. Initially independent.

- `r20_anchor_066_02` — **The Quarry Pool Moves**, L21: kill `grug_mobs:bog_ooze` ×4 in `kragmar_whispering_reedlands`. Initially independent.

- `r20_anchor_066_03` — **Jaws Along the Haul Path**, L23: kill `grug_mobs:crocodile` ×3 in `kragmar_whispering_reedlands`. After `_02` turn-in.


### anchor_067 — Siltbasket Camp

`elandor_whitebridge_shire` / `mirefolk`; Whitebridge Shire, levels 21–30; hostile Mirefolk. Purpose: Mirefolk control a marsh margin.

**Form:** 2 buildings. mud-coloured masonry, weathered wood, reed roof. wide basket lodge west; small sentry shelter northeast. Details: fishbone rack; stolen market basket.

**Approach:** south gap exposes central ground before huts. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_068 — Whitepetal Fenhold

`elandor_lorindor` / `mirefolk`; Lorindor, levels 21–30; hostile Mirefolk. Purpose: Mirefolk occupy abandoned orchard works.

**Form:** 2 buildings. pale rubble, dark reeds, mossed wood. tall narrow reed hut north; low net house southwest. Details: flower-filled cracked urn; fish drying pole.

**Approach:** east gap bypasses urn and sees both entries. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_069 — Blackreed Enclosure

`kragmar_mournfen` / `mirefolk`; Mournfen, levels 11–20; hostile Mirefolk. Purpose: Mirefolk claim drowned grave-road stores.

**Form:** 2 buildings. grave-stained rubble, dark boards, brown reeds. low longhouse southeast; squat rack shelter northwest. Details: sunken grave marker prop; mud-covered bowls.

**Approach:** west opening retains broad line into centre. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_070 — Hushwater Nests

`kragmar_whispering_reedlands` / `mirefolk`; Whispering Reedlands, levels 21–30; hostile Mirefolk. Purpose: Mirefolk interrupt reed-path traffic.

**Form:** 2 buildings. junglewood, ochre stone, reed roof. wide net lodge northeast; narrow lookout shelter southwest. Details: shell strings; torn route totem.

**Approach:** northwest opening leaves side retreat visible. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing hostile camp roster; no peaceful quest NPC. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_071 — Ashen Wheelbreak

`elandor_ashenward_march` / `clash_1`; Ashenward March, levels 31–40; contested encounter scene. Purpose: static evidence of failed supply crossing.

**Form:** 0 buildings. charred oak, pale rubble, ash. collapsed wagon northwest; low breastwork east; open southwest passage. Details: wheel halves; spilled dark crates.

**Approach:** south diagonal remains open. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_072 — Hedgefire Crossing

`elandor_ashenward_march` / `clash_2`; Ashenward March, levels 31–40; contested encounter scene. Purpose: abandoned contested checkpoint.

**Form:** 0 buildings. scorched timber, pale stones, brown soil accents. broken hedge line west; ruined firing step northeast. Details: burned gatepost; bent banner stand.

**Approach:** southeast-to-northwest path stays clear. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_073 — Redcut Breach

`kragmar_bannerbreak_mesa` / `clash_1`; Bannerbreak Mesa, levels 31–40; contested encounter scene. Purpose: static failed mesa assault.

**Form:** 0 buildings. red stone, basalt, old acacia. wall stump northwest; shallow ramp rubble southeast. Details: snapped spear rack; empty water jar.

**Approach:** east-west centre is free. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_074 — Bannerfall Pocket

`kragmar_bannerbreak_mesa` / `clash_2`; Bannerbreak Mesa, levels 31–40; contested encounter scene. Purpose: cost of a stalled frontier patrol.

**Form:** 0 buildings. basalt rubble, ochre cloth, red stone. fallen standard west; unequal cover stones northeast and south. Details: torn cloth at ground level; broken crate.

**Approach:** north approach reveals fallen standard beyond clear centre. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_075 — Crystal Landing Scar

`front_wyrmglass_crown` / `clash_1`; The Wyrmglass Crown, levels 60–60; contested encounter scene. Purpose: arrival route has seen earlier expeditions.

**Form:** 0 buildings. pale crystalline stone, slate, weathered pine. shattered shelter edge west; low lookout rubble northeast. Details: salt-worn crate; cracked signal slab.

**Approach:** southeast lane remains clear toward island paths. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_076 — Saltgate Remnant

`front_gravesalt_escarpment` / `clash_1`; Gravesalt Escarpment, levels 51–59; contested encounter scene. Purpose: broken coastal checkpoint.

**Form:** 0 buildings. white salt-like stone, gravewood, dark rubble. doorless gate stump north; low barricade southwest. Details: memorial tablet; rotted beam.

**Approach:** east approach sees through gate gap. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_077 — Tombroad Ambush

`front_gravesalt_escarpment` / `clash_2`; Gravesalt Escarpment, levels 51–59; contested encounter scene. Purpose: failed escort beside tomb galleries.

**Form:** 0 buildings. fossil rubble, dark boards, pale soil accents. cart remains southeast; tomb-wall corner northwest. Details: dragged stone slab; empty lantern bracket.

**Approach:** southwest-northeast diagonal remains open. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_078 — Causeway Toll Ruin

`front_broken_causeway` / `clash_1`; The Broken Causeway, levels 31–40; contested encounter scene. Purpose: old civic road becoming a battlefield.

**Form:** 0 buildings. pale masonry, oak, dark moss. half toll arch west; fallen booth wall northeast. Details: weathered toll slab; broken bench.

**Approach:** south approach sees arch against open centre. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_079 — Fordward Wreck

`front_broken_causeway` / `clash_2`; The Broken Causeway, levels 31–40; contested encounter scene. Purpose: supply failure on a ford approach.

**Form:** 0 buildings. mud-dark stone, oak, muted linen. cart bed northwest; low crossing marker southeast. Details: loose barrel hoops; split route stone.

**Approach:** east-west centre stays clear. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_080 — Aqueduct Last Step

`front_broken_causeway` / `clash_3`; The Broken Causeway, levels 31–40; contested encounter scene. Purpose: abandoned high route across the marsh.

**Form:** 0 buildings. pale stone, brick, moss. broken aqueduct pier northeast; stone fragments southwest. Details: dry channel fragment; discarded masonry tools.

**Approach:** northwest approach sees tall pier to one side. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_081 — West Trench Mouth

`front_shattered_line` / `clash_1`; The Shattered Line, levels 41–50; contested encounter scene. Purpose: static trench-edge position without terrain excavation.

**Form:** 0 buildings. red earth tones, basalt, charred beams. low trench revetment west above grade; collapsed shelter northeast. Details: plank bundles; broken spade prop.

**Approach:** south-north channel stays walkable. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_082 — Siege Ramp Foot

`front_shattered_line` / `clash_2`; The Shattered Line, levels 41–50; contested encounter scene. Purpose: spent siege route.

**Form:** 0 buildings. red stone, acacia beams, blackened iron accents. short ruined ramp northeast; sparse barrier southwest. Details: broken wheel rim; stacked empty crates.

**Approach:** west entry faces ramp side with bypass to south. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_083 — No-Man's Orchard

`front_shattered_line` / `clash_3`; The Shattered Line, levels 41–50; contested encounter scene. Purpose: civilian land consumed by war.

**Form:** 0 buildings. charred wood, red rubble, brown soil accents. two unequal dead stumps northwest; wall ruin southeast. Details: blackened basket; low grave stones.

**Approach:** east-west centre preserves open sightline. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_084 — Skyroot Crossing

`front_skyglass_canopy` / `clash_1`; The Skyglass Canopy, levels 51–59; contested encounter scene. Purpose: failed crossing in cloud forest.

**Form:** 0 buildings. pale stone, dark timber, faded green cloth. root-shaped timber remnant west; low wall elbow northeast. Details: cut rope coils; cracked route marker.

**Approach:** southeast approach stays below props and open. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_085 — Cloudwatch Fall

`front_skyglass_canopy` / `clash_2`; The Skyglass Canopy, levels 51–59; contested encounter scene. Purpose: abandoned elevated observation point.

**Form:** 0 buildings. pale cliff rubble, silverwood, grey cloth. broken watch platform northwest; scattered masonry east. Details: fallen signal post; empty lantern cup.

**Approach:** south clear strip leaves both exits visible. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_086 — Thunder Shore Wreck

`front_stormscale_summit` / `clash_1`; Stormscale Summit, levels 60–60; contested encounter scene. Purpose: island arrival under repeated storms.

**Form:** 0 buildings. ochre basalt, wet junglewood, green-grey cloth. split expedition frame southeast; low stone shield northwest. Details: rain-filled bowl prop; broken oar.

**Approach:** northeast-southwest diagonal stays clear. **Bounds:** x/z -8..7, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_087 — Wyrmglass Dragonspire

`front_wyrmglass_crown` / `dragon`; The Wyrmglass Crown, levels 60–60; contested encounter scene. Purpose: frame the existing dragon encounter.

**Form:** 0 buildings. pale crystalline stone, grey slate, sparse frost tones. three uneven perimeter rock teeth north/west; low broken offering wall southeast. Details: scored stones; empty hoard recess.

**Approach:** keep both island-route accesses and central arena open. **Bounds:** x/z -16..15, y 0..12; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_088 — Stormscale Dragonroost

`front_stormscale_summit` / `dragon`; Stormscale Summit, levels 60–60; contested encounter scene. Purpose: frame the existing dragon encounter.

**Form:** 0 buildings. dark basalt, ochre rock, restrained green vegetation. broken basalt rib west; low storm-shattered altar northeast. Details: split tree trunk; rain-cut stone grooves.

**Approach:** two independent island approaches remain open. **Bounds:** x/z -16..15, y 0..12; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_089 — Wyrmglass Fault Camp

`front_wyrmglass_crown` / `apex_mine`; The Wyrmglass Crown, levels 60–60; contested encounter scene. Purpose: dangerous all-gem expedition workplace.

**Form:** 2 buildings. granite, pine, slate, pale crystal accents. long survey lodge northwest; shorter braced assay shelter southeast. Details: six labelled sample recesses; rope coil rack.

**Approach:** southern arrival splits to camp and independent dragon path. **Bounds:** x/z -16..15, y 0..12; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_090 — Stormscale Gem Camp

`front_stormscale_summit` / `apex_mine`; Stormscale Summit, levels 60–60; contested encounter scene. Purpose: dangerous all-gem expedition workplace.

**Form:** 2 buildings. basalt, junglewood, ochre roof accents. broad rain lodge northeast; narrow assay house southwest. Details: six labelled sample recesses; storm gauge prop.

**Approach:** northwestern arrival sees both roofs and unblocked mine access. **Bounds:** x/z -16..15, y 0..12; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_091 — Grimtusk's Rooting

`elandor_goldmead_vale` / `rare_grimtusk`; Goldmead Vale, levels 11–20; contested encounter scene. Purpose: signs of Grimtusk on an orchard margin.

**Form:** 0 buildings. oak roots, brown soil accents, low grey stone. broken fence northwest; uprooted log east. Details: furrow marks in surface dressing; overturned feed trough.

**Approach:** south centre is clear for existing rare route. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_092 — Whitefang's Cold Den

`elandor_ashenward_march` / `rare_old_whitefang`; Ashenward March, levels 31–40; contested encounter scene. Purpose: signs of Old Whitefang along the march.

**Form:** 0 buildings. grey stone, dark oak, pale lichen accents. low rock crescent northeast; fallen trunk west. Details: gnawed bone props; rubbed stone.

**Approach:** southwest gap keeps escape from rock crescent. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_093 — The Bane's Scar

`elandor_stormvault_heights` / `rare_korgans_bane`; Stormvault Heights, levels 31–40; contested encounter scene. Purpose: signs of Korgan's Bane on exposed ridge.

**Form:** 0 buildings. slate, granite, storm-scorched pine. split monolith west; low scree heap southeast. Details: scarred shield prop; crushed pine bough.

**Approach:** north-south strip stays open. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_094 — Silkfang's Loom

`front_skyglass_canopy` / `rare_silkfang`; The Skyglass Canopy, levels 51–59; contested encounter scene. Purpose: Silkfang's ambush scene.

**Form:** 0 buildings. pale rock, dark timber, pale web-like decoration. two uneven dead limbs northwest; low cocoon-shaped stone east. Details: silken pale bands; abandoned pack.

**Approach:** south approach sees through props with free centre. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_095 — Marrowclaw's Scrape

`kragmar_blackwind_rise` / `rare_marrowclaw`; Blackwind Rise, levels 31–40; contested encounter scene. Purpose: Marrowclaw's feeding trace.

**Form:** 0 buildings. fossil stone, gravewood, ash-grey soil accents. clawed fossil block northeast; fallen gravewood southwest. Details: scattered bone props; stripped bark.

**Approach:** east-west gap avoids support surfaces under actor. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_096 — Dustwing's Perch

`kragmar_bannerbreak_mesa` / `rare_dustwing`; Bannerbreak Mesa, levels 31–40; contested encounter scene. Purpose: Dustwing's exposed resting ground.

**Form:** 0 buildings. ochre stone, acacia, dull feathers as texture accents. low broken pillar northwest; wind-scoured rubble south. Details: shed feather motif; shattered bowl.

**Approach:** east approach keeps central perch root clear. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_097 — Emerald Coil's Hollow

`front_stormscale_summit` / `rare_emerald_coil`; Stormscale Summit, levels 60–60; contested encounter scene. Purpose: Emerald Coil's humid island refuge.

**Form:** 0 buildings. basalt, junglewood, deep green accents. curved fallen trunk north; low warm stone southeast. Details: shed-skin motif; crushed ferns.

**Approach:** southwest opening keeps encounter footprint broad. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_098 — Ashmaw's Burnt Hollow

`kragmar_redtusk_savanna` / `rare_ashmaw`; Redtusk Savanna, levels 11–20; contested encounter scene. Purpose: Ashmaw's feeding trace on the savanna.

**Form:** 0 buildings. red rubble, charred acacia, brown soil accents. burned trough west; low split rock northeast. Details: scorched grass pattern; cracked clay jar.

**Approach:** south arrival sees centre before cover. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_099 — Bonerattle's Broken Toll

`front_broken_causeway` / `rare_captain_bonerattle`; The Broken Causeway, levels 31–40; contested encounter scene. Purpose: western scene on Captain Bonerattle's existing migration.

**Form:** 0 buildings. pale road stone, oak, faded cloth. leaning toll slab northwest; broken cart rail southeast. Details: old coin motif in fixed prop; empty hat peg.

**Approach:** east-west lane remains unblocked. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


### anchor_100 — Bonerattle's Siege Halt

`front_shattered_line` / `rare_captain_bonerattle`; The Shattered Line, levels 41–50; contested encounter scene. Purpose: eastern scene for the same migrating Captain Bonerattle.

**Form:** 0 buildings. red rubble, acacia, grey cloth. wheel-less supply frame northeast; low marker stones west. Details: matching toll motif; snapped drum frame.

**Approach:** south-north gap retains existing route passage. **Bounds:** x/z -6..5, y 0..8; retain existing protection.

**Actors/quests:** retain existing encounters; no additional actor. Nearby friendly hosts may discuss this scene; no additional socket, quest marker or required visit objective.


## Creative receipt and implementation acceptance

Inputs inspected: approved Round20 plan/state; current settlements, quests,
story and zone design; `source/simple_map.lua` anchor/profile data;
`r7_anchor_roster.lua`, `r7_settlement.lua`, settlement socket registry, WP13
capital-service/quest-shell and start layouts; quest catalog/registry/dialogue;
current mob spawn palettes and guard registrations. Reference sources were not
modified. No game implementation, engine run, Lua suite, synchronization or
push belongs to this creative step.

Authored accounting: six villages,18 outposts,six frontier bandit camps,six
mines,four Mirefolk camps,two apex camps =42 inhabited;16 clash sites,two arenas,
ten rare-route scenes =28 open encounters. Captain Bonerattle has two scene
cards for two existing route anchors, not two independently spawned rares.
30 regional hosts,18 civic identities (six reused shells,12 new cooks),90+48
new quest sketches. The six cultures ×17 existing quest revision rubric covers
all102 prior entries. Final quest count remains editorial, not a test quota.

Implementation acceptance requires authored-cell bounds, full NPC feet/head
clearance, existing actor/spawn clearance, distinct silhouettes, village building
counts, named readable approaches, and actual manifest/planner projection. Those
checks belong to the approved final round gate, not a new test fleet here.
No geometry claim in these cards replaces final construction evidence.

Review calibration: implementing model GPT-6 Astra; independent reviewer pending;
Critical/High findings not yet assessed; corrective rounds0; elapsed time unknown.

User visual playtest: visit one second village, frontier outpost/bandit camp,
peaceful mine, Mirefolk camp, battlefield, island camp/arena and rare scene;
walk every door/approach, check that existing actors do not spawn in scenery,
then follow one starter bundle, level10 capital introduction and destination
handoff. Confirm cooks and trainers are different people and hidden follow-ups
appear only after turn-in.

## Civic identity and journey ledger

Civic positions use the frames below; `existing` means the current published
core quest socket, including its authored direction, never a copied coordinate.
Plot coordinates go through ordinary plot/reference-height projection.

| NPC ID / name | Settlement / exact socket | Frame / position |
|---|---|---|
| `r20_dwarf_start_cook` / Hilda Hearthspoon | `hearthpine/quest_cook` | anchor (2,1,13) |
| `r20_dwarf_capital_cook` / Varda Copperpan | `dur_brannoc/terrace_bakehouse/terrace_bakehouse_quest_cook` | service_plot (2,1,-1) |
| `r20_dwarf_capital_envoy` / Dorrin Gateledger | `dur_brannoc/ancestor_hall_quest` | existing |
| `r20_human_start_cook` / Bess Honeycrust | `dawnmere/quest_cook` | anchor (2,1,13) |
| `r20_human_capital_cook` / Ansel Ovenward | `highcourt/homes_bakehouse/homes_bakehouse_quest_cook` | service_plot (2,1,-1) |
| `r20_human_capital_envoy` / Mariel Waybook | `highcourt/chapel_quest` | existing |
| `r20_elf_start_cook` / Liora Dewpot | `silverleaf/quest_cook` | anchor (2,1,13) |
| `r20_elf_capital_cook` / Mirael Petalpot | `lethariel/market_bakehouse/market_bakehouse_quest_cook` | service_plot (2,1,-1) |
| `r20_elf_capital_envoy` / Eriath Boughwarden | `lethariel/star_hall_quest` | existing |
| `r20_undead_start_cook` / Neral Saltkeeper | `stillgrave/quest_cook` | anchor (2,1,-13) |
| `r20_undead_capital_cook` / Velis Mourningbowl | `nhal_veyr/homes_mourners_hall/homes_mourners_hall_quest_cook` | service_plot (2,1,-1) |
| `r20_undead_capital_envoy` / Ossa Quietregister | `nhal_veyr/vigil_hall_quest` | existing |
| `r20_orc_start_cook` / Ugra Brothstone | `sunscar/quest_cook` | anchor (2,1,-13) |
| `r20_orc_capital_cook` / Gorla Longladle | `gor_drazhak/warren_cook_court/warren_cook_court_quest_cook` | service_plot (2,1,-1) |
| `r20_orc_capital_envoy` / Thorga Roadspeaker | `gor_drazhak/skull_hall_quest` | existing |
| `r20_troll_start_cook` / Zemi Sweetroot | `kapok/quest_cook` | anchor (2,1,-13) |
| `r20_troll_capital_cook` / Teshani Smokereed | `kezamba/shore_smokehouse/shore_smokehouse_quest_cook` | service_plot (2,1,-1) |
| `r20_troll_capital_envoy` / Nalo Pathdrum | `kezamba/shrine_quest` | existing |

The following18 travel leads are pure conversations. Each becomes visible by
its level/race/faction eligibility at the source; accepting another journey is
not its prerequisite. Their destination also accepts the turn-in. Capital
introductions are the separate12 entries in JSON, first available at level10.

| Quest ID | Level | Source NPC | Destination NPC / place |
|---|---|---|---|
| `r20_dwarf_journey_01` | 21 | `r20_dwarf_capital_envoy` | `r20_anchor_014_host` / Tarnwatch Fold |
| `r20_dwarf_journey_02` | 24 | `r20_anchor_014_host` | `r20_anchor_061_host` / Tarncut Mine |
| `r20_dwarf_journey_03` | 31 | `r20_anchor_061_host` | `r20_anchor_027_host` / Splitbolt Station |
| `r20_human_journey_01` | 21 | `r20_human_capital_envoy` | `r20_anchor_016_host` / Whitebridge Market Close |
| `r20_human_journey_02` | 24 | `r20_anchor_016_host` | `r20_anchor_062_host` / Bridgechalk Dig |
| `r20_human_journey_03` | 31 | `r20_anchor_062_host` | `r20_anchor_031_host` / Cinderline Watch |
| `r20_elf_journey_01` | 21 | `r20_elf_capital_envoy` | `r20_anchor_018_host` / Lorindor Berrycourt |
| `r20_elf_journey_02` | 24 | `r20_anchor_018_host` | `r20_anchor_063_host` / Paleroot Cutting |
| `r20_elf_journey_03` | 31 | `r20_anchor_063_host` | `r20_anchor_036_host` / Glassroot Gate |
| `r20_undead_journey_01` | 21 | `r20_undead_capital_envoy` | `r20_anchor_020_host` / Ossuary Ledgerstead |
| `r20_undead_journey_02` | 24 | `r20_anchor_020_host` | `r20_anchor_064_host` / Memoryvein Dig |
| `r20_undead_journey_03` | 31 | `r20_anchor_064_host` | `r20_anchor_039_host` / Ashveil Watch |
| `r20_orc_journey_01` | 21 | `r20_orc_capital_envoy` | `r20_anchor_022_host` / Speargrass Wellhold |
| `r20_orc_journey_02` | 24 | `r20_anchor_022_host` | `r20_anchor_065_host` / Redpick Yard |
| `r20_orc_journey_03` | 31 | `r20_anchor_065_host` | `r20_anchor_043_host` / Red Ramp Post |
| `r20_troll_journey_01` | 21 | `r20_troll_capital_envoy` | `r20_anchor_024_host` / Whisperreed Landing |
| `r20_troll_journey_02` | 24 | `r20_anchor_024_host` | `r20_anchor_066_host` / Reedstone Cut |
| `r20_troll_journey_03` | 31 | `r20_anchor_066_host` | `r20_anchor_048_host` / Thunderstep Watch |

The machine-readable `existing_quest_rework` array lists all102 actual existing
quest IDs and their individual change instruction. It is an implementation
checklist; every row is still **pending implementation** at this creative
commit. The90 regional and48 other new sketches are likewise authored plans,
not runtime registrations. No content may be reported delivered from this
ledger alone.

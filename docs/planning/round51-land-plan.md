# Partial plan — Round 51, land zones

Draft, 2026-10-19. One of the two partial plans of Round 51; the other one
covers the sea. A round coordinator merges both into the round plan. **No lane
starts from this file.**

## 1. Goal

The Round 47 swamp rework made the swamp the players' favourite area. The rest
of the land should get the same care, without overdoing it: small changes can
make a big difference. Each zone gets a few characteristic changes, scaled to
what it lacks. The user judges every proposal in a concept viewer and decides
there what goes into the game and what goes back for rework.

## 2. Rulings (the user, 2026-10-18 and 2026-10-19)

**Process**

1. **Concept viewer first** (the user: "unbedingt"). Nothing goes into the game
   before the user has picked it in the viewer.
2. **Everything is built together** in the build phase, including the swamp
   textures that are already picked. There is no early lane.
3. **Land and sea share one map reset.** The sea part needs a reset anyway.

**Grounds and textures**

4. **Swamp.** The user picked:
   - the calm 2 × 2 versions of wet grass (top) and wet (mottled) mud (top);
   - the calm side textures of both, `wet_grass_side_calm` and
     `mud_mottled_side_calm` (the old sides go);
   - the continuous hanging-moss strand above today's tapered end piece;
   - 2 × 2 versions of plain mud and dry mud (top), by Astra on branch
     `r51-swart`.

   Everything is in the lab's "All calm proposals" set.
5. **Moss.** Astra's muted moss soil (top and side, branch `r51-swart`)
   **replaces today's "neon" forest moss** (`grug_nodes:dirt_with_moss`, part
   of the elf-forest mix). The swamp gets **a moss type of its own**, a new
   node for the swamp's moss ground.
6. **Large flat grounds go to 32 px, world-aligned** (`align_style = "world",
   scale = 2`): one texture spans 2 × 2 nodes at the same 16 px per node. This
   is for silver litter, blight dirt, bone litter, mesa clay, canopy litter and
   the swamp grounds.

**Decoration**

7. **Every decorative block drops a matching default block** (cobblestone,
   stone, gravel, dirt, wood…). Players must not end up collecting lots of
   special blocks. This covers the ruin and boulder kit, which the user agreed
   to.
8. **Bones are used sparingly.** A placed skeleton should be a find, not the
   impression that everything is full of skeletons.
   - Use a small, varied set (skull, ribcage, scattered bones; humanoid and
     animal).
   - Place pieces singly, or occasionally as a pair such as a skull with a
     ribcage.
   - Rare, but never the same picture twice.
9. **The skeleton set replaces `grug_nodes:bone_pile`** everywhere.
   - Today `bone_pile` is a retinted coral skeleton, a pale branching sprite
     that does not read as bones; the user has never noticed one.
   - It stands in blight (1/500 of columns) and bone forest (1/250).
   - Towns use it too: the undead undergrowth (`wp13/palette.lua:524`) and the
     bones in camps and nests (`wp13/decor_kit.lua:55`).

   Its node name may stay as one of the set's pieces so the town kits keep
   working. Recognisable bones get a far lower density than 1/250.
10. **No glowing plants and no decorative mushrooms.**
    - A mushroom that looks like food must be food everywhere. The only
      mushrooms in the game are T3 (`grug_gathering:mushroom`,
      `grug_food/init.lua:557`; Cave Cap, `grug_cooking/init.lua:31`), so a
      lookalike that drops them in some zones and nothing in others would
      mislead players.
    - No other zone has glowing plants.
    - This also rules out mushroom rings for the elves.
11. **Flowers:** a few in the jungle (strong colours) and a few for the elves
    (pastel). For the same reason as ruling 10, they must not be mistaken for
    the gathering plants, several of which are blossoms (marshbloom, crimson
    lotus…). The viewer shows them next to the gathering sources of their zone.
12. **Gravestones get one or two block types of their own** that combine into
    gravestones. They are used both in the wild and in the towns' graveyards,
    which look odd today, and drop cobblestone.
13. **Cairns** use either special blocks by Astra or the trees' branch and twig
    shapes, and drop cobblestone.
    - Built from branch shapes they will look rough. That is fine if they stay
      small and compact.
    - The user decides in the viewer.
14. **Orc skeletons need no large bone blocks.** The pieces shared with the
    undead are enough, with a little variation (humanoid and animal).
15. **Savanna:** nothing needed; the acacias carry it.
16. **Papyrus grows directly on the ground**, at the water on sand, not on a
    pedestal (see §4).
17. **Beaches may stay "more boring"** than other areas; they are small and
    local. A few changes are welcome.
18. **New wild plants regrow like every other wild plant.** This covers
    papyrus, the beach plants and the new flowers, ferns, lichen and alpine
    plants. They use the habitat renewal (`grug_farming/renewal.lua`,
    `docs/design/farming.md` "Wild plant renewal"):
    - random spots near players, never closer than 20 nodes;
    - a chance that rises with the local deficit;
    - up to the natural density the world generator would produce there,
      measured by counting neighbours.

    The build lanes register every new plant with the vegetation authority
    (`wp40/vegetation_density.lua`). Hanging plants (moss, lianas) belong to
    their trees; the lane says how they come back.

19. **No copper-green ore stains** (2026-10-19). A copper-coloured stain on
    rock reads like ore, the same mix-up as ruling 10. They are left out and
    not designed at all.

## 3. Where the zones stand today

Facts from the 2026-10-18 inventory. The mapgen is the WP40 R7 Lua mapgen:
- Decorations are rows in `DECORATION_ROWS`
  (`mods/MAPGEN/grug_mapgen/wp40/r7_r6_manifest.lua:100`).
- Surfaces are set in `r7_r6_manifest.lua:48-65`, plus the patch mix in
  `r6_content.lua:614-629`.
- Wild ruins, graveyards and statues do not exist; such structures appear only
  in settlements and POIs.

| Faction | Biomes | Today |
|---|---|---|
| Dwarf | `grug_crags`, `grug_crags_snowy`, `grug_pine_hills` | Crags are gravel with stone outcrops. Their only decorations are rare pine bushes, and pines above y 60. Snowy crags have none. |
| Elf | `grug_elf_forest`, `grug_deep_forest` | Silver litter is flat pixel noise. Silverwood 1/200, apple, bush, grass. |
| Orc | `grug_badlands(_east)` (the "desert"), `grug_savanna` | Badlands: mesa clay, large cactus 1/1000, dry shrub 1/125. |
| Troll | `grug_deep_jungle`, `grug_jungle_fringe`, `grug_jungle_edge` | Jungle and kapok trees plus jungle grass, nothing else. |
| Undead | `grug_blight`, `grug_bone_forest` | Blight dirt (flat purple noise), gravewood, dry shrub, `bone_pile`. |
| (all) | `grug_beach` | Bare sand, no decorations. |

There are no flowers (the `flowers` mod is not shipped), no lianas and no
yellow foliage. Bones exist as an item (`grug_mobs:bone`, skeleton drops,
crafting) and as the `bone_pile` decoration.

## 4. Content per zone (for the viewer; the user picks)

**Swamp (finish).**
- The textures of rulings 4 and 5, and the swamp's own moss type (Astra).
- Hanging moss as two nodes: a continuous strand above a tapered end. Digging
  the end piece turns the strand above it into the new end.

**Troll, jungle (large; "bunter und ein bisschen wilder", the user: "genau
so").**
- Lianas hanging from jungle leaves, with the same strand/end logic as the
  moss.
- Two or three tropical flowers in strong colours (red, orange, violet).
- Ferns and large-leaved bushes on the ground.
- Now and then a fallen kapok log.

**Undead (large).**
- Small wild graveyards: 3–5 crooked gravestones from the new blocks and a
  broken fence. They are rare, and smaller and more ruined than the towns'
  graveyards, so Stillgrave and Nhal Veyr stay special.
- Mossy ruin remnants (two or three wall pieces).
- Rarely a weathered statue or obelisk.
- Skeleton pieces (rulings 8 and 9).
- The towns' graveyards switch to the new gravestone blocks.

**Dwarf (medium; "triste Steingebiete", low and high).**
- Boulders of 2–4 nodes, stone and mossy cobble.
- A lichen carpet (like the moss carpet, grey-orange).
- Small alpine plants.
- Cairns as old waymarks (ruling 13).
- Higher up: ice patches, dead snow-covered pines.

**Orc, badlands (medium).**
- Skeleton pieces, humanoid and animal (ruling 14).
- More yellow, withered bushes: a new withered-foliage node in a small bush,
  like the acacia bush.
- Coloured clay bands on steep slopes, like real mesas.

**Elf (small; the silver ground is monotonous).**
- A structured silver-litter texture, with leaves in clusters instead of noise,
  at 32 px. The user wants to see it before deciding.
- Occasional small ruin pieces and mysterious, decayed statues (the user's
  idea).
- A few pastel flowers (ruling 11).
- Fallen silverwood logs.

**Savanna:** nothing (ruling 15).

**Papyrus (fix).**
- **The defect.** The swamp row `swamp_papyrus` places Luanti's
  `papyrus_on_dirt.mts`: two dirt nodes with up to five papyrus on top, made
  for papyrus rising out of shallow water. A WP40 template is anchored on the
  first free node above the ground (`r6_templates.lua:283-318`). So the two
  dirt nodes, turned to mud, stand as a pillar on the ground with the papyrus
  on top. That is the "papyrus on two blocks" the user saw.
- **The fix.** Place papyrus as a plain stack (2–4) on its host.
- **Proposal for the viewer.**
  - Papyrus moves to sand at the water's edge, on the shores of the warm zones.
  - The swamp interior keeps the Round 47 reeds and cattails, which look
    similar and now do that job.
  - Papyrus stays available for paper. Fishing catches yield it as well
    (`grug_fishing/catch.lua:11`).

**Sand and beaches (small, ruling 17).** Sand occurs in two places that are
handled more or less separately:
- **above water**: the beach and dry shores;
- **under water**: the bed of the sea, lakes and rivers, and the shore of many
  biomes (`bed` and `shore` columns in `r7_r6_manifest.lua:48-65`).

The ideas below are for sand above water only. The bed under water belongs
with the sea's terrain changes. A new sand texture would show in both places.

- Marram grass tufts on the dry sand away from the waterline
  (`default:marram_grass_1-3` exists and is unused).
- Now and then driftwood, which drops default wood or sticks.
- Small pebble patches in the sand mix.
- Possibly a 32 px sand.

Whether this belongs to the land or the sea part is open (§8).

## 5. Phases and lanes

Model routing is the user's per session. The defaults are: Opus for the viewer
and the build lanes, Astra for art, independent review as usual.

### Phase 1 — concept (no game code)

- **VIEW (Opus): the zone viewer.** It extends the swamp concept page
  (`tools/r47_sw`, with the texture lab of branch `r51-swart`) into a viewer
  with a zone switcher.
  - Per zone, a patch with today's ground mix and decorations next to the
    proposal, switchable.
  - The kit as small structures, each naming the drop of every block it uses.
  - The flowers next to the gathering plants of their zone (ruling 11).
  - The papyrus fix and the beach ideas.
  - Kept from the swamp page: the texture lab with PNG upload and the "one
    ground everywhere" switch for judging repetition.
  - The patch is a faithful-enough reading of the zone's rows and shares, not
    a port of the mapgen. The lane documents where it simplifies.
- **ART (Astra), possibly split into two lanes:**
  - **Grounds:** swamp moss, the 32 px grounds (ruling 6), the structured
    silver litter.
  - **Plants:** lianas (strand and end), 2–3 strong and 2–3 pastel flowers,
    the withered yellow bush foliage, lichen carpet, alpine plants.
  - **Props:**
    - the skeleton set (humanoid and animal skull, ribcage, scattered bones);
    - gravestone blocks (1–2);
    - cairn stones;
    - statue pieces (undead, elves) where default blocks are not enough.
  - **Format:** textures plus node shapes (node boxes) in a form the viewer
    reads directly.
  - **Rules as in Round 47:** own work, CC0, generator committed, no Lua,
    nothing under `mods/`, no fixtures.
- **The user's picks** in the viewer, zone by zone. Rework goes back to ART or
  VIEW. Densities are rough guide values, set by eye in the viewer.

### Phase 2 — build (after the picks)

A proposed split for the coordinator:
- **LG, grounds:** the world-aligned ground tiles, the swamp ground set, the
  swamp moss node, the forest moss texture, and the hanging-moss strand/end
  pair. These are nodes and textures only; where the grounds lie is the joint
  mapgen lane's job (below).
- **LP, plants:** liana strand/end, flowers, bushes, lichen, alpine plants,
  their decoration rows per zone, their regrowth (ruling 18), and the papyrus
  fix (a decoration row).
- **LK, kit:** the decorative prop nodes (all with default drops), small
  schematics, rare placement rows, the skeleton set replacing `bone_pile`, and
  the towns' graveyards on the new gravestone blocks.
- The beach items go to whichever part the coordinator assigns them (§8).
- Recommendation for the merged round: **one joint mapgen lane for terrain and
  surfaces**, land and sea together (see §8). Decoration and kit lanes (land
  and sea) build on it in a later wave; mobs stay separate.
- Documentation in the round's D lane.

## 6. Rules and checks

- **Map reset:** new decoration only appears in newly generated terrain; one
  reset shared with the sea part (ruling 3).
- **World-aligned tiles:** Luanti supports them on solid nodes and node boxes
  only, not on plantlike nodes. The scale must divide 16; 2 does
  (`reference_projects/luanti/doc/lua_api.md`, tile definition). LG checks the
  look in the engine once.
- **Towns and POIs:** kit structures stay clear of settlements, roads and POIs,
  and no structure damages terrain it does not own. The terrain guard applies
  only if a lane touches fire or explosions; none is planned.
- **Mapgen cost:** rows and small schematics are cheap. The build lanes measure
  generation time before and after and report it as a comparison, not against
  a target. If generation is clearly slower, the user decides.
- **Game logic** (strand/end on digging, drops, placement rules) gets an
  independent review, fix deltas included.
- **Fixtures:** the usual sentence in every launch prompt. The art and viewer
  lanes run none.
- **Particles:** none planned.

## 7. Starting material

- Branch `r51-swart` (not merged):
  - `8dbeea8d`: the texture lab and the calm proposals (Claude);
  - `13c6272c`: Astra's 2 × 2 mud, dry mud, moss soil and moss soil side;
  - `d864dda4`: those wired into the lab.
- Texture lab: <https://claude.ai/artifact/ApNwovQhjjLF6VsRERfv3F> (private).
- The swamp concept as built in Round 47: `tools/r47_sw/DESIGN.md`, and the
  swamp pass `mods/MAPGEN/grug_mapgen/wp40/swamp_writer.lua`.
- Policy: `docs/planning/mapgen-native-plan.md` ruling 1 (native where
  possible). Authored surface, decorations and trees stay own Lua.

## 8. Interfaces to the sea part

- **The sea part owns** the sea and everything under it.
- **The land part owns** the swamp pools and the freshwater plants.
- **Sand and beaches are shared ground.** The sand texture also lies under all
  water, and beaches are the sea's edge. The user leans towards the land part;
  the round coordinator decides after reading both plans.
- **One joint mapgen lane (recommendation).** Both parts change terrain and
  surfaces in the same files: the surface rows and shores in
  `r7_r6_manifest.lua`, and the surface selector and ground mixes in
  `r6_content.lua`. Sand above and below water meet exactly there.
  - One lane owns these terrain and surface changes for land and sea
    together: the sea's terrain changes, sand above and below water, the
    swamp's moss ground, and the orc clay bands.
  - The decoration and kit lanes of both parts follow in a later wave. They
    mostly add rows and nodes, so they collide little.
  - The sea's mobs stay a separate lane.
  - One lane for everything (terrain, decorations, kit, sea decorations) would
    be too large to review. The split follows the layers, not land and sea.

## 9. Open questions

1. Cairns: Astra's blocks or tree branch shapes. Decided in the viewer
   (ruling 13).
2. Sand and beaches: land part or sea part. Decided by the coordinator (§8).

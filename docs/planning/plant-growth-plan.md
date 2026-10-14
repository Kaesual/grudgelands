# Partial plan — plant growth, light, seeds and salt

> **Scheduled in Round 48** ([round48-plan.md](round48-plan.md)). Its §2
> rulings and §3 interfaces override this file where they differ.

Status: **partial plan for the next round**, not yet scheduled. The user
approved the concept in chat on 2026-10-14 and added the salt and
wild-visual rulings the same day (§2.15–2.21); a coordinator folds this
file into the round plan together with other partial plans. Rulings in §2
are the user's; §3 lists the defaults this draft chose, which the lanes
build unless the user overrides them. File facts are against main
`6a8afb9f`. The art for this work (new crops, redesigns from the user's
review) is planned separately in [plant-art-plan.md](plant-art-plan.md).

## 1. Goals and reasons

**Why.** A player reported that papyrus does not grow by torchlight and
asked why mushrooms give no seeds or spores. A read-only study (chat
2026-10-14) found that the growth rules are inconsistent:

- The 17 farm crops need **no light at all**, only wet farm soil
  (`grug_farming/init.lua` `crop_timer`, line 232). They grow in total
  darkness.
- Papyrus, cactus and saplings need **light 13**
  (`default/functions.lua:221,252`, `default/trees.lua:22`). The Coal torch
  (light 12) gives 11 next to it, so these never grow indoors with Coal
  torches; the Anthracite torch (14, new in 0.47.0) gives exactly 13 on a
  face-adjacent node only.
- Papyrus grows only on six vendored dirt nodes
  (`default/functions.lua:228-238`). In the swamp it stands on
  `grug_nodes:mud` or sand (`r7_r6_manifest.lua:155`), so a player who copies
  the swamp gets no growth, and wild swamp papyrus never grows either.
- Two different mushrooms exist: `grug_gathering:mushroom` is found-only by
  design, `grug_cooking:cave_cap` is a crop. Three dishes take only the wild
  Mushroom (`grug_cooking/init.lua:135-143`).
- `biomes_mobs.md` §2 lists Sunleaf, Marshbloom, Stormkelp and Melon as
  "farmable: yes", but none of them has seeds.
- **Salt** is two items. Salt Crust (a T5 item; used in Stormkelp Broth,
  Salt-Crusted Fish, Kelp-Wrapped Roast and the T6 Grand Feast) is a crop
  with "Salt Crust Seeds" made from the crust itself; Rock Salt (a T6 item;
  used in Jungle Cocoa and Cocoa-Rubbed Game) is found-only on three
  coasts. Both count as minerals and never renew in the
  wild (`grug_mapgen/wp40/habitat_registry.lua:5`, `world.md` R4), so Rock
  Salt is a finite resource today.

**What we want.** One set of rules a player can learn in a sentence each:

1. **Light:** plants grow where it is bright enough that no monster spawns
   (light 8, daylight or torchlight). Fungi and cave plants need no light.
   Trees need real daylight.
2. **Ground:** crops grow on wet farm soil. Papyrus and cactus grow on the
   ground they stand on in the wild.
3. **Seeds:** only cultivated plants drop seeds. Any harvest item crafts
   into two seeds. Papyrus and cactus regrow from their bottom piece.
   Ground cover is decoration, without seeds or propagation.
4. **Salt** is no plant: it regrows in the wild, and Salt Crust can also be
   collected in a crafted salt pan by water.
5. **Tooltips:** every plant item says in one line how it grows or where it
   comes from.

## 2. Rulings (user, 2026-10-14)

1. **Light for plants.** Most plants need light to grow, at a level that
   "works well" without a torch beside every plant: **light 8**, the level
   at which no mob spawns (cave rows spawn at `max_light` 7; see the
   comment in `grug_materials/torch.lua:7-10`).
2. **Exempt from light:** fungi and cave plants, i.e. **Cave Cap, Mushroom
   (new) and Ember Moss**.
3. **Indoors.** Papyrus, cactus and every farm crop can be grown inside a
   base.
4. **Trees and bushes** keep growing only in daylight (torches do not
   count).
5. **Spices and healing herbs stay gather-only.** Sunleaf, Marshbloom,
   Stormkelp, Gravemoss, Dragonweed and Crimson Lotus are never cultivated.
   This supersedes `biomes_mobs.md` §2's "farmable: yes" for the three
   spices.
6. **Melon becomes a crop** (`grug_gathering:melon`; distinct from the
   existing Frost Melon crop).
7. **Mushroom becomes a crop** (`grug_gathering:mushroom`). This revokes its
   found-only status. Wild Cocoa and Rock Salt stay found-only.
8. **Seeds for every cultivated plant**, except papyrus and cactus: they
   regrow when the player leaves the bottom piece standing.
   **Sugar Cane and Bamboo keep their seeds** (their right-click harvest
   already keeps the root).
9. **Ember Moss stays a crop** (Round 10 decision), although it is a
   healing herb in the wild.
10. **Seeds of fungi are called "Spores"** (display name only).
11. **Only cultivated plants drop seeds.** Wild plants drop their harvest
    only (already true). Seeds come from the existing recipe "1 harvest
    item → 2 seeds" (already exists for every crop family) and from
    cultivated crops.
12. **Ground cover** (grass, ferns, reeds, cattails, moss carpet, …) can be
    gathered and placed for decoration but has no propagation cycle and no
    seeds. This is already the case (they drop themselves; natural renewal
    is off inside a claim) — verify, do not rebuild.
13. **Tooltips:** plants and their harvest items get a short explanation
    line (e.g. "Grows on wet farm soil.").
14. **Upgrade:** production has not been deployed since 0.45.1; the next
    deploy is a map reset anyway. No migration for crops that stand in the
    dark today.
15. **Salt Crust is no longer a crop.** No Salt Crust Seeds, no "crust →
    seeds" recipe.
16. **Salt pan.** A crafted Salt Pan stands on **any ground with water
    nearby**, needs **no light**, and collects Salt Crust over time. Recipe:
    **metal of a fitting tier + a filled Water Bucket + salt**. The Water
    Bucket is **consumed** with the craft (no empty bucket comes back, no
    extra code for it). The pan makes Salt Crust only.
17. **Rock Salt stays gather-only** (no pan, no crop).
18. **Both salts regrow in the wild** (Rock Salt and Salt Crust): a
    deliberate exception to `world.md` R4 for salt.
19. **The initial world density of both salts stays as it is** (renewable
    rows are otherwise generated at half density, `farming.md` "Initial
    wild population").
20. **Wild Potato and wild Corn look like their stage 4 crop**, as every
    other wild crop does, not like the harvest item (user's plant review,
    2026-10-14).
21. **Art changes** from the user's plant review go to GPT-6 Astra as a
    design round with three drafts per item:
    [plant-art-plan.md](plant-art-plan.md).

## 3. Defaults chosen by this draft

The user may overrule any of these; the lanes build them otherwise.

1. **Light is measured as at noon:** `core.get_node_light(pos, 0.5)`, the
   maximum of noon daylight and artificial light. Outdoor plants therefore
   keep growing at night; artificial light counts around the clock. One
   constant (`PLANT_LIGHT = 8`), shared by crops, papyrus and cactus.
2. **Trees and bushes:** `core.get_natural_light(pos, 0.5) >= 13` replaces
   the light test in `default.can_grow` (`default/trees.lua:22-25`). Glass
   passes sunlight, so a glass roof works; torches no longer help a
   sapling.
3. **Apple and blueberry regrowth** (`default/nodes.lua:831,1784`, light 11
   from any source) stays unchanged.
4. **Ember Moss seeds are also called "Spores"** (moss spreads by spores),
   so the three light-exempt crops share one word.
5. **Papyrus ground:** `group:soil` (every dirt, litter, mud and farm soil
   node) or `group:sand`, with water within 3 nodes as today.
6. **Cactus ground:** `group:sand` or `grug_nodes:mesa_clay` (the badlands
   cactus stands on mesa clay). The `default:large_cactus_seedling`
   (`default/nodes.lua` ~1394, a Basic recipe from 5 cactus) follows the
   same light rule and accepts the same ground.
7. **Cactus harvest like papyrus:** cactus gets `default.dig_up` in
   `after_dig_node` as papyrus already has (`default/nodes.lua:1424`), so
   digging a piece takes everything above it and the bottom piece regrows.
   Today a dug middle piece leaves the upper pieces floating.
8. **Darkness pauses a crop like dryness does:** progress is kept exactly
   and resumes when light returns. No progress accrues while dark.
9. **Tooltip wording** as in §4.1 (proposals; the FARM lane finalizes).
10. **The WP33 gathering catalog stays untouched.** Its `farmable`,
    `found_only_food` and `image` fields are hashed into
    `EXPECTED_MANIFEST_SHA256` (`grug_gathering/catalog.lua:11`), which
    `grug_mapgen/wp40/r7_manifest.lua` pins too. Changing them would ripple
    into the mapgen manifest. Visual changes to P9G sources (§2.20, the art
    plan) are applied as runtime overrides from a separate presentation
    file; the design docs record the new farming status.
11. **Salt pan recipe:** a Basic recipe, **3 Embersteel Bars**
    (`grug_materials:embersteel_bar`, tier 5 like Salt Crust) **+ 1 Water
    Bucket** (`grug_farming:water_bucket`, consumed, §2.16) **+ 1 Salt
    Crust** → 1 Salt Pan. "Salt" is Salt Crust
    (the pan's own product, as a seed would be); the bar count mirrors the
    bucket's three Iron Bars.
12. **Salt pan behaviour:** four fill stages at 200 s each (the crop
    timing), water (`group:water`) within 3 nodes of the pan, progress
    paused and kept while there is no water. Right-click on a full pan
    scrapes one Salt Crust and resets it to stage 1. Digging returns the
    Salt Pan (plus one Salt Crust when full). The pan reuses the existing
    basin look (`grug_nodes/crop_visual.lua` "salt" shape and the
    `grug_farming_salt_crust_*` textures).
13. **Salt regrowth** uses the existing wild renewal with each salt's own
    habitat (Rock Salt: the three coast zones and their shore rule; Salt
    Crust: mesa clay in The Shattered Line) and the resource-plant rates;
    inside an active claim nothing renews, as for plants.
14. **Wild Melon and wild Mushroom** follow §2.20 too: once they are crops,
    their P9G source nodes take their stage-4 crop look, like every other
    wild crop. Their items get the new harvest icons from the art plan.

## 4. Lanes

Suggested split: **FARM** (logic, salt and tooltips), **ART** (all art,
planned in [plant-art-plan.md](plant-art-plan.md)) and the round's docs
lane. FARM and ART can start in the same wave (see §7).

### 4.1 Lane FARM — light rule, papyrus/cactus/trees, crops, salt, tooltips

**Light gate for crops.** Growing crops (stages 1–3) advance only while
their root node has plant light ≥ 8, unless the crop's profile marks it as
light-exempt (Cave Cap, Mushroom, Ember Moss). Suggested mechanism: treat
"lit" exactly like "wet". The soil check under a growing crop already runs
every 15 s (`soil_timer`, line 85) and pauses or resumes the crop timer with
exact progress (`pause_crop_timer`/`resume_crop_timer`, lines 52-66). Make
it pause/resume on "wet and lit" instead of "wet". Today it acts only when
the soil node changes; light is not node state, so it has to evaluate on
every check under a growing crop. `crop_timer` (line 232) and
`start_crop_timer` (line 68) need the same condition, so a stale or new
timer cannot advance in the dark. Cost: one light read per growing crop per
15 s. A flag in `crop_profiles.lua` (e.g. `dark = true`) marks the exempt
families.

**Papyrus and cactus.** GRUG PATCH in `default/functions.lua:203-290`
(the file's existing convention): light test → plant light ≥ 8 measured at
noon; papyrus ground → §3.5; cactus ground → §3.6, including the ABMs'
`neighbors` lists. Keep `node.param2 >= 4 → return` in `grow_cactus`
(vendored guard against growing rotated pieces). Unverified: whether the
badlands `large_cactus.mts` cacti carry param2 ≥ 4 and so stay as
generated once mesa clay counts — check it and report; growing wild cacti
up to the height cap of 4 is acceptable if not. Wild swamp
papyrus will start growing to its height cap of 4; this is intended. Check
whether papyrus or cactus stands inside protected towns or POIs
(`grug_core.world_alterable`); if so, growth there must ask the terrain
guard like sapling growth does (`grug_trees/growth.lua`). Add cactus
`dig_up` (§3.7).

**Trees.** `default.can_grow` light test → §3.2. Every sapling, bush
sapling included, uses it (`default/trees.lua:544`).

**Crop population: 18 families.** Two new, one removed:

| Key | Harvest item | Profile | Shape | Light |
|---|---|---|---|---|
| `melon` (new) | `grug_gathering:melon` | `regrow_ground_fruit`, `regrow_stage = 2` (like Pumpkin) | `ground_fruit` | needs light |
| `mushroom` (new) | `grug_gathering:mushroom` | `regrow_bush`, `regrow_stage = 2` (like Cave Cap) | `mushroom` | exempt |
| `salt_crust` (removed) | — | becomes the salt pan below | — | — |

File facts: crops are built from every `grug_cooking.PLANTS` row
(`grug_farming/init.lua:166-169`), so `salt_crust` must be skipped there
while it stays a Cooking item; the staple loop `for _, key in
ipairs({"potato", "corn"})` (line 171) adds `melon` and `mushroom`; the
population check `#crops ~= #grug_cooking.PLANTS + 2` (line 599) becomes
the new count (15 − 1 + 4 = 18); `crop_profiles.lua`;
`grug_nodes/crop_visual.lua` `SHAPES` (line 3); `grug_farming/seed_visuals.lua`
(asserts a visual per key; drop `salt_crust`); the Basic seed recipes in
`grug_jobs/basic_recipes.lua` (rows from line 111; the catalog is generated:
a change is a row in `tools/r45_rg/edits.lua`, then rerun
`tools/r45_rg/gen_basic_recipes.lua`). Seed item names:
`grug_farming:seed_melon`, `grug_farming:seed_mushroom`. Stage textures
`grug_farming_<key>_<1..4>.png` come from lane ART; until it merges, FARM
ships placeholder copies (Pumpkin → Melon, Cave Cap → Mushroom, with a
colorize modifier where needed) so FARM never waits on ART.

**Spores.** The seed description is built at line 423
(`row.description .. " Seeds"`). The light-exempt families (§2.10, §3.4)
use "Spores" instead.

**Salt pan (§2.15–2.16, §3.11–3.12).** A craft item `Salt Pan` that places
on the top face of any walkable, solid node (not a liquid, not
`buildable_to`) after the usual protection checks for the placed node. The
placed pan has its own node timer, independent of farm soil; it reuses
the salt basin visuals. No light check. Where the existing crop code
(`transition_crop`, `harvest_crop`, `dig_crop`) can serve the pan through
a profile flag instead of a second implementation, prefer that; the lane
decides and reports. The recipe is an ordinary Basic recipe row; the
Water Bucket is a plain ingredient and is consumed whole (§2.16), so the
Basic recipe system needs no change.

**Salt regrowth (§2.18–2.19, §3.13).** Remove `rock_salt` and `salt_crust`
from `EXCLUDED` in `grug_mapgen/wp40/habitat_registry.lua:5`.
`initial_denominator` (same file) doubles the denominator of every
renewable key; keep the two salts' initial density as it is, so world
generation (`world_content.lua:110,129`, `r7_p9g.lua:515`) does not change.
Verify that renewal (`grug_farming/renewal.lua`, `vegetation_density.lua`
around line 300) finds Rock Salt's shore spots (`salt_cardinal`; Stormkelp
uses the same shore machinery with `dry_cardinal`) and Salt Crust's mesa
clay hosts, and that `natural_light` 10 at noon holds on those spots.

**Wild Potato, Corn, Melon and Mushroom (§2.20, §3.14).** Their P9G source
nodes (`grug_gathering:<key>_source`) take `row.image`, the item icon
(`grug_gathering/nodes.lua:13-20`). Give them the stage-4 crop look the
other wild crops use (`grug_nodes.crop_visual(key, 4, …, "wild")`, as in
`grug_mapgen/world_nodes.lua:5`) by a runtime override from a separate
file (§3.10). Potato and Corn keep their item icons; Melon and Mushroom
items take the art plan's new icons.

**Keep the salt basin visual.** `salt_crust` leaves the crop population,
but its `crop_visual.lua` shape and the `grug_farming_salt_crust_*`
textures stay: the wild source `grug_mapgen:salt_crust_source`
(`world_nodes.lua`) and the salt pan use them.

**Tooltips.** One pass at load, like `grug_materials.apply_tool_level_tooltips`
(`grug_materials/mining.lua:268`): appends one line, idempotent, after the
other description writers (`grug_food` appends its own lines,
`grug_food/init.lua:492`). Keep it to one line per item. Proposals:

| Items | Line |
|---|---|
| Harvest item of a crop that needs light | `Craft into seeds. Grows on wet farm soil in light.` |
| Seeds of a crop that needs light | `Plant on farm soil near water. Needs daylight or torchlight.` |
| Cave Cap, Mushroom, Ember Moss (harvest item and spores) | `Grows on wet farm soil, even in the dark.` |
| Papyrus | `Grows on dirt, mud or sand near water. Leave the bottom stalk to regrow.` |
| Cactus | `Grows on sand. Leave the bottom piece to regrow.` |
| Saplings (trees and bushes) | `Needs open sky or glass to grow.` |
| Salt Crust | `Scraped from a salt pan or found in the wild.` |
| Salt Pan | `Place on any ground near water. Collects salt crust.` |
| Wild Cocoa, Rock Salt, Sunleaf, Marshbloom, Stormkelp | `Found in the wild only.` |
| Gravemoss, Dragonweed, Crimson Lotus | `Gathered in the wild by alchemists.` |

Ember Moss is both a healing herb in the wild and a crop; its line is the
crop line. "Near water" means within 3 nodes; the line stays short on
purpose. The tooltip texts are written by Opus or the coordinator, not by
GPT-6 Astra (Astra writes quest texts, never item tooltips). Texts are
English.

**Verify, do not rebuild (§2.11, §2.12):** wild crop sources drop only
their item (`grug_mapgen/world_nodes.lua:9`), P9G sources drop only their
raw item, ground cover (`default:grass_*`, ferns, dry grass, marram,
junglegrass, dry shrub, `grug_nodes:reeds`, `:cattails`, `:moss_carpet`)
drops itself and is placeable. Report each as confirmed or changed.

### 4.2 Lane ART

All art for this work — the stages and seeds of Melon and Mushroom, the
Salt Pan icon and the redesigns from the user's plant review — is one
design round for GPT-6 Astra with three drafts per item and a pick page:
[plant-art-plan.md](plant-art-plan.md). FARM wires the art plan's target
file names (its §6) with placeholder PNGs, so the art merge only replaces
images (its §7).

### 4.3 Docs (the round's docs lane)

- `docs/design/farming.md`: 18 families; the light rule with the exempt
  set and the noon measurement; papyrus, cactus and saplings; spores; the
  salt pan replaces "the cultivated Salt Crust basin" (lines 7, 32, 89-90);
  salt regrows in the wild with unchanged initial density (lines 71,
  88-90); tooltips.
- `docs/design/world.md` R4 (line 267): the salt exception.
- `docs/design/biomes_mobs.md` §2: the "Farmable later" column and the
  "Farmable in WP32" table (lines ~146-150, 304-314) — Mushroom becomes a
  crop; Sunleaf, Marshbloom and Stormkelp are gather-only; Melon is a crop.
  The "Deliberately found-only" paragraph (line 369) keeps Wild Cocoa and
  Rock Salt only; Rock Salt now regrows.
- `docs/design/items_crafting.md` §3.7 where it lists cultivated families
  and the salts (lines ~1044-1125).
- `docs/design/world_zones.md:2129` ("All seventeen families").
- CHANGELOG: plants now need light (dark farms stop); papyrus grows on
  mud and sand and indoors; Melon and Mushroom are crops; spores; the salt
  pan; salt regrows; tooltips.

## 5. Rules

- No new crop mechanics beyond this plan (no fertilizer, seasons, random
  yield, light levels per species).
- Growth timings stay as they are (4 stages × 200 s; papyrus ABM 14 s ×
  1/71; cactus 12 s × 1/83); the salt pan uses the crop timing.
- Crop harvest and drop contract unchanged (`farming.md` "Cultivation and
  tools").
- World generation output does not change (the salts keep their initial
  density; P9G visuals change by runtime override only).
- Upgrade class of this work on its own: compatible (new items and nodes,
  changed growth rules, removed salt crop nodes); the round's map reset
  (§2.14) covers it anyway.

## 6. Verification

**Fixtures** (only the ones that test the changed behaviour, the full fleet
once per lane):

- crop: a crop in darkness does not advance; placing a light source
  resumes it with its partial progress kept; removing it pauses again;
  light 7 pauses, light 8 grows; light-exempt crops grow at light 0;
- crop: Melon and Mushroom plant, grow, harvest (right-click regrow to
  stage 2) and craft into two seeds/spores; population check 18; no Salt
  Crust seed item or seed recipe;
- salt pan: placeable on stone, sand and dirt with water within 3; not
  placeable on a liquid or without protection; fills in the dark; pauses
  without water and keeps its progress; right-click on a full pan gives
  one Salt Crust and resets to stage 1; digging returns the pan; the
  recipe consumes 3 Embersteel Bars, the filled Water Bucket and one Salt
  Crust and returns nothing;
- renewal: Rock Salt and Salt Crust are renewable; their initial
  denominators are unchanged; a renewal tick in a fixture habitat places
  each salt below its target;
- papyrus: grows on mud and sand next to water, at plant light 8 indoors,
  not at 7, not without water; cactus on sand and mesa clay; a cactus
  piece with param2 ≥ 4 does not grow; cactus `dig_up`;
- sapling: does not grow under an Anthracite torch without sky, grows under
  glass;
- wild Potato, Corn, Melon and Mushroom source nodes use the stage-4 crop
  visual; the wild Salt Crust source still registers;
- tooltips: each listed item has exactly one added line, also after a
  second application.

Existing fixtures that touch farming and may need updates:
`tools/r30_p4/portable_test.lua`, `tools/r45_rg/corpus_base.lua` (Basic
recipe corpus), `tools/r23_renewal/` (renewal). Because world generation
must not change, the round-end seed fleet doubles as that check.

**GUI checklist (the user):**

1. In a closed, unlit room: farm soil with water, plant Carrot and Cave Cap
   seeds. Carrot stays, Cave Cap grows.
2. Place a Coal torch in that field: Carrots within 4 blocks start growing.
3. Swamp papyrus planted on mud beside water inside the base, torch nearby:
   it grows (patience: ~16 min per piece on average).
4. Dig the second papyrus piece: everything above comes along, the bottom
   regrows. Same for cactus on sand.
5. A sapling in a glass-roofed room grows; in a stone-roofed room with
   torches it does not.
6. Hover over Carrot, Carrot Seeds, Mushroom Spores, Papyrus, Sunleaf, Salt
   Pan: one readable explanation line each.
7. Melon and Mushroom: craft seeds/spores, plant, harvest by right-click.
8. Craft a Salt Pan (the Water Bucket is used up), place it on stone next
   to water in a dark room, scrape a crust when it is full.
9. Wild Potato and Corn in the meadows (and Melon in the jungle) look like
   grown plants, not like items.

## 7. Orchestration notes

- **Lanes and waves:** FARM and ART in the same wave; FARM ships
  placeholder textures, ART replaces them after the user's pick. Merge
  FARM first, then ART (shared: `grug_farming/textures/`,
  `seed_visuals.lua`, `LICENSE-media.md`, the P9G presentation override
  file). Docs in the round's docs lane after both.
- **Review:** FARM changes game logic → independent review is mandatory;
  ART gets the usual art review plus the user's pick.
- **Shared files with other work:** `default/functions.lua`,
  `default/trees.lua`, `default/nodes.lua` (vendored, GRUG PATCH),
  `grug_farming/init.lua`, `grug_jobs/basic_recipes.lua` with
  `tools/r45_rg/edits.lua`, `grug_mapgen/wp40/habitat_registry.lua`,
  `docs/design/farming.md`, `docs/design/biomes_mobs.md`,
  `docs/design/world.md`. The coordinator checks the other partial plans
  for these.
- **Decided during the round:** the final tooltip texts (FARM proposes,
  the coordinator checks, the user can change them in the GUI test); the
  art picks (the user).

# Round 11 initial read-only diagnosis (historical)

This records the first discussion before the user response. Proposals here are
not current instructions where superseded by [the planning decisions](round11-planning-decisions.md).

# Round 11 playtest discussion

Date: 2026-09-20. Inspected baseline: `ac232ec2`.
Status: discussion draft, not an adopted design or implementation contract.
The user requests careful feedback and planning before the next round.
No runtime changes, tests, synchronization or deployment were performed for
this diagnosis. Root coordinated three native GPT-5.6 Sol read-only agents.
Own-provider delegation remains native; no Claude tasks this session.

Once decisions are accepted, move them into the relevant `docs/design/`
authorities, update the affected implementation packages, and remove resolved
questions here. Do not silently treat recommendations as accepted rules.

## Verified defects and reported acceptance

- Dragon disappearance after teleport-away/return has a concrete lifecycle
  defect: `grug_mobs/bosses.lua:540-555,597-617` retains an alive flag while
  `mobs/api.lua:3555-3643` may serialize a terminal far-despawn marker. Removal
  on activation does not call the dragon's death callback in
  `grug_mobs/boss_dragons.lua:816-823`. Preserve authored dragons across ordinary
  unload and retain real-death respawn semantics. Merely initializing
  `remove_ok=false` cannot fix the later serialization path. Exact GUI sequence
  has not been reproduced by agents.
- Profession learning updates metadata immediately, but
  `mods/PLAYER/grug_jobs/trainers.lua:58-76` does not refresh the stored Sfinv
  inventory formspec. Refresh after successful learn/unlearn without changing
  the user's current inventory page.
- All five primary station forms share `size[10,10]` and an eight-slot list at
  x=1 (`station_nodes.lua:72-81`). Real-coordinate slot spacing puts its right
  edge at 10.75. Widen/recenter the shared form and inspect other station forms.
- Tailor, Woodcarver and Goldsmith share an upside-down table nodebox:
  tabletop y=-0.50..-0.36, legs extend upward to +0.25
  (`station_nodes.lua:284,328`).
- Seeds use tinted harvest icons (`mods/ITEMS/grug_farming/init.lua:215-220`).
  Farmer's Hoe uses an axe image (:291-297). Hoe wear already exists outside
  Creative (:285-287), currently 64 uses. The user confirmed Creative was enabled:
  the reported absence of wear is explained, not a confirmed wear defect.
- Gatehouse stairs come from the shared
  `mods/MAPGEN/grug_mapgen/wp13/capitals.lua:1031,1101-1114` template. The reported
  head collision is credible from the opening geometry. Extend clearance along
  the ascent; confirm player-sized clearance and rotated variants rather than
  assuming one arbitrary air node is sufficient.
- Mount controller already follows look yaw while stationary. Visual chain is
  controller -> player -> mount visual (`grug_mounts/entity.lua:194-240,285-320,
  359-391`). Exact local-client transform failure is still a hypothesis. Keep
  first-person owner hiding, camera behavior and remote visibility while fixing
  visible orientation; do not feed rotation back into player camera input.
- Stable displays deliberately freeze at one animation frame
  (`grug_mobs/capital_displays.lua:32-87`). Some catalog stand clips are real
  multi-frame animations; horse, boar and wolf currently declare a single-frame
  stand. A walk loop played in place is not an acceptable idle replacement.
- Silversteel armor directly uses VoxeLibre diamond assets
  (`tools/r10_art/build_armor_assets.sh:20`); weapon/tool palette also has a blue
  bias (`tools/wp13/gen_weapon_ladder.py:81`).
- User accepts percentage fall damage and natural cave openings. Planted crop
  growth on hydrated tilled soil looks correct.

## Visual and capital proposals — pending

- Separate seed/propagule silhouettes from edible harvests. Inspect VoxeLibre,
  farming and x_farming candidates; reuse or tint actual seed sprites where
  suitable. VoxeLibre plants carrots/potatoes directly, so it does not provide
  separate seeds for every crop. x_farming has a corn-seed image.
- Tailor: licensed VoxeLibre loom appearance. Shared smith station: VoxeLibre
  anvil appearance, retaining our station logic. Goldsmith: muted golden working
  head on a dark anvil base, clearly named for jewelry; color is proposed, not
  adopted. Fix the Woodcarver table too. Anvil appearance grants no repair rules.
- Stable: fenced open shelter with earth floor, flat roof on six posts and
  enough room for all four racial models. Ground mounts make short bounded
  walks with pauses; flyers stay grounded with genuine available idle clips.
  This changes the prior static-display scope. No combat AI, breeding, loot or
  collectible animals. Define paths, clearance, unload/reload and population
  bounds before implementation; do not assume every mesh has a head-idle clip.
- Silversteel: bright neutral silver with only subtle cool shadows, consistent
  across icons, worn skins and material parts of weapons/tools. Preserve forms,
  handles and existing detail; check distinction from Iron and Steel.

## Wild plants: density and renewal — pending

Wild cooking plants currently have no runtime renewal:
`mods/MAPGEN/grug_mapgen/world_content.lua:58-80` places them during generation;
`world_nodes.lua:4-22` defines drops but no regrowth. Farmed crops are renewable
through harvesting and replanting.

The user proposes approximately half the current wild abundance, preserving
regional species distribution. Apply any approved density adjustment to the
agreed edible/plant source families, not blindly to grass, flowers or mineral
sources. Current probabilities and host predicates are in
`world_content_catalog.lua:24-45` and `world_zones.md:1708-1724`; older gathering
sources must be inventoried too. Halving per-family placement probabilities
does not guarantee exactly half of every visible patch.

`world.md` R4 currently forbids resource regeneration outside protected sockets.
Recommend an explicit wild-plant exception, leaving ores/minerals unchanged.
Proposed mechanism: sparse habitat-cell work queue, persistent depletion and
cooldowns, bounded placement attempts only in loaded terrain, local per-species
population limit and existing habitat/support predicates. Exclude roads,
functional protected content, farmland and player construction/claims; no
visible stump and no whole-zone scans or forced emergence. Handle destruction
other than ordinary harvesting, fractional low-density targets, overlapping
players and reloads explicitly. Cell size, replenishment rate and inclusion of
alchemy herbs, cave plants and non-botanical Salt Crust remain open. Renewal
must remain much slower/less dependable than an intentional farm.

## Water buckets and hoes — pending

Recommend a universal Basics water-only bucket made from three Iron Bars in the
reference bucket layout, available by Iron/T2 rather than waiting for Housing.
Housing is decided for level 20 but WP24 is still open. Empty/full item states;
source pickup and placement honor protection and never handle lava. Decide how
the two existing water source families are represented/preserved. Flow across
protected boundaries is part of this scope, not just source placement checks.

Recommend a cheap wooden hoe plus material-tier hoes with identical soil
conversion and increasing durability. A successful actual conversion spends
one use outside Creative. Exact uses and repair integration remain open; avoid
re-tilling existing farmland for wear or progression.

## Durability and repair — pending WP22/WP44 decisions

Already decided (`items_crafting.md` section 8.3; `economy.md` section 4):
approximately 3000 combat events for ordinary equipment / 6000 for refined;
zero durability disables effects without destroying the item; NPC repair costs
ledger money and scales with item level, quality and missing durability.
Exact prices must be calibrated with the economy, not resurrect an old formula.

Root recommendation: universal paid repair at ordinary settlement traders in
start locations, capitals and inhabited hubs, avoiding mandatory capital trips.
Repair one/all with a quote. Profession-based material repair is an optional
alternative, not a requirement: each crafter repairs the equipment families it
owns at its station and within its tier. That would amend the current NPC-only
rule. Include Woodcarver, Leatherworker and Goldsmith families when assigning
ownership; never assume all weapons belong to Weaponsmith.

Proposed wear boundaries: one accepted attack rather than each native packet or
each AoE victim for weapons; one damaging combat hit after dodge/full absorb
for equipped armor. Environmental damage and death do not add armor wear.
Clarify periodic effects, shields/offhands, caster equipment and accessory wear
before freezing the contract. Preserve item identity, affixes and metadata.

Open: adopt material repair at all; material/charge granularity and cost,
NPC pricing targets and discounts, event details, warning thresholds and scope
of the WP22 slice. Repair price should be proportional to missing durability;
small repeated repairs must not create a cheaper rounding exploit. Materials
need proportional value without charging a full expensive bar for trivial wear.

## Beaches and proposed work order

Screenshot, position and world seed are pending. Preserve the accepted overall
beach width, shape and course. A source-grounded hypothesis is discontinuity
between cardinal shore search, coarser distance samples and quantized run
orientation (`wp40/height.lua:177-208,5283-5330,5391-5439`). Do not declare this
the cause or shave arbitrary columns before reproducing the observed location.

After decisions, proposed parallel packages:

1. Lifecycle and mount presentation: dragons, look-yaw, stable animations.
2. Crafting UI and assets: immediate books, station forms, workstation models,
   seeds, hoe silhouettes and Silversteel palette.
3. World geometry: gate clearance, diagnosed beach defect and stable shelter.
4. Farming/resource loop: buckets, tier hoes, reduced wild abundance and agreed
   renewal semantics; coordinate stable/source ownership with package 3.
5. Durability/repair as an explicitly bounded WP22 slice with WP44 price inputs,
   only after its remaining design is decided.

Packages 1-3 can be prepared independently. At most three workers are active
alongside root; later packages reuse slots. Runtime implementation has not
started. Final acceptance must cover real unload/reactivation and visible
formspec/attachment behavior, not just interpreter parity or source assertions.

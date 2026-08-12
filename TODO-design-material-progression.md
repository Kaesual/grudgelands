# TODO — Material progression, regional resources, and mining access

**Status:** design-session staging document, updated 2026-08-11. **Do not
implement from this file.** The decisions and review resolutions below have
not yet been folded into the authoritative design specifications or BACKLOG.
A separate integration pass must reconcile all affected documents and work
packages after the owner's current WP is complete.

This file supersedes its own earlier drafts. In particular, it no longer
treats private housing isles or guilds as open alternatives, no longer places
G2 gemstones only in T5/T6, and no longer uses rock-node `level` against pick
`groupcaps.cracky.maxlevel` as the progression gate.

Decision labels used here:

- **Confirmed** — directly decided by the owner and binding for the later
  integration pass.
- **Material-review resolution** — the concrete design selected here where the
  owner delegated the detailed distribution or asked for a recommendation. It
  is the handoff target unless the owner explicitly changes it.
- **Open** — still requires owner input, runtime calibration, or work owned by
  the map/housing stream.

No statement in this staging file overrides `docs/design/` until the coordinated
integration happens.

---

## 1. Confirmed universal material spine

### 1.1 Six universal metal and pickaxe tiers

All six race regions use the same mandatory metal, pickaxe, and natural-depth
progression. Neither a faction nor a race controls a material required to
craft the next universal pickaxe.

| Tier | Character levels | Metal | Processing |
|---|---:|---|---|
| T1 | 1–10 | **Bronze** | Copper + Tin in the dual furnace |
| T2 | 11–20 | **Iron** | Iron ore in the normal furnace |
| T3 | 21–30 | **Steel** | Iron bar + mined Coal in the dual furnace |
| T4 | 31–40 | **Silversteel** | Steel + Silver in the dual furnace |
| T5 | 41–50 | **Embersteel** | Silversteel + **Emberglass** in the dual furnace |
| T6 | 51–60 | **Abyssal Steel** | Embersteel + Abyssal Crystal in the dual furnace |

Steel has two real material inputs. Mined **Coal** occupies the second material
slot; merely burning coal as fuel does not turn Iron into Steel. **Charcoal**
may fuel the machine but never substitutes for the mined-Coal ingredient.

The universal bar and pickaxe recipes consume no regional G1/G2 gemstone, no
cultural material, and no rare or king trophy. This is the non-circular spine
that lets a player reach contested resources before recipes ask for them.

### 1.2 Emberglass and material ownership

**Confirmed:** Emberglass replaces Emberstone as the visible and canonical T5
crystal. It must become a real Grudgelands item/node family rather than remain a
description-only reinterpretation of `default:mese*`.

The namespace boundary remains:

- unchanged mundane materials such as Stone, Copper, Tin, Iron ore, Coal and
  Gold may retain stable upstream itemstrings;
- reinterpreted fantastic materials, new regional gems and canonical processed
  outputs belong to a clean Grudgelands namespace;
- `grug_materials` owns the public taxonomy and lookup API even when a mundane
  entry retains an upstream itemstring;
- old Mese/Emberstone and new Emberglass must not survive as parallel usable
  versions of the same concept.

WP25 has not been runtime-tested and already requires a fresh world for its
mapgen changes. This is therefore the least wasteful point for the clean
semantic and namespace break.

### 1.3 Grudgeforged is a masterwork state

**Confirmed:** Abyssal Steel is the normally craftable T6 metal. A qualifying
trophy is consumed when an equipment item receives its final masterwork state;
for an Abyssal Steel item that state is **Grudgeforged**. A trophy is not an
ingredient of an Abyssal Steel bar or pickaxe.

Consequences:

- the dual furnace needs only two material inputs plus fuel;
- a player can craft a T6 pick and enter the full T6 depth band without killing
  a named rare or king;
- trophies control optional masterwork equipment, not access to universal T6;
- all old three-material `Grudgesteel` bar assumptions are obsolete.

---

## 2. Revised pickaxe, depth, and harvesting model

### 2.1 Confirmed model change

The current WP25 rule — deeper cosmetic rock carries a higher `level`, and a
pick must meet it with `groupcaps.cracky.maxlevel` — is retired.

Three independent checks replace it:

1. **Territory/protection check:** may this player change this position at all?
2. **Natural-depth check:** does the wielded pickaxe reach the target node's y?
3. **Resource-harvest check:** if this is an ore/gem resource, is the pickaxe
   tier high enough to receive its drop?

The checks must remain separate. Territory rules must not depend on tool
capabilities, cosmetic rock hardness must not encode political ownership, and
the no-drop resource rule must not be mistaken for permission to mine deeper
than the pickaxe allows.

### 2.2 Material-review resolution: exact pickaxe depths

Retain the six boundaries implemented by WP25. Boundaries are inclusive at the
bottom of the tier shown.

| Pickaxe tier | Canonical pickaxe | Maximum natural mining depth | Natural band it opens | Next-pick material is available no deeper than |
|---|---|---:|---|---:|
| T1 | Bronze | **y = −100** | surface/T1 Stone | Iron: y ≥ −100 |
| T2 | Iron | **y = −300** | Slate | Steel inputs: y ≥ −300 |
| T3 | Steel | **y = −500** | Basalt | Silver: y ≥ −500 |
| T4 | Silversteel | **y = −700** | Granite | Emberglass: y ≥ −700 |
| T5 | Embersteel | **y = −1000** | Emberrock | Abyssal Crystal entry supply: y ≥ −1000 |
| T6 | Abyssal Steel | **map floor (−31000)** | Abyssal Rock and all deeper T6 | no T7 prerequisite |

Wood and Stone starter picks are not additional material tiers. They share the
T1 maximum of y = −100; Bronze is the best T1 pick.

The exact political boundary follows directly:

- **y = −700 belongs to the complete protected T4/shallow layer**;
- **y = −701 is the first node of the contested T5/T6 underground**;
- T5 is y = −701…−1000;
- T6 is y = −1001…−31000;
- there is no T7 below T6.

A T4 Silversteel pick reaches the last protected T4 node but not the first deep
contested node. Emberglass is obtainable within the T4 band, so the player can
craft the T5 Embersteel pick before entering y = −701. Abyssal Crystal is
obtainable in T5, so the T6 pick is equally non-circular.

### 2.3 What the natural-depth gate covers

The depth check applies to generated excavation material: natural stone/strata,
natural ore and gem nodes, and other generated ground nodes that could be used
to bypass a stone layer. A cave exposing a deep wall does not bypass the check;
the target y is authoritative.

If the pick is too shallow for the target y:

- digging is refused; the node is not damaged or removed;
- no tool wear or resource roll occurs;
- feedback states the required pick tier or maximum depth;
- another player's tunnel, a cavern, teleportation, or an exposed cliff does
  not waive the requirement.

The implementation should use a group/API classification for generated
mineable terrain rather than a list of names. It must not store metadata on
every natural node merely to remember that mapgen placed it. Natural stratum
nodes already drop ordinary building material rather than themselves; crafted
building/storage variants remain separate where needed.

### 2.4 Cosmetic rock is not a material gate

The six authored strata remain as visual depth language:

- Stone;
- Slate;
- Basalt;
- Granite;
- Emberrock;
- Abyssal Rock.

They are **cosmetic rock**, not ore, crystal, metal or alloy. Their depth bands
remain authored, but their node hardness does not express progression.

Material-review resolution:

- all six use ordinary stone-like pickaxe diggability;
- every real pickaxe, including Wood/Stone/Bronze, can break any of the six
  when the node is at a y the pick is allowed to mine;
- every cosmetic stratum is therefore breakable if encountered or placed near
  the surface, and none can become an indestructible PvP wall;
- higher-tier picks still dig ordinary rock faster through their explicitly
  authored `times`, not through `leveldiff`;
- natural strata continue to drop ordinary Cobble unless the later art/build
  specification deliberately adds separate decorative building variants.

An Abyssal Rock node at y = −1200 is blocked from a T3 pick by position, not by
its identity. The same appearance used as a crafted decorative block near the
surface is ordinary breakable building material.

### 2.5 Material-review resolution: minimum harvest tiers

Natural resource nodes remain destructible by a lower-tier pick if the position
is within that pick's natural-depth limit, but the drop is granted only when
the pick meets the resource's minimum harvest tier.

| Minimum pick tier | Natural resources |
|---|---|
| T1 | Copper, Tin, mined Coal, Iron, Quartz |
| T2 | Gold, Citrine, Garnet, Jade (all G1 gems) |
| T3 | Silver |
| T4 | Emberglass; Diamond, Sapphire and Ruby (all G2 gems) |
| T5 | Abyssal Crystal |
| T6 | no universal progression resource; T6 grants access and better density |

Why these assignments do not deadlock:

- Iron is harvested by T1 and makes the T2 pick.
- Quartz is a universal T1 jewelry mineral, so a starting Goldsmith can cut it
  and craft the confirmed T1 trinket identities without vendor or quest
  dependency.
- Silver is harvested by T3 and makes the T4 pick.
- Emberglass is harvested by T4 and makes the T5 pick.
- Abyssal Crystal is harvested by T5 and makes the T6 pick.
- all G2 gems require T4 to harvest, but no pick recipe consumes a G2 gem.
- concentrated contested cultural-material deposits use T4 harvesting, while
  their ordinary home-region surface sources retain their natural axe/shovel/
  hand-gathering behavior and are not converted into high-tier ores.

The minimum tier is a resource property, independent of host stratum and
political zone. A T4 Ruby node exposed in a surface ravine still needs a T4
pick for its drop; a T4 pick can harvest the same node at y = −650 but cannot
mine down to a copy at y = −800 because its depth check fails first.

### 2.6 Material-review resolution: under-tier destruction

When the position is accessible but the pick is below the resource's minimum
harvest tier, use the wielded pick's normal effective dig time multiplied by:

| Harvest-tier shortfall | Dig-time multiplier | Result |
|---:|---:|---|
| 1 tier | ×4 | node destroyed, no resource drop |
| 2 tiers | ×6 | node destroyed, no resource drop |
| 3 tiers | ×8 | node destroyed, no resource drop |
| 4+ tiers | ×10 cap | node destroyed, no resource drop |

One completed under-tier dig consumes one ordinary pick-use event; it does not
apply a second wear penalty. Bare hands and non-pick tools do not destroy ore or
gem nodes.

The no-drop outcome must never be silent:

- the node description/inspection text states `Requires a T<n> pick to
  harvest`;
- completion produces a dull fracture sound and a visibly failed/shattered
  particle cue rather than the normal pickup cue;
- a short rate-limited HUD/chat message names both the destroyed resource and
  the required tier, for example: `Ruby Ore shattered. A T4 pick is required
  to recover Ruby.`;
- a renewable socket still enters its ordinary depleted state and starts its
  refill timer, so an under-tier attempt cannot be repeated for free;
- no raw item, profession bonus yield, XP or quest harvest credit is granted.

This behavior allows deliberate denial in editable contested territory but
makes accidental loss slow and unmistakable.

### 2.7 Crafted storage and fantastic-material blocks

Crafted Copper/Tin/Iron/Steel/Gold/gem/fantastic-material blocks are storage or
building nodes, not natural resource nodes.

Material-review resolution:

- they have no minimum harvest tier and never use the no-drop rule;
- any real pickaxe can recover them at any depth when territory/claim
  permissions allow it;
- they always drop themselves; unpacking them into ingots/gems remains a craft
  operation rather than an ore-drop operation;
- they use a consistent, moderately slow building-block hardness and may not
  carry a `level` that turns them into tier-gated PvP walls;
- naturally generated full storage blocks are forbidden. Mapgen places ore/gem
  nodes, never a craftable nine-unit block;
- protection, not material value, determines whether another player may remove
  a placed block.

The same rule covers Emberglass, Embersteel, Abyssal Crystal, Abyssal Steel and
gem storage blocks. Their high value may justify distinctive sound/light/art,
but not intrinsic near-indestructibility.

**Confirmed regional-gem block rule:** Citrine, Garnet, Jade, Diamond,
Sapphire and Ruby each retain one reversible storage/luxury block:

- 9 Cut Gems craft one matching block, and the block unpacks to the same 9 Cut
  Gems;
- Rough Gems cannot be packed directly, preserving gem cutting as a visible
  Goldsmith contribution;
- packing and unpacking add no further profession gate once the Cut Gems exist;
- all six blocks use the ordinary non-gated building-node behavior above;
- they emit no actual light. Facet shine and species identity come from the
  16×16 texture, so decorative use does not create free illumination or reveal
  occupied structures through light spill.

### 2.8 Required `grug_materials` API revision

The public depth interface remains centralized, but its semantics change.
Nothing outside `grug_materials` may hardcode a depth boundary, harvest tier or
stratum node name.

Target API responsibilities:

- retain `TIERS`, `tier_at(y)` and `stratum_node_for(y)` for depth bands and
  cosmetic strata;
- replace the old `level_for_tier(tier)` gate with a depth-oriented lookup such
  as `max_depth_for_pick_tier(tier)`;
- expose a single `can_mine_natural_at(pick_tier, y)` predicate;
- expose resource classification/minimum harvest tier through a group-backed
  lookup rather than name lists;
- expose a harvest-result seam that grants the drop/profession bonus only after
  the minimum-tier check;
- expose enough structured failure information for one shared feedback path;
- keep protection/territory ownership outside this API, with callers applying
  protection before depth and harvest checks.

Exact function names are implementation design. The semantic separation is
binding.

### 2.9 WP25/WP26/WP29 consequences

WP25 remains valuable: its six depth bands, five new stratum nodes, stratum
placement order, cave-wall coverage, ore registrations, raw items and public
centralization all survive. The following WP25 work is superseded:

- `level` on cosmetic strata;
- ore `level = host band` as the harvest/access rule;
- `level_for_tier` as a public gate;
- all pick `maxlevel` overrides used to open strata;
- the compensation arithmetic that changed literal `uses`/`times` to cancel
  `leveldiff` side effects;
- Mese-as-Emberstone description overrides;
- comments/tests asserting that rock identity is the hard access gate;
- WP24 as the first `stratum_node_for` consumer, because private isles no
  longer exist.

`maxlevel` must no longer carry progression semantics. The implementation pass
must audit every shipped node with a non-zero `level` and every pick groupcap,
including vendored storage blocks and Obsidian. The target normalization is:

- remove `level` from all Grudgelands natural resources, cosmetic strata and
  crafted blocks involved in this system;
- set `groupcaps.cracky.maxlevel = 0` on every Grudgelands pick;
- normalize every remaining reachable vendored node with a non-zero `level` —
  including Obsidian and metal/gem storage blocks — so no unrelated default
  node silently preserves the retired gate;
- author effective `times` and `uses` directly, then verify them in a six-pick
  × six-strata table;
- do not inherit speed or durability from `time / leveldiff` or
  `uses × 3^leveldiff` anywhere in the target design.

This invalidates the current WP25/WP22 assumption that a pick is deliberately
least durable in its own stratum. Durability and speed must be designed
explicitly and tested independently from access.

WP26 must be recut before implementation:

- Steel moves to the dual furnace as Iron bar + mined Coal;
- Emberglass replaces Emberstone;
- Abyssal Steel replaces Grudgesteel as the T6 bar;
- the rare-trophy third input and the port work needed only for that input are
  removed;
- WP26 still owns the bar/furnace chain, pricing audit and missing processed
  material registrations, but not regional gem placement or the depth gate.

WP29/tool work must register the Iron, Silversteel, Embersteel and Abyssal Steel
picks with explicit tier metadata and depth limits. WP28 may remove the old
Mese/Diamond test picks only after the revised test path can reach every band.

---

## 3. Confirmed territory and underground access

### 3.1 Surface and shallow territory

- All level-1–30 zones are peaceful, faction-protected territory.
- Enemy players may not dig, place nodes or otherwise modify their terrain
  from the surface through y = −700, inclusive.
- Level-31–60 zones are contested. Outside bounded hard-protected functional
  POI anchors, housing claims and the Holy Grounds exception, both factions may
  dig, mine and place nodes. Ordinary roads, bridges, camp shells, ruins and
  battlefield dressing are mutable but remain claim-excluded; only a critical
  bridge/gate without an adequate alternate route receives hard protection.
- Permanent protected player building exists only through housing claims.
- Housing claims exist only in the ten authored level-11–30 housing zones: all
  six level-11–20 home zones plus Whitebridge Shire, Lorindor, Speargrass Reach
  and Whispering Reedlands at level 21–30. They protect a bounded
  surface/basement volume under `TODO-design-housing.md`.
- A housing claim never reaches or privatizes y = −701 and below.

Territory permission does not grant tool access. A player allowed to edit a
position still needs a pick that reaches its y and meets any resource harvest
tier.

### 3.2 Deep T5/T6 layer

- At y = −701 and below, the underground is contested regardless of which
  faction owns the surface.
- Both factions may mine, dig and place blocks there, subject to ordinary tool
  depth and resource harvest rules.
- This deep rule overrides every land-side faction, capital, POI, road and
  housing-claim terrain restriction. There are no protected land columns at
  T5/T6: beneath a capital or other protected surface structure, both factions
  have the same terrain rights as everywhere else in the deep layer.
- Players may cross beneath the central border and tunnel through the opposing
  faction's deep race-region columns to obtain its G2 gemstones and cultural
  deposits.
- Such a tunnel can theoretically pass below an enemy capital, but the distance
  should make it less attractive than the authored surface route. It still
  cannot break upward through the capital's protected shallow layer.
- The deep layer is PvP-contested and uses the normal depth-spawn system; it is
  not Nether space.
- **The sole geographic exception is deep ocean and an immutable dragon
  channel.** Authored bays, lakes, rivers and other planned water inside a
  mainland footprint remain part of their named zone and can never classify as
  deep ocean. The first 80 nodes outside the final analytic footprint perimeter
  are an editable coastal-water shelf inheriting the adjacent perimeter zone's
  policy. Beyond that begins full-column immutable deep ocean. Dragon-channel
  2D masks override shelf distance and are immutable at every y, so neither
  immutable class can be used for tunnels, bridges or seabed mines.

The geographic implementation must answer race-region lookup at depth from the
surface column so deep gem/cultural placement retains a cultural owner even
though territorial edit rights become contested.

### 3.3 Holy Grounds working exception

The narrow central land connection is the **Holy Grounds**, fixed at
x = −2500..+2500 and z = −250..+250. Its four-zone west/east chain is
Gravesalt Escarpment — The Broken Causeway — The Shattered Line — The Skyglass
Canopy, with nominal internal x edges −1500 / 0 / +1500. It is land rather
than ocean and may contain fixed authored inland lakes.

- PvP and NPC warfare occur there.
- Neither faction may dig or place nodes from the surface through y = −700,
  inclusive.
- Roads, fortifications and battlefield terrain are therefore reproducible and
  cannot be blocked, dismantled or bypassed by a shallow tunnel.
- At y = −701 and below, the ordinary contested deep-layer rule resumes.
- This deep opening is the principal underground route into opposing G2 and
  cultural-material territory.

The Holy Grounds is the explicit no-change exception to the otherwise editable
level-31–60 contested-zone rule.

### 3.4 Offshore dragon islands

The Wyrmglass Crown and Stormscale Summit become contested offshore islands at
the western and eastern ends of the Holy Grounds/front.

- their centres are fixed at (−3150, 0) and (+3150, 0), each within a 600×700
  authoring envelope;
- neither island touches a continental landmass;
- a short ocean channel of at least 200 nodes separates each from all mainland
  land and is comfortably crossable by boat;
- both factions receive equivalent boat access;
- the complete ocean corridor/column is immutable: no digging, placement,
  tunnels or player-built bridges;
- the islands cannot be connected to the continents by underground tunnels or
  bridges;
- the island interiors are contested PvP mining/boss destinations;
- each island contains exactly **two renewable nodes of each of the three G1
  and three G2 species**: 12 live gem nodes per island, 24 across both;
- the renewable sockets/pedestals remain protected against terrain editing so
  the node budget and respawn geometry cannot be dismantled;
- both islands provide the shared direct alternative to trade or invading an
  enemy deep race region for the foreign G2 species.

Material-review starting recommendation: each depleted dragon-island gem socket
refills independently after a randomized 2–4 hour interval, matching the
existing renewable-mining-node cadence. Runtime economy tests may change the
interval, not the confirmed two-live-nodes-per-species budget.

---

## 4. Regional gemstone economy

### 4.1 Gem taxonomy

There are six regional gemstone species in two grades:

- **G1:** Citrine, Garnet, Jade;
- **G2:** Diamond, Sapphire, Ruby.

`G1`/`G2` are design/internal grade terms, not player-facing replacements for
the material names and not universal mining tiers.

Terminology remains distinct:

- regional gems use `Rough <Gem>` → `Cut <Gem>`;
- Quartz is a universal ordinary mineral/crystal reagent;
- Emberglass and Abyssal Crystal are universal fantastic progression
  resources;
- no regional raw gem is named `<Gem> Crystal`.

### 4.2 Material-review resolution: race-region mapping

The earlier one-G1/one-G2 mapping is replaced. Sapphire is Accord-native, Ruby
is Throng-native, and Diamond exists on both sides. Each faction retains all
three G1 species in its own three race regions.

| Faction | Race region | G1 species | G2 species | Cultural material | Signature wood |
|---|---|---|---|---|---|
| Accord | Human | Citrine | Diamond | Sunwax | Oak |
| Accord | Dwarf | Garnet | Sapphire | Runeslate | Mountain Pine |
| Accord | Elf | Jade | Sapphire | Moonresin | Silverwood |
| Throng | Orc | Garnet | Diamond | Red Ochre | Spikethorn Acacia |
| Throng | Troll | Jade | Ruby | Spirit Resin | Kapok |
| Throng | Undead | Citrine | Ruby | Gravesalt | Gravewood |

This intentionally produces:

- Accord native supply: Citrine/Garnet/Jade + Diamond/Sapphire;
- Throng native supply: Citrine/Garnet/Jade + Diamond/Ruby;
- one Diamond region and two faction-native-exclusive G2 regions per faction;
- Ruby as Accord's foreign G2;
- Sapphire as Throng's foreign G2;
- equal missing-species pressure without aesthetic mirror symmetry.

No final zone coordinate is implied. WP40 must ensure at least one contested
31+ surface zone and a deep T5/T6 column supply each faction-native exclusive
G2 species.

### 4.3 Confirmed G1/G2 depth curves

G1 remains the upper/middle rare-gem family:

- it begins sparsely in the upper progression;
- its density rises through T4;
- T4 is its ordinary maximum-density band;
- T5 and ordinary T6 retain exactly the T4 G1 density;
- G1 rises again only through a shared deep-T6 resource multiplier.

G2 now participates in T4–T6:

- sparse in T4;
- clearly more common in T5;
- substantially more common in T6;
- available only as the species assigned to the current race-region column,
  except on the two all-six-gem dragon islands;
- minimum harvest tier T4 for all three species.

Material-review density targets for the first mapgen/runtime pass:

| Band | Relative G2 density | Approximate target per species in an eligible race-region host volume |
|---|---:|---:|
| T4, y = −501…−700 | 1× | about 1 ore per 12,000 host nodes |
| T5, y = −701…−1000 | 2× | about 1 ore per 6,000 host nodes |
| ordinary T6, y = −1001…−1499 | 4× | about 1 ore per 3,000 host nodes |

These are economy targets, not frozen `register_ore` literals. Cluster size,
air exposure and biome eligibility materially affect observed yield and must be
measured in generated maps before values become authoritative.

### 4.4 Confirmed ordinary T4–T6 recipe demand

All ordinary crafted combat gear at T4–T6 consumes a specific Cut G2 gem.
Pickaxes, shovels, axes, other gathering tools, bars, furnaces, repair and the
keystones needed to unlock mining access are excluded.

Use this three-tier rotation for non-trinket combat gear so every species
matters and no species permanently owns one combat role:

| Gear tier | Main-hand weapons | Four armor slots | Offhand |
|---|---|---|---|
| T4 | **Ruby** | **Diamond** | **Sapphire** |
| T5 | **Diamond** | **Sapphire** | **Ruby** |
| T6 | **Sapphire** | **Ruby** | **Diamond** |

One reference main hand, four armor pieces and one offhand through T4–T6
therefore consumes exactly **six Diamond, six Sapphire and six Ruby**. This
6/6/6 non-trinket spine is lifetime-balanced while retaining different timing
for Accord's foreign Ruby and Throng's foreign Sapphire.

**Trinket correction:** Sapphire and Ruby are the same G2 grade, not successive
vertical gemstone tiers. The former `T4 trinket = Sapphire / T5 = Ruby / T6 =
Diamond` rule is superseded. T4 exposes both Sapphire-authored and Ruby-authored
trinket recipes at the same time. Accord can source Sapphire natively and
Throng can source Ruby natively, but both factions immediately know the other
recipe family; acquiring the foreign gem is the gate, never recipe rarity,
reputation or a hidden unlock. T5 combines one Sapphire and one Ruby per
trinket; T6 combines one Diamond, one Sapphire and one Ruby. These costs are
specified in §6.3/§6.4 and add symmetrically to the 6/6/6 non-trinket baseline.

For a character who crafts two native-family T4 trinkets and two current
trinkets at T5 and T6, total T4–T6 G2 demand becomes:

| Faction | Diamond | Sapphire | Ruby | Foreign native-exclusive G2 |
|---|---:|---:|---:|---:|
| Accord | 8 | 12 | 10 | 10 Ruby |
| Throng | 8 | 10 | 12 | 10 Sapphire |

Choosing a foreign-family T4 special deliberately raises that character's
foreign demand, but the baseline strategic burden remains exactly equivalent.

Recipe rules:

- each one-handed weapon, armor piece or offhand consumes one Cut G2 gem from
  its table cell; trinkets use their explicit Goldsmith table;
- a two-handed weapon consumes its tier's weapon gem **and** its tier's
  offhand gem, preserving the resource demand of the displaced offhand;
- the G2 cost belongs to the base T4–T6 gear craft and is not charged again by
  ordinary refinement or ordinary affix application;
- the species required by an ordinary recipe grants no species-specific stat
  bonus. It is a material/crafting identity, not a second hidden faction perk;
- special/masterwork recipes may add a separate authored cost, but may not
  silently turn every upgrade step into another universal gem tax;
- dropped/vendor gear remains an alternate floor, so WP5/WP7/WP29 must audit
  high-tier supply rates rather than allowing found gear to erase crafted-gem
  demand.

This is intentional ordinary progression dependency, not part of the universal
pickaxe spine. A player can always craft the pick needed to reach the relevant
contested source before needing its foreign gem. A usable vendor/drop/previous-
tier equipment floor also remains available before the foreign gem is found;
that floor must be sufficient to contest the source without becoming so
generous that crafted G2 demand disappears. In particular, WP40 must provide a
practical contested T4 surface route to Ruby for Accord and Sapphire for
Throng; the level-60 dragon islands cannot be the first usable route.

### 4.5 Acquisition audit

The later map and recipe integrations must prove all of these routes:

| Supply route | Accord | Throng | Requirement |
|---|---|---|---|
| Native faction | Diamond + Sapphire | Diamond + Ruby | equivalent aggregate G2 density and travel |
| Enemy contested 31+ zones | Ruby | Sapphire | at least one practical T4 access route per missing species |
| Deep cross-border T5/T6 | Ruby below Throng columns | Sapphire below Accord columns | entry at y = −701 with a G2-free T5 pick |
| Dragon islands | all G1/G2 | all G1/G2 | two renewable nodes/species/island; equal boat route |
| Trade | all species | all species | valid alternative, never the only route |

Required audits replace the obsolete “equal one-race-signature-gem budget”:

- native-faction G1/G2 supply by generated volume and exposed-node yield;
- contested cross-faction supply and route length at T4, T5 and T6;
- dragon-island refill/yield including the Goldsmith bonus;
- one full T4–T6 reference gear set's 6/6/6 non-trinket G2 demand plus
  the separately confirmed symmetric trinket demand;
- two-handed recipe equivalence;
- high-tier drop/vendor substitution pressure;
- zero G2 demand in universal bar/pick recipes and their unlock keystones;
- equivalent strategic access for Accord and Throng, without requiring
  geometrically identical maps.

### 4.6 Deep-T6 resource pressure

There is no post-T6 material tier. Ordinary mobs remain capped at level 60;
depth below −1000 raises environmental/spawn pressure and resource yield.

Material-review resolution for the first calibration pass:

- y = −1001…−1499: normal T6 resource density;
- y = −1500…−1999: +25% to ordinary continental ores, G1, G2 and Abyssal
  Crystal;
- y ≤ −2000: +50% to the same set, capped;
- trophies, king loot, dragon-island sockets, housing/claim rewards and unique
  quest sources never receive the multiplier;
- the bonus must be implemented as a bounded placement budget, not a runtime
  respawn system.

This restores a reason to mine beyond the T6 entrance while the capped arrival
rate and deep environment pay for the yield. Runtime testing must still verify
that y ≤ −2000 is attractive but not the only rational mine.

---

## 5. Cultural resources and PvP counter recipes

### 5.1 Signature woods and cultural materials

Every race region has one signature wood and one additional cultural material,
as mapped in §4.2. Woods remain valid universal `group:wood` inputs. Their
exclusive value is settlement identity, furniture/build palettes and optional
cultural recipes, never mandatory tool progression.

The confirmed cultural materials retain these ordinary uses:

| Race | Material | Ordinary cultural/architectural uses | Contested acquisition form |
|---|---|---|---|
| Human | Sunwax | candles, seals, polish, gilded accents | wild waxcomb/apiary cache in Human 31+ ground |
| Dwarf | Runeslate | tablets, hearths, carved architectural inlay | mineable slate inscription seam |
| Elf | Moonresin | varnish, bows, luminous wood ornament | resin root/fossil-resin nodule |
| Orc | Red Ochre | pigment, adobe decoration, war paint | ochre clay/outcrop deposit |
| Troll | Spirit Resin | totem lacquer, incense, masks | resinous jungle root/amber nodule |
| Undead | Gravesalt | grave lights, urns, wards, bleaching, markers | gravesalt crust/crystal seam |

The extra material is not forced into every cultural object. A Gravewood chair
uses Gravewood; it does not consume Gravesalt merely to carry an Undead label.
These names are canonical for the later integration. The art spike validates
16×16 readability and production method rather than reopening the vocabulary
without a concrete visual failure. In particular, Moonresin uses a cool
silver-blue or pearlescent language, while Spirit Resin uses a warm amber or
toxic-green language so the two resin families cannot be confused.

### 5.2 Confirmed source and foreign-use rule

- Each culture has an ordinary home-region surface source sufficient for its
  own decorative, architectural, quest and trade needs.
- Each material also has at least one mineable/gatherable source in its race's
  contested level-31+ zones or contested deep column.
- The concentrated contested source is harvestable at T4 and yields more than
  the ordinary decorative source.
- Foreign cultural materials are used almost exclusively for optional
  level-40+ PvP recipes and target-race counter content.
- They never enter the universal metal/tool spine, ordinary T4–T6 G2 base cost,
  ordinary alchemy recovery ladder or any recipe required for solo leveling.
- Ordinary cultural, architectural, decorative, quest and trade uses remain
  valid for the culture that owns the material.

The G2 economy and the cultural-counter economy are distinct. Foreign G2 is an
intentional ingredient in ordinary high-tier gear; foreign cultural material
is an optional counter-build choice.

### 5.3 Material-review resolution: separate PvP-special channel

Target-race effects belong to a dedicated **PvP-special** per-stack channel.
They do not consume ordinary prefix/suffix slots and are not cultural finishes.

Reasons:

- a cultural finish expresses who made/decorated the item and grants a general
  build effect;
- a PvP special expresses what target the item was deliberately prepared to
  counter;
- merging the two would make an Elven-styled item the natural anti-Elf item,
  which reverses the fiction;
- consuming ordinary affixes would make the regional material compete with the
  basic enchant system rather than create a recognizable PvP choice.

Each item may carry at most one PvP special. It may coexist with a cultural
finish, but the combined six-slot/cap audit is mandatory.

### 5.4 Material-review resolution: MVP effect and stacking rules

Direct target-race damage is restricted to the equipped weapon:

- T4 counter weapon: **+1 flat damage** against the named target race;
- T5 counter weapon: **+2 flat damage**;
- T6 counter weapon: **+3 flat damage**;
- add the flat amount after the ordinary crit result but before armor and
  absorb, so it is mitigated normally and is not multiplied by Crit;
- only the currently equipped weapon contributes direct target-race damage;
- no percentage target-race damage ships in the MVP;
- the bonus applies to hostile players and combat-capable NPCs/mobs carrying
  the matching race identity, never to passive invulnerable service NPCs.

**Confirmed weapon-counter operation:** this is a permanent in-place
per-stack operation, not a coating buff, kit item or parallel registered
weapon. Its direct input and result are:

| Weapon tier | Target culture material | Target-race damage |
|---|---:|---:|
| T4 | 1 | +1 flat damage |
| T5 | 2 | +2 flat damage |
| T6 | 3 | +3 flat damage |

No additional bar, gem, signature wood or trophy is charged. The base weapon
has already paid its ordinary material recipe. A weapon carries at most one
PvP-special target; applying a different one overwrites the old target at full
new material and service cost with no refund. Applying the identical target
again is rejected as a no-op.

The profession that owns the base weapon family performs the operation,
regardless of the crafter's race. The operation therefore permits the intended
disrespectful use of a foreign cultural material without requiring a member of
the target culture. An allied passive profession-helper NPC provides the same
operation as the solo fallback for **50% of that tier's Common weapon vendor
price**. It consumes the same supplied material and follows the same tier and
stack rules; it neither supplies foreign material nor bypasses acquisition.

Other counter content follows bounded categories:

- at most one target-race potion/elixir category may be active; a new one
  replaces the old one rather than stacking;
- utility durations refresh but do not multiply;
- identical target-race specials never stack; where two legal sources could
  affect one action, use the highest value;
- a race-taunt trinket uses the trinket's one authored special slot. It does not
  gain an additional trinket channel;
- armor-wide target-race damage/resistance stacking is out of MVP scope;
- every race receives the same recipe-tier and effect-budget envelope, while
  the actual joke, gadget or utility may differ.

**Confirmed MVP recipe-family scope:** ship exactly two data-driven
target-race families:

1. the T4--T6 weapon counter finish defined above;
2. one T4--T6 **Warding Draught** family that reduces incoming damage from the
   selected target race and obeys the single-active-potion rule.

Humorous taunt trinkets, effigies and other race gadgets remain valid expansion
ideas but are outside the MVP. They receive no placeholder registrations,
recipes or materials merely to reserve the idea. Both shipped families are
parameterized by the six target cultures rather than implemented as six
different mechanics.

**Confirmed Warding Draught envelope:** each target culture uses the same
numbers and the corresponding culture's material.

| Draught tier | Incoming target-race damage | Cultural-material cost | Duration |
|---|---:|---:|---:|
| T4 | −5% | 1 | 5 minutes |
| T5 | −7.5% | 2 | 5 minutes |
| T6 | −10% | 3 | 5 minutes |

The draught uses the shared 60-second potion cooldown. Only one target-race
ward may be active; drinking another replaces the previous ward rather than
stacking or preserving its remaining time. It affects damage from hostile
players and combat-capable NPCs/mobs carrying the selected race identity, but
never creates interaction with passive invulnerable service NPCs. Apply the
multiplier after armor and before absorb in the central damage pipeline.
Apothecary Loop does not modify its percentage or duration because that
trinket affects only the restored amount of instant HP/Mana potions.

**Confirmed Warding Draught recipes and ownership:** use existing alchemy
ingredients rather than introduce a neutral ward-base item.

| Draught tier | Complete recipe |
|---|---|
| T4 | 1 Vial + 1 Dragonweed + 1 Marshbloom + 1 target culture material |
| T5 | 1 Vial + 1 Crimson Lotus + 1 Stormkelp + 2 target culture materials |
| T6 | 1 Vial + 2 Crimson Lotus + 2 Stormkelp + 3 target culture materials |

Player crafting is Alchemist-only at the matching book tier. An allied passive
Alchemist helper offers the same supplied-material recipe as the solo fallback
for 50% of the draught's later authoritative reference price; it does not sell
or create the target material. The ward is its own PvP-buff category and may
coexist with one ordinary elixir and Well Fed, while still sharing the global
60-second potion-use clock. Drinking it does not require missing HP or Mana.

These rules encourage scouting and race diversity without making one target
race categorically inferior. Population statistics must not be used to give a
currently common race a permanently stronger counter item.

### 5.5 Cultural finishing remains separate

Cultural finishing remains a per-stack modification of the universal base item
rather than a parallel registration catalog. It preserves material tier,
refinement and ordinary affixes.

The six ordinary combat slots are eligible: weapon, offhand, head, chest, legs
and feet. The two trinket slots remain excluded from cultural signatures.

Cultural finish effects stack normally across those six slots. A culture has a
coherent effect language, not one identical stat on every item: an Elven Sword
may grant Crit while an Elven Shield grants Dodge. A top-tier weapon at about
+5% Crit remains acceptable in principle.

**Confirmed effect architecture:** every culture has exactly one fixed,
deterministic signature effect for each eligible item family. The player does
not choose from a culture-specific random or selectable effect pool when
applying the finish. The resulting six-culture × six-family table is the
authoritative cultural-effect vocabulary: for example, an Elven weapon always
has the authored Elven weapon effect, while an Elven offhand always has its
different authored offhand effect. This keeps cultural gear recognizable,
avoids turning finishing into a second affix system and still permits a culture
to express more than one combat role.

The six families are weapon, offhand, head, chest, legs and feet. Trinkets
remain outside the cultural-finish matrix and retain their own one-prefix,
one-suffix, one-special model. Variants within a family may change visuals and
animation but not select a different cultural signature effect merely because
they are, for example, swords rather than hammers. Any genuinely necessary
family split must be approved as a later exception because it multiplies the
matrix and weakens immediate readability.

**Confirmed slot-budget shape:** cultural effects use normalized value points
with these T6 anchors:

| Eligible family | T6 value-point budget |
|---|---:|
| One- or two-handed weapon | 5 |
| Offhand | 4 |
| Chest | 3 |
| Legs | 3 |
| Head | 2 |
| Feet | 2 |

A value point is an effect-balancing unit, not an automatic `+1%` conversion;
each stat or utility needs an explicit equivalence. A two-handed weapon retains
the five-point weapon budget and does not absorb the unavailable offhand's four
points. Its ordinary base damage, cadence and ability tuning own that tradeoff.
Cultural finishing must not create a separate two-handed multiplier or a
second effect. This follows the existing general equipment tradeoff in which a
one-handed build has another equipped stack and therefore another affix source.

**Confirmed tier scaling:** multiply the appropriate T6 slot budget by the
following curve before converting value points into the authored effect:

| Material tier | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Share of T6 cultural budget | 20% | 35% | 50% | 65% | 80% | 100% |

This makes cultural identity mechanically present from T1 while reserving the
largest step for T6. For illustration only, a five-point T6 weapon effect whose
conversion is one Crit percentage point per value point becomes 1/1.75/2.5/
3.25/4/5% before display normalization. Each effect definition must choose a
player-readable precision appropriate to that stat and produce a strictly
increasing effective and displayed value at every tier. If ordinary rounding
would collapse adjacent tiers, the conversion quantum must change; a tier may
not silently pay for a finish with no upgrade.

**Confirmed MVP effect vocabulary:** every cultural-matrix cell grants exactly
one stat already owned by the central equipment/combat model. The available
vocabulary is Strength, Intelligence, Dexterity, maximum HP, maximum Mana,
Crit, Dodge and armor. Attack speed may appear only if the final cell and every
weapon type covered by it already have a correct central consumer; it is not a
reason to add a parallel cadence implementation. A cell does not bundle
multiple primary stats under an "all attributes" label.

**Confirmed value-point conversions:** after applying the slot budget and the
20/35/50/65/80/100% tier multiplier, convert each remaining value point as
follows:

| Cultural effect | Effect per value point |
|---|---:|
| Strength / Intelligence / Dexterity | +3 |
| Maximum HP | +6 |
| Maximum Mana | +10 |
| Crit / Dodge | +1 percentage point |
| Armor | +1 armor point (= 1 percentage point before the 60% cap) |

Primary attributes, HP and Mana round half up to whole numbers after scaling.
Crit, Dodge and armor display one decimal place when needed. These conversions
make every tier strictly stronger even on the two-point head/feet budget: a
two-point primary effect becomes +1/+2/+3/+4/+5/+6 across T1–T6, HP becomes
+2/+4/+6/+8/+10/+12, Mana becomes +4/+7/+10/+13/+16/+20 and a percentage
effect becomes +0.4/+0.7/+1.0/+1.3/+1.6/+2.0 points.

Cultural finishes add no new proc engine, periodic globalstep, regeneration,
life or mana steal, execute rule, crowd-control effect, cooldown reduction or
knockback resistance in the MVP. Such authored mechanics belong to trinket
specials, class/race abilities or a later expansion. A cultural stat may stack
with the same ordinary affix until the existing final-stat cap; the combined
cap audit remains mandatory and the description must show both sources.

**Confirmed role policy:** individual culture/family cells may intentionally
favor one class or combat role. A finish is not a smart stat and never changes
from Strength to Intelligence, or to any other effect, according to its wearer.
The exact fixed stat and value are always visible on the item. Some finishes
may consequently be unattractive to a particular class; this is acceptable
because cultural finishing is optional, finished items are tradeable and the
six slots may freely mix cultures.

No culture may be useful to only one role across its whole six-cell row, and
each faction's three cultures must collectively offer desirable damage, tank
and healing/caster choices. Accord and Throng need equivalent aggregate role
coverage, not matching per-race stat rows. The cap/demand audit must also prove
that every culture produces at least two economically desirable finish cells;
otherwise the nominal cultural market would collapse into one favored race.

**Confirmed cultural effect languages:** use this asymmetric identity frame
when authoring the individual cells:

| Faction | Culture | Mechanical language | Preferred existing stats |
|---|---|---|---|
| Accord | Human | discipline and versatility | mixed primaries, HP, Mana and armor |
| Accord | Dwarf | fortitude and physical staying power | HP, armor and Strength |
| Accord | Elf | precision and evasion | Crit, Dodge and Dexterity |
| Throng | Orc | ferocity and forward pressure | Strength, Crit and HP |
| Throng | Troll | vitality and instinct | HP, Dodge, Intelligence and Mana |
| Throng | Undead | occult concentration | Intelligence, Mana and Crit |

The preferred-stat column is a vocabulary guide, not a requirement to place
every listed stat or to mirror counts across factions. At faction level, Human
versatility supplies Accord's casting/support bridge beside Dwarf mitigation
and Elf precision. Troll vitality supplies Throng's survival/healing bridge
beside Orc physical pressure and Undead spell pressure. The result is
strategically equivalent role coverage without pairing Human/Undead,
Dwarf/Troll and Elf/Orc into matching rows.

#### Confirmed cultural-finish matrix (effect identities)

This table fixes effect identity only. Numeric conversions still apply the
slot budgets, tier curve and confirmed conversions above and remain subject to
the final cap audit.

| Culture | Weapon | Offhand | Head | Chest | Legs | Feet |
|---|---|---|---|---|---|---|
| Human | Strength | Intelligence | Mana | HP | Armor | Dexterity |
| Dwarf | HP | Armor | Strength | HP | Armor | Strength |
| Elf | Crit | Dodge | Crit | Dexterity | Dexterity | Dodge |
| Orc | Strength | HP | Crit | HP | Strength | Crit |
| Troll | Intelligence | Mana | HP | HP | Dodge | Dodge |
| Undead | Intelligence | Crit | Mana | Mana | Intelligence | Crit |

The Human row deliberately uses six different fixed stats. A complete Human
set is a broad generalist set rather than a best-in-slot specialization set;
its individual pieces are intended to be useful trade and mixed-build choices.
The Dwarf row deliberately weights HP and armor most heavily while retaining
Strength on two lighter armor slots. In particular, the fixed Dwarf weapon
identity is HP rather than weapon damage or a proc: a Dwarf-finished hammer is
the previously discussed life-granting hammer. Offhand armor still contributes
through the central aggregate armor calculation and its existing 60% cap.
The Elf row preserves the example anchors of weapon Crit and offhand Dodge,
then distributes the remaining cells so its T6 value-point totals are Crit 7,
Dodge 6 and Dexterity 6. This is an agile precision identity, not a six-slot
Crit stack.
The Orc row is a bruiser pattern with T6 value-point totals of Strength 8, HP 7
and Crit 4. Strength is its primary forward-pressure identity; Crit remains a
supporting accent rather than reproducing the Elf row, while HP differentiates
the Orc from a fragile burst profile.
The Troll row is a shamanic-vitality bridge with T6 value-point totals of
Intelligence 5, Mana 4, HP 5 and Dodge 5. Its resilience comes from existing HP
and Dodge stats rather than a new regeneration system; its casting/healing
identity is present but does not reproduce the Undead concentration profile.
The Undead row is an occult-concentration profile with T6 value-point totals of
Intelligence 8, Crit 6 and Mana 5. It is a stronger offensive-caster and mana
specialization than Troll, but deliberately receives neither Troll's HP nor
Dodge. Its Crit offhand is also a distinct trade choice beside Troll Mana and
Human Intelligence offhands.

The resulting T6 per-stack values are:

| Culture | Weapon | Offhand | Head | Chest | Legs | Feet |
|---|---|---|---|---|---|---|
| Human | +15 Str | +12 Int | +20 Mana | +18 HP | +3 armor | +6 Dex |
| Dwarf | +30 HP | +4 armor | +6 Str | +18 HP | +3 armor | +6 Str |
| Elf | +5% Crit | +4% Dodge | +2% Crit | +9 Dex | +9 Dex | +2% Dodge |
| Orc | +15 Str | +24 HP | +2% Crit | +18 HP | +9 Str | +2% Crit |
| Troll | +15 Int | +40 Mana | +12 HP | +18 HP | +3% Dodge | +2% Dodge |
| Undead | +15 Int | +4% Crit | +20 Mana | +30 Mana | +9 Int | +2% Crit |

#### Confirmed combined cap and overcap policy

All cultural finishes, ordinary affixes, attributes and base-equipment values
add normally. There is no highest-source-only rule and no same-stat exclusion
between a finish and an affix. The existing final caps remain unchanged:

- Crit: 30%;
- Dodge: 30%;
- armor: 60% physical reduction.

Values above a cap remain present on their source stacks but have no additional
combat effect. The Character page must expose both the effective capped value
and the raw overcap, for example `Armor 60% (67% raw)`, so a player can replace
wasted affixes or mix a different cultural finish deliberately. No automatic
reroll, overflow conversion, diminishing-return curve or cap increase is added.

The theoretical T6 cultural-only maxima across a freely mixed six-slot set are
approximately +14.8 Crit percentage points (13 direct plus 1.8 derived from
the compatible Dexterity cells), +9.9 Dodge percentage points and +7 armor
points. These are upper-bound mix builds, not full single-culture sets. At
level 60, base Crit and Dexterity mean the strongest mixed Crit set reaches the
cap after comparatively few ordinary Crit affixes; that is accepted
optimization pressure rather than a balance overflow.

Full T6 plate plus shield already approaches or reaches the 60% armor cap.
Dwarf offhand/leg armor therefore acts as a substitute source for lighter,
incomplete, lower-tier or two-handed configurations; it may be partly or fully
wasted on the canonical capped plate-and-shield loadout. This consequence is
accepted. Players may keep the full Dwarf appearance for identity or mix those
two slots for uncapped stats; the cap is not raised to make every theoretical
stack add effective power.

#### Confirmed production ownership and solo fallback

The normal player-production route is both culture- and profession-bound. A
character may directly apply its own culture's finish only through the
profession that owns the base item family: the relevant Blacksmith,
Leatherworker, Tailor or later explicitly assigned owner must also meet the
ordinary mastery/tier requirement. Trinkets are excluded and the Goldsmith
does not acquire cultural finishing merely because it handles gems.

Each culture also has a passive, invulnerable cultural-master service NPC. It
offers the same finish to allied players who supply the materials and pay a
substantial Gold premium; the customer does not need the owning profession.
This is the guaranteed low-population/solo fallback, not the economically
optimal route. The service follows the same tier gate, ingredients, output and
stack metadata as player production and may not create materials or bypass the
item's required level. The confirmed Gold premiums are the 50%-of-Common table
in §8.3, preserving a meaningful player-crafter discount.

An enemy cultural master refuses service. Foreign finishes must arrive as a
tradeable finished item, loot/PvP transfer or a separately approved later
route. Finished gear has no wearer-race or wearer-faction restriction: the
culture controls authorship and access, not whether a legitimately obtained
stack functions. Essential cultural-master service NPCs are passive and
invulnerable and therefore comply with the rule that no invulnerable NPC may
participate in combat.

#### Confirmed direct workstation inputs

Cultural finishing is an in-place workstation operation, not a normal crafting
grid recipe and not an intermediate-kit family. It validates and rewrites the
specific input stack transactionally so its base identity, refinement, quality,
ordinary affixes and unrelated per-stack metadata survive. This adds no finish
kit item IDs, kit textures or tiered kit recipes.

The operation consumes units of the race's cultural material according to the
finished item's tier and eligible family:

| Eligible family | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 1 | 2 | 3 | 4 | 4 | 5 |
| Offhand | 1 | 2 | 2 | 3 | 4 | 4 |
| Chest / legs | 1 | 2 | 2 | 2 | 3 | 3 |
| Head / feet | 1 | 1 | 1 | 2 | 2 | 2 |

Weapon and offhand operations also consume one unit of that culture's
signature wood as the grip, core or focus. Armor does not consume signature
wood merely to carry a cultural label. No G1/G2 gem, additional universal bar
or trophy is charged: the base T4–T6 item has already paid its ordinary G2 and
metal costs. The cultural-master NPC consumes the same physical inputs before
charging its separate Gold premium.

Player-owned profession workstations are permitted inside valid open-world
housing claims. This is a housing-stream requirement, not a housing-exclusive
material or progression gate: public capital/village stations and the NPC
fallback remain. Exact station placement, station ownership, friend-ACL use,
recipes and prices belong to the housing/profession integration rather than
this material decision.

#### Confirmed finish replacement

Applying a different culture's finish to an already finished eligible stack
overwrites the old cultural-finish metadata and appearance while preserving the
base item, tier, refinement, quality, durability, ordinary affixes and
PvP-special channel. The new operation consumes its complete normal material
cost and, for an NPC service, the complete Gold premium. It returns none of the
old culture material or signature wood. No remover/solvent item is added.

The workstation/NPC preview must show the old culture/effect, new
culture/effect and complete material/Gold cost before confirmation. Attempting
to apply the same culture already present is rejected as a no-op before any
input is consumed. This prevents accidental loss while keeping deliberate
respecialization possible and maintaining the material/Gold sink.

**Confirmed:** cultural finishes from different cultures may be mixed freely
across all six eligible slots. There is no one-culture set lock and no limit on
the number of represented cultures; ordinary stat caps and the per-slot effect
budgets are the balance mechanism.

The old fixed six ilvl-60 race-signature recipes must be replaced, not layered
under this scalable system.

---

## 6. Goldsmith, Gold, and trinkets

### 6.1 Confirmed Goldsmith identity

The Goldsmith owns:

- both trinket slots;
- Rough → Cut gem refinement;
- jewelry and ornament components;
- a bonus yield when successfully harvesting an actual natural or renewable
  gem node.

The bonus may only add yield of the species successfully harvested. It never
creates arbitrary gems from stone, converts one species into another, or fires
when an under-tier pick destroys a node without a drop. Dragon-island yield
audits include the bonus.

The Gem Detector is removed under §8.2; the profession remains substantial
through trinkets, gem cutting, jewelry components and its real-node yield bonus.

### 6.2 Material-review resolution: Gold and the Gold Block

Gold is a universal luxury/jewelry/build material, not one of the six tool
metals and not a housing-exclusive resource.

- Gold ore remains available on both faction sides and has minimum harvest T2.
- The physical Gold ingot and the abstract `grug_money` balance remain separate
  systems; claim purchases consume money through `grug_money`, not inventory
  Gold blocks.
- Gold becomes the primary Goldsmith chassis at T4 and continues as filigree in
  T5/T6 components.
- A Gold Block is a reversible storage/status/decor node (normally nine ingots),
  follows §2.7 building-block rules and may appear in prestigious housing art.
- No universal progression, claim upgrade or land purchase requires a physical
  Gold Block.

### 6.3 Confirmed jewelry component ladder

Use **Setting** consistently for the tiered Goldsmith component. This keeps the
component legible across rings, amulets, ornaments and other trinket forms.

| Tier | Jewelry frame/component | Gem use after the G2 revision |
|---|---|---|
| T1 | Tin Setting | one Cut Quartz per trinket |
| T2 | Iron Setting | G1 authored variants |
| T3 | Copper-inlaid Steel Setting | G1 authored variants |
| T4 | Gold Setting | one Sapphire for Manawell/Mercy Seal/Last Light; one Ruby for Battlebeat/Reclaimer's Mark/Apothecary Loop; all six learned immediately |
| T5 | Gold-filigreed Embersteel Setting | one Sapphire + one Ruby per trinket |
| T6 | Gold-filigreed Abyssal Steel Setting | one Diamond + one Sapphire + one Ruby per trinket |

Copper-inlaid Steel and the two filigree entries are Goldsmith components, not
new universal bars, storage blocks or tool materials. The shorter
`Coppersteel` alternative is rejected because it reads like a seventh
universal alloy.

### 6.3a Confirmed Goldsmith keystones

Goldsmith retains the same one-time book-group redemption model as the other
manufacturing professions. Its keystones deliberately avoid G2 gems: reaching
and acquiring Sapphire, Ruby and Diamond is the recipe-input challenge, not a
tax paid before those recipes become usable.

| Book group | One-time redemption requirement |
|---|---|
| T1 | opens with the profession; no keystone |
| T2 | 4 Iron Bars + 2 Cut Quartz |
| T3 | 3 Steel Bars + 1 Cut Citrine + 1 Cut Garnet + 1 Cut Jade |
| T4 | 4 Gold Bars + 2 Emberglass |
| T5 | 4 Gold Bars + 2 Embersteel Bars + 2 suitable level-41--50 zone mob drops |
| T6 | 4 Gold Bars + 2 Abyssal Steel Bars + 2 suitable level-51--60 elite drops |

The later creature/recipe integration must choose the concrete T5/T6 drop
itemstrings from useful existing regional loot and give Accord and Throng
equivalent acquisition time. It must not invent replacement materials merely
to fill these rows. Those drops are ordinary keystone evidence, not
`group:grug_rare_trophy`, Fallen Crowns or other masterwork trophies.

This row is non-circular:

- T1 Goldsmith already cuts Quartz before the T2 redemption;
- T2 Goldsmith cuts all three G1 species before the T3 redemption, and every
  faction can gather the complete trio in friendly race regions;
- T4 opens with universal Gold and Emberglass, then exposes all six
  Sapphire-/Ruby-authored recipes together;
- T5/T6 use their universal tier metals plus level-appropriate combat proof,
  never foreign G2, loose Abyssal Crystal or a king/rare trophy.

### 6.4 Confirmed trinket model

Each passive trinket has:

- exactly one prefix;
- exactly one suffix;
- exactly one authored trinket special;
- no cultural finish;
- no ordinary equipment special-variant channel in addition to its trinket
  special.

**Confirmed no-base/no-refinement rule:** a trinket has no separate base-stat
line, equipment armor, durability or refinement state. Material tier/item level
already scales its prefix, suffix and authored special; refinement may not add
a fourth line or multiply the special. Common/Uncommon/Rare presentation must
therefore be recut for this family: quality may communicate source and roll
window, but it never changes the fixed one-prefix/one-suffix/one-special
channel count. The registered-identity equip restriction is an equipment
`unique` rule, not a claim that every trinket uses a particular quality color.

**Confirmed affix-pool split:** the one prefix always rolls exactly one primary
attribute from Strength, Intelligence or Dexterity. The one suffix always rolls
exactly one secondary value from maximum HP, maximum Mana or Crit. This creates
nine possible pairs, makes a duplicate stat structurally impossible and keeps
armor, Dodge and attack speed out of the universal trinket family. Working
lexemes may reuse `Heavy`/`Clever`/`Quick` and `of the Ox`/`of the Owl`/
`of the Eagle`, but final words belong to the naming pass.

**Confirmed affix values:** trinket prefixes and suffixes reuse the ordinary
equipment affix ranges for item-level bands 1–15, 16–30, 31–45 and 46–60 and
the same source windows. Prefix and suffix roll independently inside the
applicable window. Material tier controls only the authored special's six-step
curve; it does not select a second trinket-only affix table. Quality/source may
narrow the roll window but may not add channels or multiply the special.

**Confirmed unique-item rule:** the same registered trinket item identity may
not occupy both trinket slots at once. Different trinkets remain freely
combinable.

**Confirmed same-special rule:** when two different legal trinket identities
carry the same non-PvP special, stacking is authored per special rather than
controlled by one global rule. Simple numeric effects such as passive Mana
regeneration may add across both slots up to an explicit two-slot cap. Proc,
protection and utility effects may instead use the highest value, independent
cooldowns or duration refresh where their mechanic requires it. Every special
definition and generated tooltip must state its two-slot behavior and cap; no
consumer may silently choose a default. This preserves useful gear combinations
without promising that every future bespoke mechanic stacks safely.

Trinket specials are effects unavailable from ordinary equipment, such as
passive mana regeneration. A race-targeted joke/taunt trinket is legal, but its
targeted effect occupies this one trinket-special slot and follows §5.4; it is
not a cultural signature and receives no fourth channel.

**Confirmed MVP pool size:** ordinary trinkets draw from exactly six core
special mechanics. A special may scale across several tiers and appear on more
than one registered trinket identity, subject to the unique-item and authored
same-special rules above. New continents, bosses or later phases may extend the
registry, but the MVP may not grow beyond six merely to make every trinket name
mechanically unique.

**Confirmed registration model:** register exactly six ordinary core trinket
identities, one per special. Each identity is craftable in T1–T6; material tier,
Setting, item level, required level, affix rolls, special strength, generated
display name and tier color are per-stack data. This produces six registered
item IDs and 36 generated workstation variants rather than 36 registrations.
All six specials remain available at every tier.

The same identity at different tiers is still the same unique registered item
and cannot occupy both slots. A later boss/quest trinket may be a distinct
registered identity carrying one of the same specials, at which point that
special's authored two-slot rule applies. Item form (ring, seal, token, locket,
loop or talisman) is presentation only; both equipment positions remain generic
trinket slots with no form restriction.

**Confirmed visual-form model:** the six core identities use three visual
families, two identities per family:

| Visual family | Core identities |
|---|---|
| Amulet | **Manawell Pendant**, **Last Light Locket** |
| Ring | **Battlebeat Band**, **Apothecary Loop** |
| Medallion/ornament | **Mercy Seal**, **Reclaimer's Mark** |

These are six distinct icons and registered identities, not three mechanical
subtypes. Either generic trinket slot accepts every form, and form grants no
stat, stacking rule or equip restriction. The 16×16 treatment should keep the
three silhouettes readable, give each pair distinct interior marks, and apply
the tier Setting/gem palette through shared layers or per-stack image
composition rather than register 36 items.

**Confirmed recipe simplicity:** ordinary core trinkets require only the
tier-appropriate Setting and the explicitly assigned Cut gem(s). They add no
special-specific catalyst item, trophy, herb, mob drop or cross-profession
component. The Goldsmith workstation resolves multiple outputs from the same
input family through an explicit identity choice.

- T1 uses Cut Quartz for all six identities.
- T2 and T3 assign two identities each to Citrine, Garnet and Jade: the working
  thematic pairing is Citrine for Manawell/Mercy Seal, Garnet for
  Battlebeat/Reclaimer's Mark and Jade for Last Light/Apothecary Loop.
- T4 assigns Manawell, Mercy Seal and Last Light to one Cut Sapphire each;
  Battlebeat, Reclaimer's Mark and Apothecary Loop use one Cut Ruby each. Both
  factions learn all six together; only gem acquisition differs.
- Every T5 identity consumes one Cut Sapphire plus one Cut Ruby.
- Every T6 identity consumes one Cut Diamond, one Cut Sapphire and one Cut
  Ruby.

Recipe knowledge is deliberately easy: the relevant Goldsmith mastery/tier
opens the complete tier list. There are no rare recipe-scroll drops, reputation
grinds or enemy-recipe unlock quests. Regional acquisition and trade/PvP are
the intended constraint.

**Confirmed six-special identity set:** the full item names and form families
above are fixed; these mechanics are fixed for the MVP:

1. **Manawell** — passive flat Mana regeneration. Two different Manawell
   trinkets add up to an explicit two-slot cap and piggyback the existing Mana
   regeneration tick.
2. **Battlebeat** — additional Rage on an accepted equipped-weapon hit. It
   applies only at the existing accepted-hit settlement seam; misses, dodge,
   full absorb and refused PvP grant nothing. Two legal identities add up to an
   explicit cap.
3. **Mercy Seal** — increased outgoing healing through the central heal path.
   Two legal identities add up to an explicit cap.
4. **Last Light** — after a survived hit leaves the wearer below its authored
   critical-HP threshold, grant an absorb through the existing absorb API.
   Different identities share one internal cooldown and only the highest
   equipped strength triggers.
5. **Reclaimer's Mark** — an XP-eligible kill restores a bounded amount of HP
   and the class resource (Mana or Rage). Gray/no-XP kills grant nothing;
   different identities share one cooldown and only the highest strength
   applies.
6. **Apothecary Loop** — increases the restored amount of instant healing and
   Mana potions without shortening or resetting their shared 60-second
   cooldown. Two legal identities add up to an explicit cap.

Direct damage procs, ability-cooldown reduction, movement speed, gathering
yield, durability and vendor bonuses are excluded from the six-special MVP.
They would either duplicate ordinary affixes, destabilize core cadence or turn
a combat trinket slot into mandatory travel/economy equipment.

**Confirmed special values:** use the following tier curves. Numeric healing
and potion percentages multiply the authored amount; they are not added as
percentage points to a percent-based potion.

| Special | T1 | T2 | T3 | T4 | T5 | T6 | Two-slot behavior |
|---|---:|---:|---:|---:|---:|---:|---|
| Manawell, flat Mana/s | 0.05 | 0.10 | 0.15 | 0.25 | 0.35 | 0.50 | additive, cap 1.00/s |
| Battlebeat, Rage/accepted hit | 0.25 | 0.50 | 0.75 | 1.00 | 1.50 | 2.00 | additive, cap 4 Rage/hit |
| Mercy Seal, outgoing healing | 1% | 2% | 3% | 4% | 5% | 6% | additive, cap 12% |
| Last Light, max-HP absorb | 3% | 4% | 5% | 6% | 8% | 10% | highest only, shared 120 s cooldown |
| Reclaimer's Mark, max HP/Mana | 1% | 1.5% | 2% | 2.5% | 3% | 4% | highest only, shared 10 s cooldown |
| Reclaimer's Mark, Rage | 1 | 2 | 3 | 4 | 5 | 6 | same trigger/cooldown as its HP restore |
| Apothecary Loop, potion amount | 2.5% | 5% | 7.5% | 10% | 12.5% | 15% | additive, cap 30% |

Last Light triggers only after a survived hit leaves the wearer below 25% of
maximum HP; it does not retroactively prevent a lethal hit. Its absorb uses the
post-hit maximum-HP value and the existing central absorb API. Reclaimer's Mark
restores HP plus maximum-Mana percentage for Mage/Priest, or HP plus the listed
flat Rage for Warrior. Its XP-eligible-kill test and cooldown settle before any
restore, preventing gray-mob or multi-callback farming. Battlebeat may retain
fractional Rage internally; the normal resource HUD remains the display owner.

---

## 7. Kings, trophies, and masterwork loot

### 7.1 Confirmed encounter facts relevant to materials

- There are six race kings, not one singular Faction King.
- Each is a killable level-65 elite NPC protected by four level-60 elite
  guards.
- Essential service NPCs are separate, passive and invulnerable.
- An invulnerable NPC is always passive and never participates in combat.
- `world_zones.md` §12 owns the decided king-authoritative guard follow,
  leash/teleport, group reset, death cleanup and persistent 15-minute group
  respawn. This material staging file owns only the loot budget below.

### 7.2 Material-review resolution: Fallen Crown

**Fallen Crown remains the shared king-trophy concept.** Use one canonical
registered item with per-stack race provenance and cultural overlay/name rather
than six mechanically different trophy currencies.

Loot/economy rules:

- every eligible, unlocked participant receives exactly one Crown; all kings
  use the same quantity, vendor-value budget and eligibility rules;
- king rewards are personal encounter loot, never a shared Crown item on the
  ground. Every qualifying participant gets an independent Crown entitlement
  with the defeated king's race provenance; the killing blow has no special
  ownership;
- the current-attempt participation ledger accepts enemy-faction players who
  deal accepted damage to the king or a royal guard, or provide effective
  healing or shielding to an eligible participating attacker. Qualifying
  living participants must be within 60 nodes at the kill; a participating
  player slain by the encounter, another encounter NPC or an enemy player
  keeps eligibility for 60 seconds. Proximity without ledger contribution is
  insufficient, and a full reset clears the ledger and death grace;
- guard loot is ordinary level-60 elite loot and never substitutes for the
  crown;
- a Fallen Crown is accepted in the existing trophy slot of an ordinary
  Master-tier masterwork, including a T6 Grudgeforged item;
- it substitutes for a qualifying named-rare trophy; it is not consumed in
  addition to one;
- a crown grants the same stat/affix budget and quality window as another
  qualifying trophy, with race-specific royal ornamentation as its distinction;
- no universal bar, pickaxe, profession keystone or ordinary base-gear recipe
  requires a crown;
- no power-bearing recipe is crown-only. Named-rare and other qualifying boss
  trophies remain valid and more broadly available masterwork sources;
- each king has its own rolling 24-hour wall-clock Crown lockout per character.
  Its successful award starts only that king's timer; repeat kills are allowed
  but give no additional Crown from that king, while the other two enemy kings
  remain independently rewarding. All six kings remain economically
  equivalent.

This keeps king raids prestigious without making repetitive king killing the
only rational path to the masterwork ceiling.

---

## 8. Confirmed removal of housing-island and guild material branches

### 8.1 Housing isles and guilds are deleted from the target design

The following are final decisions, not open alternatives:

- private housing isles are removed completely;
- the island allocation grid, styles, skirts, reef/safe rings, teleport pads,
  island waypoints and no-mount island rules are removed;
- purchased housing depth rights and their approximately 1.9g ladder are
  removed;
- deterministic island treasure clusters and all six island-only materials are
  removed;
- no replacement materials are invented merely to preserve deleted island
  content;
- the guild system is removed completely: no registry, manager, roles, bank,
  purses, transaction log, terminals, `/g` chat or 5g founding sink;
- housing friend ACLs replace the housing-access function;
- open-world claim expansion and additional claims replace the old housing and
  guild Gold sinks;
- farming/housing access and Home Stone consequences move to the housing/travel
  stream.

Permanent player protection now exists only through claims in the ten authored
level-11–30 housing zones defined by `TODO-design-housing.md`. Exact claim
geometry, prices, reclaim policy and ACL UI are housing decisions rather than
material decisions.

### 8.2 Material-review resolution: deleted finder/amplifier items

- **Amplifier:** remove it from the MVP and target material design. Its only
  justified source was an island-exclusive branch that no longer exists, and
  multiplying all affix values by 10% creates cap work without serving the new
  world. Do not relocate it merely to preserve sunk design. A later boss/raid
  package may re-propose the effect on its own merits.
- **Dowsing Rod:** remove it. With no island clusters, it has no job; turning
  continental mining into direction/radar gameplay would weaken exploration.
- **Gem Detector:** remove it rather than invent a non-radar nameplate role.
  Goldsmith already owns trinkets, cutting, components and bonus yield.
- **Six island-exclusive materials:** remove the entire planned node/item/
  texture/recipe branch. None has shipped, so this avoids material inflation
  and discarded mapgen work.

### 8.3 Material-review resolution: Abyssal Crystal after island removal

Abyssal Crystal is continental and available to both factions in their own T5
underground before a T6 pick is required.

The old starting placement, `clust_scarcity = 20^3` with two ores, averages
about one crystal per 4,000 host nodes and assumed a separate safe island
payout. With that payout deleted and every T6 bar depending on the crystal,
start the new calibration at approximately **one crystal per 2,048 eligible
host nodes** across T5 and T6 — equivalent in raw density to a scatter starting
point around `16^3`, two ores, size two.

Requirements:

- the entry band y = −701…−1000 alone must support crafting an Abyssal Steel
  pick without T6 access;
- the resource continues through T6 and receives §4.6's deep multipliers;
- no housing, king, dragon-gem socket or required PvP route is its sole source;
- both faction sides receive equivalent base density;
- runtime tests measure exposed yield and time-to-one-pick/full-gear-set before
  freezing mapgen literals.

### 8.4 Cap and economy calculations to rerun

Remove old calculations based on:

- Amplifier ×1.10 affix multiplication;
- eight ordinary enchantable gear slots using the same affix model (trinkets
  now use 1 prefix + 1 suffix + one trinket special);
- one non-stacking cultural signature or six fixed ilvl-60 signature recipes;
- Grudgesteel bars consuming a rare trophy;
- a singular Faction King/Fallen Crown source;
- island depth prices, treasure payouts and guild founding;
- island-safe Abyssal Crystal supply;
- Quartz/Garnet/Diamond as the complete universal gem ladder;
- every Fine recipe consuming a generic gem reagent;
- `maxlevel`/`leveldiff` providing pick speed and durability progression.

Add audits for:

- six stacking cultural-finish slots;
- at most one PvP-special per item with direct counter damage weapon-only;
- two trinket specials and their identical-effect rules;
- T4–T6 non-trinket G2 6/6/6 reference-set demand plus the final symmetric
  trinket demand;
- crown versus named-rare trophy supply;
- claim expansion/additional-claim Gold sinks;
- revised explicit pick `times` and `uses`;
- doubled starting Abyssal Crystal density and deep-T6 multipliers.

#### Confirmed economy-rebase handoff (2026-08-11)

The old Common-vendor weapon curve of 50c→269c and 25% vendor buy-back is
superseded. The new ordinary-money axis uses these binding anchors:

- an unenchanted T1 Common vendor weapon costs **25c**;
- an unenchanted T6 Common vendor weapon costs **25s** (2,500c);
- the confirmed clean Common-weapon ladder is **25c / 65c / 1s60c / 4s /
  10s / 25s** for T1–T6. Its steps approximate the exact
  `100^(1/5) ≈ 2.512` ratio while keeping player-facing prices clean;
- enchanted/quality gear costs more than the Common baseline; its exact
  multipliers still require the economy/loot pass;
- vendor buy-back for an item is capped at **5% of its applicable purchase or
  reference price, rounded up to the next copper**: 25c therefore returns 2c,
  and 25s returns 1s25c;
- ordinary quest income and the expected vendor value of level-appropriate
  NPC/mob loot must grow on the same approximate ×2.5 tier index so ordinary
  gear does not become less attainable merely because its displayed number is
  larger.

Preserve the existing slot relationships, rounded to clean 5c increments where
needed:

| Common vendor slot | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 25c | 65c | 1s60c | 4s | 10s | 25s |
| Chest (about 80% of weapon) | 20c | 50c | 1s30c | 3s20c | 8s | 20s |
| Offhand/head/legs/feet (about 50%) | 15c | 35c | 80c | 2s | 5s | 12s50c |

Money is ledger-only universal transaction currency through `grug_money`. No
NPC, mob or world node drops money or a physical coin item. Currency enters or
moves only through explicit transactions such as quest rewards, NPC purchases
of sellable loot, NPC/player sales and player-to-player trade. Consequently,
"loot income scales by tier" means its expected vendor value scales; it never
means adding direct coin drops to a mob table.

Scaling both ordinary prices and ordinary income by the same index preserves
time-to-buy; that is intentional for baseline gear. It does not by itself make
late mounts or other aspirational sinks harder. Those must use increasing
multiples of the current tier's expected income/time budget.

The cultural-master NPC fee remains **50% of the revised unenchanted Common
vendor price for the matching tier and slot**, rounded up to a clean price.
The resulting confirmed table is:

| Cultural-master service | T1 | T2 | T3 | T4 | T5 | T6 |
|---|---:|---:|---:|---:|---:|---:|
| Weapon | 15c | 35c | 80c | 2s | 5s | 12s50c |
| Chest | 10c | 25c | 65c | 1s60c | 4s | 10s |
| Offhand/head/legs/feet | 10c | 20c | 40c | 1s | 2s50c | 6s25c |

The ordinary same-race vendor discount does not apply to this
profession-replacement service.

---

## 9. Art direction and asset scope

### 9.1 Confirmed hybrid source strategy

Use a hybrid process:

- reuse or derive mundane bases and tree palettes from licence-cleared
  reference media;
- adapt VoxeLibre's proven per-stack trim/meta technique;
- author six Grudgelands cultural motifs and the fantastic-material language;
- use reference assets only with exact provenance, author, licence, pinned
  upstream commit and modification notes in the owning `LICENSE-media.md`;
- run a small art spike before bulk production.

Useful local references already identified:

- Lord of the Test `lottother`: ore/stony/uncut/cut/ring gem families;
- Lord of the Test `lottarmor`: Elf/Dwarf inventory and worn-armor motifs;
- Lord of the Test `lottores`: Silver, ingot, crystal and salt material art;
- VoxeLibre `mcl_armor`: ItemMeta trim pipeline and overlay masks;
- minetest_game: existing mundane wood, Gold and base-material palettes.

### 9.2 Updated asset budget

The regional gem target needs six coherent families, each with at least:

- one natural ore overlay/node appearance;
- one Rough Gem inventory item;
- one Cut Gem inventory item;
- one crafted Cut-Gem storage block.

That is exactly 24 gem-family node/item roles before cultural equipment
overlays: six natural nodes, six Rough items, six Cut items and six storage
blocks. Existing Diamond and WP25 Garnet concepts reduce net-new artwork but
still need naming/namespace/style reconciliation; all six block textures must
read as polished luxury mosaics without emitted light.

The six cultural materials need one inventory identity and at least one source
node/harvest presentation each. The six signature woods need full tree/build
palettes only where existing upstream woods cannot carry the culture cleanly.

Deleting the island branch saves six exclusive material identities plus their
nodes/items/textures and the Amplifier/Dowsing/Gem-Detector art.

### 9.3 Art spike

Before full production, review:

1. one full gem family: eligible host-rock overlay, Rough Gem, Cut Gem, storage
   block and a Goldsmith trinket;
2. Emberglass → Embersteel raw/bar/block language;
3. one armor base with two cultural trims and one PvP-special marker treatment;
4. one cultural material in both ordinary architectural use and a disrespectful
   counter-recipe presentation;
5. the complete sheet at native 16×16 and nearest-neighbor enlargement.

AI generation is useful for concepts and variants, not as an unchecked final
16×16 output. Final assets require limited palettes, hard edges and manual
pixel-cluster inspection.

---

## 10. Obsolete assumptions in the existing TODO files

### 10.1 `TODO-design-depth.md`

Retain A1/A2/A4's depth-level and spawn-pressure principles, subject to the new
territorial deep layer. Reconcile or remove:

- **B6:** retain “renewable nodes only in mining camps.” The protected sockets
  on both dragon islands belong to the two special all-six-gem apex mining
  camps; they extend camp content but do not create a second renewable
  structure kind. World-wide ore respawn remains removed.
- **C7:** retain continental pre-T6 Abyssal Crystal access, but remove every
  statement treating an isle as its safe source; replace the old density with
  §8.3's starting target.
- **C8:** delete the entire island-rock/treasure-cluster decision.
- **C9:** delete all six island-exclusive materials and the Amplifier.
- **D10:** remove island comparisons; the contested continental T6 environment,
  no separate deep gear-drop layer and ordinary level-60 cap remain.
- **Status/implementation:** remove WP24 ownership of depth materials and recut
  WP34 around continental/deep/dragon supply.

After integration, the old file should contain only genuinely unresolved depth
spawn content or be deleted if those questions move to a narrower TODO.

### 10.2 `TODO-design-housing.md`

The former private-island questions were replaced on 2026-08-12 by the
claim-focused `TODO-design-housing.md`. Its stable-ID state machine, ten
level-11–30 zones, geometry, ACL, Home Stone, decay/reissue and world-mutability
contracts are the binding housing handoff. General ocean and dragon-channel
art remains in the world stream, and playable boat access to the two dragon
islands remains a separate travel requirement. Delete the housing TODO only
after those decided rules are folded into authoritative docs.

### 10.3 `TODO-design-crafting-rework.md`

Reconcile these exact areas:

- **Map handoff:** replace six one-to-one race-signature gem slots and “no
  enemy material in base progression” with §4.2's
  `race_region -> {G1, G2, cultural material, signature wood}` mapping and the
  five-route supply audit.
- **A1:** replace fixed race-signature recipes with scalable cultural finishing
  plus the separate optional PvP-special recipes.
- **A4:** remove “T6 behind a housing purchase,” Grudgesteel/trophy-bar and
  Quartz→Garnet→Diamond Goldsmith assumptions; author keystones without a
  foreign-G2 or Abyssal double gate.
- **B7:** rock names/bands/art survive; `level`, `maxlevel`, isle-generator
  consumer and engine-hard-refusal reasoning do not.
- **B8:** replace ore `level = host band`, the old gem-band ladder and island
  supply with minimum harvest tiers, new G1/G2 curves and non-circular depth
  checks. The lead-material anti-circularity principle survives.
- **B9:** delete the housing-isle `open_sea_at` exception. World/map work must
  instead protect the complete dragon-island ocean channels from building and
  tunneling.
- **B22:** retain the need for a six-pick speed table, but discard all
  `leveldiff`-derived speed/durability arithmetic and author effective values
  directly.
- **C11:** retain MVP trinkets and Goldsmith ownership; remove the Gem Detector
  as a profession pillar.
- **Mount/isle references:** remove the retired no-mount isle and allocation
  assumptions; preserve only rules re-derived for claims, immutable ocean and
  the dragon-island boat routes.

---

## 11. Decisions and remaining work owned outside the material stream

These do not block WP26's universal furnace/bar work. The map/housing owner has
resolved the entries identified below; the material integration agent must
consume those contracts rather than reopen them.

### 11.1 Map/world planning

- `docs/design/world_zones.md` now fixes the complete coast profiles, Holy
  Grounds rectangle, two island envelopes, channel/flight bands, paired boat
  approaches, land/boat graphs and the 32-seed route-parity audits;
- it also fixes planned-footprint/zone-water masks, the exterior 80-node shelf,
  full-depth deep ocean and all ten authored housing zones;
- land-side capitals, functional POI anchors and irreplaceable route structures
  share the shallow y = −700 hard-protection floor, with exact x/z bounds from
  the authored registry; ordinary road/camp envelopes remain 2D claim
  exclusions and mapgen grading inputs, not mutation protection;
- only deep-arrival placement geometry and the final deep-servant roster remain
  in the independent depth-content stream.

### 11.2 Housing/travel planning

- `TODO-design-housing.md` now fixes claim dimensions, four-tier upgrade
  ladder, maximum reservation and spacing, stable IDs, ACL, recovery,
  dormancy/decay/reissue, claim-bound Home Stone and claim farming;
- claim expansion uses the decided 4/8/12 Silversteel/Embersteel/Abyssal-Steel
  bar costs plus 30m/90m/3h of measured T4/T5/T6 reliable net solo income;
  additional stones require level 60, every existing stone at tier IV and
  escalating 12/24 Abyssal Steel plus 5h/10h T6 income;
- only the calibrated ledger amounts and measured per-faction live-Stone
  limits remain implementation outputs rather than design choices;
- playable boat ownership, acquisition, speed, damage/destruction and respawn
  still require a travel contract before the dragon encounter loop ships.

### 11.3 Encounter planning

- king/guard loot implementation. Guaranteed personal allocation, 60-node
  living radius, 60-second combat-death grace, reset cleanup, per-king 24-hour
  lockouts, participation sources and equal king budgets are decided;
  king/guard AI, leash, respawn and capital-raid eligibility are decided in
  `world_zones.md` §12;
- dragon AI, hoard and encounter reset behavior. Its participation bounds and
  cleanup match the kings. World respawn is decided: a
  persistent 30-minute base timer, full 60-second lair warning before the
  actual spawn, unload-safe delayed warning, and no temporary invulnerability.
  The two dragons have separate per-character 24-hour boss-loot lockouts, and
  their islands remain contested throughout every boss state.

### 11.4 Economy and mount planning

- set enchanted/quality purchase multipliers on top of the Common curve;
- rebase quest rewards and expected sellable-loot yield to the same
  approximately ×2.5-per-tier monetary index;
- preserve ledger-only currency with no NPC/mob/physical-coin drops; tiered
  loot income is realized through its vendor value;
- price the level-15, level-30, level-45 and level-60 mounts as meaningful
  purchases measured in reliable tier-appropriate **net solo earning time**:
  approximately **15 minutes / 45 minutes / 2 hours / 5 hours** respectively;
- measure those targets after routine repairs and consumables, without rare
  jackpots or a functioning player market. The level-15 land mount is readily
  achievable, difficulty rises at each milestone, and the fast level-60 flying
  mount is a real farming goal without becoming a dragging time wall;
- derive the nominal Gold prices only after the new per-tier net-income rates
  are measured. The old 1s/8s/30s/60s price table is superseded and must not be
  carried forward merely because its ratios already exist.

---

## 12. Remaining material questions

No remaining structural material choice currently needs owner approval. The
following values require a later focused runtime calibration rather than an
owner choice now:

1. Runtime-calibrate G1/G2 ore exposure, the dragon-node 2–4 hour refill and
   the proposed deep-T6 +25%/+50% resource multipliers.
2. Runtime-calibrate the explicit six-pick dig-speed/durability matrix and the
   ×4/×6/×8/×10 under-tier destruction times.

The following are material-review resolutions rather than remaining structural
questions: exact pick depths, y = −701 deep boundary, minimum harvest tiers,
G2 race mapping, separate PvP-special channel, removal of
Amplifier/Dowsing/Gem Detector, continental Abyssal starting density and Fallen
Crown masterwork parity.

Owner confirmations added 2026-08-11: Human **Sunwax**, the consistent
**Setting** ladder with **Copper-inlaid Steel Setting**, unique-item trinkets,
unrestricted mixing of cultural finishes, and the lifetime-balanced T4–T6
non-trinket G2 slot rotation of §4.4. Cultural signatures use one fixed deterministic effect
per culture and eligible item family; they are not selectable mini-affix pools,
and trinkets are excluded. Their T6 slot budgets are weapon 5, offhand 4,
chest/legs 3 each and head/feet 2 each; two-handed weapons receive no offhand
budget compensation. T1–T6 cultural power scales at
20/35/50/65/80/100% of those anchors. The MVP matrix uses one existing central
combat stat per cell and adds no bespoke cultural combat mechanics.
Individual cells may favor particular roles, use no class-adaptive smart stats
and must remain explicit on the stack; each faction collectively covers damage,
tanking and healing/casting. The six cultural effect languages are fixed by
§5.5. All six cultural slot rows and their numeric value-point conversions are
confirmed. Existing 30% Crit, 30% Dodge and 60% armor caps remain final; all
sources stack before the cap and visible overcap has no combat effect. Cultural
finishes are applied directly in place at a workstation with the confirmed
tier/slot material table, add no kit items, and use one signature-wood unit
only for weapons/offhands. Private profession workstations are allowed inside
valid open-world housing claims; their housing rules remain out of this stream.
The cultural-master service fee is 50% of the revised matching Common vendor
slot price; the resulting absolute six-tier table is fixed in §8.3.
The economy rebase uses 25c/25s T1/T6 Common-weapon anchors, approximately
×2.5 per tier and a 5%-ceiling buy-back. Its exact Common-weapon ladder is
25c/65c/1s60c/4s/10s/25s, and the derived cultural-master service remains 50%
of the matching Common slot price. Currency remains ledger-only: enemies drop
sellable loot, never money or physical coins. Mount prices at levels
15/30/45/60 target 15m/45m/2h/5h of reliable net solo income respectively;
fair aspiration, not dragging, is the pacing rule.
Sapphire and Ruby are equal-grade G2 species: all six T4 trinket recipes are
learned together, three consume one Sapphire and three consume one Ruby. Every
T5 trinket consumes one Sapphire plus one Ruby; every T6 trinket consumes one
Diamond, one Sapphire and one Ruby. Recipe knowledge is deliberately easy and
material acquisition carries the faction/travel challenge.
Quartz is a T1-harvest universal jewelry mineral so T1 Goldsmith progression
is self-sufficient. The Goldsmith's T2--T6 keystone row is fixed by §6.3a:
universal materials and level-appropriate ordinary mob drops gate the book,
while G2 gems, loose Abyssal Crystal and masterwork trophies do not.
The six core trinkets use the three cosmetic form families in §6.4--amulet,
ring and medallion/ornament--without mechanical form types or slot rules.
All six cultural material names in §5.1 are confirmed. Moonresin and Spirit
Resin remain separate families with deliberately contrasting palettes; the art
spike validates execution rather than choosing their names.
All six regional gems retain reversible 9-Cut-Gem storage/luxury blocks. These
blocks use ordinary building-node behavior, emit no light and never participate
in natural-resource harvest or depth gating.
The MVP target-race recipe scope is fixed to permanent weapon counter finishes
and Warding Draughts. Both use the 1/2/3 target-material cost curve at
T4/T5/T6; the weapon grants +1/+2/+3 flat damage and the five-minute draught
grants 5/7.5/10% mitigation. §5.4 owns the overwrite, stacking, Alchemist
ingredients and allied profession-helper fallback rules. Taunt gadgets are
post-MVP ideas and receive no placeholder content.

---

## 13. Final integration handoff

### 13.1 Authoritative design documents

The later integration agent must reconcile these in one coordinated pass:

- `docs/design/items_crafting.md` — material/bar names, furnace recipes, depth
  and harvesting rules, G1/G2 recipes, Goldsmith/trinkets, cultural/PvP
  specials, loot/masterworks, Amplifier/finder removal and price tables;
- `docs/design/professions.md` — Goldsmith inputs/outputs, real-node bonus and
  Gem Detector removal;
- `docs/design/world.md` — protection rules, y = −701 contested deep layer,
  Holy Grounds exception, offshore dragons, housing-isle deletion, claims,
  renewable nodes, Abyssal source and king material rewards;
- `docs/design/world_zones.md` — Holy Grounds working term, dragon islands,
  homestead areas, territory/depth columns, region mapping and all supply/route
  audits;
- `docs/design/biomes_mobs.md` — signature woods, cultural sources, region
  resource budgets, deep-T6 density/spawn relationship and dragon-node palette;
- `docs/design/inventory_equipment.md` — cultural-finish, PvP-special and
  trinket channel separation;
- `docs/design/combat_stats.md` — target-race flat-damage placement, caps and
  deep-boundary references;
- `docs/design/economy.md` — delete island/guild sinks, add claim sinks, revise
  raw/cut gem, Gold, Abyssal and trophy economics;
- `docs/design/guilds.md` — delete after all surviving cross-references are
  removed;
- `docs/design/progression.md` — housing unlock/claim progression and removal of
  isle milestones;
- `docs/design/story.md` — remove king-granted isles, retain six kings with the
  revised encounter/service distinction and update housing fiction;
- `docs/design/mounts.md` — remove isle rules and re-derive immutable-ocean/
  dragon-island travel constraints;
- `docs/design/README.md` — update the design-doc catalog after the above edits.

Then reconcile/delete the open-design layer:

- `TODO-design-depth.md` as specified in §10.1;
- `TODO-design-housing.md` as specified in §10.2;
- `TODO-design-crafting-rework.md` as specified in §10.3;
- delete this staging document only after every decided rule has an
  authoritative home and all unresolved questions have moved to a focused
  TODO.

### 13.2 Repository/process documents

After the authoritative specs agree:

- `AGENTS.md` — replace the `maxlevel` material contract and stale housing/
  guild quick-reference assumptions;
- `VENDOR.md` — revise the inventory/rationale for Mese/Emberglass, pick and
  default-node overrides; preserve exact patch provenance;
- `BACKLOG.md` — recut/cancel affected WPs below;
- `ROADMAP.md` — remove guild/isle milestones and update material/housing/world
  milestones;
- `README.md` — update the design tour and Current State only after the
  authoritative and WP status changes are complete.

### 13.3 Work-package reconciliation

| WP | Required handoff change |
|---|---|
| WP5 | Remove Amplifier support; implement/cap cultural and PvP-special metadata plus revised crown/masterwork rules; retune high-tier gear drops against G2 demand. |
| WP6 | Audit race identity on combat-capable NPCs/mobs for counter effects and the six king trophy hook; encounter AI remains elsewhere. |
| WP7 | Rebase ordinary Common gear and expected income around 25c→25s weapons and approximately ×2.5 per tier; cap buy-back at 5%; derive the 50% cultural-master service table; reprice gems/Abyssal/Gold/trophies, replace island/guild sinks with claim sinks and audit high-tier vendor gear substitution. |
| WP8 | Replace island-grant quest consequences with the claim unlock and six-king story hooks where applicable. |
| WP10 | Recut Goldsmith, trinkets, gem cutting, G1/G2 recipes, keystones and optional cultural/PvP recipes; remove Gem Detector. |
| WP13 | Move the two all-six-gem renewable budgets to dragon-island structures; update six king/guard material loot budgets; remove isle/guild terminals. |
| WP16 | Cancel/remove the guild WP completely. |
| WP17 | Remove island waypoints and rework Home Stone/travel around housing claims and dragon-island boat access. |
| WP21 | Reconcile innkeeper Home Stone rebinding with claim ownership. |
| WP22 | Delete `leveldiff`-based durability assumptions and author explicit six-pick wear targets. |
| WP23 | Move Wyrmglass Crown/Stormscale Summit to offshore islands and own their equivalent gem sockets/boat access with WP40; boss loot remains equivalent. |
| WP24 | Rewrite from housing-isle generation into open-world homestead claims, expansion, ACLs and additional-claim Gold sinks. |
| WP25 | Retrofit the shipped material mod to depth/harvest gates, clean Emberglass namespace, six G1/G2 families and revised APIs; preserve useful strata/mapgen work. |
| WP26 | Implement only the corrected two-input alloy chain and processed materials; Steel uses mined Coal, T6 is Abyssal Steel with no trophy. |
| WP27 | Add the T4–T6 G2 costs and cultural visual seams to armor base recipes without parallel catalogs. |
| WP28 | Re-audit all vendored `level` nodes and remove Mese/Diamond test tools only after revised depth test tools exist. |
| WP29 | Rename Grudgesteel gear to Abyssal Steel, provide the complete pick tier metadata/depth limits and preserve per-stack finish/special seams. |
| WP30 | Audit trader rotations/catalog names and high-tier gear availability against intentional G2 demand; no new material system. |
| WP31 | Remove housing-isle mount/open-sea assumptions, respect immutable dragon-island ocean channels and derive the level-15/30/45/60 mount prices from 15m/45m/2h/5h reliable net solo-income targets; the fast level-60 flying mount is a fair farming goal, not a dragging wall. |
| WP32 | Move farming from private isles to the decided housing-claim model without adding island materials. |
| WP33 | Place ordinary cultural surface sources if this remains the gathering-node owner, or split them into a dedicated cultural-resource WP. |
| WP34 | Recut depth economy for revised Abyssal density, G1/G2 deep multipliers, deep contested access and protected renewable dragon sockets; keep ordinary depth spawns. |
| WP40 | Own Holy Grounds geometry, the exception-free land-side T5/T6 territory projection, shallow protected volumes, coastal shelf versus full-depth immutable deep ocean, offshore dragon islands, homestead areas and every supply/route/capacity audit. |
| WP41 | Apply PvP eligibility to contested deep space and Holy Grounds while respecting no-change terrain; integrate target-race counter effects into the PvP seam. |
| WP42 | Re-anchor war-front activity to the Holy Grounds/offshore-front map without assuming editable battlefield terrain. |

WP26 may begin only after the universal material names/recipes and the WP25 API
retrofit boundary are specified authoritatively. Regional gem placement,
cultural finishes, PvP counter recipes, trinkets, housing claims, dragons and
kings should not be silently bundled into WP26.

### 13.4 Recommended integration order

1. Fold the universal material and mining-access rules (§§1–2) and recut
   WP25/WP26/WP22/WP28/WP29.
2. Fold territorial/deep/Holy Grounds/dragon decisions (§3) into world and zone
   specs with WP40/WP41 ownership.
3. Fold the race-region mapping, G2 recipe rotation and supply audits (§4).
4. Fold cultural/PvP channel rules (§5) and Goldsmith/trinket/Gold rules (§6).
5. Fold king trophy/masterwork rules (§7).
6. Remove every island/guild material, sink, detector and cross-reference (§8),
   then rewrite WP16/WP24 and the housing/travel dependencies.
7. Re-run cap/economy/route/art budgets and resolve the open material questions.
8. Reconcile the three older TODO files, BACKLOG, ROADMAP, design index and
   README; only then delete this staging file.

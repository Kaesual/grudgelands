# Round 31 — Dragon arenas: proposal and what was built (lanes DA, DA2)

Lane DA wrote the proposal (§1–§6 below, 2026-10-03). The user then
redesigned the arenas (`round31-plan.md` §6 item 11); lane DA2 built that
design. **§0 is what the game does now**; the proposal stays below as the
record of the reasoning (its option list is superseded by §0).

## 0. Built (lane DA2)

### 0.1 Size: radius 40

The arena is a round floor of **radius 40** (82 × 82 protected square).
*Why:* the edge is the leash, so the arena must hold the whole fight: ranged
players reach 20–25 nodes and must be able to stand clear of the dive (radius
7) and the 12-node breath range while the dragon is near the centre; 40 also
replaces the former 64-node drag leash with something visible. Bigger does
not fit the islands: the apex camp lies 134 nodes from each dragon (its
fitting reaches 44 from its centre), the sea at least 113 (seeds 42 and
1234), and the arena's collar adds up to 28 beyond the floor's edge, so a
radius above about 60 would meet the camp; within radius 40 the natural
relief is already −53..+21 nodes on the checked seeds.

### 0.2 Mapgen

- `source/simple_map.lua`: the `dragon` profile gets `building_core_width`
  82, `arena_radius` 40 and `bowl_core_width` 32; catalog rows 87/88 are 82
  wide and carry no props.
- `height.lua`: a dragon fitting samples its reference (the lower median)
  over the round floor only and grades a round floor: level within 4 nodes
  of the spawn, swelling gently 0–2 nodes below the reference over about 36
  nodes, its edge wandering 0–3 nodes beyond the radius (a noise), then the
  usual POI collar (6–28 nodes) from that edge. Never rough: floor heights
  stay within −2..0 of the anchor on both arenas and both seeds.
- `terrain_field.lua`: the calm bowl keeps the former 32-node size
  (`bowl_core_width`). *Why:* with the 82-node core the bowl grew and
  flattened the island far beyond the arena (up to 100 nodes of change
  beyond radius 100 in a first run); now terrain beyond radius 72 is
  unchanged (at most 3 nodes) and the islands stay untamed, no paths.
- `r20_poi_blueprint.lua`: the dragon blueprint keeps the local ground: only
  the spawn stone under the dragon (the anchor's required solid support),
  the spawn's air and four high air cells that make its bounds the whole
  82-node square, which the world protection reads.
- `arena_layout.lua` (pure, shared with grug_mobs and the fixture) and
  `arena_writer.lua` (the last pass of the R7 successor, after the
  settlements): the hazards follow the floor's height. Rim stones (stone on
  Wyrmglass, mossy cobble on Stormscale; about one in five ring columns, a
  third of them two high) mark the radius. Hazard nodes are registered in
  `world_nodes.lua`, tinted default textures, not diggable.

### 0.3 The arena is the leash (`grug_mobs/boss_dragons.lua`, `dragon_arena.lua`)

- Inside = within the radius horizontally and from 10 below to 24 above the
  spawn floor (the protected box plus a player's height). A hostile player
  inside is a target at any height or distance (this is the proposal's height
  fix); one outside is vetoed at acquisition (`_grug_target_veto`, a new hook
  in the `init.lua` acquisition veto) and dropped as a target.
- A punch, shot or ability from a player outside is cancelled in `do_punch`
  (dragon and whelps), so nobody can hurt the dragon without being
  targetable. A hit from inside engages it.
- Once a second an engaged dragon counts hostile living players inside; at
  zero it resets: the ordinary encounter reset (`leash_reset`: threat, loot
  tag, `boss_leash_reset` with whelps, enrage and participation, full
  health), then it flies to 6 above its spawn and lands. A re-pull is a fresh
  attempt. Stepping out and back in only gives the dragon its health back.
  Dragons now carry `_grug_no_leash` (no drag or contact leash), and the
  evade run skips no-leash actors. Its flight stays 4 nodes inside the edge.
- The Round 30 pathing rule is unchanged (dragons never give up, they only
  wait); the arena rule is what ends a fight.

### 0.4 Hazards

| Arena | Hazard | Rule |
|---|---|---|
| Wyrmglass | breaking ice | 7 patches of thin ice flush with the floor; a player standing 1.5 s on one node breaks it and its four neighbours into ice water (1 deep); it freezes again 20 s after nobody stands in it |
| Wyrmglass | ice water | 250 damage per second, slowed (0.6, refreshed while inside) |
| Wyrmglass | frost terraces | 3 flat frost-stone terraces, 1 and 2 nodes high, opaque blue-grey (the ice is pale and translucent) |
| Stormscale | ember fissures | 6 jagged fissures, 1–2 wide, 1 deep, glowing, basalt rim; 350 damage per second, no slow |
| Stormscale | fallen trunks | 5 jungle trunks, 1 node high, 7–8 long; players jump over, the wyvern walks over |

Damage goes through `set_hp` with a node-damage reason once a second (the
dragon scorch's path): armour does not reduce it, it is never PvP contact,
the absorb shield soaks it. Ice water deaths get their own death message.
No ice pillars and no cover, as ruled. No hazard within 9 of the spawn, 4.6
of a perch or 4 of the edge (fixture).

### 0.5 Protection

The whole 82 × 82 square is the dragon's POI core (y 10 below to 22 above
the anchor), measured in the engine: `poi` at ±40, nothing at +41. The
dragon's breath patches stay possible there, as before.

### 0.6 Checks

- `tools/r31_da2/portable_test.lua` (7407 checks): layout, rules, and the
  real `boss_dragons.lua` on a fake engine (high player targeted, outside
  player vetoed and harmless, one reset when the last hostile leaves with
  full health and cleared enrage, the flight home and landing, a clean
  re-pull, 250/350 per second through set_hp, the slow, ice breaking).
- `tools/run_fixtures.sh`: all 56 pass (`tools/r24_density_xp/roster.lua`'s
  stub now maps `grug_mapgen` for the arena layout file).
- Engine: headless boots on seeds 42 and 1234 (about 1 min each) with a
  probe that dumped both arenas; arena floor −2..0, hazards and rim stones
  present, protection as above. A live fight needs a GUI client (the dragon
  only acts in an active block): see the user test below.

### 0.7 User GUI test

1. Each arena: round, on local ground, rim stones visible at the edge.
2. Pull the dragon, step outside the rim: it stops attacking, heals and
   flies back to its spawn; shooting it from outside does nothing.
3. Stand on a frost terrace or high ground inside: the dragon still attacks.
4. Wyrmglass: stand still on thin ice (breaks, ice water hurts and slows,
   refreezes); Stormscale: step into an ember fissure (350/s), jump a trunk.

# Proposal (lane DA, superseded by §0)

## 1. How the pictures were made

Two isolated headless boots (`tools/luanti_headless.sh`, seeds 42 and 1234,
about one minute each) with a disposable probe mod that emerged only the two
arena areas: per arena ±96 nodes in x/z (y from the arena floor −24 to +110),
read the generated nodes through a VoxelManip (per column the top node and
the top ground node) and the analytic terrain height `grug_zones.terrain_height_at`
over ±128. The probe also logged the POI protection box
(`grug_core.world_feature_at`) and the dragon spawn/perch heights. An offline
Python renderer draws a top-down height/material map (contours every 4 nodes)
and an isometric cut-away from those dumps. Real and analytic heights agree
within one node (a snow layer) on more than 99.7 % of the dumped columns (the
rest are overhangs and caves). The hazard
sketches edit a copy of the seed-42 column grid and use the same renderer, so
they show the real surroundings of that seed. The probe and renderer are
scratch tools, not committed.

## 2. Today's shape

**Anchors** (`source/simple_map.lua`, `bosses.lua`): Wyrmglass Ice Dragon at
(−3260, −40), Stormscale Jungle Wyvern at (+3260, −40). POI kind `dragon`,
shape `arena_terrace`: building core 32, fitting 96, blend 160.

**Core** (`r20_poi_blueprint.lua`, catalog entries 87/88): a flat 32 × 32
floor at the lower median of the natural ground (seed 42: Wyrmglass y 326,
Stormscale y 222; seed 1234: 306 and 256), air to +12 above it, and a few
props: Wyrmglass three 5-high stone-brick rock teeth, a ruin, marks and a
slab "hoard"; Stormscale two mossy-cobble rock teeth, an altar with a candle,
a fallen tree and marks. The floor is the race palette's ground: Wyrmglass
(dwarf palette) gets **coniferous-litter dirt — a brown forest-floor square in
a snowfield**; Stormscale gets rainforest litter. Both arenas lie above the
tree line (y 220), so no trees stand around them.

**Surroundings** vary by seed (the blueprint does not): on seed 42 Wyrmglass
sits on a ledge that drops 60–90 nodes to the north-east within 64 nodes and
rises up to +44 to the south; on seed 1234 it sits on a broad, gentle snow
summit. Stormscale on seed 42 sits on a summit shelf with clay gullies falling
to the south-west and east; on seed 1234 on a grassy slope with a cliff to
the west.

**Protection** (probe): the core box is exactly x/z −16..+15 around the anchor
and y −10..+22 relative to the floor (blueprint height 12 + 10). The fitting
ring (up to ±48) and the blend are **not** protected; on the dragon islands
both factions may dig and place there (`world.md` R2b).

### 2.1 How the dragon fights there today (code reading, `boss_dragons.lua`, `bosses.lua`)

- **Spawn and rest:** spawns on the anchor; idle, it walks every 15 s in a
  straight line (no pathfinding) to the next of three perches (0,0), (18,8),
  (−15,12); a blocked walk ends in a rest in place. Perch 2 lies 2 nodes
  outside the core, in the unprotected collar.
- **Ground mode:** with a target within 12 nodes horizontally and in line of
  sight (eye height 5 ice / 4 wyvern), a 1.25 s wind-up, then three breath
  bolts in a ±15° fan (speed 22, 2 s life, so about 44 nodes of reach,
  1.5 × damage) that leave rime (slow, 8 s) or scorch (2 damage/s, 6 s)
  patches. Cooldown 6 s. The wyvern alternates breath with **lightning**: a
  ring of radius 2 on the target's spot, 1.5 s wind-up, 2 × damage.
- **Air mode:** a target beyond 12 nodes or out of sight makes it take off
  and fly (8 nodes/s) to 6 above the target; within 18 nodes it **dives**
  (1 s warning, 18 nodes/s, ends on a collision or within 2.5 of the marked
  spot, 3 × damage in radius 7 plus knockback); within 9 it lands.
- **Gust** every 12 s: radius 5, knockback 7, slow. **Enrage** at 50 %:
  cooldowns × 0.7 and two whelps.
- **Targets:** view 48, leash 64, and a **vertical tolerance of 8**: a player
  more than 8 nodes above or below the dragon is not a valid target.
- **Give-up rule (Round 30):** flying actors (`keep_flying`, the dragons and
  whelps) never give a target up; their pathing only waits. So no pathing
  failure resets the boss.
- **Where players stand:** melee at the feet (dragon reach 6, so melee eats
  breath fan and gust); ranged (scout 25, mage 20) beyond 12 nodes trigger
  take-off and dives; healers (15–20, pointing at the ally) need sight of the
  tank. On the flat floor only the few props block sight.

### 2.2 Finding: the height exploit (exists today)

Because of the vertical tolerance, a player whose feet are 9 or more nodes
above the dragon's floor is ignored, even while shooting it (the idle regen
needs 30 quiet seconds, which the damage prevents). The top-down maps mark
such ground within 25 nodes of the core: on seed 42 two patches beside the
Stormscale core and a strip south-east of Wyrmglass; on seed 1234 almost
none. Independently of the seed, a player can **build a tower in the ring**
(R2b allows it). Any height hazard must stay below +8, and the cheap
general fix is option A (§5).

## 3. Design rules every concept follows

*Why:* each rule removes one way to strand the dragon or to make a player
unreachable.

1. **Everything inside the 32-node core.** It is protected for everyone
   already (box y −10..+22), so no new protection is needed and nobody can
   dig a hazard away.
2. **Tops at most +6, pits at most 1 deep.** A player on a pillar, or the
   dragon in a pit, stays within the 8-node tolerance.
3. **Gaps narrower than the dragon** (box 6 ice, 4.8 wyvern): fissures and
   pits are 1–2 wide, so the dragon walks over them and never falls in.
4. **Off the perch walking lines** (at least 4.6 nodes, the dragon's half
   width plus margin) and at least 6 nodes from the spawn; the blueprint's
   central clearance (±2, y 1..3) stays air. A blocked perch walk would only
   make it rest in place, but the arena should not look broken.
5. **Spawn and perches stay at floor level.** `dragon_pos` uses the analytic
   terrain height, not the blueprint's, so a raised hazard under a perch
   would spawn the dragon inside it.
6. No fire, no flowing liquids, no terrain damage outside the core (the
   terrain-damage guard rule).

## 4. Concepts

Effort: S = blueprint data and existing nodes; M = new nodes and/or boss code
with a fixture; L = new systems. Main files: `wp40/r20_poi_catalog.lua`
(props of anchors 87/88), `wp40/r20_poi_blueprint.lua` (prop kinds, ground),
`grug_mobs/boss_dragons.lua`/`bosses.lua` (nodes, AI, perches), generated
textures with `LICENSE-media.md` rows, `tools/r31_da/` fixture.

### Wyrmglass (ice)

**E1 — Ice-crystal pillars (cover).** Six 2 × 2 crystal clusters with jagged
tops 3–6 high, on a loose ring at 7–14 nodes from the centre, replacing the
rock teeth.
- Melee: little change; gust knockback stops at a pillar instead of
  scattering the group.
- Ranged: a pillar between them and the dragon blocks the breath (it needs
  sight), but the dragon then takes off and dives; a dive that hits the
  pillar ends there (radius 7 still counts). Shooting needs sight too, so
  ranged step out to shoot and back to dodge.
- Healers: pillars block pointing at allies; they must keep the tank in view.
- AI: no change; straight flight slides along a pillar; the existing dive
  ends on collision. Climbing players stay within 8.
- Effort **S**: catalog props plus one `crystal` prop kind with `default:ice`;
  optionally an own glowing crystal node (S+, one node, one texture).

**E2 — Frost fault terraces (height steps).** The south and east of the core
rise in two levels, +2 and +4, with 2-node edges trimmed in ice and four
1-node ramps; spawn and both core perches stay on level 0.
- Melee: the tank holds the dragon on the low floor; reaching a ranged player
  needs a ramp.
- Ranged/healers: overview from the terraces, mostly still inside 12 nodes,
  so they still get breath; standing back from an edge hides them from a dragon
  below (the plan shows the breath shadow), which turns breath into dives.
  Knockback can drop players 2–4 nodes (little or no fall damage).
- AI: stepheight 1.1 walks the ramps and 1-node steps; at a 2-node edge the
  walk blocks and the dragon breathes or takes off. Relief 4 < 8.
- Effort **M**: the blueprint must place raised ground cells for the
  dragon kind (a height pattern instead of flat), and a fixture checks that
  spawn and perches stay at level 0. On seeds where the ring is flat, the
  south core edge becomes a 4-node step to the ring.

**E3 — Thin ice (collapsing floor).** Four patches (25–35 nodes each) of thin
ice flush with the floor over 1-deep icy water. A player standing still on it
for about 2 s, or a dive or landing within 4 nodes, cracks it; the water
slows and chills (about 1 damage/s); it refreezes after about 20 s.
- Melee: the tank drags the dragon off the patches before dives land.
- Ranged/healers: cast while standing still, so they must stand off the ice;
  free space shrinks during the dive phases.
- Healers: extra, predictable damage on whoever falls in.
- AI: dragon water damage 0, no fall damage, 1 deep keeps it within 8; whelps
  climb out.
- Effort **M**: two new nodes (thin ice, icy water) with textures, the crack
  and refreeze timers, a check in the existing 0.25 s effect step and a hook
  at dive/landing, a fixture. Server-side edits inside the core are not
  blocked by protection.

**E4 — Floor that fits the island.** Packed snow with ice, gravel and stone
patches instead of the forest-litter dirt. No fight change; it removes the
"plain brown square". Effort **S** (a ground override for the dragon kind in
the blueprint palette). Combines with any of E1–E3.

### Stormscale (jungle, storm, volcanic)

**S1 — Ember fissures.** Four jagged cracks, 1–2 wide and 6–11 long, one node
deep, glowing (an own ember node, damage per second, light, not a liquid, not
flammable) with a basalt rim; none within 6 nodes of the spawn.
- Melee: gust (7) and dive knockback can throw players into a crack, so the
  tank turns the dragon to keep the group's backs off the cracks.
- Ranged/healers: the cracks split the floor into lanes; moving to dodge a
  lightning ring needs care.
- Healers: burst damage on knocked players.
- AI: cracks narrower than the wyvern, which walks over them (lava damage 0);
  whelps are immune.
- Effort **S–M**: one node and texture, a `fissure` prop kind; no AI code.
  No lava, so no flow, bucket or cooling interplay.

**S2 — Ruined columns and fallen giant trunks (cover).** Four mossy 2 × 2
columns (2–6 high) and three fallen trunks (2 high, 2 wide, about 8 long).
- Like E1, but the low trunks only block breath from 4 or more nodes away,
  and lightning also needs sight to start, so cover stops both; the wyvern
  answers with dives.
- AI: trunks block the walk (2 high), the wyvern flies instead; all cover off
  the perch lines.
- Effort **S**: existing nodes (`default:jungletree`, `default:mossycobble`),
  one larger `log` prop kind.

**S3 — Storm totems (lightning rods).** Four wooden totems with copper tips,
5 high. A lightning strike aimed within 5 nodes of a totem jumps to it: the
ring lands at the totem's foot instead.
- Ranged/healers: standing 3–5 nodes from a totem is safe from lightning
  (closer than 2 is not); melee unchanged.
- It turns the wyvern's signature attack into something the group can play.
- AI: no pathing change; 1 × 1 totems off the perch lines.
- Effort **M**: about ten lines in `begin_lightning` (`core.find_node_near`),
  one node and texture, a prop kind, a fixture for the redirect choice.

## 5. For both arenas

**A — Height fix (recommended).** A player more than 8 above the dragon makes
it take off instead of being ignored (the tolerance then applies only to
starting the ground breath; flight already steers to 6 above the target).
Closes §2.2 for cliffs and player towers alike. Effort **S** (a few lines in
`boss_dragons.lua`, fixture); the 64 leash and 48 view bound the chase.

**B — Protect the fitting ring.** Not needed for any concept above (all stay
in the core). It would only matter against towers in the ring, which A fixes
more cheaply. Cost if wanted: **M**, since the box's y range must follow the
ring's terrain (up to 90 nodes of relief on seed 42) rather than the
blueprint, plus the gameplay cost of a 96 × 96 no-build area on each island.
Recommendation: no; instead move perch 2 from (18,8) into the core (for
example (12,8)), effort S.

## 6. Recommendation and effort

| Option | Arena | Effort | Wave 2 fit |
|---|---|---|---|
| E1 crystal pillars | Wyrmglass | S | yes |
| E2 fault terraces | Wyrmglass | M | borderline |
| E3 thin ice | Wyrmglass | M | borderline |
| E4 fitting floor | Wyrmglass | S | yes |
| S1 ember fissures | Stormscale | S–M | yes |
| S2 ruined cover | Stormscale | S | yes |
| S3 storm totems | Stormscale | M | borderline |
| A height fix | both | S | yes |
| B ring protection | both | M | not recommended |

Coordinator suggestion: **Wyrmglass E1 + E4, Stormscale S1 + S3, plus A**
(and perch 2 into the core). Together about one small-to-medium lane: two
prop kinds, two nodes, the totem redirect and the height fix, each with a
fixture and one engine check of both arenas.

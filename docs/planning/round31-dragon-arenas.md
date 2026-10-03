# Round 31 — Dragon arenas: design proposal (lane DA)

Lane DA, 2026-10-03. Status: **proposal, waiting for the user's choice**
(round plan §2.3/§2.4). Nothing here is decided; nothing in the game changes
until the user picks options. The pictures are on the lane's preview page
(`~/projects/grudgelands-orchestration/r31/previews/da/index.html`, outside
the repository); this document carries the reasoning.

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

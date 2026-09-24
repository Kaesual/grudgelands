# Round 20 playtest checklist

Prepared 2026-09-24. This is a user-run acceptance plan, not a runtime result.
Use a fresh test world for the new authored places; existing generated terrain
is not migrated. The five-minute pass assumes the world is already ready and
a character has been chosen. Longer progression and multiplayer checks are
optional follow-ups, not work expected inside those five minutes.

## First pass: about five minutes

1. **Quest bundle (one minute).** A Human in Dawnmere is a convenient reference.
   At Elian Reed, accept **Boars Beyond the Fence** and optionally **A Woodsman's
   Edge** independently. At **Bess Honeycrust**, beside the separate oven near
   the trainer, accept **The Smokehouse Share**: four raw meat portions, no
   Cooking requirement. Check that accepting the hunt does not reveal its
   successors. After its actual turn-in, **Braces for the Granary** and
   **Shapes by Lanternlight** should appear together; an unmet level requirement
   stays visible and explains its level. Do not spend the entire pass leveling.
2. **Interaction and input (one minute).** With a skill selected, use an NPC
   standing in front of a door: RMB should reach the NPC, not the door behind.
   Try a clear door/container separately. With a support/self skill aimed at a
   hand-diggable block, compare a short click with holding beyond about 200 ms:
   release casts; holding digs. Skill-held digging must not mine hand-ineligible
   stone/ore or bypass protection. Hold food RMB for 1.5 seconds: one portion,
   then release before eating another. Merely pressing LMB must not eat it.
3. **Geometry and combat (one minute).** Walk closely through an open door and
   beside a pane/shutter: no suffocation. If safely arranged, a full opaque
   stone block at head height should still cause damage in Survival without
   noclip. A Warrior's successful Charge stun should show one gold-star burst;
   an immune boss should not. Killing a crab should use ordinary prompt removal
   and retain its loot.
4. **Equipment and UI (one minute).** Read a tool/weapon's remaining/maximum
   durability. Open profession search and party pages with the configured
   inventory key; check ordinary closing before focusing a text field, then
   normal typing after focusing it. Escape remains available for native widgets
   that consume the key. If a prepared broken item is available, check that its
   appearance remains equipped with cracks and a Broken tooltip.
5. **Record one useful result (one minute).** Note race/class/level, selected
   item, location, action and observed result. For a failure include coordinates,
   time of day and a screenshot or relevant debug-log lines. Mark untested rows
   as untested; no need to complete the entire round in this pass.

## Optional input, equipment and multiplayer checks

- Hold a combat skill over an enemy, then soil, then the enemy. Try a cooling
  or unaffordable skill: fallback Strike must respect melee range and must not
  occur immediately after a successful cast. Blink/Sprint and empty-air self
  activation occur at most once per press. A drop pile receives one pickup
  attempt per press, including when inventory space is unavailable.
- Scout **Loose** uses RMB draw/release; LMB uses Strike/digging. Test early
  release, both buttons together, switching slots and being stunned. NPC or
  container interaction must not also fire or eat. Check a crop's normal harvest
  callback and a protected node; four-node hand reach must not become spell reach.
- Heal the ally currently visible in the crosshair, then aim at air or an
  obstructed ally: the latter cases heal self, not a remembered ally. An already
  running Renew retains its original recipient.
- With another player, verify native minimap points for friendly **and enemy**
  players, without ordinary mob points. Party HUD, members, pending invites and
  online invitation candidates show `[Lv X]`; a disconnected member retains
  their last known level, and reconnect/level-up refreshes it.
- Try class permissions: Warrior sword/dagger/Battle Axe and all armor ranks;
  Scout bow/sword/dagger and leather/cloth; Mage/Priest staff/wand/dagger and
  cloth. Refused equipment explains why. Shared swords/daggers keep their own
  enchants rather than changing stats with their wearer.
- Break and repair a weapon, gathering tool, armor piece and wearable offhand.
  Check the durability number and native wear bar, cracks in inventory and
  equipped views, loss of broken combat benefits, and clean restoration after
  repair. Inspect legal weapon enchant options at a profession station.

## Optional quest journey

At level 10, Elian offers **The Road to Highcourt** independently of the combat
chain. Speak with **Mariel Waybook** at Highcourt's existing chapel quest place
and complete it there. Mariel's **The Ovenward Welcome** introduction points to
**Ansel Ovenward** at the homes bakehouse's separate cook position; the Cooking
trainer remains a different actor. This is conversation travel, without a
parcel, kill requirement or return to Elian.

The main village handoff instead follows the early repair/daytime branch:
**The Road to Marta Millward**, at level 10 after **The Missing Flock**, ends
with Marta at Goldmead Village in level 11–20 country. Complete the conversation
there to reveal **Orchard Watch**. Accept compatible local supply tasks before
that outing. For the later bandit fight, speak with the captive for purse/linen
requests; the captive also accepts the main combat report.

At a new regional host, expect two independent jobs and a third consequence
hidden until its prerequisite is turned in. Check one explicit night target
at night. At level 40, an optional enemy-guard job targets the named opposing
frontier zone: ordinary faction guards count; players, civilians and kings do
not. These missions must not gate capital services.

## Optional POI routes

These are actual world **X/Z anchor centres**, not teleport commands. Ground Y
comes from fitted terrain; approach through the world/atlas or use the test
world's normal administrator navigation. Coordinates are from
[`r20_poi_catalog.lua`](../../mods/MAPGEN/grug_mapgen/wp40/r20_poi_catalog.lua).

| Route | Place | X | Z | Inspect |
|---|---|---:|---:|---|
| Whitebridge | Whitebridge Market Close | -924 | -1556 | Unequal buildings, market workplace, host Merren Oakstamp, retained boat plot |
| Whitebridge | Bridgechalk Dig | -1074 | -1256 | Roofed mine workplace, readable entrance, host Halen Chalkthumb |
| Whitebridge | Oakspan Tollhouse | -618 | -1266 | Two usable shelters, unobstructed host/guard approaches |
| Whitebridge | Siltbasket Camp | -620 | -1760 | Mirefolk shelters and existing camp actors |
| Frontier | Coalbrand Yard | -24 | -406 | Bandit shelters, clear existing spawn positions |
| Frontier | Ashen Wheelbreak | -274 | -296 | Battlefield scenery and readable through-route |
| Encounter | Grimtusk's Rooting | 152 | -2116 | Rare-route scenery without obstructing the existing encounter |
| Encounter | Wyrmglass Dragonspire | -3260 | -40 | Arena approaches, existing boss space and sightlines |
| Encounter | Wyrmglass Fault Camp | -3200 | 80 | Apex resource access, existing roots and nearby shelters |

For inhabited sites, enter the buildings rather than judging only silhouettes:
check roofs, usable interiors, doors, two-node lanes, NPC clearance and ground
support. Natural/battle encounter sites have no blanket building minimum.
Inspect a second culture if time permits; the full catalog is 70 newly authored
places plus retained starts, capitals and earlier regional compositions.

## Accepted limits and unresolved reports

Opening inventory, pause or chat can appear to the server as release and thus
cast/fire a pending action. Very short air clicks between control snapshots
(roughly the default 90 ms cadence, not an exact threshold) can be missed.
Native cracks may appear before the 200 ms decision. Creative may show a safe
predicted-block rollback/retry on an ambiguous early dig. These are accepted
playtest limits, not claims of exact physical-key tracking.

Bandit midfight healing and mobs appearing stacked remain **unconfirmed
reports**, not claimed fixes. For bandits distinguish the preserved 25-node
chase-anchor leash, 15-second contact timeout and 30-second quiet recovery:
record sustained in-bounds combat separately from deliberately leaving the
leash. For stacking, record species, coordinates and terrain/jumping state;
ordinary mobs already disable physical object collisions. Report a repeatable
case before attributing either visual symptom to a new mechanic.

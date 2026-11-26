# Round 88 — Player feedback of 2026-11-26

**Draft, not started.** Release 0.88.0, planned as **compatible** with 0.87.0.
The round answers the user's batch of player feedback: one map filter less,
faster Swiftness and Sprint, professions that advance on the level-up, quest
markers that show what is worth walking to, gathering in enemy territory,
knockback that belongs to the attack, a new Character page and an icon of its
own for every potion family.

## 1. Lanes and waves

| Wave | Lane | Deliverable |
|---|---|---|
| 1 | QOL | One map filter less (PvP into Places), Swiftness +30 % for 5 s, Sprint cooldown 180 s, the profession tier on the level-up, the "Prepared" mixtures gone. |
| 1 | QUEST | The quest markers of §2.5: grey for low givers, no marker for quests not yet acceptable. |
| 1 | GATHER | Herbs and food can be gathered in enemy home territory; everything else stays refused. |
| 1 | KNOCK | Knockback on players from the attack's weight class, never from its damage, and no stacking. |
| 1 | STATS-M | The Character page mockup (artifact) for the user's go. |
| 1 | ICONS-C | Astra's design concept for the potion and elixir icons, for the user's approval. |
| 2 | STATS | The Character page as approved (UI lane: merged only after the user's go on its screenshots). |
| 2 | ICONS-P | Two or three proposals per potion family on a pick page. |
| 3 | ICONS | The picked icons, every tier, in the game (or a follow-up 0.88.1 when the picks come late). |
| last | D | The round's records. |

Auto-forward on a mount waits for the user's own test (§7); a MOUNT lane joins
wave 2 only when that test finds a case to fix. Its likely fix: the mount also
reads `control.movement_y`, beside `control.up`
(`grug_mounts/entity.lua` `horizontal_input`).

## 2. User rulings

1. **Map filter.** The PvP filter goes. The fortresses, the Battlegrounds camps,
   the camps under construction and the arena move to Places. A Battlegrounds
   camp's tooltip names that it is also a mining camp.
2. **Potions.** Every potion and elixir family gets an icon of its own. Astra
   first writes a design concept the user approves, then two or three proposals
   **per family** (not per tier). The "Prepared … Mixture" items leave the game.
3. **Swiftness Draught: +30 % movement speed for 5 s.** The user accepts the
   break of the speed pillar (player 4.0 × 1.3 = 5.2 > 4.6, the ordinary mob
   band) as a named exception, like Sprint. **Sprint's cooldown drops from 300 s
   to 180 s** (+50 % for 10 s unchanged).
4. **Professions.** A profession whose crafts for the next tier are complete
   advances as soon as the character reaches the tier's level, without another
   craft. The hint texts change with it.
5. **Quest markers** (the giver's head and both maps):
   - a giver whose acceptable quests are all **10 or more levels below** the
     player's level shows a **grey "!"**; story quests never turn grey;
   - a quest that cannot be accepted yet gets **no marker** (the grey "soon" "!"
     of Round 65 ruling 2 goes; the giver's dialog keeps its "next quest at
     level X" hint);
   - acceptable quests above the player's level stay **yellow**; no orange;
   - "ready" (yellow "?"), "in progress" (grey "?") and the story colour stay.
6. **Gathering in enemy territory.** Herbs, apples, berries, ground plants and
   the wild cooking and alchemy ingredients can be gathered in enemy home
   territory. Trees, blocks and placing stay refused.
7. **Knockback** (on players):
   - it is a property of the attack, **never of its damage**, and **not of the
     level**;
   - an ordinary mob's melee hit pushes by its family's **weight class**:
     none / light / medium / heavy;
   - an **elite** pushes more than its class (a factor, about ×1.25); rares and
     bosses are set one by one;
   - **projectiles push nothing**;
   - pushes do not add up (§3);
   - a knockback skill for the Warrior is **not** part of this round; the user
     thinks about it further (§7).
8. **Character page.** A mockup first. Str, Int and Dex appear on the page, with
   their effect on hover. The cloak picker moves under the 3D model. The stats
   are a styled clickable list (name left, value right); a click opens a
   scrollable detail box on the right that is ordered by relevance: first the
   stat's direct effects, then, smaller, where the value comes from (for
   example "+4 from Boots").
9. **Respawn lock.** No change: the report of a respawn by Enter is taken as a
   lock that ended with the fight (Enter sends the same `quit` as Esc, which
   the lock answers).

## 3. Shared conventions

- **Knockback window** (coordinator default). Per player one window of
  0.5–0.75 s from the first push: inside it a further push applies only by the
  amount it is stronger than the strongest push so far. The direction is
  horizontal with a small fixed lift, the same for every source, so no push
  points into the floor (the reason the Expedition packs flatten theirs today).
- **Starting values by feel** (coordinator default, tuned after the user's
  test): light about 2.5, medium about 4, heavy about 6 m/s (today about 8.8
  for almost every hit from level 20 on). The four classes and the elite factor
  live in one place.
- **"Prepared" mixtures** (coordinator default): each id becomes an alias of
  `vessels:glass_bottle` instead of a registered item, so a stray leftover is a
  bottle and the release stays compatible without a migration step. The
  user may ask for a deleting step instead.

## 4. Lane goals

**QOL.** *Map:* drop the PvP layer in `grug_map/layers.lua` and move its kinds
to Places in `settlement_icons.lua`; a Battlegrounds camp's tooltip reads as a
war camp and a mining camp. *Swiftness:* `grug_alchemy` (effect, item text),
the status icon's text, and the design documents that state +10 % for 5 s and
the 4.4 < 4.6 arithmetic (`mounts.md`, `combat_stats.md`, `item_tiers.md`),
which name the draught as the second named exception. *Sprint:* the 180 s
cooldown in `grug_abilities/scout.lua` and every document that states 300 s.
*Professions:* a level-change hook (and the join, for a character that is
already saturated) advances every saturated profession the new level allows,
with the existing message, sound and basic-tier unlock; the Crafting tab's and
the craft message's hint stop asking for one more craft. *Mixtures:* the
registrations in `grug_alchemy/recipes.lua` go, the aliases of §3 replace them.

**QUEST.** The marker states in `grug_quests/state.lua` (`Q.marker_states`)
gain the low status and lose the "soon" one; the head marker (`npc.lua`), the
world map's Quests layer and the minimap follow from the state. "Low" reads the
quest's level, not its acceptance level. A giver with a ready or story quest is
never grey.

**GATHER.** A world exception (`grug_core.register_world_exception`) lets a
player dig a gathering source when the world rule refuses the place only as the
other faction's home territory; towns, roads, bridges, settlement and POI cores,
guild rooms and the sea stay refused, and claims stay with `grug_housing`. The
lane names the allowed nodes from the gathering and cooking catalogues (herbs,
spices, found food, apples, berries, the wild ingredients), never trees, logs,
leaves, ores, stone or soil. Right-click picking follows, since a pick is a dig.

**KNOCK.** Replace the damage-based push in the one knockback override
(`grug_core/combat.lua`) with §2.7: a weight class per mob family (a table
beside the families' run speeds), the tier factor, zero for projectiles, the
window and the direction of §3. The Expedition packs' own push and the
dragon's slam go through the same rule or keep their own zero. PvP melee keeps a
small fixed push. The lane reports the family table for the user to read.

**STATS-M / STATS.** The mockup shows the page at the user's window size with
real numbers of one character per class. The build uses the existing accessors
(`grug_classes` attributes, pools, crit and dodge; `grug_quality`'s equipment
totals) and adds a per-slot source breakdown; it reads every number from the
same accessors combat uses.

**ICONS-C / ICONS-P / ICONS.** Ten families: Healing, Mana, Vigor, Focus,
Precision, Stoneskin, Antivenom, Swiftness, Cave, Deepwater (plus the
merchant's healing potion). Readable at 32 and 16 px, the elixirs in line with
their status icons, a tier scheme that is not a Roman numeral. Design goals,
not permission lists, for Astra.

**D.** CHANGELOG, STATUS, the design documents the lanes did not own, and the
Completion. BACKLOG gains the Warrior knockback skill (§7) as an open idea for
a later class round.

## 5. Rules

Every lane states its upgrade classification. The planned outcome is
compatible: no saved state changes shape, the mixtures become aliases. A lane
that finds otherwise reports before it builds. No lane changes the class
balance beyond the Sprint cooldown.

## 6. Verification

- Fixtures per lane for its logic: the marker states (low, story, ready,
  none for not acceptable), the profession advance on a level change and at a
  join, the gathering exception (each refusal kind, allowed and refused nodes,
  placing), the knockback rule (classes, elite factor, projectile, window,
  direction).
- **Human tests offered:** knockback by feel (light, medium, heavy; a pack;
  an elite), on desktop and web; the Character page on both clients.

## 7. Orchestration and open points

- Start from main 0.87.0. The model routing is the user's for the session.
- Open with the user: the **auto-forward test** on a mount (desktop 5.18 and
  the web client); the **story purple**, which the user checks in the game;
  the **Warrior knockback skill**, for a later class round. For that skill: the
  mob displacement it would use (`grug_mobs.displace_mob`) already refuses a
  destination in lava or fire, without a floor under it or inside a block, and
  elite, rare and boss mobs are never pushed. It checks the destination only,
  not the way there, so a long push could cross a narrow gap.
- STATS and ICONS wait for the user's go on the mockup and the concept; the
  round may land without ICONS, which then follows as 0.88.1.

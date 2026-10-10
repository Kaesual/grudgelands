# Quests

Decided 2026-09-21; extended by Round 20 user Go, 2026-09-24, and by the
Round 28 questing redesign, 2026-10-01 (rulings 29, 39–45;
[plan](../planning/round28-questing-leveling-plan.md),
[design frame](../planning/round28-design-frame.md) §4.7); text placeholders
and quest copper by Round 29 Lane Q1, 2026-10-02
([quests plan](../planning/round29-quests-plan.md) §3–4); the Round 29
quest files and the front bounty baseline
([round plan](../planning/round29-plan.md#completion-2026-10-02)); the "use at
a place" objective, quest tags and the turn-in hook by Round 36 Lane E,
2026-10-05 ([plan](../planning/round36-plan.md) §2.5, §2.7).


### Confirmed by the user

- The Nether is excluded from V1 and reserved for the first expansion. V1
  quests must not require visiting it or obtaining Nether-exclusive items,
  kills or unlocks.

- Exactly 20 active quests maximum; accepting beyond that is refused with a
  clear explanation. Completion or abandonment frees a slot.
- The quest log supports viewing and abandoning quests. Since Round 44 it
  is part of the map window (Z or the Map & Quests tab,
  [world_map.md](world_map.md#map-window); until then a Quests tab): right
  of the map, the list box with the active count, the Quest HUD switch, the
  list and one row with "Track on HUD" on the left and Abandon on the right
  (while Confirm abandon and Cancel are shown they take the row alone,
  Round 32); below it the selected quest's title, its level and zone, one
  scrolling text field with the description, the objective lines and the
  reward line, separated by an empty line each, and where to hand it in.
  Selecting a quest marks its targets on the map (leader, talk NPC and use
  place crosshairs, rings around the nearest spawn regions;
  [world_map.md](world_map.md#quest-targets)).
- Quest lists (the quest giver's dialog and the quest log) show each quest's
  status as the entry's colour, explained by a legend or the list's tooltip:
  available gold, ready to complete green, in progress blue, locked grey; a
  repeatable quest ends in "(R)". The giver's dialog is wide enough for the
  longest title at a full-HD window; quest texts are read-only (Round 35).
- The giver's dialog opens on the first quest ready to complete, else the
  first one to accept, else the first in the list, and preselects the same
  way after every Complete and every Accept, so several finished quests are
  handed in by clicking "Complete" and several offers taken by clicking
  "Accept" again and again; after an Accept with nothing ready or acceptable
  left it stays on the accepted quest, and a failed Accept or Complete stays
  on its quest (0.45.1, the user, 2026-10-10). A click in the list shows the
  clicked quest.
- A quest HUD toggle lives in the quest log, defaults on and is saved per player.
  No active quests means no quest HUD, without changing the saved preference.
- Objective families are **item turn-in**, **kill**, **travel**
  (conversation) and, since Round 36, **use at a place** (a quest object
  held at a place; user ruling 2026-10-05, round36-plan §2.5); see
  "Objectives" below. A crafting lesson requests the resulting item, never
  provenance. Travel handoffs contain exactly one
  conversation with the named destination NPC, who also accepts the turn-in.
  No hidden item, secondary errand, arrival-radius check or return trip. The
  ordinary Complete button at the destination awards rewards. No crafting,
  mining, node-digging, arrival or escort objective engine exists; "use at
  a place" writes no node (its object is an entity).
- Kill credit uses the same per-mob damage/effective-healing participation and
  eligibility mechanism as shared XP, never a killing-blow test and never
  party membership. Players from different parties are not a special case.
- Quest-giver markers are attached floating 3D question/exclamation symbols with `set_observers()`.
  Use the existing tag visibility/hysteresis loop and distances, not a second
  independent all-players scan.
- Marker precedence: ready to turn in (yellow question mark), available
  (yellow exclamation mark), active but incomplete (silver question mark),
  relevant level-locked quest (silver exclamation mark), otherwise none.
- Quest chains use existing faction story and zone identities. No cross-faction
  cooperative questline is introduced.

### Accepted defaults

- Track up to ten selected quests on the HUD (Round 24 ruling 23; one
  constant for the tracker, the auto-track on accept and the quest-log
  notice). Each tracked quest is one HUD line showing only its objective
  (e.g. "0/4 Bring Raw Meat"), no title; a quest ready to turn in shows
  "Return to <turn-in NPC>". A quest with several objectives shows them on
  one compact line ("Wood Axe 0/1, Wood Pickaxe 0/1"), a travel quest reads
  "Travel to <NPC>" and a repeatable starts with "Repeatable: ". Two quests
  with identical objectives may read the same. Keep the tab authoritative; do not place the entire journal
  permanently on screen.
- Item turn-ins accept already-owned and traded/crafted-by-others items.
  Descriptions say “Bring ...” instead of claiming to verify personal crafting.
  V1 requirements match a registered item id (or any member of an item
  group) and a count only, with no wear, enchantment, quality or provenance
  predicates. Author hand-ins around ordinary
  resources and basic Wood/Stone tools; do not request valuable enchanted gear.
- Count and consume from main inventory and the player's owned bag contents
  through existing inventory APIs; do not reach into equipment, stations,
  chests or another player's inventory. Recheck at turn-in, not only in the UI.
- Kill counters start at acceptance; item readiness reflects current holdings.
  Sharing credit does not divide quest counters: one eligible kill is one
  count for each relevant active quest. XP splitting itself stays unchanged.
- Do not use `xp > 0` as the sole participation test: gray-level XP suppression
  must not accidentally hide the shared eligible participant event from quests.
  Quest min-level/prerequisite and target rules remain independent.
- Abandoning a quest removes its counters, not ordinary player items. It may be
  accepted again if prerequisites still hold. Completed one-time quests remain
  completed and do not consume active-log slots; repeatables follow
  "Repeatable quests" below.
- One-time XP/coin/item rewards, with all prerequisites, consumed items and
  reward space preflighted together; insufficient space refuses the turn-in
  without consumption or a dropped reward. Avoid adding mail/escrow systems.
- Every quest description includes its minimum level and the titles of its
  prerequisite quests. `min_level` gates accepting; the reward XP is
  `grug_xp.quest_reward(level, weight)`, the authored weight in kill
  equivalents at the quest's reward `level` (`progression.md`); the
  receiver's current level never changes the reward.
- Repeated packets and repeated dialogue clicks must not duplicate rewards.
  Persist active/completed state and HUD preference across reconnect/restart.
- Dependent quests remain hidden until every prerequisite has been turned in.
  Acceptance or completed objectives alone do not reveal successors. Once its
  prerequisites pass, a level-locked quest is visible with its required level.
  Quests carry no race or faction gate of their own; the giver's faction
  decides (Round 31, PvP ruling 13): a giver serves only its own faction,
  the faction of its race (a new giver's own race, else its settlement's),
  and the other faction gets the shared refusal line
  ([settlements.md](settlements.md)). Dialog, floating symbols and atlas use
  the same visibility: the other faction never sees a giver's marker. A
  quest's turn-in NPC is of its giver's faction (checked at load).
  NPCs with multiple quests offer a simple list; independent tasks can form
  bundles without a separate bundle engine.
- Explain optional crafting through a side branch; do not force every player
  to craft as a prerequisite for the local combat story.
- Opening kill lessons use common mobs and small counts (e.g. five boars).
  Avoid five low-drop-rate tusks as the first mandatory task. Quest materials
  must actually exist locally under the current zone/time spawn policies.

## Presentation and regional expansion

Decided 2026-09-21: enlarge quest symbols fivefold while holding their upper
extent fixed (growth downward). Keep per-viewer states and existing visibility
hysteresis. The optional quest HUD (up to ten one-line entries) sits at screen
middle-right, with right-aligned text and edge padding, clear of the top-right
minimap.

Round 29 replaced the 240 quests of Rounds 14–20 with 491 quests in the
per-zone quest files (below): one track per race from the start zone to its
heartland, the contested 31–40 zones, and the 41–60 front with repeatable
and island bounties. Round 31 adds 24 PvP fortress quests (below) and Round
36 the main line's 25 (below; 540 in total). This is an editorial budget,
not a filler quota.
Offer roughly three independent local starter tasks across the adventure giver
and a separate cook near an oven. Compatible tasks share an outing; avoid
repeated returns for increasing counts of the same mob. Optional item/cooking
lessons do not block the combat story or implicitly require a profession.

Each race has a level-10 capital/service introduction, followed by capital and
regional bundles and explicit destination-only travel handoffs. Keep existing
regional giver identities and add hosts at authored peaceful villages, outposts
and mining camps. Existing hostile camps do not acquire friendly quest hosts.
Kill objectives name spawn-recipe roles and leaders, and from Round 31 the
guards and captain of an enemy PvP garrison in its own area (below); no
civilian kills, player kills (PvP ruling 14: players may not be online), king
finale, Nether or future warfront AI.
Rewards follow the quest's reward level (`progression.md`), not the
receiver's current level. Content, actor sockets and local materials
must agree with the current world roster. Exact cards/IDs are maintained in the
Round 20 content contract; delivery status belongs in STATUS/BACKLOG.

## PvP fortress quests (Round 31)

Each faction's fortress ([world.md](world.md) §4; Ashenward Bastion in
Ashenward March, Bannerbreak Warhold in Bannerbreak Mesa) is the hub of its
PvP quests (pvp-plan rulings 14, 15 and 23). Its three quest givers
(Warmaster, Drillmaster, Outrider) give, all from level 40, on their line
`front` (the zone's front file):

- **one raid per enemy Battlegrounds camp** (8 per faction): kill the camp's
  guards (4 at a lower camp, 5 at a higher one) and its captain, both
  limited to that camp's area, at the reward level of the camp's band;
  solo quests (round31-plan §6 item 16: the captain is a normal-tier camp
  leader), given and turned in by the Outrider (lower camps) or the
  Drillmaster (higher camps), the two camps of a band chained by zone;
- **ordinary fortress quests**: supplies for the Quartermaster (Warmaster),
  War Trophies from enemy guards (Drillmaster; they drop only to an enemy
  player's kill), and a scouting kill in a Battlegrounds kind (Outrider);
- **an entry quest** from an outpost of the fortress's zone at level 40, a
  travel quest to the Warmaster.

No objective names a player or a General. The front ledger counts these
quests like every front quest.

## The main line (Round 36)

Each faction's main line for levels 41–60 (round36-plan §2.2–§2.8, the
[story bible](../planning/round36/story-bible.md)) runs from its fortress
Warmaster's second line, travel handoffs and turn-ins at the existing
givers the bible names, and the front climaxes folded in as required
steps (their texts carry the thread; their other quests stay as they
were). Chapters open at 41, 46 and 53, each with a quest that requires
the previous chapter's last turn-in (a Warmaster turn-in); the finale
"Party: The Collector Comes Due" opens at 60 on the rift boss, and the
last turn-in at the Warmaster carries the bible's last line. Every step a
chapter names carries the faction's tag; every required step is solo but
the finale; optional branches (the war commander's "Party:" hunt, the
islands' interactions) never block the line. The ledger counts a front
host's main line in the front bands (`ledger.py --track`).

- **The Throng** ("Our Oaths Are Ours", tag `throng_main`, the
  Warmaster's line `oaths`): chapter 1 (41) the false requisition at
  Bannerfall Pocket, Drek Rampbinder's Toll-Taker Senn with his toll-box
  at Causeway Toll Ruin, Orrel Hollowstep's ash slab at Ashen Grave;
  chapter 2 (46) the pledged standard at West Trench Mouth, Yarra
  Standardmender's Ninepins, the Accord Captain's Orders from the Accord's
  high war camp on The Shattered Line, the branded pay buried at Coinpit
  Hollow; chapter 3 (53) the Kiln-Whisper Hexers, Vaska Ashlistener's
  Huskell, Nalo Pathdrum's Chirr with the rootmark at Skyroot Crossing,
  the tally-stone at Tombroad Ambush; then the finale, turned in at Vaska,
  and `throng_main_final` at the Warmaster. Optional: War Commander
  Greyvow (57, Party:), the survey cairn and the wreck's pay chest on the
  islands (60, from the Nhal Veyr and Gor Drazhak envoys).
- **The Accord** ("Every Name Accounted For", tag `accord_main`, the
  Warmaster's line `main`): chapter 1 (41) the impounded pay at Ashen
  Wheelbreak, Toren Waterbarrel's Coal-Purse Factors, Alna Archsight's
  rubbing at Brandscar Cairn and Toll-Taker Senn with his toll-box at
  Causeway Toll Ruin (her Senn chain opens at 46, two levels earlier, so
  chapter 2 can open at 46); chapter 2 (46) the Brandbound Collectors and
  the pledged standard at Siege Ramp Foot, Nella Hedgeward's Ninepins, the
  Throng Captain's Orders from the Throng's high war camp on The Shattered
  Line (47), the courier's pay ledger at Courier's Stump; chapter 3 (53)
  the Debtjaw Hounds, turned in at Borin Splitbolt, his Huskell, Eriath
  Boughwarden's Chirr, the rootmark at Skyroot Crossing and the
  tally-stone at Tombroad Ambush; then the finale at the Warmaster and
  `accord_main_final`, a report given and taken there. Optional: War
  Commander Stonegrudge (57, Party:), Salt-Counter (58, Party:, Borin),
  the survey cairn and the wreck's pay chest on the islands (60, from the
  Dur Brannoc and Highcourt envoys, once chapter 3 has begun).

## Objective presentation

Progress appears in the message feed (`inventory_equipment.md`, "Message
feed"): whenever an objective count rises (kill credit, an item gained, a
conversation, a finished use), the quest posts one line with every objective as
"<name> n/m" ("Barley Piglet 3/10"), replacing that quest's previous line.
Accepting a quest and falling item counts post nothing; nothing goes to chat.

Kill objectives name each target by the name the mob shows (Round 38, see
"The quest-name guarantee" below): the names of the slots the objective's
roles and area select ("Yam Piglet" in the Kapok Cradle); the
dialogue, the quest log, the tracker and the message feed share that label.
A PvP camp's captain reads as he is named on this world (his camp's race).
Item objectives show the concise item name, not description stat/durability
lines; an item objective's named source must really drop that item at the
levels it is met (`E-item-source-drop`).
Worn qualifying items remain acceptable. Starter kill/drop targets follow the
minimum-level-aware local wildlife roster and remain locally achievable.

**Level ranges** (Round 28 Lane Q0): names carry no signal words (Round 38,
[biomes_mobs.md](biomes_mobs.md) "Names"), so the offer dialogue and the
quest log show each objective's target levels after it, in the objective's
own colour: "Defeat Barley Piglet × 8 (level 1–2)", "Defeat Barley Piglet:
0/8 (level 1–2)", "(level 10)" for one level. Per role, first match: a leader's fixed level; in the objective's
area that role's levels there (not the whole kind's); the role's levels in
the kinds and camps of the quest zone's recipe; its catalogue levels within
the quest level ±3; a base mob (no catalogue row) in a zone without a recipe:
the zone's level band within the quest level ±3 (a base mob adds nothing in a
recipe zone). The objective shows the union over its roles; since Round 38
a kill objective also adds the levels of every slot that bears its names
(every such mob counts). The load check's level fit (`E-level-fit`) stays on
the selected levels. An item
objective shows the range of its quest drops' roles and of its named source
(below); plain gathering,
crafting and travel objectives show none. The ranges are computed once at
load. The HUD tracker keeps its compact line without a range: added, it
would cut 22 of the 204 shipped tracker lines at the 38-character width
instead of 2.

## The quest-name guarantee (Round 38)

For the player, a mob's name is the exact answer to "which mobs does this
quest mean?" (round38-mob-names-plan.md §2.1). Every mob takes its name from
`grug_mobs/data/names.json`, one name per slot (`<zone>/<source>/L<lo>-<hi>`,
written by `tools/r38_b1/gen_names.py`): by its source (its role, a rare's
`rare.<id>`, a garrison post's `<settlement key>.<post>`), its zone (its
spawn tag's, else its first activation position's) and its level, at every
activation and level change. A kill objective or quest drop resolves its
roles and area once at load into the names of the slots they select
(`labels.lua` `Q.target_names`); a kill counts when the mob's name is one of
them (`state.lua` `mob_counts`), whatever its area, level or spawn place, and
no mob of another name counts. Item objectives name items; their mobs are
guidance (the user, 2026-10-06). A role that selects no name stops the load
(`E-no-name`); `tools/r38_names/guarantee.py --check` proves the rest over
every slot and quest (overlapping names, a critter or a town guard sharing a
counted name, names the text never says).

## Objectives (Round 28)

- **Kill**: a list of roles (entity `grug_mobs:<role>`; a sub-type is its own
  role, so a quest meaning a whole family lists its roles) and a count,
  optionally with one area: a kind or a camp of the zone's spawn recipe
  (`zone_id/kind_id`, [spawn_regions.md](spawn_regions.md)). The roles and
  the area **select names**, they do not limit the count: the objective
  counts every mob that shows one of the selected names, wherever it spawned
  (Round 38, below). A named leader stands at a rule-placed spot without an
  area; its kill objective names no area. In a zone with a spawn recipe only
  the recipe's roles appear on the surface; a kill objective there whose
  roles the recipe never spawns and none of which is a leader (a leader of
  any zone counts: a front file names the front's leaders) is reported as a
  load-time warning (W-recipe-target). Critters
  are never kill targets (Ruling 29), nor rares (Ruling 38).
- **Item**: one item, or any member of an item group (`group:tree`: "any
  log"), and a count. Objectives of one quest draw from the holdings in
  order, so two objectives never count the same item twice. An item that
  mobs drop (a family drop such as a boar tusk) may name its source:
  `roles` and optionally one `area`, checked like a quest drop's source and
  shown only as the level range (the item counts however it was obtained).
- **PvP garrison kill** (Round 31): the area may also be a PvP POI's garrison,
  `<zone>/<settlement key>` of a fortress or Battlegrounds camp
  (`front_broken_causeway/pvp_camp_broken_causeway_throng_low`), the tag its
  guards and captain carry ([world.md](world.md) §4). Its roles are the
  faction's guard and captain (a camp, at the camp's band; the captain at
  its top) or guard, bodyguard and General (a fortress); a guard or captain
  is a kill target only there, and only for a quest whose giver serves the
  other faction (`E-garrison-faction`). Own-faction kills never count. A
  garrison's guards carry their post's name (never the town guards'
  "Accord Guard"/"Throng Guard"), its captain his race's name; a quest text
  writes the captain as `{captain:<camp key>}`.
- **Travel**: one conversation, the quest's only objective, credited on
  accept (Ruling 39): the destination NPC shows its yellow "?" at once and the
  HUD reads "Travel to <NPC>". The turn-in still needs the visit.
- **Use at a place** (Round 36, round36-plan §2.5): the player goes to a
  place and holds an interaction there. The objective names the `place`, the
  `object` kind shown there, the act's `label` ("Light the signal fire") and
  its `hold` (whole seconds, 1–15); it counts once (`count` 1 or left out).
  - **Place:** a clash site by its settlement key (`r20_anchor_071` …
    `r20_anchor_086`, world_zones.md §16: Ashenward March, Bannerbreak Mesa,
    the four Battlegrounds zones and both islands), or a quest place of a
    spawn recipe, `zone_id/place_id` (a bare id: the quest file's zone),
    placed per seed like a kind leader ([spawn_regions.md](spawn_regions.md)
    step 8 and `places`); the four contested zones without a clash site have
    one each. No mapgen writes.
  - **Quest object:** an entity at the place, added while a player who still
    needs the objective is within 48 nodes (the active-block reach) and seen
    only by such players (`set_observers`); several players with the quest
    see and use the same object, the last one leaving removes it, it is
    never saved. It stands on walkable ground under open air (grass and
    flowers allowed) at the place or the nearest such column within 6 nodes
    (a place without one logs a warning once and is searched again every
    10 s), the n-th act at one place 2 nodes beside
    the first. Its nametag is the label. The object's look is a kind of
    `grug_quests/data/use_objects.json` (one texture and a size per kind,
    the one place the texture names live): the story bible's twelve objects
    (Round 36), `impounded_pay`, `false_requisition`, `brand_rubbing`,
    `ash_slab`, `toll_box`, `courier_ledger`, `branded_pay_pit`,
    `pledged_standard`, `tally_stone`, `rootmark`, `survey_cairn` and
    `wreck_pay_chest`, each drawn by `grug_quests_obj_<kind>.png` 1–1.4
    nodes wide. Every aiming ray of a player who
    does not see it (combat, hand clicks and the crosshair's interact colour,
    a skill item's right-click) passes through it.
  - **The hold:** a right-click within 5 nodes starts it, the message feed
    counts the seconds ("Light the signal fire: 2/3 s"); letting go of the
    button, stepping more than 5 nodes away or the object vanishing stops it
    ("stopped.", "too far away."), any damage interrupts it ("interrupted.");
    a lower maximum HP from an expiring buff or a gear swap is no damage.
    A finished hold credits that player only, every active quest of theirs
    with the same place, object and label at once, and hides the object from
    them. Labels: "Light the signal fire at Saltgate Remnant" in the
    dialogue, the quest log and the HUD; "Light the signal fire 0/1" in the
    feed's compact line.
  - Checks: an unknown place (`E-use-place`) or object kind
    (`E-use-object`), a hold outside 1–15 s, a count other than 1, a missing
    label, and kill or item fields on it (or its fields on another kind) stop
    the load (`E-objective`). The ledger counts no XP for it: the trip and
    the hold are the quest's time, paid by its reward weight.
- **Several objectives per quest**: the dialogue and the quest log show one
  line per objective, the HUD one compact line.
- **Quest-only drops** (`quest_drops`): an item that drops only while the
  quest is active and the player still needs it, from the listed roles
  (optionally one area; like a kill, they select the names it drops from),
  with a 1-in-N chance. It is rolled **per eligible
  participant** who has the quest (the participants of kill credit), goes
  straight into that player's inventory or bags (dropped at the feet when
  full) and posts a loot line to the message feed, so a party never competes
  for it. Each quest drop pairs with an item objective of its quest.

## Repeatable quests (Ruling 42)

A quest with `repeatable = {cooldown}` can be taken again once the cooldown
(seconds of real time) has passed since its turn-in. It is labelled
"Repeatable" in the dialogue list and detail (with the cooldown), the quest
log and the HUD; while it cools down the giver lists it with "Repeatable
again in N min.". Its first completion counts for every quest that requires
it; a repeat starts its counters from zero. Repeatables are given by existing
NPCs on one of their two lines; bounties are repeatables (`round28-design-frame.md` §4.8).

**Front bounty baseline** (Round 29): the 41–60 leveling budget of a
faction's front route counts **two repeats per bounty** (N = 2;
`ledger.py --track <race> --repeat 2`). At N = 2 the front quests carry
about 67–73 % of the 41–50 and 51–60 bands for both factions; further
repeats are extra, never part of the baseline. Island bounties pay coin and
materials and count nothing toward leveling.

## Quest data (per zone)

Quest content is data, one file per zone, read at load by
`grug_quests/loader.lua`:

- `mods/PLAYER/grug_quests/data/zones/<zone_id>.quests.json`: the zone's
  hubs (at most two givers per hub, at most two lines per giver), their givers
  and lines, and its quests (format: design frame §4.7: `giver`, `turnin`,
  `min_level`, reward `level`, `requires` across zones, `objectives`,
  `quest_drops`, `repeatable`, `rewards` with `weight`, optional `copper`
  and `items`; the design notes `lesson`, `duration_min`, `optional`,
  `climax`, `group` and `notes` are allowed and not read; `tags`, Round 36,
  is a list of snake_case names the achievements count, below). Any other field
  of a quest, an objective, its rewards or a quest drop stops the load
  (`E-unknown-key`): fixed reward `xp`, `faction`/`race` gates and kill
  objectives by entity names (`mobs`) or zone filter (`zone`) were retired
  in Round 30.
- `<zone_id>.front.quests.json`: front quests given by that zone's givers on
  the line `front`, which the zone's own file declares for that giver; the
  zone's own quests never use `front`.
- New givers stand at a free quest socket of the hub's settlement
  (`{"npc", "new": {"name", "race", "socket"}, "lines"}`): the socket-bound
  NPC system places the quest giver there with that name and race; the race
  sets the giver's faction, so a giver of the other faction can stand in a
  settlement (a spy).
- The loader checks every file at load and stops the server with every
  finding listed, each naming the file and the quest: givers and lines per
  hub, front lines, objective shapes, known NPCs, items, groups and roles,
  critter targets, areas that host their target, quest-drop pairing, and the
  level fit (every level a target, quest-drop source or item source is met
  at lies within the quest's reward level ±3). `tools/r28_design/validate.py` checks the same rules on the
  design files, plus the atlas checks.
- Item objectives allocate held items exact items first, then groups; the
  turn-in takes exactly what the progress counted.
- **Chapter chains** (Round 36): `requires` crosses files, and a quest whose
  `min_level` is below a prerequisite's opens only at the prerequisite's
  level, so its shown gate would be wrong: `validate.py` warns
  (`W-chain-gate`; two shipped bounties carry it, one level apart). The
  main line's chapter gates (41, 46, 53, 60) follow from it.
- **Turn-in hook and tags** (Round 36): `grug_quests.register_on_turn_in(fn)`
  calls `fn(player, quest_id, def)` once per completed turn-in (a
  repeatable at each), after the state and the rewards are stored; a refused
  turn-in calls nothing, and a failing observer keeps neither the others nor
  the turn-in from completing. `grug_achievements` counts through it
  `quest:<quest id>` (that quest's turn-ins; a one-time quest's achievement
  has `at = 1`) and `quest_tag:<tag>` (turn-ins of quests whose `tags` list
  it), each only while an achievement asks for it
  ([character_visuals.md](character_visuals.md) §5b).
- **Zone files depend on each other.** `requires` crosses
  zones: a race's home-zone file requires quests of its start zone, and a
  front file needs its host's `front` line. Removing a required quest or a host's `front` line
  stops the load, so replace dependent zone files in one change (or keep the
  required ids).

## For content lanes

Round 29 Lane Q1. Quest texts follow the user's text rule (2026-10-02):
English, two to four sentences, the giver's race voice, light humour
welcome; items by name only, **never an item's tooltip text**; directions
and places that depend on the seed only as **placeholders**, never a fixed
compass word.

**Placeholders** in `title` and `text`, filled per world from the spawn
regions and leader spots ([spawn_regions.md](spawn_regions.md#directions)):

| Placeholder | Reads | Use for |
|---|---|---|
| `{dir_from_giver:T}` | "southeast from here", "nearby" | compact targets: camps, leaders, shore strips |
| `{dir_of:P:T}` | "southeast of Highcourt", "near Highcourt" | any target, from a named place |
| `{zone_area:T}` | "in the southeast of Dawnmere Fields", "in the heart of Dawnmere Fields" | open kinds spread over many patches |
| `{name:T}` | "Dawnmere Meadows", "Crumb" | the display name of a kind, camp or leader |
| `{captain:T}` | "Captain Vrakk" | a PvP camp's captain (T its settlement key) as named on this world (Round 38) |

- `T` is a kind or camp of a spawn recipe, a leader role, a PvP POI (a
  fortress or Battlegrounds camp by its settlement key, Round 31), or a
  place of a "use at a place" objective (Round 36: a recipe's quest place,
  `{name:brandscar_cairn}` "Brandscar Cairn", or a clash site by its key,
  `{name:r20_anchor_076}` "Saltgate Remnant"). A bare id
  means the quest file's zone; another zone's kind, camp or quest place is
  written `zone_id/id` (`{zone_area:elandor_whitebridge_shire/oakwood}`); a
  leader role, a PvP POI and a clash site are found in any zone. A PvP POI reads its label
  (`{name:pvp_fortress_accord}` "Ashenward Bastion") and points at its
  anchor.
- `P` is a settlement key or anchor id: `highcourt`, `goldmead_village`,
  `anchor_015`.
- A kind is pointed at by its largest patch, so two placeholders of one
  quest never disagree. "From here" is measured from the giver and reads so
  only in the giver's own dialogue; the quest log and another NPC's
  dialogue (a different turn-in) read it from the giver's settlement
  instead ("northeast of Dawnmere"). On an open
  kind it is a warning (`W-placeholder-spread`): use `{zone_area:...}` or
  `{dir_of:...}` there.
- A title takes only `{name:...}`: titles appear in lists and in other
  quests' requirements and are filled once at load. Texts are filled on
  their first display and cached; a fill that starts a sentence starts with
  a capital ("{dir_from_giver:bandit_camp} the smoke rises." reads
  "Northeast from here the smoke rises.").
- Examples: "Boars raid the crops {zone_area:home_fields}.";
  "Crumb's gang holds the {name:bandit_camp} {dir_from_giver:bandit_camp}.";
  "The wolves den {dir_of:highcourt:elandor_whitebridge_shire/oakwood}."
- A target without a direction on a world (it formed no region there; the
  region check `quest_targets.py` prevents it) reads "in <zone>" or
  "around <place>" and is logged.

**No fixed compass word** in a title or text: north, south, east, west, the
four diagonals, and their -ern, -erly, -ward, -wards, -bound, -most,
-ernmost, -erner and -erners forms ("northbound", "southernmost",
"Easterners"), in any case and hyphenation ("north-east" counts). Only whole words count: names such
as "Northfold" or "Westbrook" are fine. Write a placeholder or neutral
wording ("past the mill", "along the shore").

**Copper:** `rewards.copper` is optional. Without it the quest pays
`round_half_up(0.08 × P(T) × weight)` copper, at least 1c for a weight above
0 (none for weight 0), with P = 25 / 65 / 160 / 400 / 1,000 / 2,500 for the
reward level's tier band T (1–10 … 51–60; the WP44 cutover column,
[economy plan](../planning/economy-vendor-plan.md) §4): a T1 3-KE hunt pays
6c, a T6 one 6s. Write `copper` only for a deliberate exception (an island
salvage bounty of weight 0).

**Checks:** the game refuses at load every malformed placeholder, unknown
target or place, direction in a title and compass word, naming file and
quest. Offline: `python3 tools/r28_design/validate.py --game --atlas
docs/planning/round28/zones/ --zone <your zones>` (the same rules with the
codes of its README) and `python3 tools/r28_design/ledger.py --game --track <race>
[--sister <zone>]` for the route budget (31–40 the faction's three contested
zones, 41–50 The Broken Causeway and The Shattered Line, 51–60 Gravesalt
Escarpment and The Skyglass Canopy, each with the faction's front quests).
On the region stats of three seeds, `python3
tools/r28_regions/quest_targets.py` checks that every target forms: each
kill objective, item source and quest drop, each leader and each
placeholder target (0 MISSING; after a recipe change re-render with
`tools/r28_regions/run.sh <zones>` first; CLOCK lists a text that names
only the clock its targets are not met at). The portable tests run the
real loader: `luajit tools/r28_q0/portable_test.lua` (section 5: the
shipped files over the shipped recipes, catalogue, item registry dump
`docs/planning/round28/items/existing.json` and settlement places; refresh
the dump with `tools/r28_design/dump_items.sh` after registering new
items), `luajit tools/r29_q1/portable_test.lua` (compass words) and
`luajit tools/r28_b4_quests/portable_test.lua` (the quest engine on its
fixture).

# Quests

Decided 2026-09-21; extended by Round 20 user Go, 2026-09-24, and by the
Round 28 questing redesign, 2026-10-01 (rulings 29, 39–45;
[plan](../planning/round28-questing-leveling-plan.md),
[design frame](../planning/round28-design-frame.md) §4.7).


### Confirmed by the user

- The Nether is excluded from V1 and reserved for the first expansion. V1
  quests must not require visiting it or obtaining Nether-exclusive items,
  kills or unlocks.

- Exactly 20 active quests maximum; accepting beyond that is refused with a
  clear explanation. Completion or abandonment frees a slot.
- A dedicated Quest inventory tab supports viewing and abandoning quests.
- A quest HUD toggle lives in this tab, defaults on and is saved per player.
  No active quests means no quest HUD, without changing the saved preference.
- Objective families are **item turn-in**, **kill** and **travel**
  (conversation); see "Objectives" below. A crafting lesson requests the
  resulting item, never provenance. Travel handoffs contain exactly one
  conversation with the named destination NPC, who also accepts the turn-in.
  No hidden item, secondary errand, arrival-radius check or return trip. The
  ordinary Complete button at the destination awards rewards. No crafting,
  mining, node-interaction, arrival or escort objective engine exists.
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
  Quest min-level/prerequisite/faction and target rules remain independent.
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
  receiver's current level never changes the reward. The split older quests
  keep their fixed XP until their zone's design replaces them.
- Repeated packets and repeated dialogue clicks must not duplicate rewards.
  Persist active/completed state and HUD preference across reconnect/restart.
- Dependent quests remain hidden until every prerequisite has been turned in.
  Acceptance or completed objectives alone do not reveal successors. Once race,
  faction and prerequisite gates pass, a level-locked quest is visible with its
  required level. Dialog, floating symbols and atlas use the same visibility.
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

Round 20 expanded authored journeys to 240 quests including revision of the
initial 102; Round 28 split them into the per-zone quest files (below), and
each zone's design replaces its file. This is an editorial budget, not a filler quota.
Offer roughly three independent local starter tasks across the adventure giver
and a separate cook near an oven. Compatible tasks share an outing; avoid
repeated returns for increasing counts of the same mob. Optional item/cooking
lessons do not block the combat story or implicitly require a profession.

Each race has a level-10 capital/service introduction, followed by capital and
regional bundles and explicit destination-only travel handoffs. Keep existing
regional giver identities and add hosts at authored peaceful villages, outposts
and mining camps. Existing hostile camps do not acquire friendly quest hosts.
Enemy-guard objectives use existing reachable guards and contribution credit;
no civilian kills, player kills, king finale, Nether or future warfront AI.
Rewards follow the quest's reward level (`progression.md`), not the
receiver's current level. Content, actor sockets and local materials
must agree with the current world roster. Exact cards/IDs are maintained in the
Round 20 content contract; delivery status belongs in STATUS/BACKLOG.

## Objective presentation

Progress appears in the message feed (`inventory_equipment.md`, "Message
feed"): whenever an objective count rises (kill credit, an item gained, a
conversation), the quest posts one line with every objective as
"<name> n/m" ("Small Boar 3/10"), replacing that quest's previous line.
Accepting a quest and falling item counts post nothing; nothing goes to chat.

Item objectives show the concise item name, not description stat/durability lines.
Worn qualifying items remain acceptable. Starter kill/drop targets follow the
minimum-level-aware local wildlife roster and remain locally achievable.

**Level ranges** (Round 28 Lane Q0): signal words exist only in the start
zones, so the offer dialogue and the quest log show each objective's target
levels after it, in the objective's own colour: "Defeat Small Boar × 8
(level 1–4)", "Defeat Small Boar: 0/8 (level 1–4)", "(level 10)" for one
level. Per role, first match: a leader's fixed level; in the objective's
area that role's levels there (not the whole kind's); the role's levels in
the kinds and camps of the kill zone's recipe (the zone filter's zone, else
the quest's); its catalogue levels within the quest level ±3; a base mob
(no catalogue row) in a zone without a recipe: the zone's level band within
the quest level ±3 (a base mob adds nothing in a recipe zone). The
objective shows the union over its roles. An item objective shows the range
of its quest drops' roles and of its named source (below); plain gathering,
crafting and travel objectives show none. The ranges are computed once at
load. The HUD tracker keeps its compact line without a range: added, it
would cut 22 of the 204 shipped tracker lines at the 38-character width
instead of 2.

## Objectives (Round 28)

- **Kill**: a list of roles (entity `grug_mobs:<role>`; a sub-type is its own
  role, so a quest meaning a whole family lists its roles) and a count,
  optionally limited to one area: a kind or a camp of the zone's spawn
  recipe (`zone_id/kind_id`, [spawn_regions.md](spawn_regions.md)). An
  area-limited objective counts a kill only when the mob carries that tag
  (set when it spawned from a region of that kind or from that camp), never
  by where it died. A named leader stands at a rule-placed spot without an
  area; its kill objective names no area. In a zone with a spawn recipe only
  the recipe's roles appear on the surface; a kill objective there whose
  roles the recipe never spawns is reported as a load-time warning
  (W-recipe-target). Critters
  are never kill targets (Ruling 29), nor rares (Ruling 38). The split older
  quests keep entity names (`mobs`) and an optional named-zone filter
  (`zone`, matched at the death position), and some of them ask for enemy
  faction guards in the contested zones.
- **Item**: one item, or any member of an item group (`group:tree`: "any
  log"), and a count. Objectives of one quest draw from the holdings in
  order, so two objectives never count the same item twice. An item that
  mobs drop (a family drop such as a boar tusk) may name its source:
  `roles` and optionally one `area`, checked like a quest drop's source and
  shown only as the level range (the item counts however it was obtained).
- **Travel**: one conversation, the quest's only objective, credited on
  accept (Ruling 39): the destination NPC shows its yellow "?" at once and the
  HUD reads "Travel to <NPC>". The turn-in still needs the visit.
- **Several objectives per quest**: the dialogue and the quest log show one
  line per objective, the HUD one compact line.
- **Quest-only drops** (`quest_drops`): an item that drops only while the
  quest is active and the player still needs it, from the listed roles
  (optionally one area), with a 1-in-N chance. It is rolled **per eligible
  participant** who has the quest (the participants of kill credit), goes
  straight into that player's inventory or bags (dropped at the feet when
  full) and posts a loot line to the message feed, so a group never competes
  for it. Each quest drop pairs with an item objective of its quest.

## Repeatable quests (Ruling 42)

A quest with `repeatable = {cooldown}` can be taken again once the cooldown
(seconds of real time) has passed since its turn-in. It is labelled
"Repeatable" in the dialogue list and detail (with the cooldown), the quest
log and the HUD; while it cools down the giver lists it with "Repeatable
again in N min.". Its first completion counts for every quest that requires
it; a repeat starts its counters from zero. Repeatables are given by existing
NPCs on one of their two lines; bounties are repeatables (`round28-design-frame.md` §4.8).

## Quest data (per zone)

Quest content is data, one file per zone, read at load by
`grug_quests/loader.lua`:

- `mods/PLAYER/grug_quests/data/zones/<zone_id>.quests.json`: the zone's
  hubs (at most two givers per hub, at most two lines per giver), their givers
  and lines, and its quests (format: design frame §4.7: `giver`, `turnin`,
  `min_level`, reward `level`, `requires` across zones, `objectives`,
  `quest_drops`, `repeatable`, `rewards` with `weight`, `copper` and
  `items`).
- `<zone_id>.front.quests.json`: front quests given by that zone's givers on
  the line `front`, which the zone's own file declares for that giver; the
  zone's own quests never use `front`.
- New givers stand at a free quest socket of the hub's settlement
  (`{"npc", "new": {"name", "race", "socket"}, "lines"}`): the socket-bound
  NPC system places the quest giver there with that name and race.
- The split older quests carry legacy fields (fixed `xp`, `mobs`, `zone`,
  `faction` and `race` gates, the line `legacy`).
- The loader checks every file at load and stops the server with every
  finding listed, each naming the file and the quest: givers and lines per
  hub, front lines, objective shapes, known NPCs, items, groups and roles,
  critter targets, areas that host their target, quest-drop pairing, and the
  level fit (every level a target, quest-drop source or item source is met
  at lies within the quest's reward level ±3). `tools/r28_design/validate.py` checks the same rules on the
  design files, plus the atlas checks.
- Item objectives allocate held items exact items first, then groups; the
  turn-in takes exactly what the progress counted.
- **For content lanes: zone files depend on each other.** `requires` crosses
  zones: today each race's home-zone file requires three quests and its
  capital file one quest of the start zone, and a front file needs its
  host's `front` line. Removing a required quest or a host's `front` line
  stops the load, so replace dependent zone files in one change (or keep the
  required ids).

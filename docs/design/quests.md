# Quests

Decided 2026-09-21; extended by Round 20 user Go, 2026-09-24, and by the
Round 28 questing redesign, 2026-10-01 (rulings 29, 39–45;
[plan](../planning/round28-questing-leveling-plan.md),
[design frame](../planning/round28-design-frame.md) §4.7); text placeholders
and quest copper by Round 29 Lane Q1, 2026-10-02
([quests plan](../planning/round29-quests-plan.md) §3–4); the Round 29
quest files and the front bounty baseline
([round plan](../planning/round29-plan.md#completion-2026-10-02)).


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
and island bounties. This is an editorial budget, not a filler quota.
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
the kinds and camps of the quest zone's recipe; its catalogue levels within
the quest level ±3; a base mob (no catalogue row) in a zone without a recipe:
the zone's level band within the quest level ±3 (a base mob adds nothing in a
recipe zone). The objective shows the union over its roles. An item
objective shows the range of its quest drops' roles and of its named source
(below); plain gathering,
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
  other faction (`E-garrison-faction`). Own-faction kills never count.
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
  `climax`, `group` and `notes` are allowed and not read). Any other field
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

- `T` is a kind or camp of a spawn recipe, a leader role or a PvP POI (a
  fortress or Battlegrounds camp by its settlement key, Round 31). A bare id
  means the quest file's zone; another zone's kind or camp is written
  `zone_id/id` (`{zone_area:elandor_whitebridge_shire/oakwood}`); a
  leader role and a PvP POI are found in any zone. A PvP POI reads its label
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

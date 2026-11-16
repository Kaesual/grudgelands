# Quests

Decided rules of the quest system: the kinds of quests, objectives, givers
and turn-in, the journal, markers and tracker, rewards, the quest data and
its checks, the text rules, and the shape of each level band's quests. The
quest files (`mods/PLAYER/grug_quests/data/zones/*.json`) are the source
for each quest's givers, objectives, counts, places, rewards and texts; this
file keeps the rules and the intent per band that the data does not carry.
Neighbouring owners: the reward XP and the level curve
[progression.md](progression.md); the story and the main line's beats
[story.md](story.md) §2a; the guild quests [miners_guild.md](miners_guild.md)
§11; the Expedition quests [expeditions.md](expeditions.md) §12; the PvP
fortresses [world.md](world.md) §4; the mailbox [mail.md](mail.md). The
round-by-round history of this file and its old per-band content record are
archived in [quests-history.md](../archive/design/quests-history.md).

## Scope

- The Nether is excluded from V1 and reserved for the first expansion. V1
  quests must not require visiting it or obtaining Nether-exclusive items,
  kills or unlocks.
- **393 quests in total**, counted as the quest ids in
  `mods/PLAYER/grug_quests/data/zones/*.json` (48 files). This is an
  editorial budget, not a filler quota.
- Quest chains use existing faction story and zone identities. No
  cross-faction cooperative questline is introduced.
- Kill objectives name spawn-recipe roles and leaders, and the guards and
  captain of an enemy PvP garrison in its own area ("PvP garrison kill");
  no civilian kills, player kills (PvP ruling 14: players may not be
  online), king finale, Nether or future warfront AI.
- Content, actor sockets and local materials must agree with the current
  world roster. Quest materials must actually exist locally under the
  current zone/time spawn policies.

## Kinds of quests

### Story and free play

- **Story quests** (`"story": true`) guide the player from A to B and may
  form chains. Their marker and their list category are their own ("Quest
  markers", "The giver's dialog").
- **Every other quest is free play**: it requires nothing but a level and
  has at most one follow-up (a quest that names it in `requires`) **per
  faction** (the user's ruling of 2026-10-24), rarely: the zone's last
  quest that leads to the next zone's giver, a guild's small storyline. A
  place offers its free quests at once.
- **The faction of a follow-up** is that of its givers, over every variant:
  an NPC giver's (the faction it serves) or a role giver's filter
  (`{"role", "faction"}`). A follow-up whose givers serve both factions (a
  shared quest with an Accord and a Throng variant) counts as a follow-up
  in each; a giver that serves everyone counts for both. Example: the guild
  gather quest `guild_t2_iron` (given to both factions) may be followed by
  `guild_t2_report_accord` (Accord foremen) and `guild_t2_report_throng`
  (Throng foremen), one each; a third follow-up of Accord givers, or a
  report given by the foremen of both factions next to one of them, is
  refused.
- These two rules hold only in reworked files ("The rework flag"); all 48
  quest files are reworked.

### Every quest once

Every quest is done exactly once; there are no repeatable quests and no
switch for them. A quest file that names `repeatable` stops the load like
any unknown field (`E-unknown-key`). A saved quest state that still holds a
removed quest id drops it from the active and tracked quests at load;
`completed` is only looked up by id, and an old state's `cooldowns` are
never read (`state.lua`, `tools/r46_xp`). The island bounties are one-time
quests: they pay coin and materials and count nothing toward leveling.
Completed quests remain completed and do not take active-log slots.

### Shared quests

A task that is the same in several places is **one quest**: one id, given
and handed in by several NPCs, done once per player everywhere. No giver
offers a quest the player completed (or holds) elsewhere.

- **Variants.** A shared quest carries `variants` in place of `giver` and
  `turnin`, one per giver zone: `{"zone", "givers", "turnins"?,
  "objectives"?, "quest_drops"?, "text"?, "completion"?}`. Kill objectives
  are zone-bound (their names resolve in a zone, "The quest-name
  guarantee"), so each variant counts **its own zone's names**: a variant's
  `objectives` lists one entry per objective of the quest with only the
  zone-bound fields it changes (kill and item: `roles`, `area`; talk:
  `npc`; use: `place`; quest drops: `roles`, `area`), and a bare area,
  place or placeholder id means the variant's zone. The counts, the item
  ids, the rewards, the levels and the requirements are the quest's own,
  the same in every variant. The map's targets and the "Return to" line
  follow the variant the player took.
- **Where it lives.** A shared quest lives in the quest file of its first
  variant's zone (`E-variant` elsewhere), so every tool that reads quests
  per zone file finds it in a real zone; `tools/r28_design/r28common.py`
  (`zone_quests`, `quest_variants`, `quest_view`) gives the tools each
  variant as that zone's view, and the ledger counts it once per route.
- **Givers and turn-ins.** `givers` lists NPC ids or giver roles,
  `{"role", "faction"}`: every quest NPC registered with that role and
  serving that faction gives it (bound once every mod is loaded; the camp
  foremen, "The Miner's Guild givers"). `turnins` defaults to the givers.
  An NPC gives a quest in one variant only, so the giver a player takes it
  from names the variant; the active quest keeps it (`variant`, `giver`)
  and is listed and handed in only at that variant's turn-ins. An active
  entry saved without a variant follows the first one.
- **Hubs and lines.** Each giver NPC of a variant is a hub giver of the
  variant zone's file (`E-giver-not-hub`), so a shared quest is given in
  several hubs while an NPC still gives quests in one hub only
  (`E-giver-twice`). The quest's `line` is one name, one of the (at most
  two) lines of every giver NPC that gives it; a role giver has no hub and
  no line check.
- **Factions.** A shared quest may span both factions (the start quests in
  three Accord and three Throng towns): every giver has at least one
  turn-in of its own faction in its variant (`E-turnin-faction`); the
  dialog still serves only the giver's faction.
- **Texts.** The text a player reads is the giver's own (`texts` by the
  giver's NPC id), else its race's (`texts` by race id: the giver's race),
  else the variant's `text`, else the quest's; the completion text the
  variant's, else the quest's. Placeholders resolve in the variant's zone.
  A shared quest has one name: its title takes no placeholder.

### Group quests

An elite group quest ("Party:" in its title, the design note `group`)
asks for more than one player. **Below level 51 a group quest is always
optional** (the user, 2026-10-25: the player base is small, and a partner
of the same level online at the same time is rare; from 51 a max-level
helper is easier to find):

- it is free and standalone: it requires nothing, no quest requires it,
  and no story step, travel or departure needs it;
- it never carries a zone's only key reward: the zone's weapon sits on a
  solo quest, and the group quest gives an extra (in the band 31–40 a
  choice of plain tier-4 trinkets);
- the questing share is met without it (the solo ledger skips group
  quests, `tools/r28_design/ledger.py --party solo`).

From level 51 a group quest may stand on the story path. The rule holds in
the reworked files (all 48). In the quest data (22 group quests): none
below level 20; below 51 the Expedition quest at 20 and at 40 ("The
capitals"), the band 31–40's six at 39 ("The band 31–40") and the front's
two at 50 (`front_engine_nine`, `front_last_toll`, each shared by both
factions, "The front 41–60") are free, require nothing and are required by
nothing; the twelve at 59–60 are the elites Salt-Counter and Glass-Throat
per faction (standalone), the island elites (each the one follow-up of its
bounty), the main line's four, two of them on the path to the final
turn-in (`accord_main_collector`, `throng_main_finale`), and the level-60
Expedition quest (free).

### System quests

A **system quest** is registered by code, not by a quest file: it has no
quest giver, no turn-in NPC, no objectives, no quest drops and no choice of
rewards (mail plan ruling 17.2, [mail.md](mail.md) §8). The mod that owns
it accepts it through the normal accept (the 20-quest log limit holds) and
turns it in through the normal turn-in, so its rewards, the turn-in hook
and the achievements work as for any quest. It is ready to turn in from
the start. Instead of "Return to <NPC>" the tracker shows its own turn-in
line (cut to the tracker's width like every line) and the quest log shows
it as a sentence in the text field, where the objectives stand; no NPC and
no map target is marked for it. No quest file can require it.

The one system quest is the starter quest `mailbox_visit`, "Use a mailbox
in one of the cities" (level 1, both factions): turn-in line "Open a
mailbox beside the waystone of a capital or a starting village", turned in
by opening any mailbox; reward one kill equivalent at level 1 (30 XP) and a
fixed 25c (`rewards.copper`, the first letters' postage). It is turned in
without a dialog, so its completion line (grug_mail's) goes to the message
feed with the turn-in; a quest-file quest shows its completion text in the
turn-in dialog ("Completion text"). The quest tools (`validate.py`,
`ledger.py`, `income.py`) read only the quest files, so they do not count
it.

## Objectives

Objective families are **item turn-in**, **kill**, **travel**
(conversation) and **use at a place** (a quest object held at a place; the
user's ruling of 2026-10-05). A crafting lesson requests the resulting
item, never provenance. No crafting, mining, node-digging, arrival or
escort objective engine exists; "use at a place" writes no node (its object
is an entity).

- **Several objectives per quest**: the dialogue and the quest log show one
  line per objective, the HUD one compact line.

### Kill

- **Kill**: a list of roles (entity `grug_mobs:<role>`; a sub-type is its own
  role, so a quest meaning a whole family lists its roles) and a count,
  optionally with one area: a kind or a camp of the zone's spawn recipe
  (`zone_id/kind_id`, [spawn_regions.md](spawn_regions.md)). The roles and
  the area **select names**, they do not limit the count: the objective
  counts every mob that shows one of the selected names, wherever it spawned
  ("The quest-name guarantee"). A named leader stands at a rule-placed spot
  without an area; its kill objective names no area. In a zone with a spawn
  recipe only the recipe's roles appear on the surface; a kill objective
  there whose roles the recipe never spawns and none of which is a leader (a
  leader of any zone counts: a front file names the front's leaders) is
  reported as a load-time warning (W-recipe-target). Critters are never kill
  targets (Ruling 29), nor rares (Ruling 38).
- **PvP garrison kill**: the area may also be a PvP POI's garrison,
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
- **Kill credit** uses the same per-mob damage/effective-healing
  participation and eligibility mechanism as shared XP, never a
  killing-blow test and never party membership. Players from different
  parties are not a special case. Sharing credit does not divide quest
  counters: one eligible kill is one count for each relevant active quest.
  XP splitting itself stays unchanged.
- Do not use `xp > 0` as the sole participation test: gray-level XP
  suppression must not accidentally hide the shared eligible participant
  event from quests. Quest level/prerequisite and target rules remain
  independent.
- Kill counters start at acceptance.

### The quest-name guarantee

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

### Item

- **Item**: one item, or any member of an item group (`group:tree`: "any
  log"), and a count. Objectives of one quest draw from the holdings in
  order, so two objectives never count the same item twice; held items are
  allocated exact items first, then groups, and the turn-in takes exactly
  what the progress counted. An item that mobs drop (a family drop such as
  a boar tusk) may name its source: `roles` and optionally one `area`,
  checked like a quest drop's source and shown only as the level range (the
  item counts however it was obtained).
- Item turn-ins accept already-owned and traded/crafted-by-others items;
  worn qualifying items remain acceptable. Descriptions say "Bring ..."
  instead of claiming to verify personal crafting. Requirements match a
  registered item id (or any member of an item group) and a count only,
  with no wear, enchantment, quality or provenance predicates.
- Count and consume from main inventory and the player's owned bag contents
  through existing inventory APIs; do not reach into equipment, stations,
  chests or another player's inventory. Recheck at turn-in, not only in the
  UI. Item readiness reflects current holdings.

### Quest-only drops

`quest_drops`: an item that drops only while the quest is active and the
player still needs it, from the listed roles (optionally one area; like a
kill, they select the names it drops from), with a 1-in-N chance. It is
rolled **per eligible participant** who has the quest (the participants of
kill credit), goes straight into that player's inventory or bags and posts
a loot line to the message feed, so a party never competes for it. Each
quest drop pairs with an item objective of its quest. A quest-only item is
soulbound (round60-plan.md §2 point 10: `items.json` kind `quest`, group
`grug_soulbound`): never in a chest, station, mail, trade or the trash;
dropping it destroys it. So it is never dropped at the feet: while it would
not fit nothing is rolled and the feed says "No room for …; it can drop on
a later kill."

### Travel

One conversation, the quest's only objective, credited on accept (Ruling
39): the destination NPC shows its yellow "?" at once and the HUD reads
"Travel to <NPC>". The turn-in still needs the visit. A travel handoff
contains exactly one conversation with the named destination NPC, who also
accepts the turn-in: no hidden item, secondary errand, arrival-radius check
or return trip. The ordinary Complete button at the destination awards the
rewards.

### Use at a place

The player goes to a place and holds an interaction there (round36-plan
§2.5). The objective names the `place`, the `object` kind shown there, the
act's `label` ("Light the signal fire") and its `hold` (whole seconds,
1–15); it counts once (`count` 1 or left out).

- **Place:** a clash site by its settlement key (`r20_anchor_071` …
  `r20_anchor_086`, world_zones.md §16: Ashenward March, Bannerbreak Mesa,
  the four Battlegrounds zones and both islands), or a quest place of a
  spawn recipe, `zone_id/place_id` (a bare id: the quest file's zone),
  placed per seed like a kind leader ([spawn_regions.md](spawn_regions.md)
  step 8 and `places`); the four contested zones without a clash site have
  one each for the main line and a second for the band 31–40, and
  Ashenward March and Bannerbreak Mesa one each for chapter 3. Or a **town
  place** ("Town places" below): a socket of a settlement,
  `socket:<settlement key>/<socket id>`, a spot in a capital, a village or
  a POI. No mapgen writes.
- **Quest object:** an entity at the place, added while a player who still
  needs the objective is within 48 nodes (the active-block reach) and seen
  only by such players (`set_observers`); several players with the quest
  see and use the same object, the last one leaving removes it, it is
  never saved. It stands on walkable ground under open air (grass and
  flowers allowed) at the place or the nearest such column within 6 nodes
  (a place without one logs a warning once and is searched again every
  10 s), the n-th act at one place 2 nodes beside the first. At a town
  place it stands in the socket's own cell instead (no open air asked for,
  no column searched), the n-th act on its ring cell 2 nodes beside at the
  socket's height when that cell is free over walkable ground, else in the
  socket's cell. Its nametag is the label. The object's look is a kind of
  `grug_quests/data/use_objects.json` (one texture and a size per kind,
  the one place the texture names live), each drawn by
  `grug_quests_obj_<kind>.png` 1–1.4 nodes wide (the kinds and what each picture
  shows: `grug_quests/LICENSE-media.md`). Every aiming ray of a player who does
  not see it (combat, hand clicks and the crosshair's interact colour, a
  skill item's right-click) passes through it.
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
- **Checks:** an unknown place (`E-use-place`; a town place: no such
  settlement, no such socket, a socket of another role, or a capital plot
  not every world builds) or object kind (`E-use-object`), a hold outside
  1–15 s, a count other than 1, a missing label, and kill or item fields on
  it (or its fields on another kind) stop the load (`E-objective`). The
  ledger counts no XP for it: the trip and the hold are the quest's time,
  paid by its reward weight.

#### Town places

The socket role **`quest_place`** (the settlement socket registry,
`grug_core/settlement_sockets.lua`; nobody stands on it; round59-plan.md
§2a point 1) marks a standing cell as a quest place. It goes where the
settlement's other sockets go: in a capital a `sockets` point of a building
template, `sockets <x> <y> <z> face=<0-3> id={id}_<name> role=quest_place`
([building-template-format.md](../technical/building-template-format.md)
§3; a Miner's Guild house through `tools/r58_halls/make_halls.py`) or a
plot's `extra_sockets` row; in a village, outpost, camp or POI a socket
row of its blueprint (`role = "quest_place"`); in a start town an entry
of the town's own socket list (`wp13/<town>.lua`; a start town's
template points carry only `id` and `face`, so a role written in its
template is not published, §3.4 of the format). The quest data writes
**`socket:<settlement key>/<socket id>`**, the id as the registry has it: a
capital plot's socket carries its plot id
(`socket:highcourt/miners_guild/miners_guild_cellar`), a start town's,
village's or POI's its own (`socket:goldmead_village/well_yard`). Next to
the other places: a clash site is a bare settlement key, a recipe quest
place `zone_id/place_id`, a town place always carries `socket:` and the
settlement key (never a bare id; a variant's override writes it whole).
A settlement with no NPC socket (a clash site, a rare's or a dragon's
POI, an apex mine, a mirefolk or Round 20 bandit camp) may carry one too:
the settlement NPCs (`grug_mobs/start_npcs.lua`) treat a settlement
none of whose sockets anyone stands on as scenery, silently.
It is found on every world, where the settlement is: in a capital only
in the core or a plot the planner always places (the inn, the eight
service plots and the Miner's Guild house,
`grug_mapgen/wp13/capital_services.lua`). Its name is the
settlement's ("Search the cellar at Highcourt"), its map marker the
socket's cell, and like any socket it is a standing point (the template
validator's rule). A town place is no placeholder target: a text names
the building in words ("the guild house's cellar"); the map shows the
spot. `tools/r59_qsys3/socket_places.lua` lists a settlement's sockets
as the mapgen builds them for the offline tools. The town places the
chapters use: [settlements.md](settlements.md) "Chapter 1's town places"
and "Chapter 2's town place".

## Givers, acceptance and turn-in

### Acceptance

- **One acceptance rule** (Round 65 ruling 3): a quest is accepted from its
  quest level − 2, at least 1, every kind alike (story, departures, group,
  guild, front, system quests); the quest data names only `level`
  (`grug_quests.acceptance_level`, `r28common.acceptance_level`; a stale
  `min_level` is an `E-levels` error in both validators). Every quest
  description includes its minimum level and the titles of its prerequisite
  quests.
- Dependent quests remain hidden until every prerequisite has been turned
  in. Acceptance or completed objectives alone do not reveal successors.
  Once its prerequisites pass, a quest the level still holds back is not
  listed; it counts toward the giver's hint line and the silver "!"
  ("The giver's dialog", "Quest markers").
- Exactly 20 active quests maximum; accepting beyond that is refused with a
  clear explanation. Completion or abandonment frees a slot.
- Abandoning a quest removes its counters, not ordinary player items. It
  may be accepted again if prerequisites still hold.
- Repeated packets and repeated dialogue clicks must not duplicate rewards.
  Persist active/completed state and HUD preference across
  reconnect/restart.

### Givers

- Quests carry no race or faction gate of their own; the giver's faction
  decides (PvP ruling 13): a giver serves only its own faction, the faction
  of its race (a new giver's own race, else its settlement's), and the other
  faction gets the shared refusal line ([settlements.md](settlements.md)).
  Dialog, floating symbols and atlas use the same visibility: the other
  faction never sees a giver's marker. Every giver has a turn-in NPC of its
  own faction (checked at load, per variant of a shared quest).
- NPCs with multiple quests offer a simple list; independent tasks can form
  bundles without a separate bundle engine.
- Keep existing regional giver identities and add hosts at authored
  peaceful villages, outposts and mining camps. Existing hostile camps do
  not acquire friendly quest hosts; the captive at each band 11–20 bandit
  camp (`r14_<race>_captive`, Rounds 14–15) predates this rule and stays.
  New givers stand at a free quest socket
  of the hub's settlement ("Quest data (per zone)").

### The Miner's Guild givers

Registered in code (`grug_quests/npcs.lua`), like the fortress givers: the
camps are the world's (`grug_mapgen.mining_camps`), and a camp's gather
quests are bound to the depth, not to a zone ([miners_guild.md](miners_guild.md)
§11). Each foreman is a hub giver of its camp zone's file (a Battlegrounds
zone's file holds its eight; lines `camp` and `guild`), so the quests that
name it by id are given in its zone. The design tools know them from the
camp catalogues and `npcs.lua` (`tools/r28_design/r28common.py`
`guild_quest_npcs`); a portable harness that loads the shipped files gives
`npcs.lua` the camps and capitals with `tools/r58_guildquests/guild_world.lua`.

- **The foremen:** one per mining camp and war camp (36), id
  `r58_foreman_<camp id>` (the camp ids of `grug_mapgen.mining_camps`), on
  the camp's `quest_foreman` socket, titled "Foreman" (the four foremen the
  story names carry their names, a per-camp title in `npcs.lua`: Brodd
  Deeppeg of Frostbarrow Shelf's camp, Rellis Shalemark of Ossuary Reach's,
  Audra Wainholt of Ashenward March's and Greda Stonehaul of Bannerbreak
  Mesa's, their ids kept), of the camp's race and faction, with the giver
  role **`foreman_t<tier>`**: the camp's zone tier, which its deepest lift
  reaches (`foreman_t2` … `foreman_t6`; 3/4/3/4/4 camps per faction for
  T2…T6). A guild quest of tier k lists the role rows
  `{"role": "foreman_tk", "faction": F}` … `{"role": "foreman_t6",
  "faction": F}` in the variant of faction F (one variant per faction), so
  every own camp whose lift reaches tier k gives it and turns it in, and each
  foreman stands in one variant only (`registry.lua` `bind_role_givers`
  asserts it); no tier filter exists in `grug_quests`. A camp's own quests
  (its kill quests, the T4 foreman's raid) name its foreman by id.
- **The guild leaders:** one per capital, id `r58_guild_leader_<capital
  key>`, on the guild house's leader socket (`capital_services.GUILD_HALL`
  `leader`), of the capital's race and faction, named as the story names
  them: Alis Cartwright (Highcourt), Hadrin Beamset (Dur Brannoc), Caelir
  Veinward (Lethariel), Iven Lastshift (Nhal Veyr), Drava Flintshoulder (Gor
  Drazhak), Ombali Ropekeeper (Kezamba). No role: a follow-up's talk
  objective names its race region's leader by id. Each is the one giver of
  a hub of its capital's file ("Chapter 1 in the capitals").
- Like every quest giver, both serve only their own faction.

## The journal, markers and tracker

### The giver's dialog

- Quest lists (the quest giver's dialog and the quest log) show each quest's
  status as the entry's colour, explained by a legend or the list's tooltip:
  available gold, ready to complete green, in progress blue. No list shows
  a quest the player's level holds back (Round 65 ruling 1): below the
  giver's list one grey line, never selectable, reads "More quests at
  level N.", N the lowest acceptance level among the giver's quests that
  only the level holds back (prerequisites met, not active, not done). A
  giver with only that line still opens its dialog: the line, a detail pane
  saying at which level to come back, no Accept; a giver with neither rows
  nor line does not open. Inside each category the giver's list sorts
  ready, then acceptable, then in progress, then by quest level and title
  (Round 65 ruling 5).
- Once a story quest is listed (Round 57 ruling 13), the list has two
  categories: a "Story" header in the story violet above the story quests
  and a "Side quests" header above the others, their titles set in; every
  entry keeps its status colour and a click on a header keeps the quest
  shown before. Help → Quests names the story symbols and the category. The
  giver's dialog is wide enough for the longest title at a full-HD window;
  quest texts are read-only.
- The giver's dialog opens on the first quest ready to complete, else the
  first one to accept, else the first in the list, and preselects the same
  way after every Complete and every Accept, so several finished quests are
  handed in by clicking "Complete" and several offers taken by clicking
  "Accept" again and again; after an Accept with nothing ready or acceptable
  left it stays on the accepted quest, and a failed Accept or Complete stays
  on its quest (the user, 2026-10-10). A click in the list shows the
  clicked quest.

### Completion text

A quest may carry `completion`, a short closing paragraph. At the turn-in
NPC, while the quest is ready, the dialog shows it in place of the quest
text, above the objectives and the rewards. The quest log keeps the quest
text. A system quest has no dialog: its mod posts its own completion line.

### Quest markers

- Quest-giver markers are attached floating 3D question/exclamation symbols
  with `set_observers()`. Use the existing tag visibility/hysteresis loop
  and distances, not a second independent all-players scan; keep per-viewer
  states. The symbols are five times their original size, their upper
  extent held fixed (they grow downward).
- Marker precedence: ready to turn in (yellow question mark), available
  (yellow exclamation mark), active but incomplete (silver question mark);
  with none of these, the silver exclamation mark when the giver's next
  quest (the hint line's level) opens one or two levels above the player's
  (Round 65 ruling 2; the marker value `locked`), otherwise none. A level
  change recomputes the markers.
- Story quests have their own marker (Round 57 ruling 13): the same symbol
  with the ordinary gold/silver glyph and a violet story star, so the
  status still reads on its own. The most urgent status of a giver wins
  first, and a story quest of that status makes it the story marker: a
  ready side quest beats an available story quest. The map window and the
  minimap draw the same values with their own icons
  (`grug_map_quest_story_<status>.png`, `tools/r64_map/ship.py`).

### The quest log

The quest log supports viewing and abandoning quests. It is part of the
map window (Z or the Map & Quests tab,
[world_map.md](world_map.md#map-window)): right of the map, the list box
with the active count, the Quest HUD switch, the list and one row with
"Track on HUD" on the left and Abandon on the right (while Confirm abandon
and Cancel are shown they take the row alone); below it the selected
quest's title, its level and zone (a shared quest's: the zone of the
variant the player took), one
scrolling text field with the description, the objective lines and the
reward line, separated by an empty line each, and where to hand it in.
Selecting a quest marks its targets on the map (leader, talk NPC and use
place crosshairs, rings around the nearest spawn regions;
[world_map.md](world_map.md#quest-targets)). The list has one compact line
per quest (its state marker, the title and "[Lv N]" in the difficulty
colour, like the tracker; the state and tracking in the row's tooltip;
Round 67 ruling 19), its Story and Side quests groups each sorted by quest
level, ties by title, then id: the tracker's order.

A quest HUD toggle lives in the quest log, defaults on and is saved per
player. No active quests means no quest HUD, without changing the saved
preference.

### The HUD tracker

Track up to ten selected quests on the HUD (Round 24 ruling 23; one
constant for the tracker, the auto-track on accept and the quest-log
notice). Each tracked quest is one box (Round 65 ruling 4): a
semi-transparent panel (the UI theme's dark panel colour at 30 % opacity;
the text stays opaque), in its top row the title left aligned in the
theme's light text colour, cut with "..." so it never reaches the level
label, and the quest level right aligned as "[Lv N]" (`def.level`, the
number the quest log shows) in the target frame's difficulty colour
relative to the player's level (`grug_xp.con_color`: gray at ten or more
levels below, green to yellow to red; it follows a level change); below it
the objective line in the quest yellow (e.g. "0/10 Bring Raw Meat"; with a
named source "0/1 Runner's Packet from Trench Archer"). The boxes follow
the quest log's order (Round 67 ruling 19a, one shared sort,
`grug_quests.sort_quests`): story quests on top, each group by quest level,
ties by title, then id, without group headings, so easy and hard quests
read at a glance.

All boxes share one width (the side text width, 38 characters at most)
and stand at the right edge with edge padding, centred on the screen's
middle where they fit, clear of the top-right minimap; as many show as fit between the
minimap block (its box, location line and the "Now playing" box while it
shows) and the bottom of the screen, or the bottom-centre column where a
box would reach over it (the XP row's label, the status icons and the
feed); the rest are one line "+N more" (the quest log lists them all). Ten
fit at 1920×1080 at GUI scaling 1; 1280×720 shows seven, six with "Now
playing" (`grug_core.hud_layout.quest_boxes`, `tools/r65_hud`).

A quest ready to turn in shows "Return to <turn-in NPC>" (a system quest
its own line, "System quests"; a shared quest the turn-in of the variant
the player took, the giver it was taken from when that giver is one of
them: a role quest's turn-ins are every foreman of the role). The same NPC
carries the map's hand-in marker. A quest with several objectives shows
them on one compact line ("Wood Axe 0/1, Wood Pickaxe 0/1") and a travel
quest reads "Travel to <NPC>". Two quests with identical objectives show
the same objective line. Keep the tab authoritative; do not place the
entire journal permanently on screen.

### Objective presentation

Progress appears in the message feed (`inventory_equipment.md`, "Message
feed"): whenever an objective count rises (kill credit, an item gained, a
conversation, a finished use), the quest posts one line with every objective as
"<name> n/m" ("Barley Piglet 3/10"), replacing that quest's previous line.
Accepting a quest and falling item counts post nothing; nothing goes to chat.

Kill objectives name each target by the name the mob shows ("The
quest-name guarantee"): the names of the slots the objective's roles and
area select ("Yam Piglet" in the Kapok Cradle); the dialogue, the quest
log, the tracker and the message feed share that label. A PvP camp's
captain reads as he is named on this world (his camp's race). Item
objectives show the concise item name, not description stat/durability
lines; an item objective's named source must really drop that item at the
levels it is met (`E-item-source-drop`). Such an objective, its source being
its own `roles` and `area` or a quest drop of its item in the player's
variant, names it in the quest log and the map's tooltips, "Bring
Runner's Packet: 0/1 (from Trench Archer) (level 38–40)", with the names the
drop counts (`Q.target_names`), in the giver's dialogue, "Bring Runner's Packet
× 1 (from Bandit Fletcher) (level 38–40)", which shows the variant that giver
gives, and on the tracker, "0/1 Runner's Packet from
Trench Archer" (the line of several objectives stays the compact one, which
has no room for it). The map marks that source
([quest targets](world_map.md#quest-targets)); a role that selects no name
stops the load (`E-no-name`). Starter kill/drop targets follow the
minimum-level-aware local wildlife roster and remain locally achievable.

**Level ranges**: names carry no signal words
([biomes_mobs.md](biomes_mobs.md) "Names"), so the offer dialogue and the
quest log show each objective's target levels after it, in the objective's
own colour: "Defeat Barley Piglet × 8 (level 1–2)", "Defeat Barley Piglet:
0/8 (level 1–2)", "(level 10)" for one level. Per role, first match: a
leader's fixed level; in the objective's area that role's levels there (not
the whole kind's); the role's levels in the kinds and camps of the quest
zone's recipe; its catalogue levels within the quest level ±3; a base mob
(no catalogue row) in a zone without a recipe: the zone's level band within
the quest level ±3 (a base mob adds nothing in a recipe zone). The objective
shows the union over its roles; a kill objective also adds the levels of
every slot that bears its names (every such mob counts). The load check's
level fit (`E-level-fit`) stays on the selected levels. An item objective
shows the range of its quest drops' roles and of its named source; plain
gathering, crafting and travel objectives show none. The ranges are
computed once at load. The HUD tracker keeps its compact line without a
range: added, it would cut 22 of the 204 tracker lines shipped when this
was decided at the 38-character width instead of 2.

## Rewards

- The reward XP is `grug_xp.quest_reward(level, weight)`, the authored
  weight in kill equivalents at the quest's reward `level`
  ([progression.md](progression.md)); the receiver's current level never
  changes the reward.
- One-time XP/coin/item rewards, with all prerequisites, consumed items and
  reward space (the picked choice included, "Choice rewards") preflighted
  together; insufficient space refuses the turn-in without consumption or a
  dropped reward. A quest reward never waits in the mail or in an escrow:
  it is paid at the turn-in or refused (the mailbox, [mail.md](mail.md),
  carries letters, not quest rewards).
- The equipment a zone and level band may reward is capped
  (`E-reward-budget`, "The rework flag"), and a reward is never a requested
  item (`E-reward-requested`).

### Copper

`rewards.copper` is optional. Without it the quest pays
`round_half_up(0.08 × P(T) × weight)` copper, at least 1c for a weight above
0 (none for weight 0), with P = 25 / 65 / 160 / 400 / 1,000 / 2,500 for the
reward level's tier band T (1–10 … 51–60; the WP44 cutover column,
[economy plan](../planning/economy-vendor-plan.md) §4): a T1 3-KE hunt pays
6c, a T6 one 6s. Write `copper` only for a deliberate exception (an island
salvage bounty of weight 0).

### Choice rewards

- `rewards.choices` lists 2–4 rewards, `{"item", "count"?, "affixes"?}`;
  the player picks one at the turn-in. Every player sees the same choice
  (no class filter); an equipment choice offers one item per armor class
  (cloth, leather, metal) or one weapon per weapon line.
- **The offer** shows the choices as item icons with their tooltips, and
  lists them in the reward text ("and one of:", one per line) by the name
  the made stack shows (its enchant words) with its enchant lines, so the
  enchants read without hovering (the user, 2026-10-23).
- **The turn-in** shows them as item buttons with their tooltips above the
  Complete button; a click picks one (framed and named, "Chosen: …"), and
  the text starts with the picked stack's whole tooltip (item level, stats,
  enchants); before a pick a hint says so.
  Complete refuses until one is picked ("Choose your reward first."); the
  preflight checks room for the picked reward, and a refused Complete keeps
  the pick. A system quest never carries a choice.
- **Equipment rewards** (a choice or `items`) are made at the quest's
  reward `level` as their item level, with the author's fixed enchants
  (`affixes`: `{"channel": "prefix" | "suffix", "stat"}`, at most one per
  channel, each in the item's enchant pool for that channel), never random
  ones, each of the item level's tier: `grug_items.make_stack`
  (grug_quality, the one store path: values, quality, name, tooltip).
  Every reward stack gets the receiver's tooltip as `grug_inventory.give`
  initialises one (the weapon's "Effective at level" line).
- **Tooltips.** Item buttons and images show their definition's
  description, never a stack's meta, so the dialog's tooltips are
  `grug_items.tooltip_text` of the stack the player would get (the shared
  helper; the recipe details use the same).

## Quest data and validation

### Quest data (per zone)

Quest content is data, one file per zone, read at load by
`grug_quests/loader.lua`:

- `mods/PLAYER/grug_quests/data/zones/<zone_id>.quests.json`: the zone's
  hubs (at most two givers per hub, at most two lines per giver), their givers
  and lines, the file's rework flag (`"reworked": true`, "The rework
  flag"), and its quests (format: design frame §4.7: `giver`, `turnin`,
  reward `level` (accepted from `level − 2`; no `min_level`),
  `requires` across zones, `objectives`,
  `quest_drops`, `rewards` with `weight`, optional `copper`, `items` and
  `choices`; `variants` in place of `giver` and `turnin`, `texts`,
  `story`, `completion`; the design notes `lesson`, `duration_min`,
  `optional`, `climax`, `group` and `notes` are allowed and not read;
  `tags` is a list of snake_case names the achievements count,
  below). Any other field of a quest, an objective, its rewards, a choice,
  a variant or a quest drop stops the load (`E-unknown-key`): among the
  retired fields are a fixed reward `xp`, `faction`/`race` gates, kill
  objectives by entity names (`mobs`) or zone filter (`zone`) and
  `repeatable`.
- `<zone_id>.front.quests.json`: front quests given by that zone's givers on
  the line `front`, which the zone's own file declares for that giver; the
  zone's own quests never use `front`.
- The four Battlegrounds zones have a quest file of their own (their war
  camps' foremen and quests), and the two **guild files**
  `charter_of_stone.quests.json` and `oathdelvers.quests.json`, whose zones
  are the guilds' ids (`grug_guild` catalogue `GUILDS`), not map zones: the
  home of the gather quests that the foreman roles give in every own camp
  ([miners_guild.md](miners_guild.md) §11). A quest in a guild file shows
  only its level in the quest log (no zone), and the leveling routes of
  `ledger.py` pass no guild file.
- New givers stand at a free quest socket of the hub's settlement
  (`{"npc", "new": {"name", "race", "socket", "role"?}, "lines"}`): the
  socket-bound NPC system places the quest giver there with that name and
  race; the race sets the giver's faction, so a giver of the other faction
  can stand in a settlement (a spy). The optional `role` makes it
  one of a giver role's NPCs ("Shared quests"); a code-registered NPC
  names it in `grug_quests.register_npc`.
- The loader checks every file at load and stops the server with every
  finding listed, each naming the file and the quest: givers and lines per
  hub, front lines, objective shapes, known NPCs, items, groups and roles,
  critter targets, areas that host their target, quest-drop pairing, the
  level fit (every level a target, quest-drop source or item source is met
  at lies within the quest's reward level ±3; a target that stands in an
  Expedition, no zone hosts it, is listed in both validators'
  `EXPEDITION_TARGETS` and counts as met at the Expedition's first level,
  a run's level being the player's choice), the variants, the faction
  pairing per giver, the choices and their enchants, and the rules of "The
  rework flag" below. `tools/r28_design/validate.py` checks the same rules
  on the design files (the enchant pools excepted: the game's
  `grug_items.check_affixes`), plus the atlas checks.
- **Chapter chains**: `requires` crosses files. A quest behind an unmet
  prerequisite is not shown anywhere (list, hint line, marker), so a step
  may open (its level − 2) below its prerequisite's level. The main line's
  chapter gates: "The main line".
- **Turn-in hook and tags**: `grug_quests.register_on_turn_in(fn)`
  calls `fn(player, quest_id, def)` once per completed turn-in, after the
  state and the rewards are stored; a refused
  turn-in calls nothing, and a failing observer keeps neither the others nor
  the turn-in from completing. `grug_achievements` counts through it
  `quest:<quest id>` (that quest's turn-ins; a one-time quest's achievement
  has `at = 1`) and `quest_tag:<tag>` (turn-ins of quests whose `tags` list
  it), each only while an achievement asks for it
  ([character_visuals.md](character_visuals.md) §5b).
- **Zone files depend on each other.** `requires` crosses
  zones: a race's home-zone file requires quests of its start zone, and a
  front file needs its host's `front` line. Removing a required quest or a
  host's `front` line stops the load, so replace dependent zone files in one
  change (or keep the required ids).
- **Ids:** when a band is rebuilt, a quest whose objectives stay keeps its
  id (cross-lane ids another quest requires may also stay with changed
  objectives, recorded in the upgrade contract); every other quest is new
  and the old ids are dropped (upgrade contract §4).
- **The JSON files are the source**, texts included. Each band's
  `build_structure.py` (`tools/r57_startquests`, `r59_bandquests`,
  `r59_storyquests`, `r60_bandquests`, `r60_capitals`, `r61_bandquests`,
  `r62_frontquests`) wrote its band's structure once with placeholder
  texts: a rerun writes the placeholders back, and its `--check` compares
  the structure only. The band's `portable_test.lua` checks the shipped
  files.

### The rework flag

A quest file with `"reworked": true` follows the rules the quest rework
introduced; all 48 quest files carry it, and nothing of this section ever
reports an unflagged file (the Battlegrounds files' guild quests are free
play by construction, checked by `tools/r58_guildquests`). A `.front` file
carries the flag beside its `zone` and `quests`. In reworked files (both
validators, the same codes):

- `E-free-requires`: a free quest requires at most one quest, the one it
  follows; only story quests chain;
- `E-free-follow-ups`: a free quest is required by at most one quest of a
  reworked file per faction ("Story and free play"; the game checks it once
  the givers' factions are resolved, `validate.py` reads them from the item
  dump's quest NPCs, the fortress and guild NPCs, a new giver's race or the
  atlas, and an unknown one counts for both);
- `E-free-chain`: a free follow-up has no free follow-up of its own;
- `E-reward-budget` (Round 57 ruling 17): per zone and level band (the band
  `(level − 1) // 10` of the quest's reward `level`: 1–10 … 51–60, the same
  in both validators), capitals excepted, at most two quests with an
  equipment reward of one enchant and one with two enchants (counted in
  every zone a shared quest is given in); `W-reward-levels` when two of one
  kind share a reward level there;
- `E-reward-requested`: a reward (an item or a choice) is never a requested
  item, nor a member of a requested group;
- `W-night-count` (Round 57 ruling 12; a day lasts 15 real minutes, a night
  5): a kill objective whose targets spawn only at night asks 20–50 % of
  the median count of the zone's day kill objectives (leaders left out).

## For content lanes

How to author quests and their texts. Before rebuilding a band, read the
Id rule and "The JSON files are the source" in "Quest data (per zone)".

- **Outings, not chores.** Compatible tasks share an outing; avoid repeated
  returns for increasing counts of the same mob. Opening kill lessons use
  common mobs and small counts (e.g. five boars); avoid five low-drop-rate
  tusks as the first mandatory task.
- **Crafting stays optional.** Explain optional crafting through a side
  branch; do not force every player to craft as a prerequisite for the
  local combat story. Optional item/cooking lessons do not block the combat
  story or implicitly require a profession (`tools/r45_st` refuses an item
  objective naming a profession's product); the one exception is the
  capitals' Alchemy lesson `capital_precision` ("The capitals"), which asks
  for a tier-1 elixir and names the trainer who teaches it for free.
- **Ordinary hand-ins.** Author hand-ins around ordinary resources and
  basic Wood/Stone tools; do not request valuable enchanted gear.

### Text rule

Quest texts follow the user's text rule (2026-10-02): English, two to four
sentences, the giver's race voice, light humour welcome; items by name
only, **never an item's tooltip text**; directions and places that depend
on the seed only as **placeholders**, never a fixed compass word.

### Placeholders

Placeholders in `title` and `text`, filled per world from the spawn
regions and leader spots ([spawn_regions.md](spawn_regions.md#directions)):

| Placeholder | Reads | Use for |
|---|---|---|
| `{dir_from_giver:T}` | "southeast from here", "nearby" | compact targets: camps, leaders, shore strips |
| `{dir_of:P:T}` | "southeast of Highcourt", "near Highcourt" | any target, from a named place |
| `{zone_area:T}` | "in the southeast of Dawnmere Fields", "in the heart of Dawnmere Fields" | open kinds spread over many patches |
| `{name:T}` | "Dawnmere Meadows", "Crumb" | the display name of a kind, camp or leader |
| `{captain:T}` | "Captain Vrakk" | a PvP camp's captain (T its settlement key) as named on this world |

- `T` is a kind or camp of a spawn recipe, a leader role, a PvP POI (a
  fortress or Battlegrounds camp by its settlement key), or a place of a
  "use at a place" objective (a recipe's quest place,
  `{name:brandscar_cairn}` "Brandscar Cairn", or a clash site by its key,
  `{name:r20_anchor_076}` "Saltgate Remnant"; a town place is none). A bare
  id means the quest file's zone; another zone's kind, camp or quest place
  is written `zone_id/id` (`{zone_area:elandor_whitebridge_shire/oakwood}`);
  a leader role, a PvP POI and a clash site are found in any zone. A PvP
  POI reads its label (`{name:pvp_fortress_accord}` "Ashenward Bastion")
  and points at its anchor.
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

### No fixed compass word

No fixed compass word in a title or text: north, south, east, west, the
four diagonals, and their -ern, -erly, -ward, -wards, -bound, -most,
-ernmost, -erner and -erners forms ("northbound", "southernmost",
"Easterners"), in any case and hyphenation ("north-east" counts). Only
whole words count: names such as "Northfold" or "Westbrook" are fine. Write
a placeholder or neutral wording ("past the mill", "along the shore"). So
no text names West Trench Mouth (its first word is a compass word).

### Checks

The game refuses at load every malformed placeholder, unknown
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

## Quest content by level band

The journey per race: the start zone (1–10), whose departure at 9 leads to
the steward of a band 11–20 zone; that band's departures at 19 lead to the
capital's envoy, where chapter 1 of the story opens; the capitals (19–30)
and the band 21–30 carry chapter 2, their departures at 29–30 lead to the hosts
of the contested band 31–40, which carries chapter 3; its departures at 40
and the free fortress calls (41, open from 39) lead to the front 41–60, the fortress quests and
the main line. Every band is built on the same rules: free play gated only
by level, only story quests chain ("Story and free play"), few kill
objectives and mob names per zone, and the reward pattern below. Which
quest a giver offers, with its objectives, places and rewards, is in the
quest files; the band records of the rounds that built them are archived
([quests-history.md](../archive/design/quests-history.md)).

### The start zones

The six start zones (levels 1–10: Dawnmere Fields, Hearthpine Vale and
Silverleaf Glades of The Accord; Sunscar Flats, Kapok Cradle and Stillgrave
Hollow of The Throng; round57-plan.md §2 rulings 9–12 and 15–18): every
quest is free play and there is no story quest; the story begins at the
level-19 handovers. Each town's two quest givers, the elder (lines `hunt`
and `tools`) and the cook (`pantry` and `kitchen`), offer their quests at
once, each gated only by its level.

- **Shared quests** for the tasks that are the same in several towns (the
  first hunts by day and by night, the crafting and smelting steps, the
  hunts that would be twins), one id each with a variant per town, each
  living in its first variant's file. The first day hunt and the first
  night hunt (`start_boars`, `start_rats`) are offered together. Nothing
  is handed in and given back (no tool swaps).
- **Local quests**: the zone's own hunts where no other zone hunts the same
  beast; the finale at the town's thieves' camp with its named leader; and
  the `*_departure` travel quest to the next zone's giver, the zone's one
  follow-up (it requires the finale; no quest requires a departure).
  Dawnmere's strand crabs and zombies live in kinds that are no quest
  target (no region on every seed), so Dawnmere gives neither the dead nor
  the crab quest and keeps its cook's shore-and-pasture errand.
- **Counts by phase** (ruling 12): the night's rats and the dead ask 3,
  about a third of the day hunts' 8.
- **Rewards** (ruling 18): `start_boars` a choice of 2 Healing Potion I or
  2 Mana Potion I; each zone's level-5 hunt an armor piece (cloth, leather
  or metal) with the class's main stat as its prefix, its level-7/8 hunt
  another slot with a suffix (mana, crit, maximum HP); a shared hunt has
  one slot wherever it is given; the finale one weapon per weapon line with
  a prefix and a suffix (a Wand or Staff, the Bow, a Sword or Battle Axe;
  the two-handed Staff where the Battle Axe is offered). Each zone gives
  two slots; the three Accord towns together give all four. The other
  quests pay XP and copper, the crafting ones their tool or station.

### The band 11–20

The six zones of levels 11–20 (Copperfell Foothills, Goldmead Vale and
Starbough Vale of The Accord; Mournfen, Redtusk Savanna and Raincall Basin
of The Throng; round59-plan.md §2, §2a), from the story chapter the user
picked: every quest is free play, nothing chains, a level-11 character
finds the zone's first quests (open from level 9) at once, without a
departure. The zone's own people give them: the village's steward and
local, the outpost's scout, the bandit camp's captive and the mining camp's
foreman. Each zone offers 13 quests.

- **Shared quests** for the tasks that are the same (the local's repair in
  all six zones, the load record and the held supplies at the zone's bandit
  camp, whose objects stand on town places of the camp blueprint
  `wp40/r14_poi_blueprint.lua`); the camp hunt and the guild report stay
  the guild's ([miners_guild.md](miners_guild.md) §11).
- **Local quests**: the witness (the scout's travel quest to the captive)
  and the named perpetrator (the captive's kill quest) are each zone's own
  story; so are the departure (level 19, requiring nothing, to the
  capital's envoy), the steward's handoff to the scout, and the zone's
  errands (gatherings and Basic recipes) and one day hunt in the middle
  belt.
- **Objectives**: 3 kill objectives per zone (the camp hunt, the day hunt,
  the perpetrator), so 3 mob names; no kill-for-drop.
- **Rewards** (ruling 18) at item levels 11–20 (tier-2 pieces, enchant
  tier 2): the steward's first quest a choice of 2 Healing Potion II or 2
  Mana Potion II; the day hunt an armor piece per armor class with the
  class's main stat as its prefix, the local's last craft another slot with
  a suffix (mana, crit, maximum HP); the perpetrator one weapon per weapon
  line with a prefix and a suffix. Each faction's three zones give all four
  slots.

### Chapter 1 in the capitals

The story arc's first chapter opens at the level-19 handovers in the six
capitals ([round59-plan.md](../planning/round59-plan.md) §2 and §4
STORYQUESTS; the user's chapter picks K1–K16, all "A", 2026-10-24). Four
story quests, one shared quest per faction and step, a variant per capital.

- **`story_accord_01` and `story_throng_01`** (level 19, no prerequisite):
  given by the faction's three envoys, a travel quest to the Miner's Guild
  leader of the giver's own capital, who takes the turn-in. The envoy
  speaks of a reported case and never claims the player helped the band's
  witness; the departures still travel to the envoys and are no
  prerequisite.
- **`story_accord_02` and `story_throng_02`** (level 20, requiring the
  first): given and turned in by each capital's guild leader, one use
  objective at the capital's **town place** (the same object and label in
  every variant, only the place differs; [settlements.md](settlements.md)
  "Chapter 1's town places"). At the turn-in the leader decides the
  capital's case (the right issue, a limited release, the foreign claim
  refused); where the abused papers come from stays open, pointing on to
  Frostbarrow Shelf and Ossuary Reach. No traitor and no wrong decision of
  one's own in this chapter.
- **Givers and lines.** Each faction's two quests live in the file of their
  first variant's capital (Highcourt, Gor Drazhak). The three envoys of a
  faction share the line `envoy` (with `front` they keep two lines), and
  each guild leader is the one giver of a hub `<capital key>_guild` of its
  capital (line `guild`); the guild reports (`guild_t<k>_report_*`) turn in
  there.

### The capitals

The six capital files (Highcourt, Dur Brannoc and Lethariel of The Accord;
Gor Drazhak, Kezamba and Nhal Veyr of The Throng; levels 19–30;
[round60-plan.md](../planning/round60-plan.md) §2 point 2, §2a; the
chapter-2 picks K1–K13, all "A"): every quest but the story quests is free
play, gated only by its level; nothing else chains. Each capital has two
hubs: the envoy (lines `envoy` and `front`) with the cook (`provisions` and
`dispatch`), and the guild leader alone (`guild`).

- **Shared quests** for the tasks that are the same in several capitals,
  each in its first variant's file (Highcourt's or Lethariel's); a band
  quest may have a capital variant (Varda's Mire Carp in Dur Brannoc is a
  variant of `band_mire_carp`, homed in Totemwater Reach).
- **Local quests**: each capital's climax, its named leader alone and free;
  one day or night hunt and the cook's own errand where it is the capital's
  own; and the handovers: the cooks' dispatch travels into the band and the
  envoys' departures at 29–30 to the 31–40 hosts, all free. Three kill
  objectives per capital at most, two or three mob names.
- **The Alchemy quest** `capital_precision` (round60-plan.md §2 point 6,
  §2a points 4–5): at the first capital visit (level 19, reward level 20)
  each envoy asks, on its `envoy` line and with no prerequisite, for one
  **Elixir of Precision I** (Sunleaf, a Boar Tusk and a Glass Bottle), which
  no quest rewards; each envoy has its own playful occasion. The text names
  the capital's Alchemy trainer by its plot in words (Highcourt's herb
  garden, Dur Brannoc's and Lethariel's brewhouses, Nhal Veyr's physic
  house, Gor Drazhak's herb house, Kezamba's herbalist) and sends the
  player back to where they started, by their start settlement's waystone:
  Sunleaf grows in every start zone and the start zones' boars by day drop
  the tusk; it never names the start zone (a text follows the giver's race,
  not the player's). A crafting lesson requests the item, so a friend's
  elixir counts. It is the one quest that may ask for a profession's
  product (`tools/r45_st`).
- **Chapter 2's T3** `story_throng_04` (story, level 29): Ossa
  Quietregister sends the player to post the claim notice (`claim_notice`,
  a 3 s hold) at the public register in front of Nhal Veyr's Miner's Guild
  house, a town place
  (`socket:nhal_veyr/miners_guild/miners_guild_public_register`,
  [settlements.md](settlements.md) "Chapter 2's town place"), and to report
  to Iven Lastshift, who takes the turn-in. It requires T2a
  (`story_throng_03`, Ossuary Reach), the free travel quest
  `ossuary_rubbings_03` and the free Hush quest `nhal_veyr_vigil_03`; it is
  the one Throng follow-up of each of the two free quests.
- **The Expedition quests:** the six guild leaders give one optional group
  quest per Expedition on their line `guild`, each turned in at the giver,
  one text per faction, weight 4: kill the Expedition's boss once, at any
  of its levels; the Expedition stays repeatable after the turn-in. They
  are free and standalone ("Group quests"):
  `capital_stilled_seam` "Party: The Stilled Seam" (level 20, Flintback,
  [expeditions.md](expeditions.md#13-the-stilled-seam)),
  `capital_second_shift` "Party: The Second Shift" (level 40, Auditor Nemm,
  [expeditions.md](expeditions.md#14-the-second-shift)) and
  `capital_last_mint` "Party: The Last Mint" (level 60, Duewarden,
  [expeditions.md](expeditions.md#15-the-last-mint)).
- **Rewards** (capitals are excepted from the zone budget): the climaxes a
  material choice, the night task and T3 a choice of 2 Healing Potion III
  or 2 Mana Potion III; the others XP and copper.

The Miner's Guild's quests: [miners_guild.md](miners_guild.md) §11.

### The band 21–30

The eight zones of levels 21–30 (Frostbarrow Shelf, Whitebridge Shire,
Lorindor and Moonfall Wood of The Accord; Ossuary Reach, Speargrass
Reach, Whispering Reedlands and Totemwater Reach of The Throng;
round60-plan.md §2, §2a), from the story chapter the user picked (chapter
2, every recommendation K1–K13 "A", with the feasibility check's fixes). A
level-21 character finds each zone's first quests (open from level 19) at
once; free quests require only a level, and only chapter 2's story quests
chain. The zone's own people give them: the Round 20 hosts (village,
outpost, mine) and the mining camp's foreman; no new giver.

- **Shared quests** (one id, one level, one title; the zone's voice in the
  variant text) for the tasks the hosts share: the mines' first offer
  naming their guild, the shore hunt, the snares, the planks, the corn and
  the fish.
- **Local quests**: the first errand (the potion choice), a use at a new
  place or a day hunt, a later errand (Basic recipes or gatherings), the
  zone's named leader, the travels between the zone's people and to the
  neighbours, and the departures at 29–30 to the 31–40 hosts (requiring
  nothing).
- **Chapter 2's band steps** (story): `story_accord_03` "Held in Our Name"
  (level 25, requires `story_accord_02`): Brodd Deeppeg, the Frostbarrow
  mining camp's foreman, has the player secure the dispatch record and
  release the held load at the camp's `held_load` (two uses, any order),
  turned in at Kelda Screesort; `story_accord_04` "Under a Joint Seal"
  (level 29, requires A3 and `frostbarrow_cutting_04`): Kelda to Hadrin
  Beamset in Dur Brannoc; `story_throng_03` "The Copy Between Them"
  (level 25, requires `story_throng_02`): Rellis Shalemark, the Ossuary
  camp's foreman, has the witness record secured at the `claim_rest`,
  turned in at Mereth Rubbinghand. The capitals' T3 requires it ("The
  capitals").
- **Objectives**: at most 3 kill objectives per zone (the camp hunt, the
  shore hunt or a day hunt, the named leader).
- **Rewards** at item levels 21–30 (tier-3 pieces, enchant tier 3): the
  first quest a choice of 2 Healing Potion III or 2 Mana Potion III (reward
  level 21), two armor choices on local quests (a prefix, then a suffix),
  the named leader one weapon per weapon line with a prefix and a suffix;
  no shared quest rewards equipment. Each faction's four zones give every
  slot twice. A3 and T2a pay a potion choice.

### The band 31–40

The six contested zones of levels 31–40 (Stormvault Heights, Ashenward
March and Glassroot Wilds of The Accord; Blackwind Rise, Bannerbreak Mesa
and Thunderroot Wilds of The Throng;
[round61-plan.md](../planning/round61-plan.md) §2, §2a), from the story
chapter the user picked (chapter 3, every recommendation K1–K13 "A", with
the feasibility check's fixes). A level-30 character finds each zone's
first quests (open from level 29) at once; free quests require only a
level, and only the story quests chain. The Round 20 hosts and the mining
camps' foremen give them; no new giver. The two contested base files
(`elandor_ashenward_march`, `kragmar_bannerbreak_mesa`) also hold the main
line's 15 steps of 41–60 ("The main line"), marked `story`.

- **Shared quests** (one id, one level, one title): the hosts that give one
  share the line `border`, beside `front` or, for Faeris Rootbinder and
  Rumela Stormstep, beside their local line. The camp hunts, the raid
  `camp_site_raid` and the guild reports are the guild's; no zone quest
  kills a camp hunt's role in its zone. The Runner's Packet quest
  `border_packets` is given in all six zones (its item a quest-only drop of
  the zone's bandit-camp archers).
- **Local quests**: the hosts' errands, uses at new places, each zone's
  **solo quest with its weapon** (Scrip's `ashenward_rations_03` and
  Rattle's `bannerbreak_ramp_03` among them), the travels between the hosts (requiring
  nothing) and the departures at 40 to a host with front work from 40
  (Ashenward's and Bannerbreak's hosts give their front quests themselves).
- **One optional group quest per zone** ("Group quests"): the zone's elite
  leader ("Party:", level 39), free, requiring nothing and required by
  nothing, its extra a choice of three plain tier-4 trinkets; the questing
  share is met without it.
- **Chapter 3** (story): `story_accord_05` A5 "Every Hand on the Road"
  (level 35, requires A4 and Scrip's free quest `ashenward_rations_03`): Toren Waterbarrel has the
  raided transport's record secured at the Ashenward Broken Load and taken
  to **Audra Wainholt**, the Ashenward mining camp's foreman;
  `story_accord_06` A6 "The Cost of Holding Ground" (level 40, requires A5
  and `camp_site_raid`): any of the three Accord band foremen sends the
  player with the raid's report to Nella Hedgeward, who points to the
  Warmaster; `story_throng_05` T4 "The Hands Behind the Stores" (level 36,
  requires T3 and Rattle's free quest `bannerbreak_ramp_03`): Drek Rampbinder, the handover
  record at the Bannerbreak Scattered Load, turned in at **Greda
  Stonehaul**, the Bannerbreak mining camp's foreman; `story_throng_06` T5
  "The Promise Still Stands" (level 40, requires T4 and the raid): any
  Throng band foreman to Yarra Standardmender, who points to the Warmaster.
  Scrip's, Rattle's and the raid's free quests have the story step as their
  one follow-up per faction. The free fortress calls
  (`ashenward_bastion_call`, `bannerbreak_warhold_call`, level 41, open from 39) carry
  the player on; there is no A7/T6.
- **Objectives**: 4–6 kill objectives per zone with the camp quests (the
  raid's two among them), 3–5 mob names besides the raid's garrison.
- **Rewards** at item levels 31–40 (tier-4 pieces, enchant tier 4): each
  zone's early potion choice (2 Healing Potion IV or 2 Mana Potion IV) and
  that of `border_packets`, two armor choices (a prefix, then a suffix), the
  weapon on the zone's solo quest (one per weapon line, prefix and suffix).
  The shared quests count in every zone that gives them (`E-reward-budget`)
  and a player takes each once, so armor sits only on shared quests given
  once per faction and `border_packets` pays potions: each
  faction's three zones give six pieces, every slot at least once. A5 and
  T4 pay a potion choice.

### The front 41–60

The front of levels 41–60 (The Broken Causeway and The Shattered Line at
41–50, Gravesalt Escarpment and The Skyglass Canopy at 51–60, the two
islands at 60; [round62-plan.md](../planning/round62-plan.md) §2, §2a; the
chapter-4 story layer the user picked, K1–K13 all "A", with the
feasibility check's fixes): the ten `.front` files of the four contested
hosts and six capitals and the four Battlegrounds files, whose guild and
camp quests are the guild's. No giver stands in a front zone but the
war-camp foremen (lines `camp` and `guild`); the hosts and envoys give from
their own zones and send the player there.

- **The story path** is the main line ("The main line"). The opener (open
  from 40) requires nothing, so a character who skipped the earlier
  chapters is not locked out; A6 and T5 reach it through the free fortress
  calls. The war commander hunts stay optional story branches; the two
  finales are the only required group steps.
- **The fortress quests** ("PvP fortress quests"): the entry call, the
  three ordinary quests and the eight camp raids per faction, the two camps
  of a band chained by zone.
- **Shared front quests** (one id, one level, one title, the hosts' line
  `border`, each in its first variant's base file, Ashenward March's or
  Stormvault Heights'), among them the two optional group quests at 50
  on the elites both factions hunt, and the departure `front_beyond_line`
  at 50.
- **Local quests** (line `front`, each giver's `.front` file), with Dorrin
  Gateledger as the Accord's third 41–50 giver (K1 A). The free departures
  require nothing and lead to a giver with work at once.
- **Group quests**: below 51 only the two shared ones (free, standalone,
  a plain trinket choice); from 51 Salt-Counter and Glass-Throat per
  faction, standalone (a recorded exception: the hosts share no line, and
  Glass-Throat's shared quest would live in a capital base file), and the
  island elites.
- **The islands** (60, weight 0, coin only, "Every quest once"): the
  Accord's Dur Brannoc and Highcourt bounty pairs and the Throng's pair at
  Thorga (a day hunt in the Stormscale Scorchlands, then the group quest on
  Last-Offering, K9 A); the four island uses free from 60 (open from 58).
- **Rewards** per faction and level band (tier 5 at 41–50, tier 6 at
  51–60; the budget per zone and level band, "The rework flag"): six armor
  choices with one enchant (every slot), three weapon choices with prefix
  and suffix on solo quests, three plain trinket choices (the two group
  quests at 50 and the Ninepins step at 41–50; Salt-Counter, Glass-Throat
  and the war commander from 51), a Healing or Mana Potion V/VI choice on
  the openers at 41 and 53 and early errands; the final turn-ins
  (`*_main_final`) a weapon choice. Shared quests given once per faction
  carry Ashenward's and Bannerbreak's (Toren and Drek, Nella and Yarra) and
  Stormvault's and Blackwind's (Alna and Orrel) share; the capitals carry
  the rest.
- **Objectives**: 4–6 mob names per front zone and faction besides the
  camp hunts and the garrisons (the spine's targets and the elites among
  them); the free front about a quarter kill, the spine, fortress and camp
  quests keeping theirs.

### PvP fortress quests

Each faction's fortress ([world.md](world.md) §4; Ashenward Bastion in
Ashenward March, Bannerbreak Warhold in Bannerbreak Mesa) is the hub of its
PvP quests (pvp-plan rulings 14, 15 and 23). Its three quest givers
(Warmaster, Drillmaster, Outrider) give them on their line `front` (the
zone's front file); the fortress quests start at level 41, open from 39
("Acceptance"):

- **one raid per enemy Battlegrounds camp** (8 per faction): kill the camp's
  guards (4 at a lower camp, 5 at a higher one) and its captain, both
  limited to that camp's area, at the reward level of the camp's band;
  solo quests (round31-plan §6 item 16: the captain is a normal-tier camp
  leader), given and turned in by the Outrider (lower camps) or the
  Drillmaster (higher camps), the two camps of a band chained by zone;
- **ordinary fortress quests**: supplies for the Quartermaster (Warmaster),
  War Trophies from enemy guards (Drillmaster; they drop only to an enemy
  player's kill), and a scouting kill in a Battlegrounds kind (Outrider);
- **an entry quest** from an outpost of the fortress's zone (level 41, open
  from 39), a travel quest to the Warmaster.

No objective names a player or a General. The front ledger counts these
quests like every front quest.

### The main line

Each faction's main line for levels 41–60 (round36-plan §2.2–§2.8; the
story and its beats: [story.md](story.md) §2a and the
[story bible](../planning/round36/story-bible.md)) runs from its fortress
Warmaster's second line, travel handoffs and turn-ins at the existing
givers the bible names, and the front climaxes folded in as required
steps (their texts carry the thread; their other quests stay as they
were). Chapters open at 40, 45 and 53 (their openers' levels 42, 47 and 55
minus two), each with a quest that requires the previous chapter's last
turn-in (a Warmaster turn-in); the finale "Party: The Collector Comes Due"
(level 60) opens at 58 on the rift boss, and the last turn-in at the
Warmaster carries the bible's last line. Every step a chapter names carries
the faction's tag; every required step is solo but the finale; optional
branches (the war commander's "Party:" hunt, the islands' interactions)
never block the line. The ledger counts a front host's main line in the
front bands (`ledger.py --track`). The whole spine is `story` and the story
path of 41–60, each step with a completion: the 17
Accord and 14 Throng steps (the front climaxes on Senn, Ninepins, Huskell
and Chirr among them) each require only spine steps, and The Throng's Chirr
step (`kz_front_04`) follows Huskell's (`bw_front_ashveil_04`, K12 A). The
15 steps homed in the two contested base files (Ashenward March,
Bannerbreak Mesa) live there; the others in the `.front` files.

- **The Throng** ("Our Oaths Are Ours", tag `throng_main`, the Warmaster's
  line `oaths`): the finale is turned in at Vaska Ashlistener, then
  `throng_main_final` at the Warmaster. Optional: War Commander Greyvow
  (level 59, open from 57, Party:), the survey cairn and the wreck's pay
  chest on the islands (60, from the Nhal Veyr and Gor Drazhak envoys,
  free).
- **The Accord** ("Every Name Accounted For", tag `accord_main`, the
  Warmaster's line `main`): the finale at the Warmaster and
  `accord_main_final`, a report given and taken there. Optional: War
  Commander Stonegrudge (level 59, open from 57, Party:), the survey cairn
  and the wreck's pay chest on the islands (60, from the Dur Brannoc and
  Highcourt envoys, free).

Each chapter's steps (giver, place and object per step) are in the quest
files; the step lists as written in Round 36 are archived
([quests-history.md](../archive/design/quests-history.md#the-main-line-round-36-as-written-before-the-cleanup-old-lines-277330)).

## Former section names

Older documents and tool notes cite sections by names this file no longer
uses:

| Cited as | Now |
|---|---|
| "Confirmed by the user", "Accepted defaults" | split by topic: "Scope", "Acceptance", "Givers", the objective sections, "The quest log", "The HUD tracker", "Quest markers", "Rewards", "For content lanes" |
| "Presentation and regional expansion" | "Scope" (the quest total), "Quest markers" (the symbol size), "The HUD tracker", "For content lanes", "Quest content by level band" |
| a heading with a round in brackets, e.g. "Objectives (Round 28)" | the same heading without the round |

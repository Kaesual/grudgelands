# Round 38 — Mob names: design round plan

Coordinator: Claude (Opus 5.5), drafted 2026-10-06 from the user's naming
request during Round 37 and the kill-credit bug found in the user's
playtest; revised the same day with the user's answers. Status: **complete
locally on 2026-10-06, not pushed** ([completion and GUI
checklist](#completion-2026-10-06)); approved and started on the user's "go"
(2026-10-06); phases 0 and 1 (lanes I, V, M) ran together, since V and M do
not need the finished inventory to begin.

A design round, run in parallel lanes: the names are proposed zone by zone
by several Opus agents on a shared vocabulary, checked for consistency and
taste, shown to the user on a preview page, and then built in. It replaces
the signal-word naming of Round 28 with short names that carry the zones'
feel, and it fixes the quest kill-credit bug at the same time, because both
rest on the same question: which mob does a quest mean, and can the player
tell it apart?

## 1. Why

- **Kill credit (playtest, 2026-10-06):** a kill objective with an area
  counts only mobs that *spawned* in that region
  (`grug_quests/state.lua` `mob_counts`, `_grug_area == target.area`), but
  the same role spawns in other regions of the zone under the same name
  (names are chosen per zone). In Stillgrave Hollow about one in three
  nearby Small Plague Boars and Large Grave Rats belongs to the next belt
  and does not count. 159 area-targeted (zone, role) pairs are affected; in
  93 of them the duplicate shares the quest region's belt and levels.
  Analysis: `~/projects/grudgelands-orchestration/r38/naming-analysis/`
  (`multi_region_roles.tsv` and its scripts).
- **Names (user, 2026-10-06):** signal words (Small, Large, Braindead …)
  take flair away; size and the coloured nametag already tell the rank.
  Today 205 sub-type roles carry 243 display names: 97 normal names have
  three or more words, 47 start with a signal word.

## 2. Goals

### 2.1 The guarantee (hard)

**For the player, a mob's name is the exact and always correct answer to
"which mobs does this quest mean?"** For every kill objective (and every
item objective tied to a mob): every mob that bears the name the quest names
counts — whatever its level, wherever it is, wherever it spawned — and no mob
of another name counts. Mob names, quest texts and what counts always agree.

This is a property to guarantee, not a mechanism. **Finding the best way to
guarantee it is part of the round** (lane M): counting by sub-type, counting
by the displayed name, keeping area filters and giving each area's mobs
their own name, or a mix — whichever is simplest and most robust in the
code. Whatever is chosen, a validator proves the guarantee over all quests,
recipes and names, so it cannot break silently later. A place named in a
quest text is guidance for the player; it must not silently decide what
counts unless the names make that visible.

### 2.2 Name rules (hard)

1. **Normal mobs: at most two words** ("Shore Crab", "Reef Lurker").
   **Named mobs, elites and bosses: at most three words.** Those with three
   words today keep their names this round; they are on the page for the
   user's overview only.
2. **No signal words** (Small, Large, Braindead …): size and the coloured
   nametag carry the rank.
3. **Piglet is reserved** for the level 1–2 pigs of the six start zones,
   the first kill quest of every character (`*_hunt_01`, `small_boar`,
   level 2 in all six), with the zone's flavour ("Forest Piglet").
4. **One name, one level stretch within one drop tier.** A name may span
   several level bands only if they are adjacent and in the same drop tier:
   21–23 with 24–26 is allowed; 27–29 with 30–32 is not (two tiers); 40–42
   with 47–49 is not (a gap). Where a name is reused in another zone, the
   rule holds for the name as a whole.
5. The faction names stay The Accord and The Throng; no name refers to an
   existing game; every name passes the naming checks (rewritten to these
   rules).

### 2.3 The zone's picture (soft, the heart of the round)

These are judgement goals. They are written here so every agent works
towards them, and they are what the taste review and the user's page judge.

- **A zone's names form one round picture.** The names a player meets in a
  zone belong together and carry its feel: its biome and weather, its
  people (the race region and its culture), its story (the story bible,
  the front, the dead), its danger. Reading a zone's name list should feel
  like the zone. Neighbouring zones and the two continents fit together
  too.
- **Flavour, not labels.** Zone flavour is welcome, but better than the
  obvious ("Jungle Boar"); the base word itself should fit the zone's mood
  (a word that sounds like marsh or war for those zones). Clever is welcome,
  never forced; plain and fitting beats ornate.
- **Families keep a recognisable voice.** Each family has a vocabulary
  (pigs: Piglet, Pig, Sow, Hog, Boar …) that varies with size, age, temper
  and place, so a player senses "this is the bigger, meaner one" without a
  signal word. Reuse across zones is allowed where it fits; there is no
  fixed rule for it.
- **Merging level bands takes judgement.** Rule 2.2.4 says when a name *may*
  span bands, not when it *should*. Keep one name where the creature feels
  the same (a herd grazing across 21–26), give a new name where the step up
  should feel like meeting something new (the first dangerous wolf after
  the cubs). Fewer, better names beat a name per band. Every merge or split
  carries a one-line reason on the page.

## 3. How the round runs (what the agents do)

Claude orchestrates; Opus implements and reviews (an independent review per
lane). Wide parallelism where the work splits cleanly; shared facts and a
shared name register keep the parallel lanes consistent.

| Phase | Lanes (parallel within a phase) | Output |
|---|---|---|
| **0 Facts** | **I** Inventory (one Opus): every name slot (sub-type × zone × level band, leaders, rares, elites, bosses, captains, commanders), today's name and word count, levels and drop tier per band, the quests and texts that name it, camp/roaming overlaps; a generator so the table can be rebuilt and checked | `r38/inventory/` (machine-readable + a short summary) |
| **1 Groundwork** | **V** Vocabulary and moods (one Opus): a mood brief per zone (3–5 lines from `world_zones.md`, biomes, race region, the story bible) and a vocabulary sheet per family (candidate words with their sense: size, age, temper, look, connotation). **M** Mechanism (one Opus, code): the options for §2.1 with cost, a recommendation, a prototype of the validator; the coordinator brings the choice to the user if it is not obvious | moods + vocabulary; mechanism proposal |
| **2 Naming** | **Z1…Z6** (six Opus agents, one per race region with its zones; the front and island zones carry a race region too, `world_zones.md` §8.3): names for every slot of their zones from the moods and the vocabulary, every merge/split with a reason, three-word named mobs listed unchanged. They claim names in a shared register so a reuse is a choice, not an accident | per-zone proposals with reasons |
| **3 Coherence** | **C** Consistency (one Opus): the register and the hard rules by script (collisions, word counts, tiers and gaps, Piglet), family voice across zones, neighbouring zones, the two continents. **T** Taste review (an independent Opus, zone by zone as a player would read them): flags names that break a zone's picture or sound wrong in English, with alternatives. The Z lanes revise | one coherent proposal |
| **4 The user's page** | coordinator + one Opus | German preview page (§4); the user picks and edits; a second pass if the user wants one |
| **5 Build** | **B1** Mechanism and validator (can start in phase 2, it does not depend on the final names); **B2** Names into the data and the runtime (after the picks); **B3** Quest texts that name a mob, updated by script, then **NR** an Opus text review on a page (four reviewers in parallel, as Round 36) | code, data, texts |
| **6** | **D** Round documentation: the naming rules into AGENTS.md and the design frame, completion, GUI checklist | docs |

Lua runs share the workstation cap of 8 through the round's queue
(`docs/process/templates/lua_run.sh`). No mapgen change, so no seed fleet.

## 4. The preview page (phase 4)

- **Zone view:** per zone its mood line, then every slot: level band and
  drop tier, today's name → proposed name, the reason (one line), which
  quests name it; flagged rows stand out (rules, taste notes).
- **Family view:** each family's vocabulary across the world (e.g. pigs:
  Piglet → Pig → Hog → Old Tusker as elite) with the zones and levels where
  each word appears; sprites or tinted renders where cheap.
- **Named mobs, elites and bosses:** all of them, for the overview; the
  three-word names unchanged.
- Accept by default, edit inline, one export block the user pastes back (as
  the Round 36 text pages). The user iterates as usual: a first version by
  feel, then the user's fixes.

## 5. Verification

- The §2.1 validator over all quests, recipes and names (no quest names a
  mob that can be killed without counting, or counts a mob of another name).
- The rewritten naming checks (`tools/r28_names`), `validate.py --game`,
  `quest_targets.py` on six seeds, the fixtures, one smoke boot.
- GUI: the Stillgrave quests from the playtest (every Piglet and rat of the
  quest's name counts, anywhere); a zone walk per continent to feel the
  names; the start zones' nametags.

## 6. The user's answers (2026-10-06)

1. Reuse across zones: allowed, no fixed rule; Piglet reserved.
2. Zone flavour: yes, not blunt; a nudge, not an order.
3. Named mobs, elites and bosses: all on the page for the overview; the
   three-word ones keep their names.
4. The kill-credit bug stays until this round and is fixed with the names.
5. Opus proposes the names.
6. Not every level band needs its own name (rule 2.2.4); the name is the
   exact quest target as a guarantee, the mechanism is part of the round
   (§2.1); the zone's picture and judgement in merging bands matter (§2.3);
   the round runs orchestrated and highly parallel (§3).
7. Item objectives (2026-10-06, during the round): they do not fall under
   the §2.1 guarantee. An item objective names the item; the mobs it
   mentions are guidance. The quest drops tied to a mob (the captains'
   orders) do fall under it.
8. The preview page (2026-10-06): the proposed names are accepted as shown
   (https://claude.ai/artifact/BaT3x8SHz3PiRduScz39aG).
9. World slots (2026-10-06): the 29 mobs that belong to no zone (underground
   casts, water mobs, the faction guards, unplaced sub-types) are renamed
   this round by a small lane Z7, one name per entity; rule 2.2.4 does not
   apply to them (their level comes from the place).
10. The faction guards "Accord Guard" and "Throng Guard" (L20–60) are exempt
    from rule 2.2.4.
11. A capital's L20–23 slot counts as drop tier 3 (it may share a name with
    L24+ slots, never with L19 or lower).
12. The dragon whelps are a balance bug: they become level 60 (today a fixed
    level 20 on the level-60 islands).
13. The kings stay mixed ("King of Highcourt", "Dur Brannoc King").
14. Quest texts: no reading page; an independent review agent checks that
    the new names are set correctly everywhere.
15. "Kraken Guard" becomes "Kraken" (2026-10-06): "Guard" sounds as if it
    guarded something on someone's behalf.
16. Item names (2026-10-06, lane IT's study): twelve display-only renames,
    ids unchanged — Cat Claw, Notched Cat Claw, Gleaming Cat Claw, Blighted
    Bear Claw, Pitted Crab Shell, Silver Mane, Glass Silk, Guttering Wisp
    Mote, Lichen Resin, Drilled Bone, Ivory Chitin, Layered Chitin (the
    shorter alternatives instead of the long hyphen compounds); the
    three-word family items keep their names (the family word tells which
    mobs drop them).
17. "Group" becomes "Party" everywhere the player sees it (2026-10-06),
    in this round.

## Completion (2026-10-06)

Every lane is merged on main, last lane PR (`ec2e874c`); lane D (this
section and the status documents) follows. Nothing of Round 38 is pushed
yet (origin/main is `0ba677fe`, the round's start). Reviews, each by an
independent Opus: I MERGE AFTER FIXES; M/B1 MERGE with one Low (fixed);
B2 MERGE AFTER FIXES (one Medium, one Low); B3 through the text review NR
MERGE with one Low (fixed by the coordinator); IB MERGE (one Low, to this
lane); PR MERGE AFTER FIXES (a README wording, fixed by the coordinator).
Lane C (a checker option and one exemption, with fixture cases) merged
without a review of its own; the naming lanes' proposals had the taste
review T and the user's page instead. After each merge the coordinator ran
the checks and the portable fixtures; the code lanes B1, B2, B3 and PR
each ended with a smoke boot (PASS). On main's tree (`ec2e874c`):
`tools/run_fixtures.sh` **108 of 108** (lane PR's run),
`validate.py --game` 0 errors and the same 7 warnings as before the round,
`check_rules.py --shipped` **0 problems** (22 notes: the capitals' L20–23
slots counted as tier 3) over 950 slots, `guarantee.py --check` PASS (no
E- finding over 362 objectives), `gen_names.py --check` current (898
names). No spawn recipe and no world generation changed, so there was no
seed fleet; the GUI test still wants **a fresh world**: a PvP garrison's
guards and a named rare carry their name key from their placement
(`start_npcs.lua` `install_garrison`, `rares.lua`), so actors an older
world has already placed show a fallback name (fresh-server mode, no
migration).

Round end (main 3607e9ae, 2026-10-06): run_fixtures 108/108; check_fresh_server PASS;
validate.py --game 0 errors (7 warnings, as at the start); check_rules.py --shipped 0
problems over 950 slots; guarantee.py --check PASS; income.py --check PASS; one
headless boot of main PASS (seed 8443766144962855401); no seed fleet owed (no mapgen
change); synced to the user's game.

### Shipped, by lane

Numbers come from the lanes' tools, run the same way before and after;
"before" is the round's opening tree (`50f41d62`, lane I's final
`inventory.py`), "after" main `ec2e874c`.

- **I inventory** (merge `8b0fcbe3`; `tools/r38_names/`): `inventory.py`
  lists every name slot — sub-type × zone × level band of each recipe,
  leaders, rares, kings and royal guards, dragons and whelps, the rift
  boss, PvP garrisons, guards, underground and water mobs, unplaced
  sub-types — with its name and source line, words, levels, drop tiers,
  race region, neighbours (`neighbours.lua` on the six quest seeds) and
  the quests and texts that name it: **950 slots** (921 in the 38 zones,
  29 world slots), **356 distinct names** before. `check_rules.py` checks
  the §2.2 rules (`test_rules.py` breaks one at a time). Today's names
  broke them **374 times**: 75 normal names (184 slots) over two words and
  17 named ones over three (rule 1, 201 lines), signal words on 116 slots
  (51 names; rule 2), rule 4 by 38 names. Of the 362 objectives under the
  guarantee (360 kills, 2 quest drops; the 65 item objectives are
  guidance, §6.7), **268 left same-named mobs uncounted** (230 in their
  own zone; 161 area-targeted zone and role pairs) and **21 counted a mob
  of another name than their label** (every PvP captain and commander: the
  quest said "Throng Captain", the mob showed its `pvp_names.json` name).
- **V vocabulary and moods** (design, private round folder): a mood brief
  for each of the 38 zones and a vocabulary for each of the 34 families
  (size, age, temper, look), a modifier sheet and a style guide; the fire
  and coin words reserved for the ten Undertithe-corrupted sub-types.
- **M mechanism, then B1** (merge `f7c2e794`; [quests.md "The quest-name
  guarantee"](../design/quests.md#the-quest-name-guarantee-round-38)):
  of the options in §2.1, **a kill counts by the name the mob shows**.
  `grug_mobs/data/names.json` holds one name per slot key
  (`<scope>/<source>/L<lo>-<hi>`, written by `tools/r38_b1/gen_names.py`);
  `names.lua` (over the pure `names_core.lua`) names every mob once per
  activation and on every relevel; `Q.target_names` resolves each
  objective's roles and area at load into the names of the slots they
  select, and `mob_counts` compares the mob's name with them, so every mob
  of the name counts wherever it spawned and no other does; an objective
  that selects no name stops the load (`E-no-name`); camp quests write the
  captain as `{captain:<camp key>}`. `tools/r38_names/guarantee.py --check`
  proves the property over lane I's model and the names file. The kill
  path costs **0.73 → 0.30 µs** per kill that credits nothing (20 active
  quests, LuaJIT, the `tools/r38_b1` fixture; a comparison). The review's
  Low (the validator's selector fallback against the game's) and the
  `r37_f` fixture on the names file were fixed before the merge.
- **C coherence** (merge `5e028dc0`): `check_rules.py --world-pending`
  checks the six naming lanes together; the Rift Spawn (one story
  creature at L52, 56, 59 and 60, all tier 6) is exempt from rule 4's gap
  test. Patterns set across lanes: garrison guards "<Faction> <rank>"
  (Accord Picket, Throng Veteran …), royal guards "Royal <noun>", a toll
  bandit voice per capital, one Bone Levy, Marching Zombie and Gallows
  Crow, the Last Watch names only on L56–60, split names for the six
  repeatable bounties' targets.
- **Z1–Z6 naming and T taste** (design): names for the 921 zone slots,
  one lane per race region with its zones, every name claimed in a shared
  register (a reuse with its reason), every merge or split of level bands
  with a one-line reason. The taste review read each zone as a player
  would: 5 changes (all made: Ounce → Tarn Cat, Ashenward Marcher →
  Marching Zombie, the Skyglass garrison names, Barrow Keener → Fen
  Wailer, Levy Skeleton → Bone Levy) and 13 suggestions, which the lanes
  took or answered in their revision.
- **The user's page** (lane page): the zone view, the family view and
  every named mob, elite and boss, in German
  ([preview page](https://claude.ai/artifact/BaT3x8SHz3PiRduScz39aG)):
  485 proposed names for the 921 zone slots, 330 before.
- **Z7 world slots** (design, §6.9): one name per entity for the 29 world
  slots: Giant Rat → **Pit Rat**, Giant Spider → **Crevice Spider**, Goblin
  Miner Slinger → **Goblin Pelter**, the underground Zombie → **Buried
  Miner**, Dungeon Master → **Fire Hurler**, Lava Flan → **Lava Seep**,
  Land Guard → **Bedrock Sentinel**, Crown Stone Golem → **Scree Golem**;
  21 kept (later the Kraken, lane IB).
- **B2 the accepted names** (merge `6397120c`; [biomes_mobs.md
  "Names"](../design/biomes_mobs.md#round-28-sub-types-and-loot-by-band)):
  `names.json` from the picks of Z1–Z7 (`gen_names.py --proposals`):
  **536 of 950 slots renamed** (535 by lane B2, the Kraken by lane IB), **356 → 513 distinct names** (330 → 485
  on the zone slots), §2.2 breaks **374 → 0**. Kings, royal guards, the
  General's bodyguards, the dragons and their broadcast, the whelps and
  the rift boss read their names from the file, no second copy in code;
  `check_rules.py --shipped` is the naming gate (`tools/r28_names`'s
  `build_review.py` retired); the dragon whelps are **level 60** (§6.12;
  were 20, HP **384 → 2696**, still no drops); Captain Morveth the Still is
  Captain Morveth Stillwake. The review's Medium (the map read "Dur Brannoc
  King, King of Dur Brannoc") and Low (`r31_q`'s counting order) were
  fixed before the merge.
- **B3 quest texts** (merge `8fcf175c`): **242 quest text fields in 42
  files** name the shown names (`guarantee.py` `W-text-name` **216 → 0**);
  the PvP camp quests name the post's guards and the captain by
  placeholder; jokes that rested on an old name are rewritten in the same
  voice (`stillgrave_hunt_05`). The text review NR (§6.14, no reading
  page) found one Low, the trophy quests' "Throng/Accord Guards", fixed
  by the coordinator (`77212b08`).
- **IT item study** (design): 120 items, 72 of them with a creature word;
  12 renames proposed, 8 three-word family items to keep.
- **IB items and the Kraken** (merge `9bcdad9e`; §6.15, §6.16): the
  **Kraken** (was Kraken Guard); **twelve item display names**, ids
  unchanged — Cat Claw, Notched Cat Claw, Gleaming Cat Claw, Blighted Bear
  Claw, Pitted Crab Shell, Silver Mane, Glass Silk, Guttering Wisp Mote,
  Lichen Resin, Drilled Bone, Ivory Chitin, Layered Chitin — in
  `items.json` and its catalogue copy, five quest texts, the icon
  provenance rows and the regenerated `item_tiers.md`.
- **PR Group becomes Party** (merge `ec2e874c`; §6.17): the Party tab, the
  invite notice ("Open Party to respond"), the help line, the Priest's
  description, **20 "Party: …" quest titles** and 21 quest-text phrases;
  page ids, data keys and engine groups unchanged; the design docs and the
  README say party.
- **D** (this lane): this section, STATUS, AGENTS.md's names rule and
  pointer, ROADMAP, BACKLOG, README, CHANGELOG 0.38.0 and `game.conf`
  version 0.38.0, the tools README, stale example names in
  `grug_quests` comments.

### The user's choices during the round

Besides §6 items 1–6 (before the start), all on 2026-10-06:

1. **Item objectives** are guidance, not under the guarantee; quest drops
   tied to a mob are (§6.7).
2. **The page:** the proposed names are accepted as shown (§6.8,
   [preview page](https://claude.ai/artifact/BaT3x8SHz3PiRduScz39aG)).
3. **World slots** renamed by lane Z7, one name per entity, exempt from
   rule 4 (§6.9); the faction guards exempt too (§6.10); a capital's
   L20–23 slot counts as tier 3 (§6.11).
4. **The dragon whelps** become level 60 (§6.12); **the kings** stay mixed
   ("King of Highcourt", "Dur Brannoc King"; §6.13).
5. **Quest texts:** no reading page, an independent review agent instead
   (§6.14).
6. **Z7's names** accepted as proposed (Oerkki and Mesa Golem kept).
7. **The zombie achievement stays:** "Kill %d zombies" counts the Buried
   Miner too (it counts the entity family).
8. **The Kraken** (§6.15), **twelve item renames** with the shorter
   alternatives, the three-word family items kept (§6.16), and **Group
   becomes Party** in this round (§6.17).

### Deviations from the plan

- Phases 0 and 1 ran together (I, V, M), and lane M went on as **B1 during
  phase 2**, before the picks: today's names first, with interim names for
  the PvP garrison guards until B2.
- **Lanes added during the round:** Z7 (the world slots, §6.9), the item
  study IT and its build IB, the Kraken, and PR (Group becomes Party).
- **No reading page for the texts** (§6.14): the review NR read them.
- §5's "rewritten naming checks (`tools/r28_names`)" became the new
  `tools/r38_names` (`check_rules.py`, `guarantee.py`); `r28_names`'s
  `build_review.py` is retired. §5's `quest_targets.py` run is not in the
  round log; no spawn recipe changed (0 `*.spawns.json` files), so the
  region statistics it reports are unchanged.
- Lane C merged without a review of its own (above).

### Open notes

In the [BACKLOG](../../BACKLOG.md#round-38-carry-overs); none blocks the GUI
test.

- The dragons' broadcast puts "The " before the names file's name in code;
  the achievements keep the short forms "Wyrmglass Dragon" and
  "Stormscale Wyvern"; the families' Lua descriptions are only fallbacks.
- The level-60 whelps make the enrage phase clearly harder (watch in
  playtests); the Rift Spawn's gap exemption holds while its name stays on
  one role; `guarantee.py`'s `I-now-counts` (205 objectives) and
  `W-level-fit` (135) are information, not errors; the 8 three-word family
  items keep their names.
- The welcome window after character creation is the user's separate lane
  (branch `r38-wc`), not merged in this round.

### GUI playtest checklist

Desktop client and the web build, on **a fresh world** made on main after
this lane. Helpers: `/xp give`, `/teleport`, `/giveme`, `/time`
(privileges `server`, `give`, `settime`). Say what reads or looks wrong.

1. **Stillgrave Hollow, the playtest quests:** `stillgrave_hunt_01` — every
   Barrow Piglet counts, anywhere in the zone, from any field;
   `stillgrave_hunt_02` — every Grave Rat counts the same way; a creature
   of another name never does.
2. **The start zones' nametags:** each zone's level 1–2 pigs are its
   Piglet (Barley, Pine, Glade, Yam, Barrow, Scrub Piglet); no name has a
   signal word (Small, Large, Braindead, Confused …).
3. **A zone walk per continent** (Elandor and Kragmar, a few zones and
   belts each): do the names feel like the zone, and does the bigger,
   meaner one read as such without a signal word?
4. **A PvP garrison quest** (for example `ashenward_bastion_picket_broken`,
   "Blind the …" at level 42): the text names the camp's guards (Throng
   Pickets) and the captain by name; the guards and the captain
   count.
5. **The Map tab's king markers:** "Dur Brannoc King" once, "King of
   Highcourt" as it is.
6. **A dragon fight to the enrage:** the two whelps are level 60.
7. **Party:** the Party tab, a "Party: …" quest title in the log and the
   invite line "Open Party to respond".
8. **Loot with the new item names:** Cat Claw, Silver Mane, Glass Silk,
   Layered Chitin ….
9. **Underground:** Pit Rat, Crevice Spider, Buried Miner, Goblin Pelter,
   Fire Hurler, Lava Seep.
10. **The Kraken's nametag** in deep ocean reads "Kraken".
11. **A few rewritten quest texts:** `stillgrave_hunt_05` ("Borrow Has Had
    Long Enough") and a camp quest read naturally with the new names.

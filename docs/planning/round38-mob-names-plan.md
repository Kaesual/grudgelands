# Round 38 — Mob names: design round plan

Coordinator: Claude (Opus 5.5), drafted 2026-10-06 from the user's naming
request during Round 37 and the kill-credit bug found in the user's
playtest; revised the same day with the user's answers. Status: **approved and
started on the user's "go" (2026-10-06)**; phases 0 and 1 (lanes I, V, M)
run together, since V and M do not need the finished inventory to begin.

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

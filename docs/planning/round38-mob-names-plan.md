# Round 38 — Mob names: design round plan

Coordinator: Claude (Opus 5.5), drafted 2026-10-06 from the user's naming
request during Round 37 and the kill-credit bug found in the user's
playtest. Status: **draft; the user answered §5 on 2026-10-06 (rulings in
§2); awaiting the user's approval and go**.

A design round: first a proposal the user reviews on a preview page, then
one implementation lane. It replaces the signal-word naming of Round 28 with
short names that carry flair, and it fixes the quest kill-credit bug at the
same time, because both rest on the same question: which mob does a quest
mean, and can the player tell it apart?

## 1. Why

- **Kill credit (playtest, 2026-10-06):** a kill objective with an area
  counts only mobs that *spawned* in that region
  (`grug_quests/state.lua` `mob_counts`, `_grug_area == target.area`), but
  the same role spawns in other regions of the zone under the same name
  (names are chosen per zone). In Stillgrave Hollow about one in three
  nearby Small Plague Boars and Large Grave Rats belongs to the next belt
  and does not count. 159 area-targeted (zone, role) pairs are affected; in
  93 of them the duplicate shares the quest region's belt and levels, so
  names alone cannot separate them. Analysis:
  `~/projects/grudgelands-orchestration/r38/naming-analysis/multi_region_roles.tsv`.
- **Names (user, 2026-10-06):** signal words (Small, Large, Braindead …)
  take flair away; size and the coloured nametag already tell the rank.
  Today 205 sub-type roles carry 243 display names: 97 normal names have
  three or more words, 47 start with a signal word.

## 2. Rules (user, 2026-10-06)

1. **The name is the quest's target, exactly.** A kill quest that names a
   mob counts every mob of that name, whatever its level, wherever it is
   and wherever it spawned; a mob of another name never counts. Mob names,
   quest texts and "counts for the quest" always agree. A place in a quest
   text is guidance, not a filter. (This replaces the area filter in
   `grug_quests/state.lua` `mob_counts` and fixes the playtest's kill-credit
   bug; camp quests whose camp mob also roams outside need their own name.)
2. **One name, one level stretch within one drop tier.** A name (a sub-type)
   may span several level bands only if they are adjacent and in the same
   drop tier: 21–23 and 24–26 is allowed; 27–29 and 30–32 is not (two
   tiers); 40–42 and 47–49 is not (not adjacent). So not every band needs
   its own name, least of all in the higher zones. Where a name is reused
   in another zone, the same rule holds for the name as a whole.
3. **Normal mobs: at most two words** ("Shore Crab", "Reef Lurker").
   **Named mobs, elites and bosses: at most three words**; those with three
   words today keep their names this round (they are on the page for the
   user's overview only).
4. **No signal words** (Small, Large, Braindead …): size and the coloured
   nametag carry the rank. The one reserved word is **Piglet**: always the
   level 1–2 pigs of the six start zones, the first kill quest of every
   character (`*_hunt_01`, `small_boar`, level 2 in all six), with the
   zone's flavour ("Forest Piglet", "Jungle Piglet").
5. **Zone flavour, not blunt:** names may carry the zone's mood, but better
   than the obvious ("Jungle Boar"); the base word should fit the zone's
   feel (e.g. a word that sounds like marsh or war for those zones). Clever
   is welcome, not required. Reusing a name across zones is allowed; there
   is no fixed rule for it.
6. Kill quests keep naming the exact mob (design frame §5); the faction
   names stay The Accord and The Throng; no name refers to an existing
   game. Opus proposes the names (user, 2026-10-06).

## 3. Lanes

| Lane | Wave | Kind | Content |
|---|---|---|---|
| **N1** Inventory and vocabulary | 1 | analysis + page | every name slot (sub-type × zone × belt, leaders, rares, elites, bosses, captains), today's name, word count, where quests and texts use it; a family vocabulary sheet (per family: 4–8 candidate words by size/age/temper/look) |
| **N2** Proposal | 1 (after N1) | page | a full old → new table per zone and belt that keeps every rule of §2, from the vocabulary; the preview page for the user (German frame, English names), per family and per zone, with accept / edit per row and an export the user pastes back |
| **N3** Implementation | 2 (after the user's picks) | code + data + texts | names by zone and level stretch at runtime (the name is applied after the area tag), kill objectives count by name (§2.1; quest data names the mob, not an area filter), the naming validators rewritten to the new rules (§2.2–§2.5, including one level stretch per name within a drop tier), quest titles and texts that name a mob updated by script, region/quest checks re-run |
| **NR** Quest text review | 2 (after N3) | page | an Opus review of every changed quest text (as Round 36's text rounds), suggestions on a page for the user |
| **D** Round documentation | 3 | docs | naming rules into AGENTS.md and the design frame, completion, GUI checklist |

## 4. The preview page (N2)

- **Family view:** each family's ladder (e.g. pigs: Piglet → Pig → Hog →
  Old Tusker as elite) with sprites or the tinted mob render, the zones and
  levels where each word appears.
- **Zone view:** per zone and belt, today's name → proposed name, level
  range, which quests name it; rows the rules flag (word count, collision,
  a name over two drop tiers or with a level gap) stand out.
- Accept by default, edit inline, one export block for the user (as the
  Round 36 text pages).

## 5. Answered (user, 2026-10-06)

1. Reuse across zones: allowed, no fixed rule (§2.5); Piglet reserved
   (§2.4).
2. Zone flavour: yes, not blunt (§2.5).
3. Named mobs, elites and bosses: all on the page for the overview; the
   three-word ones keep their names (§2.3).
4. The kill-credit bug stays until this round and is fixed with the names
   (§2.1).
5. Opus proposes the names.
6. Added by the user: not every level band needs its own name (§2.2), and
   the name is the exact quest target (§2.1).

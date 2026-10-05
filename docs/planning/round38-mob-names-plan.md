# Round 38 — Mob names: design round plan

Coordinator: Claude (Opus 5.5), drafted 2026-10-06 from the user's naming
request during Round 37 and the kill-credit bug found in the user's
playtest. Status: **draft, awaiting the user's answers to §5**.

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

## 2. Rules (user, 2026-10-06; proposal to confirm in §5)

1. **Normal mobs: at most two words.** "Shore Crab", "Reef Lurker".
2. **Named mobs, elites and bosses: at most three words** (leaders, rares,
   captains, commanders, Kings, Generals, dragons, the rift boss).
3. **No signal words.** Variety comes from each family's own vocabulary
   (pigs: Piglet, Pig, Sow, Hog, Boar …); size and the nametag colour carry
   the rank.
4. **One name per level belt:** where a role spawns in several belts of a
   zone, each belt's mobs get their own name, so a quest's target is
   unambiguous; a quest with an area counts its whole belt (every region of
   that belt), not one region.
5. Kill quests keep naming the exact mob and place (design frame §5); the
   faction names stay The Accord and The Throng; no name refers to an
   existing game.

## 3. Lanes

| Lane | Wave | Kind | Content |
|---|---|---|---|
| **N1** Inventory and vocabulary | 1 | analysis + page | every name slot (sub-type × zone × belt, leaders, rares, elites, bosses, captains), today's name, word count, where quests and texts use it; a family vocabulary sheet (per family: 4–8 candidate words by size/age/temper/look) |
| **N2** Proposal | 1 (after N1) | page | a full old → new table per zone and belt that keeps every rule of §2, from the vocabulary; the preview page for the user (German frame, English names), per family and per zone, with accept / edit per row and an export the user pastes back |
| **N3** Implementation | 2 (after the user's picks) | code + data + texts | names by zone and belt at runtime (the name is applied after the area tag), quests count the belt, the naming validators rewritten to the new rules, quest titles and texts that name a mob updated by script, region/quest checks re-run |
| **NR** Quest text review | 2 (after N3) | page | an Opus review of every changed quest text (as Round 36's text rounds), suggestions on a page for the user |
| **D** Round documentation | 3 | docs | naming rules into AGENTS.md and the design frame, completion, GUI checklist |

## 4. The preview page (N2)

- **Family view:** each family's ladder (e.g. pigs: Piglet → Pig → Hog →
  Old Tusker as elite) with sprites or the tinted mob render, the zones and
  levels where each word appears.
- **Zone view:** per zone and belt, today's name → proposed name, level
  range, which quests name it; rows the rules flag (word count, collision,
  same name in two belts) stand out.
- Accept by default, edit inline, one export block for the user (as the
  Round 36 text pages).

## 5. Questions for the user

1. **Name reuse across zones:** may two zones use the same name for the
   same family at a similar level (e.g. "Hog" in three zones)? Reuse keeps
   the count small (about 160 tier names instead of about 300) and lets a
   word mean a size everywhere; unique per zone gives more flair.
2. **Zone flavour:** keep zone-flavoured names such as "Plague Boar" or
   "Jungle Boar" (two words), or one family vocabulary everywhere and let
   the tint show the zone?
3. **Leaders, rares and bosses:** rename only those over three words, or
   review all named mobs on the same page?
4. **Kill-credit bug in the meantime:** the fix needs the new names to be
   clear, so it ships with this round. Accept that the bug stays until then
   (recommended), or ship a stop-gap now (any mob of that sub-type in the
   zone counts, briefly with the unclear names)?
5. **Who proposes names:** Opus (recommended; the same routing as this
   round), or GPT-6 Astra for the vocabulary as a creative pass with an Opus
   review?

# TODO — Crafting rework: what the 2026-08-07 session left open

The crafting/professions/materials rework was decided on 2026-08-07 and
folded into `docs/design/` (commit `d5baf03`): the two ladders
(`items_crafting.md` §2.1), the six-tier material ladder (§3.0), one item
per concept (§3.0.3), depth gating by rock strata (§3.0.4), the six
material-cut professions (`professions.md` §2), the one recipe book per
profession (§2.2) with the surviving keystones (§2.3), refinement and the
prefix/suffix affixes (§6b), the six-step housing depth ladder
(`world.md` §5.3 / `economy.md` §4.1 / `items_crafting.md` §8.4), the
removal of the continental mining claims (`guilds.md` §3.2), the herb /
spice split (`biomes_mobs.md` §2) and the new `mounts.md`.

**Everything in this file is open unless its *Decision* line says
otherwise.** No decided *rule* lives here — a decided question keeps only
a one-line stub naming the design file it landed in, so the reasoning
behind it stays findable; the rule itself lives in `docs/design/`.
Several design sections point here by name for exactly these lists.

Once a question is decided: fold it into the design doc named in its
*Lands in* line, update ROADMAP/BACKLOG where affected, and replace the
question with that stub. When nothing open is left, delete the file
(AGENTS.md "Documentation layers").

Groups: **A** crafting & items · **B** materials & world · **C** two
design tensions · **D** mounts · **E** cooking.

---

## A. Crafting & items

### A1 — Signature recipes per profession per mastery tier

`items_crafting.md` §2.1 statement 3 makes it binding that **mastery
brings a few profession-exclusive recipes per tier**, and §3.0.3 forbids
a profession from ever making a *parallel* base item. So a signature
recipe can only be a consumable, a kit, a container, an offhand, a
trinket, a fitting or a detector — never a sword or a chestplate that
already exists on the base ladder.

What is already authored:

- **Tailor — bags, all four tiers**: 8 / 16 / 24 / 32 slots (§3.5,
  `inventory_equipment.md` §3). The one fully decided line.
- **Alchemist** — §3.6's table is already cut by mastery tier
  (Apprentice/Journeyman/Expert/Master) and needs only its material
  costs.
- **Tailor — spell tome** at Journeyman / Expert / Master (+10/+20/+30
  mana, §3.5).
- Prose, but **not** cut by tier: Blacksmith shields "Journeyman+",
  metal fittings, whetstone/polish kits (§3.3, §7); Leatherworker armor
  kits "from Journeyman up" and the quiver (§3.4); Woodcarver bows
  (Phase 2, §3.6a); Goldsmith trinkets, Gem Detector, the 10 → 20 %
  mining gem bonus (§3.6b).

Open: an explicit **profession × mastery tier** table with the material
cost of every row, for Blacksmith, Leatherworker, Woodcarver and
Goldsmith, plus the tier cut of the Tailor's non-bag rows.

Options:

- **(a) Two rows per tier per profession** — 6 × 4 × 2 = 48 rows, hand
  authored. Symmetric, easy to check against §2.1.
- **(b) One row per tier, plus more at Master** — front-loads the
  interesting recipes at the end of the ladder, matching §2.4's "at 60
  the professions stay load-bearing".
- **(c) Derive from the existing lines only** — every profession gets
  its §7 kit line cut across four tiers and nothing else. Cheapest,
  thinnest.

Recommendation: **(a)**, because the four mastery tiers are also the
enchant-slot ladder (§6b.5) and a tier that hands over *only* a slot
count reads as an empty level-up. Author them against the §3.0.3 filter
above — if a proposed row duplicates a base item, it is not a signature
recipe.

*Lands in*: `items_crafting.md` §3.3–§3.6b (per-profession sections),
plus a summary column in §2.1.
**Decision:** _open_ — blocks nothing, but WP10 cannot ship the books
without it.

### A2 — The affix word lists and their stat mapping

`items_crafting.md` §6b.4 decided the **grammar** and points here for the
**vocabulary**: max 2 prefixes + 2 suffixes, prefixes as adjectives
(*lucky*, *quick*, *heavy*, *clever*), suffixes in the genitive (*of the
bear*), two suffixes combining as "of Bear and Ox", the refinement word
dropping as soon as an affix appears. §6.2 holds the stat **pools** per
item family and §6.3 the **values**.

Open: the word list, the stat each word maps to, and which affix is legal
on which item family.

Two constraints the list must satisfy:

- §6.2 is the legality table already — an affix is legal on a family iff
  its stat is in that family's pool. Nothing new has to be invented for
  legality *if* every affix maps to exactly one §6.3 stat.
- §6.2's "no duplicate stat per item" means the two prefixes must carry
  different stats, and a suffix may not repeat a prefix's stat. That is a
  roller rule (WP5), but it constrains the vocabulary: a word must
  identify its stat unambiguously.

**The example list was not conformant, and is fixed.** §6b.4's *of the
snake* mapped to "+poison", and there is no poison stat anywhere in
`combat_stats.md` or in §6.2/§6.3 — it was an off-hand example, never a
decision. **Poison is out of scope for the MVP affix list** (decided
2026-08-08): the example is now *of the cat* (+dodge), a stat the §6.2
pools actually contain, and poison is recorded in `classes.md` §6 as
arriving with the **Rogue in Phase 2** as its signature damage type. Any
word list authored for this question must map every word to a stat that
exists in §6.2 — no candidate may reintroduce poison, and promoting
poison to a real stat is Rogue work (a damage-over-time consumer in the
`classes.md` §2 pipeline), not affix work.

Options:

- **(a) One word per stat, one set** — 9 stats in §6.3 (+Str, +Int,
  +Dex, +HP, +Mana, +Crit%, +Dodge%, +Attack speed%, +Armor%), 9 words,
  used as prefix or suffix depending on where the roller puts them.
  Smallest list, but "Sword of the Heavy" reads badly.
- **(b) A prefix word and a suffix word per stat** — 9 + 9 = 18 words,
  adjectives for prefixes and animals for suffixes exactly as §6b.4
  sketches. The stat space is covered twice, so any roll can be phrased
  either way.
- **(c) Several synonyms per stat, chosen by roll strength** — "heavy"
  vs "massive" for a low vs high +Str roll. Flavourful, but it makes the
  word a second, redundant display of the number that the grey stat line
  already shows (§6b.4's own division of labour: "the word says which
  stat, the line says how much").

Recommendation: **(b)** — 18 words, one per (position, stat) pair, no
synonyms. Legality then needs no table of its own: it falls straight out
of §6.2, and adding the trinket row of A3 extends it for free.

*Lands in*: `items_crafting.md` §6b.4 (word table) — §6.2 stays the
legality source.
**Decision:** _open_ — **blocks WP5** (the roller needs the words to
build a display name). The **poison sub-question is decided
2026-08-08**: out of scope for the MVP affix list → landed in
`items_crafting.md` §6b.4 (example replaced by *of the cat*) and
`classes.md` §6 (poison arrives with the Rogue in Phase 2). The word
list itself is untouched by that and still has to be authored.

### A3 — Trinkets (and bags) have no enchant pool

**Decision (trinket half):** decided 2026-08-08 → landed in
`items_crafting.md` §6.2 (the new **Trinkets** pool row — +Str, +Int,
+Dex, +HP, +mana, +crit%, universal-ish because every class wears both
slots, deliberately no +armor%/+dodge%/+attack speed%) and
`items_crafting.md` §6.3 (the cap check **re-run for 8 slots**: crit
worst case ≈ 36 % against a 30 % cap — it clamps, dodge ≈ 19 % and the
60 % armor cap are untouched). Option **(a)** below was taken, together
with C11's option (b). The reasoning stays here; the rule lives there.

**Owner steer, 2026-08-08 — trinkets are NOT finished planning and must
not be implemented before they are.** The direction to work out: a
trinket probably deserves **its own kind of enchantment rather than the
normal prefix/suffix affixes**, because it has **no base value at all** —
no damage number, no armor number — so both the refinement bonus and the
affix model that hang off a base value have nothing to bite on. That
makes option **(b)** below (fixed special effects, §6b.7 shape) the more
likely resolution than the pool row that was provisionally landed under
(a). Re-open this before WP5 or WP10 touches trinkets: the §6.2 pool row
already in the doc is a placeholder, not a settled rule.

**Still open below: the bag half — and the same gap now applies to
trinkets.** §6b.1's refinement-word table has no row for trinkets, and
§6b.2's refinement bonus ("+15 % base damage or the armor equivalent,
+100 % durability") has nothing to attach to on an item that has neither
a damage number nor an armor number. Since §6b.3 makes refinement the
prerequisite for *every* affix, the new §6.2 trinket row needs that
answered before WP5 can roll one — it is exactly the bag problem, on a
second family. Options (d)/(e) below were written for bags; whatever is
chosen has to cover trinkets too, or trinkets need their own base-stat
line in §3.1/§3.2 for the +15 % to bite.

The bag hole as originally written: §6b.1 makes **bags** an
"Ornate" refinable family, but §6b.2's refinement bonus is "+15 % base
damage or the armor equivalent, +100 % durability" — a bag has neither a
damage number nor durability, and no §6.2 pool. Today "Ornate Bag" is a
name with no effect behind it.

Options for trinkets (**(a) was taken**, see the decision stub above):

- **(a) Own pool row.** Proposal: +Str / +Int / +Dex (one primary),
  +HP, +Mana, +Crit% — deliberately *no* +Armor%, so trinkets never
  compete with armor for the 60 % cap (§6.3's cap safety note is
  computed for 6 slots: weapon, offhand, 4 armor — adding 2 trinket
  slots re-opens that arithmetic and has to be re-checked).
- **(b) Trinkets are enchant-free and carry a fixed effect each**, in
  the shape of §6b.7's special variants. Distinct identity, no pool
  needed, but it makes the Goldsmith the one profession whose product
  ignores the whole affix system.
- **(c) The pool follows the wearer's class** — rejected on sight: item
  meta is rolled at craft time and cannot know its future wearer.

Options for bags: **(d)** bags carry no affixes and refinement gives
them a defined bag-specific bonus (e.g. +4 slots, which collides with
the four fixed sizes of `inventory_equipment.md` §3); **(e)** bags are
removed from §6b.1's refinable families entirely and the "Ornate" word
covers cloth armor and spell tomes only.

Recommendation: **(a)** for trinkets — with the §6.3 cap arithmetic
re-run for 8 slots — and **(e)** for bags: the bag line is already the
Tailor's four-tier signature ladder (A1), it needs no second progression
axis, and "you cannot refine a bag" is one sentence rather than a new
bonus type. **(e) cannot simply be extended to trinkets**: a trinket
that may not be refined may not be enchanted either (§6b.3), which would
empty the §6.2 row just added.

*Lands in*: `items_crafting.md` §6.2 (new row — **done 2026-08-08**),
§6.3 (cap re-check — **done 2026-08-08**), §6b.1 (the refinement-word
row for bags **and** trinkets) and §6b.2 (what refinement gives an item
with no damage and no armor number).
**Decision:** trinket pool + cap arithmetic **decided 2026-08-08**
(→ `items_crafting.md` §6.2/§6.3). **Open**: the bag half, and the
refinement question for both bags and trinkets. Blocks WP5's roller for
trinkets only, nothing else.

### A4 — T5/T6 keystones, and the two new professions' keystone rows

`items_crafting.md` §2.3 carries keystones for **T2/T3/T4 only**, and its
Woodcarver and Goldsmith rows are empty and point here. The rule is
decided (a keystone is the redemption token that opens a book group; the
materials prove the player has been in the ring that produces them); the
lists are not.

Missing: **T5 and T6 columns for all six professions**, and the **T2–T6
rows for Woodcarver and Goldsmith**.

Constraints the lists must respect:

- The shape of the existing rows: ~6 units of the tier's own material
  plus 2–4 units of a ring-specific mob drop; T4 already adds
  `group:grug_rare_trophy`.
- §2.4's pacing: a keystone is ~30–60 min of natural play in the ring
  just reached.
- **T6 is behind a purchase.** Abyssal Crystal is a housing-depth
  resource (§5.5, world.md §5.4 step 6 — the 1g step) plus the 10 %
  apex-hoard bridge (§10 P5). §3.0.1 already accepts this for the T6
  *metal*; a T6 keystone that also demands Abyssal Crystal doubles the
  gate. Decide whether that is intended.

Recommendation: T5 = 6 × the tier material + 2 × an outer/coast drop;
T6 = 6 × the tier material + 1 rare trophy **and no Abyssal Crystal** —
the crystal is already spent on every Grudgesteel bar (§3.0.2), so
charging it twice makes T6 crafting hostage to the depth ladder in two
places. Woodcarver rows key off the per-race woods and the Blacksmith
fittings it cross-buys (§3.6a); Goldsmith rows key off gold bars plus the
tier's gem (Quartz T2, Garnet T4, Diamond T6) — which also makes B8's
scarcity values load-bearing.

*Lands in*: `items_crafting.md` §2.3 (extend the table to T2–T6 × 6
professions).
**Decision:** _open_ — **blocks WP10** (the book cannot gate groups
without them).

### A5 — T5/T6 leather and bolt grades, and the Woodcarver's wood grades

The material chains stop short of six tiers in three places:

- **Leatherworker** (§3.4): T1 light, T2 cured, T3 heavy, T4 scaled —
  **T5 and T6 open**.
- **Tailor** (§3.5): T1 patch bolt, T2 woven, T3 heavy, T4 silkweave —
  **T5 and T6 open**.
- **Woodcarver** (§3.6a): "grades follow the six tiers", **no grade
  named at all**.

These are not internal labels. §3.8 makes them **item names**: cloth
items take their bolt grade and leather items their leather grade
(Linen Robe, Silkweave Cowl), and under §3.0.3 a Woodcarver staff must
be material-named like everything else. Whatever is chosen is what
players read on the item.

Two constraints:

- **Both continents must reach every grade** (`biomes_mobs.md` §3.2's
  binding cross-continent drop-table pairs, §6's base-material map).
  A T5 hide from a mob that exists on one continent only is not
  acceptable.
- Level 41–60 sources have to exist. Check the T5/T6 grades against the
  outer/coast rosters of `biomes_mobs.md` §3.1 before naming them.

Options for wood specifically:

- **(a) Six processed grades of any wood** (seasoned → hardened → …),
  with the per-race woods of `biomes_mobs.md` §5 (silverwood, gravewood)
  as a cosmetic skin. Satisfies the both-continents rule by
  construction.
- **(b) Six distinct tree species**, one per tier. Flavourful, but it
  needs six mirrored tree registrations and six mapgen bands, and the
  per-race woods then compete with the tier ladder for the same name
  slot.

Recommendation: **(a)** for wood; for leather and cloth, name T5/T6 from
existing outer/coast drops rather than inventing new mobs.

*Lands in*: `items_crafting.md` §3.4, §3.5, §3.6a; cross-check
`biomes_mobs.md` §6.
**Decision:** _open_.

### A6 — Does a refined item show a marker once it is enchanted?

`items_crafting.md` §6b.4 removes the refinement word from the name as
soon as an affix is present ("Stone Sword of the Ox", never "Honed Stone
Sword of the Ox"), on the argument that §6b.3 makes "enchanted" imply
"refined". The **grey stat line still shows the number** (§6b.2), so the
+15 % is visible; what is not visible is the *word*.

Open: whether an enchanted item should carry any other visible sign that
it is refined.

Options:

- **(a) Nothing** — the status quo of §6b.4. An affix implies
  refinement, and a player who wants proof reads the stat line or the
  doubled durability.
- **(b) A tooltip line** — one extra grey line, "Refined", above the
  affix lines. No art, no name-length cost, and it gives §6b.7's
  **special variants** somewhere to state their effect, which they
  currently do not have.
- **(c) An icon marker** — a corner overlay or a colour tint, reusing
  the trim/colourise technique §6b.7 already adopts from
  VoxeLibre `mcl_armor/trims.lua`. Visible in the inventory grid without
  hovering; costs an overlay texture per family.
- **(d) The durability bar carries it** — 6000 vs 3000 wear (§6b.2,
  §8.3) is already rendered by the engine. Free, but unreadable on a
  fresh item, which is exactly when a buyer looks.

Recommendation: **(b)**. It is the only option that also solves the
special-variant display problem, and it costs one string.

*Lands in*: `items_crafting.md` §6b.4 (and §6b.7 if the variant line
comes with it).
**Decision:** _open_ — WP5 owns the description builder, so decide
before WP5 writes it.

---

## B. Materials & world

### B7 — Rock-stratum node names and textures (six strata)

**Decision:** decided 2026-08-08 → landed in `items_crafting.md` §3.0.4
(the stratum table with names, bands, `level`s and textures, the
re-parameterised pick `maxlevel`s, the placement rule, the cobble drop,
the `grug_stratum` group and `cracky = 3`) and `world.md` §2 R6 (the
world rule: node names, cobble drop, cave walls). The reasoning stays
here; the rules and numbers live there.

What the decision actually turned on, and would be expensive to
re-derive:

- **`default:stone` is kept as the T1 stratum**, so there are six strata
  but only five new nodes. A separate T1 node would have had to be
  dragged through the mapgen filler, the cobble source, the `wherein` of
  every ore registration and several recipes — for nothing.
- **Placement is `register_ore{ore_type = "stratum"}`, not a
  `grug_mapgen` y-band VoxelManip pass**, and the strata are registered
  **last**. In mgv7 the ore stage runs *after* cave generation and
  before the dungeons (`mapgen_v7.cpp:335/355/359`) and registration
  order is placement order — so **cave walls inherit their stratum for
  free**. That was the real question in this item: plain-stone cave
  walls would have made every deep cave a bypass for a level-10 player.
  The VoxelManip route would have had to re-solve the cave problem by
  hand.
- **Six `level` steps need six `maxlevel` steps**, and `default` ships
  only three — hence the `core.override_item` pass over the vendored
  picks (`default` stays unpatched, VENDOR.md). Accepted side effect:
  bronze stops breaking obsidian. **T2 has no tool of its own until
  WP26/WP29**; the steel pick spans T2+T3 and iron lies in the T1 band,
  so the ladder is walkable to −500 with today's item set.
- The isle generator cannot ride on the ore stage (`register_ore` only
  runs in the mapgen), so it asks `grug_materials.stratum_node_for(y)`
  instead — that is the WP24 interface (`world.md` §5.3).

Rejected: a separate T1 stratum node; the y-band VoxelManip pass; six
hand-made 16px textures (Phase 3 work — `^[colorize` on
`default_stone.png` was taken instead); and reusing `default`'s existing
stone family (stone / desert_stone / sandstone), which already carries
biome meaning and would have made depth and biome say the same thing.

*Landed in*: `items_crafting.md` §3.0.4, `world.md` §2 R6/§5.3.

### B8 — Quartz and Garnet: depth placement and scarcity

**Decision:** decided 2026-08-08 → landed in `items_crafting.md` §3.0.1
(the ore placement table — bands, `clust_scarcity`, `clust_num_ores`,
`clust_size` — plus the band rule, the ore `level` rule and the Abyssal
Crystal placement). Silver, iron and Emberstone were authored in the
same pass. The reasoning stays here; the numbers live there.

What the decision turned on:

- **The band rule**: a lead metal lies one band *above* its own tier, a
  gem in its own band — otherwise a tier-n tool would be needed to reach
  the material a tier-n tool is made of. It also settles how §3.0.1's
  "Digging depth" column reads: it is a *tool* depth, not a find depth.
- **The iron deadlock**, found while checking the rule against the
  vendored ores: iron starts at −128, i.e. *below* the T2 stratum that
  already demands an iron or steel pick. The new −1 … −100 iron band is
  a deadlock fix, not tuning.
- **The ore `level` leak**, found while checking B7's cave-wall
  inheritance: if an ore carried the `level` of its own tier, a cave at
  −600 would expose Silver to any bronze pick. Fixed by giving an ore
  the `level` of the *band* it lies in — an ore is exactly as hard as
  the rock around it — which does not deadlock anything, because the
  band rule already put the metal one tier shallower.
- **Calibration** stays what it was: gems are a reagent, not a rarity
  (§6.4 spends one on every fine recipe), so Quartz sits at iron's
  density and Garnet at copper's. Re-tune against §2.4 after the first
  runtime test rather than on paper (pattern:
  `docs/research/wp6_spawn_budget.md`).
- **Abyssal Crystal gets no continental deposit at all** — WP25
  registers node and item, WP24 (isle treasure clusters) and WP23 (the
  10 % dragon hoard) place them. That keeps §3.0.2's binding statement
  literally true: Grudgesteel needs the level-30 isle grant and its
  deepest depth step.

*Landed in*: `items_crafting.md` §3.0.1.

### B9 — `grug_core.open_sea_at` starts open sea 3200 nodes out

`open_sea_at(pos)` is a pure Chebyshev distance from the nearer continent
rectangle compared against `OCEAN_COASTAL_WIDTH` (1500), so open sea
begins at |z| = 3200. `BACKLOG.md` already flags this in the WP24
readiness note (it would spawn Kraken Guards on housing beaches,
`world.md` §2b), and `mounts.md` §4.1 now inherits it one-for-one:
until it is fixed, the "Exhausted" debuff fires on a player's own isle
beach.

**This is now a hard precondition for two systems, not one** — WP24 and
the mount rule. `mounts.md` §4.2 additionally requires that the isle
no-mount zone and the open-sea rule **meet exactly at the isle's
150-node safe ring with no gap**.

Options:

- **(a) Make the function isle-aware** — it returns false inside every
  isle's 150-node safe ring, and keeps its continental semantics
  unchanged. The housing band lives inside the open sea by construction
  (`world.md` §5.6), so an exception is the honest model.
- **(b) Shrink `OCEAN_COASTAL_WIDTH`** — moves the Kraken Guard *toward*
  the continents, which is the opposite of what §2b wants, and does
  nothing for the isles.
- **(c) A separate "safe water" predicate** consulted by every caller —
  more surface, and every future caller has to remember both.

Recommendation: **(a)**. Keep one predicate; `mounts.md` §4.1's "the
mount rule calls the function and nothing else" then stays true.

*Lands in*: implementation, not design — `world.md` §2b's wording only
needs the isle exception spelled out.
**Decision:** _open_ (mechanism) — the *need* is decided. Owner: WP24;
the mount WP consumes it.

---

## C. Two design tensions

These two are not gaps in a list. Both are consequences the rework
produced deliberately, and both leave a profession standing on very
little in the MVP. They want a decision, not an author.

### C10 — Leather is wearable but nobody wants it

**The situation.** Leather is armor class 2 (`inventory_equipment.md`
§2). The MVP classes are Warrior 3, Mage 1, Priest 1; the Rogue, the
class leather was designed for, is Phase 2 (ROADMAP). WP7 therefore
shipped the leather curve in the generator with `register = false`, and
`items_crafting.md` §3.4/§3.8 kept the items unregistered. Under
§3.0.3's one-item-per-concept merge, the vendor catalog and the base
craft ladder are the same items — so a line that does not register does
not exist **anywhere**, vendor or craft.

What is left for the profession in the MVP:

- **Armor kits** (§7, Journeyman up) — real, but they upgrade armor the
  profession itself cannot make anyone wear.
- **The quiver** (§3.4) — dead until §9's bows, i.e. Phase 2.
- **Cross-supply**: leather to Tailors (bags), Alchemists (apothecary
  gear), Woodcarvers (grips) — `professions.md` §3.

Against the Blacksmith's five families that is one active line and two
feeders. And WP6 already wired the ×5 leather loot hook
(`register_drop_hook`, `grug_leather` group), which rewards a profession
whose output nobody wears.

**A factual correction the options depend on** (applied to the design
docs on 2026-08-07). An earlier draft of `items_crafting.md` §3.4 and
`professions.md` §2 said "no MVP class can wear rank-2 armor". That is
**not** what the shipped rule says: `inventory_equipment.md` §2 grants
each class "its own rank **and everything below**", and
`grug_inventory/equipment.lua:113-116` refuses only `rank > max`. A
**Warrior (rank 3) can already equip leather (rank 2) today** — the
filter allows it, there are simply no items. Both doc passages have
been corrected to say so and to point here; the real question is not
*may* a Warrior wear leather but *why would he*, since at equal tier
leather is strictly less armor than metal.

Options:

- **(a) Ship as decided.** Accept an asymmetric MVP roster; the line
  switches on with the Rogue or with WP5's drop tables, whichever lands
  first. Zero cost, and it is the status quo of §3.4/§3.8.
- **(b) Pull the Rogue into the MVP.** Solves it completely and solves
  nothing else cheaply — a class kit, a talent tree, the stealth
  research of ROADMAP Phase 2, and it grows the MVP by a class.
- **(c) Register the leather line and make it the Warrior's light
  set.** The rank filter already permits it, the curve is already in
  the generator, and §6.2's leather pool (+Dex, +HP, +crit%, +dodge%)
  against metal's (+Str, +HP, +armor%, +dodge%) is exactly a
  mitigation-vs-avoidance choice. Cost: 24 registrations and one
  balance question — a Warrior in leather must not out-perform plate
  badly enough to make plate pointless. §3.1's curve already prices
  leather below metal, so the tuning knob exists.
- **(d) Broaden the profession's exclusives.** Thin: belts and gloves
  would need new equipment slots, and `inventory_equipment.md` §2
  deliberately has none free in the MVP.
- **(e) Drop the Leatherworker from the MVP roster**, merging leather
  into the Tailor until the Rogue arrives. Smallest roster, but it
  breaks `professions.md` §2.1's "three armor classes, three
  professions" and has to be un-merged later.

Recommendation: **(c)**, with **(a)** as the fallback if the balance
work is unwanted this phase. It costs no new class and no new slot, it
lights up 24 items that are already generated, it gives the Warrior a
real gearing decision instead of a single upgrade line, and it retires
the "nothing can wear leather" clause instead of carrying it into
Phase 2. Whichever is chosen, **§3.8's sentence needs correcting** —
today it states as fact something the shipped filter contradicts.

*Lands in*: `items_crafting.md` §3.4/§3.8, `professions.md` §2, and
(if (c)) `inventory_equipment.md` §2's rationale.
**Decision:** _open_ — affects WP5's drop tables and WP10's scope.

### C11 — The Goldsmith's headline product is post-MVP

**Decision:** decided 2026-08-08, option **(b)** — **trinkets are pulled
into the MVP** → landed in `inventory_equipment.md` §2 (the two slots
are no longer reserved; trinket items ship as the Goldsmith's exclusive
family, no armor class, no rank binding), `items_crafting.md` §3.6b (the
profession's headline is a product, not a promise), `items_crafting.md`
§6.2/§6.3 (the pool row and the re-run cap arithmetic — A3) and
`professions.md` §2.1 (the coverage bullet). The situation and the
options below are kept for the reasoning.

**The situation.** `professions.md` §2.1 celebrates that "both trinket
slots finally have an owner" — the Goldsmith (`items_crafting.md`
§3.6b). But `inventory_equipment.md` §2 keeps both trinket slots
**reserved**: UI and meta shipped with WP15, the items are post-MVP. So
in the MVP the profession stands on three things, and two of them depend
on other unshipped work:

- **Gem refinement** — cutting raw gems into the reagent every fine and
  masterwork recipe wants (§6.4). Real and central, but only once WP5
  and WP10 exist.
- **The Gem Detector** (`world.md` §5.4) — only useful on a housing
  isle, i.e. after **WP24**.
- **The mining bonus gem chance** (10 % → 20 % at Journeyman) — the one
  thing that works on day one, and it is a passive, not a product.

It is the only one of the six professions with no wearable output of its
own in the MVP, and A3 shows the gap is doubled: trinkets have no
enchant pool either.

Options:

- **(a) Ship as decided.** The Goldsmith is a supplier profession in
  the MVP. Honest, cheap, and it makes gem supply a real market. Risk: a
  player picking it at level 5 gets almost nothing for a long time — so
  it should at least not be offered before WP24 ships, or be flagged in
  the trainer text.
- **(b) Pull trinkets into the MVP.** The slots, the meta and the
  `allow_put` filter already exist (WP15); what is missing is an item
  family, a curve and the §6.2 pool row of A3. No model, no armor class,
  no rank binding — trinkets are the cheapest missing content in the
  game. It also fixes A3 by construction and gives the sixth profession
  its own product.
- **(c) An interim line — gem sockets/inlays** applied to other
  professions' refined items. Rejected on sight: a fifth stat channel
  next to §6b's hard 4-slot ceiling, and it re-opens §6.3's cap
  arithmetic for no design gain.
- **(d) Defer the Goldsmith to Phase 2** and hand gems back to the
  Blacksmith. Breaks §2.1's coverage argument and re-creates the
  ownerless trinket slots the re-cut was made to fix.

Recommendation: **(b)**. Two slots that already exist, one curve, one
pool row — and it turns the profession's headline from a promise into a
product. If (b) is rejected, take **(a)** *plus* the explicit note that
the Goldsmith's value in the MVP is the gem reagent, and say so at the
trainer.

*Lands in*: `inventory_equipment.md` §2 (slot status),
`items_crafting.md` §3.6b, §6.2 (with A3).
**Decision:** **(b), decided 2026-08-08** — see the stub at the top of
this question. What (b) does **not** answer is the trinket base-stat
curve and the refinement bonus for a family with neither damage nor
armor; that stays with A3.

---

## D. Mounts

`docs/design/mounts.md` (new, 2026-08-07) decides the four tiers and
their speeds (§1.1), the prices (§2 — 1s/8s/30s/60s ≈ 1g total), that a
mount is an attached entity and never `physics_override.speed` (§3), the
open-sea "Exhausted" rule (§4.1) and the isle no-mount rule (§4.2), plus
the licence-checked reference implementations (§5). It **deliberately
left everything below out** — none of it is needed to keep the design
coherent, all of it is needed before a work package can ship.

### D12 — Is there a saddle ITEM, and what are the mount assets?

`items_crafting.md` §3.0.3's cleanup removes `mobs:saddle` / `lasso` /
`net` (`mounts.md` §3 — taming was rejected). But the acquisition
pattern §5 recommends, LotT's `lottmobs:register_horse`, is exactly *a
craftitem whose `on_place` spawns the mount entity* — that item **is** a
saddle in all but name.

Open: (i) does the purchase hand over an inventory item, or a permanent
per-character flag plus a summon action; (ii) which models for four
mounts, and from where.

On (ii): `mounts.md` §5 clears the *code* licences (mobs_redo MIT, LotT
LGPL 2.1, VoxeLibre GPL-3.0-or-later) but names **no model** for a
flying mount. mobs_redo ships none; VoxeLibre's `mobs_mc/horse.lua`
covers the land tiers. Assets have to go through the AGENTS.md licence
rule (re-verify in the source repo before import) and the shopping-list
pattern of `docs/research/assets/`.

Recommendation: **one item per tier, no separate saddle** — a second
token for the same act would violate one item per concept
(`items_crafting.md` §3.0.3), and the removal of `mobs:saddle` was
decided on exactly that ground. Tie the choice to D13.

**Decision:** _open_.

### D13 — Does a mount persist in the world after dismount?

Open: after `mobs.detach`, does the mount entity stay standing where it
was left (Minecraft/LotT-like) or return to the owner's inventory as the
D12 item (WoW-like)?

Options:

- **(a) Back to the inventory.** No entity budget cost, nothing to
  steal or grief, no despawn timer, and it matches §1's "bought,
  permanent, per character".
- **(b) Stays in the world.** Needs an owner check, a despawn or
  reclaim rule, and it competes with the active-object budget the WP6
  spawn audit (`docs/research/wp6_spawn_budget.md`) measured. A lost
  mount also becomes a support question.

Recommendation: **(a)** — it also makes D14 nearly moot.

**Decision:** _open_.

### D14 — Can mounts be attacked, damaged or killed, and do they drop anything?

`mounts.md` §3 already says a mount carries no level, no XP, no threat
and no aggro, and is **not** registered through `grug_mobs.register_mob`
(that wrapper is the level engine). It does not say what a punch does to
it.

Options: **(a)** invulnerable, no drops — a permanent purchase must not
be destructible, and PvP counterplay is D15's dismount instead;
**(b)** killable with the mount returning to the owner (a cooldown, not
a loss); **(c)** killable and lost — rejected: 60s of gold deleted by
one gank.

Recommendation: **(a)**.

**Decision:** _open_.

### D15 — Does damage or combat dismount the rider?

The natural hook exists: `grug_core.mark_in_combat` / `in_combat`
(5 s window, shipped with WP4 and reused by WP6's leash and by
recovery).

This is the load-bearing one. Mobs run 4.4 nodes/s (`combat_stats.md`);
an Apprentice mount does 6 and a Journeyman 8. **Without a rule, a
mounted player is immune to the entire mob game** — the 25 m soft
de-aggro and the 40 m leash of WP6 become unreachable by design.

Options: **(a)** any damage dismounts immediately; **(b)** being
`in_combat` blocks *mounting* but does not dismount; **(c)** both — damage
dismounts, and mounting is refused while in combat; **(d)** a damage
threshold or a cast-like remount delay.

Recommendation: **(c)**. (a) alone lets a player remount mid-fight; (b)
alone lets a player ride away from a fight already started.

**Decision:** _open_ — this one has to be decided before the WP, not
during it.

### D16 — Is riding restricted in enemy territory, on the war coast, in PvP, or underground?

**Decision (enemy-territory switch only):** decided 2026-08-08 → landed
in `mounts.md` §4.3. **Land mounts are allowed everywhere**, enemy
territory included; **flying mounts are banned in enemy territory** — a
flying mount cannot be summoned there, and a rider who crosses the
border while flying is dismounted after the **same 10-second warned
grace** as §4.1's "Exhausted", so the game has one number and one shape
for "you are somewhere your mount may not be". The mechanism is
`grug_core.territory_at(pos)` (`mods/CORE/grug_core/init.lua:586-596`,
returns `accord`/`throng`/`ocean`) compared against the rider's own
faction; over water it is silent, so §4.1 keeps the strait and the open
sea and the border rule takes over on landfall. `mounts.md` §1.1 carries
the one-line summary.

**The other three switches were not answered and stay open:**

- **The war coast.** The recommendation below asks for flight to be
  refused over **both** war coasts, i.e. also over one's *own*. The
  enemy-side half is now covered by the territory ban; the **own-side
  half is undecided** — a defender flying along their own war coast is
  still legal under §4.3.
- **While flagged for PvP.** Untouched. The recommendation to fold it
  into D15 (the combat dismount) rather than make it a fifth zone rule
  still stands and is still unanswered.
- **Underground.** Untouched. The recommendation below (unrestricted —
  the §3.0.4 depth ladder gates *breaking* rock, not reaching it) is
  still only a recommendation, and D17's flight-ceiling half is its
  mirror image upward.

The original context and options are kept below.

`world.md` §1 builds the whole invasion model on the war-coast funnel
(guard strength runs inverse, the strait-facing band is capped 20–30 and
is where PvP is meant to happen), and §6 already denies waypoints in
enemy territory for the same reason. Mounts are the first system since
that could route around it.

Open, and they are four separate switches: enemy territory · the war
coast · while flagged for PvP · underground.

Recommendation: **land riding allowed everywhere except the isles**
(`mounts.md` §4.2 already covers those); **flying refused in enemy
territory and over both war coasts**, because a flying mount otherwise
delivers a raider anywhere on the enemy continent without passing a
guard; **underground unrestricted** — the depth ladder of §3.0.4 gates
*breaking rock*, not reaching it, so a flyer in a cave takes nothing
away. Fold the PvP switch into D15 rather than making it a fifth zone
rule.

**Decision:** **enemy territory decided 2026-08-08** (→ `mounts.md`
§4.3, land yes / flying no). **Still open**: the *own*-side war coast,
the PvP flag (D15), and underground.

### D17 — Is there a flight ceiling, and what happens over the strait?

**Decision (strait half):** decided 2026-08-08 with D16 → landed in
`mounts.md` §4.3. Option **(a)** was taken and the strait itself needs
**no rule of its own**: flight over the strait stays legal and stays
governed by §4.1's Exhausted rule, and the **enemy-territory flight ban
closes the hole on landfall** instead. Option (b) — a third no-mount
zone over the strait — was rejected for the reason listed below (it
strands flyers in water), and (c) was rejected as contradicting
`world.md` §1. **The ceiling half is still open** (see below); nothing
in the game caps a flying mount's altitude today.

Two halves of one question.

- **Ceiling**: nothing stops a flying mount from climbing until the
  engine does. Open: a hard y cap, and whether it is a design rule or
  just the map limit.
- **The strait is not open sea.** `open_sea_at` measures distance from
  the continent rectangles, and the strait at z = 0 lies *between* them,
  inside the coastal band — so "Exhausted" (`mounts.md` §4.1) never
  fires there. A Master flying mount crosses the 200-node strait
  (`world.md` §1) in roughly 25 s at 8 nodes/s and lands wherever the
  rider likes. That is the war-coast funnel bypassed, in the one place
  the design cares most about.

Options: **(a)** a flat ceiling plus D16's enemy-territory flight ban
(the ban is what actually closes the hole); **(b)** make the strait a
third no-mount zone, dismounting flyers over it — blunt, and it strands
them in water; **(c)** leave it open and accept air invasion as
intended PvP content — a real option, but it contradicts `world.md` §1
and should be taken deliberately if at all.

Recommendation: **(a)**.

**Decision:** **strait half decided 2026-08-08** with D16, option (a)
minus the ceiling (→ `mounts.md` §4.3). **Open**: whether there is a
**flight ceiling** at all, and whether it would be a design rule or just
the map limit.

### D18 — What does "Exhausted" do to an un-mounted player?

`mounts.md` §4.1 states the debuff applies "mounted, swimming or flying
alike", then fixes **only** the mounted consequence (dismount after
10 s). A swimmer today gets a debuff that does nothing; the open sea's
actual deterrent is the Kraken Guard and the boat-destruction rule of
`world.md` §2b.

Options: **(a)** cosmetic for swimmers — the Kraken does the killing;
**(b)** escalating damage over time after the same 10 s window;
**(c)** a stamina model — swim speed decays to zero and the player
sinks.

Recommendation: **(b)**. It uses the clock the mount rule already needs,
it does not depend on one mob's spawn roll, and it makes the deterrent
legible ("the sea is killing me") instead of arbitrary.

*Lands in*: `world.md` §2b as much as `mounts.md` §4.1 — the debuff is
an ocean rule that mounts merely consume.
**Decision:** _open_.

### D19 — Are skins/variants separate purchases, and are the four tiers four creatures?

Open: (i) is a mount tier one creature or a choice of several; (ii) are
they per faction, per race, or global; (iii) do cosmetic variants cost
extra.

The art bill decides this. Six races × 4 tiers × 2 factions is 48
skins — a Phase 3 quantity (ROADMAP: own assets are Phase 3), and WP7
already accepted that even the race vendors ship **without** race-specific
skins.

Recommendation: **four creatures total** (two land, two flying),
re-skinned per **faction** for flavour and not per race. Defer cosmetic
variants as separate purchases entirely — the economy has no cosmetic
sink today, and inventing one is a bigger decision than mounts.

**Decision:** _open_.

### D20 — Is the riding trainer a new NPC or a role on the existing trainers?

`mounts.md` §1 says riding is learned "from a trainer in a race
capital". The capitals will already hold job trainers
(`professions.md` §1), class trainers (WP11's respec) and the WP7
vendors, and **WP13 owns the real capital structures** — so the NPC
placement decision has to be made before WP13 authors them.

Options: **(a)** a role on the existing **job** trainer — riding is a
universal skill exactly like Cooking and First Aid, which that NPC
already teaches; **(b)** a dedicated stable master, which is more
readable and gives the mount line a place in the world; **(c)** the
faction Quartermaster (already a shipped NPC).

Recommendation: **(a)** — no new NPC, no new model, and it keeps the
"universal skill" framing of `mounts.md` §1 literally true at the point
of sale. **(b)** is the better answer if WP13 wants stables as
architecture anyway.

**Decision:** _open_.

---

## E. Cooking

### E21 — Cooking's per-tier recipe lists

Decided already: Cooking has a recipe book with the same **six T1–T6
groups** and level gates as a profession book but **no keystones** — a
group opens on its **ingredients**, which are regional, so T6 cooking
needs ingredients that only exist in level-50+ areas
(`items_crafting.md` §2.2/§2.3/§3.7, `professions.md` §1). The
ingredient set is decided too, including the found-only three:
`biomes_mobs.md` §2 lists every plant per biome with its `[food]` /
`[food found-only]` / `[herb Tn]` / `[spice Tn]` marker, names mushrooms,
wild cocoa and rock salt as deliberately never-farmable, and §6 maps them
to both continents.

Open: the **recipes**.

- **The recipes per group.** §3.7 names three today — cooked meat/fish,
  Hearty Stew (meat + potato/corn), Hunter's Feast (meat ×2 + melon +
  mushroom) — against six groups.
- **Which ingredient opens each group.** With no keystone, the
  ingredient *is* the gate, so this list is the level gate.
- **How Well Fed maps.** §3.7's buff is "+1/+2/+3 Str AND Int for
  15 min **by tier**" — three steps against six groups.

Options for the buff mapping: **(a)** two groups per step
(T1–T2 → +1, T3–T4 → +2, T5–T6 → +3) — no new numbers, nothing to
re-balance; **(b)** six steps +1…+6 — a straight consumable treadmill,
which `combat_stats.md` §5 rules out; **(c)** keep three steps and let
T4–T6 add duration or a second effect instead of a bigger number.

Recommendation: **(a)** for the buff, 2–3 recipes per group, and gate
each group on the ingredient `biomes_mobs.md` §2 already places in that
ring — roughly potato/corn (T1), berries/apples (T2), mushrooms (T3),
melon + marshbloom (T4), rock salt + stormkelp (T5), wild cocoa + outer
or coast meat (T6). That makes the "find cocoa in the jungle" quest goal
of §3.7 land on the top group by construction, and keeps every tier
reachable on both continents (`biomes_mobs.md` §6).

*Lands in*: `items_crafting.md` §3.7.
**Decision:** _open_ — **blocks WP10**'s cooking book.

---

## Status summary

| # | Question | Blocks |
|---|---|---|
| A1 | Signature recipes per profession × mastery tier | WP10 |
| A2 | Affix word lists + stat mapping (poison ruled out 2026-08-08) | **WP5** |
| A3 | ~~Trinket enchant pool~~ (decided 2026-08-08) — refinement for bags **and** trinkets still open | WP5 (trinkets only) |
| A4 | T5/T6 keystones + Woodcarver/Goldsmith rows | **WP10** |
| A5 | T5/T6 leather & bolt grades, wood grades | material ladder, WP10 |
| A6 | Visible marker on an enchanted refined item | WP5 (description) |
| B7 | ~~Rock-stratum node names & textures~~ — **decided 2026-08-08**: five new nodes below `default:stone`, placed as stratum ores registered last (`items_crafting.md` §3.0.4, `world.md` §2 R6) | — (WP25 and WP24's isle rock are design-unblocked) |
| B8 | ~~Quartz/Garnet/Silver depth & scarcity~~ — **decided 2026-08-08**: ore bands, scarcities and the ore `level` rule (`items_crafting.md` §3.0.1) | — |
| B9 | `open_sea_at` boundary fix | **WP24**, mounts WP |
| C10 | Leatherworker has no armor customers | WP5 drops, WP10 scope |
| C11 | ~~Goldsmith's headline product is post-MVP~~ — **decided 2026-08-08**: trinkets ship in the MVP | — |
| D12–D20 | Mounts: item/assets, persistence, damage, combat dismount, zones, ceiling, Exhausted, skins, trainer. **D16's enemy-territory switch and D17's strait half are decided 2026-08-08** (`mounts.md` §4.3); open in those two: own-side war coast, PvP flag, underground, flight ceiling | **mounts WP**; D20 also WP13 |
| E21 | Cooking recipe lists per tier | **WP10** |

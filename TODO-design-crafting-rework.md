# TODO — Crafting rework: what the 2026-08-07 session left open

The crafting/professions/materials rework was decided on 2026-08-07 and
folded into `docs/design/` (commit `d5baf03`): the two ladders
(`items_crafting.md` §2.1), the six-tier material ladder (§3.0), one item
per concept (§3.0.3), exact natural pick depths plus separate harvest tiers
(§3.0.4), the six
material-cut professions (`professions.md` §2), the one recipe book per
profession (§2.2) with the surviving keystones (§2.3), refinement and the
prefix/suffix affixes (§6b), the herb/spice split
(`biomes_mobs.md` §2) and the new `mounts.md`. The later material, map,
open-world housing and mount-geography decisions live in their design docs;
this file retains only the crafting/content questions they did not answer.

**Everything in this file is open.** No decided rule or resolved-question
stub lives here; those rules and their rationale belong to `docs/design/` and
the repository history. Several design sections point here by name for exactly
these remaining lists.

Once a question is decided: fold it into the design doc named in its
*Lands in* line, update ROADMAP/BACKLOG where affected, and remove the resolved
question from this file. When nothing open is left, delete the file
(AGENTS.md "Documentation layers").

Groups: **A** crafting & items · **B** material calibration · **C** profession
identity · **D** mounts · **E** cooking.

## A. Crafting & items

### A1 — Signature recipes per profession per mastery tier

`items_crafting.md` §2.1 statement 3 makes it binding that **mastery
brings a few profession-exclusive recipes per tier**, and §3.0.3 forbids
a profession from ever making a *parallel* base item. So a signature
recipe can only be a consumable, a kit, a container, an offhand, a
trinket or a fitting — never a sword or a chestplate that
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
  (Phase 2, §3.6a); Goldsmith trinkets (§3.6b).

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

### A3 — Do bags participate in refinement and enchanting?

`items_crafting.md` §6b.1 still names bags as an Ornate refinable family, but
§6b.2's bonus modifies base damage or armor and ordinary durability. A bag has
none of those values, so "Ornate Bag" currently has no defined effect. The
separate trinket exception in §6.2 is complete and does not belong to this
question.

Options: **(a)** define a bag-specific refinement benefit without colliding
with the fixed 8/16/24/32-slot ladder; **(b)** remove bags from the refinable
families entirely and reserve the Ornate word for cloth armor and spell tomes.

Recommendation: **(b)**. The four mastery sizes already supply the bag line's
progression, and removing one unsupported family is clearer than adding a
second bag axis.

*Lands in*: `items_crafting.md` §§6b.1/6b.2.
**Decision:** _open_ — affects WP10's Tailor book.

### A4 — Remaining profession keystones

`items_crafting.md` §2.3 carries only the keystone cells whose materials are
authored and omits this question's missing rows. The rule is decided (a
keystone is the redemption token that opens a book group; the materials prove
the player has been in the region that produces them); the lists below are not.

Still missing: **T5 and T6 columns for Blacksmith, Leatherworker, Tailor,
Alchemist and Woodcarver**, plus the **T2–T4 Woodcarver rows**.

Constraints the lists must respect:

- The shape of the existing rows: ~6 units of the tier's own material
  plus 2–4 units of a ring-specific mob drop; T4 already adds
  `group:grug_rare_trophy`.
- §2.4's pacing: a keystone is ~30–60 min of natural play in the source region
  just reached.
- Universal metal/pick progression must remain non-circular. Profession
  keystones may prove arrival through bars and level-appropriate ordinary mob
  drops, but must not require a foreign G2 gem or loose Abyssal Crystal.

Recommendation for the still-open rows: T5 = 6 × the tier material + 2 ×
a level-41–50 drop; T6 = 6 × the tier material + 2 × a level-51–60 elite
drop. Woodcarver rows key off the universal processed wood grades and the
Blacksmith fittings it cross-buys (§3.6a), not a race-exclusive wood.

*Lands in*: `items_crafting.md` §2.3 (extend the table to T2–T6 × 6
professions).
**Decision:** _open_ — all rows listed above **block WP10** (the book cannot
gate groups without them).

---

## B. Material calibration

### B22 — The six picks' dig-speed progression: the actual `times`

The material review keeps the **rule** — every higher-tier pick is faster on
ordinary rock, including its own current band — but retires engine level
difference as the progression mechanism. Natural-depth access and resource
harvesting are separate checks in `world.md` §2 R6 and do not set the speed
curve.

The six effective `times` and `uses` sets are still unauthored. They must form
an explicit six-pick progression, preserve sensible durability and be measured
against representative ordinary rock in a runtime calibration. Wood and Stone
starter picks share the T1 depth cap but still need a deliberate relative
speed below Bronze.

Options:

- **(a) Author one `times`/`uses` set per tier from a curve**, then verify the
  effective seconds and blocks-per-tool values in a six-pick table.
- **(b) Reuse one vendored profile for every tier.** Cheapest, but it makes
  access the only reward and contradicts the decided speed progression.

Recommendation: **(a)**, calibrated in a runtime test rather than derived on
paper (pattern: `docs/research/wp6_spawn_budget.md`). Author it together with
the missing Iron, Silversteel, Embersteel and Abyssal Steel picks.

*Lands in*: `items_crafting.md` §3.0.4.
**Decision:** _open_ (the `times` and `uses` numbers). Owner:
**WP29/WP22** — WP29 authors the pick catalog and recipes, WP22
runtime-calibrates dig times and durability (BACKLOG WP22 row). WP26
ships bars and furnaces only, no picks.

---

## C. Profession identity

This is not a gap in a list. It is a consequence the rework produced
deliberately, and it leaves one profession standing on very little in the MVP.
It wants a decision, not an author.

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

### C12 — Does the bow foundation receive a playable ranged class?

The item foundation is already decided: bows follow the material weapon curve,
arrows are stackable ammunition, the Woodcarver owns bows and the Leatherworker
owns quivers. The current MVP classes and the named Phase-2 additions contain
no Hunter-like bow user, so those registrations would have no designed combat
consumer.

Options:

- **(a) Add a Hunter-like ranged class** and author its resource, baseline
  attack, abilities, armor rank and talent identity around the bow foundation.
- **(b) Keep the foundation inactive** until a later class package explicitly
  adopts it; no player-facing bow, arrow or quiver recipe ships in advance.
- **(c) Assign bows to one already planned Phase-2 class**, then revise that
  class's kit around a ranged baseline rather than adding another class.

Recommendation: **(b)** until a class package can evaluate (a) and (c) against
the complete seven-class role roster. It preserves the license-checked item
work without shipping a dead equipment line or silently redesigning a class.

*Lands in*: `docs/design/classes.md`, `docs/design/items_crafting.md` §9 and
`docs/design/professions.md` §5.
**Decision:** _open_ — blocks any playable bow consumer, not the existing item
foundation or its profession ownership.

---

## D. Mounts

`docs/design/mounts.md` decides the four level-15/30/45/60 tiers and their
6/8/7/10-node speeds (§1.1), income-time price targets (§2), the persistent
inventory item plus ephemeral attached entity (§3), ocean warning/hard-flight
boundaries, flyable Holy Grounds and the enemy-territory flight ban (§4), plus
the licence-checked references (§5). The unresolved parts below must close
before the work package can ship.

### D12 — Which assets represent the four mount tiers?

Open: which models represent the four tiers, and from where.

`mounts.md` §5 clears the *code* licences (mobs_redo MIT, LotT
LGPL 2.1, VoxeLibre GPL-3.0-or-later) but names **no model** for a
flying mount. mobs_redo ships none; VoxeLibre's `mobs_mc/horse.lua`
covers the land tiers. Assets have to go through the AGENTS.md licence
rule (re-verify in the source repo before import) and the shopping-list
pattern of `docs/research/assets/`.

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

Recommendation: **(a)**, and it got stronger on 2026-08-08: D15's damage
dismount is now **decided** (`mounts.md` §3.1), so the counterplay
option (a) leans on exists in the design rather than being promised by a
sibling question. A hit already takes the rider off the mount; making
the mount itself destructible on top would only add the gank loss (c)
was rejected for.

**Decision:** _open_.

### D15 — May a player mount while in combat?

Incoming damage already dismounts immediately under `mounts.md` §3.1. Open:
whether the mount action is also **refused**
while `grug_core.mark_in_combat` / `in_combat` is true (the 5 s window
shipped with WP4 and reused by WP6's leash and by recovery). Under the
damage rule alone a player can remount between two hits and ride away
from a fight already started. The hook exists and costs nothing; this needs a
decision, not an author.

Options: **(a)** refuse mounting for the complete 5 s combat window;
**(b)** allow mounting between hits and rely on the next damage event to
dismount again; **(c)** add a separate cast-like remount delay.

*Landed in*: `mounts.md` §3.1.
**Decision:** _open_ and wanted before the mount WP, not during it.

### D16 — May flying tiers operate underground?

Enemy territory, Holy Grounds, PvP-tag and ocean behavior are decided in
`mounts.md` §4 and no longer belong to this TODO.

**Still open:** whether either flying tier may operate underground. The earlier
recommendation remains unrestricted underground because the pick's natural
depth limit, rather than physical arrival, owns material access.

### D17 — Flight ceiling and post-dismount drift

The authored ocean/channel warning and hard-flight boundaries are decided in
`mounts.md` §4.1.

**Still open:** the general flight ceiling. The eventual ceiling and forced-
dismount implementation must bound post-dismount air drift so a high-altitude
rider cannot cross a dragon-channel hard strip after losing the mount. The
design deliberately does not choose a ceiling value yet.

### D18 — What does "Exhausted" do to an un-mounted player?

The revised `mounts.md` §4.1 no longer uses `Exhausted` for flight: flyers have
a spatial warning band and a hard no-flight column. Whether an unmounted
swimmer in deep ocean receives an `Exhausted` effect is therefore purely an
ocean-survival question. The present deterrents are the Kraken Guard, immutable
deep-ocean terrain and the boat-threat rules.

Options: **(a)** cosmetic for swimmers — the Kraken does the killing;
**(b)** escalating damage over time after the same 10 s window;
**(c)** a stamina model — swim speed decays to zero and the player
sinks.

Recommendation: **(b)**. It does not depend on one mob's spawn roll and makes
the deterrent legible ("the sea is killing me") instead of arbitrary.

*Lands in*: the revised ocean section of `world.md`, not the mount movement
system.
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

---

## E. Cooking

### E21 — Cooking's per-tier recipe lists

Cooking has a recipe book with the same **six T1–T6
groups** and level gates as a profession book but **no keystones** — a
group opens on its **ingredients**, which are regional, so T6 cooking
needs ingredients that only exist in level-50+ areas
(`items_crafting.md` §2.2/§2.3/§3.7, `professions.md` §1). The
ingredient set is decided too, including the found-only three:
`biomes_mobs.md` §2 lists every plant per biome with its `[food]` /
`[food found-only]` / `[herb Tn]` / `[spice Tn]` marker, names mushrooms,
wild cocoa and rock salt as deliberately never-farmable, and §6 maps them
to both continents.

The authoritative food structure in `items_crafting.md` §3.7 and
`combat_stats.md` §5 supplies the constraints for this question: raw food uses
the 4%/s resting channel without a buff; cooked food restores through that
channel at 8%/s and adds one replace-on-eat food buff; the Alchemist's Healing
Potion retains the instant in-combat slot. The open work is the recipe and
magnitude table per group.

Open: the **recipes**, and now also the **magnitudes**.

- **The recipes per group.** §3.7 names three today — cooked meat/fish,
  Hearty Stew (meat + potato/corn), Hunter's Feast (meat ×2 + melon +
  mushroom) — against six groups.
- **Which ingredient opens each group.** With no keystone, the
  ingredient *is* the gate, so this list is the level gate.
- **How Well Fed maps.** §3.7's buff is "+1/+2/+3 Str AND Int for
  15 min **by tier**" — three steps against six groups.
- **The restore percentage per group** (new with the structure above).
  §3.7 carries one worked example, the owner's: potatoes with boar
  steak, **30 % of max HP**. Six groups need six numbers, and they are
  bounded from above by the potion: a cooked dish may match the potion's
  30 % because it is paid for in ~4 s of standing still, but a dish that
  restores *more* than a potion would make the potion pointless outside
  combat as well as inside it.
- **The example's own magnitudes do not match the shipped ones**, and
  E21 has to reconcile them rather than pick silently: the worked
  example is **+5 Strength for 5 minutes**, while §3.7's Well Fed is
  **+1/+2/+3 Str *and* Int for 15 minutes**. Different size, different
  duration, and one stat against two. The structure is what was decided
  on 2026-08-08; these numbers were not.

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
reachable on both continents (`biomes_mobs.md` §6). For the restore, a
matching six-step ramp topping out at the potion's 30 % rather than
above it; for the example's +5/5 min, read it as the *shape* (one
primary stat, a short buff) and let (a)'s ramp set the size, or the
"no consumable treadmill" rule of `combat_stats.md` §5 is reopened by a
single dish.

*Lands in*: `items_crafting.md` §3.7.
**Decision:** _open_ — the per-group recipes, restore percentages and buff
magnitudes **block WP10**'s cooking book.

---

## Status summary

| # | Question | Blocks |
|---|---|---|
| A1 | Signature recipes per profession × mastery tier | WP10 |
| A3 | Whether bags participate in refinement and enchanting | WP10 |
| A4 | Remaining T5/T6 keystones + Woodcarver rows | **WP10** |
| B22 | The six picks' explicit dig-speed `times` and durability `uses` | WP29/WP22 |
| C10 | Leatherworker has no armor customers | WP5 drops, WP10 scope |
| C12 | Whether the bow foundation receives a Hunter-like or existing ranged class | future class/bow package |
| D12, D14–D19 | Mount assets, entity damage, mounting in combat, underground flight, ceiling/post-dismount drift, swimmer exhaustion, skins | **mounts WP** (D20 decided 2026-08-13 → `mounts.md` §1) |
| E21 | Cooking recipe lists per tier, restore percentages and buff magnitudes | **WP10** |

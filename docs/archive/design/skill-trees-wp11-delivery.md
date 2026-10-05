# Skill trees (WP11): delivery record

Archived 2026-10-06 (Round 37 lane DE) from `docs/design/skill_trees.md` at
`81266ab6`. This is the WP11 revision-2 delivery history: the citation
convention of its time, the talent name audit, the KAT, the file table, the
movement-aggregator and absorb-stacking sizing, the class-change site list,
the implementation lanes, the full text of the 2026-09-16 rulings with what
each replaced, the closed decision record and the task list. It is not
living design. The current rules and numbers are
[skill_trees.md](../../design/skill_trees.md).

**Line citations below are historical.** They point into `mods/` at
`70dda602` (2026-09-16) or at that lane's branch, and they were not
maintained afterwards; in October 2026 most of them pointed at unrelated
lines. Never edit code by these numbers; find the symbol instead.

The X1/X2 (phase 1) record is
[wp11-talents-phase1.md](../../research/wp11-talents-phase1.md).

Section numbers inside the copied text (§1–§7) are the revision's own: §1–§2
and the current-rule summaries of §3 live on in skill_trees.md under the
same numbers; §2.11 is section C here and §7 is section F.

**Names (Round 37 ruling, plan §2.3.6).** The name audit of the former §2.11
quoted the talent, spell and class names of an existing game as the reason
for each rename. This copy describes it neutrally: it gives our own names
only and never the other game's.

## A. The former preamble

The revision was written against the decided frame of 2026-09-16 and quoted
it where it bound: `classes.md`'s core principle that new active main skills
come from talent capstones (ruling 3 widened it to keystones as well, ruling
4 made the tree their only source); the Mend row of `classes.md` §5 ("Unlocked
via the Holy tree (WP11)"); the no-trainer respec location; AGENTS.md's rule
that `docs/design/` holds decided rules only; and AGENTS.md's rule never to
copy assets or names 1:1 from existing commercial games, which ruling 5 made
binding for every talent name.

Its citation convention: "Everything this design says about the code is a
`file:line` citation into `mods/` at `70dda602` … nothing under `mods/` is
changed by this lane. Citations into the four design docs this lane edits
(`combat_stats.md`, `classes.md`, `progression.md`, `BACKLOG.md`) are
branch-relative … §5.2's supersession table writes those numbers as
`main:NNN` and quotes the sentence in full."

At the time two sites still called the Priest healing tree "the Holy tree"
(`classes.md:464` and a comment at `grug_abilities/kits.lua:650`); the rename
to Mercy has since reached both (task 5 below).

## B. The former §1.4 respec history

- The respec price retired `BACKLOG.md`'s earlier "5c × level, min 25c"
  (then `:542-550`), the only other respec number in the repository at the
  time.
- Main's 5.7 said the free first respec covered a mis-click at "level 3", the
  level the old cadence gave the first point; ruling 1 moved the first point
  to level 2 and the sentence followed it.
- The first price table, WP44's income-derived `RESPEC_PRICES` of Round 29
  lane E4, read 15c, 35c, 75c, 2s, 6s, 12s. Commit `8f4d5638` (2026-10-05)
  changed the 51–60 price to 5s25c; `economy.md` §4 owns the prices.
- The `/class` registration (`grug_classes/selection.lua:594-595` at the
  time; one call to the generic `register_set_command` helper, which `/race`
  still uses) was removed with WP11.
- The revision said "`/xp` can lower a level"; since then `/xp` only grants a
  positive amount, and the free level-drop reset is reached only through
  `grug_xp.set_xp`.

## C. The name audit (former §2.11, neutral wording)

Ruling 5 (paraphrased): talent names must not remind of an existing
commercial game; rename every talent the review flagged and check the rest.
Tree names stay. Ruling 21 later set the criterion: the overall picture
matters, single common words are not protected.

**First pass, revision 1 → revision 2.** Ten revision-1 talent names matched
or closely echoed talent, spell or class terms of an existing game and were
replaced. The replacements are Deep Reserve, Tinder, Hobble, Ironbound,
Spite, Stoke, Broadstroke, Hold Ground (keystone) with Unbroken (capstone),
Firebrand and Hard Faith. Hobble and the later Deadweight were both retired
by ruling 19's Ruin rebuild, which moved Hamstring to tier 3 and put Onset
and Tendon Cut in their places.

**Second pass (independent review, 2026-09-16).** Five more names on the
first pass's "no collision" list turned out to be another game's talent or
spell names, three of them on the bow class. All five were renamed; the
current names are Hard Faith (replacing a first-pass rename), Cold Eye,
Shifting Weight, Weathered and Whitehot. Because a first-pass rename failed,
every name since carries a confidence label rather than a verdict; "low"
means "no collision either reader is aware of", never "proven clean".

**Low risk, 54 names:** Ironbound, Weathered, Hold Ground, Unbroken, Spite,
Affront, Bellow, Grudge, Heavy Hand, Stoke, Broadstroke, Ruination, Keen
Edge, Tinder, Firebrand, Whitehot, Deep Well, Far Cast, Cinderfall, Ashfall,
Hoarfrost, Rimebite, Cold Focus, Quick Step, Far Step, Gentle Hand, Quiet
Steps, Hearten, Warding Faith, Deep Reserve, Turn Aside, Second Skin,
Sharpened Word, Swift Word, Word of Ruin, Last Word, Hard Faith, Warded
Wrath, Recompense, Hardened, Strong Draw, Cold Eye, Twin Shot, Longshot,
Fletching, Shifting Weight, Fine Edge, Deep Focus, Follow Through, Light
Step, Slip Away, Shake Loose, Untouchable, Onset.

**Medium risk, recorded and not renamed** (ruling 21: each is a
single-word or single-concept echo of an existing game's name; the list
stays so a reviewer can see it was looked at, and because many such echoes
together would make the picture ruling 21 forbids). Alternatives were noted
in case the picture ever gets too close:

| Name | Where | Alternative |
|---|---|---|
| Deep Chill | Rime, Frost tier 1 | Long Winter |
| Frostbind | Rime, Frost keystone | Rimelock |
| Glacial Ward | Rime, Ward keystone | Coldshell |
| Tendon Cut | Ruin, Lash tier 4 | Cut Deep |
| Pinning Shot | Quarry, Ranging keystone | Stake Shot |
| Brand | Ember, Blaze keystone | Sear |
| Quiver | Quarry, Ranging tier 1 | Full Quiver |
| Opening | Veil, Blade keystone | First Cut |
| Snare Shot | the Scout's base kit | — |
| Sprint | the Scout's base kit; ruling 21 names it as not protected | Break Away |

Three of these sit on the Scout's bow tree and one in its base kit, the one
place where the picture could start to read like another game's ranged
class; a later pass would start there.

**The "Word" and "Shot" families.** The revision put one question to the
user: the Priest's Sharpened Word, Swift Word, Word of Ruin and Last Word
extend another game's priest spell-name pattern, and Twin Shot with Snare
Shot extends a "…Shot" pattern on the bow class. Clean replacements if
wanted: Whetted Verse, Quick Verse, Verse of Ruin, Final Verse; Twinned
Arrow. The question is open in BACKLOG ("Audit 2026-10 open questions",
DP-06); the talents ship with the Word names.

**Kept by ruling 5:** the tree names Ruin, Rime and Reckoning, although they
echo talent names of an existing game.

**Shipped ability names (Round 31 user ruling):** the shipped abilities
whose names matched another game's were renamed; the current names are
Heal, Shield and Mend (Priest) and Ice Nova (Mage). Generic words (Blink,
Hamstring, Charge, Smite, Taunt, Fireball, Sprint) stay. The Ice Nova sound
id became `cast_ice_nova` in Round 37.

The audit covered all 64 talents: 54 low risk, 8 medium (the table, which
also carries the Scout's two base-kit names) and the two shipped names Mend
and Hamstring.

## D. The former §3 (data model and seams, as planned and built)

The current-rule summaries of §3.1–§3.6 and §3.9–§3.11 stay in
[skill_trees.md](../../design/skill_trees.md) §3. The full text of the
revision follows, with its citations at `70dda602`.

### 3.1 Where talents live

New file **`mods/PLAYER/grug_classes/talents.lua`**, loaded from the existing
`dofile` block at `grug_classes/init.lua:210-213`, next to `stats.lua` and
`perks.lua`. `grug_classes` is the right owner for three reasons that already
hold in the tree: it owns the class registry (`init.lua:11-18`) and its def
comment already reserves room for "skill trees (WP11)" (`init.lua:7-8`); it
owns the per-player derived stats every numeric talent touches (`stats.lua`);
and it is a dependency of both `grug_inventory` and `grug_abilities`
(`stats.lua:79-82`), so both read talents without a new dependency edge.

**Reading needs no new edge; the UI and the respec do.**
`grug_classes/mod.conf` depends on `grug_core`, `grug_factions` and `grug_xp`
only. The Talents page of §3.5 needs **`sfinv`** (today a dependency of
`grug_inventory` alone) and the respec transaction of §1.4 needs
**`grug_money`** (`grug_money.take`, `mods/PLAYER/grug_money/init.lua:122`).
Both are one-line `mod.conf` additions with a load-order consequence, and
lane X4 owns them.

Registration mirrors `register_class` (`init.lua:14`):

```lua
grug_classes.register_tree({
    id = "bulwark", class = "warrior", name = "Bulwark",
    chains = {"wall", "anvil"},          -- exactly two, ruling 2
    capstone_chain = "wall",             -- which chain carries the capstone
})

grug_classes.register_talent({
    id = "ironbound", tree = "bulwark", chain = "wall", tier = 1,
    name = "Ironbound", description = "Armor rating +1 per rank.",
    effects = {armor_rating_add = {1, 2, 3, 4, 5}},  -- one value per rank
})

grug_classes.register_talent({
    id = "hold_ground", tree = "bulwark", chain = "wall", tier = 3,
    keystone = true,                     -- exactly one per chain, tier 3
    ability = "hold_ground",             -- the grug_abilities id it grants
    effects = {hold_ground_absorb = {20, 30, 40}},
})

grug_classes.register_talent({
    id = "unbroken", tree = "bulwark", chain = "wall", tier = 4,
    capstone = true,                     -- exactly one per TREE, on its chain
    effects = {armor_rating_multiplier = {1.65},
               armor_rating_add_low_hp = {15}},
})
```

`register_talent` asserts the shape at load time the way `register_ability`
does (`grug_abilities/init.lua:475-510`): tier in 1..4, rank counts 5/4/3/3
by tier, chain belongs to the tree, exactly two chains per tree, exactly one
keystone per chain in tier 3, exactly one capstone per tree in tier 4 and on
a declared chain, eight talents per tree, two trees per class, and every
effect key present in the closed vocabulary table. A typo is a startup
failure, never a silently inert talent.

### 3.2 The one hook

```lua
-- Summed bonus of this key over the player's ranked talents; 0 when none.
function grug_classes.get_talent_bonus(player, key)
```

It is the deliberate twin of `grug_classes.get_race_perk`
(`grug_classes/perks.lua:21-28`), down to the stub override for mods below
`grug_classes` in the dependency graph (`perks.lua:31`):

```lua
grug_core.get_talent_bonus = grug_classes.get_talent_bonus
```

Every numeric talent in §2 is one call to this function at the site its
**Modifies** column names, and nothing else. **The site is not always in
`kits.lua`.** A kit table's `cooldown`, `charge`, `range` and `max_distance`
fields are evaluated **once at load time**, with no player in scope: a
per-player read written there would change the number for everybody. **Five
talents of the three shipped classes** therefore hook a central per-player
site instead, and each of those sites already exists and is already the only
one of its kind:

| Talent | The constant it re-tunes | Where the read goes |
|---|---|---|
| Grudge, Quick Step, Swift Word, Second Skin | `cooldown` in the ability def | `grug_abilities/init.lua:1233`, the sole `arm_cooldown(user, def, def.cooldown)` call |
| Onset | `cooldown` in the ability def — Charge's, `kits.lua:299` | the same `arm_cooldown` call, `grug_abilities/init.lua:1233` |
| Far Cast | `max_distance` in the projectile registration (`kits.lua:413`) and `range` in the ability def (`:446`) | flight: the spawn call (`kits.lua:453-460`), since `grug_projectiles/init.lua:195` prefers `params.max_distance`; targeting reach: `grug_abilities.get_range` (`init.lua:170-177`), the twin of the elf `ability_range_bonus` perk, whose item-meta override `normalize_kit` refreshes (`grug_abilities/init.lua:1827-1831`) |

The Scout adds two more, both onto sites already in the
table: **Slip Away** (Sidestep's cooldown → `init.lua:1233`) and **Follow
Through** (Opening's charge → `init.lua:718`). Nothing in either tree hooks
the `spend` call at `init.lua:1232` except the Mage capstone **Whitehot**,
which halves Fireball's mana cost for its window — the previous revision
routed a Scout talent through that seam, and ruling 14's move from focus to
mana removed it.

Every other numeric talent sits at the line its table names, inside a function
body with the player in scope. Two worked examples:

```lua
-- grug_classes/stats.lua:45 at the time (the body of the function at :44);
-- since Round 33 Dexterity gives 0.0005 per point (combat_stats.md §2)
return math.min(0.30, 0.05 + 0.0005 * grug_classes.get_attributes(player).dex)
-- with talents, cap-aware (§2.10; ruling 10)
local cap = math.max(0.30,
    0.01 * grug_classes.get_talent_bonus(player, "crit_cap_override"))
return math.min(cap, 0.05 + 0.0005 * grug_classes.get_attributes(player).dex
    + 0.01 * grug_classes.get_talent_bonus(player, "crit_chance_add"))

-- kits.lua:342 today
return math.floor(ctx.weapon_damage * 1.5) + ctx.melee_bonus, 3, ...
-- with talents
local mult = 1.5 + grug_classes.get_talent_bonus(user, "mighty_blow_multiplier_add")
return math.floor(ctx.weapon_damage * mult) + ctx.melee_bonus, 3, ...
```

A second, smaller accessor answers unlock questions:

```lua
-- 0..5; used by the kit grant, the gates and the UI, never by a numeric consumer.
function grug_classes.talent_rank(player, talent_id)
```

**Timed windows are the one new shape revision 2 adds.** **Eight talents** are
not a constant summed bonus but a bounded window. Six belong to the three
shipped classes — **Hold Ground** (its root/slow immunity), **Unbroken**,
**Ruination**, **Whitehot**, **Turn Aside** and **Last Word** — and two to the
Scout, **Shake Loose** and **Untouchable**. Of these, four are triggered by a
condition rather than by a button (Unbroken, Ruination, Whitehot, Last Word),
which is a start time the talent code sets, not a new mechanism. The Scout's
base-kit **Sidestep** and **Sprint** use the same table without being talents
([scout.md](../../design/scout.md) §2), which is why the table belongs to the window shape
rather than to the talent registry. They are not a third seam — `get_talent_bonus` returns 0 for a window key that is not
running — but they need one small per-player expiry table of the shape
`grug_core`'s absorbs already use (`grug_core/combat.lua:1010-1017`), owned by
`talents.lua` and cleared on leave, death and respec — **not** on a class
change, which ruling 20 abolished. That table
is the single place a window lives; nothing else in the design needs state.

### 3.3 Persistence

- One player-meta **string** key, `grug_classes:talents`, holding `id=rank`
  pairs separated by commas: `ironbound=4,grudge=1`. The same store class and
  race already use (`grug_classes/init.lua:3-4`, `:76`, `:113`); a string
  keeps it to one key instead of sixty-four, and it stays human-readable for
  `/talents` debugging.
- One player-meta **integer** key, `grug_classes:respec_used`, is 0 until the
  first successful free reset and 1 thereafter. It persists across reconnects
  so the free reset is granted once per character; paid resets leave it at 1.
- Parsed once per join into a per-player runtime cache (the pattern of
  `grug_abilities`' runtime tables, `init.lua:22-38`), invalidated on spend,
  respec and leave (a class change is no longer an event — ruling 20).
- **The read path validates, it does not trust.** Unknown ids are dropped,
  ranks are clamped to the talent's own rank count, a rank whose tier gate or
  hard chain is not satisfied is dropped **together with everything below it
  in its chain**, and the total spent is clamped to `floor(level / 2)`. A
  hand-edited meta string therefore cannot buy a capstone at level 4.
- No point balance is persisted. Points available are always derived
  (`floor(grug_xp.get_level(player) / 2)`, `grug_xp/init.lua:48`), never
  stored, so the two can never disagree.

### 3.4 Granting a new skill, and replacing an existing one

A newly ranked active-skill talent adds its ability to the Skills catalogue and announces that location; it does not insert an item. Full respec removes representations that are no longer unlocked. Re-ranking exposes the ability for manual recovery. Passive and replacement talents remain read-only information and never create dummy items.

**Two mechanisms, and ruling 13 makes the second one carry most of the
design.**

**A new skill** is an ordinary `grug_abilities` registration with
`talent_gated = true` and its owning talent ID. The shared
`grug_abilities.is_unlocked(player, id)` predicate checks class membership and
positive talent rank; catalogue listing, recovery, normalization and actual
cast/swing execution all use that authority. Possessing a forged or stale
representation never grants an ability.

A talent-granted ability appears in Inventory > Skills and is recovered
manually. Registration order determines catalogue order but never moves an
existing hotbar item. Under ruling 10 at most two such abilities exist per
build. Base-kit insertion occurs once at character creation; later unlocks
announce catalogue availability and do not require a free inventory slot.

**A replacement** (the eight replacing keystones and the two replacing
capstones) is **not** a registration and touches none of the above. The
shipped ability keeps its id, its key, its icon and its registration; the
talent is a read inside its own `cast` or `proc_swing` body, exactly like
every numeric talent in §2 — Bellow is a radius the Taunt body reads, Hearten
is a loop the Heal body runs, Frostbind is where Ice Nova takes its
origin from. That is why ruling 13 is cheaper as well as kinder to the
hotbar: of the **twenty-four** keystones and capstones, **sixteen** — the ten
replacements and the six effects — cost zero new registrations, zero new
items and zero grant logic.

Talent spending and respec invoke `grug_abilities.normalize_kit(player)`.
This removes stale or duplicate representations and refreshes surviving item
metadata without filling discarded slots. The Skills catalogue refreshes its
entitlement list and announces new entries. Replacements need no additional
item: the next cast reads the current talent rank.

**Hotbar budget** (`classes.md` §2b reserves keys 1-8). Under rulings 13 and
19 the ceiling is **base kit + 2**. Warrior, Mage and Priest start with
**Strike + 3**; Scout's explicitly approved four class abilities give it
**Strike + 4**:

| Class | Base kit | Max new buttons | Worst case |
|---|---|---|---|
| Warrior | Strike + 3 — Charge (`kits.lua:291`), Mighty Blow (`:321`), Taunt (`:380`); **Hamstring leaves the base kit with ruling 19** and returns as Ruin's keystone | 2 (Hold Ground, Hamstring) | **6 of 8** |
| Mage | Strike + 3 (`classes.md:445-447`) | 2 (Cinderfall, Glacial Ward) | 6 of 8 |
| Priest | Strike + 3 (`classes.md:461-463`) | 2 (Mend, Word of Ruin) | 6 of 8 |
| Scout | Strike + 4 ([scout.md](../../design/scout.md) §2) | 2 (Pinning Shot, Opening) | **7 of 8** |

Two keys stay free in the original three classes; Scout keeps at least one
free key. The Warrior's remaining space accommodates `classes.md`'s parked
"Warrior shield abilities → after WP14 (offhand/shields)", for which
`register_ability` already carries the `slot = "offhand"` plumbing
(`grug_abilities/init.lua`). All four classes remain inside the eight-key
hotbar; Scout's extra base skill does not add an extra talent-button allowance.

**A Warrior who takes neither Ruin keystone has no snare.** That is the cost
of ruling 19, and it should be visible rather than discovered: Hamstring is
`classes.md:419-420`'s "control tool (in
an engine where mobs outrun players, the snare is the Warrior's identity)", and a Bulwark-only Warrior now reaches
level 26 before that identity is available at all. The counter-argument the
ruling rests on is that a Warrior who wants the snare gets it **and** its
ranks in one 13-point commitment, instead of being handed it at level 1 and
then re-tuning it with three separate talents.

### 3.5 UI

Round 19 follow-up: talent names/ranks share the same text alignment in every
state. Purchasable talents have a clearly visible button background and border;
locked/maxed entries remain visibly distinct and retain their status and tooltip.
This is presentation only: first-click purchases and authorization are unchanged.

A third `sfinv` page beside Character and Bags (`grug_inventory/pages.lua:182`,
`:246`), registered from `grug_classes/talents_ui.lua` so the page lives
with the data it shows and `grug_inventory` keeps its two pages. This costs
the `sfinv` dependency edge of §3.1. sfinv uses legacy coordinates and the
content area spans about y 0.3-5.0 (`pages.lua:1-2`).

Revision 1's layout drew five talents per tree in three tiers. Revision 2 has
**eight talents per tree in two chains and four tiers**, which is a two-column
chain layout per tree and four rows — sixteen buttons for the class, plus the
per-tree point counters, the gate labels and the description line. That fits
the sfinv area only if the two trees are **tabbed rather than side by side**:

```
+---------------------------------------------------------------+
| Character | Bags | Talents |                        (sfinv tabs)
+---------------------------------------------------------------+
| Warrior      [ BULWARK 21 ] [ Ruin 9 ]      Points left: 0     |
|                                            [ Respec  --    12s]|
|      WALL                       ANVIL                          |
| T1 | Ironbound      5/5 |   | Spite          5/5 |             |
| T2 | Weathered     4/4 |   | Affront        3/4 |     (>=5)   |
| T3 | Hold Ground *  3/3 |   | Bellow *       0/3 |     (>=12)  |
| T4 | Unbroken **    1/1 |   | Grudge         0/3 |     (>=20)  |
|                                                               |
| Unbroken -- rank 1/1: total armor rating x1.65; below 20% HP, |
| +33% of K as rating after the multiplier for 8 s / 180 s.     |
+---------------------------------------------------------------+
```

- `*` marks a keystone, `**` the capstone; a locked talent is a plain label
  (no click target) with its reason spelled out ("needs 12 points in Bulwark"
  or "needs Weathered 4/4").
- Clicking an available talent immediately spends one point for one rank.
  Hover explains the effect before purchase; selected/last-purchased detail
  may remain visible. There is no preselection click or purchase confirmation.
- The **Respec button lives here** (ruling 4) with its price in the label and
  an inline confirmation prompt, since there is no NPC to host the transaction.
- Fixed numeric button fields map only to registered trees and talents of the
  submitting PlayerRef's own class. Names and descriptions are escaped with
  `core.formspec_escape`; no player name or free-text field enters a purchase.
- Combat statistics are on Character, not Talents. The freed space belongs to
  tree controls, ranks and wrapped descriptions. Effective Character values
  include active effects; Help explains caps, multipliers and exceptions.
- Round 18 supplies semantic action icons for active talent abilities as well
  as base skills (`classes.md` §2c). Passive talent-tree artwork remains outside
  that action-icon scope.

### 3.6 Level-up flow

`grug_classes` already registers on the level-change callback
(`grug_classes/stats.lua:90-93`, the callback itself at `grug_xp/init.lua:34`).
The same registration gains the talent line:

```lua
-- old_level is nil on join (grug_xp/init.lua:32-33), which is why
-- stats.lua:91-92 already guards it. Arithmetic on nil here would error
-- on every single join.
if old_level ~= nil and
        math.floor(new_level / 2) > math.floor(old_level / 2) then
```

On that condition, post one message-feed line alongside the "Reached level N!"
level-up banner (`grug_xp/init.lua`, a large centre message since Round 28
ruling 20, no longer a chat line) only when at least one point is unspent, directing
the player to Inventory > Talents. No new globalstep, no new HUD element, no
new packet. The banner itself names the points the jump earned in a second
line, "You gained +1 Talent Point" (or "+N Talent Points" over several
levels; Round 36 §2.14.4); both read the one rule
`grug_classes.talent_points_at(level)` = floor(level / 2).

### 3.7 The KAT

`tools/wp11/talent_tree_kat.lua`, plain Lua 5.1 under a stub registry, in the
shape of `tools/wp13/ability_rightclick_kat.lua:1-45` — it loads the **real**
`talents.lua` and the real `register_talent`, and runs under both interpreters
with identical output. Eight groups, each able to go red on its own:

1. **Shape.** Every class has exactly 2 trees; every tree 8 talents in two
   chains of 4; ranks 5/4/3/3 by tier; exactly one keystone per chain in
   tier 3; exactly one capstone per tree, in tier 4, on a declared chain.
   Tier gates are 0/5/12/**20** points in the tree. Totals: **28 ranks per
   tree, 56 per class**.
2. **Arithmetic.** `floor(60/2) == 30`; one tree costs **28**; each tree is
   13 + 15 ranks; the milestone table of §1.3 reproduces exactly
   (13 / 15 / 20 / 21 / 28 points in a tree); **a capstone costs 21 and two
   cost 42 > 30**, which is ruling 18's "one capstone per character" as an
   assertion rather than a rule; two full trees cost 56 > 30; no build holds
   more than two new-skill keystones. This row goes red if anyone re-tunes
   the cadence or a gate without re-tuning the trees.
3. **Spend rules**, as a table of cases: a tier-2 rank with 4 points in the
   tree is refused and with 5 accepted; a tier-3 rank with 11 refused, 12
   accepted; tier 4 with 19 refused, 20 accepted; a tier-2 rank whose
   tier-1 chain talent is at 4/5 is refused; a sixth rank refused; a spend
   with 0 points left refused; a spend at level 1 refused; **a capstone
   refused at 20 points in the tree and accepted at 21**, and refused at 21
   when its chain's keystone is at 2/3; **a second rank in any capstone
   refused** (ruling 17); and **a second capstone refused outright**, because
   30 points cannot reach two (§1.3's arithmetic — this is the row that goes
   red if anyone re-tunes a gate and quietly makes two reachable).
4. **Persistence round trip.** Serialize → parse → identical; forged meta
   (`unknown_id=2,ruination=9`) is dropped and clamped; a forged mid-chain rank
   drops everything below it in that chain.
5. **Effect-key coverage.** Every key in the closed vocabulary is read by at
   least one consumer source file, and every `effects` key a talent uses is in
   the vocabulary. This is the row that goes red when a talent is added whose
   modifier nothing applies — the failure mode a numeric talent system has.
6. **Cap and armor invariants.** With every crit talent at rank 5 on a level-60
   character and **no** window running, `get_crit_chance` still returns
   ≤ 0.30; with every dodge talent maxed, `get_dodge_chance` ≤ 0.30; with the
   armor talents maxed, final armor reduction remains ≤ 0.70. With identical
   maximum gear, five Ironbound ranks (then 5 rating; 7.5 at level 60 since
   Round 35) and Stoneskin (181 raw rating), a damage
   Warrior remains about 57.28% against an L70 dragon; the 21-point Bulwark
   commitment reaches about 68.87%, and its emergency window about 69.91%. **With Ruination running, and only
   then,** crit may reach 0.50. (The dodge cap is only
   raised by the Scout's Untouchable, so its invariant belongs to lane S3 and
   this group asserts dodge ≤ 0.30 unconditionally for the three shipped
   classes.)
7. **Window lifecycle.** Every timed window returns 0 before it starts and
   after it expires, and respec, death and leave clear it — those are now the
   only three lifecycle events, since ruling 20 removed the class change.
8. **The shared central seams stay neutral without talents.** The six talents
   that hook `arm_cooldown` (`grug_abilities/init.lua:1233`), the charge line (`:718`), the
   spend line (`:1232`) and `get_range` (`:170-177`) sit on paths every
   ability of every class runs through. One case per seam with **no talent
   ranked** must reproduce today's value exactly — Taunt 8 s, Blink 15 s,
   Smite 2 s, Hamstring 6 s, Fireball 6% base mana and 20 m, and an elf's Fireball
   still 25 m.

**Mutation proof** the review should demand: revert the one line of
`stats.lua:45` that adds `crit_chance_add` and group 5 goes red; give a
tier-1 talent 6 ranks and group 1 goes red; make the `arm_cooldown` read
default to 1 instead of 0 and group 8 goes red; let a window key leak past its
expiry and group 7 goes red.

`tools/wp11/talent_ui_kat.lua` is historical pre-Round-19 evidence for the
former select-then-buy interaction and raw/effective/cap header, alongside
budget/tier/prerequisite, respec and escaping checks. It is not a current UI
acceptance gate. Round 19's `tools/r19_ui/fixture.lua` loads the real talent
model and page to verify first-click purchases, refusal paths, concise UI and
serialized text/layout; `tools/r19_final/micro.lua` includes it in the bounded
final interpreter-parity gate. Respec authorization and costs remain unchanged.

### 3.8 What changes where

| File | Change | Size |
|---|---|---|
| `grug_classes/talents.lua` | **new** — registry, the 48 talents of the three shipped classes (3 classes x 2 trees x 8), spend/respec, persistence, window table, the two accessors | large |
| `grug_classes/talents_ui.lua` | **new** — the sfinv page of §3.5 | medium |
| `grug_classes/init.lua:210-214` | one `dofile` line for the UI | 1 line |
| `grug_classes/mod.conf` | two dependency edges: `sfinv` and `grug_money` | 1 line |
| `grug_classes/stats.lua:20,30,45,90` | four talent reads (max HP, max mana, crit + the crit-cap override, the level-up line with the `old_level ~= nil` guard). `stats.lua:49`'s dodge cap is the Scout's alone and belongs to lane S3 | small |
| `grug_abilities/kits.lua:342,370,372,453-460,458,495,496,504,505,533,591,613,640,671` | one talent read per numeric talent whose number lives inside a function body, plus Warded Wrath's shield gate at `kits.lua:591` | medium |
| `grug_abilities/init.lua:170-177,718,1232,1233` | the four **central per-player seams** the load-time constants force (§3.2) | small |
| `grug_abilities/init.lua:939,950,966,1719,1724,1808,1858,2109,2202` | rage per swing; the grant predicate at the three `talent_gated` sites; the append-after-base-kit rule; rage per hit taken; in-combat mana regen | small |
| `grug_abilities/kits.lua` (new section) | **4 new ability registrations** for the three shipped classes — Hold Ground, Cinderfall, Glacial Ward, Word of Ruin (§2.9) | medium |
| `grug_abilities/kits.lua:350` | one `talent_gated = true` on the **shipped Hamstring**, which ruling 19 moves out of the Warrior's base kit and into Ruin's keystone | 1 line |
| `grug_abilities/kits.lua:340-344, 368-374, 389-404, 429, 488-490, 583-592, 612-614, 639-640` | **the seven replacements** of the three shipped classes — six replacing keystones (Bellow, Broadstroke, Brand, Frostbind, Turn Aside, Recompense) and the replacing capstone Hearten — plus the rule-breaking finisher Tendon Cut; each a read inside the shipped ability's own body, no registration (§3.4) | medium |
| `grug_inventory/equipment.lua` armor aggregate | Ironbound rating and Unbroken's deep-tree ×1.65 plus its emergency rating (both level-scaled, §2.10) | small |
| `grug_core/combat.lua` and `grug_abilities/init.lua` | attacker-level armor formula; heal threat factor; the threat multiplier on **both** its sites (cast and swing) | small |
| `grug_core/` the speed aggregator | **prerequisite, not this WP** — §3.9. Hold Ground's and Shake Loose's root/slow immunity are flags it owns, and the Scout's Sprint is a modifier in it | — |
| `tools/wp11/talent_tree_kat.lua` | **new** — §3.7 | medium |
| `tools/wp11/talent_ui_kat.lua` | **new** — X4 interactions, transaction and render checks | medium |
| `docs/design/combat_stats.md` §2 | the common cap-override rule; Round 11 has filled its Unbroken armor and Scout dodge cases, while the remaining Mage crit consumer belongs to X3 | small |
| `docs/design/classes.md`, `progression.md`, `economy.md`, `items_crafting.md`, `README.md` | the "base value" wording of §2.10 and the no-class-trainer respec rule | small |

### 3.9 The movement aggregator (ruling 11) — a prerequisite this WP does not own

Three talents and one base-kit ability in this design write the player's
movement: Hold Ground and Shake Loose set a **root/slow immunity flag**, the
Scout's Sprint sets a **+50 % modifier**, and Tendon Cut and Pinning Shot
apply a **root**. They cannot be written the way the game writes movement
today.

**Measured, not inherited.** `grug_mobs/verbs.lua:100-118` says there are two
owners of `physics_override.speed`, and `mounts.md:128-133` and
the former `boats.md` §5 (2026-08-13 text) both repeat that count. A `grep` over the tree finds
**three**:

| Writer | Lines | What it writes |
|---|---|---|
| mob webs / snares | `grug_mobs/verbs.lua:153`, `:167`, `:178` | `{speed = factor}`, then `{speed = 1}` to restore, plus a join reset |
| the ability root/slow chain | `grug_abilities/kits.lua:161`, `:167` | `{speed = 1, jump = 1}` and `{speed = stage.speed, jump = stage.jump or 1}` |
| **character creation** | `grug_classes/selection.lua:52`, `:91` | `{speed = 0, jump = 0, gravity = 0}` — and `:91` restores a **snapshot** |

The third is the one the two existing comments miss, and it is the most
awkward kind for an aggregator:

- `reassert_player_lock` (`selection.lua:49-53`) **re-asserts** the freeze
  whenever it observes the override drifting, so it would fight any other
  writer for the whole of character creation.
- `release_player` (`:91`) writes back `session.physics`, a snapshot taken
  when creation began. If a slow or a sprint is running at that moment, the
  snapshot captures the *modified* value and restores it permanently after the
  aggregator believes the effect expired — **exactly the bug class ruling 11
  exists to end**, and one the aggregator does not fix unless this writer
  migrates too.

**It is an aggregator for speed and jump.** Ice Nova uses the hard-root flag
(logical speed 0, jump 0), followed by its independent 50% slow. The shared
physics writer zeros locomotion targets with native braking enabled, so an
already moving player stops; airborne falling and gravity remain active. Movement immunity
removes roots and suppresses negative modifiers. Charge stun independently sets
speed and jump to zero and blocks action execution. Gravity stays unchanged for
combat control; the character-selection exclusive hold owns its gravity freeze.

**Ruling 11 decides the shape**: one central aggregator in `grug_core` where
each system registers a **named** modifier with its **own duration**; effects
overlap freely; a **root is a hard flag** — speed 0 regardless of modifiers,
never a "−1000 %"; **mounts stay outside it**, exactly as `mounts.md:128-133`
already requires.

```lua
grug_core.set_move_modifier(player, "sprint", {speed = 0.50}, 10)
grug_core.set_move_modifier(player, "mob_web", {speed = -0.40}, 7)
grug_core.clear_move_modifier(player, "sprint")
grug_core.set_root(player, 4)             -- hard flag: speed 0, jump 0
grug_core.set_move_immunity(player, 8)    -- discards negatives and roots
grug_core.hold_movement(player, "class_creation")  -- exclusive; releases exactly
```

**Recommended combination rule: additive percentages per axis, then one
clamp.** `speed = clamp(1 + Σ speed, 0.1, 1.5)` and the same for `jump`, with
a root or an exclusive hold taking precedence over the sum. Additive rather
than multiplicative because the shipped numbers already read as absolute
speeds (`kits.lua:372` sets `speed = 0.5`), because two slows multiplying to
0.25 is a stacking rule nobody decided, and because a sum is the only form in
which the KAT can state a single invariant without enumerating orders. Ruling
26 makes it binding.

**Stances (user ruling 2026-09-28).** A self-imposed stance is not a modifier
in the sum: it is a named speed factor applied after it,
`speed = clamp(clamp(1 + Σ speed, 0.1, 1.5) × Π stances, 0.1, 1.5)`. Immunity
does not discard a stance (it is not a debuff), Shake Loose's negative clear
keeps it, and it scales Sprint and every other positive modifier. Jump is not
affected. Current stances: eating ×0.35 (`grug_food`) and drawing or holding a
drawn bow ×0.5 (Scout Loose); each owner clears its stance on every end path,
and death/leave drop the whole record. API: `grug_core.set_move_stance`,
`clear_move_stance`, `get_move_stance`.

**Size, honestly.** The **core** is roughly **100 lines**: a per-player table
of named entries with expiries, one accumulator per axis, the root flag, the
immunity, the exclusive hold, and the join/leave reset `verbs.lua:176-186`
already performs. The **migrations are extra** and are what the lane must
budget for — the machinery being replaced is about 95 lines in
`verbs.lua:100-200` plus about 55 in `kits.lua:118-176`, and the third writer
brings its own snapshot/re-assert logic:

| Piece | Work |
|---|---|
| aggregator core (speed + jump, root, immunity, hold) | ~100 lines, new |
| migrate `grug_mobs/verbs.lua`'s slow chain | rewrite ~95 lines down to calls |
| migrate `grug_abilities/kits.lua`'s staged root/slow | rewrite ~55 lines, and the staged `root → slow` chain becomes two named modifiers with different durations, which is what it always wanted to be |
| migrate `grug_classes/selection.lua` | the freeze becomes `hold_movement`, the snapshot restore disappears |
| KAT | overlap, expiry, root precedence, immunity, hold, and a no-effect baseline per axis |

**It is a prerequisite, and it is not WP11's.**
`docs/research/mob-pressure-task-card.md` §4b carries it, because a mob that
must keep moving while it swings is the other consumer. WP11 should **not**
start Hold Ground or anything Scout-shaped until it exists; everything else in
§4 is independent of it.

### 3.10 Removing the class change (ruling 20) — what it touches

Ruling 20 removes class changing from the game entirely, for admins too. That
is a deletion rather than a feature, but it is not free: **five** shipped
comments and one command registration assume the opposite, and WP11 is the WP
that makes them wrong.

| Site | What it is | What ruling 20 does to it |
|---|---|---|
| `grug_classes/selection.lua:594-595` | the `/class` registration — one call to the generic `register_set_command` helper | **that call is removed**, and nothing else. `:554-592` is the helper itself and `:596-597` registers `/race`, which ruling 20 does not touch; deleting the range would take both with it |
| `grug_abilities/init.lua:1772-1780` | `normalize_kit` entitlement purge — removes unavailable kit representations | **kept**, and it becomes the respec path's purge instead: a full talent reset has to take back the two talent-granted buttons (§3.4), which is the same operation |
| `grug_abilities/init.lua` lifecycle | Separate one-time character kit insertion from normalization | Class switching is unavailable. Join and talent changes normalize existing representations; neither re-grants discarded skills. Skills recovery preserves cooldown and charge state. |
| `grug_inventory/equipment.lua:57` | "the class-change unequip below, later WP11 respec / WP14…" | comment corrected: there is no class change, and a talent respec never unequips anything |
| `grug_inventory/equipment.lua:501` | "Admin-only today, **player-reachable with WP11's respec**" | the promise is **withdrawn**. The class-restriction unequip path becomes unreachable by design, and the comment must say so rather than point at a WP11 that will not deliver it |
| `grug_inventory/equipment.lua:579` | "a Warrior who respecs to Mage" | comment corrected: that character cannot exist |
| `grug_core/combat.lua:110` | "WP11's respec unequipping what the new class may not wear" | comment corrected; it is listed there among "the writers this is waiting for", and one of them is now never coming |

**The equipment argument is the ruling's own**, and it is the strongest one:
a class change has to decide what happens to gear the new class may not wear
(`inventory_equipment.md:184-193`'s armor-class ranks — Warrior 3, Mage 1,
Priest 1), and every answer is bad. Removing the operation removes the
question. The cost is that `equipment.lua:501`'s class-restriction unequip
code stays in the tree with no caller; it should be kept (it is the guard that
makes the rank rule true if anything ever writes an equipment list directly)
and re-commented, not deleted.

**Character creation is unaffected**: choosing a class for the first time is
not a change, and `selection.lua`'s creation flow stays exactly as it is —
including the movement freeze that §3.9 migrates onto the aggregator.

### 3.11 Absorb shields stack (ruling 23)

Revision 2 recorded "one absorb per player, a new one replaces the old"
(`grug_core/combat.lua:1003-1012`) as a named consequence and put a second
slot to the user as an open decision, because four sources write it: the
Priest's Shield (base kit), Glacial Ward (Mage keystone), Hold Ground
(Warrior keystone) and Recompense (Priest keystone, on a landed Smite at most every 6 s).
A healer shielding the tank deleted the tank's own cooldown.

**Ruling 23 answers it with the pattern ruling 11 already established**:
absorbs stack as **named contributions with independent durations**, one
aggregator, no replacement.

```lua
grug_core.add_absorb(target, "shield_spell", amount, 15)
grug_core.add_absorb(target, "hold_ground", amount, 8)
grug_core.get_absorb(target)        -- unchanged signature: the total
```

- **Soak order: shortest remaining duration first.** A shield about to expire
  should be the one that is spent, or a long self-buff swallows damage a
  15-second heal-cast was meant to take. This is the one rule the old single
  slot never had to state.
- **Re-casting the same name refreshes that contribution**, and does not add a
  second one — so Recompense tops its own shield up (at most once every 6 s)
  rather than stacking a dozen.
- **The read side does not change.** `grug_core.get_absorb(player)`
  (`combat.lua:1020`) keeps its signature and returns the sum, so Warded
  Wrath's "while the Priest carries an absorb shield" gate (§2.6) and the
  central hp-change modifier's soak (`:1003-1030`) are untouched.
- **A cap is still needed**, and it is a number for the balance pass rather
  than for this file: with four writers and no replacement, a coordinated pair
  can stack more absorb than any single source was balanced against.
  Recommendation: cap the **total** at the target's max HP, which is
  self-scaling and needs no table.

**Size: ~40 lines in `grug_core/combat.lua`**, replacing the ~30 that the
single slot occupies at `:1003-1030`. **It shares no code with the movement
aggregator of §3.9** — the arithmetic is different (a consumable pool drained
by damage, not a multiplier summed per axis) — but it shares its *shape*:
named entries, independent expiries, one accessor, cleared on leave and death.
Building them in the same lane would let one KAT cover both lifecycles, and
that is the only argument for pairing them.

**Ownership**: it is a `grug_core` change, so like §3.9 it is **not**
`grug_classes`' to make. Unlike §3.9 it has no consumer outside WP11 — no mob
and no NPC writes an absorb — so WP11's lane X3 can carry it.

## E. The former §4–§6 (lanes, rulings, decision record)

### 4. Implementation lanes

Rulings 13, 17 and 19 together shrank this WP more than any other decision in
the revision: **four** new ability registrations instead of fifteen, sixteen
of the twenty-four keystones and capstones costing nothing to register, and
one-rank capstones. The five-lane cut of the previous revision collapses back
to **four**, in dependency order. X2, X3 and X4 run in parallel once X1 has
landed.

| Lane | Scope | Depends on | Size |
|---|---|---|---|
| **X1 — the model** | `talents.lua`: registry, the 48 talent registrations of the three shipped classes (data only, no consumer), points, the two gate kinds, spend/respec rules, persistence with the validating read path, the window table of §3.2, `get_talent_bonus` / `talent_rank`, the `on_talents_changed` callback, and the whole KAT of §3.7 except group 5's consumer half. Ships with **zero gameplay effect** — every talent is inert. | — | M |
| **X2 — the numeric consumers** | The **30** talents of the three shipped classes that are neither keystone nor capstone, at the sites of the §3.8 table. **Twenty-five are a one-line read where the table says; five hook the three central per-player seams of §3.2** (Grudge, Quick Step, Swift Word and Onset on `arm_cooldown`; Far Cast on the spawn call and `get_range`), and each of those needs its own no-talent regression case (KAT group 8). Completes KAT groups 5 and 6. Touches shared files, so it is one lane and not split by class. | X1 | M |
| **X3 — keystones and capstones (implemented Round 12)** | **Four** new ability registrations (Hold Ground, Cinderfall, Glacial Ward, Word of Ruin); the `talent_gated` flag on the **two shipped abilities that become keystones**, Mend (already flagged) and Hamstring (`kits.lua:350`, ruling 19), plus their rank scaling; the shared entitlement predicate and manual Skills recovery rule of §3.4; **seven replacements** written inside the shipped abilities' own bodies (Bellow, Broadstroke, Brand, Frostbind, Turn Aside, Recompense, Hearten) and the rule-breaking finisher Tendon Cut; the remaining capstone effects and cap-override paths. Round 11 already delivered Ironbound and Unbroken's armor-rating multiplier/window, Round 12 preserves that implementation alongside Scout. The Crit override, named absorbs and Hold Ground immunity use the shared §3 seams. The bounded native X3 probe covers each ability/replacement and lifecycle. | X1, §3.9 for one talent | L |
| **X4 — UI, level-up and respec (implemented 2026-09-17)** | The sfinv Talents page of §3.5, the two `mod.conf` edges, the level-up chat line with its `old_level ~= nil` guard, the respec transaction against `grug_money.take`, the price of ruling 22 (§1.4), and the raw-vs-effective display `combat_stats.md:104-108` requires — including the **raised cap** while a rule-breaker runs. The six price values are WP44's income-derived `RESPEC_PRICES` (Round 29 lane E4). | X1 | M |

X3 is the only lane that owes a runtime test on a headless server; X1, X2 and
X4 are provable with the KAT plus one probe each. A **replacement** owes a
probe of its own kind: the shipped ability must still behave exactly as
`classes.md` §§3-5 specifies with the talent unranked, and differently with it
ranked — that is the mutation proof for the sixteen of twenty-four that
register nothing.

**Outside this WP but ahead of it**: the speed aggregator of §3.9 (~100 lines
in `grug_core`), which the mob-pressure lane owns and which X3 needs for one
talent. The Scout's own lanes are [scout.md](../../design/scout.md) §7 and need X1-X4
first.

---

### 5. Decided 2026-09-16 (the user's rulings)

These are the user's decisions of 2026-09-16, recorded as the binding frame
for this revision. Each is followed by what it replaced.

#### 5.1 The rulings

1. **Talent points.** One point every 2 levels, the first at level 2 → **30
   points at level 60**. "Two thirds" was a rough guideline; slight deviation
   is fine. *(Built into §1.3.)*
2. **Tree size.** About **30 ranks per tree** (≈60 per class), so a player can
   fill one tree completely **or** spread over both with one prioritised. A
   full tree is **not** forced. Each tree contains **two rough playstyle
   directions (chains)**. Dependencies of both kinds: level/points gating
   **and** hard chains ("all ranks in A before B"). Rank counts vary **3-5**
   by talent strength; no need to invent more talents to reach 30 — vary
   ranks. *(Built into §1.1, §1.2; the chain is 5/4/3/3.)*
3. **Keystones and capstones.** Per tree: **two keystones and one capstone**.
   A keystone is a **new active skill** at a chain/tier boundary; the capstone
   is the **top talent of the tree** — a skill or a strong effect, and **not
   every capstone is a skill**. The capstone hangs on **its direction's
   chain**, not on the whole tree. *(Built into §1.2, §2; six capstones are
   skills and two are effects.)*
4. **No class trainer.** New skills come **only** from the tree; the base kit
   at class choice stays. Damage and effect improvements of skills come from
   the tree too. **Respec for money, in the talent UI, no NPC.** *(Built into
   §1.4, §3.5. The user is recorded as "against money" as the respec's price
   shape; ruling 22 settles it.)*
5. **Names.** Tree names as proposed stay (Bulwark/Ruin, Ember/Rime,
   Mercy/Reckoning). **Talent** names must not remind of an existing
   commercial MMO — rename every talent the review flagged and check the rest. *(Done in the
   name audit, section C.)*
6. **Caps** *(coordinator proposal, not a user ruling)*: talents work within
   the `combat_stats.md` caps; only capstones may exceed a cap, time-limited.
   **SUPERSEDED the same day by ruling 10**, which widens it: rule-breaker
   talents may too. It is no longer an open decision.*
7. **A fourth class, "Scout"** (the user's chosen name), leather armour,
   planned now and implemented later: two trees, ranged (bow) and melee
   (stealthy melee). **No poison** — "no new combat mechanic"; the melee direction
   uses existing stats: timed dodge windows, crit chance, slows,
   escape/retreat moves, traps if cheap. **Invisibility is the capstone of the
   melee tree, reachable only by a "pure" build.** *(§2.7, §2.8,
   [scout.md](../../design/scout.md).)*
8. **Invisibility rules** (2026-09-16, second set): combat **breaks** it
   (dealing or taking damage, casting a hostile ability); there is a
   **detection chance** even while invisible when very close to a mob; mobs
   and guards of a **higher level than the player** have a markedly higher
   detection chance — "no level-40 player sneaks past a level-60 mob or
   guard"; invisibility **significantly reduces movement speed**.
   *([scout.md](../../design/scout.md) §5; they are deferred whole to [scout.md](../../design/scout.md) §8.)*
9. **Sprint** (2026-09-16, second set): a new talent idea for the melee
   direction or for both leather trees — about **10 s of markedly increased
   movement speed**. *(Refined by ruling 10 below; it is now the Scout's
   base-kit ability, [scout.md](../../design/scout.md) §2.)*

**Third round, 2026-09-16.** These four change the design more than any of the
first nine, and two of them retire earlier recommendations of this file.

10. **Rule-breaking, with limits.** "Skills may explicitly **break the base
    inequalities** (mob 4.4 > player 4.0, stat caps, roots) — that is what
    skills are for (Blink and a dodge roll already do). The rule: **the bigger
    the break, the stronger the limit**, usually cooldown or duration."
    **Sprint stays IN combat**, ~10 s, cooldown **at least 3 minutes, rather
    5** — "a deliberate special, not an every-fight button." This **replaces**
    the coordinator's cap proposal (ruling 6): **capstones AND rule-breaker
    talents** may exceed caps, time-limited. *(§2's `‼` marks, §2.9's table,
    §2.10. It **withdraws this file's previous recommendation** that Sprint be
    out-of-combat only, and it requires the `mounts.md` amendment named in
    §7, task 1.)*
11. **Speed ownership.** "Effects overlap freely with independent durations;
    the design is **one central aggregator in `grug_core`** where each system
    registers a **named modifier with its own duration**; a **root is a hard
    flag** (speed 0 regardless of modifiers), never a '−1000 %'; **mounts stay
    outside** the aggregator." *(§3.9 sizes it at ~100 lines and recommends
    additive percentages; it is a **prerequisite owned by the mob-pressure
    lane**, not by WP11, and the Scout's speed-and-stealth lane collapses into
    it.)*
12. **Historical ruling, with Round 17 overriding only the trajectory:**
    arrows and Fireball now home on the valid release-time target.
    **The Scout is as simple as possible**, and that has priority over "as
    cool as possible": **no invisibility in version 1** (the melee capstone
    becomes a strong time-limited effect built from existing stats), **no
    poison, no traps**; the bow family through the existing sprite generator;
    **arrows ballistic** with gravity, while **Fireball stays straight** —
    "the trajectory is what makes the archer hard"; leather borrows the cloth
    cut; a **base kit of four abilities from existing mechanics only**.
    *(§2.7, §2.8, and [scout.md](../../design/scout.md), whose §8 keeps ruling 8 and the
    whole stealth analysis as "deferred: stealth v2".)*
13. **Keystones may modify or replace existing skills** instead of adding new
    ones — "eight new abilities per build is too many." **Per tree at most ONE
    keystone that adds a new skill**; the other keystone improves or replaces
    an existing skill; **the capstone is an effect or a replacement.**
    *(§2 throughout, §2.9's recount to **eight** registrations across four
    classes and **five** in WP11, §3.4's two mechanisms, and §4's collapse
    back to four lanes. It **resolves** the previous revision's hotbar decision: no build
    exceeds base kit + 2 keys.)*

**Fourth round, 2026-09-16.**

14. **The Scout uses mana.** Decided — no new resource, no renamed bar in the
    data model beyond its label. *(Closes what this file carried as an open
    decision; [scout.md](../../design/scout.md) §1.)*
15. **The HUD's heart statbars are rejected** — "half hearts are an ugly
    approximation". Ruling: a **thin, point-accurate LIFE bar**, and a
    **mana-or-rage bar directly above the hotbar slots**; every class has
    exactly **one** secondary bar. *(Not WP11 —
    `docs/research/hud-bars-task-card.md`.)*
16. **Warrior rage fills too fast** — "in combat the resource is effectively
    unlimited". A user finding, not yet a decision. *(§2.2's note and open
    §7's task 8.)*

**Fifth round, 2026-09-16.** The user answered the *original* open-decisions
list of revision 1 (`main:docs/design/skill_trees.md` §§5.1-5.13) rather than
this file's renumbered §6; each answer is mapped onto the current document
below. After this round **every one of revision 1's thirteen questions is
closed**.

17. **A capstone has ONE rank** — a strong effect or a replacement — and what
    gates it is its chain plus the points in the tree, not a ladder of its
    own. *(Answers original 5.4, and it is worth recording **against** what.
    Main's §5.4 recommended the opposite — "(a) Capstone has 3 ranks…
    **Recommendation: (a)**" — so this is the user taking option (b) over the
    document's own advice, on the coordinator's later recommendation in the
    dialogue, and confirmed by the user afterwards. It is **decided**, not
    pending.*
    *One half of main's 5.4(b) is deliberately **not** taken: it read
    "Capstone has 1 rank **and one numeric talent in the tree gets 5 ranks, so
    the tree still holds 15**". This design takes the one-rank capstone and
    **drops the compensating rank**, which is exactly why a tree is **28** and
    not 30. That is accepted under ruling 1's "slight deviation is fine"
    rather than overlooked: a fifth rank bolted onto one numeric talent per
    tree would buy two ranks of padding and cost the 5/4/3 ladder its
    regularity, and 28 of 30 points leaves a player two to place freely, which
    reads better than an exact fit. §1.2 and §1.3 carry the number openly.)*
18. **Only one capstone per level-60 character, and it must follow
    *implicitly* from the tree's requirements**: reaching a capstone costs
    more than half of all available points, and the first one lands around
    **level 40-44**. *(Answers original 5.5, which asked whether both
    capstones should be reachable — the answer is no. §1.3 shows the gates
    already do it: a capstone costs **21 in-tree points = 70 % of 30 = level
    42**, and two cost 42 > 30, so the second is arithmetically out of reach
    rather than discouraged.)*
19. **Every class starts with four skills — Strike plus three.** The Warrior
    loses one: **Hamstring leaves the base kit**, and "it may return later
    through a keystone". *(Answers original 5.11, the hotbar question.
    Hamstring is now Ruin's new-skill keystone, §2.2; §3.4's budget drops to
    **6 of 8** for every class.)*
20. **Class change is removed entirely, including for admins** — "equipment
    would be a problem otherwise". A respec is **not** a class change; a
    respec is a **full reset**; and an admin level drop triggers a **full free
    reset** as well. *(Answers original 5.9 and 5.10. §1.4 and §3.10 carry the
    consequences, including the shipped `/class` command and the four code
    comments that assume a switch.)*
21. **Names: what matters is the overall picture.** Paraphrased: single
    words like 'Holy' or 'Sprint' are not protected — the whole must not sit
    too close to an existing commercial MMO.
    Keep the audit; do not rename for single common words. *(Answers original
    5.6. the name audit (section C) keeps its confidence labels and stops proposing renames for
    single-word collisions.)*
22. **Respec price: original 5.7's option (a)** — five minutes of measured
    reliable net solo income at the character's own bracket, **and the first
    respec of a character is free**. *(Closes what this file carried as an open decision on the respec price.
    `BACKLOG.md`'s "5c × level, min 25c" is retired by it.)*
23. **Absorbs stack**, the way speed effects do: named contributions with
    independent durations in one aggregator, instead of "one absorb slot, a
    new shield replaces the old". The Warrior's tank cooldown keeps the
    **self-absorb** form of original 5.13 variant (B) — in this design that is
    **Hold Ground**, Bulwark's keystone, since ruling 13 made the capstone
    (Unbroken) an effect. *(Closes what this file
    carried as an open decision on the absorb collision; §3.11 sizes it and says what it shares with §3.9.)*
24. **Open questions may live inside the design docs**, as long as each is
    clearly attributable to its design doc — so §6 stays in this file and in
    `scout.md`, and no root `TODO-…md` is created. *(Answers original 5.1 and
    closes this file's earlier question about where the open list should live.)*

Original 5.2, 5.3, 5.8 and 5.12 were already closed by rulings 1, 2/3, 4 and
10 respectively, and are recorded there.

**Sixth round, 2026-09-16 (interactive).** The user answered the five items
that were still open after the fifth round. **Nothing in this design is
undecided any more.**

25. **Warrior rage: option (b) — lower the income and add decay.**
    Swing **12 → 8** at all five sites, hit taken **4 → 3**, and **5 rage/s
    decay out of combat** on the existing `grug_core.in_combat` window.
    *(Answers ruling 16's finding. This is a `classes.md` §3 tuning change,
    not WP11's — §7 task 8 carries it for the WP11 / mob-pressure round, with
    option (a) — raise Mighty Blow to 35 and Hamstring to 15 — recorded there
    as the fallback if (b) overshoots and leaves the Warrior starved.)*
26. **The movement aggregator combines additively, per axis, with one clamp.**
    `clamp(1 + Σ, 0.1, 1.5)` for speed and for jump; a root or an exclusive
    hold takes precedence over the sum. Self-imposed stances multiply the
    clamped result (ruling 2026-09-28, §3.9). *(§3.9 and
    `docs/research/mob-pressure-task-card.md` §4b already describe it; the
    ruling makes the recommendation binding.)*
27. **The Scout's trees are Quarry and Veil.** *(The names used throughout
    §2.7, §2.8 and [scout.md](../../design/scout.md).)*
28. **A bow's damage is `weapon damage + floor(Dex/10)`**, through a new
    `grug_classes.get_ranged_bonus` beside `get_melee_bonus`
    (`grug_classes/stats.lua:34-36`). *(One accessor, and one sentence added
    to `combat_stats.md` §2 — §7 task 9. It is what makes the Scout's
    Dexterity-led growth mean something.)* Since Round 33 the term is `Dex/10` with its
    fraction ([combat_stats.md](../../design/combat_stats.md) §2).
29. **Historical ruling: Sprint is +25 % for 10 s on a 300 s cooldown.**
    **The user amended the speed to +50% on 2026-09-20; duration, cooldown
    and the existing movement cap remain unchanged.** *(The amended value
    puts a sprinting Scout at 6.0 nodes/s against
    the ordinary aggressive band's 4.6, which ruling 10 permits and which
    **confirms §7 task 1**: `mounts.md` §3.1 and `combat_stats.md` §3 must
    record the exception.)*

#### 5.2 What each ruling replaced

**The retired text no longer exists on this branch**, because this lane's own
commits replaced it. Every line number in the left-hand column is therefore a
line on **`main` at `70dda602`**, written `main:NNN`, and the retired sentence
is quoted in full so the supersession can be checked without a second
checkout. Line numbers elsewhere in this file are branch-relative.

| Ruling | Replaces (on `main` at `70dda602`) |
|---|---|
| 1 | `progression.md main:28` "**1 talent point every 3 levels** (20 points total at 60)" **and** `combat_stats.md main:14` "the class skill tree (**1 skill point per level**)". Revision 1's open decision about which one won is closed: **neither**. |
| 2 | `progression.md main:29-30` "talent trees hold 2 trees × 5 talents × 3 ranks = 30 ranks per class — you can fill two thirds: real choices, no full clear (WP11)" and `BACKLOG.md main:34`'s repetition of it |
| 3 | `progression.md main:31-35` "**9 of 10 talents are numeric modifiers** (cheap to build, easy to balance); **exactly one capstone per tree**, unlocked at 8+ points in that tree, and **every capstone is a NEW active 'main skill'** … (e.g. Priest Holy capstone: Mend; further capstones designed with WP11)" |
| 4 | `progression.md main:36-37` "**Respec at the class trainer for gold**, price rising with level — repeatable per-character gold sink and the class trainer's purpose", together with the former matching text in `economy.md`, `items_crafting.md` and `world.md`. All living sections now state the no-trainer rule. |
| 5 | revision 1's naming open decision, for talents |
| 7 | `classes.md main:466-470`: poison was to arrive in Phase 2 as the signature damage type of a planned Phase-2 melee class (noted 2026-08-08). That class is **superseded by the Scout**, and with it the poison plan. The bullet was then `classes.md:475-487` on that branch and quoted its own retired text. |

#### 5.3 Where each correction is made

One commit per file, this lane's files only:

Line numbers below follow the preamble's convention: `main:NNN` is the text as
it stood before this lane, the bare number is where it is on this branch.

| File | Correction |
|---|---|
| `docs/design/progression.md` | §2's cadence, tree-size and capstone bullets (`main:28-37`, now `:30-52`); the respec location; the pointer paragraph |
| `docs/design/combat_stats.md` | `main:14`'s "1 skill point per level", now `:13-20` |
| `docs/design/classes.md` | the pointer paragraph; the Phase-2 melee-class bullet (`main:466-470`, now `:470-482`) marked superseded by the Scout |
| `BACKLOG.md` | the WP11 row (`main:34`) and the respec-price note (`main:539-540`, now `:542-550`) |

The living sections of `economy.md`, `items_crafting.md` and `world.md` have
since been corrected. `docs/research/post-wp40-readiness.md` is a historical
readiness record rather than current design authority.

---

### 6. Closed decision record

**No open decisions as of 2026-09-16.** Six rounds of rulings closed all
thirteen questions of revision 1 and the five that survived into revision 2;
§5 carries each with its ruling text, and §7 carries remaining implementation
work.

The heading stays for whatever the first playtest raises. When something new
goes here it should carry, as the user's meta-instruction of 2026-09-16
requires, **why it is open** — not only what the options are.

For the record, the five items this section held until the sixth round, and
where their answers now live:

| Was open | Decided by | Now in |
|---|---|---|
| Warrior rage calibration | ruling 25 — option (b), lower income and add decay | §2.2's note, §7 task 8 |
| the movement aggregator's arithmetic | ruling 26 — additive per axis, one clamp | §3.9 |
| the Scout's tree names | ruling 27 — Quarry / Veil | §1.1, §2.7, §2.8 |
| what feeds a bow's damage | ruling 28 — `weapon damage + Dex/10` (fractions count since Round 33) | [scout.md](../../design/scout.md) §1, §7 task 9 |
| Sprint's percentage and cooldown | user amendment 2026-09-20 — +50 % / 10 s / 300 s | [scout.md](../../design/scout.md) §2, §7 task 1 |

## F. The former §7 task list, closed

The revision listed settled design that its docs-only lane could not write
itself. Status at `81266ab6` (Round 37 lane DE, checked against the code):

| # | Task | Status |
|---|---|---|
| 1 | Amend `mounts.md` §3.1 and `combat_stats.md` §3: the 4.4 > 4.0 inequality holds except for named, long-cooldown skills, Sprint first at +50 % for 10 s every 300 s; the Swiftness Draught stays | **done**: both files carry the exception |
| 2 | Implement the remaining Mage crit-cap override without replacing Unbroken's armor path or the Scout's dodge-cap override | **closed**: the cap override is read for every class in `grug_classes.get_crit_chance` (`crit_cap_override`); no Mage talent raises the crit cap |
| 4 | Correct the shipped comments that assume a class change and remove the `/class` registration (not the helper `/race` needs) | **registration removed** (`selection.lua` registers `/char` and `/race` only); a few code comments still mention a class change (for example `grug_classes/init.lua` "admin /class switches", `grug_visuals/apply.lua`), a code-comment cleanup |
| 5 | Rename the two remaining "Holy tree" mentions to Mercy | **done**: no "Holy" remains in `docs/design/` or `mods/PLAYER` outside this record |
| 7 | Fix three drifted citations into `mods/ENTITIES/mobs/api.lua` held by `mounts.md` and two `grug_mobs` comments | **not tracked further**: since Round 37 the design docs cite symbols, not line numbers |
| 8 | Re-tune Warrior rage (ruling 25): swing 12 → 8, hit taken 4 → 3, 5 rage/s out-of-combat decay; fallback Mighty Blow 35 and Hamstring 15 if (b) overshoots | **done**: `RAGE_PER_SWING = 8`, `RAGE_PER_HIT_TAKEN = 3`, `RAGE_DECAY_PER_SECOND = 5` in `grug_abilities`; `classes.md` §3 carries the ledger; the fallback was not needed |
| 9 | The ranged damage term of ruling 28, `grug_classes.get_ranged_bonus` | **done** in Round 11 |

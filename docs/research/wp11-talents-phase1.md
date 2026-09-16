# WP11 talents, phase 1 — what shipped, what it measures, what is open

Round 4, lane W1, 2026-09-16. Branch `wp11-r4-talents-phase1`, based on main
`dfb32cd5`. Scope: lanes **X1** (the model) and **X2** (the thirty numeric
consumers) of `docs/design/skill_trees.md` §4, plus the rulings of 2026-09-16
that are code and have no other home. Lanes **X3** (keystones, capstones, four
new ability registrations) and **X4** (the sfinv page, the respec price) are
untouched.

---

## 1. What shipped

### 1.1 The model — `mods/PLAYER/grug_classes/talents.lua` (new)

One file, loaded from the existing `dofile` block in `grug_classes/init.lua`
next to `stats.lua` and `perks.lua`, exactly where §3.1 puts it.

- **Registry.** `register_tree` and `register_talent` assert their shape at
  load time the way `register_ability` does, and `audit_talents()` runs once at
  the end of the file for everything a single registration cannot see: eight
  talents per tree in two chains of four, one talent per (chain, tier), exactly
  one keystone per chain in tier 3, exactly one capstone per tree on its own
  chain, 28 ranks per tree, two trees per class. A typo is a startup failure,
  never a silently inert talent.
- **The 48 talents** of Warrior, Mage and Priest (§§2.1–2.6) as data, with the
  effect keys of the Key column. Every talent carries a player-facing
  `description`, which the interim chat commands print and which lane X4's page
  can reuse.
- **Points**: `floor(level / 2)`, derived and never persisted, so "points
  available" and "level" cannot disagree.
- **Both gate kinds**: tier gates 0 / 5 / 12 / 20 points in that tree, and hard
  chains ("all ranks of the talent above it, in the same chain").
- **Spend rules** with a refusal reason per case, so the UI has a sentence to
  show ("Hold Ground needs 12 points in Bulwark (you have 9).").
- **Respec** — a full reset that returns every point (ruling 20). The price
  ledger is X4's; the shipped `/respec` is free.
- **Persistence**, one player-meta string `grug_classes:talents` holding
  `id=rank` pairs, with the **validating** read path of §3.3.
- **The timed-window table** of §3.2, owned here and cleared on leave, death
  and respec. `get_talent_bonus` returns 0 for a window key whose window is not
  running, so a consumer needs no second accessor.
- **Accessors**: `get_talent_bonus(player, key)` and `talent_rank(player, id)`,
  plus `talent_points_total/spent/available`, `tree_points`,
  `register_on_talents_changed`, `start_talent_window` /
  `talent_window_active` / `clear_talent_windows`, and the `grug_core`
  stub override, the deliberate twin of `get_race_perk`.
- **A talent change re-applies derived stats.** `grug_classes.apply_stats` is
  the only writer of a player's `hp_max`, and it used to run on an equipment
  change, a level change and the class pick only — so a spent point raised
  `get_max_hp` while the character's real ceiling stayed put, and a respec left
  the raised ceiling behind. `talents.lua` registers `apply_stats` as the
  **first** `on_talents_changed` consumer, without `heal_gain`, so a spend
  hands out no free health and a respec clamps current HP correctly. (Found by
  the independent review of 2026-09-16, finding 1; the KAT and the engine probe
  now assert the **applied** ceiling, not only the accessor, and two mutations
  hold it there.)

**Performance note for the review.** `get_talent_bonus` sits on the damage
pipeline, so a player's ranks are parsed once and **pre-summed** into a static
key→value table cached per player name. A read is then one table index for the
common case and, for the seven windowed keys, a short loop over the ranked
windowed talents. The cache is dropped on spend, respec, level change, class
pick and leave.

### 1.2 The consumers — the one-line reads of §3.8

| Site | Talents |
|---|---|
| `grug_classes/stats.lua` max HP | Weathered, Hardened |
| `grug_classes/stats.lua` max mana | Deep Well, Deep Reserve |
| `grug_classes/stats.lua` crit | Keen Edge, Firebrand, Hard Faith |
| `grug_inventory/equipment.lua` armor percent | Ironbound |
| `grug_core/combat.lua` heal threat | Quiet Steps |
| `grug_core/combat.lua` cast threat multiplier | Affront (cast half) |
| `grug_abilities/init.lua` swing threat multiplier | Affront (swing half) |
| `grug_abilities/init.lua` rage per hit taken | Spite |
| `grug_abilities/init.lua` the five swing rage sites | Stoke |
| `grug_abilities/init.lua` in-combat mana regen | Cold Focus |
| `grug_abilities/init.lua` `effective_cooldown` | Grudge, Onset, Quick Step, Swift Word |
| `grug_abilities/init.lua` `get_range` | Far Cast (targeting half) |
| `grug_abilities/kits.lua` Mighty Blow | Heavy Hand |
| `grug_abilities/kits.lua` Fireball | Tinder, Far Cast (flight half) |
| `grug_abilities/kits.lua` Frost Nova | Deep Chill, Hoarfrost |
| `grug_abilities/kits.lua` Blink | Far Step |
| `grug_abilities/kits.lua` Smite | Sharpened Word, Warded Wrath |
| `grug_abilities/kits.lua` Flash Heal | Gentle Hand |
| `grug_abilities/kits.lua` Power Word: Shield | Warding Faith, Second Skin |

**Two new per-player seams**, because §3.2's problem is real: a kit table's
`cooldown` and `range` are evaluated once at load time with no player in
scope, so a read written there would change the number for everybody.

- `grug_abilities.effective_cooldown(player, def)` is the one place the four
  cooldown talents land. A def names its key with a new `cooldown_talent`
  field; without one, and without a ranked talent, it returns `def.cooldown`
  exactly. The single `arm_cooldown(user, def, def.cooldown)` call now passes
  through it.
- `get_range` gained the same shape: a def names its key with `range_talent`,
  and the elf's `+5 m` perk still stacks on top of it. Every **server-side**
  reader follows a talent immediately, because they call `get_range` live —
  that includes `grug_core.combat_ray`'s reach for hostile casts and the
  target-lock range check. **The per-stack `range` meta override does not**:
  it is derived from `get_range` inside `sync_kit`, which runs on join and on
  the class pick, so the reach the *client* is allowed to point at only
  catches up after a relog. Nothing shipped is affected — the one talent with
  a `range_talent` is Far Cast, and Fireball aims off the eye position and
  look direction rather than off `pointed_thing` — but the moment a talent
  re-tunes the range of an ability that reads `pointed_thing`, lane X3's
  `register_on_talents_changed(sync_kit)` (§3.4) has to exist. §5.1 carries
  it.

**Twenty-eight of the thirty numeric talents are wired.** The two that are not
are **Tendon Cut** (`hamstring_root`) and **Ashfall**
(`cinderfall_radius_add`): §2.9 counts them among the thirty, but Tendon Cut
reads inside a Hamstring that no character can have until X3 wires the grant,
and Ashfall re-tunes a Cinderfall that X3 still has to register. Both are
registered as data; §4's own lane table already assigns Tendon Cut to X3.

### 1.3 The rulings that are code

- **Ruling 19** — `talent_gated = true` on the shipped Hamstring. The predicate
  that has kept Renew out of the kit since WP19 now keeps Hamstring out too, so
  **every class starts with Strike plus three**. Until X3 grants it, **no
  Warrior has a snare at all**, which is the stated cost of the ruling and the
  single most visible change of this lane in play.
- **Ruling 20** — the `/class` registration is gone. Not the
  `register_set_command` helper above it, which `/race` still needs, and not
  the creation flow. The five shipped comments that assume a class change
  (`grug_inventory/equipment.lua:57`, `:501`, `:579`, `grug_core/combat.lua:110`,
  `grug_abilities/init.lua:1775-1776`) now say what is true; each line number
  was re-resolved against this tree before the edit. `equipment.lua`'s
  class-restriction unequip is **kept and re-commented**, per §3.10: it is the
  guard that makes the armor-rank rule true if anything ever writes an
  equipment list directly.
- **Ruling 25** — the Warrior rage ledger, option (b). §2 has the measurement.
- **§7 task 5, code half** — `kits.lua`'s "Holy tree" comment names Mercy.

### 1.4 The interim interface

Lane X4 owns the sfinv Talents page, so until it lands there is no way to play
a talent at all. Three **player-reachable** chat commands fill the gap and
**X4 removes them**:

- `/talents` — class, points total/spent/left, then each tree with its point
  count and each talent as `id rank/max Name`, with the reason it is locked;
- `/talent <id>` — spends one rank, or refuses with that reason;
- `/respec` — full reset, free for now.

The level-up chat line of §3.6 ships with them, on the existing `grug_xp`
level-change registration in `stats.lua` and with the `old_level ~= nil` guard
that join needs. The same call does ruling 20's last bullet: an **admin level
drop wipes the talents and returns every point**, free.

---

## 2. Measurements

Every number below is produced by a command in §4, not estimated.

### 2.1 Counts

| | Measured | Source |
|---|---|---|
| talent registrations | **48** | KAT group 1, engine probe |
| trees | **6** (2 per class) | KAT group 1, engine probe |
| ranks per tree | **28** (13 + 15) | KAT group 1 |
| ranks per class | **56** | KAT group 1 |
| points at level 60 | **30** | KAT group 2 |
| first point | **level 2** (level 1 = 0, level 3 = 1) | KAT group 2 |
| a capstone | **21 points in its tree = level 42** | KAT group 2, by real spends |
| two capstones | 21 + 21 = **42 > 30**, out of reach | KAT group 2 |
| a whole tree | **28 points = level 56**, 2 left over | KAT group 2 |
| base kit per class after ruling 19 | **4** (warrior, mage, priest) | engine probe |
| effect keys | **46** declared, **24** read by a consumer, **22** pending lane X3 | KAT group 5 |
| applied `hp_max`, Weathered 4/4 | **325 → 337**, back to **325** on respec, **0** healing on a spend | KAT group 6, engine probe |
| admin level drop 60 → 4 | **14** ranks wiped, **0** spent, **2** points available | KAT group 4 |

### 2.2 The rage ledger (ruling 25)

Computed by the KAT from the constants the shipped file actually carries; the
"before" row is the code this lane replaced.

| | before | after |
|---|---|---|
| landed full swing | +12 | **+8** |
| hit taken | +4 | **+3** |
| out-of-combat decay | −2 /s | **−5 /s** |
| landed swings to a full bar from 0 | 9 | **13** |
| seconds from 100 to empty, out of combat | 50 | **20** |
| landed swings per Mighty Blow (25 rage) | 3 | **4** |

**One correction to the ruling's wording.** Ruling 25 and §7 task 8 both say
"**add** a 5 rage/s out-of-combat decay on the existing `grug_core.in_combat`
window". The code already had one: `grug_abilities/init.lua` decayed rage at
**2 per second** out of combat (the `cur - 2 * elapsed` line in the resource
ticker). This lane therefore **raises 2 to 5** rather than adding a decay. The
ruling's intent — a faster bleed — is unchanged, and the measured
seconds-to-empty above is against the real old number.

The three income numbers are named constants (`RAGE_PER_SWING`,
`RAGE_PER_HIT_TAKEN`, `RAGE_DECAY_PER_SECOND`), so §7 task 8's recorded
fallback — **option (a): leave the income alone and raise the prices instead,
Mighty Blow 25 → 35 and Hamstring 10 → 15** — costs three edits plus two kit
numbers if the user's playtest says (b) overshoots and leaves the Warrior
starved.

### 2.3 The neutral seams

With no talent ranked, measured through the shipped functions on the real
ability defs (KAT group 8, and again inside the engine):

Taunt **8 s**, Charge **10 s**, Blink **15 s**, Smite **2 s**, Hamstring's
charge **6 s**, Fireball **8 mana**, Fireball's targeting reach **20 m**, an
elf's Fireball **25 m**, Fireball's flight **20 m** and its damage
**6 + spell power**. With the talents ranked, through the same functions:
Grudge 3/3 → Taunt **5 s**; Onset 4/4 → Charge **6 s**; Quick Step 4/4 → Blink
**9 s**; Swift Word 4/4 → Smite **1.4 s**; Far Cast 4/4 → Fireball **26 m**
reach *and* **26 m** flight; Tinder 5/5 → Fireball **+5** damage.

### 2.4 Gates

`bash tools/wp40/r7/run.sh unit` **PASS** (unchanged). `python3
tools/check_fresh_server.py` **PASS**. Parser and SETGLOBAL clean on all nine
changed files and tree-wide; the five plain-5.1 sweeps produce only the
pre-existing `|`-inside-a-string hits of sweep 4, none of them on a line this
lane wrote. The `tools/wp13/final_micro.lua` pair is byte-identical
(`4d41e72a8980389f6dad96341bb20443f9ddc903eb1450930149c63ac9952484`); this
lane touches no mapgen file.

The KAT is byte-identical under LuaJIT and PUC 5.1
(`0990656c6b0385987260537f23dca94f8e0aa6d58ae6e4fd176365d115181eff`; it moves
with any measured number, by design, and it moved from `83c7a9b1…` when the
review fixes added the applied-ceiling and level-drop rows).

---

## 3. What the review should look at

1. **The gate arithmetic, in the validating read path.** A tier gate is
   "points in the tree MINUS this talent's own ranks ≥ the gate". That is the
   order-independent form of "the points already spent when its first rank was
   bought", and it is what makes a forged three-rank tier-4 talent on a
   20-point tree drop while the legal one on a 23-point tree survives. The
   spend rule uses the same expression, which is why the two cannot drift.
2. **The budget trim.** When a forged string spends more than
   `floor(level / 2)`, ranks are returned deepest-tier-first, latest
   registration first inside a tier, re-running the gate fixpoint after each —
   a total order, so two servers cannot disagree about the same forged string.
3. **`get_talent_bonus` on the damage pipeline** (§1.1's performance note) and
   the invalidation set: spend, respec, level change, class pick, leave.
4. **`apply_stats` as the first `on_talents_changed` consumer**, and the two
   orderings it depends on: it is registered at the bottom of `talents.lua`
   (which is `dofile`d after `stats.lua`, so `stats.lua` could not register
   it), and `commit` drops the parsed cache **before** firing the callbacks,
   so `apply_stats` reads the state the spend just produced.
5. **`max_mana_percent_add` is shared by Deep Well (Mage) and Deep Reserve
   (Priest)** and the consumer adds the percentages over the *untalented* pool
   rather than compounding. No character can hold both today; if the key is
   ever given to a third class's tree that choice becomes visible.
6. **The two seams' data fields** (`cooldown_talent`, `range_talent`). They
   move a talent's identity into the kit table, which is where the number it
   re-tunes lives; the alternative was an id list inside `grug_abilities`.

---

## 4. How to re-run every claim

From the repository root, with `LC_ALL=C`:

```
bash tools/wp11/static.sh                 # parser, SETGLOBAL, sweeps, fresh-server,
                                          # WP40 unit, the KAT under both interpreters
luajit          -e 'io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))'
tools/bin/lua51 -e 'io.write(dofile("tools/wp11/talent_tree_kat.lua")("."))'
bash tools/wp11/mutations.sh              # eight deliberate breaks, each going red
luajit          tools/wp13/final_micro.lua . /tmp/micro-luajit.tsv luajit
tools/bin/lua51 tools/wp13/final_micro.lua . /tmp/micro-puc.tsv    puc51
PORT=31112 PROBE="$PWD/tools/wp11/probe_talents" \
	nice -n 19 bash tools/luanti_headless.sh 150   # the engine probe
```

The engine probe is `tools/wp11/probe_talents/`, staged into the throwaway game
copy and never shipped. It prints `WP11PROBE` lines into the server log and a
final `WP11PROBE RESULT PASS|FAIL n`.

**Mutation proofs** (`tools/wp11/mutations.sh`). Each mutation is restored
from a byte copy the script takes itself, **not** from version control — an
uncommitted change in a mutated file would otherwise be thrown away, which is
what happened the first time it ran against a dirty tree. The ten: a tier gate
lowered from 12 to 9; the hard chain no longer checked on a spend; the
persistence read aliasing an unknown id onto a real talent; one `add_rage`
site left on the retired 12; the cooldown seam defaulting to
`def.cooldown - 1`; a tier-1 talent given a sixth rank; a window key leaking
past its expiry; a consumer dropping its effect key; the talents-changed
consumer removed; and the free reset on an admin level drop disabled. All ten
turn the KAT red, with between one and eight named failures.

---

## 5. What is open

### 5.1 Inside WP11

- **Lane X3**: the four new ability registrations (Hold Ground, Cinderfall,
  Glacial Ward, Word of Ruin), the grant predicate at the three `talent_gated`
  sites plus the append-after-base-kit rule of §3.4, the seven replacements,
  Tendon Cut, the five capstone effects, the two cap-override paths and
  `combat_stats.md` §2's cap-override paragraph (§7 task 2). **Hold Ground's
  root/slow immunity needs the `grug_core` movement aggregator of §3.9 first**,
  which the mob-pressure lane owns.
- **Lane X4**: the sfinv Talents page, the two `mod.conf` edges (`sfinv`,
  `grug_money`), the respec price of ruling 22, and the removal of the three
  interim chat commands.
- **`register_on_talents_changed(sync_kit)` (§3.4)** is X3's, and two things
  wait on it: taking a talent-granted button back on a respec, and re-deriving
  the per-stack `range` meta override so a range talent reaches the *client's*
  pointing ray without a relog (§1.2).
- **Hold Ground's timed window is X3's.** §3.2 counts it among the eight, but
  the def here is deliberately **not** `window = true`: only its root/slow
  immunity is windowed, while `hold_ground_absorb` is read once at cast time
  and must answer whenever X3 asks — marking the def windowed would make
  `get_talent_bonus` return 0 for the amount outside the window. The immunity
  belongs on the §3.9 movement aggregator's own flag, not on a talent effect
  key. The registration says so in place.
- **Absorb stacking (ruling 23, §3.11)** is X3's and is not done, so the
  shipped single-slot absorb still means a Priest's Power Word: Shield
  overwrites a Mage's Glacial Ward once those exist.

### 5.2 Three places where `skill_trees.md` contradicts itself

Resolved here in favour of the arithmetic, and named so the design doc can be
corrected by whoever owns it:

1. **§3.7 group 1 says "Totals: 30 ranks per tree, 60 per class".** §1.2, §2.9,
   §3.7's own group 2 and `BACKLOG.md`'s WP11 row all say **28 and 56**, and
   28 is what ruling 17's one-rank capstone produces. Implemented: **28 / 56**.
2. **§3.7 group 3 says "a capstone refused at 20 points in the tree and
   accepted at 21"**, one clause after saying "tier 4 with 19 refused, 20
   accepted". §1.3 settles it: the tier-4 gate is 20 points already spent, the
   capstone is the **21st** point, and that is level 42 — the level §1.3 and
   ruling 18 both name. Implemented: **accepted at 20 points in the tree**.
3. **§3.1's `register_talent` example gives Unbroken three ranks**
   (`armor_cap_override = {70, 75, 80}`). Ruling 17 made every capstone one
   rank, and §2.1 states Unbroken as +15 armor with the cap at 75.
   Implemented: **one rank, `{15}` and `{75}`**.

### 5.3 One genuine design gap

**Broadstroke has three ranks and no per-rank scaling.** §2.2's row gives it
3 ranks like every tier-3 keystone, but its effect text ("every other hostile
within 3 m for half its total") is the same at rank 1 and rank 3, while every
other multi-rank keystone in the design scales (Bellow 6/8/10 m, Brand 2/3/4,
Frostbind 3/4/5 m, Turn Aside 10/15/20, Recompense 6/9/12). It is registered
here as `mighty_blow_cleave = {3, 3, 3}` — the radius, unscaled as written —
so ranks 2 and 3 currently buy nothing. **Lane X3 or the user should decide
what they buy** (a growing radius and a rising share are the two obvious
candidates).

### 5.4 Not this lane's files, and still wrong

- `BACKLOG.md`'s WP11 row says "five open decisions in `skill_trees.md` §6";
  §6 has said "no open decisions" since the sixth round of rulings, and the
  row's status is still `open`.
- `skill_trees.md` §2.1 and §2.2 still carry the pre-ruling-25 parentheticals
  "(base 4)" for Spite and "(base 12)" for Stoke. Ruling 25 is what changed
  those bases; the shipped talent descriptions say 3 and 8, and this lane may
  only add a status line to that file. (Raised by the independent review.)
- `AGENTS.md:442` still reasons from "+12" for the PvP tool/fist fraction
  rage.
- `skill_trees.md` §7 tasks **1, 3, 6, 7 and 9** are untouched: the
  `mounts.md`/`combat_stats.md` Sprint exception, the class trainer in
  `economy.md:92` / `items_crafting.md:2380` / `world.md:408` /
  `docs/research/post-wp40-readiness.md:81`, the mcl_bows media line, the three
  drifted `api.lua` citations, and the ranged damage term. Task 2 is X3's.
  Task 5's other half is the `classes.md:464` Renew row.
- `selection.lua`'s `register_set_command` keeps its `cmd == "class"` branch,
  which is now unreachable. §3.10 says the registration is removed "and nothing
  else", and keeping the hunk to two lines keeps it out of the lane that
  rewrites the spawn freeze in the same file.

---

## 6. What the user should play, in a FRESH world

Nothing in this lane is visible without a player, so the headless probe proves
state and the playtest proves feel. In order:

1. **Make a Warrior and look at the hotbar.** It must be **Strike, Charge,
   Mighty Blow, Taunt — four keys, no Hamstring** (ruling 19). Mage and Priest
   are unchanged at four each. *A Warrior has no snare at all until lane X3
   lands the keystone; that is the ruling, not a regression.*
2. **Fight something and watch the rage bar** (ruling 25). It should now take
   about **13 landed swings** to fill from empty instead of 9, **four swings**
   between Mighty Blows instead of three, and a full bar should be **gone
   twenty seconds** after the fight instead of fifty. The question for the
   playtest is the one the ruling was written for: does rage now feel like a
   resource, or does the Warrior feel starved? If starved, §7 task 8's
   fallback (prices up instead of income down) is recorded and cheap.
3. **`/talents`.** At level 1 it should say 0 points. Level up (`/xp` works) and
   check that the first point arrives at **level 2** and one more every second
   level, with a chat line each time.
4. **`/talent ironbound`** five times, then **`/talent hold_ground`** — it must
   refuse with *"Hold Ground needs 12 points in Bulwark"* rather than doing
   nothing. Spend three into `spite` and try again; it should go through.
5. **Feel a talent.** `ironbound` 5/5 is +5% armor; `weathered` 4/4 is +12 max
   HP (the health bar grows immediately); `grudge` 3/3 takes Taunt's cooldown
   from 8 s to 5 s, which is visible on the icon's wear bar. On a Mage,
   `far_cast` 4/4 should let a Fireball reach noticeably further, and the
   crosshair should let you *target* that far as well.
6. **`/respec`.** Every point comes back, the stored string is emptied, and
   `/talents` shows the full budget again. It is free for now — the price lands
   with lane X4.
7. **`/class` must be gone** (ruling 20) and **`/race` must still work**.
8. **Relog** and check that the talents are still there: they live in player
   meta and are parsed fresh on every read.

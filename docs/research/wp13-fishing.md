# WP13 playtest round 5 — the axe in the hand, the rod, and fish

Increment record for wave 3's lane F. Base: `main` at `f37a0c5b` ("Freeze the
Dur Brannoc corner digest on the gate seed"). Evidence:
[`tools/wp13/evidence/20260916-fishing/`](../../tools/wp13/evidence/20260916-fishing/).

Three user rulings from playtest 5 (2026-09-16) built it:

1. *"The axe blades of the Dur Brannoc residents point the wrong way"* — fix at
   the root, not per NPC.
2. *"The fishing rods of anglers sit in the middle of the hand, and they are
   sticks. VoxeLibre has a rod that looks good, we should take it into the
   game."*
3. *"We should plan fish too (for cooking). Later special fishing loot tables
   per zone. Fish availability shall be IDENTICAL on both continents
   (distributed over the zones)."*

---

## 1. The axe

### 1.1 What was wrong, measured

The wield convention (round 2, `mods/PLAYER/grug_visuals/wield_geometry.lua`)
fixes a held sprite's LONG axis — the image's anti-diagonal through the grip
pixel (3.4, 12.6) — and leaves the ROLL about that axis to one Euler triple,
`x = 90, y = -(45 + t), z = 90`. That triple maps the image's **up-left** side
to model **up**. All three axe families draw the bit on the up-left side, so
through it the cutting edge points at the sky.

That the roll is otherwise invisible is not an assumption; it is measured by
`tools/wp13/evidence/20260916-fishing/sprite_axis.py`, which mirrors every held
sprite about its own long axis (exactly what a 180° roll does in the world) and
compares silhouettes:

| sprite family | silhouette overlap under the roll | pixels that move |
|---|---|---|
| `default_tool_*sword` (6), `*pick` (6), `*shovel` (6) | **100.0 %** | 0 |
| `grug_materials_tool_*pick` (4), `*shovel` (4) | **100.0 %** | 0 |
| `grug_gear_item_sword_*` (6), `_dagger_*` (6) | **100.0 %** | 0 |
| `default_stick` | **100.0 %** | 0 |
| `grug_gear_item_staff_*` (7) | 34.5 % | 18 |
| `grug_fishing_rod` | 40.0 % | 27 |
| `default_tool_*axe` (6) | **26.3 %** | 28 |
| `grug_materials_tool_*axe` (4) | **26.3 %** | 28 |
| `grug_gear_item_greataxe_*` (6) | **17.4 %** | 38 |

**39 of the 63** sprites a character can hold are invariant; `sprite_axis.py`
prints those two counts itself, because the first version of this section quoted
a hand count ("26 sprites") and got it wrong.

So a sword, a dagger, a pick, a shovel and a stick **cannot tell the two rolls
apart** — the round-2 sword the user approved is provably untouched by this
change — while an axe's whole head moves. (Stronger still, and checked by the
review: the `tool` and `upright` branches of `wield_transform` return bitwise
identical `pos`/`rot`/`size` before and after this lane at four statures, so
nothing outside the axe family moves by a single float.)

**There are THREE axe families, not two.** Besides minetest_game's four
surviving hatchets and the generator's six greataxes,
`mods/ITEMS/grug_materials/tools.lua` registers
`grug_materials:axe_{iron,silversteel,embersteel,abyssal_steel}` with
`groups = {axe = 1, grug_equip_weapon = 1}`. They take the rolled pose too, and
they were measured by nothing until the review of 2026-09-16 pointed it out:
they are now four rows in `sprite_axis.py`'s corpus (26.3 %, 28 px moved, the
same geometry as `default`'s) and four rows in the KAT's `POSE_CASES`. Fourteen
items in all.

### 1.2 Why "up" is the wrong side, and not a matter of taste

The arm swings. `character.b3d`'s `mine` frames rotate `Arm_Right` about its own
local x (the fixture measures +114.1° at the peak, forward), and the sprite's
plane **is** the plane that swing happens in. Follow the head through the
downstroke: the chop is an angular velocity along model +x, the velocity of a
point out along the haft is that crossed with the blade, and with the head on
the up side the dot product is **−1** — the axe's poll leads and the edge
trails. Mirror it and it is **+1**. `tools/wp13/wield_transform_kat.lua` prints
both numbers, for the arm hanging and for the arm at 90°, and the trailing one
is kept as the negative control: a fixture that cannot reproduce the reported
defect has not modelled the engine.

### 1.3 What shipped

A **third pose**, `POSE.edge_down`, in the same file as the derivation, for art
whose working edge is drawn off the long axis. It is the tool transform rolled
180° about the blade; composing that roll into section 7's matrix gives, again
uniquely,

```
x = 90,   y = -(45 - t),   z = -90
```

— the 45 changing sign against the tilt because the mirror negates the in-plane
roll while leaving the long axis alone. The **position does not move at all**:
the grip pixel is on the anti-diagonal, which the mirror fixes point by point.
Measured, relative to the fist, by the KAT:

```
tool      hanging   hilt 0,0,-1.923  grip 0,0,0  tip 0,0,7.128  flat -1,0,0  head 0,+1,0
edge_down hanging   hilt 0,0,-1.923  grip 0,0,0  tip 0,0,7.128  flat +1,0,0  head 0,-1,0
tool      raised90  ...                                          flat -1,0,0  head 0,0,-1
edge_down raised90  ...                                          flat +1,0,0  head 0,0,+1
```

Which items get it is a **group**, like the diagonal/upright split already was,
and both tables moved out of `apply.lua` into `wield_geometry.lua` — they *are*
the sprite convention, and a fixture with no engine has to be able to read them.
`EDGE_DOWN` is `{"axe"}` and is checked **first**, because `grug_gear`'s
greataxes and even `default:axe_stone` also carry `grug_equip_weapon` (the boot
log shows `default:axe_stone groups=axe=1,grug_equip_weapon=1`) and would
otherwise fall through to the plain tool pose.

**The player's axe goes through the same seam** — `apply.lua`'s `shown_item`
routes a hotbar axe and an NPC's activity tool into one `sync_wield` — so this
is one fix, not a fix per NPC. Renders of before and after, at four points of
the chop, are in `evidence/.../renders/wield-axe.png` and `wield-greataxe.png`;
`wield-sword.png` is the same pair for the sword, where the two rows are
identical by construction.

The staff is deliberately **not** rolled: its off-axis mass is a knob, not an
edge, and nothing about it has to lead a swing.

---

## 2. The rod

### 2.1 The defect

`fish` villagers wielded `default:stick`. A stick declares none of the diagonal
families, so the seam holds it in the **upright** pose — centre in the fist —
which is exactly the report: *"the fishing rods of anglers sit in the middle of
the hand"*. `renders/wield-rod.png` shows the two rows side by side.

### 2.2 The import

VoxeLibre's `mcl_fishing_fishing_rod.png`, copied byte for byte as
`mods/ITEMS/grug_fishing/textures/grug_fishing_rod.png` (sha256
`c1298c45…0e37eb3d`). `docs/research/licensing.md` §2/§3.2 permits CC BY-SA 4.0
media kept under CC BY-SA 4.0 with attribution; the row naming the base pack
(Pixel Perfection, XSSheep), the licence, the source and "no modification" is in
`mods/ITEMS/grug_fishing/LICENSE-media.md`, quoting submodule pin
`c2dbc520ff4e1637072d33b06c3a2404e0f08df7`.

It needed **no redrawing**: the sprite is already in this game's convention —
long axis on the anti-diagonal, grip bottom-left, an opaque pixel under the fist
at (3, 12) — with the line and the float hanging off the **down-right** side,
which the plain tool pose turns into "downwards". Measured centroid offset
**−0.86** (the axe families are +0.49 and +1.48, i.e. the other way).

### 2.3 Its wield class

`fishing_rod` joins `DIAGONAL_GROUP`, so the rod is a **tool-pose** item:
`POSE.tool`, `rot 90,-45,90`, grip in the fist. Not `edge_down` — a rod has no
edge, and its line has to hang down. The KAT's `wp13_wield_pose` rows print the
class for thirteen real items including this one, and the engine probe prints
the same classes out of the live registry.

---

## 3. Fish and the cooked fish

**The raw fish already existed.** `grug_mobs:raw_fish` is a WP6 Mirefolk drop,
priced 2c by the traders, and `items_crafting.md` §2.3's cooking ladder already
called its T1 dish "Cooked Fish". Fishing is therefore a second **source**, not
a second fish — the KAT refuses any catch-table entry registered by
`grug_fishing` itself.

What is new is `grug_fishing:cooked_fish`: a `cooking` recipe from the raw fish
(cooktime 5) with the cooked-meat numbers (`core.item_eat(8)` plus
`mobs.add_eatable`, mirroring `mobs:meat`), group `food_fish`, **no food buff**.
It ships **no PNG**: its icon is the existing raw-fish art through
`^[multiply:#d59a5a`, the runtime-derivative pattern `grug_gear` and
`grug_gathering` already use.

**The T4 Marshbloom Chowder, the T5 Salt-Crusted Fish, the restore percentages
and the Well Fed model belong to WP10** (professions owns free Cooking and the
six cooking groups, `BACKLOG.md`), and nothing here pre-empts them. The rows
appended to `items_crafting.md` §3.7 say so in the document as well.

**Trader audits.** Neither the rod nor the cooked fish carries
`_grug_sell_price`. The anti-loop audit walks only recipes whose *output* has a
price, so with both unpriced there is nothing for it to judge — and the cooked
fish is then exactly as sellable as `mobs:meat`, which is also unpriced.
`grug_traders` was not edited. The boot log shows its three audits clean.

---

## 4. The mechanic

One mod, `mods/ITEMS/grug_fishing`, one global, two files.

* **Cast**: right-click water with the rod. The rod declares
  `liquids_pointable = true` — `default:water_source` is `pointable = false`,
  and that flag is the only way a click can land on it — and `range = 8`, so an
  angler fishes from the bank.
* **Bite**: `3 .. 10 s`, drawn from a `PcgRandom` (AGENTS.md's rule; seeded from
  the wall clock, because a bite is the one thing here that *should* differ
  between two identical casts).
* **Catch**: one weighted table, **78 % `grug_mobs:raw_fish`, 12 %
  `default:stick`, 10 % `default:papyrus`** — weights are percent and sum to
  100. Deliberately **not** `grug_gathering:stormkelp`: that is the front-only
  T5 cooking gate, and a world-wide fishing source for it would hand every pond
  the ingredient the design puts on the contested front.
* **One table for the whole world**, per the ruling. The seam for the later
  per-zone tables is `grug_fishing.table_for(pos)` — it already takes the
  position and returns the one table there is; nothing outside `catch.lua` may
  name the table directly. The KAT calls it at eight positions spanning both
  sides of the z = 0 mirror and requires the *same table object* back.
* **Re-validated at the bite, never trusted from the cast**: the angler is
  online, still holding a rod, within 8 nodes, and the water is still there.
  A second right-click reels the line in. A full pack drops the catch rather
  than eating it. Only a landed catch wears the rod (64 catches).
* **Cost when nobody fishes**: one float add, one compare and one `next` every
  0.5 s. The globalstep is throttled the AGENTS.md way and returns on an empty
  table before doing anything else.
* **Craft**: 3 × `default:stick` + 2 × `grug_mobs:spider_silk` in VoxeLibre's
  mirrored pair of shapes. Spider Silk is the game's only string-class material
  (`grug_mobs/items.lua`, "Spider Silk", Tailor T3, 5c).
* **NPCs**: `start_villagers.lua`'s ACTIVITY row `fish` now names
  `grug_fishing:rod` instead of `default:stick`. `grug_mobs` gains **no
  dependency** — the field is a string the visuals seam resolves at draw time —
  and its own startup audit is what would notice the mod going away. It did
  notice, while this lane was being written: `start_npcs_kat.lua` went red with
  *"fish wields the unregistered grug_fishing:rod"* until the fixture's
  independent item transcription learned the new name.

---

## 5. How it is verified

| Claim | Evidence |
|---|---|
| the axe pose is the tool pose rolled, and only rolled | `tools/wp13/wield_transform_kat.lua` section C1b: hilt, grip, tip and blade identical to three decimals at two arm angles; `flat` and `head` exactly negated; size and position unchanged; `rot.z` negated |
| the edge leads the chop, and did not before | the same section's `leads()` dot product: **+1** after, **−1** before (kept as the control) |
| which items are in which pose | `wp13_wield_pose` rows for 13 real items, driven through the shipped `grug_visuals.pose_for`; and the same 8 classes re-read out of the live engine registry in `headless-boot.log` |
| the roll cannot move a sword, dagger, pick, shovel or stick | `sprite_axis.py`, 100.0 % silhouette overlap on **39 of 63** held sprites, counted by the script itself |
| all three axe families take the rolled pose | `sprite_axis.py` measures `grug_materials`' four axes alongside `default`'s and the greataxes; `wp13_wield_pose` asserts the mapping for `grug_materials:axe_iron` and `_abyssal_steel` (and their pick/shovel siblings staying `tool`) |
| the rod is in the game's sprite convention | `sprite_axis.py`: opaque grip pixel, centroid −0.86 (line on the down side) |
| the catch table and the bite | `tools/wp13/fishing_kat.lua` sections A and B: weights exhaustively enumerated (every roll 0..99 lands on exactly its entry's weight), both continents, both ends of the wait, clamping |
| the mechanic | the same fixture's section D drives the **real** `on_place` closure and the **real** globalstep through nine cases (lands / reeled in / walked off / rod away / water gone / dry land / full pack / junk roll / left the server), with "one tick before the bite" as the negative control |
| the registrations are what the fixture says | `headless-boot.log`, one clean boot, zero `ERROR`/`ModError`, `[fishprobe]` lines carrying groups, recipes, poses and the catch table straight out of the engine |
| an angler really holds the rod | `headless-boot-angler-reload.log`: all three Kezamba `fish` sockets, `wield_item=grug_fishing:rod wield_pose=tool wield_entity=true`; and `watch-gate-B-unwatched.log`, where a **fresh** world does the same as soon as the probe stops being the only thing in the way. §6a |
| the fresh-world empty hands are the probe, not the game | `watch_gate.sh`: two boots, two fresh worlds, one variable (`grug_mobs.nearest_player_d2`). A: three anglers empty for 200 s. B: all three holding the rod at t=60. No shipped byte patched |
| nothing else moved | the six start identities and Highcourt's blueprint digests re-run and compared to main; `tools/wp40/r7/run.sh unit` PASS |

Both KATs are byte-identical under LuaJIT and `tools/bin/lua51`
(`kat-luajit.txt` / `kat-puc51.txt`), and the mutation runs in
`mutations.txt` show each of them going red when the property is broken on
purpose.

---

## 6. What a review should look at

* **The roll's sign.** Everything in §1.2 hangs on the bone frame
  `diag(-1, -1, 1)` and on Irrlicht's `Rz·Ry·Rx` order. Both are re-derived
  independently inside the KAT from `character.b3d`, but they are the place a
  sign error would hide.
* **`EDGE_DOWN` before `DIAGONAL`.** If the order is ever swapped, every axe
  silently returns to the old pose and only the `wp13_wield_pose` rows notice.
  (The review tried exactly that mutation; it bites.)
* **A NEW axe sprite is not automatically right.** The rolled pose is correct
  for today's fourteen axes because all three families happen to draw the bit on
  the same side — measured, not assumed. A future axe drawn the other way would
  take the pose and be wrong, and only `sprite_axis.py`'s centroid column would
  say so.
* **One known blind spot, written down rather than papered over.** The rolled
  pose's `tilt_sign` decides how it treats `TILT_UP`, and `TILT_UP` is **0** —
  so the sign is inert for every byte this lane ships and no fixture can see
  it. `mutations.txt` case **M2** flips it on purpose and is *expected to
  pass*, which is the point of listing it. This is the same class of finding
  the round-2 review recorded for `e2_z`: raise `TILT_UP` above 0 and M2 has to
  start failing.
* **`pose_for` is called once a second per player.** It takes the group lookup
  as an argument rather than closing over the item name precisely so that the
  poll allocates nothing; a refactor that reintroduces a closure there is a
  regression.
* **The fishing globalstep.** The table is keyed by player name and cleared on
  leave and on death; `reel` writes `casts`, which is why the due list is
  collected before it is walked.
* **The junk choice.** `default:papyrus` and `default:stick` were picked because
  they are worthless and unpriced. Any later addition to that table has to be
  checked against §3.8's anti-loop rule and against the front-only gate
  ingredients.

### Five exact numbers and decisions, recorded because the review asked for them

* **The rod lasts 65 catches, not 64.** `ROD_WEAR = floor(65535/64) = 1023`;
  after 64 catches wear is 65472 and `ItemStack::addWear` clears only when the
  next step would exceed 65535 — the 65th. The constant is named `ROD_USES = 64`
  and the audit line says `rod 64 uses`, which is the engine's own `uses = N`
  convention, so the rod wears exactly like every other tool in the game. The
  off-by-one is real and cosmetic; it is written down rather than "fixed" into
  disagreeing with every other tool.
* **`range = 8` is not only a casting range.** An item definition's `range` sets
  the wielder's whole interaction distance while that item is held, so with the
  rod in hand a player can right-click a door, a chest or a vendor from 8 nodes
  instead of the usual 4. That is a side effect of a number chosen for water and
  a reviewer should know it exists — but it is **not new and not the rod's
  alone**, and one claim of the review needs correcting here: the rod is *not*
  the only item in the game that sets `range`. Every ability orb does
  (`grug_abilities/init.lua:544`, `range = def.range or 4`), and
  `grug_abilities/kits.lua` runs 4, 8, 12 and **20** — Fireball already extends
  a player's interaction reach two and a half times further than this rod, by
  design (AGENTS.md: "item `range` = targeting range"). So the rod joins an
  existing pattern at its low end. Server-side consumers that care re-validate
  distance themselves (the trade formspec does, on every action).
* **There is deliberately no `is_protected` check on a cast.** The game has real
  faction protection (`grug_core/protection.lua`, honoured by
  `grug_materials/mining.lua`), and fishing does not go through it: fishing
  changes no node, so there is nothing for the protection rule to guard.
  Fishing in an enemy capital's cenote is therefore allowed. If the design ever
  wants it blocked, the check goes in `cast_or_reel` and nowhere else.
* **Fishing is a small, unaudited vendor faucet, and that is for WP10/economy to
  price.** A rod costs 3 sticks + 2 Spider Silk and yields ≈ 65 × 78 % ≈ 51 raw
  fish at 2c ≈ **102c** of vendor value. `grug_traders` audit 3 correctly does
  not fire — it walks craft/cook recipes, and this is a gathering faucet like
  mining, not a loop — but the number belongs on record next to the other
  income figures of `items_crafting.md` §8.1.
* **The sprite counts are printed, not hand-counted.** The first write-up of
  §1.1 said "26 sprites"; `sprite_axis.py` now ends with a counted line
  (`rows: 63   invariant under the roll (100.0%): 39   moved by it: 24`) so the
  number in a note can always be copied from a run.

## 6a. The empty-handed anglers are a PROBE ARTEFACT — corrected 2026-09-16

**The first version of this section was wrong, and the correction matters more
than the observation.** It blamed a failed `add_entity` inside `sync_wield`
plus the one-shot `grug_work_dressed` flag, and proposed a per-tick
`apply_race_visual` for every work resident in the game. The independent review
rejected that diagnosis; measuring it settled the question, and the proposed
patch is **withdrawn**.

### The observation

On a **fresh** headless world all three Kezamba `fish` sockets carry a
`grug_mobs:villager_troll` with `activity=fish` and an **empty hand** at every
sample (`headless-boot-angler.log`: 180 s; the reviewer's own boot: 420 s). The
**same world rebooted** through `ROOT=` gives all three
`wield_item=grug_fishing:rod wield_pose=tool wield_entity=true` twenty seconds
in (`headless-boot-angler-reload.log`).

### The cause

`work_tick` reaches its dressing block only past the watch gate
(`start_villagers.lua:786`):

```lua
if not watched(self, pos) then
    …
    return false
end
-- The tool and the pose, once per activation.
if not temp.grug_work_dressed then …
```

and `watched` asks `grug_mobs.nearest_player_d2`, which returns **nil when
nobody is connected** — `levels.lua`'s own comment for the same call says
`visible = false -- nobody connected`. A headless boot has no player, so the
gate is false on every tick and the dressing block is **never reached at all**.
The wield seam is not involved.

### The controlled experiment

`watch_gate.sh` runs two boots, each on its own fresh world, differing in
exactly one thing: the second stages an `unwatch.lua` next to the probe that
replaces `grug_mobs.nearest_player_d2` with a function answering 0. No shipped
byte is patched — `watched` reads that field off the global table on every
call — and the probe prints `players=` and `watch_override=` on every sample so
the two halves cannot be confused.

```
A-watched    watch_override false   players=0   3 anglers, wield_item=nil for the whole window
B-unwatched  watch_override true    players=0   3 anglers, wield_item=grug_fishing:rod wield_pose=tool
```

One variable, two outcomes. Two further corroborations, both in this lane's own
evidence and both pointed out by the review:

* `npc-probe/probe.txt` shows the `chop` resident with **`anim=stand`** on the
  fresh boot, not `anim=work`. The animation is set *after* the same gate, so a
  failing `add_entity` could not explain it.
* The failure is **100 % uniform** — three anglers, every sample, every work
  resident of the start programme. An `add_entity` race would be sporadic.

The reload half is the other branch: `after_activate` dresses unconditionally
when `_grug_work_activity` is already in staticdata, and it runs whether or not
anyone is watching.

### What follows

* **Nothing ships differently, and no lane needs to fix anything.** A player who
  can see an angler is by definition within the 24-node watch radius, so the
  gate is true and the resident is dressed on the next work tick. The user will
  not see empty hands; a headless probe always will.
* The **one-shot flag remains a latent risk** — if `spawn_wield` ever failed on
  the single dressing tick there would be no retry for a mob, only for players
  (who have the once-a-second poll). That path is **unmeasured**: this lane
  never observed it, because the gate stopped the tick before it could.
  Narrow, self-healing on the next unload/reload, and not worth a behaviour
  change to the NPC tick on this evidence.
* **What to do with a headless probe of NPC appearance**: stage an
  `unwatch.lua`, or the probe will keep reporting a defect the game does not
  have.

## 7. What is open

*(The two stale documents this list used to name are now fixed here:
`docs/design/character_visuals.md` §4 describes three poses and the
`fishing_rod` family, and `docs/research/wp13-weapon-ladder.md` carries a dated
status pointer rather than a rewritten record — it is the round-2 record and
stays as written.)*

* **Per-zone fishing tables** (the user's "later"): the seam is
  `grug_fishing.table_for(pos)` and it is the only thing that needs to change.
* **More fish species.** One species is what the cooking ladder needs today;
  the zone-table lane is the natural place for more, and the "identical on both
  continents" ruling is the constraint it has to keep.
* **Food buffs.** WP10 owns Well Fed, the restore percentages and the T4/T5
  fish dishes.
* **The rod in first person.** This lane only owns the third-person attached
  entity. The engine's own first-person wielditem uses `wield_image` (which the
  rod does not declare, so it falls back to the inventory image) and is
  untouched.

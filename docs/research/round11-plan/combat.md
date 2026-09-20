> Consolidated planning annex. [README.md](README.md) governs any conflict.
> Values are proposed for approval with the complete plan; no runtime is implemented.

# Round 11 armor and small creature-presentation plan

Read-only planning against `ac232ec2`; no implementation or runtime claim.

## Recommended armor model

Use one numerical **armor rating** total and resolve it against the attacker's
level:

```
K(L) = 20 + 0.5 * min(L, 60) + 8.5 * max(L - 60, 0)
DR   = min(0.70, A_raw / (A_raw + K(attacker_level)))
damage_after_armor = ceil(damage * (1 - DR))
```

`L` is the attacker level, clamped to at least 1. The steeper post-60 term is
deliberate: K(60)=50, K(65)=92.5 and K(70)=135, so a king and a dragon penetrate
visibly more armor without adding a boss-only bypass. There is deliberately no
defender-level or effective-rating cap: raw armor that overcaps against an
equal-level enemy remains useful against stronger enemies. Only final DR is
capped at 70%. Keep the current “armor cannot reduce a positive hit to zero”
consequence of `ceil`.

This reuses the shipped six-tier armor budget rather than replacing it. Current
base set totals at catalog item levels 3/10/20/30/40/50 are:

| Tier | Cloth | Leather | Metal | Refined metal | Proposed shield |
|---|---:|---:|---:|---:|---:|
| 1 | 4 | 5 | 8 | 8 | 8 |
| 2 | 5 | 10 | 14 | 16 | 14 |
| 3 | 6 | 17 | 23 | 27 | 23 |
| 4 | 8 | 23 | 32 | 37 | 32 |
| 5 | 11 | 29 | 40 | 46 | 40 |
| 6 | 14 | 36 | 49 | 57 | 49 |

The first four columns are the actual per-slot rounded generator output from
`mods/ITEMS/grug_gear/init.lua:209-243,419-449`; refinement remains the existing
15% per-piece calculation (`init.lua:299-310`,
`mods/ITEMS/grug_quality/init.lua:876-883`). A shield should contribute the
same rating as the matching tier's **unrefined metal set total**. Thus shield
strength derives from the existing curve and is strong enough to define a tank
build without inventing another progression ladder.

Representative reductions (before affixes/talents):

| Defender gear | Attacker L | Rating | DR |
|---|---:|---:|---:|
| T1 cloth / leather / metal | 1 | 4 / 5 / 8 | 16.3% / 19.6% / 28.1% |
| T3 cloth / leather / metal | 30 | 6 / 17 / 23 | 14.6% / 32.7% / 39.7% |
| T3 refined metal | 30 | 27 | 43.5% |
| T3 refined metal + shield | 30 | 50 | 58.8% |
| T6 cloth / leather / metal | 60 | 14 / 36 / 49 | 21.9% / 41.9% / 49.5% |
| T6 refined cloth / leather / metal | 60 | 16 / 42 / 57 | 24.2% / 45.7% / 53.3% |
| T6 refined metal + shield | 60 / 65 / 70 | 106 | 67.9% / 53.4% / 44.0% |
| same + Ironbound 5 rating | 60 / 65 / 70 | 111 | 68.9% / 54.5% / 45.1% |

An ordinary catalog T6 non-shield plate build does not cap. A same-level
dedicated tank gets close; additional rating can cap same-level protection and
remains valuable against L65 kings and L70 dragons.

The upper bound must include authored endgame loot. At ilvl 75 the existing
per-slot curve produces metal 16/25/19/11 = 71 base rating and 18/29/22/13 =
82 refined rating. A same-curve refined shield can contribute at most 82. The
conservative pre-specialization permanent maximum is **210 rating**: 82 refined plate +
82 refined shield + 30 from one maximum +6 armor affix on each of five
armor-bearing stacks + the documented +7 mixed cultural-finish maximum
(`docs/design/items_crafting.md:2056-2065`) + 4 Stoneskin + 5 Ironbound. The separate emergency +15 is added only after
the Bulwark multiplier below. Food currently grants no armor (`grug_food/init.lua:9-43`);
Stoneskin is the existing +4 armor elixir (`grug_alchemy/recipes.lua:105-107`). The
accepted prefix-plus-suffix model prohibits repeating one stat on the same
item, so Stalwart/of the Tortoise contributes at most once per stack.

The current **Unbroken** Bulwark capstone becomes the specialization gate:

- learning the existing 21-point mutually exclusive Bulwark capstone grants a
  permanent **+40% total armor rating** (`rating * 1.40`), with no new button;
- its existing low-HP/180-second trigger retains the separate +15 rating for
  8 seconds, applied after the multiplier;
- its old 75% cap override is removed; final DR always caps at 70%.

Maximum permanent 210 rating on a damage Warrior, explicitly including the
easy five-rank Ironbound dip, gives capped 70% against L60, **69.4% against the
L65 king** and only **60.9% against the L70 dragon**. The same gear on a true
Bulwark becomes 294 rating and gives **68.5% against the dragon**; during the
Unbroken window, 309 gives **69.6%**. This is the required meaningful same-gear
DPS/tank split. Excess rating remains useful against higher attackers, while a
damage build cannot obtain the multiplier through a shallow talent dip.

Apply the multiplier to the final aggregated rating, including gear,
refinement, affixes, cultural finish, Stoneskin and Ironbound, then add the
Unbroken window's 15. Keep rating as a float until the final damage `ceil`; the
Character/Talents UI should show base raw rating, the active Bulwark multiplier,
and resulting rating so the multiplicative capstone is not opaque. Shield
refinement is explicitly included in this contract; it is not an open
implementation choice.

The tradeoff is that the post-60 K slope is intentionally sharp and Unbroken
changes from a mostly emergency capstone into the core passive tank separator.
That is still the simplest implementable model: it uses the existing exclusive
21-point commitment, preserves every raw-rating source, introduces no block
subsystem, and cannot accidentally boost a Ruin/DPS Warrior who merely spends
five points in Ironbound. Balance fixtures must therefore compare identical
gear on Ruin versus Bulwark, including the Ironbound dip, rather than comparing
different equipment sets.

Convert every current additive “armor percent” source into the same rating:

- `_grug_armor` and the existing refinement delta already are rating.
- Existing affix `_grug_armor_percent`, quality stat `armor_percent`, talent
  `armor_percent_add`, and status modifier `armor` become armor **rating** in
  player-facing text and aggregation. In fresh-server mode these metadata/API
  names may be renamed cleanly; if retained internally, document that they no
  longer mean percentage. The existing affix bands 1–2, 1–3, 2–4, 3–6 remain
  unchanged (`grug_quality/init.lua:53-54,69-85,261-273`).
- Keep one prefix plus one suffix as the Round-11 ceiling. Do not introduce a
  shield-only multiplier, block roll, armor penetration stat or class scalar.
- Adopt 70% as the hard cap. Reconcile **Unbroken** with the permanent 1.40
  total-rating multiplier plus its retained +15-rating window, remove the old
  75% override and update its text (`grug_classes/talents.lua:347-354`).

### Damage provenance and boundaries

Armor applies only to hostile punch/combat damage with an authoritative
attacker level:

- mob/NPC attacker: live entity `_grug_level` (normal mobs already persist it;
  `grug_mobs/levels.lua:417-448`);
- king: actual L65, already fixed at `grug_mobs/bosses.lua:367-373`;
- dragon: change the actual `_grug_fixed_level` from 60 to 70, not its label
  alone (`grug_mobs/boss_dragons.lua:790-805`);
- PvP: attacker's character level through `grug_core.get_player_level`;
- projectiles: stamp immutable attacker level when spawned and carry it through
  the existing owner/damage attribution. Do not recompute from the victim or
  current zone.

Fall damage continues to bypass armor and dodge, then applies Dwarf reduction
and absorb as already decided. Suffocation, drowning, lava, node/environmental
HP changes and unattributed administrative damage also ignore armor. Absorb
continues after armor. Player attacks against mobs/NPCs retain mobs_redo's
existing `armor_groups` pipeline; this proposal changes player intake only.
Friendly NPC damage, hostile NPC damage and mob projectiles use the same
attacker-level resolver rather than separate formulas.

Raising dragons to actual L70 also changes every existing level-derived input:
HP/damage fit, damage dealt by players through target-level malus, threat/XP
and boss gear roll item level. Review these consumers together; do not patch
only nametag and armor. King remains L65. The current XP reward caps effective
mob level at player level +5 (`grug_mobs/levels.lua:461-476`), so document
whether that intentional anti-power-level cap remains; no new reward exception
is needed merely for armor.

### Implementation seams and ownership

1. `grug_core/combat.lua`: publish pure `armor_k(level)` and
   `armor_reduction(raw_rating, attacker_level, cap)` and extend
   `apply_player_armor` to accept authoritative attacker level. Keep one
   rounding site. Current percentage implementation is at lines 172-200 and
   central HP modifier use near 1309-1315.
2. `grug_inventory/equipment.lua` and `grug_quality/init.lua`: expose raw
   rating, aggregate base/refinement/affix/talent/status once, refresh UI names;
   current percentage overrides are equipment.lua:518-530 and
   quality/init.lua:943-953.
3. Shield registration/equip package: six Armorsmith shields, rating derived by
   calling the shared metal-set curve rather than copying the table. Offhand is
   currently deliberately excluded from armor aggregation
   (`equipment.lua:518-526`), so add it in this package.
4. `grug_mobs`/projectiles and PvP call sites: provide attacker level explicitly.
   Do not guess level in the pure formula. Change dragon fixed level and audit
   its existing level consumers as one commit.
5. Design/UI docs: replace “1 point = 1%” and 60% statements in
   `combat_stats.md:95-128,156-173`; regenerate item, affix, talent and Character
   page wording. Existing item descriptions still print percentage directly
   (`grug_gear/init.lua:153-157`).

Focused acceptance should cover the table above, zero/negative/missing rating,
L1/L60/L65/L70, cap behavior, fractional damage rounding, PvP level, melee mob,
NPC and projectile provenance, and explicit environmental/fall bypass. A
separate balance table should show dragon HP/damage/reward before and after L70
so the level change is deliberate rather than collateral.

## Small Round-11 creature/mount briefs

### Dragon lifecycle

Confirmed bug: authored dragons use ordinary monster far-unload culling.
`mobs/api.lua:3555-3609` can serialize a terminal marker after `remove_ok` is
set; activation consumes it and removes the entity (`3632-3643`). The boss
alive flag remains 1 because only death clears it
(`grug_mobs/boss_dragons.lua:816-823`), while the spawner requires it to be
unset (`grug_mobs/bosses.lua:597-617`). Add an explicit authored-boss exemption
to far culling and mark dragons; prove save/unload/reactivate survives and real
death still schedules exactly one respawn. Merely setting `remove_ok=false`
once is insufficient because ordinary serialization sets it true again.

### Mount yaw

Movement already reads look yaw and sets controller yaw every step, including
while stationary (`grug_mounts/entity.lua:194-240,285-320`). The likely defect
is the nested render chain: controller -> attached player -> visible mesh
(`359-391`). Attached-object setters are ignored; relative rotation changes
require `set_attach` again (`reference_projects/luanti/doc/lua_api.md:8864-8875`).
Choose one visual rotation owner and update the visible child's relative attach
rotation while retaining it as a player child for first-person hiding. Exercise the transform with source/attachment regression fixtures during
implementation; first/third person, stationary/moving and a remote observer
remain explicit checks in the final user GUI playtest. Do not require an
intermediate user session before delivery. Double-yaw and camera feedback are
the main visual risks; headless checks do not prove their absence on screen.

### Stable displays

The accepted scope includes bounded walking, not an idle-only fallback. Ground
mounts walk slowly on CAP-authored safe lanes and pause; flying appearances
remain grounded and use verified idle clips. Reuse model move clips only during
actual translation. Single-frame stand clips may remain during pauses; no
invented head animation or walk-in-place loop. GAME owns throttled movement,
collision/footprint clearance, serialization and exact population; CAP supplies
safe geometry/waypoints. No combat AI, loot, flight or visible teleport reset.

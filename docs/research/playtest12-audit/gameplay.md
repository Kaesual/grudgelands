AUDIT COMPLETE

Baseline `2a308891` — Playtest 12, Lane C: combat, creatures, progression, mounts, trinkets, consumables and statuses. Static read-only audit only; no Lua, engine, KAT or runtime execution was permitted.

I found two current-rule violations (A), one missing shipped integration (B), and one unresolved design question (D). No Critical findings.

## Coverage matrix

| Area | Governing authority | Responsible consumers checked | State / check result |
|---|---|---|---|
| Player pools, damage and armor | `docs/design/combat_stats.md:45`, §2 status rules at `docs/design/combat_stats.md:168` | `mods/CORE/grug_core/combat.lua:73`, `mods/PLAYER/grug_classes/stats.lua:49`, `mods/ITEMS/grug_quality/init.lua:700` | Match: pool/class/status/gear composition, damage-only level fit, base-pool mana costs and caps follow the current formulas. |
| Environmental damage | `docs/design/combat_stats.md:198` and armor distinction | `mods/CORE/grug_core/combat.lua:1275`, `suffocation.lua` | Match for armor: only punch damage receives armor; fall, drowning, node damage and suffocation bypass it. Percentage suffocation is implemented. Fall scaling remains D01. |
| Target authority and PvP | `docs/design/combat_stats.md:245`, `docs/design/classes.md:225` | `combat_ray.lua`, swing clock, cast acquisition, projectile collision, PvP callback | Current-ray swings/casts and exact-target transactions match. Geographic/tag PvP remains explicitly open WP41. Mounted ordinary PvP has A01. |
| Mob levels, tiers and budgets | `docs/design/combat_stats.md:393`, `docs/design/biomes_mobs.md:1368` | `levels.lua`, registration wrapper and spawn rows | Central HP/damage/XP tiers and critter exceptions match. Surface-density multiplication and depth pulse are explicitly open WP37/WP34, not baseline defects. The full 40-row budget arithmetic was not re-executed. |
| Threat, roam and leash | `docs/design/combat_stats.md:643` | `combat.lua`, `aggro.lua`, mobs_redo acquisition/chase patches | Match for threat, 120% switching, 40 m validity/leash, 15 s contact and visible evade with 40 s recovery teleport. One-node-safe idle roaming is a post-baseline E change. |
| Bosses and royal groups | `audit-input/session-rulings.md:258` | `boss_dragons.lua`, `bosses.lua`, `levels.lua`, `start_npcs.lua` | 18,000 HP, moving combat states, bounded attacks/adds, and two royal guards match. Scorch combat-state integration has A02. Later dragon-idle/target-filter changes are E. |
| Statuses, food and alchemy | `docs/design/inventory_equipment.md:263`, `docs/design/items_crafting.md:988` | `status.lua`, `grug_food/init.lua`, `grug_alchemy/effects.lua`, potion cooldown | Match: one food plus one elixir, replacement behavior, combat-paused food healing, allowed modifier vocabulary, level gates and persistent potion clock. |
| Trinkets | `docs/design/items_crafting.md:1933`, R9-TRINKETS | `grug_trinkets/init.lua` and all six consumer seams | Five integrations and stacking/cooldown rules match. Apothecary Loop misses the weak vendor potion: B01. |
| Mounts | `docs/design/mounts.md:118`, ruling 37 | `grug_mounts/entity.lua`, combat refusal, damage-forwarding and lifecycle hooks | Ownership, attachment, flight legality, damage forwarding/dismount and lifecycle largely match. Ordinary PvP attack refusal is incomplete: A01. Camera/status/autostep/T1 speed are later E changes. |
| Talents and progression | `docs/design/progression.md:27`, `skill_trees.md` | `talents.lua`, `talents_ui.lua`, class selection and equipment refresh | X1/X2/X4 match: authoritative parsing, budget/gates, full respec and no class-change path. X3 effects and absorb aggregation are explicitly open. |

## Material findings

### PT12-C-A01 — Mounted riders can still use ordinary PvP attacks

**Classification:** A
**Severity:** High

**Requirement.** Ruling 37, dated 2026-09-19, says mounted players cannot trigger abilities or swings and must dismount first: `audit-input/session-rulings.md:605`. It is folded into `docs/design/mounts.md:172`.

**Implementation.** The shared mount detector/refusal exists at `mods/CORE/grug_core/combat.lua:32`, but it is called only from the authoritative swing pass at `mods/PLAYER/grug_abilities/init.lua:1319` and cast entry at `mods/PLAYER/grug_abilities/init.lua:1560`. The hostile ordinary-tool/fist PvP path begins at `mods/PLAYER/grug_abilities/init.lua:2369` and reaches proportional damage processing at `mods/PLAYER/grug_abilities/init.lua:2417` without consulting the mount state.

This does not extend to Grudgelands mobs: their ordinary raw punches are separately vetoed at `mods/ENTITIES/mobs/api.lua:2947`.

**Player outcome.** A mounted player can wield an ordinary tool or use a fist against a hostile player, deal proportional damage, mark combat and potentially earn ordinary melee resource credit without dismounting. This permits mounted pursuit and attacking at mount speed until the rider receives damage.

**Confidence / reproduction.** High static confidence; the complete callback path was followed. Not runtime-reproduced. The existing immutable combat KAT checks mounted authoritative swings and casts only at `tools/wp39/combat_integration_test.lua:511`; its ordinary PvP cases use an unmounted attacker.

**Existing tracking:** None found.

**Recommended correction and scope.** Apply the existing live-mount refusal before ordinary and neutral player-damage settlement, returning suppression before target, cadence, damage, rage or combat-state mutation. Add hostile and factionless ordinary-PvP mount cases without changing WP41 eligibility policy.

---

### PT12-C-B01 — Apothecary Loop omits the weak vendor healing potion

**Classification:** B
**Severity:** Medium

**Requirement.** Apothecary Loop increases the restored amount of instant HP/Mana potions: `docs/design/items_crafting.md:1941` and `docs/design/items_crafting.md:1954`. The vendor potion is explicitly the weak 15% instant healing potion.

**Implementation.** Crafted Healing/Mana Potions pass their amount through `grug_core.trinket_instant_potion` at `mods/ITEMS/grug_alchemy/effects.lua:27`. The weak vendor potion declares `grug_potion_instant = 1` at `mods/ENTITIES/grug_traders/potion.lua:78`, but computes 15% and calls the central heal directly at `mods/ENTITIES/grug_traders/potion.lua:115`, bypassing the trinket hook.

**Player outcome.** A T6 Apothecary Loop raises a crafted 30% potion to 34.5%, but the vendor’s weak instant potion remains 15% instead of 17.25%. The shared cooldown still applies.

**Confidence / reproduction.** High static confidence. Not runtime-reproduced. The immutable trinket KAT exercises only `grug_alchemy`’s health and mana potion closures at `tools/r9_trinkets/trinkets_kat.lua:348`; it never loads the weak vendor item.

**Existing tracking:** None found.

**Recommended correction and scope.** Route the weak potion’s unrounded amount through the same `grug_core` bridge before final rounding. Prefer coverage driven by the `grug_potion_instant` contract so future instant potions cannot silently bypass the effect.

---

### PT12-C-A02 — Dragon scorch damage does not refresh combat state

**Classification:** A
**Severity:** Medium

**Requirement.** Combat state is “dealt or received damage within the last 5 s”: `docs/design/classes.md:105`. R9-BOSS defines scorch as a dragon ground attack dealing two damage each second: `audit-input/session-rulings.md:274`.

**Implementation.** Scorch subtracts HP with `reason.type = "node_damage"` at `mods/ENTITIES/grug_mobs/boss_dragons.lua:159`. The central HP modifier refreshes combat only for `reason.type == "punch"` at `mods/CORE/grug_core/combat.lua:1275`. No explicit scorch call replaces that missing mark. By comparison, the hostile poison chain explicitly calls `mark_in_combat` after its `set_hp` tick at `mods/ENTITIES/grug_mobs/verbs.lua:239`.

**Player outcome.** Five seconds after the last punch, a player can be taking continuous dragon scorch damage while treated as out of combat. Deferred food healing and food regeneration can resume, mana uses the out-of-combat rate, Warrior rage decays, and mounting is temporarily permitted between damage ticks.

**Confidence / reproduction.** High call-chain confidence; static only. The boss KAT checks the two-HP scorch decrement but not combat state at `tools/r8_mob1/bosses_kat.lua:442`.

**Existing tracking:** None found.

**Recommended correction and scope.** Mark scorch victims in combat on its hostile tick, following the existing poison precedent. Do not broaden this automatically to unrelated environmental damage without a separate authority decision.

---

### PT12-C-D01 — Percentage-based player fall danger has no decided curve

**Classification:** D
**Severity:** Medium balance/design risk

**Authority conflict.** The Playtest 12 planning draft records a request for level-independent percentage danger but explicitly says that the curve and treatment of Dwarf reduction/absorption remain undecided and received no numbered approval: `audit-input/planning-draft.md:78`. No current design section supplies the missing formula.

**Implementation.** Engine fall damage remains absolute. The central modifier only applies the Dwarf multiplier at `mods/CORE/grug_core/combat.lua:1317`, then lets absorb soak the remainder at `mods/CORE/grug_core/combat.lua:1325`.

**Player outcome.** The same fall removes approximately the same HP at level 1 and level 60, so it becomes proportionally much less dangerous as maximum HP grows.

**Confidence / reproduction.** High static confidence; no runtime reproduction. This is not a confirmed implementation defect because the replacement rule is unresolved.

**Existing tracking:** The planning draft only; no approved WP or numbered ruling found.

**Recommended next step.** Decide the reference fall curve, maximum-HP scaling, minimum/maximum damage, and ordering with Dwarf mitigation and absorb before changing code.

## Positive matches

- Base HP/mana pools, class factors, gear/talent/status composition and damage-only scaling follow the current formulas.
- Armor is correctly limited to physical punch damage; environmental damage bypasses it.
- Crosshair-authoritative swings, hostile casts and Fireball use current aim rather than enemy-memory aim.
- Mob tiers, threat accumulation, taunt, hysteresis, leash reset and visible evade/run-home behavior follow their current owners.
- Boss tier HP is centrally fixed at 18,000 in `mods/ENTITIES/grug_mobs/levels.lua:81`; royal resolution uses only the west/east throne sockets at `mods/ENTITIES/grug_mobs/start_npcs.lua:313`.
- Status modifier vocabulary, one-food/one-elixir stacking, potion-clock persistence and combat-paused food restoration match.
- Manawell, Battlebeat, Mercy Seal, Last Light and Reclaimer follow the authored stacking, trigger and cooldown policies.
- Mount ownership, ephemeral entity lifecycle, flight boundaries, forwarded rider damage/tool wear and damage dismount were connected to their actual consumers.
- Talent storage is server-validated against class, rank, tier, chain and point budget; the Talents page is the mutation authority and class change is absent.

## C — stale documentation, not code defects

| Stale text | Later authority / actual state |
|---|---|
| Boss tier ×20 HP in `docs/design/combat_stats.md:399` | Superseded 2026-09-19 by flat 18,000 HP; code is correct. |
| Four royal guards in `docs/design/world.md:398` and `docs/design/biomes_mobs.md:1166` | Superseded by R9-BOSS’s exactly two guards; code is correct. |
| Stationary/perch-only dragons in `docs/design/world.md:593` | Superseded by R9-BOSS’s walking/flying combat behavior. |
| Talent trees described as merely proposed in `docs/design/progression.md:20` | Superseded by the 2026-09-16 rulings and shipped X1/X2/X4 work. |
| Percentage mana regeneration in `docs/design/classes.md:96` | Superseded by `docs/design/combat_stats.md:796`; implementation uses the later absolute formula. |
| T1 mount speed 6 in `docs/design/mounts.md:41` | Superseded on 2026-09-20 by ruling 55; the baseline predates that ruling. |

## E — known open work or post-baseline decisions

| Item | Classification reason |
|---|---|
| Ground mobs/NPCs may idle into drops deeper than one node | Safe free roaming was newly decided in ruling 52 after baseline export. |
| Dragon gust runs without a target; idle perch changes teleport every 15 s; dragon custom AoE/projectiles omit `peaceful_player` | All three are addressed by post-baseline ruling 53. They are not historical baseline defects under the prior R9-BOSS wording. |
| Mount mesh can obstruct first-person view; no mounted status; entity has default zero stepheight; T1 speed remains 6 | Rulings 54–55 were approved after this baseline. |
| Named absorb contributions/stacking and remaining keystone/capstone effects | WP11 X3 is explicitly open in `BACKLOG.md:34`. |
| Surface spawn chance ×0.75 and depth phase-in pulse | Explicit WP37/WP34 open work; design documents already label the shipped difference. |
| Natural out-of-combat HP regeneration | Explicit WP21 open work. |
| Geographic PvP eligibility/tag, target-race effects and PvP death XP exemption | WP41 and WP9 remain open; current faction/global-PvP behavior is documented as interim. |
| Scout, bows and other named future class content | Outside shipped scope, not missing baseline behavior. |

## Limits

This is not a claim of full-game conformance. I did not execute existing KATs, regenerate spawn-budget evidence, inspect runtime camera/collision behavior, visually audit meshes/textures, or reproduce combat in Luanti. Craft/refinement provenance belongs to Lane A; world geometry and zone generation belong to Lane B and were excluded except where mount flight queries consume them.

## Prioritized discussion questions

1. Should PT12-C-A01 be corrected as a narrow mounted-PvP gate immediately, or scheduled with WP41 while preserving ruling 37 unchanged?
2. For PT12-C-A02, should combat marking be added only to known hostile periodic effects such as scorch/poison, or should a source-aware central periodic-damage seam be designed?
3. Should the Apothecary correction dispatch through the existing `grug_potion_instant` group so every instant potion shares one integration boundary?
4. What exact maximum-HP fall-damage curve, cap/floor and Dwarf/absorb ordering should resolve PT12-C-D01?
5. Should the ruling 52–55 changes remain one coordinated post-playtest package, given that dragon targeting, safe roaming and mount visibility/stepping each require separate runtime checks?

---
Archived from the independent audit; local source links and whitespace were normalized to
portable path citations. Baseline line numbers refer to `2a308891`.
Coordinator dispositions in [README.md](README.md) govern the combined inventory.

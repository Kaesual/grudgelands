> Review record, 2026-10-12: independent read-only engineering review of the
> class redesign package as it stood that day. Code line numbers refer to main
> at 0e6b3061. The adopted simplifications are in
> [the continuation plan](../continuation.md#4-adopted-simplifications).

# Class redesign — engineering review (implementation complexity and simplifications)

Read-only review of `docs/design/ability_targeting.md` and `docs/planning/class-redesign/*` (implementation-design first), with the handoff §3 approvals as fixed. Code read: `grug_abilities` (init, input, kits, scout, crosshair, strike_delay), `grug_classes/talents.lua`, `grug_projectiles`, `grug_core` (combat, combat_ray, homing, status, movement, particles), `grug_mobs` telegraph and dragon lightning. No fixtures or engine runs: nothing was changed.

## Summary

**Overall: large.** This is the biggest gameplay change since WP38/39. It reverses two shipped core principles: classes.md:35 "Instant abilities + cooldowns, no cast times" and classes.md:54 "No global cooldown". It also replaces the talent model and roughly 45 ability definitions. About two thirds of the ~110 talent nodes are plain number modifiers that the existing data-driven talent vocabulary already handles. A small set of shared mechanisms drives the real cost. If those are built **once, before any class work**, each class becomes mostly data plus small effect code. If each class lane builds them itself, there will be four competing input implementations in `input.lua` (implementation-design §9 already warns about this).

**Top three cost drivers:**
1. **Cast lifecycle in the one input machine:** preparation, occupied action time, release-time revalidation, cancellation, Arrowfall's 4-release channel, and the Scout LMB/RMB remap. `try_cast` is atomic today and has to be split. `input.lua` is 825 lines of timing-sensitive code.
2. **Area targeting:** live preview, the per-column surface/air footprint, cover rules, and delayed or pulsed settlement at a fixed anchor (Meteor, Fire Rain, Winter Field, Censure).
3. **Talent graph replacement:** the data model, validator, UI, migration/refund and starter re-grant. On top of that comes the volume: ~45 ability defs and tooltips, and the ~40 tool fixtures that pin the current kits.

A hidden fourth driver: Parry, Retort and Ice Armor need **hit classification** (direct vs area/periodic, melee vs projectile, dodged or absorbed). The incoming-damage seam does not carry it.

## Shared primitives (build once; the table below refers to them)

| Id | Primitive | What exists to build on | New work |
|---|---|---|---|
| P1 | **Action clock:** one per-player "next action ready" time. Every committed cast, swing and release pushes it by its occupied time. | `strike_delay.lua:2-10` already does "Shared successful-action boundary; never shorten an existing melee deadline" for casts and released arrows (`init.lua:2440-2442`, `input.lua:205`). Swing deadline `swing_progress.next_due`; the lateness carry `SWING_CATCHUP` is at `init.lua:1107,1336`. | Generalize to per-def `occupy`. Read it in `cast_refusal` (`init.lua:1449`) and in the swing pass. **M** |
| P2 | **Prepared cast / channel:** 1..n releases, a captured recipient/anchor/target, cancel rules, stance, ring cue. | Bow draw lifecycle in `scout.lua`: start 402, release 435, clear 338, 0.05 s loop 492, stun/death/leave/equipment cleanup 521-545, move stance, repair receipt. Ring owner in `crosshair.lua:46,196`. | Split `try_cast` (validate → `def.cast` → `spend` → cooldown, `init.lua:1512-1526`) into begin and commit. Generalize the draw table into a channel owner. **M–L** |
| P3 | **Area query:** circle/cone/arc, vertical band, LOS from an origin, filter, cap and deterministic order. | Sphere loops in Nova (`kits.lua:660`), Cinderfall (1050), Mighty Blow cleave (374), Taunt radius (452), Heal splash (844). Horizontal cone plus LOS: `telegraph.lua:36,113-131`. Node-only LOS lock: `homing.lua:70-80`. | One function used by about 14 skills, previews included. **M** (**L/R** with the per-column footprint) |
| P4 | **Delayed/pulsed area at a fixed anchor:** warning, N pulses, re-resolve recipients per pulse. | Dragon lightning: snapshot position, wind-up ring, delayed horizontal-radius impact (`boss_dragons.lua:593-609, 711-720`; effect `particle_effects.lua:378`). | Runtime scheduler table plus cleanup. **S–M** |
| P5 | **Readiness window:** a timed charge consumed by the next qualifying attack, with ICD and status icon. | Talent windows plus status icon (`talents.lua:994-1035`), `set_status` (`status.lua:100`), swing procs (`kits.lua:342-394`, `scout.lua:646`). | Key windows by an arbitrary id rather than only a talent. Use the runtime mono clock instead of `os.time()` meta (`talents.lua:1042-1048`, 1 s resolution, persisted). **S** |
| P6 | **Incoming-hit classification hook:** fires for dodged, absorbed and landed hits and says direct/area/periodic, melee/projectile. | One hp-change modifier with dodge, armor, absorb in order (`combat.lua:1543-1683`). The ability dodge pre-roll is a second dodge site (`combat.lua:1234`). `register_on_settled_incoming_hit` skips dodged and fully absorbed hits (`combat.lua:1400, 1688-1693`). | Tag the non-direct damage sources. Every mob damage path arrives as `reason.type == "punch"` from the mob object: telegraph cone `telegraph.lua:134`, boss and dragon areas `bosses.lua:340`, `boss_dragons.lua:383,603,767`, auras and poison `verbs.lua:626,835`. **M/R** |
| P7 | **Transformation:** `replaces = <id>` substitution in place, with a shared cooldown key. | `normalize_kit` (`init.lua:1993-2016`). Cooldowns are keyed by `def.id` (`init.lua:1013-1027`). | Substitution plus a `cooldown_key`. Per-layout dedupe once A/B exists; today's `have[def.id]` is global. **S–M** |
| P8 | **Graph talent registry:** per-node gate, multi-parent prerequisites, data-driven modifiers. | Effect-key vocabulary plus pre-summed `get_talent_bonus` (`talents.lua:49-115, 1066-1084`). Validating parse (`talents.lua:877-958`). | The registry is hard-wired to two chains and four tiers with "hard chain" gates (`talents.lua:28-31, 220-267, 825-857`). The UI is chain/tier columns (`talents_ui.lua:209-224`). Both need a rewrite. **L** |
| P9 | **Projectile at an explicit target:** for Split Shot secondaries and Arrowfall follow-ups. | `spawn_batch` with an atomic commit callback (`grug_projectiles/init.lua:305-345`). `actor_projectile_lock` = range plus terrain LOS plus lock (`homing.lua:70-80`). | `spawn_one` always re-acquires through the crosshair (`grug_projectiles/init.lua:217-222`), so it needs a `target=` variant. **S** |
| P10 | **Actual-HP settlement receipt:** for Word of Ruin, Recover and Close Dance consumption. | `deal_ability_damage` returns the pre-mitigation `amount` (`combat.lua:1314`). `hp_before` exists for players (`combat.lua:1276`). Mob subtraction is the floored damage, overkill included (`grug_mobs/init.lua:344-352`). | Return `min(dealt, hp_before)` for both. **S** |

## Mechanic table

S/M/L = small/medium/large, R = risky.

| Mechanic | Class | Reuse (file:line) | New work | Rating |
|---|---|---|---|---|
| Fiery Spark (free projectile, 1 s) | Mage | Fireball projectile and `cast_interval` (`kits.lua:496-618`, `init.lua:973-995`) | New def; P1 | S |
| Cold Spark (transform, slow on hit) | Mage | Slow on settled hit (`scout.lua:135-150` pending_control pattern); `grug_mobs.slow` | P7 | S |
| Fireball as a separate paid skill, splash with cover | Mage | Existing def; splash loop `kits.lua:526-535` | Cooldown/cost change; LOS from impact via P3 | S |
| Afterglow burn on mobs | Mage | Mend tick loop `kits.lua:970-998` is players only | **No mob DoT exists**; new per-target table | M |
| Flame Lance (1.25 s prepared, movement cancels) | Mage | P2 | Movement-cancel rule (ambiguity A2) | S given P2 |
| Ice Wave (70° cone, slow) | Mage | Cone plus LOS `telegraph.lua:36,113-131`; `grug_mobs.slow` | P3 | S |
| Ice Nova (transform, 0.65D, breakable root) | Mage | `kits.lua:629-689`; root breaks on damage `grug_mobs/init.lua:487-510`, `movement.lua:458` | P7 plus numbers | S |
| Cold Shock (Nova empowers next Spark) | Mage | P5 | — | S |
| Blink | Mage | Unchanged `kits.lua:691-735` | — | S |
| Ice Armor (+0.20K, reactive slow on melee attacker) | Mage | `set_status` armor modifier, consumed at `equipment.lua:845` and `grug_quality/init.lua:1098` | Reactive part needs P6 (melee vs projectile) | M (R via P6) |
| Meteor / Fire Rain / Winter Field (preview, fixed anchor, pulses) | Mage | Cinderfall anchor from ray `kits.lua:1038-1043`; dragon lightning P4 | P3+P4 plus preview; Winter Field slow re-applied per pulse | L (R with per-column) |
| Strike/Charge starters, Charge 0.75 s stun, Halt, Reach the Fight | Warrior | `kits.lua:275-331`, `charge.lua` | Numbers; Halt is a post-stun slow | S |
| Retort (Strike transform, ready on hit or dodge) | Warrior | Swing proc model `init.lua:1145-1238`; Mighty Blow proc `kits.lua:342-394` | P5+P6+P7. Strike is `universal` and `register_ability` asserts class XOR universal (`init.lua:775-776`), so a per-class basic is needed | M |
| Recover (heal from actual HP removed) | Warrior | `heal_player` no_crit | P10 on the swing result | S–M |
| Hold Ground (5 s absorb, no immunity) | Warrior | `kits.lua:1013-1030`, `add_absorb` | Numbers; drop move immunity | S |
| Taunt → Bellow | Warrior | `kits.lua:436-478` (taunt_radius) | P7 | S |
| Unbroken (active armor plus absorb) | Warrior | `set_status` armor, `add_absorb` | Remove passive proc `talents.lua:1108-1127` | S |
| Mighty Blow → Broadstroke (100° arc, max 2, LOS, no crit/rage/proc) | Warrior | Cleave loop `kits.lua:373-380` (sphere, all targets, no LOS) | P3; no-crit flag in `deal_ability_damage` | S–M |
| Hamstring (8 s proc cooldown) | Warrior | `kits.lua:396-434`, charge timers `init.lua:1051-1083` | Numbers | S |
| Ruination (active 8 s window) | Warrior | Window exists (`kits.lua:381`) | Active self cast plus P5 | S |
| Self-cast 0.35 s recovery "preserving" the swing timer | Warrior | strike_delay | P1 rule (ambiguity A9) | M |
| Smite (free, 1 s) / Rebuke | Priest | `kits.lua:737-800` | Numbers; P1 | S |
| Heal (1.5 s, retained recipient, no self fallback at release) | Priest | `resolve_friendly_target` `kits.lua:94-104` | P2 plus actor-to-actor LOS helper (A5) plus recipient name cue | M |
| Shield / Mend (same-caster replace) | Priest | `kits.lua:864-998`; mends keyed per target only (`kits.lua:950`) | Key per caster and target | S |
| Hearten / Haven (automatic party, prepared) | Priest | `grug_parties.view` (`grug_parties/init.lua:120`); Heal splash loop `kits.lua:844-857` | Filter, sort, cap (P3) plus P2 | M |
| Word of Ruin (0.75 s, recovery capped by actual HP) | Priest | `kits.lua:1078-1112` (uses pre-mitigation `dealt`) | P2+P10 | M |
| Censure (fixed area, 4 nearest) | Priest | Same as Meteor | P2+P3+P4 | M (shares Mage cost) |
| Final Word | Priest | — | P2 | S |
| Clear Conscience / Shelter / Hard Faith / support no-crit | Priest | P5; status armor; `heal_player` no_crit | Per-call crit add/no-crit option in `deal_ability_damage` (crit rolled centrally at `combat.lua:1242`) | S each |
| Loose: LMB quick shot, hold repeats | Scout | Fireball-style held hostile cast in `input.lua:388-401`; arrow `launch` `scout.lua:194-264` | Drop the draw, the special-casing at `input.lua:179-181, 228-229` and the RMB bow branch `input.lua:296-299, 695-706` | M |
| Loose RMB = melee on a hostile in reach | Scout | Authoritative swing is LMB/dig-driven | RMB must synthesize a swing and arbitrate interaction, food, pickup and entity `on_rightclick` (`input.lua:274-303, 780-791`) | **R** |
| Bladecraft (LMB melee, RMB bow) | Scout | **This is today's Loose mapping** ("LMB: melee Strike… Hold RMB to draw", `scout.lua:553`) | Transform plus quick RMB shot | S–M |
| Scout shared offensive recovery across bow and blade | Scout | strike_delay | P1 vs the swing clock | M/R |
| Aimed Shot (0.75 s, stance) / Snare (0.18 s) | Scout | `set_move_stance` (`movement.lua:308`), `launch` | P2; 0.18 s is about two server steps | S |
| Split Shot (nearest legal secondaries, arrows per recipient) | Scout | `spawn_batch` plus `consume_ammo` commit (`scout.lua:243-252`) | P3+P9; tie-break via `ObjectRef:get_guid()` (lua_api.md:9050, engine ≥5.13) | M |
| Arrowfall (4 releases, single acquisition, facing cone, per-release payment) | Scout | Bow channel pattern; P9 | P2 multi-release, scheduler, installment ceil math (trivial) | M–L |
| Opening (Parry-empowered, rear 120°) | Scout | `behind_target` `scout.lua:621`, proc `scout.lua:646-670` | P5; widen rear test from 180° to 120° | S |
| Parry (−40% after armor, before absorb; dodge consumes) | Scout | Exact insertion point exists between armor (`combat.lua:1578`) and absorb (`combat.lua:1639`) | P6 at both dodge sites | M/R |
| Flourish (90° cone, 3 targets) | Scout | Cone pattern | P3 (+P2 0.25 s) | S |
| Close Dance (3 charges, first-hit −30%) | Scout | P5, P6, P10 | — | M |
| Sidestep / Shake Loose / Quiver / Light Step / Travel Worn | Scout | `start_sidestep` (`grug_classes/scout.lua:20-33`), `clear_negative_move_modifiers`, `arrow_refund_chance` | Numbers | S |
| Strongest-only hostile slow | All | Aggregator sums speeds (`movement.lua:156-166`) | Max instead of sum for negative entries | S (balance-wide effect) |
| Repeated-root diminishing returns | All | — | New per-target immunity window | S–M, defer |
| ~70 pure modifier talents | All | `EFFECT_KEYS` plus `get_talent_bonus` | Data rows (see simplification 5) | S each, M total |
| Talent graph, UI line art, migration | All | Validating parse; `tools/migration/steps/v0_44_0.py` already removes skill items | P8; generator; step file plus end-to-end test | L |
| Area preview (caster-only) | Mage/Priest | Crosshair refresh at 0.15 s per player (`init.lua:2275-2294`) | Private particles: `particles.lua:21` says "Nothing passes `playername`", so a private path or `image_waypoint` HUD is new | M |
| Readiness and recipient cues | All | Status icon row; ring owners | P5; one HUD text for the Heal recipient | S |
| Hotbar A/B (handoff §3.2) | All | `storage.lua` lists, `normalize_kit` | Not class work; see Planning | L |

## Simplification proposals, ranked by savings

1. **Replace the per-column surface/air footprint with "horizontal radius + vertical band ±H + node-only LOS from a point just above the anchor".** Use it for settlement and preview alike. The preview is a rim of ~12–16 samples, each snapped to the nearest standable y within ±H, plus a centre mark.
   - **Saves** the largest unfrozen spec (eligible cells, partial nodes, liquids, one cell per column, tie rules, footpoint mapping), a 50–80-column builder per preview refresh, and the class of "preview and damage chose different floors" bugs. The LOS rule alone already guarantees "no damage through floors/walls".
   - **Design cost:** no per-column visualisation of gaps or pits. An actor in a hole within ±H but out of sight of the anchor point is spared, which reads as cover. Note that the current budget cannot show per-column gaps anyway: R=4 is ~50 columns against "24 live preview particles".
2. **One action clock (P1) and one channel owner (P2) for all four classes**, parametrised per ability (`prep`, `occupy`, `releases`, `stance`, `cancel_on_move`), instead of the four class timing prose rules. Drop sub-step preparations: Loose and Snare 0.18 s, Flourish 0.25 s. They become instant with their occupy time.
   - **Saves** four bespoke timing models, a large share of the input-machine test matrix, and the 0.09 s server-step jitter on 0.18 s windows (≈50% error).
   - **Design cost:** Warrior's "recovery preserves the swing timer" and Scout's "defense adds 0.25 s to next offensive-ready" become one uniform rule: every action pushes the clock by its occupy time. Snare loses an invisible 0.18 s tell.
3. **Scout controls: keep today's dual mapping as Bladecraft and make Loose a plain LMB bow cast.** Bladecraft = LMB melee, RMB bow (exists, `scout.lua:553`). Loose = cast with a 0.85 s interval, held LMB repeats like Fireball. **Drop "Loose RMB = melee".**
   - **Saves** the one risky input change (RMB as an attack versus interaction, food, pickup and entity `on_rightclick`) and deletes the draw machinery (~300 lines of `scout.lua`) and its native-RMB renew logic.
   - **Design cost:** a Quarry Scout with an empty quiver or a closing enemy switches to Strike, which remains an entitlement. That can make Strike a 6th slot for some players.
4. **Hit classification by exception (P6):** treat every hostile punch as "direct" unless the source is tagged area or periodic. Tag ~8 known sites: telegraph cone, boss shatter and cleave, dragon breath, lightning and slam, damage auras, poison, scorch.
   - **Saves** a full damage-source taxonomy.
   - **Design cost:** an untagged future area attack would trigger Parry, Retort or Ice Armor until someone tags it. Melee vs projectile (Ice Armor) still needs a mob-arrow tag, or the rule simplifies to "any direct hit": the attacker gets slowed even by arrows.
5. **Data-driven modifier talents:** parametrised effect keys (`damage_pct:<tag>`, `cost_pct:<tag>`, `cooldown_sub:<id>`, `radius_add:<id>`, `duration_add:<id>`, `range_add:<tag>`), applied by one ability-parameter pipeline from per-ability base tables (coefficient, cost %, cooldown, radius, duration, range, tags fire/frost/bow/blade/paid/support).
   - **Saves** ~60 bespoke consumer sites and the "one key, one read site" bookkeeping (`talents.lua:49-115`).
   - **No design cost.** It keeps the level-proof rule because coefficients are D/S/R/M- or P/K-relative.
6. **Readiness via status icons (P5)** for Retort, Cold Shock, Clear Conscience, Follow the Line, Parry guard, Opening-ready, Close Dance and Ruination. Add at most one crosshair "empowered" tint later.
   - **Saves** new HUD elements per mechanic.
   - **Design cost:** the cue sits in the peripheral icon row rather than at the crosshair.
7. **Cut or defer low-identity bespoke mechanics:**
   - Afterglow, the only mob DoT: replace with a Fireball damage rank. Costs Ember a burn flavour.
   - Shelter, armor while the own Shield lasts: fold into the Warding Faith amount. Small loss.
   - Halt, the post-stun slow: keep, it is small.
   - Winter Field's 0.5 s lingering: becomes the slow re-applied each 1 s pulse with ≤1 s linger.
   - Repeated-root diminishing returns: defer.
   - Talent line-art PNG (handoff §6, an approved direction): defer one round and ship the graph in an adapted `layout_tree`.

   Costs are listed per item; none touches class identity.
8. **Arrowfall scheduling rule:** at most one release per input pass at the first pass ≥ its scheduled time, scheduled from the first release, never a catch-up burst.
   - **Saves** the open "step spans two releases" question.
   - **Design cost:** under lag the volley stretches by up to one step per arrow.

## Planning, dependency and migration risks

- **Sequence.** Lane split in §9 step 3 is right in principle, but needs one more step and an explicit serial foundation. Every class touches `kits.lua` (all four classes in one 1115-line file), `talents.lua` (all trees inline, 1370 lines), `particle_effects.lua`, `status_icons.lua`, `CAST_SOUNDS` and skill icons.
  - Plan a **mechanical pre-split** (compatible): `kits/<class>.lua` and `talents/<class>.lua`.
  - Then a **serial foundation lane**: P1–P10, the P8 registry and validator, the area preview.
  - Only then four class lanes in parallel, then UI/tooltips/web_data, then migration.
  - **Realistically two rounds:** foundation plus Mage/Warrior, then Priest/Scout plus UI plus migration.
- **Hotbar A/B is an independent large package.** It touches inventory lists, sort exclusion, consumption order including ammo, give exclusion, two dropdowns, cooldown overlay, and Loose's stack lookup in `main` (`scout.lua:325, 357`). Land it in its own lane. The class lanes should call a "representation lists" API (`init.lua:932-942`) so that per-layout dedupe arrives in one place. Otherwise `normalize_kit` changes twice.
- **Migration.**
  - **The risk:** new trees **reuse old talent ids** (`hold_ground`, `unbroken`, `bellow`, `broadstroke`, `ruination`, `hamstring`, `heavy_hand`, `stoke`, `keen_edge`, `onset`, `ironbound`, `weathered`, `mend`, `hearten`, `gentle_hand`, `warding_faith`, `deep_reserve`, `sharpened_word`, `hard_faith`, `word_of_ruin`, `far_cast`, `quick_step`). The validating parse drops only unknown ids (`talents.lua:877-958`), so reused ids would be **silently reinterpreted** under new gates.
  - **The step:** declare `migrate` with a step that clears `grug_classes:talents`, every `grug_classes:talent_ready:*`, `grug_classes:unbroken_ready` and retired skill items. The `v0_44_0.py` skill-item pattern exists. Add an end-to-end test (`tools/r44_ms`/`r45_ms` pattern) on a world with talented characters of all four classes.
  - **Starters for existing characters:** existing characters have `META_INITIAL_KIT=1` (`init.lua:2051-2077`). A Mage or Priest who loses Strike gets no Spark/Smite on the hotbar under "no auto-placement" and cannot attack until visiting the catalogue. The online handler must place the new basics, or the user must rule (TODO "initial starter placement").
  - **Retired ability ids** (sprint, cinderfall, glacial_ward, pinning_shot, Strike for Mage/Priest) need the offline removal, or stay registered as retired defs so `normalize_kit` drops them. Unregistered names would remain as unknown items.
- **Cooldown keys under transformation.** Nova (18 s) replaces Ice Wave (12 s) and Broadstroke replaces Mighty Blow under different ids. Without a shared `cooldown_key` (P7), a transform bought mid-cooldown resets it, which the handoff forbids.
- **Performance.**
  - Previews are per player in the 0.15 s crosshair pass: one ray plus ≤16 snapped samples. That is cheap, and private particles only load the caster's own client.
  - The real particle risk is committed telegraphs and pulses for many casters. Singles live ≤3 s (`particles.lua:71`) and spawners ≤1 s, so Fire Rain and Winter Field markers must re-emit per pulse.
  - The preview budget in implementation-design §6 is internally inconsistent: "at most 24 live preview particles per caster with lifetime at most 0.3 s … initially 5 Hz" gives ~36 live.
  - Combat-path change: report the PvE micro run before and after (`tools/r31_pvp/run.sh`, AGENTS).
- **Test strategy gaps.**
  - The ~40 tool files that pin current kits need a retire/rewrite list in the brief. Counts of tool files mentioning the id: fireball 12, charge 17, blink 17, opening 13, sprint 10, start_bow_draw 4.
  - Channels need a fake monotonic clock in portable fixtures.
  - The particle catalogue check (`tools/r40_px`) needs new budget rows.
  - New skill icons: `register_ability` hard-wires `grug_abilities_skill_<id>.png` (`init.lua:836`), so ~30 new abilities need placeholder textures before any art round.
  - The `web_data.json` export must be regenerated.
  - The desktop/web GUI checklist must include preview legibility and RMB behaviour.
- **Live world.** There is only one production world, but every character's talents reset. The refund is free (points derive from level), so the only user-visible loss is hotbar layout. That is acceptable, but needs the starter placement above.

## Ambiguities to settle before an implementation brief

- **A1 Prepared-cast gesture.** Press starts and completes automatically, or hold-to-channel? How does it interact with skill items' gather/dig mode and the 0.35 s tap window at nodes (`input.lua:16, 433-442`)? A prepared Heal aimed at the ground would currently start only on release.
- **A2 "Movement cancels".** Movement keys, position delta, or external displacement (knockback, falling, jump)? The server only sees controls every ~0.09 s.
- **A3 Anchor definition.** "Enemy footpoint" for airborne or mounted actors and dragons. "Eligible terrain" when `combat_ray` passes non-walkable nodes (plants, water) (`input.lua:240-242`).
- **A4 Preview.** Budget arithmetic (above). Whether gaps must be shown at all (see simplification 1). Representation: private particles versus `image_waypoint`. The web client's support for both is unverified.
- **A5 "Visible from caster"** for Heal at release, party members, Split Shot secondaries and Arrowfall. Which ray (eye to centre, node-only walkable, as in `homing.lua:73-79`)? Do other actors block?
- **A6 Hit taxonomy** for Parry, Retort, Ice Armor and Close Dance: which mob sources count as direct, melee or projectile (P6). Absorbed melee triggering Ice Armor is already listed as open.
- **A7 Arrowfall timing.** Release schedule under step jitter (simplification 8). Facing cone horizontal or 3D. Range from eye to target centre.
- **A8 Split Shot.** Distance measured from the primary's position at release. Tie-break: `get_guid()` requires engine ≥5.13 on the production server (verify); player names for players.
- **A9 Action clock versus swing clock.** Is "occupied time" the same deadline as `swing_progress.next_due`? strike_delay today pushes it by the **full weapon interval** after any cast. That contradicts Warrior's "0.35 s recovery … preserve rather than reset the swing timer" and Mage/Priest's 1 s.
- **A10 Cancelled preparation.** "Already reserved preparation time remains occupied": the elapsed part, or the whole reserved duration?
- **A11 Slot scrolling.** Does scrolling the hotbar (needed to reach Opening after Parry) cancel a preparation or channel ("a new skill request cancels")? Or only an activation of another skill?
- **A12 Universal Strike.** Becomes per-class: not granted to Mage/Priest, replaced by Retort for Warrior, optional for Scout. This needs a registration rule (`init.lua:775-776`).

## Notes (theoretical, no escalation)

- `talent_trigger_ready` uses `os.time()` seconds persisted in meta (`talents.lua:1042-1048`). That is fine for 60 s ICDs, coarse for Retort's 6 s.
- `ability_targeting.md` §4 requires no client mod. Nothing in the contract needs one. The only feature that depends on undocumented client behaviour is RMB-on-hostile (simplification 3).
- Homing projectiles ignore new cover after launch (`homing.lua:44-67`). The mage.md correction row matches the code.

Fixtures run: none. This is a read-only review with no code change; no Luanti started.

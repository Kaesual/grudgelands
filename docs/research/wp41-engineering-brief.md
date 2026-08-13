# WP41 Geographic PvP — Engineering Brief

Status: **Implementation-ready engineering contract, authored 2026-08-13
(post-WP40 planning pass); not an implementation or shipped-WP claim.**

This brief freezes how WP41 implements the decided PvP design. The design
itself is closed and is not reopened here: the authoritative rules are
[`world_zones.md`](../design/world_zones.md) §§4/15 (voluntary flagging, the
four-row transaction, support/refresh, AoE/projectile/boundary semantics,
lifecycle/visibility) and [`world.md`](../design/world.md) §2c. The BACKLOG
WP41 row is the acceptance contract. Engine claims below cite the pinned
`reference_projects/luanti` checkout (`df04879`); combat-pipeline claims cite
the shipped WP38/WP39 contracts recorded in AGENTS.md and
`docs/design/classes.md` §2b / `combat_stats.md` §2.

## 1. Single authority: `grug_pvp`

- One new mod **`mods/PLAYER/grug_pvp`** with exactly one global table
  `grug_pvp`. Dependencies: `grug_core`, `grug_factions`; a hard startup
  requirement on the WP40 zone API (`grug_zones` or its `grug_core`
  compatibility adapters — whichever name ships, resolved once at load).
- `grug_pvp` is the **only** reader and writer of PvP state. No combat path,
  quest, UI or later WP reads the player-meta key, evaluates zone PvP
  geography for eligibility, or implements a private geographic exception
  (`world_zones.md` §4 last bullet).
- `grug_pvp` owns: per-player PvP state and persistence, the eligibility
  transaction, tag/refresh rules, death/reconnect lifecycle, the HUD states,
  the attributable-effect death-cleanup registry, the PvP event bus and the
  bypass backstop. It does **not** own damage math (armor/dodge/absorb stay
  in `grug_core/combat.lua`), threat, XP consequences, quests, guards or
  war-front content.

### 1.1 State model

- Persistent: `pvp_expiry` — one absolute wall-clock timestamp (`os.time()`
  seconds) in player meta, written only through `grug_pvp`. Offline time
  counts down by construction; disconnect never clears it
  (`world_zones.md` §15.4).
- Derived, never persisted: `contested(player)` — the result of
  `pvp_rule_at(player pos)` == `"contested"`; recomputed synchronously
  inside every transaction and on the shared ticker for HUD. One
  in-memory `last_rule` per online player carries the previous
  observation for §2's synchronous leave-contested tail; it is seeded
  from the current position at join and never persisted.
- `tagged(player)` := `contested(player) or now < pvp_expiry`. There is no
  separate boolean flag that could desynchronize from the timestamp.
- Death sets `pvp_expiry = 0` and runs the attributable-effect cleanup
  (§4.7). Reconnect restores the persisted expiry; joining inside contested
  ground forces the tag again by the derivation above.
- Meta writes are transition-writes only: a refresh writes the key only when
  the new expiry differs by ≥ 1 s from the stored value.

### 1.2 Geography input (WP40 API, consumed, never reinterpreted)

- `pvp_rule_at(pos)` → `peaceful` / `contested` / `outside` is the only
  geographic PvP input. Its precedence (y ≤ −701 contested override,
  Holy/island contested, peaceful zone water/shelf inheritance, deep
  ocean/channel `outside`) is WP40's contract
  (`wp40-engineering-brief.md` §5.3) and is not re-evaluated by WP41.
- `faction_at`, `territory_rule_at` and anchor lookups are **not** PvP
  eligibility inputs. Enemy identity comes from `grug_factions`
  (`get_faction` + `grug_core.opposing_faction`); geography comes from
  `pvp_rule_at`; the two never substitute for each other.
- `outside` (deep ocean / dragon channel) positions use the four-row
  peaceful-zone table and never force the tag — the rule decided
  2026-08-13 and recorded in `world_zones.md` §15.1. The contested islands
  and shores force it on arrival as usual. WP41 consumes this rule; it
  does not interpret geography.

## 2. The atomic transaction

Every hostile attempt resolves in one synchronous sequence with no yield,
timer or deferred step between (a) and (f). "Hostile attempt" means a
server-validated contact with an enemy player or a protected enemy-faction
combatant/object (`world_zones.md` §15.1 header); clicking air, missing the
authoritative ray, a filtered ally or an invalid/out-of-range target calls
nothing here.

For `grug_pvp.hostile_attempt(attacker, target, context)` with a player
target:

- **(a) Geography snapshot.** Read `pvp_rule_at` for both **current**
  positions at this instant (§15.3: eligibility is resolved at the instant
  each target would receive an effect, using both current positions; the
  launch zone grants no future damage).
- **(b) Contested forcing.** For each of the two players standing in
  contested ground, ensure the tag (idempotent). This happens **before**
  the table is evaluated (§15.1).
- **(c) State snapshot.** Record `attacker_before` / `target_before`
  (safe/tagged) after (b).
- **(d) Four-row table** (verbatim §15.1):

  | Attacker before | Target before | Result |
  |---|---|---|
  | safe | safe | attacker becomes tagged; effect **blocked**; target stays safe |
  | safe | tagged | attacker becomes tagged before resolution; effect may land |
  | tagged | safe | effect **blocked**; target stays safe |
  | tagged | tagged | effect may land |

  Tagging the attacker in rows 1–2 writes the 60-second expiry only when
  the attacker is outside contested ground (inside it the tag is already
  forced and the expiry is display-irrelevant until they leave).
- **(e) Outcome record.** The call returns one of three outcomes —
  `blocked`, `eligible`, or `invalid` (not an enemy player / not a valid
  hostile contact; nothing was tagged). The caller maps `blocked` onto its
  path's decided cost semantics: a valid blocked swing consumes weapon
  cadence as a **combat miss** but pays no landed-hit proc, rage or on-hit
  effect; a launched cast/projectile keeps its ordinary launch cost while
  target-dependent settlement effects do not run (§15.1). WP39's
  aim-miss/combat-miss vocabulary is reused, not duplicated: `blocked` is a
  combat miss by definition.
- **(f) Resolution and refresh.** Only `eligible` proceeds into the
  existing damage pipeline (full-swing build, crit,
  `grug_core.apply_player_armor`, dodge, absorb — unchanged WP38/WP39
  order). When a commit actually lowers HP or consumes ≥ 1 absorb, the
  path calls `grug_pvp.damage_committed(attacker, target, hp_loss,
  absorb_loss)`, which refreshes **both** participants (§15.2). Miss,
  dodge, immunity, eligibility refusal and zero post-mitigation damage
  refresh nothing.

Support is the mirror transaction:
`grug_pvp.support_contact(helper, target, context)` runs (a)–(c) on the
**ally** pair, and iff the support was effective (restored HP, added
absorb, removed a harmful PvP effect, or applied a combat-relevant buff)
on a **tagged** ally, it tags the helper and refreshes both (§15.2).
Failed, rejected or zero-effect support calls must not be reported as
effective by the caller; periodic effective ticks repeat the contact while
the source is online and attributable.

Boundary tail: leaving contested ground sets
`pvp_expiry = max(pvp_expiry, now + 60)` (§15.2 last bullet), and this
write is **synchronous, never ticker-deferred**. `grug_pvp` keeps one
in-memory `last_rule` per online player, seeded from the current position
at join. Every synchronous state read — `state()`, `would_block` and step
(a) of every transaction — first compares the current rule against
`last_rule`; observing `contested → non-contested` applies the tail to
meta **before** any snapshot or table evaluation, then updates
`last_rule`. The shared ticker performs the same check only as the
HUD/persistence backstop. The leave-player handler runs the **same
transition observer before discarding session state**: if `last_rule`
is still `contested` **or** the current logout position is contested, it
persists `max(expiry, now + 60)` — so crossing out of contested ground
and logging out before any tick or transaction still records the tail
(the leave callback receives a valid player ObjectRef,
`doc/lua_api.md:6635`). Because that callback does not run for connected
players on shutdown (`doc/lua_api.md:6637`), a `core.register_on_shutdown`
sweep runs the same observer for every connected player. A player who
teleports or sprints out of contested ground is therefore never
observable as safe by any transaction, disconnect race or shutdown race;
in-memory seeding at join is safe because an offline player cannot move.

## 3. Public API and ownership

Per `world_zones.md` §15.5, the seam is:

```lua
grug_pvp.state(player)          -- {tagged=bool, contested=bool, expiry=int}
grug_pvp.tag(player, reason)    -- idempotent; reason is a diagnostic string
grug_pvp.hostile_attempt(attacker, target, context) -- outcome (see below)
grug_pvp.support_contact(helper, target, context)   -- outcome
grug_pvp.damage_committed(attacker, target, hp_loss, absorb_loss)
```

Additions this brief freezes (implementation-owned latitude in §15.5):

```lua
grug_pvp.npc_hostile_attempt(player, npc_ref, context)
    -- tags the player before PvE damage resolves on a protected
    -- enemy-faction combatant (guard, war-front unit, king, royal guard,
    -- protected faction combat object); ordinary creatures never call it.
grug_pvp.npc_damage_committed(player, npc_ref, hp_loss, absorb_loss)
    -- refreshes the involved player on the same HP/absorb rule; the NPC
    -- itself has no tag (§15.2).
grug_pvp.would_block(attacker, target)
    -- pre-state four-row evaluation used by the knockback suppressor
    -- (§5.1) and UI previews. Like every synchronous read it first runs
    -- §2's transition observer, whose only possible mutation is
    -- extending an expiry (the leave-contested tail); the four-row
    -- evaluation itself never tags, refreshes or writes.
grug_pvp.begin_aoe(owner)
    -- returns one single-use AoE batch implementing world_zones.md
    -- §15.3's snapshot semantics: it snapshots the owner state; each
    -- batch:evaluate(target, context) records and returns that target's
    -- four-row outcome against the snapshot; one batch:commit() then
    -- applies the owner tag exactly once iff at least one valid hostile
    -- contact was recorded, and freezes the recorded outcomes for effect
    -- application. Effects and damage_committed run only after commit();
    -- batch:abort() discards everything with no state change. A batch is
    -- synchronous within one server step; reuse, evaluate-after-commit
    -- or commit-after-abort is a loud error.
grug_pvp.register_attributable_effect(owner_name, handle)
grug_pvp.clear_attributable_effects(player)   -- death cleanup, §4.7
grug_pvp.classify_death(player)
    -- returns the recorded final-commit attribution: {pvp=true, killer=..}
    -- when the lethal committed transaction's attacker was an eligible
    -- enemy player, else {pvp=false, source=..}. Consequences (XP rule)
    -- are explicitly NOT applied here (§8).
grug_pvp.register_on_tag(fn) / register_on_hostile_attempt(fn)
    / register_on_support_contact(fn) / register_on_damage_committed(fn)
    -- read-only event bus for WP17 (Home Stone interruption), WP9 and
    -- diagnostics; callbacks run unwrapped after state settles and may
    -- not mutate PvP state re-entrantly (guarded).
```

- Outcome encoding: `hostile_attempt` returns
  `outcome, detail` where `outcome` is one of the interned strings
  `"blocked" | "eligible" | "invalid"` and `detail` is a per-player scratch
  record reused across calls (never retained by callers). This satisfies
  §15.5's blocked / combat-miss / damage-eligible distinction without
  per-punch allocation: `blocked` **is** the combat-miss outcome.
- `context` is a small constant table per call site
  (`{kind="melee"|"swing"|"cast"|"projectile"|"aoe"|"support", ability=id}`),
  interned at integration time, never built per punch. It is static
  call-site identity only; the dynamic AoE owner/target snapshot lives in
  the batch object above, never in `context`.

## 4. Integration per combat path

No caller reads player meta or zone PvP flags directly; each calls the seam
exactly once per would-be effect.

### 4.1 Ordinary tool/fist melee (engine punches)

The shipped PvP melee handler (`on_punchplayer` in `grug_abilities`,
WP38/WP39) gains the transaction at its top: enemy-player pair →
`hostile_attempt`. `blocked` → `return true` (suppresses default damage,
`reference_projects/luanti/doc/lua_api.md:6600`), consume cadence per
§15.1, discard the punch's
fraction bank contribution for procs/rage, count no wear beyond the
ordinary per-swing rule. `eligible` → unchanged WP38/WP39 resolution;
`damage_committed` fires exactly where the integer commit lowers HP or
absorb is consumed (the existing bank rules already localize that point:
fractions bank, refresh happens only on a committing packet). Same-faction
pairs never reach `grug_pvp` (they stay with `grug_factions`' handler;
callbacks combine under `RUN_CALLBACKS_MODE_OR`,
`src/script/cpp_api/s_player.cpp:63`).

### 4.2 Authoritative held swings

The WP39 held clock attacks only a live hostile returned by the current
server eye/look ray. Its swing execution calls `hostile_attempt` with the
ray target at the instant the due swing fires. `blocked` is a combat miss
(cadence consumed, no proc/rage/cost/charge/effect — the identical class
WP39 already defines for evade/immunity/"PvP refusal"); aim-miss semantics
are untouched. The existing exact attacker+ray-target claim-once token
carries the transaction result to the finish seam so cost/reset/rage/
post-effects settle only on `eligible` accepted hits.

### 4.3 Hostile casts

Charge, Taunt, Smite and every later current-aim hostile cast call
`hostile_attempt` at server validation of their pointed target, before any
effect. `blocked` keeps the decided launch-cost rule: resource already
spent by the cast's own rules stays spent; target-dependent effects do not
run.

### 4.4 Projectiles

`grug_projectiles`' settlement seam calls `hostile_attempt` with the
**owner** as attacker at collision time (§15.3: direct projectiles use
their owner; collision with a safe enemy in peaceful ground tags the owner
but does not damage that first safe target). Launch cost (Fireball's
8 mana) remains paid on any outcome. The projectile's exact-once
settlement token is the transaction carrier; terminal cleanup releases it
on every path.

### 4.5 AoE and persistent areas

- One-shot AoE (Frost Nova pattern): snapshot the candidate target set
  first, evaluate `hostile_attempt` per target **from one owner-state
  snapshot** taken before the first tag write: the owner is tagged once if
  any valid hostile contact exists, and every target resolves from the
  same pre-tag snapshot so iteration order cannot change who is protected
  (§15.3). Implementation: exactly the frozen §3 batch API —
  `begin_aoe(owner)`, one `batch:evaluate(target, context)` per candidate,
  then one `batch:commit()` that applies the owner tag exactly once
  before any effect resolves; every per-target outcome was frozen at
  evaluate time from the pre-tag snapshot, so iteration order cannot
  change who is protected.
- Persistent areas remember creation-time eligibility: a safe enemy who
  walks into an active field is ignored and cannot force the remote owner
  into PvP; newly entering **tagged** enemies may be affected while the
  owner is tagged; each real HP/absorb result refreshes normally. The MVP
  ships no persistent field; the seam and tests exist so later WPs cannot
  improvise one.

### 4.6 Protected NPCs

`grug_mobs`' accepted-punch hook already distinguishes protected faction
combatants. WP41 inserts `npc_hostile_attempt` before hostile damage on a
king, royal guard, enemy capital/outpost guard, war-front unit or
protected faction combat object; `npc_damage_committed` refreshes on the
HP/absorb rule. Ordinary hostile creatures never touch PvP state
(§15.1). Passive invulnerable service NPCs never enter the damage
interaction at all (their `do_punch` truthy-return invulnerability stands).

### 4.7 Death, respawn, disconnect

- `register_on_dieplayer`: clear the tag and run
  `clear_attributable_effects` — every registered attributable hostile
  player DoT/field that could immediately re-tag the respawned character is
  removed (§15.4). WP41 registers Fireball-class instant effects trivially
  (nothing persists); the registry exists so later DoT/field WPs must
  enroll.
- Respawns are safe by design (the six protected starting settlements);
  the code still evaluates geography on respawn so a future contested
  respawn would force the tag rather than leak safety.
- Disconnect: the leave-player handler runs §2's transition observer —
  `last_rule == contested` or a contested logout position persists the
  60-second tail before session state is discarded; beyond that the
  absolute timestamp simply persists. Reconnect: state derives; a
  contested-zone reconnect is forced by derivation, and the entry banner
  (§6) replays.

## 5. Bypass protection

### 5.1 Knockback on blocked punches

Builtin knockback is its **own** `on_punchplayer` callback registered
before any mod loads (`builtin/game/knockback.lua:25`), so it runs before
`grug_abilities`' handler and is not stopped by our `return true` (OR-mode
callback combination, `s_player.cpp:63`). A blocked safe-target punch must
have **no** combat effect, knockback included. Frozen mechanism: wrap
`core.calculate_knockback` (`builtin/game/knockback.lua:2`, invoked at
`:40`) to return 0 when both objects are enemy players and
`grug_pvp.would_block(hitter, player)` is true. `would_block` first runs
§2's transition observer for both players — its only possible mutation is
extending an expiry, exactly as §3 specifies — and then evaluates the
pure four-row pre-state table. A knockback evaluated in the same server
step as a contested→peaceful crossing therefore already sees the leaver
tagged, and the suppressor and the subsequent transaction always judge
one punch from the same states: deterministic and order-independent even
though the suppressor runs before the transaction itself. All other pairs
delegate to the original function unchanged.

### 5.2 Central backstop in the HP pipeline

The central `register_on_player_hpchange` modifier chain
(`doc/lua_api.md:6606`; `PlayerHPChangeReason` at `:11865`) gains one
final `grug_pvp` guard: an HP-lowering change whose reason attributes an
enemy **player** source and which does not carry the current transaction's
claim token is zeroed and logged loudly (`core.log("error", ...)` plus the
`/combatdebug` channel). New combat paths therefore fail **closed and
visible**, never open. The token is the same claim-once mechanism WP39
uses for exact-once settlement; `grug_pvp` issues it inside
`hostile_attempt` and the pipeline consumes it once.

### 5.3 Path audit

T7 (§9) enumerates every damage source in the tree (engine punch, held
clock, `deal_ability_damage`, projectile settlement, environment, mobs)
and proves each either carries the token, is same-faction-filtered, or is
non-player-attributed. The audit is a repository grep plus a runtime
assertion suite, recorded in the WP's review evidence.

## 6. HUD, UI and visibility (§15.4)

- Tagged: crossed-swords status icon plus `PvP 0:SS` countdown; forced
  contested state reads `PvP — CONTESTED`. Implemented as one HUD element
  pair per player, updated from the **existing shared 0.5 s ticker** (no
  new globalstep); text writes only when the displayed second changes.
- Zone entry: crossing into a contested zone shows the zone title plus
  "Contested Territory — PvP enabled" for 2.5 s. Crossing detection rides
  the same ticker; the banner replays on reconnect inside contested ground.
- Target Frame: sword marker for tagged enemies, shield marker for
  protected safe enemies — supplied as one `grug_pvp.state`-derived flag to
  the existing WP19 target-frame renderer.
- `/combatdebug` (WP39, admin-only, per-player) gains a PvP channel:
  transaction outcomes with reason, tag transitions, refresh sources,
  backstop hits. Disabled sites do no formatting work beyond the enabled
  check (WP39 rule).

## 7. Performance and Lua 5.1 constraints

- Plain Lua 5.1 throughout (`docs/research/luanti-lua.md` do-not-write
  list); wall clock is `os.time()`; no vector `==`; no `goto`; regression
  tests runnable under `tools/bin/lua51`.
- Hot-path budget: `hostile_attempt` performs at most 2 scalar zone
  queries, no table allocation (interned outcomes, reused scratch detail),
  no string concatenation and no meta write on the no-transition path.
  Target ≤ 25 µs per call on the project host; measured in T7's micro
  bench against ~5 punch packets/s/player and the 100-player design
  target.
- No new globalstep: HUD/tail/banner ride the existing shared 0.5 s
  ticker; all state transitions are event-driven.
- Meta writes throttled to ≥ 1 s expiry deltas; the ticker never writes
  meta for an unchanged state.
- The event bus runs callbacks unwrapped **after** state settles (loud
  errors, AGENTS equipment-notifier precedent) with a re-entrancy guard
  that rejects nested state mutation.

## 8. Explicit boundaries

- **WP9 (quests):** consumes the event bus and `classify_death`'s
  attribution record; WP41 ships no quest content and no death *penalty*
  logic. The **PvP-death/XP consequence stays open** in
  `TODO-design-pvp-death.md`: WP41 delivers the attribution seam that TODO
  requires ("an exact attribution boundary") — the recorded final
  HP-lowering committed transaction — while `grug_xp`'s universal 25% rule
  remains untouched until the TODO is decided. No WP41 code branches on
  the undecided answer.
- **WP13 (structures):** kings, guards and civic services are WP6/WP13
  content; WP41 only supplies §4.6's seam through the existing hooks and
  changes no NPC roster, level or placement.
- **WP42 (war-front life):** later war units call the same
  `npc_hostile_attempt` seam; WP41 ships no clash anchors, schedules or
  units.
- **WP40:** geography is consumed, never recomputed; WP41 lands only after
  WP40's zone API and its compatibility consumers are merged (BACKLOG
  dependency row: WP5, WP39, WP40). The WP5 dependency is consumption-only:
  the per-stack target-race weapon finish and Warding Draught effects enter
  through this seam's damage path when WP5 ships them; WP41 reserves the
  post-crit/pre-armor (counter) and post-armor/pre-absorb (ward) hook
  points (`items_crafting.md` §4.3) without implementing either item.
- **WP17/WP24:** the Home Stone channel interruption consumes the event
  bus exactly as `housing.md` §4 specifies; WP41 implements no channel.

## 9. Task DAG

| Task | Owned result | Requires | Completion gate |
| --- | --- | --- | --- |
| T0 — WP40 gate | resolved zone-API adapter, startup hard-fail without it; `pvp_rule_at` conformance fixtures (peaceful/contested/outside, y = −701, shelf inheritance) | merged WP40 | fixtures green against the live API |
| T1 — state core | `grug_pvp` mod, state model §1.1, tag/expiry/death/reconnect lifecycle, meta persistence, event bus skeleton | T0 | pure-Lua 5.1 unit tests under `tools/wp41/` for every lifecycle edge |
| T2 — transaction engine | §2's atomic sequence, four-row table, AoE snapshot batch (`begin_aoe`), support contact, refresh rules, outcome records, claim token | T1 | full four-row × geography matrix in headless tests |
| T3 — melee/swing integration | §4.1/§4.2 wiring incl. cadence/rage/bank interplay and §5.1 knockback suppression | T2 | WP39 regression suites (`tools/wp39/`) stay green; blocked-swing side-effect matrix passes |
| T4 — casts/projectiles/AoE/support | §4.3–§4.5 wiring incl. launch-cost retention and snapshot ordering | T2 | per-path matrices; Fireball exact-once tests stay green |
| T5 — protected NPCs | §4.6 seam in `grug_mobs` hooks; guard/king tagging and refresh | T2 | NPC matrix incl. ordinary-creature non-effect |
| T6 — HUD/UI/diagnostics | §6 complete; `/combatdebug` PvP channel | T1 | manual checklist + no-allocation ticker audit |
| T7 — backstop and exploit suite | §5.2/§5.3 guard, path audit, micro bench, full exploit matrix §10 | T3–T6 (`/combatdebug` evidence needs T6) | every §10 row automated where headless-testable; bench within §7 budgets |
| T8 — docs and gates | BACKLOG ✅ row, ROADMAP/README sync, AGENTS combat-section delta, review rounds per `wp-workflow.md` | T1–T7 | clean mandatory review; runtime test plan delivered |

T3, T4 and T5 are parallel after T2. Nothing in T1–T8 introduces a second
eligibility evaluator or a second PvP state store.

## 10. Transaction and exploit test matrix

Automated coverage crosses **each combat path** — ordinary melee, ability
swing, targeted cast, projectile, one-shot AoE — with **each geography** —
peaceful, contested, deep y ≤ −701 under a peaceful surface — and the four
state rows (§15.5). Beyond that product, the named cases:

1. Safe→safe first strike: attacker tagged, zero damage, zero knockback,
   zero rage/proc, cadence consumed; target stays safe and untargetable.
2. Safe→tagged: attacker tagged before resolution; damage may land; both
   refreshed only on HP/absorb commit.
3. Tagged→safe blocked in peaceful ground incl. via projectile collision
   and AoE membership.
4. Contested forcing: both players forced before the table on entry,
   presence and reconnect; `outside` (deep ocean/channel) forces nothing
   and resolves with the peaceful-zone table (the decided §15.1 rule).
5. Deep override: y = −701 contested beneath a peaceful capital column;
   y = −700 remains peaceful; returning above starts the full tail and
   never clears early.
6. Refresh truth-table: hp_loss > 0, absorb_loss ≥ 1, effective
   heal/shield/cleanse/buff of tagged ally → refresh both; miss, dodge,
   immunity, refusal, zero-effect damage/support, standing near a tagged
   player → no refresh. Periodic effective ticks repeat the contact.
7. Leave-contested tail: expiry ≥ now + 60 even with no contact inside,
   applied synchronously — a hostile attempt in the same server step
   after teleporting out of contested ground still sees the leaver
   tagged; a logout inside contested ground persists the tail; a logout
   **immediately after crossing out**, before any tick or transaction,
   also persists it (leave-handler transition observer), as does a
   shutdown with connected players (shutdown sweep). Display switches
   CONTESTED → countdown.
8. Death: tag cleared, attributable effects cleared, respawn safe, no
   re-tag from stale fields; `classify_death` records the lethal
   committed transaction's attacker exactly.
9. Disconnect/reconnect: offline countdown, contested-reconnect forcing,
   banner replay; no meta churn on idle ticks.
10. AoE snapshot: iteration order permuted → identical protected set; a
    safe enemy walking into an active persistent field never tags or
    damages; a newly entering tagged enemy may be hit while the owner is
    tagged.
11. Boundary race: teleport/high-speed crossing between poll ticks → the
    transaction's synchronous snapshot decides; no eligibility from stale
    zone state.
12. Launch costs: Fireball mana paid on blocked collision; cast resource
    rules unchanged; blocked swing consumes cadence but no charge/proc.
13. Fraction-bank interplay: banked PvP melee fractions across a
    tag-expiry boundary neither refresh nor land after expiry makes the
    pair ineligible; target-switch bank discard unchanged.
14. Bypass: a synthetic rogue damage path (direct `set_hp` with a
    player-attributed reason, no token) is zeroed, logged and surfaced in
    `/combatdebug`; the token cannot be replayed (claim-once).
15. Knockback suppression: blocked punches move the target 0 nodes;
    eligible punches keep builtin knockback; PvE knockback untouched; a
    knockback evaluated first in the same step as a contested→peaceful
    crossing agrees with the subsequent transaction (the observer runs
    inside `would_block`).
16. NPC seam: attacking a king/royal guard/enemy guard tags before PvE
    damage; damaging them refreshes on the HP/absorb rule; ordinary
    creatures and passive invulnerable services never change PvP state.
17. Same-faction: no `grug_pvp` call, no tag, existing friendly-fire
    handling byte-identical.
18. Spawn-gank impossibility: respawned safe player in the protected start
    cannot be damaged or selected by any path while safe.
19. WP39 invariants: exact-once settlement, cadence, rage, proc and
    projectile suites all green with `grug_pvp` active (regression gate).
20. Performance: hostile_attempt micro bench within §7 budget; zero
    allocation on the no-transition ticker path; meta write count over a
    scripted 10-minute fight within the transition-only bound.

Every headless-testable row lands in `tools/wp41/` as real-code Lua 5.1
regressions (WP39 pattern) and must stay green when later WPs touch
combat, zones or claims.

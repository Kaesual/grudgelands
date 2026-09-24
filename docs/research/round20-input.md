# Round 20 F5 contextual input implementation

**Current gate:** implementation, independent review and technical validation
passed. Delivery: [Round 20 integration receipt](round20-completion.md).
Earlier implementation-milestone notes below describe their original evidence;
the final integration section supersedes their pending-gate wording.

Status: implemented on `wp20-ux`; independent review and final runtime evidence
pending. Implementer: GPT-6 Astra. Reviewer: pending. Critical/High findings,
fix rounds and elapsed time: pending/unknown.

Authority: `../planning/round20-input-contract-proposal.md`. The coordinator
confirmed user acceptance of the two native-engine limitations below and fixed
food holding at 1.5 seconds, exactly one portion per press, existing sound gain.

## Implementation

- All skill representations omit `on_use` and no-dig pointabilities. Their native
  range is four nodes, independently of the unchanged server-side spell range.
  Zero native damage and zero wear preserve skill cooldown/charge representations.
  Native digging uses the actual hand fallback, not equipped weapon capabilities.
- `input.lua` owns observed LMB/RMB press state. Native node/object callbacks
  supply immediate press observations; a throttled control pass supplies held
  intent and release. Target changes can switch from combat to native digging
  within one press. A first ambiguous block waits approximately 200 ms; early
  release casts, sustained input digs, retargeting discards the old release intent.
- Cast readiness/resource checks precede quiet activation. A successful cast
  pushes fallback Strike at least one current weapon interval out. Failure in
  hostile context uses literal melee Strike with its own range; selected swing
  procs keep the existing authoritative transaction. No new global cooldown,
  damage pipeline, ammo consumer or inventory swap is introduced.
- Blink/Sprint explicitly use once-per-press policy. Frost Nova explicitly marks
  offensive self-targeting; other combat/support skills may repeat in appropriate
  target context. Empty-space self activation occurs at most once per press.
- A builtin drop receives one pickup attempt on the initial decision. Repeated
  native packets and held input cannot consume the next drop. Full inventory
  still consumes that attempt.
- RMB interaction retains the actual node/entity callback and owns the press.
  Loose draws with RMB and fires through its existing release transaction;
  LMB uses Strike/digging. Food uses a deliberate 1.5-second RMB hold and one
  portion; existing planting/placement, food eligibility and sound remain.
  Held RMB blocks concurrent skill combat/digging. Slot changes, death and stun
  cancel pending actions until release.
- Every registered node receives one load-time wrapper around its existing
  `on_punch`/`on_dig`, where present. Ordinary tools delegate unchanged; skills
  additionally require current unlocked selection, hand eligibility/reach,
  protection and actor/RMB state. Custom crop callbacks and material/profession
  rules remain the actual delegates, called once. No `can_dig` rewrite, world
  timer, second digging engine, fake PlayerRef or temporary wield replacement.
- Former zero-time `dig_immediate=3` nodes use positive-time group 2. The hand
  and skill zero-use capability uses 0.3 seconds; ordinary tool defaults use the
  engine's positive group-2 time. Ore/material-tier capabilities are untouched.
- Friendly support resolves a current server ray: visible eligible ally in
  range, otherwise self. Remembered targets and stale client refs cannot redirect
  support. Renew still captures its recipient on activation.
- Skill RMB fallback raycasts actors and nodes together by physical intersection
  distance. An NPC in front of a door receives its actual callback. Ordinary
  native object clicks remain engine-dispatched without duplication.

## Engine evidence and accepted limitations

Local Luanti `src/client/game.cpp:2786` selects usable-item input instead of
native digging. `:3269` supplies the real hand fallback. Native `on_punch`
provides the press (`src/network/serverpackethandler.cpp:1047`); completion
still reaches the actual node `on_dig` and builtin protection/drop/wear path
(`builtin/game/item.lua:489`). The new wrapper authorizes, never emulates it.

1. `src/client/game.cpp:1375` releases controls on inventory/pause/chat/focus
   changes. The server cannot distinguish this from physical release. The user
   explicitly accepted that such a GUI interruption can complete an ambiguous
   short-click cast or release a drawn arrow. Known RMB interactions cancel draws.
2. `src/client/client.cpp:631` sends periodic position/control snapshots, not
   a dedicated edge queue. The interval comes from `dedicated_server_step`
   (`src/serverenvironment.cpp:875`, default 0.09 seconds). Native interactions
   immediately embed controls (`client.cpp:1176`), but a very short air click
   between snapshots can be missed once `on_use` is removed. The user accepted
   this limit for playtesting; no promised exact minimum physical-click time.

Native crack presentation can begin before the 200 ms decision; root accepted
that presentation provided actual node removal retains native time and guard.
Creative's accelerated hand can finish some blocks in about 0.164 seconds,
before arbitration expires. The guard safely refuses that completion, which
can cause a predicted block rollback and retry while holding. The coordinator
explicitly retained this bounded Creative limitation; Survival timing takes
priority. No extra digging engine or Creative speed retune was introduced.

## Verification

Executed: plain-5.1 parser and SETGLOBAL inspection for all changed Lua;
five source sweeps, including tools fixtures; `git diff --check`. The only
SETGLOBAL assignments are existing mod tables. Sweep 4 matches existing pipe
string literals and a comment; no unsupported executable operator.
No runtime interpreter or engine run, synchronization, merge or push occurred.

Prepared final-only fixtures:
- `tools/r20_input/friendly_micro.lua`: actual kit definitions; current ally,
  stale pointed reference, forbidden memory lookup, obstruction/range and
  invalid-friendly outcomes.
- `tools/r20_input/controls_micro.lua`: actual input constructor; short/held
  arbitration, changed target, native callback delegation, protection/hand
  eligibility, selected cast versus Strike deadline/range, friendly blocker,
  utility repetition, one-drop attempts, RMB bow/food and cancellation.

Root must consolidate these with final real ability/Scout/food integration
coverage under the single final PUC/LuaJIT pair. Existing fixtures expecting
cast `on_use`, no-dig pointabilities, LMB Loose or remembered healing describe
retired behavior and must be updated rather than treated as new acceptance.

## GUI acceptance

Hold a skill over an enemy, retarget dirt, then enemy again. Test short versus
held support clicks on a block, torches/plants, protected nodes and custom crop
harvesting. Confirm four-node native digging never inherits caster reach.
Use an unaffordable/cooling skill and verify melee Strike only within its reach;
check that successful casts never immediately add a Strike. Aim support at ally,
air and obstructed ally; old support effects retain their original recipient.
Pick one drop from a pile per press. Use Loose RMB draw/release and food RMB
1.5-second hold; interaction before a door/container must not also eat/fire.
Test simultaneous buttons, slot switch and stun. Observe the accepted GUI-release
and very-short-air-click limits, including ordinary configured inventory keys.

## Independent review follow-up: release transactions

Two Medium findings were confirmed in source review. A successful Loose release
now extends the same melee deadline used by generic successful casts, through
`strike_delay.lua`; it preserves any later existing deadline. A failed projectile
launch does not extend it. Food's native placement/secondary callback refreshes
its stack after contextual input runs, because that call can consume a due held
portion. The original delegate runs once on that current copy and its result is
returned to the engine, preventing the stale incoming copy restoring consumed
food. Ordinary placement changes remain authoritative.

`tools/r20_input/transactions_micro.lua` loads the actual Scout, shared deadline
and food modules. It prepares successful/failed release and later-deadline
assertions, then models native callback copy/write-back for partial/last food
portions and a mutating placement delegate. It checks the actual melee deadline;
it does not claim full init.lua damage settlement coverage. The fixture is
prepared only, not executed in this lane. Parent integration must include it in
the replacement final interpreter pair. Parser, SETGLOBAL, all five sweeps and
whitespace checks completed; existing pipe literals/comment are sweep-4 false
positives. No runtime or engine process was run for these fixes.

## Final integration gate

Independent reviewer: Astra `r20_creative`, 0 Critical/High, two Medium findings corrected in one pass and focused re-review clean. Obsolete no-dig comments removed. Final portable dispatch and real Scout/Food transaction fixtures plus real engine registrations passed; elapsed unknown.

Final evidence and delivery state: [Round 20 receipt](round20-completion.md).

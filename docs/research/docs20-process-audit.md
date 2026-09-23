# Docs20 process and carry-over audit

Date: 2026-09-23. Worktree baseline for this lane: commit `bc87d184`, based on
`d6937b31`. Scope was limited to four process documents and this report. No Lua,
runtime data, installed game, BACKLOG or technical guide was changed.

## Process documents reviewed

- `docs/process/wp-workflow.md`
- `docs/process/agent-model-policy.md`
- `docs/process/cross-cli-orchestration.md`
- `docs/process/claude-cli-review.md`

The standing execution rule remains unchanged: a coordinator uses native agents
for its own provider, while provider CLIs are only for an authorized
cross-provider task. The current Round 19 session permits native Sol/Astra and
excludes Claude work because credits are exhausted. General future
cross-provider mechanics and model defaults remain documented; they are not
authorization for this session.

## Corrections made

- Removed the blanket requirement that native review/research agents run
  “synchronously” with a `run_in_background` setting. That was an obsolete
  process workaround and does not fit the native delegation interface. Native
  agents now use its completion notifications and wait mechanism.
- Kept external Claude CLI monitoring as its own OS-process procedure. The
  wording no longer defines it as an exception to a native-agent synchronous
  rule.
- Corrected the active-session reference in the model policy from Round 14 to
  `round19-execution.md`, and the stale “Current Round 10” label in the cross-CLI
  guide to Round 19.
- Added an explicit documentation-only path: when a change does not touch Lua,
  executable fixtures, generated runtime data or the installed game, it does
  not require Lua parser/static/runtime gates, the PUC/LuaJIT final pair,
  synchronization or an in-game test plan. Proportionate content/link checks
  and non-trivial independent review still apply. Runtime-relevant changes keep
  every existing gate and budget.

Independent review requirements, reviewer freshness, Lua 5.1 compatibility,
the final-byte interpreter rule, workstation process caps, permissions,
destructive-action safeguards and escalation requirements were not weakened.

## BACKLOG carry-over comparison

Compared the current `/home/jan/projects/grudgelands/BACKLOG.md` with the
pre-consolidation `/tmp/grug-docs20/BACKLOG.md`.

No confirmed active carry-over was lost in the current consolidated BACKLOG.
The high-risk items that could easily disappear are present:

- corrected 27/53 delivery accounting, including delivered WP8, WP12 and WP20;
- WP11 measured respec-price calibration through WP44;
- WP13 remaining POI roster, shipwrights, mining/apex sockets, geometry issue
  and pending GUI walk;
- WP14 moving held light deferred, while ordinary offhands are delivered;
- WP17 waypoints, claim-bound Home Stone and boats remain distinct from the
  delivered innkeeper return;
- WP21 broader player recovery/rest remains open despite the separate delivered
  mob idle-healing follow-up;
- WP22 pick calibration and repair redesign;
- WP23/WP24/WP34/WP41/WP42 dependency chain;
- WP27–WP30 partial delivery/remainder warnings;
- WP31 economy and GUI remainder, WP32 claim integration and GUI remainder;
- WP37 density conflict is explicitly blocked pending reconciliation;
- WP40 first-public-release obligations and WP46/WP48/WP49 remainders.

The current BACKLOG intentionally moves delivery chronology and detailed old
acceptance evidence to the archive/status layer. Those omissions are not lost
implementation scope. Root should keep `docs/STATUS.md` responsible for the
pending R18/R19 GUI checks as the consolidated BACKLOG now states.

## Stale statements in the current module guide

The current root-owned `docs/technical/module-guide.md` has these concrete
technical discrepancies:

1. Its Atlas section says `grug_map` owns **seven cartographic views**. Round 19
   replaced regional views with one full-world atlas at 1x/2x/4x zoom and native
   horizontal/vertical scrolling.
2. The same section says Round 16 uses **formspec v3**. The current Map page
   requires formspec v4 for native scroll containers. Its outer page uses the
   shared legacy inventory dimensions/scaling, then switches only Map content
   to real coordinates.
3. The Atlas section omits the 0.5-second scroll quiet interval, center-preserving
   zoom, fixed-size markers, full-view clipping/translation and reset on an
   actual new Map-tab visit. These are current implementation seams, not only UI
   prose.
4. The generic UI bullet recommends `real_coordinates[true]` without the Map
   exception above. Applying that blanket instruction to Map would reintroduce
   the Round 19 outer-window sizing defect.
5. The Parties section omits the current saved health-color mode: By class is
   the default, an explicit All green choice persists, and updates remain
   compare-first. This is an active HUD seam.
6. The Quests section omits the current concise item-name presentation while
   worn matching stacks remain valid. That omission can lead a future UI edit
   back to full durability/stat descriptions.
7. The Preparation section describes the older scheduling shape but omits the
   delivered Round 18 scan time budget, small batches, immediate dispatch after
   selection, and dismissible waiting/menu behavior. Its one-in-flight emerge
   statement remains true; the missing scheduler details should be added rather
   than replacing that invariant.

The combat portion already carries the current Round 17 homing contract, Round
19 top-center statuses, movement-gated ambient pursuit and safe idle recovery;
those should be preserved when root corrects the guide.

## Validation

`git diff --check` passes. This documentation-only lane intentionally ran no Lua
parser, interpreter, native server, synchronization or GUI test.


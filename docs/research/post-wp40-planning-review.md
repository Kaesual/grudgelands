# Post-WP40 Planning Pass — Independent Review Record

Status: **Review evidence for the 2026-08-13 planning pass on branch
`plan-post-wp40-readiness` (base `main` = `7b6c876`). Final verdict:
CLEAN.** Raw JSONL streams are deliberately not committed; this record
summarizes reviewer, scope, findings and resolutions.

## Reviewer and parameters

- Reviewer: **Codex CLI, model `gpt-5.6-sol`, `model_reasoning_effort =
  "xhigh"`**, sandbox `read-only`, `approval_policy = "never"`,
  `--ephemeral`, JSONL streaming, no subagents, no network/web search.
- Four rounds against the live branch; the reviewed tree was never
  modified while a round was running. Fixes were committed between
  rounds; rounds 2–4 re-verified each prior fix at its anchor plus the
  complete branch diff for new contradictions.
- The reviewer independently verified every cited engine fact at the
  pinned `reference_projects/luanti` commit `df04879`, including
  `builtin/game/knockback.lua:2/25/40`,
  `src/script/cpp_api/s_player.cpp:63` and
  `doc/lua_api.md:6600/6635/6637`, and confirmed that WP40's frozen
  geometry (128×128/256×256 start envelopes, 600×500 dry cores, fixed
  anchors) is untouched, no WP status changed, and the documentation
  layers/cross-references hold.

## Scope reviewed

The complete planning diff `main...HEAD`: Phase-A design decisions
(start-settlement protection, fail-closed indirect mutation, D20) folded
into `world.md`, `world_zones.md`, `housing.md`, `mounts.md`,
`professions.md`; the WP37 task card; the WP41 and WP44 engineering
briefs; the WP13/WP33/WP24 readiness cards with sequence/critical path;
BACKLOG/ROADMAP/README/TODO synchronization; deletion of
`TODO-design-spawn-safety.md`. Eight lenses: design consistency and no
reopening of decided rules; WP13 spawn-safety/trainer completeness; WP41
executability and single authority; WP44 reproducibility and measurement
truth; WP13/WP33/WP24 dependencies and staging; documentation layers and
backlog truth; missing/hidden decisions and invented measurements; task
DAGs, acceptance gates and Lua/engine contracts.

## Round 1 — full review: NOT CLEAN (2 High, 10 Medium, 1 Low)

All thirteen findings were verified against sources and fixed in
`b33b61e`:

| # | Severity | Finding (condensed) | Resolution |
|---|---|---|---|
| 1 | High | WP41's leave-contested 60 s tail was ticker-driven; a player could be observed safe immediately after leaving contested ground | Synchronous transition observer (in-memory `last_rule`) before every transaction snapshot; ticker demoted to HUD backstop |
| 2 | High | WP13 promised fail-closed protection but the mutation predicate was assigned to the later WP24 — a staging gap | WP13 ships the world-content half of the predicate in `grug_core`; WP24 extends the same predicate to claims |
| 3 | Medium | The WP41 brief silently decided PvP semantics for `outside` (deep ocean/channel) columns | Decided with the owner (2026-08-13) and recorded in `world_zones.md` §15.1: four-row peaceful table, never forced; the brief consumes it |
| 4 | Medium | WP44 allowed publishing sink prices from unvalidated bands | Every band validates before its sink prices publish; unreachable bands leave prices unpublished |
| 5 | Medium | Repair deduction charged armor wear from outgoing swings; quality/wear price scaling unowned | Per-slot trigger classes (weapon = outgoing swings, armor = incoming-hit constant); §1.6 owns the full §8.3 repair-price axis |
| 6 | Medium | Σaoc misused as a spawn-share weight; dangling "§4" reference | Roster weights are an explicit modeled input from shipped spawn rows (1/chance per cell, `aoc` as cap only); `biomes_mobs.md` §4 named |
| 7 | Medium | Baseline-vs-candidate irreproducible after price migration | T0 freezes a checksummed legacy price/buy-back fixture; the baseline leg reads only it |
| 8 | Medium | "One command" was two steps; `date` inside the canonical manifest | One wrapper script; run metadata sidecar-only |
| 9 | Medium | Decay default listed as an open later input though decided (`0`, range 0..3650) | Removed from the later-input list |
| 10 | Medium | Per-faction live limits phrased as a WP40 measured output — WP40 explicitly has no quota | WP40 owns the packing portfolio; WP24 selects defaults below demonstrated capacity |
| 11 | Medium | `begin_aoe` missing from the frozen API; static context conflated with the dynamic snapshot | Batch API frozen (`begin_aoe`/`evaluate`/`commit`/`abort`, single owner tag at commit); context is static call-site identity only |
| 12 | Medium | WP41 T7 depended only on T3–T5 but needed T6's `/combatdebug` | T7 requires T3–T6 |
| 13 | Low | README design tour still described the old, smaller protection extent | Updated to full envelopes + aprons, fail-closed |

## Round 2 — focused re-review: NOT CLEAN (1 High, 4 Medium, 1 Low)

Ten of thirteen fixes confirmed; the `world_zones.md` §15.1 outside rule
was explicitly verified as consistent with §§4/15 and WP40's geography
contract. Remaining findings, fixed in `85c9cc1`:

| # | Severity | Finding (condensed) | Resolution |
|---|---|---|---|
| 1 | High | The tail could still be bypassed by logging out right after crossing contested→peaceful; §4.7 said "nothing to do" on disconnect; `would_block` labeled mutation-free despite the observer | Leave handler runs the observer before discarding session state (`last_rule` OR contested position ⇒ persist tail; `lua_api.md:6635`); `register_on_shutdown` sweep because the leave callback skips connected players on shutdown (`:6637`); §4.7 and test row 7 state the same contract |
| 2 | Medium | BACKLOG WP24 row still said the packing audit "sets" the limits | Row reworded: portfolio informs; WP24 selects defaults below capacity |
| 3 | Medium | Repair-price axis claimed but no owner/task/gate; quality multiplier undecided | New WP44 §1.6 owns the data incl. the quality multiplier as a constrained catalog output; T1 owns it with unit tests; acceptance gate 8 |
| 4 | Medium | WP37's chance multiplication could silently stale WP44's roster weights | Spawn rows are explicit ledger-rerun triggers (WP44 §7); reciprocal rule and gate in the WP37 card; ordering note in the readiness overview |
| 5 | Medium | The report was to embed its own SHA-256 — self-referential | External `.sha256` beside the report; never embedded |
| 6 | Low | WP41 T2 row still said "AoE snapshot context" | "AoE snapshot batch" |

## Round 3 — focused re-review: NOT CLEAN (2 Medium)

Both fixed in `fec12cb`:

| # | Severity | Finding (condensed) | Resolution |
|---|---|---|---|
| 1 | Medium | §5.1 still called `would_block` unconditionally pure, contradicting the §3 API; knockback-first after a boundary crossing could disagree with the transaction | §5.1 states the observer-first contract; suppressor and transaction always judge one punch from the same states; test row 15 covers knockback-first after a crossing |
| 2 | Medium | `game_commit` inside the canonical manifest is self-referential once the frozen report is committed | Removed; checkout commit lives only in the uncommitted sidecar; canonical identity is carried by input content checksums |

## Round 4 — focused re-review: **CLEAN**

No Critical/High/Medium findings. The reviewer confirmed both round-3
fixes at their anchors, re-verified the API/§5.1/test-matrix agreement
and the manifest/reproducibility contract, and found no new
inconsistency in the complete branch diff.

## Final state

- Branch `plan-post-wp40-readiness`, base `main` `7b6c876`, reviewed
  HEAD `fec12cb` (plus this evidence commit).
- `git diff --check` clean; all nine reference submodules exactly on
  their pins; worktree clean; no runtime code changed; no WP status
  changed.

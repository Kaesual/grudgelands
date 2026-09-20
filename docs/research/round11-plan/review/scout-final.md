# Round 11 SCOUT independent review

Reviewer: native GPT-6 Astra; author: native GPT-5.6 Sol. Preliminary production checkpoint: `08f6f8b267e31d9e3f3ef6c2a454a13473f54a93`; subsequent test checkpoint: `d4ace47e85bc3edc2a9a533298956a32b787a791`. No source authorship, main mutation, sync, push, or PUC runtime by reviewer.

Final disposition: **CLEAN — accept `35bde4c8b2b54fd1ead15e0531b61c33a3d19a3b`**. Its worktree is clean. All findings below are historical and closed by `6c4ec3a8` and `3d61d55b`; there are no remaining correctness, design, Lua or performance findings in the bounded Scout scope.

Calibration: 0 Critical / 1 High / 4 Medium / 1 Low found; two source fix rounds; author native Sol, independent reviewer native Astra; elapsed wall time unknown. No PUC runtime was run. The reviewer ran only the bounded movement fixture under LuaJIT and parser/bytecode checks; the other retained focused logs were inspected rather than rerun.

One exact documentation correction is accepted for coordinator integration: replace the evidence document's SETGLOBAL sentence with: “SETGLOBAL inspection found only the declared mod-table writes in top-level `grug_projectiles`, `grug_items` (Quality), `grug_abilities` and `grug_classes`; loaded subfiles write no globals.” This is an already verified factual correction, not a pending gameplay gate.

Final verification: all 15 source/fixture SHA-256 entries in `docs/research/round11-scout-evidence.md` match the frozen checkout. Final `scout.lua` SHA-256 is `909d9c466bee7cddc77ebe210483dfdb06d0390db9368ad4f8da9942556b0a59`. Reviewer parser checks passed for all 18 changed Lua files; SETGLOBAL output contained only the four declared tables above. Retained logs under `tools/r11_scout/evidence/` report gameplay `PASS 0`, swing authority `ok`, projectile batch `ok`, successful ammunition and quality checks, and passing static parser/sweeps. Movement independently reports `wp11_move_aggregator PASS mutation 0` with the old-negative-dispel case. No broad or engine runtime acceptance is implied.

The following findings document the pre-fix checkpoints and their concrete failures.

## High — Opening bypasses its entire mana cost

`mods/PLAYER/grug_abilities/init.lua:1428` calls `affordable(player, selected.cost)` and `:1270` calls `spend(context.player, context.proc.cost)`. Both helpers inspect only resolved `mana`/`rage` fields (`:162–183`), but Opening declares `{mana_percent = 15}` in `mods/PLAYER/grug_abilities/scout.lua:382`. Only the cast dispatcher currently calls `cost_for`.

Concrete scenario: a Scout with zero mana selects a charged Opening and lands a rear swing. The 220/250/280% proc fires, no mana is deducted, and charge resets. Resolve the percentage cost before proc eligibility and carry that exact resolved cost to accepted settlement. Verify the actual held-swing preparation/finish path, including zero mana, front hit, cancellation, and landed rear hit; invoking only `proc_swing` does not exercise the defect.

## Medium — Arrow control treats published damage as accepted settlement

`mods/PLAYER/grug_abilities/scout.lua:80–86` applies Snare/Pinning control whenever `deal_ability_damage` returns a positive number. `mods/CORE/grug_core/combat.lua:1100–1184` returns the published amount even when a punch is vetoed or entirely absorbed; that function's existing callers rely on its established return meaning. The current Scout fixture replaces it with an always-successful damage stub.

Concrete scenario: Pinning Shot reaches an enemy player with a complete absorb shield: HP loss is zero, but the player is rooted. Likewise, `mods/ENTITIES/grug_mobs/init.lua:599–600` vetoes an evading mob's punch, but the positive published amount still reaches Scout's control branch. Root/slow must follow an explicit accepted/HP-loss settlement result, preserving existing damage-return semantics and handling synchronous lethal entity removal safely.

## Medium — A delayed Loose release can attack while mounted

`mods/PLAYER/grug_abilities/scout.lua:240–285` validates the bow and selected ability but does not revalidate mount/cast eligibility. `try_cast` checks mounted state only when starting the draw. `mods/PLAYER/grug_mounts/entity.lua:453–469` permits mounting while out of combat; starting a draw does not mark combat.

Concrete scenario: during a running draw, switch to a mount item and use it, return to Loose before the next 0.05-second draw poll, then release. The active record survives, and the mounted player launches an arrow. Revalidate mounted state at the delayed execution boundary and cancel without ammo consumption.

## Medium — The shipped quality wrapper discards durability notification reasons

`mods/ITEMS/grug_quality/init.lua:934–938` replaces `grug_inventory.equipment_changed` with a two-argument wrapper and forwards only player/listname. REPAIR's third argument `"durability_metadata"` never reaches the real ability consumers (`mods/PLAYER/grug_abilities/init.lua:2069`, `scout.lua:299`). This is present in both root and Scout checkouts.

Concrete scenario: an ordinary landed authoritative swing wears its equipped weapon. The quality wrapper strips the reason, and the ability consumer treats changed wear/remainder metadata as a concrete weapon swap, resets the held cadence to now plus a full interval, discards lateness and clears the input latch. Forward the reason through the actual quality wrapper and exercise this whole notification chain, rather than a direct callback stub.

## Medium — Shake Loose suppresses existing slows instead of clearing them

`mods/PLAYER/grug_classes/scout.lua:19–23` invokes only `grug_core.set_move_immunity`. The actual helper (`mods/CORE/grug_core/movement.lua:334–341`) clears roots but retains every negative modifier; `combine` explicitly suppresses those modifiers only during immunity (`:125–130`).

Concrete scenario: a Scout has a seven-second slow and immediately uses Shake Loose. Movement is restored for four seconds, then the old slow resumes for its remaining three seconds. The authoritative talent promises to clear every existing slow/root. Add a bounded movement seam that removes the existing negative contributions when Shake Loose starts, retaining positive modifiers; exercise the actual movement aggregator rather than a stub. The treatment of newly applied slows during immunity should follow the accepted aggregator contract.

## Low — A fully charged release repeats an identical inventory write

At corrected source `6c4ec3a8`, `mods/PLAYER/grug_abilities/scout.lua:273` clears the cached draw step before the release path calls `set_draw_wear(player, 1)`. If the held draw already reached step 10 / wear 0, release writes wear 0 again. A full held draw therefore permits 12 writes (start, ten updates, repeated release), contrary to the evidence document's at-most-11 claim and the compare-first inventory criterion. Compare the actual wear before calling `inv:set_stack`, or retain the step cache through the final reset.

## Focused fix review at 6c4ec3a8

All original five findings are closed by source inspection of `6c4ec3a8`: the swing carries its resolved cost, control subscribes to accepted outgoing settlement, delayed release rechecks mounting, the quality wrapper preserves its third argument, and Shake Loose calls a new actual dispel seam. Focused tests were added for each relevant boundary. `3d61d55b` closes the low duplicate-write finding by retaining the cached step through the final reset; its actual release paths were re-reviewed.

The evidence document at `4f9af36c` had 15 SHA-256 entries; all were independently matched against that clean worktree. Its movement test command initially returned the fixture function without invoking it. The reviewer ran the actual bounded LuaJIT invocation once: `luajit -e 'io.write(dofile("tools/wp11/move_aggregator_kat.lua")("."))'`, obtaining `wp11_move_aggregator PASS mutation 0`, including the new dispel case. The final evidence now documents the correct invocation. Root authority reconciliation `aa7866ec` correctly records Scout's four base class abilities plus Strike / at most seven hotbar buttons.

## Audited boundaries and pending evidence

Read the required workflow checklist, model policy and Lua interpreter strategy, approved Round 11 gear/class direction, current reconciled Scout and talent specifications, and the full Scout production delta including activation commit `e52ce738` and ammo-test commit `f34d43a6`. Reviewed all sixteen talent values/consumers, class/starter registration, bow draw and release aim, partial impulse/damage, batch rollback, main/quiver consumption/refund, shared Twin durability receipt, charge cadence, timed dodge/cap windows and persistence, and the actual shared cast/swing paths.

Engine contracts were checked in root's pinned reference checkout: `builtin/game/register.lua:546–563` runs non-modifier HP callbacks after modifiers but before engine HP assignment (`src/server/player_sao.cpp:511–537`); `src/client/game.cpp:2786–2789` sends usable-item `INTERACT_USE` on the fresh press, not repeated held ticks. This review does not infer real engine playtest completion.

Final author static gates, bounded LuaJIT evidence, immutable source hashes, and focused re-review of fixes are accepted as described above. Session instruction forbids PUC runtime; no exception was taken.

## User runtime test plan

In a fresh Flatpak world, choose Scout and confirm its equipped wooden bow, stone sword and 20 arrows. Check partial/full Loose with release-time aim, Twin/Longshot and ammunition/refund behavior; try a weapon change and mounting during draw. Test Opening from front/rear with insufficient/sufficient mana, Snare/Pinning against ordinary and refused/fully absorbed hits, and Shake Loose on an existing long slow while Sprint remains active. Confirm Untouchable's six-second window and persistent 180-second cooldown through reconnect. Engine GUI behavior remains the user's runtime gate.

# Round 11 SCOUT independent review

Reviewer: native GPT-6 Astra; author: native GPT-5.6 Sol. Preliminary production checkpoint: `08f6f8b267e31d9e3f3ef6c2a454a13473f54a93`; subsequent test checkpoint: `d4ace47e85bc3edc2a9a533298956a32b787a791`. No source authorship, main mutation, sync, push, or PUC runtime by reviewer.

Disposition: **CHANGES REQUIRED; final candidate/evidence still pending**. Findings below refer to checkpoint source, before author fixes.

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

## Audited boundaries and pending evidence

Read the required workflow checklist, model policy and Lua interpreter strategy, approved Round 11 gear/class direction, current reconciled Scout and talent specifications, and the full Scout production delta including activation commit `e52ce738` and ammo-test commit `f34d43a6`. Reviewed all sixteen talent values/consumers, class/starter registration, bow draw and release aim, partial impulse/damage, batch rollback, main/quiver consumption/refund, shared Twin durability receipt, charge cadence, timed dodge/cap windows and persistence, and the actual shared cast/swing paths.

Engine contracts were checked in root's pinned reference checkout: `builtin/game/register.lua:546–563` runs non-modifier HP callbacks after modifiers but before engine HP assignment (`src/server/player_sao.cpp:511–537`); `src/client/game.cpp:2786–2789` sends usable-item `INTERACT_USE` on the fresh press, not repeated held ticks. This review does not infer real engine playtest completion.

Final author static gates, bounded LuaJIT evidence, immutable source hashes, and focused re-review of fixes remain pending. Session instruction forbids PUC runtime; parser/static gates remain required.

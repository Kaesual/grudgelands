# Independent review: Skills catalog restore fix

Reviewed candidate: `9036d18f5422606a32c4b91964d65d6c9df8c6ed`

Baseline: `0659b8507f004bfcee50cc7ad4a60d47d6859673`

Reviewer independence: read-only review; I did not author the candidate and made no repository edits.

## Findings

### Medium — the regression fixture does not reproduce the engine callback order it claims

`tools/r12_skills/behavior.lua:125-137`

The candidate calls the detached source `allow_take` first (line 125), then the player destination `allow_put` (lines 133-135), writes the destination, and invokes only detached `on_take` (line 137). Luanti's cross-inventory path does destination `allowPut` first and source `allowTake` second (`reference_projects/luanti/src/inventorymanager.cpp:402-405`), performs the move, then reports source `onTake` followed by destination `onPut` (`reference_projects/luanti/src/inventorymanager.cpp:595-605`). Therefore the new block is a useful focused check of the fresh-wrapper defect, infinite catalog preservation, and the destination policy, but it does not satisfy its comment's “complete cross-inventory transaction” claim or the requested actual source/destination callback sequence. A future stateful callback interaction could pass this fixture while failing in-engine. Model the four callbacks in engine order (`destination allow_put`, `source allow_take`, move/infinite-source restoration, `source on_take`, `destination on_put`), with an explicit destination on-action spy even if the current production module does not consume that notification.

## Production-code assessment

No production correctness or security finding was found. `ScriptApiPlayer::pushPutTakeArguments` constructs a fresh `InvRef` for the callback from the inventory location (`reference_projects/luanti/src/script/cpp_api/s_player.cpp:264-283`), so comparing it to the separately created result of `player:get_inventory()` is not a valid identity test. `InvRef:get_location()` returns `{type = "player", name = loc.name}` for a player inventory (`reference_projects/luanti/src/script/lua_api/l_inventory.cpp:350-363`). The replacement at `mods/PLAYER/grug_skills/bound_items.lua:14-18,38` therefore authenticates the inventory by the stable engine location and actor name.

The guard remains limited to player-owned `main` and owned bag lists and still requires `grug_abilities.is_unlocked` or matching mount tier plus owner metadata. A detached, node, undefined, or other player's inventory fails the location/name check. Craft and equipment/external lists remain rejected. The patch does not widen entitlement, mount ownership, or external-list access.

The existing and added checks retain the relevant behavior: duplicate recovery is refused, the detached catalog remains an infinite source, a foreign player location is refused, and cooldown wear/state tests still pass.

## Verification

- Inspected the complete two-file diff and exact candidate commit.
- Traced Luanti `IMoveAction` allow, mutation/infinite-source restoration, and notification paths plus `pushPutTakeArguments`, `InvRef::create`, and `InvRef:get_location`.
- `luajit tools/r12_skills/behavior.lua .`: PASS.
- Plain Lua 5.1 parse of both changed Lua files: PASS, using the primary worktree's `tools/bin/luac51` because the candidate worktree does not contain the built binary.
- Five prohibited-syntax/API sweeps over both changed files: no hits.
- `SETGLOBAL`: none in changed production `bound_items.lua`; the fixture's four globals are deliberate harness setup (`sfinv`, `grug_money`, `grug_mounts`, `grug_skills`).
- `git diff --check`: PASS.

## Limits

No native Luanti GUI/runtime test was run. I did not run PUC runtime or broad suites, per the review brief. The candidate worktree's reference submodules are uninitialized, so engine verification used the primary worktree's pinned Luanti checkout at `df04879066de6eb94ca43996822a6dfacc74feca`; repository files were not modified.

## Re-review after fixture correction

Corrected head: `15d2808c6a19c51ba5d7a96aabd46d109d863291` (on top of production fix `9036d18f5422606a32c4b91964d65d6c9df8c6ed`)

Verdict: clean. The Medium fixture-fidelity finding above is resolved; no new findings.

The correction changes only `tools/r12_skills/behavior.lua`; the production tree is byte-identical to the previously reviewed production fix. The focused transaction now mirrors `IMoveAction` in the relevant order:

1. destination player `allow_put` with a distinct inventory wrapper;
2. detached source `allow_take`, asserted infinite (`-1`);
3. source removal and destination insertion;
4. infinite-source restoration before notifications;
5. detached source `on_take`;
6. player destination `on_put`, observed by an explicit spy.

The fixture asserts the four callback labels in engine order and asserts exactly one destination put notification. It still verifies duplicate refusal, catalog preservation, successful recovery into `main`, foreign-player rejection, disallowed craft destination, allowed owned bag destination, entitlement/owner checks, and retained cooldown behavior. No check was weakened or removed.

Re-review verification on corrected head:

- `git diff --check 9036d18f..15d2808c`: PASS.
- `luajit tools/r12_skills/behavior.lua .`: PASS.
- Plain Lua 5.1 parse of the corrected fixture: PASS.
- Five prohibited-syntax/API sweeps: no hits.
- Fixture `SETGLOBAL` output remains limited to deliberate harness setup globals.
- Exact diff over `mods/` from `9036d18f` to `15d2808c`: empty.

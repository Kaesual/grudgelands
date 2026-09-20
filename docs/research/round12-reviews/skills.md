# Independent review: Round 12 Skills catalogue

Reviewed candidate `900102d71753d9ab4cc7000d80b04ba72169e125`
against base `68ad8bb1`, including prerequisite commit `ca55d4a5`.

## Findings

### Medium — Talent ability unlocks are never announced

`docs/design/skill_trees.md:863` requires the first rank of a new active-skill
talent to announce that the item is available in Inventory > Skills. The talent
consumer at `mods/PLAYER/grug_abilities/init.lua:2233-2239` only normalizes
items, descriptions, mana and HUD state, while the Skills consumer at
`mods/PLAYER/grug_skills/page.lua:119` only rebuilds the detached catalogue.
There is no `chat_send_player` on either path. Reproduction: rank Hamstring,
Renew, Pinning Shot or Opening from zero to one; the catalogue gains the item
but the player receives no location notice. This is especially visible because
the item is intentionally no longer inserted into main.

### Medium — Forbidden equipment strays are skipped instead of purged, and mount cleanup bypasses the equipment-change seam

Ability normalization explicitly excludes every equipment list at
`mods/PLAYER/grug_abilities/init.lua:2183-2199`, so an ability stack inserted by
a server-side inventory writer remains indefinitely in equipment, contrary to
the package rule that normalization clears defensive strays from forbidden
lists. Mount normalization does scan those same lists, but directly calls
`set_stack` at `mods/PLAYER/grug_mounts/state.lua:53-67`; for an injected mount
in a weapon/offhand/trinket list this violates the repository's mandatory
`grug_inventory.equipment_changed` notification seam and can leave equipment
caches/stat consumers stale. Reproduction: insert a bound ability and mount
directly into equipment before `normalize_kit`/`reconcile_items`; the ability is
retained, while the mount is removed without an equipment notification.
Normal UI moves are guarded, but normalization is explicitly the defensive
boundary for server-inserted or forged state.

### Low — Skills deletion accepts a mount representation owned by somebody else

The catalogue destination at `mods/PLAYER/grug_skills/page.lua:70-75` validates
only the live catalogue entry and exact item name. It does not validate the
mount stack's `grug_mounts:owner` metadata, even though the shared entitlement
predicate performs that check at `mods/PLAYER/grug_skills/bound_items.lua:14-21`
and the accepted transaction cases require forged-owner deletion to fail.
Reproduction: give an entitled player a same-tier mount stack whose owner meta
names another player, then drag it onto the matching Skills slot; `allow_put`
returns `-1` and consumes it. Use the same entitlement/owner predicate for this
destination before returning the infinite-destination result.

### Low — The promised page-open detached-inventory audit is absent

`grug_skills.guard_destinations` runs at mods-loaded and join only
(`mods/PLAYER/grug_skills/bound_items.lua:66-73`). Opening Skills calls only
`rebuild` (`mods/PLAYER/grug_skills/page.lua:96-104`). Therefore a detached
inventory created after the join callback remains unwrapped even after the
Skills page opens, despite the finite-guard contract requiring a page-open
audit to cover late detached inventories. Reproduction: create a permissive
detached inventory after player join, open Skills, then move a bound item into
it; its `allow_put` is still unchanged. The current shipped census creates no
such late inventory, which limits present impact, but the package explicitly
claims this event-driven completeness boundary.

## Verified clean areas

- Engine transaction direction is used correctly: player `take` remains open
  for Q/drop, while node and detached destinations reject bound stacks. The
  engine invokes destination `allowPut` and source `allowTake` separately, and
  repeats both directions for swaps
  (`reference_projects/luanti/src/inventorymanager.cpp:383-425`).
- Returning `ItemStack("")` from each bound item's `on_drop` reaches the
  deletion path without creating a world entity; no active-mount state is
  touched.
- Skills recovery rechecks the source-slot mapping and live entitlement,
  scans main, craft and all four bag-content lists, checks main capacity, and
  reconstructs current cooldown/charge wear without mutating runtime ledgers.
- Exact mount tiers remain independently owned and use their original
  6.4/8/8/12 speeds through the exact `tier_id` passed to `toggle`.
- Purchase no longer depends on inventory capacity; failed prerequisite,
  level, model, price or money checks precede the metadata commit.
- Ordinary node/detached items delegate to the prior callback exactly, or use
  the engine's permissive count default. Cross-player player-inventory access
  remains rejected by the server.

No runtime test was needed to establish these source-level findings. Per the
session constraint, no PUC runtime or broad suite was run.
## Integration re-review — `eaac9849fd04676832c1bbebaf388884cd7c3b19`

**Verdict: CLEAN.** The four findings from the first review are fixed in the integrated candidate, and no new correctness issue was found in the reviewed delta from `932cde07`.

- Talent-change rebuilding compares the prior catalog with the new entitled catalog and announces only a newly appearing talent-gated active ability (`mods/PLAYER/grug_skills/page.lua:35-55,133-135`). Initial/class/race/mount rebuilds do not request announcements, and a repeated talent callback does not repeat the notice.
- Ability and mount normalization now inspect equipment lists, purge bound representations from those invalid destinations, and emit one `grug_inventory.equipment_changed(player)` notification after the pass when equipment changed (`mods/PLAYER/grug_abilities/init.lua:2185-2207`; `mods/PLAYER/grug_mounts/state.lua:53-75`). The notification follows the required nil-list full-refresh seam.
- Skills-page deletion now revalidates entitlement; mount entitlement includes the exact owner metadata as well as the owned tier (`mods/PLAYER/grug_skills/bound_items.lua:14-24`; `mods/PLAYER/grug_skills/page.lua:82-88`).
- Opening the Skills page reruns destination wrapping, covering detached inventories registered after startup/join (`mods/PLAYER/grug_skills/page.lua:109-111`; `mods/PLAYER/grug_skills/bound_items.lua:68-75`).
- Runtime use of a Creative/forged locked talent representation is blocked at both execution boundaries: cast dispatch checks `is_unlocked`, and swing selection refuses a locked definition (`mods/PLAYER/grug_abilities/init.lua:1129-1133,1568-1596`). The latter feeds the native input, PvP, and held-clock paths.
- Mount descriptions retain fractional speeds with `%g` (`mods/PLAYER/grug_mounts/state.lua:27-36`).

Focused reviewer reruns on these exact bytes:

```text
chrt --idle 0 ionice -c3 luajit tools/r12_skills/behavior.lua .
r12 Skills real callbacks PASS: normalization, equipment notifications, retained tiers, owner/delete/recovery, bag absence, cooldown, late guards, unlock notice

chrt --idle 0 ionice -c3 luajit tools/wp39/combat_integration_test.lua .
combat_integration_test: ok
```

The committed `source-inputs.sha256` entries match the current files. The checked-in static summary reports Lua 5.1 parse, SETGLOBAL/sweeps, `git diff --check`, and reference-pin checks passing. Per the review constraint, I did not run PUC runtime or broad suites.
